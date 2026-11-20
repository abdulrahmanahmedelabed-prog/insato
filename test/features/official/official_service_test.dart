// OfficialMinutesService over an in-memory database: record creation and
// numbering, lifecycle (review gate, approval, lock, new version),
// signatures, logo / template files, and the official exports.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/official_repository.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/export_docx/minutes_docx.dart';
import 'package:insato/features/official/docx_template.dart';
import 'package:insato/features/official/official_models.dart';
import 'package:insato/features/official/official_service.dart';
import 'package:insato/features/official/template_placeholders.dart';
import 'package:insato/minutes/export_service.dart';

import '../../session/fakes.dart' show memoryDb;

ExportService _exportService() {
  ByteData font(String p) => ByteData.sublistView(File(p).readAsBytesSync());
  return ExportService(
    fonts: PdfFontSet(
      arabicRegular: font(PdfFontSet.arabicRegularAsset),
      arabicBold: font(PdfFontSet.arabicBoldAsset),
      latinRegular: font(PdfFontSet.latinRegularAsset),
      latinBold: font(PdfFontSet.latinBoldAsset),
    ),
  );
}

Minutes _minutes({VotePosition khaled = VotePosition.unclear}) => Minutes(
  title: 'الميزانية',
  summary: 'نوقشت الميزانية.',
  attendees: const ['أحمد', 'سارة'],
  topics: const [MinutesTopic(title: 'الميزانية', discussion: 'نقاش')],
  decisions: [
    MinutesDecision(
      text: 'اعتماد الميزانية',
      formalText: 'قرر المجلس اعتماد الميزانية',
      evidence: const [0],
      vote: MinutesVote(
        mode: VoteMode.formalVote,
        positions: [
          const MinutesVotePosition(
            speaker: 'أحمد',
            position: VotePosition.approve,
            evidence: [0],
          ),
          const MinutesVotePosition(
            speaker: 'سارة',
            position: VotePosition.object,
            evidence: [1],
          ),
          MinutesVotePosition(speaker: 'خالد', position: khaled),
        ],
        evidence: const [0, 1],
      ),
    ),
  ],
  actionItems: const [ActionItem(task: 'إرسال التقرير', owner: 'سارة')],
  openQuestions: const [],
  languagesDetected: const ['العربية'],
  generatedAt: DateTime(2026, 6, 16, 12),
  model: 'test',
);

