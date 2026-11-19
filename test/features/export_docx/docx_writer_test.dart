import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/export_docx/docx_writer.dart';

import 'xml_check.dart';

void main() {
  group('xmlEscape / stripInvalidXmlChars', () {
    test('escapes the five XML special characters', () {
      expect(
        xmlEscape(r'''<a href="x">Tom & 'Jerry'</a>'''),
        '&lt;a href=&quot;x&quot;&gt;Tom &amp; &apos;Jerry&apos;&lt;/a&gt;',
      );
    });

    test('removes control characters, lone surrogates and U+FFFE/FFFF', () {
      final dirty =
          'a\u0000b\u0001c\u0008d\u000Be\u000Cf\u001Fg'
          '\uD800h\uDC00i￾j￿k';
      expect(stripInvalidXmlChars(dirty), 'abcdefghijk');
      expect(xmlEscape(dirty), 'abcdefghijk');
    });

    test('keeps tab, newline, carriage return, Arabic and emoji', () {
      const ok = 'سطر\tأول\nثانٍ\r😀 ﷺ';
      expect(stripInvalidXmlChars(ok), ok);
      expect(identical(stripInvalidXmlChars(ok), ok), isTrue);
    });
  });

  group('splitByDirection', () {
    test('Arabic only is one RTL piece', () {
      final p = splitByDirection('اجتماع الميزانية 2026.');
      expect(p, hasLength(1));
      expect(p.single.rtl, isTrue);
    });

    test('Latin words inside Arabic become LTR pieces', () {
      final p = splitByDirection('نشر Kubernetes cluster على الخادم (OPEX).');
      expect(p.map((e) => e.toString()).toList(), [
        'R«نشر »',
        'L«Kubernetes cluster»',
        'R« على الخادم (»',
        'L«OPEX»',
        'R«).»',
      ]);
      expect(
        p.map((e) => e.text).join(),
        'نشر Kubernetes cluster على الخادم (OPEX).',
      );
    });

    test('digits after Latin text stay in the LTR piece', () {
      final p = splitByDirection('باستخدام claude-opus-5-5 بتاريخ 2026');
      expect(p.map((e) => e.toString()).toList(), [
        'R«باستخدام »',
        'L«claude-opus-5-5»',
        'R« بتاريخ 2026»',
      ]);
    });

    test('empty text has no pieces', () {
      expect(splitByDirection(''), isEmpty);
    });
  });

  group('DocxBuilder', () {
    DocxBuilder sample() {
      final d = DocxBuilder(footerText: 'تذييل')
        ..subtitle('محضر اجتماع')
        ..title('عنوان <تجريبي> & "مقتبس"')
        ..heading('قسم')
        ..paragraph('فقرة\nبسطرين\tوتبويب')
        ..bullets(['أ', 'ب'])
        ..numbered(['١', '٢'])
        ..numbered(['واحد'])
        ..table(
          DocxTable(
            header: const ['أ', 'ب'],
            rows: const [
              ['1', '2'],
              ['3', '4'],
            ],
            columnWidths: const [1000, 2000],
          ),
        )
        ..pageBreak()
        ..note('ملاحظة');
      return d;
    }

    final meta = DocxMetadata(
      title: 'عنوان & <اختبار>',
      created: DateTime.utc(2026, 11, 19, 9, 5, 7),
      creator: 'إنصاتو',
      application: 'إنصاتو',
    );

    test('zip holds every required part, all well-formed', () {
      final parts = unzipParts(sample().build(meta));
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
        expect(parts.containsKey(name), isTrue, reason: name);
      }
      expect(parts.keys.toSet(), DocxBuilder.partNames.toSet());
      for (final e in parts.entries) {
        expect(() => checkWellFormed(e.value), returnsNormally, reason: e.key);
      }
      expect(checkWellFormed(parts['word/document.xml']!), 'w:document');
      expect(checkWellFormed(parts['[Content_Types].xml']!), 'Types');
    });

    test('content types and relationships reference every part', () {
      final parts = unzipParts(sample().build(meta));
      final types = parts['[Content_Types].xml']!;
      for (final part in DocxBuilder.partNames.where(
        (n) => n.endsWith('.xml') && n != '[Content_Types].xml',
      )) {
        expect(types, contains('PartName="/$part"'), reason: part);
      }
      final rels = parts['word/_rels/document.xml.rels']!;
      for (final t in [
        'styles',
        'numbering',
        'settings',
        'fontTable',
        'footer',
      ]) {
        expect(rels, contains('relationships/$t"'), reason: t);
      }
      expect(parts['_rels/.rels'], contains('Target="word/document.xml"'));
    });

    test('RTL section, paragraphs and runs; Arabic font with fallback', () {
      final parts = unzipParts(sample().build(meta));
      final doc = parts['word/document.xml']!;
      expect(doc, contains('<w:bidi/></w:sectPr>'));
      final paragraphs = RegExp(r'<w:p>').allMatches(doc).length;
      final bidi = RegExp(
        r'<w:pPr>(?:(?!</w:pPr>).)*<w:bidi/>',
        dotAll: true,
      ).allMatches(doc).length;
      expect(bidi, paragraphs, reason: 'every paragraph is RTL');
      expect(doc, contains('<w:rtl/>'));
      expect(doc, contains('<w:bidiVisual/>'));
      final styles = parts['word/styles.xml']!;
      expect(styles, contains('w:cs="Noto Naskh Arabic"'));
      expect(styles, contains('w:bidi="ar-SA"'));
      final fonts = parts['word/fontTable.xml']!;
      expect(
        fonts,
        contains(
          '<w:font w:name="Noto Naskh Arabic"><w:altName w:val="Arial"/>',
        ),
      );
    });

    test('escapes text and metadata, keeps breaks and tabs', () {
      final parts = unzipParts(sample().build(meta));
      final doc = parts['word/document.xml']!;
      expect(doc, contains('&lt;تجريبي&gt; &amp; &quot;مقتبس&quot;'));
      expect(plainText(doc), contains('عنوان <تجريبي> & "مقتبس"'));
      expect(
        doc,
        contains('فقرة</w:t><w:br/><w:t xml:space="preserve">بسطرين'),
      );
      expect(doc, contains('<w:tab/>'));
      expect(doc, contains('<w:br w:type="page"/>'));
      final core = parts['docProps/core.xml']!;
      expect(core, contains('<dc:title>عنوان &amp; &lt;اختبار&gt;</dc:title>'));
      expect(core, contains('2026-11-19T09:05:07Z'));
    });

    test('bullets share one list; each numbered list restarts', () {
      final parts = unzipParts(sample().build(meta));
      final numbering = parts['word/numbering.xml']!;
      expect(numbering, contains('w:numFmt w:val="bullet"'));
      expect(numbering, contains('w:numFmt w:val="decimal"'));
      expect('<w:num '.allMatches(numbering).length, 3);
      expect('<w:startOverride w:val="1"/>'.allMatches(numbering).length, 2);
      final doc = parts['word/document.xml']!;
      expect('<w:numId w:val="1"/>'.allMatches(doc).length, 2);
      expect('<w:numId w:val="2"/>'.allMatches(doc).length, 2);
      expect('<w:numId w:val="3"/>'.allMatches(doc).length, 1);
    });

    test('table has a repeated header row and one row per entry', () {
      final doc = unzipParts(sample().build(meta))['word/document.xml']!;
      final tables = tablesOf(doc);
      expect(tables, hasLength(1));
      expect(rowCount(tables.single), 3);
      expect('<w:tblHeader/>'.allMatches(tables.single).length, 1);
      expect('<w:gridCol '.allMatches(tables.single).length, 2);
    });

    test('footer has page fields', () {
      final footer = unzipParts(sample().build(meta))['word/footer1.xml']!;
      expect(footer, contains('w:instr=" PAGE "'));
      expect(footer, contains('w:instr=" NUMPAGES "'));
      expect(plainText(footer), contains('تذييل — صفحة'));
    });
  });
}
