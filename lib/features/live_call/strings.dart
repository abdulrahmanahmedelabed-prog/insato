// Arabic (MSA) UI strings of the live Insato call (v1.2).

import '../../core/time_format.dart' show formatArabicDateTime;
import 'call_engine.dart' show CallEndReason, CallPhase, CallQuality;

/// Arabic strings of the live-call feature.
abstract final class LCS {
  /// Feature name.
  static const String title = 'مكالمة إنصاتو الحية';

  /// Short entry label.
  static const String entry = 'مكالمة حية';

  /// Menu tooltip.
  static const String menuTooltip = 'مكالمة إنصاتو الحية';

  /// Intro on the start screen.
  static const String intro =
      'اتصال صوتي مباشر بين جهازين عليهما إنصاتو عبر الإنترنت (هاتف مع هاتف '
      'أو هاتف مع حاسوب). يفرّغ كل جهاز كلام من حوله لحظيًا، ويظهر النص '
      'المشترك على الشاشتين، ثم يُكتب المحضر بعد انتهاء المكالمة.';

  /// Start button.
  static const String startCall = 'بدء مكالمة';

  /// Start button subtitle.
  static const String startCallHint = 'يظهر رمز تعطيه للطرف الآخر.';

  /// Join button.
  static const String joinCall = 'الانضمام إلى مكالمة';

  /// Join button subtitle.
  static const String joinCallHint = 'أدخل الرمز أو امسحه من شاشة الطرف الآخر.';

  /// Privacy note.
  static const String privacyNote =
      'الصوت يمرّ مشفّرًا بين الجهازين مباشرةً (أو عبر خادم TURN مشفّرًا إن '
      'ضبطته). خادم الإشارة لا يرى إلا رسائل إعداد مشفّرة لا يستطيع قراءتها '
      'أو تزويرها.';

  /// Not configured banner.
  static const String notConfigured =
      'لم يُضبط خادم الإشارة بعد. أدخل عنوانه في إعدادات المكالمة الحية '
      '(يمكن نشره مجانًا، انظر دليل الإعداد).';

  /// Open settings.
  static const String openSettings = 'إعدادات المكالمة الحية';

  /// Busy.
  static const String busy =
      'يوجد تسجيل أو مكالمة قيد التشغيل. أنهِه أولًا ثم ابدأ المكالمة.';

  /// Consent required (thrown).
  static const String consentRequired =
      'قبل المكالمة الحية الأولى يجب تأكيد إشعار الموافقة.';

  /// Consent dialog title.
  static const String consentTitle = 'قبل المكالمة الحية';

  /// Consent dialog body.
  static const String consentBody =
      'أثناء المكالمة يُبث صوت ميكروفون هذا الجهاز إلى الجهاز الآخر، ويُفرَّغ '
      'كلام كل من يتحدث قرب الجهازين نصيًا، ويُحفظ النص والتسجيل كاجتماع، ثم '
      'يُرسل النص إلى محرك المحضر الذي اخترته.\n\n'
      'أبلغ كل الحاضرين حول الجهازين بذلك وخذ موافقتهم قبل البدء. يظهر مؤشر '
      'البث طوال المكالمة، ويستطيع أي طرف إيقافها بلمسة واحدة.';

  /// Consent accept.
  static const String consentAccept = 'أبلغتُ الحاضرين وأوافق';

  /// Cancel.
  static const String cancel = 'إلغاء';

  /// Close.
  static const String close = 'إغلاق';

  /// Join screen: code label.
  static const String codeLabel = 'رمز المكالمة';

  /// Join screen: code hint.
  static const String codeHint = 'مثل K7QM-2XPA-9DTR';

  /// Invalid code.
  static const String invalidCode =
      'الرمز غير صحيح: 12 حرفًا ورقمًا كما يظهر على الجهاز الآخر.';

  /// Scan QR.
  static const String scanQr = 'مسح رمز QR';

  /// Scanner hint.
  static const String scanHint = 'وجّه الكاميرا إلى رمز المكالمة على الجهاز الآخر.';

  /// Not a call code.
  static const String notACallCode = 'هذا ليس رمز مكالمة إنصاتو.';

  /// Join action.
  static const String join = 'انضمام';

  /// The caller's code.
  static const String yourCode = 'رمز المكالمة';

  /// Waiting.
  static const String waiting =
      'بانتظار انضمام الطرف الآخر… اطلب منه فتح إنصاتو واختيار «الانضمام '
      'إلى مكالمة» ثم مسح الرمز أو كتابته.';

  /// Preparing.
  static const String preparing = 'جارٍ التحضير…';