void main() {
  late AppDatabase db;
  late Directory tmp;
  late OfficialMinutesService service;
  late MeetingRepository meetings;
  final now = DateTime(2026, 6, 16, 12);

  setUp(() async {
    db = memoryDb();
    tmp = Directory.systemTemp.createTempSync('insato_official_');
    meetings = MeetingRepository(db);
    service = OfficialMinutesService(
      repository: OfficialMinutesRepository(db, clock: () => now),
      settings: OfficialSettingsStore(db),
      meetings: meetings,
      segments: SegmentRepository(db),
      speakers: SpeakerRepository(db),
      brandingDir: () async => tmp.path,
      templatesDir: () async => tmp.path,
      clock: () => now,
    );
    await OfficialSettingsStore(db).saveProfile(
      const EntityProfile(
        entityName: 'شركة المثال',
        committees: ['مجلس الإدارة'],
        chairName: 'أحمد',
        secretaryName: 'منى',
        defaultPlace: 'القاعة الكبرى',
      ),
    );
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<Meeting> newMeeting(String id, {DateTime? at}) async {
    await meetings.create(
      id: id,
      title: 'اجتماع',
      createdAt: at ?? DateTime(2026, 6, 16, 10),
      status: MeetingStatus.ready,
      context: const MeetingContext(
        template: 'board',
        expectedAttendees: ['أحمد', 'سارة', 'خالد'],
      ),
    );
    await meetings.saveMinutes(id, _minutes());
    return (await meetings.get(id))!;
  }

  test('records are numbered per entity, committee and Hijri year', () async {
    final a = await service.ensureRecord(await newMeeting('a'));
    final b = await service.ensureRecord(await newMeeting('b'));
    final c = await service.ensureRecord(
      await newMeeting('c', at: DateTime(2026, 6, 1)),
    );
    expect(a.numberText, '1/1448هـ');
    expect(b.numberText, '2/1448هـ');
    expect(c.numberText, '1/1447هـ');
    expect(a.committee, 'مجلس الإدارة');
    expect(a.chair, 'أحمد');
    expect(a.place, 'القاعة الكبرى');
    expect(a.attendance.map((x) => x.name), ['أحمد', 'سارة', 'خالد']);
    // Same record on the next call.
    expect((await service.ensureRecord((await meetings.get('a'))!)).version, 1);
  });

  test('lifecycle: review gate, approval lock, new version', () async {
    final m = await newMeeting('m');
    var record = await service.ensureRecord(m);
    // Everyone present so the unclear vote of خالد matters.
    record = await service.save(
      record.copyWith(
        attendance: [
          for (final a in record.attendance)
            a.copyWith(status: AttendanceStatus.present),
        ],
      ),
    );
    await expectLater(
      service.approve('m'),
      throwsA(isA<OfficialActionException>()),
    );
    await expectLater(
      service.markReviewed('m'),
      throwsA(isA<OfficialActionException>()),
    );
    final minutes = (await meetings.get('m'))!.minutes!;
    record = await service.setVoteReview(
      record,
      minutes,
      0,
      const VoteReview(
        decisionKey: 'اعتماد الميزانية',
        mode: VoteMode.formalVote,
        positions: {
          'أحمد': VotePosition.approve,
          'سارة': VotePosition.object,
          'خالد': VotePosition.approve,
        },
      ),
    );
    record = await service.markReviewed('m');
    expect(record.status, OfficialStatus.reviewed);
    final approved = await service.approve('m');
    expect(approved.status, OfficialStatus.approved);
    expect(approved.approvedHash, hasLength(64));
    final bundle = (await service.bundle('m'))!;
    expect(bundle.document.isApproved, isTrue);
    expect(bundle.document.resolutions.single.tally.outcome.name, 'passed');

    // Locked: edits are refused.
    await expectLater(
      service.save(approved.copyWith(place: 'أخرى')),
      throwsA(isA<OfficialActionException>()),
    );

    // Signatures need the approved version and keep the hash.
    final sig = await service.sign(
      meetingId: 'm',
      signerName: 'أحمد',
      signerRole: 'رئيس الاجتماع',
      strokes: const [
        [SignaturePoint(0.1, 0.5), SignaturePoint(0.9, 0.4)],
      ],
      aspectRatio: 3,
    );
    expect(sig.contentHash, approved.approvedHash);
    await expectLater(
      service.sign(
        meetingId: 'm',
        signerName: 'سارة',
        signerRole: '',
        strokes: const [],
        aspectRatio: 3,
      ),
      throwsA(isA<OfficialActionException>()),
    );

    // Regenerated minutes with other content → new draft version.
    await meetings.saveMinutes('m', _minutes().copyWith(summary: 'ملخص آخر'));
    await service.onMinutesChanged('m');
    final v2 = (await OfficialMinutesRepository(db).get('m'))!;
    expect(v2.version, 2);
    expect(v2.status, OfficialStatus.draft);
    expect(v2.approvedHash, isNull);
    final versions = await OfficialMinutesRepository(db).versions('m');
    expect(versions.single.version, 1);
    expect(versions.single.minutes.summary, 'نوقشت الميزانية.');
    // Signatures of v1 stay in the history, v2 has none yet.
    final b2 = (await service.bundle('m'))!;
    expect(b2.signatures, isEmpty);
    expect(
      await OfficialMinutesRepository(db).signatures('m', version: 1),
      hasLength(1),
    );
  });

  test('changing the committee renumbers in its own sequence', () async {
    await OfficialSettingsStore(db).saveProfile(
      const EntityProfile(
        entityName: 'شركة المثال',
        committees: ['مجلس الإدارة', 'لجنة التدقيق'],
      ),
    );
    final m1 = await newMeeting('m1');
    await service.ensureRecord(m1);
    final m2 = await newMeeting('m2');
    final r2 = await service.ensureRecord(m2);
    expect(r2.meetingNumber, 2);
    final moved = await service.changeCommittee(m2, r2, 'لجنة التدقيق');
    expect(moved.meetingNumber, 1);
    expect(moved.committee, 'لجنة التدقيق');
  });

  test('logo and template uploads are validated', () async {
    await expectLater(
      service.setLogo(Uint8List.fromList(utf8.encode('<svg/>')), 'l.svg'),
      throwsA(isA<OfficialActionException>()),
    );
    await expectLater(
      service.setLogo(Uint8List.fromList([1, 2, 3]), 'l.png'),
      throwsA(isA<OfficialActionException>()),
    );
    final png = img.encodePng(img.Image(width: 20, height: 10));
    final p = await service.setLogo(png, 'logo.png');
    expect(p.logoFile, endsWith('.png'));
    expect(await service.logoBytes(), png);
    await service.clearLogo();
    expect(await service.logoBytes(), isNull);

    await expectLater(
      service.uploadTemplate(
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        fileName: 'x.docx',
        name: 'x',
        baseTemplateId: 'board',
      ),
      throwsA(isA<DocxTemplateException>()),
    );
    await expectLater(
      service.uploadTemplate(
        bytes: buildSampleTemplate(),
        fileName: 'x.pdf',
        name: 'x',
        baseTemplateId: 'board',
      ),
      throwsA(isA<OfficialActionException>()),
    );
    final t = await service.uploadTemplate(
      bytes: buildSampleTemplate(),
      fileName: 'قالبنا.docx',
      name: '',
      baseTemplateId: 'committee',
    );
    expect(t.name, 'قالبنا');
    expect(t.placeholders, contains('resolutions'));
    expect(await service.templateBytes(t), isNotNull);
    await service.deleteTemplate(t);
    expect(await OfficialSettingsStore(db).templates(), isEmpty);
    expect(await service.templateBytes(t), isNull);
  });

  test(
    'official exports: Markdown, text, PDF, built-in and uploaded Word',
    () async {
      final m = await newMeeting('e');
      final png = img.encodePng(img.Image(width: 20, height: 10));
      await service.setLogo(png, 'logo.png');
      var record = await service.ensureRecord(m);
      record = await service.save(
        record.copyWith(
          attendance: [
            for (final a in record.attendance)
              a.copyWith(status: AttendanceStatus.present),
          ],
        ),
      );
      record = await service.setVoteReview(
        record,
        m.minutes!,
        0,
        const VoteReview(
          decisionKey: 'اعتماد الميزانية',
          mode: VoteMode.formalVote,
          positions: {'خالد': VotePosition.abstain},
        ),
      );
      await service.markReviewed('e');
      await service.approve('e');
      await service.sign(
        meetingId: 'e',
        signerName: 'منى',
        signerRole: 'أمين السر',
        strokes: const [
          [SignaturePoint(0.1, 0.5), SignaturePoint(0.9, 0.4)],
        ],
        aspectRatio: 3,
      );
      final meeting = (await meetings.get('e'))!;
      final doc = (await service.documentForExport(meeting))!;
      expect(doc.isApproved, isTrue);

      final export = _exportService();
      final md = export.toMarkdown(
        meeting,
        meeting.minutes!,
        {},
        official: doc,
      );
      expect(md, contains('محضر اجتماع مجلس الإدارة رقم 1/1448هـ'));
      expect(md, contains('1 محرم 1448هـ'));
      expect(md, contains('قرار رقم (1/1/1448):'));
      expect(md, contains('اكتمل النصاب'));
      expect(md, contains(doc.contentHash));
      expect(md, contains('موقَّع إلكترونياً'));
      final text = export.toPlainText(
        meeting,
        meeting.minutes!,
        {},
        official: doc,
      );
      expect(text, contains('ممتنع: خالد'));
      final pdf = await export.toPdf(
        meeting,
        meeting.minutes!,
        {},
        official: doc,
      );
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

      final docx = const MinutesDocxComposer().buildOfficial(
        doc,
        meeting.minutes!,
        {},
        created: DateTime(2026),
      );
      final arc = ZipDecoder().decodeBytes(docx);
      final body = utf8.decode(arc.findFile('word/document.xml')!.content);
      expect(body, contains('قرر المجلس اعتماد الميزانية'));
      expect(body, isNot(contains('insato_img')));
      expect('<w:drawing'.allMatches(body).length, 2); // logo + signature
      final footer = utf8.decode(arc.findFile('word/footer1.xml')!.content);
      expect(footer, contains(doc.contentHash));

      final filled = const MinutesDocxComposer().buildOfficial(
        doc,
        meeting.minutes!,
        {},
        templateBytes: buildSampleTemplate(),
      );
      final fb = utf8.decode(
        ZipDecoder().decodeBytes(filled).findFile('word/document.xml')!.content,
      );
      expect(fb, contains('شركة المثال'));
      expect(fb, contains('إرسال التقرير'));
      expect(fb, contains('1 محرم 1448هـ'));
      expect(
        RegExp(r'\{\{(entity_name|resolutions|signature\.name)\}\}')
            .hasMatch(fb),
        isFalse,
      );

      // Non-official meetings keep the v1.1 layout with the Hijri date added.
      final plain = export.toMarkdown(meeting, meeting.minutes!, {});
      expect(plain, contains('الموافق 1 محرم 1448هـ'));
      expect(plain, isNot(contains('النصاب')));
    },
  );
}
