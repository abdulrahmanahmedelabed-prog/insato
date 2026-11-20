// Clock alignment between the host and a guest device (v1.2 C).
//
// Three clocks are involved:
//
// * each device's monotonic CPU clock (microseconds, [MonotonicClock]);
// * each device's audio sample clock (16 kHz, may run a few ppm off);
// * the host's audio timeline (the sample index the host's VAD sees).
//
// [CaptureTimestamper] maps a device's sample index to its CPU clock from
// the arrival times of the capture frames (the earliest arrival bounds the
// capture time from above, so a sliding minimum removes delivery jitter).
//
// [ClockSyncEstimator] estimates `guest clock − host clock` with NTP-style
// ping / pong exchanges: host sends t1, guest receives at t2 and answers at
// t3, host receives at t4. offset = ((t2 − t1) + (t3 − t4)) / 2,
// round trip = (t4 − t1) − (t3 − t2). Only exchanges close to the minimum
// round trip are trusted (queueing delay is asymmetric); a least-squares
// line through them over the last two minutes gives offset and drift (ppm).
//
// Cross-correlation of overlapping audio (alignment.dart) then removes what
// the network estimate cannot see (different input latencies of the
// devices' audio stacks).
//
// Pure Dart.

import 'dart:math' as math;

import '../../core/models.dart' show kSampleRate;

/// Microseconds of one sample at [kSampleRate].
const double kUsPerSample = 1e6 / kSampleRate;

/// A monotonic microsecond clock shared by everything on one device.
class MonotonicClock {
  MonotonicClock._() : _sw = Stopwatch()..start();
  final Stopwatch _sw;

  /// The process-wide instance.
  static final MonotonicClock instance = MonotonicClock._();

  /// Microseconds since the clock started.
  int nowUs() => _sw.elapsedMicroseconds;
}

/// Maps a capture stream's sample index to the device's CPU clock.
class CaptureTimestamper {
  /// Creates a timestamper; [windowUs] bounds the sliding minimum (drift
  /// between the sample clock and the CPU clock is followed within it).
  CaptureTimestamper({
    this.windowUs = 10 * 1000 * 1000,
    this.resetJumpUs = 1000 * 1000,
  });

  /// Length of the sliding minimum.
  final int windowUs;

  /// A sustained jump larger than this (e.g. after a pause the caller did
  /// not report) restarts the estimate.
  final int resetJumpUs;

  // (arrivalUs, candidate anchor) with increasing candidates (monotonic
  // deque for the sliding minimum).
  final List<(int, double)> _deque = [];
  int _jumpCount = 0;

  /// Estimated CPU time of sample index 0, or null before the first frame.
  double? get anchorUs => _deque.isEmpty ? null : _deque.first.$2;

  /// Forgets everything (call when capture restarts or resumes).
  void reset() {
    _deque.clear();
    _jumpCount = 0;
  }

  /// Records that the frame ending at sample index [endIndex] arrived at
  /// [arrivalUs]; returns the CPU time of sample [endIndex] − [length]
  /// (the frame's first sample).
  int stamp({
    required int endIndex,
    required int length,
    required int arrivalUs,
  }) {
    final candidate = arrivalUs - endIndex * kUsPerSample;
    final a = anchorUs;
    if (a != null && candidate - a > resetJumpUs) {
      if (++_jumpCount >= 3) reset();
    } else {
      _jumpCount = 0;
    }
    while (_deque.isNotEmpty && _deque.last.$2 >= candidate) {
      _deque.removeLast();
    }
    _deque.add((arrivalUs, candidate));
    while (_deque.length > 1 && arrivalUs - _deque.first.$1 > windowUs) {
      _deque.removeAt(0);
    }
    return timeOf(endIndex - length);
  }

  /// CPU time (µs) of sample [index].
  int timeOf(int index) => ((anchorUs ?? 0) + index * kUsPerSample).round();

  /// Sample index at CPU time [us] (fractional).
  double indexAt(int us) => (us - (anchorUs ?? 0)) / kUsPerSample;
}

/// One ping / pong exchange (all in microseconds).
class ClockSample {
  /// Creates a sample: [t1], [t4] host clock, [t2], [t3] guest clock.
  const ClockSample(this.t1, this.t2, this.t3, this.t4);

  /// Host send time.
  final int t1;

  /// Guest receive time.
  final int t2;

  /// Guest send time.
  final int t3;

  /// Host receive time.
  final int t4;

