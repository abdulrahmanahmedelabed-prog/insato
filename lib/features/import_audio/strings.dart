// Arabic (MSA) UI strings of the recording import («استيراد تسجيل»).

/// Arabic strings of the recording import.
abstract final class IS {
  /// Action label (meetings screen).
  static const String importAction = 'استيراد تسجيل';

  /// Action tooltip.
  static const String importTooltip =
      'استيراد تسجيل صوتي (مكالمة أو مذكرة صوتية أو تسجيل اجتماع)';

  /// Label of the file chooser's type group.
  static const String audioFiles = 'ملفات صوتية';

  /// Confirm dialog title.
  static const String confirmTitle = 'استيراد تسجيل';

  /// Confirm dialog intro.
  static const String confirmBody =
      'سيُفرَّغ التسجيل ويُميَّز المتحدثون بأصواتهم ويُكتب المحضر كما في '
      'الاجتماعات المسجّلة. تجري المعالجة على هذا الجهاز وقد تستغرق بعض الوقت.';

  /// Title field label.
  static const String titleLabel = 'عنوان الاجتماع';

  /// Source file line.
  static String sourceFile(String name) => 'الملف: $name';

  /// Legal reminder (call recordings).
  static const String legalNotice =
      'تختلف قوانين تسجيل المكالمات والاجتماعات من بلد إلى آخر. تأكّد من أن '
      'تسجيل هذه المحادثة مسموح به، وأن المشاركين علموا بالتسجيل أو وافقوا '
      'عليه، قبل استيراده ومعالجته.';

  /// Confirmation checkbox.
  static const String legalCheckbox =
      'أؤكّد أن لديّ الحق في معالجة هذا التسجيل.';

  /// Confirm button.
  static const String startImport = 'استيراد ومعالجة';

  /// Cancel button of the dialog.
  static const String cancel = 'إلغاء';

  /// Badge on imported meetings.
  static const String importedBadge = 'مستورد';

  /// Badge semantics.
  static const String importedBadgeSemantics = 'اجتماع من تسجيل مستورد';

  /// Progress card title.
  static const String progressTitle = 'استيراد تسجيل';

  /// Cancel the running import.
  static const String cancelImport = 'إلغاء الاستيراد';

  /// Cancelling…
  static const String cancelling = 'جارٍ الإلغاء…';

  /// Import cancelled.
  static const String cancelled = 'أُلغي استيراد التسجيل.';

  /// Success line.
  static const String done = 'اكتمل استيراد التسجيل وتفريغه.';

  /// Success line with failed segments.
  static String doneWithFailures(int n) =>
      'اكتمل استيراد التسجيل، وتعذّر تفريغ $n من المقاطع.';

  /// Minutes follow.
  static const String minutesFollow =
      'يُكتب المحضر الآن في الخلفية إن كان محرك المحضر جاهزًا.';

  /// Open the imported meeting.
  static const String openMeeting = 'فتح الاجتماع';

  /// Open the models screen after a models error.
  static const String openModels = 'تنزيل النماذج';

  /// Dismiss the card.
  static const String dismiss = 'إخفاء';

  /// Import failed title.
  static const String failedTitle = 'تعذّر استيراد التسجيل';

  /// Another import is running.
  static const String busy =
      'يجري استيراد تسجيل آخر الآن. انتظر حتى يكتمل أو ألغِه أولًا.';

  /// Recording in progress.
  static const String recordingActive =
      'لا يمكن استيراد تسجيل أثناء تسجيل اجتماع. أوقف التسجيل أولًا.';

  /// Only the first shared file is imported.
  static const String onlyFirstShared =
      'يُستورد ملف واحد في كل مرة؛ استُورد الملف الأول فقط.';

  /// A shared item could not be received.
  static const String sharedReceiveFailed =
      'تعذّر استلام الملف المُشارَك. احفظه على الجهاز ثم استورده من «استيراد '
      'تسجيل».';

  /// Shared file too large.
  static const String sharedTooLarge =
      'الملف المُشارَك أكبر من الحد المسموح للاستيراد.';

