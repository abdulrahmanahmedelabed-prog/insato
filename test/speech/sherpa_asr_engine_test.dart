import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/speech/model_catalog.dart';
import 'package:insato/speech/sherpa_asr_engine.dart';

String clean(String s) => WhisperOutputFilter.clean(s);

void main() {
  group('WhisperOutputFilter', () {
    test('keeps ordinary speech untouched', () {
      const ar = 'نبدأ الاجتماع بمراجعة الميزانية للربع الثالث.';
      expect(clean(ar), ar);
      expect(clean('  The budget is 3.5 million.  '),
          'The budget is 3.5 million.');
      expect(clean('Thank you.'), 'Thank you.');
      expect(clean('شكراً لكم جميعاً على الحضور.'),
          'شكراً لكم جميعاً على الحضور.');
      expect(clean('Visit insato.app (beta) today.'),
          'Visit insato.app (beta) today.');
      expect(clean('لا لا لا'), 'لا لا لا');
    });

    test('removes non-speech annotations', () {
      expect(clean('[موسيقى]'), '');
      expect(clean('[Music]'), '');
      expect(clean('(تصفيق)'), '');
      expect(clean('♪ ♪'), '');
      expect(clean('*laughs* okay let us start'), 'okay let us start');
      expect(clean('(applause) Welcome everyone'), 'Welcome everyone');
      expect(clean('[BLANK_AUDIO]'), '');
      expect(clean('<|ar|> مرحبا'), 'مرحبا');
    });

    test('drops subtitle credits and thanks-for-watching hallucinations', () {
      expect(clean('Thank you for watching!'), '');
      expect(clean('Thanks for watching.'), '');
      expect(clean('Subtitles by the Amara.org community'), '');
      expect(clean('ترجمة نانسي قنقر'), '');
      expect(clean('اشتركوا في القناة'), '');
      expect(clean('شكرا للمشاهدة'), '');
      expect(clean('شكراً على المشاهدة'), '');
      expect(clean('Sous-titres réalisés par la communauté d\'Amara.org'), '');
      expect(clean('ご視聴ありがとうございました'), '');
      expect(clean('We approved the plan. Thanks for watching!'),
          'We approved the plan.');
      expect(clean('you'), '');
      expect(clean('...'), '');
    });

    test('collapses runaway repetition loops', () {
      expect(clean('okay okay okay okay okay okay'), 'okay');
      expect(
          clean('we will meet tomorrow we will meet tomorrow '
              'we will meet tomorrow we will meet tomorrow'),
          'we will meet tomorrow');
      expect(clean('نعم، نعم، نعم، نعم، نعم'), 'نعم،');
      expect(clean('هههههههههههههههههههههههه'), 'ههه');
      expect(clean('Revenue was 10000000000 dollars'),
          'Revenue was 10000000000 dollars');
    });

    test('collapseRepetitions keeps short legitimate repeats', () {
      expect(WhisperOutputFilter.collapseRepetitions('no no no'), 'no no no');
      expect(WhisperOutputFilter.collapseRepetitions('a b a b'), 'a b a b');
      expect(WhisperOutputFilter.collapseRepetitions('x y x y x y z'), 'x y z');
    });
  });

  group('language helpers', () {
    test('normalizeWhisperLanguage', () {
      expect(normalizeWhisperLanguage('<|ar|>'), 'ar');
      expect(normalizeWhisperLanguage('en'), 'en');
      expect(normalizeWhisperLanguage('Arabic'), 'ar');
      expect(normalizeWhisperLanguage(''), isNull);
      expect(normalizeWhisperLanguage(null), isNull);
      expect(normalizeWhisperLanguage('<||>'), isNull);
    });

    test('normalizeLanguageCode', () {
      expect(normalizeLanguageCode('en-US'), 'en');
      expect(normalizeLanguageCode(' AR '), 'ar');
      expect(normalizeLanguageCode('pt_BR'), 'pt');
      expect(normalizeLanguageCode(''), isNull);
      expect(normalizeLanguageCode('multi'), isNull);
      expect(normalizeLanguageCode(null), isNull);
    });
  });

  group('audio preparation', () {
    test('pads short segments to 1 s, centred', () {
      final s = Float32List.fromList(List.filled(4000, 0.5));
      final out = prepareForWhisper(s);
      expect(out.length, kSampleRate);
      expect(out[0], 0);
      expect(out[out.length - 1], 0);
      expect(out[(kSampleRate - 4000) ~/ 2], 0.5);
      expect(s[0], 0.5, reason: 'input untouched');
    });

    test('long segments keep their length; quiet audio is amplified', () {
      final quiet = Float32List.fromList(
          List.generate(2 * kSampleRate, (i) => i.isEven ? 0.05 : -0.05));
      final out = prepareForWhisper(quiet);
      expect(out.length, quiet.length);
      expect(out[0], closeTo(0.4, 1e-6), reason: 'gain capped at 8x');
      final loud = Float32List.fromList(List.filled(kSampleRate, 0.6));
      expect(prepareForWhisper(loud)[10], closeTo(0.6, 1e-6));
      final silent = Float32List(kSampleRate);
      expect(prepareForWhisper(silent).every((v) => v == 0), isTrue);
    });

    test('rmsDbfs', () {
      expect(rmsDbfs(Float32List(10)), -120);
      expect(rmsDbfs(Float32List(0)), -120);
      expect(rmsDbfs(Float32List.fromList(List.filled(100, 1.0))),
          closeTo(0, 1e-9));
      expect(rmsDbfs(Float32List.fromList(List.filled(100, 0.1))),
          closeTo(-20, 1e-4));
    });

    test('recommendedThreadCount', () {
      expect(recommendedThreadCount(1), 1);
      expect(recommendedThreadCount(2), 1);
      expect(recommendedThreadCount(4), 3);
      expect(recommendedThreadCount(16), 4);
      expect(recommendedThreadCount(), inInclusiveRange(1, 4));
    });
  });

  test('engine name derives from the model files', () {
    final e = SherpaAsrEngine(
      paths: const WhisperModelPaths(
        encoder: '/m/turbo-encoder.int8.onnx',
        decoder: '/m/turbo-decoder.int8.onnx',
        tokens: '/m/turbo-tokens.txt',
      ),
      numThreads: 2,
    );
    expect(e.name, 'whisper-turbo (on-device)');
    expect(e.numThreads, 2);
  });
}
