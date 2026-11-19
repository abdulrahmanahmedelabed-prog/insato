// Regression tests for UI review findings: settings reset scope, API key /
// model save error handling, meeting deletion unmounting its caller, the
// recording screen's landscape layout, Space shortcut, finish navigation
// with a dialog open, the recording bar's inset / live title, and share
// files left on disk.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/app.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/ui/navigation.dart';
import 'package:insato/ui/screens/meeting_detail_screen.dart';
import 'package:insato/ui/screens/meetings_screen.dart';
import 'package:insato/ui/screens/recording_screen.dart';
import 'package:insato/ui/screens/settings_screen.dart';
import 'package:insato/ui/services/connection_tester.dart';
import 'package:insato/ui/services/share_gateway.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../session/fakes.dart';
import 'harness.dart';

Finder vertical() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

Future<void> pumpBare(WidgetTester t, Widget child) => t.pumpWidget(
  MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: InsatoTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// Starts a recording through the app (consent already given) and returns
/// with the recording screen on top.
Future<void> startRecording(WidgetTester t, UiTestEnv env) async {
  await env.run(t, () async {
    await AppSettings(
      env.db,
    ).save(const AppSettingsData(consentAcknowledged: true, keepAudio: false));
  });
  await pumpApp(t, env);
  await t.tap(find.byType(FloatingActionButton));
  await settle(t, rounds: 10);
  expect(find.byType(RecordingScreen), findsOneWidget);
}

/// Deletes the row at once but completes only when [gate] opens, like the
/// real deletion still removing the audio file and saving the ledger while
/// the meeting streams have already re-emitted.
class SlowDeletePostProcessor extends PostProcessor {
  SlowDeletePostProcessor(AppDatabase db, this.gate)
    : super(
        db: db,
        meetings: MeetingRepository(db),
        segments: SegmentRepository(db),
        speakers: SpeakerRepository(db),
        settings: AppSettings(db),
      );

  final Completer<void> gate;

  @override
  Future<bool> deleteMeeting(String meetingId) async {
    final deleted = await super.deleteMeeting(meetingId);
    await gate.future;
    return deleted;
  }
}

/// Pumps the app with deletions held open by [gate].
Future<void> pumpAppSlowDelete(
  WidgetTester t,
  UiTestEnv env,
  Completer<void> gate,
) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...env.overrides,
        postProcessorProvider.overrideWithValue(
          SlowDeletePostProcessor(env.db, gate),
        ),
      ],
      retry: (_, _) => null,
      child: const InsatoApp(),
    ),
  );
  await settle(t);
}

/// Pops the top page (the recording screen is a full-screen dialog with a
/// close button, which pageBack does not find).
Future<void> popTop(WidgetTester t) async {
  await t.state<NavigatorState>(find.byType(Navigator).first).maybePop();
  await t.pump();
}

