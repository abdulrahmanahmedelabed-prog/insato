// Microphone capture seam of the voice features, plus the remembered input
// device (F18).
//
// [MicCapture] is the surface of [AudioCaptureService] the enrollment
// recorder, the microphone test and the device-aware session source use;
// tests replace it through [micCaptureFactoryProvider], so no plugin is
// touched.

import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_capture_service.dart';
import '../../core/errors.dart';
import '../../data/database.dart';
import '../../data/repositories.dart' show databaseProvider;
import '../../data/secure_settings.dart';
import '../../session/meeting_session_controller.dart' show SessionAudioSource;
import 'voice_devices.dart';

/// Microphone capture: [SessionAudioSource] plus device selection.
abstract class MicCapture implements SessionAudioSource {
  /// Lists the available inputs. Throws [AudioCaptureException].
  Future<List<InputDevice>> listInputDevices();

  /// Selects the input for the next [start] (null = system default).
  void selectDevice(InputDevice? device);

  /// The input selected for the next [start].
  InputDevice? get selectedDevice;

  /// Stops any take and releases the recorder.
  Future<void> dispose();
}

/// [MicCapture] over an [AudioCaptureService].
class AudioCaptureMic implements MicCapture {
  /// Wraps [service] (owned: [dispose] disposes it).
  AudioCaptureMic(this.service);

  /// The wrapped service.
  final AudioCaptureService service;

  @override
  Stream<Float32List> get frames => service.frames;
  @override
  Stream<double> get level => service.level;
  @override
  Stream<AudioCaptureState> get states => service.states;
  @override
  Stream<AudioCaptureException> get errors => service.errors;
  @override
  Duration get elapsed => service.elapsed;
  @override
  Future<bool> hasPermission({bool request = true}) =>
      service.hasPermission(request: request);
  @override
  Future<void> start({String? archivePath}) =>
      service.start(archivePath: archivePath);
  @override
  Future<void> pause() => service.pause();
  @override
  Future<void> resume() => service.resume();
  @override
  Future<Duration> stop() => service.stop();
  @override
  Future<List<InputDevice>> listInputDevices() => service.listInputDevices();
  @override
  void selectDevice(InputDevice? device) => service.selectDevice(device);
  @override
  InputDevice? get selectedDevice => service.selectedDevice;
  @override
  Future<void> dispose() => service.dispose();
}

/// Builds a [MicCapture] with the given options.
typedef MicCaptureFactory = MicCapture Function(AudioCaptureOptions options);

/// Creates microphone captures (a fresh recorder each time). Overridden in
/// tests.
final micCaptureFactoryProvider = Provider<MicCaptureFactory>(
  (ref) =>
      (options) => AudioCaptureMic(AudioCaptureService(options: options)),
);

/// The platform the capture options are built for. Overridden in tests.
final capturePlatformProvider = Provider<CapturePlatform>(
  (ref) => CapturePlatform.current,
);

// ===========================================================================
// Remembered device
// ===========================================================================

/// The remembered microphone: the platform id (`AppSettingsData.inputDeviceId`)
/// plus its stable key, so it is found again after an Android reconnect
/// gives it a new id.
class RememberedInputDevice {
  /// Creates the value.
  const RememberedInputDevice({this.id, this.key});

  /// Nothing remembered: the system default.
  static const RememberedInputDevice systemDefault = RememberedInputDevice();

  /// Platform id (null = default).
  final String? id;

  /// Stable key ([voiceDeviceKey]); null = default or unknown.
  final String? key;

  /// True when the system default is remembered.
  bool get isDefault =>
      (id == null || id!.isEmpty) && (key == null || key!.isEmpty);

  /// Display label of the remembered device (null for the default).
  String? get label {
    final parts = parseVoiceDeviceKey(key);
    if (parts != null && parts.label.isNotEmpty) return parts.label;
    return isDefault ? null : id;
  }
}

/// Reads and writes the remembered microphone.
///
/// The id is the shared setting `AppSettings.setInputDeviceId`; the key is
/// kept in the settings table under [keySetting].
class InputDevicePreferences {
  /// Creates the store.
  InputDevicePreferences({required this.settings, required this.db});

  /// Shared app settings.
  final AppSettings settings;

  /// Database holding the settings table.
  final AppDatabase db;

  /// Settings-table key of the remembered device key.
  static const String keySetting = 'voice.input_device_key';

  /// The remembered device. A key without an id (the id was cleared by
  /// another screen) is ignored.
  Future<RememberedInputDevice> load() async {
    final data = await settings.load();
    final id = data.inputDeviceId?.trim();
    if (id == null || id.isEmpty) return RememberedInputDevice.systemDefault;
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(keySetting))).getSingleOrNull();
    final key = row?.value.trim();
    return RememberedInputDevice(
      id: id,
      key: (key == null || key.isEmpty) ? null : key,
    );
  }

  /// Remembers [device] (null = system default). Throws
  /// [InsatoException] when the settings cannot be written.
  Future<void> remember(InputDevice? device) async {
    try {
      await db.transaction(() async {
        await settings.setInputDeviceId(device?.id);
        final key = voiceDeviceKey(device);
        if (device == null || key == null) {
          await (db.delete(
            db.settings,
          )..where((s) => s.key.equals(keySetting))).go();
        } else {
          await db
              .into(db.settings)
              .insertOnConflictUpdate(
                SettingsCompanion(
                  key: const Value(keySetting),
                  value: Value(key),
                ),
              );
        }
      });
    } catch (e) {
      throw InsatoException(
        'تعذّر حفظ اختيار الميكروفون.',
        debugDetails: '$e',
        cause: e,
      );
    }
  }
}

/// The remembered-device store.
final inputDevicePreferencesProvider = Provider<InputDevicePreferences>(
  (ref) => InputDevicePreferences(
    settings: ref.watch(appSettingsProvider),
    db: ref.watch(databaseProvider),
  ),
);

/// Lists the inputs with a short-lived recorder, closing it afterwards.
/// Throws [AudioCaptureException].
Future<List<InputDevice>> listInputDevicesWith(
  MicCaptureFactory factory,
) async {
  final mic = factory(const AudioCaptureOptions());
  try {
    return await mic.listInputDevices();
  } finally {
    await mic.dispose().catchError((Object _) {});
  }
}

/// The available microphones (refresh with `ref.invalidate`).
final inputDevicesProvider = FutureProvider.autoDispose<List<InputDevice>>(
  (ref) => listInputDevicesWith(ref.watch(micCaptureFactoryProvider)),
);

/// The remembered microphone (refresh with `ref.invalidate`).
final rememberedInputDeviceProvider =
    FutureProvider.autoDispose<RememberedInputDevice>(
      (ref) => ref.watch(inputDevicePreferencesProvider).load(),
    );

/// Resolves the remembered device against [devices].
InputDeviceResolution resolveRemembered(
  List<InputDevice> devices,
  RememberedInputDevice remembered,
) => resolveInputDevice(
  devices,
  storedId: remembered.id,
  storedKey: remembered.key,
);
