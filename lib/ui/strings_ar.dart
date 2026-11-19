// All user-facing UI strings of Insato (إنصاتو), in Modern Standard Arabic.
//
// Strings produced by lower layers (exceptions' `messageAr`, job status
// lines) are shown as they are; everything the UI itself says lives here so
// the wording stays consistent and reviewable in one place.

/// Arabic UI strings.
abstract final class S {
  // ---------------------------------------------------------------------------
  // App & navigation
  // ---------------------------------------------------------------------------

  /// App name.
  static const String appName = 'إنصاتو';

  /// App tagline.
  static const String appTagline = 'محاضر اجتماعات احترافية بالعربية';

  /// Navigation: meetings.
  static const String navMeetings = 'الاجتماعات';

  /// Navigation: voice library.
  static const String navSpeakers = 'المتحدثون';

  /// Navigation: settings.
  static const String navSettings = 'الإعدادات';

  /// Generic actions.
  static const String cancel = 'إلغاء';

  /// Save.
  static const String save = 'حفظ';

  /// Delete.
  static const String delete = 'حذف';

  /// Close.
  static const String close = 'إغلاق';

  /// Retry.
  static const String retry = 'إعادة المحاولة';

  /// Confirm.
  static const String confirm = 'تأكيد';

  /// Rename.
  static const String rename = 'إعادة التسمية';

  /// Dismiss a message.
  static const String dismiss = 'تجاهل';

  /// Copied to clipboard.
  static const String copied = 'تم النسخ إلى الحافظة.';

  /// Generic unexpected error.
  static const String unexpectedError = 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  /// Loading.
  static const String loading = 'جارٍ التحميل…';

  // ---------------------------------------------------------------------------
  // Meetings list
  // ---------------------------------------------------------------------------

  /// FAB label.
  static const String newMeeting = 'اجتماع جديد';

  /// Shortcut hint for Ctrl+N.
  static const String newMeetingShortcut = 'اجتماع جديد (Ctrl+N)';

  /// Search hint.
  static const String searchMeetings = 'ابحث في الاجتماعات';

  /// Clear search.
  static const String clearSearch = 'مسح البحث';

  /// Empty list title.
  static const String noMeetingsTitle = 'لا توجد اجتماعات بعد';

  /// Empty list body.
  static const String noMeetingsBody =
      'اضغط «اجتماع جديد» ليبدأ إنصاتو بالاستماع وتفريغ الكلام وتمييز '
      'المتحدثين، ثم يكتب لك محضرًا عربيًا احترافيًا.';

  /// No search results.
  static const String noSearchResults = 'لا توجد اجتماعات مطابقة لبحثك.';

  /// Delete meeting dialog title.
  static const String deleteMeetingTitle = 'حذف الاجتماع؟';

  /// Delete meeting dialog body.
  static String deleteMeetingBody(String title) =>
      'سيُحذف «$title» نهائيًا مع نصه الكامل ومحضره وتسجيله الصوتي. '
      'تبقى البصمات الصوتية للمتحدثين محفوظة.';

  /// Snackbar after deleting.
  static const String meetingDeleted = 'تم حذف الاجتماع.';

  /// Select a meeting (wide layout placeholder).
  static const String selectMeetingTitle = 'اختر اجتماعًا';

  /// Select a meeting body.
  static const String selectMeetingBody =
      'اختر اجتماعًا من القائمة لعرض محضره ونصه الكامل ومتحدثيه.';

  /// Number of speakers.
  static String speakersCount(int n) => switch (n) {
    0 => 'لا متحدثين',
    1 => 'متحدث واحد',
    2 => 'متحدثان',
    >= 3 && <= 10 => '$n متحدثين',
    _ => '$n متحدثًا',
  };

  /// Number of segments.
  static String segmentsCount(int n) => switch (n) {
    0 => 'لا مقاطع',
    1 => 'مقطع واحد',
    2 => 'مقطعان',
    >= 3 && <= 10 => '$n مقاطع',
    _ => '$n مقطعًا',
  };

  /// Number of meetings.
  static String meetingsCount(int n) => switch (n) {
    0 => 'لم يظهر في أي اجتماع',
    1 => 'اجتماع واحد',
    2 => 'اجتماعان',
    >= 3 && <= 10 => '$n اجتماعات',
    _ => '$n اجتماعًا',
  };

  // ---------------------------------------------------------------------------
  // Meeting status
  // ---------------------------------------------------------------------------

  /// Status: recording.
  static const String statusRecording = 'قيد التسجيل';

  /// Status: processing.
  static const String statusProcessing = 'قيد المعالجة';

  /// Status: ready.
  static const String statusReady = 'جاهز';

  /// Status: failed.
  static const String statusFailed = 'تعذّرت المعالجة';

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Recording screen title.
  static const String recordingTitle = 'تسجيل الاجتماع';

