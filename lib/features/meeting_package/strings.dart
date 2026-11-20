// Arabic (MSA) UI strings of «حزمة الاجتماع» (offline meeting packages).

import 'package_format.dart' show PackageErrorKind;

/// Arabic strings of the meeting-package feature.
abstract final class PS {
  /// Meeting menu: export.
  static const String exportEntry = 'تصدير حزمة الاجتماع';

  /// Meeting menu: merge a package into this meeting.
  static const String mergeEntry = 'دمج حزمة اجتماع هنا';

  /// Meeting menu: undo the last merge.
  static const String undoEntry = 'التراجع عن دمج الحزمة';

  /// Meetings screen: import.
  static const String importEntry = 'استيراد حزمة اجتماع';

  /// Tooltip of the meetings-screen button.
  static const String importTooltip = 'استيراد حزمة اجتماع (.insato)';

  /// Export dialog title.
  static const String exportTitle = 'تصدير حزمة الاجتماع';

  /// Export dialog intro.
  static const String exportIntro =
      'تجمع الحزمة تسجيل هذا الاجتماع ونصه في ملف واحد بامتداد ‎.insato‎ '
      'يمكن نقله دون إنترنت — بكابل USB أو بلوتوث أو المشاركة القريبة '
      '(Nearby Share / AirDrop) أو بطاقة ذاكرة، أو بالبريد عند توفر اتصال — '
      'ثم دمجه في الاجتماع الرئيسي على جهاز آخر.';

  /// Include audio switch.
  static const String includeAudio = 'تضمين التسجيل الصوتي';

  /// Include audio subtitle.
  static const String includeAudioHint =
      'يتيح مواءمة التوقيت بدقة مع التسجيل الرئيسي والاستماع إلى المقاطع. '
      'يكبر حجم الملف (نحو 2 ميغابايت لكل دقيقة).';

  /// No recording available.
  static const String noAudioAvailable =
      'لا يوجد تسجيل صوتي محفوظ لهذا الاجتماع.';

  /// Include minutes switch.
  static const String includeMinutes = 'تضمين المحضر';

  /// Include voiceprints switch.
  static const String includeVoiceprints = 'تضمين بصمات الصوت';

  /// Voiceprint warning.
  static const String voiceprintsWarning =
      'بصمات الصوت بيانات حيوية (بيومترية) تخص المتحدثين. لا تضمّنها إلا '
      'بموافقتهم ولجهة تثق بها. تساعد على التعرف على المتحدثين أنفسهم في '
      'الجهاز الآخر.';

  /// Password field.
  static const String password = 'كلمة مرور (اختيارية)';

  /// Password hint.
  static const String passwordHint =
      'تُشفَّر الحزمة بمعيار AES-256-GCM، ولا يمكن فتحها دون كلمة المرور. '
      'أبلغها للمستلم بطريقة أخرى غير الملف نفسه.';

  /// Password confirmation field.
  static const String passwordConfirm = 'تأكيد كلمة المرور';

  /// Password mismatch.
  static const String passwordMismatch = 'كلمتا المرور غير متطابقتين.';

  /// Password too short.
  static const String passwordShort = 'استخدم 6 أحرف على الأقل.';

  /// Export action.
  static const String exportAction = 'تصدير';

  /// Cancel.
  static const String cancel = 'إلغاء';

  /// Close.
  static const String close = 'إغلاق';

  /// Exported (shared).
  static const String exported = 'جُهّزت حزمة الاجتماع للمشاركة.';

  /// Saved at path.
  static String savedAt(String path) => 'حُفظت حزمة الاجتماع في: $path';

  /// Export failed.
  static const String exportFailed = 'تعذّر تصدير حزمة الاجتماع.';

  /// Password dialog title.
  static const String passwordTitle = 'حزمة محمية بكلمة مرور';

  /// Password dialog body.
  static const String passwordBody =
      'أدخل كلمة المرور التي اختارها من صدّر الحزمة.';

  /// Open action.
  static const String openAction = 'فتح';

  /// Import sheet title.
  static const String importTitle = 'حزمة اجتماع';

  /// Device label.
  static const String device = 'الجهاز';

  /// Recording start label.
  static const String startedAt = 'بدء التسجيل';

  /// Duration label.
  static const String duration = 'المدة';

  /// Segments label.
  static const String segments = 'المقاطع';

  /// Speakers label.
  static const String speakers = 'المتحدثون';

  /// Contents label.
  static const String contents = 'المحتوى';

  /// Content items.
  static const String hasAudio = 'تسجيل صوتي';

  /// Content items.
  static const String hasMinutes = 'محضر';

  /// Content items.
  static const String hasVoiceprints = 'بصمات صوت';

  /// Content items.
  static const String encrypted = 'مشفّرة';

  /// Content items.
  static const String transcriptOnly = 'النص فقط';

  /// Import as new meeting.
  static const String asNewMeeting = 'إنشاء اجتماع جديد منها';

  /// Merge into an existing meeting.
  static const String mergeIntoExisting = 'دمجها في اجتماع موجود';

  /// Choose the meeting to merge into.
  static const String chooseMeeting = 'اختر الاجتماع الرئيسي';

  /// No meeting to merge into.
  static const String noMeetings = 'لا توجد اجتماعات يمكن الدمج فيها.';

  /// Merge preview title.
  static const String previewTitle = 'معاينة الدمج';

  /// Merge into …
  static String mergeInto(String title) => 'الدمج في «$title»';

