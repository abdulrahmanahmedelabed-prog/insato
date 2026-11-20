// The body of official minutes as a format-neutral outline (v1.2): the
// template's sections in order, as headings, paragraphs, lists, tables,
// numbered resolutions and the signature block. PDF, Word, Markdown and
// share text render this outline, so every format has the same content.
//
// Pure Dart, unit-tested.

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../minutes/export_service.dart' show agendaStatusText;
import 'official_document.dart';
import 'official_templates.dart';
import 'template_placeholders.dart' show voteLinesOf;

/// A block of the outline.
sealed class OutlineBlock {
  const OutlineBlock();
}

/// A section heading.
class OutlineHeading extends OutlineBlock {
  /// Creates a heading.
  const OutlineHeading(this.text);

  /// Text.
  final String text;
}

/// A paragraph.
class OutlineParagraph extends OutlineBlock {
  /// Creates a paragraph; [muted] for small notes.
  const OutlineParagraph(this.text, {this.muted = false, this.bold = false});

  /// Text (may contain line breaks).
  final String text;

  /// Small, muted text.
  final bool muted;

  /// Emphasised (e.g. the quorum statement).
  final bool bold;
}

/// `label: value` rows.
class OutlineLabelValues extends OutlineBlock {
  /// Creates rows.
  const OutlineLabelValues(this.rows);

  /// Rows.
  final List<(String, String)> rows;
}

/// A bulleted or numbered list.
class OutlineList extends OutlineBlock {
  /// Creates a list.
  const OutlineList(this.items, {this.numbered = false});

  /// Items.
  final List<String> items;

  /// Numbered.
  final bool numbered;
}

/// A table.
class OutlineTable extends OutlineBlock {
  /// Creates a table. Column 0 is the first (right-most in RTL).
  const OutlineTable(this.header, this.rows, {this.flex = const []});

  /// Header cells.
  final List<String> header;

  /// Rows.
  final List<List<String>> rows;

  /// Relative column widths (empty = equal).
  final List<int> flex;
}

/// A numbered resolution with its vote lines.
class OutlineResolution extends OutlineBlock {
  /// Creates a resolution block.
  const OutlineResolution(this.resolution);

  /// The resolution.
  final OfficialResolution resolution;

  /// Number label.
  String get label => resolution.label;

  /// Formal text.
  String get text => resolution.text;

  /// Vote result and names per position.
  List<String> get voteLines => voteLinesOf(resolution);
}

/// The signature block.
class OutlineSignatures extends OutlineBlock {
  /// Creates the block.
  const OutlineSignatures(this.signatories);

  /// Signatories.
  final List<OfficialSignatory> signatories;
}

List<String> _paragraphs(String text) => [
  for (final p in text.trim().split(RegExp(r'\n\s*\n')))
    if (p.trim().isNotEmpty) p.trim(),
];

String _agendaLine(MinutesAgendaItem a) {
  final note = _one(a.note ?? '');
  return '${_one(a.item)} — ${agendaStatusText(a.status)}'
      '${note.isEmpty ? '' : ': $note'}';
}

