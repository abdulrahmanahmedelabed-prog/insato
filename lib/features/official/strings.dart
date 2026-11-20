// Arabic (MSA) UI strings of official minutes (v1.2: templates, entity
// profile, attendance, quorum, votes, approval, signatures, versions).
// Shared words (save, cancel, delete, …) come from `S` in
// lib/ui/strings_ar.dart.

/// Arabic strings of the official-minutes feature.
abstract final class OS {
  // ---------------------------------------------------------------------------
  // Template choice (context page)
  // ---------------------------------------------------------------------------

  /// Section header on the context page.
  static const String templateHeader = 'نوع المحضر';

  /// Dropdown label.
  static const String templateLabel = 'قالب المحضر';

  /// Helper under the dropdown.
  static const String templateHelper =
      'يحدد صياغة القرارات وقواعد النصاب والتصويت والتواقيع. يمكن تغييره '
      'لاحقاً، وترفع قوالب جهتك من الإعدادات.';

  /// Group label of uploaded templates.
  static const String uploadedTemplates = 'قوالب جهتك';

  /// Suffix of an uploaded template's entry.
  static String uploadedBasedOn(String base) => 'قالب Word — على قواعد: $base';

  // ---------------------------------------------------------------------------
  // Official minutes screen
  // ---------------------------------------------------------------------------

  /// Screen title / menu entry.
  static const String screenTitle = 'المحضر الرسمي';

  /// Menu entry subtitle.
  static const String openOfficial = 'البيانات والحضور والتصويت والاعتماد';

  /// Shown when the meeting has no minutes yet.
  static const String noMinutes =
      'أنشئ المحضر أولاً، ثم أكمل بياناته الرسمية هنا.';

  /// Shown when the meeting uses the simplified template.
  static const String notOfficialTemplate =
      'هذا الاجتماع يستخدم قالب «اجتماع فريق (مبسّط)». اختر قالباً رسمياً '
      'لإظهار النصاب والتصويت والتواقيع والاعتماد.';

  /// Button: choose a template.
  static const String chooseTemplate = 'اختيار قالب المحضر';

  /// Lifecycle section header.
  static const String lifecycle = 'مراحل الاعتماد';

  /// Version label.
  static String version(int v) => 'الإصدار $v';

  /// Mark reviewed.
  static const String markReviewed = 'تأكيد المراجعة';

  /// Approve.
  static const String approve = 'اعتماد المحضر';

  /// Approve confirmation title.
  static const String approveTitle = 'اعتماد المحضر؟';

  /// Approve confirmation body.
  static const String approveBody =
      'سيُقفل محتوى المحضر ويُحسب رمز التحقق (SHA-256) ويُحفظ هذا الإصدار في '
      'السجل. أي تعديل لاحق يُنشئ إصداراً جديداً يحتاج إلى اعتماد وتوقيع من '
      'جديد.';

  /// New version.
  static const String newVersion = 'تعديل بإصدار جديد';

  /// New version confirmation title.
  static const String newVersionTitle = 'إنشاء إصدار جديد؟';

  /// New version confirmation body.
  static const String newVersionBody =
      'يبقى الإصدار المعتمد وتواقيعه محفوظاً في السجل، ويصبح المحضر مسودة '
      'جديدة قابلة للتعديل.';

  /// Versions history.
  static const String versions = 'سجل الإصدارات';

  /// No versions yet.
  static const String noVersions = 'لم يُعتمد أي إصدار بعد.';

  /// Hash label.
  static const String hashLabel = 'رمز التحقق (SHA-256)';

  /// Content changed after approval.
  static const String hashMismatch =
      'تغيّر محتوى المحضر بعد اعتماده؛ أنشئ إصداراً جديداً واعتمده من جديد.';

  /// Locked hint.
  static const String lockedHint =
      'المحضر معتمد ومقفل: لتعديل أي بيان أنشئ إصداراً جديداً.';

  /// Header data section.
  static const String headerSection = 'بيانات المحضر';

  /// Edit header data.
  static const String editHeader = 'تعديل البيانات';

  /// Committee label.
  static const String committee = 'المجلس / اللجنة';

  /// No committee.
  static const String noCommittee = 'بدون';

  /// Meeting number label.
  static const String meetingNumber = 'رقم الاجتماع';

  /// Invalid number.
  static const String numberInvalid = 'أدخل رقماً صحيحاً موجباً.';

  /// Place label.
  static const String place = 'المكان';

  /// Chair label.
  static const String chair = 'رئيس الاجتماع';

