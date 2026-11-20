#ifndef RUNNER_AUDIO_DECODER_CHANNEL_H_
#define RUNNER_AUDIO_DECODER_CHANNEL_H_

// Recording import: MethodChannel "insato/audio_decoder" backed by Media
// Foundation (IMFSourceReader with MFAudioFormat_PCM output). Decodes the
// formats Windows ships decoders for (m4a / AAC, mp3, wav incl. compressed
// WAV, wma, flac, and others when the codec is installed) into interleaved
// 16-bit PCM at the file's own rate and channel count. Protocol (see
// lib/features/import_audio/audio_decoder.dart):
//
//   isSupported -> bool
//   open {path} -> {handle, sampleRate, channels, durationMs?, codec?}
//   read {handle, maxBytes} -> {data: Uint8List, sampleRate, channels}
//                              | null at the end of the stream
//   close {handle} -> null
//   errors: "unsupported", "not_found", "io", "decode"
//
// Calls run on the platform thread (COM is initialised there as an STA by
// main.cpp); each read decodes at most about maxBytes, a few milliseconds
// of work, so the UI stays responsive. Dart pulls chunk by chunk.

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

struct IMFSourceReader;

class AudioDecoderChannel {
 public:
  explicit AudioDecoderChannel(flutter::BinaryMessenger* messenger);
  ~AudioDecoderChannel();

  AudioDecoderChannel(const AudioDecoderChannel&) = delete;
  AudioDecoderChannel& operator=(const AudioDecoderChannel&) = delete;

 private:
  struct Session;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::map<int32_t, std::unique_ptr<Session>> sessions_;
  int32_t next_handle_ = 1;
  bool mf_started_ = false;
};

#endif  // RUNNER_AUDIO_DECODER_CHANNEL_H_
