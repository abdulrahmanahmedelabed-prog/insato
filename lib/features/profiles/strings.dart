// Arabic (MSA) strings of the speaker profiles feature (F16). Shared words
// (save, cancel, delete, …) come from `S` in lib/ui/strings_ar.dart.
//
// Wording rule (spec guardrails): descriptive, nominal and gender-neutral;
// only what was observed in speech; never a judgement or a score.

import '../../core/models.dart';
import '../../core/time_format.dart';
import 'profile_model.dart' show DomainTrend;

/// Arabic strings of the speaker profiles feature.
abstract final class PS {
  // ---------------------------------------------------------------------------
  // Opt-in tile and dialogs
  // ---------------------------------------------------------------------------

  /// Opt-in switch title.
  static const String optInTitle = 'تفعيل ملف المتحدث';

  /// Opt-in subtitle while off.
  static const String optInOffSubtitle =
      'ملف وصفي لما يظهر في كلام المتحدث عبر الاجتماعات. معطّل افتراضياً.';

  /// Opt-in subtitle while on.
  static const String optInOnSubtitle =
      'يُحدَّث بعد كل محضر. يبقى على هذا الجهاز ويمكن حذفه في أي وقت.';

  /// Short notice under the switch.
  static const String optInNotice =
      'يُستحسن إبلاغ الشخص بأن ملفاً وصفياً يُبنى عن مشاركاته.';

  /// One-time notice dialog title.
  static const String noticeTitle = 'قبل تفعيل ملفات المتحدثين';

  /// One-time notice dialog body.
  static const String noticeBody =
      'ملف المتحدث ملخص وصفي لما يظهر في كلام الشخص عبر الاجتماعات: '
      'المعارف والمهارات الظاهرة في الحديث، واللغات المستعملة، وأسلوب '
      'التواصل الملاحظ، والإسهامات والمهام.\n\n'
      '• يُبنى فقط من سلوك ظاهر وموثّق بأدلة من النص، وكل ملاحظة مرتبطة '
      'بموضعها في الاجتماع.\n'
      '• لا يتضمن أي استنتاج عن المشاعر أو الحالة النفسية أو الصحة أو الدين '
      'أو التوجه السياسي أو الأصل أو العمر أو غيرها من الصفات الحساسة، ولا '
      'يمنح درجات للتوظيف أو التقييم.\n'
      '• يبقى الملف على هذا الجهاز، ويمكن حذفه مع ملاحظاته في أي وقت.\n'
      '• يُستخرج جزء الملاحظات مع المحضر باستعمال محرك المحاضر الذي اخترته '
      'في الإعدادات.\n\n'
      'يُستحسن إبلاغ الشخص قبل تفعيل ملفه.';

  /// Notice dialog confirm button.
  static const String noticeAccept = 'فهمت، فعّل الملف';

  /// Turn-off dialog title.
  static const String disableTitle = 'إيقاف ملف المتحدث';

  /// Turn-off dialog body.
  static const String disableBody =
      'لن تُستخرج ملاحظات جديدة لهذا المتحدث. هل تريد أيضاً حذف الملف '
      'وجميع ملاحظات الاجتماعات المحفوظة له؟';

  /// Turn-off: keep data.
  static const String disableKeep = 'إيقاف مع الإبقاء على الملف';

  /// Turn-off: delete data.
  static const String disableDelete = 'إيقاف وحذف الملف';

  /// Snack after enabling.
  static const String enabledSnack =
      'فُعّل ملف المتحدث. تُضاف الملاحظات مع المحاضر القادمة.';

  /// Snack after disabling.
  static const String disabledSnack = 'أُوقف ملف المتحدث.';

  /// Snack after deleting.
  static const String deletedSnack = 'حُذف ملف المتحدث وملاحظاته.';

  /// Generic failure.
  static const String actionFailed = 'تعذّر تنفيذ العملية. حاول مرة أخرى.';

  // ---------------------------------------------------------------------------
  // Profile screen
  // ---------------------------------------------------------------------------

  /// Screen title.
  static const String screenTitle = 'ملف المتحدث';

  /// Screen title with the speaker's name.
  static String screenTitleFor(String name) => 'ملف المتحدث: $name';

  /// Rebuild action.
  static const String rebuild = 'إعادة بناء الملف';

  /// Rebuild tooltip.
  static const String rebuildTooltip =
      'إعادة حساب الملف من جميع الاجتماعات المحفوظة';

