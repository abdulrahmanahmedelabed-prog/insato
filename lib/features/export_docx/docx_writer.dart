// A small, pure-Dart writer of right-to-left Word documents (.docx, Office
// Open XML WordprocessingML zipped with package:archive).
//
// It supports exactly what the meeting minutes need: a title, headings,
// paragraphs of (bold / muted) runs, bullet and numbered lists
// (word/numbering.xml), tables with a repeated header row, page breaks and a
// page-numbered footer. Every paragraph is RTL (`w:bidi`), Arabic runs carry
// `w:rtl` and the complex-script font attributes (`w:cs`), so Word, LibreOffice
// and Google Docs lay the document out right-to-left with Noto Naskh Arabic
// (falling back to Arial / Times New Roman where it is not installed).

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

// ---------------------------------------------------------------------------
// XML text helpers
// ---------------------------------------------------------------------------

/// True for code points allowed in XML 1.0 documents:
/// `#x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]`.
bool isValidXmlChar(int rune) =>
    rune == 0x9 ||
    rune == 0xA ||
    rune == 0xD ||
    (rune >= 0x20 && rune <= 0xD7FF) ||
    (rune >= 0xE000 && rune <= 0xFFFD) ||
    (rune >= 0x10000 && rune <= 0x10FFFF);

/// Removes the characters XML 1.0 cannot carry at all (C0 controls other
/// than tab / newline / carriage return, lone surrogates, U+FFFE, U+FFFF).
String stripInvalidXmlChars(String input) {
  var clean = true;
  for (final r in input.runes) {
    if (!isValidXmlChar(r)) {
      clean = false;
      break;
    }
  }
  if (clean) return input;
  final b = StringBuffer();
  for (final r in input.runes) {
    if (isValidXmlChar(r)) b.writeCharCode(r);
  }
  return b.toString();
}

/// Escapes [input] for XML text and attribute values (`& < > " '`) after
/// removing characters XML cannot carry.
String xmlEscape(String input) {
  final s = stripInvalidXmlChars(input);
  final b = StringBuffer();
  for (final unit in s.codeUnits) {
    switch (unit) {
      case 0x26:
        b.write('&amp;');
      case 0x3C:
        b.write('&lt;');
      case 0x3E:
        b.write('&gt;');
      case 0x22:
        b.write('&quot;');
      case 0x27:
        b.write('&apos;');
      default:
        b.writeCharCode(unit);
    }
  }
  return b.toString();
}

// ---------------------------------------------------------------------------
// Direction of text pieces
// ---------------------------------------------------------------------------

bool _isRtlLetter(int r) =>
    (r >= 0x0590 && r <= 0x08FF) || // Hebrew, Arabic, Syriac, Thaana, …
    (r >= 0xFB1D && r <= 0xFDFF) || // Presentation forms A
    (r >= 0xFE70 && r <= 0xFEFF) || // Presentation forms B
    (r >= 0x10E60 && r <= 0x10EFF) ||
    (r >= 0x1EE00 && r <= 0x1EEFF);

bool _isLtrLetter(int r) =>
    (r >= 0x41 && r <= 0x5A) ||
    (r >= 0x61 && r <= 0x7A) ||
    (r >= 0xC0 && r <= 0x24F && r != 0xD7 && r != 0xF7) ||
    (r >= 0x370 && r <= 0x52F) || // Greek, Cyrillic
    (r >= 0x1E00 && r <= 0x1FFF);

bool _isDigit(int r) => r >= 0x30 && r <= 0x39;

/// One piece of text with a single direction.
class DirectionalPiece {
  /// Creates a piece.
  const DirectionalPiece(this.text, {required this.rtl});

  /// The text.
  final String text;

  /// True when the piece is right-to-left (gets `w:rtl`).
  final bool rtl;

  @override
  String toString() => '${rtl ? 'R' : 'L'}«$text»';
}

