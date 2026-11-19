// Gemini (default minutes engine) in Settings: privacy notice, key, model,
// connection test via models.list, and the engine switch.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/ui/screens/settings_screen.dart';
import 'package:insato/ui/services/connection_tester.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:insato/ui/ui_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

http.Client models(List<String> ids, {int status = 200}) => MockClient(
  (req) async => http.Response(
    status == 200
        ? jsonEncode({
            'models': [
              for (final id in ids)
                {
                  'name': 'models/$id',
                  'supportedGenerationMethods': ['generateContent'],
                },
            ],
          })
        : jsonEncode({
            'error': {
              'code': 400,
              'status': 'INVALID_ARGUMENT',
              'message': 'API key not valid.',
              'details': [
                {
                  '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                  'reason': 'API_KEY_INVALID',
                },
              ],
            },
          }),
    status,
  ),
);

void main() {
  group('GeminiConnectionTester', () {
    test('ok when the configured model exists', () async {
      final r = await GeminiConnectionTester(
        client: models(['gemini-flash-latest', 'gemini-2.5-flash']),
      ).test(' AIza ', model: 'gemini-flash-latest');
      expect(r.ok, isTrue);
      expect(r.model, 'gemini-flash-latest');
    });

    test(
      'suggests the newest Flash model when the configured one is missing',
      () async {
        final r = await GeminiConnectionTester(
          client: models(['gemini-2.0-flash', 'gemini-2.5-flash']),
        ).test('AIza', model: 'gemini-flash-latest');
        expect(r.ok, isTrue);
        expect(r.model, 'gemini-2.5-flash');
        expect(r.messageAr, contains('gemini-2.5-flash'));
      },
    );

    test('invalid key, no Flash model, empty key', () async {
      final bad = await GeminiConnectionTester(client: models([], status: 400))
          .test('x');
      expect(bad.ok, isFalse);
      expect(bad.messageAr, contains('Gemini'));
      final none = await GeminiConnectionTester(
        client: models(['gemini-2.5-pro']),
      ).test('x');
      expect(none.ok, isFalse);
      final empty = await GeminiConnectionTester().test('  ');
      expect(empty.ok, isFalse);
    });
  });

  group('settings screen', () {
    testWidgets('Gemini is selected by default with its notice', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await pumpScreen(t, env, const SettingsScreen());
      expect(find.text(S.engineGemini), findsOneWidget);
      expect(find.text(S.geminiPrivacyTitle), findsOneWidget);
      expect(find.widgetWithText(TextField, S.geminiKey), findsOneWidget);
      expect(find.widgetWithText(TextField, S.anthropicKey), findsNothing);

      await t.ensureVisible(find.text(S.geminiPrivacyAccept));
      await t.tap(find.text(S.geminiPrivacyAccept));
      await settle(t, rounds: 10);
      final s = await env.run(t, () => AppSettings(env.db).load());
      expect(s.geminiPrivacyAcknowledged, isTrue);
      expect(find.text(S.geminiPrivacyAccepted), findsOneWidget);

      // Withdrawing works too.
      await t.tap(find.text(S.geminiPrivacyWithdraw));
      await settle(t, rounds: 10);
      final w = await env.run(t, () => AppSettings(env.db).load());
      expect(w.geminiPrivacyAcknowledged, isFalse);
      await env.dispose(t);
    });

    testWidgets('saving the Gemini key and switching to Claude', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await pumpScreen(t, env, const SettingsScreen());
      await t.enterText(
        find.widgetWithText(TextField, S.geminiKey),
        '  AIza-key  ',
      );
      // Submitting the field saves the key.
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t, rounds: 10);
      expect(env.secure.gemini, 'AIza-key');

      await t.ensureVisible(find.text(S.engineClaude));
      await t.pump();
      await t.tap(find.text(S.engineClaude));
      await settle(t, rounds: 10);
      final s = await env.run(t, () => AppSettings(env.db).load());
      expect(s.minutesEngine, AppSettingsData.engineClaude);
      expect(find.widgetWithText(TextField, S.anthropicKey), findsOneWidget);
      expect(find.text(S.geminiPrivacyTitle), findsNothing);
      await env.dispose(t);
    });

    testWidgets('minutes engine readiness follows key and notice', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await pumpScreen(t, env, const SettingsScreen());
      final container = ProviderScope.containerOf(
        t.element(find.byType(SettingsScreen)),
      );
      final sub = container.listen(minutesEngineReadyProvider, (_, _) {});
      addTearDown(sub.close);
      await env.run(
        t,
        () => container.read(geminiKeyConfiguredProvider.future),
      );
      await settle(t, rounds: 5);
      expect(container.read(minutesEngineReadyProvider), isFalse);
      env.secure.gemini = 'AIza';
      container.invalidate(geminiKeyConfiguredProvider);
      await env.run(
        t,
        () => container.read(geminiKeyConfiguredProvider.future),
      );
      await settle(t, rounds: 5);
      expect(container.read(minutesEngineReadyProvider), isFalse);
      await env.run(
        t,
        () => AppSettings(env.db).setGeminiPrivacyAcknowledged(true),
      );
      await settle(t, rounds: 10);
      expect(container.read(minutesEngineReadyProvider), isTrue);
      await env.dispose(t);
    });
  });
}
