import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/multi_device/pcm_codec.dart';

import 'sim.dart';

void main() {
  group('PCM16 codec', () {
    test('speech round-trips losslessly and compresses', () {
      final pcm = floatToInt16(syntheticSpeech(16000));
      final enc = encodePcm16(pcm);
      expect(enc[0], kPcmCodecRice);
      expect(enc.length, lessThan(pcm.length * 2 * 0.85));
      expect(decodePcm16(enc), pcm);
    });

    test('silence compresses strongly', () {
      final pcm = Int16List(1600);
      final enc = encodePcm16(pcm);
      expect(enc.length, lessThan(300));
      expect(decodePcm16(enc), pcm);
    });

    test('full-scale noise falls back to raw and round-trips', () {
      final r = math.Random(5);
      final pcm = Int16List.fromList([
        for (var i = 0; i < 1600; i++) r.nextInt(65536) - 32768,
      ]);
      final enc = encodePcm16(pcm);
      expect(enc[0], kPcmCodecRaw);
      expect(enc.length, 3 + 3200);
      expect(decodePcm16(enc), pcm);
    });

    test('extreme jumps use the escape code', () {
      final pcm = Int16List.fromList([
        for (var i = 0; i < 600; i++) i.isEven ? 32767 : -32768,
        for (var i = 0; i < 600; i++) 0,
      ]);
      expect(decodePcm16(encodePcm16(pcm)), pcm);
    });

    test('tiny frames', () {
      for (final n in [0, 1, 2, 3, 257]) {
        final pcm = Int16List.fromList([for (var i = 0; i < n; i++) i * 7 - 3]);
        expect(decodePcm16(encodePcm16(pcm)), pcm, reason: 'n=$n');
      }
    });

    test('malformed input throws FormatException', () {
      expect(() => decodePcm16(Uint8List(2)), throwsFormatException);
      expect(
        () => decodePcm16(Uint8List.fromList([9, 1, 0, 0, 0])),
        throwsFormatException,
      );
      final enc = encodePcm16(floatToInt16(syntheticSpeech(1600)));
      expect(
        () => decodePcm16(Uint8List.sublistView(enc, 0, enc.length ~/ 2)),
        throwsFormatException,
      );
      expect(
        () => decodePcm16(Uint8List.fromList([0, 4, 0, 1, 2])),
        throwsFormatException,
      );
    });

    test('float conversion clamps', () {
      final i = floatToInt16(Float32List.fromList([2, -2, 0.5]));
      expect(i, [32767, -32768, 16384]);
      expect(int16ToFloat(i)[2], closeTo(0.5, 1e-4));
    });
  });
}
