// Fills a Word template (.docx) uploaded by the user with the minutes
// (v1.2, A): `{{placeholder}}` markers in the document body, headers and
// footers are replaced by editing the OOXML directly (package:archive +
// package:xml), so the template's own styles, fonts, page setup and
// right-to-left settings are kept.
//
// * A placeholder may be split by Word across several runs (`{{mee` +
//   `ting_number}}`, spell-check / edit history): the text of a paragraph is
//   matched as a whole and the replacement is written into the run where the
//   placeholder starts (keeping its formatting); the rest is removed from
//   the following runs.
// * Scalar values replace the marker inline; line breaks become `<w:br/>`.
// * Image values (`{{logo}}`, `{{signature.image}}`) become inline pictures.
// * Block placeholders (`{{resolutions}}`, `{{action_items}}`, …) alone in a
//   paragraph expand into one paragraph per entry, cloned from it.
// * Item placeholders (`{{action_item.task}}`, `{{signature.name}}`, …):
//   a table row (or, outside tables, a paragraph) that contains them is
//   repeated once per item.
// * Unknown placeholders stay visible; known ones without a value become
//   empty.
//
// Pure Dart, unit-tested.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Largest accepted template file.
const int kMaxTemplateBytes = 10 * 1024 * 1024;

/// A template could not be used; [messageAr] explains why.
class DocxTemplateException implements Exception {
  /// Creates the exception.
  const DocxTemplateException(this.messageAr);

  /// Arabic, user-facing reason.
  final String messageAr;

  @override
  String toString() => 'DocxTemplateException: $messageAr';
}

/// An image to insert.
class DocxImage {
  /// Creates an image. [extension] is `png` or `jpeg`.
  const DocxImage({
    required this.bytes,
    required this.extension,
    required this.widthPx,
    required this.heightPx,
    this.maxWidthCm = 4,
    this.maxHeightCm = 2.5,
  });

  /// File bytes.
  final Uint8List bytes;

  /// `png` or `jpeg`.
  final String extension;

  /// Pixel width.
  final int widthPx;

  /// Pixel height.
  final int heightPx;

  /// Largest printed width.
  final double maxWidthCm;

  /// Largest printed height.
  final double maxHeightCm;

  /// Printed size in EMU, keeping the aspect ratio.
  (int, int) get extentEmu {
    const emuPerCm = 360000;
    final w = widthPx <= 0 ? 1 : widthPx;
    final h = heightPx <= 0 ? 1 : heightPx;
    var cw = maxWidthCm;
    var ch = cw * h / w;
    if (ch > maxHeightCm) {
      ch = maxHeightCm;
      cw = ch * w / h;
    }
    return ((cw * emuPerCm).round(), (ch * emuPerCm).round());
  }
}

/// Values to fill a template with. A value is a [String], a [DocxImage] or
/// null (known but empty).
class DocxTemplateData {
  /// Creates the data.
  const DocxTemplateData({
    this.values = const {},
    this.blocks = const {},
    this.collections = const {},
  });

  /// Scalar placeholders (`entity_name` → text / image / null).
  final Map<String, Object?> values;

  /// Block placeholders (`resolutions` → one entry per paragraph).
  final Map<String, List<String>> blocks;

  /// Item collections (`action_item` → items of field → value).
  final Map<String, List<Map<String, Object?>>> collections;
}

final RegExp _placeholder = RegExp(
  r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?)\s*\}\}',
);

/// Names of the placeholders in [text], in order (duplicates kept).
List<String> placeholdersIn(String text) => [
  for (final m in _placeholder.allMatches(text)) m.group(1)!,
];

const String _nsW =
    'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const String _relImage =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image';

bool _isW(XmlNode n, String local) =>
    n is XmlElement &&
    n.name.local == local &&
    (n.name.namespaceUri == _nsW || n.name.prefix == 'w');

XmlElement? _ancestor(XmlNode n, String local) {
  XmlNode? p = n.parent;
  while (p != null) {
    if (_isW(p, local)) return p as XmlElement;
    p = p.parent;
  }
  return null;
}

