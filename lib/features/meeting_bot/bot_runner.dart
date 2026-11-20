// State machine of the meeting bot (pure Dart over a browser driver and a
// recorder; unit-tested with fakes and a fake clock).
//
//   idle ─start─► scheduled ─(time)─► launching ─► joining ─► waitingAdmission
//                                         │            │             │
//                                         ▼            ▼             ▼
//                                       failed ◄──── (denied / timeouts / errors)
//                                                      │             │
//                                                      └─(admitted)──┴─► recording
//                                                                         │
//              ended ◄── leaving ◄── (meeting ended / removed / everyone left /
//                                     long silence / browser closed / stop)
//
// The bot never records before the organiser admits it: the Insato
// meeting starts when the page shows the bot inside the call, and stops
// before the bot leaves.

import 'dart:async';

import 'bot_audio.dart' show BotCaptureMode;
import 'bot_scripts.dart';
import 'browser_driver.dart';
import 'meeting_link.dart';

/// Phase of the bot.
enum BotPhase {
  /// Nothing scheduled or running.
  idle,

  /// Waiting for the scheduled join time (while the app runs).
  scheduled,

  /// Starting the browser.
  launching,

  /// Opening the meeting page, entering the name, asking to join.
  joining,

  /// In the lobby, waiting for the organiser to admit the bot.
  waitingAdmission,

  /// Admitted; the meeting is being recorded.
  recording,

  /// Stopping the recording and leaving the meeting.
  leaving,

  /// Finished normally (see [BotStatus.reason]).
  ended,

  /// Finished with a problem (see [BotStatus.reason]).
  failed,
}

/// Why the bot finished.
enum BotEndReason {
  /// The user pressed stop (or stopped the recording).
  userStopped,

  /// The meeting ended.
  meetingEnded,

  /// Everybody else left.
  everyoneLeft,

  /// The bot was removed from the meeting.
  removed,

  /// The organiser declined the request to join.
  denied,

  /// Nobody admitted the bot in time.
  admissionTimeout,

  /// The join page could not be completed in time.
  joinTimeout,

  /// The host did not start the meeting in time.
  notStarted,

  /// A human check (CAPTCHA) was not completed in time.
  verificationTimeout,

  /// The link is invalid or the meeting no longer exists.
  invalidLink,

  /// The meeting does not accept guests without an account.
  guestsBlocked,

  /// The bot's browser was closed.
  browserClosed,

  /// Neither Edge nor Chrome is installed.
  browserMissing,

  /// The browser could not be started.
  launchFailed,

  /// The Insato recording could not start.
  recordingFailed,

  /// No sound for a long time.
  silenceTimeout,

  /// The page stopped showing the meeting.
  callLost,

  /// The page stopped answering.
  pageUnresponsive,

  /// Another recording is running.
  busy,

  /// Not available on this platform.
  unsupportedPlatform,
}

/// What the bot should do.
class BotRequest {
  /// Creates a request.
  const BotRequest({
    required this.link,
    required this.botName,
    this.scheduledAt,
    this.showWindow = false,
  });

  /// The meeting.
  final MeetingLink link;

  /// Name shown to the participants.
  final String botName;

  /// Join time (null = now).
  final DateTime? scheduledAt;

  /// Keep the browser window visible.
  final bool showWindow;
}

/// What the recorder needs to start the Insato meeting.
class BotRecordingRequest {
  /// Creates the request.
  const BotRecordingRequest({
    required this.link,
    required this.botName,
    this.pid,
  });

  /// The meeting.
  final MeetingLink link;

  /// The bot's name.
  final String botName;

  /// The bot browser's process id (for process-loopback capture).
  final int? pid;
}

/// A started recording.
class BotRecordingStarted {
  /// Creates the result.
  const BotRecordingStarted({required this.meetingId, required this.mode});

  /// The Insato meeting.
  final String meetingId;

  /// How the audio is captured.
  final BotCaptureMode mode;
}

/// Records the meeting through the normal Insato pipeline (fake in tests).
abstract class BotRecorder {
  /// Starts the recording. Throws (an Arabic `InsatoException` when
  /// possible) when it cannot start.
  Future<BotRecordingStarted> start(BotRecordingRequest request);

  /// Stops the recording (minutes follow as usual); no-op when not
  /// recording. Never throws.
  Future<void> stop();
}

