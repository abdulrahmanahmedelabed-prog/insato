import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/codes/reversed_speech_logic.dart';

TranscriptSegment useg(int index, {String? speakerId, int durMs = 2000}) =>
    TranscriptSegment(
      id: 's$index',
      meetingId: 'm',
      index: index,
      startMs: index * 3000,
      endMs: index * 3000 + durMs,
      text: '',
      kind: SegmentKind.unintelligible,
      speakerId: speakerId,
    );

CodeFinding coded(int id, List<int> evidence, {Map<String, dynamic>? extra}) =>
    CodeFinding(
      id: id,
      meetingId: 'm',
      kind: CodeFindingKind.speechCoded,
      payload: {
        ...CodedSpeechItem(
          speaker: 'عمر',
          character: CodedSpeechCharacter.inventedLanguage,
          description: 'وصف المحرك',
          evidence: evidence,
        ).toJson(),
        ...?extra,
      },
      segmentIds: evidence,
      createdAt: DateTime(2026),
    );

void main() {
  group('audio', () {
    test('frameRangeForMs clamps to the signal', () {
      expect(
        frameRangeForMs(
          startMs: 1000,
          endMs: 1500,
          sampleRate: 16000,
          totalFrames: 100000,
        ),
        (16000, 24000),
      );
      expect(
        frameRangeForMs(
          startMs: 5000,
          endMs: 9000,
          sampleRate: 16000,
          totalFrames: 100000,
        ),
        (80000, 100000),
      );
      expect(
        frameRangeForMs(
          startMs: 9000,
          endMs: 9500,
          sampleRate: 16000,
          totalFrames: 100000,
        ),
        (100000, 100000),
      );
      expect(
        frameRangeForMs(
          startMs: 2000,
          endMs: 1000,
          sampleRate: 48000,
          totalFrames: 480000,
        ),
        (96000, 96000),
      );
      expect(
        frameRangeForMs(
          startMs: -50,
          endMs: 10,
          sampleRate: 1000,
          totalFrames: 100,
        ),
        (0, 10),
      );
    });

    test('sliceMs copies the range and reverseSamples reverses it', () {
      final signal = Float32List.fromList([
        for (var i = 0; i < 1000; i++) i / 1000,
      ]);
      final clip = sliceMs(signal, 100, 200, sampleRate: 1000);
      expect(clip.length, 100);
      expect(clip.first, closeTo(0.1, 1e-6));
      expect(clip.last, closeTo(0.199, 1e-6));
      clip[0] = 5;
      expect(signal[100], closeTo(0.1, 1e-6), reason: 'slice is a copy');

      final r = reverseSamples(Float32List.fromList([1, 2, 3, 4]));
      expect(r, [4, 3, 2, 1]);
      expect(reverseSamples(Float32List(0)), isEmpty);
      expect(reverseSamples(reverseSamples(signal)), signal);
    });
  });

  group('assessReversedAsr', () {
    test('accepts real text', () {
      final v = assessReversedAsr(
        const AsrResult(
          text: '  مرحبا   بكم ',
          language: 'ar',
          confidence: 0.8,
        ),
        durationMs: 2000,
      );
      expect(v.isAccepted, isTrue);
      expect(v.text, 'مرحبا بكم');
      expect(v.confidence, 0.8);
    });

    test('rejects silence, empty, filtered and low-confidence output', () {
      ReversedRejection? r(AsrResult a, {int ms = 2000}) =>
          assessReversedAsr(a, durationMs: ms).rejection;
      expect(
        r(const AsrResult(text: '', rejection: AsrRejection.silence)),
        ReversedRejection.noText,
      );
      expect(r(const AsrResult(text: '  ')), ReversedRejection.noText);
      expect(
        r(const AsrResult(text: 'شكرا', rejection: AsrRejection.filtered)),
        ReversedRejection.noText,
      );
      expect(
        r(const AsrResult(text: 'ربما', confidence: 0.1)),
        ReversedRejection.lowConfidence,
      );
      expect(
        r(const AsrResult(text: 'نعم نعم'), ms: 200),
        ReversedRejection.tooShort,
      );
    });

    test('rejects noise, implausible length and the forward guess', () {
      expect(
        assessReversedAsr(
          const AsrResult(text: 'ا ا ا ...'),
          durationMs: 2000,
        ).rejection,
        ReversedRejection.tooFewLetters,
      );
      expect(
        assessReversedAsr(
          const AsrResult(text: '123 456'),
          durationMs: 2000,
        ).rejection,
        ReversedRejection.tooFewLetters,
      );
      expect(
        assessReversedAsr(
          AsrResult(text: 'كلمة ' * 30),
          durationMs: 1000,
        ).rejection,
        ReversedRejection.implausibleLength,
      );
      expect(
        assessReversedAsr(
          const AsrResult(text: 'Hello, world!'),
          durationMs: 2000,
          forwardText: 'hello world',
        ).rejection,
        ReversedRejection.sameAsForward,
      );
    });
  });

  group('payload enrichment', () {
    test('ReversedSpeechResult JSON round trip and malformed input', () {
      final r = ReversedSpeechResult(
        segment: 4,
        text: 'نص',
        language: 'ar',
        confidence: 0.7,
        at: DateTime.utc(2026, 11, 19, 10),
      );
      final back = ReversedSpeechResult.tryParse(r.toJson())!;
      expect(back.segment, 4);
      expect(back.text, 'نص');
      expect(back.language, 'ar');
      expect(back.confidence, 0.7);
      expect(back.at, DateTime.utc(2026, 11, 19, 10));
      expect(const ReversedSpeechResult(segment: 1, text: 'x').toJson().keys, [
        'segment',
        'text',
      ]);
      expect(
        ReversedSpeechResult.tryParse({'segment': -1, 'text': 'x'}),
        isNull,
      );
      expect(
        ReversedSpeechResult.tryParse({'segment': 1, 'text': ' '}),
        isNull,
      );
      expect(ReversedSpeechResult.tryParse('x'), isNull);
      expect(readReversedResults(const {kReversedResultsKey: 'bad'}), isEmpty);
      expect(
        readReversedChecked(const {
          kReversedCheckedKey: [1, 'x', -2],
        }),
        {1},
      );
    });

    test('enrichPayload keeps the item and replaces re-checked results', () {
      final base = coded(1, [2, 3]).payload;
      final first = enrichPayload(
        base,
        checked: {2, 3},
        results: const [
          ReversedSpeechResult(segment: 3, text: 'أولى'),
          ReversedSpeechResult(segment: 2, text: 'ثانية'),
        ],
      );
      expect(first['description'], 'وصف المحرك');
      expect(first['character'], 'invented_language');
      expect(readReversedResults(first).map((r) => r.segment), [2, 3]);
      expect(readReversedChecked(first), {2, 3});

      // Re-checking segment 3 without a result drops only its old result.
      final second = enrichPayload(first, checked: {3}, results: const []);
      expect(readReversedResults(second).single.text, 'ثانية');
      expect(readReversedChecked(second), {2, 3});
      // Base payload untouched.
      expect(base.containsKey(kReversedResultsKey), isFalse);
    });
  });

  group('planReversedFindings', () {
    test('enriches covering findings and creates app findings', () {
      const ok = ReversedSpeechResult(segment: 5, text: 'نص معكوس');
      const ok2 = ReversedSpeechResult(segment: 7, text: 'كلام آخر');
      final plan = planReversedFindings(
        meetingId: 'm',
        findings: [
          coded(10, [5, 6]),
          coded(11, [9]),
          CodeFinding(
            id: 12,
            meetingId: 'm',
            kind: CodeFindingKind.jargon,
            payload: const {
              'term': 'x',
              'evidence': [7],
            },
            segmentIds: const [7],
            createdAt: DateTime(2026),
          ),
        ],
        attempts: [
          ReversedAttempt(segment: useg(5), result: ok),
          ReversedAttempt(segment: useg(6)),
          ReversedAttempt(
            segment: useg(7, speakerId: 'sp'),
            result: ok2,
          ),
          ReversedAttempt(segment: useg(8)),
        ],
        speakerName: (s) => s.speakerId == 'sp' ? 'سارة' : '',
        describe: (ms) => 'مدة $ms',
        now: DateTime(2026, 11, 19),
      );
      expect(plan.updates.keys, [10]);
      final p = plan.updates[10]!;
      expect(readReversedResults(p).single.text, 'نص معكوس');
      expect(readReversedChecked(p), {5, 6});
      expect(p['description'], 'وصف المحرك');

      // Segment 7 is only cited by a jargon finding: a new app finding.
      final c = plan.created.single;
      expect(c.kind, CodeFindingKind.speechCoded);
      expect(c.speakerId, 'sp');
      expect(c.segmentIds, [7]);
      expect(c.payload[kFindingOriginKey], kOriginApp);
      expect(c.payload['speaker'], 'سارة');
      expect(c.payload['character'], 'unknown');
      expect(c.payload['description'], 'مدة 2000');
      expect(c.payload['evidence'], [7]);
      expect(readReversedResults(c.payload).single.text, 'كلام آخر');
      // Segment 8 had no result and no finding: nothing is created.
      expect(plan.isEmpty, isFalse);
    });

    test('nothing to do', () {
      final plan = planReversedFindings(
        meetingId: 'm',
        findings: const [],
        attempts: [ReversedAttempt(segment: useg(1))],
        speakerName: (_) => '',
        describe: (_) => '',
      );
      expect(plan.isEmpty, isTrue);
    });
  });
}
