// Arabic strings of the Groq engines (free plan): minutes / ask /
// consistency over Groq's OpenAI-compatible chat API, and cloud
// transcription with Groq Whisper. Modern Standard Arabic.

/// Groq strings.
abstract final class GS {
  /// Product name in status lines.
  static const String displayName = 'Groq';

  /// Where users create a free Groq key.
  static const String keyUrl = 'https://console.groq.com/keys';

  // ---------------------------------------------------------------- Errors

  /// No key stored (minutes).
  static const String keyMissing =
      'مفتاح Groq API غير مضبوط. أنشئ مفتاحاً مجانياً من console.groq.com/keys '
      'وأدخله في الإعدادات.';

  /// Notice not accepted (minutes).
  static const String privacyPending =
      'قبل إرسال نص الاجتماع إلى Groq، اقرأ تنبيه الخصوصية في الإعدادات '
      'ووافق عليه.';

  /// Key rejected.
  static const String keyInvalid =
      'رفضت خدمة Groq المفتاح (غير صالح أو أُلغي). تحقّق منه في الإعدادات.';

  /// Daily quota exhausted.
  static const String dailyQuota =
      'استُنفدت الحصة المجانية اليومية لخدمة Groq. أعد المحاولة غداً، أو '
      'اختر محركاً آخر من الإعدادات.';

  /// Per-minute limit with a long wait.
  static String minuteQuota(Duration wait) =>
      'بلغت حدّ الطلبات المجاني لخدمة Groq مؤقتاً (عدد محدود من الطلبات '
      'والكلمات في الدقيقة). حاول مجدداً بعد ${secondsAr(wait)}.';

  /// Too many attempts while rate limited.
  static const String minuteQuotaRepeated =
      'بلغت حدّ الطلبات المجاني لخدمة Groq عدة مرات متتالية. انتظر دقيقة ثم '
      'أعد المحاولة.';

  /// Even a minimal request exceeds the free per-minute token limit.
  static const String requestTooLarge =
      'الطلب أكبر من الحدّ المجاني لخدمة Groq في الدقيقة حتى بعد تقسيم '
      'الاجتماع. اختر نموذجاً آخر من الإعدادات أو محركاً آخر.';

  /// Model missing.
  static String modelMissing(String model) =>
      'النموذج «$model» غير متاح في حساب Groq. اختر نموذجاً آخر من الإعدادات '
      '(أو «اختيار تلقائي»).';

  /// No usable chat model.
  static const String noModel =
      'المفتاح صالح، لكن لا يتوفر في حساب Groq نموذج مناسب لكتابة المحاضر.';

  /// Network / server failure.
  static const String unavailable =
      'تعذّر الاتصال بخدمة Groq (الخدمة مشغولة أو الاتصال غير مستقر). حاول '
      'مرة أخرى بعد قليل.';

  /// Other HTTP failure.
  static String httpError(int status, String? message) =>
      'رفضت خدمة Groq الطلب (رمز $status)'
      '${message == null || message.isEmpty ? '' : ': $message'}.';

  // ------------------------------------------------------------ ASR errors

  /// No key (transcription).
  static const String asrKeyMissing =
      'اخترتَ التفريغ السحابي (Groq Whisper) لكن مفتاح Groq غير مضبوط. أضِف '
      'المفتاح من الإعدادات أو اختر التفريغ على الجهاز.';

  /// Transcription notice not accepted.
  static const String asrPrivacyPending =
      'اخترتَ التفريغ السحابي (Groq Whisper) ولم توافق بعد على تنبيه خصوصيته. '
      'وافق عليه في الإعدادات أو اختر التفريغ على الجهاز.';

  /// Key unreadable now (locked device).
  static const String asrKeyUnreadable =
      'تعذّرت قراءة مفتاح Groq المحفوظ الآن. افتح قفل الجهاز وحاول مجدداً.';

