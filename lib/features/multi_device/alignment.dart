// Audio-based refinement of the host ↔ guest alignment (v1.2 C).
//
// The network clock estimate (clock_sync.dart) aligns the devices' CPU
// clocks to about a millisecond on a quiet LAN, but each device's audio
// stack adds its own, unknown input latency (tens to a few hundred ms on
// Android). Both devices hear the same room, so the lag between their
// signals is measured directly: the envelopes (mean |x| per 1 ms) of a few
// seconds of overlapping audio are high-passed (onsets matter, levels do
// not) and cross-correlated over ±[maxLagMs]; the peak, refined by parabolic
// interpolation, gives the lag to ~0.1 ms. A peak is accepted only when it
// is strong and clearly above every other lag (otherwise silence, noise or
// echo could pull the alignment), and a correction is applied once two
// estimates agree. The remaining error is dominated by the acoustic path
// difference (sound travels ≈ 34 cm per ms), well under the 20 ms target.
//
// Pure Dart.

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models.dart' show kSampleRate;

/// Samples per envelope bin (1 ms at 16 kHz).
const int kEnvelopeHop = kSampleRate ~/ 1000;

/// Mean absolute value per [hop] samples of `x[start, start + length)`.
Float32List envelope(
  Float32List x, {
  int start = 0,
  int? length,
  int hop = kEnvelopeHop,
}) {
  final len = length ?? (x.length - start);
  final bins = len ~/ hop;
  final out = Float32List(bins);
  for (var b = 0; b < bins; b++) {
    var s = 0.0;
    final o = start + b * hop;
    for (var i = 0; i < hop; i++) {
      s += x[o + i].abs();
    }
    out[b] = s / hop;
  }
  return out;
}

/// Envelope minus its moving average over [window] bins (onset emphasis),
/// log-compressed so loud bursts do not dominate.
Float32List _onsets(Float32List env, {int window = 64}) {
  final n = env.length;
  final logEnv = Float64List(n);
  for (var i = 0; i < n; i++) {
    logEnv[i] = math.log(1e-4 + env[i]);
  }
  final prefix = Float64List(n + 1);
  for (var i = 0; i < n; i++) {
    prefix[i + 1] = prefix[i] + logEnv[i];
  }
  final out = Float32List(n);
  final half = window ~/ 2;
  for (var i = 0; i < n; i++) {
    final a = math.max(0, i - half);
    final b = math.min(n, i + half + 1);
    out[i] = logEnv[i] - (prefix[b] - prefix[a]) / (b - a);
  }
  return out;
}

/// Result of [estimateLag].
class LagEstimate {
  /// Creates an estimate.
  const LagEstimate({
    required this.lagSamples,
    required this.peak,
    required this.ratio,
  });

  /// How many samples the signal lags the reference (positive: the signal
  /// hears things later).
  final double lagSamples;

  /// Normalised correlation at the peak (0..1).
  final double peak;

  /// Peak divided by the best correlation outside ±10 ms of it.
  final double ratio;

  /// [lagSamples] in milliseconds.
  double get lagMs => lagSamples * 1000 / kSampleRate;

  @override
  String toString() =>
      'LagEstimate(${lagMs.toStringAsFixed(2)} ms, '
      'peak ${peak.toStringAsFixed(2)}, ratio ${ratio.toStringAsFixed(2)})';
}