  /// Connecting.
  static const String connecting = 'جارٍ الاتصال بالطرف الآخر…';

  /// Reconnecting.
  static const String reconnecting = 'انقطع الاتصال، جارٍ إعادة الاتصال…';

  /// Ongoing indicator.
  static const String liveIndicator = 'يتم البث والتفريغ';

  /// Stop.
  static const String stop = 'إيقاف المكالمة';

  /// Mute.
  static const String mute = 'كتم الميكروفون';

  /// Unmute.
  static const String unmute = 'إلغاء الكتم';

  /// Muted chip.
  static const String mutedChip = 'الميكروفون مكتوم: لا يُبث صوتك ولا يُفرَّغ';

  /// Peer muted chip.
  static String peerMuted(String name) => '$name كتم ميكروفونه';

  /// Safety code label.
  static const String safetyCode = 'رمز الأمان';

  /// Safety code hint.
  static const String safetyHint =
      'يجب أن يظهر الرمز نفسه على الجهازين؛ إن اختلف فأنهِ المكالمة.';

  /// Transcript placeholder.
  static const String transcribing = 'جارٍ التفريغ…';

  /// Empty transcript.
  static const String noLinesYet = 'سيظهر هنا كلام الطرفين لحظة بلحظة.';

  /// "You" side label.
  static const String thisDevice = 'هذا الجهاز';

  /// Speaking now.
  static const String speakingNow = 'يتحدث الآن';

  /// Ended.
  static const String ended = 'انتهت المكالمة';

  /// Saving.
  static const String saving = 'جارٍ حفظ الاجتماع وإكمال التفريغ…';

  /// Saved.
  static const String saved = 'حُفظ الاجتماع، وسيُكتب المحضر بالمحرك المختار.';

  /// Open meeting.
  static const String openMeeting = 'فتح الاجتماع';

  /// New call.
  static const String newCall = 'مكالمة جديدة';

  /// Save failure.
  static const String saveFailed =
      'تعذّر إكمال حفظ المكالمة؛ بقي ما فُرِّغ أثناءها في الاجتماع.';

  /// Leave while live.
  static const String leaveTitle = 'إنهاء المكالمة؟';

  /// Leave while live body.
  static const String leaveBody =
      'لا يمكن مغادرة شاشة المكالمة أثناء البث. هل تريد إنهاء المكالمة؟';

  /// Transcription not available.
  static String transcriptionUnavailable(String reason) =>
      'يستمر الاتصال، لكن تعذّر بدء التفريغ على هذا الجهاز'
      '${reason.isEmpty ? '.' : ': $reason'}';

  /// Background warning.
  static const String backgroundWarning =
      'تعذّر تشغيل المكالمة في الخلفية؛ أبقِ التطبيق مفتوحًا أثناءها.';

  /// Notification channel.
  static const String notificationChannel = 'المكالمة الحية';

  /// Notification channel description.
  static const String notificationChannelDescription =
      'يظهر هذا الإشعار طوال مدة بث المكالمة الحية وتفريغها.';

  /// Notification title.
  static const String notificationTitle = 'إنصاتو: يتم البث والتفريغ';

  /// Notification text.
  static String notificationText(String peer) =>
      peer.isEmpty ? 'مكالمة حية جارية' : 'مكالمة حية مع $peer';

  /// Notification stop button.
  static const String notificationStop = 'إيقاف البث';

  /// Meeting title.
  static String meetingTitle(String peer, DateTime at) =>
      'مكالمة مع ${peer.isEmpty ? 'جهاز آخر' : peer} — '
      '${formatArabicDateTime(at)}';

  /// Status line of a phase.
  static String phase(CallPhase p) => switch (p) {
    CallPhase.idle || CallPhase.preparing => preparing,
    CallPhase.waitingForPeer => waiting,
    CallPhase.connecting => connecting,
    CallPhase.active => liveIndicator,
    CallPhase.reconnecting => reconnecting,
    CallPhase.ended || CallPhase.failed => ended,
  };

