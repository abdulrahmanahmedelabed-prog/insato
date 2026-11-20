#include "bot_audio_channel.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <string>
#include <utility>
#include <variant>
#include <vector>

namespace {

constexpr char kMethodChannelName[] = "insato/meeting_bot_audio/control";
constexpr char kEventChannelName[] = "insato/meeting_bot_audio";

// Upper bound of undelivered events (~5 s of 20 ms packets).
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

// The "pid" argument of start (Dart ints arrive as int32 or int64); 0 when
// missing or out of range.
DWORD PidArgument(const EncodableValue* arguments) {
  if (arguments == nullptr) {
    return 0;
  }
  const auto* map = std::get_if<EncodableMap>(arguments);
  if (map == nullptr) {
    return 0;
  }
  const auto it = map->find(EncodableValue("pid"));
  if (it == map->end()) {
    return 0;
  }
  if (const auto* v32 = std::get_if<int32_t>(&it->second)) {
    return *v32 > 0 ? static_cast<DWORD>(*v32) : 0;
  }
  if (const auto* v64 = std::get_if<int64_t>(&it->second)) {
    return (*v64 > 0 && *v64 <= 0xFFFFFFFFLL) ? static_cast<DWORD>(*v64) : 0;
  }
  return 0;
}

}  // namespace

BotAudioChannel::BotAudioChannel(flutter::BinaryMessenger* messenger,
                                 HWND window)
    : window_(window) {
  const auto* codec = &flutter::StandardMethodCodec::GetInstance();
  methods_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName, codec);
  events_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, kEventChannelName, codec);

  capture_ = std::make_unique<BotAudioCapture>(
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
            // Nobody listens any more: never keep capturing.
            StopCapture();
            sink_ = nullptr;
            return nullptr;
          }));
}

BotAudioChannel::~BotAudioChannel() {
  // Join the capture thread first so no callback runs during teardown.
  StopCapture();
  methods_->SetMethodCallHandler(nullptr);
  events_->SetStreamHandler(nullptr);
  sink_ = nullptr;
}

void BotAudioChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "isSupported") {
    result->Success(EncodableValue(BotAudioCapture::IsSupported()));
  } else if (method == "start") {
    const DWORD pid = PidArgument(call.arguments());
    {
      std::lock_guard<std::mutex> lock(mutex_);
      queue_.clear();
    }
    // Waits briefly for the stream to be activated, so a refusal is
    // reported as false (the Dart side then falls back to system audio).
    const bool ok = pid != 0 && capture_->Start(pid);
    result->Success(EncodableValue(ok));
  } else if (method == "stop") {
    // Join the capture thread (it flushes its last batch), then hand every
    // queued packet to Dart before the reply.
    capture_->Stop();
    DeliverPendingEvents();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

// Stops capture and drops what was not delivered (stream cancelled or
// teardown: nobody listens any more).
void BotAudioChannel::StopCapture() {
  capture_->Stop();
  std::lock_guard<std::mutex> lock(mutex_);
  queue_.clear();
}

void BotAudioChannel::Enqueue(EncodableValue event) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    queue_.push_back(std::move(event));
    while (queue_.size() > kMaxQueuedEvents) {
      queue_.pop_front();
    }
  }
  if (!post_pending_.exchange(true)) {
    if (!::PostMessage(window_, kBotAudioMessage, 0, 0)) {
      post_pending_.store(false);
    }
  }
}

void BotAudioChannel::DeliverPendingEvents() {
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
