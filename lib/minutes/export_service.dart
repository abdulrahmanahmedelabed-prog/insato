// Exports minutes and transcripts as Markdown, plain text (for sharing) and
// a print-ready Arabic PDF.

import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/models.dart';
import '../core/time_format.dart';
import 'minutes_prompt.dart';

/// Raw TrueType bytes of the fonts embedded in PDFs.
class PdfFontSet {
  /// Creates a font set from raw `.ttf` bytes.
  const PdfFontSet({
    required this.arabicRegular,
    required this.arabicBold,
    required this.latinRegular,
    required this.latinBold,
  });

  /// NotoNaskhArabic-Regular.ttf
  final ByteData arabicRegular;

  /// NotoNaskhArabic-Bold.ttf
  final ByteData arabicBold;

  /// NotoSans-Regular.ttf (fallback for Latin and other scripts)
  final ByteData latinRegular;

  /// NotoSans-Bold.ttf
  final ByteData latinBold;

  /// Asset paths of the bundled fonts (see pubspec.yaml).
  static const String arabicRegularAsset =
      'assets/fonts/NotoNaskhArabic-Regular.ttf';

  /// Bold Arabic font asset path.
  static const String arabicBoldAsset = 'assets/fonts/NotoNaskhArabic-Bold.ttf';

  /// Latin fallback font asset path.
  static const String latinRegularAsset = 'assets/fonts/NotoSans-Regular.ttf';

  /// Bold Latin fallback font asset path.
  static const String latinBoldAsset = 'assets/fonts/NotoSans-Bold.ttf';

  /// Loads the bundled fonts from [bundle] (default: [rootBundle]).
  static Future<PdfFontSet> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final results = await Future.wait([
      b.load(arabicRegularAsset),
      b.load(arabicBoldAsset),
      b.load(latinRegularAsset),
      b.load(latinBoldAsset),
    ]);
    return PdfFontSet(
      arabicRegular: results[0],
      arabicBold: results[1],
      latinRegular: results[2],
      latinBold: results[3],
    );
  }
}

/// Converts minutes / transcripts into shareable documents.
///
/// All outputs are Arabic, right-to-left. Speaker names are taken from the
/// minutes as generated; [Speaker] records are used for the attendee
/// fallback and for transcript appendices.
class ExportService {
  /// Creates the service. Pass [fonts] to avoid asset loading (tests); in
  /// production the fonts are loaded lazily from [bundle] / `rootBundle`.
  ExportService({this._fonts, this._bundle});

  PdfFontSet? _fonts;
  final AssetBundle? _bundle;

  /// Name of the app, shown in footers.
  static const String appName = 'إنصاتو';

  // -------------------------------------------------------------------------
  // Helpers shared by all formats
  // -------------------------------------------------------------------------

  List<String> _attendees(
    Minutes minutes,
    Map<String, Speaker> speakersById,
    List<TranscriptSegment> segments,
  ) {
    if (minutes.attendees.isNotEmpty) return minutes.attendees;
    return speakerStats(
      segments,
      speakersById,
    ).where((s) => s.name != kUnknownSpeakerName).map((s) => s.name).toList();
  }

  String _durationText(Meeting meeting) => meeting.durationMs > 0
      ? '${formatDuration(meeting.durationMs, alwaysHours: true)} '
            '(${formatDurationWords(meeting.durationMs)})'
      : 'غير معروفة';

  String _generatedLine(Minutes minutes) {
    final model = minutes.model.isEmpty ? '' : ' باستخدام ${minutes.model}';
    return 'أُعدّ هذا المحضر آلياً بواسطة تطبيق $appName$model بتاريخ '
        '${formatArabicDateTime(minutes.generatedAt)}، ويُستحسن مراجعته قبل '
        'اعتماده.';
  }

  static String _oneLine(String s) =>
      s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

