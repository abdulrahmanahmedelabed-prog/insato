// Synthetic signals and devices for the multi-device tests.

import 'dart:math' as math;
import 'dart:typed_data';

/// Speech-like test signal: syllable bursts (harmonic + noise, 80–250 ms)
/// separated by pauses (60–400 ms), at 16 kHz.
Float32List syntheticSpeech(int samples, {int seed = 1, double gain = 0.3}) {
  final r = math.Random(seed);
  final out = Float32List(samples);
  var i = 0;
  while (i < samples) {
    final len = 1280 + r.nextInt(2720);
    final f0 = 100 + r.nextInt(150);
    final amp = gain * (0.4 + 0.6 * r.nextDouble());
    for (var k = 0; k < len && i + k < samples; k++) {
      final env = math.sin(math.pi * k / len);
      final t = (i + k) / 16000;
      final h =
          math.sin(2 * math.pi * f0 * t) +
          0.5 * math.sin(4 * math.pi * f0 * t) +
          0.3 * (r.nextDouble() * 2 - 1);
      out[i + k] = (amp * env * h).toDouble();
    }
    i += len + 960 + r.nextInt(5440);
  }
  return out;
}

/// White noise at [level] (rms ≈ level / √3).
Float32List noise(int samples, {int seed = 7, double level = 0.003}) {
  final r = math.Random(seed);
  return Float32List.fromList([
    for (var i = 0; i < samples; i++) level * (r.nextDouble() * 2 - 1),
  ]);
}

/// Silence with [bursts] of speech-like audio at the given ranges.
Float32List speechAt(
  int samples,
  List<(int, int)> ranges, {
  int seed = 3,
  double gain = 0.3,
}) {
  final s = syntheticSpeech(samples, seed: seed, gain: gain);
  final out = Float32List(samples);
  for (final (a, b) in ranges) {
    for (var i = a; i < b && i < samples; i++) {
      out[i] = s[i];
    }
  }
  return out;
}

/// `a·x + b·y + n` (shorter inputs are zero-padded).
Float32List mixSignals(List<(double, Float32List)> parts, int length) {
  final out = Float32List(length);
  for (final (g, x) in parts) {
    for (var i = 0; i < length && i < x.length; i++) {
      out[i] += g * x[i];
    }
  }
  return out;
}

/// Deterministic jitter source.
class Jitter {
  Jitter(int seed) : _r = math.Random(seed);
  final math.Random _r;

  /// Uniform integer in [0, max].
  int next(int max) => max <= 0 ? 0 : _r.nextInt(max + 1);

  /// Occasionally (probability [p]) a large delay up to [max].
  int spike(double p, int max) => _r.nextDouble() < p ? _r.nextInt(max + 1) : 0;
}
