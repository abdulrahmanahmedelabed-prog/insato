// Channel attribution of Phone Link calls: which side of the call spoke in
// a speech segment, given the two time-aligned channels of the session.
//
// * remote channel = system audio (loopback): only the telephone line plays
//   there, so its activity is the remote side's speech.
// * local channel  = the microphone: the people next to the PC, plus the
//   remote voices again when the PC speakers play the call ("bleed" /
//   acoustic echo; headphones avoid it).
//
// Bleed suppression: the microphone's 10 ms energy envelope is compared
// with the remote envelope at lags of ±[CallAttributionConfig.maxEchoLagMs]
// (the loopback jitter buffer may place the remote audio before or after
// its echo). When they correlate, the echo path gain is estimated as a low
// percentile of the power ratio over remote-active blocks (robust to local
// speech on top), and a microphone block counts as local speech only when
// its power exceeds the predicted echo by [CallAttributionConfig.residualMarginDb].
// A segment whose microphone activity is all explained by the remote side
// is attributed to the remote side (the microphone segment is suppressed).
//
// Pure Dart (no Flutter imports).

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models.dart' show kSampleRate;
import 'phone_call_models.dart';

/// Tuning of [attributeCallSegment].
class CallAttributionConfig {
  /// Creates a configuration (defaults are the shipped tuning).
  const CallAttributionConfig({
    this.blockMs = 10,
    this.activityMarginDb = 9,
    this.absoluteFloorDbfs = -60,
    this.maxEchoLagMs = 300,
    this.minEchoCorrelation = 0.3,
    this.echoGainPercentile = 0.25,
    this.residualMarginDb = 6,
    this.minSideActiveMs = 200,
  });

  /// Energy block length (ms).
  final int blockMs;

  /// A block is active when this many dB above its channel's noise floor.
  final double activityMarginDb;

  /// …and above this absolute level (dBFS).
  final double absoluteFloorDbfs;

  /// Echo lag search range (± ms).
  final int maxEchoLagMs;

  /// Envelope correlation from which the microphone is assumed to hear
  /// the remote side.
  final double minEchoCorrelation;

  /// Percentile of the mic/remote power ratio used as the echo gain.
  final double echoGainPercentile;

  /// Local speech must exceed the predicted echo by this much (dB).
  final double residualMarginDb;

  /// Activity (ms) below which a side is considered silent in a segment.
  final int minSideActiveMs;

  /// Samples per block at 16 kHz.
  int get blockSamples => kSampleRate * blockMs ~/ 1000;
}

/// Outcome of [attributeCallSegment].
class CallAttribution {
  /// Creates an attribution.
  const CallAttribution({
    required this.side,
    required this.localActiveMs,
    required this.remoteActiveMs,
    required this.micActiveMs,
    required this.bleedSuppressed,
    required this.overlap,
    required this.echoCorrelation,
    required this.echoLagMs,
    required this.echoGainDb,
    required this.localSnrDb,
    required this.remoteSnrDb,
  });

  /// The side the segment is attributed to.
  final CallSide side;

  /// Local speech after bleed suppression (ms).
  final int localActiveMs;

  /// Remote (loopback) speech (ms).
  final int remoteActiveMs;

  /// Microphone activity before bleed suppression (ms).
  final int micActiveMs;

  /// True when the microphone was active but its activity was the remote
  /// voice heard through the speakers.
  final bool bleedSuppressed;

  /// Both sides spoke substantially (the segment goes to the dominant one).
  final bool overlap;

  /// Best envelope correlation mic ↔ remote (0 when not measurable).
  final double echoCorrelation;

  /// Lag of [echoCorrelation] (ms, positive: the mic follows the remote).
  final int echoLagMs;

  /// Estimated echo power gain (dB; −∞ without echo).
  final double echoGainDb;

  /// Local channel SNR over its active blocks (dB above floor).
  final double localSnrDb;

  /// Remote channel SNR over its active blocks (dB above floor).
  final double remoteSnrDb;

