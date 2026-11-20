// The bot's state machine over a fake browser, a fake recorder and a fake
// clock.

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/features/meeting_bot/bot_audio.dart';
import 'package:insato/features/meeting_bot/bot_runner.dart';
import 'package:insato/features/meeting_bot/bot_scripts.dart';
import 'package:insato/features/meeting_bot/browser_driver.dart';
import 'package:insato/features/meeting_bot/meeting_link.dart';
import 'package:insato/features/meeting_bot/strings.dart';

import 'bot_fakes.dart';

final MeetingLink _meet = parseMeetingLink(
  'https://meet.google.com/abc-defg-hij',
).link!;

final MeetingLink _teams = parseMeetingLink(
  'https://teams.live.com/meet/9876543210123?p=XyZ',
).link!;

class _Env {
  _Env() {
    runner = MeetingBotRunner(
      driver: driver,
      recorder: recorder,
      now: clock.call,
      autoTick: false,
      errorMessage: (e) => e is InsatoException ? e.messageAr : null,
    );
    runner.statuses.listen((s) => phases.add(s.phase));
  }

  final BotClock clock = BotClock();
  final FakeBotDriver driver = FakeBotDriver();
  final FakeBotRecorder recorder = FakeBotRecorder();
  late final MeetingBotRunner runner;
  final List<BotPhase> phases = [];

  FakePage get page => driver.page;

  Future<void> tick([Duration step = const Duration(seconds: 1)]) async {
    clock.advance(step);
    await runner.tick();
  }

  Future<void> startMeet({
    DateTime? at,
    String name = 'إنصاتو — كاتب المحضر',
  }) => runner.start(BotRequest(link: _meet, botName: name, scheduledAt: at));

  /// prejoin → lobby → admitted.
  Future<void> admit() async {
    page.state = BotPageState.prejoin;
    await tick();
    page.state = BotPageState.lobby;
    await tick();
    page.state = BotPageState.inCall;
    await tick();
  }
}

