// Session audio for F13: microphone, system audio (Windows WASAPI loopback)
// or both mixed, as chosen in Settings (`AppSettingsData.audioSource`).
//
// * mic    – everything is delegated to the microphone source (the F18
//            device-aware source in production), archive included.
// * both   – the microphone is the clock: every microphone frame takes the
//            same number of system samples from the [SystemAudioBuffer]
//            (zeros while nothing plays) and the two are summed through a
//            soft limiter. The mixed signal is archived here.
// * system – no microphone; a timer emits system audio paced by wall clock
//            ([WallClockSilenceFiller]), zeros for silent gaps.
//
// On Android / iOS (and anything but Windows) the setting is ignored and the
// microphone is recorded, as the spec requires.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_capture_service.dart';
import '../../audio/wav_writer.dart';
import '../../core/errors.dart';
import '../../core/models.dart' show kSampleRate;
import '../../data/secure_settings.dart';
import '../../session/meeting_session_controller.dart' show SessionAudioSource;
import '../voice/device_aware_audio_source.dart'
    show deviceAwareAudioSourceProvider;
import '../voice/mic_capture.dart' show capturePlatformProvider;
import 'strings.dart';
import 'system_audio_dsp.dart';
import 'system_audio_source.dart';

/// What a take records.
enum SessionAudioMode {
  /// Microphone only.
  mic,

  /// System audio only.
  system,

  /// Microphone and system audio mixed.
  both,
}

/// The mode for the stored [setting] on [platform]: system audio exists only
/// on Windows; unknown values fall back to the default ([SessionAudioMode.both]
/// on Windows).
SessionAudioMode resolveSessionAudioMode(
  String? setting,
  CapturePlatform platform,
) {
  if (platform != CapturePlatform.windows) return SessionAudioMode.mic;
  return switch (setting) {
    AppSettingsData.audioSourceMic => SessionAudioMode.mic,
    AppSettingsData.audioSourceSystem => SessionAudioMode.system,
    _ => SessionAudioMode.both,
  };
}

/// Opens the archive WAV of a mixed take.
typedef MixedArchiveOpener = Future<WavWriter> Function(String path);

/// [SessionAudioSource] honouring the audio-source setting (F13).
class MixedSessionAudioSource implements SessionAudioSource {
  /// Creates the source. [clock] is a monotonic time source (default: a
  /// [Stopwatch]); [tick] is how often system-only audio is emitted.
  MixedSessionAudioSource({
    required this._mic,
    required this._system,
    required this._loadAudioSource,
    CapturePlatform? platform,
    Duration Function()? clock,
    this.tick = const Duration(milliseconds: 100),
    MixedArchiveOpener? openArchive,
  }) : _platform = platform ?? CapturePlatform.current,
       _clock = clock ?? _stopwatchClock(),
       _openArchive = openArchive ?? _defaultOpenArchive;

  static Duration Function() _stopwatchClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  static Future<WavWriter> _defaultOpenArchive(String path) =>
      WavWriter.open(path, sampleRate: kSampleRate, channels: 1);

  final SessionAudioSource _mic;
  final SystemAudioSource _system;
  final Future<String?> Function() _loadAudioSource;
  final CapturePlatform _platform;
  final Duration Function() _clock;
  final MixedArchiveOpener _openArchive;

  /// Pacing interval of system-only takes.
  final Duration tick;

  final _frames = StreamController<Float32List>.broadcast();
  final _level = StreamController<double>.broadcast();
  final _states = StreamController<AudioCaptureState>.broadcast();
  final _errors = StreamController<AudioCaptureException>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  final LevelMeter _meter = LevelMeter();

  SessionAudioMode _mode = SessionAudioMode.mic;
  WallClockSilenceFiller? _filler;
  Timer? _timer;
  WavWriter? _wav;
  bool _wavFailed = false;
  bool _systemActive = false;
  bool _active = false;
  bool _disposed = false;
  int _samples = 0;

  /// Mode of the running (or last) take.
  SessionAudioMode get mode => _mode;

  /// The system-audio source.
  SystemAudioSource get system => _system;

  @override
  Stream<Float32List> get frames => _frames.stream;
  @override
  Stream<double> get level => _level.stream;
  @override
  Stream<AudioCaptureState> get states => _states.stream;
  @override
  Stream<AudioCaptureException> get errors => _errors.stream;

  @override
  Duration get elapsed => _mode == SessionAudioMode.mic
      ? _mic.elapsed
      : Duration(
          microseconds:
              _samples * Duration.microsecondsPerSecond ~/ kSampleRate,
        );

  Future<SessionAudioMode> _resolveMode() async {
    if (_platform != CapturePlatform.windows) return SessionAudioMode.mic;
    String? setting;
    try {
      setting = await _loadAudioSource();
    } catch (_) {
      setting = null;
    }
    return resolveSessionAudioMode(setting, _platform);
  }