  @override
  String toString() =>
      'CallAttribution(${side.name}, local ${localActiveMs}ms, remote '
      '${remoteActiveMs}ms, mic ${micActiveMs}ms, bleed=$bleedSuppressed, '
      'overlap=$overlap, ρ=${echoCorrelation.toStringAsFixed(2)} '
      '@${echoLagMs}ms)';
}

double _db(double power) =>
    power <= 1e-20 ? -200 : 10 * math.log(power) / math.ln10;

/// Mean-square power per block of [x] ([n] blocks of [size]).
Float64List _blockPowers(Float32List x, int n, int size) {
  final out = Float64List(n);
  for (var b = 0; b < n; b++) {
    var acc = 0.0;
    final off = b * size;
    for (var i = 0; i < size; i++) {
      final v = x[off + i];
      acc += v * v;
    }
    out[b] = acc / size;
  }
  return out;
}

/// Attributes one speech segment to a side of the call from its [local]
/// (microphone) and [remote] (loopback) samples, time-aligned and of the
/// same rate (16 kHz). [localFloorDbfs] / [remoteFloorDbfs] are the
/// channels' running noise floors (see [NoiseFloorTracker]).
CallAttribution attributeCallSegment(
  Float32List local,
  Float32List remote, {
  double localFloorDbfs = -70,
  double remoteFloorDbfs = -90,
  CallAttributionConfig config = const CallAttributionConfig(),
}) {
  final size = config.blockSamples;
  final n = math.min(local.length, remote.length) ~/ size;
  if (n == 0) {
    return const CallAttribution(
      side: CallSide.local,
      localActiveMs: 0,
      remoteActiveMs: 0,
      micActiveMs: 0,
      bleedSuppressed: false,
      overlap: false,
      echoCorrelation: 0,
      echoLagMs: 0,
      echoGainDb: double.negativeInfinity,
      localSnrDb: 0,
      remoteSnrDb: 0,
    );
  }
  final ml = _blockPowers(local, n, size);
  final mr = _blockPowers(remote, n, size);
  final localGate = math.max(
    localFloorDbfs + config.activityMarginDb,
    config.absoluteFloorDbfs,
  );
  final remoteGate = math.max(
    remoteFloorDbfs + config.activityMarginDb,
    config.absoluteFloorDbfs,
  );
  final remoteActive = [for (final p in mr) _db(p) > remoteGate];
  final micActive = [for (final p in ml) _db(p) > localGate];

  // --- Echo path: envelope correlation over ± maxLag -----------------------
  final maxLag = math.min(n - 1, config.maxEchoLagMs ~/ config.blockMs);
  final el = [for (final p in ml) math.sqrt(p)];
  final er = [for (final p in mr) math.sqrt(p)];
  var bestRho = 0.0;
  var bestLag = 0;
  final remoteCount = remoteActive.where((a) => a).length;
  if (remoteCount >= 5) {
    for (var lag = -maxLag; lag <= maxLag; lag++) {
      final rho = _correlation(er, el, lag);
      if (rho > bestRho) {
        bestRho = rho;
        bestLag = lag;
      }
    }
  }
  var gain = 0.0;
  if (bestRho >= config.minEchoCorrelation) {
    final ratios = <double>[
      for (var i = 0; i < n; i++)
        if (remoteActive[i] && i + bestLag >= 0 && i + bestLag < n)
          ml[i + bestLag] / math.max(mr[i], 1e-20),
    ]..sort();
    if (ratios.isNotEmpty) {
      final k = ((ratios.length - 1) * config.echoGainPercentile).round();
      gain = ratios[k];
    }
  }

  // --- Local speech = microphone power well above the predicted echo -------
  final residual = math.pow(10, config.residualMarginDb / 10).toDouble();
  var localBlocks = 0, micBlocks = 0, remoteBlocks = 0;
  var localSum = 0.0, remoteSum = 0.0;
  for (var j = 0; j < n; j++) {
    if (remoteActive[j]) {
      remoteBlocks++;
      remoteSum += _db(mr[j]) - remoteFloorDbfs;
    }
    if (!micActive[j]) continue;
    micBlocks++;
    var echo = 0.0;
    if (gain > 0) {
      // ±1 block of timing slack.
      for (var k = -1; k <= 1; k++) {
        final i = j - bestLag + k;
        if (i >= 0 && i < n) echo = math.max(echo, mr[i]);
      }
      echo *= gain;
    }
    if (ml[j] > echo * residual) {
      localBlocks++;
      localSum += _db(ml[j]) - localFloorDbfs;
    }
  }
  final b = config.blockMs;
  final localMs = localBlocks * b;
  final remoteMs = remoteBlocks * b;
  final micMs = micBlocks * b;
  final minMs = config.minSideActiveMs;

  CallSide side;
  var overlap = false;
  if (localMs < minMs && remoteMs < minMs) {
    // Hardly any speech on either side: the more active one wins; on a tie
    // the louder one relative to its floor; else the microphone.
    if (remoteMs != localMs) {
      side = remoteMs > localMs ? CallSide.remote : CallSide.local;
    } else {
      final lPeak = _db(ml.fold<double>(0, math.max)) - localFloorDbfs;
      final rPeak = _db(mr.fold<double>(0, math.max)) - remoteFloorDbfs;
      side = rPeak > lPeak && micMs == 0 ? CallSide.remote : CallSide.local;
    }
  } else if (localMs < minMs) {
    side = CallSide.remote;
  } else if (remoteMs < minMs) {
    side = CallSide.local;
  } else {
    overlap = true;
    side = remoteMs >= localMs ? CallSide.remote : CallSide.local;
  }
  final bleed = side == CallSide.remote && micMs >= minMs && localMs < minMs;
  return CallAttribution(
    side: side,
    localActiveMs: localMs,
    remoteActiveMs: remoteMs,
    micActiveMs: micMs,
    bleedSuppressed: bleed,
    overlap: overlap,
    echoCorrelation: bestRho,
    echoLagMs: bestLag * b,
    echoGainDb: gain > 0 ? _db(gain) : double.negativeInfinity,
    localSnrDb: localBlocks == 0 ? 0 : localSum / localBlocks,
    remoteSnrDb: remoteBlocks == 0 ? 0 : remoteSum / remoteBlocks,
  );
}

