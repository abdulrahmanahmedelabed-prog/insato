import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';

Float32List vec(List<double> v) => Float32List.fromList(v);

double norm(Float32List v) =>
    math.sqrt(v.fold<double>(0, (s, x) => s + x * x));

Minutes sampleMinutes() => Minutes(
      title: 'اجتماع الميزانية',
      summary: 'ملخص',
      attendees: const ['أحمد', 'سارة'],
      topics: const [
        MinutesTopic(
            title: 'الميزانية', discussion: 'نقاش', speakerNames: ['أحمد']),
      ],
      decisions: const [MinutesDecision(text: 'اعتماد', proposedBy: 'سارة')],
      actionItems: const [
        ActionItem(task: 'إرسال التقرير', owner: 'أحمد', dueDate: 'الخميس'),
      ],
      openQuestions: const ['متى؟'],
      languagesDetected: const ['العربية', 'الإنجليزية'],
      generatedAt: DateTime.utc(2026, 11, 19, 12),
      model: 'claude-opus-5-5',
      nextMeeting: 'الأحد',
    );

void main() {
  late AppDatabase db;
  late MeetingRepository meetings;
  late SegmentRepository segments;
  late SpeakerRepository speakers;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    meetings = MeetingRepository(db);
    segments = SegmentRepository(db);
    speakers = SpeakerRepository(db);
  });
  tearDown(() => db.close());

  TranscriptSegment seg(String meetingId, int i,
          {String? speakerId,
          Float32List? embedding,
          bool locked = false,
          String id = ''}) =>
      TranscriptSegment(
        id: id,
        meetingId: meetingId,
        index: i,
        startMs: i * 1000,
        endMs: i * 1000 + 900,
        text: 'نص $i',
        speakerId: speakerId,
        language: 'ar',
        embedding: embedding,
        speakerLocked: locked,
      );

  group('pure helpers', () {
    test('parseAutoSpeakerNumber', () {
      expect(parseAutoSpeakerNumber('متحدث 3'), 3);
      expect(parseAutoSpeakerNumber(' متحدث 12 '), 12);
      expect(parseAutoSpeakerNumber('متحدث ٤'), 4);
      expect(parseAutoSpeakerNumber('متحدث ۱۵'), 15);
      expect(parseAutoSpeakerNumber('أحمد'), isNull);
      expect(parseAutoSpeakerNumber('متحدث'), isNull);
      expect(parseAutoSpeakerNumber('متحدث 2 أحمد'), isNull);
    });

    test('nextAutoSpeakerNumber picks smallest unused', () {
      expect(nextAutoSpeakerNumber(const []), 1);
      expect(nextAutoSpeakerNumber(const ['متحدث 1', 'متحدث 2']), 3);
      expect(nextAutoSpeakerNumber(const ['متحدث 1', 'متحدث 3', 'سارة']), 2);
    });

    test('pickSpeakerColor chooses least used, palette order on ties', () {
      expect(pickSpeakerColor(const []), kSpeakerPalette[0]);
      expect(pickSpeakerColor([kSpeakerPalette[0]]), kSpeakerPalette[1]);
      expect(pickSpeakerColor(kSpeakerPalette), kSpeakerPalette[0]);
      expect(
          pickSpeakerColor([...kSpeakerPalette, kSpeakerPalette[0]]),
          kSpeakerPalette[1]);
      expect(kSpeakerPalette.toSet().length, kSpeakerPalette.length);
    });

    test('combineVoiceprints weights by count and normalises', () {
      final r = combineVoiceprints(vec([1, 0]), 3, vec([0, 1]), 1);
      expect(r.count, 4);
      expect(r.centroid![0], closeTo(3 / math.sqrt(10), 1e-6));
      expect(r.centroid![1], closeTo(1 / math.sqrt(10), 1e-6));
      expect(norm(r.centroid!), closeTo(1, 1e-6));
    });

    test('combineVoiceprints handles missing sides and caps count', () {
      expect(combineVoiceprints(null, 0, null, 0).centroid, isNull);
      final onlyB = combineVoiceprints(null, 5, vec([3, 4]), 7);
      expect(onlyB.count, 7);
      expect(onlyB.centroid![0], closeTo(0.6, 1e-6));
      final capped = combineVoiceprints(vec([1, 0]), 150, vec([1, 0]), 150);
      expect(capped.count, kMaxVoiceprintEmbeddingCount);
      final mismatch = combineVoiceprints(vec([1, 0, 0]), 2, vec([0, 1]), 9);
      expect(mismatch.centroid!.length, 2);
    });

    test('defaultMeetingTitle', () {
      expect(defaultMeetingTitle(DateTime(2026, 3, 7, 9, 5)),
          'اجتماع 2026/03/07 09:05');
    });
  });

  group('MeetingRepository', () {
    test('create and get', () async {
      final m = await meetings.create(title: '  مراجعة  ');
      expect(m.title, 'مراجعة');
      expect(m.status, MeetingStatus.recording);
      final got = await meetings.get(m.id);
      expect(got!.title, 'مراجعة');
      expect(got.createdAt.millisecondsSinceEpoch,
          m.createdAt.millisecondsSinceEpoch);
      expect(await meetings.get('nope'), isNull);
    });

    test('default title when blank', () async {
      final t = DateTime(2026, 1, 2, 3, 4);
      final m = await meetings.create(title: ' ', createdAt: t);
      expect(m.title, defaultMeetingTitle(t));
    });

    test('watchAll is newest first and live', () async {
      final base = DateTime(2026, 1, 1);
      await meetings.create(title: 'a', createdAt: base);
      await meetings.create(
          title: 'b', createdAt: base.add(const Duration(milliseconds: 5)));
      final stream = meetings.watchAll();
      expect((await stream.first).map((m) => m.title), ['b', 'a']);
      final later = expectLater(
          stream.map((l) => l.map((m) => m.title).toList()),
          emitsThrough(['c', 'b', 'a']));
      await meetings.create(title: 'c', createdAt: base.add(const Duration(days: 1)));
      await later;
      expect((await meetings.getAll()).length, 3);
    });

    test('updates title, status, duration, audio path, error', () async {
      final m = await meetings.create(title: 't');
      expect(await meetings.updateTitle(m.id, ' جديد '), isTrue);
      expect(await meetings.updateTitle(m.id, '   '), isFalse);
      await meetings.setDuration(m.id, 65000);
      await meetings.setAudioPath(m.id, '/x/a.wav');
      await meetings.setError(m.id, 'خطأ');
      var got = (await meetings.get(m.id))!;
      expect(got.title, 'جديد');
      expect(got.durationMs, 65000);
      expect(got.audioPath, '/x/a.wav');
      expect(got.status, MeetingStatus.failed);
      expect(got.errorMessage, 'خطأ');

      await meetings.updateStatus(m.id, MeetingStatus.processing);
      got = (await meetings.get(m.id))!;
      expect(got.status, MeetingStatus.processing);
      expect(got.errorMessage, isNull);

      await meetings.setAudioPath(m.id, null);
      expect((await meetings.get(m.id))!.audioPath, isNull);
      expect(await meetings.updateTitle('missing', 'x'), isFalse);
    });

    test('saveMinutes round-trips and marks ready', () async {
      final m = await meetings.create();
      await meetings.setError(m.id, 'فشل');
      await meetings.saveMinutes(m.id, sampleMinutes());
      final got = (await meetings.get(m.id))!;
      expect(got.status, MeetingStatus.ready);
      expect(got.errorMessage, isNull);
      expect(got.minutes!.toJson(), sampleMinutes().toJson());

      await meetings.clearMinutes(m.id);
      expect((await meetings.get(m.id))!.minutes, isNull);
    });

    test('corrupt minutes JSON reads as no minutes', () async {
      final m = await meetings.create();
      await db.customStatement(
          "UPDATE meetings SET minutes_json = '{not json' WHERE id = ?",
          [m.id]);
      expect((await meetings.get(m.id))!.minutes, isNull);
    });

    test('watch emits updates and null after delete', () async {
      final m = await meetings.create(title: 'x');
      final s = meetings.watch(m.id);
      expect((await s.first)!.title, 'x');
      final expectation = expectLater(
          s.map((m) => m?.title), emitsInOrder(['x', 'y', null]));
      await Future<void>.delayed(Duration.zero);
      await meetings.updateTitle(m.id, 'y');
      await Future<void>.delayed(Duration.zero);
      await meetings.delete(m.id);
      await expectation;
    });

    test('delete cascades to segments and removes audio file', () async {
      final dir = await Directory.systemTemp.createTemp('insato_test');
      addTearDown(() => dir.delete(recursive: true));
      final wav = File('${dir.path}/m.wav')..writeAsBytesSync([1, 2, 3]);

      final m = await meetings.create();
      final other = await meetings.create();
      await meetings.setAudioPath(m.id, wav.path);
      await segments.insert(seg(m.id, 0));
      await segments.insert(seg(m.id, 1));
      await segments.insert(seg(other.id, 0));

      expect(await meetings.delete(m.id), isTrue);
      expect(await meetings.get(m.id), isNull);
      expect(await segments.getForMeeting(m.id), isEmpty);
      expect(await segments.getForMeeting(other.id), hasLength(1));
      expect(wav.existsSync(), isFalse);
      expect(await meetings.delete(m.id), isFalse);
    });

    test('delete tolerates a missing audio file', () async {
      final m = await meetings.create();
      await meetings.setAudioPath(m.id, '/nonexistent/insato/a.wav');
      expect(await meetings.delete(m.id), isTrue);
    });
  });

  group('SegmentRepository', () {
    late Meeting m;
    setUp(() async => m = await meetings.create());

    test('insert generates ids and round-trips embeddings', () async {
      final e = vec([0.1, -0.2, 0.3, 0.9]);
      final s = await segments.insert(seg(m.id, 0, embedding: e));
      expect(s.id, isNotEmpty);
      final got = (await segments.get(s.id))!;
      expect(got.embedding, e);
      expect(got.text, 'نص 0');
      expect(got.language, 'ar');
      expect(got.startMs, 0);
      expect(got.endMs, 900);
      expect(got.speakerLocked, isFalse);

      final kept = await segments.insert(seg(m.id, 1, id: 'fixed'));
      expect(kept.id, 'fixed');
      await expectLater(segments.insert(seg(m.id, 2, id: 'fixed')),
          throwsA(isA<SqliteException>()));
    });

    test('getForMeeting/watchForMeeting order by index', () async {
      await segments.insertAll([seg(m.id, 2), seg(m.id, 0), seg(m.id, 1)]);
      expect((await segments.getForMeeting(m.id)).map((s) => s.index),
          [0, 1, 2]);
      final stream = segments.watchForMeeting(m.id);
      expect((await stream.first).length, 3);
      final later = expectLater(
          stream.map((l) => l.length), emitsThrough(4));
      await segments.insert(seg(m.id, 3));
      await later;
      expect(await segments.nextIndex(m.id), 4);
      expect(await segments.nextIndex('empty'), 0);
    });

    test('update, updateText, reassignSpeaker', () async {
      final a = await speakers.create();
      final b = await speakers.create();
      final s = await segments.insert(seg(m.id, 0, speakerId: a.id));
      expect(await segments.updateText(s.id, 'مصحح'), isTrue);
      expect(await segments.reassignSpeaker(s.id, b.id), isTrue);
      var got = (await segments.get(s.id))!;
      expect(got.text, 'مصحح');
      expect(got.speakerId, b.id);
      expect(got.speakerLocked, isTrue);

      await segments.reassignSpeaker(s.id, null, locked: false);
      got = (await segments.get(s.id))!;
      expect(got.speakerId, isNull);
      expect(got.speakerLocked, isFalse);

      final updated = TranscriptSegment(
        id: s.id,
        meetingId: m.id,
        index: 5,
        startMs: 10,
        endMs: 20,
        text: 'كامل',
        speakerId: a.id,
        language: 'en',
        embedding: vec([1, 2]),
      );
      expect(await segments.update(updated), isTrue);
      got = (await segments.get(s.id))!;
      expect(got.index, 5);
      expect(got.text, 'كامل');
      expect(got.language, 'en');
      expect(got.embedding, vec([1, 2]));
      expect(got.speakerId, a.id);
      expect(await segments.updateText('missing', 'x'), isFalse);
    });

    test('bulkAssignSpeakers respects locks by default', () async {
      final a = await speakers.create();
      final b = await speakers.create();
      final s0 = await segments.insert(seg(m.id, 0, speakerId: a.id));
      final s1 =
          await segments.insert(seg(m.id, 1, speakerId: a.id, locked: true));
      final s2 = await segments.insert(seg(m.id, 2));

      final n = await segments
          .bulkAssignSpeakers({s0.id: b.id, s1.id: b.id, s2.id: b.id});
      expect(n, 2);
      final byId = {for (final s in await segments.getForMeeting(m.id)) s.id: s};
      expect(byId[s0.id]!.speakerId, b.id);
      expect(byId[s1.id]!.speakerId, a.id);
      expect(byId[s2.id]!.speakerId, b.id);

      final forced = await segments
          .bulkAssignSpeakers({s1.id: b.id}, respectLocked: false);
      expect(forced, 1);
      expect((await segments.get(s1.id))!.speakerId, b.id);
      expect(await segments.bulkAssignSpeakers({}), 0);
    });

    test('rejects unknown speaker ids (foreign key)', () async {
      await expectLater(segments.insert(seg(m.id, 0, speakerId: 'ghost')),
          throwsA(isA<SqliteException>()));
    });

    test('delete', () async {
      final s = await segments.insert(seg(m.id, 0));
      expect(await segments.delete(s.id), isTrue);
      expect(await segments.get(s.id), isNull);
    });
  });

  group('SpeakerRepository', () {
    test('auto-naming sequence and distinct colors', () async {
      final s1 = await speakers.create();
      final s2 = await speakers.create();
      final s3 = await speakers.create();
      expect([s1.name, s2.name, s3.name], ['متحدث 1', 'متحدث 2', 'متحدث 3']);
      expect({s1.colorValue, s2.colorValue, s3.colorValue}.length, 3);
      expect(s1.isNamedByUser, isFalse);

      await speakers.rename(s2.id, 'سارة');
      final s4 = await speakers.create();
      expect(s4.name, 'متحدث 2');

      await speakers.delete(s1.id);
      final s5 = await speakers.create();
      expect(s5.name, 'متحدث 1');
      final s6 = await speakers.create();
      expect(s6.name, 'متحدث 4');
    });

    test('create with explicit name and centroid', () async {
      final c = vec([0.6, 0.8]);
      final s = await speakers.create(
          name: 'خالد', centroid: c, embeddingCount: 4);
      expect(s.isNamedByUser, isTrue);
      final got = (await speakers.get(s.id))!;
      expect(got.name, 'خالد');
      expect(got.centroid, c);
      expect(got.embeddingCount, 4);
      expect(got.isNamedByUser, isTrue);
    });

    test('concurrent creates get unique names', () async {
      final list = await Future.wait(List.generate(6, (_) => speakers.create()));
      expect(list.map((s) => s.name).toSet().length, 6);
    });

    test('rename, getAll order, watchAll', () async {
      final a = await speakers.create(createdAt: DateTime(2026, 1, 1));
      final b = await speakers.create(createdAt: DateTime(2026, 1, 2));
      final stream = speakers.watchAll();
      expect((await stream.first).map((s) => s.id), [a.id, b.id]);
      final later = expectLater(stream.map((l) => l.first.name),
          emitsThrough('أحمد'));
      expect(await speakers.rename(a.id, '  أحمد '), isTrue);
      await later;
      final got = (await speakers.get(a.id))!;
      expect(got.isNamedByUser, isTrue);
      expect(() => speakers.rename(a.id, ' '), throwsArgumentError);
      expect(await speakers.rename('missing', 'x'), isFalse);
      expect((await speakers.getAllById()).keys, containsAll([a.id, b.id]));
    });

    test('updateVoiceprint and forgetVoice', () async {
      final s = await speakers.create();
      expect(s.centroid, isNull);
      expect(s.embeddingCount, 0);
      final c = vec([0.0, 1.0, 0.0]);
      await speakers.updateVoiceprint(s.id, c, 12);
      var got = (await speakers.get(s.id))!;
      expect(got.centroid, c);
      expect(got.embeddingCount, 12);

      await speakers.forgetVoice(s.id);
      got = (await speakers.get(s.id))!;
      expect(got.centroid, isNull);
      expect(got.embeddingCount, 0);
    });

    test('merge reassigns segments, combines centroids, deletes source',
        () async {
      final m1 = await meetings.create();
      final m2 = await meetings.create();
      final into = await speakers.create(centroid: vec([1, 0]), embeddingCount: 3);
      final from = await speakers.create(
          name: 'منى', centroid: vec([0, 1]), embeddingCount: 1);
      final other = await speakers.create();
      final a = await segments.insert(seg(m1.id, 0, speakerId: from.id, locked: true));
      final b = await segments.insert(seg(m2.id, 0, speakerId: from.id));
      final c = await segments.insert(seg(m1.id, 1, speakerId: other.id));

      final merged = await speakers.merge(from.id, into.id);
      expect(merged.id, into.id);
      expect(merged.embeddingCount, 4);
      expect(merged.centroid![0], closeTo(3 / math.sqrt(10), 1e-6));
      expect(merged.centroid![1], closeTo(1 / math.sqrt(10), 1e-6));
      // Only the source had a user name, so the target adopts it.
      expect(merged.name, 'منى');
      expect(merged.isNamedByUser, isTrue);

      expect(await speakers.get(from.id), isNull);
      final stored = (await speakers.get(into.id))!;
      expect(stored.name, 'منى');
      expect(stored.centroid![0], closeTo(merged.centroid![0], 1e-6));
      expect(stored.embeddingCount, 4);

      expect((await segments.get(a.id))!.speakerId, into.id);
      expect((await segments.get(a.id))!.speakerLocked, isTrue);
      expect((await segments.get(b.id))!.speakerId, into.id);
      expect((await segments.get(c.id))!.speakerId, other.id);
    });

    test('merge keeps the target user name and handles missing centroid',
        () async {
      final into = await speakers.create(name: 'علي');
      final from = await speakers.create(
          name: 'Ali', centroid: vec([3, 4]), embeddingCount: 2);
      final merged = await speakers.merge(from.id, into.id);
      expect(merged.name, 'علي');
      expect(merged.centroid![0], closeTo(0.6, 1e-6));
      expect(merged.embeddingCount, 2);
    });

    test('merge errors and self-merge', () async {
      final a = await speakers.create();
      expect((await speakers.merge(a.id, a.id)).id, a.id);
      expect(await speakers.get(a.id), isNotNull);
      await expectLater(speakers.merge('ghost', a.id), throwsStateError);
      await expectLater(speakers.merge(a.id, 'ghost'), throwsStateError);
    });

    test('merge is atomic: failure leaves data untouched', () async {
      final m = await meetings.create();
      final a = await speakers.create();
      final s = await segments.insert(seg(m.id, 0, speakerId: a.id));
      await expectLater(speakers.merge(a.id, 'ghost'), throwsStateError);
      expect((await segments.get(s.id))!.speakerId, a.id);
      expect(await speakers.get(a.id), isNotNull);
    });

    test('delete sets segment speakers to null', () async {
      final m = await meetings.create();
      final a = await speakers.create();
      final s = await segments.insert(seg(m.id, 0, speakerId: a.id));
      expect(await speakers.delete(a.id), isTrue);
      expect((await segments.get(s.id))!.speakerId, isNull);
      expect(await speakers.delete(a.id), isFalse);
    });

    test('speakersForMeeting orders by first appearance', () async {
      final m = await meetings.create();
      final other = await meetings.create();
      final a = await speakers.create();
      final b = await speakers.create();
      final c = await speakers.create();
      await segments.insert(seg(m.id, 0, speakerId: b.id));
      await segments.insert(seg(m.id, 1, speakerId: a.id));
      await segments.insert(seg(m.id, 2, speakerId: b.id));
      await segments.insert(seg(m.id, 3));
      await segments.insert(seg(other.id, 0, speakerId: c.id));

      final list = await speakers.speakersForMeeting(m.id);
      expect(list.map((s) => s.id), [b.id, a.id]);
      expect(list.first.name, b.name);

      final stream = speakers.watchSpeakersForMeeting(m.id);
      expect((await stream.first).length, 2);
      final later = expectLater(stream.map((l) => l.map((s) => s.id).toList()),
          emitsThrough([b.id, a.id, c.id]));
      await segments.insert(seg(m.id, 4, speakerId: c.id));
      await later;
    });
  });
}
