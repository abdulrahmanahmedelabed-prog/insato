// Arabic (MSA) strings of the on-device and local-server minutes engines
// (F14). Shared words (save, cancel, delete, …) come from `S` in
// lib/ui/strings_ar.dart.

/// Arabic strings of the local minutes engines.
abstract final class LS {
  // ---------------------------------------------------------------------------
  // Engine names and availability
  // ---------------------------------------------------------------------------

  /// Name of the on-device engine in status lines («يكتب … المحضر»).
  static const String localDisplayName = 'النموذج المحلي';

  /// Name of the local-server engine in status lines.
  static const String serverDisplayName = 'الخادم المحلي';

  /// The on-device engine cannot run: its model is not downloaded.
  static const String localUnavailable =
      'لم يُنزَّل نموذج اللغة المحلي بعد. نزّله من الإعدادات ← محرك كتابة '
      'المحضر ← على الجهاز، أو اختر محركاً آخر.';

  /// The server engine cannot run: no model chosen.
  static const String serverUnavailable =
      'لم يُختر نموذج على الخادم المحلي. أدخل عنوان الخادم في الإعدادات، '
      'واضغط «اختبار الاتصال»، ثم اختر النموذج.';

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------

  /// Backend used after close.
  static const String engineClosed =
      'أُغلق محرك المحضر المحلي. أعد المحاولة.';

  /// The model's context window is too small for the prompt.
  static const String contextTooSmall =
      'نافذة السياق في النموذج أصغر من أن تتسع للتعليمات والنص. اختر نموذجاً '
      'أكبر، أو زِد طول السياق في إعدادات الخادم (LM Studio: Context Length).';

  /// The notes of one transcript part could not be read (shown in minutes
  /// notes through the final step).
  static const String chunkNotesUnreadable =
      'تعذّر استخراج ملاحظات هذا الجزء من الاجتماع بدقة؛ قد ينقص المحضر بعض '
      'ما دار فيه.';

  /// The local model could not be loaded.
  static String localLoadFailed(int ramGb) =>
      'تعذّر تحميل النموذج المحلي. قد لا تكفي ذاكرة الجهاز (يحتاج إلى نحو '
      '$ramGb غ.ب)، أو أن ملف النموذج تالف. أغلق التطبيقات الأخرى، أو اختر '
      'نموذجاً أصغر، أو احذف النموذج وأعد تنزيله.';

  /// The native runtime is missing on this device.
  static const String localRuntimeUnavailable =
      'محرك تشغيل النماذج المحلية غير متاح على هذا الجهاز. اختر محركاً آخر '
      'لكتابة المحضر.';

  /// Generation failed in the local runtime.
  static const String localGenerationFailed =
      'تعذّر على النموذج المحلي إكمال الكتابة. أعد المحاولة، أو اختر نموذجاً '
      'آخر.';

  /// The server cannot be reached.
  static String serverUnreachable(String url) =>
      'تعذّر الاتصال بالخادم المحلي على $url. تأكد من تشغيل Ollama أو '
      'LM Studio، ومن صحة العنوان والمنفذ، ومن أن الجهازين على الشبكة نفسها '
      '(ولخادم على جهاز آخر: اسمح له بالاستماع على الشبكة، مثل '
      'OLLAMA_HOST=0.0.0.0).';

  /// The server did not answer in time.
  static String serverTimeout(String url) =>
      'انتهت مهلة انتظار الخادم المحلي ($url). قد يكون النموذج كبيراً على '
      'الجهاز أو مشغولاً؛ أعد المحاولة.';

  /// The server stopped streaming.
  static const String serverStalled =
      'توقف الخادم المحلي عن الإرسال أثناء الكتابة. أعد المحاولة.';

  /// The chosen model is not on the server.
  static String serverModelMissing(String model, bool ollama) => ollama
      ? 'النموذج «$model» غير موجود على خادم Ollama. اختر نموذجاً من القائمة '
            'أو نزّله أولاً بالأمر: ollama pull $model'
      : 'النموذج «$model» غير متاح على الخادم. حمّله في LM Studio أولاً ثم '
            'اختره من القائمة.';

  /// The prompt exceeded the server's context length.
  static const String serverContextExceeded =
      'تجاوز النص طول السياق الذي حمّل به الخادم النموذج. زِد طول السياق '
      '(Context Length) في LM Studio ثم أعد التحميل، أو اختر نموذجاً آخر.';

  /// Other HTTP error.
  static String serverHttpError(int status, String? message) =>
      'أعاد الخادم المحلي خطأ ($status)${message == null ? '' : ': $message'}';

  /// The server answered but is neither Ollama nor OpenAI-compatible.
  static String serverNotRecognised(String url) =>
      'يستجيب العنوان $url لكنه لا يبدو خادم Ollama ولا خادماً متوافقاً مع '
      'OpenAI (مثل LM Studio). تحقق من العنوان والمنفذ.';

  // ---------------------------------------------------------------------------
  // Server settings
  // ---------------------------------------------------------------------------

  /// Section intro.
  static const String serverIntro =
      'يكتب المحضرَ نموذجٌ يعمل على خادم في جهازك أو في شبكتك المحلية '
      '(Ollama أو LM Studio). الجودة والسرعة تعتمدان على النموذج وقوة الجهاز؛ '
      'النماذج الصغيرة أقل دقة من المحركات السحابية.';

  /// Privacy line: the server is this device.
  static const String serverPrivacyLoopback =
      'الخادم على هذا الجهاز: لا يغادر نص الاجتماع جهازك.';

  /// Privacy line: the server is another device on the network.
  static const String serverPrivacyLan =
      'الخادم على جهاز آخر: يُرسَل نص الاجتماع إليه عبر الشبكة المحلية '
      '(دون تشفير إن كان العنوان يبدأ بـ http). استعمله على شبكة تثق بها.';

