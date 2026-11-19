// Input-device helpers for F18 (external microphones) and the device tag of
// voiceprints. Pure Dart apart from the `record` value types.
//
// * A *device key* (`<type>|<label>`) identifies a microphone stably across
//   reconnects: Android assigns a new numeric id each time a USB / Bluetooth
//   device is attached, while its type and product name stay the same. The
//   key is what `Speaker.voiceDevice` and `Meeting.inputDevice` store; null
//   means the system default microphone.
// * [resolveInputDevice] finds the remembered device in the current list
//   (by id, then by key) and reports when it is gone.
// * [micCaptureOptions] and [farFieldVadConfig] implement the far-field
//   "meeting room" profile.
// * [knownSpeakerThresholdFor] / [voiceDeviceAfterLearning] implement the
//   relaxed matching when a voiceprint was learned on another microphone.

import 'dart:math' as math;

import '../../audio/audio_capture_service.dart'
    show AudioCaptureOptions, CapturePlatform;
import '../../core/models.dart' show Speaker;
import '../../speech/vad_segmenter.dart' show VadSegmenterConfig;

import 'package:record/record.dart'
    show AndroidAudioSource, InputDevice, InputDeviceType;

/// Separator between type and label in a device key.
const String kDeviceKeySeparator = '|';

/// Stable key of [device] (`<type>|<label>`); null for the system default.
String? voiceDeviceKey(InputDevice? device) {
  if (device == null) return null;
  final label = device.label.trim();
  if (label.isEmpty && device.id.trim().isEmpty) return null;
  return '${device.type.name}$kDeviceKeySeparator'
      '${label.isEmpty ? device.id.trim() : label}';
}

/// A parsed device key.
class VoiceDeviceKeyParts {
  /// Creates the parts.
  const VoiceDeviceKeyParts(this.type, this.label);

  /// Transport type.
  final InputDeviceType type;

  /// Product label.
  final String label;
}

/// Splits a key made by [voiceDeviceKey]. A key without a known type prefix
/// (e.g. written by an older build) is treated as a bare label of unknown
/// type. Returns null for null / blank keys.
VoiceDeviceKeyParts? parseVoiceDeviceKey(String? key) {
  final k = key?.trim();
  if (k == null || k.isEmpty) return null;
  final at = k.indexOf(kDeviceKeySeparator);
  if (at > 0) {
    final typeName = k.substring(0, at);
    final known = InputDeviceType.values.any((t) => t.name == typeName);
    if (known) {
      return VoiceDeviceKeyParts(
        InputDeviceType.fromString(typeName),
        k.substring(at + 1).trim(),
      );
    }
  }
  return VoiceDeviceKeyParts(InputDeviceType.unknown, k);
}

/// True for Bluetooth inputs.
bool isBluetoothInput(InputDeviceType type) =>
    type == InputDeviceType.bluetoothSco ||
    type == InputDeviceType.bluetoothA2dp ||
    type == InputDeviceType.bluetoothLe;

/// True for inputs that capture through a narrow-band call profile
/// (Bluetooth HFP / SCO: 8–16 kHz, heavy compression), which lowers
/// transcription accuracy and voiceprint quality.
bool isNarrowBandInput(InputDeviceType type) =>
    type == InputDeviceType.bluetoothSco || type == InputDeviceType.bluetoothLe;

/// True for external microphones (anything but the built-in one).
bool isExternalInput(InputDeviceType type) =>
    type != InputDeviceType.builtIn && type != InputDeviceType.unknown;

/// Outcome of [resolveInputDevice].
class InputDeviceResolution {
  /// Creates a resolution.
  const InputDeviceResolution({this.device, this.missing = false});

  /// The device to select (null = system default).
  final InputDevice? device;

  /// True when a remembered device was not found (the default is used).
  final bool missing;
}

/// Finds the remembered microphone in [devices]: by [storedId] first, then
/// by [storedKey] (same type and label, e.g. after an Android reconnect gave
/// it a new id). With nothing remembered the default is used; a remembered
/// device that is absent yields the default with [InputDeviceResolution.missing].
InputDeviceResolution resolveInputDevice(
  List<InputDevice> devices, {
  String? storedId,
  String? storedKey,
}) {
  final id = storedId?.trim();
  final key = storedKey?.trim();
  final hasId = id != null && id.isNotEmpty;
  final hasKey = key != null && key.isNotEmpty;
  if (!hasId && !hasKey) return const InputDeviceResolution();
  if (hasId) {
    for (final d in devices) {
      if (d.id == id) return InputDeviceResolution(device: d);
    }
  }
  if (hasKey) {
    for (final d in devices) {
      if (voiceDeviceKey(d) == key) return InputDeviceResolution(device: d);
    }
  }
  return const InputDeviceResolution(missing: true);
}

