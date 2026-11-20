// Arabic (MSA) UI strings of F13 (Windows system-audio capture). Shared
// words come from `S` in lib/ui/strings_ar.dart.

/// Arabic strings of F13.
abstract final class SystemAudioStrings {
  /// Selector title (Settings).
  static const String title = 'مصدر الصوت';

  /// Selector explanation (Settings).
  static const String hint =
      'على ويندوز يمكن تسجيل صوت النظام أيضاً، أي ما يصدر من السماعات مثل '
      'أصوات المشاركين في Zoom أو Teams، مع الميكروفون أو بدونه.';

  /// Segment: microphone only.
  static const String mic = 'الميكروفون';

  /// Segment: system audio only.
  static const String system = 'صوت النظام';

  /// Segment: both, mixed.
  static const String both = 'كلاهما';

  /// Long description of the microphone choice (semantics / tooltip).
  static const String micLong = 'تسجيل الميكروفون فقط';

  /// Long description of the system choice (semantics / tooltip).
  static const String systemLong =
      'تسجيل صوت النظام فقط (ما يصدر من السماعات، مثل اجتماع Zoom أو Teams)';

  /// Long description of the both choice (semantics / tooltip).
  static const String bothLong =
      'تسجيل الميكروفون وصوت النظام معاً في مسار واحد';

  /// Shown when system audio cannot be captured on this computer.
  static const String unsupported =
      'تسجيل صوت النظام غير متاح على هذا الجهاز؛ سيُسجَّل الميكروفون فقط.';

  /// Snack after a change.
  static String chosen(String label) => 'مصدر الصوت: $label.';

  /// Tip about headphones when system audio is recorded.
  static const String headphonesTip =
      'نصيحة: عند تسجيل الميكروفون وصوت النظام معاً استخدم سماعات رأس حتى '
      'لا يُلتقط صوت المشاركين مرتين.';

  // ---------------------------------------------------------------------------
  // Capture messages
  // ---------------------------------------------------------------------------

  /// System capture could not start ("system only" mode: fatal).
  static const String startFailed =
      'تعذّر بدء تسجيل صوت النظام. تأكّد من وجود جهاز إخراج صوت (سماعات) '
      'مفعّل ثم حاول مجدداً.';

  /// System capture could not start ("both" mode: the take continues).
  static const String startFailedMicOnly =
      'تعذّر بدء تسجيل صوت النظام؛ يستمر التسجيل من الميكروفون فقط.';

  /// The default output device changed during the take.
  static const String deviceChanged =
      'تغيّر جهاز إخراج الصوت؛ يستمر تسجيل صوت النظام من الجهاز الجديد.';

  /// No output device is available.
  static const String noDevice =
      'لا يوجد جهاز إخراج صوت مفعّل، فلا يمكن تسجيل صوت النظام حالياً. '
      'سيُستأنف تلقائياً عند توصيل سماعات أو تفعيلها.';

  /// Any other capture problem.
  static const String captureProblem =
      'حدثت مشكلة في تسجيل صوت النظام؛ تجري إعادة المحاولة تلقائياً.';

  /// The output device uses a format that cannot be captured.
  static const String unsupportedFormat =
      'صيغة جهاز إخراج الصوت الحالي غير مدعومة لتسجيل صوت النظام.';

  /// The mixed archive could not be created.
  static const String archiveFailed =
      'تعذّر إنشاء ملف حفظ التسجيل الصوتي. تحقّق من مساحة التخزين.';

  /// The mixed archive could not be written mid-take.
  static const String archiveWriteFailed =
      'تعذّر حفظ الصوت على الجهاز (قد تكون مساحة التخزين ممتلئة). '
      'يستمر النسخ المباشر دون حفظ الصوت.';
}
