// Arabic (MSA) UI strings of the voice features: voice enrollment (F1) and
// external microphones (F18). Shared words (save, cancel, retry…) come from
// `S` in lib/ui/strings_ar.dart.

import 'audio_quality.dart';

/// Arabic strings of F1 / F18.
abstract final class VoiceStrings {
  // ---------------------------------------------------------------------------
  // F1 — Voice enrollment
  // ---------------------------------------------------------------------------

  /// Title of the enrollment screen for a new person.
  static const String enrollTitle = 'إضافة شخص بصوته';

  /// Title of the enrollment screen when improving a voiceprint.
  static String improveTitle(String name) => 'تحسين بصمة «$name»';

  /// Entry point (voice library / speaker menu): add a person by voice.
  static const String enrollAction = 'إضافة شخص بصوته';

  /// Entry point (speaker menu): improve the voiceprint.
  static const String improveAction = 'تحسين البصمة الصوتية';

  /// Short explanation shown above the form.
  static const String enrollIntro =
      'سجّل صوت الشخص وهو يقرأ الفقرة المعروضة لمدة 10–15 ثانية، ليتعرّف '
      'إنصاتو عليه باسمه من أول جملة في كل اجتماع. تُحفظ البصمة على هذا '
      'الجهاز فقط.';

  /// Explanation when improving.
  static const String improveIntro =
      'سجّل عيّنة جديدة من صوت هذا الشخص لتُضاف إلى بصمته الحالية؛ يفيد ذلك '
      'خاصةً إذا تغيّر الميكروفون أو أخطأ التطبيق في التعرّف عليه.';

  /// Name field label.
  static const String nameLabel = 'اسم الشخص';

  /// Name field hint.
  static const String nameHint = 'مثال: د. سارة الأحمد';

  /// Name required.
  static const String nameRequired = 'يُرجى كتابة اسم الشخص.';

  /// A named speaker with the same name exists.
  static String nameTaken(String name) =>
      'يوجد في مكتبة الأصوات شخص باسم «$name». يمكنك تحسين بصمته بدلًا من '
      'إضافة شخص جديد.';

  /// Button: improve the existing speaker with that name.
  static const String improveExisting = 'تحسين بصمته';

  /// Passage language selector label.
  static const String passageLanguage = 'لغة الفقرة';

  /// Arabic.
  static const String languageArabic = 'العربية';

  /// English.
  static const String languageEnglish = 'English';

  /// Another passage.
  static const String otherPassage = 'فقرة أخرى';

  /// Reading instruction.
  static const String readAloud =
      'اقرأ الفقرة التالية بصوت طبيعي وعلى بعد 20–50 سم من الميكروفون:';

  /// Start recording button.
  static const String startRecording = 'ابدأ التسجيل';

  /// Stop button.
  static const String stopRecording = 'إنهاء التسجيل';

  /// Record again button.
  static const String recordAgain = 'إعادة التسجيل';

  /// Save the voiceprint.
  static const String saveVoice = 'حفظ البصمة';

  /// Recording state label.
  static const String recording = 'جارٍ التسجيل… اقرأ الفقرة الآن';

  /// Keep reading prompt (not enough speech yet at the target duration).
  static const String keepReading =
      'استمر في القراءة؛ ما زال الكلام المسموع قليلًا.';

  /// Analysing.
  static const String analyzing = 'جارٍ تحليل التسجيل واستخراج البصمة…';

  /// Saving.
  static const String saving = 'جارٍ حفظ البصمة…';

  /// Elapsed / target, e.g. "0:07 من 0:15".
  static String elapsedOf(int elapsedMs, int targetMs) =>
      '${_clock(elapsedMs)} من ${_clock(targetMs)}';

  /// Voiced progress line.
  static String voicedProgress(int voicedMs, int targetMs) =>
      'كلام مسموع: ${_seconds(voicedMs)} من ${_seconds(targetMs)} ثانية';

  /// Semantics of the voiced progress bar.
  static const String voicedProgressLabel = 'مقدار الكلام المسموع';