/// `w:t` elements whose nearest paragraph is [p].
List<XmlElement> _texts(XmlElement p) => [
  for (final e in p.descendants.whereType<XmlElement>())
    if (_isW(e, 't') && identical(_ancestor(e, 'p'), p)) e,
];

String _paragraphText(XmlElement p) => _texts(p).map((t) => t.innerText).join();

/// Paragraphs that contain no other paragraph.
List<XmlElement> _innermostParagraphs(XmlNode root) => [
  for (final e in root.descendants.whereType<XmlElement>())
    if (_isW(e, 'p') &&
        !e.descendants.any((d) => d is XmlElement && _isW(d, 'p')))
      e,
];

bool _isDocxZip(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x50 &&
    bytes[1] == 0x4B &&
    bytes[2] == 0x03 &&
    bytes[3] == 0x04;

bool _isOleDoc(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0xD0 &&
    bytes[1] == 0xCF &&
    bytes[2] == 0x11 &&
    bytes[3] == 0xE0;

Archive _openDocx(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const DocxTemplateException('الملف فارغ.');
  }
  if (bytes.length > kMaxTemplateBytes) {
    throw const DocxTemplateException(
      'حجم القالب يتجاوز الحد المسموح (10 ميغابايت).',
    );
  }
  if (_isOleDoc(bytes)) {
    throw const DocxTemplateException(
      'صيغة Word القديمة (.doc) غير مدعومة. احفظ القالب بصيغة .docx ثم '
      'أعد رفعه.',
    );
  }
  if (!_isDocxZip(bytes)) {
    throw const DocxTemplateException(
      'الملف ليس مستند Word صالحاً بصيغة .docx.',
    );
  }
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const DocxTemplateException('تعذّرت قراءة ملف Word: الملف تالف.');
  }
  if (archive.findFile('word/document.xml') == null ||
      archive.findFile('[Content_Types].xml') == null) {
    throw const DocxTemplateException(
      'الملف ليس مستند Word صالحاً (لا يحتوي على متن المستند).',
    );
  }
  return archive;
}

String _fileText(ArchiveFile f) => utf8.decode(f.content, allowMalformed: true);

bool _isTemplatePart(String name) =>
    name == 'word/document.xml' ||
    RegExp(r'^word/(header|footer)\d*\.xml$').hasMatch(name);

/// Checks an uploaded template and returns the placeholders it contains
/// (distinct, in order of appearance). Throws [DocxTemplateException] with
/// an Arabic reason when it is not a usable .docx or has no placeholder
/// of [known] (when given, any `{{…}}` otherwise).
List<String> inspectDocxTemplate(Uint8List bytes, {Set<String>? known}) {
  final archive = _openDocx(bytes);
  final found = <String>[];
  for (final f in archive.files) {
    if (!f.isFile || !_isTemplatePart(f.name)) continue;
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(_fileText(f));
    } on XmlException {
      throw const DocxTemplateException('تعذّرت قراءة ملف Word: الملف تالف.');
    }
    for (final p in _innermostParagraphs(doc)) {
      for (final name in placeholdersIn(_paragraphText(p))) {
        if (!found.contains(name)) found.add(name);
      }
    }
  }
  final usable = known == null
      ? found
      : found.where(
          (n) => known.contains(n) || known.contains(n.split('.').first),
        );
  if (usable.isEmpty) {
    throw const DocxTemplateException(
      'لم يُعثر في القالب على أي حقل مثل {{meeting_title}} أو '
      '{{resolutions}}. أضف الحقول إلى المستند (يمكنك تنزيل القالب النموذجي '
      'للاطلاع عليها) ثم أعد رفعه.',
    );
  }
  return found;
}

