// Arabic (MSA) UI strings of the glossary (F2) and meeting context (F3)
// feature. Shared words (save, cancel, delete, …) come from `S` in
// lib/ui/strings_ar.dart.

import '../../core/models.dart';

/// Arabic strings of the glossary and meeting-context feature.
abstract final class CS {
  // ---------------------------------------------------------------------------
  // Glossary screen (F2)
  // ---------------------------------------------------------------------------

  /// Glossary screen title / navigation label.
  static const String glossaryTitle = 'قاموس المصطلحات';

  /// One-line description for a settings tile or navigation entry.
  static const String glossarySubtitle =
      'أسماء وجهات ومصطلحات تُكتب كما تريدها في التفريغ والمحضر';

  /// Intro paragraph at the top of the glossary screen.
  static const String glossaryIntro =
      'أضف الأسماء والمصطلحات التي يكثر ورودها في اجتماعاتك بالتهجئة '
      'الصحيحة. يستعملها إنصاتو في موضعين: تُرسَل إلى خدمة التفريغ '
      'السحابية (Deepgram) حين تكون مفعّلة لتحسين التعرّف عليها، وتُضمَّن '
      'في طلب كتابة المحضر ليصحّح محرّك المحاضر الأخطاء نحو هذه التهجئة '
      'حين يدعمها السياق. لا يُرسَل القاموس إلى أي خدمة لم تخترها.';

  /// Search field hint.
  static const String searchHint = 'ابحث في المصطلحات';

  /// Clear search tooltip.
  static const String clearSearch = 'مسح البحث';

  /// Filter chip: all categories.
  static const String allCategories = 'الكل';

  /// Add-term button.
  static const String addTerm = 'إضافة مصطلح';

  /// Edit-term dialog title.
  static const String editTerm = 'تعديل المصطلح';

  /// Term field label.
  static const String termLabel = 'المصطلح بالتهجئة الصحيحة';

  /// Term field hint.
  static const String termHint = 'مثال: Kubernetes أو مجموعة الراجحي';

  /// Arabic spelling field label.
  static const String arSpellingLabel = 'التهجئة العربية أو الترجمة (اختياري)';

  /// Arabic spelling field hint.
  static const String arSpellingHint = 'مثال: كوبرنيتس';

  /// Category field label.
  static const String categoryLabel = 'التصنيف';

  /// Validation: blank term.
  static const String termEmpty = 'اكتب المصطلح.';

  /// Validation: term too long.
  static String termTooLong(int max) => 'المصطلح أطول من $max حرفًا.';

  /// Validation: duplicate term in the same scope.
  static const String termDuplicate = 'هذا المصطلح موجود في القائمة بالفعل.';

  /// Snack: term added.
  static const String termAdded = 'أُضيف المصطلح.';

  /// Snack: term saved.
  static const String termSaved = 'حُفظ المصطلح.';

  /// Snack: term deleted.
  static const String termDeleted = 'حُذف المصطلح.';

  /// Undo action.
  static const String undo = 'تراجع';

  /// Delete confirmation title.
  static const String deleteTermTitle = 'حذف المصطلح؟';

  /// Delete confirmation body.
  static String deleteTermBody(String term) =>
      'سيُحذف «$term» من القاموس ولن يُستعمل في الاجتماعات القادمة. '
      'المحاضر المكتوبة سابقًا لا تتغير.';

  /// Empty glossary title.
  static const String emptyTitle = 'القاموس فارغ';

  /// Empty glossary body.
  static const String emptyBody =
      'أضف أسماء الأشخاص والجهات والمصطلحات التقنية التي يخطئ التفريغ في '
      'كتابتها عادةً.';

  /// No search results.
  static const String noResults = 'لا توجد مصطلحات مطابقة.';

  /// Section header: speakers' names.
  static const String speakerNamesHeader = 'أسماء المتحدثين (تُضاف تلقائيًا)';

  /// Explanation under the speaker names header.
  static const String speakerNamesBody =
      'كل متحدث سمّيته في مكتبة الأصوات يُعامَل كمصطلح من فئة «شخص» دون '
      'أن تضيفه هنا. لتغيير التهجئة أعد تسمية المتحدث.';

  /// Section header: where terms are used.
  static const String usageHeader = 'أين يُستعمل القاموس';