  /// Saved (new person).
  static String savedNew(String name) =>
      'حُفظت بصمة «$name». سيتعرّف عليه إنصاتو باسمه في الاجتماعات القادمة.';

  /// Saved (improved).
  static String savedImproved(String name) => 'تحسّنت بصمة «$name».';

  /// Review header.
  static const String checksTitle = 'فحص جودة التسجيل';

  /// Check passed: enough speech.
  static String checkSpeech(int voicedMs) =>
      'مقدار الكلام: ${_seconds(voicedMs)} ثانية';

  /// Check: level.
  static String checkLevel(double dbfs) => 'مستوى الصوت: ${dbfs.round()} dBFS';

  /// Check: clipping none.
  static const String checkNoClipping = 'لا يوجد تشبّع (تقطيع) في الصوت';

  /// Check: voice consistency.
  static String checkConsistency(int percent) =>
      'ثبات الصوت عبر التسجيل: $percent٪';

  /// Message for a quality issue.
  static String issue(AudioQualityIssueKind kind) => switch (kind) {
    AudioQualityIssueKind.noSpeech =>
      'لم يُسمع أي كلام. تأكّد من الميكروفون واقرأ الفقرة بصوت مسموع.',
    AudioQualityIssueKind.tooLittleSpeech =>
      'الكلام المسموع أقل من 8 ثوانٍ. اقرأ الفقرة كاملة دون توقّف طويل.',
    AudioQualityIssueKind.clipping =>
      'الصوت مرتفع جدًا ومتشبّع. ابتعد قليلًا عن الميكروفون أو اخفض مستوى '
          'الإدخال.',
    AudioQualityIssueKind.someClipping =>
      'في التسجيل لحظات مرتفعة قليلًا. يمكن الحفظ، لكن الابتعاد قليلًا أفضل.',
    AudioQualityIssueKind.tooQuiet =>
      'الصوت منخفض جدًا. اقترب من الميكروفون وتحدّث بصوت أوضح.',
    AudioQualityIssueKind.quiet =>
      'الصوت منخفض قليلًا. يمكن الحفظ، لكن الاقتراب من الميكروفون أفضل.',
    AudioQualityIssueKind.noisy =>
      'الضجيج المحيط مرتفع مقارنةً بالصوت. يُفضّل التسجيل في مكان أهدأ.',
  };

  /// The take mixes voices / is too inconsistent.
  static const String inconsistentVoice =
      'يبدو أن التسجيل يضمّ أكثر من صوت أو ضجيجًا متقطّعًا. سجّل مرة أخرى '
      'بصوت شخص واحد فقط.';

  /// No voiceprint could be extracted.
  static const String noVoiceprint =
      'تعذّر استخراج بصمة صوتية من التسجيل. أعد التسجيل بصوت أوضح.';

  /// Similar voice found (new person).
  static String similarVoice(String name, int percent) =>
      'هذا الصوت يشبه كثيرًا بصمة «$name» المحفوظة '
      '(تشابه $percent٪). قد يكون الشخص نفسه.';

  /// Similar voice of an unnamed speaker: offer to name it.
  static String similarUnnamedVoice(String name, int percent) =>
      'هذا الصوت يشبه كثيرًا «$name» من اجتماعات سابقة '
      '(تشابه $percent٪). يمكنك ربط التسجيل به وتسميته، '
      'فتُحدَّث كل الاجتماعات السابقة بالاسم الجديد.';

  /// Button: add the sample to the similar speaker.
  static String addToSimilar(String name) => 'أضِف العيّنة إلى «$name»';

  /// Button: save as a different person anyway.
  static const String saveAsNewAnyway = 'حفظ كشخص مختلف';

  /// Recording refused while a meeting is being recorded.
  static const String busyRecording =
      'لا يمكن تسجيل بصمة أو اختبار الميكروفون أثناء تسجيل اجتماع. أنهِ '
      'التسجيل أولًا.';

  /// Speaker model missing.
  static const String speakerModelMissing =
      'يحتاج تسجيل البصمة إلى نموذجي «كشف الكلام» و«البصمة الصوتية». '
      'نزّلهما من صفحة النماذج ثم أعد المحاولة.';