/// Fills [template] with [data] and returns the new .docx bytes. Throws
/// [DocxTemplateException] when [template] is not a usable .docx.
Uint8List fillDocxTemplate(Uint8List template, DocxTemplateData data) {
  final archive = _openDocx(template);
  final filler = _Filler(data);
  final out = Archive();
  final edited = <String, String>{};
  for (final f in archive.files) {
    if (!f.isFile || !_isTemplatePart(f.name)) continue;
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(_fileText(f));
    } on XmlException {
      throw const DocxTemplateException('تعذّرت قراءة ملف Word: الملف تالف.');
    }
    filler.part = f.name;
    filler.fill(doc);
    edited[f.name] = doc.toXmlString();
  }
  // Relationships of the parts that received images.
  for (final entry in filler.images.entries) {
    final part = entry.key;
    final slash = part.lastIndexOf('/');
    final relsName =
        '${part.substring(0, slash)}/_rels/${part.substring(slash + 1)}.rels';
    final existing = archive.findFile(relsName);
    final rels = existing == null
        ? XmlDocument.parse(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/'
            '2006/relationships"></Relationships>',
          )
        : XmlDocument.parse(edited[relsName] ?? _fileText(existing));
    for (final img in entry.value) {
      rels.rootElement.children.add(
        XmlElement(const XmlName.qualified('Relationship'), [
          XmlAttribute(const XmlName.qualified('Id'), img.relId),
          XmlAttribute(const XmlName.qualified('Type'), _relImage),
          XmlAttribute(
            const XmlName.qualified('Target'),
            'media/${img.fileName}',
          ),
        ]),
      );
    }
    edited[relsName] = rels.toXmlString();
  }
  if (filler.images.isNotEmpty) {
    final ctName = '[Content_Types].xml';
    final ct = XmlDocument.parse(
      edited[ctName] ?? _fileText(archive.findFile(ctName)!),
    );
    final defaults = {
      for (final e in ct.rootElement.childElements)
        if (e.name.local == 'Default')
          (e.getAttribute('Extension') ?? '').toLowerCase(),
    };
    for (final ext in {
      for (final list in filler.images.values)
        for (final i in list) i.extension,
    }) {
      if (defaults.contains(ext)) continue;
      ct.rootElement.children.insert(
        0,
        XmlElement(const XmlName.qualified('Default'), [
          XmlAttribute(const XmlName.qualified('Extension'), ext),
          XmlAttribute(
            const XmlName.qualified('ContentType'),
            ext == 'png' ? 'image/png' : 'image/jpeg',
          ),
        ]),
      );
    }
    edited[ctName] = ct.toXmlString();
  }

  final written = <String>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    written.add(f.name);
    final text = edited[f.name];
    out.addFile(
      text == null
          ? ArchiveFile.bytes(f.name, f.content)
          : ArchiveFile.bytes(f.name, utf8.encode(text)),
    );
  }
  for (final e in edited.entries) {
    if (!written.contains(e.key)) {
      out.addFile(ArchiveFile.bytes(e.key, utf8.encode(e.value)));
    }
  }
  for (final list in filler.images.values) {
    for (final i in list) {
      out.addFile(ArchiveFile.bytes('word/media/${i.fileName}', i.image.bytes));
    }
  }
  return ZipEncoder().encodeBytes(out);
}

class _PlacedImage {
  _PlacedImage(this.relId, this.fileName, this.extension, this.image);
  final String relId;
  final String fileName;
  final String extension;
  final DocxImage image;
}

const String _imgMarkStart = '\u0001IMG';
const String _imgMarkEnd = '\u0002';

class _Filler {
  _Filler(this.data);

  final DocxTemplateData data;
  String part = 'word/document.xml';
  final Map<String, List<_PlacedImage>> images = {};
  final List<DocxImage> _pending = [];
  int _counter = 0;

  /// Collection prefix of the first item placeholder in [text], or null.
  String? _collectionIn(String text) {
    for (final name in placeholdersIn(text)) {
      final dot = name.indexOf('.');
      if (dot > 0 && data.collections.containsKey(name.substring(0, dot))) {
        return name.substring(0, dot);
      }
    }
    return null;
  }

