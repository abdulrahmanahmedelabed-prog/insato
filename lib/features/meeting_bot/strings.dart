// Arabic (MSA) UI strings of the meeting bot.

import 'bot_audio.dart' show BotCaptureMode;
import 'bot_runner.dart' show BotEndReason, BotPhase;
import 'bot_scripts.dart' show BotPageState;
import 'meeting_link.dart' show MeetingLinkError, MeetingPlatform;

/// Arabic strings of the meeting bot.
abstract final class BotStrings {
  /// Screen / entry title.
  static const String title = 'روبوت الاجتماع';

  /// Tooltip of the app-bar entry.
  static const String entryTooltip =
      'إرسال روبوت إنصاتو إلى اجتماع Meet أو Teams أو Zoom أو Webex';

  /// Entry tile on the new-meeting form (Windows).
  static const String entryTile = 'اجتماع عبر الإنترنت؟ أرسل روبوت إنصاتو إليه';

  /// Entry tile subtitle.
  static const String entryTileSubtitle =
      'يدخل اجتماع Google Meet أو Microsoft Teams أو Zoom أو Webex ويسجّله '
      'ويكتب المحضر.';

  /// Intro on the screen.
  static const String intro =
      'يدخل إنصاتو اجتماعك على Google Meet أو Microsoft Teams أو Zoom أو '
      'Cisco Webex مشاركاً باسم '
      'واضح، وينتظر حتى يسمح له المنظّم بالدخول، ثم يسجّل صوت الاجتماع '
      'ويكتب المحضر كأي اجتماع آخر، ويغادر عند انتهاء الاجتماع.';

  /// Default bot name shown to the participants.
  static const String defaultBotName = 'إنصاتو — كاتب المحضر';

  /// Explanation off Windows.
  static const String windowsOnlyTitle = 'متاح في نسخة ويندوز فقط';

  /// Explanation off Windows (body).
  static const String windowsOnlyBody =
      'يعمل الروبوت بتشغيل متصفح Microsoft Edge مستقل على الحاسوب والتقاط '
      'صوته، وهذا غير ممكن على الهواتف والأجهزة اللوحية. استخدم إنصاتو على '
      'حاسوب يعمل بنظام ويندوز 10 أو 11 لإرسال الروبوت، أو سجّل الاجتماع من '
      'هاتفك بالميكروفون.';

  // ---------------------------------------------------------------------------
  // Form
  // ---------------------------------------------------------------------------

  /// Link field label.
  static const String linkLabel = 'رابط الاجتماع';

  /// Link field hint.
  static const String linkHint =
      'الصق رابط Meet أو Teams أو Zoom أو Webex، أو نص الدعوة كاملاً، أو '
      'معرّف اجتماع Zoom';

  /// Link error messages.
  static String linkError(MeetingLinkError error) => switch (error) {
    MeetingLinkError.empty => 'أدخل رابط الاجتماع.',
    MeetingLinkError.notALink =>
      'لم يُعثر على رابط اجتماع أو معرّف اجتماع Zoom في النص المُدخل.',
    MeetingLinkError.insecure => 'يجب أن يبدأ الرابط بـ https.',
    MeetingLinkError.unsupportedHost =>
      'هذا ليس رابط Google Meet أو Microsoft Teams أو Zoom أو Webex.',
    MeetingLinkError.invalidMeetCode =>
      'رمز اجتماع Google Meet غير صالح (مثال: abc-defg-hij).',
    MeetingLinkError.invalidTeamsLink =>
      'هذا الرابط من Teams لكنه ليس رابط اجتماع.',
    MeetingLinkError.invalidZoomLink =>
      'لم يُعثر على معرّف اجتماع Zoom صالح (من 9 إلى 11 رقماً).',
    MeetingLinkError.invalidWebexLink =>
      'هذا الرابط من Webex لكنه ليس رابط اجتماع.',
  };

  /// Service name.
  static String platformName(MeetingPlatform p) => switch (p) {
    MeetingPlatform.googleMeet => 'Google Meet',
    MeetingPlatform.teams => 'Microsoft Teams',
    MeetingPlatform.zoom => 'Zoom',
    MeetingPlatform.webex => 'Cisco Webex',
  };

  /// Passcode field (Zoom).
  static const String passcodeLabel = 'رمز مرور الاجتماع (إن وُجد)';

  /// Passcode helper.
  static const String passcodeHelper =
      'يُدخله الروبوت إذا طلبته صفحة Zoom. الروابط التي تحتوي pwd لا تحتاجه.';

  /// Webex is experimental.
  static const String webexExperimental =
      'دعم Webex تجريبي: قد تطلب بعض المواقع بريداً إلكترونياً أو حساباً '
      'للانضمام، وعندها لن يستطيع الروبوت الدخول.';

