// Arabic (MSA) UI strings of phone-call mode (وضع المكالمة الهاتفية).

/// Arabic strings of phone-call mode.
abstract final class PCS {
  /// Feature name.
  static const String title = 'وضع المكالمة الهاتفية';

  /// App-bar tooltip / menu entry.
  static const String menuTooltip = 'تسجيل مكالمة هاتفية';

  /// Setup screen intro.
  static const String intro =
      'فرِّغ مكالمة هاتفية عادية (شبكة الجوال، دون حاجة إلى إنترنت عند الطرف '
      'البعيد) في أثناء حدوثها، حين تجتمع مجموعة حول هاتف واحد بمكبّر الصوت.';

  // --- Modes ---------------------------------------------------------------

  /// Phone Link mode name.
  static const String modePhoneLink = 'عبر Phone Link على ويندوز';

  /// Phone Link mode description.
  static const String modePhoneLinkHint =
      'تستقبل المكالمة على الحاسوب عبر تطبيق Phone Link (البلوتوث). يُسجَّل '
      'صوت الطرف البعيد من صوت النظام وصوتك من الميكروفون في قناتين '
      'منفصلتين، فيُنسب كل كلام إلى طرفه بدقة. (الطريقة المفضّلة)';

  /// Phone Link unavailable here.
  static const String modePhoneLinkWindowsOnly =
      'متاح على ويندوز فقط. على هذا الجهاز استخدم طريقة مكبّر الصوت.';

  /// Speakerphone mode name.
  static const String modeSpeakerphone = 'مكبّر الصوت وجهاز ثانٍ';

  /// Speakerphone mode description.
  static const String modeSpeakerphoneHint =
      'تجري المكالمة بمكبّر الصوت على هاتف، ويسجّلها إنصاتو على جهاز آخر '
      'بالميكروفون. يعمل على أي جهاز، مع ملف «صوت الهاتف» المناسب للصوت '
      'ضيّق النطاق.';

  // --- Legal ---------------------------------------------------------------

  /// Legal notice title.
  static const String legalTitle = 'قبل التسجيل: القانون والموافقة';

  /// Legal notice.
  static const String legalBody =
      'تسجيل المكالمات الهاتفية تنظّمه قوانين تختلف من بلد إلى آخر، وكثير '
      'منها يشترط علم جميع الأطراف أو موافقتهم، وقد يُعدّ التسجيل دون إذن '
      'مخالفة. أبلِغ الطرف البعيد في بداية المكالمة بأنها تُسجَّل وتُفرَّغ '
      'لإعداد محضر، واحصل على موافقة الحاضرين في الطرفين.';

  /// Consent checkbox.
  static const String legalConfirm =
      'سأُبلغ جميع الأطراف بالتسجيل وأحصل على موافقتهم.';

  // --- Guide ---------------------------------------------------------------

  /// Guide title (Phone Link).
  static const String guideTitle = 'خطوات ربط الهاتف عبر Phone Link';

  /// Android tab.
  static const String android = 'أندرويد';

  /// iPhone tab.
  static const String iphone = 'آيفون';

  /// Android steps.
  static const List<String> androidSteps = [
    ('على الحاسوب: افتح تطبيق «Phone Link» (الربط بالهاتف) من قائمة ابدأ، '
        'واختر «Android».'),
    ('على الهاتف: ثبّت تطبيق «Link to Windows» (الربط بـ Windows) وسجّل '
        'الدخول بحساب Microsoft نفسه، ثم امسح رمز QR الظاهر على الحاسوب.'),
    ('فعّل البلوتوث في الجهازين، ثم من Phone Link افتح «المكالمات» واختر '
        '«إعداد»، واقبل طلب الاقتران على الهاتف وعلى الحاسوب.'),
    'اسمح على الهاتف بأذونات المكالمات وجهات الاتصال لتطبيق Link to Windows.',
    ('من Phone Link ← «المكالمات»: اطلب الرقم أو أجب عن المكالمة الواردة؛ '
        'سيُسمع الطرف البعيد من سمّاعات الحاسوب.'),
  ];

