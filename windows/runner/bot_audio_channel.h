#ifndef RUNNER_BOT_AUDIO_CHANNEL_H_
#define RUNNER_BOT_AUDIO_CHANNEL_H_

// Meeting bot: Flutter channels of the process-loopback capture.
//
// * MethodChannel "insato/meeting_bot_audio/control": isSupported -> bool,
//   start({pid: int}) -> bool (true once the stream is activated),
//   stop -> null.
// * EventChannel "insato/meeting_bot_audio": the same maps as
//   "insato/system_audio": {type: "audio", rate, channels, samples
//   (Float32List)}, {type: "started"}, {type: "error", code}.
//
// Like SystemAudioChannel, the capture thread never touches Flutter
// objects: it queues events and posts kBotAudioMessage to the top-level
// window; FlutterWindow forwards it to DeliverPendingEvents().

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

#include "bot_audio_capture.h"

// Window message that asks the platform thread to deliver queued events.
constexpr UINT kBotAudioMessage = WM_APP + 0x52;

class BotAudioChannel {
 public:
  BotAudioChannel(flutter::BinaryMessenger* messenger, HWND window);
  ~BotAudioChannel();

  BotAudioChannel(const BotAudioChannel&) = delete;
  BotAudioChannel& operator=(const BotAudioChannel&) = delete;

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
  std::unique_ptr<BotAudioCapture> capture_;

  std::mutex mutex_;
  std::deque<flutter::EncodableValue> queue_;
  std::atomic<bool> post_pending_{false};
};

#endif  // RUNNER_BOT_AUDIO_CHANNEL_H_