void main() {
  group('settings', () {
    testWidgets('reset keeps per-meeting voiceprint ledgers', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await env.run(t, () async {
        await AppSettings(env.db).setMatchThreshold(0.7);
        await env.db
            .into(env.db.settings)
            .insert(
              SettingsCompanion.insert(
                key: '${kVoiceprintLedgerPrefix}m1',
                value: '{}',
              ),
            );
      });
      await pumpScreen(t, env, const SettingsScreen());
      await t.scrollUntilVisible(
        find.text(S.resetSettings),
        300,
        scrollable: vertical(),
      );
      await t.ensureVisible(find.text(S.resetSettings));
      await t.pump();
      await t.tap(find.text(S.resetSettings));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, S.confirm));
      await settle(t, rounds: 10);

      final rows = await env.run(t, () => env.db.select(env.db.settings).get());
      final keys = rows.map((r) => r.key).toSet();
      expect(keys, contains('${kVoiceprintLedgerPrefix}m1'));
      expect(keys, isNot(contains(AppSettings.kMatchThreshold)));
      expect(find.text(S.settingsReset), findsOneWidget);
      await env.dispose(t);
    });

    testWidgets('a key that passed the test but failed to save does not '
        'leave the card disabled', (t) async {
      await pumpBare(
        t,
        ApiKeyCard(
          label: S.anthropicKey,
          load: () async => null,
          save: (_) async => throw PlatformException(code: 'keystore'),
          clear: () async {},
          test: (_) async => const ConnectionTestResult(
            ok: true,
            messageAr: 'ok',
            model: 'claude-opus-5-5',
          ),
        ),
      );
      await t.pump();
      await t.enterText(find.byType(TextField), 'sk-ant-1');
      await t.tap(find.text(S.testConnection));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final save = t.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(S.save),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(save.onPressed, isNotNull);
      expect(find.text(S.unexpectedError), findsOneWidget);
      // The test result itself is still shown.
      expect(find.textContaining('الاتصال ناجح'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('clearing a key that fails reports the error', (t) async {
      await pumpBare(
        t,
        ApiKeyCard(
          label: S.anthropicKey,
          load: () async => 'sk-ant-1',
          save: (_) async {},
          clear: () async => throw PlatformException(code: 'keystore'),
        ),
      );
      await t.pump();
      await t.tap(find.text(S.clearKey));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(S.unexpectedError), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('the model field does not claim a failed save', (t) async {
      await pumpBare(
        t,
        ClaudeModelField(value: 'claude-opus-5-5', onSave: (_) async => false),
      );
      await t.enterText(find.byType(TextField), 'claude-other');
      await t.tap(find.byTooltip(S.save));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(S.modelSaved), findsNothing);
      // The field shows the model that is really in use.
      expect(find.text('claude-opus-5-5'), findsOneWidget);
    });

    testWidgets('the model field confirms a successful save', (t) async {
      String? saved;
      await pumpBare(
        t,
        ClaudeModelField(
          value: 'claude-opus-5-5',
          onSave: (m) async {
            saved = m;
            return true;
          },
        ),
      );
      await t.enterText(find.byType(TextField), 'claude-other');
      await t.tap(find.byTooltip(S.save));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(saved, 'claude-other');
      expect(find.text(S.modelSaved), findsOneWidget);
    });
  });

  group('deleting a meeting', () {
    testWidgets('from the phone detail page returns to the list', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await env.run(t, () => seedMeeting(env));
      final gate = Completer<void>();
      await pumpAppSlowDelete(t, env, gate);
      await t.tap(find.text('اجتماع الميزانية'));
      await settle(t);
      expect(find.byType(MeetingDetailScreen), findsOneWidget);
      final container = ProviderScope.containerOf(
        t.element(find.byType(MeetingDetailScreen)),
      );

      await t.tap(find.byTooltip('المزيد'));
      await settle(t);
      await t.tap(find.text(S.deleteMeeting).last);
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, S.delete));
      // The row is gone and the streams re-emit (unmounting the menu that
      // started the deletion) before the deletion completes.
      await settle(t, rounds: 10);
      gate.complete();
      await settle(t, rounds: 10);

      expect(find.byType(MeetingDetailScreen), findsNothing);
      expect(find.text(S.meetingNotFound), findsNothing);
      expect(find.byType(MeetingsScreen), findsOneWidget);
      expect(find.text(S.meetingDeleted), findsOneWidget);
      expect(container.read(selectedMeetingProvider), isNull);
      expect(t.takeException(), isNull);
      await env.dispose(t);
    });

    testWidgets('on desktop clears the selection', (t) async {
      setScreenSize(t, kDesktop);
      final env = UiTestEnv();
      await env.run(t, () => seedMeeting(env));
      final gate = Completer<void>();
      await pumpAppSlowDelete(t, env, gate);
      await t.tap(find.text('اجتماع الميزانية').first);
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(MeetingDetailScreen)),
      );
      expect(container.read(selectedMeetingProvider), isNotNull);

      await t.tap(find.byTooltip('المزيد'));
      await settle(t);
      await t.tap(find.text(S.deleteMeeting).last);
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, S.delete));
      // The row is gone and the streams re-emit (unmounting the menu that
      // started the deletion) before the deletion completes.
      await settle(t, rounds: 10);
      gate.complete();
      await settle(t, rounds: 10);

      expect(container.read(selectedMeetingProvider), isNull);
      expect(find.byType(MeetingDetailScreen), findsNothing);
      expect(find.text(S.selectMeetingTitle), findsOneWidget);
      expect(find.text(S.meetingDeleted), findsOneWidget);
      await env.dispose(t);
    });
  });

  group('recording screen', () {
    testWidgets('fits a landscape phone and keeps Stop reachable', (t) async {
      setScreenSize(t, const Size(780, 360));
      final env = UiTestEnv();
      await startRecording(t, env);
      expect(t.takeException(), isNull);
      final stop = find.widgetWithText(FilledButton, S.stop);
      expect(stop, findsOneWidget);
      // Fully on screen and hit-testable.
      final r = t.getRect(stop);
      expect(r.bottom, lessThanOrEqualTo(360));
      expect(r.top, greaterThanOrEqualTo(0));
      await t.tap(stop);
      await settle(t);
      expect(find.text(S.confirmStopTitle), findsOneWidget);
      await t.tap(find.text(S.cancel));
      await settle(t);
      await env.dispose(t);
    });

    testWidgets('fits a small portrait phone', (t) async {
      setScreenSize(t, const Size(320, 520));
      final env = UiTestEnv();
      await startRecording(t, env);
      expect(t.takeException(), isNull);
      final stop = find.widgetWithText(FilledButton, S.stop);
      expect(t.getRect(stop).bottom, lessThanOrEqualTo(520));
      await env.dispose(t);
    });

    testWidgets('Space on a focused button activates it, not pause', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await startRecording(t, env);
      final container = ProviderScope.containerOf(
        t.element(find.byType(RecordingScreen)),
      );

      // The screen itself focused: Space toggles pause.
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(t);
      expect(
        container.read(meetingSessionControllerProvider).phase,
        SessionPhase.paused,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(t);
      expect(
        container.read(meetingSessionControllerProvider).phase,
        SessionPhase.recording,
      );

      // Stop focused: Space opens the stop confirmation.
      Focus.of(t.element(find.text(S.stop))).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(t);
      expect(
        container.read(meetingSessionControllerProvider).phase,
        SessionPhase.recording,
      );
      expect(find.text(S.confirmStopTitle), findsOneWidget);
      await t.tap(find.text(S.cancel));
      await settle(t);
      await env.dispose(t);
    });

    testWidgets('a take ended by the system while a dialog is open replaces '
        'the recording screen', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await startRecording(t, env);
      env.audio.emit(voiceSamples(0, 2000));
      await settle(t, rounds: 10);

      await t.tap(find.widgetWithText(FilledButton, S.stop));
      await settle(t);
      expect(find.text(S.confirmStopTitle), findsOneWidget);

      env.audio.endBySystem();
      await settle(t, rounds: 20);
      expect(find.byType(MeetingDetailScreen), findsOneWidget);
      expect(find.text(S.confirmStopTitle), findsNothing);
      // The recording screen is gone, not left under the meeting page.
      expect(find.byType(RecordingScreen, skipOffstage: false), findsNothing);

      await popTop(t);
      await settle(t);
      expect(find.byType(MeetingsScreen), findsOneWidget);
      expect(find.text(S.noActiveRecording), findsNothing);
      await env.dispose(t);
    });

    testWidgets('renaming during the recording updates the recording bar', (
      t,
    ) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await startRecording(t, env);

      await t.tap(find.byTooltip(S.editTitle));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'مراجعة الميزانية');
      await t.tap(find.widgetWithText(FilledButton, S.save).last);
      await settle(t, rounds: 10);

      await popTop(t);
      await settle(t, rounds: 10);
      final bar = find.ancestor(
        of: find.text(S.backToRecording),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: bar.first, matching: find.text('مراجعة الميزانية')),
        findsOneWidget,
      );
      await env.dispose(t);
    });

    testWidgets('the recording bar applies the status-bar inset once', (
      t,
    ) async {
      setScreenSize(t, kPhone);
      t.view.padding = const FakeViewPadding(top: 30);
      addTearDown(t.view.resetPadding);
      final env = UiTestEnv();
      await startRecording(t, env);
      await popTop(t);
      await settle(t, rounds: 10);
      expect(find.text(S.backToRecording), findsOneWidget);

      final appBar = find.descendant(
        of: find.byType(MeetingsScreen),
        matching: find.byType(AppBar),
      );
      expect(MediaQuery.paddingOf(t.element(appBar)).top, 0);
      // The bar itself sits below the status bar.
      expect(t.getTopLeft(find.text(S.backToRecording)).dy, greaterThan(30));
      await env.dispose(t);
    });
  });

  group('share gateway', () {
    late Directory root;
    late Directory temp;
    late Directory exports;

    setUp(() {
      root = Directory.systemTemp.createTempSync('insato_share_');
      temp = Directory('${root.path}/share')..createSync();
      exports = Directory('${root.path}/exports')..createSync();
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('mobile share files are removed after sharing', () async {
      final seen = <bool>[];
      final g = DefaultShareGateway(
        exportsDir: () async => exports.path,
        shareTempDir: () async => temp.path,
        isMobile: true,
        share: (ShareParams params) async {
          seen.add(File(params.files!.single.path).existsSync());
        },
      );
      final r = await g.shareFile(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'محضر.md',
        mimeType: 'text/markdown',
      );
      expect(seen, [true]);
      expect(r.shared, isTrue);
      expect(r.savedPath, isNull);
      expect(temp.listSync(), isEmpty);
      expect(exports.listSync(), isEmpty);
    });

    test('a failed mobile share leaves no file and reports no path', () async {
      final g = DefaultShareGateway(
        exportsDir: () async => exports.path,
        shareTempDir: () async => temp.path,
        isMobile: true,
        share: (_) async => throw StateError('no share sheet'),
      );
      final r = await g.shareFile(
        bytes: Uint8List.fromList([1]),
        fileName: 'a.pdf',
        mimeType: 'application/pdf',
      );
      expect(r.shared, isFalse);
      expect(r.savedPath, isNull);
      expect(temp.listSync(), isEmpty);
    });

    test('leftover mobile copies from older builds are purged', () async {
      File('${exports.path}/old.md').writeAsStringSync('secret');
      File('${temp.path}/stale.pdf').writeAsStringSync('secret');
      final g = DefaultShareGateway(
        exportsDir: () async => exports.path,
        shareTempDir: () async => temp.path,
        isMobile: true,
        share: (_) async {},
      );
      await g.purgeStale();
      expect(exports.listSync(), isEmpty);
      expect(temp.listSync(), isEmpty);
    });

    test('desktop keeps the saved copy and reports its path', () async {
      final g = DefaultShareGateway(
        exportsDir: () async => exports.path,
        shareTempDir: () async => temp.path,
        isMobile: false,
        share: (_) async {},
      );
      await g.purgeStale();
      final r = await g.shareFile(
        bytes: Uint8List.fromList([1]),
        fileName: 'a.md',
        mimeType: 'text/markdown',
      );
      expect(r.savedPath, '${exports.path}/a.md');
      expect(File(r.savedPath!).existsSync(), isTrue);
    });
  });
}