  /// Secretary label.
  static const String secretary = 'أمين السر';

  /// Start time label.
  static const String startTime = 'وقت البدء';

  /// End time label.
  static const String endTime = 'وقت الانتهاء';

  /// Date label.
  static const String date = 'التاريخ';

  /// Quorum rule label.
  static const String quorumRule = 'قاعدة النصاب';

  /// Majority rule label.
  static const String majorityRule = 'قاعدة التصويت';

  /// Casting vote switch.
  static const String castingVote = 'يرجَّح صوت الرئيس عند التساوي';

  /// Template default.
  static const String templateDefault = 'حسب القالب';

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  /// Attendance section / screen title.
  static const String attendance = 'كشف الحضور';

  /// Edit attendance.
  static const String editAttendance = 'تعديل كشف الحضور';

  /// Attendance intro.
  static const String attendanceIntro =
      'عُبّئ الكشف من الحضور المتوقعين والأصوات المتعرَّف عليها. راجع كل '
      'اسم وحدد حالته؛ المدعوون لا يُحتسبون في النصاب ولا في التصويت.';

  /// Needs confirmation badge.
  static const String needsConfirmation = 'يحتاج تأكيداً';

  /// Add person.
  static const String addPerson = 'إضافة شخص';

  /// Name field.
  static const String personName = 'الاسم';

  /// Title field.
  static const String personTitle = 'الصفة (اختياري)';

  /// Speaker link field.
  static const String spokeAs = 'تحدث في التسجيل باسم';

  /// No speaker link.
  static const String notLinked = 'لم يتحدث / غير مربوط';

  /// Refresh from attendees and speakers.
  static const String refreshAttendance = 'إضافة المتوقعين والمتحدثين الجدد';

  /// Empty attendance.
  static const String attendanceEmpty =
      'الكشف فارغ. أضف الأعضاء أو حدّث الكشف من الحضور المتوقعين.';

  /// Edit an entry.
  static const String edit = 'تعديل';

  /// Remove person.
  static const String removePerson = 'حذف من الكشف';

  /// Duplicate name.
  static const String duplicatePerson = 'هذا الاسم موجود في الكشف.';

  /// Quorum header.
  static const String quorum = 'النصاب';

  // ---------------------------------------------------------------------------
  // Votes
  // ---------------------------------------------------------------------------

  /// Resolutions section header.
  static const String resolutions = 'القرارات والتصويت';

  /// Vote review screen title.
  static const String voteReview = 'مراجعة التصويت';

  /// Vote review intro.
  static const String voteReviewIntro =
      'رصد المحرّك مواقف المتحدثين من كل قرار. أكّد المواقف «غير الواضحة» '
      'وصحّح ما يلزم قبل الاعتماد؛ لا يُضاف موقف لم يُعبَّر عنه.';

  /// Confirm a resolution's vote.
  static const String confirmVote = 'تأكيد التصويت';

  /// Confirmed badge.
  static const String confirmed = 'مؤكَّد';

  /// Needs review badge.
  static const String needsReview = 'بحاجة إلى مراجعة';

  /// Vote mode label.
  static const String voteMode = 'طريقة الإقرار';

  /// Evidence label.
  static String evidence(List<int> ids) =>
      'الدليل: ${ids.map((i) => '#$i').join('، ')}';

  /// No resolutions.
  static const String noResolutions = 'لا توجد قرارات في هذا المحضر.';

  /// Pending votes banner.
  static String pendingVotes(int n) =>
      'يوجد $n من القرارات فيها مواقف غير واضحة تحتاج إلى تأكيد.';

  /// Not counted (guest / unknown).
  static const String notCounted = 'غير محتسب';

  /// Saved.
  static const String voteSaved = 'حُفظت مراجعة التصويت.';

  // ---------------------------------------------------------------------------
  // Signatures
  // ---------------------------------------------------------------------------

  /// Signatures section.
  static const String signatures = 'التواقيع';

  /// Sign button.
  static const String sign = 'توقيع';

  /// Signed state.
  static String signedAt(String when) => 'وُقِّع في $when';

  /// Not signed.
  static const String notSigned = 'لم يوقّع بعد';

  /// Signing available after approval.
  static const String signAfterApproval =
      'تُجمع التواقيع على الجهاز بعد اعتماد المحضر.';

  /// Signature screen title.
  static const String signatureTitle = 'التوقيع على المحضر';

  /// Signature pad hint.
  static const String signatureHint = 'وقّع بإصبعك أو بالقلم داخل الإطار';