/// Pearson correlation of `a[i]` and `b[i + lag]` over the overlap.
double _correlation(List<double> a, List<double> b, int lag) {
  final from = math.max(0, -lag);
  final to = math.min(a.length, b.length - lag);
  final m = to - from;
  if (m < 5) return 0;
  var sa = 0.0, sb = 0.0;
  for (var i = from; i < to; i++) {
    sa += a[i];
    sb += b[i + lag];
  }
  final ma = sa / m, mb = sb / m;
  var cov = 0.0, va = 0.0, vb = 0.0;
  for (var i = from; i < to; i++) {
    final x = a[i] - ma, y = b[i + lag] - mb;
    cov += x * y;
    va += x * x;
    vb += y * y;
  }
  if (va <= 1e-24 || vb <= 1e-24) return 0;
  return cov / math.sqrt(va * vb);
}

/// Running noise floor of a channel (dBFS) from 10 ms block powers:
/// follows drops immediately and rises slowly (≈ 3 dB per second), so
/// speech does not lift it.
class NoiseFloorTracker {
  /// Creates a tracker starting at [initialDbfs].
  NoiseFloorTracker({
    this.initialDbfs = -70,
    this.riseDbPerSecond = 3,
    this.minDbfs = -100,
  }) : _floor = initialDbfs;

  /// Starting floor.
  final double initialDbfs;

  /// Upward drift speed.
  final double riseDbPerSecond;

  /// Lowest floor reported (digital silence on the loopback).
  final double minDbfs;

  double _floor;
  double _acc = 0;
  int _count = 0;

  /// Current floor (dBFS).
  double get floorDbfs => _floor;

  /// Feeds samples (16 kHz).
  void add(Float32List samples) {
    const block = kSampleRate ~/ 100;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i];
      _acc += v * v;
      if (++_count == block) {
        final db = math.max(minDbfs, _db(_acc / block));
        _floor = db < _floor ? db : _floor + riseDbPerSecond / 100;
        _acc = 0;
        _count = 0;
      }
    }
  }

  /// Back to [initialDbfs].
  void reset() {
    _floor = initialDbfs;
    _acc = 0;
    _count = 0;
  }
}
