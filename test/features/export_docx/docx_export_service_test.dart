import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/export_docx/docx_export_service.dart';
import 'package:insato/features/export_docx/strings.dart';
import 'package:insato/minutes/export_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../minutes/fixtures.dart';
import 'xml_check.dart';

ByteData _font(String name) {
  final bytes = File('assets/fonts/$name').readAsBytesSync();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

/// What the fake share sheet received, with the file content read while the
/// file still existed.
class _Shared {
  _Shared(this.params, this.bytes, this.path);

  final ShareParams params;
  final Uint8List bytes;
  final String path;
}

void main() {
  final export = ExportService(
    fonts: PdfFontSet(
      arabicRegular: _font('NotoNaskhArabic-Regular.ttf'),
      arabicBold: _font('NotoNaskhArabic-Bold.ttf'),
      latinRegular: _font('NotoSans-Regular.ttf'),
      latinBold: _font('NotoSans-Bold.ttf'),
    ),
  );
  final speakers = {'a': speaker('a', 'سارة', named: true)};
  final segments = [seg(0, 0, 4000, 'نبدأ بمراجعة الميزانية', speakerId: 'a')];

  late Directory tmp;
  late List<_Shared> shared;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('insato_docx_share_');
    shared = [];
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> fakeShare(ShareParams params) async {
    final f = params.files!.single;
    shared.add(_Shared(params, await f.readAsBytes(), f.path));
  }

  DocxExportService service({
    required bool mobile,
    Future<void> Function(ShareParams)? share,
  }) => DocxExportService(
    export: export,
    exportsDir: () async => '${tmp.path}/exports',
    shareTempDir: () async => '${tmp.path}/share',
    isMobile: mobile,
    share: share ?? fakeShare,
    now: () => DateTime.utc(2026, 11, 19, 12),
  );

  test('subject and summary body', () {
    expect(
      DocxExportService.shareSubject(meeting(), sampleMinutes()),
      'محضر اجتماع: مراجعة ميزانية الربع الرابع',
    );
    expect(
      DocxExportService.shareSubject(
        meeting(),
        sampleMinutes().copyWith(title: '  '),
      ),
      'محضر اجتماع: اجتماع الميزانية',
    );
    final body = DocxExportService.shareBody(
      meeting(),
      sampleMinutes(),
      format: MinutesExportFormat.docx,
    );
    expect(body, startsWith('محضر اجتماع: مراجعة ميزانية الربع الرابع\n'));
    expect(body, contains('${XS.date}: '));
    expect(body, contains('${XS.duration}: 01:02:03'));
    expect(
      body,
      contains('ناقش الحضور الميزانية. واتُّفق على خفض النفقات بنسبة 10%.'),
    );
    expect(body, contains(XS.counts(2, 2)));
    expect(body, contains(XS.attachedAs('Word')));
    expect(body, endsWith(XS.sentFrom));
  });

  test('long summaries are cut at a word with an ellipsis', () {
    final long = List.filled(300, 'كلمة').join(' ');
    final body = DocxExportService.shareBody(
      meeting(),
      sampleMinutes().copyWith(summary: long),
    );
    final line = body.split('\n').firstWhere((l) => l.startsWith('كلمة'));
    expect(line, endsWith('كلمة…'));
    expect(
      line.runes.length,
      lessThanOrEqualTo(DocxExportService.maxSummaryChars + 1),
    );
  });

  test(
    'mobile: shares the .docx with subject and body, then deletes it',
    () async {
      final r = await service(mobile: true).shareMinutes(
        format: MinutesExportFormat.docx,
        meeting: meeting(),
        minutes: sampleMinutes(),
        speakersById: speakers,
        segments: segments,
        includeTranscript: true,
      );
      expect(r.shared, isTrue);
      expect(r.savedPath, isNull);
      final s = shared.single;
      expect(s.params.subject, 'محضر اجتماع: مراجعة ميزانية الربع الرابع');
      expect(s.params.text, contains(XS.attachedAs('Word')));
      final file = s.params.files!.single;
      expect(file.mimeType, MinutesExportFormat.docx.mimeType);
      expect(file.name, 'محضر - اجتماع الميزانية - 2026-11-19.docx');
      expect(s.path, startsWith('${tmp.path}/share/'));
      expect(File(s.path).existsSync(), isFalse, reason: 'temp file removed');
      final parts = unzipParts(s.bytes);
      checkWellFormed(parts['word/document.xml']!);
      expect(
        plainText(parts['word/document.xml']!),
        contains(XS.transcriptAppendix),
      );
      expect(parts['docProps/core.xml'], contains('2026-11-19T12:00:00Z'));
    },
  );

  test('desktop: keeps the copy in the exports folder', () async {
    final r = await service(mobile: false).shareMinutes(
      format: MinutesExportFormat.markdown,
      meeting: meeting(),
      minutes: sampleMinutes(),
      speakersById: speakers,
    );
    expect(r.shared, isTrue);
    expect(
      r.savedPath,
      '${tmp.path}/exports/محضر - اجتماع الميزانية - 2026-11-19.md',
    );
    expect(File(r.savedPath!).existsSync(), isTrue);
    final md = utf8.decode(shared.single.bytes);
    expect(md, export.toMarkdown(meeting(), sampleMinutes(), speakers));
    expect(shared.single.params.files!.single.mimeType, 'text/markdown');
  });

  test('PDF reuses ExportService.toPdf and is shared the same way', () async {
    final r = await service(mobile: true).shareMinutes(
      format: MinutesExportFormat.pdf,
      meeting: meeting(),
      minutes: sampleMinutes(),
      speakersById: speakers,
    );
    expect(r.shared, isTrue);
    final s = shared.single;
    expect(ascii.decode(s.bytes.sublist(0, 5)), '%PDF-');
    expect(s.params.subject, 'محضر اجتماع: مراجعة ميزانية الربع الرابع');
    expect(s.params.text, contains(XS.attachedAs('PDF')));
    expect(s.params.files!.single.name, endsWith('.pdf'));
    expect(s.params.files!.single.mimeType, 'application/pdf');
  });

  test(
    'share failure: desktop reports the saved copy, mobile nothing',
    () async {
      Future<void> failing(ShareParams _) async =>
          throw UnimplementedError('no share target');
      final desktop = await service(mobile: false, share: failing).shareMinutes(
        format: MinutesExportFormat.docx,
        meeting: meeting(),
        minutes: sampleMinutes(),
        speakersById: speakers,
      );
      expect(desktop.shared, isFalse);
      expect(desktop.savedPath, endsWith('.docx'));
      expect(File(desktop.savedPath!).existsSync(), isTrue);

      final mobile = await service(mobile: true, share: failing).shareMinutes(
        format: MinutesExportFormat.docx,
        meeting: meeting(),
        minutes: sampleMinutes(),
        speakersById: speakers,
      );
      expect(mobile.shared, isFalse);
      expect(mobile.savedPath, isNull);
      expect(Directory('${tmp.path}/share').listSync(), isEmpty);
    },
  );
}