  /// Deepgram usage line.
  static String deepgramUsage(int used, int total, int max) => total <= max
      ? 'التفريغ السحابي (Deepgram): يُرسَل $used مصطلحًا مع كل مقطع.'
      : 'التفريغ السحابي (Deepgram): يقبل $max مصطلحًا فقط لكل طلب، فيُرسَل '
            'أول $used من أصل $total (مصطلحات الاجتماع والحضور أولًا).';

  /// Deepgram not in use.
  static const String deepgramOff =
      'التفريغ السحابي (Deepgram) غير مفعّل، فلا يُرسَل القاموس إليه. '
      'التفريغ على الجهاز لا يستعمل القاموس.';

  /// Minutes-prompt usage line.
  static String minutesUsage(int total) =>
      'كتابة المحضر: تُضمَّن المصطلحات ($total) كتهجئات معتمدة في الطلب '
      'المرسَل إلى محرّك المحاضر الذي اخترته.';

  /// Category header with its count.
  static String categoryCount(String label, int n) => '$label ($n)';

  /// Export action.
  static const String exportList = 'نسخ القائمة كنص';

  /// Import action.
  static const String importList = 'استيراد من نص';

  /// Snack after copying the list.
  static String exported(int n) => 'نُسخ $n مصطلحًا إلى الحافظة.';

  /// Nothing to export.
  static const String nothingToExport = 'لا توجد مصطلحات لنسخها.';

  /// Import dialog title.
  static const String importTitle = 'استيراد مصطلحات';

  /// Import dialog body (format).
  static const String importBody =
      'الصق سطرًا لكل مصطلح بالصيغة:\n'
      'المصطلح | التهجئة العربية | التصنيف\n'
      'الحقلان الثاني والثالث اختياريان. التصنيف واحد من: شخص، جهة، '
      'مصطلح تقني، أخرى. المصطلح الموجود يُحدَّث ولا يتكرر.';

  /// Import field label.
  static const String importFieldLabel = 'المصطلحات';

  /// Import confirm button.
  static const String importAction = 'استيراد';

  /// Import: nothing valid found.
  static const String importNothing = 'لم يُعثر على مصطلحات صالحة في النص.';

  /// Import result.
  static String imported(int n, int skipped) => skipped == 0
      ? 'استُورد $n مصطلحًا.'
      : 'استُورد $n مصطلحًا وتُجوهل $skipped سطرًا غير صالح.';

  /// Generic glossary save failure.
  static const String saveFailed = 'تعذّر حفظ القاموس. حاول مرة أخرى.';

  /// Glossary menu tooltip (import / export).
  static const String glossaryMenu = 'خيارات القاموس';

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  /// Arabic label of [c].
  static String category(GlossaryCategory c) => switch (c) {
    GlossaryCategory.person => 'شخص',
    GlossaryCategory.organisation => 'جهة',
    GlossaryCategory.technical => 'مصطلح تقني',
    GlossaryCategory.other => 'أخرى',
  };

  // ---------------------------------------------------------------------------
  // Meeting context sheet (F3)
  // ---------------------------------------------------------------------------

  /// Sheet title before recording.
  static const String setupTitle = 'سياق الاجتماع';

  /// Sheet subtitle before recording.
  static const String setupIntro =
      'كل الحقول اختيارية. جدول الأعمال يرتّب موضوعات المحضر ويبيّن ما '
      'نوقش منه وما لم يُناقش، والحضور المتوقعون ومصطلحات الاجتماع تحسّن '
      'كتابة الأسماء. يمكنك تعديل ذلك لاحقًا.';

  /// Sheet title when editing an existing meeting.
  static const String editTitle = 'تعديل سياق الاجتماع';

  /// Sheet subtitle when editing.
  static const String editIntro =
      'تُستعمل التعديلات عند إعادة كتابة المحضر. المحضر الحالي لا يتغير '
      'حتى تعيد توليده.';

  /// Meeting title field.
  static const String titleLabel = 'عنوان الاجتماع (اختياري)';

  /// Meeting title hint.
  static const String titleHint = 'مثال: اجتماع لجنة المشتريات';

  /// Agenda section.
  static const String agendaHeader = 'جدول الأعمال';

  /// Agenda field label.
  static const String agendaItemLabel = 'بند جديد';

  /// Agenda field hint.
  static const String agendaItemHint = 'اكتب البند ثم اضغط إضافة';

  /// Add agenda item.
  static const String addAgendaItem = 'إضافة البند';

  /// Empty agenda.
  static const String agendaEmpty = 'لا بنود بعد.';

  /// Agenda item semantics.
  static String agendaItemSemantics(int n, int total, String text) =>
      'البند $n من $total: $text';

