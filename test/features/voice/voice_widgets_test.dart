import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/voice/voice.dart';
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../session/fakes.dart' show voiceOf;
import '../../ui/harness.dart';
import 'voice_fakes.dart';

const usb = InputDevice(id: '17', label: 'Jabra', type: InputDeviceType.usb);
const bt = InputDevice(
  id: 'bt',
  label: 'Buds',
  type: InputDeviceType.bluetoothSco,
);

/// Scrolls the page's list until [f] is visible, then taps it.
Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  await t.pump();
  await t.tap(f);
}

class VoiceUiEnv {
  final UiTestEnv base = UiTestEnv();
  final FakeMicFactory mics = FakeMicFactory(devices: const [usb, bt]);
  final FakeEnrollmentAnalyzer analyzer = FakeEnrollmentAnalyzer(speaker: 2);
  final FakePlayback player = FakePlayback();

  Future<void> pump(WidgetTester t, Widget child) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.overrides,
          micCaptureFactoryProvider.overrideWithValue(mics.call),
          capturePlatformProvider.overrideWithValue(CapturePlatform.android),
          meetingRecordingActiveProvider.overrideWithValue(false),
          enrollmentAnalyzerFactoryProvider.overrideWithValue(
            ({bool farField = false}) async => analyzer,
          ),
          micTestDirProvider.overrideWithValue(() async => base.tmp.path),
          testPlaybackFactoryProvider.overrideWithValue(() => player),
        ],
        retry: (_, _) => null,
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: InsatoTheme.light(),
          home: child,
        ),
      ),
    );
    await settle(t);
  }
}

