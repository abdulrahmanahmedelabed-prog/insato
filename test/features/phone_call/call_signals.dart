// Synthetic signals for the phone-call tests: speech-like noise bursts
// (random syllable lengths and gains), echoes and band-limited audio.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:insato/core/models.dart' show kSampleRate;

/// [ms] of speech-like audio: uniform noise of [amp] gated by syllables of
/// 100–300 ms separated by 40–160 ms pauses, each with its own gain.
Float32List speechLike(int ms, {int seed = 1, double amp = 0.3}) {
  final r = math.Random(seed);
  final n = ms * kSampleRate ~/ 1000;
  final out = Float32List(n);
  var i = 0;
  while (i < n) {
    final on = (100 + r.nextInt(200)) * kSampleRate ~/ 1000;
    final gain = 0.4 + 0.6 * r.nextDouble();
    for (var k = 0; k < on && i < n; k++, i++) {
      out[i] = amp * gain * (2 * r.nextDouble() - 1);
    }
    i += (40 + r.nextInt(120)) * kSampleRate ~/ 1000;
  }
  return out;
}

/// Low-level noise floor of [ms] at [amp].
Float32List noise(int ms, {int seed = 99, double amp = 0.001}) {
  final r = math.Random(seed);
  return Float32List.fromList([
    for (var i = 0; i < ms * kSampleRate ~/ 1000; i++)
      amp * (2 * r.nextDouble() - 1),
  ]);
}

/// [x] scaled by [gain] and shifted later by [delayMs] (negative: earlier),
/// same length.
Float32List echo(Float32List x, {double gain = 0.25, int delayMs = 60}) {
  final d = delayMs * kSampleRate ~/ 1000;
  final out = Float32List(x.length);
  for (var i = 0; i < x.length; i++) {
    final j = i - d;
    if (j >= 0 && j < x.length) out[i] = gain * x[j];
  }
  return out;
}

/// Sample-wise sum (length of the longest).
Float32List add(List<Float32List> parts) {
  final n = parts.fold<int>(0, (m, p) => math.max(m, p.length));
  final out = Float32List(n);
  for (final p in parts) {
    for (var i = 0; i < p.length; i++) {
      out[i] += p[i];
    }
  }
  return out;
}

/// [ms] of a sum of sines at [hz] (amplitude [amp] each).
Float32List tones(int ms, List<double> hz, {double amp = 0.1}) {
  final n = ms * kSampleRate ~/ 1000;
  return Float32List.fromList([
    for (var i = 0; i < n; i++)
      hz.fold<double>(
        0,
        (a, f) => a + amp * math.sin(2 * math.pi * f * i / kSampleRate),
      ),
  ]);
}

/// RMS of [x] from sample [from].
double rms(Float32List x, {int from = 0}) {
  var s = 0.0;
  for (var i = from; i < x.length; i++) {
    s += x[i] * x[i];
  }
  return math.sqrt(s / math.max(1, x.length - from));
}