  /// Overlap label.
  static const String overlap = 'التداخل مع التسجيل الرئيسي';

  /// No overlap.
  static const String noOverlap = 'لا تداخل في الوقت';

  /// Offset label.
  static const String offset = 'فرق التوقيت';

  /// Offset value.
  static String offsetValue(String signedDuration) =>
      'تبدأ الحزمة عند $signedDuration من بداية الاجتماع';

  /// Alignment by audio.
  static String alignedByAudio(String correction) =>
      'ضُبط التوقيت بمطابقة الصوتين (صُحّحت ساعة الجهاز بمقدار $correction).';

  /// Alignment by clock only.
  static const String alignedByClock =
      'ضُبط التوقيت بساعتي الجهازين فقط (لم يُعثر على صوت مشترك)؛ قد يختلف '
      'الترتيب قليلًا إن كانت ساعة أحد الجهازين غير دقيقة.';

  /// New segments.
  static String newSegments(int n) => 'مقاطع جديدة: $n';

  /// Duplicates.
  static String duplicates(int n, int replaced) =>
      'مقاطع مكررة سمعها الجهازان: $n (اعتُمد النص الأوضح؛ استُبدل $replaced)';

  /// Speakers matched / created.
  static String speakersSummary(int matched, int created) =>
      'متحدثون معروفون: $matched، متحدثون جدد: $created';

  /// Merge action.
  static const String mergeAction = 'دمج';

  /// Merge note about undo.
  static const String undoNote =
      'يمكنك التراجع عن الدمج لاحقًا من قائمة الاجتماع.';

  /// Merged.
  static String merged(int n) => 'دُمجت الحزمة: أُضيف $n مقطعًا.';

  /// Regenerate minutes question.
  static const String regenerateTitle = 'إعادة إنشاء المحضر؟';

  /// Regenerate minutes body.
  static const String regenerateBody =
      'تغيّر نص الاجتماع بعد الدمج. هل تريد إعادة إنشاء المحضر ليشمل ما '
      'سجّله الجهاز الآخر؟';

  /// Regenerate action.
  static const String regenerateAction = 'إعادة إنشاء المحضر';

  /// Later.
  static const String later = 'لاحقًا';

  /// Imported as new meeting.
  static const String imported = 'أُنشئ اجتماع جديد من الحزمة.';

  /// Undo confirm title.
  static const String undoTitle = 'التراجع عن الدمج؟';

  /// Undo confirm body.
  static String undoBody(String device) =>
      'يُعاد الاجتماع إلى حاله قبل دمج حزمة «$device»: تُحذف المقاطع '
      'المضافة ويُستعاد النص والتسجيل والمحضر وبصمات الصوت كما كانت.';

  /// Undo action.
  static const String undoAction = 'تراجع';

  /// Undone.
  static const String undone = 'أُلغي دمج الحزمة.';

  /// Nothing to undo.
  static const String nothingToUndo = 'لا يوجد دمج للتراجع عنه.';

  /// Generic failure.
  static const String failed = 'تعذّر إكمال العملية.';

  /// Meeting missing.
  static const String meetingMissing = 'الاجتماع غير موجود.';

  /// Meeting busy.
  static const String stillRecording =
      'الاجتماع قيد التسجيل أو المعالجة. انتظر حتى ينتهي ثم أعد المحاولة.';

  /// Progress.
  static const String progressReading = 'جارٍ قراءة الاجتماع…';

  /// Progress.
  static const String progressAnalysing = 'جارٍ تحليل التسجيل…';

  /// Progress.
  static const String progressPacking = 'جارٍ تجهيز الحزمة…';

  /// Progress.
  static const String progressEncrypting = 'جارٍ تشفير الحزمة…';

  /// Progress.
  static const String progressOpening = 'جارٍ فتح الحزمة والتحقق من سلامتها…';

  /// Progress.
  static const String progressImporting = 'جارٍ استيراد الحزمة…';

  /// Progress.
  static const String progressAligning = 'جارٍ مواءمة التوقيت بين التسجيلين…';

  /// Progress.
  static const String progressPlanning = 'جارٍ ترتيب المقاطع وإزالة المكرر…';

  /// Progress.
  static const String progressMerging = 'جارٍ الدمج…';

  /// Progress.
  static const String progressRefining = 'جارٍ تحسين تمييز المتحدثين…';

  /// Progress.
  static const String progressDone = 'اكتمل.';

  /// Arabic message of a package error.
  static String error(PackageErrorKind kind) => switch (kind) {
    PackageErrorKind.notAPackage => 'هذا الملف ليس حزمة اجتماع من إنصاتو.',
    PackageErrorKind.unsupportedVersion =>
      'صدرت هذه الحزمة من إصدار أحدث من إنصاتو. حدّث التطبيق ثم أعد المحاولة.',
    PackageErrorKind.passwordRequired => 'هذه الحزمة محمية بكلمة مرور.',
    PackageErrorKind.wrongPassword =>
      'كلمة المرور غير صحيحة، أو عُدّل محتوى الحزمة المشفّرة.',
    PackageErrorKind.tampered =>
      'فشل التحقق من سلامة الحزمة: تغيّر محتواها بعد التصدير (تلف أثناء '
          'النقل أو تعديل متعمد). اطلب نسخة جديدة من الجهاز الآخر.',
    PackageErrorKind.corrupt =>
      'الحزمة تالفة أو ناقصة. اطلب نسخة جديدة من الجهاز الآخر.',
  };
}