  /// Rebuild in progress.
  static const String rebuilding = 'تجري إعادة بناء الملف…';

  /// Rebuild done.
  static const String rebuilt = 'أُعيد بناء الملف.';

  /// Delete action.
  static const String deleteProfile = 'حذف الملف';

  /// Delete dialog title.
  static const String deleteTitle = 'حذف ملف المتحدث؟';

  /// Delete dialog body.
  static const String deleteBody =
      'سيُحذف الملف وجميع ملاحظات الاجتماعات المحفوظة لهذا المتحدث، ويُوقف '
      'جمع الملاحظات. لا تتأثر المحاضر ولا النصوص.';

  /// Speaker missing.
  static const String speakerMissing = 'لم يعد هذا المتحدث موجوداً.';

  /// Not enabled: title.
  static const String notEnabledTitle = 'ملف المتحدث غير مفعّل';

  /// Not enabled: body.
  static const String notEnabledBody =
      'فعّل الملف لهذا المتحدث ليُبنى ملخص وصفي لمشاركاته عبر الاجتماعات.';

  /// Enabled but nothing built yet.
  static const String emptyTitle = 'لا توجد بيانات بعد';

  /// Enabled but nothing built yet: body.
  static const String emptyBody =
      'لم يُرصد كلام لهذا المتحدث في الاجتماعات المحفوظة بعد. تُضاف '
      'الإحصاءات والملاحظات بعد الاجتماعات القادمة.';

  /// Load error.
  static const String loadFailed = 'تعذّر قراءة الملف.';

  /// Descriptive disclaimer at the top of the profile.
  static const String disclaimer =
      'ملاحظات وصفية لما ظهر في الكلام فقط، مرتبطة بأدلتها. ليست تقييماً '
      'للشخص ولا تصلح أساساً لقرارات توظيف.';

  /// Header line: meetings and last update.
  static String headerLine(int meetings, DateTime updatedAt) =>
      '${meetingCount(meetings)} · آخر تحديث ${formatArabicDateTime(updatedAt)}';

  /// Hint shown while there are statistics but no notes yet.
  static const String noNotesHint =
      'تُستخرج ملاحظات المعارف والأسلوب والإسهامات مع محاضر الاجتماعات '
      'التالية (أو عند إعادة كتابة محضر اجتماع سابق).';

  /// Items omitted by the guardrails.
  static String omittedNote(int n) =>
      'أُغفلت ${_count(n, 'ملاحظة واحدة', 'ملاحظتان', 'ملاحظات', 'ملاحظة')} '
      'لأنها لا تصف سلوكاً ظاهراً في الكلام.';

  /// Low-evidence badge.
  static const String lowEvidence = 'أدلة محدودة';

  /// Low-evidence badge semantics.
  static const String lowEvidenceHint =
      'رُصدت هذه الملاحظة من كلام قليل؛ تُقرأ بحذر.';

  /// Show more.
  static String showMore(int n) => 'عرض المزيد ($n)';

  /// Show less.
  static const String showLess = 'عرض أقل';

  /// Meeting label of an evidence group.
  static String evidenceMeeting(String title, DateTime at) =>
      '$title · ${formatArabicShortDate(at)}';

  /// Deleted meeting.
  static const String deletedMeeting = 'اجتماع محذوف';

  /// Line sheet title (evidence without audio).
  static const String lineSheetTitle = 'السطر المقابل من النص';

  /// Line sheet: why no audio.
  static const String lineSheetNoAudio =
      'لم يُحتفظ بتسجيل هذا الاجتماع، فهذا نص السطر المستشهد به.';

  /// Line sheet: still recording.
  static const String lineSheetRecording =
      'ما زال الاجتماع قيد التسجيل، فهذا نص السطر المستشهد به.';

  /// Line sheet: playback failed.
  static const String lineSheetFailed =
      'تعذّر تشغيل التسجيل، فهذا نص السطر المستشهد به.';

  /// Open meeting action.
  static const String openMeeting = 'فتح الاجتماع';

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  /// Section: knowledge & skills.
  static const String sectionKnowledge = 'المعارف والمهارات الظاهرة';

  /// Section: languages.
  static const String sectionLanguages = 'اللغات';

  /// Section: communication style.
  static const String sectionStyle = 'أسلوب التواصل';

  /// Section: contributions.
  static const String sectionContributions = 'الإسهامات';

  /// Section: summary.
  static const String sectionSummary = 'الملخص';

  /// Knowledge: empty.
  static const String knowledgeEmpty =
      'لم تُرصد بعد معارف موثّقة في مجال محدد.';