/// Splits [text] into right-to-left and left-to-right pieces so Latin words
/// (names, product terms, code) keep their own font and order inside an
/// Arabic paragraph.
///
/// A piece is LTR only from its first Latin / Greek / Cyrillic letter to its
/// last such letter or ASCII digit (with the neutral characters between
/// them); everything else — Arabic letters, leading digits, spaces and
/// punctuation at the boundaries — belongs
/// to the surrounding RTL text, which matches how Word itself splits runs.
List<DirectionalPiece> splitByDirection(String text) {
  if (text.isEmpty) return const [];
  final runes = text.runes.toList();
  final pieces = <DirectionalPiece>[];
  final buf = StringBuffer();
  var bufRtl = true;
  var i = 0;
  while (i < runes.length) {
    final r = runes[i];
    if (_isLtrLetter(r)) {
      // Extend to the last LTR letter (or a digit that follows LTR text,
      // as in `claude-opus-5` or `OPEX 2026`) before the next RTL letter.
      var end = i;
      var j = i;
      while (j < runes.length && !_isRtlLetter(runes[j])) {
        if (_isLtrLetter(runes[j]) || _isDigit(runes[j])) end = j;
        j++;
      }
      if (buf.isNotEmpty && bufRtl) {
        pieces.add(DirectionalPiece(buf.toString(), rtl: true));
        buf.clear();
      }
      bufRtl = false;
      for (var k = i; k <= end; k++) {
        buf.writeCharCode(runes[k]);
      }
      pieces.add(DirectionalPiece(buf.toString(), rtl: false));
      buf.clear();
      bufRtl = true;
      i = end + 1;
    } else {
      buf.writeCharCode(r);
      i++;
    }
  }
  if (buf.isNotEmpty) pieces.add(DirectionalPiece(buf.toString(), rtl: true));
  return pieces;
}

// ---------------------------------------------------------------------------
// Document model
// ---------------------------------------------------------------------------

/// A run of text with one formatting.
class DocxRun {
  /// Creates a run.
  const DocxRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.color,
    this.sizeHalfPoints,
  });

  /// The text; `\n` becomes a line break and `\t` a tab.
  final String text;

  /// Bold.
  final bool bold;

  /// Italic.
  final bool italic;

  /// Hex colour without `#` (e.g. `5F6B7A`), or null for the style's.
  final String? color;

  /// Font size in half-points (22 = 11 pt), or null for the style's.
  final int? sizeHalfPoints;
}

/// Paragraph styles defined in word/styles.xml.
enum DocxStyle {
  /// Body text.
  normal('Normal'),

  /// Document title.
  title('Title'),

  /// Small label above the title.
  subtitle('Subtitle'),

  /// Section heading.
  heading1('Heading1'),

  /// Sub-heading (topic titles).
  heading2('Heading2'),

  /// Small, muted text (notes, generated-by line).
  note('InsatoNote'),

  /// List item.
  listParagraph('ListParagraph'),

  /// Text inside table cells.
  tableText('InsatoTableText');

  const DocxStyle(this.id);

  /// The `w:styleId`.
  final String id;
}

/// Paragraph alignment (in the paragraph's own, right-to-left direction).
enum DocxAlign {
  /// Leading edge (right in an RTL paragraph).
  start,

  /// Centered.
  center,

  /// Justified.
  justify,
}

/// A block-level element of the body.
sealed class DocxBlock {
  const DocxBlock();
}

/// A paragraph.
class DocxParagraph extends DocxBlock {
  /// Creates a paragraph.
  const DocxParagraph(
    this.runs, {
    this.style = DocxStyle.normal,
    this.align = DocxAlign.start,
    this.numId,
    this.keepNext = false,
  });

  /// The runs.
  final List<DocxRun> runs;

  /// The paragraph style.
  final DocxStyle style;

  /// Alignment.
  final DocxAlign align;

  /// Numbering instance (`w:numId`) for list items, or null.
  final int? numId;

  /// Keep with the next paragraph (headings).
  final bool keepNext;
}

/// A table. Column 0 is the right-most column (`w:bidiVisual`).
class DocxTable extends DocxBlock {
  /// Creates a table. [columnWidths] are in twentieths of a point and must
  /// have one entry per column.
  DocxTable({
    required this.header,
    required this.rows,
    required this.columnWidths,
    this.minRowHeight,
  }) : assert(header.length == columnWidths.length),
       assert(rows.every((r) => r.length == columnWidths.length));

