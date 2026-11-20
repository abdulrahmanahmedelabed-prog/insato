// Arabic (MSA) UI strings of the contradiction & consistency checker
// (v1.2, D). Shared words (cancel, …) come from `S` in
// lib/ui/strings_ar.dart.

import 'consistency_models.dart';

/// Arabic strings of the consistency checker.
abstract final class DS {
  /// Tab title in the meeting screen.
  static const String tabTitle = 'التناقضات';

  /// Header of the tab.
  static const String header = 'كاشف التناقضات';

  /// Explanation under the header.
  static const String intro =
      'يقارن قرارات هذا الاجتماع ومهامه بالقرارات المعتمدة والمهام السابقة '
      'وببعضها، ويعرض ما قد يتعارض معها لتراجعه.';

  /// Run button.
  static const String checkNow = 'افحص الآن';

  /// Run button after a run.
  static const String checkAgain = 'أعد الفحص';

  /// Status while running.
  static const String checking = 'جارٍ فحص التناقضات…';

  /// Status: heuristics.
  static const String checkingLocal =
      'جارٍ المقارنة بالقرارات والمهام السابقة…';

  /// Status: engine.
  static String checkingEngine(String engine) =>
      'جارٍ التحقق من النتائج عبر $engine…';

  /// No minutes yet.
  static const String noMinutes =
      'لا يوجد محضر بعد. أنشئ المحضر أولاً ثم افحص التناقضات.';

  /// No findings.
  static const String noFindingsTitle = 'لا تناقضات';

  /// No findings body.
  static const String noFindingsBody =
      'لم يُعثر على تعارض مع القرارات أو المهام السابقة في آخر فحص.';

  /// Never checked.
  static const String notCheckedBody =
      'لم يُفحص هذا الاجتماع بعد. اضغط «افحص الآن».';

  /// Summary after a run.
  static String summary(int open) => switch (open) {
    0 => 'اكتمل الفحص: لا تناقضات مفتوحة.',
    1 => 'اكتمل الفحص: ملاحظة واحدة تحتاج إلى مراجعة.',
    2 => 'اكتمل الفحص: ملاحظتان تحتاجان إلى مراجعة.',
    <= 10 => 'اكتمل الفحص: $open ملاحظات تحتاج إلى مراجعة.',
    _ => 'اكتمل الفحص: $open ملاحظة تحتاج إلى مراجعة.',
  };

  /// The engine could not be used: only the local rules ran.
  static String localOnly(String reason) =>
      'فُحص الاجتماع بالقواعد المحلية فقط (تكشف الحالات الواضحة). $reason';

  /// Generic engine failure.
  static const String engineFailed = 'تعذّر الاتصال بمحرك المحضر.';

  /// Section of handled findings.
  static String handled(int n) => 'تمت معالجتها ($n)';

  /// Section of open findings.
  static String openCount(int n) => 'تحتاج إلى مراجعة ($n)';

  /// Side headers.
  static const String thisMeeting = 'في هذا الاجتماع';

  /// Earlier side header.
  static const String earlier = 'سابقاً';

  /// Other item of the same meeting.
  static const String sameMeeting = 'في الاجتماع نفسه';

  /// A manual task (no meeting).
  static const String manualTask = 'مهمة أُضيفت يدوياً';

  /// A deleted meeting.
  static const String deletedMeeting = 'اجتماع محذوف';

  /// Approved badge.
  static const String approved = 'معتمد';

  /// Not approved badge.
  static const String notApproved = 'غير معتمد';

  /// Show evidence / open.
  static const String showEvidence = 'استمع إلى الدليل';

  /// Open the meeting.
  static const String openMeeting = 'فتح الاجتماع';

  /// Dismiss.
  static const String dismiss = 'تجاهل';

  /// Confirm for resolutions.
  static const String confirmCancelled = 'تم الإلغاء رسمياً';

  /// Confirm for tasks.
  static const String acknowledge = 'تأكيد';

  /// Undo a decision.
  static const String reopen = 'تراجع';

  /// Dismissed label.
  static const String dismissedLabel = 'تم تجاهلها';

  /// Confirmed label (resolution).
  static const String confirmedCancelledLabel =
      'تم تأكيد الإلغاء الرسمي للقرار السابق';

  /// Confirmed label (task).
  static const String acknowledgedLabel = 'تم التأكيد';

  /// Origin labels.
  static const String originEngine = 'بالمحرك';

  /// Origin: heuristic.
  static const String originHeuristic = 'قاعدة محلية';

  /// Confirm dialog.
  static const String confirmTitle = 'تأكيد الإلغاء الرسمي';

