import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/pcm.dart';

Float32List sine(double freq, int rate, int n, {double amp = 0.5}) {
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = amp * math.sin(2 * math.pi * freq * i / rate);
  }
  return out;
}

/// Splits [data] into random-size chunks (including empty and 1-byte ones).
List<Uint8List> randomChunks(Uint8List data, math.Random rnd) {
  final chunks = <Uint8List>[];
  var i = 0;
  while (i < data.length) {
    final size = math.min(rnd.nextInt(9), data.length - i);
    chunks.add(Uint8List.sublistView(data, i, i + size));
    i += size;
  }
  return chunks;
}

Float32List concat(List<Float32List> parts) {
  final total = parts.fold<int>(0, (a, p) => a + p.length);
  final out = Float32List(total);
  var o = 0;
  for (final p in parts) {
    out.setRange(o, o + p.length, p);
    o += p.length;
  }
  return out;
}

void main() {
  group('pcm16LeBytesToFloat32', () {
    test('decodes extremes and zero', () {
      final bytes = Uint8List.fromList([
        0x00,
        0x80,
        0xff,
        0x7f,
        0,
        0,
        0xff,
        0xff,
      ]);
      final f = pcm16LeBytesToFloat32(bytes);
      expect(f, hasLength(4));
      expect(f[0], -1.0);
      expect(f[1], closeTo(32767 / 32768, 1e-7));
      expect(f[2], 0);
      expect(f[3], closeTo(-1 / 32768, 1e-9));
    });

    test('ignores an odd trailing byte', () {
      expect(
        pcm16LeBytesToFloat32(Uint8List.fromList([1, 0, 9])),
        hasLength(1),
      );
    });
  });

  group('float32ToPcm16Bytes', () {
    test('round trips within one quantisation step', () {
      final s = sine(440, 16000, 1000, amp: 0.9);
      final back = pcm16LeBytesToFloat32(float32ToPcm16Bytes(s));
      for (var i = 0; i < s.length; i++) {
        expect(back[i], closeTo(s[i], 1.5 / 32768));
      }
    });

    test('clamps out-of-range values and maps NaN to silence', () {
      final bytes = float32ToPcm16Bytes(
        Float32List.fromList([2.0, -3.0, double.nan, 1.0, -1.0]),
      );
      final d = ByteData.sublistView(bytes);
      expect(d.getInt16(0, Endian.little), 32767);
      expect(d.getInt16(2, Endian.little), -32767);
      expect(d.getInt16(4, Endian.little), 0);
      expect(d.getInt16(6, Endian.little), 32767);
      expect(d.getInt16(8, Endian.little), -32767);
    });
  });

  group('Pcm16Decoder', () {
    test('odd-sized chunks decode identically to one shot', () {
      final rnd = math.Random(7);
      final data = Uint8List.fromList(
        List<int>.generate(4001, (_) => rnd.nextInt(256)),
      );
      final expected = pcm16LeBytesToFloat32(data);
      final decoder = Pcm16Decoder();
      final got = concat([
        for (final c in randomChunks(data, rnd)) decoder.convert(c),
      ]);
      expect(got, orderedEquals(expected));
      expect(decoder.hasPendingByte, isTrue); // 4001 is odd
      decoder.reset();
      expect(decoder.hasPendingByte, isFalse);
    });

    test('align() yields sample-aligned bytes equal to the input', () {
      final rnd = math.Random(3);
      final data = Uint8List.fromList(
        List<int>.generate(3000, (_) => rnd.nextInt(256)),
      );
      final decoder = Pcm16Decoder();
      final out = BytesBuilder();
      for (final c in randomChunks(data, rnd)) {
        final aligned = decoder.align(c);
        expect(aligned.length.isEven, isTrue);
        out.add(aligned);
      }
      expect(out.takeBytes(), orderedEquals(data));
      expect(decoder.hasPendingByte, isFalse);
    });

    test('single byte chunks', () {
      final decoder = Pcm16Decoder();
      expect(decoder.convert(Uint8List.fromList([0x00])), isEmpty);
      final f = decoder.convert(Uint8List.fromList([0x80]));
      expect(f, [-1.0]);
    });
  });

  group('levels', () {
    test('rms of a sine is amplitude / sqrt(2)', () {
      final s = sine(1000, 16000, 16000, amp: 0.5);
      expect(rms(s), closeTo(0.5 / math.sqrt2, 1e-3));
      expect(rms(Float32List(0)), 0);
      expect(rms(s, 0, 0), 0);
    });

    test('dBFS conversion', () {
      expect(rmsToDbfs(1.0), closeTo(0, 1e-9));
      expect(rmsToDbfs(0.1), closeTo(-20, 1e-9));
      expect(rmsToDbfs(0), kSilenceDbfs);
      expect(rmsToDbfs(double.nan), kSilenceDbfs);
    });

    test('meter level maps floor..0 dB to 0..1', () {
      expect(dbfsToMeterLevel(0), 1);
      expect(dbfsToMeterLevel(-60), 0);
      expect(dbfsToMeterLevel(-30), closeTo(0.5, 1e-9));
      expect(dbfsToMeterLevel(-90), 0);
      expect(dbfsToMeterLevel(6), 1);
      expect(dbfsToMeterLevel(-20, floorDb: -40), closeTo(0.5, 1e-9));
      expect(meterLevel(Float32List(100)), 0);
      expect(meterLevel(Float32List.fromList([1, -1, 1, -1])), 1);
    });
  });

  group('downmix', () {
    test('averages channels', () {
      final m = downmixToMono(Float32List.fromList([1, 0, 0.5, 0.5, -1, 1]), 2);
      expect(m, [0.5, 0.5, 0.0]);
      final mono = Float32List.fromList([1, 2]);
      expect(identical(downmixToMono(mono, 1), mono), isTrue);
      expect(() => downmixToMono(mono, 0), throwsArgumentError);
    });

    test('streaming downmixer handles frames split across chunks', () {
      final rnd = math.Random(11);
      final interleaved = Float32List.fromList(
        List<double>.generate(3 * 500, (_) => rnd.nextDouble() * 2 - 1),
      );
      final expected = downmixToMono(interleaved, 3);
      final mixer = InterleavedDownmixer(3);
      final parts = <Float32List>[];
      var i = 0;
      while (i < interleaved.length) {
        final n = math.min(rnd.nextInt(5), interleaved.length - i);
        parts.add(
          mixer.process(Float32List.sublistView(interleaved, i, i + n)),
        );
        i += n;
      }
      final got = concat(parts);
      expect(got.length, expected.length);
      for (var k = 0; k < got.length; k++) {
        expect(got[k], closeTo(expected[k], 1e-6));
      }
    });
  });

  group('loudspeaker downmix (loopback)', () {
    Float32List frame(int channels, Map<int, double> values, {int frames = 4}) {
      final out = Float32List(channels * frames);
      for (var f = 0; f < frames; f++) {
        values.forEach((c, v) => out[f * channels + c] = v);
      }
      return out;
    }

    double mono(int channels, Map<int, double> values) =>
        InterleavedDownmixer(channels, speakerLayout: true)
            .process(frame(channels, values))
            .first;

    test('5.1 / 7.1: front voice keeps its level, LFE is excluded', () {
      expect(mono(6, {0: 0.5, 1: 0.5}), closeTo(0.5, 1e-6));
      expect(mono(6, {2: 0.5}), closeTo(0.3536, 1e-4));
      expect(mono(8, {3: 0.9}), 0);
      expect(mono(8, {0: 0.5, 1: 0.5}), closeTo(0.5, 1e-6));
    });

    test('mono and stereo are unchanged', () {
      expect(mono(2, {0: 0.5, 1: 0.1}), closeTo(0.3, 1e-6));
      expect(mono(1, {0: 0.4}), closeTo(0.4, 1e-6));
      expect(speakerDownmixWeights(2), [0.5, 0.5]);
    });

    test('chunk boundaries carry over with six channels', () {
      final interleaved = frame(6, {0: 0.2, 1: 0.2, 2: 0.4, 4: 0.1}, frames: 50);
      final whole = InterleavedDownmixer(6, speakerLayout: true)
          .process(interleaved);
      final mixer = InterleavedDownmixer(6, speakerLayout: true);
      final parts = <Float32List>[];
      for (var i = 0; i < interleaved.length; i += 7) {
        parts.add(
          mixer.process(
            Float32List.sublistView(
              interleaved,
              i,
              math.min(i + 7, interleaved.length),
            ),
          ),
        );
      }
      final got = concat(parts);
      expect(got.length, whole.length);
      for (var k = 0; k < got.length; k++) {
        expect(got[k], closeTo(whole[k], 1e-6));
      }
    });
  });

  group('resampling', () {
    test('passthrough when rates match', () {
      final s = sine(440, 16000, 100);
      expect(identical(resampleLinear(s, 16000), s), isTrue);
      final r = StreamingResampler(inputRate: 16000);
      expect(r.isPassthrough, isTrue);
      expect(identical(r.process(s), s), isTrue);
      expect(r.flush(), isEmpty);
    });

    for (final rate in [8000, 11025, 22050, 32000, 44100, 48000, 96000]) {
      test('$rate Hz -> 16 kHz keeps length and a 440 Hz tone', () {
        const seconds = 2;
        final input = sine(440, rate, rate * seconds);
        final out = resampleLinear(input, rate);
        expect(out.length, closeTo(16000 * seconds, 1));
        final ideal = sine(440, 16000, out.length);
        // Ignore the edges, where the filter sees zero padding.
        var maxErr = 0.0;
        for (var i = 400; i < out.length - 400; i++) {
          maxErr = math.max(maxErr, (out[i] - ideal[i]).abs());
        }
        expect(maxErr, lessThan(0.02));
      });
    }

    test('downsampling attenuates content above the new Nyquist', () {
      final tone = sine(11000, 48000, 48000, amp: 0.5);
      final out = resampleLinear(tone, 48000);
      final mid = Float32List.sublistView(out, 1000, out.length - 1000);
      expect(rmsToDbfs(rms(mid)), lessThan(rmsToDbfs(rms(tone)) - 40));
    });

    test('streaming in random chunks equals one-shot', () {
      final rnd = math.Random(5);
      final input = Float32List.fromList(
        List<double>.generate(44100, (_) => rnd.nextDouble() * 2 - 1),
      );
      final expected = resampleLinear(input, 44100);
      final r = StreamingResampler(inputRate: 44100);
      final parts = <Float32List>[];
      var i = 0;
      while (i < input.length) {
        final n = math.min(rnd.nextInt(3000), input.length - i);
        parts.add(r.process(Float32List.sublistView(input, i, i + n)));
        i += n;
      }
      parts.add(r.flush());
      final got = concat(parts);
      expect(got.length, expected.length);
      for (var k = 0; k < got.length; k++) {
        expect(got[k], closeTo(expected[k], 1e-6));
      }
    });

    test('process after flush throws', () {
      final r = StreamingResampler(inputRate: 48000)..flush();
      expect(() => r.process(Float32List(10)), throwsStateError);
      expect(r.flush(), isEmpty);
    });

    test('rejects invalid rates', () {
      expect(() => StreamingResampler(inputRate: 0), throwsArgumentError);
      expect(
        () => StreamingResampler(inputRate: 16000, outputRate: -1),
        throwsArgumentError,
      );
    });

    test('a constant signal stays constant (unity DC gain)', () {
      final input = Float32List(48000)..fillRange(0, 48000, 0.25);
      final out = resampleLinear(input, 48000);
      for (var i = 200; i < out.length - 200; i++) {
        expect(out[i], closeTo(0.25, 1e-4));
      }
    });
  });

  group('PcmStreamConverter', () {
    test('identity format is detected', () {
      expect(
        PcmStreamConverter(inputSampleRate: 16000, inputChannels: 1).isIdentity,
        isTrue,
      );
      expect(
        PcmStreamConverter(inputSampleRate: 48000, inputChannels: 1).isIdentity,
        isFalse,
      );
    });

    test('48 kHz stereo bytes in odd chunks -> 16 kHz mono tone', () {
      const rate = 48000;
      final left = sine(300, rate, rate);
      final stereo = Float32List(rate * 2);
      for (var i = 0; i < rate; i++) {
        stereo[2 * i] = left[i];
        stereo[2 * i + 1] = left[i];
      }
      final bytes = float32ToPcm16Bytes(stereo);
      final conv = PcmStreamConverter(inputSampleRate: rate, inputChannels: 2);
      final rnd = math.Random(1);
      final parts = <Float32List>[];
      var i = 0;
      while (i < bytes.length) {
        final n = math.min(1 + rnd.nextInt(777), bytes.length - i);
        parts.add(conv.convert(Uint8List.sublistView(bytes, i, i + n)));
        i += n;
      }
      parts.add(conv.flush());
      final out = concat(parts);
      expect(out.length, closeTo(16000, 1));
      final ideal = sine(300, 16000, out.length);
      for (var k = 400; k < out.length - 400; k++) {
        expect(out[k], closeTo(ideal[k], 0.01));
      }
    });
  });
}