  static String _mdCell(String? s) {
    if (s == null || s.trim().isEmpty) return '—';
    return _oneLine(s).replaceAll(r'\', r'\\').replaceAll('|', r'\|');
  }

  /// Escapes characters that would start Markdown block constructs at the
  /// beginning of a line (headings, quotes, lists, tables).
  ///
  /// CommonMark only honours a backslash before ASCII punctuation, so an
  /// ordered-list marker is neutralised by escaping its delimiter (`1.` ->
  /// `1\.`), never the digits, and only when it could actually start a list
  /// (followed by whitespace or end of line; `3.5` is left alone). Bullet
  /// markers are likewise escaped only when followed by whitespace, so
  /// emphasis such as `*مهم*` at the start of a line keeps working.
  static String _mdText(String s) =>
      s.split('\n').map(_mdEscapeLine).join('\n');

  static final RegExp _mdOrderedMarker = RegExp(
    r'^(\s*)(\d{1,9})([.)])(?=\s|$)',
  );
  static final RegExp _mdBlockChar = RegExp(r'^(\s*)([#>|])');
  static final RegExp _mdBulletMarker = RegExp(r'^(\s*)([+\-*])(?=\s|$)');

  static String _mdEscapeLine(String line) => line
      .replaceFirstMapped(
        _mdOrderedMarker,
        (m) => '${m.group(1)}${m.group(2)}\\${m.group(3)}',
      )
      .replaceFirstMapped(_mdBlockChar, (m) => '${m.group(1)}\\${m.group(2)}')
      .replaceFirstMapped(
        _mdBulletMarker,
        (m) => '${m.group(1)}\\${m.group(2)}',
      );

  // -------------------------------------------------------------------------
  // Markdown
  // -------------------------------------------------------------------------

  /// Renders the minutes as Markdown with Arabic headings. When
  /// [includeTranscript] is true and [segments] are given, the full
  /// transcript is appended.
  String toMarkdown(
    Meeting meeting,
    Minutes minutes,
    Map<String, Speaker> speakersById, {
    List<TranscriptSegment> segments = const [],
    bool includeTranscript = false,
  }) {
    final b = StringBuffer();
    final title = minutes.title.trim().isEmpty ? meeting.title : minutes.title;
    b
      ..writeln('# محضر اجتماع: ${_oneLine(title)}')
      ..writeln()
      ..writeln('- **التاريخ:** ${formatArabicDateTime(meeting.createdAt)}')
      ..writeln('- **المدة:** ${_durationText(meeting)}');
    if (minutes.languagesDetected.isNotEmpty) {
      b.writeln('- **لغات الاجتماع:** ${minutes.languagesDetected.join('، ')}');
    }
    b
      ..writeln()
      ..writeln('## الملخص')
      ..writeln()
      ..writeln(
        minutes.summary.trim().isEmpty
            ? 'لا يوجد ملخص.'
            : _mdText(minutes.summary.trim()),
      )
      ..writeln();

    final attendees = _attendees(minutes, speakersById, segments);
    b
      ..writeln('## الحضور')
      ..writeln();
    if (attendees.isEmpty) {
      b.writeln('لم يُحدَّد الحضور.');
    } else {
      for (final a in attendees) {
        b.writeln('- ${_oneLine(a)}');
      }
    }
    b.writeln();

    if (minutes.topics.isNotEmpty) {
      b
        ..writeln('## محاور النقاش')
        ..writeln();
      for (var i = 0; i < minutes.topics.length; i++) {
        final t = minutes.topics[i];
        b
          ..writeln('### ${i + 1}. ${_oneLine(t.title)}')
          ..writeln()
          ..writeln(_mdText(t.discussion.trim()))
          ..writeln();
        if (t.speakerNames.isNotEmpty) {
          b
            ..writeln('*المتحدثون: ${t.speakerNames.join('، ')}*')
            ..writeln();
        }
      }
    }

    b
      ..writeln('## القرارات')
      ..writeln();
    if (minutes.decisions.isEmpty) {
      b.writeln('لم تُتخذ قرارات.');
    } else {
      for (var i = 0; i < minutes.decisions.length; i++) {
        final d = minutes.decisions[i];
        final by = d.proposedBy == null ? '' : ' *(اقترحه: ${d.proposedBy})*';
        b.writeln('${i + 1}. ${_oneLine(d.text)}$by');
      }
    }
    b.writeln();

    b
      ..writeln('## المهام')
      ..writeln();
    if (minutes.actionItems.isEmpty) {
      b.writeln('لم تُسنَد مهام.');
    } else {
      b
        ..writeln('| # | المهمة | المسؤول | الموعد |')
        ..writeln('|---|---|---|---|');
      for (var i = 0; i < minutes.actionItems.length; i++) {
        final a = minutes.actionItems[i];
        b.writeln(
          '| ${i + 1} | ${_mdCell(a.task)} | ${_mdCell(a.owner)} | '
          '${_mdCell(a.dueDate)} |',
        );
      }
    }
    b.writeln();

    if (minutes.openQuestions.isNotEmpty) {
      b
        ..writeln('## أسئلة مفتوحة')
        ..writeln();
      for (final q in minutes.openQuestions) {
        b.writeln('- ${_oneLine(q)}');
      }
      b.writeln();
    }
    if (minutes.nextMeeting != null) {
      b
        ..writeln('## الاجتماع القادم')
        ..writeln()
        ..writeln(_mdText(minutes.nextMeeting!))
        ..writeln();
    }
    if (minutes.notes != null) {
      b
        ..writeln('## ملاحظات')
        ..writeln()
        ..writeln(_mdText(minutes.notes!))
        ..writeln();
    }
    b
      ..writeln('---')
      ..writeln()
      ..writeln('*${_generatedLine(minutes)}*');

    if (includeTranscript && segments.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## ملحق: النص الكامل للاجتماع')
        ..writeln();
      for (final block in buildTranscriptBlocks(segments, speakersById)) {
        b
          ..writeln(
            '**[${formatTimestamp(block.startMs)}] '
            '${block.speakerName}:** ${_mdText(block.text)}',
          )
          ..writeln();
      }
    }
    return '${b.toString().trimRight()}\n';
  }

  // -------------------------------------------------------------------------
  // Plain text
  // -------------------------------------------------------------------------

  /// Renders the minutes as plain text suitable for messaging apps / e-mail.
  String toPlainText(
    Meeting meeting,
    Minutes minutes,
    Map<String, Speaker> speakersById, {
    List<TranscriptSegment> segments = const [],
    bool includeTranscript = false,
  }) {
    final b = StringBuffer();
    final title = minutes.title.trim().isEmpty ? meeting.title : minutes.title;
    void heading(String h) => b
      ..writeln()
      ..writeln('▪ $h')
      ..writeln();

    b
      ..writeln('محضر اجتماع: ${_oneLine(title)}')
      ..writeln('التاريخ: ${formatArabicDateTime(meeting.createdAt)}')
      ..writeln('المدة: ${_durationText(meeting)}');
    if (minutes.languagesDetected.isNotEmpty) {
      b.writeln('لغات الاجتماع: ${minutes.languagesDetected.join('، ')}');
    }

    heading('الملخص');
    b.writeln(
      minutes.summary.trim().isEmpty ? 'لا يوجد ملخص.' : minutes.summary.trim(),
    );

    final attendees = _attendees(minutes, speakersById, segments);
    heading('الحضور');
    b.writeln(attendees.isEmpty ? 'لم يُحدَّد الحضور.' : attendees.join('، '));

    if (minutes.topics.isNotEmpty) {
      heading('محاور النقاش');
      for (var i = 0; i < minutes.topics.length; i++) {
        final t = minutes.topics[i];
        if (i > 0) b.writeln();
        b
          ..writeln('${i + 1}. ${_oneLine(t.title)}')
          ..writeln(t.discussion.trim());
        if (t.speakerNames.isNotEmpty) {
          b.writeln('(المتحدثون: ${t.speakerNames.join('، ')})');
        }
      }
    }

    heading('القرارات');
    if (minutes.decisions.isEmpty) {
      b.writeln('لم تُتخذ قرارات.');
    } else {
      for (var i = 0; i < minutes.decisions.length; i++) {
        final d = minutes.decisions[i];
        final by = d.proposedBy == null ? '' : ' (اقترحه: ${d.proposedBy})';
        b.writeln('${i + 1}. ${_oneLine(d.text)}$by');
      }
    }

    heading('المهام');
    if (minutes.actionItems.isEmpty) {
      b.writeln('لم تُسنَد مهام.');
    } else {
      for (var i = 0; i < minutes.actionItems.length; i++) {
        final a = minutes.actionItems[i];
        b.writeln('${i + 1}. ${_oneLine(a.task)}');
        b.writeln(
          '   المسؤول: ${a.owner ?? 'غير محدد'} — الموعد: '
          '${a.dueDate ?? 'غير محدد'}',
        );
      }
    }

    if (minutes.openQuestions.isNotEmpty) {
      heading('أسئلة مفتوحة');
      for (final q in minutes.openQuestions) {
        b.writeln('• ${_oneLine(q)}');
      }
    }
    if (minutes.nextMeeting != null) {
      heading('الاجتماع القادم');
      b.writeln(minutes.nextMeeting);
    }
    if (minutes.notes != null) {
      heading('ملاحظات');
      b.writeln(minutes.notes);
    }
    b
      ..writeln()
      ..writeln('—')
      ..writeln(_generatedLine(minutes));

    if (includeTranscript && segments.isNotEmpty) {
      heading('ملحق: النص الكامل للاجتماع');
      b.writeln(
        renderTranscript(segments, speakersById, includeLanguage: false),
      );
    }
    return '${b.toString().trimRight()}\n';
  }

  // -------------------------------------------------------------------------
  // Transcript
  // -------------------------------------------------------------------------

  /// The full transcript as plain text with a short header, one line per
  /// speaker turn: `[hh:mm:ss] Name: text`.
  String fullTranscriptText(
    Meeting meeting,
    List<TranscriptSegment> segments,
    Map<String, Speaker> speakersById,
  ) {
    final b = StringBuffer()
      ..writeln('النص الكامل للاجتماع: ${_oneLine(meeting.title)}')
      ..writeln('التاريخ: ${formatArabicDateTime(meeting.createdAt)}')
      ..writeln('المدة: ${_durationText(meeting)}')
      ..writeln();
    final body = renderTranscript(
      segments,
      speakersById,
      includeLanguage: false,
    );
    b.writeln(body.isEmpty ? 'لا يوجد كلام مسجّل.' : body);
    return '${b.toString().trimRight()}\n';
  }

  /// A safe file name for exports, e.g. `محضر - اجتماع الميزانية - 2026-11-19.pdf`.
  /// Characters that are invalid on Windows / Android are removed.
  static String suggestedFileName(
    Meeting meeting,
    String extension, {
    String prefix = 'محضر',
  }) {
    final d = meeting.createdAt.toLocal();
    final date =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    var title = meeting.title
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.length > 60) title = title.substring(0, 60).trim();
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    final parts = [prefix, if (title.isNotEmpty) title, date];
    return '${parts.join(' - ')}.$ext';
  }

