// Riverpod wiring of the meeting bot.
//
// [meetingBotControllerProvider] owns one [MeetingBotRunner]. When the
// organiser admits the bot, [SessionBotRecorder] points the session's audio
// at the bot capture (`botCaptureTargetProvider`, read by
// `sessionAudioSourceProvider` through `meetingBotAwareSource`) and starts
// an ordinary Insato meeting; transcription, speakers and minutes follow
// the normal pipeline. The controller is not auto-disposed, so a scheduled
// bot joins while the app keeps running.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_capture_service.dart' show CapturePlatform;
import '../../core/errors.dart';
import '../../session/meeting_session_controller.dart'
    show SessionState, defaultSessionTitle;
import '../../session/providers.dart';
import '../system_audio/mixed_session_audio_source.dart'
    show systemAudioSupportedProvider;
import '../voice/mic_capture.dart' show capturePlatformProvider;
import 'bot_audio.dart';
import 'bot_runner.dart';
import 'browser_driver.dart';
import 'strings.dart';

/// Starts the bot's browser (overridable in tests).
final botBrowserDriverProvider = Provider<BotBrowserDriver>(
  (ref) => ChromiumBotBrowserDriver(),
);

/// Creates the runner for a recorder (overridable in tests).
final meetingBotRunnerFactoryProvider =
    Provider<MeetingBotRunner Function(BotRecorder recorder)>(
      (ref) =>
          (recorder) => MeetingBotRunner(
            driver: ref.read(botBrowserDriverProvider),
            recorder: recorder,
            errorMessage: (e) => e is InsatoException ? e.messageAr : null,
          ),
    );

/// [BotRecorder] over the meeting session.
class SessionBotRecorder implements BotRecorder {
  /// Creates the recorder.
  SessionBotRecorder(this._ref);

  final Ref _ref;
  bool _active = false;
  bool _stopping = false;

  /// True between a successful [start] and the end of the recording.
  bool get isActive => _active;

  /// True while [stop] runs.
  bool get isStopping => _stopping;

  @override
  Future<BotRecordingStarted> start(BotRecordingRequest request) async {
    if (_ref.read(meetingSessionControllerProvider).isActive) {
      throw const InsatoException(BotStrings.busyRecording);
    }
    bool processSupported;
    try {
      processSupported = await _ref.read(botProcessLoopbackSupportedProvider)();
    } catch (_) {
      processSupported = false;
    }
    bool systemSupported;
    try {
      systemSupported = await _ref.read(systemAudioSupportedProvider.future);
    } catch (_) {
      systemSupported = false;
    }
    final mode = chooseBotCaptureMode(
      processSupported: processSupported,
      systemSupported: systemSupported,
      havePid: request.pid != null,
    );
    if (mode == null) {
      throw const InsatoException(BotStrings.captureUnsupported);
    }
    try {
      final id = await _startSession(request, mode);
      return BotRecordingStarted(meetingId: id, mode: mode);
    } catch (_) {
      // Process loopback refused (e.g. activation failed on this build):
      // record the whole system output instead, with the warning.
      if (mode != BotCaptureMode.processLoopback || !systemSupported) rethrow;
    }
    final id = await _startSession(request, BotCaptureMode.systemLoopback);
    return BotRecordingStarted(
      meetingId: id,
      mode: BotCaptureMode.systemLoopback,
    );
  }

  Future<String> _startSession(
    BotRecordingRequest request,
    BotCaptureMode mode,
  ) async {
    setBotCaptureTarget(_ref, BotCaptureTarget(mode: mode, pid: request.pid));
    final String meetingId;
    try {
      meetingId = await _ref
          .read(meetingSessionControllerProvider.notifier)
          .start(
            title: BotStrings.meetingTitle(
              defaultSessionTitle(DateTime.now()),
              request.link.platform,
            ),
            // The bot screen requires the user's confirmation first.
            consentGiven: true,
          );
    } catch (_) {
      setBotCaptureTarget(_ref, null);
      rethrow;
    }
    _active = true;
    return meetingId;
  }

  @override
  Future<void> stop() async {
    if (!_active || _stopping) return;
    if (!_ref.mounted) {
      // The app is shutting down; the session tears itself down.
      _active = false;
      return;
    }
    _stopping = true;
    try {
      await _ref.read(meetingSessionControllerProvider.notifier).stop();
    } catch (_) {
      // The session reports its own errors.
    } finally {
      _stopping = false;
      released();
    }
  }

  /// The recording is over (stopped here or elsewhere): the session's
  /// audio goes back to the normal source.
  void released() {
    if (!_active) return;
    _active = false;
    if (_ref.mounted) setBotCaptureTarget(_ref, null);
  }
}

/// Drives the meeting bot. See the file header.
class MeetingBotController extends Notifier<BotStatus> {
  MeetingBotRunner? _runner;
  SessionBotRecorder? _recorder;

  @override
  BotStatus build() {
    ref.listen<SessionState>(meetingSessionControllerProvider, _onSession);
    ref.onDispose(() {
      final runner = _runner;
      _runner = null;
      if (runner != null) unawaited(runner.dispose());
    });
    return const BotStatus();
  }

  /// Sends the bot (now or at [BotRequest.scheduledAt]).
  Future<void> start(BotRequest request) async {
    if (state.isBusy) return;
    if (ref.read(capturePlatformProvider) != CapturePlatform.windows) {
      state = BotStatus(
        phase: BotPhase.failed,
        request: request,
        reason: BotEndReason.unsupportedPlatform,
      );
      return;
    }
    if (ref.read(meetingSessionControllerProvider).isActive) {
      state = BotStatus(
        phase: BotPhase.failed,
        request: request,
        reason: BotEndReason.busy,
      );
      return;
    }
    await _disposeRunner();
    final recorder = SessionBotRecorder(ref);
    final runner = ref.read(meetingBotRunnerFactoryProvider)(recorder);
    _recorder = recorder;
    _runner = runner;
    runner.onStatus = (s) {
      if (ref.mounted && identical(_runner, runner)) state = s;
    };
    await runner.start(request);
  }

  /// Stops the bot (and its recording).
  Future<void> stop() async => _runner?.stop();

  /// Clears a finished status.
  void reset() {
    if (state.isBusy) return;
    _runner?.reset();
    state = const BotStatus();
  }

  Future<void> _disposeRunner() async {
    final runner = _runner;
    _runner = null;
    if (runner != null) await runner.dispose();
  }

  void _onSession(SessionState? prev, SessionState next) {
    final runner = _runner;
    final recorder = _recorder;
    if (runner == null || recorder == null || !recorder.isActive) return;
    if (next.isCapturing) runner.noteAudioLevel(next.level);
    if (recorder.isStopping) return;
    if (prev != null && prev.isCapturing && !next.isCapturing) {
      // Stopped from the recording screen (or by the platform).
      unawaited(runner.recordingStoppedElsewhere());
    }
    if (!next.isActive) recorder.released();
  }
}

/// The meeting bot.
final meetingBotControllerProvider =
    NotifierProvider<MeetingBotController, BotStatus>(MeetingBotController.new);
