import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/codes/codes_logic.dart';
import 'package:insato/features/codes/reversed_speech_logic.dart';

TranscriptSegment seg(
  int index, {
  String text = '',
  SegmentKind kind = SegmentKind.speech,
  int startMs = -1,
  int durMs = 2000,
  String? speakerId,
}) {
  final start = startMs < 0 ? index * 3000 : startMs;
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
  List<int> segmentIds = const [],
}) => CodeFinding(
  id: id,
  meetingId: 'm',
  kind: kind,
  payload: payload,
  createdAt: DateTime(2026),
  speakerId: speakerId,
  segmentIds: segmentIds,
);

Speaker speaker(String id, String name) => Speaker(
  id: id,
  name: name,
  colorValue: 0,
  isNamedByUser: true,
  createdAt: DateTime(2026),
);

void main() {
  group('digits', () {
    test('normalizeDigits converts Arabic-Indic and Persian digits', () {
      expect(normalizeDigits('عقد ٢٠٢٤/۰۴۲ x9'), 'عقد 2024/042 x9');
      expect(digitsOf('INV-٢٠٢٤-0042'), '20240042');
      expect(digitsOf('بدون أرقام'), '');
    });

    test('digitStreams splits on words, joins on separators', () {
      expect(digitStreams('الفاتورة 2024-0042 بتاريخ 5/3'), [
        ['2024', '0042'],
        ['5', '3'],
      ]);
      expect(digitStreams('١٢ و٣'), [
        ['12'],
        ['3'],
      ]);
      expect(digitStreams('1,500.50 ريال'), [
        ['1', '500', '50'],
      ]);
      expect(digitStreams(''), isEmpty);
    });
  });

  group('verifyReferenceText', () {
    ReferenceCheck check(String verbatim, List<String> texts, {String n = ''}) =>
        verifyReferenceText(
          verbatim: verbatim,
          normalized: n,
          evidenceTexts: texts,
        );

    test('verified when the digits appear as whole groups', () {
      expect(
        check('INV-2024/0042', ['الفاتورة رقم ٢٠٢٤ ٠٠٤٢ متأخرة']),
        ReferenceCheck.verified,
      );
      expect(check('20240042', ['رقم 2024-0042']), ReferenceCheck.verified);
      expect(check('المادة 77', ['حسب المادة ٧٧ من النظام']),
          ReferenceCheck.verified);
      expect(
        check('0042', ['الفاتورة 2024-0042']),
        ReferenceCheck.verified,
      );
    });

    test('unverified when digits differ or only match partially', () {
      expect(check('2024-0043', ['رقم 2024-0042']), ReferenceCheck.unverified);
      expect(check('42', ['رقم 0042']), ReferenceCheck.unverified);
      expect(check('123', ['قال 12 و3']), ReferenceCheck.unverified);
      expect(
        check('5000', ['خمسة آلاف ريال']),
        ReferenceCheck.unverified,
      );
    });

    test('falls back to normalized digits when verbatim has none', () {
      expect(
        check('ألفين وأربعة وعشرين', ['سنة 2024'], n: '2024'),
        ReferenceCheck.verified,
      );
    });

    test('non-numeric codes are matched as text', () {
      expect(check('ABC-X', ['المنتج abc x متوفر']), ReferenceCheck.verified);
      expect(check('ABC-Y', ['المنتج abc x متوفر']),
          ReferenceCheck.unverified);
    });

    test('no evidence text', () {
      expect(check('2024', const []), ReferenceCheck.noEvidence);
      expect(check('2024', const ['  ']), ReferenceCheck.noEvidence);
    });

    test('verifyReference uses only the evidence segments', () {
      final segments = [seg(1, text: 'العقد 5512'), seg(2, text: 'لا شيء')];
      ReferenceItem ref(List<int> ev) => ReferenceItem(
        kind: ReferenceKind.contract,
        verbatim: '5512',
        normalized: '5512',
        context: 'عقد',
        speaker: 'سارة',
        evidence: ev,
      );
      expect(verifyReference(ref([1]), segments), ReferenceCheck.verified);
      expect(verifyReference(ref([2]), segments), ReferenceCheck.unverified);
      expect(verifyReference(ref([]), segments), ReferenceCheck.noEvidence);
      expect(verifyReference(ref([9]), segments), ReferenceCheck.noEvidence);
    });
  });

  group('groupFindings', () {
    test('parses each detector and keeps stored order', () {
      final codes = groupFindings([
        finding(1, CodeFindingKind.jargon, const JargonItem(
          term: 'مشروع النسر',
          inferredMeaning: 'اسم رمزي لنظام الرواتب',
          confidence: HypothesisConfidence.medium,
          speakers: ['سارة'],
          evidence: [3],
        ).toJson()),
        finding(2, CodeFindingKind.speechCoded, const CodedSpeechItem(
          speaker: 'عمر',
          character: CodedSpeechCharacter.reversedSpeech,
          description: 'مقطع قصير',
        ).toJson(), segmentIds: [4, 5]),
        finding(3, CodeFindingKind.spokenCode, const SpokenCodeItem(
          language: 'sql',
          code: 'SELECT 1;',
          explanation: 'استعلام',
          speaker: 'سارة',
        ).toJson()),
        finding(4, CodeFindingKind.implied, const ImpliedItem(
          literal: 'لعلنا نعيد النظر',
          basis: 'نبرة',
          confidence: HypothesisConfidence.low,
          speaker: 'عمر',
        ).toJson()),
        finding(5, CodeFindingKind.reference, const ReferenceItem(
          kind: ReferenceKind.invoice,
          verbatim: '٤٢',
          normalized: '42',
          context: 'فاتورة',
          speaker: 'سارة',
        ).toJson()),
        // Unusable payloads are skipped.
        finding(6, CodeFindingKind.jargon, const {}),
        finding(7, CodeFindingKind.spokenCode, const {'code': '  '}),
      ]);
      expect(codes.jargon.single.item.term, 'مشروع النسر');
      expect(codes.jargon.single.item.evidence, [3]);
      // Evidence falls back to the row's segment ids.
      expect(codes.codedSpeech.single.item.evidence, [4, 5]);
      expect(codes.codedSpeech.single.item.character,
          CodedSpeechCharacter.reversedSpeech);
      expect(codes.spokenCode.single.item.code, 'SELECT 1;');
      expect(codes.implied.single.finding.id, 4);
      expect(codes.references.single.item.normalized, '42');
      expect(codes.isEmpty, isFalse);
      expect(codes.toMinutesCodes().jargon.single.term, 'مشروع النسر');
      expect(groupFindings(const []).isEmpty, isTrue);
    });
  });

  group('speakers and segments', () {
    test('findingSpeakerName prefers the voice library name', () {
      final speakers = {'a': speaker('a', 'سارة أحمد')};
      final f = finding(1, CodeFindingKind.implied, const {}, speakerId: 'a');
      expect(findingSpeakerName(f, 'سارة', speakers), 'سارة أحمد');
      final g = finding(2, CodeFindingKind.implied, const {});
      expect(findingSpeakerName(g, ' عمر ', speakers), 'عمر');
      expect(findingSpeakerName(g, '', speakers), isNull);
    });

    test('uncovered unintelligible segments and durations', () {
      final segments = [
        seg(3, kind: SegmentKind.unintelligible, durMs: 1500),
        seg(1, kind: SegmentKind.unintelligible, durMs: 2500, text: 'ربما'),
        seg(2, text: 'كلام'),
      ];
      final codes = groupFindings([
        finding(1, CodeFindingKind.speechCoded, const CodedSpeechItem(
          speaker: 'x',
          character: CodedSpeechCharacter.unknown,
          description: '',
          evidence: [3],
        ).toJson()),
      ]);
      expect(uncoveredUnintelligible(segments, codes).map((s) => s.index),
          [1]);
      expect(
        uncoveredUnintelligible(segments, const GroupedCodes())
            .map((s) => s.index),
        [1, 3],
      );
      expect(evidenceDurationMs([1, 3, 9], segments), 4000);
      expect(asrGuessesFor([1, 2, 3], segments), ['ربما']);
      expect(
        segmentSpeakerName(
          seg(1, speakerId: 'a'),
          {'a': speaker('a', 'سارة')},
        ),
        'سارة',
      );
      expect(segmentSpeakerName(seg(1), const {}), isNull);
    });

    test('app findings and reversed results', () {
      final f = finding(1, CodeFindingKind.speechCoded, {
        ...const CodedSpeechItem(
          speaker: '',
          character: CodedSpeechCharacter.unknown,
          description: '',
          evidence: [2],
        ).toJson(),
        kFindingOriginKey: kOriginApp,
        kReversedResultsKey: [
          {'segment': 2, 'text': 'مرحبا'},
        ],
      });
      expect(isAppFinding(f), isTrue);
      final e = groupFindings([f]).codedSpeech.single;
      expect(reversedResultsOf(e).single.text, 'مرحبا');
    });
  });

  group('code languages', () {
    test('labels and fence tags', () {
      expect(codeLanguageLabel('python'), 'Python');
      expect(codeLanguageLabel('SQL'), 'SQL');
      expect(codeLanguageLabel('elixir'), 'elixir');
      expect(codeLanguageLabel('  '), isNull);
      expect(codeFenceTag('C++'), 'cpp');
      expect(codeFenceTag('url'), 'text');
      expect(codeFenceTag('Python'), 'python');
    });
  });
}