  /// Engine closed.
  static const String asrClosed = 'محرك التفريغ السحابي مُغلق.';

  /// Response not understood.
  static const String asrBadResponse = 'استجابة غير مفهومة من خدمة Groq.';

  /// Request rejected.
  static String asrRejected(int status) =>
      'رفضت خدمة Groq طلب التفريغ (رمز $status).';

  /// Network failure after retries.
  static const String asrUnreachable =
      'تعذّر الاتصال بخدمة التفريغ السحابي. تحقق من الاتصال بالإنترنت.';

  /// Quota exhausted for the meeting.
  static const String asrQuotaExhausted =
      'استُنفدت الحصة المجانية للتفريغ السحابي (Groq Whisper) الآن.';

  /// Fallback to on-device for the rest of the meeting.
  static const String asrFellBackToDevice =
      'استُنفدت الحصة المجانية للتفريغ السحابي (Groq Whisper)، فيكمل إنصاتو '
      'تفريغ بقية الاجتماع على جهازك.';

  /// No on-device model to fall back to.
  static const String asrNoDeviceFallback =
      'استُنفدت الحصة المجانية للتفريغ السحابي (Groq Whisper)، ونموذج Whisper '
      'غير مُنزَّل على الجهاز، فلن تُفرَّغ بقية المقاطع الآن. يمكنك إعادة '
      'معالجة الاجتماع من التسجيل لاحقاً.';

  // ------------------------------------------------------------- Settings

  /// Key label.
  static const String keyLabel = 'مفتاح Groq API';

  /// Key helper.
  static const String keyHelper =
      'أنشئ مفتاحاً مجانياً من GroqCloud (الرابط أدناه). يُحفظ مشفّراً في '
      'مخزن الجهاز الآمن ولا يُرسَل إلا إلى Groq. المفتاح نفسه يخدم المحضر '
      'والتفريغ السحابي.';

  /// Where to get a key.
  static const String keyWhere = 'احصل على مفتاح مجاني من:';

  /// Engine helper (minutes).
  static const String engineHelper =
      'Groq: نماذج مفتوحة كبيرة وسريعة جداً، مجانية بمفتاح من GroqCloud، مع '
      'حدود منخفضة لعدد الطلبات والكلمات في الدقيقة واليوم؛ تُقسَّم '
      'الاجتماعات الطويلة تلقائياً. يُرسَل نص الاجتماع فقط.';

  /// Privacy title (minutes).
  static const String privacyTitle = 'تنبيه خصوصية Groq';

  /// Privacy body (minutes).
  static const String privacyBody =
      'يُرسَل نص الاجتماع (دون الصوت) إلى خوادم Groq لمعالجته. تقول Groq في '
      'سياستها إنها لا تستخدم بيانات واجهة API لتدريب النماذج، لكنها تعالجها '
      'على خوادمها وقد تحتفظ بها مؤقتاً وفق سياستها؛ وهذا تعهّد من المزوّد '
      'وليس ضماناً من إنصاتو. لا تُرسِل عبره اجتماعات سرية؛ استخدم لها المحرك '
      'على الجهاز أو الخادم المحلي.';

  /// Model label.
  static const String modelLabel = 'نموذج Groq';

  /// Automatic model choice.
  static const String modelAuto = 'اختيار تلقائي (أكبر نموذج متاح)';

  /// Automatic choice with the model in use.
  static String modelAutoWith(String model) => 'اختيار تلقائي (حالياً: $model)';

  /// Model helper.
  static const String modelHelper =
      'يُختار تلقائياً أكبر نموذج Llama أو Qwen أو gpt-oss متاح لمفتاحك. اضغط '
      '«تحديث القائمة» لعرض النماذج المتاحة الآن.';

  /// Refresh the model list.
  static const String refreshModels = 'تحديث القائمة';

  /// Loading list.
  static const String loadingModels = 'جارٍ جلب النماذج من Groq…';

