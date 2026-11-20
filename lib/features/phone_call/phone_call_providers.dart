// Riverpod wiring of phone-call mode.
//
// * [phoneCallSetupProvider]: the call setup armed for the next recording
//   (set by the setup screen, cleared when that take stops — the call
//   sources report it — or by the user).
// * [phoneCallSessionPlanProvider]: what the session changes while armed
//   (telephone VAD, language hint, voiceprint thresholds per call side);
//   read by `MeetingSessionController.start`.
// * [phoneCallAwareSource]: used by `sessionAudioSourceProvider` — the
//   Phone Link / speakerphone source while armed, the usual chain
//   otherwise (a multi-device hub is not combined with a call take).
// * [phoneCallLogStoreProvider] / [phoneCallLogProvider]: the per-meeting
//   call log.
// * [phoneCallProbeFactoryProvider]: level probes of the pre-call check.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_capture_service.dart' show CapturePlatform;
import '../../core/models.dart' show Speaker;
import '../../session/meeting_session_controller.dart'
    show SessionAudioSource, SessionEngineRequest;
import '../../session/providers.dart'
    show databaseProvider, meetingSessionControllerProvider;
import '../system_audio/mixed_session_audio_source.dart'
    show systemAudioSourceProvider;
import '../voice/device_aware_audio_source.dart'
    show deviceAwareAudioSourceProvider;
import '../voice/mic_capture.dart' show capturePlatformProvider;
import 'call_session_audio.dart';
import 'phone_call_log.dart';
import 'phone_call_models.dart';
import 'phone_link_source.dart';
import 'speakerphone_source.dart';
import 'telephone_profile.dart';

/// The call setup chosen on the setup screen.
class PhoneCallSetup {
  /// Creates a setup.
  const PhoneCallSetup({required this.mode, this.languageChoice});

  /// How the call is captured.
  final PhoneCallMode mode;

  /// Language of the call: null = as in Settings, [kCallLanguageAuto] =
  /// auto-detect, else an ISO-639-1 code.
  final String? languageChoice;
}

/// Arms / disarms phone-call mode for the next recording.
class PhoneCallSetupController extends Notifier<PhoneCallSetup?> {
  @override
  PhoneCallSetup? build() => null;

  /// Arms [setup] for the next recording.
  void arm(PhoneCallSetup setup) => state = setup;

  /// The call take ended (stopped or discarded): the setup applied to that
  /// one recording. Called by the call sources' `stop`.
  void takeEnded() => state = null;

  /// Back to ordinary recordings (ignored while a recording runs, whose
  /// source must not be replaced).
  void disarm() {
    if (ref.read(meetingSessionControllerProvider).isActive) return;
    state = null;
  }
}

/// The armed call setup (null: ordinary meetings).
final phoneCallSetupProvider =
    NotifierProvider<PhoneCallSetupController, PhoneCallSetup?>(
      PhoneCallSetupController.new,
    );

/// What a call take changes in the session.
class PhoneCallSessionPlan {
  /// Creates a plan for [setup].
  const PhoneCallSessionPlan(
    this.setup, {
    this.profile = TelephoneAudioProfile.standard,
  });

  /// The armed setup.
  final PhoneCallSetup setup;

  /// The telephone audio profile.
  final TelephoneAudioProfile profile;

  /// [base] with the telephone VAD and the call's language hint.
  SessionEngineRequest adjustRequest(SessionEngineRequest base) {
    final hint = resolveCallLanguageHint(
      setup.languageChoice,
      base.languageHint,
    );
    return base.withOverrides(
      languageHint: hint,
      clearLanguageHint: hint == null,
      vadConfig: profile.vadFor(setup.mode),
    );
  }

  /// Voiceprint threshold of [speaker] for a segment of [partition].
  double knownSpeakerThreshold(
    Speaker speaker, {
    required String? partition,
    required String? sessionDeviceKey,
    required double base,
  }) => profile.knownSpeakerThreshold(
    speaker,
    partition: partition,
    sessionDeviceKey: sessionDeviceKey,
    base: base,
  );
}

/// Whether [mode] can be used on [platform].
bool phoneCallModeAvailable(PhoneCallMode mode, CapturePlatform platform) =>
    mode == PhoneCallMode.speakerphone || platform == CapturePlatform.windows;

