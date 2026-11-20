// The bot records through the real session controller: the session's
// audio becomes the bot capture (process loopback of the browser, or the
// system output as fallback) only while the bot records.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart' show CapturePlatform;
import 'package:insato/core/models.dart' show MeetingStatus;
import 'package:insato/features/meeting_bot/bot_audio.dart';
import 'package:insato/features/meeting_bot/bot_providers.dart';
import 'package:insato/features/meeting_bot/bot_runner.dart';
import 'package:insato/features/meeting_bot/bot_scripts.dart';
import 'package:insato/features/meeting_bot/meeting_link.dart';
import 'package:insato/features/system_audio/mixed_session_audio_source.dart';
import 'package:insato/features/voice/mic_capture.dart'
    show capturePlatformProvider;
import 'package:insato/session/providers.dart';

import '../../session/fakes.dart';
import '../system_audio/system_audio_fakes.dart';
import 'bot_fakes.dart';

class _Harness {
  _Harness({
    CapturePlatform platform = CapturePlatform.windows,
    bool processSupported = true,
  }) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
        appPathsProvider.overrideWithValue(
          AppPaths(documentsDir: () async => tmp, supportDir: () async => tmp),
        ),
        mixedSessionAudioSourceProvider.overrideWithValue(mic),
        sessionPlatformHooksProvider.overrideWithValue(FakeHooks()),
        sessionEnginesFactoryProvider.overrideWithValue(FakeEnginesFactory()),
        minutesEngineFactoryProvider.overrideWithValue(() async => null),
        capturePlatformProvider.overrideWithValue(platform),
        systemAudioPlatformProvider.overrideWithValue(systemPlatform),
        systemAudioSupportedProvider.overrideWith((ref) async => true),
        botProcessLoopbackSupportedProvider.overrideWithValue(
          () async => processSupported,
        ),
        botProcessAudioPlatformFactoryProvider.overrideWithValue((pid) {
          pids.add(pid);
          return processPlatform;
        }),
        botBrowserDriverProvider.overrideWithValue(driver),
        meetingBotRunnerFactoryProvider.overrideWithValue(
          (recorder) => runner = MeetingBotRunner(
            driver: driver,
            recorder: recorder,
            now: clock.call,
            autoTick: false,
          ),
        ),
      ],
    );
    container.listen(meetingBotControllerProvider, (_, _) {});
  }

  final db = memoryDb();
  final Directory tmp = Directory.systemTemp.createTempSync('insato_bot_');
  final FakeAudioSource mic = FakeAudioSource();
  final FakeSystemAudioPlatform processPlatform = FakeSystemAudioPlatform();
  final FakeSystemAudioPlatform systemPlatform = FakeSystemAudioPlatform();
  final List<int> pids = [];
  final FakeBotDriver driver = FakeBotDriver();
  final BotClock clock = BotClock();
  late final ProviderContainer container;
  MeetingBotRunner? runner;

  BotStatus get status => container.read(meetingBotControllerProvider);

  Future<void> tick() async {
    clock.advance(const Duration(seconds: 1));
    await runner!.tick();
  }

  Future<void> send() => container
      .read(meetingBotControllerProvider.notifier)
      .start(
        BotRequest(
          link: parseMeetingLink('https://meet.google.com/abc-defg-hij').link!,
          botName: 'إنصاتو — كاتب المحضر',
        ),
      );

  Future<void> admit() async {
    driver.page.state = BotPageState.prejoin;
    await tick();
    driver.page.state = BotPageState.lobby;
    await tick();
    driver.page.state = BotPageState.inCall;
    await tick();
  }

  Future<void> dispose() async {
    container.dispose();
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {
      // Best effort.
    }
  }
}

