import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/diarization/vector_math.dart';

Float32List v(List<double> xs) => Float32List.fromList(xs);

void main() {
  group('dot / l2Norm', () {
    test('computes dot product for lengths not divisible by 4', () {
      expect(dot(v([1, 2, 3, 4, 5]), v([5, 4, 3, 2, 1])), 35);
      expect(l2Norm(v([3, 4])), closeTo(5, 1e-9));
    });

    test('throws on length mismatch', () {
      expect(() => dot(v([1, 2]), v([1])), throwsArgumentError);
      expect(() => cosine(v([1, 2]), v([1])), throwsArgumentError);
    });
  });

  group('l2Normalize', () {
    test('produces a unit vector without modifying the input', () {
      final x = v([3, 4]);
      final n = l2Normalize(x);
      expect(n[0], closeTo(0.6, 1e-6));
      expect(n[1], closeTo(0.8, 1e-6));
      expect(x[0], 3);
      expect(l2Norm(n), closeTo(1, 1e-6));
    });

    test('zero and non-finite vectors become all zeros', () {
      expect(l2Normalize(v([0, 0, 0])), everyElement(0));
      expect(l2Normalize(v([double.nan, 1])), everyElement(0));
    });

    test('in-place variant returns the original norm', () {
      final x = v([0, 5]);
      expect(l2NormalizeInPlace(x), closeTo(5, 1e-9));
      expect(x[1], closeTo(1, 1e-6));
      final z = v([0, 0]);
      expect(l2NormalizeInPlace(z), 0);
    });
  });

  group('cosine', () {
    test('is scale invariant (robust to non-normalised input)', () {
      expect(cosine(v([2, 0]), v([10, 10])), closeTo(math.sqrt1_2, 1e-6));
      expect(cosine(v([1, 0]), v([-3, 0])), closeTo(-1, 1e-9));
    });

    test('returns 0 for zero vectors', () {
      expect(cosine(v([0, 0]), v([1, 0])), 0);
    });

    test('is clamped to [-1, 1]', () {
      final a = v([0.1, 0.2, 0.3]);
      expect(cosine(a, a), lessThanOrEqualTo(1));
      expect(cosine(a, a), closeTo(1, 1e-6));
    });
  });

  group('isUsableEmbedding', () {
    test('rejects null, empty, zero, NaN, Infinity and wrong dimension', () {
      expect(isUsableEmbedding(null), isFalse);
      expect(isUsableEmbedding(Float32List(0)), isFalse);
      expect(isUsableEmbedding(v([0, 0])), isFalse);
      expect(isUsableEmbedding(v([double.nan, 1])), isFalse);
      expect(isUsableEmbedding(v([double.infinity, 1])), isFalse);
      expect(isUsableEmbedding(v([1, 0]), dimension: 3), isFalse);
      expect(isUsableEmbedding(v([1, 0]), dimension: 2), isTrue);
    });
  });

  group('weightedMeanNormalized', () {
    test('averages directions, not magnitudes', () {
      final m = weightedMeanNormalized([v([10, 0]), v([0, 1])])!;
      expect(m[0], closeTo(math.sqrt1_2, 1e-6));
      expect(m[1], closeTo(math.sqrt1_2, 1e-6));
    });

    test('respects weights', () {
      final m = weightedMeanNormalized([v([1, 0]), v([0, 1])], [3, 1])!;
      expect(m[0] / m[1], closeTo(3, 1e-5));
      expect(l2Norm(m), closeTo(1, 1e-6));
    });

    test('skips unusable vectors and non-positive weights', () {
      final m = weightedMeanNormalized(
          [v([0, 0]), v([double.nan, 0]), v([0, 2]), v([5, 0])],
          [1, 1, 1, 0])!;
      expect(m[0], closeTo(0, 1e-9));
      expect(m[1], closeTo(1, 1e-6));
    });

    test('returns null when nothing usable or the mean cancels out', () {
      expect(weightedMeanNormalized([]), isNull);
      expect(weightedMeanNormalized([v([0, 0])]), isNull);
      expect(meanNormalized([v([1, 0]), v([-1, 0])]), isNull);
    });

    test('throws on mismatched weights or dimensions', () {
      expect(() => weightedMeanNormalized([v([1])], [1, 2]),
          throwsArgumentError);
      expect(() => meanNormalized([v([1, 0]), v([1, 0, 0])]),
          throwsArgumentError);
    });
  });

  test('addScaledInPlace and normalizeAccumulator', () {
    final acc = Float64List(2);
    addScaledInPlace(acc, v([1, 0]), 2);
    addScaledInPlace(acc, v([0, 1]), 2);
    expect(acc, [2, 2]);
    final n = normalizeAccumulator(acc);
    expect(n[0], closeTo(math.sqrt1_2, 1e-6));
    expect(normalizeAccumulator(Float64List(3)), everyElement(0));
    expect(() => addScaledInPlace(acc, v([1])), throwsArgumentError);
  });

  test('bestAndSecond', () {
    expect(bestAndSecond([]), (-1, double.negativeInfinity,
        double.negativeInfinity));
    expect(bestAndSecond([0.3]), (0, 0.3, double.negativeInfinity));
    expect(bestAndSecond([0.3, 0.9, 0.5]), (1, 0.9, 0.5));
    expect(bestAndSecond([0.9, 0.1, 0.5]), (0, 0.9, 0.5));
  });
}