/// The microphone of call takes: the F18 device-aware source (overridable
/// in tests).
final phoneCallMicSourceProvider = Provider<SessionAudioSource>(
  (ref) => ref.watch(deviceAwareAudioSourceProvider),
);

/// The session plan while a usable call setup is armed, else null.
final phoneCallSessionPlanProvider = Provider<PhoneCallSessionPlan?>((ref) {
  final setup = ref.watch(phoneCallSetupProvider);
  if (setup == null) return null;
  if (!phoneCallModeAvailable(setup.mode, ref.watch(capturePlatformProvider))) {
    return null;
  }
  return PhoneCallSessionPlan(setup);
});

/// The call log store.
final phoneCallLogStoreProvider = Provider<PhoneCallLogStore>(
  (ref) => PhoneCallLogStore(ref.watch(databaseProvider)),
);

/// The call log of a meeting (null when it was not a phone call).
final phoneCallLogProvider = StreamProvider.autoDispose
    .family<PhoneCallLog?, String>(
      (ref, id) => ref.watch(phoneCallLogStoreProvider).watch(id),
    );

/// The session source while a call is armed ([fallback] otherwise; also
/// for Phone Link off Windows).
SessionAudioSource phoneCallAwareSource(
  Ref ref,
  SessionAudioSource Function() fallback,
) {
  final plan = ref.watch(phoneCallSessionPlanProvider);
  if (plan == null) return fallback();
  final mic = ref.watch(phoneCallMicSourceProvider);
  final store = ref.watch(phoneCallLogStoreProvider);
  // The armed setup is used up when the take stops: the source is then
  // replaced by the usual one (the session keeps its reference until it has
  // written the call log).
  final setupNotifier = ref.read(phoneCallSetupProvider.notifier);
  switch (plan.setup.mode) {
    case PhoneCallMode.phoneLink:
      final source = PhoneLinkSessionAudioSource(
        mic: mic,
        system: ref.watch(systemAudioSourceProvider),
        profile: plan.profile,
        logStore: store,
        onTakeEnded: setupNotifier.takeEnded,
      );
      ref.onDispose(source.dispose);
      return source;
    case PhoneCallMode.speakerphone:
      final source = SpeakerphoneSessionAudioSource(
        mic: mic,
        profile: plan.profile,
        logStore: store,
        onTakeEnded: setupNotifier.takeEnded,
      );
      ref.onDispose(source.dispose);
      return source;
  }
}

// ===========================================================================
// Pre-call check
// ===========================================================================

/// Live levels of both sides for the pre-call check.
abstract class PhoneCallLevelProbe {
  /// 0..1 microphone level.
  Stream<double> get localLevel;

  /// 0..1 remote level (empty for the speakerphone mode).
  Stream<double> get remoteLevel;

  /// Starts capturing (throws an `InsatoException` with an Arabic message).
  Future<void> start();

  /// Stops capturing and releases the probe.
  Future<void> stop();
}

class _SourceProbe implements PhoneCallLevelProbe {
  _SourceProbe(this._source, this._dispose);

  final SessionAudioSource _source;
  final Future<void> Function() _dispose;
  bool _started = false;

  CallSessionAudio get _call => _source as CallSessionAudio;

  @override
  Stream<double> get localLevel => _call.localLevel;

  @override
  Stream<double> get remoteLevel => _call.remoteLevel;

  @override
  Future<void> start() async {
    await _source.hasPermission();
    await _source.start();
    _started = true;
  }

  @override
  Future<void> stop() async {
    try {
      if (_started) await _source.stop();
    } finally {
      _started = false;
      await _dispose();
    }
  }
}

/// Creates the level probe of a mode (overridden in tests).
final phoneCallProbeFactoryProvider =
    Provider<PhoneCallLevelProbe Function(PhoneCallMode)>((ref) {
      return (mode) {
        final mic = ref.read(phoneCallMicSourceProvider);
        switch (mode) {
          case PhoneCallMode.phoneLink:
            final s = PhoneLinkSessionAudioSource(
              mic: mic,
              system: ref.read(systemAudioSourceProvider),
            );
            return _SourceProbe(s, s.dispose);
          case PhoneCallMode.speakerphone:
            final s = SpeakerphoneSessionAudioSource(mic: mic);
            return _SourceProbe(s, s.dispose);
        }
      };
    });