/// Timing of the bot.
class BotTimings {
  /// Creates timings (defaults for real meetings).
  const BotTimings({
    this.poll = const Duration(seconds: 1),
    this.joinTimeout = const Duration(minutes: 2),
    this.admissionTimeout = const Duration(minutes: 15),
    this.notStartedTimeout = const Duration(minutes: 60),
    this.verificationTimeout = const Duration(minutes: 5),
    this.aloneGrace = const Duration(minutes: 2),
    this.silenceTimeout = const Duration(minutes: 30),
    this.callLostGrace = const Duration(minutes: 2),
    this.inCallActionsEvery = const Duration(seconds: 15),
    this.maxProbeFailures = 20,
    this.audioActivityLevel = 0.02,
  });

  /// Interval between two page checks.
  final Duration poll;

  /// From opening the page to reaching the lobby (or the call).
  final Duration joinTimeout;

  /// Longest wait in the lobby.
  final Duration admissionTimeout;

  /// Longest wait for the host to start the meeting (Zoom, Webex).
  final Duration notStartedTimeout;

  /// How long the user has to complete a human check in the bot window.
  final Duration verificationTimeout;

  /// How long the bot stays once it is alone.
  final Duration aloneGrace;

  /// How long without any sound before leaving.
  final Duration silenceTimeout;

  /// How long the call may be missing from the page before leaving.
  final Duration callLostGrace;

  /// How often microphone / camera are re-checked in the call.
  final Duration inCallActionsEvery;

  /// Consecutive failed page checks before giving up.
  final int maxProbeFailures;

  /// Input level (0..1) that counts as sound.
  final double audioActivityLevel;
}

/// Snapshot of the bot for the UI.
class BotStatus {
  /// Creates a status.
  const BotStatus({
    this.phase = BotPhase.idle,
    this.request,
    this.reason,
    this.meetingId,
    this.captureMode,
    this.pageState,
    this.recordingSince,
    this.detail,
    this.errorMessage,
  });

  /// Phase.
  final BotPhase phase;

  /// The running / last request.
  final BotRequest? request;

  /// Why the bot finished ([BotPhase.ended] / [BotPhase.failed]).
  final BotEndReason? reason;

  /// The Insato meeting recorded by the bot.
  final String? meetingId;

  /// How the audio is captured while recording.
  final BotCaptureMode? captureMode;

  /// Last page state seen.
  final BotPageState? pageState;

  /// When the recording started.
  final DateTime? recordingSince;

  /// Technical detail (logs, never shown alone).
  final String? detail;

  /// Arabic message of a recording start failure, when there is one.
  final String? errorMessage;

  /// True while the bot occupies the browser / recording.
  bool get isActive => switch (phase) {
    BotPhase.launching ||
    BotPhase.joining ||
    BotPhase.waitingAdmission ||
    BotPhase.recording ||
    BotPhase.leaving => true,
    _ => false,
  };

  /// True while scheduled or active.
  bool get isBusy => isActive || phase == BotPhase.scheduled;

  /// Returns a copy.
  BotStatus copyWith({
    BotPhase? phase,
    BotEndReason? reason,
    String? meetingId,
    BotCaptureMode? captureMode,
    BotPageState? pageState,
    DateTime? recordingSince,
    String? detail,
    String? errorMessage,
  }) => BotStatus(
    phase: phase ?? this.phase,
    request: request,
    reason: reason ?? this.reason,
    meetingId: meetingId ?? this.meetingId,
    captureMode: captureMode ?? this.captureMode,
    pageState: pageState ?? this.pageState,
    recordingSince: recordingSince ?? this.recordingSince,
    detail: detail ?? this.detail,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  @override
  String toString() =>
      'BotStatus(${phase.name}, reason: ${reason?.name}, '
      'page: ${pageState?.name}, meeting: $meetingId)';
}

/// Arabic message of a recorder failure (an `InsatoException` carries
/// `messageAr`), else null.
typedef BotErrorMessage = String? Function(Object error);

/// Runs one bot request at a time. See the file header.
class MeetingBotRunner {
  /// Creates the runner. With [autoTick] a periodic timer drives [tick];
  /// tests leave it off and call [tick] themselves with a fake [now].
  MeetingBotRunner({
    required this.driver,
    required this.recorder,
    this.timings = const BotTimings(),
    DateTime Function()? now,
    this.autoTick = true,
    BotErrorMessage? errorMessage,
    this.onStatus,
  }) : _now = now ?? DateTime.now,
       _errorMessage = errorMessage ?? ((_) => null);

  /// Starts browsers.
  final BotBrowserDriver driver;

  /// Records the meeting.
  final BotRecorder recorder;

  /// Timing.
  final BotTimings timings;

  /// Whether a timer calls [tick].
  final bool autoTick;

