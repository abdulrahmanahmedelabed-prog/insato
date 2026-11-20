// "اختبار المايك" (F18): live level with clipping / too-quiet hints, a 5 s
// test recording with a quality summary, and playback of that recording.
// Works before any model is downloaded (speech is found by energy).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../audio/audio_capture_service.dart'
    show AudioCaptureState, InputDevice;
import '../../core/errors.dart';
import '../../data/secure_settings.dart';
import '../../ui/strings_ar.dart';
import 'audio_quality.dart';
import 'enrollment_controller.dart' show meetingRecordingActiveProvider;
import 'mic_capture.dart';
import 'strings.dart';
import 'voice_devices.dart';

/// Length of the test recording.
const int kMicTestDurationMs = 5000;

// ===========================================================================
// Playback seam
// ===========================================================================

/// Plays the test recording.
abstract class TestPlayback {
  /// Plays the WAV file at [path] from the start.
  Future<void> play(String path);

  /// Stops playback.
  Future<void> stop();

  /// Fires when playback reaches the end.
  Stream<void> get onComplete;

  /// Releases the player.
  Future<void> dispose();
}

/// [TestPlayback] with `audioplayers`.
class AudioplayersTestPlayback implements TestPlayback {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path, mimeType: 'audio/wav'));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;

  @override
  Future<void> dispose() => _player.dispose();
}

/// Creates the test player. Overridden in tests.
final testPlaybackFactoryProvider = Provider<TestPlayback Function()>(
  (ref) => AudioplayersTestPlayback.new,
);

/// Directory for the temporary test recording. Overridden in tests.
final micTestDirProvider = Provider<Future<String> Function()>(
  (ref) =>
      () async => (await getTemporaryDirectory()).path,
);

// ===========================================================================
// Controller
// ===========================================================================

/// Phase of the microphone test.
enum MicTestPhase {
  /// Nothing running.
  idle,

  /// Opening the microphone.
  starting,

  /// Showing the live level.
  monitoring,

  /// Recording the 5 s test.
  recordingTest,

  /// Test recorded; result shown, playback available.
  recorded,

  /// Playing the test back.
  playing,

  /// Failed ([MicTestState.errorAr]).
  error,
}

/// What the microphone-test screen shows.
class MicTestState {
  /// Creates a state.
  const MicTestState({
    this.phase = MicTestPhase.idle,
    this.level = 0,
    this.hint = LiveSignalHint.waiting,
    this.remainingMs = 0,
    this.result,
    this.device,
    this.errorAr,
    this.warningAr,
    this.hasRecording = false,
  });

  /// Phase.
  final MicTestPhase phase;

  /// Meter level 0..1.
  final double level;

  /// Live hint.
  final LiveSignalHint hint;

  /// Time left in the test recording.
  final int remainingMs;

  /// Quality of the last test recording.
  final AudioQualityReport? result;

  /// Microphone in use (null = default).
  final InputDevice? device;

  /// Blocking error.
  final String? errorAr;

  /// Non-blocking warning.
  final String? warningAr;

  /// A test recording exists and can be played.
  bool get canPlay =>
      hasRecording &&
      (phase == MicTestPhase.recorded ||
          phase == MicTestPhase.monitoring ||
          phase == MicTestPhase.idle);

  /// Whether a test recording file exists.
  final bool hasRecording;

  /// Whether the microphone is open.
  bool get micOpen =>
      phase == MicTestPhase.monitoring || phase == MicTestPhase.recordingTest;

  /// Copy with changes.
  MicTestState copyWith({
    MicTestPhase? phase,
    double? level,
    LiveSignalHint? hint,
    int? remainingMs,
    AudioQualityReport? result,
    InputDevice? device,
    bool clearDevice = false,
    String? errorAr,
    bool clearError = false,
    String? warningAr,
    bool clearWarning = false,
    bool? hasRecording,
  }) {
    return MicTestState(
      phase: phase ?? this.phase,
      level: level ?? this.level,
      hint: hint ?? this.hint,
      remainingMs: remainingMs ?? this.remainingMs,
      result: result ?? this.result,
      device: clearDevice ? null : (device ?? this.device),
      errorAr: clearError ? null : (errorAr ?? this.errorAr),
      warningAr: clearWarning ? null : (warningAr ?? this.warningAr),
      hasRecording: hasRecording ?? this.hasRecording,
    );
  }
}

/// Drives the microphone-test screen.
class MicTestController extends Notifier<MicTestState> {
  MicCapture? _mic;
  final List<StreamSubscription<Object?>> _subs = [];
  final LiveLevelMonitor _monitor = LiveLevelMonitor();
  Timer? _ticker;
  final List<Float32List> _take = [];
  bool _closing = false;
  int _takeSamples = 0;
  String? _testPath;
  TestPlayback? _player;
  StreamSubscription<void>? _playerDone;
  bool _transition = false;

