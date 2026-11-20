#include "system_audio_channel.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <string>
#include <utility>
#include <vector>

namespace {

constexpr char kMethodChannelName[] = "insato/system_audio/control";
constexpr char kEventChannelName[] = "insato/system_audio";

// Upper bound of undelivered events (~5 s of 20 ms packets). If the
// platform thread stalls longer, the oldest events are dropped instead of
// growing memory without limit.
constexpr size_t kMaxQueuedEvents = 256;

using flutter::EncodableMap;
using flutter::EncodableValue;

EncodableValue StatusEvent(const std::string& type, const std::string& code) {
  EncodableMap map;
  map[EncodableValue("type")] = EncodableValue(type);
  if (!code.empty()) {
    map[EncodableValue("code")] = EncodableValue(code);
  }
  return EncodableValue(std::move(map));
}

EncodableValue AudioEvent(SystemAudioCapture::Packet&& packet) {
  EncodableMap map;
  map[EncodableValue("type")] = EncodableValue("audio");
  map[EncodableValue("rate")] =
      EncodableValue(static_cast<int32_t>(packet.sample_rate));
  map[EncodableValue("channels")] =
      EncodableValue(static_cast<int32_t>(packet.channels));
  map[EncodableValue("samples")] = EncodableValue(std::move(packet.samples));
  return EncodableValue(std::move(map));
}

}  // namespace

SystemAudioChannel::SystemAudioChannel(flutter::BinaryMessenger* messenger,
                                       HWND window)
    : window_(window) {
  const auto* codec = &flutter::StandardMethodCodec::GetInstance();
  methods_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName, codec);
  events_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, kEventChannelName, codec);

  capture_ = std::make_unique<SystemAudioCapture>(
      [this](SystemAudioCapture::Packet&& packet) {
        Enqueue(AudioEvent(std::move(packet)));
      },
      [this](const std::string& type, const std::string& code) {
        Enqueue(StatusEvent(type, code));
      });

  methods_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });

  events_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [this](const EncodableValue*,
                 std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            sink_ = std::move(events);
            return nullptr;
          },
          [this](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            // Nobody listens any more: never keep capturing in the
            // background.
            StopCapture();
            sink_ = nullptr;
            return nullptr;
          }));
}

SystemAudioChannel::~SystemAudioChannel() {
  // Join the capture thread first so no callback runs during teardown.
  StopCapture();
  methods_->SetMethodCallHandler(nullptr);
  events_->SetStreamHandler(nullptr);
  sink_ = nullptr;
}

void SystemAudioChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "isSupported") {
    result->Success(EncodableValue(SystemAudioCapture::IsSupported()));
  } else if (method == "start") {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      queue_.clear();
    }
    result->Success(EncodableValue(capture_->Start()));
  } else if (method == "stop") {
    // Join the capture thread (it flushes its last batch), then hand every
    // queued packet to Dart before the reply: the Dart side still listens
    // until the reply arrives, so the end of the take is not lost.
    capture_->Stop();
    DeliverPendingEvents();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

// Stops capture and drops what was not delivered (stream cancelled or
// teardown: nobody listens any more).
void SystemAudioChannel::StopCapture() {
  capture_->Stop();
  std::lock_guard<std::mutex> lock(mutex_);
  queue_.clear();
}

void SystemAudioChannel::Enqueue(EncodableValue event) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    queue_.push_back(std::move(event));
    while (queue_.size() > kMaxQueuedEvents) {
      queue_.pop_front();
    }
  }
  if (!post_pending_.exchange(true)) {
    if (!::PostMessage(window_, kSystemAudioMessage, 0, 0)) {
      post_pending_.store(false);
    }
  }
}

void SystemAudioChannel::DeliverPendingEvents() {
  // Clear the flag before taking the queue: an event queued after this
  // point posts a new message, so nothing is left behind.
  post_pending_.store(false);
  std::deque<EncodableValue> pending;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    pending.swap(queue_);
  }
  if (!sink_) {
    return;
  }
  for (const EncodableValue& event : pending) {
    sink_->Success(event);
  }
}
