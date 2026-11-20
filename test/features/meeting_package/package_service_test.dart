import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/pcm.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/meeting_package_store.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/meeting_package/package_audio.dart';
import 'package:insato/features/meeting_package/package_format.dart';
import 'package:insato/features/meeting_package/package_service.dart';
import 'package:insato/session/post_processor.dart';

import '../../session/fakes.dart' show memoryDb;
import '../multi_device/sim.dart';

const int _sr = 16000;

Future<void> _writeWav(String path, Float32List x) async {
  final bytes = float32ToPcm16Bytes(x);
  await File(path).writeAsBytes([
    ...buildWavHeader(sampleRate: _sr, channels: 1, dataBytes: bytes.length),
    ...bytes,
  ]);
}

/// One Insato installation: its own database and recordings folder.
class _Device {
  _Device(this.name, {bool background = true})
    : db = memoryDb(),
      dir = Directory.systemTemp.createTempSync('insato_pkg_dev') {
    meetings = MeetingRepository(db, recordingsDir: () async => dir.path);
    segments = SegmentRepository(db);
    speakers = SpeakerRepository(db);
    settings = AppSettings(db);
    post = PostProcessor(
      db: db,
      meetings: meetings,
      segments: segments,
      speakers: speakers,
      settings: settings,
    );
    service = MeetingPackageService(
      db: db,
      meetings: meetings,
      segments: segments,
      speakers: speakers,
      settings: settings,
      recordingsDir: () async => dir.path,
      refine: (id) async {
        refined.add(id);
        await post.refine(id);
      },
      device: PackageDevice(name: name, platform: 'android'),
      appVersion: '1.2.0-test',
      runInBackground: background,
    );
  }

  final String name;
  final AppDatabase db;
  final Directory dir;
  late final MeetingRepository meetings;
  late final SegmentRepository segments;
  late final SpeakerRepository speakers;
  late final AppSettings settings;
  late final PostProcessor post;
  late final MeetingPackageService service;
  final List<String> refined = [];

  Future<void> dispose() async {
    await db.close();
    dir.deleteSync(recursive: true);
  }

  List<String> files() =>
      [for (final f in dir.listSync()) f.uri.pathSegments.last]..sort();
}

TranscriptSegment _seg(
  String meetingId,
  int idx,
  int s,
  int e,
  String text,
  String? speaker,
) => TranscriptSegment(
  id: '',
  meetingId: meetingId,
  index: idx,
  startMs: s,
  endMs: e,
  text: text,
  speakerId: speaker,
  language: 'ar',
);