/// Whether [device] (by id or key) is present in [devices].
bool isDevicePresent(List<InputDevice> devices, InputDevice device) {
  final key = voiceDeviceKey(device);
  return devices.any((d) => d.id == device.id || voiceDeviceKey(d) == key);
}

/// Capture options for a session.
///
/// Far field ("اجتماع في قاعة") switches on automatic gain and noise
/// suppression where the platform applies them through `record` (Android:
/// `AutomaticGainControl` / `NoiseSuppressor`). iOS would need Apple's
/// voice-processing unit, which attenuates distant talkers, and Windows does
/// not apply the flags, so there the far-field profile only tunes the VAD
/// ([farFieldVadConfig]). A selected Bluetooth headset needs the Android
/// plugin to manage the SCO link, or the take silently stays on another mic.
AudioCaptureOptions micCaptureOptions({
  required bool farField,
  InputDevice? device,
  required CapturePlatform platform,
}) {
  final bluetooth = device != null && isNarrowBandInput(device.type);
  final android = platform == CapturePlatform.android;
  return AudioCaptureOptions(
    noiseSuppress: farField && android,
    autoGainOnAndroid: farField && android,
    androidAudioSource: AndroidAudioSource.voiceRecognition,
    androidManageBluetooth: bluetooth && android,
  );
}

/// Identity of the options [micCaptureOptions] builds, to tell whether a
/// capture service must be rebuilt (options are fixed per service).
String micCaptureOptionsKey(AudioCaptureOptions o) =>
    '${o.noiseSuppress}/${o.autoGainOnAndroid}/${o.androidManageBluetooth}/'
    '${o.androidAudioSource.name}';

/// VAD tuning for distant talkers: a lower speech-probability threshold,
/// slightly shorter minimum speech and a little more silence before a cut,
/// so quiet far-field speech still opens segments and is not chopped.
const VadSegmenterConfig farFieldVadConfig = VadSegmenterConfig(
  threshold: 0.35,
  minSpeechDuration: 0.2,
  minSilenceDuration: 0.6,
);

/// VAD configuration for the far-field setting.
VadSegmenterConfig vadConfigFor({required bool farField}) =>
    farField ? farFieldVadConfig : const VadSegmenterConfig();

// ===========================================================================
// Voiceprints and devices
// ===========================================================================

/// How much the voiceprint threshold is lowered when a voiceprint was learned
/// on another microphone than the meeting's.
const double kDeviceMismatchRelaxation = 0.05;

/// Lowest threshold a relaxation may reach.
const double kMinRelaxedThreshold = 0.4;

/// Whether [speaker]'s voiceprint was learned on another microphone than the
/// session's ([sessionDeviceKey]; null = default microphone, as is a null
/// `Speaker.voiceDevice`).
bool isVoiceDeviceMismatch(Speaker speaker, String? sessionDeviceKey) =>
    _norm(speaker.voiceDevice) != _norm(sessionDeviceKey);

String? _norm(String? key) {
  final k = key?.trim();
  return (k == null || k.isEmpty) ? null : k;
}

/// Similarity a segment needs to match [speaker]'s voiceprint in a session
/// recorded on [sessionDeviceKey]: [base], relaxed by [relaxation] (never
/// below [floor]) when the voiceprint was learned on another microphone,
/// because the same voice through different hardware scores lower.
double knownSpeakerThresholdFor(
  Speaker speaker, {
  required String? sessionDeviceKey,
  required double base,
  double relaxation = kDeviceMismatchRelaxation,
  double floor = kMinRelaxedThreshold,
}) {
  if (!isVoiceDeviceMismatch(speaker, sessionDeviceKey)) return base;
  return math.max(math.min(floor, base), base - relaxation);
}

/// The device tag of a voiceprint after [learnedCount] embeddings recorded
/// on [sessionDeviceKey] were added to a voiceprint of [previousCount]
/// embeddings tagged [currentDevice] (counts capped like the voiceprint,
/// at [cap]).
///
/// A voiceprint without evidence takes the session's device; otherwise the
/// tag moves once the new microphone contributes at least half of the
/// voiceprint, so it follows the device it has adapted to.
String? voiceDeviceAfterLearning({
  required String? currentDevice,
  required String? sessionDeviceKey,
  required int previousCount,
  required int learnedCount,
  int cap = 200,
}) {
  final current = _norm(currentDevice);
  final session = _norm(sessionDeviceKey);
  if (current == session) return current;
  if (learnedCount <= 0) return current;
  final prev = math.min(math.max(previousCount, 0), cap);
  if (prev == 0) return session;
  return learnedCount / (prev + learnedCount) >= 0.5 ? session : current;
}
