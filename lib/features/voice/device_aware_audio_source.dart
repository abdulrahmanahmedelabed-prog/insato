// Session audio source that honours the F18 microphone settings: the
// remembered input device, the far-field profile and a graceful fallback
// to the default microphone when the chosen one disappears mid-meeting.
//
// The platform plugins already keep the take alive when the device goes
// away (`AudioRouteChangeMode.follow` moves capture to the default input,
// see `buildRecordConfig`). This source adds what the user needs to know:
// it watches the device list while recording and, when the chosen
// microphone is gone, reports it once on [errors] (shown as a warning by the
// session controller) and on [deviceEvents], without stopping anything.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_capture_service.dart';
import '../../core/errors.dart';
import '../../data/secure_settings.dart';
import '../../session/meeting_session_controller.dart' show SessionAudioSource;
import 'mic_capture.dart';
import 'strings.dart';
import 'voice_devices.dart';

/// What happened to the session's microphone.
enum MicDeviceEventKind {
  /// Capture started on [MicDeviceEvent.deviceKey].
  started,

  /// The remembered device was not connected at start; the default is used.
  missingAtStart,

  /// The device was disconnected during the take; capture continues on the
  /// default microphone.
  fellBack,
}

/// A microphone change of the running session.
class MicDeviceEvent {
  /// Creates the event.
  const MicDeviceEvent(this.kind, {this.deviceKey, this.label});

  /// What happened.
  final MicDeviceEventKind kind;

  /// Device key now in use (null = system default).
  final String? deviceKey;

  /// Label of the device concerned (the lost one for [MicDeviceEventKind.fellBack]
  /// and [MicDeviceEventKind.missingAtStart]).
  final String? label;
}

/// [SessionAudioSource] with device selection, far field and fallback.
class DeviceAwareSessionAudioSource implements SessionAudioSource {
  /// Creates the source.
  DeviceAwareSessionAudioSource({
    required MicCaptureFactory captureFactory,
    required this._loadSettings,
    required this._loadRemembered,
    CapturePlatform? platform,
    this.pollInterval = const Duration(seconds: 3),
  }) : _factory = captureFactory,
       _platform = platform ?? CapturePlatform.current;

  final MicCaptureFactory _factory;
  final Future<AppSettingsData> Function() _loadSettings;
  final Future<RememberedInputDevice> Function() _loadRemembered;
  final CapturePlatform _platform;

  /// How often the device list is checked while recording.
  final Duration pollInterval;

  final _frames = StreamController<Float32List>.broadcast();
  final _level = StreamController<double>.broadcast();
  final _states = StreamController<AudioCaptureState>.broadcast();
  final _errors = StreamController<AudioCaptureException>.broadcast();
  final _events = StreamController<MicDeviceEvent>.broadcast();

  MicCapture? _capture;
  String? _optionsKey;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _poll;
  bool _polling = false;
  InputDevice? _requested;
  String? _activeKey;
  bool _fellBack = false;
  bool _farField = false;
  bool _disposed = false;

  /// Microphone changes of the running take.
  Stream<MicDeviceEvent> get deviceEvents => _events.stream;

  /// Key of the device capturing now (null = system default).
  String? get activeDeviceKey => _activeKey;

  /// Whether the running (or last) take uses the far-field profile.
  bool get farField => _farField;

  /// Whether the chosen microphone was lost during the running take.
  bool get fellBack => _fellBack;

  @override
  Stream<Float32List> get frames => _frames.stream;
  @override
  Stream<double> get level => _level.stream;
  @override
  Stream<AudioCaptureState> get states => _states.stream;
  @override
  Stream<AudioCaptureException> get errors => _errors.stream;
  @override
  Duration get elapsed => _capture?.elapsed ?? Duration.zero;

  MicCapture _ensureCapture(AudioCaptureOptions options) {
    final key = micCaptureOptionsKey(options);
    final existing = _capture;
    if (existing != null && key == _optionsKey) return existing;
    if (existing != null) {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      _subs.clear();
      unawaited(existing.dispose().catchError((Object _) {}));
    }
    final c = _factory(options);
    _capture = c;
    _optionsKey = key;
    _subs
      ..add(c.frames.listen(_frames.add))
      ..add(c.level.listen(_level.add))
      ..add(c.states.listen(_onState))
      ..add(c.errors.listen(_errors.add));
    return c;
  }

  MicCapture get _anyCapture =>
      _capture ??
      _ensureCapture(micCaptureOptions(farField: false, platform: _platform));