  /// Pause.
  static const String pause = 'إيقاف مؤقت';

  /// Resume.
  static const String resume = 'استئناف';

  /// Stop.
  static const String stop = 'إنهاء الاجتماع';

  /// Cancel recording.
  static const String discardRecording = 'تجاهل التسجيل';

  /// Recording state labels.
  static const String stateRecording = 'يسجّل الآن';

  /// Paused label.
  static const String statePaused = 'متوقف مؤقتًا';

  /// Preparing label.
  static const String statePreparing = 'جارٍ التحضير…';

  /// Finishing label.
  static const String stateFinishing = 'جارٍ إنهاء الاجتماع…';

  /// Confirm stop title.
  static const String confirmStopTitle = 'إنهاء الاجتماع؟';

  /// Confirm stop body.
  static const String confirmStopBody =
      'سيتوقف التسجيل، ويُكمل إنصاتو تفريغ ما تبقّى من الكلام، ثم يحسّن تمييز '
      'المتحدثين ويكتب المحضر.';

  /// Confirm discard title.
  static const String confirmDiscardTitle = 'تجاهل هذا التسجيل؟';

  /// Confirm discard body.
  static const String confirmDiscardBody =
      'سيُحذف التسجيل ونصه نهائيًا، ولن يُكتب له محضر. لا يمكن التراجع عن ذلك.';

  /// Discard button.
  static const String discard = 'تجاهل وحذف';

  /// The take ended on its own before the discard was confirmed.
  static const String discardTooLate =
      'انتهى التسجيل قبل تأكيد التجاهل، فحُفظ الاجتماع. يمكنك حذفه من قائمة '
      'الاجتماعات إن شئت.';

  /// Finish-later action on the finishing overlay.
  static const String finishLater = 'إنهاء لاحقًا';

  /// Explanation shown above [finishLater].
  static const String finishLaterHint =
      'يمكنك حفظ الاجتماع الآن دون انتظار اكتمال التفريغ، ثم إعادة معالجته '
      'من التسجيل الصوتي لاحقًا.';

  /// Finish later is no longer possible.
  static const String finishLaterUnavailable =
      'لم يعد ذلك ممكنًا؛ أوشك التفريغ على الاكتمال.';

  /// Live transcription suspended because it fell too far behind.
  static const String liveTranscriptionPaused =
      'التفريغ المباشر متوقف مؤقتًا، والتسجيل مستمر';

  /// Live transcript empty.
  static const String listeningHint =
      'إنصاتو يستمع… سيظهر النص هنا بعد أول جملة مكتملة.';

  /// Current speaker label.
  static const String currentSpeaker = 'المتحدث الحالي';

  /// No speaker yet.
  static const String noSpeakerYet = 'لم يُحدَّد بعد';

  /// Backlog indicator.
  static String backlog(int segments, int audioMs) =>
      'بانتظار التفريغ: ${segmentsCount(segments)} '
      '(${(audioMs / 1000).round()} ث)';

  /// Processing behind warning.
  static const String processingBehind =
      'التفريغ متأخر عن الكلام بأكثر من دقيقة؛ سيكتمل بعد انتهاء الاجتماع.';

  /// Failed segments indicator.
  static String failedSegments(int n) => 'تعذّر تفريغ ${segmentsCount(n)}';

  /// Edit title.
  static const String editTitle = 'تعديل العنوان';

  /// Meeting title field label.
  static const String meetingTitleLabel = 'عنوان الاجتماع';

  /// Live transcript header.
  static const String liveTranscript = 'النص المباشر';

  /// Back to recording banner.
  static const String recordingInProgress = 'يوجد اجتماع قيد التسجيل';

  /// Back to recording action.
  static const String backToRecording = 'العودة إلى التسجيل';

  /// Keyboard shortcut hint on desktop.
  static const String spaceShortcutHint = 'مسافة: إيقاف مؤقت/استئناف';

  /// Microphone level semantics.
  static const String micLevel = 'مستوى صوت الميكروفون';

  /// Elapsed time semantics.
  static const String elapsedTime = 'مدة التسجيل';

  /// No active recording.
  static const String noActiveRecording = 'لا يوجد تسجيل قيد التشغيل.';

  /// Open meeting.
  static const String openMeeting = 'فتح الاجتماع';

  /// Engine label.
  static String engine(String e) => 'محرك التفريغ: $e';

  // ---------------------------------------------------------------------------
  // Consent
  // ---------------------------------------------------------------------------

  /// Consent dialog title.
  static const String consentTitle = 'قبل أول تسجيل';