  /// iPhone steps.
  static const List<String> iphoneSteps = [
    'على الحاسوب: افتح تطبيق «Phone Link» (الربط بالهاتف) واختر «iPhone».',
    ('امسح رمز QR بكاميرا الآيفون وافتح الرابط، ثم أكّد رمز الاقتران عبر '
        'البلوتوث في الجهازين.'),
    ('على الآيفون: الإعدادات ← Bluetooth ← اسم الحاسوب (ⓘ)، وفعّل «مزامنة '
        'جهات الاتصال» و«إظهار الإشعارات».'),
    'أبقِ الآيفون قريباً من الحاسوب وفيه البلوتوث مفعّلاً طوال المكالمة.',
    ('من Phone Link ← «المكالمات»: اطلب الرقم أو أجب عن المكالمة الواردة؛ '
        'سيُسمع الطرف البعيد من سمّاعات الحاسوب.'),
  ];

  /// Shared tips (Phone Link).
  static const List<String> phoneLinkTips = [
    ('يفضَّل استخدام سمّاعات رأس موصولة بالحاسوب: يسمع الميكروفون حينها '
        'صوتك فقط. مع سمّاعات الحاسوب يحاول إنصاتو تمييز صدى الطرف البعيد '
        'وتجاهله.'),
    ('اختر في إعدادات ويندوز الميكروفون نفسه الذي تستخدمه في المكالمة، ولا '
        'تكتم صوت النظام: يُسجَّل الطرف البعيد مما يصدر من السمّاعات.'),
    ('أوقف الأصوات الأخرى على الحاسوب (الموسيقى والإشعارات) لأنها تُسجَّل '
        'مع الطرف البعيد.'),
  ];

  /// Speakerphone guide title.
  static const String speakerGuideTitle = 'خطوات المكالمة بمكبّر الصوت';

  /// Speakerphone steps.
  static const List<String> speakerSteps = [
    ('ضع الهاتف الذي تجري عليه المكالمة على الطاولة وشغّل مكبّر الصوت '
        'بمستوى مرتفع وواضح.'),
    ('ضع الجهاز الذي يعمل عليه إنصاتو قريباً من الهاتف (نحو نصف متر) وفي '
        'وسط الحاضرين، ولا تغطِّ الميكروفون.'),
    ('لا تشغّل التسجيل على الهاتف نفسه الذي تجري عليه المكالمة: أغلب الهواتف '
        'توقف الميكروفون عن التطبيقات الأخرى أثناء المكالمة.'),
    'أجرِ الفحص أدناه في أثناء المكالمة واطلب من الطرف البعيد التحدث.',
  ];

  // --- Language ------------------------------------------------------------

  /// Language choice label.
  static const String languageTitle = 'لغة المكالمة';

  /// Language choice hint.
  static const String languageHint =
      'تحديد اللغة يحسّن التعرّف على صوت الهاتف ضيّق النطاق.';

  /// As in Settings.
  static const String languageSettings = 'كما في الإعدادات';

  /// Auto-detect.
  static const String languageAuto = 'اكتشاف تلقائي';

  /// Arabic.
  static const String languageArabic = 'العربية';

  /// English.
  static const String languageEnglish = 'الإنجليزية';

  // --- Check ---------------------------------------------------------------

  /// Check section title.
  static const String checkTitle = 'فحص الصوت قبل التسجيل';

  /// Check hint (Phone Link).
  static const String checkHintPhoneLink =
      'ابدأ المكالمة ثم شغّل الفحص: تكلّم أنت ليتحرك مؤشر الميكروفون، واطلب '
      'من الطرف البعيد التحدث ليتحرك مؤشر صوت المكالمة.';