String _one(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

/// The outline of [doc] / [minutes] following the template's sections.
/// The header (title, entity, logo, info rows) is rendered by each format
/// from [OfficialDocument] directly and is not part of the outline, except
/// the opening sentence.
List<OutlineBlock> officialOutline(OfficialDocument doc, Minutes minutes) {
  final out = <OutlineBlock>[];
  for (final section in doc.template.sections) {
    switch (section) {
      case OfficialSection.header:
        out.add(OutlineParagraph(doc.opening));
      case OfficialSection.attendance:
        out.add(const OutlineHeading('الحضور والغياب'));
        final groups = doc.attendanceGroups;
        if (groups.isEmpty) {
          out.add(
            const OutlineParagraph('لم يُعدّ كشف الحضور بعد.', muted: true),
          );
        } else {
          out.add(
            OutlineLabelValues([
              for (final (label, names) in groups) (label, names.join('، ')),
            ]),
          );
        }
      case OfficialSection.quorum:
        out
          ..add(const OutlineHeading('النصاب'))
          ..add(OutlineParagraph(doc.quorum.statementAr, bold: true));
      case OfficialSection.agenda:
        if (minutes.agendaCoverage.isEmpty) continue;
        out
          ..add(const OutlineHeading('جدول الأعمال'))
          ..add(
            OutlineList([
              for (final a in minutes.agendaCoverage) _agendaLine(a),
            ], numbered: true),
          );
      case OfficialSection.summary:
        out.add(const OutlineHeading('الملخص'));
        final ps = _paragraphs(minutes.summary);
        if (ps.isEmpty) {
          out.add(const OutlineParagraph('لا يوجد ملخص.', muted: true));
        } else {
          out.addAll(ps.map(OutlineParagraph.new));
        }
      case OfficialSection.discussion:
        if (minutes.topics.isEmpty) continue;
        out.add(const OutlineHeading('المداولات'));
        for (var i = 0; i < minutes.topics.length; i++) {
          final t = minutes.topics[i];
          out.add(OutlineParagraph('${i + 1}. ${_one(t.title)}', bold: true));
          out.addAll(_paragraphs(t.discussion).map(OutlineParagraph.new));
        }
      case OfficialSection.resolutions:
        out.add(OutlineHeading(doc.template.resolutionsHeading));
        if (doc.resolutions.isEmpty) {
          out.add(
            OutlineParagraph(
              'لم تُتخذ ${doc.template.resolutionsHeading == 'التوصيات' ? 'توصيات' : 'قرارات'}.',
              muted: true,
            ),
          );
        } else {
          out.addAll(doc.resolutions.map(OutlineResolution.new));
        }
      case OfficialSection.actionItems:
        if (minutes.actionItems.isEmpty) continue;
        out
          ..add(const OutlineHeading('المهام'))
          ..add(
            OutlineTable(
              const ['#', 'المهمة', 'المسؤول', 'الموعد'],
              [
                for (var i = 0; i < minutes.actionItems.length; i++)
                  [
                    '${i + 1}',
                    _one(minutes.actionItems[i].task),
                    minutes.actionItems[i].owner ?? '—',
                    minutes.actionItems[i].dueDate ?? '—',
                  ],
              ],
              flex: const [1, 6, 3, 3],
            ),
          );
      case OfficialSection.openQuestions:
        if (minutes.openQuestions.isEmpty) continue;
        out
          ..add(const OutlineHeading('مسائل معلقة'))
          ..add(OutlineList(minutes.openQuestions.map(_one).toList()));
      case OfficialSection.nextMeeting:
        final next = minutes.nextMeeting?.trim() ?? '';
        if (next.isEmpty) continue;
        out
          ..add(const OutlineHeading('الاجتماع القادم'))
          ..add(OutlineParagraph(next));
      case OfficialSection.notes:
        final notes = _paragraphs(minutes.notes ?? '');
        if (notes.isEmpty) continue;
        out.add(const OutlineHeading('ملاحظات'));
        out.addAll(notes.map((n) => OutlineParagraph(n, muted: true)));
      case OfficialSection.signatures:
        out
          ..add(const OutlineHeading('التواقيع'))
          ..add(OutlineSignatures(doc.signatories));
    }
  }
  final endTime = doc.endTime.isEmpty
      ? null
      : 'وانتهى الاجتماع في تمام الساعة ${doc.endTime}.';
  if (endTime != null) {
    final sigIndex = out.indexWhere((b) => b is OutlineSignatures);
    final at = sigIndex > 0 ? sigIndex - 1 : out.length;
    out.insert(at, OutlineParagraph(endTime));
  }
  return out;
}

/// Footer lines of official minutes: status, approval, hash.
List<String> officialFooterLines(OfficialDocument doc) => [
  doc.statusLine,
  ?doc.approvalLine,
  ?doc.hashLine,
];

/// One-line signature state: «موقَّع إلكترونياً بتاريخ …» or a dotted line.
String signatureStateText(OfficialSignatory s) => s.signature == null
    ? '....................'
    : 'موقَّع إلكترونياً بتاريخ ${formatArabicDateTime(s.signature!.signedAt)}';
