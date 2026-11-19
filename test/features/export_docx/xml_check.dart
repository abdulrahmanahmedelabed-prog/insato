// A strict, minimal XML 1.0 well-formedness checker for the tests (package
// xml is not a direct dependency): one root element, balanced and properly
// nested tags, quoted and unique attributes, declared namespace prefixes,
// only the predefined / numeric entities, no raw `<` or `&` in text and no
// characters XML forbids.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:insato/features/export_docx/docx_writer.dart';

/// Thrown for malformed XML.
class XmlCheckError implements Exception {
  XmlCheckError(this.message, this.offset);

  final String message;
  final int offset;

  @override
  String toString() => 'XmlCheckError at $offset: $message';
}

final RegExp _name = RegExp(
  r'^[A-Za-z_][A-Za-z0-9_.\-]*(:[A-Za-z_][A-Za-z0-9_.\-]*)?$',
);
final RegExp _attr = RegExp(r'''\s+([^\s=/>]+)\s*=\s*("[^"<]*"|'[^'<]*')''');
final RegExp _entity = RegExp(
  r'&(amp|lt|gt|quot|apos|#[0-9]+|#x[0-9A-Fa-f]+);',
);

void _checkText(String text, int offset) {
  for (final r in text.runes) {
    if (!isValidXmlChar(r)) {
      throw XmlCheckError('invalid character U+${r.toRadixString(16)}', offset);
    }
  }
  if (text.contains('<')) throw XmlCheckError('raw < in text', offset);
  if (text.replaceAll(_entity, '').contains('&')) {
    throw XmlCheckError('bad entity in "$text"', offset);
  }
}

/// Checks [xml]; returns the root element's qualified name.
String checkWellFormed(String xml) {
  var i = 0;
  if (xml.startsWith('<?xml')) {
    final end = xml.indexOf('?>');
    if (end < 0) throw XmlCheckError('unterminated declaration', 0);
    i = end + 2;
  }
  final stack = <String>[];
  final nsStack = <Set<String>>[
    {'xml'},
  ];
  String? root;
  var rootClosed = false;
  while (i < xml.length) {
    final lt = xml.indexOf('<', i);
    final text = xml.substring(i, lt < 0 ? xml.length : lt);
    if (stack.isEmpty && text.trim().isNotEmpty) {
      throw XmlCheckError('text outside the root', i);
    }
    _checkText(text, i);
    if (lt < 0) break;
    if (xml.startsWith('<!--', lt)) {
      final end = xml.indexOf('-->', lt);
      if (end < 0) throw XmlCheckError('unterminated comment', lt);
      i = end + 3;
      continue;
    }
    final gt = xml.indexOf('>', lt);
    if (gt < 0) throw XmlCheckError('unterminated tag', lt);
    final tag = xml.substring(lt + 1, gt);
    if (tag.startsWith('/')) {
      final name = tag.substring(1).trim();
      if (stack.isEmpty || stack.last != name) {
        throw XmlCheckError(
          'closing </$name> does not match <${stack.isEmpty ? '' : stack.last}>',
          lt,
        );
      }
      stack.removeLast();
      nsStack.removeLast();
      if (stack.isEmpty) rootClosed = true;
      i = gt + 1;
      continue;
    }
    if (tag.startsWith('?') || tag.startsWith('!')) {
      throw XmlCheckError('unexpected markup <$tag>', lt);
    }
    final selfClosing = tag.endsWith('/');
    final body = selfClosing ? tag.substring(0, tag.length - 1) : tag;
    final nameEnd = body.indexOf(RegExp(r'\s'));
    final name = nameEnd < 0 ? body : body.substring(0, nameEnd);
    if (!_name.hasMatch(name)) throw XmlCheckError('bad name "$name"', lt);
    final rest = nameEnd < 0 ? '' : body.substring(nameEnd);
    final attrs = <String>{};
    final declared = {...nsStack.last};
    var consumed = 0;
    for (final m in _attr.allMatches(rest)) {
      if (m.start != consumed) {
        throw XmlCheckError('garbage in attributes of <$name>', lt);
      }
      consumed = m.end;
      final an = m.group(1)!;
      if (!_name.hasMatch(an)) throw XmlCheckError('bad attribute $an', lt);
      if (!attrs.add(an)) throw XmlCheckError('duplicate attribute $an', lt);
      final value = m.group(2)!;
      _checkText(value.substring(1, value.length - 1), lt);
      if (an.startsWith('xmlns:')) declared.add(an.substring(6));
    }
    if (rest.substring(consumed).trim().isNotEmpty) {
      throw XmlCheckError('garbage in attributes of <$name>', lt);
    }
    for (final qn in [name, ...attrs.where((a) => !a.startsWith('xmlns'))]) {
      final colon = qn.indexOf(':');
      if (colon > 0 && !declared.contains(qn.substring(0, colon))) {
        throw XmlCheckError('undeclared prefix in $qn', lt);
      }
    }
    if (stack.isEmpty) {
      if (rootClosed || root != null) {
        throw XmlCheckError('second root element', lt);
      }
      root = name;
    }
    if (!selfClosing) {
      stack.add(name);
      nsStack.add(declared);
    } else if (stack.isEmpty) {
      rootClosed = true;
    }
    i = gt + 1;
  }
  if (stack.isNotEmpty) throw XmlCheckError('unclosed <${stack.last}>', i);
  if (root == null) throw XmlCheckError('no root element', 0);
  return root;
}

/// Unzips a .docx into its parts as text.
Map<String, String> unzipParts(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return {
    for (final f in archive.files)
      if (f.isFile) f.name: utf8.decode(f.readBytes()!),
  };
}

/// The `<w:tbl>…</w:tbl>` elements of a document.xml (no nested tables).
List<String> tablesOf(String documentXml) => RegExp(
  r'<w:tbl>.*?</w:tbl>',
  dotAll: true,
).allMatches(documentXml).map((m) => m.group(0)!).toList();

/// Number of rows of a table.
int rowCount(String tableXml) => '<w:tr>'.allMatches(tableXml).length;

/// The concatenated `w:t` text of [xml], with entities decoded.
String plainText(String xml) =>
    RegExp(r'<w:t(?: [^>]*)?>([^<]*)</w:t>')
        .allMatches(xml)
        .map((m) => m.group(1)!)
        .join()
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