  /// Open the models page.
  static const String openModels = 'فتح صفحة النماذج';

  /// The speaker being improved no longer exists.
  static const String speakerGone = 'لم يعد هذا المتحدث موجودًا في المكتبة.';

  /// Analysis failed.
  static const String analysisFailed =
      'تعذّر تحليل التسجيل. أعد المحاولة، وإن تكرّر الخطأ فأعد تنزيل نموذج '
      'البصمة الصوتية.';

  /// Device used for the take.
  static String recordedOn(String device) => 'سُجّلت على: $device';

  /// Bluetooth advisory on the enrollment screen.
  static const String bluetoothEnrollWarning =
      'الميكروفون الحالي سمّاعة بلوتوث، وجودة صوتها منخفضة. للحصول على بصمة '
      'دقيقة استخدم ميكروفون الجهاز أو ميكروفونًا سلكيًا أو USB.';

  // ---------------------------------------------------------------------------
  // F18 — Microphones
  // ---------------------------------------------------------------------------

  /// Settings section header.
  static const String micSection = 'الميكروفون';

  /// Device selector label.
  static const String inputDevice = 'جهاز الإدخال (الميكروفون)';

  /// Default device option.
  static const String defaultDevice = 'الميكروفون الافتراضي للنظام';

  /// Default device subtitle.
  static const String defaultDeviceHint =
      'يتبع إعدادات النظام، ويُستخدم تلقائيًا إذا فُصل الميكروفون المختار.';

  /// Refresh device list.
  static const String refreshDevices = 'تحديث قائمة الأجهزة';

  /// Choose device dialog title.
  static const String chooseDevice = 'اختر الميكروفون';

  /// Device list failed.
  static const String devicesFailed =
      'تعذّر الحصول على قائمة الميكروفونات. تأكّد من إذن الميكروفون ثم حدّث '
      'القائمة.';

  /// Loading devices.
  static const String loadingDevices = 'جارٍ البحث عن الميكروفونات…';

  /// Remembered device not connected.
  static String rememberedMissing(String label) =>
      'الميكروفون المحفوظ «$label» غير متصل الآن؛ سيُستخدم الافتراضي.';

  /// Device chosen confirmation.
  static String deviceChosen(String label) => 'سيُستخدم «$label» في التسجيل.';

  /// Default chosen confirmation.
  static const String defaultChosen = 'سيُستخدم الميكروفون الافتراضي.';

  /// Selection takes effect at the next recording.
  static const String appliesNextRecording =
      'يُطبَّق التغيير من التسجيل التالي.';

  /// Bluetooth badge.
  static const String bluetoothBadge = 'بلوتوث — جودة أقل';

  /// Bluetooth warning (narrow-band call profile).
  static const String bluetoothWarning =
      'ميكروفونات سمّاعات البلوتوث تعمل بنمط المكالمات منخفض الجودة '
      '(نطاق ترددي ضيق)، فتقلّ دقة التفريغ وتمييز المتحدثين، ولا تلتقط إلا '
      'صوت من يرتديها. للاجتماعات استخدم ميكروفون الجهاز أو ميكروفونًا '
      'سلكيًا أو USB.';

  /// Device type names.
  static String deviceType(String typeName) => switch (typeName) {
    'builtIn' => 'مدمج',
    'wiredHeadset' => 'سمّاعة سلكية',
    'lineIn' => 'مدخل خطّي',
    'bluetoothSco' || 'bluetoothA2dp' || 'bluetoothLe' => 'بلوتوث',
    'usb' => 'USB',
    'hdmi' => 'HDMI',
    'airPlay' => 'AirPlay',
    'thunderbolt' => 'Thunderbolt',
    'displayPort' => 'DisplayPort',
    _ => 'خارجي',
  };

  /// Far-field toggle title.
  static const String farField = 'اجتماع في قاعة';