  /// Header cells (repeated on every page).
  final List<String> header;

  /// Body rows.
  final List<List<String>> rows;

  /// Column widths (twips).
  final List<int> columnWidths;

  /// Minimum body row height (twips), e.g. room for a signature.
  final int? minRowHeight;
}

/// A page break.
class DocxPageBreak extends DocxBlock {
  /// Creates a page break.
  const DocxPageBreak();
}

/// Metadata written to docProps/core.xml and docProps/app.xml.
class DocxMetadata {
  /// Creates metadata.
  const DocxMetadata({
    required this.title,
    required this.created,
    this.subject = '',
    this.creator = '',
    this.application = '',
    this.language = 'ar-SA',
  });

  /// `dc:title`.
  final String title;

  /// `dc:subject`.
  final String subject;

  /// `dc:creator` / `cp:lastModifiedBy`.
  final String creator;

  /// `Application` in app.xml.
  final String application;

  /// `dc:language`.
  final String language;

  /// `dcterms:created` / `dcterms:modified`.
  final DateTime created;
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

/// Builds a right-to-left .docx document block by block.
class DocxBuilder {
  /// Creates a builder.
  ///
  /// [arabicFont] is used for complex-script (Arabic) runs and [latinFont]
  /// for Latin runs; when a font is not installed Word substitutes the
  /// [arabicFallback] / [latinFallback] declared in word/fontTable.xml.
  /// [footerText] is written before "page X of Y" in the footer.
  DocxBuilder({
    this.arabicFont = 'Noto Naskh Arabic',
    this.arabicFallback = 'Arial',
    this.latinFont = 'Noto Sans',
    this.latinFallback = 'Arial',
    this.footerText = '',
    this.pageLabel = 'صفحة',
    this.ofLabel = 'من',
  });

  /// Complex-script (Arabic) font.
  final String arabicFont;

  /// Substitute for [arabicFont] (`w:altName`).
  final String arabicFallback;

  /// Latin font.
  final String latinFont;

  /// Substitute for [latinFont] (`w:altName`).
  final String latinFallback;

  /// Footer text (e.g. the app name); empty for none.
  final String footerText;

  /// "Page" word of the footer.
  final String pageLabel;

  /// "of" word of the footer.
  final String ofLabel;

  final List<DocxBlock> _blocks = [];
  int _numbered = 0;

  /// numId of the shared bullet list instance.
  static const int bulletNumId = 1;

  /// The blocks added so far.
  List<DocxBlock> get blocks => List.unmodifiable(_blocks);

  /// Adds any block.
  void add(DocxBlock block) => _blocks.add(block);

  /// Adds the document title.
  void title(String text) => _blocks.add(
    DocxParagraph([DocxRun(text)], style: DocxStyle.title, keepNext: true),
  );

  /// Adds the small label above the title.
  void subtitle(String text) => _blocks.add(
    DocxParagraph([DocxRun(text)], style: DocxStyle.subtitle, keepNext: true),
  );

  /// Adds a heading of [level] 1 or 2.
  void heading(String text, {int level = 1}) => _blocks.add(
    DocxParagraph(
      [DocxRun(text)],
      style: level <= 1 ? DocxStyle.heading1 : DocxStyle.heading2,
      keepNext: true,
    ),
  );

  /// Adds a paragraph of plain [text].
  void paragraph(String text, {DocxAlign align = DocxAlign.justify}) =>
      _blocks.add(DocxParagraph([DocxRun(text)], align: align));

  /// Adds a paragraph of [runs].
  void runs(
    List<DocxRun> runs, {
    DocxStyle style = DocxStyle.normal,
    DocxAlign align = DocxAlign.start,
  }) => _blocks.add(DocxParagraph(runs, style: style, align: align));

  /// Adds a small, muted note.
  void note(String text) =>
      _blocks.add(DocxParagraph([DocxRun(text)], style: DocxStyle.note));

