// Widget tests of the recording import: the meetings-screen action, the
// confirmation with the legal reminder, the progress card (success, cancel)
// with the imported badge, and files shared to the app by other apps.
// Also the job controller end to end (import → minutes) over an in-memory
// database and fake engines.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/import_audio/import_audio.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/ui/screens/home_shell.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import '../../session/fakes.dart';
import '../../ui/harness.dart';

/// Inbox fake: [files] are handed over on the first take.
class FakeInbox implements SharedAudioInbox {
  FakeInbox(this.files);

  List<SharedAudioFile> files;
  final StreamController<void> _arrivals = StreamController.broadcast();

  @override
  Stream<void> get arrivals => _arrivals.stream;

  @override
  Future<List<SharedAudioFile>> takePending() async {
    final out = files;
    files = const [];
    return out;
  }

  void deliver(List<SharedAudioFile> f) {
    files = f;
    _arrivals.add(null);
  }
}

Float32List _conversation() {
  final parts = [
    voiceSamples(0, 2000),
    voiceSamples(null, 500),
    voiceSamples(1, 2000),
  ];
  final out = Float32List(parts.fold(0, (a, p) => a + p.length));
  var o = 0;
  for (final p in parts) {
    out.setRange(o, o + p.length, p);
    o += p.length;
  }
  return out;
}

Future<String> _wav(Directory dir, String name) async {
  final path = '${dir.path}/$name';
  final w = await WavWriter.open(path);
  await w.appendFloat32(_conversation());
  await w.close();
  return path;
}

UiTestEnv _env({String? pickedPath, SharedAudioInbox? inbox}) {
  final env = UiTestEnv();
  env.engines.segmenterBuilder = RunSegmenter.new;
  env.extraOverrides.addAll([
    nativeAudioDecoderProvider.overrideWithValue(null),
    sharedAudioInboxProvider.overrideWithValue(inbox),
    audioFilePickerProvider.overrideWithValue(
      () async => pickedPath == null
          ? null
          : PickedAudio(path: pickedPath, name: pickedPath.split('/').last),
    ),
  ]);
  return env;
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(HomeShell)));

Future<void> _confirmDialog(WidgetTester t) async {
  expect(find.text(IS.legalNotice), findsOneWidget);
  final start = find.widgetWithText(FilledButton, IS.startImport);
  expect(t.widget<FilledButton>(start).onPressed, isNull);
  final legal = find.byKey(const ValueKey('import-legal'));
  await t.ensureVisible(legal);
  await t.pump();
  await t.tap(legal);
  await t.pump();
  expect(t.widget<FilledButton>(start).onPressed, isNotNull);
  await t.tap(start);
  await settle(t);
}

