// The placeholders an uploaded Word template may use (v1.2), their values
// for a meeting, and the downloadable sample template that contains all of
// them.
//
// Unit-tested.

import 'dart:typed_data';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../minutes/export_service.dart' show ExportService, agendaStatusText;
import '../export_docx/docx_writer.dart';
import 'docx_template.dart';
import 'official_document.dart';
import 'official_models.dart';
import 'signature_raster.dart';

/// Kind of a placeholder.
enum PlaceholderKind {
  /// Replaced inline by text.
  text,

  /// Replaced inline by a picture.
  image,

  /// Alone in a paragraph: one paragraph per entry.
  block,

  /// Field of a repeated table row / paragraph.
  item,
}

/// A documented placeholder.
class TemplatePlaceholder {
  /// Creates an entry.
  const TemplatePlaceholder(this.name, this.descriptionAr, this.kind);

  /// Name without braces.
  final String name;

  /// What it becomes (Arabic).
  final String descriptionAr;

  /// Kind.
  final PlaceholderKind kind;

  /// `{{name}}`.
  String get token => '{{$name}}';
}

/// Every supported placeholder.
const List<TemplatePlaceholder> kTemplatePlaceholders = [
  TemplatePlaceholder('entity_name', 'اسم الجهة', PlaceholderKind.text),
  TemplatePlaceholder('logo', 'شعار الجهة (صورة)', PlaceholderKind.image),
  TemplatePlaceholder(
    'document_title',
    'عنوان المحضر الرسمي مع رقم الاجتماع',
    PlaceholderKind.text,
  ),
  TemplatePlaceholder('meeting_title', 'موضوع الاجتماع', PlaceholderKind.text),
  TemplatePlaceholder('template_name', 'نوع الاجتماع', PlaceholderKind.text),
  TemplatePlaceholder('committee', 'المجلس أو اللجنة', PlaceholderKind.text),
  TemplatePlaceholder(
    'meeting_number',
    'رقم الاجتماع (مثل 12/1448هـ)',
    PlaceholderKind.text,
  ),
  TemplatePlaceholder('weekday', 'اليوم', PlaceholderKind.text),
  TemplatePlaceholder(
    'date_hijri',
    'التاريخ الهجري (أم القرى)',
    PlaceholderKind.text,
  ),
  TemplatePlaceholder(
    'date_gregorian',
    'التاريخ الميلادي',
    PlaceholderKind.text,
  ),
  TemplatePlaceholder('time_start', 'وقت البدء', PlaceholderKind.text),
  TemplatePlaceholder('time_end', 'وقت الانتهاء', PlaceholderKind.text),
  TemplatePlaceholder('place', 'المكان', PlaceholderKind.text),
  TemplatePlaceholder('chair', 'رئيس الاجتماع', PlaceholderKind.text),
  TemplatePlaceholder('secretary', 'أمين السر', PlaceholderKind.text),
  TemplatePlaceholder('opening', 'فقرة الافتتاح الرسمية', PlaceholderKind.text),
  TemplatePlaceholder(
    'attendees_present',
    'الحاضرون (فقرة لكل اسم)',
    PlaceholderKind.block,
  ),
  TemplatePlaceholder(
    'attendees_absent',
    'الغائبون بعذر ودون عذر',
    PlaceholderKind.block,
  ),
  TemplatePlaceholder(
    'attendees_absent_excused',
    'الغائبون بعذر',
    PlaceholderKind.block,
  ),
  TemplatePlaceholder(
    'attendees_absent_unexcused',
    'الغائبون دون عذر',
    PlaceholderKind.block,
  ),
  TemplatePlaceholder('guests', 'المدعوون', PlaceholderKind.block),
  TemplatePlaceholder(
    'quorum',
    'عبارة النصاب (اكتمل / لم يكتمل)',
    PlaceholderKind.text,
  ),
  TemplatePlaceholder('agenda', 'جدول الأعمال وتغطيته', PlaceholderKind.block),
  TemplatePlaceholder('summary', 'الملخص التنفيذي', PlaceholderKind.block),
  TemplatePlaceholder('topics', 'محاور النقاش', PlaceholderKind.block),
  TemplatePlaceholder(
    'resolutions',
    'القرارات أو التوصيات مرقّمة بصيغتها الرسمية',
    PlaceholderKind.block,
  ),
  TemplatePlaceholder(
    'votes',
    'نتائج التصويت لكل قرار مع الأسماء',
    PlaceholderKind.block,
  ),
  TemplatePlaceholder('action_items', 'المهام', PlaceholderKind.block),
  TemplatePlaceholder(
    'open_questions',
    'المسائل المعلقة',
    PlaceholderKind.block,
  ),
  TemplatePlaceholder('next_meeting', 'الاجتماع القادم', PlaceholderKind.text),
  TemplatePlaceholder('notes', 'ملاحظات', PlaceholderKind.block),
  TemplatePlaceholder(
    'signatures',
    'التواقيع (الاسم والصفة والتوقيع)',
    PlaceholderKind.block,
  ),
  TemplatePlaceholder('status', 'حالة المحضر والإصدار', PlaceholderKind.text),
  TemplatePlaceholder('version', 'رقم الإصدار', PlaceholderKind.text),
  TemplatePlaceholder(
    'content_hash',
    'رمز التحقق SHA-256 للمحتوى المعتمد',
    PlaceholderKind.text,
  ),
  TemplatePlaceholder('approval_date', 'تاريخ الاعتماد', PlaceholderKind.text),
  TemplatePlaceholder(
    'resolution.number',
    'في صف جدول متكرر: رقم القرار',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'resolution.text',
    'في صف متكرر: نص القرار',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'resolution.vote',
    'في صف متكرر: نتيجة التصويت',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'action_item.number',
    'في صف متكرر: رقم المهمة',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'action_item.task',
    'في صف متكرر: المهمة',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'action_item.owner',
    'في صف متكرر: المسؤول',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'action_item.due',
    'في صف متكرر: الموعد',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'attendee.name',
    'في صف متكرر: اسم من في كشف الحضور',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'attendee.title',
    'في صف متكرر: الصفة',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'attendee.status',
    'في صف متكرر: حاضر / غائب بعذر / …',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'signature.name',
    'في صف متكرر: اسم الموقِّع',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'signature.role',
    'في صف متكرر: صفة الموقِّع',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'signature.image',
    'في صف متكرر: صورة التوقيع',
    PlaceholderKind.item,
  ),
  TemplatePlaceholder(
    'signature.date',
    'في صف متكرر: تاريخ التوقيع',
    PlaceholderKind.item,
  ),
];

