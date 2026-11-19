// Arabic (MSA) strings of the Word export & share feature (F12): the export
// sheet, the share subject / body and the labels written into the .docx.
// Shared words (export failed, saved to, include transcript, …) come from
// `S` in lib/ui/strings_ar.dart.

import '../../core/models.dart';

/// Arabic strings of the Word export & share feature.
abstract final class XS {
  // -------------------------------------------------------------------------
  // Export sheet
  // -------------------------------------------------------------------------

  /// Title of the export sheet.
  static const String sheetTitle = 'تصدير المحضر ومشاركته';

  /// Hint under the title.
  static const String sheetHint =
      'اختر صيغة الملف، وستظهر تطبيقات البريد والمراسلة في قائمة المشاركة.';

  /// Tooltip of the button that opens the sheet.
  static const String openSheet = 'تصدير ومشاركة';

  /// PDF option.
  static const String sharePdf = 'مشاركة PDF';

  /// PDF option subtitle.
  static const String sharePdfHint = 'للقراءة والطباعة كما هو';

  /// Word option.
  static const String shareDocx = 'مشاركة Word';

  /// Word option subtitle.
  static const String shareDocxHint = 'ملف docx قابل للتعديل في Word';

  /// Markdown option.
  static const String shareMarkdown = 'مشاركة Markdown';

  /// Markdown option subtitle.
  static const String shareMarkdownHint = 'نص منسّق للملاحظات والمستودعات';

  /// Print option.
  static const String printPdf = 'طباعة';

  /// Shown while a file is being prepared.
  static const String preparing = 'جارٍ تجهيز الملف…';

  // -------------------------------------------------------------------------
  // Share subject / body
  // -------------------------------------------------------------------------

  /// E-mail subject: «محضر اجتماع: <title>».
  static String shareSubject(String title) => 'محضر اجتماع: $title';

  /// Body line naming the attached format.
  static String attachedAs(String formatName) =>
      'مرفق المحضر الكامل بصيغة $formatName.';

  /// Counts line of the body.
  static String counts(int decisions, int tasks) =>
      'القرارات: $decisions — المهام: $tasks';

  /// Signature of the body.
  static const String sentFrom = 'أُعدّ بواسطة تطبيق إنصاتو.';

  // -------------------------------------------------------------------------
  // Document labels
  // -------------------------------------------------------------------------

  /// Label above the title.
  static const String docKicker = 'محضر اجتماع';

  /// Date label.
  static const String date = 'التاريخ';

  /// Duration label.
  static const String duration = 'المدة';

  /// Unknown duration.
  static const String unknownDuration = 'غير معروفة';

  /// Languages label.
  static const String languages = 'لغات الاجتماع';

  /// Summary heading.
  static const String summary = 'الملخص';

  /// No summary.
  static const String noSummary = 'لا يوجد ملخص.';

  /// Attendees heading.
  static const String attendees = 'الحضور';

  /// No attendees.
  static const String noAttendees = 'لم يُحدَّد الحضور.';

  /// Agenda coverage heading.
  static const String agenda = 'تغطية جدول الأعمال';

  /// Agenda table: item.
  static const String agendaItem = 'البند';

  /// Agenda table: status.
  static const String agendaStatus = 'الحالة';

  /// Agenda table: note.
  static const String agendaNote = 'ملاحظة';

  /// Arabic label of an agenda item status.
  static String agendaStatusLabel(AgendaItemStatus s) => switch (s) {
    AgendaItemStatus.discussed => 'نوقش',
    AgendaItemStatus.partiallyDiscussed => 'نوقش جزئياً',
    AgendaItemStatus.notDiscussed => 'لم يُناقَش',
  };

  /// Topics heading.
  static const String topics = 'محاور النقاش';

  /// Speakers of a topic.
  static String topicSpeakers(String names) => 'المتحدثون: $names';

  /// Decisions heading.
  static const String decisions = 'القرارات';

  /// No decisions.
  static const String noDecisions = 'لم تُتخذ قرارات.';

  /// Proposer of a decision.
  static String proposedBy(String name) => ' (اقترحه: $name)';

  /// Action items heading.
  static const String actionItems = 'المهام';

  /// No action items.
  static const String noActionItems = 'لم تُسنَد مهام.';

  /// Action table: number column.
  static const String colNumber = '#';

  /// Action table: task.
  static const String colTask = 'المهمة';

  /// Action table: owner.
  static const String colOwner = 'المسؤول';

  /// Action table: due date.
  static const String colDue = 'الموعد';

  /// Empty cell.
  static const String emptyCell = '—';

  /// Open questions heading.
  static const String openQuestions = 'أسئلة مفتوحة';

  /// Next meeting heading.
  static const String nextMeeting = 'الاجتماع القادم';

  /// Notes heading.
  static const String notes = 'ملاحظات';

  /// Signature block heading.
  static const String signatures = 'اعتماد المحضر وتوقيعات الحضور';

  /// Signature table: name.
  static const String sigName = 'أسماء الحضور';

  /// Signature table: signature.
  static const String sigSignature = 'التوقيع';

  /// Signature table: date.
  static const String sigDate = 'التاريخ';

  /// Transcript appendix heading.
  static const String transcriptAppendix = 'ملحق: النص الكامل للاجتماع';

  /// Footer "page".
  static const String page = 'صفحة';

  /// Footer "of".
  static const String of = 'من';

  /// Line noting how the minutes were produced.
  static String generatedBy(String app, String model, String when) =>
      'أُعدّ هذا المحضر آلياً بواسطة تطبيق $app'
      '${model.isEmpty ? '' : ' باستخدام $model'} بتاريخ $when، '
      'ويُستحسن مراجعته قبل اعتماده.';
}