  /// Consent body.
  static const String consentBody =
      'سيسجّل إنصاتو كل ما يلتقطه الميكروفون، ويفرّغه نصًا، ويميّز المتحدثين '
      'من خلال بصماتهم الصوتية.\n\n'
      'تسجيل الآخرين دون علمهم قد يخالف القانون أو سياسات جهة العمل. يجب '
      'إبلاغ جميع المشاركين بأن الاجتماع يُسجَّل والحصول على موافقتهم قبل '
      'البدء.\n\n'
      'تُحفظ التسجيلات والنصوص والبصمات الصوتية على جهازك. لكتابة المحضر '
      'يُرسَل نص الاجتماع فقط (دون الصوت) إلى محرك المحضر الذي تختاره في '
      'الإعدادات: Gemini من Google (الافتراضي، مجاني) أو Claude. في الفئة '
      'المجانية من Gemini قد تستخدم Google النصوص المرسلة لتحسين منتجاتها وقد '
      'يطّلع عليها مراجعون بشريون؛ فلا تستخدمها للاجتماعات السرية. وإذا اخترت '
      'التفريغ السحابي تُرسَل مقاطع الصوت إلى Deepgram لمعالجتها؛ يطلب إنصاتو '
      'من Deepgram عدم استخدامها في تدريب نماذجها، لكن مدة احتفاظها بها تخضع '
      'لسياسة بياناتها.';

  /// Consent checkbox.
  static const String consentCheckbox =
      'سأُبلغ المشاركين بالتسجيل وأحصل على موافقتهم.';

  /// Accept consent.
  static const String consentAccept = 'موافق، ابدأ التسجيل';

  // ---------------------------------------------------------------------------
  // Start errors
  // ---------------------------------------------------------------------------

  /// Models missing action.
  static const String openModels = 'فتح النماذج';

  /// Open settings action.
  static const String openSettings = 'فتح الإعدادات';

  /// Start failed title.
  static const String startFailedTitle = 'تعذّر بدء التسجيل';

  // ---------------------------------------------------------------------------
  // Meeting detail
  // ---------------------------------------------------------------------------

  /// Tab: minutes.
  static const String tabMinutes = 'المحضر';

  /// Tab: transcript.
  static const String tabTranscript = 'النص الكامل';

  /// Tab: speakers.
  static const String tabSpeakers = 'المتحدثون';

  /// Meeting not found.
  static const String meetingNotFound = 'الاجتماع غير موجود أو حُذف.';

  /// Share text.
  static const String shareText = 'مشاركة نصًا';

  /// Export PDF.
  static const String exportPdf = 'تصدير PDF';

  /// Print.
  static const String printPdf = 'طباعة';

  /// Export Markdown.
  static const String exportMarkdown = 'تصدير Markdown';

  /// Copy minutes.
  static const String copyMinutes = 'نسخ المحضر';

  /// Copy transcript.
  static const String copyTranscript = 'نسخ النص الكامل';

  /// Rename meeting.
  static const String renameMeeting = 'تعديل عنوان الاجتماع';

  /// Delete meeting.
  static const String deleteMeeting = 'حذف الاجتماع';

  /// Reprocess.
  static const String reprocess = 'إعادة المعالجة من التسجيل الصوتي';

  /// Reprocess confirm title.
  static const String reprocessTitle = 'إعادة معالجة الاجتماع؟';

  /// Reprocess confirm body.
  static const String reprocessBody =
      'سيُعاد تفريغ التسجيل الصوتي بالكامل وتمييز متحدثيه بالإعدادات '
      'والنماذج الحالية، ويُستبدل النص الحالي. تُحفظ تصحيحاتك للمتحدثين قدر '
      'الإمكان. قد يستغرق ذلك وقتًا مقاربًا لمدة الاجتماع.';

  /// Reprocess action.
  static const String reprocessAction = 'إعادة المعالجة';

  /// Refine speakers.
  static const String refineSpeakers = 'إعادة تمييز المتحدثين';

  /// No audio file.
  static const String noAudio = 'لا يوجد تسجيل صوتي محفوظ لهذا الاجتماع.';

  /// Export include transcript.
  static const String includeTranscript = 'إرفاق النص الكامل';

  /// Exported file saved.
  static String savedTo(String path) => 'حُفظ الملف في: $path';

  /// Export failed.
  static const String exportFailed = 'تعذّر تصدير الملف.';

  /// Need minutes first.
  static const String noMinutesToExport =
      'لا يوجد محضر بعد. أنشئ المحضر أولًا.';

  /// Recording in progress note on detail.
  static const String meetingStillRecording =
      'هذا الاجتماع قيد التسجيل الآن. سيظهر المحضر بعد إنهائه.';

  // ---------------------------------------------------------------------------
  // Minutes
  // ---------------------------------------------------------------------------

  /// Summary.
  static const String summary = 'الملخص';

  /// Attendees.
  static const String attendees = 'الحضور';

  /// Topics.
  static const String topics = 'محاور النقاش';

  /// Decisions.
  static const String decisions = 'القرارات';