  /// Knowledge: domain subtitle.
  static String domainSubtitle(int meetings, DemonstrationLevel highest) =>
      '${meetingCount(meetings)} · أعلى مستوى ظاهر: ${levelLabel(highest)}';

  /// Demonstration level label.
  static String levelLabel(DemonstrationLevel l) => switch (l) {
    DemonstrationLevel.mentioned => 'ذِكر واستعمال للمصطلحات',
    DemonstrationLevel.explained => 'شرح أو إجابة',
    DemonstrationLevel.led => 'قيادة النقاش أو القرار',
  };

  /// Trend label.
  static String trendLabel(DomainTrend t) => switch (t) {
    DomainTrend.single => 'ظهر في اجتماع واحد',
    DomainTrend.deepening => 'حضور أعمق في الاجتماعات الأحدث',
    DomainTrend.steady => 'حضور متقارب عبر الاجتماعات',
    DomainTrend.lighter => 'حضور أخف في الاجتماعات الأحدث',
  };

  /// Languages: empty.
  static const String languagesEmpty = 'لم تُحدَّد لغة الكلام بعد.';

  /// Language row value.
  static String languageShare(int percent, int ms) =>
      '$percent٪ · ${formatDurationWords(ms)}';

  /// Code switching line.
  static String codeSwitching(int percent, int mixedTurns) =>
      'التبديل بين اللغات: في $percent٪ من الانتقالات بين المقاطع'
      '${mixedTurns > 0 ? '، و${_count(mixedTurns, 'مداخلة واحدة', 'مداخلتان', 'مداخلات', 'مداخلة')} تمزج لغتين أو أكثر' : ''}.';

  /// Single language.
  static const String singleLanguage = 'لم يُرصد تبديل بين اللغات.';

  /// Style: talk share.
  static const String statTalkShare = 'حصة وقت الكلام';

  /// Style: talk share value.
  static String talkShareValue(int percent, int ms) =>
      '$percent٪ (${formatDurationWords(ms)})';

  /// Style: turns.
  static const String statTurns = 'عدد المداخلات';

  /// Style: mean turn length.
  static const String statMeanTurn = 'متوسط طول المداخلة';

  /// Style: questions vs statements.
  static const String statQuestions = 'الأسئلة المطروحة';

  /// Questions value.
  static String questionsValue(int questions, int statements) =>
      '${_count(questions, 'سؤال واحد', 'سؤالان', 'أسئلة', 'سؤالاً')} · '
      '${_count(statements, 'مقطع تقريري واحد', 'مقطعان تقريريان', 'مقاطع تقريرية', 'مقطعاً تقريرياً')}';

  /// Style: interruptions.
  static const String statInterruptions = 'تداخل الكلام';

  /// Interruptions value.
  static String interruptionsValue(int given, int received) =>
      'بدء الكلام خلال حديث متحدث آخر: $given · '
      'بدء متحدث آخر خلال الكلام: $received';

  /// Style: task follow-through.
  static const String statTasks = 'متابعة المهام';

  /// Task follow-through value.
  static String tasksValue(int completed, int owned, int open) =>
      'أُنجزت $completed من $owned · مفتوحة $open';

  /// Style: decisions proposed.
  static const String statDecisions = 'قرارات منسوبة في المحاضر';

  /// Stats low evidence.
  static const String statsLowEvidence =
      'الكلام المرصود قليل؛ تُقرأ هذه الأرقام بحذر.';

  /// Per-meeting trend header.
  static const String perMeetingTitle = 'حصة الكلام حسب الاجتماع';

  /// Per-meeting row semantics.
  static String perMeetingSemantics(String title, int percent) =>
      '$title: $percent٪ من وقت الكلام';

  /// Style observations header.
  static const String styleObservations = 'ملاحظات من المحاضر';

  /// Contributions: empty.
  static const String contributionsEmpty = 'لم تُرصد إسهامات بعد.';

  /// Contribution kind label.
  static String contributionKind(ContributionKind k) => switch (k) {
    ContributionKind.proposed => 'اقتراح',
    ContributionKind.decided => 'قرار',
    ContributionKind.tookTask => 'تولّي مهمة',
    ContributionKind.answeredQuestion => 'إجابة عن سؤال',
    ContributionKind.askedQuestion => 'سؤال',
    ContributionKind.raisedConcern => 'ملاحظة أو اعتراض',
    ContributionKind.other => 'إسهام',
  };