void main() {
  test(
    'admitted: records the browser process only, then restores the mic',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      expect(h.container.read(sessionAudioSourceProvider), same(h.mic));

      await h.send();
      expect(h.status.phase, BotPhase.joining);
      // Nothing is recorded while joining / waiting.
      h.driver.page.state = BotPageState.lobby;
      await h.tick();
      expect(
        h.container.read(meetingSessionControllerProvider).isActive,
        isFalse,
      );

      h.driver.page.state = BotPageState.inCall;
      await h.tick();
      expect(h.status.phase, BotPhase.recording);
      expect(h.status.captureMode, BotCaptureMode.processLoopback);
      final session = h.container.read(meetingSessionControllerProvider);
      expect(session.isCapturing, isTrue);
      expect(session.audioSourceInUse, 'system');
      expect(session.title, contains('Google Meet'));
      expect(h.pids, [4242]);
      expect(h.processPlatform.starts, 1);
      expect(h.systemPlatform.starts, 0);
      expect(h.mic.started, isFalse);
      expect(
        h.container.read(sessionAudioSourceProvider),
        isA<MixedSessionAudioSource>(),
      );

      h.processPlatform.emitAudio(sine(500));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      h.driver.page.state = BotPageState.ended;
      await h.tick();
      expect(h.status.phase, BotPhase.ended);
      expect(h.status.reason, BotEndReason.meetingEnded);
      final id = h.status.meetingId!;
      final meeting = await h.container.read(meetingRepositoryProvider).get(id);
      expect(meeting, isNotNull);
      expect(meeting!.status, isNot(MeetingStatus.recording));
      expect(
        h.container.read(meetingSessionControllerProvider).isActive,
        isFalse,
      );
      expect(h.container.read(botCaptureTargetProvider), isNull);
      expect(h.container.read(sessionAudioSourceProvider), same(h.mic));
      expect(h.driver.session!.closed, isTrue);
    },
  );

  test('stopping the recording elsewhere makes the bot leave', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.send();
    await h.admit();
    expect(h.status.phase, BotPhase.recording);
    await h.container.read(meetingSessionControllerProvider.notifier).stop();
    await waitUntil(() => h.status.phase == BotPhase.ended);
    expect(h.status.reason, BotEndReason.userStopped);
    expect(h.status.meetingId, isNotNull);
    expect(h.driver.session!.closed, isTrue);
    expect(h.container.read(botCaptureTargetProvider), isNull);
  });

  test('process loopback refused: falls back to the system output', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.processPlatform.startResult = false;
    await h.send();
    await h.admit();
    expect(h.status.phase, BotPhase.recording);
    expect(h.status.captureMode, BotCaptureMode.systemLoopback);
    expect(h.systemPlatform.starts, 1);
    expect(
      h.container.read(botCaptureTargetProvider)?.mode,
      BotCaptureMode.systemLoopback,
    );
    await h.container.read(meetingBotControllerProvider.notifier).stop();
    expect(h.status.phase, BotPhase.ended);
    expect(h.container.read(botCaptureTargetProvider), isNull);
  });

  test('old Windows: the system output is used from the start', () async {
    final h = _Harness(processSupported: false);
    addTearDown(h.dispose);
    await h.send();
    await h.admit();
    expect(h.status.captureMode, BotCaptureMode.systemLoopback);
    expect(h.processPlatform.starts, 0);
    await h.container.read(meetingBotControllerProvider.notifier).stop();
  });

  test('refused off Windows and while another recording runs', () async {
    final phone = _Harness(platform: CapturePlatform.android);
    addTearDown(phone.dispose);
    await phone.send();
    expect(phone.status.phase, BotPhase.failed);
    expect(phone.status.reason, BotEndReason.unsupportedPlatform);
    expect(phone.driver.launches, isEmpty);

    final busy = _Harness();
    addTearDown(busy.dispose);
    await busy.container
        .read(meetingSessionControllerProvider.notifier)
        .start(title: 'اجتماع', consentGiven: true);
    await busy.send();
    expect(busy.status.reason, BotEndReason.busy);
    expect(busy.driver.launches, isEmpty);
    await busy.container.read(meetingSessionControllerProvider.notifier).stop();
  });

  test('chooseBotCaptureMode', () {
    expect(
      chooseBotCaptureMode(
        processSupported: true,
        systemSupported: true,
        havePid: true,
      ),
      BotCaptureMode.processLoopback,
    );
    expect(
      chooseBotCaptureMode(
        processSupported: true,
        systemSupported: true,
        havePid: false,
      ),
      BotCaptureMode.systemLoopback,
    );
    expect(
      chooseBotCaptureMode(
        processSupported: false,
        systemSupported: false,
        havePid: true,
      ),
      isNull,
    );
  });
}
