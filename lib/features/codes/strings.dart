// Arabic (MSA) UI strings of the codes, jargon, hidden meanings and
// references feature (F17). Shared words (save, cancel, copied, …) come from
// `S` in lib/ui/strings_ar.dart.

import '../../core/models.dart';

/// Arabic strings of the codes feature.
abstract final class KS {
  // ---------------------------------------------------------------------------
  // Tab
  // ---------------------------------------------------------------------------

  /// Tab title of the meeting screen.
  static const String tabTitle = 'الرموز والشيفرات';

  /// Intro note at the top of the tab (transparency rule).
  static const String intro =
      'ما يلي ملاحظات وصفية استخرجها محرّك المحضر من نص الاجتماع، وكل '
      'تفسير فيها فرضية مستنتجة وليست حقيقة مؤكدة. لكل عنصر رابط إلى '
      'موضعه في التسجيل لتتحقق منه بنفسك.';

  /// Nothing found and no unintelligible segment.
  static const String emptyTitle = 'لا توجد رموز أو شيفرات';

  /// Body of the empty state.
  static const String emptyBody =
      'لم يرصد المحضر كلامًا مرمّزًا أو مصطلحات داخلية أو كودًا برمجيًا أو '
      'تلميحات أو أرقامًا مرجعية في هذا الاجتماع. أنشئ المحضر أو أعد '
      'إنشاءه لتحليل الاجتماع.';

  /// Error loading the findings.
  static const String loadError = 'تعذّر تحميل الرموز والشيفرات.';

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  /// Section 1.
  static const String codedSpeechTitle = 'كلام مرمّز أو غير مفهوم';

  /// Section 2.
  static const String jargonTitle = 'رموز ومصطلحات داخلية';

  /// Section 3.
  static const String spokenCodeTitle = 'كود برمجي قيل شفهيًا';

  /// Section 4.
  static const String impliedTitle = 'كلام مُلمَّح';

  /// Section 5.
  static const String referencesTitle = 'أرقام ورموز مرجعية';

  /// Sub-heading: unintelligible segments without an engine finding.
  static const String otherUnintelligibleTitle =
      'مقاطع غير مفهومة أخرى في التفريغ';

  /// Explanation under [otherUnintelligibleTitle].
  static const String otherUnintelligibleNote =
      'رصدها التعرّف على الكلام ولم يتناولها المحضر. استمع إليها من رابط '
      'الدليل.';

  /// Empty section line.
  static const String noneInSection = 'لا شيء في هذا القسم.';

  // ---------------------------------------------------------------------------
  // Common item parts
  // ---------------------------------------------------------------------------

  /// «Speaker: name».
  static String speakerLine(String name) => 'المتحدث: $name';

  /// «Speakers: a، b».
  static String speakersLine(List<String> names) =>
      'استخدمه: ${names.join('، ')}';

  /// Unknown speaker.
  static const String unknownSpeaker = 'متحدث غير معروف';

  /// Badge: inferred meaning.
  static const String inferred = 'مستنتج';

  /// Badge: hypothesis.
  static const String hypothesis = 'فرضية';

  /// Label of a confidence level.
  static String confidence(HypothesisConfidence c) => switch (c) {
    HypothesisConfidence.low => 'ثقة منخفضة',
    HypothesisConfidence.medium => 'ثقة متوسطة',
    HypothesisConfidence.high => 'ثقة عالية',
  };

  /// «Basis: …».
  static String basis(String text) => 'السبب: $text';

  /// No evidence link available.
  static const String noEvidence = 'لا يوجد رابط دليل لهذا العنصر.';

  // ---------------------------------------------------------------------------
  // Coded speech
  // ---------------------------------------------------------------------------

  /// Characterisation label.
  static String character(CodedSpeechCharacter c) => switch (c) {
    CodedSpeechCharacter.unsupportedLanguage => 'لغة حقيقية غير مدعومة',
    CodedSpeechCharacter.reversedSpeech => 'يبدو كلامًا معكوسًا',
    CodedSpeechCharacter.lettersOrNumbers => 'حروف أو أرقام متتابعة',
    CodedSpeechCharacter.whispering => 'همس أو صوت منخفض جدًا',
    CodedSpeechCharacter.inventedLanguage => 'لغة مخترعة أو مقاطع مبعثرة',
    CodedSpeechCharacter.unknown => 'غير محدد الطبيعة',
  };

  /// Heading of the hypotheses list.
  static const String possibleMeanings = 'تفسيرات محتملة (فرضيات)';

  /// No hypothesis was offered.
  static const String noHypotheses =
      'لم يقترح المحضر تفسيرًا؛ لا يدّعي إنصاتو فكّ أي رمز.';