void main() {
  testWidgets('import from the meetings screen: confirm, progress, badge', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final dir = Directory.systemTemp.createTempSync('insato_imp_ui_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = (await t.runAsync(() => _wav(dir, 'New Recording 3.wav')))!;
    final env = _env(pickedPath: path)..minutes = FakeMinutesEngine();
    await pumpApp(t, env);

    // Empty state offers the import next to "new meeting".
    expect(find.text(IS.importAction), findsOneWidget);
    await tapMeetingSource(t, IS.importTooltip);
    expect(find.text(IS.sourceFile('New Recording 3.wav')), findsOneWidget);
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('import-title')))
          .controller!
          .text,
      'New Recording 3',
    );
    await _confirmDialog(t);

    final container = _container(t);
    await settleUntil(
      t,
      () => container.read(importJobProvider).phase == ImportPhase.succeeded,
      reason: 'import finished',
    );
    expect(find.byKey(const ValueKey('import-progress-card')), findsOneWidget);
    expect(find.text(IS.done), findsOneWidget);
    expect(find.text(IS.importedBadge), findsOneWidget);
    expect(find.text('New Recording 3'), findsOneWidget);

    // Minutes follow automatically, as after a recording.
    final id = container.read(importJobProvider).meetingId!;
    await settleUntil(t, () async {
      final m = await MeetingRepository(env.db).get(id);
      return m?.minutes != null;
    }, reason: 'minutes generated');

    await t.tap(find.text(IS.dismiss));
    await settle(t);
    expect(find.byKey(const ValueKey('import-progress-card')), findsNothing);
    await env.dispose(t);
  });

  testWidgets('the running import can be cancelled', (t) async {
    setScreenSize(t, kPhone);
    final dir = Directory.systemTemp.createTempSync('insato_imp_ui_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = (await t.runAsync(() => _wav(dir, 'memo.wav')))!;
    final env = _env(pickedPath: path);
    final gate = Completer<void>();
    env.engines.asr = FakeAsr()..gate = gate;
    await pumpApp(t, env);

    await tapMeetingSource(t, IS.importTooltip);
    await _confirmDialog(t);
    final container = _container(t);
    await settleUntil(
      t,
      () => container.read(importJobProvider).progress > kDecodeProgressShare,
      reason: 'transcribing',
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await t.tap(find.text(IS.cancelImport));
    await t.pump();
    expect(container.read(importJobProvider).cancelling, isTrue);
    gate.complete();
    await settleUntil(
      t,
      () => container.read(importJobProvider).phase == ImportPhase.cancelled,
      reason: 'cancelled',
    );
    expect(find.text(IS.cancelled), findsOneWidget);
    final all = await env.run(t, () => MeetingRepository(env.db).getAll());
    expect(all, isEmpty);
    await env.dispose(t);
  });

  testWidgets('a refused file shows an Arabic error and no meeting', (t) async {
    setScreenSize(t, kPhone);
    final dir = Directory.systemTemp.createTempSync('insato_imp_ui_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/doc.mp3';
    File(path).writeAsBytesSync('%PDF-1.7'.codeUnits);
    final env = _env(pickedPath: path);
    await pumpApp(t, env);
    await tapMeetingSource(t, IS.importTooltip);
    await _confirmDialog(t);
    final container = _container(t);
    await settleUntil(
      t,
      () => container.read(importJobProvider).phase == ImportPhase.failed,
    );
    expect(find.text(IS.failedTitle), findsOneWidget);
    expect(find.text(IS.notAudio), findsOneWidget);
    expect(find.text(S.noMeetingsTitle), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('a file shared by another app is offered for import', (t) async {
    setScreenSize(t, kPhone);
    final dir = Directory.systemTemp.createTempSync('insato_imp_ui_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = (await t.runAsync(
      () => _wav(dir, 'Call recording Mona_241115_103012.wav'),
    ))!;
    final inbox = FakeInbox([
      SharedAudioFile(
        name: 'Call recording Mona_241115_103012.wav',
        path: path,
      ),
    ]);
    final env = _env(inbox: inbox);
    await pumpApp(t, env);
    expect(
      find.text(IS.sourceFile('Call recording Mona_241115_103012.wav')),
      findsOneWidget,
    );
    await _confirmDialog(t);
    final container = _container(t);
    await settleUntil(
      t,
      () => container.read(importJobProvider).phase == ImportPhase.succeeded,
    );
    final id = container.read(importJobProvider).meetingId!;
    final m = (await env.run(t, () => MeetingRepository(env.db).get(id)))!;
    expect(m.title, 'مكالمة: Mona');
    expect(m.createdAt, DateTime(2024, 11, 15, 10, 30, 12));
    // The share copy is removed after the import.
    expect(File(path).existsSync(), isFalse);

    // A failed hand-over is reported.
    inbox.deliver(const [SharedAudioFile(name: 'big.m4a', error: 'too_large')]);
    await settle(t);
    expect(find.text(IS.sharedTooLarge), findsOneWidget);
    await env.dispose(t);
  });

  test('the job refuses to run during a live recording', () async {
    final env = _env();
    final container = ProviderContainer(overrides: env.overrides);
    addTearDown(() async {
      container.dispose();
      await env.db.close();
      env.tmp.deleteSync(recursive: true);
    });
    final jobs = container.read(importJobProvider.notifier);
    expect(jobs.busyReason(), isNull);
    await container
        .read(meetingSessionControllerProvider.notifier)
        .start(consentGiven: true);
    expect(jobs.busyReason(), IS.recordingActive);
    final id = await jobs.start(const ImportRequest(path: '/x.wav'));
    expect(id, isNull);
    expect(container.read(importJobProvider).errorAr, IS.recordingActive);
    await container.read(meetingSessionControllerProvider.notifier).stop();
  });

  test('ImportInfo JSON round trip', () {
    final info = ImportInfo(
      fileName: 'a.m4a',
      format: 'M4A',
      codec: 'aac',
      sourceSampleRate: 44100,
      sourceChannels: 2,
      sizeBytes: 1234,
      importedAt: DateTime.utc(2026, 11, 20, 9),
      callRecording: true,
      viaShare: true,
    );
    final back = ImportInfo.fromJson(info.toJson())!;
    expect(back.fileName, 'a.m4a');
    expect(back.codec, 'aac');
    expect(back.sourceSampleRate, 44100);
    expect(back.sourceChannels, 2);
    expect(back.sizeBytes, 1234);
    expect(back.importedAt.toUtc(), DateTime.utc(2026, 11, 20, 9));
    expect(back.callRecording, isTrue);
    expect(back.viaShare, isTrue);
    expect(ImportInfo.fromJson({'file_name': 1}), isNull);
    expect(
      isImportedMeeting(
        Meeting(
          id: 'm',
          title: 't',
          createdAt: DateTime(2026),
          status: MeetingStatus.ready,
          inputDevice: kImportedInputDevice,
        ),
      ),
      isTrue,
    );
  });
}
