// Widget-test harness: the real app (or a single screen) over an in-memory
// database, fake secure settings, fake model states, fake sharing and the
// session fakes — no native plugin is touched.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/app.dart';
import 'package:insato/core/interfaces.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/context/strings.dart' show CS;
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/ui/services/connection_tester.dart';
import 'package:insato/ui/services/share_gateway.dart';
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../session/fakes.dart';

/// Records share / copy / print calls.
class FakeShareGateway implements ShareGateway {
  final List<String> copied = [];
  final List<String> sharedTexts = [];
  final List<String> sharedFiles = [];
  int prints = 0;

  @override
  Future<void> copyText(String text) async => copied.add(text);

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    sharedTexts.add(text);
    return const ShareOutcome(shared: true);
  }

  @override
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    Rect? origin,
  }) async {
    sharedFiles.add(fileName);
    return const ShareOutcome(shared: true);
  }

  @override
  Future<ShareOutcome> sharePdf({
    required Uint8List bytes,
    required String fileName,
    Rect? origin,
  }) async {
    sharedFiles.add(fileName);
    return const ShareOutcome(shared: true);
  }

  @override
  Future<bool> printPdf({
    required Future<Uint8List> Function() build,
    required String name,
  }) async {
    prints++;
    return true;
  }
}

/// Connection tester returning a fixed result.
class FakeConnectionTester extends ClaudeConnectionTester {
  FakeConnectionTester(this.result);

  final ConnectionTestResult result;
  final List<String> keys = [];

  @override
  Future<ConnectionTestResult> test(String apiKey, {String model = ''}) async {
    keys.add(apiKey);
    return result;
  }
}

/// Every model installed.
Map<String, ModelState> allModelsReady() => {
  for (final id in const [
    'silero-vad',
    'whisper-turbo',
    'whisper-medium',
    'whisper-small',
    'wespeaker-resnet34',
    '3dspeaker-eres2net-base',
  ])
    id: const ModelState(ModelStatus.ready),
};

/// Test environment with all fakes.
class UiTestEnv {
  UiTestEnv({Map<String, ModelState>? modelStates})
    : modelStates = modelStates ?? allModelsReady();

  final AppDatabase db = memoryDb();
  final FakeSecureSettings secure = FakeSecureSettings();
  final FakeShareGateway share = FakeShareGateway();
  final FakeAudioSource audio = FakeAudioSource();
  final FakeHooks hooks = FakeHooks();
  final FakeEnginesFactory engines = FakeEnginesFactory();
  final Directory tmp = Directory.systemTemp.createTempSync('insato_ui_');
  FakeMinutesEngine? minutes;
  FakeConnectionTester tester = FakeConnectionTester(
    const ConnectionTestResult(
      ok: true,
      messageAr: 'ok',
      model: 'claude-opus-5-5',
    ),
  );
  Map<String, ModelState> modelStates;

  /// Additional overrides of a test (applied last).
  final List<Override> extraOverrides = [];

  /// Provider overrides.
  List<Override> get overrides => [
    databaseProvider.overrideWithValue(db),
    secureSettingsProvider.overrideWithValue(secure),
    appPathsProvider.overrideWithValue(
      AppPaths(documentsDir: () async => tmp, supportDir: () async => tmp),
    ),
    modelStatesProvider.overrideWith((ref) => Stream.value(modelStates)),
    sessionAudioSourceProvider.overrideWithValue(audio),
    sessionPlatformHooksProvider.overrideWithValue(hooks),
    sessionEnginesFactoryProvider.overrideWithValue(engines),
    minutesEngineFactoryProvider.overrideWithValue(() async {
      final m = minutes;
      return m == null ? null : MinutesEngineHandle(m);
    }),
    shareGatewayProvider.overrideWithValue(share),
    claudeConnectionTesterProvider.overrideWithValue(tester),
    ...extraOverrides,
  ];