void main() {
  test(
    'joins, waits for admission, records, leaves when the meeting ends',
    () async {
      final env = _Env();
      await env.startMeet();
      expect(env.runner.status.phase, BotPhase.joining);
      expect(env.driver.launches.single.url, _meet.uri);
      expect(env.driver.launches.single.showWindow, isFalse);

      env.page.state = BotPageState.prejoin;
      await env.tick();
      expect(env.page.actions, [BotActions.prejoin]);
      expect(env.recorder.calls, isEmpty);

      env.page.state = BotPageState.lobby;
      await env.tick();
      expect(env.runner.status.phase, BotPhase.waitingAdmission);
      // Waiting in the lobby records nothing and presses nothing.
      await env.tick(const Duration(minutes: 3));
      expect(env.recorder.calls, isEmpty);
      expect(env.page.actions, [BotActions.prejoin]);

      env.page.state = BotPageState.inCall;
      await env.tick();
      final s = env.runner.status;
      expect(s.phase, BotPhase.recording);
      expect(s.meetingId, 'meeting-1');
      expect(s.captureMode, BotCaptureMode.processLoopback);
      expect(s.recordingSince, env.clock.now);
      expect(env.recorder.calls, ['start']);
      expect(env.recorder.requests.single.pid, 4242);
      // Devices are turned off right when admitted.
      expect(env.page.actions.last, BotActions.inCall);

      env.runner.noteAudioLevel(0.5);
      env.page.state = BotPageState.ended;
      await env.tick();
      expect(env.runner.status.phase, BotPhase.ended);
      expect(env.runner.status.reason, BotEndReason.meetingEnded);
      expect(env.runner.status.meetingId, 'meeting-1');
      expect(env.recorder.calls, ['start', 'stop']);
      // The bot leaves (best effort) and the browser is closed.
      expect(env.page.actions.last, BotActions.leave);
      expect(env.driver.session!.closed, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(
        env.phases,
        containsAllInOrder([
          BotPhase.launching,
          BotPhase.joining,
          BotPhase.waitingAdmission,
          BotPhase.recording,
          BotPhase.leaving,
          BotPhase.ended,
        ]),
      );
      await env.runner.dispose();
    },
  );

  test('Teams: the launcher page is passed in the browser', () async {
    final env = _Env();
    await env.runner.start(BotRequest(link: _teams, botName: 'Bot'));
    env.page.state = BotPageState.launcher;
    await env.tick();
    expect(env.page.actions, [BotActions.launcher]);
    env.page.state = BotPageState.prejoin;
    await env.tick();
    expect(env.page.actions.last, BotActions.prejoin);
    await env.runner.dispose();
  });

  test('declined by the organiser: failed, nothing recorded', () async {
    final env = _Env();
    await env.startMeet();
    env.page.state = BotPageState.lobby;
    await env.tick();
    env.page.state = BotPageState.denied;
    await env.tick();
    expect(env.runner.status.phase, BotPhase.failed);
    expect(env.runner.status.reason, BotEndReason.denied);
    expect(env.recorder.calls, isEmpty);
    expect(env.driver.session!.closed, isTrue);
    await env.runner.dispose();
  });

  test('nobody admits the bot: admission timeout', () async {
    final env = _Env();
    await env.startMeet();
    env.page.state = BotPageState.lobby;
    await env.tick();
    await env.tick(const Duration(minutes: 14));
    expect(env.runner.status.phase, BotPhase.waitingAdmission);
    await env.tick(const Duration(minutes: 2));
    expect(env.runner.status.phase, BotPhase.failed);
    expect(env.runner.status.reason, BotEndReason.admissionTimeout);
    await env.runner.dispose();
  });

  test(
    'back on the join screen after asking: the bot never knocks again',
    () async {
      final env = _Env();
      await env.startMeet();
      env.page.state = BotPageState.lobby;
      await env.tick();
      env.page.state = BotPageState.prejoin;
      await env.tick();
      expect(env.runner.status.reason, BotEndReason.admissionTimeout);
      expect(env.page.actions, isNot(contains(BotActions.prejoin)));
      await env.runner.dispose();
    },
  );

  test('a join page that never completes times out', () async {
    final env = _Env();
    await env.startMeet();
    env.page.state = BotPageState.unknown;
    await env.tick(const Duration(seconds: 90));
    expect(env.runner.status.phase, BotPhase.joining);
    await env.tick(const Duration(seconds: 40));
    expect(env.runner.status.phase, BotPhase.failed);
    expect(env.runner.status.reason, BotEndReason.joinTimeout);
    await env.runner.dispose();
  });

  test('invalid link and guests not allowed are reported', () async {
    for (final (state, reason) in [
      (BotPageState.invalid, BotEndReason.invalidLink),
      (BotPageState.blocked, BotEndReason.guestsBlocked),
    ]) {
      final env = _Env();
      await env.startMeet();
      env.page.state = state;
      await env.tick();
      expect(env.runner.status.reason, reason);
      expect(env.runner.status.phase, BotPhase.failed);
      await env.runner.dispose();
    }
  });

  test('everyone left: the bot waits the grace period, then leaves', () async {
    final env = _Env();
    await env.startMeet();
    await env.admit();
    env.page.alone = true;
    await env.tick();
    await env.tick(const Duration(seconds: 60));
    expect(env.runner.status.phase, BotPhase.recording);
    // Somebody comes back: the timer restarts.
    env.page.alone = false;
    env.page.participants = 3;
    await env.tick();
    env.page.participants = 1;
    await env.tick();
    await env.tick(const Duration(seconds: 100));
    expect(env.runner.status.phase, BotPhase.recording);
    await env.tick(const Duration(seconds: 30));
    expect(env.runner.status.phase, BotPhase.ended);
    expect(env.runner.status.reason, BotEndReason.everyoneLeft);
    expect(env.recorder.calls, ['start', 'stop']);
    await env.runner.dispose();
  });

  test('removed during the recording: ended, the recording is kept', () async {
    final env = _Env();
    await env.startMeet();
    await env.admit();
    env.page.state = BotPageState.removed;
    await env.tick();
    expect(env.runner.status.phase, BotPhase.ended);
    expect(env.runner.status.reason, BotEndReason.removed);
    expect(env.recorder.calls, ['start', 'stop']);
    await env.runner.dispose();
  });

  test('the browser closes during the recording', () async {
    final env = _Env();
    await env.startMeet();
    await env.admit();
    env.driver.session!.crash();
    await env.tick();
    expect(env.runner.status.phase, BotPhase.ended);
    expect(env.runner.status.reason, BotEndReason.browserClosed);
    expect(env.recorder.calls, ['start', 'stop']);
    await env.runner.dispose();
  });

  test('long silence ends the recording; sound keeps it going', () async {
    final env = _Env();
    await env.startMeet();
    await env.admit();
    for (var i = 0; i < 4; i++) {
      await env.tick(const Duration(minutes: 10));
      env.runner.noteAudioLevel(0.3);
    }
    expect(env.runner.status.phase, BotPhase.recording);
    env.runner.noteAudioLevel(0.001); // below the activity level
    await env.tick(const Duration(minutes: 29));
    expect(env.runner.status.phase, BotPhase.recording);
    await env.tick(const Duration(minutes: 2));
    expect(env.runner.status.reason, BotEndReason.silenceTimeout);
    await env.runner.dispose();
  });

  test('the call disappears from the page for too long', () async {
    final env = _Env();
    await env.startMeet();
    await env.admit();
    env.page.state = BotPageState.unknown;
    await env.tick(const Duration(seconds: 60));
    expect(env.runner.status.phase, BotPhase.recording);
    await env.tick(const Duration(seconds: 61));
    expect(env.runner.status.reason, BotEndReason.callLost);
    await env.runner.dispose();
  });

  test('an unresponsive page eventually ends the bot', () async {
    final env = _Env();
    await env.startMeet();
    env.page.throwOnProbe = true;
    for (var i = 0; i < 19; i++) {
      await env.tick();
    }
    expect(env.runner.status.phase, BotPhase.joining);
    await env.tick();
    expect(env.runner.status.phase, BotPhase.failed);
    expect(env.runner.status.reason, BotEndReason.pageUnresponsive);
    await env.runner.dispose();
  });

  test('in the call, devices are re-checked periodically', () async {
    final env = _Env();
    await env.startMeet();
    await env.admit();
    final before = env.page.actions.where((a) => a == BotActions.inCall).length;
    await env.tick(const Duration(seconds: 5));
    await env.tick(const Duration(seconds: 11));
    final after = env.page.actions.where((a) => a == BotActions.inCall).length;
    expect(after, before + 1);
    await env.runner.dispose();
  });

  test('user stop before admission: ended without a recording', () async {
    final env = _Env();
    await env.startMeet();
    env.page.state = BotPageState.lobby;
    await env.tick();
    await env.runner.stop();
    expect(env.runner.status.phase, BotPhase.ended);
    expect(env.runner.status.reason, BotEndReason.userStopped);
    expect(env.runner.status.meetingId, isNull);
    expect(env.recorder.calls, isEmpty);
    expect(env.driver.session!.closed, isTrue);
    await env.runner.dispose();
  });

  test('user stop while recording stops the recording first', () async {
    final env = _Env();
    await env.startMeet();
    await env.admit();
    await env.runner.stop();
    expect(env.runner.status.phase, BotPhase.ended);
    expect(env.runner.status.reason, BotEndReason.userStopped);
    expect(env.recorder.calls, ['start', 'stop']);
    expect(env.page.actions.last, BotActions.leave);
    await env.runner.dispose();
  });

  test('recording stopped from the recording screen: the bot leaves', () async {
    final env = _Env();
    await env.startMeet();
    await env.admit();
    await env.runner.recordingStoppedElsewhere();
    expect(env.runner.status.phase, BotPhase.ended);
    expect(env.runner.status.meetingId, 'meeting-1');
    // The session already stopped; the recorder is not asked again.
    expect(env.recorder.calls, ['start']);
    expect(env.driver.session!.closed, isTrue);
    await env.runner.dispose();
  });

  test('the recording cannot start: failed with the Arabic message', () async {
    final env = _Env();
    env.recorder.failWith = const InsatoException(BotStrings.busyRecording);
    await env.startMeet();
    await env.admit();
    expect(env.runner.status.phase, BotPhase.failed);
    expect(env.runner.status.reason, BotEndReason.recordingFailed);
    expect(env.runner.status.errorMessage, BotStrings.busyRecording);
    expect(env.driver.session!.closed, isTrue);
    await env.runner.dispose();
  });

  test('scheduled: launches at the time, not before', () async {
    final env = _Env();
    final at = env.clock.now.add(const Duration(minutes: 30));
    await env.startMeet(at: at);
    expect(env.runner.status.phase, BotPhase.scheduled);
    await env.tick(const Duration(minutes: 29));
    expect(env.driver.launches, isEmpty);
    await env.tick(const Duration(minutes: 1));
    expect(env.driver.launches, hasLength(1));
    expect(env.runner.status.phase, BotPhase.joining);
    await env.runner.dispose();
  });

  test('a schedule can be cancelled', () async {
    final env = _Env();
    await env.startMeet(at: env.clock.now.add(const Duration(hours: 1)));
    await env.runner.stop();
    expect(env.runner.status.phase, BotPhase.ended);
    expect(env.runner.status.reason, BotEndReason.userStopped);
    await env.tick(const Duration(hours: 2));
    expect(env.driver.launches, isEmpty);
    await env.runner.dispose();
  });

  test('browser problems at start', () async {
    for (final (failure, reason) in [
      (BotBrowserFailure.notFound, BotEndReason.browserMissing),
      (BotBrowserFailure.devToolsTimeout, BotEndReason.launchFailed),
    ]) {
      final env = _Env();
      env.driver.failWith = BotBrowserException(failure);
      await env.startMeet();
      expect(env.runner.status.phase, BotPhase.failed);
      expect(env.runner.status.reason, reason);
      await env.runner.dispose();
    }
  });

  test('one request at a time; reset after the end', () async {
    final env = _Env();
    await env.startMeet();
    await env.runner.start(BotRequest(link: _teams, botName: 'B'));
    expect(env.driver.launches, hasLength(1));
    await env.runner.stop();
    env.runner.reset();
    expect(env.runner.status.phase, BotPhase.idle);
    await env.runner.start(BotRequest(link: _teams, botName: 'B'));
    expect(env.driver.launches, hasLength(2));
    await env.runner.dispose();
  });

  test('Zoom: host not started waits up to the longer limit', () async {
    final env = _Env();
    final zoom = parseMeetingLink('Meeting ID: 812 3456 7890 Passcode: 4x7Kp9')
        .link!;
    await env.runner.start(BotRequest(link: zoom, botName: 'Bot'));
    expect(env.driver.launches.single.url.path, '/wc/join/81234567890');
    env.page.state = BotPageState.prejoin;
    await env.tick();
    env.page.state = BotPageState.notStarted;
    await env.tick();
    expect(env.runner.status.phase, BotPhase.waitingAdmission);
    expect(env.runner.status.pageState, BotPageState.notStarted);
    expect(BotStrings.pageDetail(BotPageState.notStarted), isNotNull);
    await env.tick(const Duration(minutes: 40));
    expect(env.runner.status.phase, BotPhase.waitingAdmission);
    // The host starts; the waiting room follows with its own limit.
    env.page.state = BotPageState.lobby;
    await env.tick();
    await env.tick(const Duration(minutes: 10));
    expect(env.runner.status.phase, BotPhase.waitingAdmission);
    env.page.state = BotPageState.inCall;
    await env.tick();
    expect(env.runner.status.phase, BotPhase.recording);
    await env.runner.dispose();
  });

  test('Zoom: host never starts the meeting', () async {
    final env = _Env();
    await env.startMeet();
    env.page.state = BotPageState.notStarted;
    await env.tick();
    await env.tick(const Duration(minutes: 59));
    expect(env.runner.status.phase, BotPhase.waitingAdmission);
    await env.tick(const Duration(minutes: 2));
    expect(env.runner.status.reason, BotEndReason.notStarted);
    await env.runner.dispose();
  });

  test(
    'a human check shows the window and is never solved by the bot',
    () async {
      final env = _Env();
      await env.startMeet();
      env.page.state = BotPageState.verification;
      await env.tick();
      expect(env.driver.session!.windowShown, 1);
      await env.tick(const Duration(minutes: 3));
      expect(env.driver.session!.windowShown, 1);
      expect(env.runner.status.phase, BotPhase.joining);
      // Nothing is clicked on the check.
      expect(env.page.actions, isEmpty);
      await env.tick(const Duration(minutes: 3));
      expect(env.runner.status.reason, BotEndReason.verificationTimeout);
      await env.runner.dispose();
    },
  );

  test('the user completes the check: joining continues', () async {
    final env = _Env();
    await env.startMeet();
    env.page.state = BotPageState.verification;
    await env.tick();
    await env.tick(const Duration(minutes: 2));
    env.page.state = BotPageState.prejoin;
    await env.tick();
    await env.tick(const Duration(seconds: 90));
    expect(env.runner.status.phase, BotPhase.joining);
    await env.runner.dispose();
  });

  test('every phase and reason has Arabic text', () {
    for (final p in BotPhase.values) {
      expect(BotStrings.phase(p, botName: 'x', time: '10:00'), isNotEmpty);
    }
    for (final r in BotEndReason.values) {
      expect(BotStrings.reason(r), isNotEmpty);
    }
  });
}
