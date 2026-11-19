import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/ask/ask_answer.dart';
import 'package:insato/features/ask/ask_prompt.dart';
import 'package:insato/features/ask/ask_retrieval.dart';

AskMeetingRef refOf(
  int alias,
  String id, {
  Map<int, int> segments = const {},
}) => AskMeetingRef(
  meetingId: id,
  alias: alias,
  title: 'اجتماع $alias',
  createdAt: DateTime(2026, 11, alias),
  segmentStartMs: segments,
);

void main() {
  final refs = {
    1: refOf(1, 'm-a', segments: {3: 30000, 4: 40000}),
    2: refOf(2, 'm-b', segments: {7: 3723000}),
  };

  group('parseAskEngineOutput', () {
    test('reads the schema object', () {
      final raw = parseAskEngineOutput(
        '{"answer": " تقرر التأجيل [M1#3] ", "answer_found": true}',
      )!;
      expect(raw.answer, 'تقرر التأجيل [M1#3]');
      expect(raw.found, isTrue);
    });

    test('answer_found false is kept', () {
      final raw = parseAskEngineOutput(
        '{"answer":"لا تذكر الاجتماعات ذلك.","answer_found":false}',
      )!;
      expect(raw.found, isFalse);
    });

    test('tolerates fences and prose around the JSON', () {
      final raw = parseAskEngineOutput(
        'Here it is:\n```json\n{"answer":"نعم [M2]","answer_found":true}\n```',
      )!;
      expect(raw.answer, 'نعم [M2]');
    });

    test('accepts a plain-text answer from a local model', () {
      final raw = parseAskEngineOutput('الإجابة بنص عادي [M1]')!;
      expect(raw.answer, 'الإجابة بنص عادي [M1]');
      expect(raw.found, isTrue);
    });

    test('rejects empty or unusable output', () {
      expect(parseAskEngineOutput(''), isNull);
      expect(parseAskEngineOutput('   '), isNull);
      expect(parseAskEngineOutput('{"answer":"","answer_found":true}'), isNull);
      expect(parseAskEngineOutput('{"answer_found":true}'), isNull);
    });
  });

  group('linkAskAnswer', () {
    test('turns references into numbered citations with timestamps', () {
      final linked = linkAskAnswer(
        'تقرر الإطلاق في ديسمبر [M1#3]، وتتولى ليلى الحملة [M2#7].',
        refs,
      );
      expect(linked.sources, hasLength(2));
      final first = linked.sources[0];
      expect(first.number, 1);
      expect(first.meetingId, 'm-a');
      expect(first.segmentIndex, 3);
      expect(first.timestamp, '00:00:30');
      expect(first.label, 'اجتماع 1 — 00:00:30');
      expect(linked.sources[1].timestamp, '01:02:03');
      expect(linked.parts, [
        const AskTextPart('تقرر الإطلاق في ديسمبر'),
        AskCitationPart(first),
        const AskTextPart('، وتتولى ليلى الحملة'),
        AskCitationPart(linked.sources[1]),
        const AskTextPart('.'),
      ]);
      expect(linked.plainText, 'تقرر الإطلاق في ديسمبر، وتتولى ليلى الحملة.');
      expect(
        linked.modelText,
        'تقرر الإطلاق في ديسمبر [M1#3]، وتتولى ليلى الحملة [M2#7].',
      );
    });

    test('reuses the number of a repeated reference', () {
      final linked = linkAskAnswer('أ [M1#3] ب [M1#3] ج [M1#4]', refs);
      expect(linked.sources.map((s) => s.number), [1, 2]);
      final markers = linked.parts.whereType<AskCitationPart>().toList();
      expect(markers.map((m) => m.citation.number), [1, 1, 2]);
    });

    test('groups with several references and continuation ids', () {
      final linked = linkAskAnswer('قرار [M1#3، #4][M2]', refs);
      expect(linked.sources.map((s) => '${s.meetingId}#${s.segmentIndex}'), [
        'm-a#3',
        'm-a#4',
        'm-b#null',
      ]);
      expect(linked.modelText, 'قرار [M1#3][M1#4][M2]');
    });

    test('accepts Arabic-Indic digits and lower-case aliases', () {
      final linked = linkAskAnswer('نعم [m١#٣]', refs);
      expect(linked.sources.single.segmentIndex, 3);
    });

    test('drops unknown meetings and degrades unknown segments', () {
      final linked = linkAskAnswer('أ [M9#1] ب [M1#99] ج', refs);
      expect(linked.sources, hasLength(1));
      final c = linked.sources.single;
      expect(c.meetingId, 'm-a');
      expect(c.segmentIndex, isNull);
      expect(c.timestamp, isNull);
      expect(c.label, 'اجتماع 1');
      expect(linked.plainText, 'أ ب ج');
      expect(linked.modelText, 'أ ب [M1] ج');
    });

    test('a meeting cited with and without a missing segment is one source',
        () {
      final linked = linkAskAnswer('أ [M1] ب [M1#99]', refs);
      expect(linked.sources, hasLength(1));
    });

    test('leaves brackets that are not references as text', () {
      final linked = linkAskAnswer('القائمة [1] و[ملاحظة] و[#5]', refs);
      expect(linked.sources, isEmpty);
      expect(linked.plainText, 'القائمة [1] و[ملاحظة] و[#5]');
    });

    test('removes Markdown emphasis', () {
      final linked = linkAskAnswer('**مهم** جداً', refs);
      expect(linked.plainText, 'مهم جداً');
    });

    test('an answer without references has no sources', () {
      final linked = linkAskAnswer('لا تتضمن الاجتماعات ذلك.', refs);
      expect(linked.sources, isEmpty);
      expect(linked.parts, [const AskTextPart('لا تتضمن الاجتماعات ذلك.')]);
    });
  });

  group('prompt', () {
    test('schema is strict', () {
      final s = askAnswerSchema();
      expect(s['additionalProperties'], isFalse);
      expect(
        (s['required'] as List).toSet(),
        (s['properties'] as Map).keys.toSet(),
      );
    });

    test('budgets per engine', () {
      expect(askPromptCharBudget('claude'), greaterThan(askPromptCharBudget('local')));
      expect(askPromptCharBudget('gemini'), greaterThan(askPromptCharBudget('server')));
      expect(askPromptCharBudget('unknown'), askPromptCharBudget('server'));
    });

    test('history keeps the latest turns and clips answers', () {
      final history = [
        for (var i = 0; i < kAskHistoryTurns + 2; i++)
          AskHistoryTurn(question: 'سؤال $i', answer: 'ج' * 5000),
      ];
      final text = renderAskHistory(history);
      expect(text, isNot(contains('سؤال 0')));
      expect(text, isNot(contains('سؤال 1<')));
      expect(text, contains('سؤال ${kAskHistoryTurns + 1}'));
      expect(text.length, lessThan(kAskHistoryTurns * 1500));
      expect(renderAskHistory(const []), isEmpty);
    });

    test('user message contains history, context, question and notice', () {
      final msg = buildAskUserMessage(
        question: '  ما موعد الإطلاق؟ ',
        context: '<meetings_catalog>\nM1 | x\n</meetings_catalog>\n',
        now: DateTime(2026, 11, 19),
        history: const [AskHistoryTurn(question: 'س', answer: 'ج [M1]')],
        noMatches: true,
      );
      expect(msg.indexOf('<conversation_history>'),
          lessThan(msg.indexOf('<context>')));
      expect(msg, contains('<question>\nما موعد الإطلاق؟\n</question>'));
      expect(msg, contains('M1 | x'));
      expect(msg, contains('لم يُعثر على مقاطع'));
      expect(msg, contains('2026'));
      final plain = buildAskUserMessage(
        question: 'س',
        context: '',
        now: DateTime(2026, 11, 19),
      );
      expect(plain, isNot(contains('<conversation_history>')));
      expect(plain, isNot(contains('لم يُعثر على مقاطع')));
    });

    test('overhead grows with the history and the question', () {
      final a = askMessageOverhead('س', const []);
      final b = askMessageOverhead('س' * 100, const [
        AskHistoryTurn(question: 'q', answer: 'a'),
      ]);
      expect(b, greaterThan(a + 100));
    });
  });
}
