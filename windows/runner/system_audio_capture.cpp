#include "system_audio_capture.h"

#include <audioclient.h>
#include <mmdeviceapi.h>
#include <mmreg.h>
#include <wrl/client.h>

#include <cstring>
#include <memory>
#include <system_error>
#include <utility>

using Microsoft::WRL::ComPtr;

namespace {

// Shared-mode buffer the audio engine keeps for us (100-ns units): 200 ms.
constexpr REFERENCE_TIME kBufferDuration = 2000000;

// How often the capture client is drained. Loopback event callbacks are not
// signalled reliably on every Windows 10 build, so polling is used.
constexpr DWORD kPollIntervalMs = 20;

// Pause before reopening after a device change / failure.
constexpr DWORD kRestartDelayMs = 200;
constexpr DWORD kRetryDelayMs = 2000;

enum class SampleKind { kFloat32, kInt16, kInt24, kInt32, kUnsupported };

// True when |guid| is the KSDATAFORMAT_SUBTYPE_* GUID of |format_tag|
// ({tag-0000-0010-8000-00aa00389b71}); avoids depending on ksmedia.h.
bool IsSubtypeOf(const GUID& guid, WORD format_tag) {
  static const unsigned char kTail[8] = {0x80, 0x00, 0x00, 0xaa,
                                         0x00, 0x38, 0x9b, 0x71};
  return guid.Data1 == format_tag && guid.Data2 == 0x0000 &&
         guid.Data3 == 0x0010 && std::memcmp(guid.Data4, kTail, 8) == 0;
}

SampleKind KindOf(const WAVEFORMATEX* format) {
  WORD tag = format->wFormatTag;
  if (tag == WAVE_FORMAT_EXTENSIBLE &&
      format->cbSize >= sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX)) {
    const auto* ext = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(format);
    if (IsSubtypeOf(ext->SubFormat, WAVE_FORMAT_IEEE_FLOAT)) {
      tag = WAVE_FORMAT_IEEE_FLOAT;
    } else if (IsSubtypeOf(ext->SubFormat, WAVE_FORMAT_PCM)) {
      tag = WAVE_FORMAT_PCM;
    }
  }
  if (tag == WAVE_FORMAT_IEEE_FLOAT && format->wBitsPerSample == 32) {
    return SampleKind::kFloat32;
  }
  if (tag == WAVE_FORMAT_PCM) {
    switch (format->wBitsPerSample) {
      case 16:
        return SampleKind::kInt16;
      case 24:
        return SampleKind::kInt24;
      case 32:
        return SampleKind::kInt32;
      default:
        break;
    }
  }
  return SampleKind::kUnsupported;
}

float ReadSample(const BYTE* p, SampleKind kind) {
  switch (kind) {
    case SampleKind::kFloat32: {
      float v = 0.0f;
      std::memcpy(&v, p, sizeof(v));
      return v;
    }
    case SampleKind::kInt16: {
      int16_t v = 0;
      std::memcpy(&v, p, sizeof(v));
      return static_cast<float>(v) / 32768.0f;
    }
    case SampleKind::kInt24: {
      const uint32_t u = (static_cast<uint32_t>(p[2]) << 24) |
                         (static_cast<uint32_t>(p[1]) << 16) |
                         (static_cast<uint32_t>(p[0]) << 8);
      return static_cast<float>(static_cast<int32_t>(u)) / 2147483648.0f;
    }
    case SampleKind::kInt32: {
      int32_t v = 0;
      std::memcpy(&v, p, sizeof(v));
      return static_cast<float>(v) / 2147483648.0f;
    }
    default:
      return 0.0f;
  }
}

// Appends |frames| frames of |data| as float32 to |out|.
void AppendFrames(const BYTE* data, UINT32 frames, const WAVEFORMATEX* format,
                  SampleKind kind, std::vector<float>* out) {
  const size_t channels = format->nChannels;
  const size_t bytes_per_sample = format->wBitsPerSample / 8;
  const size_t block_align = format->nBlockAlign;
  const size_t start = out->size();
  out->resize(start + static_cast<size_t>(frames) * channels);
  float* dst = out->data() + start;
  for (size_t f = 0; f < frames; ++f) {
    const BYTE* frame = data + f * block_align;
    for (size_t c = 0; c < channels; ++c) {
      *dst++ = ReadSample(frame + c * bytes_per_sample, kind);
    }
  }
}

