// State machine of the voice-enrollment screen (F1):
//
//   idle → starting → recording → analyzing → review → saving → saved
//                         ↘ error (any step) ↙
//
// Recording uses the remembered microphone and the far-field setting, like
// meetings, so the voiceprint matches meeting conditions and is tagged with
// that device. The take auto-stops at 15 s once enough speech was heard
// (else it runs on to 20 s); the user may stop earlier.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_capture_service.dart'
    show AudioCaptureState, InputDevice;
import '../../core/errors.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../data/secure_settings.dart';
import '../../session/providers.dart' show meetingSessionControllerProvider;
import '../../ui/strings_ar.dart';
import 'audio_quality.dart';
import 'enrollment_engine.dart';
import 'enrollment_texts.dart';
import 'mic_capture.dart';
import 'strings.dart';
import 'voice_devices.dart';
import 'voiceprint_builder.dart';

/// Target length of an enrollment take.
const int kEnrollmentTargetMs = 15000;

/// Hard limit of an enrollment take.
const int kEnrollmentMaxMs = 20000;

/// Speech (live estimate) after which the take may end at the target.
const int kEnrollmentLiveVoicedMs = 8500;

/// Phase of the enrollment flow.
enum EnrollmentPhase {
  /// Ready to record.
  idle,

  /// Opening the microphone.
  starting,

  /// Recording the take.
  recording,

  /// Running VAD and the speaker model.
  analyzing,

  /// Showing the checks; save or record again.
  review,

  /// Writing the voiceprint.
  saving,

  /// Done.
  saved,

  /// Something failed ([EnrollmentState.errorAr]).
  error,
}

/// What the enrollment screen shows.
class EnrollmentState {
  /// Creates a state.
  const EnrollmentState({
    this.phase = EnrollmentPhase.idle,
    this.elapsedMs = 0,
    this.voicedEstimateMs = 0,
    this.level = 0,
    this.hint = LiveSignalHint.waiting,
    this.analysis,
    this.similar,
    this.nameConflict,
    this.errorAr,
    this.modelsMissing = false,
    this.warningAr,
    this.device,
    this.saved,
    this.language = EnrollmentLanguage.arabic,
    this.passageIndex = 0,
  });

  /// Phase.
  final EnrollmentPhase phase;

  /// Recorded time.
  final int elapsedMs;

  /// Live estimate of the speech recorded.
  final int voicedEstimateMs;

  /// Meter level 0..1.
  final double level;

  /// Live hint.
  final LiveSignalHint hint;

  /// Analysis of the take (review and later).
  final EnrollmentAnalysis? analysis;

  /// Existing voiceprint that resembles the take (new person only).
  final SimilarVoice? similar;

  /// Named speaker that already carries the entered name.
  final Speaker? nameConflict;

  /// Blocking error.
  final String? errorAr;

  /// The error is about missing models (offer the models page).
  final bool modelsMissing;

  /// Non-blocking capture warning.
  final String? warningAr;

  /// Microphone of the take (null = default).
  final InputDevice? device;

  /// The saved speaker.
  final Speaker? saved;

  /// Language of the reading passage.
  final EnrollmentLanguage language;

  /// Passage number.
  final int passageIndex;

  /// The passage to read.
  String get passage => enrollmentPassage(language, passageIndex);

  /// Whether the microphone is open.
  bool get isRecording => phase == EnrollmentPhase.recording;

  /// Whether a background step runs.
  bool get isBusy =>
      phase == EnrollmentPhase.starting ||
      phase == EnrollmentPhase.analyzing ||
      phase == EnrollmentPhase.saving;