  /// Check hint (speakerphone).
  static const String checkHintSpeaker =
      'ابدأ المكالمة بمكبّر الصوت ثم شغّل الفحص، وتأكد من تحرّك المؤشر حين '
      'يتكلم الحاضرون وحين يتكلم الطرف البعيد.';

  /// Start check.
  static const String checkStart = 'بدء الفحص';

  /// Stop check.
  static const String checkStop = 'إيقاف الفحص';

  /// Local level label.
  static const String levelLocal = 'صوتك (الميكروفون)';

  /// Remote level label.
  static const String levelRemote = 'الطرف البعيد (صوت المكالمة)';

  /// Speakerphone level label.
  static const String levelRoom = 'الميكروفون (الحاضرون والهاتف)';

  /// Level seen.
  static const String levelOk = 'يعمل';

  /// Level not seen yet.
  static const String levelWaiting = 'في انتظار الصوت…';

  /// All good.
  static const String checkReady = 'الصوت جاهز للتسجيل.';

  /// Check could not start.
  static String checkFailed(String reason) => 'تعذّر بدء الفحص: $reason';

  // --- Start ---------------------------------------------------------------

  /// Start button.
  static const String start = 'بدء تسجيل المكالمة';

  /// Start anyway (check not completed).
  static const String startAnyway = 'البدء دون إكمال الفحص';

  /// Busy: a meeting is being recorded.
  static const String busy = 'يوجد تسجيل قيد التشغيل؛ أنهِه أولاً.';

  /// Armed banner.
  static const String armed = 'وضع المكالمة مفعّل للتسجيل التالي';

  /// Cancel call mode.
  static const String disarm = 'إلغاء وضع المكالمة';

  // --- Recording card ------------------------------------------------------

  /// Recording card title.
  static String recordingTitle(bool phoneLink) =>
      phoneLink ? '$title — Phone Link' : '$title — مكبّر الصوت';

  /// Segment counters.
  static String counters(int local, int remote) =>
      'مقاطع الطرف المحلي: $local · مقاطع الطرف البعيد: $remote';

  /// Unattributed counter.
  static String unattributed(int n) => 'مقاطع لم يُحدَّد طرفها: $n';

  /// Bleed counter.
  static String bleed(int n) => 'صدى السمّاعات المُتجاهَل: $n';

  /// Headphones advice.
  static const String headphones =
      'يلتقط الميكروفون صوت الطرف البعيد من السمّاعات كثيراً؛ استخدم سمّاعات '
      'رأس لنتيجة أدق.';

  /// Remote side label.
  static const String remoteSide = 'الطرف البعيد';

  /// Local side label.
  static const String localSide = 'الطرف المحلي';

  // --- Meeting card --------------------------------------------------------

  /// Meeting card title.
  static const String meetingCardTitle = 'اجتماع تضمّن مكالمة هاتفية';

  /// Mode line.
  static String modeLine(bool phoneLink) =>
      'طريقة الالتقاط: ${phoneLink ? modePhoneLink : modeSpeakerphone}';

  // --- Errors --------------------------------------------------------------

  /// Loopback missing (Phone Link).
  static const String loopbackUnavailable =
      'تعذّر تسجيل صوت النظام على هذا الحاسوب، وهو لازم لوضع Phone Link. '
      'استخدم طريقة مكبّر الصوت أو حدّث التطبيق.';

  /// Loopback did not start.
  static const String loopbackStartFailed =
      'تعذّر بدء تسجيل صوت المكالمة من الحاسوب. تأكد من وجود جهاز إخراج '
      'صوت مفعّل ثم أعد المحاولة.';

  /// Loopback lost on resume.
  static const String loopbackLost =
      'توقف تسجيل صوت المكالمة؛ يستمر تسجيل الميكروفون فقط.';

  /// Archive could not be created.
  static const String archiveFailed = 'تعذّر إنشاء ملف التسجيل الصوتي.';

  /// Archive write failed.
  static const String archiveWriteFailed =
      'تعذّر حفظ جزء من التسجيل الصوتي؛ يستمر التفريغ المباشر.';
}
