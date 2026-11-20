import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/codes/codes_export.dart';
import 'package:insato/features/codes/codes_logic.dart';
import 'package:insato/features/codes/reversed_speech_logic.dart';
import 'package:insato/features/codes/strings.dart';

TranscriptSegment seg(
  int index, {
  String text = '',
  SegmentKind kind = SegmentKind.speech,
  int? startMs,
  int durMs = 2000,
  String? speakerId,
}) {
  final start = startMs ?? index * 3000;
  return TranscriptSegment(
    id: 's$index',
    meetingId: 'm',
    index: index,
    startMs: start,
    endMs: start + durMs,
    text: text,
    kind: kind,
    speakerId: speakerId,
  );
}

CodeFinding finding(
  int id,
  CodeFindingKind kind,
  Map<String, dynamic> payload, {
  String? speakerId,
}) => CodeFinding(
  id: id,
  meetingId: 'm',
  kind: kind,
  payload: payload,
  createdAt: DateTime(2026),
  speakerId: speakerId,
);

Speaker speaker(String id, String name) => Speaker(
  id: id,
  name: name,
  colorValue: 0,
  isNamedByUser: true,
  createdAt: DateTime(2026),
);

void main() {
  group('jargon logic', () {
    final segments = [
      seg(0, startMs: 9000, speakerId: 'a'),
      seg(1, startMs: 4000, speakerId: 'b'),
      seg(2, startMs: 12000, speakerId: 'a'),
      seg(3, startMs: 15000),
    ];
    final speakers = {'a': speaker('a', 'سارة'), 'b': speaker('b', 'عمر')};

    test('jargonFirstUseMs is the earliest cited segment', () {
      const item = JargonItem(
        term: 'فينيق',
        inferredMeaning: 'مشروع',
        confidence: HypothesisConfidence.medium,
        evidence: [0, 1, 2],
      );
      expect(jargonFirstUseMs(item, segments), 4000);
      const none = JargonItem(
        term: 'x',
        inferredMeaning: '',
        confidence: HypothesisConfidence.low,
        evidence: [42],
      );
      expect(jargonFirstUseMs(none, segments), isNull);
    });

    test('jargonSpeakers keeps the engine list when given', () {
      const item = JargonItem(
        term: 't',
        inferredMeaning: '',
        confidence: HypothesisConfidence.low,
        speakers: ['  منى ', ''],
        evidence: [0, 1, 2],
      );
      expect(jargonSpeakers(item, segments, speakers), ['منى']);
    });

    test('jargonSpeakers counts evidence speakers, most frequent first', () {
      const item = JargonItem(
        term: 't',
        inferredMeaning: '',
        confidence: HypothesisConfidence.low,
        evidence: [0, 1, 2, 3],
      );
      expect(jargonSpeakers(item, segments, speakers), ['سارة', 'عمر']);
      const tie = JargonItem(
        term: 't',
        inferredMeaning: '',
        confidence: HypothesisConfidence.low,
        evidence: [0, 1],
      );
      // Tie: first-use order (segment 1 at 4 s is عمر).
      expect(jargonSpeakers(tie, segments, speakers), ['عمر', 'سارة']);
    });

    test('resolveSpeakerNames follows the voice library', () {
      final grouped = groupFindings([
        finding(
          1,
          CodeFindingKind.implied,
          const ImpliedItem(
            literal: 'ربما نؤجل',
            basis: '',
            confidence: HypothesisConfidence.low,
            speaker: 'متحدث 1',
          ).toJson(),
          speakerId: 'a',
        ),
        finding(
          2,
          CodeFindingKind.reference,
          const ReferenceItem(
            kind: ReferenceKind.invoice,
            verbatim: '42',
            normalized: '42',
            context: '',
            speaker: 'كما في المحضر',
          ).toJson(),
        ),
      ]);
      final r = resolveSpeakerNames(grouped, segments, speakers);
      expect(r.implied.single.item.speaker, 'سارة');
      expect(r.references.single.item.speaker, 'كما في المحضر');
    });
  });

  group('renderCodesSection', () {
    test('empty codes and no unintelligible segment render nothing', () {
      expect(renderCodesSection(codes: const MinutesCodes()), '');
    });

    test('markdown: five sections, hypotheses wording, fenced code', () {
      final segments = [
        seg(0, text: 'الفاتورة 2024-0042', startMs: 61000),
        seg(1, kind: SegmentKind.unintelligible, startMs: 3000),
        seg(2, text: 'مشروع فينيق', startMs: 5000),
      ];
      const codes = MinutesCodes(
        codedSpeech: [
          CodedSpeechItem(
            speaker: 'سارة',
            character: CodedSpeechCharacter.reversedSpeech,
            description: 'مقطع قصير',
            hypotheses: [
              CodeHypothesis(
                meaning: 'اسم مورّد',
                confidence: HypothesisConfidence.low,
                basis: 'السياق',
              ),
            ],
            evidence: [1],
          ),
        ],
        jargon: [
          JargonItem(
            term: 'فينيق',
            inferredMeaning: 'اسم رمزي لمشروع',
            confidence: HypothesisConfidence.medium,
            speakers: ['سارة', 'عمر'],
            evidence: [2],
          ),
        ],
        spokenCode: [
          SpokenCodeItem(
            language: 'python',
            code: 'print("```")\n',
            explanation: 'يطبع نصًا',
            speaker: 'عمر',
            issues: ['لا شيء'],
            evidence: [2],
          ),
        ],
        implied: [
          ImpliedItem(
            literal: 'لعلنا نراجع الأمر لاحقًا',
            basis: 'نبرة متحفظة',
            confidence: HypothesisConfidence.low,
            speaker: 'عمر',
            possibleMeanings: ['اعتراض مهذب'],
          ),
        ],
        references: [
          ReferenceItem(
            kind: ReferenceKind.invoice,
            verbatim: '2024-0042',
            normalized: 'INV-2024-0042',
            context: 'فاتورة | المورّد',
            speaker: 'سارة',
            evidence: [0],
          ),
        ],
      );
      final out = renderCodesSection(
        codes: codes,
        segments: segments,
        reversed: {
          1: [const ReversedSpeechResult(segment: 1, text: 'مرحبا')],
        },
      );
      expect(out, startsWith('## ${KS.exportTitle}\n'));
      expect(out, contains('_${KS.exportCaveat}_'));
      for (final h in [
        KS.codedSpeechTitle,
        KS.jargonTitle,
        KS.spokenCodeTitle,
        KS.impliedTitle,
        KS.referencesTitle,
      ]) {
        expect(out, contains('### $h'));
      }
      expect(
        out,
        contains(
          '${KS.hypothesis} (${KS.confidence(HypothesisConfidence.low)}): '
          'اسم مورّد',
        ),
      );
      expect(out, contains('«مرحبا» (#1)'));
      expect(out, contains('(${KS.inferred}، '));
      expect(out, contains(KS.firstUse('00:00:05')));
      expect(out, contains(KS.speakersLine(['سارة', 'عمر'])));
      // A longer fence than the backticks inside the code.
      expect(out, contains('````python\nprint("```")\n````'));
      expect(out, contains('**Python** — ${KS.speakerLine('عمر')}'));
      expect(out, contains('${KS.hypothesis} ('));
      expect(out, contains('اعتراض مهذب'));
      // Table cells escape pipes; the digits are verified.
      expect(out, contains('فاتورة \\| المورّد'));
      expect(out, contains(KS.verified));
      expect(out, contains('00:01:01'));
    });

    test('plain text indents code and underlines headings', () {
      const codes = MinutesCodes(
        spokenCode: [
          SpokenCodeItem(
            language: '',
            code: 'SELECT 1;\nSELECT 2;',
            explanation: '',
            speaker: '',
          ),
        ],
      );
      final out = renderCodesSection(
        codes: codes,
        format: CodesExportFormat.text,
      );
      expect(out, isNot(contains('```')));
      expect(out, contains('    SELECT 1;\n    SELECT 2;'));
      expect(
        out,
        contains('${KS.exportTitle}\n${'=' * KS.exportTitle.length}'),
      );
      expect(out, contains(KS.unknownLanguage));
      expect(out, contains(KS.speakerLine(KS.unknownSpeaker)));
    });

    test('from findings: uncovered segments, reversed results, renames', () {
      final segments = [
        seg(0, kind: SegmentKind.unintelligible, speakerId: 'a'),
        seg(1, kind: SegmentKind.unintelligible, speakerId: 'b'),
      ];
      final payload = enrichPayload(
        const CodedSpeechItem(
          speaker: 'متحدث 1',
          character: CodedSpeechCharacter.unknown,
          description: '',
          evidence: [0],
        ).toJson(),
        checked: {0},
        results: [const ReversedSpeechResult(segment: 0, text: 'سر')],
      );
      final out = renderCodesSectionFromFindings(
        findings: [
          finding(1, CodeFindingKind.speechCoded, payload, speakerId: 'a'),
        ],
        segments: segments,
        speakersById: {'a': speaker('a', 'سارة'), 'b': speaker('b', 'عمر')},
      );
      expect(out, contains('**سارة**'));
      expect(out, isNot(contains('متحدث 1')));
      expect(out, contains(KS.noHypotheses));
      expect(out, contains('«سر» (#0)'));
      expect(out, contains('**${KS.otherUnintelligibleTitle}**'));
      expect(out, contains('عمر — ${KS.duration(2000)}'));
    });
  });
}