  /// Guest − host clock offset of this exchange.
  double get offsetUs => ((t2 - t1) + (t3 - t4)) / 2;

  /// Network round trip.
  int get rttUs => (t4 - t1) - (t3 - t2);

  /// Host time of the exchange's midpoint.
  double get hostMidUs => (t1 + t4) / 2;
}

/// Offset + drift estimate of a guest clock relative to the host clock.
class ClockSyncEstimator {
  /// Creates an estimator keeping exchanges of the last [windowUs].
  ClockSyncEstimator({
    this.windowUs = 120 * 1000 * 1000,
    this.maxDriftPpm = 500,
    this.minSpanForDriftUs = 8 * 1000 * 1000,
  });

  /// Exchanges older than this are dropped.
  final int windowUs;

  /// Drift estimates are clamped to ±this.
  final double maxDriftPpm;

  /// Drift is only estimated once the trusted exchanges span this long.
  final int minSpanForDriftUs;

  final List<ClockSample> _samples = [];
  double _offset = 0; // at _refUs
  double _drift = 0; // µs per µs
  double _refUs = 0;
  int _accepted = 0;

  /// Number of exchanges in the window.
  int get sampleCount => _samples.length;

  /// True once at least three sane exchanges were seen.
  bool get isReady => _accepted >= 3;

  /// Estimated drift of the guest clock relative to the host, in ppm.
  double get driftPpm => _drift * 1e6;

  /// Median round trip of the recent exchanges (ms), or null.
  double? get rttMs {
    if (_samples.isEmpty) return null;
    final r = [for (final s in _samples.reversed.take(10)) s.rttUs]..sort();
    return r[r.length ~/ 2] / 1000;
  }

  /// Smallest round trip in the window (ms), or null.
  double? get minRttMs => _samples.isEmpty
      ? null
      : _samples.map((s) => s.rttUs).reduce(math.min) / 1000;

  /// Adds an exchange (ignored when its timestamps are inconsistent).
  void add(ClockSample s) {
    if (s.t4 < s.t1 || s.t3 < s.t2 || s.rttUs < 0) return;
    _samples.add(s);
    while (_samples.isNotEmpty && s.t4 - _samples.first.t4 > windowUs) {
      _samples.removeAt(0);
    }
    _accepted++;
    _refit();
  }

  void _refit() {
    final minRtt = _samples.map((s) => s.rttUs).reduce(math.min);
    // Trust exchanges within 2 ms (or 50 %) of the best round trip; keep at
    // least the best third.
    final slack = math.max(2000, minRtt ~/ 2);
    var trusted = [
      for (final s in _samples)
        if (s.rttUs <= minRtt + slack) s,
    ];
    if (trusted.length < math.min(3, _samples.length)) {
      final sorted = [..._samples]..sort((a, b) => a.rttUs.compareTo(b.rttUs));
      trusted = sorted.take(math.max(1, _samples.length ~/ 3)).toList();
    }
    final n = trusted.length;
    var mt = 0.0, mo = 0.0;
    for (final s in trusted) {
      mt += s.hostMidUs;
      mo += s.offsetUs;
    }
    mt /= n;
    mo /= n;
    final span =
        trusted.map((s) => s.hostMidUs).reduce(math.max) -
        trusted.map((s) => s.hostMidUs).reduce(math.min);
    var slope = 0.0;
    if (n >= 4 && span >= minSpanForDriftUs) {
      var sxx = 0.0, sxy = 0.0;
      for (final s in trusted) {
        final dx = s.hostMidUs - mt;
        sxx += dx * dx;
        sxy += dx * (s.offsetUs - mo);
      }
      if (sxx > 0) slope = sxy / sxx;
      final cap = maxDriftPpm / 1e6;
      slope = slope.clamp(-cap, cap);
    }
    _refUs = mt;
    _offset = mo;
    _drift = slope;
  }

  /// Guest − host offset (µs) at host time [hostUs].
  double offsetAt(num hostUs) => _offset + _drift * (hostUs - _refUs);

  /// Host time of guest time [guestUs].
  int guestToHost(int guestUs) {
    // hostUs = guestUs − offset(hostUs); one fixed-point step is exact to
    // well below a microsecond for realistic drifts.
    var h = guestUs - offsetAt(guestUs);
    h = guestUs - offsetAt(h);
    return h.round();
  }

  /// Guest time of host time [hostUs].
  int hostToGuest(int hostUs) => (hostUs + offsetAt(hostUs)).round();
}
