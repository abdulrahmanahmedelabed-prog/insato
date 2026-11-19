import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:katib/core/models.dart';
import 'package:katib/speech/vad_segmenter.dart';

Float32List _ramp(int n, [int from = 0]) =>
    Float32List.fromList(List.generate(n, (i) => (from + i).toDouble()));

void main() {
  test('sample/ms conversions', () {
    expect(samplesToMs(16000), 1000);
    expect(samplesToMs(8), 0);
    expect(samplesToMs(160), 10);
    expect(msToSamples(250), 4000);
  });

  test('default config is tuned for meetings and Whisper', () {
    const c = VadSegmenterConfig();
    expect(c.threshold, 0.5);
    expect(c.minSilenceDuration, 0.5);
    expect(c.minSpeechDuration, 0.25);
    expect(c.maxSpeechDuration, 20.0);
    expect(c.windowSize, 512);
    expect(c.bufferSizeInSeconds, greaterThanOrEqualTo(60));
    expect(c.maxSegmentSeconds, lessThan(30));
  });

  group('WindowChunker', () {
    test('re-blocks arbitrary chunk sizes in order', () {
      final c = WindowChunker(4);
      final out = <double>[];
      var windows = 0;
      for (final chunk in [_ramp(3, 0), _ramp(6, 3), _ramp(1, 9), _ramp(5, 10)]) {
        for (final w in c.add(chunk)) {
          expect(w.length, 4);
          out.addAll(w);
          windows++;
        }
      }
      expect(windows, 3);
      expect(out, List.generate(12, (i) => i.toDouble()));
      expect(c.pending, 3);
      expect(c.takeRemainder(), [12.0, 13.0, 14.0]);
      expect(c.pending, 0);
      expect(c.takeRemainder(), isEmpty);
    });

    test('windows are independent copies', () {
      final c = WindowChunker(2);
      final w1 = c.add(_ramp(2)).single;
      c.add(_ramp(2, 10));
      expect(w1, [0.0, 1.0]);
    });
  });

  group('AudioHistory', () {
    test('slices by absolute index across wrap-around', () {
      final h = AudioHistory(10);
      h.append(_ramp(7, 0));
      h.append(_ramp(7, 7)); // 0..13, keeps 4..13
      expect(h.startIndex, 4);
      expect(h.endIndex, 14);
      expect(h.slice(4, 14), List.generate(10, (i) => (i + 4).toDouble()));
      expect(h.slice(8, 11), [8.0, 9.0, 10.0]);
      expect(() => h.slice(3, 5), throwsRangeError);
      expect(() => h.slice(10, 15), throwsRangeError);
    });

    test('appending more than capacity keeps the newest samples', () {
      final h = AudioHistory(5);
      h.append(_ramp(12));
      expect(h.startIndex, 7);
      expect(h.endIndex, 12);
      expect(h.slice(7, 12), [7.0, 8.0, 9.0, 10.0, 11.0]);
    });
  });

  group('splitLongSegment', () {
    test('returns the segment untouched when short enough', () {
      final s = Float32List(100);
      final pieces = splitLongSegment(s, 100);
      expect(pieces.single.offset, 0);
      expect(identical(pieces.single.samples, s), isTrue);
    });

    test('splits at the quietest frame and preserves every sample', () {
      // 25 s of "speech" with a silent gap at 18 s.
      final n = 25 * kSampleRate;
      final s = Float32List(n);
      for (var i = 0; i < n; i++) {
        s[i] = 0.5 * ((i % 40) < 20 ? 1 : -1);
      }
      final gapStart = 18 * kSampleRate;
      for (var i = gapStart; i < gapStart + 1600; i++) {
        s[i] = 0;
      }
      final max = 20 * kSampleRate;
      final pieces = splitLongSegment(s, max);
      expect(pieces, hasLength(2));
      expect(pieces[0].samples.length, lessThanOrEqualTo(max));
      final cut = pieces[1].offset;
      expect(cut, inInclusiveRange(gapStart, gapStart + 1600));
      expect(pieces[0].samples.length + pieces[1].samples.length, n);
      expect(pieces[1].samples.first, s[cut]);
    });

    test('very long audio yields pieces all within the limit', () {
      final s = Float32List(100 * kSampleRate);
      for (var i = 0; i < s.length; i++) {
        s[i] = (i % 7) / 10;
      }
      final max = 29 * kSampleRate;
      final pieces = splitLongSegment(s, max);
      expect(pieces.length, greaterThanOrEqualTo(4));
      var expectedOffset = 0;
      for (final pc in pieces) {
        expect(pc.offset, expectedOffset);
        expect(pc.samples.length, lessThanOrEqualTo(max));
        expectedOffset += pc.samples.length;
      }
      expect(expectedOffset, s.length);
    });
  });
}
