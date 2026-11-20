import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:insato/features/official/docx_template.dart';
import 'package:insato/features/official/template_placeholders.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

/// A minimal .docx whose body is [body] (inner XML of w:body).
Uint8List docxWith(String body, {String? header}) {
  final a = Archive()
    ..addFile(
      ArchiveFile.bytes(
        '[Content_Types].xml',
        utf8.encode(
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="xml" ContentType="application/xml"/></Types>',
        ),
      ),
    )
    ..addFile(
      ArchiveFile.bytes(
        'word/document.xml',
        utf8.encode(
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<w:document xmlns:w="$_w"><w:body>$body</w:body></w:document>',
        ),
      ),
    );
  if (header != null) {
    a.addFile(
      ArchiveFile.bytes(
        'word/header1.xml',
        utf8.encode('<w:hdr xmlns:w="$_w">$header</w:hdr>'),
      ),
    );
  }
  return ZipEncoder().encodeBytes(a);
}

String part(Uint8List docx, String name) =>
    utf8.decode(ZipDecoder().decodeBytes(docx).findFile(name)!.content);

String run(String text, {bool bold = false}) =>
    '<w:r><w:rPr>${bold ? '<w:b/>' : ''}<w:rtl/></w:rPr>'
    '<w:t xml:space="preserve">$text</w:t></w:r>';

String para(String runs) => '<w:p><w:pPr><w:bidi/></w:pPr>$runs</w:p>';

Uint8List png(int w, int h) => img.encodePng(img.Image(width: w, height: h));

void main() {
  group('fillDocxTemplate', () {
    test('replaces placeholders split across runs, keeping formatting', () {
      final t = docxWith(
        para(
          run('الجهة: {{entity', bold: true) +
              run('_na') +
              run('me}} — ') +
              run('{{unknown_field}} {{place}}'),
        ),
      );
      final out = fillDocxTemplate(
        t,
        const DocxTemplateData(
          values: {'entity_name': 'شركة المثال', 'place': null},
        ),
      );
      final xml = part(out, 'word/document.xml');
      expect(xml, contains('شركة المثال'));
      expect(xml, isNot(contains('entity')));
      expect(xml, contains('{{unknown_field}}'));
      expect(xml, isNot(contains('{{place}}')));
      // The value went into the first (bold) run.
      expect(
        RegExp(
          r'<w:b/><w:rtl/></w:rPr><w:t xml:space="preserve">الجهة: شركة المثال</w:t>',
        ).hasMatch(xml),
        isTrue,
      );
    });

    test('expands a block placeholder into paragraphs and breaks lines', () {
      final t = docxWith(
        para(run('{{resolutions}}')) + para(run('{{summary}}')),
      );
      final out = fillDocxTemplate(
        t,
        const DocxTemplateData(
          blocks: {
            'resolutions': ['أولاً: قرار', 'ثانياً: قرار آخر'],
            'summary': ['سطر\nثانٍ'],
          },
        ),
      );
      final xml = part(out, 'word/document.xml');
      expect('<w:p>'.allMatches(xml).length, 3);
      expect(xml, contains('أولاً: قرار'));
      expect(xml, contains('ثانياً: قرار آخر'));
      expect(xml, contains('<w:br/>'));
    });

    test('an empty block removes its paragraph', () {
      final t = docxWith(para(run('{{guests}}')) + para(run('باقٍ')));
      final out = fillDocxTemplate(
        t,
        const DocxTemplateData(blocks: {'guests': []}),
      );
      final xml = part(out, 'word/document.xml');
      expect('<w:p>'.allMatches(xml).length, 1);
      expect(xml, contains('باقٍ'));
    });

    test('repeats table rows per item and inserts images', () {
      String cell(String text) => '<w:tc>${para(run(text))}</w:tc>';
      final t = docxWith(
        '<w:tbl><w:tr>${cell('الاسم')}${cell('التوقيع')}</w:tr>'
        '<w:tr>${cell('{{signature.name}}')}${cell('{{signature.image}}')}</w:tr>'
        '</w:tbl>${para(run('{{logo}}'))}',
        header: para(run('{{entity_name}}')),
      );
      final sig = DocxImage(
        bytes: png(30, 10),
        extension: 'png',
        widthPx: 30,
        heightPx: 10,
      );
      final out = fillDocxTemplate(
        t,
        DocxTemplateData(
          values: {'logo': sig, 'entity_name': 'الجهة'},
          collections: {
            'signature': [
              {'name': 'أحمد', 'image': sig},
              {'name': 'سارة', 'image': null},
            ],
          },
        ),
      );
      final xml = part(out, 'word/document.xml');
      expect('<w:tr>'.allMatches(xml).length, 3);
      expect(xml, contains('أحمد'));
      expect(xml, contains('سارة'));
      expect('<w:drawing'.allMatches(xml).length, 2);
      final rels = part(out, 'word/_rels/document.xml.rels');
      expect('Relationship '.allMatches(rels).length, 2);
      expect(part(out, '[Content_Types].xml'), contains('Extension="png"'));
      expect(part(out, 'word/header1.xml'), contains('الجهة'));
      final names = ZipDecoder().decodeBytes(out).files.map((f) => f.name);
      expect(names.where((n) => n.startsWith('word/media/')), hasLength(2));
    });
  });

  group('inspectDocxTemplate', () {
    test('lists placeholders and rejects bad files', () {
      final t = docxWith(para(run('{{meeting_') + run('title}} {{x.y}}')));
      expect(inspectDocxTemplate(t), ['meeting_title', 'x.y']);
      expect(
        () => inspectDocxTemplate(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<DocxTemplateException>()),
      );
      expect(
        () => inspectDocxTemplate(
          Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0, 0]),
        ),
        throwsA(
          predicate(
            (e) => e is DocxTemplateException && e.messageAr.contains('.doc'),
          ),
        ),
      );
      expect(
        () => inspectDocxTemplate(
          docxWith(para(run('بلا حقول'))),
          known: knownPlaceholderNames,
        ),
        throwsA(isA<DocxTemplateException>()),
      );
      expect(
        () => inspectDocxTemplate(Uint8List(kMaxTemplateBytes + 1)),
        throwsA(isA<DocxTemplateException>()),
      );
    });

    test('the sample template contains every placeholder and fills', () {
      final sample = buildSampleTemplate(created: DateTime(2026));
      final found = inspectDocxTemplate(sample, known: knownPlaceholderNames);
      for (final p in kTemplatePlaceholders) {
        expect(found, contains(p.name), reason: p.name);
      }
    });
  });
}
