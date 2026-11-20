// Arabic (MSA) UI strings of v1.2 C (multi-device recording).

import 'guest_client.dart' show JoinFailure;
import 'hub.dart' show NetworkQuality;

/// Arabic strings of the multi-device feature.
abstract final class MS {
  /// Menu / screen title (host).
  static const String hostEntry = 'اجتماع متعدد الأجهزة';

  /// Menu / screen title (guest).
  static const String guestEntry = 'الانضمام كجهاز إضافي';

  /// Menu tooltip.
  static const String menuTooltip = 'التسجيل بعدة أجهزة';

  /// Host screen intro.
  static const String hostIntro =
      'اجعل الهواتف والحواسيب الأخرى في القاعة ميكروفونات إضافية لهذا '
      'الاجتماع: افتح إنصاتو على كل جهاز، واختر «الانضمام كجهاز إضافي»، ثم '
      'امسح الرمز أو اكتبه. يصل حتى أربعة أجهزة.';

  /// Same network requirement.
  static const String sameNetwork =
      'يجب أن تكون جميع الأجهزة على شبكة Wi-Fi نفسها. لا حاجة إلى الإنترنت.';

  /// Privacy note shown on both sides.
  static const String privacyNote =
      'يبقى الصوت داخل الشبكة المحلية: يُرسل مشفّراً من كل جهاز إلى جهاز '
      'المضيف مباشرةً، ولا يمرّ بأي خادم.';

  /// Windows firewall note.
  static const String windowsFirewall =
      'على ويندوز: إذا ظهرت نافذة جدار الحماية فاسمح لإنصاتو على الشبكات '
      'الخاصة، وإلا فلن تتمكن الأجهزة الأخرى من الاتصال.';

  /// Label of the pairing code.
  static const String codeLabel = 'رمز الانضمام';

  /// Label of the address.
  static const String addressLabel = 'عنوان الجهاز المضيف';

  /// No LAN address found.
  static const String noAddress =
      'لم يُعثر على اتصال بشبكة محلية. اتصل بشبكة Wi-Fi ثم أعد المحاولة.';

  /// Opening the host.
  static const String opening = 'جارٍ تجهيز الاستضافة…';

  /// Hosting could not start.
  static const String hostStartFailed =
      'تعذّر بدء الاستضافة على الشبكة المحلية. تحقق من الاتصال بالشبكة ثم '
      'أعد المحاولة.';

  /// Start the meeting.
  static const String startMeeting = 'بدء الاجتماع';

  /// Back to the recording.
  static const String backToRecording = 'العودة إلى التسجيل';

  /// Stop hosting.
  static const String stopHosting = 'إيقاف الاستضافة';

  /// Hosting cannot stop while recording.
  static const String cannotStopWhileRecording =
      'لا يمكن إيقاف الاستضافة أثناء التسجيل؛ أنهِ الاجتماع أولاً.';

  /// Guests section title.
  static const String devicesTitle = 'الأجهزة المتصلة';

  /// No guest yet.
  static const String noDevices = 'لم ينضم أي جهاز بعد.';

  /// Device count line on the recording screen.
  static String devicesCount(int connected, int total) =>
      total == 0 ? 'لا أجهزة إضافية' : 'الأجهزة الإضافية: $connected من $total';

  /// Connected.
  static const String connected = 'متصل';

  /// Disconnected (meeting continues).
  static const String disconnected = 'انقطع الاتصال';

  /// Battery label.
  static String battery(int pct, bool? charging) =>
      'البطارية $pct٪${charging == true ? ' (يُشحن)' : ''}';

  /// Battery unknown.
  static const String batteryUnknown = 'البطارية غير معروفة';

  /// Network quality label.
  static String quality(NetworkQuality q) => switch (q) {
    NetworkQuality.good => 'الشبكة جيدة',
    NetworkQuality.fair => 'الشبكة متوسطة',
    NetworkQuality.poor => 'الشبكة ضعيفة',
  };

  /// Round trip.
  static String rtt(double ms) => '${ms.round()} مللي ثانية';

  /// Alignment locked.
  static const String aligned = 'متزامن';

  /// Alignment pending.
  static const String aligning = 'جارٍ التزامن';

  /// Remove action.
  static const String remove = 'إزالة';

  /// Remove confirmation title.
  static String removeTitle(String name) => 'إزالة «$name»؟';

  /// Remove confirmation body.
  static const String removeBody =
      'سيتوقف هذا الجهاز عن التسجيل ولن يستطيع الانضمام مجدداً إلى هذا '
      'الاجتماع. يستمر الاجتماع بباقي الأجهزة.';

  /// Cancel.
  static const String cancel = 'إلغاء';

  /// Unknown device name.
  static const String unnamedDevice = 'جهاز بلا اسم';

  /// Platform label.
  static String platform(String p) => switch (p) {
    'android' => 'أندرويد',
    'ios' => 'آيفون / آيباد',
    'windows' => 'ويندوز',
    _ => p,
  };

  // --- guest -------------------------------------------------------------

  /// Guest intro.
  static const String guestIntro =
      'يعمل هذا الجهاز ميكروفوناً إضافياً لاجتماع يُسجَّل على جهاز آخر. '
      'يُكتب المحضر على جهاز المضيف فقط.';

  /// Scan QR action.
  static const String scanQr = 'مسح رمز QR';