  @override
  MicTestState build() {
    ref.onDispose(() => unawaited(_disposeAll()));
    return const MicTestState();
  }

  void _set(MicTestState s) {
    if (ref.mounted) state = s;
  }

  /// Opens the microphone and shows the live level.
  Future<void> startMonitor() async {
    if (state.micOpen || _transition) return;
    await _stopPlayback();
    await _open(archivePath: null, phase: MicTestPhase.monitoring);
  }

  /// Closes the microphone.
  Future<void> stopMonitor() async {
    if (state.phase != MicTestPhase.monitoring || _transition) return;
    _transition = true;
    try {
      await _close();
      if (!ref.mounted) return;
      _set(
        state.copyWith(
          phase: state.hasRecording ? MicTestPhase.recorded : MicTestPhase.idle,
          level: 0,
        ),
      );
    } finally {
      _transition = false;
    }
  }

  /// Records the 5 s test (re-opening the microphone with a WAV archive).
  Future<void> recordTest() async {
    if (state.phase == MicTestPhase.recordingTest || _transition) return;
    await _stopPlayback();
    _transition = true;
    try {
      await _close();
    } finally {
      _transition = false;
    }
    String path;
    try {
      final dir = await ref.read(micTestDirProvider)();
      await Directory(dir).create(recursive: true);
      path = p.join(dir, 'insato_mic_test.wav');
      final old = File(path);
      if (await old.exists()) await old.delete();
    } catch (e) {
      _fail(VoiceStrings.testFileFailed);
      return;
    }
    if (!ref.mounted) return;
    _testPath = path;
    _take.clear();
    _takeSamples = 0;
    _set(state.copyWith(hasRecording: false));
    await _open(archivePath: path, phase: MicTestPhase.recordingTest);
  }

  /// Plays the last test recording.
  Future<void> play() async {
    final path = _testPath;
    if (path == null || !state.hasRecording || state.micOpen) return;
    try {
      final player = _player ??= ref.read(testPlaybackFactoryProvider)();
      await _playerDone?.cancel();
      _playerDone = player.onComplete.listen((_) {
        if (state.phase == MicTestPhase.playing) {
          _set(state.copyWith(phase: MicTestPhase.recorded));
        }
      });
      _set(state.copyWith(phase: MicTestPhase.playing, clearError: true));
      await player.play(path);
    } catch (e) {
      _set(
        state.copyWith(
          phase: MicTestPhase.recorded,
          warningAr: VoiceStrings.playbackFailed,
        ),
      );
    }
  }

  /// Stops playback.
  Future<void> stopPlayback() => _stopPlayback();