  /// Why a call ended.
  static String endReason(CallEndReason? r, String peer) {
    final who = peer.isEmpty ? 'الطرف الآخر' : peer;
    return switch (r) {
      null => ended,
      CallEndReason.localHangUp => 'أنهيتَ المكالمة.',
      CallEndReason.remoteHangUp => 'أنهى $who المكالمة.',
      CallEndReason.networkLost => 'انقطع الاتصال بالإنترنت ولم يُستعد.',
      CallEndReason.connectFailed =>
        'تعذّر الاتصال المباشر بين الجهازين (قد تحجبه الشبكة). جرّب شبكة '
            'أخرى أو اضبط خادم TURN في إعدادات المكالمة الحية.',
      CallEndReason.securityFailure =>
        'تعذّر التحقق من الطرف الآخر: الرمز غير صحيح أو حاول طرف ثالث '
            'التدخل. لم يُبث أي صوت.',
      CallEndReason.relayUnavailable =>
        'تعذّر الوصول إلى خادم الإشارة. تحقّق من الاتصال بالإنترنت ومن '
            'العنوان في الإعدادات.',
      CallEndReason.callFull => 'في هذه المكالمة جهازان بالفعل.',
      CallEndReason.notFound =>
        'لم يُعثر على مكالمة بهذا الرمز، أو انتهت مهلة الانتظار.',
      CallEndReason.deviceError =>
        'تعذّر تشغيل الميكروفون أو الاتصال على هذا الجهاز.',
    };
  }

  /// Quality label.
  static String quality(CallQuality q) => switch (q) {
    CallQuality.unknown => 'جودة الاتصال: قيد القياس',
    CallQuality.good => 'جودة الاتصال: جيدة',
    CallQuality.fair => 'جودة الاتصال: متوسطة',
    CallQuality.poor => 'جودة الاتصال: ضعيفة',
  };

  /// Via TURN.
  static const String viaTurn = 'عبر خادم TURN';

  /// Direct.
  static const String direct = 'اتصال مباشر';

  /// Round trip.
  static String rtt(int ms) => 'التأخير $ms ملّي ثانية';

  // Settings ---------------------------------------------------------------

  /// Settings tile subtitle.
  static const String settingsSubtitle =
      'خادم الإشارة، وخادم TURN، واسم الجهاز';

  /// Signaling URL label.
  static const String signalingUrl = 'عنوان خادم الإشارة';

  /// Signaling URL hint.
  static const String signalingUrlHint = 'wss://insato-signaling.example.workers.dev';

  /// Signaling help.
  static const String signalingHelp =
      'خادم صغير مجاني يعرّف الجهازين ببعضهما فقط، ولا يمرّ عبره الصوت. '
      'انشره مرة واحدة (Cloudflare Workers أو غيره) وفق دليل الإعداد، '
      'واستخدم العنوان نفسه على كل الأجهزة. من ينضم بمسح رمز QR يستخدم '
      'خادم المتصل تلقائيًا.';

  /// Built-in relay note.
  static String builtInRelay(String url) =>
      'إن تركتَ الحقل فارغًا يُستخدم الخادم المدمج: $url';

  /// Invalid URL.
  static const String invalidUrl =
      'العنوان غير صالح: يجب أن يبدأ بـ wss:// (أو ws:// للتجربة المحلية).';

  /// TURN section.
  static const String turnSection = 'خادم TURN (اختياري)';

  /// TURN help.
  static const String turnHelp =
      'يلزم فقط عندما تمنع الشبكة الاتصال المباشر (بعض شبكات الشركات '
      'والجوال). يمرّ الصوت عبره مشفّرًا ولا يستطيع سماعه.';

  /// TURN URL label.
  static const String turnUrl = 'عنوان TURN';

  /// TURN user.
  static const String turnUser = 'اسم المستخدم';

  /// TURN credential.
  static const String turnCredential = 'كلمة المرور';

  /// TURN credential stored.
  static const String turnCredentialSaved = 'محفوظة في مخزن المفاتيح الآمن';

  /// Relay only.
  static const String relayOnly = 'الاتصال عبر TURN فقط';

  /// Relay only hint.
  static const String relayOnlyHint =
      'يخفي عنوان IP لكل جهاز عن الآخر، ويتطلب خادم TURN.';

  /// Device name.
  static const String deviceName = 'اسم هذا الجهاز في المكالمات';

  /// Save.
  static const String save = 'حفظ';

  /// Saved toast.
  static const String settingsSaved = 'حُفظت إعدادات المكالمة الحية.';

  // Log --------------------------------------------------------------------

  /// History title.
  static const String history = 'سجل المكالمات';

  /// Log card title.
  static const String logTitle = 'سجل المكالمة الحية';

  /// Log: between.
  static String between(String a, String b) => 'بين «$a» و«$b»';

  /// Log event label.
  static String event(String kind, {required bool byRemote}) {
    final side = byRemote ? ' (الطرف الآخر)' : '';
    return switch (kind) {
      'start' => 'بدء البث',
      'stop' => 'إيقاف البث$side',
      'reconnecting' => 'انقطاع الاتصال',
      'reconnected' => 'عودة الاتصال',
      'mute' => 'كتم الميكروفون$side',
      'unmute' => 'إلغاء الكتم$side',
      _ => kind,
    };
  }
}