  /// Duration of an unintelligible segment, e.g. «المدة: 2.4 ث».
  static String duration(int durationMs) {
    final tenths = (durationMs.clamp(0, 1 << 40) / 100).round();
    return 'المدة: ${tenths ~/ 10}.${tenths % 10} ث';
  }

  /// Total duration of the cited unintelligible segments.
  static String totalDuration(int durationMs) {
    final tenths = (durationMs.clamp(0, 1 << 40) / 100).round();
    return 'مدة المقاطع: ${tenths ~/ 10}.${tenths % 10} ث';
  }

  /// Heading of a reversed-audio re-ASR result.
  static const String reversedResultTitle =
      'فرضية: كلام معكوس (أُعيد التعرّف على الصوت بعد قلبه زمنيًا)';

  /// Caveat under a reversed-audio result.
  static const String reversedResultCaveat =
      'نتيجة آلية قد تكون مصادفة؛ لم يُغيَّر النص الأصلي. استمع للتحقق.';

  /// «Segment #n».
  static String segmentNumber(int index) => 'المقطع #$index';

  /// Label of an app-created finding (no engine item).
  static const String fromTranscript = 'رُصد في التفريغ ولم يتناوله المحضر';

  /// Description of an app-created coded-speech finding.
  static String appFindingDescription(int durationMs) {
    final tenths = (durationMs.clamp(0, 1 << 40) / 100).round();
    return 'مقطع غير مفهوم مدته ${tenths ~/ 10}.${tenths % 10} ث رُصد في '
        'التفريغ ولم يتناوله المحضر.';
  }

  /// Low-confidence guess of the recogniser.
  static String asrGuess(String text) => 'تخمين التعرّف على الكلام: «$text»';

  // ---------------------------------------------------------------------------
  // Jargon
  // ---------------------------------------------------------------------------

  /// «Inferred meaning: …».
  static String inferredMeaning(String text) => 'المعنى المستنتج: $text';

  /// Add-to-glossary button.
  static const String addToGlossary = 'أضف إلى القاموس';

  /// Already in the glossary.
  static const String inGlossary = 'في القاموس';

  /// Dialog title.
  static const String addToGlossaryTitle = 'إضافة المصطلح إلى القاموس';

  /// Dialog explanation.
  static const String addToGlossaryNote =
      'المعنى المعروض مستنتج من السياق. صحّحه أو أكّده قبل الحفظ؛ يُحفظ '
      'في القاموس كما تكتبه.';

  /// Term field label.
  static const String termLabel = 'المصطلح';

  /// Meaning field label.
  static const String meaningLabel = 'المعنى المؤكَّد';

  /// Validation: blank term.
  static const String termEmpty = 'اكتب المصطلح.';

  /// Validation: blank meaning.
  static const String meaningEmpty = 'اكتب المعنى المؤكَّد.';

  /// Scope: every meeting.
  static const String scopeGlobal = 'كل الاجتماعات';

  /// Scope: this meeting only.
  static const String scopeMeeting = 'هذا الاجتماع فقط';

  /// Scope label.
  static const String scopeLabel = 'النطاق';

  /// Snack bar after adding.
  static String addedToGlossary(String term) => 'أُضيف «$term» إلى القاموس.';

  /// Failure.
  static const String addToGlossaryFailed = 'تعذّرت الإضافة إلى القاموس.';

  // ---------------------------------------------------------------------------
  // Spoken code
  // ---------------------------------------------------------------------------

  /// Copy-code button tooltip.
  static const String copyCode = 'نسخ الكود';

  /// Semantics label of a code block.
  static String codeBlockLabel(String language) => 'كتلة كود بلغة $language';

  /// Language label when unknown.
  static const String unknownLanguage = 'نص';

  /// Heading of the issues list.
  static const String potentialIssues = 'ملاحظات محتملة';

  /// Reconstruction caveat.
  static const String reconstructedNote =
      'أُعيد بناء الكود مما قيل شفهيًا؛ راجعه قبل استعماله.';

  // ---------------------------------------------------------------------------
  // Implied speech
  // ---------------------------------------------------------------------------

  /// «What was said: …».
  static String literal(String text) => 'ما قيل حرفيًا: «$text»';

  /// Heading of the possible meanings.
  static const String impliedMeanings = 'معانٍ محتملة (فرضيات، لا حقائق)';

  // ---------------------------------------------------------------------------
  // References
  // ---------------------------------------------------------------------------

  /// Table column: kind.
  static const String colKind = 'النوع';

  /// Table column: value.
  static const String colValue = 'القيمة';

  /// Table column: context.
  static const String colContext = 'يشير إلى';

  /// Table column: speaker.
  static const String colSpeaker = 'المتحدث';

