import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/interfaces.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/diarization/vector_math.dart';
import 'package:insato/features/voice/audio_quality.dart';
import 'package:insato/features/voice/enrollment_engine.dart';
import 'package:insato/features/voice/voiceprint_builder.dart';

import '../../session/fakes.dart' show embeddingOf, memoryDb, voiceOf;
import 'voice_fakes.dart';

/// Segmenter that buffers everything and emits energy spans on flush, with
/// 100 ms of padding on each side (like the real VAD).
class BufferingSegmenter implements SpeechSegmenter {
  final _out = StreamController<SpeechSegment>();
  final List<Float32List> _parts = [];
  bool initialized = false;
  bool disposed = false;
  Object? failWith;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  void accept(Float32List samples) => _parts.add(samples);

  @override
  void flush() {
    final f = failWith;
    if (f != null) {
      _out.addError(f);
      return;
    }
    final audio = join(_parts);
    final pad = millisToSamples(100);
    var i = 0;
    for (final s in energySpeechSpans(audio)) {
      final start = (s.startSample - pad).clamp(0, audio.length);
      final end = (s.endSample + pad).clamp(0, audio.length);
      _out.add(
        SpeechSegment(
          index: i++,
          startMs: samplesToMillis(start),
          samples: Float32List.sublistView(audio, start, end),
        ),
      );
    }
  }

  @override
  Stream<SpeechSegment> get segments => _out.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _out.close();
  }
}

EnrollmentVoiceprint sampleOf(int voice, {int n = 6, int seed = 100}) =>
    buildEnrollmentVoiceprint([
      for (var i = 0; i < n; i++)
        WeightedEmbedding(embeddingOf(voice, seed + i, noise: 0.1), 3),
    ])!;

