import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/export_docx/minutes_docx.dart';
import 'package:insato/features/export_docx/strings.dart';

import '../../minutes/fixtures.dart';
import 'xml_check.dart';

/// The table of [doc] whose header contains [headerText].
String tableWith(String doc, String headerText) =>
    tablesOf(doc).firstWhere((t) => plainText(t).contains(headerText));

void main() {
  const composer = MinutesDocxComposer();
  final speakers = {
    'a': speaker('a', 'سارة', named: true),
    'b': speaker('b', 'متحدث 2'),
  };
  final segments = [
    seg(0, 0, 4000, 'نبدأ بمراجعة الميزانية', speakerId: 'a'),
    seg(1, 5000, 9000, 'I will send the report', speakerId: 'b'),
  ];
  final agendaMinutes = sampleMinutes().copyWith(
    agendaCoverage: const [
      MinutesAgendaItem(
        item: 'الميزانية',
        status: AgendaItemStatus.discussed,
        note: 'اعتُمدت',
      ),
      MinutesAgendaItem(item: 'التوظيف', status: AgendaItemStatus.notDiscussed),
    ],
  );

  Map<String, String> partsOf(
    Minutes minutes, {
    bool includeTranscript = false,
    Meeting? m,
  }) => unzipParts(
    composer.build(
      m ?? meeting(),
      minutes,
      speakers,
      segments: segments,
      includeTranscript: includeTranscript,
    ),
  );

  test('all parts exist and every part is well-formed XML', () {
    final parts = partsOf(agendaMinutes, includeTranscript: true);
    for (final name in [
      '[Content_Types].xml',
      '_rels/.rels',
      'word/document.xml',
      'word/styles.xml',
      'word/numbering.xml',
      'word/_rels/document.xml.rels',
      'docProps/core.xml',
      'docProps/app.xml',
    ]) {
      expect(parts, contains(name));
    }
    for (final e in parts.entries) {
      expect(() => checkWellFormed(e.value), returnsNormally, reason: e.key);
    }
  });

  test('RTL document with the Arabic minutes text and sections', () {
    final parts = partsOf(agendaMinutes);
    final doc = parts['word/document.xml']!;
    expect(doc, contains('<w:bidi/>'));
    expect(doc, contains('<w:rtl/>'));
    final text = plainText(doc);
    for (final s in [
      XS.docKicker,
      'مراجعة ميزانية الربع الرابع',
      XS.summary,
      'ناقش الحضور الميزانية.',
      'واتُّفق على خفض النفقات بنسبة 10%.',
      XS.attendees,
      XS.agenda,
      'نوقش',
      'لم يُناقَش',
      XS.topics,
      '1. النفقات التشغيلية',
      'المتحدثون: سارة، متحدث 2',
      XS.decisions,
      'خفض النفقات بنسبة 10%',
      ' (اقترحه: سارة)',
      XS.actionItems,
      'إعداد تقرير | النفقات',
      'الخميس القادم',
      XS.openQuestions,
      'هل تشمل الخطة فرع جدة؟',
      XS.nextMeeting,
      'الأحد 2026-11-29',
      XS.notes,
      XS.signatures,
      'لغات الاجتماع: العربية، الإنجليزية',
      'claude-opus-5-5',
    ]) {
      expect(text, contains(s), reason: s);
    }
    // Latin words keep their own LTR runs.
    expect(doc, contains('<w:t xml:space="preserve">OPEX</w:t>'));
    // Headings use the heading styles (navigation pane / outline).
    expect(doc, contains('<w:pStyle w:val="Heading1"/>'));
    expect(doc, contains('<w:pStyle w:val="Heading2"/>'));
    expect(doc, contains('<w:pStyle w:val="Title"/>'));
    // Decisions are a numbered list, attendees and questions bullets.
    expect('<w:numId w:val="2"/>'.allMatches(doc).length, 2);
    expect('<w:numId w:val="1"/>'.allMatches(doc).length, 3);
    expect(parts['docProps/core.xml'], contains('محضر اجتماع: مراجعة ميزانية'));
  });

  test('action table has one row per action item plus the header', () {
    final doc = partsOf(sampleMinutes())['word/document.xml']!;
    final table = tableWith(doc, XS.colTask);
    expect(rowCount(table), sampleMinutes().actionItems.length + 1);
    expect(plainText(table), contains(XS.colOwner));
    expect(plainText(table), contains(XS.colDue));
    expect(plainText(table), contains('مراجعة العقود'));
    // Missing owner / due date show a dash.
    expect(MinutesDocxComposer.actionRows(sampleMinutes().actionItems)[1], [
      '2',
      'مراجعة العقود',
      '—',
      '—',
    ]);
  });

  test('no action items: a note instead of a table', () {
    final doc = partsOf(
      sampleMinutes().copyWith(actionItems: const []),
    )['word/document.xml']!;
    expect(plainText(doc), contains(XS.noActionItems));
    expect(
      tablesOf(doc).where((t) => plainText(t).contains(XS.colTask)),
      isEmpty,
    );
  });

  test('signature block lists the attendees, or blank lines', () {
    var doc = partsOf(sampleMinutes())['word/document.xml']!;
    var sig = tableWith(doc, XS.sigSignature);
    expect(rowCount(sig), 3);
    expect(plainText(sig), contains('سارة'));
    expect(plainText(sig), contains(XS.sigName));
    expect(sig, contains('w:hRule="atLeast"'));

    // No attendees in the minutes: named speakers heard in the transcript.
    doc = partsOf(
      sampleMinutes().copyWith(attendees: const []),
    )['word/document.xml']!;
    sig = tableWith(doc, XS.sigSignature);
    expect(plainText(sig), contains('سارة'));
  });

  test('blank signature lines when nobody is known', () {
    final doc = unzipParts(
      composer.build(
        meeting(),
        sampleMinutes().copyWith(attendees: const []),
        const {},
      ),
    )['word/document.xml']!;
    expect(rowCount(tableWith(doc, XS.sigSignature)), 4);
    expect(plainText(doc), contains(XS.noAttendees));
  });

  test('transcript appendix only on request', () {
    expect(
      plainText(partsOf(sampleMinutes())['word/document.xml']!),
      isNot(contains(XS.transcriptAppendix)),
    );
    final doc = partsOf(
      sampleMinutes(),
      includeTranscript: true,
    )['word/document.xml']!;
    final text = plainText(doc);
    expect(text, contains(XS.transcriptAppendix));
    expect(text, contains('نبدأ بمراجعة الميزانية'));
    expect(text, contains('I will send the report'));
    expect(doc, contains('<w:br w:type="page"/>'));
  });

  test('escapes <>&"\' and strips control characters everywhere', () {
    const nasty = 'مهمة <b>عاجلة</b> & "مقتبسة" \'مفردة\'\u0001\u0007\u001B￿';
    final minutes = sampleMinutes().copyWith(
      title: 'عنوان $nasty',
      summary: 'ملخص $nasty',
      actionItems: [
        const ActionItem(task: nasty, owner: 'أ<ب>', dueDate: '&غداً'),
      ],
      decisions: const [MinutesDecision(text: nasty, proposedBy: '"س"')],
      openQuestions: const [nasty],
      attendees: const ['سارة & شركاه'],
    );
    final parts = partsOf(minutes, includeTranscript: true);
    for (final e in parts.entries) {
      expect(() => checkWellFormed(e.value), returnsNormally, reason: e.key);
      expect(e.value, isNot(contains('\u0001')));
      expect(e.value, isNot(contains('\u0007')));
      expect(e.value, isNot(contains('\u001B')));
      expect(e.value, isNot(contains('￿')));
    }
    final doc = parts['word/document.xml']!;
    expect(doc, isNot(contains('<b>')));
    expect(doc, contains('&gt;عاجلة&lt;/'));
    expect(doc, contains('&amp;'));
    expect(doc, contains('&quot;'));
    expect(doc, contains('&apos;'));
    const clean = 'مهمة <b>عاجلة</b> & "مقتبسة" \'مفردة\'';
    final text = plainText(doc);
    expect(text, contains(clean));
    expect(text, contains('أ<ب>'));
    expect(text, contains('&غداً'));
    final table = tableWith(doc, XS.colTask);
    expect(rowCount(table), 2);
    expect(parts['docProps/core.xml'], contains('&lt;b&gt;'));
    expect(parts['word/footer1.xml'], contains('&amp;'));
  });
}
