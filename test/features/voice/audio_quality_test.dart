import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/voice/audio_quality.dart';

import 'voice_fakes.dart';

SpeechSpan msSpan(int startMs, int endMs) =>
    SpeechSpan(millisToSamples(startMs), millisToSamples(endMs));

void main() {
  group('normalizeSpans', () {
    test('sorts, clamps and merges overlapping spans', () {
      final spans = normalizeSpans(const [
        SpeechSpan(500, 900),
        SpeechSpan(-10, 100),
        SpeechSpan(80, 200),
        SpeechSpan(900, 1000),
        SpeechSpan(1500, 3000),
      ], 2000);
      expect(spans, const [
        SpeechSpan(0, 200),
        SpeechSpan(500, 1000),
        SpeechSpan(1500, 2000),
      ]);
    });

    test('drops spans outside the audio', () {
      expect(normalizeSpans(const [SpeechSpan(3000, 4000)], 2000), isEmpty);
    });
  });

  group('analyzeAudioQuality', () {
    test('a good 12 s reading passes', () {
      final audio = readingTake(segments: 5, speechMs: 2200);
      final report = analyzeAudioQuality(audio, energySpeechSpans(audio));
      expect(report.passed, isTrue, reason: '$report');
      expect(report.issues, isEmpty);
      expect(report.voicedMs, greaterThanOrEqualTo(10000));
      expect(report.speechDbfs, closeTo(-17, 1.5));
      expect(report.noiseDbfs, lessThan(-60));
      expect(report.snrDb, greaterThan(30));
      expect(report.clippedRatio, 0);
    });

    test('less than 8 s of speech is blocking', () {
      final audio = readingTake(segments: 3, speechMs: 2000);
      final report = analyzeAudioQuality(audio, energySpeechSpans(audio));
      expect(report.passed, isFalse);
      expect(report.has(AudioQualityIssueKind.tooLittleSpeech), isTrue);
    });

    test('padding is not counted as speech', () {
      final audio = readingTake(segments: 4, speechMs: 2100);
      final spans = energySpeechSpans(audio);
      final plain = analyzeAudioQuality(audio, spans);
      final padded = analyzeAudioQuality(audio, spans, paddingMsPerSpan: 300);
      expect(plain.voicedMs - padded.voicedMs, 4 * 300);
      expect(padded.has(AudioQualityIssueKind.tooLittleSpeech), isTrue);
    });

    test('the mic test needs no minimum speech', () {
      final audio = join([noise(500), tone(2000), noise(500)]);
      final report = analyzeAudioQuality(
        audio,
        energySpeechSpans(audio),
        config: AudioQualityConfig.micTest,
      );
      expect(report.passed, isTrue);
    });

    test('silence is reported as no speech', () {
      final audio = noise(5000);
      final report = analyzeAudioQuality(audio, const []);
      expect(report.has(AudioQualityIssueKind.noSpeech), isTrue);
      expect(report.passed, isFalse);
      expect(report.speechDbfs, lessThan(-100));
      expect(report.snrDb, 0);
    });

    test('heavy clipping blocks, light clipping warns', () {
      final heavy = readingTake(segments: 5, amplitude: 1.4);
      for (var i = 0; i < heavy.length; i++) {
        heavy[i] = heavy[i].clamp(-1.0, 1.0);
      }
      final r1 = analyzeAudioQuality(heavy, energySpeechSpans(heavy));
      expect(r1.has(AudioQualityIssueKind.clipping), isTrue);
      expect(r1.passed, isFalse);
      expect(r1.peak, 1.0);

      final light = readingTake(segments: 5);
      // ~0.05 % of samples at full scale.
      for (var i = 0; i < light.length; i += 2000) {
        light[i] = 1.0;
      }
      final r2 = analyzeAudioQuality(light, energySpeechSpans(light));
      expect(r2.has(AudioQualityIssueKind.someClipping), isTrue);
      expect(r2.has(AudioQualityIssueKind.clipping), isFalse);
      expect(r2.passed, isTrue);
    });

    test('very quiet speech blocks, quiet speech warns', () {
      final veryQuiet = readingTake(segments: 5, amplitude: 0.008);
      final spans = [
        for (var i = 0; i < 5; i++)
          msSpan(400 + i * 2600, 400 + i * 2600 + 2200),
      ];
      final r1 = analyzeAudioQuality(veryQuiet, spans);
      expect(r1.has(AudioQualityIssueKind.tooQuiet), isTrue);
      expect(r1.passed, isFalse);

      final quiet = readingTake(segments: 5, amplitude: 0.025);
      final r2 = analyzeAudioQuality(quiet, spans);
      expect(r2.has(AudioQualityIssueKind.quiet), isTrue);
      expect(r2.has(AudioQualityIssueKind.tooQuiet), isFalse);
      expect(r2.passed, isTrue);
    });

    test('loud background earns a noise warning', () {
      final audio = join([
        noise(400, amplitude: 0.08),
        for (var i = 0; i < 5; i++) ...[
          tone(2200),
          noise(400, amplitude: 0.08, seed: i + 5),
        ],
      ]);
      final spans = [
        for (var i = 0; i < 5; i++)
          msSpan(400 + i * 2600, 400 + i * 2600 + 2200),
      ];
      final report = analyzeAudioQuality(audio, spans);
      expect(report.has(AudioQualityIssueKind.noisy), isTrue);
      expect(report.passed, isTrue);
    });

    test('blocking issues are listed first', () {
      final audio = readingTake(segments: 2, amplitude: 0.025);
      final report = analyzeAudioQuality(audio, energySpeechSpans(audio));
      expect(report.issues.first.blocking, isTrue);
      expect(report.issues.last.blocking, isFalse);
    });
  });

  group('energySpeechSpans', () {
    test('finds tone bursts in noise', () {
      final audio = join([
        noise(1000),
        tone(1500),
        noise(1000, seed: 2),
        tone(800),
        noise(1000, seed: 3),
      ]);
      final spans = energySpeechSpans(audio);
      expect(spans, hasLength(2));
      expect(spans[0].durationMs, closeTo(1500, 60));
      expect(spans[0].startSample, closeTo(millisToSamples(1000), 900));
      expect(spans[1].durationMs, closeTo(800, 60));
    });

    test('bridges short gaps and drops tiny blips', () {
      final audio = join([
        noise(1000),
        tone(600),
        noise(200, seed: 2),
        tone(600),
        noise(1000, seed: 3),
        tone(100),
        noise(1000, seed: 4),
      ]);
      final spans = energySpeechSpans(audio);
      expect(spans, hasLength(1));
      expect(spans.single.durationMs, closeTo(1400, 60));
    });

    test('speech almost throughout is still found', () {
      final audio = join([noise(200), tone(4800)]);
      final spans = energySpeechSpans(audio);
      expect(spans, hasLength(1));
      expect(spans.single.durationMs, closeTo(4800, 60));
    });

    test('empty and too-short audio yield nothing', () {
      expect(energySpeechSpans(Float32List(0)), isEmpty);
      expect(energySpeechSpans(Float32List(100)), isEmpty);
    });
  });

  group('LiveLevelMonitor', () {
    test('waits, then reports good speech and counts voiced time', () {
      final m = LiveLevelMonitor();
      expect(m.hint, LiveSignalHint.waiting);
      m.add(noise(500));
      m.add(tone(3000));
      expect(m.hint, LiveSignalHint.good);
      expect(m.voicedMs, closeTo(3000, 150));
      expect(m.elapsedMs, 3500);
      expect(m.clippedEver, isFalse);
    });

    test('flags clipping while it lasts', () {
      final m = LiveLevelMonitor();
      m.add(noise(500));
      final loud = tone(500, amplitude: 1.5);
      for (var i = 0; i < loud.length; i++) {
        loud[i] = loud[i].clamp(-1.0, 1.0);
      }
      m.add(loud);
      expect(m.hint, LiveSignalHint.clipping);
      expect(m.clippedEver, isTrue);
      m.add(tone(3000));
      expect(m.hint, LiveSignalHint.good);
    });

    test('flags speech that stays too quiet', () {
      final m = LiveLevelMonitor();
      m.add(noise(500, amplitude: 0.0005));
      m.add(tone(3500, amplitude: 0.005));
      expect(m.hint, LiveSignalHint.tooQuiet);
    });

    test('ignores non-finite samples and resets', () {
      final m = LiveLevelMonitor();
      m.add(Float32List.fromList(List.filled(1600, double.nan)));
      expect(m.lastFrameDbfs.isFinite, isTrue);
      m.add(tone(1000));
      m.reset();
      expect(m.elapsedMs, 0);
      expect(m.voicedMs, 0);
      expect(m.hint, LiveSignalHint.waiting);
      expect(m.noiseFloorDbfs, isNull);
    });
  });

  test('sample/ms conversions', () {
    expect(samplesToMillis(kSampleRate), 1000);
    expect(millisToSamples(250), kSampleRate ~/ 4);
  });
}
