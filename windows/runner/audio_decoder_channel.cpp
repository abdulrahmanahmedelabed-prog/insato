#include "audio_decoder_channel.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propidl.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <utility>

using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

namespace {

constexpr char kChannelName[] = "insato/audio_decoder";

// MF_SOURCE_READER_FIRST_AUDIO_STREAM as the DWORD the reader API takes.
constexpr DWORD kAudioStream =
    static_cast<DWORD>(MF_SOURCE_READER_FIRST_AUDIO_STREAM);
constexpr DWORD kMediaSource = static_cast<DWORD>(MF_SOURCE_READER_MEDIASOURCE);

constexpr int32_t kDefaultChunk = 256 * 1024;
constexpr int32_t kMinChunk = 4096;
constexpr int32_t kMaxChunk = 4 * 1024 * 1024;

// ReadSample calls in a row that return neither audio nor end of stream
// before the decoder is considered stuck.
constexpr int kMaxEmptyReads = 10000;

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int size = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         utf8.data(),
                                         static_cast<int>(utf8.size()),
                                         nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                        static_cast<int>(utf8.size()), &wide[0], size);
  return wide;
}

std::string HexResult(HRESULT hr) {
  char buffer[32];
  std::snprintf(buffer, sizeof(buffer), "hr=0x%08lX",
                static_cast<unsigned long>(hr));
  return std::string(buffer);
}

// Protocol error code of a failed HRESULT.
const char* ErrorCodeFor(HRESULT hr) {
  if (hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) ||
      hr == HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND)) {
    return "not_found";
  }
  if (hr == E_ACCESSDENIED ||
      hr == HRESULT_FROM_WIN32(ERROR_SHARING_VIOLATION)) {
    return "io";
  }
  if (hr == MF_E_UNSUPPORTED_BYTESTREAM_TYPE ||
      hr == MF_E_UNSUPPORTED_FORMAT || hr == MF_E_UNSUPPORTED_SCHEME ||
      hr == MF_E_INVALIDMEDIATYPE || hr == MF_E_TOPO_CODEC_NOT_FOUND ||
      hr == MF_E_NO_MORE_TYPES || hr == MF_E_INVALIDSTREAMNUMBER ||
      hr == MF_E_INVALIDTYPE) {
    return "unsupported";
  }
  return "decode";
}

// Codec label from an audio subtype GUID. Audio subtypes are
// {XXXXXXXX-0000-0010-8000-00AA00389B71} with Data1 = the WAVE format tag,
// so no SDK-version-dependent constants are needed.
std::string CodecLabel(const GUID& subtype) {
  switch (subtype.Data1) {
    case 0x0001:
      return "pcm";
    case 0x0003:
      return "pcm_float";
    case 0x0006:
      return "alaw";
    case 0x0007:
      return "mulaw";
    case 0x0011:
      return "ima_adpcm";
    case 0x0031:
      return "gsm610";
    case 0x0055:
      return "mp3";
    case 0x0161:
    case 0x0162:
    case 0x0163:
      return "wma";
    case 0x1610:
      return "aac";
    case 0x7361:
      return "amr_nb";
    case 0x7362:
      return "amr_wb";
    case 0x704F:
      return "opus";
    case 0xF1AC:
      return "flac";
    case 0x6C61:
      return "alac";
    default: {
      char buffer[24];
      std::snprintf(buffer, sizeof(buffer), "wave_0x%04lX",
                    static_cast<unsigned long>(subtype.Data1 & 0xFFFF));
      return std::string(buffer);
    }
  }
}

}  // namespace

struct AudioDecoderChannel::Session {
  ComPtr<IMFSourceReader> reader;
  // Format of the samples the reader delivers now.
  UINT32 rate = 0;
  UINT32 channels = 0;
  UINT32 bits = 16;
  bool is_float = false;
  bool ended = false;
  // PCM16 of a sample that arrived in a new format while a chunk in the old
  // one was being filled; returned first by the next read.
  std::vector<uint8_t> carry;
};