  /// Recognised link.
  static String detected(MeetingPlatform p, String id) =>
      'اجتماع ${platformName(p)}: $id';

  /// Name field label.
  static const String nameLabel = 'اسم الروبوت كما يراه المشاركون';

  /// Name field helper.
  static const String nameHelper =
      'اجعل الاسم يوضح أنه روبوت تسجيل حتى يعرف المشاركون ذلك.';

  /// Empty name.
  static const String nameEmpty = 'أدخل اسماً للروبوت.';

  /// Schedule header.
  static const String whenHeader = 'وقت الانضمام';

  /// Join now.
  static const String joinNow = 'الآن';

  /// Join later.
  static const String joinLater = 'في وقت محدد';

  /// Pick a time.
  static const String pickTime = 'اختيار الوقت';

  /// Scheduled time label.
  static String joinAt(String time) => 'ينضم الروبوت في $time';

  /// The time is in the past.
  static const String timeInPast = 'اختر وقتاً لاحقاً.';

  /// Schedule note.
  static const String scheduleNote =
      'ينضم الروبوت في الموعد ما دام إنصاتو مفتوحاً على هذا الحاسوب.';

  /// Show the browser window.
  static const String showWindow = 'إظهار نافذة متصفح الروبوت';

  /// Show the browser window (subtitle).
  static const String showWindowHint =
      'تبقى النافذة مصغّرة عادةً. أظهرها لمتابعة ما يفعله الروبوت.';

  /// Privacy header.
  static const String privacyHeader = 'الخصوصية والموافقة';

  /// Privacy notice.
  static const String privacyNotice =
      '• يظهر الروبوت لجميع المشاركين باسمه، ولا يدخل إلا إذا سمح له '
      'المنظّم؛ لا يتجاوز أي إعداد أمان للاجتماع.\n'
      '• لا يستخدم ميكروفونك ولا الكاميرا: ميكروفون الروبوت صامت دائماً '
      'والكاميرا مغلقة.\n'
      '• يُعالَج التسجيل على هذا الحاسوب مثل أي اجتماع آخر في إنصاتو.\n'
      '• عليك إبلاغ المشاركين بالتسجيل والحصول على موافقتهم وفق الأنظمة '
      'المعمول بها لديك ولدى جهتك.';

  /// Consent checkbox.
  static const String consentCheck =
      'أؤكد أنني مخوّل بتسجيل هذا الاجتماع وأن المشاركين سيُبلَّغون بذلك.';

  /// Start now.
  static const String start = 'إرسال الروبوت الآن';

  /// Schedule.
  static const String schedule = 'جدولة الروبوت';

  /// Windows / browser requirement.
  static const String requirement =
      'يتطلب متصفح Microsoft Edge (مثبّت مع ويندوز 10 و11) أو Google Chrome. '
      'لالتقاط صوت الاجتماع وحده يلزم Windows 10 الإصدار 2004 أو أحدث.';

  /// Join-flows version.
  static String scriptsVersion(String v) => 'إصدار مسارات الانضمام: $v';

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Status header.
  static const String statusHeader = 'حالة الروبوت';

  /// Phase line.
  static String phase(BotPhase phase, {String? botName, String? time}) =>
      switch (phase) {
        BotPhase.idle => 'لا يعمل',
        BotPhase.scheduled => 'مجدول: سينضم الروبوت في ${time ?? ''}',
        BotPhase.launching => 'جارٍ تشغيل المتصفح…',
        BotPhase.joining => 'جارٍ فتح الاجتماع وإدخال الاسم…',
        BotPhase.waitingAdmission =>
          'في غرفة الانتظار: بانتظار سماح المنظّم بدخول «${botName ?? ''}»…',
        BotPhase.recording => 'يسجّل الاجتماع الآن',
        BotPhase.leaving => 'جارٍ إنهاء التسجيل ومغادرة الاجتماع…',
        BotPhase.ended => 'انتهت مهمة الروبوت',
        BotPhase.failed => 'تعذّر إكمال مهمة الروبوت',
      };

  /// Detail of the page state while joining / waiting, when useful.
  static String? pageDetail(BotPageState? state) => switch (state) {
    BotPageState.notStarted =>
      'لم يبدأ المضيف الاجتماع بعد؛ سينتظر الروبوت حتى ساعة.',
    BotPageState.verification =>
      'يطلب الموقع تحققاً بشرياً (CAPTCHA). أُظهرت نافذة متصفح الروبوت: '
          'أكمل التحقق بنفسك خلال خمس دقائق، فالروبوت لا يتجاوزه.',
    _ => null,
  };

