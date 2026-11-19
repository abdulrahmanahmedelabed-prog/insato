#ifndef RUNNER_SYSTEM_AUDIO_CHANNEL_H_
#define RUNNER_SYSTEM_AUDIO_CHANNEL_H_

// F13: Flutter channels of the system-audio (WASAPI loopback) capture.
//
// * MethodChannel "insato/system_audio/control": isSupported -> bool,
//   start -> bool, stop -> null.
// * EventChannel "insato/system_audio": maps with a "type" key:
//   {type: "audio", rate: int, channels: int, samples: Float32List}
//   (interleaved float32), {type: "started"}, {type: "restarted"} (default
//   output device changed; capture moved to it), {type: "error", code: str}.
//
// The capture thread never touches Flutter objects: it queues events and
// posts kSystemAudioMessage to the top-level window; FlutterWindow forwards
// that message to DeliverPendingEvents() on the platform thread.

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>
#include <windows.h>

#include <atomic>
#include <deque>
#include <memory>
#include <mutex>

#include "system_audio_capture.h"

// Window message that asks the platform thread to deliver queued events.
constexpr UINT kSystemAudioMessage = WM_APP + 0x51;

class SystemAudioChannel {
 public:
  SystemAudioChannel(flutter::BinaryMessenger* messenger, HWND window);
  ~SystemAudioChannel();

  SystemAudioChannel(const SystemAudioChannel&) = delete;
  SystemAudioChannel& operator=(const SystemAudioChannel&) = delete;

  // Sends the queued events to Dart. Platform thread only.
  void DeliverPendingEvents();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Any thread.
  void Enqueue(flutter::EncodableValue event);

  void StopCapture();

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methods_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> events_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::unique_ptr<SystemAudioCapture> capture_;

  std::mutex mutex_;
  std::deque<flutter::EncodableValue> queue_;
  std::atomic<bool> post_pending_{false};
};

#endif  // RUNNER_SYSTEM_AUDIO_CHANNEL_H_