  /// Action items.
  static const String actionItems = 'المهام والإجراءات';

  /// Open questions.
  static const String openQuestions = 'مسائل معلّقة';

  /// Next meeting.
  static const String nextMeeting = 'الاجتماع القادم';

  /// Notes.
  static const String notes = 'ملاحظات';

  /// Languages.
  static const String languages = 'اللغات المستخدمة';

  /// Task column.
  static const String task = 'المهمة';

  /// Owner column.
  static const String owner = 'المسؤول';

  /// Due column.
  static const String due = 'الموعد';

  /// Not specified.
  static const String notSpecified = 'غير محدد';

  /// Proposed by.
  static String proposedBy(String name) => 'اقترحه: $name';

  /// Speakers in topic.
  static String topicSpeakers(String names) => 'تحدّث فيه: $names';

  /// Generated by model.
  static String generatedBy(String model, String date) =>
      'أُنشئ بواسطة $model في $date';

  /// None.
  static const String noneRecorded = 'لا يوجد.';

  /// Generate minutes.
  static const String generateMinutes = 'إنشاء المحضر';

  /// Regenerate minutes.
  static const String regenerateMinutes = 'إعادة إنشاء المحضر';

  /// Regenerate hint.
  static const String regenerateHint =
      'أعد إنشاء المحضر بعد تصحيح أسماء المتحدثين ليظهروا بأسمائهم.';

  /// No minutes yet.
  static const String noMinutesTitle = 'لم يُنشأ المحضر بعد';

  /// No minutes body.
  static const String noMinutesBody =
      'يكتب إنصاتو المحضر بالعربية الفصحى من النص الكامل باستخدام محرك المحضر '
      'المختار في الإعدادات.';

  /// Minutes engine not ready.
  static const String apiKeyMissingTitle = 'محرك المحضر غير جاهز';

  /// Minutes engine not ready body.
  static const String apiKeyMissingBody =
      'أضِف مفتاح محرك المحضر من الإعدادات ليكتب إنصاتو المحضر؛ مفتاح Gemini '
      'مجاني من Google AI Studio. يُرسَل نص الاجتماع فقط، ولا يُرسَل الصوت.';

  /// Add key.
  static const String addApiKey = 'ضبط محرك المحضر';

  /// Processing note.
  static const String meetingProcessing = 'جارٍ معالجة الاجتماع وكتابة المحضر…';

  // ---------------------------------------------------------------------------
  // Transcript
  // ---------------------------------------------------------------------------

  /// Empty transcript.
  static const String noTranscriptTitle = 'لا يوجد نص';

  /// Empty transcript body.
  static const String noTranscriptBody = 'لم يُلتقط أي كلام في هذا الاجتماع.';

  /// Unknown speaker.
  static const String unknownSpeaker = 'متحدث غير محدد';

  /// Segment sheet title.
  static const String segmentSheetTitle = 'تعديل المقطع';

  /// Who said this.
  static const String whoSaidThis = 'من قال هذا؟';

  /// New speaker option.
  static const String newSpeaker = 'متحدث جديد';

  /// Remove speaker option.
  static const String noSpeaker = 'بلا متحدث';

  /// Edit text.
  static const String editText = 'تعديل النص';

  /// Text field label.
  static const String segmentText = 'نص المقطع';

  /// Delete segment.
  static const String deleteSegment = 'حذف المقطع';

  /// Locked indicator.
  static const String lockedByUser = 'حدّدتَ المتحدث يدويًا';

  /// Reassigned.
  static const String speakerAssigned = 'تم تعيين المتحدث.';

  /// Text saved.
  static const String textSaved = 'تم حفظ النص.';

  /// Text empty.
  static const String textEmpty = 'لا يمكن أن يكون النص فارغًا.';

  /// Segment deleted.
  static const String segmentDeleted = 'تم حذف المقطع.';

  /// Language label.
  static String languageTag(String code) => languageName(code) ?? code;

  // ---------------------------------------------------------------------------
  // Speakers
  // ---------------------------------------------------------------------------

  /// Rename speaker title.
  static const String renameSpeakerTitle = 'تسمية المتحدث';

  /// Rename speaker explanation.
  static const String renameSpeakerBody =
      'سيتذكّر إنصاتو هذا الاسم ويتعرّف على صوت هذا الشخص تلقائيًا في '
      'الاجتماعات القادمة. يتغيّر الاسم في جميع الاجتماعات.';

  /// Name label.
  static const String speakerNameLabel = 'الاسم';

  /// Name empty.
  static const String nameEmpty = 'يُرجى إدخال اسم.';

  /// Renamed.
  static const String speakerRenamed = 'تم حفظ الاسم.';

  /// Merge.
  static const String merge = 'دمج مع متحدث آخر';

