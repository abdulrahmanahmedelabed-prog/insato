import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/multi_device/alignment.dart';

import 'sim.dart';

Float32List _delayed(Float32List x, int d) {
  final out = Float32List(x.length);
  for (var i = 0; i < x.length; i++) {
    final j = i - d;
    out[i] = j >= 0 && j < x.length ? x[j] : 0;
  }
  return out;
}

void main() {
  final speech = syntheticSpeech(16000 * 5, seed: 21);

  test('envelope is the mean absolute value per ms', () {
    final e = envelope(Float32List.fromList(List.filled(64, -0.5)));
    expect(e.length, 4);
    expect(e[0], closeTo(0.5, 1e-6));
  });

  for (final lagMs in [-180.0, -37.5, 0.0, 12.25, 95.0, 240.0]) {
    test('measures a ${lagMs}ms lag through noise and gain differences', () {
      final d = (lagMs * 16).round();
      final ref = mixSignals([(1, speech), (1, noise(speech.length))], speech.length);
      final sig = mixSignals([
        (0.3, _delayed(speech, d)),
        (1, noise(speech.length, seed: 99, level: 0.004)),
      ], speech.length);
      final e = estimateLag(ref, sig)!;
      expect(e.lagMs, closeTo(lagMs, 1.0));
      expect(e.peak, greaterThan(0.35));
      expect(e.ratio, greaterThan(1.15));
    });
  }

  test('silence or unrelated audio gives no confident estimate', () {
    final silence = Float32List(speech.length);
    expect(estimateLag(silence, speech), isNull);
    final other = syntheticSpeech(speech.length, seed: 77);
    final e = estimateLag(speech, other);
    final t = AlignmentTracker();
    expect(t.consider(e), 0);
    expect(t.rejected + t.accepted, 1);
  });

  group('AlignmentTracker', () {
    LagEstimate est(double ms) =>
        LagEstimate(lagSamples: ms * 16, peak: 0.8, ratio: 2);

    test('applies a correction once two estimates agree', () {
      final t = AlignmentTracker();
      expect(t.consider(est(70)), 0);
      expect(t.consider(est(71)), -(70.5 * 16).round());
      expect(t.correctionSamples, -(70.5 * 16).round());
      expect(t.state, AlignmentState.network);
      expect(t.consider(est(0.4)), 0);
      expect(t.state, AlignmentState.locked);
    });

    test('an isolated outlier never moves the alignment', () {
      final t = AlignmentTracker();
      t.consider(est(70));
      t.consider(est(-150));
      expect(t.correctionSamples, 0);
      t.consider(est(69));
      expect(t.correctionSamples, -(69.5 * 16).round());
    });

    test('weak or ambiguous peaks are rejected', () {
      final t = AlignmentTracker();
      t.consider(const LagEstimate(lagSamples: 800, peak: 0.1, ratio: 3));
      t.consider(const LagEstimate(lagSamples: 800, peak: 0.9, ratio: 1.01));
      t.consider(null);
      expect(t.rejected, 3);
      expect(t.correctionSamples, 0);
    });
  });
}
