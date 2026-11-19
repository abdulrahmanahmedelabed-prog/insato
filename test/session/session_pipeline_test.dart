import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/diarization/speaker_tracker.dart';
import 'package:insato/session/meeting_session_controller.dart';

import 'fakes.dart';

void main() {
  late AppDatabase db;
  late MeetingRepository meetings;
  late SegmentRepository segments;
  late SpeakerRepository speakers;
  late Meeting meeting;

  setUp(() async {
    db = memoryDb();
    meetings = MeetingRepository(db);
    segments = SegmentRepository(db);
    speakers = SpeakerRepository(db);
    meeting = await meetings.create(title: 'اختبار');
  });
  tearDown(() => db.close());

  SessionPipeline pipeline({
    SegmentProcessor? processor,
    List<Speaker> known = const [],
    FakeAsr? asr,
  }) => SessionPipeline(
    meetingId: meeting.id,
    processor:
        processor ??
        InlineSegmentProcessor(asr: asr ?? FakeAsr(), embedder: FakeEmbedder()),
    tracker: SpeakerTracker(knownSpeakers: known),
    speakers: speakers,
    segments: segments,
  );

  test(
    'stores segments in order with auto speakers متحدث 1, متحدث 2',
    () async {
      final p = pipeline();
      final voices = [0, 0, 1, 1, 0, 2, 1];
      var t = 0;
      for (var i = 0; i < voices.length; i++) {
        p.submit(speech(i, t, 2000, voices[i]));
        t += 2500;
      }
      await p.drain();
      final stored = await segments.getForMeeting(meeting.id);
      expect(stored.map((s) => s.text), [
        for (var i = 0; i < voices.length; i++) 'كلام $i',
      ]);
      expect(
        stored.map((s) => s.index),
        List.generate(voices.length, (i) => i),
      );
      final byId = await speakers.getAllById();
      final names = stored.map((s) => byId[s.speakerId]!.name).toList();
      expect(names, [
        'متحدث 1',
        'متحدث 1',
        'متحدث 2',
        'متحدث 2',
        'متحدث 1',
        'متحدث 3',
        'متحدث 2',
      ]);
      expect(p.createdSpeakerIds, hasLength(3));
      expect(p.recognizedSpeakerIds, isEmpty);
      expect(p.storedCount, 7);
      expect(p.pendingCount, 0);
      expect(p.currentSpeaker!.name, 'متحدث 2');
      // Embeddings are stored for refinement.
      expect(stored.every((s) => s.embedding?.length == kFakeDim), isTrue);
      expect(stored.first.language, 'ar');
    },
  );

  test(
    'applies results in submission order even when they finish reversed',
    () async {
      final shuffled = ShuffledProcessor(
        InlineSegmentProcessor(asr: FakeAsr(), embedder: FakeEmbedder()),
      );
      final p = pipeline(processor: shuffled);
      for (var i = 0; i < 6; i++) {
        p.submit(speech(i, i * 3000, 2000, i % 2));
      }
      expect(p.pendingCount, 6);
      await shuffled.releaseReversed();
      await p.drain();
      final stored = await segments.getForMeeting(meeting.id);
      expect(stored.map((s) => s.text), [
        'كلام 0',
        'كلام 1',
        'كلام 2',
        'كلام 3',
        'كلام 4',
        'كلام 5',
      ]);
      final byId = await speakers.getAllById();
      expect(stored.map((s) => byId[s.speakerId]!.name).toList(), [
        'متحدث 1',
        'متحدث 2',
        'متحدث 1',
        'متحدث 2',
        'متحدث 1',
        'متحدث 2',
      ]);
    },
  );

  test('a saved voiceprint reuses the named speaker', () async {
    final ahmed = await speakers.create(
      name: 'أحمد',
      centroid: voiceOf(1),
      embeddingCount: 20,
    );
    final p = pipeline(known: [ahmed]);
    p.submit(speech(0, 0, 3000, 1));
    p.submit(speech(1, 3500, 3000, 0));
    p.submit(speech(2, 7000, 3000, 1));
    await p.drain();
    final stored = await segments.getForMeeting(meeting.id);
    expect(stored[0].speakerId, ahmed.id);
    expect(stored[2].speakerId, ahmed.id);
    final other = await speakers.get(stored[1].speakerId!);
    // N is unique across the library ('أحمد' is not an auto name).
    expect(other!.name, 'متحدث 1');
    expect(p.recognizedSpeakerIds, {ahmed.id});
    expect(p.createdSpeakerIds, {other.id});
  });

  test(
    'silence is skipped and creates no speaker; failures are counted',
    () async {
      final p = pipeline(asr: FakeAsr(failIndices: {2}));
      p.submit(speech(0, 0, 2000, 0));
      p.submit(speech(1, 2500, 2000, null)); // silence → empty transcript
      p.submit(speech(2, 5000, 2000, 1)); // ASR failure
      p.submit(speech(3, 7500, 2000, 0));
      await p.drain();
      final stored = await segments.getForMeeting(meeting.id);
      expect(stored.map((s) => s.text), ['كلام 0', 'كلام 3']);
      expect(p.skippedCount, 1);
      expect(p.failedCount, 1);
      expect(p.lastError, isA<AsrException>());
      expect(p.completedCount, 4);
      expect(await speakers.getAll(), hasLength(1));
    },
  );

  test(
    'short segments inherit the previous speaker without new speakers',
    () async {
      final p = pipeline();
      p.submit(speech(0, 0, 3000, 0));
      p.submit(speech(1, 3200, 500, 1)); // too short to embed: inherits
      await p.drain();
      final stored = await segments.getForMeeting(meeting.id);
      expect(stored[1].speakerId, stored[0].speakerId);
      expect(stored[1].embedding, isNull);
      expect(await speakers.getAll(), hasLength(1));
    },
  );

  test('follows a speaker merged by the user mid-meeting', () async {
    final p = pipeline();
    p.submit(speech(0, 0, 3000, 0));
    p.submit(speech(1, 3500, 3000, 1));
    await p.drain();
    final first = await segments.getForMeeting(meeting.id);
    final a = first[0].speakerId!;
    final b = first[1].speakerId!;
    // The user says both are the same person.
    await speakers.merge(b, a);
    p.submit(speech(2, 7000, 3000, 1));
    await p.drain();
    final stored = await segments.getForMeeting(meeting.id);
    expect(stored.map((s) => s.speakerId).toSet(), {a});
    expect(p.failedCount, 0);
  });

  test('a speaker deleted mid-meeting is replaced by a fresh one', () async {
    final p = pipeline();
    p.submit(speech(0, 0, 3000, 0));
    await p.drain();
    final first = (await segments.getForMeeting(meeting.id)).single;
    await speakers.delete(first.speakerId!);
    p.submit(speech(1, 3500, 3000, 0));
    await p.drain();
    final stored = await segments.getForMeeting(meeting.id);
    expect(stored[0].speakerId, isNull);
    expect(stored[1].speakerId, isNotNull);
    expect(await speakers.get(stored[1].speakerId!), isNotNull);
    expect(p.failedCount, 0);
  });

  test('abort discards pending results', () async {
    final shuffled = ShuffledProcessor(
      InlineSegmentProcessor(asr: FakeAsr(), embedder: FakeEmbedder()),
    );
    final p = pipeline(processor: shuffled);
    p.submit(speech(0, 0, 2000, 0));
    p.submit(speech(1, 2500, 2000, 1));
    p.abort();
    p.submit(speech(2, 5000, 2000, 1)); // ignored after abort
    await shuffled.releaseReversed();
    await p.drain();
    expect(await segments.getForMeeting(meeting.id), isEmpty);
    expect(p.submittedCount, 2);
  });

  test('waitForCapacity resolves once the backlog shrinks', () async {
    final shuffled = ShuffledProcessor(
      InlineSegmentProcessor(asr: FakeAsr(), embedder: FakeEmbedder()),
    );
    final p = pipeline(processor: shuffled);
    for (var i = 0; i < 5; i++) {
      p.submit(speech(i, i * 2500, 2000, 0));
    }
    var released = false;
    final wait = p.waitForCapacity(1).then((_) => released = true);
    await Future<void>.delayed(Duration.zero);
    expect(released, isFalse);
    expect(p.pendingAudioMs, 10000);
    await shuffled.releaseReversed();
    await wait;
    expect(released, isTrue);
    await p.drain();
    expect(p.pendingAudioMs, 0);
  });

  test('drain reports progress', () async {
    final p = pipeline();
    for (var i = 0; i < 3; i++) {
      p.submit(speech(i, i * 2500, 2000, 0));
    }
    final progress = <(int, int)>[];
    await p.drain(onProgress: (d, t) => progress.add((d, t)));
    expect(progress.last, (3, 3));
  });

  test(
    'InlineSegmentProcessor reports embedding errors without failing',
    () async {
      final proc = InlineSegmentProcessor(
        asr: FakeAsr(),
        embedder: _ThrowingEmbedder(),
      );
      final r = await proc.process(speech(0, 0, 2000, 0));
      expect(r.asr.text, 'كلام 0');
      expect(r.embedding, isNull);
      expect(r.embeddingErrorAr, isNotNull);
      await proc.dispose();
      await expectLater(
        proc.process(speech(1, 0, 2000, 0)),
        throwsA(isA<AsrException>()),
      );
    },
  );
}

class _ThrowingEmbedder extends FakeEmbedder {
  @override
  Future<Float32List?> embed(Float32List samples) async =>
      throw const ModelException('embedding failed');
}