  void fill(XmlDocument doc) {
    // 1. Table rows with item placeholders are repeated per item.
    final rows = [
      for (final e in doc.descendants.whereType<XmlElement>())
        if (_isW(e, 'tr')) e,
    ];
    final filledRows = <XmlElement>{};
    for (final row in rows) {
      if (row.parent == null) continue;
      final text = _innermostParagraphs(row).map(_paragraphText).join('\n');
      final prefix = _collectionIn(text);
      if (prefix == null) continue;
      final items = data.collections[prefix]!;
      final parent = row.parent!;
      final index = parent.children.indexOf(row);
      final clones = <XmlElement>[];
      for (final item in items) {
        final clone = row.copy();
        for (final p in _innermostParagraphs(clone)) {
          _replaceInline(p, (n) => _itemLookup(prefix, item, n));
        }
        clones.add(clone);
      }
      parent.children.removeAt(index);
      parent.children.insertAll(index, clones);
      filledRows.addAll(clones);
    }

    // 2. Paragraph-level expansion (item paragraphs and blocks).
    for (final p in _innermostParagraphs(doc)) {
      if (p.parent == null) continue;
      final row = _ancestor(p, 'tr');
      if (row != null && filledRows.contains(row)) continue;
      final text = _paragraphText(p);
      final prefix = _collectionIn(text);
      if (prefix != null) {
        final items = data.collections[prefix]!;
        _expand(p, [
          for (final item in items)
            (XmlElement clone) =>
                _replaceInline(clone, (n) => _itemLookup(prefix, item, n)),
        ]);
        continue;
      }
      final only = _placeholder.firstMatch(text.trim());
      if (only != null &&
          only.start == 0 &&
          only.end == text.trim().length &&
          data.blocks.containsKey(only.group(1))) {
        final entries = data.blocks[only.group(1)]!;
        _expand(p, [
          for (final entry in entries)
            (XmlElement clone) => _replaceInline(
              clone,
              (n) => n == only.group(1) ? entry : _Unknown.instance,
            ),
        ]);
      }
    }

    // 3. Inline replacement everywhere else.
    for (final p in _innermostParagraphs(doc)) {
      final row = _ancestor(p, 'tr');
      if (row != null && filledRows.contains(row)) continue;
      _replaceInline(p, _lookup);
    }
  }

  /// Replaces [p] by one clone per filler (none → the paragraph is removed).
  void _expand(XmlElement p, List<void Function(XmlElement)> fillers) {
    final parent = p.parent!;
    final index = parent.children.indexOf(p);
    final clones = <XmlElement>[];
    for (final f in fillers) {
      final c = p.copy();
      f(c);
      clones.add(c);
    }
    parent.children.removeAt(index);
    if (clones.isEmpty && _isW(parent, 'tc')) {
      // A table cell must keep at least one paragraph.
      if (!parent.children.any((c) => _isW(c, 'p'))) {
        final empty = p.copy();
        for (final t in _texts(empty)) {
          t.innerText = '';
        }
        clones.add(empty);
      }
    }
    parent.children.insertAll(index, clones);
  }

  Object? _lookup(String name) {
    if (data.values.containsKey(name)) return data.values[name];
    if (data.blocks.containsKey(name)) return data.blocks[name]!.join('\n');
    final dot = name.indexOf('.');
    if (dot > 0 && data.collections.containsKey(name.substring(0, dot))) {
      return null; // item field outside an item row: empty
    }
    return _Unknown.instance;
  }

  Object? _itemLookup(String prefix, Map<String, Object?> item, String name) {
    if (name.startsWith('$prefix.')) {
      final field = name.substring(prefix.length + 1);
      return item.containsKey(field) ? item[field] : _Unknown.instance;
    }
    return _lookup(name);
  }