struct CoTaskMemDeleter {
  void operator()(WAVEFORMATEX* p) const { ::CoTaskMemFree(p); }
};

// Signals |restart_event| when the default console render device changes.
// Reference counted like any COM object; the capture thread holds one
// reference while it is registered.
class DeviceNotifier : public IMMNotificationClient {
 public:
  explicit DeviceNotifier(HANDLE restart_event)
      : restart_event_(restart_event) {}

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
        riid == __uuidof(IMMNotificationClient)) {
      *object = static_cast<IMMNotificationClient*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }

  HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow flow, ERole role,
                                                   LPCWSTR) override {
    if (flow == eRender && role == eConsole) {
      ::SetEvent(restart_event_);
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR, DWORD) override {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR,
                                                   const PROPERTYKEY) override {
    return S_OK;
  }

 private:
  virtual ~DeviceNotifier() = default;

  HANDLE restart_event_;
  LONG refs_ = 1;
};

}  // namespace

SystemAudioCapture::SystemAudioCapture(PacketCallback on_packet,
                                       EventCallback on_event)
    : on_packet_(std::move(on_packet)), on_event_(std::move(on_event)) {
  stop_event_ = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  restart_event_ = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
}

SystemAudioCapture::~SystemAudioCapture() {
  Stop();
  if (stop_event_) {
    ::CloseHandle(stop_event_);
  }
  if (restart_event_) {
    ::CloseHandle(restart_event_);
  }
}

bool SystemAudioCapture::Start() {
  if (!stop_event_ || !restart_event_) {
    return false;
  }
  if (thread_.joinable()) {
    if (running_.load()) {
      return true;
    }
    // The previous worker ended by itself (e.g. COM failure): reap it.
    thread_.join();
  }
  ::ResetEvent(stop_event_);
  ::ResetEvent(restart_event_);
  running_.store(true);
  try {
    thread_ = std::thread(&SystemAudioCapture::Run, this);
  } catch (const std::system_error&) {
    running_.store(false);
    return false;
  }
  return true;
}

void SystemAudioCapture::Stop() {
  if (!thread_.joinable()) {
    return;
  }
  ::SetEvent(stop_event_);
  thread_.join();
  running_.store(false);
}

// static
bool SystemAudioCapture::IsSupported() {
  ComPtr<IMMDeviceEnumerator> enumerator;
  const HRESULT hr =
      ::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                         IID_PPV_ARGS(enumerator.GetAddressOf()));
  return SUCCEEDED(hr) && enumerator;
}

void SystemAudioCapture::Run() {
  const HRESULT init = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(init)) {
    on_event_("error", "com");
    running_.store(false);
    return;
  }
  {
    ComPtr<IMMDeviceEnumerator> enumerator;
    HRESULT hr =
        ::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                           IID_PPV_ARGS(enumerator.GetAddressOf()));
    if (FAILED(hr) || !enumerator) {
      on_event_("error", "com");
    } else {
      DeviceNotifier* notifier = new DeviceNotifier(restart_event_);
      const bool registered =
          SUCCEEDED(enumerator->RegisterEndpointNotificationCallback(notifier));
      bool first = true;
      const HANDLE waits[2] = {stop_event_, restart_event_};
      for (;;) {
        ::ResetEvent(restart_event_);
        const Outcome outcome = CaptureOnce(enumerator.Get(), first);
        if (outcome == Outcome::kStopped) {
          break;
        }
        first = false;
        const DWORD delay =
            outcome == Outcome::kRestart ? kRestartDelayMs : kRetryDelayMs;
        // A failed device is retried after a while, or as soon as the
        // default device changes; a stop request ends the loop.
        const DWORD woke = ::WaitForMultipleObjects(2, waits, FALSE, delay);
        if (woke == WAIT_OBJECT_0) {
          break;
        }
      }
      if (registered) {
        enumerator->UnregisterEndpointNotificationCallback(notifier);
      }
      notifier->Release();
    }
  }
  ::CoUninitialize();
  running_.store(false);
}