  /// Adds a `label: value` line with a bold label.
  void labelValue(String label, String value) => _blocks.add(
    DocxParagraph([DocxRun('$label: ', bold: true), DocxRun(value)]),
  );

  /// Adds a bullet list; each item is a list of runs.
  void bulletRuns(List<List<DocxRun>> items) {
    for (final item in items) {
      _blocks.add(
        DocxParagraph(item, style: DocxStyle.listParagraph, numId: bulletNumId),
      );
    }
  }

  /// Adds a bullet list of plain items.
  void bullets(List<String> items) => bulletRuns([
    for (final i in items) [DocxRun(i)],
  ]);

  /// Adds a numbered list (restarting at 1); each item is a list of runs.
  void numberedRuns(List<List<DocxRun>> items) {
    if (items.isEmpty) return;
    _numbered++;
    final numId = bulletNumId + _numbered;
    for (final item in items) {
      _blocks.add(
        DocxParagraph(item, style: DocxStyle.listParagraph, numId: numId),
      );
    }
  }

  /// Adds a numbered list of plain items.
  void numbered(List<String> items) => numberedRuns([
    for (final i in items) [DocxRun(i)],
  ]);

  /// Adds a table.
  void table(DocxTable table) => _blocks.add(table);

  /// Adds a page break.
  void pageBreak() => _blocks.add(const DocxPageBreak());

  // -------------------------------------------------------------------------
  // Serialisation
  // -------------------------------------------------------------------------

  static const String _xmlDecl =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

  static const String _nsW =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const String _nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const String _relBase =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// Text width of an A4 page with 2 cm margins (twips).
  static const int textWidth = 11906 - 2 * 1134;

  /// Paths of the parts of the package, in zip order.
  static const List<String> partNames = [
    '[Content_Types].xml',
    '_rels/.rels',
    'docProps/core.xml',
    'docProps/app.xml',
    'word/document.xml',
    'word/_rels/document.xml.rels',
    'word/styles.xml',
    'word/numbering.xml',
    'word/settings.xml',
    'word/fontTable.xml',
    'word/footer1.xml',
  ];

  /// Returns every part of the package as XML text, keyed by path.
  Map<String, String> buildParts(DocxMetadata meta) => {
    '[Content_Types].xml': _contentTypes(),
    '_rels/.rels': _packageRels(),
    'docProps/core.xml': _coreXml(meta),
    'docProps/app.xml': _appXml(meta),
    'word/document.xml': _documentXml(),
    'word/_rels/document.xml.rels': _documentRels(),
    'word/styles.xml': _stylesXml(),
    'word/numbering.xml': _numberingXml(),
    'word/settings.xml': _settingsXml(),
    'word/fontTable.xml': _fontTableXml(),
    'word/footer1.xml': _footerXml(),
  };

  /// Builds the zipped .docx bytes.
  Uint8List build(DocxMetadata meta) {
    final parts = buildParts(meta);
    final archive = Archive();
    for (final name in partNames) {
      archive.addFile(ArchiveFile.bytes(name, utf8.encode(parts[name]!)));
    }
    final created = meta.created.year < 1980 ? DateTime(1980) : meta.created;
    return ZipEncoder().encodeBytes(archive, modified: created);
  }

  String _contentTypes() {
    const wml =
        'application/vnd.openxmlformats-officedocument.'
        'wordprocessingml';
    return '$_xmlDecl'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
        'content-types">'
        '<Default Extension="rels" ContentType="application/'
        'vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" '
        'ContentType="$wml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" '
        'ContentType="$wml.styles+xml"/>'
        '<Override PartName="/word/numbering.xml" '
        'ContentType="$wml.numbering+xml"/>'
        '<Override PartName="/word/settings.xml" '
        'ContentType="$wml.settings+xml"/>'
        '<Override PartName="/word/fontTable.xml" '
        'ContentType="$wml.fontTable+xml"/>'
        '<Override PartName="/word/footer1.xml" '
        'ContentType="$wml.footer+xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType="application/'
        'vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/'
        'vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';
  }

