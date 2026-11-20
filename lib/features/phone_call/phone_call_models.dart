// Phone-call mode (وضع المكالمة الهاتفية): shared value types.
//
// A regular cellular call (no internet on the remote side) is transcribed
// live while a remote group gathers around one phone on speaker:
//
// * [PhoneCallMode.phoneLink] – Windows only: the call is taken on the PC
//   through Microsoft Phone Link (Bluetooth). The remote side is captured
//   from system audio (WASAPI loopback) and the local side from the
//   microphone, as two separate channels.
// * [PhoneCallMode.speakerphone] – any platform: the call runs on speaker
//   on one phone and Insato records it with this device's microphone.
//
// Pure Dart (no Flutter imports).

import '../../core/models.dart' show MinutesCallHint;

/// How the call reaches Insato.
enum PhoneCallMode {
  /// Windows + Microsoft Phone Link: remote = loopback, local = microphone.
  phoneLink,

  /// A phone on speaker next to this device (microphone only).
  speakerphone;

  /// Stored form (`phone_link` / `speakerphone`), also the minutes hint mode.
  String get storageName => switch (this) {
    PhoneCallMode.phoneLink => MinutesCallHint.modePhoneLink,
    PhoneCallMode.speakerphone => MinutesCallHint.modeSpeakerphone,
  };

  /// Parses [storageName]; null for anything else.
  static PhoneCallMode? fromStorage(Object? v) => switch (v) {
    MinutesCallHint.modePhoneLink => PhoneCallMode.phoneLink,
    MinutesCallHint.modeSpeakerphone => PhoneCallMode.speakerphone,
    _ => null,
  };
}

/// Side of the call a speech segment belongs to.
enum CallSide {
  /// People next to this device (heard by the microphone).
  local,

  /// The remote group on the telephone line («الطرف البعيد»).
  remote;

  /// Diarization partition of this side ([ChannelProfile.partition]).
  String get partition => name;

  /// The side of a [partition] value; null for anything else.
  static CallSide? ofPartition(String? partition) => switch (partition) {
    'local' => CallSide.local,
    'remote' => CallSide.remote,
    _ => null,
  };
}

/// Channel id of the microphone in phone-call [ChannelProfile]s.
const String kCallChannelLocal = 'local';

/// Channel id of the telephone line (loopback) in [ChannelProfile]s.
const String kCallChannelRemote = 'remote';

/// Voice-device tag of the telephone channel (`Speaker.voiceDevice`): a
/// voiceprint learned from remote-side speech is tagged with it, distinct
/// from every microphone key, so wideband ↔ telephone mismatches are known
/// (like the F18 microphone tags).
const String kTelephoneVoiceDeviceKey = 'telephone|call';

/// True when [deviceKey] is the telephone channel tag.
bool isTelephoneVoiceDevice(String? deviceKey) =>
    deviceKey?.trim() == kTelephoneVoiceDeviceKey;
