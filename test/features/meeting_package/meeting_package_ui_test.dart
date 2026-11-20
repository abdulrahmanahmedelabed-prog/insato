import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/meeting_package/meeting_package.dart';
import 'package:insato/features/meeting_package/package_codec.dart';
import 'package:insato/features/meeting_package/package_format.dart';
import 'package:insato/features/meeting_package/package_service.dart';
import 'package:insato/features/meeting_package/package_ui.dart'
    show ExportPackageDialog;
import 'package:insato/session/providers.dart';
import 'package:insato/ui/screens/meeting_detail_screen.dart';
import 'package:insato/ui/screens/meetings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';

class _FakeFiles implements PackageFiles {
  PickedPackageFile? next;
  final List<(String, Uint8List)> saved = [];

  @override
  Future<PickedPackageFile?> pick() async => next;

  @override
  Future<PackageSaveResult> save({
    required Uint8List bytes,
    required String fileName,
    Rect? origin,
  }) async {
    saved.add((fileName, bytes));
    return const PackageSaveResult(done: true);
  }
}

UiTestEnv _env(_FakeFiles files) {
  final env = UiTestEnv();
  env.extraOverrides.addAll([
    packageFilesProvider.overrideWithValue(files),
    meetingPackageServiceProvider.overrideWith((ref) {
      final paths = ref.watch(appPathsProvider);
      return MeetingPackageService(
        db: ref.watch(databaseProvider),
        meetings: ref.watch(meetingRepositoryProvider),
        segments: ref.watch(segmentRepositoryProvider),
        speakers: ref.watch(speakerRepositoryProvider),
        settings: ref.watch(appSettingsProvider),
        recordingsDir: paths.recordingsDir,
        resolveRecording: paths.resolveRecording,
        refine: (id) => ref.read(postProcessorProvider).refine(id),
        device: const PackageDevice(name: 'جهاز المقر'),
        appVersion: 'test',
        runInBackground: false,
        kdfIterations: 1000,
      );
    }),
  ]);
  return env;
}

Future<Uint8List> _fieldPackage(DateTime startedAt, {String? password}) =>
    encodeMeetingPackage(
      MeetingPackage(
        manifest: PackageManifest(
          appVersion: 'test',
          schemaVersion: 6,
          exportedAt: startedAt.add(const Duration(hours: 1)),
          exportedMonotonicUs: 0,
          device: const PackageDevice(name: 'هاتف الميدان'),
          meetingId: 'remote',
          title: 'تسجيل الفريق الميداني',
          startedAt: startedAt,
          durationMs: 3000,
          includes: const PackageIncludes(
            audio: false,
            voiceprints: false,
            minutes: false,
          ),
        ),
        segments: const [
          PackageSegment(
            index: 0,
            startMs: 0,
            endMs: 2000,
            text: 'سؤال من الفريق الميداني',
            speakerKey: 'r1',
            language: 'ar',
          ),
        ],
        speakers: const [
          PackageSpeaker(
            key: 'r1',
            name: 'متحدث 1',
            colorValue: 0xFF1565C0,
            isNamedByUser: false,
          ),
        ],
      ),
      password: password,
      kdfIterations: 1000,
    );

Future<void> _openMenuItem(WidgetTester t, String label) async {
  await t.tap(find.byTooltip('المزيد'));
  await settle(t);
  await t.tap(find.text(label));
  await settle(t);
}