  String _packageRels() =>
      '$_xmlDecl'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="$_relBase/officeDocument" '
      'Target="word/document.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/'
      'package/2006/relationships/metadata/core-properties" '
      'Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" Type="$_relBase/extended-properties" '
      'Target="docProps/app.xml"/>'
      '</Relationships>';

  String _documentRels() =>
      '$_xmlDecl'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="$_relBase/styles" Target="styles.xml"/>'
      '<Relationship Id="rId2" Type="$_relBase/numbering" '
      'Target="numbering.xml"/>'
      '<Relationship Id="rId3" Type="$_relBase/settings" '
      'Target="settings.xml"/>'
      '<Relationship Id="rId4" Type="$_relBase/fontTable" '
      'Target="fontTable.xml"/>'
      '<Relationship Id="rId5" Type="$_relBase/footer" Target="footer1.xml"/>'
      '</Relationships>';

  static String _w3cdtf(DateTime t) {
    final u = t.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-'
        '${two(u.day)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  String _coreXml(DocxMetadata m) {
    final when = _w3cdtf(m.created);
    return '$_xmlDecl'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/'
        'package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${xmlEscape(m.title)}</dc:title>'
        '<dc:subject>${xmlEscape(m.subject)}</dc:subject>'
        '<dc:creator>${xmlEscape(m.creator)}</dc:creator>'
        '<dc:language>${xmlEscape(m.language)}</dc:language>'
        '<cp:lastModifiedBy>${xmlEscape(m.creator)}</cp:lastModifiedBy>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$when</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$when</dcterms:modified>'
        '</cp:coreProperties>';
  }

  String _appXml(DocxMetadata m) =>
      '$_xmlDecl'
      '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/'
      '2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/'
      'officeDocument/2006/docPropsVTypes">'
      '<Application>${xmlEscape(m.application)}</Application>'
      '<DocSecurity>0</DocSecurity>'
      '<ScaleCrop>false</ScaleCrop>'
      '<LinksUpToDate>false</LinksUpToDate>'
      '<SharedDoc>false</SharedDoc>'
      '<HyperlinksChanged>false</HyperlinksChanged>'
      '</Properties>';

  String _fontsAttr() =>
      '<w:rFonts w:ascii="${xmlEscape(latinFont)}" '
      'w:hAnsi="${xmlEscape(latinFont)}" '
      'w:eastAsia="${xmlEscape(latinFont)}" '
      'w:cs="${xmlEscape(arabicFont)}"/>';