  /// Table column: check.
  static const String colCheck = 'التحقق';

  /// Table column: evidence.
  static const String colEvidence = 'الدليل';

  /// «As said: …» (verbatim differs from normalised).
  static String asSaid(String verbatim) => 'كما قيل: $verbatim';

  /// Reference kind label.
  static String referenceKind(ReferenceKind k) => switch (k) {
    ReferenceKind.contract => 'رقم عقد',
    ReferenceKind.invoice => 'رقم فاتورة',
    ReferenceKind.ticket => 'رقم تذكرة',
    ReferenceKind.legalArticle => 'مادة قانونية',
    ReferenceKind.product => 'رمز منتج',
    ReferenceKind.account => 'رقم حساب',
    ReferenceKind.amount => 'مبلغ',
    ReferenceKind.date => 'تاريخ أو وقت',
    ReferenceKind.phone => 'رقم هاتف',
    ReferenceKind.other => 'معرّف آخر',
  };

  /// Verified badge.
  static const String verified = 'مطابق للنص';

  /// Verified tooltip.
  static const String verifiedHint =
      'وُجدت أرقام هذا المرجع كما هي في نص مقاطع الدليل.';

  /// Unverified badge.
  static const String unverified = 'غير متحقَّق';

  /// Unverified tooltip.
  static const String unverifiedHint =
      'لم تُوجد أرقام هذا المرجع كما هي في نص مقاطع الدليل؛ قد يكون '
      'المحرّك أخطأ في نقلها أو قيلت بالكلمات. استمع للتحقق.';

  /// No evidence to verify against.
  static const String noEvidenceToVerify = 'بلا دليل';

  /// Tooltip of [noEvidenceToVerify].
  static const String noEvidenceToVerifyHint =
      'لا توجد مقاطع دليل يمكن مطابقة المرجع بها.';

  // ---------------------------------------------------------------------------
  // Reversed speech
  // ---------------------------------------------------------------------------

  /// Button.
  static const String reverseButton = 'حاول فك الكلام المعكوس';

  /// Button hint / explanation.
  static const String reverseHint =
      'يقلب صوت المقاطع غير المفهومة زمنيًا ويعيد التعرّف عليه بمحرّك '
      'التفريغ المختار في الإعدادات. تُعرض أي نتيجة فرضيةً بجانب المقطع '
      'ولا يُغيَّر النص الأصلي.';

  /// Button disabled: no kept audio.
  static const String reverseNoAudio =
      'لا يوجد تسجيل صوتي محفوظ لهذا الاجتماع، لذا يتعذّر فك الكلام المعكوس.';

  /// Button disabled: no unintelligible segment.
  static const String reverseNothing =
      'لا توجد مقاطع غير مفهومة في هذا الاجتماع.';

  /// Button disabled: recording or another job.
  static const String reverseBusy =
      'انتظر حتى تنتهي المعالجة الجارية لهذا الاجتماع.';

  /// Progress line.
  static String reverseProgress(int done, int total) =>
      'جارٍ تحليل المقطع $done من $total…';

  /// Loading engines.
  static const String reverseLoading = 'جارٍ تحميل محرّك التعرّف على الكلام…';

  /// Saving.
  static const String reverseSaving = 'جارٍ حفظ النتائج…';

  /// Cancel button.
  static const String reverseCancel = 'إيقاف';

  /// Result summary.
  static String reverseDone(int analysed, int found, int failed) {
    final base = found == 0
        ? 'حُلِّل $analysed من المقاطع ولم يظهر فيها كلام معكوس مفهوم.'
        : 'حُلِّل $analysed من المقاطع، وظهر نص محتمل في $found منها '
              '(معروض فرضيةً بجانب كل مقطع).';
    return failed == 0 ? base : '$base تعذّر تحليل $failed.';
  }

  /// Cancelled.
  static const String reverseCancelled = 'أُوقف فك الكلام المعكوس.';

  /// Error: meeting recording.
  static const String reverseRecording =
      'لا يمكن تحليل اجتماع ما زال قيد التسجيل.';

  /// Error: meeting missing.
  static const String meetingMissing = 'الاجتماع غير موجود.';

  /// Error: unreadable WAV.
  static const String reverseBadAudio =
      'ملف التسجيل الصوتي تالف أو بصيغة غير مدعومة.';

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Export heading.
  static const String exportTitle = 'الرموز والشيفرات';

  /// Export caveat line.
  static const String exportCaveat =
      'ملاحظات وصفية؛ كل تفسير فيها فرضية مستنتجة وليست حقيقة مؤكدة.';

  /// Export: evidence timestamps prefix.
  static String exportEvidence(List<String> stamps) =>
      'الدليل: ${stamps.join('، ')}';
}