  /// Context size label.
  static String contextLabel(int tokens) => 'سياق ${tokens ~/ 1000} ألف رمز';

  /// Connection test OK.
  static const String testOk = 'الاتصال ناجح والمفتاح صالح.';

  /// No key entered for the test.
  static const String testNoKey = 'أدخل مفتاح Groq API أولاً.';

  /// Connection failed.
  static const String testUnreachable =
      'تعذّر الاتصال بخدمة Groq. تحقّق من اتصالك بالإنترنت.';

  /// ASR helper under the engine choice.
  static const String asrHelper =
      'تفريغ سحابي مجاني عبر Groq Whisper: أدق وأسرع على الأجهزة الضعيفة، '
      'لكن مقاطع الصوت تُرسَل إلى Groq. الحصة المجانية محدودة؛ وإذا نفدت أثناء '
      'اجتماع يكمل إنصاتو على الجهاز إن كان نموذج Whisper مُنزَّلاً. تبقى '
      'البصمات الصوتية على جهازك.';

  /// ASR privacy title.
  static const String asrPrivacyTitle = 'تنبيه خصوصية التفريغ السحابي';

  /// ASR privacy body.
  static const String asrPrivacyBody =
      'في التفريغ السحابي تُرسَل مقاطع الصوت المسجّلة إلى خوادم Groq لتحويلها '
      'إلى نص، ومعها بعض مصطلحات قاموسك لتحسين التعرّف عليها. تقول Groq في '
      'سياستها إنها لا تستخدم بيانات واجهة API لتدريب النماذج، لكنها تعالج '
      'الصوت على خوادمها وفق سياستها؛ وهذا تعهّد من المزوّد وليس ضماناً من '
      'إنصاتو. للاجتماعات السرية اختر التفريغ على الجهاز.';

  /// Whisper model label.
  static const String asrModelLabel = 'نموذج Groq Whisper';

  /// large-v3.
  static const String asrModelLargeV3 = 'large-v3 (الأدق)';

  /// large-v3-turbo.
  static const String asrModelTurbo = 'large-v3-turbo (أسرع)';

  /// Whisper model helper.
  static const String asrModelHelper =
      'large-v3 أدق في العربية؛ large-v3-turbo أسرع. كلاهما مجاني ضمن حصة '
      'Groq.';

  /// Fallback switch title.
  static const String fallbackTitle =
      'التبديل التلقائي إلى المحرك السحابي المجاني الآخر';

  /// Fallback switch subtitle.
  static const String fallbackSubtitle =
      'إذا نفدت الحصة اليومية للمحرك المختار (Gemini أو Groq) يُستخدم الآخر '
      'تلقائياً، بشرط أن يكون مفتاحه محفوظاً وتنبيه خصوصيته مقبولاً. وإن كان '
      'التبديل معطّلاً يُعرَض عليك عند الحاجة.';

  // --------------------------------------------------------------- Fallback

  /// Quota exhausted; another engine is offered.
  static String quotaOffer(String exhausted, String alternative) =>
      'استُنفدت الحصة المجانية اليومية لـ $exhausted. يمكنك كتابة المحضر الآن '
      'بـ $alternative (مضبوط لديك)، أو المحاولة غداً.';

  /// Button: use the other engine once.
  static String useAlternative(String alternative) =>
      'اكتب المحضر بـ $alternative';

  /// Status line when switching automatically.
  static String switching(String exhausted, String alternative) =>
      'نفدت حصة $exhausted اليومية، جارٍ التبديل إلى $alternative…';

  // ---------------------------------------------------------------- Helpers

  /// "N ثانية" / "N دقيقة" for a wait.
  static String secondsAr(Duration d) {
    final s = (d.inMilliseconds / 1000).ceil().clamp(1, 1 << 30);
    if (s < 120) return '$s ثانية';
    return '${(s / 60).ceil()} دقيقة';
  }
}
