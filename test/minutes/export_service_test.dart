import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/minutes/export_service.dart';

import 'fixtures.dart';

ByteData _font(String name) {
  final bytes = File('assets/fonts/$name').readAsBytesSync();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

void main() {
  final fonts = PdfFontSet(
    arabicRegular: _font('NotoNaskhArabic-Regular.ttf'),
    arabicBold: _font('NotoNaskhArabic-Bold.ttf'),
    latinRegular: _font('NotoSans-Regular.ttf'),
    latinBold: _font('NotoSans-Bold.ttf'),
  );
  final service = ExportService(fonts: fonts);
  final speakers = {
    'a': speaker('a', 'سارة', named: true),
    'b': speaker('b', 'متحدث 2'),
  };
  final segments = [
    seg(0, 0, 4000, 'نبدأ بمراجعة الميزانية', speakerId: 'a'),
    seg(
      1,
      5000,
      9000,
      'I will send the report',
      speakerId: 'b',
      language: 'en',
    ),
  ];

  group('toMarkdown', () {
    test('has all Arabic sections, escaped table and metadata', () {
      final md = service.toMarkdown(meeting(), sampleMinutes(), speakers);
      for (final h in [
        '# محضر اجتماع: مراجعة ميزانية الربع الرابع',
        '## الملخص',
        '## الحضور',
        '## محاور النقاش',
        '### 1. النفقات التشغيلية',
        '## القرارات',
        '## المهام',
        '| # | المهمة | المسؤول | الموعد |',
        '## أسئلة مفتوحة',
        '## الاجتماع القادم',
        '## ملاحظات',
      ]) {
        expect(md, contains(h), reason: h);
      }
      expect(
        md,
        contains(r'| 1 | إعداد تقرير \| النفقات | متحدث 2 | الخميس القادم |'),
      );
      expect(md, contains('| 2 | مراجعة العقود | — | — |'));
      expect(md, contains('1. خفض النفقات بنسبة 10% *(اقترحه: سارة)*'));
      expect(md, contains('01:02:03'));
      expect(md, contains('العربية، الإنجليزية'));
      expect(md, isNot(contains('ملحق')));
    });

    test('empty sections and transcript appendix', () {
      final m = Minutes(
        title: '',
        summary: '',
        attendees: const [],
        topics: const [],
        decisions: const [],
        actionItems: const [],
        openQuestions: const [],
        languagesDetected: const [],
        generatedAt: DateTime(2026),
        model: '',
      );
      final md = service.toMarkdown(
        meeting(),
        m,
        speakers,
        segments: segments,
        includeTranscript: true,
      );
      expect(md, contains('# محضر اجتماع: اجتماع الميزانية'));
      expect(md, contains('لم تُتخذ قرارات.'));
      expect(md, contains('لم تُسنَد مهام.'));
      expect(md, isNot(contains('## أسئلة مفتوحة')));
      expect(md, isNot(contains('## الاجتماع القادم')));
      // Attendees fall back to the transcript speakers.
      expect(md, contains('- سارة\n- متحدث 2'));
      expect(md, contains('## ملحق: النص الكامل للاجتماع'));
      expect(md, contains('**[00:00:05] متحدث 2:** I will send the report'));
    });
  });

  test('toPlainText', () {
    final txt = service.toPlainText(
      meeting(),
      sampleMinutes(),
      speakers,
      segments: segments,
      includeTranscript: true,
    );
    expect(txt, startsWith('محضر اجتماع: مراجعة ميزانية الربع الرابع'));
    expect(txt, contains('▪ المهام'));
    expect(txt, contains('المسؤول: غير محدد — الموعد: غير محدد'));
    expect(txt, contains('[00:00:00] سارة: نبدأ بمراجعة الميزانية'));
    expect(txt, isNot(contains('**')));
    expect(txt, isNot(contains('#')));
  });

  test('fullTranscriptText', () {
    final t = service.fullTranscriptText(meeting(), segments, speakers);
    expect(t, contains('النص الكامل للاجتماع: اجتماع الميزانية'));
    expect(t, contains('[00:00:05] متحدث 2: I will send the report'));
    expect(
      service.fullTranscriptText(meeting(), const [], speakers),
      contains('لا يوجد كلام مسجّل.'),
    );
  });

  test('suggestedFileName strips invalid characters', () {
    final name = ExportService.suggestedFileName(
      meeting(title: 'خطة: Q4/2026 <نهائي>?'),
      '.pdf',
    );
    expect(name, 'محضر - خطة Q4 2026 نهائي - 2026-11-19.pdf');
  });

  group('toPdf', () {
    test('produces a valid PDF', () async {
      final bytes = await service.toPdf(meeting(), sampleMinutes(), speakers);
      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      final tail = latin1.decode(bytes.sublist(bytes.length - 1024));
      expect(tail, contains('%%EOF'));
    });

    test('long minutes with transcript appendix span many pages', () async {
      final base = sampleMinutes();
      final longText = List.filled(
        400,
        'نص طويل للمناقشة مع English words',
      ).join(' ');
      final m = Minutes(
        title: base.title,
        summary: longText,
        attendees: base.attendees,
        topics: [
          for (var i = 0; i < 5; i++)
            MinutesTopic(title: 'محور $i', discussion: longText),
        ],
        decisions: base.decisions,
        actionItems: [
          for (var i = 0; i < 60; i++)
            ActionItem(task: 'مهمة رقم $i', owner: 'سارة', dueDate: 'غداً'),
        ],
        openQuestions: base.openQuestions,
        languagesDetected: base.languagesDetected,
        generatedAt: base.generatedAt,
        model: base.model,
      );
      final manySegments = [
        for (var i = 0; i < 300; i++)
          seg(
            i,
            i * 10000,
            i * 10000 + 9000,
            'جملة رقم $i في الاجتماع',
            speakerId: i.isEven ? 'a' : 'b',
          ),
      ];
      final bytes = await service.toPdf(
        meeting(),
        m,
        speakers,
        segments: manySegments,
        includeTranscript: true,
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      final text = latin1.decode(bytes);
      final pages = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
      expect(pages, greaterThan(5));
    });
  });
}