SystemAudioCapture::Outcome SystemAudioCapture::CaptureOnce(
    IMMDeviceEnumerator* enumerator, bool first) {
  ComPtr<IMMDevice> device;
  HRESULT hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole,
                                                   device.GetAddressOf());
  if (FAILED(hr) || !device) {
    on_event_("error", "no_device");
    return Outcome::kFailed;
  }

  ComPtr<IAudioClient> client;
  hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                        reinterpret_cast<void**>(client.GetAddressOf()));
  if (FAILED(hr) || !client) {
    on_event_("error", "init");
    return Outcome::kFailed;
  }

  WAVEFORMATEX* raw_format = nullptr;
  hr = client->GetMixFormat(&raw_format);
  if (FAILED(hr) || raw_format == nullptr) {
    on_event_("error", "init");
    return Outcome::kFailed;
  }
  std::unique_ptr<WAVEFORMATEX, CoTaskMemDeleter> format(raw_format);
  const SampleKind kind = KindOf(format.get());
  if (kind == SampleKind::kUnsupported || format->nChannels == 0 ||
      format->nSamplesPerSec == 0) {
    on_event_("error", "format");
    return Outcome::kFailed;
  }

  hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK,
                          kBufferDuration, 0, format.get(), nullptr);
  if (FAILED(hr)) {
    on_event_("error", "init");
    return hr == AUDCLNT_E_DEVICE_INVALIDATED ? Outcome::kRestart
                                              : Outcome::kFailed;
  }

  ComPtr<IAudioCaptureClient> capture;
  hr = client->GetService(IID_PPV_ARGS(capture.GetAddressOf()));
  if (FAILED(hr) || !capture) {
    on_event_("error", "init");
    return Outcome::kFailed;
  }
  hr = client->Start();
  if (FAILED(hr)) {
    on_event_("error", "init");
    return hr == AUDCLNT_E_DEVICE_INVALIDATED ? Outcome::kRestart
                                              : Outcome::kFailed;
  }
  on_event_(first ? "started" : "restarted", "");

  const uint32_t sample_rate = format->nSamplesPerSec;
  const uint32_t channels = format->nChannels;
  const HANDLE waits[2] = {stop_event_, restart_event_};
  Outcome outcome = Outcome::kStopped;
  std::vector<float> batch;
  for (;;) {
    const DWORD woke =
        ::WaitForMultipleObjects(2, waits, FALSE, kPollIntervalMs);
    if (woke == WAIT_OBJECT_0) {
      outcome = Outcome::kStopped;
      break;
    }
    if (woke == WAIT_OBJECT_0 + 1) {
      outcome = Outcome::kRestart;
      break;
    }
    if (woke != WAIT_TIMEOUT) {
      on_event_("error", "capture");
      outcome = Outcome::kFailed;
      break;
    }

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
      if (hr == AUDCLNT_S_BUFFER_EMPTY || frames == 0) {
        capture->ReleaseBuffer(frames);
        break;
      }
      if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0 || data == nullptr) {
        batch.resize(batch.size() + static_cast<size_t>(frames) * channels,
                     0.0f);
      } else {
        AppendFrames(data, frames, format.get(), kind, &batch);
      }
      hr = capture->ReleaseBuffer(frames);
      if (FAILED(hr)) {
        break;
      }
    }
    if (hr == AUDCLNT_E_DEVICE_INVALIDATED) {
      outcome = Outcome::kRestart;
      break;
    }
    if (FAILED(hr)) {
      on_event_("error", "capture");
      outcome = Outcome::kFailed;
      break;
    }
    if (!batch.empty()) {
      Packet packet;
      packet.sample_rate = sample_rate;
      packet.channels = channels;
      packet.samples = std::move(batch);
      batch = std::vector<float>();
      on_packet_(std::move(packet));
    }
  }
  client->Stop();
  return outcome;
}