  /// Merge title.
  static String mergeTitle(String name) => 'دمج «$name» مع…';

  /// Merge body.
  static const String mergeBody =
      'اختر الشخص نفسه. ستنتقل جميع مقاطع هذا المتحدث في كل الاجتماعات '
      'إليه، وتُدمج البصمتان الصوتيتان.';

  /// Merge confirm.
  static String mergeConfirm(String from, String into) =>
      'دمج «$from» في «$into»؟ لا يمكن التراجع عن ذلك.';

  /// Merged.
  static const String speakersMerged = 'تم دمج المتحدثَين.';

  /// No other speakers.
  static const String noOtherSpeakers = 'لا يوجد متحدثون آخرون للدمج.';

  /// Forget voice.
  static const String forgetVoice = 'هذا ليس نفس الشخص';

  /// Forget voice explanation.
  static const String forgetVoiceTitle = 'نسيان البصمة الصوتية؟';

  /// Forget voice body.
  static String forgetVoiceBody(String name) =>
      'سينسى إنصاتو البصمة الصوتية لـ«$name» ولن يتعرّف عليه تلقائيًا بعد '
      'الآن حتى يتعلّمها من جديد. استخدم ذلك إذا نُسبت إليه أصوات أشخاص '
      'آخرين. تبقى مقاطعه الحالية كما هي.';

  /// Forget action.
  static const String forget = 'نسيان البصمة';

  /// Voice forgotten.
  static const String voiceForgotten = 'تم نسيان البصمة الصوتية.';

  /// Delete speaker title.
  static const String deleteSpeakerTitle = 'حذف المتحدث؟';

  /// Delete speaker body.
  static String deleteSpeakerBody(String name) =>
      'سيُحذف «$name» وبصمته الصوتية، وتصبح مقاطعه في جميع الاجتماعات '
      'بلا متحدث محدد.';

  /// Speaker deleted.
  static const String speakerDeleted = 'تم حذف المتحدث.';

  /// Voice library title.
  static const String voiceLibrary = 'مكتبة الأصوات';

  /// Voice library intro.
  static const String voiceLibraryIntro =
      'كل متحدث سمعه إنصاتو له بصمة صوتية. سمِّ المتحدثين ليتعرّف عليهم إنصاتو '
      'بأسمائهم في الاجتماعات القادمة.';

  /// Empty library.
  static const String noSpeakersTitle = 'لا يوجد متحدثون بعد';

  /// Empty library body.
  static const String noSpeakersBody =
      'سيظهر هنا كل من يتحدث في اجتماعاتك، مع بصمته الصوتية.';

  /// Speakers in meeting empty.
  static const String noMeetingSpeakers =
      'لم يُميَّز أي متحدث في هذا الاجتماع.';

  /// Voiceprint present.
  static const String hasVoiceprint = 'بصمة صوتية محفوظة';

  /// No voiceprint.
  static const String noVoiceprint = 'بلا بصمة صوتية';

  /// Auto named.
  static const String autoNamed = 'اسم تلقائي';

  /// Talk time.
  static String talkTime(String duration, int percent) =>
      '$duration · $percent٪ من الكلام';

  /// Speaker actions tooltip.
  static const String speakerActions = 'إجراءات المتحدث';

  /// Name hint.
  static const String speakerNameHint = 'مثال: د. سارة أحمد';

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Section: minutes engine.
  static const String sectionClaude = 'محرك كتابة المحضر';

  /// Minutes engine choice label.
  static const String minutesEngine = 'المحرك';

  /// Engine: Gemini.
  static const String engineGemini = 'Gemini (مجاني)';

  /// Engine: Claude.
  static const String engineClaude = 'Claude';

  /// Engine: on-device model.
  static const String engineLocal = 'على الجهاز';

  /// Engine: local server.
  static const String engineServer = 'خادم محلي';

  /// Helper under the engine choice, per engine.
  static String minutesEngineHelper(String engine) => switch (engine) {
    'claude' =>
      'Claude من Anthropic: أعلى جودة في كتابة المحاضر، ويتطلب مفتاح API '
          'مدفوعاً. يُرسَل نص الاجتماع فقط.',
    'local' =>
      'نموذج يعمل على جهازك دون إنترنت: أعلى خصوصية، لكنه أبطأ وأقل جودة من '
          'المحركات السحابية.',
    'server' =>
      'نموذج على خادم في شبكتك المحلية (Ollama أو LM Studio): لا يغادر النص '
          'شبكتك.',
    _ =>
      'Gemini من Google: جودة جيدة ومجاني بمفتاح من Google AI Studio، مع حدود '
          'لعدد الطلبات في الدقيقة واليوم. يُرسَل نص الاجتماع فقط.',
  };

  /// Gemini key label.
  static const String geminiKey = 'مفتاح Gemini API';