/// Names of every scalar / block placeholder and every item prefix (for
/// validating uploads).
Set<String> get knownPlaceholderNames => {
  for (final p in kTemplatePlaceholders) p.name,
  for (final p in kTemplatePlaceholders)
    if (p.kind == PlaceholderKind.item) p.name.split('.').first,
};

/// Image of an encoded PNG / JPEG for a template, or null when it cannot
/// be decoded.
DocxImage? docxImageOf(
  Uint8List bytes, {
  double maxWidthCm = 4,
  double maxHeightCm = 2.5,
}) {
  final size = imageSize(bytes);
  if (size == null) return null;
  final isPng = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
  final isJpeg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  if (!isPng && !isJpeg) return null;
  return DocxImage(
    bytes: bytes,
    extension: isPng ? 'png' : 'jpeg',
    widthPx: size.width,
    heightPx: size.height,
    maxWidthCm: maxWidthCm,
    maxHeightCm: maxHeightCm,
  );
}

String _one(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

String _agendaLine(int i, MinutesAgendaItem a) {
  final note = _one(a.note ?? '');
  final status = agendaStatusText(a.status);
  return '${i + 1}. ${_one(a.item)} — $status${note.isEmpty ? '' : ': $note'}';
}

String _topicLine(int i, MinutesTopic t) =>
    '${i + 1}. ${_one(t.title)}\n${t.discussion.trim()}';

String _actionLine(int i, ActionItem a) {
  final owner = a.owner ?? 'غير محدد';
  final due = a.dueDate ?? 'غير محدد';
  return '${i + 1}. ${_one(a.task)} — المسؤول: $owner — الموعد: $due';
}

const String _blank = '....................';

String _signatureLine(OfficialSignatory s) {
  final name = s.name.isEmpty ? _blank : s.name;
  final sig = s.signature == null
      ? _blank
      : 'موقَّع إلكترونياً بتاريخ ${formatArabicDateTime(s.signature!.signedAt)}';
  return '${s.role}: $name — التوقيع: $sig';
}

/// Vote lines of a resolution (result, then names per position).
List<String> voteLinesOf(OfficialResolution r) => [
  if (r.voteLine != null) r.voteLine!,
  for (final (label, names) in r.namesByPosition) '$label: ${names.join('، ')}',
];

/// The values of every placeholder for [doc] / [minutes].
DocxTemplateData templateDataFor(OfficialDocument doc, Minutes minutes) {
  final logo = doc.logo == null ? null : docxImageOf(doc.logo!);
  return DocxTemplateData(
    values: {
      'entity_name': doc.entityName,
      'logo': logo,
      'document_title': doc.documentTitle,
      'meeting_title': doc.minutesTitle,
      'template_name': doc.templateName,
      'committee': doc.bodyName,
      'meeting_number': doc.record.numberText ?? '',
      'weekday': doc.weekday,
      'date_hijri': doc.hijriDate,
      'date_gregorian': doc.gregorianDate,
      'time_start': doc.startTime,
      'time_end': doc.endTime,
      'place': doc.record.place,
      'chair': doc.record.chair,
      'secretary': doc.record.secretary,
      'opening': doc.opening,
      'quorum': doc.quorum.statementAr,
      'next_meeting': minutes.nextMeeting ?? '',
      'status': doc.statusLine,
      'version': '${doc.record.version}',
      'content_hash': doc.isApproved ? doc.contentHash : '',
      'approval_date': doc.isApproved && doc.record.approvedAt != null
          ? formatArabicDateTime(doc.record.approvedAt!)
          : '',
    },
    blocks: {
      'attendees_present': doc.present,
      'attendees_absent': [
        for (final a in doc.absentExcused) '$a (بعذر)',
        for (final a in doc.absentUnexcused) '$a (دون عذر)',
      ],
      'attendees_absent_excused': doc.absentExcused,
      'attendees_absent_unexcused': doc.absentUnexcused,
      'guests': doc.guests,
      'agenda': [
        for (var i = 0; i < minutes.agendaCoverage.length; i++)
          _agendaLine(i, minutes.agendaCoverage[i]),
      ],
      'summary': [
        for (final p in minutes.summary.split(RegExp(r'\n\s*\n')))
          if (p.trim().isNotEmpty) p.trim(),
      ],
      'topics': [
        for (var i = 0; i < minutes.topics.length; i++)
          _topicLine(i, minutes.topics[i]),
      ],
      'resolutions': [
        for (final r in doc.resolutions) '${r.label} ${_one(r.text)}',
      ],
      'votes': [
        for (final r in doc.resolutions)
          if (voteLinesOf(r).isNotEmpty)
            '${r.label}\n${voteLinesOf(r).join('\n')}',
      ],
      'action_items': [
        for (var i = 0; i < minutes.actionItems.length; i++)
          _actionLine(i, minutes.actionItems[i]),
      ],
      'open_questions': [for (final q in minutes.openQuestions) _one(q)],
      'notes': [
        if (minutes.notes != null)
          for (final p in minutes.notes!.split(RegExp(r'\n\s*\n')))
            if (p.trim().isNotEmpty) p.trim(),
      ],
      'signatures': [for (final s in doc.signatories) _signatureLine(s)],
    },
    collections: {
      'resolution': [
        for (final r in doc.resolutions)
          {
            'number': r.label,
            'text': r.text,
            'vote': voteLinesOf(r).join('\n'),
          },
      ],
      'action_item': [
        for (var i = 0; i < minutes.actionItems.length; i++)
          {
            'number': '${i + 1}',
            'task': _one(minutes.actionItems[i].task),
            'owner': minutes.actionItems[i].owner ?? '',
            'due': minutes.actionItems[i].dueDate ?? '',
          },
      ],
      'attendee': [
        for (final a in doc.record.attendance)
          {'name': a.name, 'title': a.title, 'status': a.status.labelAr},
      ],
      'signature': [
        for (final s in doc.signatories)
          {
            'name': s.name,
            'role': s.role,
            'image': s.signature == null || s.signature!.isEmpty
                ? null
                : docxImageOf(
                    signaturePng(s.signature!),
                    maxWidthCm: 4.5,
                    maxHeightCm: 1.6,
                  ),
            'date': s.signature == null
                ? ''
                : formatArabicDateTime(s.signature!.signedAt),
          },
      ],
    },
  );
}

/// A ready-made sample template (.docx) containing every placeholder,
/// in the app's own right-to-left layout.
Uint8List buildSampleTemplate({DateTime? created}) {
  const w = DocxBuilder.textWidth;
  final d = DocxBuilder(footerText: '{{entity_name}} — {{content_hash}}')
    ..runs([const DocxRun('{{logo}}')], align: DocxAlign.center)
    ..runs([
      const DocxRun('{{entity_name}}', bold: true, sizeHalfPoints: 28),
    ], align: DocxAlign.center)
    ..subtitle('{{template_name}} — {{committee}}')
    ..title('{{document_title}}')
    ..labelValue('الموضوع', '{{meeting_title}}')
    ..labelValue(
      'اليوم والتاريخ',
      '{{weekday}} {{date_hijri}} الموافق {{date_gregorian}}',
    )
    ..labelValue('الوقت', 'من {{time_start}} إلى {{time_end}}')
    ..labelValue('المكان', '{{place}}')
    ..labelValue('رئيس الاجتماع', '{{chair}}')
    ..labelValue('أمين السر', '{{secretary}}')
    ..labelValue('رقم الاجتماع', '{{meeting_number}}')
    ..paragraph('{{opening}}')
    ..heading('الحضور')
    ..paragraph('{{attendees_present}}')
    ..heading('الغائبون')
    ..paragraph('{{attendees_absent}}')
    ..heading('المدعوون')
    ..paragraph('{{guests}}')
    ..heading('كشف الحضور')
    ..table(
      DocxTable(
        header: const ['الاسم', 'الصفة', 'الحالة'],
        rows: const [
          ['{{attendee.name}}', '{{attendee.title}}', '{{attendee.status}}'],
        ],
        columnWidths: const [w * 4 ~/ 10, w * 3 ~/ 10, w * 3 ~/ 10],
      ),
    )
    ..heading('النصاب')
    ..paragraph('{{quorum}}')
    ..heading('جدول الأعمال')
    ..paragraph('{{agenda}}')
    ..heading('الملخص')
    ..paragraph('{{summary}}')
    ..heading('محاور النقاش')
    ..paragraph('{{topics}}')
    ..heading('القرارات')
    ..paragraph('{{resolutions}}')
    ..heading('القرارات ونتائج التصويت (جدول)')
    ..table(
      DocxTable(
        header: const ['الرقم', 'القرار', 'التصويت'],
        rows: const [
          [
            '{{resolution.number}}',
            '{{resolution.text}}',
            '{{resolution.vote}}',
          ],
        ],
        columnWidths: const [w * 2 ~/ 10, w * 5 ~/ 10, w * 3 ~/ 10],
      ),
    )
    ..heading('تفاصيل التصويت')
    ..paragraph('{{votes}}')
    ..heading('المهام')
    ..table(
      DocxTable(
        header: const ['#', 'المهمة', 'المسؤول', 'الموعد'],
        rows: const [
          [
            '{{action_item.number}}',
            '{{action_item.task}}',
            '{{action_item.owner}}',
            '{{action_item.due}}',
          ],
        ],
        columnWidths: const [
          600,
          (w - 600) * 5 ~/ 9,
          (w - 600) * 2 ~/ 9,
          (w - 600) * 2 ~/ 9,
        ],
      ),
    )
    ..paragraph('{{action_items}}')
    ..heading('المسائل المعلقة')
    ..paragraph('{{open_questions}}')
    ..labelValue('الاجتماع القادم', '{{next_meeting}}')
    ..heading('ملاحظات')
    ..paragraph('{{notes}}')
    ..heading('التواقيع')
    ..table(
      DocxTable(
        header: const ['الاسم', 'الصفة', 'التوقيع', 'التاريخ'],
        rows: const [
          [
            '{{signature.name}}',
            '{{signature.role}}',
            '{{signature.image}}',
            '{{signature.date}}',
          ],
        ],
        columnWidths: const [
          w * 3 ~/ 10,
          w * 2 ~/ 10,
          w * 3 ~/ 10,
          w * 2 ~/ 10,
        ],
        minRowHeight: 900,
      ),
    )
    ..paragraph('{{signatures}}')
    ..note('{{status}} — الإصدار {{version}} — {{approval_date}}')
    ..note('رمز التحقق: {{content_hash}}')
    ..heading('دليل الحقول')
    ..note(
      'احذف هذا القسم من قالبك. ضع أي حقل مما يلي في المستند وسيُستبدل '
      'عند التصدير. الحقل وحده في فقرة يتوسع إلى فقرة لكل عنصر، وصف '
      'الجدول الذي يحتوي حقولاً مثل {{action_item.task}} يتكرر لكل عنصر.',
    );
  for (final p in kTemplatePlaceholders) {
    d.runs([DocxRun('${p.token}  ', bold: true), DocxRun(p.descriptionAr)]);
  }
  return d.build(
    DocxMetadata(
      title: 'قالب محضر إنصاتو',
      creator: ExportService.appName,
      application: ExportService.appName,
      created: created ?? DateTime.now(),
    ),
  );
}

/// Placeholder documentation as lines (`{{x}} — description`).
List<String> placeholderGuideLines() => [
  for (final p in kTemplatePlaceholders) '${p.token} — ${p.descriptionAr}',
];

/// The [OfficialSignatory]s that still need to sign.
List<OfficialSignatory> pendingSignatories(OfficialDocument doc) => [
  for (final s in doc.signatories)
    if (s.signature == null && s.name.isNotEmpty) s,
];

/// True when every named signatory signed.
bool allSigned(OfficialDocument doc) =>
    doc.record.status == OfficialStatus.approved &&
    pendingSignatories(doc).isEmpty;
