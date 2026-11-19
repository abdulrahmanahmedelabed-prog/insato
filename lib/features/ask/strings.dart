// Arabic (MSA) UI strings of "Ask your meetings" (F8). Shared words come
// from `S` in lib/ui/strings_ar.dart.

import '../../core/time_format.dart';

/// Arabic strings of the ask feature.
abstract final class AS {
  /// Screen title / navigation label.
  static const String title = 'اسأل اجتماعاتك';

  /// One-line description for a navigation entry or settings tile.
  static const String subtitle =
      'اطرح سؤالاً عن اجتماعاتك المسجلة واحصل على إجابة مع روابط إلى مصادرها';

  /// Empty-state title.
  static const String emptyTitle = 'عمّ تريد أن تسأل؟';

  /// Empty-state body.
  static const String emptyBody =
      'ابحث في محاضر اجتماعاتك ونصوصها بأي لغة، وستصلك الإجابة بالعربية مع '
      'روابط تفتح الاجتماع عند اللحظة التي قيل فيها الكلام.';

  /// Example questions (tap to fill the field).
  static const List<String> examples = [
    'ما القرارات التي اتُّخذت بشأن الميزانية؟',
    'ما المهام المسندة إلى سارة وما مواعيدها؟',
    'ماذا قيل عن موعد إطلاق المشروع؟',
  ];

  /// Label above the example questions.
  static const String examplesLabel = 'أمثلة';

  /// Privacy line for a cloud engine: what is sent and where.
  static String cloudNotice(String engineName) =>
      'يُرسَل سؤالك ومقتطفات ذات صلة من اجتماعاتك إلى $engineName لصياغة '
      'الإجابة، وفق المحرك المختار في الإعدادات. يستهلك كل سؤال طلباً واحداً '
      'من حصة الاستخدام.';

  /// Extra privacy line for the Gemini free tier.
  static const String geminiFreeTierNotice =
      'في الفئة المجانية من Gemini قد تستخدم Google النصوص المرسلة لتحسين '
      'منتجاتها وقد يطّلع عليها مراجعون بشريون. للاجتماعات السرية اختر المحرك '
      'المحلي على الجهاز.';

  /// Privacy line for an on-device / local engine.
  static String localNotice(String engineName) =>
      'تُعالَج أسئلتك على $engineName، ولا يغادر شيء من اجتماعاتك جهازك أو '
      'شبكتك.';

  /// Question field label.
  static const String fieldLabel = 'سؤالك';

  /// Question field hint.
  static const String fieldHint = 'اكتب سؤالاً عن اجتماعاتك…';

  /// Send button tooltip.
  static const String send = 'إرسال السؤال';

  /// Stop button tooltip.
  static const String stop = 'إيقاف';

  /// Clear conversation action.
  static const String clear = 'محادثة جديدة';

  /// Clear confirmation title.
  static const String clearTitle = 'بدء محادثة جديدة؟';

  /// Clear confirmation body.
  static const String clearBody =
      'ستُمسح الأسئلة والإجابات الحالية. لا تُحفَظ المحادثة بعد إغلاق '
      'التطبيق.';

  /// Note that the history is not stored.
  static const String notStored =
      'تبقى المحادثة في الذاكرة فقط ولا تُحفَظ على الجهاز.';

  /// Semantics label of a user bubble.
  static const String youAsked = 'سؤالك';

  /// Semantics label of an answer bubble.
  static const String answerLabel = 'الإجابة';

  /// Heading of the sources list under an answer.
  static const String sources = 'المصادر';

  /// Badge of an answer the meetings did not contain.
  static const String notFound = 'لم تُعثر على إجابة صريحة في الاجتماعات';

  /// "Answered by" footer of an answer.
  static String answeredBy(String engine) => 'أجاب: $engine';

  /// Copy answer action.
  static const String copyAnswer = 'نسخ الإجابة';

  /// Snack after copying.
  static const String answerCopied = 'نُسخت الإجابة.';

  /// Retry action.
  static const String retry = 'إعادة المحاولة';

  /// Open settings action.
  static const String openSettings = 'فتح الإعدادات';

  /// Inline citation marker label for screen readers.
  static String citationSemantics(int number, String label) =>
      'المصدر $number: $label. اضغط لفتح الاجتماع';

  /// Source tile hint for screen readers.
  static const String openSourceHint = 'فتح الاجتماع عند هذا الموضع';

  /// Source tile subtitle: meeting date.
  static String sourceDate(DateTime date) => formatArabicShortDate(date);

  /// The meeting as a whole (citation without a timestamp).
  static const String wholeMeeting = 'الاجتماع والمحضر';

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  /// Searching the local corpus.
  static const String searching = 'جارٍ البحث في اجتماعاتك…';

  /// Loading a local model.
  static const String loadingModel = 'جارٍ تحميل النموذج المحلي…';

  /// Connecting.
  static String connecting(String engine) => 'جارٍ إرسال السؤال إلى $engine…';

  /// Thinking.
  static String thinking(String engine) => '$engine يفكّر في الإجابة…';

  /// Writing.
  static String writing(String engine) => '$engine يكتب الإجابة…';

  /// Retrying after a transient failure.
  static const String retrying = 'تعذّر الاتصال مؤقتاً، تُعاد المحاولة…';

  /// Waiting for the provider's rate limit.
  static String waitingForQuota(Duration? wait) => wait == null
      ? 'بلغت حد الطلبات في الدقيقة، الانتظار قبل المحاولة…'
      : 'بلغت حد الطلبات في الدقيقة، الانتظار ${wait.inSeconds} ثانية…';

  /// Processing chunks (local engines).
  static const String processingChunk = 'جارٍ معالجة النص على الجهاز…';

  // ---------------------------------------------------------------------------
  // Outcomes
  // ---------------------------------------------------------------------------

  /// No meeting has any searchable content.
  static const String noMeetings =
      'لا توجد بعد اجتماعات مفرَّغة يمكن البحث فيها. سجّل اجتماعاً أولاً ثم '
      'اسأل عنه.';

  /// The engine's answer could not be read.
  static const String unreadable =
      'تعذّر فهم إجابة المحرك. أعد المحاولة، أو أعد صياغة السؤال.';

  /// The question was stopped by the user.
  static const String cancelled = 'أُوقف السؤال.';

  /// Unexpected failure.
  static const String unexpected = 'تعذّرت الإجابة عن السؤال. حاول مرة أخرى.';

  /// Error title.
  static const String errorTitle = 'تعذّرت الإجابة';
}