  /// Copy with changes. Nullable fields are cleared with their `clear*` flag.
  EnrollmentState copyWith({
    EnrollmentPhase? phase,
    int? elapsedMs,
    int? voicedEstimateMs,
    double? level,
    LiveSignalHint? hint,
    EnrollmentAnalysis? analysis,
    bool clearAnalysis = false,
    SimilarVoice? similar,
    bool clearSimilar = false,
    Speaker? nameConflict,
    bool clearNameConflict = false,
    String? errorAr,
    bool clearError = false,
    bool? modelsMissing,
    String? warningAr,
    bool clearWarning = false,
    InputDevice? device,
    bool clearDevice = false,
    Speaker? saved,
    EnrollmentLanguage? language,
    int? passageIndex,
  }) {
    return EnrollmentState(
      phase: phase ?? this.phase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      voicedEstimateMs: voicedEstimateMs ?? this.voicedEstimateMs,
      level: level ?? this.level,
      hint: hint ?? this.hint,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      similar: clearSimilar ? null : (similar ?? this.similar),
      nameConflict: clearNameConflict
          ? null
          : (nameConflict ?? this.nameConflict),
      errorAr: clearError ? null : (errorAr ?? this.errorAr),
      modelsMissing: modelsMissing ?? this.modelsMissing,
      warningAr: clearWarning ? null : (warningAr ?? this.warningAr),
      device: clearDevice ? null : (device ?? this.device),
      saved: saved ?? this.saved,
      language: language ?? this.language,
      passageIndex: passageIndex ?? this.passageIndex,
    );
  }
}

/// Whether a meeting is being recorded (the microphone is taken).
final meetingRecordingActiveProvider = Provider<bool>(
  (ref) => ref.watch(meetingSessionControllerProvider).isActive,
);

/// Drives the enrollment screen. Auto-disposed with the screen; the
/// microphone and engines are always released.
class VoiceEnrollmentController extends Notifier<EnrollmentState> {
  MicCapture? _mic;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _ticker;
  final List<Float32List> _chunks = [];
  int _samples = 0;
  final LiveLevelMonitor _monitor = LiveLevelMonitor();
  bool _farField = false;
  bool _stopping = false;

  @override
  EnrollmentState build() {
    ref.onDispose(() => unawaited(_release()));
    return const EnrollmentState();
  }

  void _set(EnrollmentState s) {
    if (ref.mounted) state = s;
  }

  /// Chooses the passage language.
  void setLanguage(EnrollmentLanguage language) {
    if (state.isRecording || state.isBusy) return;
    _set(state.copyWith(language: language, passageIndex: 0));
  }

  /// Shows another passage (e.g. for "improve voice").
  void nextPassage() {
    if (state.isRecording || state.isBusy) return;
    _set(state.copyWith(passageIndex: state.passageIndex + 1));
  }

