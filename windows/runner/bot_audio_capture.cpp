#include "bot_audio_capture.h"

// windows.h comes first (via the header); mmsystem.h defines WAVE_FORMAT_PCM
// and WAVEFORMATEX even if a build adds WIN32_LEAN_AND_MEAN later.
#include <mmsystem.h>
#include <mmreg.h>

#include <audioclient.h>
#include <avrt.h>
#include <mmdeviceapi.h>
#include <objidl.h>
#include <propidl.h>
#include <wrl/client.h>

#include <cstdint>
#include <cstring>
#include <utility>
#include <vector>

using Microsoft::WRL::ComPtr;

namespace {

// Shared-mode buffer the audio engine keeps for us (100-ns units): 200 ms.
constexpr REFERENCE_TIME kBufferDuration = 2000000;

// Longest wait between two drains of the capture client (the stream event
// normally wakes the thread first).
constexpr DWORD kPollIntervalMs = 10;

// Captured frames are handed on in blocks of at least this many ms.
constexpr uint32_t kMinBlockMs = 20;

// Longest wait for ActivateAudioInterfaceAsync to complete.
constexpr DWORD kActivateTimeoutMs = 5000;

// Longest wait of Start() for the first activation (platform thread).
constexpr DWORD kStartWaitMs = 6000;

// Pause before re-activating after a failure during capture.
constexpr DWORD kRetryDelayMs = 2000;

// Windows 10 version 2004: first build with process-loopback capture.
constexpr DWORD kMinBuild = 19041;

// Stream format requested from the process-loopback client (converted by
// the engine thanks to AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM).
constexpr WORD kChannels = 2;
constexpr DWORD kSampleRate = 48000;
constexpr WORD kBitsPerSample = 16;

// Virtual device of process-loopback activation
// (VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK).
constexpr wchar_t kProcessLoopbackDevice[] = L"VAD\\Process_Loopback";

// AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK.
constexpr INT32 kActivationTypeProcessLoopback = 1;

// PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE.
constexpr INT32 kIncludeTargetProcessTree = 0;

// Same layout as AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS /
// AUDIOCLIENT_ACTIVATION_PARAMS (audioclientactivationparams.h): enums are
// 32-bit, the union holds only the loopback parameters.
struct ProcessLoopbackParams {
  DWORD target_process_id;
  INT32 process_loopback_mode;
};

struct ActivationParams {
  INT32 activation_type;
  ProcessLoopbackParams process_loopback;
};

static_assert(sizeof(ActivationParams) == 12,
              "must match AUDIOCLIENT_ACTIVATION_PARAMS");

using ActivateAudioInterfaceAsyncFn = HRESULT(WINAPI*)(
    LPCWSTR device_interface_path, REFIID riid, PROPVARIANT* activation_params,
    IActivateAudioInterfaceCompletionHandler* completion_handler,
    IActivateAudioInterfaceAsyncOperation** activation_operation);

ActivateAudioInterfaceAsyncFn ResolveActivate() {
  // Mmdevapi.dll stays loaded for the life of the process.
  HMODULE module =
      ::LoadLibraryExW(L"Mmdevapi.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (module == nullptr) {
    return nullptr;
  }
  return reinterpret_cast<ActivateAudioInterfaceAsyncFn>(
      ::GetProcAddress(module, "ActivateAudioInterfaceAsync"));
}

ActivateAudioInterfaceAsyncFn Activator() {
  static const ActivateAudioInterfaceAsyncFn fn = ResolveActivate();
  return fn;
}

// Real Windows build number (GetVersionEx is deprecated and may lie).
DWORD WindowsBuild() {
  using RtlGetVersionFn = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  HMODULE ntdll = ::GetModuleHandleW(L"ntdll.dll");
  if (ntdll == nullptr) {
    return 0;
  }
  const auto get_version = reinterpret_cast<RtlGetVersionFn>(
      ::GetProcAddress(ntdll, "RtlGetVersion"));
  if (get_version == nullptr) {
    return 0;
  }
  RTL_OSVERSIONINFOW info;
  std::memset(&info, 0, sizeof(info));
  info.dwOSVersionInfoSize = sizeof(info);
  if (get_version(&info) != 0) {
    return 0;
  }
  if (info.dwMajorVersion < 10) {
    return 0;
  }
  return info.dwBuildNumber;
}

// Receives the result of ActivateAudioInterfaceAsync. Agile (IAgileObject):
// the completion is called on a worker thread of the audio service.
class ActivationHandler : public IActivateAudioInterfaceCompletionHandler,
                          public IAgileObject {
 public:
  ActivationHandler() {
    done_ = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  }

  ULONG STDMETHODCALLTYPE AddRef() override {
    return static_cast<ULONG>(::InterlockedIncrement(&refs_));
  }

  ULONG STDMETHODCALLTYPE Release() override {
    const LONG refs = ::InterlockedDecrement(&refs_);
    if (refs == 0) {
      delete this;
    }
    return static_cast<ULONG>(refs);
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                           void** object) override {
    if (object == nullptr) {
      return E_POINTER;
    }
    if (riid == __uuidof(IUnknown) ||
        riid == __uuidof(IActivateAudioInterfaceCompletionHandler)) {
      *object = static_cast<IActivateAudioInterfaceCompletionHandler*>(this);
      AddRef();
      return S_OK;
    }
    if (riid == __uuidof(IAgileObject)) {
      *object = static_cast<IAgileObject*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }

  HRESULT STDMETHODCALLTYPE
  ActivateCompleted(IActivateAudioInterfaceAsyncOperation* operation) override {
    HRESULT activate_result = E_FAIL;
    IUnknown* unknown = nullptr;
    HRESULT hr = E_POINTER;
    if (operation != nullptr) {
      hr = operation->GetActivateResult(&activate_result, &unknown);
    }
    if (SUCCEEDED(hr)) {
      hr = activate_result;
    }
    if (SUCCEEDED(hr) && unknown != nullptr) {
      hr = unknown->QueryInterface(IID_PPV_ARGS(client_.GetAddressOf()));
    } else if (SUCCEEDED(hr)) {
      hr = E_NOINTERFACE;
    }
    if (unknown != nullptr) {
      unknown->Release();
    }
    result_ = hr;
    if (done_ != nullptr) {
      ::SetEvent(done_);
    }
    return S_OK;
  }

  // Signalled once ActivateCompleted ran.
  HANDLE done() const { return done_; }

  // Activation result (valid after done()).
  HRESULT result() const { return result_; }

  // The activated client (valid after done()).
  ComPtr<IAudioClient> TakeClient() { return std::move(client_); }

 private:
  virtual ~ActivationHandler() {
    if (done_ != nullptr) {
      ::CloseHandle(done_);
    }
  }

  HANDLE done_ = nullptr;
  HRESULT result_ = E_PENDING;
  ComPtr<IAudioClient> client_;
  LONG refs_ = 1;
};

// Appends |frames| interleaved PCM16 frames of |data| as float32 to |out|.
void AppendPcm16(const BYTE* data, UINT32 frames, std::vector<float>* out) {
  const size_t count = static_cast<size_t>(frames) * kChannels;
  const size_t start = out->size();
  out->resize(start + count);
  float* dst = out->data() + start;
  for (size_t i = 0; i < count; ++i) {
    int16_t v = 0;
    std::memcpy(&v, data + i * sizeof(int16_t), sizeof(v));
    dst[i] = static_cast<float>(v) / 32768.0f;
  }
}

}  // namespace

BotAudioCapture::BotAudioCapture(PacketCallback on_packet,
                                 EventCallback on_event)
    : on_packet_(std::move(on_packet)), on_event_(std::move(on_event)) {
  stop_event_ = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  audio_event_ = ::CreateEventW(nullptr, FALSE, FALSE, nullptr);
  ready_event_ = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
}

BotAudioCapture::~BotAudioCapture() {
  // Joins the worker first: it is the only user of the event handles.
  Stop();
  if (stop_event_) {
    ::CloseHandle(stop_event_);
  }
  if (audio_event_) {
    ::CloseHandle(audio_event_);
  }
  if (ready_event_) {
    ::CloseHandle(ready_event_);
  }
}

// static
bool BotAudioCapture::IsSupported() {
  return WindowsBuild() >= kMinBuild && Activator() != nullptr;
}

bool BotAudioCapture::Start(DWORD pid) {
  if (!stop_event_ || !audio_event_ || !ready_event_ || pid == 0) {
    return false;
  }
  if (!IsSupported()) {
    on_event_("error", "unsupported");
    return false;
  }
  Stop();
  ::ResetEvent(stop_event_);
  ::ResetEvent(audio_event_);
  ::ResetEvent(ready_event_);
  ready_ok_.store(false);
  running_.store(true);
  // The runner builds with _HAS_EXCEPTIONS=0, so std::thread cannot report
  // a failure by throwing; check that a thread was actually created.
  thread_ = std::thread(&BotAudioCapture::Run, this, pid);
  if (!thread_.joinable()) {
    running_.store(false);
    return false;
  }
  const DWORD woke = ::WaitForSingleObject(ready_event_, kStartWaitMs);
  if (woke != WAIT_OBJECT_0 || !ready_ok_.load()) {
    Stop();
    return false;
  }
  return true;
}

void BotAudioCapture::Stop() {
  if (!thread_.joinable()) {
    return;
  }
  ::SetEvent(stop_event_);
  thread_.join();
  running_.store(false);
}

void BotAudioCapture::ReportReady(bool ok, bool* reported) {
  if (*reported) {
    return;
  }
  *reported = true;
  ready_ok_.store(ok);
  ::SetEvent(ready_event_);
}

void BotAudioCapture::Run(DWORD pid) {
  bool reported = false;
  const HRESULT init = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(init)) {
    on_event_("error", "com");
    ReportReady(false, &reported);
    running_.store(false);
    return;
  }
  // Optional MMCSS scheduling; capture works without it.
  DWORD mmcss_task = 0;
  const HANDLE mmcss = ::AvSetMmThreadCharacteristicsW(L"Audio", &mmcss_task);
  for (;;) {
    const Outcome outcome = CaptureOnce(pid, &reported);
    if (outcome == Outcome::kStopped) {
      break;
    }
    // A first activation that fails ends the worker (Start returns false);
    // a failure after capture had started is retried after a pause.
    if (!ready_ok_.load()) {
      break;
    }
    if (::WaitForSingleObject(stop_event_, kRetryDelayMs) == WAIT_OBJECT_0) {
      break;
    }
  }
  ReportReady(false, &reported);
  if (mmcss != nullptr) {
    ::AvRevertMmThreadCharacteristics(mmcss);
  }
  ::CoUninitialize();
  running_.store(false);
}