void main() {
  // The room: 80 s of speech-like audio heard by both devices.
  final room = mixSignals([
    (1, syntheticSpeech(_sr * 80, seed: 31)),
    (1, noise(_sr * 80, seed: 12)),
  ], _sr * 80);
  final t0 = DateTime(2026, 11, 20, 9, 0, 0);

  late _Device hq;
  late _Device field;
  late String mainId;
  late String remoteId;
  late Speaker sara;

  setUp(() async {
    hq = _Device('حاسوب المقر');
    field = _Device('هاتف ب');

    // Main meeting: the whole 80 s.
    sara = await hq.speakers.create(name: 'سارة');
    final m = await hq.meetings.create(
      title: 'الاجتماع الرئيسي',
      createdAt: t0,
      status: MeetingStatus.ready,
    );
    mainId = m.id;
    await _writeWav('${hq.dir.path}/${m.id}.wav', room);
    await hq.meetings.setAudioPath(m.id, '${m.id}.wav');
    await hq.meetings.setDuration(m.id, 80000);
    await hq.segments.insertAll([
      _seg(m.id, 0, 1000, 3000, 'افتتاح الاجتماع', sara.id),
      _seg(m.id, 1, 20000, 24000, 'نبدأ بمراجعة الميزانية', sara.id),
    ]);
    await hq.meetings.saveMinutes(
      m.id,
      Minutes(
        title: 'محضر',
        summary: 'ملخص',
        attendees: const ['سارة'],
        topics: const [],
        decisions: const [
          MinutesDecision(text: 'اعتماد الميزانية', evidence: [1]),
        ],
        actionItems: const [],
        openQuestions: const [],
        languagesDetected: const ['ar'],
        generatedAt: t0,
        model: 'test',
      ),
    );
    await hq.db
        .into(hq.db.tasks)
        .insert(
          TasksCompanion.insert(
            task: 'إعداد التقرير',
            sourceMeetingId: Value(m.id),
            evidenceSegmentIds: const Value('[1]'),
            createdAt: t0,
            updatedAt: t0,
          ),
        );

    // Field device: started 15 s after the main device, but its clock is
    // 7 s fast; recorded 40 s of the same room.
    final auto = await field.speakers.create();
    final r = await field.meetings.create(
      title: 'تسجيل الفريق الميداني',
      createdAt: t0.add(const Duration(seconds: 22)),
      status: MeetingStatus.ready,
    );
    remoteId = r.id;
    await _writeWav(
      '${field.dir.path}/${r.id}.wav',
      Float32List.fromList(
        Float32List.sublistView(
          room,
          15 * _sr,
          55 * _sr,
        ).map((x) => 0.5 * x).toList(),
      ),
    );
    await field.meetings.setAudioPath(r.id, '${r.id}.wav');
    await field.meetings.setDuration(r.id, 40000);
    await field.segments.insertAll([
      // Main time 17 s: only heard well by the field device.
      _seg(r.id, 0, 2000, 3500, 'تعليق من الفريق الميداني', auto.id),
      // Main time 20–24 s: the same utterance as the main segment #1.
      _seg(r.id, 1, 5050, 9000, 'نبدا بمراجعه الميزانيه', auto.id),
      // Main time 45 s.
      _seg(r.id, 2, 30000, 33000, 'سؤال عن الجدول الزمني', auto.id),
    ]);
  });

  tearDown(() async {
    await hq.dispose();
    await field.dispose();
  });

  Future<MeetingPackage> exportFromField({
    PackageExportOptions options = const PackageExportOptions(),
  }) async {
    final out = await field.service.export(
      remoteId,
      options,
      kdfIterations: 1000,
    );
    expect(out.fileName, endsWith('.insato'));
    expect(out.fileName, contains('تسجيل الفريق الميداني'));
    return hq.service.open(out.bytes, password: options.password);
  }

  test(
    'export carries times, SNR and the recording, not voiceprints',
    () async {
      final pkg = await exportFromField();
      expect(pkg.manifest.device.name, 'هاتف ب');
      expect(pkg.manifest.startedAt, t0.add(const Duration(seconds: 22)));
      expect(pkg.manifest.includes.voiceprints, isFalse);
      expect(pkg.segments, hasLength(3));
      expect(pkg.segments.every((s) => s.snrDb != null), isTrue);
      expect(pkg.audioWav, isNotNull);
      expect(pkg.speakers.single.centroid, isNull);
    },
  );

  test(
    'merge aligns by audio, interleaves, de-duplicates and remaps',
    () async {
      final pkg = await exportFromField();
      final preview = await hq.service.previewMerge(mainId, pkg);
      expect(preview.alignment.method, AlignmentMethod.audio);
      expect(preview.alignment.offsetMs, closeTo(15000, 5));
      expect(preview.alignment.clockErrorMs, closeTo(-7000, 5));
      expect(preview.overlapMs, closeTo(40000, 10));
      expect(preview.plan.duplicates, 1);
      expect(preview.plan.inserts, hasLength(2));
      expect(preview.newSpeakers, 1);

      final result = await hq.service.merge(mainId, pkg);
      expect(result.insertedSegments, 2);
      expect(hq.refined, [mainId]);

      final segs = await hq.segments.getForMeeting(mainId);
      expect(
        [for (final s in segs) s.text],
        [
          'افتتاح الاجتماع',
          'تعليق من الفريق الميداني',
          anyOf('نبدأ بمراجعة الميزانية', 'نبدا بمراجعه الميزانيه'),
          'سؤال عن الجدول الزمني',
        ],
      );
      expect([for (final s in segs) s.index], [0, 1, 2, 3]);
      expect(segs[1].startMs, closeTo(17000, 10));
      expect(segs[3].startMs, closeTo(45000, 10));

      // The remote speaker is a new device-tagged speaker; its segments keep
      // the remote attribution.
      final remoteSpeaker = await hq.speakers.get(segs[1].speakerId!);
      expect(remoteSpeaker!.name, 'متحدث 1 (جهاز: هاتف ب)');
      expect(segs[1].speakerLocked, isTrue);
      expect(segs[3].speakerId, remoteSpeaker.id);

      // Evidence of the minutes and tasks follow the renumbered segment.
      final m = (await hq.meetings.get(mainId))!;
      expect(m.minutes!.decisions.single.evidence, [2]);
      final task = await hq.db.select(hq.db.tasks).getSingle();
      expect(jsonDecode(task.evidenceSegmentIds), [2]);

      // A merged recording replaced the main one; the original is kept for
      // undo.
      expect(m.audioPath, isNot('$mainId.wav'));
      expect(hq.files(), containsAll(['$mainId.wav', m.audioPath]));
      expect(hq.files().where((f) => f.startsWith('import-')), isEmpty);
      final merged = await readWavInfo('${hq.dir.path}/${m.audioPath}');
      expect(merged.frameCount, 80 * _sr);
      expect(m.durationMs, 80000);
    },
  );

  test(
    'undo restores the meeting, references, speakers and recording',
    () async {
      final pkg = await exportFromField();
      await hq.service.merge(mainId, pkg);
      final latest = await hq.service.store.watchLatest(mainId).first;
      expect(latest!.deviceName, 'هاتف ب');
      final mergedAudio = (await hq.meetings.get(mainId))!.audioPath!;

      expect(await hq.service.undoLastMerge(mainId), isTrue);
      final segs = await hq.segments.getForMeeting(mainId);
      expect(
        [for (final s in segs) s.text],
        ['افتتاح الاجتماع', 'نبدأ بمراجعة الميزانية'],
      );
      expect([for (final s in segs) s.speakerId], [sara.id, sara.id]);
      final m = (await hq.meetings.get(mainId))!;
      expect(m.audioPath, '$mainId.wav');
      expect(m.minutes!.decisions.single.evidence, [1]);
      final task = await hq.db.select(hq.db.tasks).getSingle();
      expect(jsonDecode(task.evidenceSegmentIds), [1]);
      expect(hq.files(), isNot(contains(mergedAudio)));
      expect((await hq.speakers.getAll()).map((s) => s.name), ['سارة']);
      expect(await hq.service.store.watchLatest(mainId).first, isNull);
      expect(await hq.service.undoLastMerge(mainId), isFalse);
    },
  );

  test('voiceprints map a remote voice to the library', () async {
    // The field device knows the voice; the main device too (same person).
    final voice = Float32List.fromList([0.6, 0.8, 0, 0]);
    final fieldSpeaker = (await field.speakers.getAll()).single;
    await field.speakers.updateVoiceprint(fieldSpeaker.id, voice, 9);
    final known = await hq.speakers.create(
      name: 'منى',
      centroid: Float32List.fromList([0.62, 0.78, 0.01, 0]),
      embeddingCount: 20,
    );
    final pkg = await exportFromField(
      options: const PackageExportOptions(includeVoiceprints: true),
    );
    expect(pkg.speakers.single.centroid, voice);
    await hq.service.merge(mainId, pkg);
    final segs = await hq.segments.getForMeeting(mainId);
    expect(segs[1].speakerId, known.id);
    expect(segs[3].speakerId, known.id);
  });

  test('encrypted export needs the password', () async {
    final out = await field.service.export(
      remoteId,
      const PackageExportOptions(password: 'ميدان-2026', includeAudio: false),
      kdfIterations: 1000,
    );
    await expectLater(
      hq.service.open(out.bytes),
      throwsA(
        isA<PackageException>().having(
          (e) => e.kind,
          'kind',
          PackageErrorKind.passwordRequired,
        ),
      ),
    );
    final pkg = await hq.service.open(out.bytes, password: 'ميدان-2026');
    expect(pkg.encrypted, isTrue);
    expect(pkg.audioWav, isNull);
    // Without audio the wall clocks decide (7 s off here).
    final preview = await hq.service.previewMerge(mainId, pkg);
    expect(preview.alignment.method, AlignmentMethod.wallClock);
    expect(preview.alignment.offsetMs, 22000);
  });

  test('a package becomes a new meeting', () async {
    final pkg = await exportFromField(
      options: const PackageExportOptions(includeMinutes: false),
    );
    final id = await hq.service.importAsNewMeeting(pkg);
    final m = (await hq.meetings.get(id))!;
    expect(m.title, 'تسجيل الفريق الميداني');
    expect(m.createdAt, t0.add(const Duration(seconds: 22)));
    expect(m.status, MeetingStatus.ready);
    expect(m.audioPath, '$id.wav');
    expect(File('${hq.dir.path}/$id.wav').lengthSync(), pkg.audioWav!.length);
    final segs = await hq.segments.getForMeeting(id);
    expect(segs, hasLength(3));
    final sp = await hq.speakers.get(segs.first.speakerId!);
    expect(sp!.name, 'متحدث 1 (جهاز: هاتف ب)');
  });

  test('deleting a merged meeting removes the kept recordings', () async {
    final pkg = await exportFromField();
    await hq.service.merge(mainId, pkg);
    expect(hq.files().where((f) => f.endsWith('.wav')), hasLength(2));
    await hq.meetings.delete(mainId);
    expect(hq.files().where((f) => f.endsWith('.wav')), isEmpty);
    final keys = await hq.db.select(hq.db.settings).get();
    expect(
      keys.where((k) => k.key.startsWith(kMeetingPackageUndoKeyPrefix)),
      isEmpty,
    );
  });

  test('a meeting being recorded cannot be merged into', () async {
    final pkg = await exportFromField();
    await hq.meetings.updateStatus(mainId, MeetingStatus.recording);
    await expectLater(hq.service.merge(mainId, pkg), throwsA(anything));
    expect(await hq.segments.getForMeeting(mainId), hasLength(2));
  });
}
