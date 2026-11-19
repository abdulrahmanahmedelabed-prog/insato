import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/speech/sherpa_speaker_embedder.dart';

void main() {
  test('minimum embedding length is 0.8 s', () {
    expect(kMinEmbeddingSamples, (0.5 * kSampleRate).round());
  });

  test('l2Normalize yields a unit vector', () {
    final v = l2Normalize(Float32List.fromList([3, 4]))!;
    expect(v[0], closeTo(0.6, 1e-6));
    expect(v[1], closeTo(0.8, 1e-6));
    var n = 0.0;
    final r = l2Normalize(
        Float32List.fromList(List.generate(256, (i) => math.sin(i * 1.0))))!;
    for (final x in r) {
      n += x * x;
    }
    expect(n, closeTo(1, 1e-5));
  });

  test('l2Normalize rejects degenerate vectors', () {
    expect(l2Normalize(Float32List(0)), isNull);
    expect(l2Normalize(Float32List(8)), isNull);
    expect(l2Normalize(Float32List.fromList([1, double.nan])), isNull);
    expect(l2Normalize(Float32List.fromList([1, double.infinity])), isNull);
  });

  test('does not modify the input', () {
    final input = Float32List.fromList([2, 0]);
    l2Normalize(input);
    expect(input, [2.0, 0.0]);
  });
}
