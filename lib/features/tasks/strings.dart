// Arabic (MSA) UI strings of action-item tracking (F9). Shared words (save,
// cancel, delete, …) come from `S` in lib/ui/strings_ar.dart.

import '../../core/models.dart';

/// Arabic strings of the task-tracking feature.
abstract final class TS {
  // ---------------------------------------------------------------------------
  // Navigation & screen
  // ---------------------------------------------------------------------------

  /// Tasks screen title / navigation label.
  static const String tasksTitle = 'المهام';

  /// One-line description for a navigation entry or settings tile.
  static const String tasksSubtitle =
      'المهام المستخرجة من المحاضر: تابع حالتها وعدّلها وأكّد تحديثاتها';

  /// Add-task button.
  static const String addTask = 'إضافة مهمة';

  /// Empty state (no tasks at all): title.
  static const String emptyTitle = 'لا توجد مهام بعد';

  /// Empty state (no tasks at all): body.
  static const String emptyBody =
      'تظهر هنا المهام التي يستخرجها محرّك المحاضر من بنود «المهام '
      'والمسؤوليات» في كل محضر، ويمكنك أيضًا إضافة مهمة يدويًا.';

  /// Nothing matches the current filters.
  static const String noMatches = 'لا توجد مهام تطابق عوامل التصفية الحالية.';

  /// Clear all filters.
  static const String clearFilters = 'مسح عوامل التصفية';

  /// Error loading tasks.
  static const String loadFailed = 'تعذّر تحميل المهام.';

  /// Error saving a task change.
  static const String saveFailed = 'تعذّر حفظ التغيير. حاول مرة أخرى.';

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Status label.
  static String status(TaskStatus s) => switch (s) {
    TaskStatus.open => 'مفتوحة',
    TaskStatus.done => 'منجزة',
    TaskStatus.cancelled => 'ملغاة',
  };

  /// Status filter chip with its count, e.g. «مفتوحة (3)».
  static String statusCount(String label, int n) => '$label ($n)';

  /// Filter: all statuses.
  static const String allStatuses = 'الكل';

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  /// Owner filter label.
  static const String ownerFilter = 'المسؤول';

  /// Owner filter: any owner.
  static const String anyOwner = 'كل المسؤولين';

  /// Owner filter / tile: task without an owner.
  static const String noOwner = 'بلا مسؤول';

  /// Meeting filter label.
  static const String meetingFilter = 'الاجتماع';

  /// Meeting filter: any meeting.
  static const String anyMeeting = 'كل الاجتماعات';

  /// Meeting filter / tile: task entered manually (or its meeting deleted).
  static const String noMeeting = 'مُدخلة يدويًا';

  /// Search field hint.
  static const String searchHint = 'ابحث في المهام';

  /// Clear search tooltip.
  static const String clearSearch = 'مسح البحث';

  /// Header with the number of shown tasks.
  static String shownCount(int n) => switch (n) {
    1 => 'مهمة واحدة',
    2 => 'مهمتان',
    >= 3 && <= 10 => '$n مهام',
    _ => '$n مهمة',
  };

  // ---------------------------------------------------------------------------
  // Task tile
  // ---------------------------------------------------------------------------

  /// Owner line.
  static String ownerLine(String owner) => 'المسؤول: $owner';

  /// Due line.
  static String dueLine(String due) => 'الموعد: $due';

  /// Source meeting line.
  static String sourceLine(String title) => 'من اجتماع: $title';

  /// Source meeting deleted.
  static const String sourceDeleted = 'من اجتماع محذوف';

  /// Number of evidence segments.
  static String evidenceCount(int n) => switch (n) {
    1 => 'مستندة إلى مقطع واحد',
    2 => 'مستندة إلى مقطعين',
    >= 3 && <= 10 => 'مستندة إلى $n مقاطع',
    _ => 'مستندة إلى $n مقطعًا',
  };

  /// Semantics: checkbox marking a task done.
  static String markDoneSemantics(String task) => 'تعليم «$task» منجزة';

  /// Semantics: checkbox re-opening a done task.
  static String reopenSemantics(String task) => 'إعادة فتح «$task»';

  /// Menu: task actions tooltip.
  static const String taskMenu = 'إجراءات المهمة';

  /// Menu: edit.
  static const String edit = 'تعديل';

  /// Menu: mark done.
  static const String markDone = 'تعليمها منجزة';

  /// Menu: re-open.
  static const String reopen = 'إعادة فتحها';

  /// Menu: cancel the task.
  static const String cancelTask = 'إلغاء المهمة';

  /// Menu: open the source meeting.
  static const String openMeeting = 'فتح الاجتماع';

  /// Snack: task marked done.
  static const String markedDone = 'عُلّمت المهمة منجزة.';

  /// Snack: task re-opened.
  static const String reopened = 'أُعيد فتح المهمة.';

  /// Snack: task cancelled.
  static const String cancelled = 'أُلغيت المهمة.';

  /// Snack: task saved.
  static const String saved = 'حُفظت المهمة.';

  /// Snack: task added.
  static const String added = 'أُضيفت المهمة.';

  /// Snack: task deleted.
  static const String deleted = 'حُذفت المهمة.';

  /// Undo action of a snack.
  static const String undo = 'تراجع';

  /// Delete confirmation title.
  static const String deleteTitle = 'حذف المهمة؟';

  /// Delete confirmation body.
  static String deleteBody(String task) =>
      'ستُحذف المهمة «$task» وأي تحديثات مقترحة لها. لا يمكن التراجع عن '
      'ذلك. لن يتغيّر المحضر الذي ذُكرت فيه.';