  /// Runs real-async database work from inside a widget test.
  Future<T> run<T>(WidgetTester t, Future<T> Function() f) async =>
      (await t.runAsync(f)) as T;

  /// Releases resources (call at the end of each test).
  Future<void> dispose(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(db.close);
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {
      // Best effort.
    }
  }
}

/// Sets the logical screen size (phone by default).
void setScreenSize(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// Phone size.
const Size kPhone = Size(420, 900);

/// Desktop size.
const Size kDesktop = Size(1400, 900);

/// Pumps the whole app.
Future<void> pumpApp(WidgetTester t, UiTestEnv env) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: env.overrides,
      retry: (_, _) => null,
      child: const InsatoApp(),
    ),
  );
  await settle(t);
}

/// Pumps [child] inside an Arabic RTL MaterialApp with the app theme.
Future<void> pumpScreen(WidgetTester t, UiTestEnv env, Widget child) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: env.overrides,
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

/// Pumps frames until database streams have delivered (drift's in-memory
/// executor completes on real async I/O boundaries).
Future<void> settle(WidgetTester t, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pump(const Duration(milliseconds: 16));
  }
  // Let route / dialog transitions finish.
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 16));
}

/// Taps the "new meeting" button and starts the recording from the
/// meeting-context form with "skip and start" (consent already given).
Future<void> startFromFab(WidgetTester t) async {
  await t.tap(find.byType(FloatingActionButton));
  await settle(t);
  await t.tap(find.text(CS.skipAndStart));
  await settle(t, rounds: 10);
}

/// A finished meeting with minutes, two speakers (one named) and a
/// bilingual transcript.
Future<({Meeting meeting, Speaker sara, Speaker auto})> seedMeeting(
  UiTestEnv env, {
  String title = 'اجتماع الميزانية',
  bool withMinutes = true,
}) async {
  final speakers = SpeakerRepository(env.db);
  final sara = await speakers.create(name: 'سارة');
  final auto = await speakers.create();
  final meetings = MeetingRepository(env.db);
  final m = await meetings.create(
    title: title,
    status: MeetingStatus.ready,
    createdAt: DateTime(2026, 11, 19, 10, 30),
  );
  await meetings.setDuration(m.id, 754000);
  final segs = SegmentRepository(env.db);
  await segs.insertAll([
    TranscriptSegment(
      id: '',
      meetingId: m.id,
      index: 0,
      startMs: 0,
      endMs: 4000,
      text: 'مرحبًا بكم في اجتماع الميزانية',
      speakerId: sara.id,
      language: 'ar',
    ),
    TranscriptSegment(
      id: '',
      meetingId: m.id,
      index: 1,
      startMs: 5000,
      endMs: 9000,
      text: 'We should finalize the marketing budget this week',
      speakerId: auto.id,
      language: 'en',
    ),
  ]);
  if (withMinutes) {
    await meetings.saveMinutes(
      m.id,
      Minutes(
        title: 'محضر اجتماع الميزانية',
        summary: 'ناقش الفريق ميزانية التسويق للربع القادم.',
        attendees: const ['سارة', 'متحدث 1'],
        topics: const [
          MinutesTopic(
            title: 'ميزانية التسويق',
            discussion: 'اقتُرح اعتماد الميزانية هذا الأسبوع.',
            speakerNames: ['سارة'],
          ),
        ],
        decisions: const [
          MinutesDecision(text: 'اعتماد ميزانية التسويق', proposedBy: 'سارة'),
        ],
        actionItems: const [
          ActionItem(
            task: 'إعداد تقرير الميزانية',
            owner: 'سارة',
            dueDate: 'الخميس',
          ),
        ],
        openQuestions: const ['موعد الإطلاق'],
        languagesDetected: const ['العربية', 'الإنجليزية'],
        generatedAt: DateTime(2026, 11, 19, 11),
        model: 'claude-opus-5-5',
      ),
    );
  }
  final meeting = (await meetings.get(m.id))!;
  return (meeting: meeting, sara: sara, auto: auto);
}