  /// Reason line.
  static String reason(BotEndReason reason) => switch (reason) {
    BotEndReason.userStopped => 'أوقفتَ الروبوت.',
    BotEndReason.meetingEnded => 'انتهى الاجتماع.',
    BotEndReason.everyoneLeft => 'غادر جميع المشاركين.',
    BotEndReason.removed => 'أُخرج الروبوت من الاجتماع.',
    BotEndReason.denied => 'رفض المنظّم دخول الروبوت.',
    BotEndReason.admissionTimeout =>
      'لم يسمح أحد بدخول الروبوت في الوقت المحدد.',
    BotEndReason.joinTimeout =>
      'تعذّر إكمال صفحة الانضمام؛ ربما تغيّرت واجهة الخدمة. جرّب إظهار نافذة '
          'المتصفح أو حدّث إنصاتو.',
    BotEndReason.invalidLink =>
      'الرابط أو رمز المرور غير صالح، أو انتهت صلاحية الاجتماع.',
    BotEndReason.notStarted => 'لم يبدأ المضيف الاجتماع في الوقت المحدد.',
    BotEndReason.verificationTimeout =>
      'لم يُكمَل التحقق البشري (CAPTCHA) الذي طلبه الموقع.',
    BotEndReason.guestsBlocked =>
      'هذا الاجتماع لا يقبل ضيوفاً دون حساب؛ اطلب من المنظّم السماح بذلك.',
    BotEndReason.browserClosed => 'أُغلق متصفح الروبوت.',
    BotEndReason.browserMissing =>
      'لم يُعثر على Microsoft Edge أو Google Chrome على هذا الحاسوب.',
    BotEndReason.launchFailed => 'تعذّر تشغيل متصفح الروبوت.',
    BotEndReason.recordingFailed => 'تعذّر بدء التسجيل.',
    BotEndReason.silenceTimeout => 'لم يُسمع أي صوت لمدة طويلة، فغادر الروبوت.',
    BotEndReason.callLost => 'لم تعد صفحة الاجتماع تُظهر المكالمة.',
    BotEndReason.pageUnresponsive => 'توقفت صفحة الاجتماع عن الاستجابة.',
    BotEndReason.busy => busyRecording,
    BotEndReason.unsupportedPlatform => windowsOnlyTitle,
  };

  /// Recording saved.
  static const String recordingSaved = 'حُفظ التسجيل ويُكتب المحضر كالمعتاد.';

  /// Capture note (process loopback).
  static const String captureProcess =
      'يُسجَّل صوت متصفح الروبوت وحده، لا ميكروفونك ولا أصوات الحاسوب الأخرى.';

  /// Capture warning (system loopback fallback).
  static const String captureSystem =
      'تنبيه: لا يدعم ويندوز لديك التقاط صوت تطبيق واحد (يتطلب Windows 10 '
      'الإصدار 2004 أو أحدث)، لذلك يُسجَّل كل ما يصدر من سماعات الحاسوب. '
      'أوقف الأصوات الأخرى، ولا تفتح الاجتماع نفسه في تطبيق آخر على هذا '
      'الحاسوب حتى لا يُسجَّل مرتين.';

  /// Capture line.
  static String capture(BotCaptureMode mode) => switch (mode) {
    BotCaptureMode.processLoopback => captureProcess,
    BotCaptureMode.systemLoopback => captureSystem,
  };

  /// Speakers note.
  static const String speakersNote =
      'يُشغَّل صوت الاجتماع على سماعات هذا الحاسوب أثناء التسجيل.';

  /// Stop (recording).
  static const String stop = 'إيقاف الروبوت وإنهاء التسجيل';

  /// Cancel (before recording).
  static const String cancel = 'إلغاء';

  /// Open the recording screen.
  static const String openRecording = 'شاشة التسجيل';

  /// Open the recorded meeting.
  static const String openMeeting = 'فتح الاجتماع';

  /// Send another bot.
  static const String again = 'إرسال الروبوت مجدداً';

  /// Recording since.
  static String recordingSince(String time) => 'بدأ التسجيل في $time';

  // ---------------------------------------------------------------------------
  // Recorder errors
  // ---------------------------------------------------------------------------

  /// Another recording runs.
  static const String busyRecording =
      'يوجد تسجيل قيد التشغيل؛ أوقفه قبل إرسال الروبوت.';

  /// No capture available.
  static const String captureUnsupported =
      'تعذّر التقاط صوت الاجتماع على هذا الحاسوب.';

  /// Title suffix of recorded meetings.
  static String meetingTitle(String base, MeetingPlatform p) =>
      '$base (${platformName(p)})';
}
