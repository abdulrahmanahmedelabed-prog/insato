import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/ask/ask_corpus.dart';
import 'package:insato/features/ask/ask_retrieval.dart';

import 'fixtures.dart';

AskPackedContext run(
  String q, {
  int budget = 20000,
  List<String> previous = const [],
  Map<String, int> aliases = const {},
  List<AskMeetingSource>? meetings,
}) => runAskRetrieval(
  AskRetrievalJob(
    meetings: meetings ?? corpus(),
    question: q,
    charBudget: budget,
    previousQuestions: previous,
    aliases: aliases,
  ),
);

void main() {
  group('AskMeetingSource.from', () {
    test('keeps content segments in order with speaker names', () {
      final meeting = Meeting(
        id: 'm',
        title: 't',
        createdAt: DateTime(2026),
        status: MeetingStatus.ready,
        durationMs: 0,
      );
      TranscriptSegment seg(
        int i,
        String text, {
        String? speaker,
        SegmentKind kind = SegmentKind.speech,
      }) => TranscriptSegment(
        id: 's$i',
        meetingId: 'm',
        index: i,
        startMs: i * 1000,
        endMs: i * 1000 + 500,
        text: text,
        speakerId: speaker,
        kind: kind,
      );
      final speaker = Speaker(
        id: 'sp',
        name: 'سارة',
        colorValue: 0,
        isNamedByUser: true,
        createdAt: DateTime(2026),
      );
      final src = AskMeetingSource.from(
        meeting,
        [
          seg(3, ' ثالث ', speaker: 'sp'),
          seg(1, 'أول'),
          seg(2, '   '),
          seg(4, '', kind: SegmentKind.unintelligible),
        ],
        {'sp': speaker},
      );
      expect(src.segments.map((s) => s.index), [1, 3, 4]);
      expect(src.segments[1].text, 'ثالث');
      expect(src.segments[1].speakerName, 'سارة');
      expect(src.segments[0].speakerName, 'متحدث غير محدد');
      expect(src.segments[2].unintelligible, isTrue);
      expect(src.positionOf(3), 1);
      expect(src.positionOf(2), -1);
      expect(src.hasContent, isTrue);
    });
  });

  group('transcriptWindows', () {
    test('overlap by half and cover every segment', () {
      final segs = lines([for (var i = 0; i < 13; i++) ('a', 'كلمة')]);
      final w = transcriptWindows(
        segs,
        windowing: const AskWindowing(maxSegments: 4),
      );
      expect(w.first, (0, 3));
      expect(w[1], (2, 5));
      expect(w.last.$2, 12);
      final covered = {
        for (final (a, b) in w)
          for (var i = a; i <= b; i++) i,
      };
      expect(covered, hasLength(13));
    });

    test('stop growing at the character limit', () {
      final segs = lines([
        ('a', 'x' * 400),
        ('a', 'y' * 400),
        ('a', 'z'),
        ('a', 'w'),
      ]);
      final w = transcriptWindows(
        segs,
        windowing: const AskWindowing(maxChars: 600),
      );
      expect(w.first, (0, 1));
    });

    test('empty and single', () {
      expect(transcriptWindows(const []), isEmpty);
      expect(transcriptWindows(lines([('a', 'b')])), [(0, 0)]);
    });
  });

  test('buildAskDocuments creates header, minutes and transcript docs', () {
    final docs = buildAskDocuments(corpus());
    final kinds = docs.map((d) => (d.meeting, d.kind)).toSet();
    expect(kinds, contains((0, AskDocKind.header)));
    expect(kinds, contains((0, AskDocKind.transcript)));
    expect(kinds, contains((1, AskDocKind.summary)));
    expect(kinds, contains((1, AskDocKind.decisions)));
    expect(kinds, contains((1, AskDocKind.actions)));
    expect(kinds, contains((2, AskDocKind.topic)));
    expect(kinds, isNot(contains((2, AskDocKind.transcript))));
  });

  test('assignAskAliases numbers oldest first and keeps earlier ones', () {
    final c = corpus();
    final a = assignAskAliases(c, const {});
    expect(a, {'m-hiring': 1, 'm-budget': 2, 'm-launch': 3});
    final b = assignAskAliases(c, const {'m-launch': 7});
    expect(b['m-launch'], 7);
    expect(b['m-hiring'], 8);
    expect(b['m-budget'], 9);
  });

  test('mentionsRecency', () {
    expect(mentionsRecency('ماذا حدث في آخر اجتماع؟'), isTrue);
    expect(mentionsRecency('What happened in the latest meeting?'), isTrue);
    expect(mentionsRecency('ما الخيارات الأخرى؟'), isFalse);
    expect(mentionsRecency('ما الميزانية؟'), isFalse);
  });

  group('runAskRetrieval', () {
    test('finds the relevant meeting and packs its excerpts', () {
      final r = run('متى موعد إطلاق التطبيق؟');
      expect(r.hasMatches, isTrue);
      expect(r.detailedMeetings.first, 'm-launch');
      final alias = r.aliases['m-launch'];
      expect(r.text, contains('[M$alias#1 00:00:10] أحمد: نحتاج'));
      expect(r.text, contains('<meetings_catalog>'));
      expect(r.text, contains('اجتماع إطلاق التطبيق'));
      expect(r.refs[alias]!.segmentStartMs[1], 10000);
      expect(r.excerptLines, greaterThan(0));
    });

    test('matches spelling variants (ة/ه, hamza) and English', () {
      final r = run('الميزانيه والتسويق');
      expect(r.detailedMeetings.first, 'm-budget');
      final en = run('hosting cost');
      expect(en.detailedMeetings.first, 'm-budget');
      final alias = en.aliases['m-budget'];
      expect(en.text, contains('[M$alias#3 00:00:30] مها: The cloud'));
    });

    test('renders the minutes overview with evidence references', () {
      final r = run('ما قرارات مراجعة الميزانية؟');
      final alias = r.aliases['m-budget']!;
      expect(r.text, contains('<minutes>'));
      expect(r.text, contains('- تخفيض نفقات السفر [M$alias#2]'));
      expect(r.text, contains('المسؤول: خالد [M$alias#4]'));
      expect(r.refs[alias]!.segmentStartMs, containsPair(2, 20000));
      expect(r.refs[alias]!.segmentStartMs, containsPair(4, 40000));
    });

    test('includes matching minutes topics of meetings without transcript', () {
      final r = run('توظيف مهندسين للواجهة الخلفية');
      expect(r.detailedMeetings.first, 'm-hiring');
      expect(r.text, contains('موضوع: التوظيف'));
    });

    test('falls back to the most recent meetings when nothing matches', () {
      final r = run('zzzz qqqq');
      expect(r.hasMatches, isFalse);
      expect(r.detailedMeetings, ['m-launch', 'm-budget', 'm-hiring']);
      expect(r.text, contains('الملخص: نوقشت ميزانية'));
    });

    test('fallback includes transcript of recent meetings without minutes', () {
      final r = run('What was discussed?');
      expect(r.hasMatches, isFalse);
      expect(r.detailedMeetings.first, 'm-launch');
      // m-launch has no minutes: its transcript is what the model gets.
      expect(r.text, contains('<transcript_excerpts>'));
      expect(r.text, contains('صباح الخير جميعاً'));
      expect(r.excerptLines, greaterThan(0));
      expect(r.refs.values.any((ref) => ref.segmentStartMs.isNotEmpty), isTrue);
    });

    test('fallback excerpts span a long meeting within the budget', () {
      final long = [
        source(
          'long',
          'اجتماع طويل',
          DateTime(2026, 11, 20),
          lines([
            for (var i = 0; i < 300; i++) ('سارة', 'جملة رقم $i ${'ك' * 60}'),
          ]),
        ),
        ...corpus(),
      ];
      for (final budget in [3000, 8000, 20000]) {
        final r = run('zzzz qqqq', budget: budget, meetings: long);
        expect(r.hasMatches, isFalse);
        expect(r.text.length, lessThanOrEqualTo(budget), reason: '$budget');
        expect(r.text, contains('جملة رقم 0 '), reason: '$budget');
      }
      final r = run('zzzz qqqq', budget: 8000, meetings: long);
      // Not only the opening: later parts of the meeting are sampled too.
      final nums = RegExp(r'جملة رقم (\d+)')
          .allMatches(r.text)
          .map((m) => int.parse(m.group(1)!))
          .toList();
      expect(nums.reduce((a, b) => a > b ? a : b), greaterThan(100));
    });

    test('spreadOrder covers every index, spreading prefixes', () {
      expect(spreadOrder(0), isEmpty);
      expect(spreadOrder(1), [0]);
      for (final n in [2, 3, 5, 8, 13, 100]) {
        final o = spreadOrder(n);
        expect(o.toSet(), {for (var i = 0; i < n; i++) i}, reason: '$n');
        expect(o.length, n);
      }
      expect(spreadOrder(8).take(4), [0, 4, 2, 6]);
    });

    test('puts the latest meeting first for recency questions', () {
      final r = run('ما قرارات الميزانية في آخر اجتماع؟');
      expect(r.detailedMeetings.first, 'm-launch');
      expect(r.detailedMeetings, contains('m-budget'));
    });

    test('follow-up questions use the previous question', () {
      final r = run(
        'ومن المسؤول عنها؟',
        previous: const ['ماذا قيل عن الحملة التسويقية؟'],
      );
      expect(r.detailedMeetings.first, 'm-launch');
      expect(r.text, contains('ليلى'));
    });

    test('keeps the conversation aliases', () {
      final r = run('الميزانية', aliases: const {'m-budget': 5});
      expect(r.aliases['m-budget'], 5);
      expect(r.text, contains('M5'));
    });

    test('respects the character budget', () {
      final big = [
        source(
          'big',
          'اجتماع طويل',
          DateTime(2026, 11, 1),
          lines([
            for (var i = 0; i < 400; i++)
              ('سارة', 'نناقش ميزانية المشروع رقم $i بالتفصيل ${'ك' * 80}'),
          ]),
        ),
        ...corpus(),
      ];
      for (final budget in [3000, 8000, 20000]) {
        final r = run('ميزانية المشروع', budget: budget, meetings: big);
        expect(r.text.length, lessThanOrEqualTo(budget), reason: '$budget');
        expect(r.excerptLines, greaterThan(0));
      }
      final small = run('ميزانية المشروع', budget: 3000, meetings: big);
      final large = run('ميزانية المشروع', budget: 20000, meetings: big);
      expect(large.excerptLines, greaterThan(small.excerptLines));
    });

    test('lists a limited catalogue when there are many meetings', () {
      final many = [
        for (var i = 0; i < 300; i++)
          source(
            'm$i',
            'اجتماع رقم $i',
            DateTime(2026, 1, 1).add(Duration(days: 300 - i)),
            lines([('أ', 'نص $i')]),
          ),
      ];
      final r = run('اجتماع', budget: 10000, meetings: many);
      expect(r.text, contains('اجتماعات أقدم غير مدرجة'));
      expect(r.text.length, lessThanOrEqualTo(10000));
    });

    test('marks unintelligible segments', () {
      final m = source('u', 'اجتماع الصوت', DateTime(2026, 11, 1), [
        ...lines([('أ', 'نتحدث عن الخادم الجديد')]),
        const AskSegment(
          index: 1,
          startMs: 10000,
          endMs: 12400,
          text: '',
          speakerName: 'ب',
          unintelligible: true,
        ),
      ]);
      final r = run('الخادم الجديد', meetings: [m]);
      expect(r.text, contains('[M1#1 00:00:10] ب: [غير مفهوم — مقطع #1'));
    });
  });
}
