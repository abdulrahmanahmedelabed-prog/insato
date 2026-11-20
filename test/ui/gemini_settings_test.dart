// Gemini (default minutes engine) in Settings: privacy notice, key, model,
// connection test via models.list, and the engine switch.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/groq/strings.dart';
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
      expect(find.widgetWithText(TextField, GS.keyLabel), findsNothing);
      // Engine choice: only free cloud engines (and local ones).
      expect(find.text(S.engineGroq), findsOneWidget);
      expect(find.textContaining('Claude'), findsNothing);
      expect(find.textContaining('Deepgram'), findsNothing);

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

    testWidgets('saving the Gemini key and switching to Groq', (t) async {
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

      await t.ensureVisible(find.text(S.engineGroq));
      await t.pump();
      await t.tap(find.text(S.engineGroq));
      await settle(t, rounds: 10);
      final s = await env.run(t, () => AppSettings(env.db).load());
      expect(s.minutesEngine, AppSettingsData.engineGroq);
      expect(find.widgetWithText(TextField, GS.keyLabel), findsOneWidget);
      expect(find.text(GS.privacyTitle), findsOneWidget);
      expect(find.text(GS.modelLabel), findsOneWidget);
      expect(find.text(S.geminiPrivacyTitle), findsNothing);
      // The automatic fallback between free cloud engines is offered.
      expect(find.text(GS.fallbackTitle), findsOneWidget);

      // Accepting the Groq notice, then the fallback switch.
      await t.ensureVisible(find.text(S.geminiPrivacyAccept));
      await t.tap(find.text(S.geminiPrivacyAccept));
      await settle(t, rounds: 10);
      await t.ensureVisible(find.text(GS.fallbackTitle));
      // Keep the tile clear of the snack bar at the bottom.
      await t.drag(find.text(GS.fallbackTitle), const Offset(0, -300));
      await settle(t, rounds: 5);
      await t.tap(find.text(GS.fallbackTitle));
      await settle(t, rounds: 10);
      final g = await env.run(t, () => AppSettings(env.db).load());
      expect(g.groqPrivacyAcknowledged, isTrue);
      expect(g.geminiPrivacyAcknowledged, isFalse);
      expect(g.cloudFallbackAuto, isTrue);
      await env.dispose(t);
    });

    testWidgets('engine labels stay on one line at phone width', (t) async {
      setScreenSize(t, const Size(360, 800));
      final env = UiTestEnv();
      await pumpScreen(t, env, const SettingsScreen());
      Finder inButton(String l) => find.descendant(
        of: find.byType(SegmentedButton<String>).first,
        matching: find.text(l),
      );
      final labels = [
        S.engineGemini,
        S.engineGroq,
        S.engineLocal,
        S.engineServer,
      ].where((l) => inButton(l).evaluate().isNotEmpty).toList();
      expect(labels.length, greaterThanOrEqualTo(2));
      for (final l in labels) {
        final style = DefaultTextStyle.of(t.element(inButton(l))).style;
        final line = (style.fontSize ?? 14) * (style.height ?? 1.5);
        expect(
          t.getSize(inButton(l)).height,
          lessThan(line * 1.6),
          reason: '$l wraps',
        );
      }
      expect(t.takeException(), isNull);
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