  /// Gemini key helper.
  static const String geminiKeyHelper =
      'أنشئ مفتاحاً مجانياً من Google AI Studio (الرابط أدناه). يُحفظ مشفّراً '
      'في مخزن الجهاز الآمن ولا يُرسَل إلا إلى Google.';

  /// Where to get a Gemini key.
  static const String geminiKeyWhere = 'احصل على مفتاح مجاني من:';

  /// Gemini model label.
  static const String geminiModel = 'نموذج Gemini';

  /// Gemini model helper.
  static const String geminiModelHelper =
      'الافتراضي gemini-flash-lite-latest (أحدث نموذج Flash-Lite المجاني، '
      'الأسرع وصاحب أوسع حصة مجانية). إن لم يكن متاحاً لمفتاحك يُختار أحدث '
      'نموذج Flash تلقائياً.';

  /// Gemini privacy notice title.
  static const String geminiPrivacyTitle = 'تنبيه خصوصية Gemini المجاني';

  /// Gemini privacy notice body (shown before first use).
  static const String geminiPrivacyBody =
      'عند استخدام مفتاح Gemini المجاني (دون تفعيل الفوترة) قد تستخدم Google '
      'نصوص الاجتماعات المرسلة والمحاضر الناتجة لتحسين منتجاتها، وقد يطّلع '
      'عليها مراجعون بشريون بعد فصلها عن حسابك. لا تُرسِل عبره اجتماعات سرية '
      'أو بيانات شخصية حساسة؛ استخدم لها المحرك على الجهاز أو مفتاحاً من مشروع '
      'Google Cloud مفعّل الفوترة (يُعامَل كخدمة مدفوعة ولا يُستخدم في '
      'التدريب). يُرسَل نص الاجتماع فقط، ولا يُرسَل الصوت.';

  /// Accept the Gemini notice.
  static const String geminiPrivacyAccept = 'فهمت وأوافق';

  /// Notice accepted.
  static const String geminiPrivacyAccepted =
      'وافقت على تنبيه الخصوصية. يمكنك سحب الموافقة في أي وقت.';

  /// Withdraw consent.
  static const String geminiPrivacyWithdraw = 'سحب الموافقة';

  /// The selected local engine is not available in this build.
  static const String engineUnavailable =
      'هذا المحرك غير متاح في هذا الإصدار.';

  /// API key label.
  static const String anthropicKey = 'مفتاح Anthropic API (Claude)';

  /// API key helper.
  static const String anthropicKeyHelper =
      'يُحفظ المفتاح مشفّرًا في مخزن الجهاز الآمن، ولا يُرسَل إلا إلى Anthropic.';

  /// Show key.
  static const String showKey = 'إظهار المفتاح';

  /// Hide key.
  static const String hideKey = 'إخفاء المفتاح';

  /// Key saved.
  static const String keySaved = 'تم حفظ المفتاح.';

  /// Key cleared.
  static const String keyCleared = 'تم حذف المفتاح.';

  /// Key configured.
  static const String keyConfigured = 'المفتاح مضبوط';

  /// The stored key cannot be read right now (locked keystore).
  static const String keyUnreadable =
      'تتعذّر قراءة المفتاح المحفوظ الآن؛ افتح قفل الجهاز ثم عُد إلى هذه الصفحة.';

  /// Key not configured.
  static const String keyNotConfigured = 'لم يُضبط مفتاح بعد';

  /// Clear key.
  static const String clearKey = 'حذف المفتاح';

  /// Test connection.
  static const String testConnection = 'اختبار الاتصال';

  /// Testing.
  static const String testingConnection = 'جارٍ اختبار الاتصال…';

  /// Connection ok.
  static String connectionOk(String model) =>
      'الاتصال ناجح والمفتاح صالح (النموذج: $model).';

  /// Claude model label.
  static const String claudeModel = 'نموذج Claude';

  /// Claude model helper.
  static const String claudeModelHelper =
      'الافتراضي claude-opus-5-5، وهو الأعلى جودة في كتابة المحاضر.';

  /// Model saved.
  static const String modelSaved = 'تم حفظ النموذج.';

  /// Detail level.
  static const String minutesDetail = 'مستوى تفصيل المحضر';

  /// Detailed.
  static const String detailDetailed = 'مفصّل';

  /// Concise.
  static const String detailConcise = 'موجز';

  /// Detail explanation.
  static const String minutesDetailHelper =
      'المفصّل يوثّق النقاش ومواقف المتحدثين، والموجز يكتفي بالنقاط الأساسية.';

  /// Section: transcription.
  static const String sectionAsr = 'التفريغ الصوتي';

  /// On device.
  static const String asrLocal = 'على الجهاز';

  /// Cloud.
  static const String asrCloud = 'سحابي (Deepgram)';