  void _listen() {
    if (_subs.isNotEmpty) return;
    _subs
      ..add(_mic.frames.listen(_onMicFrames))
      ..add(_mic.level.listen(_onMicLevel))
      ..add(_mic.states.listen(_onMicState))
      ..add(_mic.errors.listen(_addError))
      ..add(_system.warnings.listen(_onSystemWarning));
  }

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (await _resolveMode() == SessionAudioMode.system) return true;
    return _mic.hasPermission(request: request);
  }

  @override
  Future<void> start({String? archivePath}) async {
    if (_disposed) throw StateError('MixedSessionAudioSource disposed');
    _listen();
    _mode = await _resolveMode();
    _samples = 0;
    _meter.reset();
    _wavFailed = false;
    _active = true;
    switch (_mode) {
      case SessionAudioMode.mic:
        await _mic.start(archivePath: archivePath);
      case SessionAudioMode.both:
        await _openWav(archivePath);
        try {
          await _mic.start();
        } catch (_) {
          _active = false;
          await _closeWav();
          rethrow;
        }
        try {
          await _system.start();
          _systemActive = true;
        } on AudioCaptureException catch (e) {
          _systemActive = false;
          _addError(
            AudioCaptureException(
              SystemAudioStrings.startFailedMicOnly,
              debugDetails: e.debugDetails,
              cause: e,
            ),
          );
        }
      case SessionAudioMode.system:
        _setState(AudioCaptureState.starting);
        await _openWav(archivePath);
        try {
          await _system.start();
        } catch (_) {
          _active = false;
          await _closeWav();
          _setState(AudioCaptureState.idle);
          rethrow;
        }
        _systemActive = true;
        _filler = WallClockSilenceFiller(clock: _clock)..start();
        _startTimer();
        _setState(AudioCaptureState.recording);
    }
  }

  @override
  Future<void> pause() async {
    switch (_mode) {
      case SessionAudioMode.mic:
        return _mic.pause();
      case SessionAudioMode.both:
        await _mic.pause();
        await _pauseSystem();
      case SessionAudioMode.system:
        if (_filler == null || _filler!.isPaused) return;
        pumpSystemAudio();
        _stopTimer();
        _filler!.pause();
        await _pauseSystem();
        _setState(AudioCaptureState.paused);
        _emitLevel(0);
    }
  }

  @override
  Future<void> resume() async {
    switch (_mode) {
      case SessionAudioMode.mic:
        return _mic.resume();
      case SessionAudioMode.both:
        await _resumeSystem();
        await _mic.resume();
      case SessionAudioMode.system:
        final filler = _filler;
        if (filler == null || !filler.isPaused) return;
        await _resumeSystem();
        filler.resume();
        _startTimer();
        _setState(AudioCaptureState.recording);
    }
  }

  @override
  Future<Duration> stop() async {
    switch (_mode) {
      case SessionAudioMode.mic:
        _active = false;
        return _mic.stop();
      case SessionAudioMode.both:
        if (!_active) return elapsed;
        try {
          await _mic.stop();
          // Let the microphone's last frames reach the mixer.
          await Future<void>.delayed(Duration.zero);
        } finally {
          _active = false;
          await _stopSystem();
          await _closeWav();
        }
        return elapsed;
      case SessionAudioMode.system:
        final filler = _filler;
        if (filler == null) return elapsed;
        _setState(AudioCaptureState.stopping);
        _stopTimer();
        await _stopSystem();
        if (!filler.isPaused) _emit(filler.drain(_system.buffer, flush: true));
        filler.stop();
        _filler = null;
        _active = false;
        await _closeWav();
        _emitLevel(0);
        _setState(AudioCaptureState.idle);
        return elapsed;
    }
  }

  /// Stops any take and releases the streams (the microphone source is
  /// owned by its own provider and is not disposed here).
  Future<void> dispose() async {
    if (_disposed) return;
    if (_active) {
      try {
        await stop();
      } catch (_) {
        // Best effort on teardown.
      }
    }
    _disposed = true;
    _stopTimer();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _frames.close();
    await _level.close();
    await _states.close();
    await _errors.close();
  }

  /// Emits the system audio due by wall clock (system-only takes; called by
  /// the pacing timer, public for tests).
  void pumpSystemAudio() {
    final filler = _filler;
    if (filler == null || filler.isPaused || _mode != SessionAudioMode.system) {
      return;
    }
    _emit(filler.drain(_system.buffer));
  }

  // -------------------------------------------------------------------------

  void _onMicFrames(Float32List frame) {
    switch (_mode) {
      case SessionAudioMode.mic:
        _frames.add(frame);
      case SessionAudioMode.both:
        if (!_active) return;
        final sys = _systemActive
            ? _system.buffer.take(frame.length)
            : Float32List(0);
        _emit(mixSoftLimited(frame, sys));
      case SessionAudioMode.system:
        break; // The microphone is not used.
    }
  }

  void _onMicLevel(double v) {
    if (_mode == SessionAudioMode.mic) _emitLevel(v);
  }

  void _onMicState(AudioCaptureState s) {
    if (_mode == SessionAudioMode.system) return;
    _setState(s);
    if (_mode == SessionAudioMode.both && s != AudioCaptureState.recording) {
      _meter.reset();
      _emitLevel(0);
    }
  }

  void _onSystemWarning(AudioCaptureException e) {
    if (_mode != SessionAudioMode.mic && _active) _addError(e);
  }

  void _emit(Float32List samples) {
    if (samples.isEmpty) return;
    _samples += samples.length;
    final wav = _wav;
    if (wav != null && !_wavFailed) {
      wav.appendFloat32(samples).catchError((Object e) {
        if (_wavFailed) return;
        _wavFailed = true;
        _addError(
          AudioCaptureException(
            SystemAudioStrings.archiveWriteFailed,
            debugDetails: '$e',
            cause: e,
          ),
        );
      });
    }
    if (!_frames.isClosed) _frames.add(samples);
    for (final v in _meter.add(samples)) {
      _emitLevel(v);
    }
  }

  Future<void> _openWav(String? path) async {
    _wav = null;
    if (path == null) return;
    try {
      _wav = await _openArchive(path);
    } catch (e) {
      throw AudioCaptureException(
        SystemAudioStrings.archiveFailed,
        debugDetails: '$e',
        cause: e,
      );
    }
  }

  Future<void> _closeWav() async {
    final wav = _wav;
    _wav = null;
    if (wav == null) return;
    try {
      await wav.close();
    } catch (e) {
      if (!_wavFailed) {
        _wavFailed = true;
        _addError(
          AudioCaptureException(
            SystemAudioStrings.archiveWriteFailed,
            debugDetails: '$e',
            cause: e,
          ),
        );
      }
    }
  }

  Future<void> _pauseSystem() async {
    if (!_systemActive) return;
    await _system.stop();
    _system.buffer.clear();
    final wav = _wav;
    if (wav != null && !_wavFailed) {
      unawaited(wav.flush().catchError((Object _) {}));
    }
  }

  Future<void> _resumeSystem() async {
    if (!_systemActive) return;
    try {
      await _system.start();
    } on AudioCaptureException catch (e) {
      if (_mode == SessionAudioMode.system) {
        // Keep the time line going with silence; the warning explains why.
        _addError(e);
      } else {
        _systemActive = false;
        _addError(
          AudioCaptureException(
            SystemAudioStrings.startFailedMicOnly,
            debugDetails: e.debugDetails,
            cause: e,
          ),
        );
      }
    }
  }

  Future<void> _stopSystem() async {
    if (!_systemActive) return;
    _systemActive = false;
    await _system.stop();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(tick, (_) => pumpSystemAudio());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _setState(AudioCaptureState s) {
    if (!_states.isClosed) _states.add(s);
  }

  void _emitLevel(double v) {
    if (!_level.isClosed) _level.add(v);
  }

  void _addError(AudioCaptureException e) {
    if (!_errors.isClosed) _errors.add(e);
  }
}

