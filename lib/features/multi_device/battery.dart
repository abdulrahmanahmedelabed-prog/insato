// Battery level of a guest device (v1.2 C), read through the app's own
// method channel `insato/battery` (Android BatteryManager, iOS UIDevice,
// Windows GetSystemPowerStatus; see MainActivity.kt, AppDelegate.swift and
// windows/runner/battery_channel.cpp). battery_plus cannot be used: its
// Linux dependency conflicts with wakelock_plus. Unknown on any failure.

import 'package:flutter/services.dart';

/// A battery reading.
class BatteryReading {
  /// Creates a reading.
  const BatteryReading({this.level, this.charging});

  /// Percentage 0–100 (null = unknown).
  final int? level;

  /// Charging (null = unknown).
  final bool? charging;
}

/// Reads the battery; never throws.
class BatteryReader {
  /// Creates a reader on [channel].
  const BatteryReader({this.channel = const MethodChannel('insato/battery')});

  /// The platform channel.
  final MethodChannel channel;

  /// The current reading (both fields null when unavailable).
  Future<BatteryReading> read() async {
    try {
      final r = await channel.invokeMapMethod<String, Object?>('read');
      final level = r?['level'];
      final charging = r?['charging'];
      return BatteryReading(
        level: level is int && level >= 0 && level <= 100 ? level : null,
        charging: charging is bool ? charging : null,
      );
    } on PlatformException {
      return const BatteryReading();
    } on MissingPluginException {
      return const BatteryReading();
    }
  }
}