void main() {
  testWidgets('enrollment: record, review and save a new person (phone)', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = VoiceUiEnv();
    await env.pump(t, const VoiceEnrollmentScreen());
    expect(find.text(VoiceStrings.enrollTitle), findsOneWidget);
    expect(find.text(kArabicEnrollmentPassages.first), findsOneWidget);

    await t.tap(find.text(VoiceStrings.languageEnglish));
    await t.pump();
    expect(find.text(kEnglishEnrollmentPassages.first), findsOneWidget);
    await t.tap(find.text(VoiceStrings.otherPassage));
    await t.pump();
    expect(find.text(kEnglishEnrollmentPassages[1]), findsOneWidget);

    await t.enterText(find.byType(TextField), 'د. سارة');
    await t.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await tapVisible(t, find.text(VoiceStrings.startRecording));
    await settle(t);
    expect(find.text(VoiceStrings.stopRecording), findsOneWidget);
    expect(find.text(VoiceStrings.recording), findsOneWidget);

    env.mics.recording!.emit(readingTake());
    await t.pump(const Duration(milliseconds: 150));
    await tapVisible(t, find.text(VoiceStrings.stopRecording));
    await settle(t);
    expect(find.text(VoiceStrings.checksTitle), findsOneWidget);
    expect(find.text(VoiceStrings.saveVoice), findsOneWidget);
    expect(t.takeException(), isNull);

    await tapVisible(t, find.text(VoiceStrings.saveVoice));
    await settle(t);
    final all = await env.base.run(
      t,
      () => SpeakerRepository(env.base.db).getAll(),
    );
    expect(all.single.name, 'د. سارة');
    await env.base.dispose(t);
  });

  testWidgets('enrollment: blocked take offers only "record again" (desktop)', (
    t,
  ) async {
    setScreenSize(t, kDesktop);
    final env = VoiceUiEnv();
    await env.pump(t, const VoiceEnrollmentScreen());
    await tapVisible(t, find.text(VoiceStrings.startRecording));
    await settle(t);
    env.mics.recording!.emit(readingTake(segments: 2));
    await t.pump(const Duration(milliseconds: 150));
    await tapVisible(t, find.text(VoiceStrings.stopRecording));
    await settle(t);
    expect(
      find.text(VoiceStrings.issue(AudioQualityIssueKind.tooLittleSpeech)),
      findsOneWidget,
    );
    expect(find.text(VoiceStrings.saveVoice), findsNothing);
    await tapVisible(t, find.text(VoiceStrings.recordAgain));
    await settle(t);
    expect(find.text(VoiceStrings.startRecording), findsOneWidget);
    await env.base.dispose(t);
  });

  testWidgets('improve voice of a named speaker hides the name field', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = VoiceUiEnv();
    final s = await env.base.run(
      t,
      () =>
          SpeakerRepository(env.base.db)
              .create(name: 'خالد', centroid: voiceOf(2), embeddingCount: 4),
    );
    await env.pump(t, VoiceEnrollmentScreen(speaker: s));
    expect(find.text(VoiceStrings.improveTitle('خالد')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(VoiceStrings.improveIntro), findsOneWidget);
    await env.base.dispose(t);
  });

  testWidgets('mic settings: pick a device, Bluetooth warning, far field', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = VoiceUiEnv();
    await env.pump(
      t,
      const Scaffold(body: SingleChildScrollView(child: MicSettingsSection())),
    );
    expect(find.text(VoiceStrings.micSection), findsOneWidget);
    expect(find.text(VoiceStrings.defaultDevice), findsOneWidget);

    await t.tap(find.text(VoiceStrings.inputDevice));
    await settle(t);
    expect(find.text(VoiceStrings.chooseDevice), findsOneWidget);
    expect(find.text('Jabra (USB)'), findsOneWidget);
    expect(find.text(VoiceStrings.bluetoothBadge), findsOneWidget);
    expect(find.text(VoiceStrings.bluetoothWarning), findsOneWidget);

    await t.tap(find.text('Buds (بلوتوث)'));
    await settle(t);
    final remembered = await env.base.run(
      t,
      () => InputDevicePreferences(
        settings: AppSettings(env.base.db),
        db: env.base.db,
      ).load(),
    );
    expect(remembered.id, 'bt');
    await settle(t);
    expect(find.text('Buds (بلوتوث)'), findsOneWidget);
    expect(find.text(VoiceStrings.bluetoothWarning), findsOneWidget);

    await t.tap(find.text(VoiceStrings.farField));
    await settle(t);
    final s = await env.base.run(t, () => AppSettings(env.base.db).load());
    expect(s.farFieldMode, isTrue);
    expect(t.takeException(), isNull);
    await env.base.dispose(t);
  });

  testWidgets('mic chip opens the picker', (t) async {
    setScreenSize(t, kPhone);
    final env = VoiceUiEnv();
    await env.pump(t, const Scaffold(body: Center(child: MicDeviceChip())));
    expect(find.text(VoiceStrings.defaultDevice), findsOneWidget);
    await t.tap(find.byType(MicDeviceChip));
    await settle(t);
    expect(find.text(VoiceStrings.chooseDevice), findsOneWidget);
    await t.tap(find.text('Jabra (USB)'));
    await settle(t);
    expect(find.text('Jabra'), findsOneWidget);
    await env.base.dispose(t);
  });

  testWidgets('mic test: 5 s recording, result and playback', (t) async {
    setScreenSize(t, kPhone);
    final env = VoiceUiEnv();
    await env.pump(t, const MicTestScreen());
    expect(find.text(VoiceStrings.distanceTip), findsOneWidget);
    await tapVisible(t, find.text(VoiceStrings.recordTest));
    await settle(t);
    env.mics.recording!.emit(join([noise(400), tone(4800)]));
    await t.pump(const Duration(milliseconds: 150));
    await settle(t, rounds: 40);
    expect(find.text(VoiceStrings.testResult), findsOneWidget);
    expect(find.text(VoiceStrings.testOk), findsOneWidget);
    await tapVisible(t, find.text(VoiceStrings.playTest));
    await settle(t);
    expect(env.player.played, hasLength(1));
    expect(find.text(VoiceStrings.stopPlayback), findsOneWidget);
    expect(t.takeException(), isNull);
    await env.base.dispose(t);
  });
}