void main() {
  testWidgets('export dialog: voiceprints off by default, password checked', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final files = _FakeFiles();
    final env = _env(files);
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));

    await _openMenuItem(t, PS.exportEntry);
    expect(find.byType(ExportPackageDialog), findsOneWidget);
    expect(find.text(PS.voiceprintsWarning), findsOneWidget);
    final voice = t.widget<SwitchListTile>(
      find.byKey(const Key('package-include-voiceprints')),
    );
    expect(voice.value, isFalse);
    // No recording in this meeting: the audio switch is disabled.
    final audio = t.widget<SwitchListTile>(
      find.byKey(const Key('package-include-audio')),
    );
    expect(audio.onChanged, isNull);

    await t.enterText(find.byKey(const Key('package-password')), 'secret12');
    await t.pump();
    await t.enterText(
      find.byKey(const Key('package-password-confirm')),
      'secret13',
    );
    await t.tap(find.text(PS.exportAction));
    await t.pump();
    expect(find.text(PS.passwordMismatch), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('package-password-confirm')),
      'secret12',
    );
    await t.tap(find.text(PS.exportAction));
    await settleUntil(t, () => files.saved.isNotEmpty, reason: 'saved');

    final (name, bytes) = files.saved.single;
    expect(name, endsWith('.insato'));
    final pkg = await env.run(
      t,
      () => decodeMeetingPackage(bytes, password: 'secret12'),
    );
    expect(pkg.encrypted, isTrue);
    expect(pkg.manifest.title, 'اجتماع الميزانية');
    expect(pkg.manifest.includes.voiceprints, isFalse);
    expect(pkg.segments, hasLength(2));
    expect(find.text(PS.exported), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('import from the meetings screen as a new meeting', (t) async {
    setScreenSize(t, kPhone);
    final files = _FakeFiles();
    final env = _env(files);
    final bytes = await env.run(
      t,
      () => _fieldPackage(DateTime(2026, 11, 19, 11)),
    );
    files.next = PickedPackageFile('field.insato', bytes);
    await pumpScreen(t, env, MeetingsScreen(onOpen: (_) {}));

    // Phone width: the entry sits in the meetings-screen sources menu.
    await openSourcesMenu(t);
    await t.tap(find.text(PS.importTooltip).last);
    await settleUntil(
      t,
      () => find.text('هاتف الميدان').evaluate().isNotEmpty,
      reason: 'summary',
    );
    expect(find.text('تسجيل الفريق الميداني'), findsOneWidget);
    await t.tap(find.byKey(const Key('package-as-new')));
    await settleUntil(
      t,
      () async => (await MeetingRepository(env.db).getAll()).length == 1,
      reason: 'imported',
    );
    final m = (await env.run(
      t,
      () => MeetingRepository(env.db).getAll(),
    )).single;
    expect(m.title, 'تسجيل الفريق الميداني');
    final speakers = await env.run(t, () => SpeakerRepository(env.db).getAll());
    expect(speakers.single.name, 'متحدث 1 (جهاز: هاتف الميدان)');
    await env.dispose(t);
  });

  testWidgets('merge into a meeting: password, preview, regenerate, undo', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final files = _FakeFiles();
    final env = _env(files);
    final seeded = await env.run(t, () => seedMeeting(env));
    final bytes = await env.run(
      t,
      () => _fieldPackage(
        seeded.meeting.createdAt.add(const Duration(seconds: 6)),
        password: 'ميدان-2026',
      ),
    );
    files.next = PickedPackageFile('field.insato', bytes);
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));

    await _openMenuItem(t, PS.mergeEntry);
    await settleUntil(
      t,
      () => find.text(PS.passwordTitle).evaluate().isNotEmpty,
      reason: 'password prompt',
    );
    await t.enterText(find.byKey(const Key('package-open-password')), 'خطأ');
    await t.tap(find.text(PS.openAction));
    await settleUntil(
      t,
      () => find
          .text(PS.error(PackageErrorKind.wrongPassword))
          .evaluate()
          .isNotEmpty,
      reason: 'wrong password',
    );
    await t.enterText(
      find.byKey(const Key('package-open-password')),
      'ميدان-2026',
    );
    await t.tap(find.text(PS.openAction));
    await settleUntil(
      t,
      () => find.text(PS.previewTitle).evaluate().isNotEmpty,
      reason: 'preview',
    );
    expect(find.text('هاتف الميدان'), findsOneWidget);
    expect(find.text(PS.newSegments(1)), findsOneWidget);
    expect(find.text(PS.alignedByClock), findsOneWidget);
    expect(find.text(PS.speakersSummary(0, 1)), findsOneWidget);

    await t.tap(find.byKey(const Key('package-merge-confirm')));
    await settleUntil(
      t,
      () => find.text(PS.regenerateTitle).evaluate().isNotEmpty,
      reason: 'merged',
    );
    await t.tap(find.text(PS.later));
    await settle(t);
    final segs = await env.run(
      t,
      () => SegmentRepository(env.db).getForMeeting(seeded.meeting.id),
    );
    expect(
      [for (final s in segs) s.text],
      [
        'مرحبًا بكم في اجتماع الميزانية',
        'We should finalize the marketing budget this week',
        'سؤال من الفريق الميداني',
      ],
    );
    expect(segs.last.startMs, 6000);

    await _openMenuItem(t, PS.undoEntry);
    expect(find.text(PS.undoTitle), findsOneWidget);
    expect(find.text(PS.undoBody('هاتف الميدان')), findsOneWidget);
    await t.tap(find.byKey(const Key('package-undo-confirm')));
    await settleUntil(
      t,
      () async =>
          (await SegmentRepository(env.db).getForMeeting(seeded.meeting.id))
              .length ==
          2,
      reason: 'undone',
    );
    expect(find.text(PS.undone), findsOneWidget);
    await t.tap(find.byTooltip('المزيد'));
    await settle(t);
    expect(find.text(PS.undoEntry), findsNothing);
    await env.dispose(t);
  });

  testWidgets('a file that is not a package shows an Arabic error', (t) async {
    setScreenSize(t, kPhone);
    final files = _FakeFiles()
      ..next = PickedPackageFile('x.insato', Uint8List.fromList([1, 2, 3]));
    final env = _env(files);
    await pumpScreen(t, env, MeetingsScreen(onOpen: (_) {}));
    // Phone width: the entry sits in the meetings-screen sources menu.
    await openSourcesMenu(t);
    await t.tap(find.text(PS.importTooltip).last);
    await settleUntil(
      t,
      () => find
          .text(PS.error(PackageErrorKind.notAPackage))
          .evaluate()
          .isNotEmpty,
      reason: 'error',
    );
    await env.dispose(t);
  });
}
