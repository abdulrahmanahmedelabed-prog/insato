#include "battery_channel.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

BatteryChannel::BatteryChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "insato/battery",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "read") {
          result->NotImplemented();
          return;
        }
        flutter::EncodableMap reply;
        SYSTEM_POWER_STATUS status;
        if (GetSystemPowerStatus(&status)) {
          // 128 = no system battery, 255 = unknown.
          const bool has_battery = (status.BatteryFlag & 128) == 0 &&
                                   status.BatteryFlag != 255;
          if (has_battery && status.BatteryLifePercent <= 100) {
            reply[flutter::EncodableValue("level")] =
                flutter::EncodableValue(
                    static_cast<int>(status.BatteryLifePercent));
          }
          if (has_battery && status.ACLineStatus != 255) {
            reply[flutter::EncodableValue("charging")] =
                flutter::EncodableValue(status.ACLineStatus == 1);
          }
        }
        result->Success(flutter::EncodableValue(reply));
      });
}