  // ---------------------------------------------------------------------------
  // Edit dialog
  // ---------------------------------------------------------------------------

  /// Dialog title (new).
  static const String newTaskTitle = 'مهمة جديدة';

  /// Dialog title (edit).
  static const String editTaskTitle = 'تعديل المهمة';

  /// Task field label.
  static const String taskLabel = 'المهمة';

  /// Task field hint.
  static const String taskHint = 'مثال: إعداد مسودة الميزانية';

  /// Validation: blank task.
  static const String taskEmpty = 'اكتب نص المهمة.';

  /// Validation: task too long.
  static String taskTooLong(int max) => 'النص أطول من $max حرف.';

  /// Owner field label.
  static const String ownerLabel = 'المسؤول (اختياري)';

  /// Owner field hint.
  static const String ownerHint = 'اكتب اسمًا أو اختر متحدثًا';

  /// Owner: pick a speaker button.
  static const String pickSpeaker = 'اختيار من المتحدثين';

  /// Speaker picker title.
  static const String pickSpeakerTitle = 'اختر المسؤول';

  /// Clear owner tooltip.
  static const String clearOwner = 'إزالة المسؤول';

  /// Owner linked to a speaker of the voice library.
  static const String ownerLinked = 'مرتبط بمتحدث في مكتبة الأصوات';

  /// Due field label.
  static const String dueLabel = 'الموعد (اختياري)';

  /// Due field hint.
  static const String dueHint = 'مثال: الخميس القادم أو 2026/12/01';

  /// Validation: field too long.
  static String fieldTooLong(int max) => 'النص أطول من $max حرف.';

  /// Status field label.
  static const String statusLabel = 'الحالة';

  // ---------------------------------------------------------------------------
  // Pending task updates (proposed by minutes)
  // ---------------------------------------------------------------------------

  /// Section header.
  static const String pendingHeader = 'تحديثات مقترحة بانتظار تأكيدك';

  /// Section explanation.
  static const String pendingBody =
      'رصد محرّك المحاضر في اجتماعات لاحقة ما يدل على تقدّم هذه المهام. لا '
      'يُطبَّق أي تغيير على حالة مهمة قبل أن تؤكّده.';

  /// Proposed status change.
  static String proposedStatus(TaskStatus s) =>
      'التغيير المقترح: ${status(s)}';

  /// Progress note only (no status change).
  static const String progressOnly = 'ملاحظة تقدّم دون تغيير الحالة';

  /// Task already has the proposed status.
  static const String alreadyApplied = 'حالة المهمة مطابقة للمقترح بالفعل';

  /// The task was deleted since.
  static const String taskGone = 'حُذفت هذه المهمة';

  /// Where the update came from.
  static String proposedIn(String title) => 'من محضر: $title';

  /// Apply the update.
  static const String apply = 'تطبيق';

  /// Acknowledge a progress note.
  static const String acknowledge = 'اطّلعت';

  /// Reject the update.
  static const String reject = 'رفض';

  /// Apply every applicable update.
  static String applyAll(int n) => 'تطبيق الكل ($n)';

  /// Apply-all confirmation title.
  static const String applyAllTitle = 'تطبيق كل التحديثات؟';

  /// Apply-all confirmation body.
  static String applyAllBody(int n) =>
      'ستُغيَّر حالة المهام المعنية ($n) وفق ما اقترحته المحاضر. راجعها '
      'أولًا إن لم تكن متأكدًا.';

  /// Snack: update applied.
  static const String applied = 'طُبّق التحديث على المهمة.';

  /// Snack: update rejected / acknowledged.
  static const String dismissed = 'أُزيل التحديث المقترح.';

  /// Snack: n updates applied.
  static String appliedCount(int n) => 'طُبّقت التحديثات ($n).';

  /// Snack: the update no longer exists.
  static const String updateGone =
      'لم يعد هذا التحديث موجودًا، ربما عولج من شاشة أخرى.';

  // ---------------------------------------------------------------------------
  // Meeting panel
  // ---------------------------------------------------------------------------

  /// Meeting panel: tasks created by this meeting.
  static const String meetingTasksHeader = 'مهام هذا الاجتماع';

  /// Meeting panel: none.
  static const String meetingTasksEmpty =
      'لم تُستخرج مهام من محضر هذا الاجتماع.';

  /// Meeting panel: updates proposed by this meeting.
  static const String meetingUpdatesHeader = 'تحديثات لمهام سابقة';

  /// Open the tasks screen.
  static const String openTasksScreen = 'كل المهام';

  // ---------------------------------------------------------------------------
  // Open-tasks banner (recording start)
  // ---------------------------------------------------------------------------

  /// Banner title.
  static String bannerTitle(int n) =>
      'مهام مفتوحة للحاضرين المتوقَّعين: ${shownCount(n)}';

  /// Banner explanation.
  static const String bannerBody =
      'قد يكون هذا الاجتماع مناسبًا لمتابعتها. سيُبلَغ محرّك المحاضر بها '
      'ليقترح تحديث حالتها إن نوقشت.';

  /// More tasks of the same attendee.
  static String moreTasks(int n) => '+ ${shownCount(n)} أخرى';

  /// Hide the banner.
  static const String hideBanner = 'إخفاء';

  /// Expand / collapse the banner.
  static const String showDetails = 'عرض التفاصيل';

  /// Collapse the banner.
  static const String hideDetails = 'إخفاء التفاصيل';
}