BotAudioCapture::Outcome BotAudioCapture::CaptureOnce(DWORD pid,
                                                      bool* reported) {
  const ActivateAudioInterfaceAsyncFn activate = Activator();
  if (activate == nullptr) {
    on_event_("error", "unsupported");
    ReportReady(false, reported);
    return Outcome::kFailed;
  }

  ActivationParams params;
  std::memset(&params, 0, sizeof(params));
  params.activation_type = kActivationTypeProcessLoopback;
  params.process_loopback.target_process_id = pid;
  params.process_loopback.process_loopback_mode = kIncludeTargetProcessTree;

  PROPVARIANT prop;
  std::memset(&prop, 0, sizeof(prop));
  prop.vt = VT_BLOB;
  prop.blob.cbSize = sizeof(params);
  prop.blob.pBlobData = reinterpret_cast<BYTE*>(&params);

  ActivationHandler* handler = new ActivationHandler();
  ComPtr<IActivateAudioInterfaceAsyncOperation> operation;
  HRESULT hr = activate(kProcessLoopbackDevice, __uuidof(IAudioClient), &prop,
                        handler, operation.GetAddressOf());
  ComPtr<IAudioClient> client;
  if (SUCCEEDED(hr)) {
    const HANDLE waits[2] = {stop_event_, handler->done()};
    const DWORD woke =
        ::WaitForMultipleObjects(2, waits, FALSE, kActivateTimeoutMs);
    if (woke == WAIT_OBJECT_0) {
      handler->Release();
      return Outcome::kStopped;
    }
    if (woke == WAIT_OBJECT_0 + 1) {
      hr = handler->result();
      client = handler->TakeClient();
    } else {
      hr = E_FAIL;
    }
  }
  // The async operation keeps its own reference until it completes.
  handler->Release();
  if (FAILED(hr) || !client) {
    on_event_("error", "activate");
    ReportReady(false, reported);
    return Outcome::kFailed;
  }

  WAVEFORMATEX format;
  std::memset(&format, 0, sizeof(format));
  format.wFormatTag = WAVE_FORMAT_PCM;
  format.nChannels = kChannels;
  format.nSamplesPerSec = kSampleRate;
  format.wBitsPerSample = kBitsPerSample;
  format.nBlockAlign = static_cast<WORD>(kChannels * (kBitsPerSample / 8));
  format.nAvgBytesPerSec = kSampleRate * format.nBlockAlign;
  format.cbSize = 0;

  ::ResetEvent(audio_event_);
  hr = client->Initialize(
      AUDCLNT_SHAREMODE_SHARED,
      AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
          AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
          AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
      kBufferDuration, 0, &format, nullptr);
  if (SUCCEEDED(hr)) {
    hr = client->SetEventHandle(audio_event_);
  }
  ComPtr<IAudioCaptureClient> capture;
  if (SUCCEEDED(hr)) {
    hr = client->GetService(IID_PPV_ARGS(capture.GetAddressOf()));
    if (SUCCEEDED(hr) && !capture) {
      hr = E_POINTER;
    }
  }
  if (SUCCEEDED(hr)) {
    hr = client->Start();
  }
  if (FAILED(hr)) {
    on_event_("error", "init");
    ReportReady(false, reported);
    return Outcome::kFailed;
  }
  on_event_("started", "");
  ReportReady(true, reported);

  const size_t min_block_samples =
      static_cast<size_t>(kSampleRate) * kMinBlockMs / 1000 * kChannels;
  const HANDLE waits[2] = {stop_event_, audio_event_};
  Outcome outcome = Outcome::kStopped;
  std::vector<float> batch;
  batch.reserve(min_block_samples * 2);

  auto flush = [&]() {
    if (batch.empty()) {
      return;
    }
    SystemAudioCapture::Packet packet;
    packet.sample_rate = kSampleRate;
    packet.channels = kChannels;
    packet.samples = std::move(batch);
    batch = std::vector<float>();
    batch.reserve(min_block_samples * 2);
    on_packet_(std::move(packet));
  };

  for (;;) {
    const DWORD woke =
        ::WaitForMultipleObjects(2, waits, FALSE, kPollIntervalMs);
    if (woke == WAIT_OBJECT_0) {
      outcome = Outcome::kStopped;
      break;
    }
    if (woke != WAIT_TIMEOUT && woke != WAIT_OBJECT_0 + 1) {
      on_event_("error", "capture");
      outcome = Outcome::kFailed;
      break;
    }

    // Drain every packet the engine holds.
    UINT32 packet_frames = 0;
    for (;;) {
      hr = capture->GetNextPacketSize(&packet_frames);
      if (FAILED(hr) || packet_frames == 0) {
        break;
      }
      BYTE* data = nullptr;
      UINT32 frames = 0;
      DWORD flags = 0;
      hr = capture->GetBuffer(&data, &frames, &flags, nullptr, nullptr);
      if (FAILED(hr)) {
        break;
      }
      if (hr == AUDCLNT_S_BUFFER_EMPTY) {
        hr = S_OK;
        break;
      }
      if (frames > 0) {
        if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0 || data == nullptr) {
          batch.resize(batch.size() + static_cast<size_t>(frames) * kChannels,
                       0.0f);
        } else {
          AppendPcm16(data, frames, &batch);
        }
      }
      hr = capture->ReleaseBuffer(frames);
      if (FAILED(hr)) {
        break;
      }
    }
    if (FAILED(hr)) {
      on_event_("error", "capture");
      outcome = Outcome::kFailed;
      break;
    }
    if (batch.size() >= min_block_samples) {
      flush();
    }
  }
  client->Stop();
  // Frames already read belong to the recording.
  flush();
  return outcome;
}