  /// Far-field toggle subtitle.
  static const String farFieldHint =
      'للمتحدثين البعيدين عن الميكروفون: يضبط كشف الكلام ليلتقط الأصوات '
      'الخافتة، ويفعّل رفع الصوت التلقائي وتخفيف الضجيج حيث يدعمهما النظام '
      '(أندرويد). يُطبَّق من التسجيل التالي.';

  /// Mic test entry.
  static const String micTest = 'اختبار المايك';

  /// Mic test entry subtitle.
  static const String micTestHint =
      'استمع إلى تسجيل قصير وتحقّق من مستوى الصوت قبل الاجتماع.';

  /// Mic test intro.
  static const String micTestIntro =
      'تحدّث بصوتك الطبيعي من المكان الذي ستجلس فيه في الاجتماع، وراقب '
      'المؤشر. ثم سجّل 5 ثوانٍ واستمع إليها.';

  /// Start monitoring.
  static const String startMonitor = 'ابدأ الاستماع';

  /// Stop monitoring.
  static const String stopMonitor = 'إيقاف الاستماع';

  /// Record 5 s test.
  static const String recordTest = 'سجّل 5 ثوانٍ';

  /// Recording the test.
  static String recordingTest(int remainingMs) =>
      'جارٍ تسجيل الاختبار… ${_seconds(remainingMs)}';

  /// Play the test.
  static const String playTest = 'استمع إلى التسجيل';

  /// Stop playback.
  static const String stopPlayback = 'إيقاف التشغيل';

  /// Playback failed.
  static const String playbackFailed = 'تعذّر تشغيل تسجيل الاختبار.';

  /// Live hint: waiting.
  static const String hintWaiting = 'تحدّث ليُقاس مستوى الصوت…';

  /// Live hint: good.
  static const String hintGood = 'مستوى الصوت جيد.';

  /// Live hint: too quiet.
  static const String hintTooQuiet =
      'الصوت منخفض جدًا: اقترب من الميكروفون أو فعّل «اجتماع في قاعة».';

  /// Live hint: clipping.
  static const String hintClipping =
      'الصوت متشبّع: ابتعد قليلًا عن الميكروفون أو اخفض مستوى الإدخال.';

  /// Distance tip.
  static const String distanceTip =
      'نصيحة: ضع الميكروفون على بُعد 30–50 سم من المتحدث. في القاعات ضعه '
      'في منتصف الطاولة بعيدًا عن المكيّف والحاسوب، وفعّل «اجتماع في قاعة».';

  /// Result summary title.
  static const String testResult = 'نتيجة الاختبار';

  /// Result: OK.
  static const String testOk = 'الميكروفون جاهز للاجتماع.';

  /// Result: nothing heard.
  static const String testSilent =
      'لم يُسمع أي كلام في تسجيل الاختبار. تأكّد من اختيار الميكروفون الصحيح '
      'وأنه غير مكتوم.';

  /// Background noise level.
  static String noiseLevel(double dbfs) =>
      'مستوى الضجيج المحيط: ${dbfs.round()} dBFS';

  /// Test file could not be created.
  static const String testFileFailed =
      'تعذّر إنشاء ملف تسجيل الاختبار. تحقّق من مساحة التخزين.';

  /// Mid-meeting fallback warning.
  static String micDisconnected(String label) =>
      'فُصل الميكروفون «$label». يستمر التسجيل عبر الميكروفون الافتراضي دون '
      'توقّف.';

  /// Start-of-meeting fallback warning.
  static String micMissingAtStart(String label) =>
      'الميكروفون المختار «$label» غير متصل؛ يجري التسجيل عبر الميكروفون '
      'الافتراضي.';

  /// Voiceprint device line (speaker details).
  static String voiceLearnedOn(String device) => 'البصمة مسجّلة على: $device';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _clock(int ms) {
    final s = (ms / 1000).floor().clamp(0, 5999);
    final m = s ~/ 60;
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  static String _seconds(int ms) {
    final tenths = (ms / 100).round().clamp(0, 99999);
    final whole = tenths ~/ 10;
    final frac = tenths % 10;
    return frac == 0 ? '$whole' : '$whole.$frac';
  }
}
