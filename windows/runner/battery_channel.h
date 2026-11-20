#ifndef RUNNER_BATTERY_CHANNEL_H_
#define RUNNER_BATTERY_CHANNEL_H_

// v1.2 C: MethodChannel "insato/battery", method "read" ->
// {level: int 0..100 (absent when unknown), charging: bool (absent when
// unknown)}, from GetSystemPowerStatus. Desktops without a battery report
// nothing. See lib/features/multi_device/battery.dart.

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

class BatteryChannel {
 public:
  explicit BatteryChannel(flutter::BinaryMessenger* messenger);

  BatteryChannel(const BatteryChannel&) = delete;
  BatteryChannel& operator=(const BatteryChannel&) = delete;

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_BATTERY_CHANNEL_H_