  // -------------------------------------------------------------------------
  // PDF
  // -------------------------------------------------------------------------

  Future<PdfFontSet> _loadFonts() async =>
      _fonts ??= await PdfFontSet.load(_bundle);

  /// Renders the minutes as an A4, right-to-left PDF with the bundled Arabic
  /// font (Latin fallback), a header, page-numbered footer ("صفحة X من Y"),
  /// an action-items table and, optionally, the transcript as an appendix.
  Future<Uint8List> toPdf(
    Meeting meeting,
    Minutes minutes,
    Map<String, Speaker> speakersById, {
    List<TranscriptSegment> segments = const [],
    bool includeTranscript = false,
  }) async {
    final fonts = await _loadFonts();
    final arabic = pw.Font.ttf(fonts.arabicRegular);
    final arabicBold = pw.Font.ttf(fonts.arabicBold);
    final latin = pw.Font.ttf(fonts.latinRegular);
    final latinBold = pw.Font.ttf(fonts.latinBold);

    const accent = PdfColor.fromInt(0xFF1F4E79);
    const muted = PdfColor.fromInt(0xFF5F6B7A);
    const rule = PdfColor.fromInt(0xFFC9D3DF);
    const headerFill = PdfColor.fromInt(0xFFE8EEF5);

    final base = pw.TextStyle(
      font: arabic,
      fontNormal: arabic,
      fontBold: arabicBold,
      fontFallback: [latin],
      fontSize: 11,
      lineSpacing: 3,
    );
    final bold = base.copyWith(
      font: arabicBold,
      fontWeight: pw.FontWeight.bold,
      fontFallback: [latinBold],
    );
    final h1 = bold.copyWith(fontSize: 20, color: accent);
    final h2 = bold.copyWith(fontSize: 14, color: accent);
    final h3 = bold.copyWith(fontSize: 12);
    final small = base.copyWith(fontSize: 9, color: muted);

    final theme = pw.ThemeData.withFont(
      base: arabic,
      bold: arabicBold,
      fontFallback: [latin],
    ).copyWith(defaultTextStyle: base);

    final title = minutes.title.trim().isEmpty ? meeting.title : minutes.title;
    final dateText = formatArabicDateTime(meeting.createdAt);
    final durationText = _durationText(meeting);

    pw.Widget sectionTitle(String text) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: rule, width: 1)),
      ),
      child: pw.Text(text, style: h2),
    );

    pw.Widget paragraph(String text, {pw.TextStyle? style}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text.trim(),
        style: style ?? base,
        textAlign: pw.TextAlign.justify,
        // Lets long paragraphs flow across pages.
        overflow: pw.TextOverflow.span,
      ),
    );

    pw.Widget bullet(String text, {String marker = '•'}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 18, child: pw.Text(marker, style: bold)),
          pw.Expanded(child: pw.Text(_oneLine(text), style: base)),
        ],
      ),
    );

    pw.Widget emptyNote(String text) => paragraph(text, style: small);

    pw.Widget infoRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label: ', style: bold.copyWith(fontSize: 10)),
            pw.TextSpan(text: value, style: base.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );

    final attendees = _attendees(minutes, speakersById, segments);
    final content = <pw.Widget>[
      // Title block (first page).
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: const pw.BoxDecoration(
          color: headerFill,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('محضر اجتماع', style: small.copyWith(fontSize: 11)),
            pw.SizedBox(height: 2),
            pw.Text(_oneLine(title), style: h1),
            pw.SizedBox(height: 6),
            infoRow('التاريخ', dateText),
            infoRow('المدة', durationText),
            if (minutes.languagesDetected.isNotEmpty)
              infoRow('لغات الاجتماع', minutes.languagesDetected.join('، ')),
          ],
        ),
      ),
      sectionTitle('الملخص'),
      if (minutes.summary.trim().isEmpty)
        emptyNote('لا يوجد ملخص.')
      else
        ...minutes.summary
            .trim()
            .split(RegExp(r'\n\s*\n'))
            .where((p) => p.trim().isNotEmpty)
            .map((p) => paragraph(p)),
      sectionTitle('الحضور'),
      if (attendees.isEmpty)
        emptyNote('لم يُحدَّد الحضور.')
      else
        paragraph(attendees.join('، ')),
    ];

    if (minutes.topics.isNotEmpty) {
      content.add(sectionTitle('محاور النقاش'));
      for (var i = 0; i < minutes.topics.length; i++) {
        final t = minutes.topics[i];
        content.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 3),
            child: pw.Text('${i + 1}. ${_oneLine(t.title)}', style: h3),
          ),
        );
        content.addAll(
          t.discussion
              .trim()
              .split(RegExp(r'\n\s*\n'))
              .where((p) => p.trim().isNotEmpty)
              .map((p) => paragraph(p)),
        );
        if (t.speakerNames.isNotEmpty) {
          content.add(
            paragraph('المتحدثون: ${t.speakerNames.join('، ')}', style: small),
          );
        }
      }
    }

    content.add(sectionTitle('القرارات'));
    if (minutes.decisions.isEmpty) {
      content.add(emptyNote('لم تُتخذ قرارات.'));
    } else {
      for (var i = 0; i < minutes.decisions.length; i++) {
        final d = minutes.decisions[i];
        final by = d.proposedBy == null ? '' : ' (اقترحه: ${d.proposedBy})';
        content.add(bullet('${_oneLine(d.text)}$by', marker: '${i + 1}.'));
      }
    }

    content.add(sectionTitle('المهام'));
    if (minutes.actionItems.isEmpty) {
      content.add(emptyNote('لم تُسنَد مهام.'));
    } else {
      content.add(
        _actionTable(minutes.actionItems, base, bold, headerFill, rule),
      );
    }

    if (minutes.openQuestions.isNotEmpty) {
      content.add(sectionTitle('أسئلة مفتوحة'));
      content.addAll(minutes.openQuestions.map((q) => bullet(q)));
    }
    if (minutes.nextMeeting != null) {
      content
        ..add(sectionTitle('الاجتماع القادم'))
        ..add(paragraph(minutes.nextMeeting!));
    }
    if (minutes.notes != null) {
      content
        ..add(sectionTitle('ملاحظات'))
        ..addAll(
          minutes.notes!
              .split(RegExp(r'\n\s*\n'))
              .where((p) => p.trim().isNotEmpty)
              .map((p) => paragraph(p)),
        );
    }
    content
      ..add(pw.SizedBox(height: 12))
      ..add(pw.Divider(color: rule, thickness: 0.5))
      ..add(paragraph(_generatedLine(minutes), style: small));

    if (includeTranscript && segments.isNotEmpty) {
      content
        ..add(pw.NewPage())
        ..add(sectionTitle('ملحق: النص الكامل للاجتماع'));
      for (final block in buildTranscriptBlocks(segments, speakersById)) {
        content.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.RichText(
              textAlign: pw.TextAlign.justify,
              overflow: pw.TextOverflow.span,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '[${formatTimestamp(block.startMs)}] ',
                    style: small,
                  ),
                  pw.TextSpan(
                    text: '${block.speakerName}: ',
                    style: bold.copyWith(fontSize: 10),
                  ),
                  pw.TextSpan(
                    text: block.text,
                    style: base.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final doc = pw.Document(
      title: 'محضر اجتماع: ${_oneLine(title)}',
      author: appName,
      creator: appName,
      subject: dateText,
    );
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 36),
          textDirection: pw.TextDirection.rtl,
          theme: theme,
        ),
        maxPages: 5000,
        header: (context) {
          if (context.pageNumber == 1) return pw.SizedBox();
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: rule, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'محضر اجتماع: ${_oneLine(title)}',
                    style: small,
                    maxLines: 1,
                  ),
                ),
                pw.Text('$dateText — $durationText', style: small),
              ],
            ),
          );
        },
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(appName, style: small),
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: small,
              ),
            ],
          ),
        ),
        build: (context) => content,
      ),
    );
    return doc.save();
  }

  pw.Widget _actionTable(
    List<ActionItem> items,
    pw.TextStyle base,
    pw.TextStyle bold,
    PdfColor headerFill,
    PdfColor rule,
  ) {
    // pw.Table lays columns out left-to-right regardless of text direction,
    // so the logical RTL order (#, task, owner, due) is reversed here to put
    // "#" on the right-hand side.
    pw.Widget cell(String text, pw.TextStyle style) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(text, style: style),
    );
    final headerStyle = bold.copyWith(fontSize: 10);
    final cellStyle = base.copyWith(fontSize: 10);
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerFill),
        repeat: true,
        children: [
          cell('الموعد', headerStyle),
          cell('المسؤول', headerStyle),
          cell('المهمة', headerStyle),
          cell('#', headerStyle),
        ],
      ),
      for (var i = 0; i < items.length; i++)
        pw.TableRow(
          children: [
            cell(items[i].dueDate ?? '—', cellStyle),
            cell(items[i].owner ?? '—', cellStyle),
            cell(_oneLine(items[i].task), cellStyle),
            cell('${i + 1}', cellStyle),
          ],
        ),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: rule, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(5),
        3: pw.FixedColumnWidth(24),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
      children: rows,
    );
  }
}