/// Estimates the lag of [signal] behind [reference] (same length, same
/// timeline) within ±[maxLagMs]. Returns null when either side has too
/// little activity to measure.
LagEstimate? estimateLag(
  Float32List reference,
  Float32List signal, {
  int maxLagMs = 300,
}) {
  final n = math.min(reference.length, signal.length);
  final a = _onsets(envelope(reference, length: n));
  final b = _onsets(envelope(signal, length: n));
  final bins = a.length;
  final maxLag = math.min(maxLagMs, bins ~/ 3);
  if (bins < 200 || maxLag < 1) return null;
  if (_variance(a) < 1e-3 || _variance(b) < 1e-3) return null;

  // corr[l] = Σ a[i]·b[i + l] / √(Σa² Σb²) over the overlap.
  final corr = Float64List(2 * maxLag + 1);
  for (var l = -maxLag; l <= maxLag; l++) {
    final i0 = math.max(0, -l);
    final i1 = math.min(bins, bins - l);
    var dot = 0.0, ea = 0.0, eb = 0.0;
    for (var i = i0; i < i1; i++) {
      final x = a[i], y = b[i + l];
      dot += x * y;
      ea += x * x;
      eb += y * y;
    }
    corr[l + maxLag] = (ea <= 0 || eb <= 0) ? 0 : dot / math.sqrt(ea * eb);
  }
  var bi = 0;
  for (var i = 1; i < corr.length; i++) {
    if (corr[i] > corr[bi]) bi = i;
  }
  final peak = corr[bi];
  var other = 1e-9;
  for (var i = 0; i < corr.length; i++) {
    if ((i - bi).abs() > 10 && corr[i] > other) other = corr[i];
  }
  var frac = 0.0;
  if (bi > 0 && bi < corr.length - 1) {
    final y0 = corr[bi - 1], y1 = corr[bi], y2 = corr[bi + 1];
    final den = y0 - 2 * y1 + y2;
    if (den.abs() > 1e-12) frac = (0.5 * (y0 - y2) / den).clamp(-0.5, 0.5);
  }
  return LagEstimate(
    lagSamples: (bi - maxLag + frac) * kEnvelopeHop,
    peak: peak,
    ratio: peak / other,
  );
}

double _variance(Float32List x) {
  if (x.isEmpty) return 0;
  var m = 0.0;
  for (final v in x) {
    m += v;
  }
  m /= x.length;
  var s = 0.0;
  for (final v in x) {
    s += (v - m) * (v - m);
  }
  return s / x.length;
}

/// State of a guest channel's audio alignment.
enum AlignmentState {
  /// No accepted cross-correlation yet (network clock only).
  network,

  /// At least one accepted estimate; residual below [AlignmentTracker.lockedMs].
  locked,
}

/// Turns accepted [LagEstimate]s into a sample correction for one guest.
class AlignmentTracker {
  /// Creates a tracker.
  AlignmentTracker({
    this.minPeak = 0.35,
    this.minRatio = 1.15,
    this.agreeMs = 3,
    this.lockedMs = 2,
  });

  /// Smallest accepted correlation peak.
  final double minPeak;

  /// Smallest accepted peak-to-runner-up ratio.
  final double minRatio;

  /// Two estimates within this many ms agree.
  final double agreeMs;

  /// A residual below this many ms counts as aligned.
  final double lockedMs;

  /// Samples added to the network-estimated position of the guest's audio.
  int correctionSamples = 0;

  /// Accepted residuals (ms) since the last correction, newest last.
  final List<double> _pending = [];

  /// Last accepted residual in ms (after earlier corrections), or null.
  double? lastResidualMs;

  /// Number of accepted estimates.
  int accepted = 0;

  /// Number of rejected estimates (too weak / ambiguous).
  int rejected = 0;

  /// Current state.
  AlignmentState get state =>
      lastResidualMs != null && lastResidualMs!.abs() <= lockedMs
      ? AlignmentState.locked
      : AlignmentState.network;

  /// Considers an estimate measured on audio placed with the current
  /// [correctionSamples]. Returns the change applied (samples, 0 = none).
  int consider(LagEstimate? e) {
    if (e == null || e.peak < minPeak || e.ratio < minRatio) {
      rejected++;
      return 0;
    }
    accepted++;
    lastResidualMs = e.lagMs;
    if (e.lagMs.abs() <= lockedMs / 2) {
      _pending.clear();
      return 0;
    }
    _pending.add(e.lagMs);
    if (_pending.length > 3) _pending.removeAt(0);
    // Apply once two of the recent estimates agree (an isolated outlier,
    // e.g. an echo, never moves the alignment).
    for (var i = _pending.length - 1; i > 0; i--) {
      for (var j = i - 1; j >= 0; j--) {
        if ((_pending[i] - _pending[j]).abs() <= agreeMs) {
          final ms = (_pending[i] + _pending[j]) / 2;
          final delta = -(ms * kSampleRate / 1000).round();
          correctionSamples += delta;
          _pending.clear();
          return delta;
        }
      }
    }
    return 0;
  }
}