namespace {

// Reads the reader's current output type. False on failure or when it is
// not PCM / float.
bool ReadCurrentFormat(IMFSourceReader* reader, UINT32* rate,
                       UINT32* channels, UINT32* bits, bool* is_float) {
  ComPtr<IMFMediaType> type;
  if (FAILED(reader->GetCurrentMediaType(kAudioStream, &type))) {
    return false;
  }
  GUID subtype = {};
  type->GetGUID(MF_MT_SUBTYPE, &subtype);
  *rate = MFGetAttributeUINT32(type.Get(), MF_MT_AUDIO_SAMPLES_PER_SECOND, 0);
  *channels = MFGetAttributeUINT32(type.Get(), MF_MT_AUDIO_NUM_CHANNELS, 0);
  *bits = MFGetAttributeUINT32(type.Get(), MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
  *is_float = subtype == MFAudioFormat_Float;
  return *rate > 0 && *channels > 0 &&
         (subtype == MFAudioFormat_PCM || subtype == MFAudioFormat_Float);
}

void PushSample16(std::vector<uint8_t>* out, int value) {
  if (value > 32767) value = 32767;
  if (value < -32768) value = -32768;
  const uint16_t u = static_cast<uint16_t>(static_cast<int16_t>(value));
  out->push_back(static_cast<uint8_t>(u & 0xFF));
  out->push_back(static_cast<uint8_t>((u >> 8) & 0xFF));
}

// Appends |len| bytes in the session's format to |out| as PCM16 LE.
void AppendAsPcm16(const BYTE* data, DWORD len, UINT32 bits, bool is_float,
                   std::vector<uint8_t>* out) {
  if (is_float) {
    const DWORD n = len / 4;
    out->reserve(out->size() + n * 2);
    for (DWORD i = 0; i < n; ++i) {
      float v = 0.0f;
      std::memcpy(&v, data + i * 4, sizeof(float));
      if (!(v == v)) v = 0.0f;  // NaN
      v = std::max(-1.0f, std::min(1.0f, v));
      PushSample16(out, static_cast<int>(v * 32767.0f));
    }
    return;
  }
  switch (bits) {
    case 8: {
      out->reserve(out->size() + len * 2);
      for (DWORD i = 0; i < len; ++i) {
        PushSample16(out, (static_cast<int>(data[i]) - 128) * 256);
      }
      return;
    }
    case 24: {
      const DWORD n = len / 3;
      out->reserve(out->size() + n * 2);
      for (DWORD i = 0; i < n; ++i) {
        out->push_back(data[i * 3 + 1]);
        out->push_back(data[i * 3 + 2]);
      }
      return;
    }
    case 32: {
      const DWORD n = len / 4;
      out->reserve(out->size() + n * 2);
      for (DWORD i = 0; i < n; ++i) {
        out->push_back(data[i * 4 + 2]);
        out->push_back(data[i * 4 + 3]);
      }
      return;
    }
    default:
      out->insert(out->end(), data, data + (len - len % 2));
      return;
  }
}

// Appends the audio of |sample| to |out|. False when the buffer cannot be
// read.
bool AppendSample(IMFSample* sample, UINT32 bits, bool is_float,
                  std::vector<uint8_t>* out) {
  ComPtr<IMFMediaBuffer> buffer;
  if (FAILED(sample->ConvertToContiguousBuffer(&buffer))) {
    return false;
  }
  BYTE* data = nullptr;
  DWORD length = 0;
  if (FAILED(buffer->Lock(&data, nullptr, &length))) {
    return false;
  }
  if (data != nullptr && length > 0) {
    AppendAsPcm16(data, length, bits, is_float, out);
  }
  buffer->Unlock();
  return true;
}

// Sets a PCM output type on the reader: 16-bit PCM, else PCM at the
// decoder's depth, else float.
HRESULT ConfigurePcmOutput(IMFSourceReader* reader) {
  HRESULT hr = E_FAIL;
  for (int attempt = 0; attempt < 3; ++attempt) {
    ComPtr<IMFMediaType> type;
    hr = MFCreateMediaType(&type);
    if (FAILED(hr)) {
      return hr;
    }
    type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    type->SetGUID(MF_MT_SUBTYPE,
                  attempt == 2 ? MFAudioFormat_Float : MFAudioFormat_PCM);
    if (attempt == 0) {
      type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
    }
    hr = reader->SetCurrentMediaType(kAudioStream, nullptr, type.Get());
    if (SUCCEEDED(hr)) {
      return hr;
    }
  }
  return hr;
}

void Fail(std::unique_ptr<flutter::MethodResult<EncodableValue>>& result,
          const char* code, const std::string& message) {
  result->Error(code, message);
}

const EncodableValue* Arg(const EncodableValue* args, const char* key) {
  const auto* map = std::get_if<EncodableMap>(args);
  if (map == nullptr) {
    return nullptr;
  }
  auto it = map->find(EncodableValue(key));
  return it == map->end() ? nullptr : &it->second;
}

int32_t IntArg(const EncodableValue* args, const char* key, int32_t fallback) {
  const EncodableValue* v = Arg(args, key);
  if (v == nullptr) {
    return fallback;
  }
  if (const auto* i = std::get_if<int32_t>(v)) {
    return *i;
  }
  if (const auto* l = std::get_if<int64_t>(v)) {
    return static_cast<int32_t>(*l);
  }
  return fallback;
}

}  // namespace

AudioDecoderChannel::AudioDecoderChannel(flutter::BinaryMessenger* messenger) {
  mf_started_ = SUCCEEDED(::MFStartup(MF_VERSION, MFSTARTUP_LITE));
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
}

AudioDecoderChannel::~AudioDecoderChannel() {
  channel_->SetMethodCallHandler(nullptr);
  // Readers must be released before Media Foundation shuts down.
  sessions_.clear();
  if (mf_started_) {
    ::MFShutdown();
  }
}

void AudioDecoderChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableValue* args = call.arguments();

