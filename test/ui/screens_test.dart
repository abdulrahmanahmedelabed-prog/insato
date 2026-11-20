import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/interfaces.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/groq/strings.dart';
import 'package:insato/ui/screens/models_screen.dart';
import 'package:insato/ui/screens/settings_screen.dart';
import 'package:insato/ui/screens/speakers_screen.dart';
import 'package:insato/ui/services/connection_tester.dart';
import 'package:insato/ui/strings_ar.dart';
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
      expect(find.text(S.sectionMinutesEngine), findsOneWidget);
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

    testWidgets('saving and testing the Groq key', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await env.run(t, () => AppSettings(env.db).setMinutesEngine('groq'));
      await pumpScreen(t, env, const SettingsScreen());

      expect(find.text(GS.privacyTitle), findsOneWidget);
      final field = find.widgetWithText(TextField, GS.keyLabel);
      expect(t.widget<TextField>(field).obscureText, isTrue);
      await t.enterText(field, '  gsk_123  ');
      await t.ensureVisible(find.text(S.testConnection));
      await t.tap(find.text(S.testConnection));
      await settle(t, rounds: 10);
      expect(env.tester.keys, ['gsk_123']);
      // A key that passed the test is stored.
      expect(env.secure.groq, 'gsk_123');
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
      await env.run(t, () => AppSettings(env.db).setMinutesEngine('groq'));
      await pumpScreen(t, env, const SettingsScreen());
      await t.enterText(find.widgetWithText(TextField, GS.keyLabel), 'bad');
      await t.ensureVisible(find.text(S.testConnection));
      await t.tap(find.text(S.testConnection));
      await settle(t, rounds: 10);
      expect(find.text('المفتاح غير صالح'), findsOneWidget);
      expect(env.secure.groq, isNull);
      await env.dispose(t);
    });

    testWidgets('switching to cloud ASR shows the Groq Whisper settings',
        (t) async {
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
      expect(find.text(GS.asrPrivacyTitle), findsOneWidget);
      expect(find.widgetWithText(TextField, GS.keyLabel), findsOneWidget);
      expect(find.text(GS.asrModelLargeV3), findsOneWidget);
      // The on-device model stays selectable as the quota fallback.
      expect(find.text(S.whisperFallbackNote), findsOneWidget);

      // Accepting the transcription notice is stored.
      await t.ensureVisible(find.text(S.geminiPrivacyAccept).last);
      await t.tap(find.text(S.geminiPrivacyAccept).last);
      await settle(t, rounds: 10);
      expect(
        (await env.run(t, () => AppSettings(env.db).load()))
            .groqAsrPrivacyAcknowledged,
        isTrue,
      );
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