  /// The device the next take will use, resolved from the settings and the
  /// connected devices (the device-key result goes to
  /// `MeetingSessionController.start(inputDevice:)`).
  Future<InputDeviceResolution> resolveConfiguredDevice() async =>
      _resolve(await _loadRemembered());

  Future<InputDeviceResolution> _resolve(
    RememberedInputDevice remembered,
  ) async {
    if (remembered.isDefault) return const InputDeviceResolution();
    List<InputDevice> devices;
    try {
      devices = await _anyCapture.listInputDevices();
    } catch (_) {
      // Listing failed: try the remembered id; the platform falls back to
      // the default input if it is not there.
      return InputDeviceResolution(
        device: InputDevice(
          id: remembered.id!,
          label: remembered.label ?? remembered.id!,
          type:
              parseVoiceDeviceKey(remembered.key)?.type ??
              InputDeviceType.unknown,
        ),
      );
    }
    return resolveRemembered(devices, remembered);
  }

  @override
  Future<bool> hasPermission({bool request = true}) =>
      _anyCapture.hasPermission(request: request);

  @override
  Future<void> start({String? archivePath}) async {
    if (_disposed) throw StateError('DeviceAwareSessionAudioSource disposed');
    final settings = await _loadSettings();
    final remembered = await _loadRemembered();
    final resolution = await _resolve(remembered);
    _farField = settings.farFieldMode;
    final options = micCaptureOptions(
      farField: settings.farFieldMode,
      device: resolution.device,
      platform: _platform,
    );
    final capture = _ensureCapture(options);
    capture.selectDevice(resolution.device);
    _fellBack = false;
    _requested = resolution.device;
    await capture.start(archivePath: archivePath);
    _activeKey = voiceDeviceKey(resolution.device);
    if (resolution.missing) {
      final label = remembered.label ?? VoiceStrings.defaultDevice;
      _errors.add(AudioCaptureException(VoiceStrings.micMissingAtStart(label)));
      _events.add(
        MicDeviceEvent(MicDeviceEventKind.missingAtStart, label: label),
      );
    } else {
      _events.add(
        MicDeviceEvent(
          MicDeviceEventKind.started,
          deviceKey: _activeKey,
          label: resolution.device?.label,
        ),
      );
    }
    _startPolling();
  }

  @override
  Future<void> pause() => _anyCapture.pause();

  @override
  Future<void> resume() => _anyCapture.resume();

  @override
  Future<Duration> stop() async {
    _stopPolling();
    final c = _capture;
    if (c == null) return Duration.zero;
    return c.stop();
  }

  /// Stops any take and releases the recorder and streams.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopPolling();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final c = _capture;
    _capture = null;
    if (c != null) await c.dispose().catchError((Object _) {});
    await _frames.close();
    await _level.close();
    await _states.close();
    await _errors.close();
    await _events.close();
  }

  void _onState(AudioCaptureState s) {
    if (s == AudioCaptureState.idle) _stopPolling();
    _states.add(s);
  }

  void _startPolling() {
    _stopPolling();
    if (_requested == null) return;
    _poll = Timer.periodic(pollInterval, (_) => unawaited(checkDevice()));
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// Checks once whether the chosen microphone is still connected (called
  /// periodically while recording). Reports a loss once per take.
  Future<void> checkDevice() async {
    final requested = _requested;
    final c = _capture;
    if (requested == null || c == null || _fellBack || _polling) return;
    _polling = true;
    try {
      final List<InputDevice> devices;
      try {
        devices = await c.listInputDevices();
      } catch (_) {
        return; // Transient; check again next time.
      }
      if (_disposed || _fellBack || !identical(_requested, requested)) return;
      if (isDevicePresent(devices, requested)) return;
      _fellBack = true;
      _activeKey = null;
      _stopPolling();
      final label = requested.label.isEmpty ? requested.id : requested.label;
      _errors.add(AudioCaptureException(VoiceStrings.micDisconnected(label)));
      _events.add(MicDeviceEvent(MicDeviceEventKind.fellBack, label: label));
    } finally {
      _polling = false;
    }
  }
}

/// The device-aware session source. The integrator points
/// `sessionAudioSourceProvider` at it (see the feature's notes).
final deviceAwareAudioSourceProvider = Provider<DeviceAwareSessionAudioSource>((
  ref,
) {
  final settings = ref.watch(appSettingsProvider);
  final prefs = ref.watch(inputDevicePreferencesProvider);
  final source = DeviceAwareSessionAudioSource(
    captureFactory: ref.watch(micCaptureFactoryProvider),
    loadSettings: settings.load,
    loadRemembered: prefs.load,
    platform: ref.watch(capturePlatformProvider),
  );
  ref.onDispose(source.dispose);
  return source;
});