  /// Confirm dialog body.
  static String confirmBody(String earlier, bool approved) =>
      'سيُعلَّم $earlier بأنه «أُلغي رسمياً» بهذا الاجتماع، ويظهر ذلك في '
      'اجتماعه. ${approved ? 'محضره معتمد ومقفل، لذا يُضاف تنويه إليه ولا '
                'يُعدَّل محتواه المعتمد.' : 'لا يُعدَّل نص المحضر، بل يُضاف تنويه إليه.'}';

  /// Snack after confirming.
  static const String confirmedSnack = 'سُجّل الإلغاء الرسمي للقرار السابق.';

  /// Snack after dismissing.
  static const String dismissedSnack = 'تم تجاهل الملاحظة.';

  /// Action failed.
  static const String actionFailed = 'تعذّر تنفيذ الإجراء.';

  /// Kind labels.
  static String kindLabel(FindingKind k) => switch (k) {
    FindingKind.contradictsResolution => 'يتعارض مع قرار سابق',
    FindingKind.duplicatesTask => 'يكرر مهمة قائمة',
    FindingKind.changesOwner => 'يغيّر المسؤول عن مهمة',
    FindingKind.changesDeadline => 'يغيّر موعد مهمة',
    FindingKind.revisitsClosedTopic => 'يعيد فتح موضوع محسوم',
    FindingKind.internalConflict => 'تعارض داخل الاجتماع',
  };

  /// Severity labels.
  static String severityLabel(FindingSeverity s) => switch (s) {
    FindingSeverity.high => 'خطورة عالية',
    FindingSeverity.medium => 'خطورة متوسطة',
    FindingSeverity.low => 'للعلم',
  };

  /// Side kind labels.
  static String sideKindLabel(SideKind k) => switch (k) {
    SideKind.resolution => 'قرار معتمد',
    SideKind.decision => 'قرار',
    SideKind.actionItem => 'مهمة',
    SideKind.task => 'مهمة',
  };

  /// Owner line.
  static String owner(String name) => 'المسؤول: $name';

  /// Due line.
  static String due(String d) => 'الموعد: $d';

  /// Task status labels.
  static String taskStatus(String? wire) => switch (wire) {
    'done' => 'منجزة',
    'cancelled' => 'ملغاة',
    _ => 'مفتوحة',
  };

  /// Meeting number.
  static String meetingNumber(String n) => 'رقم $n';

  // ---------------------------------------------------------------------------
  // Superseded annotations (earlier meeting)
  // ---------------------------------------------------------------------------

  /// Card title.
  static const String supersededTitle = 'قرارات أُلغيت رسمياً';

  /// One annotation.
  static String supersededBy(String label, String byTitle, String date) =>
      '$label — أُلغي رسمياً في اجتماع «$byTitle» ($date).';

  /// Note on approved minutes.
  static const String supersededApprovedNote =
      'المحضر معتمد: أُضيف هذا التنويه دون تعديل محتواه المعتمد أو رمز '
      'التحقق.';

  /// Note on other minutes.
  static const String supersededNote =
      'تنويه مضاف إلى المحضر؛ لا يُعدَّل نص القرار.';

  /// Superseding decision line.
  static String supersedingText(String text) => 'بالقرار: «$text»';

  /// Label shown on a superseded decision.
  static const String supersededBadge = 'أُلغي رسمياً';

  // ---------------------------------------------------------------------------
  // Live mode
  // ---------------------------------------------------------------------------

  /// Settings tile title.
  static const String liveTitle = 'فحص التناقضات أثناء التسجيل';

  /// Settings tile subtitle.
  static const String liveSubtitle =
      'كل بضع دقائق يُرسل آخر ما قيل مع القرارات والمهام السابقة المرتبطة '
      'به إلى محرك المحضر السحابي الذي وافقت عليه، ويظهر أي تعارض في شريط '
      'هادئ. معطّل افتراضياً، ولا يعمل مع المحرك المحلي.';

  /// Banner: one live finding.
  static String liveBanner(int n) => n == 1
      ? 'قد يتعارض ما قيل للتو مع بند سابق.'
      : 'قد يتعارض ما قيل للتو مع $n من البنود السابقة.';

  /// Banner details button.
  static const String liveDetails = 'التفاصيل';

  /// Banner hide button.
  static const String liveHide = 'إخفاء';

  /// Live details sheet title.
  static const String liveSheetTitle = 'تنبيهات الفحص المباشر';

  /// Live details sheet note.
  static const String liveSheetNote =
      'تنبيهات أولية من النقاش الجاري؛ يُجرى فحص كامل بعد إنشاء المحضر.';

  /// Live mode needs a cloud engine.
  static const String liveNeedsCloud =
      'الفحص المباشر يعمل مع Gemini أو Groq فقط.';
}