  /// Called synchronously with every status change (before [statuses]).
  void Function(BotStatus status)? onStatus;

  final DateTime Function() _now;
  final BotErrorMessage _errorMessage;

  final _statuses = StreamController<BotStatus>.broadcast();
  BotStatus _status = const BotStatus();
  BotBrowserSession? _browser;
  Timer? _timer;
  Future<void> _serial = Future<void>.value();
  bool _disposed = false;
  bool _recording = false;

  DateTime? _joinStartedAt;
  DateTime? _lobbySince;
  DateTime? _notStartedSince;
  DateTime? _verificationSince;
  DateTime? _lastInCall;
  DateTime? _aloneSince;
  DateTime? _lastSound;
  DateTime? _lastInCallActions;
  int _probeFailures = 0;

  /// Current status.
  BotStatus get status => _status;

  /// Status changes.
  Stream<BotStatus> get statuses => _statuses.stream;

  /// Starts [request] (now, or at [BotRequest.scheduledAt]). Ignored while
  /// another request is busy.
  Future<void> start(BotRequest request) => _run(() async {
    if (_disposed || _status.isBusy) return;
    _resetTracking();
    final at = request.scheduledAt;
    if (at != null && at.isAfter(_now())) {
      _set(BotStatus(phase: BotPhase.scheduled, request: request));
      _startTimer();
      return;
    }
    _set(BotStatus(phase: BotPhase.launching, request: request));
    _startTimer();
    await _launch();
  });

  /// User stop: cancels a schedule, stops the recording and leaves.
  Future<void> stop() => _run(() async {
    switch (_status.phase) {
      case BotPhase.scheduled:
        _stopTimer();
        _set(
          _status.copyWith(
            phase: BotPhase.ended,
            reason: BotEndReason.userStopped,
          ),
        );
      case BotPhase.launching ||
          BotPhase.joining ||
          BotPhase.waitingAdmission ||
          BotPhase.recording:
        await _finish(BotEndReason.userStopped);
      default:
        break;
    }
  });

  /// The recording was stopped outside the bot (recording screen): leave
  /// the meeting.
  Future<void> recordingStoppedElsewhere() => _run(() async {
    if (_status.phase != BotPhase.recording) return;
    _recording = false;
    await _finish(BotEndReason.userStopped);
  });

  /// Feeds the recording's input level (0..1) for the silence rule.
  void noteAudioLevel(double level) {
    if (level >= timings.audioActivityLevel) _lastSound = _now();
  }

  /// One step of the state machine (called by the timer; public for
  /// tests).
  Future<void> tick() => _run(_tick);

  /// Clears an ended / failed status back to idle.
  void reset() {
    if (_status.isBusy) return;
    _set(const BotStatus());
  }

  /// Stops everything (recording included) and closes [statuses].
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    _stopTimer();
    await _serial;
    await _statuses.close();
  }

  // -------------------------------------------------------------------------

  Future<void> _run(Future<void> Function() body) {
    final next = _serial.then((_) => body());
    _serial = next.catchError((Object _) {});
    return next;
  }

  void _set(BotStatus s) {
    _status = s;
    onStatus?.call(s);
    if (!_statuses.isClosed) _statuses.add(s);
  }

  void _resetTracking() {
    _joinStartedAt = null;
    _lobbySince = null;
    _notStartedSince = null;
    _verificationSince = null;
    _lastInCall = null;
    _aloneSince = null;
    _lastSound = null;
    _lastInCallActions = null;
    _probeFailures = 0;
    _recording = false;
  }