  String _stylesXml() {
    String pStyle(
      String id,
      String name, {
      String? basedOn,
      String? next,
      bool isDefault = false,
      String pPr = '',
      String rPr = '',
      int? uiPriority,
    }) =>
        '<w:style w:type="paragraph"${isDefault ? ' w:default="1"' : ''} '
        'w:styleId="$id"><w:name w:val="$name"/>'
        '${basedOn == null ? '' : '<w:basedOn w:val="$basedOn"/>'}'
        '${next == null ? '' : '<w:next w:val="$next"/>'}'
        '${uiPriority == null ? '' : '<w:uiPriority w:val="$uiPriority"/>'}'
        '<w:qFormat/>'
        '<w:pPr>$pPr</w:pPr>'
        '<w:rPr>$rPr</w:rPr>'
        '</w:style>';

    String size(int halfPoints) =>
        '<w:sz w:val="$halfPoints"/><w:szCs w:val="$halfPoints"/>';
    const bold = '<w:b/><w:bCs/>';
    String color(String hex) => '<w:color w:val="$hex"/>';
    const accent = '1F4E79';
    const muted = '5F6B7A';

    return '$_xmlDecl'
        '<w:styles xmlns:w="$_nsW">'
        '<w:docDefaults>'
        '<w:rPrDefault><w:rPr>${_fontsAttr()}${size(22)}'
        '<w:lang w:val="en-US" w:eastAsia="en-US" w:bidi="ar-SA"/>'
        '</w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:bidi/>'
        '<w:spacing w:after="120" w:line="300" w:lineRule="auto"/>'
        '</w:pPr></w:pPrDefault>'
        '</w:docDefaults>'
        '${pStyle('Normal', 'Normal', isDefault: true, pPr: '<w:bidi/>')}'
        '${pStyle('Title', 'Title', basedOn: 'Normal', next: 'Normal', uiPriority: 10, pPr: '<w:keepNext/><w:bidi/><w:spacing w:after="160"/>', rPr: '$bold${color(accent)}${size(40)}')}'
        '${pStyle('Subtitle', 'Subtitle', basedOn: 'Normal', next: 'Title', uiPriority: 11, pPr: '<w:keepNext/><w:bidi/><w:spacing w:after="0"/>', rPr: '${color(muted)}${size(22)}')}'
        '${pStyle('Heading1', 'heading 1', basedOn: 'Normal', next: 'Normal', uiPriority: 9, pPr: '<w:keepNext/><w:keepLines/><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="2" w:color="C9D3DF"/></w:pBdr><w:bidi/><w:spacing w:before="280" w:after="120"/><w:outlineLvl w:val="0"/>', rPr: '$bold${color(accent)}${size(28)}')}'
        '${pStyle('Heading2', 'heading 2', basedOn: 'Normal', next: 'Normal', uiPriority: 9, pPr: '<w:keepNext/><w:keepLines/><w:bidi/><w:spacing w:before="160" w:after="80"/><w:outlineLvl w:val="1"/>', rPr: '$bold${size(24)}')}'
        '${pStyle('ListParagraph', 'List Paragraph', basedOn: 'Normal', uiPriority: 34, pPr: '<w:bidi/><w:spacing w:after="60"/><w:ind w:left="720"/><w:contextualSpacing/>')}'
        '${pStyle('InsatoNote', 'Insato Note', basedOn: 'Normal', pPr: '<w:bidi/>', rPr: '${color(muted)}${size(18)}')}'
        '${pStyle('InsatoTableText', 'Insato Table Text', basedOn: 'Normal', pPr: '<w:bidi/><w:spacing w:before="40" w:after="40" w:line="260" w:lineRule="auto"/>', rPr: size(20))}'
        '<w:style w:type="table" w:default="1" w:styleId="TableNormal">'
        '<w:name w:val="Normal Table"/><w:uiPriority w:val="99"/>'
        '<w:semiHidden/><w:unhideWhenUsed/>'
        '<w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar>'
        '<w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/>'
        '<w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/>'
        '</w:tblCellMar></w:tblPr></w:style>'
        '<w:style w:type="table" w:styleId="InsatoTable">'
        '<w:name w:val="Insato Table"/><w:basedOn w:val="TableNormal"/>'
        '<w:uiPriority w:val="59"/>'
        '<w:tblPr><w:tblBorders>'
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="C9D3DF"/>'
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="C9D3DF"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="C9D3DF"/>'
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="C9D3DF"/>'
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="C9D3DF"/>'
        '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="C9D3DF"/>'
        '</w:tblBorders></w:tblPr></w:style>'
        '</w:styles>';
  }

  String _numberingXml() {
    String abstractNum(int id, String fmt, String text) =>
        '<w:abstractNum w:abstractNumId="$id">'
        '<w:multiLevelType w:val="singleLevel"/>'
        '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="$fmt"/>'
        '<w:lvlText w:val="$text"/><w:lvlJc w:val="left"/>'
        '<w:pPr><w:bidi/><w:ind w:left="720" w:hanging="360"/></w:pPr>'
        '<w:rPr><w:rFonts w:ascii="${xmlEscape(latinFallback)}" '
        'w:hAnsi="${xmlEscape(latinFallback)}" '
        'w:cs="${xmlEscape(arabicFallback)}"/><w:rtl/></w:rPr>'
        '</w:lvl></w:abstractNum>';
    final b = StringBuffer()
      ..write(_xmlDecl)
      ..write('<w:numbering xmlns:w="$_nsW">')
      ..write(abstractNum(0, 'bullet', '•'))
      ..write(abstractNum(1, 'decimal', '%1.'))
      ..write(
        '<w:num w:numId="$bulletNumId"><w:abstractNumId w:val="0"/>'
        '</w:num>',
      );
    for (var i = 1; i <= _numbered; i++) {
      b.write(
        '<w:num w:numId="${bulletNumId + i}"><w:abstractNumId w:val="1"/>'
        '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/>'
        '</w:lvlOverride></w:num>',
      );
    }
    b.write('</w:numbering>');
    return b.toString();
  }