  // -------------------------------------------------------------------------
  // Progress statuses
  // -------------------------------------------------------------------------

  /// Checking the file.
  static const String checking = 'جارٍ فحص الملف…';

  /// Preparing speech models.
  static const String loadingModels = 'جارٍ تحميل نماذج التعرّف على الكلام…';

  /// Decoding with percentage.
  static String decoding(int percent) =>
      'جارٍ تحويل الصوت ($percent٪)…';

  /// Decoding without a known duration.
  static String decodingMinutes(int minutes) =>
      'جارٍ تحويل الصوت ($minutes د)…';

  /// Transcribing with percentage.
  static String transcribing(int percent) =>
      'جارٍ تفريغ التسجيل ($percent٪)…';

  /// Finishing the transcript.
  static const String finishing = 'جارٍ إكمال التفريغ…';

  /// Speaker identification.
  static const String speakers = 'جارٍ تمييز المتحدثين بأصواتهم…';

  // -------------------------------------------------------------------------
  // Errors
  // -------------------------------------------------------------------------

  /// File missing.
  static const String notFound =
      'تعذّر العثور على الملف المختار. ربما نُقل أو حُذف.';

  /// File unreadable.
  static const String unreadable =
      'تعذّرت قراءة الملف. تأكّد من أنه محفوظ على الجهاز ثم أعد المحاولة.';

  /// Empty file.
  static const String emptyFile = 'الملف فارغ.';

  /// Not an audio file.
  static const String notAudio =
      'هذا الملف ليس تسجيلًا صوتيًا. اختر ملفًا بصيغة M4A أو MP3 أو WAV أو '
      'AMR أو OGG أو FLAC أو 3GP أو CAF.';

  /// Too large.
  static String tooLarge(int maxGb) =>
      'الملف أكبر من الحد المسموح ($maxGb غيغابايت).';

  /// Too long.
  static String tooLong(int maxHours) =>
      'مدة التسجيل أطول من الحد المسموح ($maxHours ساعات). قسّمه إلى أجزاء '
      'أقصر ثم استوردها.';

  /// Too short.
  static const String tooShort =
      'التسجيل قصير جدًا أو لا يحتوي على صوت يمكن تفريغه.';

  /// Codec not supported on this device.
  static String unsupported(String format) =>
      'لا يدعم هذا الجهاز فكّ ترميز ملفات $format. حوّل الملف إلى M4A أو MP3 '
      'أو WAV ثم أعد المحاولة.';

  /// Unsupported, format unknown.
  static const String unsupportedUnknown =
      'صيغة هذا الملف غير مدعومة على هذا الجهاز. حوّل الملف إلى M4A أو MP3 أو '
      'WAV ثم أعد المحاولة.';

  /// Decoding failed half-way / corrupt file.
  static const String decodeFailed =
      'تعذّر فكّ ترميز الصوت؛ قد يكون الملف تالفًا أو غير مكتمل.';

  /// Not enough storage.
  static const String noSpace =
      'لا تكفي مساحة التخزين لحفظ الصوت المحوَّل. أفرغ بعض المساحة ثم أعد '
      'المحاولة.';

  /// Transcription failed after the meeting was created.
  static String transcriptionFailed(String reason) =>
      'تعذّر تفريغ التسجيل المستورد: $reason يمكنك إعادة المحاولة من قائمة '
      'الاجتماع «إعادة المعالجة من التسجيل الصوتي».';

  /// Unexpected.
  static const String unexpected = 'حدث خطأ غير متوقع أثناء استيراد التسجيل.';

  // -------------------------------------------------------------------------
  // Titles
  // -------------------------------------------------------------------------

  /// Title of an imported call.
  static String callTitle(String who) => 'مكالمة: $who';

  /// Title of an imported call without a name.
  static String callTitleAt(String date) => 'مكالمة $date';

  /// Fallback title.
  static String importedTitleAt(String date) => 'تسجيل مستورد $date';
}