  /// Scanner hint.
  static const String scanHint =
      'وجّه الكاميرا إلى الرمز الظاهر على جهاز المضيف.';

  /// Scanner not available (Windows).
  static const String scanUnavailable =
      'مسح الرمز بالكاميرا غير متاح على هذا الجهاز؛ اكتب الرمز والعنوان.';

  /// Not an Insato code.
  static const String notAJoinCode = 'هذا ليس رمز انضمام من إنصاتو.';

  /// Discovered hosts title.
  static const String nearbyHosts = 'اجتماعات قريبة على الشبكة';

  /// Searching.
  static const String searching = 'جارٍ البحث في الشبكة…';

  /// Nothing found.
  static const String noneFound =
      'لم يُعثر على اجتماع قريب. اكتب العنوان الظاهر على جهاز المضيف.';

  /// Manual entry title.
  static const String manualEntry = 'إدخال يدوي';

  /// Code hint.
  static const String codeHint = 'مثل K7QM-2XPA-9DTR';

  /// Address hint.
  static const String addressHint = 'مثل 192.168.1.5:47800';

  /// Invalid code.
  static const String invalidCode =
      'الرمز من 12 حرفاً ورقماً كما يظهر على جهاز المضيف.';

  /// Invalid address.
  static const String invalidAddress =
      'اكتب العنوان والمنفذ كما يظهران على جهاز المضيف.';

  /// Device name field.
  static const String deviceName = 'اسم هذا الجهاز (يظهر للمضيف)';

  /// Join action.
  static const String join = 'انضمام';

  /// This device is an extra microphone of another meeting.
  static const String busyGuest =
      'يعمل هذا الجهاز الآن ميكروفوناً إضافياً لاجتماع آخر؛ غادره أولاً لبدء '
      'اجتماع جديد.';

  /// Already recording a meeting here.
  static const String busyRecording =
      'يسجّل هذا الجهاز اجتماعاً الآن؛ أنهِه قبل الانضمام كجهاز إضافي.';

  /// Join failure messages.
  static String joinFailure(JoinFailure f) => switch (f) {
    JoinFailure.unreachable =>
      'تعذّر الوصول إلى جهاز المضيف. تأكد أن الجهازين على شبكة Wi-Fi نفسها '
          'وأن العنوان صحيح، وعلى ويندوز اسمح لإنصاتو في جدار الحماية.',
    JoinFailure.rejectedOrWrongCode =>
      'رفض جهاز المضيف الاتصال. تحقق من رمز الانضمام.',
    JoinFailure.full => 'اكتمل عدد الأجهزة الإضافية لهذا الاجتماع (4 أجهزة).',
    JoinFailure.removed => 'أزال المضيف هذا الجهاز من الاجتماع.',
    JoinFailure.ended => 'انتهى الاجتماع.',
    JoinFailure.version =>
      'إصدار إنصاتو على هذا الجهاز لا يتوافق مع جهاز المضيف؛ حدّث التطبيق.',
  };

  /// Guest screen title.
  static const String guestTitle = 'جهاز إضافي';

  /// Phases.
  static const String connecting = 'جارٍ الاتصال بجهاز المضيف…';

  /// Waiting in the lobby.
  static const String waiting = 'متصل. بانتظار بدء الاجتماع على جهاز المضيف.';

  /// Recording.
  static const String recording = 'يسجّل ويرسل الصوت إلى جهاز المضيف';

  /// Paused.
  static const String paused = 'التسجيل متوقف مؤقتاً على جهاز المضيف';

  /// Reconnecting.
  static const String reconnecting =
      'انقطع الاتصال. جارٍ إعادة الاتصال… يستمر الاجتماع على جهاز المضيف.';

  /// Ended.
  static const String ended = 'انتهى الاجتماع. شكراً لك.';

  /// Removed.
  static const String removed = 'أزال المضيف هذا الجهاز من الاجتماع.';

  /// Gave up reconnecting.
  static const String gaveUp =
      'تعذّرت إعادة الاتصال بجهاز المضيف. يمكنك الانضمام من جديد.';

  /// Leave action.
  static const String leave = 'مغادرة';

  /// Done action.
  static const String done = 'تم';

  /// Guest notification title.
  static const String guestNotification = 'إنصاتو: جهاز إضافي في اجتماع';

  /// Host label.
  static String hostLabel(String name) => 'المضيف: $name';

  /// Meeting label.
  static String meetingLabel(String title) => 'الاجتماع: $title';

  /// Guest local-storage note.
  static const String guestNoStorage =
      'لا يُحفظ الصوت ولا النص على هذا الجهاز.';

  // --- meeting log ---------------------------------------------------------

  /// Log card title.
  static const String logTitle = 'التسجيل بعدة أجهزة';

  /// Devices line.
  static String logDevices(int n) =>
      'شارك $n من الأجهزة الإضافية مع جهاز المضيف.';

  /// Segments taken from a device.
  static String chosen(int n) => 'فُرّغ $n من المقاطع من صوته';

  /// A gap.
  static String gap(String device, String from, String? to) => to == null
      ? 'انقطع «$device» من $from حتى نهاية الاجتماع'
      : 'انقطع «$device» من $from إلى $to';

  /// A removal.
  static String removedAt(String device, String at) =>
      'أُزيل «$device» عند $at';

  /// No gaps.
  static const String noGaps = 'لم ينقطع أي جهاز.';
}