  /// ASR explanation local.
  static const String asrLocalHelper =
      'خصوصية تامة: يُفرَّغ الكلام على جهازك دون إنترنت باستخدام Whisper.';

  /// ASR explanation cloud.
  static const String asrCloudHelper =
      'دقة أعلى وسرعة أكبر على الأجهزة الضعيفة، لكن مقاطع الصوت تُرسَل إلى '
      'Deepgram لمعالجتها. يطلب إنصاتو عدم استخدامها في تدريب النماذج، '
      'ويخضع الاحتفاظ بها لسياسة بيانات Deepgram. تبقى البصمات الصوتية على '
      'جهازك.';

  /// Deepgram key.
  static const String deepgramKey = 'مفتاح Deepgram API';

  /// Whisper model.
  static const String whisperModel = 'نموذج Whisper';

  /// Language hint.
  static const String languageHint = 'لغة الاجتماع';

  /// Language hint helper.
  static const String languageHintHelper =
      'اترك «تلقائي» إذا كان الاجتماع بأكثر من لغة؛ اختر لغة واحدة فقط إذا '
      'كان الكلام كله بها لتحسين الدقة.';

  /// Auto language.
  static const String languageAuto = 'تلقائي (متعدد اللغات)';

  /// Keep audio.
  static const String keepAudio = 'الاحتفاظ بالتسجيل الصوتي';

  /// Keep audio helper.
  static const String keepAudioHelper =
      'يتيح إعادة معالجة الاجتماع لاحقًا. أوقفه لتوفير المساحة أو لمزيد من '
      'الخصوصية.';

  /// Section: speakers.
  static const String sectionSpeakers = 'تمييز المتحدثين';

  /// Sensitivity.
  static const String matchSensitivity = 'حساسية مطابقة الأصوات';

  /// Sensitivity helper.
  static const String matchSensitivityHelper =
      'القيمة الأعلى أكثر حذرًا: يقلّ الخلط بين الأشخاص لكن قد يُقسَم الشخص '
      'الواحد إلى متحدثَين. القيمة الأدنى تجمع الأصوات المتشابهة بسهولة أكبر. '
      'الافتراضي ٠٫٥٥.';

  /// Lenient end of the slider.
  static const String lenient = 'تجميع أكثر';

  /// Strict end of the slider.
  static const String strict = 'تمييز أدق';

  /// Section: models.
  static const String sectionModels = 'نماذج التعرّف على الكلام';

  /// Manage models.
  static const String manageModels = 'إدارة النماذج';

  /// Manage models subtitle.
  static const String manageModelsSubtitle =
      'تنزيل نماذج التفريغ وكشف الكلام والبصمة الصوتية أو حذفها.';

  /// Section: privacy.
  static const String sectionPrivacy = 'الخصوصية';

  /// Privacy text.
  static const String privacyBody =
      '• تُحفظ التسجيلات والنصوص والبصمات الصوتية على جهازك فقط، ولا تُنسخ '
      'احتياطيًا إلى السحابة.\n'
      '• لكتابة المحضر يُرسَل نص الاجتماع فقط (دون الصوت) إلى محرك المحضر '
      'المختار: Google (Gemini، الافتراضي) أو Anthropic (Claude). في الفئة '
      'المجانية من Gemini قد تستخدم Google النصوص لتحسين منتجاتها وقد يطّلع '
      'عليها مراجعون بشريون؛ ولا يغادر النص جهازك مع المحرك المحلي.\n'
      '• في التفريغ السحابي تُرسَل مقاطع الصوت إلى Deepgram لمعالجتها، مع '
      'طلب عدم استخدامها في تدريب النماذج؛ ويخضع الاحتفاظ بها لسياسة بيانات '
      'Deepgram.\n'
      '• مفاتيح API محفوظة مشفّرة في المخزن الآمن للنظام، لا في قاعدة بيانات '
      'التطبيق.\n'
      '• أبلغ المشاركين دائمًا بأن الاجتماع يُسجَّل.';

  /// Section: about.
  static const String sectionAbout = 'حول إنصاتو';

  /// About body.
  static const String aboutBody =
      'إنصاتو يستمع إلى اجتماعاتك بأي لغة، ويفرّغها، ويميّز المتحدثين بأصواتهم، '
      'ثم يكتب محضرًا عربيًا احترافيًا.';

  /// Licenses.
  static const String licenses = 'التراخيص مفتوحة المصدر';

  /// Reset settings.
  static const String resetSettings = 'استعادة الإعدادات الافتراضية';

  /// Reset confirm.
  static const String resetSettingsBody =
      'ستعود جميع التفضيلات إلى قيمها الافتراضية. لا تتأثر مفاتيح API '
      'والاجتماعات.';

  /// Settings reset.
  static const String settingsReset = 'تمت استعادة الإعدادات الافتراضية.';