  void _replaceInline(XmlElement p, Object? Function(String) lookup) {
    final texts = _texts(p);
    if (texts.isEmpty) return;
    final contents = [for (final t in texts) t.innerText];
    final full = contents.join();
    final matches = _placeholder.allMatches(full).toList();
    if (matches.isEmpty) return;
    // Start offset and length of every node in the original text.
    final starts = <int>[];
    final lens = <int>[];
    var pos = 0;
    for (final c in contents) {
      starts.add(pos);
      lens.add(c.length);
      pos += c.length;
    }
    int nodeAt(int offset) {
      for (var i = 0; i < lens.length; i++) {
        if (offset >= starts[i] && offset < starts[i] + lens[i]) return i;
      }
      return lens.length - 1;
    }

    var changed = false;
    for (final m in matches.reversed) {
      final value = lookup(m.group(1)!);
      if (value is _Unknown) continue;
      final String replacement;
      if (value is DocxImage) {
        _pending.add(value);
        replacement = '$_imgMarkStart${_pending.length - 1}$_imgMarkEnd';
      } else {
        replacement = value?.toString() ?? '';
      }
      final a = nodeAt(m.start);
      final b = nodeAt(m.end - 1);
      final aOff = m.start - starts[a];
      final bOff = m.end - starts[b];
      if (a == b) {
        contents[a] =
            contents[a].substring(0, aOff) +
            replacement +
            contents[a].substring(bOff);
      } else {
        contents[a] = contents[a].substring(0, aOff) + replacement;
        for (var k = a + 1; k < b; k++) {
          contents[k] = '';
        }
        contents[b] = contents[b].substring(bOff);
      }
      changed = true;
    }
    if (!changed) return;
    for (var i = 0; i < texts.length; i++) {
      _writeText(texts[i], contents[i]);
    }
  }

  /// Writes [text] into [t], splitting it at line breaks (`<w:br/>`) and
  /// image markers (`<w:drawing>`).
  void _writeText(XmlElement t, String text) {
    if (!text.contains('\n') && !text.contains(_imgMarkStart)) {
      t.innerText = text;
      _preserve(t);
      return;
    }
    final parent = t.parent!;
    final index = parent.children.indexOf(t);
    final nodes = <XmlNode>[];
    final pieces = RegExp('\n|$_imgMarkStart(\\d+)$_imgMarkEnd');
    var last = 0;
    void addText(String s) {
      if (s.isEmpty) return;
      final e = XmlElement(XmlName.qualified(t.name.qualified), [], [
        XmlText(s),
      ]);
      _preserve(e);
      nodes.add(e);
    }

    for (final m in pieces.allMatches(text)) {
      addText(text.substring(last, m.start));
      if (m.group(0) == '\n') {
        nodes.add(
          XmlElement(
            XmlName.qualified(
              t.name.prefix == null ? 'br' : '${t.name.prefix}:br',
            ),
          ),
        );
      } else {
        nodes.add(_drawing(_pending[int.parse(m.group(1)!)]));
      }
      last = m.end;
    }
    addText(text.substring(last));
    parent.children.removeAt(index);
    parent.children.insertAll(index, nodes);
  }

  static void _preserve(XmlElement t) {
    t.setAttribute('xml:space', 'preserve');
  }

  XmlElement _drawing(DocxImage image) {
    _counter++;
    final ext = image.extension == 'png' ? 'png' : 'jpeg';
    final placed = _PlacedImage(
      'rIdInsato$_counter',
      'insato_${part.replaceAll(RegExp(r'[^a-z0-9]'), '_')}_$_counter.$ext',
      ext,
      image,
    );
    images.putIfAbsent(part, () => []).add(placed);
    final (cx, cy) = image.extentEmu;
    final id = 9000 + _counter;
    final xml =
        '<w:drawing xmlns:w="$_nsW" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/'
        'wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/'
        'relationships">'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/>'
        '<wp:docPr id="$id" name="Insato $id"/>'
        '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/>'
        '</wp:cNvGraphicFramePr>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/'
        'drawingml/2006/picture"><pic:pic>'
        '<pic:nvPicPr><pic:cNvPr id="$id" name="${placed.fileName}"/>'
        '<pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="${placed.relId}"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/>'
        '</a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>';
    return XmlDocumentFragment.parse(xml).firstElementChild!.copy();
  }
}

/// Marker for "unknown placeholder: leave it as is".
class _Unknown {
  const _Unknown();
  static const _Unknown instance = _Unknown();
}