  String _settingsXml() =>
      '$_xmlDecl'
      '<w:settings xmlns:w="$_nsW">'
      '<w:defaultTabStop w:val="720"/>'
      '<w:characterSpacingControl w:val="doNotCompress"/>'
      '<w:compat><w:compatSetting w:name="compatibilityMode" '
      'w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>'
      '</w:compat>'
      '<w:themeFontLang w:val="en-US" w:bidi="ar-SA"/>'
      '</w:settings>';

  String _fontTableXml() {
    String font(String name, String alt, String charset, String family) =>
        '<w:font w:name="${xmlEscape(name)}">'
        '<w:altName w:val="${xmlEscape(alt)}"/>'
        '<w:charset w:val="$charset"/><w:family w:val="$family"/>'
        '<w:pitch w:val="variable"/></w:font>';
    return '$_xmlDecl'
        '<w:fonts xmlns:w="$_nsW">'
        '${font(arabicFont, arabicFallback, 'B2', 'roman')}'
        '${font(latinFont, latinFallback, '00', 'swiss')}'
        '${font(arabicFallback, 'Times New Roman', '00', 'swiss')}'
        '</w:fonts>';
  }

  String _footerXml() {
    const muted =
        '<w:color w:val="5F6B7A"/><w:sz w:val="18"/>'
        '<w:szCs w:val="18"/>';
    String run(String text) =>
        '<w:r><w:rPr>$muted<w:rtl/></w:rPr>'
        '<w:t xml:space="preserve">${xmlEscape(text)}</w:t></w:r>';
    String field(String instr) =>
        '<w:fldSimple w:instr=" $instr "><w:r><w:rPr>$muted<w:rtl/></w:rPr>'
        '<w:t>1</w:t></w:r></w:fldSimple>';
    final lead = footerText.trim().isEmpty ? '' : '${footerText.trim()} — ';
    return '$_xmlDecl'
        '<w:ftr xmlns:w="$_nsW" xmlns:r="$_nsR">'
        '<w:p><w:pPr><w:pStyle w:val="InsatoNote"/><w:bidi/>'
        '<w:jc w:val="center"/></w:pPr>'
        '${run('$lead$pageLabel ')}${field('PAGE')}${run(' $ofLabel ')}'
        '${field('NUMPAGES')}'
        '</w:p></w:ftr>';
  }

  String _documentXml() {
    final b = StringBuffer()
      ..write(_xmlDecl)
      ..write('<w:document xmlns:w="$_nsW" xmlns:r="$_nsR"><w:body>');
    for (final block in _blocks) {
      switch (block) {
        case DocxParagraph():
          _writeParagraph(b, block);
        case DocxTable():
          _writeTable(b, block);
          // Word needs a paragraph between adjacent tables, and a body that
          // ends with a table looks cramped; a small spacer covers both.
          b.write(
            '<w:p><w:pPr><w:bidi/><w:spacing w:after="60"/></w:pPr>'
            '</w:p>',
          );
        case DocxPageBreak():
          b.write(
            '<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:br w:type="page"/>'
            '</w:r></w:p>',
          );
      }
    }
    b
      ..write('<w:sectPr>')
      ..write('<w:footerReference w:type="default" r:id="rId5"/>')
      ..write('<w:pgSz w:w="11906" w:h="16838"/>')
      ..write(
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" '
        'w:left="1134" w:header="567" w:footer="567" w:gutter="0"/>',
      )
      ..write('<w:bidi/>')
      ..write('</w:sectPr></w:body></w:document>');
    return b.toString();
  }