void main() {
  group('collectSpeechSpans', () {
    test('feeds the take, flushes and returns the merged spans', () async {
      final seg = BufferingSegmenter();
      final audio = readingTake(segments: 3, speechMs: 1500);
      final spans = await collectSpeechSpans(seg, audio);
      expect(seg.initialized, isTrue);
      expect(seg.disposed, isTrue);
      expect(spans, hasLength(3));
      expect(spans.first.durationMs, closeTo(1700, 80));
    });

    test('a segmenter error becomes an Insato error', () async {
      final seg = BufferingSegmenter()..failWith = StateError('boom');
      await expectLater(
        collectSpeechSpans(seg, readingTake()),
        throwsA(isA<InsatoException>()),
      );
      expect(seg.disposed, isTrue);
    });
  });

  test('SegmenterEmbedderAnalyzer wires segmenter and embedder', () async {
    var disposed = false;
    final analyzer = SegmenterEmbedderAnalyzer(
      newSegmenter: BufferingSegmenter.new,
      embedOne: (s) async => s.length > 100 ? voiceOf(1) : null,
      paddingMsPerSpan: 200,
      onDispose: () async => disposed = true,
    );
    expect(analyzer.paddingMsPerSpan, 200);
    final spans = await analyzer.detectSpeech(readingTake(segments: 2));
    expect(spans, hasLength(2));
    final out = await analyzer.embed([Float32List(10), Float32List(1000)]);
    expect(out[0], isNull);
    expect(out[1], voiceOf(1));
    await analyzer.dispose();
    expect(disposed, isTrue);
  });

  group('analyzeEnrollmentTake', () {
    test('a clean 13 s reading can be saved', () async {
      final analyzer = FakeEnrollmentAnalyzer(speaker: 3);
      final a = await analyzeEnrollmentTake(readingTake(), analyzer);
      expect(a.quality.passed, isTrue);
      expect(a.voiceIssues, isEmpty);
      expect(a.canSave, isTrue);
      expect(cosine(a.voiceprint!.centroid, voiceOf(3)), greaterThan(0.97));
      // 5 segments + windows over 11 s of joined speech.
      expect(analyzer.embedCalls, greaterThanOrEqualTo(10));
    });

    test('silence: no speech and no embedding work', () async {
      final analyzer = FakeEnrollmentAnalyzer();
      final a = await analyzeEnrollmentTake(noise(12000), analyzer);
      expect(a.quality.has(AudioQualityIssueKind.noSpeech), isTrue);
      expect(a.voiceIssues, [EnrollmentVoiceIssue.noVoiceprint]);
      expect(a.canSave, isFalse);
      expect(analyzer.embedCalls, 0);
    });

    test('too little speech blocks saving', () async {
      final a = await analyzeEnrollmentTake(
        readingTake(segments: 2),
        FakeEnrollmentAnalyzer(),
      );
      expect(a.quality.has(AudioQualityIssueKind.tooLittleSpeech), isTrue);
      expect(a.voiceprint, isNotNull);
      expect(a.canSave, isFalse);
    });

    test('two voices block saving', () async {
      final a = await analyzeEnrollmentTake(
        readingTake(),
        FakeEnrollmentAnalyzer(mixed: true),
      );
      expect(a.quality.passed, isTrue);
      expect(a.voiceIssues, contains(EnrollmentVoiceIssue.inconsistent));
      expect(a.canSave, isFalse);
    });
  });

  group('VoiceEnrollmentWriter', () {
    late AppDatabase db;
    late SpeakerRepository speakers;
    late VoiceEnrollmentWriter writer;

    setUp(() {
      db = memoryDb();
      speakers = SpeakerRepository(db);
      writer = VoiceEnrollmentWriter(db: db, speakers: speakers);
    });
    tearDown(() => db.close());

    test('creates a named speaker with the voiceprint and device', () async {
      final sample = sampleOf(2);
      final s = await writer.createSpeaker(
        name: '  د. سارة  ',
        sample: sample,
        deviceKey: 'usb|Jabra',
      );
      final stored = (await speakers.get(s.id))!;
      expect(stored.name, 'د. سارة');
      expect(stored.isNamedByUser, isTrue);
      expect(stored.voiceDevice, 'usb|Jabra');
      expect(stored.embeddingCount, sample.embeddingCount);
      expect(cosine(stored.centroid!, sample.centroid), closeTo(1, 1e-5));
      expect(
        () => writer.createSpeaker(name: ' ', sample: sample),
        throwsArgumentError,
      );
    });

    test('improves an existing voiceprint, weighted by counts', () async {
      final old = await speakers.create(
        name: 'خالد',
        centroid: voiceOf(5),
        embeddingCount: 30,
        voiceDevice: 'builtIn|Mic',
      );
      final sample = sampleOf(5, seed: 7);
      final s = await writer.improveSpeaker(
        speakerId: old.id,
        sample: sample,
        deviceKey: 'usb|Jabra',
      );
      expect(s.embeddingCount, 30 + sample.embeddingCount);
      expect(cosine(s.centroid!, voiceOf(5)), greaterThan(0.97));
      // 30 old vs ≤ 12 new embeddings: the tag stays on the old device.
      expect(s.voiceDevice, 'builtIn|Mic');
      expect(s.name, 'خالد');
    });

    test('names an unnamed voice, clears low confidence, takes the device '
        'when the voiceprint was forgotten', () async {
      final unnamed = await speakers.create(lowConfidence: true);
      expect(unnamed.isNamedByUser, isFalse);
      final s = await writer.improveSpeaker(
        speakerId: unnamed.id,
        sample: sampleOf(1),
        deviceKey: 'usb|Jabra',
        newName: 'منى',
      );
      expect(s.name, 'منى');
      expect(s.isNamedByUser, isTrue);
      expect(s.lowConfidence, isFalse);
      expect(s.voiceDevice, 'usb|Jabra');
      expect(s.centroid, isNotNull);
    });

    test('a vanished speaker is reported in Arabic', () async {
      await expectLater(
        writer.improveSpeaker(speakerId: 'nope', sample: sampleOf(1)),
        throwsA(isA<InsatoException>()),
      );
    });
  });
}
