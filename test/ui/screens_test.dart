import 'package:flutter_test/flutter_test.dart';
import 'package:katib/core/interfaces.dart';
import 'package:katib/data/repositories.dart';
import 'package:katib/data/secure_settings.dart';
import 'package:katib/ui/screens/models_screen.dart';
import 'package:katib/ui/screens/settings_screen.dart';
import 'package:katib/ui/screens/speakers_screen.dart';
import 'package:katib/ui/services/connection_tester.dart';
import 'package:katib/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

Finder vertical() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  group('settings', () {
    testWidgets('shows every section in Arabic', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await pumpScreen(t, env, const SettingsScreen());
      expect(find.text(S.sectionClaude), findsOneWidget);
      expect(find.text(S.keyNotConfigured), findsOneWidget);
      expect(find.text(S.minutesDetail), findsOneWidget);
      for (final s in [
        S.sectionAsr,
        S.sectionSpeakers,
        S.sectionModels,
        S.sectionPrivacy,
        S.sectionAbout,
      ]) {
        await t.scrollUntilVisible(find.text(s), 200, scrollable: vertical());
        expect(find.text(s), findsOneWidget);
      }
      await env.dispose(t);
    });

    testWidgets('saving and testing the Anthropic key', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await pumpScreen(t, env, const SettingsScreen());

      final field = find.widgetWithText(TextField, S.anthropicKey);
      expect(t.widget<TextField>(field).obscureText, isTrue);
      await t.enterText(field, '  sk-ant-123  ');
      await t.tap(find.text(S.testConnection));
      await settle(t, rounds: 10);
      expect(env.tester.keys, ['sk-ant-123']);
      // A key that passed the test is stored.
      expect(env.secure.anthropic, 'sk-ant-123');
      expect(find.text(S.keyConfigured), findsOneWidget);
      expect(find.textContaining('الاتصال ناجح'), findsOneWidget);
      await env.dispose(t);
    });

    testWidgets('a failed test shows the error and stores nothing', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv()
        ..tester = FakeConnectionTester(
          const ConnectionTestResult(ok: false, messageAr: 'المفتاح غير صالح'),
        );
      await pumpScreen(t, env, const SettingsScreen());
      await t.enterText(find.widgetWithText(TextField, S.anthropicKey), 'bad');
      await t.tap(find.text(S.testConnection));
      await settle(t, rounds: 10);
      expect(find.text('المفتاح غير صالح'), findsOneWidget);
      expect(env.secure.anthropic, isNull);
      await env.dispose(t);
    });

    testWidgets('switching to cloud ASR shows the Deepgram key', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await pumpScreen(t, env, const SettingsScreen());
      await t.scrollUntilVisible(
        find.text(S.asrCloud),
        200,
        scrollable: vertical(),
      );
      expect(find.text(S.whisperModel), findsOneWidget);
      await t.ensureVisible(find.text(S.asrCloud));
      await t.pump();
      await t.tap(find.text(S.asrCloud));
      await settle(t, rounds: 10);
      final s = await env.run(t, () => AppSettings(env.db).load());
      expect(s.asrEngine, AppSettingsData.asrCloud);
      expect(find.widgetWithText(TextField, S.deepgramKey), findsOneWidget);
      expect(find.text(S.whisperModel), findsNothing);
      await env.dispose(t);
    });

    testWidgets('choosing a language hint stores it', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await pumpScreen(t, env, const SettingsScreen());
      await t.scrollUntilVisible(
        find.text(S.languageHint),
        200,
        scrollable: vertical(),
      );
      await t.ensureVisible(find.text(S.languageHint));
      await t.pump();
      await t.tap(find.text(S.languageHint));
      await settle(t);
      await t.tap(find.text('الإنجليزية'));
      await settle(t, rounds: 10);
      final s = await env.run(t, () => AppSettings(env.db).load());
      expect(s.languageHint, 'en');
      await env.dispose(t);
    });
  });

  group('models', () {
    testWidgets('lists required models with sizes and download buttons', (
      t,
    ) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv(
        modelStates: {
          'silero-vad': const ModelState(ModelStatus.ready),
          'whisper-turbo': const ModelState(
            ModelStatus.downloading,
            progress: 0.42,
          ),
        },
      );
      await pumpScreen(t, env, const ModelsScreen());
      expect(find.text(S.requiredModels), findsOneWidget);
      expect(find.text(S.downloadRequired), findsOneWidget);
      expect(find.text(S.recommendationNote), findsOneWidget);
      await t.scrollUntilVisible(
        find.text(S.downloading(42)),
        200,
        scrollable: vertical(),
      );
      expect(find.text(S.cancelDownload), findsOneWidget);
      await env.dispose(t);
    });
  });

  group('voice library', () {
    testWidgets('shows speakers with meeting counts and voiceprints', (
      t,
    ) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      final seeded = await env.run(t, () => seedMeeting(env));
      await pumpScreen(t, env, const SpeakersScreen());
      expect(find.text(S.voiceLibrary), findsOneWidget);
      expect(find.text('سارة'), findsOneWidget);
      expect(find.text(seeded.auto.name), findsOneWidget);
      expect(find.text(S.meetingsCount(1)), findsNWidgets(2));
      expect(find.text(S.noVoiceprint), findsNWidgets(2));
      await env.dispose(t);
    });

    testWidgets('deleting a speaker asks first', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      final seeded = await env.run(t, () => seedMeeting(env));
      await pumpScreen(t, env, const SpeakersScreen());
      await t.tap(find.byTooltip(S.speakerActions).first);
      await settle(t);
      await t.tap(find.text(S.delete).last);
      await settle(t);
      expect(find.text(S.deleteSpeakerTitle), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, S.delete));
      await settle(t, rounds: 10);
      final all = await env.run(t, () => SpeakerRepository(env.db).getAll());
      expect(all, hasLength(1));
      expect(
        all.single.id == seeded.sara.id || all.single.id == seeded.auto.id,
        isTrue,
      );
      await env.dispose(t);
    });
  });
}