  /// Contribution kind as a role in the narrative.
  static String contributionRole(ContributionKind k) => switch (k) {
    ContributionKind.proposed => 'طرح المقترحات',
    ContributionKind.decided => 'اتخاذ القرارات أو إعلانها',
    ContributionKind.tookTask => 'تولّي المهام',
    ContributionKind.answeredQuestion => 'الإجابة عن الأسئلة',
    ContributionKind.askedQuestion => 'طرح الأسئلة',
    ContributionKind.raisedConcern => 'إبداء الملاحظات والاعتراضات',
    ContributionKind.other => 'المشاركة في النقاش',
  };

  /// Decisions sub-header.
  static const String decisionsTitle = 'قرارات مقترحة (من المحاضر)';

  /// Tasks sub-header.
  static const String tasksTitle = 'المهام المسندة';

  /// Task status label.
  static String taskStatus(TaskStatus s) => switch (s) {
    TaskStatus.open => 'مفتوحة',
    TaskStatus.done => 'منجزة',
    TaskStatus.cancelled => 'ملغاة',
  };

  /// Summary: empty.
  static const String summaryEmpty = 'لا يتوفر ملخص بعد.';

  /// Per-meeting summaries header.
  static const String meetingSummaries = 'ملخص الدور في كل اجتماع';

  // ---------------------------------------------------------------------------
  // Narrative (stored in the profile)
  // ---------------------------------------------------------------------------

  /// Participation sentence.
  static String narrativeParticipation({
    required int meetings,
    required String first,
    required String last,
    required int sharePercent,
    required int speakingMs,
  }) =>
      'المشاركة المرصودة: ${meetingCount(meetings)}'
      '${first == last ? ' (${_isolate(first)})' : ' بين ${_isolate(first)} و${_isolate(last)}'}'
      '، بنحو $sharePercent٪ من وقت الكلام فيها '
      '(${formatDurationWords(speakingMs)}).';

  /// Typical role sentence.
  static String narrativeRole(List<String> roles) =>
      'الدور المعتاد بحسب الإسهامات المرصودة: ${_join(roles)}.';

  /// Domains sentence.
  static String narrativeDomains(List<String> domains) =>
      'أبرز المجالات الظاهرة في الحديث: ${domains.join('، ')}.';

  /// A domain with its meeting count.
  static String domainWithMeetings(String domain, int meetings) =>
      '${_isolate(domain)} (${meetingCount(meetings)})';

  /// A strength in a domain.
  static String strengthInDomain(DemonstrationLevel level, String domain) =>
      switch (level) {
        DemonstrationLevel.led => 'قيادة النقاش في ${_isolate(domain)}',
        _ => 'شرح موضوعات في ${_isolate(domain)}',
      };

  /// Task strength.
  static String strengthTasks(int completed, int owned) =>
      'إنجاز $completed من $owned من المهام المسندة';

  /// Strengths sentence.
  static String narrativeStrengths(List<String> strengths) =>
      'مواطن قوة ملاحظة: ${strengths.join('، ')}.';

  /// A recent per-meeting summary.
  static String narrativeMeetingSummary(String date, String summary) =>
      'في اجتماع ${_isolate(date)}: $summary';

  /// No notes yet.
  static const String narrativeNoNotes =
      'لا توجد بعد ملاحظات اجتماعات لهذا المتحدث؛ الأرقام أعلاه محسوبة من '
      'النصوص فقط.';

  /// Low evidence.
  static const String narrativeLowEvidence =
      'البيانات المتاحة قليلة، فتُقرأ هذه الملاحظات بحذر.';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// «اجتماع واحد»، «اجتماعان»، «3 اجتماعات»، «11 اجتماعاً».
  static String meetingCount(int n) =>
      _count(n, 'اجتماع واحد', 'اجتماعان', 'اجتماعات', 'اجتماعاً');

  static String _count(
    int n,
    String one,
    String two,
    String fewPlural,
    String manySingular,
  ) {
    if (n == 1) return one;
    if (n == 2) return two;
    if (n >= 3 && n <= 10) return '$n $fewPlural';
    return '$n $manySingular';
  }

  static String _join(List<String> parts) => switch (parts.length) {
    0 => '',
    1 => parts.first,
    _ =>
      '${parts.sublist(0, parts.length - 1).join('، ')} و${parts.last}',
  };

  /// First-strong isolate for names / dates inside Arabic sentences.
  static String _isolate(String s) => '\u2068$s\u2069';
}