// ===========================================================================
// Providers
// ===========================================================================

/// The native system-audio channels. Overridden in tests.
final systemAudioPlatformProvider = Provider<SystemAudioPlatform>(
  (ref) => MethodChannelSystemAudioPlatform(),
);

/// The system-audio source (Windows).
final systemAudioSourceProvider = Provider<SystemAudioSource>((ref) {
  final source = SystemAudioSource(
    platform: ref.watch(systemAudioPlatformProvider),
  );
  ref.onDispose(source.dispose);
  return source;
});

/// Whether system audio can be recorded on this device (false off Windows).
final systemAudioSupportedProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(capturePlatformProvider) != CapturePlatform.windows) {
    return false;
  }
  return ref.watch(systemAudioSourceProvider).isSupported();
});

/// The session audio source of F13: on Windows a [MixedSessionAudioSource]
/// over the F18 device-aware microphone; elsewhere the microphone source
/// itself. The integrator points `sessionAudioSourceProvider` at it.
final mixedSessionAudioSourceProvider = Provider<SessionAudioSource>((ref) {
  final mic = ref.watch(deviceAwareAudioSourceProvider);
  final platform = ref.watch(capturePlatformProvider);
  if (platform != CapturePlatform.windows) return mic;
  final settings = ref.watch(appSettingsProvider);
  final source = MixedSessionAudioSource(
    mic: mic,
    system: ref.watch(systemAudioSourceProvider),
    loadAudioSource: () async => (await settings.load()).audioSource,
    platform: platform,
  );
  ref.onDispose(source.dispose);
  return source;
});