  /// Move item up.
  static const String moveUp = 'نقل إلى الأعلى';

  /// Move item down.
  static const String moveDown = 'نقل إلى الأسفل';

  /// Edit agenda item.
  static const String editAgendaItem = 'تعديل البند';

  /// Remove agenda item.
  static const String removeAgendaItem = 'حذف البند';

  /// Drag handle hint.
  static const String dragToReorder = 'اسحب لإعادة الترتيب';

  /// Agenda item validation.
  static const String agendaItemEmpty = 'اكتب نص البند.';

  /// Agenda full.
  static String agendaFull(int max) => 'الحد الأقصى $max بندًا.';

  /// Attendees section.
  static const String attendeesHeader = 'الحضور المتوقعون';

  /// Attendee field label.
  static const String attendeeLabel = 'اسم الحاضر';

  /// Attendee field hint.
  static const String attendeeHint = 'اختر من مكتبة الأصوات أو اكتب اسمًا';

  /// Add attendee.
  static const String addAttendee = 'إضافة الحاضر';

  /// Attendee from the voice library.
  static const String fromVoiceLibrary = 'من مكتبة الأصوات';

  /// Remove attendee tooltip.
  static String removeAttendee(String name) => 'إزالة $name';

  /// No attendees.
  static const String attendeesEmpty = 'لم يُحدَّد حضور.';

  /// Attendees full.
  static String attendeesFull(int max) => 'الحد الأقصى $max اسمًا.';

  /// Attendee already listed.
  static const String attendeeDuplicate = 'الاسم مضاف بالفعل.';

  /// Notes section.
  static const String notesHeader = 'ملاحظات السياق';

  /// Notes field label.
  static const String notesLabel = 'خلفية تساعد على فهم النقاش (اختياري)';

  /// Notes field hint.
  static const String notesHint =
      'مثال: متابعة لاجتماع الأسبوع الماضي حول عقد الصيانة';

  /// Meeting-only terms section.
  static const String meetingTermsHeader = 'مصطلحات هذا الاجتماع';

  /// Meeting-only terms explanation.
  static const String meetingTermsBody =
      'تُضاف إلى القاموس العام لهذا الاجتماع فقط.';

  /// No meeting terms.
  static const String meetingTermsEmpty = 'لا مصطلحات خاصة.';

  /// Add a meeting term.
  static const String addMeetingTerm = 'إضافة مصطلح للاجتماع';

  /// Remove a meeting term.
  static String removeTerm(String term) => 'إزالة $term';

  /// Start recording with the context.
  static const String startRecording = 'ابدأ التسجيل';

  /// Start without context.
  static const String skipAndStart = 'ابدأ دون سياق';

  /// Discard changes confirmation.
  static const String discardTitle = 'تجاهل التعديلات؟';

  /// Discard body.
  static const String discardBody = 'لن تُحفظ التعديلات التي أدخلتها.';

  /// Discard action.
  static const String discard = 'تجاهل';

  /// Context saved.
  static const String contextSaved = 'حُفظ سياق الاجتماع.';

  /// Context save failure.
  static const String contextSaveFailed =
      'تعذّر حفظ سياق الاجتماع. حاول مرة أخرى.';

  /// Meeting not found.
  static const String meetingMissing = 'لم يعد هذا الاجتماع موجودًا.';

  /// Meeting terms could not be saved after starting.
  static const String meetingTermsSaveFailed =
      'بدأ التسجيل، لكن تعذّر حفظ مصطلحات الاجتماع. أضفها من «تعديل سياق '
      'الاجتماع».';

  // ---------------------------------------------------------------------------
  // Context card (meeting detail)
  // ---------------------------------------------------------------------------

  /// Card title.
  static const String contextCardTitle = 'سياق الاجتماع';

  /// Edit button.
  static const String editContext = 'تعديل السياق';

  /// Add-context button when nothing was entered.
  static const String addContext = 'إضافة سياق';

  /// Empty context.
  static const String contextEmpty =
      'لم يُدخَل جدول أعمال أو حضور متوقعون لهذا الاجتماع.';

  /// Agenda count.
  static String agendaCount(int n) => 'جدول الأعمال ($n)';

  /// Attendees count.
  static String attendeesCount(int n) => 'الحضور المتوقعون ($n)';

  /// Meeting terms count.
  static String meetingTermsCount(int n) => 'مصطلحات الاجتماع ($n)';
}
