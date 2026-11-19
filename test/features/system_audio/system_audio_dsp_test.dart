import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart' show kSampleRate;
import 'package:insato/features/system_audio/system_audio.dart';

import 'system_audio_fakes.dart';

Float32List _filled(int n, double v) => Float32List(n)..fillRange(0, n, v);

void main() {
  group('SystemAudioConverter', () {
    test('48 kHz stereo becomes 16 kHz mono with the same tone', () {
      final c = SystemAudioConverter();
      final mono = sine(1000, rate: 48000, hz: 440);
      final stereo = interleave(mono, 2);
      final parts = <Float32List>[];
      // Odd chunking, including a chunk that splits a stereo frame.
      var at = 0;
      for (final size in [961, 4801, 333, 12000]) {
        final end = math.min(at + size, stereo.length);
        parts.add(
          c.convert(
            Float32List.sublistView(stereo, at, end),
            sampleRate: 48000,
            channels: 2,
          ),
        );
        at = end;
      }
      parts.add(
        c.convert(
          Float32List.sublistView(stereo, at),
          sampleRate: 48000,
          channels: 2,
        ),
      );
      parts.add(c.flush());
      final out = concatSamples(parts);
      expect(out.length, closeTo(16000, 2));
      final expected = sine(1000, hz: 440);
      var maxErr = 0.0;
      for (var i = 800; i < 15000; i++) {
        maxErr = math.max(maxErr, (out[i] - expected[i]).abs());
      }
      expect(maxErr, lessThan(0.03));
    });

    test('mono 16 kHz passes through unchanged', () {
      final c = SystemAudioConverter();
      final s = sine(100);
      expect(c.convert(s, sampleRate: kSampleRate, channels: 1), s);
    });

    test('a format change flushes the old converter and switches', () {
      final c = SystemAudioConverter();
      final a = c.convert(
        interleave(sine(200, rate: 48000), 2),
        sampleRate: 48000,
        channels: 2,
      );
      expect(c.inputRate, 48000);
      final b = c.convert(
        interleave(sine(200, rate: 44100), 1),
        sampleRate: 44100,
        channels: 1,
      );
      expect(c.inputRate, 44100);
      expect(c.inputChannels, 1);
      final total = a.length + b.length + c.flush().length;
      // 200 ms + 200 ms at 16 kHz.
      expect(total, closeTo(6400, 4));
    });

    test('rejects an invalid format', () {
      expect(
        () => SystemAudioConverter().convert(
          Float32List(4),
          sampleRate: 0,
          channels: 2,
        ),
        throwsArgumentError,
      );
    });
  });

  group('SystemAudioBuffer', () {
    test('take returns buffered samples across chunks, then zeros', () {
      final b = SystemAudioBuffer(maxSamples: 100)
        ..add(Float32List.fromList([1, 2, 3]))
        ..add(Float32List.fromList([4, 5]));
      expect(b.length, 5);
      expect(b.take(2), [1, 2]);
      expect(b.take(2), [3, 4]);
      expect(b.take(4), [5, 0, 0, 0]);
      expect(b.length, 0);
      expect(b.zeroFilled, 3);
      expect(b.take(0), isEmpty);
    });

    test('drops the oldest samples beyond maxSamples', () {
      final b = SystemAudioBuffer(maxSamples: 4)
        ..add(Float32List.fromList([1, 2, 3]))
        ..add(Float32List.fromList([4, 5, 6]));
      expect(b.length, 4);
      expect(b.dropped, 2);
      expect(b.take(4), [3, 4, 5, 6]);
    });

    test('a single block larger than the buffer keeps its newest part', () {
      final b = SystemAudioBuffer(maxSamples: 3)
        ..add(Float32List.fromList([9]))
        ..add(Float32List.fromList([1, 2, 3, 4, 5]));
      expect(b.length, 3);
      expect(b.dropped, 3);
      expect(b.take(3), [3, 4, 5]);
    });

    test('clear empties it', () {
      final b = SystemAudioBuffer()..add(_filled(10, 0.1));
      b.clear();
      expect(b.length, 0);
      expect(b.take(2), [0, 0]);
    });
  });

  group('WallClockSilenceFiller', () {
    test('emits elapsed × rate samples: audio first, zeros for silence', () {
      final clock = FakeClock();
      final f = WallClockSilenceFiller(clock: clock.call, lag: Duration.zero)
        ..start();
      final buffer = SystemAudioBuffer();
      expect(f.drain(buffer), isEmpty);

      buffer.add(_filled(800, 0.5)); // 50 ms of audio.
      clock.advance(const Duration(milliseconds: 100));
      final first = f.drain(buffer);
      expect(first.length, 1600);
      expect(first.sublist(0, 800).every((s) => s == 0.5), isTrue);
      expect(first.sublist(800).every((s) => s == 0), isTrue);
      expect(f.silenceSamples, 800);

      // Nothing plays for a second: one second of zeros.
      clock.advance(const Duration(seconds: 1));
      final silent = f.drain(buffer);
      expect(silent.length, 16000);
      expect(silent.every((s) => s == 0), isTrue);
      expect(f.emitted, 17600);
      expect(f.elapsed, const Duration(milliseconds: 1100));
    });

    test('the lag leaves late packets time to arrive', () {
      final clock = FakeClock();
      final f = WallClockSilenceFiller(
        clock: clock.call,
        lag: const Duration(milliseconds: 150),
      )..start();
      final buffer = SystemAudioBuffer();
      clock.advance(const Duration(milliseconds: 100));
      expect(f.due(), 0);
      clock.advance(const Duration(milliseconds: 150));
      // 250 ms − 150 ms lag.
      expect(f.due(), 1600);
      // A packet for that slot arrives late but before it is emitted.
      buffer.add(_filled(1600, 0.25));
      final out = f.drain(buffer);
      expect(out.every((s) => s == 0.25), isTrue);
      expect(f.silenceSamples, 0);
      // The end of the take ignores the lag.
      expect(f.due(flush: true), 2400);
    });

    test('paused time is excluded', () {
      final clock = FakeClock();
      final f = WallClockSilenceFiller(clock: clock.call, lag: Duration.zero)
        ..start();
      clock.advance(const Duration(milliseconds: 500));
      f.pause();
      expect(f.isPaused, isTrue);
      clock.advance(const Duration(seconds: 10));
      expect(f.due(), 8000);
      f.resume();
      clock.advance(const Duration(milliseconds: 500));
      expect(f.activeTime, const Duration(seconds: 1));
      expect(f.drain(SystemAudioBuffer()).length, 16000);
      f.stop();
      expect(f.isRunning, isFalse);
      expect(f.due(), 0);
    });
  });

  group('soft limiter mixer', () {
    test('softLimit is identity below the threshold and bounded above', () {
      expect(softLimit(0.5), 0.5);
      expect(softLimit(-0.8), -0.8);
      expect(softLimit(double.nan), 0);
      for (final x in [0.81, 1.0, 1.5, 3.0, 100.0]) {
        final y = softLimit(x);
        expect(y, greaterThan(kSoftLimitThreshold));
        expect(y, lessThanOrEqualTo(1.0));
        expect(softLimit(-x), -y);
      }
      // Monotonic and continuous at the knee.
      expect(softLimit(1.2), greaterThan(softLimit(1.1)));
      expect((softLimit(0.8001) - 0.8001).abs(), lessThan(1e-6));
    });

    test('mixSoftLimited sums, applies gains and pads the shorter input', () {
      final mic = Float32List.fromList([0.1, 0.2, 0.3]);
      final sys = Float32List.fromList([0.1, -0.2]);
      final out = mixSoftLimited(mic, sys);
      expect(out.length, 3);
      expect(out[0], closeTo(0.2, 1e-6));
      expect(out[1], closeTo(0, 1e-6));
      expect(out[2], closeTo(0.3, 1e-6));
      final quiet = mixSoftLimited(mic, sys, micGain: 0.5, systemGain: 0);
      expect(quiet[2], closeTo(0.15, 1e-6));
    });

    test('loud speech on both sides never clips', () {
      final out = mixSoftLimited(_filled(10, 0.9), _filled(10, 0.9));
      expect(out.every((s) => s < 1.0 && s > 0.8), isTrue);
    });
  });

  group('LevelMeter', () {
    test('reports one reading per window', () {
      final m = LevelMeter(window: 100);
      expect(m.add(_filled(50, 0.5)), isEmpty);
      final r = m.add(_filled(250, 0.5));
      expect(r.length, 3);
      expect(r.first, greaterThan(0.8));
      expect(m.add(Float32List(100)).single, 0);
    });
  });
}