  Future<void> _stopPlayback() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {
      // Already stopped.
    }
    if (state.phase == MicTestPhase.playing) {
      _set(state.copyWith(phase: MicTestPhase.recorded));
    }
  }

  Future<void> _open({
    required String? archivePath,
    required MicTestPhase phase,
  }) async {
    if (ref.read(meetingRecordingActiveProvider)) {
      _fail(VoiceStrings.busyRecording);
      return;
    }
    _transition = true;
    _set(
      state.copyWith(
        phase: MicTestPhase.starting,
        clearError: true,
        clearWarning: true,
        level: 0,
        hint: LiveSignalHint.waiting,
      ),
    );
    _monitor.reset();
    try {
      final settings = await ref.read(appSettingsProvider).load();
      final remembered = await ref.read(inputDevicePreferencesProvider).load();
      final factory = ref.read(micCaptureFactoryProvider);
      var resolution = const InputDeviceResolution();
      if (!remembered.isDefault) {
        try {
          resolution = resolveRemembered(
            await listInputDevicesWith(factory),
            remembered,
          );
        } catch (_) {
          resolution = const InputDeviceResolution();
        }
      }
      final mic = factory(
        micCaptureOptions(
          farField: settings.farFieldMode,
          device: resolution.device,
          platform: ref.read(capturePlatformProvider),
        ),
      );
      _mic = mic;
      if (!await mic.hasPermission()) {
        throw const AudioCaptureException(
          'يحتاج إنصاتو إلى إذن الميكروفون لاختباره. اسمح به من إعدادات '
          'الجهاز ثم أعد المحاولة.',
        );
      }
      mic.selectDevice(resolution.device);
      _subs
        ..add(mic.frames.listen(_onFrames))
        ..add(
          mic.level.listen((l) {
            if (ref.mounted) _set(state.copyWith(level: l));
          }),
        )
        ..add(
          mic.errors.listen((e) {
            if (ref.mounted) _set(state.copyWith(warningAr: e.messageAr));
          }),
        )
        ..add(mic.states.listen(_onCaptureState));
      await mic.start(archivePath: archivePath);
      if (!ref.mounted) {
        await _close();
        return;
      }
      _set(
        state.copyWith(
          phase: phase,
          device: resolution.device,
          clearDevice: resolution.device == null,
          remainingMs: phase == MicTestPhase.recordingTest
              ? kMicTestDurationMs
              : 0,
          warningAr: resolution.missing && remembered.label != null
              ? VoiceStrings.rememberedMissing(remembered.label!)
              : null,
        ),
      );
      _ticker = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _onTick(),
      );
    } catch (e) {
      await _close();
      _fail(e is InsatoException ? e.messageAr : S.unexpectedError);
    } finally {
      _transition = false;
    }
  }

  /// The platform can end or pause the capture on its own (an error, a
  /// phone call, a route change).
  void _onCaptureState(AudioCaptureState s) {
    if (!ref.mounted || _transition || _closing) return;
    final phase = state.phase;
    if (phase != MicTestPhase.monitoring &&
        phase != MicTestPhase.recordingTest) {
      return;
    }
    switch (s) {
      case AudioCaptureState.idle || AudioCaptureState.stopping:
        if (phase == MicTestPhase.recordingTest) {
          // Judge what was recorded so far.
          unawaited(_finishTest());
        } else {
          unawaited(
            _close().then((_) => _fail(VoiceStrings.captureEnded)),
          );
        }
      case AudioCaptureState.paused:
        _set(state.copyWith(warningAr: VoiceStrings.capturePaused));
      case AudioCaptureState.recording:
        if (state.warningAr == VoiceStrings.capturePaused) {
          _set(state.copyWith(clearWarning: true));
        }
      case AudioCaptureState.starting:
        break;
    }
  }

  void _onFrames(Float32List frame) {
    if (!ref.mounted) return;
    _monitor.add(frame);
    if (state.phase == MicTestPhase.recordingTest) {
      _take.add(frame);
      _takeSamples += frame.length;
    }
  }

  void _onTick() {
    if (!ref.mounted) return;
    final phase = state.phase;
    if (phase != MicTestPhase.monitoring &&
        phase != MicTestPhase.recordingTest) {
      return;
    }
    final hint = _monitor.hint;
    if (phase == MicTestPhase.recordingTest) {
      final remaining = kMicTestDurationMs - samplesToMillis(_takeSamples);
      _set(state.copyWith(hint: hint, remainingMs: remaining.clamp(0, 99999)));
      if (remaining <= 0) unawaited(_finishTest());
    } else if (hint != state.hint) {
      _set(state.copyWith(hint: hint));
    }
  }

  Future<void> _finishTest() async {
    if (state.phase != MicTestPhase.recordingTest || _transition) return;
    _transition = true;
    try {
      await _close();
      if (!ref.mounted) return;
      final audio = Float32List(_takeSamples);
      var at = 0;
      for (final c in _take) {
        audio.setAll(at, c);
        at += c.length;
      }
      _take.clear();
      final report = analyzeAudioQuality(
        audio,
        energySpeechSpans(audio),
        config: AudioQualityConfig.micTest,
      );
      final path = _testPath;
      final exists = path != null && await File(path).exists();
      if (!ref.mounted) return;
      _set(
        state.copyWith(
          phase: MicTestPhase.recorded,
          result: report,
          remainingMs: 0,
          level: 0,
          hasRecording: exists,
          warningAr: exists ? null : VoiceStrings.testFileFailed,
          clearWarning: exists,
        ),
      );
    } finally {
      _transition = false;
    }
  }

  void _fail(String messageAr) {
    _set(
      state.copyWith(phase: MicTestPhase.error, errorAr: messageAr, level: 0),
    );
  }

  Future<void> _close() async {
    _closing = true;
    _ticker?.cancel();
    _ticker = null;
    final mic = _mic;
    _mic = null;
    final subs = [..._subs];
    _subs.clear();
    try {
      if (mic != null) {
        try {
          await mic.stop();
        } catch (_) {
          // Disposed below.
        }
      }
      for (final s in subs) {
        await s.cancel();
      }
    } finally {
      _closing = false;
    }
    if (mic != null) await mic.dispose().catchError((Object _) {});
  }

  Future<void> _disposeAll() async {
    await _close();
    await _playerDone?.cancel();
    _playerDone = null;
    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {
        // Released below.
      }
      await player.dispose().catchError((Object _) {});
    }
    final path = _testPath;
    _testPath = null;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // A stale temp file is harmless and replaced by the next test.
      }
    }
  }
}

/// The microphone test (one per open screen).
final micTestControllerProvider =
    NotifierProvider.autoDispose<MicTestController, MicTestState>(
      MicTestController.new,
    );

/// Whether a device is a Bluetooth call-profile microphone (UI warning).
bool showsBluetoothWarning(InputDevice? device) =>
    device != null && isBluetoothInput(device.type);