  void _writeParagraph(StringBuffer b, DocxParagraph p) {
    b.write('<w:p><w:pPr>');
    if (p.style != DocxStyle.normal) {
      b.write('<w:pStyle w:val="${p.style.id}"/>');
    }
    if (p.keepNext) b.write('<w:keepNext/>');
    if (p.numId != null) {
      b.write(
        '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="${p.numId}"/>'
        '</w:numPr>',
      );
    }
    b.write('<w:bidi/>');
    switch (p.align) {
      case DocxAlign.start:
        break;
      case DocxAlign.center:
        b.write('<w:jc w:val="center"/>');
      case DocxAlign.justify:
        b.write('<w:jc w:val="both"/>');
    }
    b.write('</w:pPr>');
    for (final run in p.runs) {
      _writeRun(b, run);
    }
    b.write('</w:p>');
  }

  void _writeRun(StringBuffer b, DocxRun run) {
    final text = stripInvalidXmlChars(run.text).replaceAll('\r\n', '\n');
    for (final piece in splitByDirection(text)) {
      b.write('<w:r><w:rPr>');
      if (run.bold) b.write('<w:b/><w:bCs/>');
      if (run.italic) b.write('<w:i/><w:iCs/>');
      if (run.color != null) b.write('<w:color w:val="${run.color}"/>');
      if (run.sizeHalfPoints != null) {
        b.write(
          '<w:sz w:val="${run.sizeHalfPoints}"/>'
          '<w:szCs w:val="${run.sizeHalfPoints}"/>',
        );
      }
      if (piece.rtl) b.write('<w:rtl/>');
      b.write('</w:rPr>');
      _writeText(b, piece.text);
      b.write('</w:r>');
    }
  }

  static void _writeText(StringBuffer b, String text) {
    final lines = text.replaceAll('\r', '\n').split('\n');
    for (var li = 0; li < lines.length; li++) {
      if (li > 0) b.write('<w:br/>');
      final tabs = lines[li].split('\t');
      for (var ti = 0; ti < tabs.length; ti++) {
        if (ti > 0) b.write('<w:tab/>');
        if (tabs[ti].isEmpty) continue;
        b.write('<w:t xml:space="preserve">${xmlEscape(tabs[ti])}</w:t>');
      }
    }
  }

  void _writeTable(StringBuffer b, DocxTable t) {
    b
      ..write('<w:tbl><w:tblPr><w:tblStyle w:val="InsatoTable"/>')
      ..write('<w:bidiVisual/>')
      ..write(
        '<w:tblW w:w="${t.columnWidths.fold<int>(0, (a, w) => a + w)}" '
        'w:type="dxa"/>',
      )
      ..write('<w:tblLayout w:type="fixed"/>')
      ..write(
        '<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" '
        'w:firstColumn="0" w:lastColumn="0" w:noHBand="1" w:noVBand="1"/>',
      )
      ..write('</w:tblPr><w:tblGrid>');
    for (final w in t.columnWidths) {
      b.write('<w:gridCol w:w="$w"/>');
    }
    b.write('</w:tblGrid>');
    _writeRow(b, t, t.header, header: true);
    for (final row in t.rows) {
      _writeRow(b, t, row, header: false);
    }
    b.write('</w:tbl>');
  }

  void _writeRow(
    StringBuffer b,
    DocxTable t,
    List<String> cells, {
    required bool header,
  }) {
    b.write('<w:tr><w:trPr><w:cantSplit/>');
    if (header) {
      b.write('<w:tblHeader/>');
    } else if (t.minRowHeight != null) {
      b.write('<w:trHeight w:val="${t.minRowHeight}" w:hRule="atLeast"/>');
    }
    b.write('</w:trPr>');
    for (var i = 0; i < cells.length; i++) {
      b
        ..write('<w:tc><w:tcPr>')
        ..write('<w:tcW w:w="${t.columnWidths[i]}" w:type="dxa"/>');
      if (header) {
        b.write('<w:shd w:val="clear" w:color="auto" w:fill="E8EEF5"/>');
      }
      b.write('</w:tcPr>');
      _writeParagraph(
        b,
        DocxParagraph([
          DocxRun(cells[i], bold: header),
        ], style: DocxStyle.tableText),
      );
      b.write('</w:tc>');
    }
    b.write('</w:tr>');
  }
}
