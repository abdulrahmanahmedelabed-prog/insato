import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/models.dart';
import 'package:insato/speech/asr_outcome.dart';
import 'package:insato/speech/cloud_asr_engine.dart';

SpeechSegment tone(double amplitude, {int ms = 1000}) {
  final n = kSampleRate * ms ~/ 1000;
  return SpeechSegment(
    index: 0,
    startMs: 0,
    samples: Float32List.fromList([
      for (var i = 0; i < n; i++) amplitude * math.sin(i * 0.05),
    ]),
  );
}

void main() {
  group('classifyAsrOutcome (F17: real speech is never dropped)', () {
    test('silence is dropped', () {
      final o = classifyAsrOutcome(
        const AsrResult(text: '', rejection: AsrRejection.silence),
      );
      expect(o.isDropped, isTrue);
      expect(o.kind, isNull);
    });

    test('recognised speech is kept as speech', () {
      final o = classifyAsrOutcome(
        const AsrResult(text: '  مرحبا ', confidence: 0.9),
      );
      expect(o.kind, SegmentKind.speech);
      expect(o.text, 'مرحبا');
      expect(o.confidence, 0.9);
    });

    test('empty / no-text / filtered output is unintelligible', () {
      for (final r in const [
        AsrResult(text: ''),
        AsrResult(text: '', rejection: AsrRejection.noText),
        AsrResult(text: 'Thank you.', rejection: AsrRejection.filtered),
      ]) {
        final o = classifyAsrOutcome(r);
        expect(o.kind, SegmentKind.unintelligible, reason: '$r');
        expect(o.text, '', reason: 'filtered output is never kept');
      }
    });

    test('low confidence keeps the guess as unintelligible', () {
      final low = classifyAsrOutcome(
        const AsrResult(text: 'ربما', confidence: 0.2),
      );
      expect(low.kind, SegmentKind.unintelligible);
      expect(low.text, 'ربما');
      expect(low.confidence, 0.2);
      final flagged = classifyAsrOutcome(
        const AsrResult(text: 'x', rejection: AsrRejection.lowConfidence),
      );
      expect(flagged.kind, SegmentKind.unintelligible);
      expect(
        classifyAsrOutcome(
          const AsrResult(text: 'ok', confidence: 0.5),
          lowConfidence: 0.6,
        ).kind,
        SegmentKind.unintelligible,
      );
    });

    test('rejection wire values round-trip', () {
      for (final r in AsrRejection.values) {
        expect(AsrRejection.tryParse(r.wire), r);
      }
      expect(AsrRejection.noText.wire, 'no_text');
      expect(AsrRejection.tryParse('nope'), isNull);
      expect(AsrRejection.tryParse(null), isNull);
    });
  });

  group('CloudAsrEngine v1.1', () {
    test('keyterms are sent as repeated parameters, deduplicated', () {
      final e = CloudAsrEngine(
        apiKeyProvider: () => 'k',
        keyterms: const ['Insato', ' Insato ', 'KPI  report', ''],
      );
      final uri = e.buildUri();
      expect(uri.queryParametersAll['keyterm'], ['Insato', 'KPI report']);
      expect(uri.queryParameters['mip_opt_out'], 'true');
      final many = CloudAsrEngine(
        apiKeyProvider: () => 'k',
        keyterms: [for (var i = 0; i < 80; i++) 't$i'],
      );
      expect(
        many.buildUri().queryParametersAll['keyterm'],
        hasLength(kMaxDeepgramKeyterms),
      );
      expect(
        CloudAsrEngine(apiKeyProvider: () => 'k').buildUri().queryParameters
            .containsKey('keyterm'),
        isFalse,
      );
    });

    test('silent audio is reported as silence without a request', () async {
      var calls = 0;
      final e = CloudAsrEngine(
        apiKeyProvider: () => 'k',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final r = await e.transcribe(tone(0.00001));
      expect(r.rejection, AsrRejection.silence);
      expect(calls, 0);
      await e.dispose();
    });

    test('an empty transcript of voiced audio is no-text', () async {
      final e = CloudAsrEngine(
        apiKeyProvider: () => 'k',
        client: MockClient(
          (_) async => http.Response(
            '{"results":{"channels":[{"alternatives":[{"transcript":"",'
            '"confidence":0}]}]}}',
            200,
          ),
        ),
      );
      final r = await e.transcribe(tone(0.3));
      expect(r.isEmpty, isTrue);
      expect(r.rejection, AsrRejection.noText);
      expect(classifyAsrOutcome(r).kind, SegmentKind.unintelligible);
      await e.dispose();
    });
  });
}