  if (method == "isSupported") {
    result->Success(EncodableValue(mf_started_));
    return;
  }

  if (method == "open") {
    if (!mf_started_) {
      Fail(result, "unsupported", "Media Foundation unavailable");
      return;
    }
    const EncodableValue* path_value = Arg(args, "path");
    const auto* path =
        path_value == nullptr ? nullptr : std::get_if<std::string>(path_value);
    if (path == nullptr || path->empty()) {
      Fail(result, "io", "missing path");
      return;
    }
    const std::wstring wide = Utf8ToWide(*path);
    if (wide.empty()) {
      Fail(result, "io", "invalid path encoding");
      return;
    }
    const DWORD attributes = ::GetFileAttributesW(wide.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) {
      Fail(result, "not_found", "file not found");
      return;
    }

    auto session = std::make_unique<Session>();
    HRESULT hr =
        ::MFCreateSourceReaderFromURL(wide.c_str(), nullptr, &session->reader);
    if (FAILED(hr)) {
      Fail(result, ErrorCodeFor(hr), "MFCreateSourceReaderFromURL " +
                                          HexResult(hr));
      return;
    }
    session->reader->SetStreamSelection(
        static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
    hr = session->reader->SetStreamSelection(kAudioStream, TRUE);
    if (FAILED(hr)) {
      // No audio stream at all.
      Fail(result, "unsupported", "no audio stream " + HexResult(hr));
      return;
    }

    std::string codec;
    {
      ComPtr<IMFMediaType> native;
      if (SUCCEEDED(
              session->reader->GetNativeMediaType(kAudioStream, 0, &native))) {
        GUID subtype = {};
        if (SUCCEEDED(native->GetGUID(MF_MT_SUBTYPE, &subtype))) {
          codec = CodecLabel(subtype);
        }
      }
    }

    hr = ConfigurePcmOutput(session->reader.Get());
    if (FAILED(hr)) {
      // No decoder for this codec is installed.
      Fail(result, "unsupported",
           "no PCM output for " + (codec.empty() ? std::string("audio") : codec) +
               " " + HexResult(hr));
      return;
    }
    if (!ReadCurrentFormat(session->reader.Get(), &session->rate,
                           &session->channels, &session->bits,
                           &session->is_float)) {
      Fail(result, "unsupported", "unexpected output type");
      return;
    }

    int64_t duration_ms = 0;
    PROPVARIANT var;
    ::PropVariantInit(&var);
    if (SUCCEEDED(session->reader->GetPresentationAttribute(
            kMediaSource, MF_PD_DURATION, &var)) &&
        var.vt == VT_UI8) {
      // 100-nanosecond units.
      duration_ms = static_cast<int64_t>(var.uhVal.QuadPart / 10000);
    }
    ::PropVariantClear(&var);

    const int32_t handle = next_handle_++;
    EncodableMap reply;
    reply[EncodableValue("handle")] = EncodableValue(handle);
    reply[EncodableValue("sampleRate")] =
        EncodableValue(static_cast<int32_t>(session->rate));
    reply[EncodableValue("channels")] =
        EncodableValue(static_cast<int32_t>(session->channels));
    if (duration_ms > 0) {
      reply[EncodableValue("durationMs")] = EncodableValue(duration_ms);
    }
    if (!codec.empty()) {
      reply[EncodableValue("codec")] = EncodableValue(codec);
    }
    sessions_[handle] = std::move(session);
    result->Success(EncodableValue(reply));
    return;
  }

  if (method == "read") {
    const int32_t handle = IntArg(args, "handle", -1);
    const int32_t max_bytes =
        std::max(kMinChunk,
                 std::min(kMaxChunk, IntArg(args, "maxBytes", kDefaultChunk)));
    auto it = sessions_.find(handle);
    if (it == sessions_.end()) {
      Fail(result, "decode", "unknown handle");
      return;
    }
    Session& s = *it->second;

    std::vector<uint8_t> out;
    out.swap(s.carry);
    UINT32 out_rate = s.rate;
    UINT32 out_channels = s.channels;
    int empty_reads = 0;
    while (static_cast<int32_t>(out.size()) < max_bytes && !s.ended) {
      DWORD flags = 0;
      ComPtr<IMFSample> sample;
      HRESULT hr =
          s.reader->ReadSample(kAudioStream, 0, nullptr, &flags, nullptr,
                               &sample);
      if (FAILED(hr) || (flags & MF_SOURCE_READERF_ERROR) != 0) {
        Fail(result, "decode", "ReadSample " + HexResult(hr));
        return;
      }
      if ((flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) != 0) {
        if (!ReadCurrentFormat(s.reader.Get(), &s.rate, &s.channels,
                               &s.bits, &s.is_float)) {
          Fail(result, "decode", "unsupported format change");
          return;
        }
      }
      if ((flags & MF_SOURCE_READERF_ENDOFSTREAM) != 0) {
        s.ended = true;
      }
      const bool format_moved =
          s.rate != out_rate || s.channels != out_channels;
      if (format_moved && !out.empty()) {
        // Keep this chunk in the old format; the new one starts next read.
        if (sample) {
          AppendSample(sample.Get(), s.bits, s.is_float, &s.carry);
        }
        break;
      }
      if (format_moved) {
        out_rate = s.rate;
        out_channels = s.channels;
      }
      if (sample) {
        if (!AppendSample(sample.Get(), s.bits, s.is_float, &out)) {
          Fail(result, "decode", "unreadable sample buffer");
          return;
        }
        empty_reads = 0;
      } else if (!s.ended && ++empty_reads > kMaxEmptyReads) {
        Fail(result, "decode", "decoder stalled");
        return;
      }
    }
    if (out.empty() && s.ended && s.carry.empty()) {
      result->Success();
      return;
    }
    EncodableMap reply;
    reply[EncodableValue("data")] = EncodableValue(std::move(out));
    reply[EncodableValue("sampleRate")] =
        EncodableValue(static_cast<int32_t>(out_rate));
    reply[EncodableValue("channels")] =
        EncodableValue(static_cast<int32_t>(out_channels));
    result->Success(EncodableValue(reply));
    return;
  }

  if (method == "close") {
    sessions_.erase(IntArg(args, "handle", -1));
    result->Success();
    return;
  }

  result->NotImplemented();
}