  /// Opens the microphone and starts the take.
  Future<void> start() async {
    if (state.isRecording || state.isBusy) return;
    if (ref.read(meetingRecordingActiveProvider)) {
      _fail(VoiceStrings.busyRecording);
      return;
    }
    _set(
      state.copyWith(
        phase: EnrollmentPhase.starting,
        clearError: true,
        clearWarning: true,
        clearAnalysis: true,
        clearSimilar: true,
        clearNameConflict: true,
        modelsMissing: false,
        elapsedMs: 0,
        voicedEstimateMs: 0,
        level: 0,
        hint: LiveSignalHint.waiting,
      ),
    );
    _chunks.clear();
    _samples = 0;
    _monitor.reset();
    _stopping = false;
    try {
      final settings = await ref.read(appSettingsProvider).load();
      final remembered = await ref.read(inputDevicePreferencesProvider).load();
      final factory = ref.read(micCaptureFactoryProvider);
      final platform = ref.read(capturePlatformProvider);
      _farField = settings.farFieldMode;

      InputDeviceResolution resolution = const InputDeviceResolution();
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
      // The screen may have closed while the settings / devices loaded: no
      // microphone is opened then.
      if (!ref.mounted) return;
      final mic = factory(
        micCaptureOptions(
          farField: _farField,
          device: resolution.device,
          platform: platform,
        ),
      );
      _mic = mic;
      if (!await mic.hasPermission()) {
        throw const AudioCaptureException(
          'يحتاج إنصاتو إلى إذن الميكروفون لتسجيل البصمة الصوتية. اسمح به من '
          'إعدادات الجهاز ثم أعد المحاولة.',
        );
      }
      if (!ref.mounted) {
        // Disposed meanwhile (onDispose ran before _mic was set or while it
        // was awaited): release here, nothing else will.
        await _release();
        return;
      }
      mic.selectDevice(resolution.device);
      _subs
        ..add(mic.frames.listen(_onFrames))
        ..add(
          mic.level.listen((l) {
            if (ref.mounted && state.isRecording) {
              _set(state.copyWith(level: l));
            }
          }),
        )
        ..add(
          mic.errors.listen((e) {
            if (ref.mounted) _set(state.copyWith(warningAr: e.messageAr));
          }),
        )
        ..add(mic.states.listen(_onCaptureState));
      await mic.start();
      if (!ref.mounted) {
        // The screen closed while the microphone was starting: stop and
        // release it, or it would keep capturing with no owner.
        try {
          await mic.stop();
        } catch (_) {
          // Released below.
        }
        await _release();
        return;
      }
      _set(
        state.copyWith(
          phase: EnrollmentPhase.recording,
          device: resolution.device,
          clearDevice: resolution.device == null,
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
      await _release();
      _fail(e is InsatoException ? e.messageAr : VoiceStrings.analysisFailed);
    }
  }

  /// The platform can end or pause the take on its own (an error, a phone
  /// call, a route change): frames stop, so the auto-stop would never fire.
  void _onCaptureState(AudioCaptureState s) {
    if (!ref.mounted || !state.isRecording || _stopping) return;
    switch (s) {
      case AudioCaptureState.idle || AudioCaptureState.stopping:
        // Ended by the platform: analyse what was captured.
        unawaited(stop());
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
    if (!ref.mounted || !state.isRecording || _stopping) return;
    _chunks.add(frame);
    _samples += frame.length;
    _monitor.add(frame);
  }

  void _onTick() {
    if (!ref.mounted || !state.isRecording) return;
    final elapsed = samplesToMillis(_samples);
    _set(
      state.copyWith(
        elapsedMs: elapsed,
        voicedEstimateMs: _monitor.voicedMs,
        hint: _monitor.hint,
      ),
    );
    final enoughSpeech = _monitor.voicedMs >= kEnrollmentLiveVoicedMs;
    if ((elapsed >= kEnrollmentTargetMs && enoughSpeech) ||
        elapsed >= kEnrollmentMaxMs) {
      unawaited(stop());
    }
  }

  /// Ends the take and analyses it.
  Future<void> stop() async {
    if (!state.isRecording || _stopping) return;
    _stopping = true;
    _ticker?.cancel();
    _ticker = null;
    final mic = _mic;
    try {
      await mic?.stop();
    } catch (_) {
      // The frames received so far are analysed anyway.
    }
    await _release();
    final audio = _joined();
    if (!ref.mounted) return;
    _set(
      state.copyWith(
        phase: EnrollmentPhase.analyzing,
        elapsedMs: samplesToMillis(audio.length),
        level: 0,
      ),
    );
    EnrollmentAnalyzer? analyzer;
    try {
      analyzer = await ref.read(enrollmentAnalyzerFactoryProvider)(
        farField: _farField,
      );
      final analysis = await analyzeEnrollmentTake(audio, analyzer);
      if (!ref.mounted) return;
      _set(state.copyWith(phase: EnrollmentPhase.review, analysis: analysis));
    } on EnrollmentModelsMissingException catch (e) {
      _fail(e.messageAr, modelsMissing: true);
    } catch (e) {
      _fail(e is InsatoException ? e.messageAr : VoiceStrings.analysisFailed);
    } finally {
      _stopping = false;
      if (analyzer != null) {
        await analyzer.dispose().catchError((Object _) {});
      }
    }
  }

  /// Discards the take and returns to [EnrollmentPhase.idle].
  Future<void> reset() async {
    _ticker?.cancel();
    _ticker = null;
    final mic = _mic;
    if (mic != null) {
      try {
        await mic.stop();
      } catch (_) {
        // Released below.
      }
    }
    await _release();
    _chunks.clear();
    _samples = 0;
    _monitor.reset();
    _set(
      EnrollmentState(
        language: state.language,
        passageIndex: state.passageIndex + 1,
      ),
    );
  }

  /// Saves the take as a new person named [name], or (with [speakerId]) adds
  /// it to that speaker's voiceprint, naming it [name] when given.
  ///
  /// For a new person, unless [force] is set, the save stops first when a
  /// named speaker already carries [name] ([EnrollmentState.nameConflict])
  /// or the voice resembles a stored voiceprint ([EnrollmentState.similar]);
  /// the screen then lets the user choose. Returns the saved speaker, or
  /// null when nothing was saved.
  Future<Speaker?> save({
    String? name,
    String? speakerId,
    bool force = false,
  }) async {
    final analysis = state.analysis;
    final sample = analysis?.voiceprint;
    if (state.phase != EnrollmentPhase.review ||
        analysis == null ||
        sample == null ||
        !analysis.canSave) {
      return null;
    }
    final trimmed = name?.trim();
    if (speakerId == null && (trimmed == null || trimmed.isEmpty)) {
      _set(state.copyWith(errorAr: VoiceStrings.nameRequired));
      return null;
    }
    final speakers = ref.read(speakerRepositoryProvider);
    final writer = ref.read(voiceEnrollmentWriterProvider);
    final deviceKey = voiceDeviceKey(state.device);
    _set(state.copyWith(phase: EnrollmentPhase.saving, clearError: true));
    try {
      if (speakerId == null && !force) {
        final all = await speakers.getAll();
        final conflict = findSpeakerNamed(trimmed!, [
          for (final s in all)
            if (s.isNamedByUser) s,
        ]);
        final similar = findSimilarVoice(sample.centroid, all);
        if (conflict != null || similar != null) {
          _set(
            state.copyWith(
              phase: EnrollmentPhase.review,
              nameConflict: conflict,
              clearNameConflict: conflict == null,
              similar: similar,
              clearSimilar: similar == null,
            ),
          );
          return null;
        }
      }
      final Speaker saved;
      if (speakerId == null) {
        saved = await writer.createSpeaker(
          name: trimmed!,
          sample: sample,
          deviceKey: deviceKey,
        );
      } else {
        saved = await writer.improveSpeaker(
          speakerId: speakerId,
          sample: sample,
          deviceKey: deviceKey,
          newName: trimmed,
        );
      }
      _set(
        state.copyWith(
          phase: EnrollmentPhase.saved,
          saved: saved,
          clearSimilar: true,
          clearNameConflict: true,
        ),
      );
      return saved;
    } catch (e) {
      _set(
        state.copyWith(
          phase: EnrollmentPhase.review,
          errorAr: e is InsatoException ? e.messageAr : S.unexpectedError,
        ),
      );
      return null;
    }
  }

  Float32List _joined() {
    final out = Float32List(_samples);
    var at = 0;
    for (final c in _chunks) {
      out.setAll(at, c);
      at += c.length;
    }
    _chunks.clear();
    return out;
  }

  void _fail(String messageAr, {bool modelsMissing = false}) {
    _set(
      state.copyWith(
        phase: EnrollmentPhase.error,
        errorAr: messageAr,
        modelsMissing: modelsMissing,
        level: 0,
      ),
    );
  }

  Future<void> _release() async {
    _ticker?.cancel();
    _ticker = null;
    final subs = [..._subs];
    _subs.clear();
    for (final s in subs) {
      await s.cancel();
    }
    final mic = _mic;
    _mic = null;
    if (mic != null) await mic.dispose().catchError((Object _) {});
  }
}

/// The enrollment flow (one per open screen).
final voiceEnrollmentControllerProvider =
    NotifierProvider.autoDispose<VoiceEnrollmentController, EnrollmentState>(
      VoiceEnrollmentController.new,
    );
