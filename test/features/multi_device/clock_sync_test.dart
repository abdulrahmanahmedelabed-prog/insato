import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/multi_device/clock_sync.dart';

import 'sim.dart';

void main() {
  group('ClockSyncEstimator', () {
    test('offset and drift of a skewed clock under asymmetric jitter', () {
      // Guest clock = 5.3 s + host·(1 + 80 ppm); network 2 ms + 0–8 ms
      // each way, occasional 60 ms spikes on the way back.
      const offset0 = 5300000.0;
      const drift = 80e-6;
      double guestOf(double hostUs) => offset0 + hostUs * (1 + drift);
      final j = Jitter(11);
      final est = ClockSyncEstimator();
      for (var k = 0; k < 120; k++) {
        final t1 = 1000000 + k * 1000000;
        final d1 = 2000 + j.next(8000);
        final d2 = 2000 + j.next(8000) + j.spike(0.1, 60000);
        final t2 = guestOf((t1 + d1).toDouble()).round();
        final t3 = t2 + 150;
        final t4 = t1 + d1 + 150 + d2; // host ≈ guest rate over 150 µs
        est.add(ClockSample(t1, t2, t3, t4));
      }
      expect(est.isReady, isTrue);
      expect(est.driftPpm, closeTo(80, 10));
      const probe = 118000000;
      final truth = guestOf(probe.toDouble()) - probe;
      expect(est.offsetAt(probe), closeTo(truth, 2000));
      final g = guestOf(probe.toDouble()).round();
      expect(est.guestToHost(g), closeTo(probe, 2000));
      expect(est.hostToGuest(probe), closeTo(g, 2000));
      expect(est.rttMs, isNotNull);
      expect(est.minRttMs!, greaterThanOrEqualTo(4));
    });

    test('needs three samples; inconsistent samples are ignored', () {
      final est = ClockSyncEstimator();
      est.add(const ClockSample(10, 5, 4, 20)); // t3 < t2
      est.add(const ClockSample(10, 5, 6, 5)); // t4 < t1
      expect(est.sampleCount, 0);
      est.add(const ClockSample(0, 1000, 1000, 2000));
      est.add(const ClockSample(1000000, 1001000, 1001000, 1002000));
      expect(est.isReady, isFalse);
      est.add(const ClockSample(2000000, 2001000, 2001000, 2002000));
      expect(est.isReady, isTrue);
      expect(est.offsetAt(0), closeTo(0, 1));
      expect(est.driftPpm, 0); // span too short for drift
    });
  });

  group('CaptureTimestamper', () {
    test('removes delivery jitter and follows sample-clock drift', () {
      // Frames of 100 ms; arrival = capture end + 20 ms + 0–30 ms jitter;
      // the sample clock runs 50 ppm fast relative to the CPU clock.
      final j = Jitter(3);
      final ts = CaptureTimestamper();
      var maxErr = 0.0;
      for (var k = 1; k <= 1200; k++) {
        final end = k * 1600;
        final captureEndUs = 7000000 + end * kUsPerSample * (1 - 50e-6);
        final arrival = (captureEndUs + 20000 + j.next(30000)).round();
        final first = ts.stamp(endIndex: end, length: 1600, arrivalUs: arrival);
        if (k > 50) {
          final truthFirst =
              7000000 + (end - 1600) * kUsPerSample * (1 - 50e-6) + 20000;
          maxErr = math.max(maxErr, (first - truthFirst).abs());
        }
      }
      // Constant latency is invisible here (cross-correlation removes it);
      // jitter and drift must not leak through.
      expect(maxErr, lessThan(2500));
    });

    test('a sustained jump (unreported pause) restarts the estimate', () {
      final ts = CaptureTimestamper();
      for (var k = 1; k <= 20; k++) {
        ts.stamp(endIndex: k * 1600, length: 1600, arrivalUs: k * 100000);
      }
      final before = ts.anchorUs!;
      for (var k = 21; k <= 25; k++) {
        ts.stamp(
          endIndex: k * 1600,
          length: 1600,
          arrivalUs: k * 100000 + 5000000,
        );
      }
      expect(ts.anchorUs! - before, closeTo(5000000, 1));
      ts.reset();
      expect(ts.anchorUs, isNull);
      expect(ts.indexAt(1000), closeTo(16, 0.01));
    });
  });
}