  // ---------------------------------------------------------------------------
  // Models
  // ---------------------------------------------------------------------------

  /// Models screen title.
  static const String modelsTitle = 'النماذج';

  /// Models intro.
  static const String modelsIntro =
      'يعمل إنصاتو على جهازك دون إنترنت بعد تنزيل النماذج التالية مرة واحدة. '
      'يُنصح بالتنزيل عبر شبكة Wi-Fi.';

  /// Required group.
  static const String requiredModels = 'النماذج المطلوبة لإعداداتك';

  /// Other group.
  static const String otherModels = 'نماذج أخرى';

  /// Download.
  static const String download = 'تنزيل';

  /// Download all.
  static const String downloadRequired = 'تنزيل النماذج المطلوبة';

  /// Cancel download.
  static const String cancelDownload = 'إيقاف التنزيل';

  /// Delete model.
  static const String deleteModel = 'حذف النموذج';

  /// Delete model confirm.
  static String deleteModelBody(String name) =>
      'سيُحذف «$name» من الجهاز. يمكنك تنزيله مجددًا لاحقًا.';

  /// Ready.
  static const String modelReady = 'جاهز';

  /// Not downloaded.
  static const String modelNotDownloaded = 'غير منزّل';

  /// Failed.
  static const String modelFailed = 'فشل التنزيل';

  /// Recommended.
  static const String recommended = 'موصى به';

  /// In use.
  static const String inUse = 'مستخدم حاليًا';

  /// Use this Whisper.
  static const String useThisModel = 'استخدام هذا النموذج';

  /// Size.
  static String approxSize(int mb) => mb >= 1000
      ? 'نحو ${(mb / 1000).toStringAsFixed(1)} غيغابايت'
      : 'نحو $mb ميغابايت';

  /// Download progress.
  static String downloading(int percent) => 'جارٍ التنزيل… $percent٪';

  /// Extracting / finishing.
  static const String finishingInstall = 'جارٍ فك الضغط والتحقق…';

  /// Recommendation note.
  static const String recommendationNote =
      'Whisper Turbo هو الأعلى دقة ويدعم العربية ولهجاتها والإنجليزية '
      'و٩٧ لغة أخرى، حتى عند الخلط بينها في الجملة نفسها. على الهواتف الأقدم '
      'اختر Whisper Small للسرعة، أو استخدم التفريغ السحابي.';

  /// Models missing banner.
  static const String modelsMissingTitle = 'النماذج غير مكتملة';

  /// Models missing banner body.
  static String modelsMissingBody(String names) =>
      'نزّل النماذج التالية قبل التسجيل: $names';

  /// Models state loading error.
  static const String modelsLoadFailed = 'تعذّر قراءة حالة النماذج.';

  /// Cloud mode note on models.
  static const String cloudModeNote =
      'التفريغ السحابي مفعّل، لذا لا تحتاج إلى نموذج Whisper على الجهاز.';

  // ---------------------------------------------------------------------------
  // Languages (ISO-639-1 → Arabic name)
  // ---------------------------------------------------------------------------

  /// Common meeting languages offered as a hint, in display order.
  static const List<String> commonLanguageCodes = [
    'ar',
    'en',
    'fr',
    'es',
    'de',
    'tr',
    'fa',
    'ur',
    'hi',
    'zh',
    'ru',
    'it',
    'pt',
    'id',
    'ms',
    'ja',
    'ko',
  ];

  static const Map<String, String> _languageNames = {
    'ar': 'العربية',
    'en': 'الإنجليزية',
    'fr': 'الفرنسية',
    'es': 'الإسبانية',
    'de': 'الألمانية',
    'tr': 'التركية',
    'fa': 'الفارسية',
    'ur': 'الأردية',
    'hi': 'الهندية',
    'zh': 'الصينية',
    'ru': 'الروسية',
    'it': 'الإيطالية',
    'pt': 'البرتغالية',
    'id': 'الإندونيسية',
    'ms': 'الملايوية',
    'ja': 'اليابانية',
    'ko': 'الكورية',
    'nl': 'الهولندية',
    'sw': 'السواحيلية',
    'he': 'العبرية',
    'ku': 'الكردية',
    'bn': 'البنغالية',
  };

  /// Marker of an unintelligible transcript segment (F17), e.g.
  /// «كلام غير مفهوم (2.4 ث)».
  static String unintelligibleSegment(int durationMs) {
    final tenths = (durationMs.clamp(0, 1 << 40) / 100).round();
    return 'كلام غير مفهوم (${tenths ~/ 10}.${tenths % 10} ث)';
  }

  /// Arabic name of the language [code] (e.g. `en`, `en-US`), or null.
  static String? languageName(String? code) {
    if (code == null) return null;
    final c = code.trim().toLowerCase().split(RegExp('[-_]')).first;
    return _languageNames[c];
  }
}
