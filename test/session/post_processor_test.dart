import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:katib/audio/wav_writer.dart';
import 'package:katib/core/errors.dart';
import 'package:katib/core/models.dart';
import 'package:katib/data/database.dart';
import 'package:katib/data/repositories.dart';
import 'package:katib/data/secure_settings.dart';
import 'package:katib/diarization/vector_math.dart';
import 'package:katib/session/post_processor.dart';

import 'fakes.dart';

void main() {
  late AppDatabase db;
  late MeetingRepository meetings;
  late SegmentRepository segments;
  late SpeakerRepository speakers;
  late AppSettings settings;
  late Meeting meeting;
  FakeMinutesEngine? minutesEngine;
  late FakeEnginesFactory engines;
  late PostProcessor post;
  late Directory tmp;

  setUp(() async {
    db = memoryDb();
    meetings = MeetingRepository(db);
    segments = SegmentRepository(db);
    speakers = SpeakerRepository(db);
    settings = AppSettings(db);
    minutesEngine = null;
    engines = FakeEnginesFactory();
    post = PostProcessor(
      db: db,
      meetings: meetings,
      segments: segments,
      speakers: speakers,
      settings: settings,
      minutesEngineFactory: () async {
        final e = minutesEngine;
        return e == null ? null : MinutesEngineHandle(e);
      },
      enginesFactory: engines,
    );
    meeting = await meetings.create(title: 'اجتماع الاختبار');
    tmp = await Directory.systemTemp.createTemp('katib_post_');
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  var seed = 0;
  Future<TranscriptSegment> addSeg(
    int index,
    int voice,
    String? speakerId, {
    int durMs = 2000,
    bool locked = false,
    bool embed = true,
  }) {
    final start = index * 3000;
    return segments.insert(
      TranscriptSegment(
        id: '',
        meetingId: meeting.id,
        index: index,
        startMs: start,
        endMs: start + durMs,
        text: 'جملة $index',
        speakerId: speakerId,
        embedding: embed ? embeddingOf(voice, ++seed) : null,
        speakerLocked: locked,
      ),
    );
  }

  Future<Map<int, String?>> speakerByIndex() async => {
    for (final s in await segments.getForMeeting(meeting.id))
      s.index: s.speakerId,
  };

  group('refine', () {
    test('fixes a live mislabel and keeps both speakers', () async {
      final a = await speakers.create();
      final b = await speakers.create();
      await addSeg(0, 0, a.id);
      await addSeg(1, 0, a.id);
      await addSeg(2, 1, b.id);
      await addSeg(3, 1, a.id); // live error: voice 1 labelled A
      await addSeg(4, 1, b.id);
      await addSeg(5, 0, a.id);
      final report = await post.refine(
        meeting.id,
        sessionCreatedSpeakerIds: {a.id, b.id},
      );
      final by = await speakerByIndex();
      expect(by, {0: a.id, 1: a.id, 2: b.id, 3: b.id, 4: b.id, 5: a.id});
      expect(report.clusters, 2);
      expect(report.relabeledSegments, 1);
      expect(report.createdSpeakerIds, isEmpty);
      expect(report.removedSpeakerIds, isEmpty);
      // Both new automatic speakers have ≥ 3 s of speech → voiceprints.
      final sa = (await speakers.get(a.id))!;
      final sb = (await speakers.get(b.id))!;
      expect(sa.embeddingCount, 3);
      expect(sb.embeddingCount, 3);
      expect(cosine(sa.centroid!, voiceOf(0)), greaterThan(0.9));
      expect(cosine(sb.centroid!, voiceOf(1)), greaterThan(0.9));
      // Names untouched.
      expect(sa.name, 'متحدث 1');
      expect(sb.name, 'متحدث 2');
    });

    test(
      'merges a person split live and deletes the unused auto speaker',
      () async {
        final a = await speakers.create();
        final c = await speakers.create();
        await addSeg(0, 0, a.id);
        await addSeg(1, 0, c.id);
        await addSeg(2, 0, a.id);
        await addSeg(3, 0, c.id, durMs: 1000);
        final report = await post.refine(
          meeting.id,
          sessionCreatedSpeakerIds: {a.id, c.id},
        );
        expect((await speakerByIndex()).values.toSet(), {a.id});
        expect(report.removedSpeakerIds, [c.id]);
        expect(await speakers.get(c.id), isNull);
      },
    );

    test('links to a saved voiceprint and updates it', () async {
      final ahmed = await speakers.create(
        name: 'أحمد',
        centroid: voiceOf(2),
        embeddingCount: 10,
      );
      final d = await speakers.create(); // live failed to recognise him
      await addSeg(0, 2, d.id);
      await addSeg(1, 2, d.id);
      final report = await post.refine(
        meeting.id,
        sessionCreatedSpeakerIds: {d.id},
      );
      expect((await speakerByIndex()).values.toSet(), {ahmed.id});
      expect(report.removedSpeakerIds, [d.id]);
      final updated = (await speakers.get(ahmed.id))!;
      expect(updated.embeddingCount, 12);
      expect(updated.name, 'أحمد');
    });

    test('user-locked segments survive refinement', () async {
      final a = await speakers.create();
      final sara = await speakers.create(name: 'سارة');
      await addSeg(0, 0, a.id);
      await addSeg(1, 0, a.id);
      await addSeg(2, 0, sara.id, locked: true); // user insists
      await addSeg(3, 0, a.id);
      await post.refine(meeting.id, sessionCreatedSpeakerIds: {a.id});
      final segs = await segments.getForMeeting(meeting.id);
      expect(segs[2].speakerId, sara.id);
      expect(segs[2].speakerLocked, isTrue);
    });

    test('creates a speaker for a cluster nobody owns', () async {
      final ahmed = await speakers.create(
        name: 'أحمد',
        centroid: voiceOf(2),
        embeddingCount: 10,
      );
      // An unknown voice was wrongly attributed to Ahmed live.
      await addSeg(0, 2, ahmed.id);
      await addSeg(1, 3, ahmed.id);
      await addSeg(2, 3, ahmed.id);
      final report = await post.refine(meeting.id);
      expect(report.createdSpeakerIds, hasLength(1));
      final created = report.createdSpeakerIds.single;
      expect(await speakerByIndex(), {0: ahmed.id, 1: created, 2: created});
      expect((await speakers.get(created))!.name, 'متحدث 1');
    });

    test('short-lived new speakers get no voiceprint yet', () async {
      final a = await speakers.create();
      final b = await speakers.create();
      await addSeg(0, 0, a.id, durMs: 2000);
      await addSeg(1, 0, a.id, durMs: 2000);
      await addSeg(2, 1, b.id, durMs: 1500); // < 3 s in total
      await post.refine(meeting.id, sessionCreatedSpeakerIds: {a.id, b.id});
      expect((await speakers.get(a.id))!.centroid, isNotNull);
      final sb = (await speakers.get(b.id))!;
      expect(sb.centroid, isNull);
      expect(sb.embeddingCount, 0);
    });

    test(
      'running refinement twice does not double-count voiceprints',
      () async {
        final a = await speakers.create();
        await addSeg(0, 0, a.id);
        await addSeg(1, 0, a.id);
        await post.refine(meeting.id, sessionCreatedSpeakerIds: {a.id});
        final first = (await speakers.get(a.id))!;
        await post.refine(meeting.id);
        final second = (await speakers.get(a.id))!;
        expect(second.embeddingCount, first.embeddingCount);
        expect(cosine(second.centroid!, first.centroid!), closeTo(1, 1e-6));
      },
    );

    test('segments without embeddings follow removed speakers', () async {
      final a = await speakers.create();
      final c = await speakers.create();
      await addSeg(0, 0, a.id);
      await addSeg(1, 0, c.id);
      await addSeg(2, 0, c.id, durMs: 500, embed: false);
      await addSeg(3, 0, a.id);
      await post.refine(meeting.id, sessionCreatedSpeakerIds: {a.id, c.id});
      expect((await speakerByIndex()).values.toSet(), {a.id});
      expect(await speakers.get(c.id), isNull);
    });

    test('empty meeting is a no-op', () async {
      final r = await post.refine(meeting.id);
      expect(r.clusters, 0);
    });
  });

  group('corrections', () {
    test(
      'reassignSegment locks and moves the voiceprint contribution',
      () async {
        final a = await speakers.create(name: 'علي');
        final b = await speakers.create(name: 'منى');
        await addSeg(0, 0, a.id);
        await addSeg(1, 0, a.id);
        final wrong = await addSeg(2, 1, a.id);
        await addSeg(3, 1, b.id);
        await post.learnFromCorrections(meeting.id);
        expect((await speakers.get(a.id))!.embeddingCount, 3);
        expect((await speakers.get(b.id))!.embeddingCount, 1);

        await post.reassignSegment(wrong.id, b.id);
        final seg = (await segments.get(wrong.id))!;
        expect(seg.speakerId, b.id);
        expect(seg.speakerLocked, isTrue);
        final sa = (await speakers.get(a.id))!;
        final sb = (await speakers.get(b.id))!;
        expect(sa.embeddingCount, 2);
        expect(sb.embeddingCount, 2);
        expect(
          cosine(sa.centroid!, voiceOf(0)),
          greaterThan(cosine(sa.centroid!, voiceOf(1))),
        );

        // Learning again changes nothing.
        final again = await post.learnFromCorrections(meeting.id);
        expect(again.updatedSpeakers, 0);
      },
    );

    test('rename and merge flows', () async {
      final a = await speakers.create();
      final b = await speakers.create();
      await addSeg(0, 0, a.id, durMs: 3000);
      await addSeg(1, 0, b.id, durMs: 3000);
      await post.learnFromCorrections(meeting.id);
      expect((await speakers.get(a.id))!.embeddingCount, 1);

      await expectLater(
        post.renameSpeaker(a.id, '   '),
        throwsA(isA<KatibException>()),
      );
      await expectLater(
        post.renameSpeaker('missing', 'س'),
        throwsA(isA<KatibException>()),
      );
      await post.renameSpeaker(b.id, ' خالد ');
      expect((await speakers.get(b.id))!.name, 'خالد');

      final merged = await post.mergeSpeakers(b.id, a.id);
      expect(merged.name, 'خالد'); // the user-given name is kept
      expect(merged.isNamedByUser, isTrue);
      expect((await speakerByIndex()).values.toSet(), {a.id});
      final count = (await speakers.get(a.id))!.embeddingCount;
      expect(count, 2);
      // The merged contribution is not learned a second time.
      await post.learnFromCorrections(meeting.id);
      expect((await speakers.get(a.id))!.embeddingCount, count);
      await expectLater(
        post.mergeSpeakers('x', a.id),
        throwsA(isA<KatibException>()),
      );
    });

    test('reassignSegment validates ids', () async {
      final a = await speakers.create();
      final s = await addSeg(0, 0, a.id);
      await expectLater(
        post.reassignSegment('nope', a.id),
        throwsA(isA<KatibException>()),
      );
      await expectLater(
        post.reassignSegment(s.id, 'nobody'),
        throwsA(isA<KatibException>()),
      );
      await post.reassignSegment(s.id, null);
      expect((await segments.get(s.id))!.speakerId, isNull);
    });

    test('deleteMeeting removes the ledger', () async {
      final a = await speakers.create(name: 'علي');
      await addSeg(0, 0, a.id);
      await post.learnFromCorrections(meeting.id);
      expect(await db.select(db.settings).get(), isNotEmpty);
      expect(await post.deleteMeeting(meeting.id), isTrue);
      expect(await db.select(db.settings).get(), isEmpty);
      expect((await speakers.get(a.id))!.embeddingCount, 1);
    });
  });

  group('minutes', () {
    test('regenerateMinutes saves minutes and marks ready', () async {
      final a = await speakers.create(name: 'هدى');
      await addSeg(0, 0, a.id);
      minutesEngine = FakeMinutesEngine();
      final progress = <String>[];
      final m = await post.regenerateMinutes(
        meeting.id,
        onProgress: (_, s) => progress.add(s),
      );
      expect(m.attendees, ['هدى']);
      expect(progress, isNotEmpty);
      final stored = (await meetings.get(meeting.id))!;
      expect(stored.status, MeetingStatus.ready);
      expect(stored.minutes!.summary, m.summary);
    });

    test('errors keep the transcript and set an Arabic error', () async {
      final a = await speakers.create();
      await addSeg(0, 0, a.id);
      minutesEngine = FakeMinutesEngine(
        fail: const MinutesGenerationException('تعذّر الاتصال بالخادم.'),
      );
      await expectLater(
        post.regenerateMinutes(meeting.id),
        throwsA(isA<MinutesGenerationException>()),
      );
      final stored = (await meetings.get(meeting.id))!;
      expect(stored.status, MeetingStatus.failed);
      expect(stored.errorMessage, 'تعذّر الاتصال بالخادم.');
      expect(await segments.getForMeeting(meeting.id), hasLength(1));

      // With previous minutes the meeting stays ready.
      minutesEngine = FakeMinutesEngine();
      await post.regenerateMinutes(meeting.id);
      minutesEngine = FakeMinutesEngine(
        fail: const MinutesGenerationException('خطأ'),
      );
      await expectLater(
        post.regenerateMinutes(meeting.id),
        throwsA(isA<MinutesGenerationException>()),
      );
      final kept = (await meetings.get(meeting.id))!;
      expect(kept.status, MeetingStatus.ready);
      expect(kept.minutes, isNotNull);
    });

    test('missing key / empty transcript', () async {
      await expectLater(
        post.regenerateMinutes(meeting.id),
        throwsA(isA<KatibException>()),
      );
      await meetings.updateStatus(meeting.id, MeetingStatus.processing);
      expect(
        await post.generateMinutesIfPossible(meeting.id),
        MinutesOutcome.skippedEmpty,
      );
      expect((await meetings.get(meeting.id))!.status, MeetingStatus.ready);

      final a = await speakers.create();
      await addSeg(0, 0, a.id);
      await expectLater(
        post.regenerateMinutes(meeting.id),
        throwsA(isA<MissingApiKeyException>()),
      );
      await meetings.updateStatus(meeting.id, MeetingStatus.processing);
      expect(
        await post.generateMinutesIfPossible(meeting.id),
        MinutesOutcome.skippedNoApiKey,
      );
      expect((await meetings.get(meeting.id))!.status, MeetingStatus.ready);

      minutesEngine = FakeMinutesEngine();
      expect(
        await post.generateMinutesIfPossible(meeting.id),
        MinutesOutcome.generated,
      );
    });
  });

  group('reprocessFromAudio', () {
    Future<String> writeWav(List<(int?, int)> parts) async {
      final path = '${tmp.path}/${meeting.id}.wav';
      final w = await WavWriter.open(path);
      for (final (voice, ms) in parts) {
        await w.appendFloat32(voiceSamples(voice, ms));
      }
      await w.close();
      await meetings.setAudioPath(meeting.id, path);
      return path;
    }

    test(
      're-transcribes, keeps locks by overlap, replaces atomically',
      () async {
        engines.segmenterBuilder = RunSegmenter.new;
        await writeWav([
          (0, 2000),
          (null, 500),
          (1, 2000),
          (null, 500),
          (0, 2000),
        ]);
        final sara = await speakers.create(name: 'سارة');
        // Old transcript: a locked segment covering the middle voice.
        await segments.insert(
          TranscriptSegment(
            id: '',
            meetingId: meeting.id,
            index: 0,
            startMs: 2400,
            endMs: 4600,
            text: 'قديم',
            speakerId: sara.id,
            speakerLocked: true,
          ),
        );
        await meetings.updateStatus(meeting.id, MeetingStatus.ready);
        final progress = <double>[];
        final report = await post.reprocessFromAudio(
          meeting.id,
          onProgress: (p, _) => progress.add(p),
        );
        expect(report.segments, 3);
        expect(report.failedSegments, 0);
        expect(report.durationMs, 7000);
        final segs = await segments.getForMeeting(meeting.id);
        expect(segs.map((s) => s.text), ['كلام 0', 'كلام 1', 'كلام 2']);
        expect(segs[1].speakerId, sara.id);
        expect(segs[1].speakerLocked, isTrue);
        expect(segs[0].speakerId, isNotNull);
        expect(segs[2].speakerId, segs[0].speakerId);
        expect(segs[0].speakerId, isNot(sara.id));
        expect(progress.last, 1.0);
        expect((await meetings.get(meeting.id))!.status, MeetingStatus.ready);
      },
    );

    test('fails cleanly without audio and keeps the transcript', () async {
      final a = await speakers.create();
      await addSeg(0, 0, a.id);
      await expectLater(
        post.reprocessFromAudio(meeting.id),
        throwsA(isA<KatibException>()),
      );
      expect(await segments.getForMeeting(meeting.id), hasLength(1));
    });

    test('model problems surface as ModelException', () async {
      await writeWav([(0, 2000)]);
      engines.notReady = const ModelException('النموذج غير مُنزَّل');
      await expectLater(
        post.reprocessFromAudio(meeting.id),
        throwsA(isA<ModelException>()),
      );
    });

    test('a corrupt archive is reported in Arabic', () async {
      final path = '${tmp.path}/bad.wav';
      await File(path).writeAsBytes(Uint8List.fromList(List.filled(10, 7)));
      await meetings.setAudioPath(meeting.id, path);
      await expectLater(
        post.reprocessFromAudio(meeting.id),
        throwsA(
          isA<KatibException>().having(
            (e) => e.messageAr,
            'messageAr',
            contains('تالف'),
          ),
        ),
      );
    });
  });

  test('recoverInterruptedMeetings finalises crashed meetings', () async {
    final a = await speakers.create();
    await addSeg(0, 0, a.id);
    await addSeg(1, 0, a.id);
    final processing = await meetings.create(
      title: 'معالجة',
      status: MeetingStatus.processing,
    );
    final withMinutes = await meetings.create(
      title: 'بمحضر',
      status: MeetingStatus.ready,
    );
    minutesEngine = FakeMinutesEngine();
    await segments.insert(
      TranscriptSegment(
        id: '',
        meetingId: withMinutes.id,
        index: 0,
        startMs: 0,
        endMs: 1000,
        text: 'نص',
      ),
    );
    await post.regenerateMinutes(withMinutes.id);
    await meetings.updateStatus(withMinutes.id, MeetingStatus.processing);

    final n = await post.recoverInterruptedMeetings();
    expect(n, 3);
    final m = (await meetings.get(meeting.id))!;
    expect(m.status, MeetingStatus.failed);
    expect(m.errorMessage, contains('انقطع التسجيل'));
    expect(m.durationMs, 5000);
    expect(await segments.getForMeeting(meeting.id), hasLength(2));
    expect((await meetings.get(processing.id))!.status, MeetingStatus.failed);
    expect((await meetings.get(withMinutes.id))!.status, MeetingStatus.ready);
    expect(await post.recoverInterruptedMeetings(), 0);
  });
}
