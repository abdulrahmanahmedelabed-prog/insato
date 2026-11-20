// The meeting-bot screen: Windows-only explanation, link validation,
// consent, live status and stop.

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart' show CapturePlatform;
import 'package:insato/features/meeting_bot/bot_providers.dart';
import 'package:insato/features/meeting_bot/bot_runner.dart';
import 'package:insato/features/meeting_bot/meeting_bot_screen.dart';
import 'package:insato/features/meeting_bot/meeting_link.dart'
    show MeetingLinkError;
import 'package:insato/features/meeting_bot/strings.dart';
import 'package:insato/features/voice/mic_capture.dart'
    show capturePlatformProvider;
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';
import 'bot_fakes.dart';

UiTestEnv _env(CapturePlatform platform, FakeBotDriver driver) {
  final env = UiTestEnv();
  env.extraOverrides.addAll([
    capturePlatformProvider.overrideWithValue(platform),
    botBrowserDriverProvider.overrideWithValue(driver),
    meetingBotRunnerFactoryProvider.overrideWithValue(
      (recorder) =>
          MeetingBotRunner(driver: driver, recorder: recorder, autoTick: false),
    ),
  ]);
  return env;
}

void main() {
  testWidgets('phones: explanation only; no entry tile', (t) async {
    final env = _env(CapturePlatform.android, FakeBotDriver());
    await pumpScreen(
      t,
      env,
      const Scaffold(
        body: Column(children: [MeetingBotEntryTile(), MeetingBotButton()]),
      ),
    );
    expect(find.text(BotStrings.entryTile), findsNothing);
    await t.tap(find.byType(MeetingBotButton));
    await settle(t);
    expect(find.text(BotStrings.windowsOnlyTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('bot-link')), findsNothing);
    await env.dispose(t);
  });

  testWidgets('Windows: validate, consent, send, then cancel', (t) async {
    setScreenSize(t, kDesktop);
    final driver = FakeBotDriver();
    final env = _env(CapturePlatform.windows, driver);
    await pumpScreen(t, env, const MeetingBotScreen());
    expect(find.text(BotStrings.intro), findsOneWidget);
    expect(find.text(BotStrings.defaultBotName), findsOneWidget);

    FilledButton startButton() =>
        t.widget<FilledButton>(find.byKey(const ValueKey('bot-start')));
    expect(startButton().onPressed, isNull);

    await t.enterText(
      find.byKey(const ValueKey('bot-link')),
      'https://example.com/x',
    );
    await t.pump();
    expect(
      find.text(BotStrings.linkError(MeetingLinkError.unsupportedHost)),
      findsOneWidget,
    );

    await t.enterText(
      find.byKey(const ValueKey('bot-link')),
      'https://meet.google.com/abc-defg-hij',
    );
    await t.pump();
    expect(find.textContaining('abc-defg-hij'), findsWidgets);
    expect(startButton().onPressed, isNull); // consent missing

    await t.ensureVisible(find.byKey(const ValueKey('bot-consent')));
    await t.tap(find.byKey(const ValueKey('bot-consent')));
    await t.pump();
    expect(startButton().onPressed, isNotNull);

    await t.ensureVisible(find.byKey(const ValueKey('bot-start')));
    await t.tap(find.byKey(const ValueKey('bot-start')));
    await settle(t);
    expect(driver.launches.single.url.host, 'meet.google.com');
    expect(find.text(BotStrings.phase(BotPhase.joining)), findsOneWidget);
    expect(find.byKey(const ValueKey('bot-link')), findsNothing);

    await t.tap(find.byKey(const ValueKey('bot-stop')));
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    expect(
      find.text(BotStrings.reason(BotEndReason.userStopped)),
      findsOneWidget,
    );
    await t.tap(find.text(BotStrings.again));
    await settle(t);
    expect(find.byKey(const ValueKey('bot-link')), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('Zoom meeting ID shows the passcode field', (t) async {
    setScreenSize(t, kDesktop);
    final env = _env(CapturePlatform.windows, FakeBotDriver());
    await pumpScreen(t, env, const MeetingBotScreen());
    expect(find.byKey(const ValueKey('bot-passcode')), findsNothing);
    await t.enterText(
      find.byKey(const ValueKey('bot-link')),
      'Meeting ID: 812 3456 7890 Passcode: 4x7Kp9',
    );
    await t.pump();
    expect(find.byKey(const ValueKey('bot-passcode')), findsOneWidget);
    expect(find.text('4x7Kp9'), findsOneWidget);
    expect(find.textContaining('812 3456 7890'), findsWidgets);
    await env.dispose(t);
  });
}