  void _startTimer() {
    if (!autoTick || _timer != null) return;
    _timer = Timer.periodic(timings.poll, (_) => unawaited(tick()));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _launch() async {
    final request = _status.request!;
    final BotBrowserSession browser;
    try {
      browser = await driver.launch(
        BotLaunchOptions(url: request.link.uri, showWindow: request.showWindow),
      );
    } on BotBrowserException catch (e) {
      await _fail(
        e.failure == BotBrowserFailure.notFound
            ? BotEndReason.browserMissing
            : BotEndReason.launchFailed,
        detail: e.toString(),
      );
      return;
    } catch (e) {
      await _fail(BotEndReason.launchFailed, detail: '$e');
      return;
    }
    if (_status.phase != BotPhase.launching) {
      // Stopped while starting.
      await browser.close();
      return;
    }
    _browser = browser;
    _joinStartedAt = _now();
    _set(_status.copyWith(phase: BotPhase.joining));
  }

  Future<void> _tick() async {
    final now = _now();
    switch (_status.phase) {
      case BotPhase.scheduled:
        final at = _status.request?.scheduledAt;
        if (at == null || !now.isBefore(at)) {
          _set(_status.copyWith(phase: BotPhase.launching));
          await _launch();
        }
        return;
      case BotPhase.joining || BotPhase.waitingAdmission || BotPhase.recording:
        break;
      default:
        return;
    }
    final browser = _browser;
    if (browser == null || !browser.isAlive) {
      await _end(BotEndReason.browserClosed);
      return;
    }
    final BotProbe probe;
    try {
      probe = BotProbe.fromJson(await browser.evaluate(_expr('probe')));
    } catch (e) {
      if (!browser.isAlive) {
        await _end(BotEndReason.browserClosed);
        return;
      }
      _probeFailures++;
      if (_probeFailures >= timings.maxProbeFailures) {
        await _end(BotEndReason.pageUnresponsive, detail: '$e');
      }
      return;
    }
    _probeFailures = 0;
    if (probe.state != _status.pageState) {
      _set(_status.copyWith(pageState: probe.state));
    }
    switch (_status.phase) {
      case BotPhase.joining:
        await _whileJoining(probe, now);
      case BotPhase.waitingAdmission:
        await _whileWaiting(probe, now);
      case BotPhase.recording:
        await _whileRecording(probe, now);
      default:
        break;
    }
  }

  String _expr(String mode) {
    final request = _status.request!;
    return botPageExpression(
      platformScriptId(request.link.platform),
      mode,
      vars: {'name': request.botName, 'passcode': request.link.passcode ?? ''},
    );
  }

  Future<BotActionResult> _act(String group) async {
    final browser = _browser;
    if (browser == null) return const BotActionResult();
    try {
      return BotActionResult.fromJson(await browser.evaluate(_expr(group)));
    } catch (_) {
      return const BotActionResult();
    }
  }

  /// Ends with [reason] when the page shows a final state; true if so.
  Future<bool> _handleFinalStates(BotPageState state) async {
    final reason = switch (state) {
      BotPageState.denied => BotEndReason.denied,
      BotPageState.lobbyTimeout => BotEndReason.admissionTimeout,
      BotPageState.invalid => BotEndReason.invalidLink,
      BotPageState.blocked => BotEndReason.guestsBlocked,
      BotPageState.removed =>
        _status.phase == BotPhase.recording
            ? BotEndReason.removed
            : BotEndReason.denied,
      BotPageState.ended => BotEndReason.meetingEnded,
      _ => null,
    };
    if (reason == null) return false;
    await _end(reason);
    return true;
  }

  Future<void> _whileJoining(BotProbe probe, DateTime now) async {
    if (await _handleFinalStates(probe.state)) return;
    switch (probe.state) {
      case BotPageState.launcher:
        await _act(BotActions.launcher);
      case BotPageState.prejoin:
        await _act(BotActions.prejoin);
      case BotPageState.lobby || BotPageState.notStarted:
        _lobbySince = now;
        if (probe.state == BotPageState.notStarted) _notStartedSince = now;
        _set(_status.copyWith(phase: BotPhase.waitingAdmission));
        return;
      case BotPageState.inCall:
        await _admitted(now);
        return;
      case BotPageState.verification:
        await _whileVerifying(now);
        return;
      default:
        _verificationSince = null;
        break;
    }
    final since = _joinStartedAt ?? now;
    if (now.difference(since) >= timings.joinTimeout) {
      await _end(BotEndReason.joinTimeout);
    }
  }

  /// A human check (CAPTCHA): the bot never solves it. Its window is shown
  /// so the user can; the join timeout restarts once the check is passed.
  Future<void> _whileVerifying(DateTime now) async {
    if (_verificationSince == null) {
      _verificationSince = now;
      try {
        await _browser?.showWindow();
      } catch (_) {
        // The user can still restore it from the taskbar.
      }
    }
    _joinStartedAt = now;
    if (now.difference(_verificationSince!) >= timings.verificationTimeout) {
      await _end(BotEndReason.verificationTimeout);
    }
  }

  Future<void> _whileWaiting(BotProbe probe, DateTime now) async {
    if (await _handleFinalStates(probe.state)) return;
    if (probe.state == BotPageState.inCall) {
      await _admitted(now);
      return;
    }
    if (probe.state == BotPageState.prejoin) {
      // Back on the join screen after asking: the request is over. The bot
      // never knocks again by itself.
      await _end(BotEndReason.admissionTimeout);
      return;
    }
    if (probe.state == BotPageState.notStarted) {
      // Waiting for the host to start: a longer limit, counted from the
      // first time the page said so.
      final since = _notStartedSince ??= now;
      _lobbySince = now;
      if (now.difference(since) >= timings.notStartedTimeout) {
        await _end(BotEndReason.notStarted);
      }
      return;
    }
    if (probe.state == BotPageState.verification) {
      await _whileVerifying(now);
      _lobbySince = now;
      return;
    }
    final since = _lobbySince ?? now;
    if (now.difference(since) >= timings.admissionTimeout) {
      await _end(BotEndReason.admissionTimeout);
    }
  }

  Future<void> _admitted(DateTime now) async {
    final request = _status.request!;
    // Devices off before anything is recorded.
    await _act(BotActions.inCall);
    _lastInCallActions = now;
    _lastInCall = now;
    _lastSound = now;
    _aloneSince = null;
    _set(_status.copyWith(phase: BotPhase.recording));
    final BotRecordingStarted started;
    try {
      started = await recorder.start(
        BotRecordingRequest(
          link: request.link,
          botName: request.botName,
          pid: _browser?.pid,
        ),
      );
    } catch (e) {
      await _fail(
        BotEndReason.recordingFailed,
        detail: '$e',
        errorMessage: _errorMessage(e),
      );
      return;
    }
    if (_status.phase != BotPhase.recording) {
      // Stopped while the recording was starting.
      await recorder.stop();
      return;
    }
    _recording = true;
    _set(
      _status.copyWith(
        meetingId: started.meetingId,
        captureMode: started.mode,
        recordingSince: _now(),
      ),
    );
  }

  Future<void> _whileRecording(BotProbe probe, DateTime now) async {
    if (await _handleFinalStates(probe.state)) return;
    if (probe.state == BotPageState.inCall) {
      _lastInCall = now;
      final last = _lastInCallActions;
      if (last == null || now.difference(last) >= timings.inCallActionsEvery) {
        _lastInCallActions = now;
        await _act(BotActions.inCall);
      }
      final alone = probe.alone || probe.participants == 1;
      if (alone) {
        final since = _aloneSince ??= now;
        if (now.difference(since) >= timings.aloneGrace) {
          await _end(BotEndReason.everyoneLeft);
          return;
        }
      } else {
        _aloneSince = null;
      }
    } else {
      final last = _lastInCall ?? now;
      if (now.difference(last) >= timings.callLostGrace) {
        await _end(BotEndReason.callLost);
        return;
      }
    }
    final sound = _lastSound ?? now;
    if (now.difference(sound) >= timings.silenceTimeout) {
      await _end(BotEndReason.silenceTimeout);
    }
  }

  /// Ends after a recording ([_finish]) or before one ([_fail]).
  Future<void> _end(BotEndReason reason, {String? detail}) =>
      _recording || _status.phase == BotPhase.recording
      ? _finish(reason, detail: detail)
      : _fail(reason, detail: detail);

  /// Stops the recording (if any), leaves and closes the browser.
  Future<void> _finish(BotEndReason reason, {String? detail}) async {
    final recorded = _recording;
    final hadMeeting = _status.meetingId != null;
    _set(_status.copyWith(phase: BotPhase.leaving, detail: detail));
    if (recorded) {
      _recording = false;
      await recorder.stop();
    }
    await _closeBrowser(leave: true);
    _stopTimer();
    // Without a recording a user stop is still a normal end; other reasons
    // before admission are failures.
    final ok = hadMeeting || reason == BotEndReason.userStopped;
    _set(
      _status.copyWith(
        phase: ok ? BotPhase.ended : BotPhase.failed,
        reason: reason,
      ),
    );
  }

  Future<void> _fail(
    BotEndReason reason, {
    String? detail,
    String? errorMessage,
  }) async {
    if (_recording) {
      _recording = false;
      await recorder.stop();
    }
    _set(_status.copyWith(phase: BotPhase.leaving, detail: detail));
    await _closeBrowser(leave: true);
    _stopTimer();
    _set(
      _status.copyWith(
        phase: BotPhase.failed,
        reason: reason,
        errorMessage: errorMessage,
      ),
    );
  }

  Future<void> _closeBrowser({required bool leave}) async {
    final browser = _browser;
    _browser = null;
    if (browser == null) return;
    if (leave && browser.isAlive) {
      try {
        await browser
            .evaluate(_expr(BotActions.leave))
            .timeout(const Duration(seconds: 3));
        // Let the page tell the meeting the bot left.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } catch (_) {
        // Closing the browser leaves the meeting anyway.
      }
    }
    try {
      await browser.close();
    } catch (_) {
      // Best effort.
    }
  }
}
