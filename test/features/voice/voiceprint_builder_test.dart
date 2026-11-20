import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/diarization/vector_math.dart';
import 'package:insato/features/voice/audio_quality.dart';
import 'package:insato/features/voice/enrollment_texts.dart';
import 'package:insato/features/voice/voiceprint_builder.dart';

import '../../session/fakes.dart' show embeddingOf, voiceOf;
import 'voice_fakes.dart';

Speaker sp(
  String id, {
  String name = 'متحدث 1',
  bool named = false,
  Float32List? centroid,
  int count = 0,
  String? device,
}) => Speaker(
  id: id,
  name: name,
  colorValue: 0,
  isNamedByUser: named,
  createdAt: DateTime(2026),
  centroid: centroid,
  embeddingCount: count,
  voiceDevice: device,
);

void main() {
  group('planEnrollmentChunks', () {
    test('segments ≥ 1 s plus 3 s windows over the joined speech', () {
      final audio = join([
        noise(500),
        tone(2000),
        noise(500, seed: 2),
        tone(600),
        noise(500, seed: 3),
        tone(4000),
      ]);
      final spans = [
        SpeechSpan(millisToSamples(500), millisToSamples(2500)),
        SpeechSpan(millisToSamples(3000), millisToSamples(3600)),
        SpeechSpan(millisToSamples(4100), millisToSamples(8100)),
      ];
      final chunks = planEnrollmentChunks(audio, spans);
      final segs = chunks.where((c) => c.kind == EnrollmentChunkKind.segment);
      final wins = chunks.where((c) => c.kind == EnrollmentChunkKind.window);
      expect(segs.map((c) => c.durationMs), [2000, 4000]);
      // Joined speech 6.6 s → windows at 0, 1.5, 3.0 s (3 s each).
      expect(wins, hasLength(3));
      expect(wins.every((c) => c.durationMs == 3000), isTrue);
      // Windows contain only speech (the tone), never the pauses.
      for (final w in wins) {
        var peak = 0.0;
        for (final s in w.samples) {
          if (s.abs() > peak) peak = s.abs();
        }
        expect(peak, greaterThan(0.15));
      }
    });

    test('short joined speech of several spans becomes one window', () {
      final audio = join([tone(800), noise(300), tone(800)]);
      final chunks = planEnrollmentChunks(audio, [
        SpeechSpan(0, millisToSamples(800)),
        SpeechSpan(millisToSamples(1100), millisToSamples(1900)),
      ]);
      expect(chunks, hasLength(1));
      expect(chunks.single.kind, EnrollmentChunkKind.window);
      expect(chunks.single.durationMs, 1600);
    });

    test('no speech, no chunks; invalid sizes throw', () {
      expect(planEnrollmentChunks(noise(2000), const []), isEmpty);
      expect(
        () => planEnrollmentChunks(noise(10), const [], windowMs: 0),
        throwsArgumentError,
      );
    });
  });

  test('chunkWeight is seconds within [0.5, 10]', () {
    expect(chunkWeight(100), 0.5);
    expect(chunkWeight(3000), 3);
    expect(chunkWeight(60000), 10);
  });

  group('buildEnrollmentVoiceprint', () {
    test('averages consistent embeddings close to the true voice', () {
      final items = [
        for (var i = 0; i < 8; i++) WeightedEmbedding(embeddingOf(2, i), 3),
      ];
      final vp = buildEnrollmentVoiceprint(items)!;
      expect(cosine(vp.centroid, voiceOf(2)), greaterThan(0.97));
      expect(vp.consistency, greaterThan(0.8));
      expect(vp.mixedVoices, isFalse);
      expect(vp.isConsistent, isTrue);
      expect(vp.used, 8);
      expect(vp.rejected, 0);
      expect(vp.embeddingCount, 8);
      expect(l2Norm(vp.centroid), closeTo(1, 1e-5));
    });

    test('drops outliers (another voice) and caps the count', () {
      final items = [
        for (var i = 0; i < 14; i++) WeightedEmbedding(embeddingOf(2, i), 3),
        WeightedEmbedding(embeddingOf(5, 1), 3),
        WeightedEmbedding(embeddingOf(6, 1), 3),
      ];
      final vp = buildEnrollmentVoiceprint(items)!;
      expect(vp.rejected, 2);
      expect(vp.used, 14);
      expect(vp.embeddingCount, kMaxEnrollmentEmbeddingCount);
      expect(cosine(vp.centroid, voiceOf(2)), greaterThan(0.97));
    });

    test('two voices in one take are detected', () {
      final items = [
        for (var i = 0; i < 6; i++)
          WeightedEmbedding(embeddingOf(i.isEven ? 1 : 4, i), 3),
      ];
      final vp = buildEnrollmentVoiceprint(items)!;
      expect(vp.mixedVoices, isTrue);
      expect(vp.isConsistent, isFalse);
    });

    test('a short interjection by someone else is not "mixed"', () {
      expect(
        detectMixedVoices([
          for (var i = 0; i < 10; i++) embeddingOf(1, i),
          embeddingOf(4, 1),
          embeddingOf(4, 2),
        ]),
        isFalse,
      );
      expect(
        detectMixedVoices([for (var i = 0; i < 3; i++) embeddingOf(i, i)]),
        isFalse,
      );
    });

    test('skips unusable vectors and minority dimensions', () {
      final items = [
        WeightedEmbedding(Float32List(64), 3),
        WeightedEmbedding(Float32List.fromList([1, 0, 0]), 3),
        WeightedEmbedding(embeddingOf(1, 1), 0),
        WeightedEmbedding(embeddingOf(1, 2), 2),
        WeightedEmbedding(embeddingOf(1, 3), 2),
      ];
      final vp = buildEnrollmentVoiceprint(items)!;
      expect(vp.centroid.length, 64);
      expect(vp.used, 2);
      expect(vp.rejected, 3);
      expect(buildEnrollmentVoiceprint(const []), isNull);
      expect(
        buildEnrollmentVoiceprint([WeightedEmbedding(Float32List(4), 1)]),
        isNull,
      );
    });
  });

  group('improvedVoiceprint', () {
    final sample = buildEnrollmentVoiceprint([
      for (var i = 0; i < 6; i++) WeightedEmbedding(embeddingOf(2, 50 + i), 3),
    ])!;

    test('weights the old voiceprint by its count', () {
      final heavy = improvedVoiceprint(
        sp('a', centroid: voiceOf(7), count: 200),
        sample,
      );
      final light = improvedVoiceprint(
        sp('a', centroid: voiceOf(7), count: 2),
        sample,
      );
      expect(heavy.count, 200);
      expect(light.count, 8);
      expect(
        cosine(heavy.centroid, voiceOf(7)),
        greaterThan(cosine(light.centroid, voiceOf(7))),
      );
      expect(
        cosine(light.centroid, sample.centroid),
        greaterThan(cosine(heavy.centroid, sample.centroid)),
      );
    });

    test('replaces a missing or incompatible voiceprint', () {
      final none = improvedVoiceprint(sp('a'), sample);
      expect(none.centroid, sample.centroid);
      expect(none.count, sample.embeddingCount);
      final otherDim = improvedVoiceprint(
        sp('a', centroid: Float32List.fromList([1, 0, 0]), count: 50),
        sample,
      );
      expect(otherDim.centroid, sample.centroid);
    });
  });

  group('similar voices and names', () {
    test('finds the most similar compatible voiceprint over the threshold', () {
      final speakers = [
        sp('a', centroid: voiceOf(1), count: 5),
        sp('b', centroid: embeddingOf(2, 9), count: 5),
        sp('c', centroid: voiceOf(2), count: 5),
        sp('d', centroid: Float32List.fromList([1, 0]), count: 5),
        sp('e'),
      ];
      final hit = findSimilarVoice(voiceOf(2), speakers)!;
      expect(hit.speaker.id, 'c');
      expect(hit.similarity, closeTo(1, 1e-5));
      expect(
        findSimilarVoice(voiceOf(2), speakers, excludeId: 'c')!.speaker.id,
        'b',
      );
      expect(findSimilarVoice(voiceOf(9), speakers), isNull);
    });

    test('name lookup is trimmed and case-insensitive', () {
      final speakers = [
        sp('a', name: 'Sara Ahmed', named: true),
        sp('b', name: 'د. خالد', named: true),
      ];
      expect(findSpeakerNamed(' sara ahmed ', speakers)!.id, 'a');
      expect(findSpeakerNamed('د. خالد', speakers)!.id, 'b');
      expect(findSpeakerNamed('د. خالد', speakers, excludeId: 'b'), isNull);
      expect(findSpeakerNamed('  ', speakers), isNull);
    });
  });

  group('reading passages', () {
    test('every language has passages of a 10–18 s reading length', () {
      for (final lang in EnrollmentLanguage.values) {
        final list = enrollmentPassages(lang);
        expect(list.length, greaterThanOrEqualTo(3));
        for (final p in list) {
          final words = p.split(RegExp(r'\s+')).length;
          expect(words, inInclusiveRange(28, 50), reason: p);
        }
      }
    });

    test('index wraps around and direction follows the language', () {
      expect(
        enrollmentPassage(EnrollmentLanguage.arabic, 3),
        kArabicEnrollmentPassages[0],
      );
      expect(
        enrollmentPassage(EnrollmentLanguage.english, -1),
        kEnglishEnrollmentPassages[1],
      );
      expect(EnrollmentLanguage.arabic.isRtl, isTrue);
      expect(EnrollmentLanguage.english.code, 'en');
    });
  });
}