  /// API flavour selector label.
  static const String flavorLabel = 'نوع الخادم';

  /// Flavour: Ollama.
  static const String flavorOllama = 'Ollama';

  /// Flavour: OpenAI-compatible.
  static const String flavorOpenAi = 'LM Studio / OpenAI';

  /// URL field label.
  static const String urlLabel = 'عنوان الخادم';

  /// URL field helper.
  static const String urlHelper =
      'مثال: http://127.0.0.1:11434 لـ Ollama، أو http://127.0.0.1:1234/v1 '
      'لـ LM Studio، أو عنوان جهاز آخر في الشبكة مثل http://192.168.1.20:11434';

  /// Invalid URL.
  static const String urlInvalid =
      'أدخل عنواناً صحيحاً يبدأ بـ http:// أو https://';

  /// Save-URL tooltip.
  static const String saveUrl = 'حفظ العنوان';

  /// Test-connection button.
  static const String testConnection = 'اختبار الاتصال';

  /// Test running.
  static const String testing = 'جارٍ الاتصال بالخادم…';

  /// Connected.
  static String connected(String flavor, int models) =>
      'تم الاتصال بخادم $flavor. '
      '${models == 0 ? 'لا توجد عليه نماذج بعد.' : 'النماذج المتاحة: $models.'}';

  /// The flavour was detected and the URL adjusted.
  static String flavorDetected(String url) =>
      'اكتُشف نوع الخادم تلقائياً وحُفظ العنوان: $url';

  /// No models on the server.
  static const String noServerModels =
      'لا توجد نماذج على الخادم. نزّل نموذجاً أولاً، مثل: ollama pull qwen3:8b '
      '(أو حمّل نموذجاً في LM Studio).';

  /// Model picker label.
  static const String serverModelLabel = 'النموذج';

  /// Model picker hint.
  static const String serverModelHint = 'اختر نموذجاً';

  /// No model chosen yet.
  static const String serverModelNone =
      'لم يُختر نموذج بعد. اضغط «اختبار الاتصال» لعرض النماذج المتاحة.';

  /// Refresh models tooltip.
  static const String refreshModels = 'تحديث قائمة النماذج';

  /// Model chosen.
  static String serverModelChosen(String model) => 'اختير النموذج «$model».';

  /// Recommendation for server models.
  static const String serverModelAdvice =
      'يُنصح بنموذج يجيد العربية بحجم 7–14 مليار معامل على الأقل (مثل '
      'qwen3:8b أو qwen3:14b) للحصول على محضر جيد.';

  // ---------------------------------------------------------------------------
  // On-device settings
  // ---------------------------------------------------------------------------

  /// Section intro.
  static const String localIntro =
      'يعمل النموذج داخل التطبيق دون إنترنت ولا يغادر نص الاجتماع جهازك. '
      'المقابل: كتابة المحضر أبطأ بكثير (قد تستغرق دقائق لاجتماع طويل) '
      'وجودته أقل من المحركات السحابية، ويستهلك البطارية والذاكرة. '
      'الاجتماعات الطويلة تُعالَج على أجزاء ثم يُجمَع المحضر منها.';

  /// Download size advice.
  static const String downloadAdvice =
      'ملفات النماذج كبيرة؛ يُفضَّل تنزيلها عبر Wi-Fi مع توفر مساحة تخزين '
      'كافية.';

  /// Models list header.
  static const String modelsHeader = 'اختر النموذج';

  /// Recommended badge.
  static const String recommended = 'موصى به';

  /// Selected badge (semantics).
  static const String selected = 'مختار';

  /// Size and RAM line.
  static String sizeAndRam(String sizeGb, int ramGb) =>
      'الحجم: $sizeGb غ.ب • الذاكرة المطلوبة: $ramGb غ.ب أو أكثر';

  /// RAM note under the list.
  static const String ramNote =
      'إن كانت ذاكرة الجهاز أقل من المطلوب فقد يفشل تحميل النموذج أو يُغلق '
      'التطبيق أثناء الكتابة؛ اختر حينها نموذجاً أصغر.';

  /// Status: not downloaded.
  static const String notDownloaded = 'غير مُنزَّل';

  /// Status: ready.
  static const String downloaded = 'مُنزَّل وجاهز';

  /// Status: downloading with percent.
  static String downloading(int percent) => 'جارٍ التنزيل… $percent٪';

  /// Status: failed.
  static String failed(String? error) =>
      'فشل التنزيل${error == null ? '' : ': $error'}';

  /// Download button.
  static const String download = 'تنزيل';

  /// Cancel-download button.
  static const String cancelDownload = 'إلغاء التنزيل';

  /// Delete button.
  static const String deleteModel = 'حذف النموذج';

  /// Delete confirmation title.
  static const String deleteTitle = 'حذف النموذج؟';

  /// Delete confirmation body.
  static String deleteBody(String name, String sizeGb) =>
      'سيُحذف «$name» ($sizeGb غ.ب) من الجهاز، ويلزم تنزيله من جديد لاستعمال '
      'المحرك المحلي.';

  /// Delete refused: the model is generating right now.
  static const String modelInUse =
      'النموذج قيد الاستعمال الآن في كتابة محضر أو إجابة سؤال. أعد المحاولة '
      'بعد انتهائه.';

  /// Selected model is not downloaded.
  static const String selectedNotDownloaded =
      'النموذج المختار غير مُنزَّل بعد: نزّله لتفعيل كتابة المحضر على الجهاز.';

  /// Model chosen snack.
  static String modelChosen(String name) => 'اختير «$name».';

  /// Models could not be listed.
  static const String modelsLoadFailed =
      'تعذّر قراءة حالة النماذج على الجهاز.';
}