  /// Clear the pad.
  static const String clear = 'مسح';

  /// Signer name.
  static const String signerName = 'اسم الموقِّع';

  /// Signer role.
  static const String signerRole = 'الصفة';

  /// Save signature.
  static const String saveSignature = 'حفظ التوقيع';

  /// Empty signature.
  static const String emptySignature = 'ارسم التوقيع أولاً.';

  /// Signature stored notice.
  static const String signatureSaved = 'حُفظ التوقيع.';

  /// Remove a signature.
  static const String removeSignature = 'حذف التوقيع';

  /// Signature pad semantics.
  static const String signaturePadSemantics = 'مساحة التوقيع';

  /// What the signer approves.
  static String signerStatement(String hash) =>
      'بتوقيعك تقرّ بالمحضر المعتمد ذي رمز التحقق: $hash';

  // ---------------------------------------------------------------------------
  // Entity profile & templates (Settings)
  // ---------------------------------------------------------------------------

  /// Settings tile title.
  static const String entityTitle = 'الجهة والقوالب';

  /// Settings tile subtitle.
  static const String entitySubtitle =
      'اسم الجهة وشعارها والمجالس واللجان وقوالب Word للمحاضر الرسمية';

  /// Entity section.
  static const String entitySection = 'بيانات الجهة';

  /// Entity name.
  static const String entityName = 'اسم الجهة';

  /// Logo.
  static const String logo = 'الشعار';

  /// Pick logo.
  static const String pickLogo = 'اختيار صورة الشعار';

  /// Remove logo.
  static const String removeLogo = 'إزالة الشعار';

  /// No logo.
  static const String noLogo = 'لا يوجد شعار (PNG أو JPG)';

  /// Committees.
  static const String committees = 'المجالس واللجان';

  /// Committees helper.
  static const String committeesHelper =
      'تُرقَّم الاجتماعات تلقائياً لكل مجلس أو لجنة في كل سنة.';

  /// Add committee.
  static const String addCommittee = 'إضافة مجلس أو لجنة';

  /// Default chair.
  static const String defaultChair = 'رئيس الاجتماع الافتراضي';

  /// Default secretary.
  static const String defaultSecretary = 'أمين السر الافتراضي';

  /// Default place.
  static const String defaultPlace = 'المكان الافتراضي';

  /// Year style.
  static const String yearStyle = 'سنة ترقيم الاجتماعات';

  /// Hijri.
  static const String hijriYear = 'هجرية (12/1448هـ)';

  /// Gregorian.
  static const String gregorianYear = 'ميلادية (12/2026)';

  /// Saved.
  static const String saved = 'حُفظت البيانات.';

  /// Templates section.
  static const String templatesSection = 'قوالب Word الخاصة بجهتك';

  /// Templates intro.
  static const String templatesIntro =
      'ارفع قالب محضر جهتك بصيغة .docx بعد وضع الحقول مثل {{meeting_title}} '
      'و{{resolutions}} و{{signatures}} في أماكنها. يحتفظ التصدير بتنسيق '
      'قالبك وخطوطه واتجاهه، ويُستخدم القالب الذي تختاره لكل اجتماع.';

  /// Upload template.
  static const String uploadTemplate = 'رفع قالب Word';

  /// Download sample.
  static const String downloadSample = 'تنزيل القالب النموذجي';

  /// Sample file name.
  static const String sampleFileName = 'قالب محضر إنصاتو النموذجي.docx';

  /// Placeholder guide.
  static const String placeholderGuide = 'دليل الحقول';

  /// No templates.
  static const String noTemplates = 'لم يُرفع أي قالب بعد.';

  /// Template name.
  static const String templateName = 'اسم القالب';

  /// Base template.
  static const String baseTemplate = 'قواعد القالب (الصياغة والنصاب والتواقيع)';

  /// Delete template.
  static const String deleteTemplate = 'حذف القالب';

  /// Delete template confirm.
  static const String deleteTemplateBody =
      'ستعود الاجتماعات التي تستخدم هذا القالب إلى القالب المبسّط.';

  /// Upload done.
  static String templateUploaded(int n) => 'رُفع القالب، وفيه $n من الحقول.';

  /// Placeholders count.
  static String placeholdersCount(int n) => '$n من الحقول';

  /// File read failure.
  static const String fileReadFailed = 'تعذّرت قراءة الملف.';

  /// SVG note.
  static const String logoFormats = 'PNG أو JPG، بحد أقصى 4 ميغابايت';
}
