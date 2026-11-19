// Pure logic of action-item tracking (F9): owner identity and labels,
// filtering / sorting of the tasks screen, edit drafts and validation, the
// classification of pending task updates proposed by minutes, and matching
// expected attendees to task owners for the recording-start banner.
//
// No Flutter imports; unit-tested in test/features/tasks/.

import '../../core/models.dart';
import '../../ui/format.dart' show normalizeForSearch;

/// Longest accepted task text (characters).
const int kMaxTaskLength = 500;

/// Longest accepted owner name (characters).
const int kMaxTaskOwnerLength = 120;

/// Longest accepted due text (characters).
const int kMaxTaskDueLength = 80;

/// Collapses inner whitespace and trims.
String collapseTaskSpaces(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

// ---------------------------------------------------------------------------
// Owners
// ---------------------------------------------------------------------------

/// Owner filter value of tasks without an owner.
const String kNoOwnerKey = 'none';

/// The owner's display name of [task]: the linked speaker's current name
/// (it follows renames in the voice library), else the free-text owner, else
/// null.
String? taskOwnerLabel(TrackedTask task, Map<String, Speaker> speakersById) {
  final id = task.ownerSpeakerId;
  if (id != null) {
    final s = speakersById[id];
    if (s != null && s.name.trim().isNotEmpty) return collapseTaskSpaces(s.name);
  }
  final t = task.ownerText;
  if (t == null) return null;
  final c = collapseTaskSpaces(t);
  return c.isEmpty ? null : c;
}

/// Grouping key of [task]'s owner: the normalised display name (so a person
/// written as free text in one task and linked to a speaker in another is
/// one owner), or [kNoOwnerKey].
String taskOwnerKey(TrackedTask task, Map<String, Speaker> speakersById) {
  final label = taskOwnerLabel(task, speakersById);
  if (label == null) return kNoOwnerKey;
  final n = normalizeForSearch(label);
  return n.isEmpty ? kNoOwnerKey : 'name:$n';
}

/// One entry of the owner filter.
class TaskOwnerOption {
  /// Creates an option.
  const TaskOwnerOption({
    required this.key,
    required this.label,
    required this.count,
  });

  /// [taskOwnerKey] value.
  final String key;

  /// Display name (null for [kNoOwnerKey]).
  final String? label;

  /// Number of tasks.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is TaskOwnerOption &&
      other.key == key &&
      other.label == label &&
      other.count == count;

  @override
  int get hashCode => Object.hash(key, label, count);

  @override
  String toString() => 'TaskOwnerOption($key, $label, $count)';
}

/// The distinct owners of [tasks], most tasks first then by name; tasks
/// without an owner come last. The label of a key is the first (newest)
/// spelling seen.
List<TaskOwnerOption> taskOwnerOptions(
  Iterable<TrackedTask> tasks,
  Map<String, Speaker> speakersById,
) {
  final labels = <String, String?>{};
  final counts = <String, int>{};
  for (final t in tasks) {
    final k = taskOwnerKey(t, speakersById);
    labels.putIfAbsent(
      k,
      () => k == kNoOwnerKey ? null : taskOwnerLabel(t, speakersById),
    );
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final list = [
    for (final e in counts.entries)
      TaskOwnerOption(key: e.key, label: labels[e.key], count: e.value),
  ];
  list.sort((a, b) {
    if ((a.key == kNoOwnerKey) != (b.key == kNoOwnerKey)) {
      return a.key == kNoOwnerKey ? 1 : -1;
    }
    final c = b.count.compareTo(a.count);
    return c != 0 ? c : (a.label ?? '').compareTo(b.label ?? '');
  });
  return list;
}

// ---------------------------------------------------------------------------
// Meetings
// ---------------------------------------------------------------------------

/// Meeting filter value of tasks without a source meeting (entered manually,
/// or their meeting was deleted).
const String kNoMeetingKey = '';

/// One entry of the meeting filter.
class TaskMeetingOption {
  /// Creates an option.
  const TaskMeetingOption({
    required this.key,
    required this.title,
    required this.count,
    this.createdAt,
  });

  /// Meeting id, or [kNoMeetingKey].
  final String key;

  /// Meeting title (null for [kNoMeetingKey] or an unknown meeting).
  final String? title;

  /// Meeting date (null when unknown).
  final DateTime? createdAt;

  /// Number of tasks.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is TaskMeetingOption &&
      other.key == key &&
      other.title == title &&
      other.createdAt == createdAt &&
      other.count == count;

  @override
  int get hashCode => Object.hash(key, title, createdAt, count);
}

/// The source meetings of [tasks], newest meeting first; tasks without a
/// (known) meeting are grouped under [kNoMeetingKey], last.
List<TaskMeetingOption> taskMeetingOptions(
  Iterable<TrackedTask> tasks,
  Map<String, Meeting> meetingsById,
) {
  final counts = <String, int>{};
  for (final t in tasks) {
    final k = taskMeetingKey(t, meetingsById);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final list = [
    for (final e in counts.entries)
      TaskMeetingOption(
        key: e.key,
        title: meetingsById[e.key]?.title,
        createdAt: meetingsById[e.key]?.createdAt,
        count: e.value,
      ),
  ];
  list.sort((a, b) {
    if ((a.key == kNoMeetingKey) != (b.key == kNoMeetingKey)) {
      return a.key == kNoMeetingKey ? 1 : -1;
    }
    final da = a.createdAt, db = b.createdAt;
    if (da != null && db != null) return db.compareTo(da);
    return (a.title ?? '').compareTo(b.title ?? '');
  });
  return list;
}

/// Meeting filter key of [task]: its source meeting id when that meeting is
/// known, else [kNoMeetingKey].
String taskMeetingKey(TrackedTask task, Map<String, Meeting> meetingsById) {
  final id = task.sourceMeetingId;
  return id != null && meetingsById.containsKey(id) ? id : kNoMeetingKey;
}

// ---------------------------------------------------------------------------
// Filtering
// ---------------------------------------------------------------------------

/// The filters of the tasks screen. Null fields do not filter.
class TaskFilter {
  /// Creates a filter (default: open tasks only).
  const TaskFilter({
    this.status = TaskStatus.open,
    this.ownerKey,
    this.meetingKey,
    this.query = '',
  });

  /// No filter at all.
  static const TaskFilter none = TaskFilter(status: null);

  /// Status, or null for every status.
  final TaskStatus? status;

  /// [taskOwnerKey] value, or null for every owner.
  final String? ownerKey;

  /// [taskMeetingKey] value, or null for every meeting.
  final String? meetingKey;

  /// Free-text search (task, owner, due).
  final String query;

  /// True when only the default status filter is set.
  bool get isDefault =>
      status == TaskStatus.open &&
      ownerKey == null &&
      meetingKey == null &&
      query.trim().isEmpty;

  /// Copy with replaced fields; `clear*` flags reset nullable fields.
  TaskFilter copyWith({
    TaskStatus? status,
    bool allStatuses = false,
    String? ownerKey,
    bool clearOwner = false,
    String? meetingKey,
    bool clearMeeting = false,
    String? query,
  }) => TaskFilter(
    status: allStatuses ? null : (status ?? this.status),
    ownerKey: clearOwner ? null : (ownerKey ?? this.ownerKey),
    meetingKey: clearMeeting ? null : (meetingKey ?? this.meetingKey),
    query: query ?? this.query,
  );

  @override
  bool operator ==(Object other) =>
      other is TaskFilter &&
      other.status == status &&
      other.ownerKey == ownerKey &&
      other.meetingKey == meetingKey &&
      other.query == query;

  @override
  int get hashCode => Object.hash(status, ownerKey, meetingKey, query);

  @override
  String toString() =>
      'TaskFilter(${status?.name}, owner: $ownerKey, meeting: $meetingKey, '
      'query: $query)';
}

/// True when [task] matches [filter] (ignoring its status when
/// [ignoreStatus], used for the per-status counts).
bool taskMatches(
  TrackedTask task,
  TaskFilter filter, {
  required Map<String, Speaker> speakersById,
  required Map<String, Meeting> meetingsById,
  bool ignoreStatus = false,
}) {
  if (!ignoreStatus && filter.status != null && task.status != filter.status) {
    return false;
  }
  if (filter.ownerKey != null &&
      taskOwnerKey(task, speakersById) != filter.ownerKey) {
    return false;
  }
  if (filter.meetingKey != null &&
      taskMeetingKey(task, meetingsById) != filter.meetingKey) {
    return false;
  }
  final q = normalizeForSearch(filter.query);
  if (q.isEmpty) return true;
  final hay = normalizeForSearch(
    [
      task.task,
      taskOwnerLabel(task, speakersById) ?? '',
      task.dueText ?? '',
    ].join(' '),
  );
  return q.split(' ').every(hay.contains);
}

/// Display order: open, done, cancelled; newest first within a status
/// (ties by id, newest first).
int compareTasks(TrackedTask a, TrackedTask b) {
  final s = a.status.index.compareTo(b.status.index);
  if (s != 0) return s;
  final c = b.createdAt.compareTo(a.createdAt);
  return c != 0 ? c : b.id.compareTo(a.id);
}

/// [tasks] matching [filter], in [compareTasks] order.
List<TrackedTask> filterTasks(
  Iterable<TrackedTask> tasks,
  TaskFilter filter, {
  required Map<String, Speaker> speakersById,
  required Map<String, Meeting> meetingsById,
}) => [
  for (final t in tasks)
    if (taskMatches(
      t,
      filter,
      speakersById: speakersById,
      meetingsById: meetingsById,
    ))
      t,
]..sort(compareTasks);

/// Number of tasks per status among those matching every other part of
/// [filter] (owner, meeting, search), for the status chips.
Map<TaskStatus, int> taskStatusCounts(
  Iterable<TrackedTask> tasks,
  TaskFilter filter, {
  required Map<String, Speaker> speakersById,
  required Map<String, Meeting> meetingsById,
}) {
  final out = {for (final s in TaskStatus.values) s: 0};
  for (final t in tasks) {
    if (taskMatches(
      t,
      filter,
      speakersById: speakersById,
      meetingsById: meetingsById,
      ignoreStatus: true,
    )) {
      out[t.status] = out[t.status]! + 1;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Editing
// ---------------------------------------------------------------------------

/// An edited, not yet stored task.
class TaskDraft {
  /// Creates a draft.
  const TaskDraft({
    required this.task,
    this.ownerText,
    this.ownerSpeakerId,
    this.dueText,
    this.status = TaskStatus.open,
  });

  /// Draft of an existing [t]; the owner text shows the linked speaker's
  /// current name when there is one.
  factory TaskDraft.of(TrackedTask t, Map<String, Speaker> speakersById) =>
      TaskDraft(
        task: t.task,
        ownerText: taskOwnerLabel(t, speakersById),
        ownerSpeakerId: t.ownerSpeakerId,
        dueText: t.dueText,
        status: t.status,
      );

  /// Task text.
  final String task;

  /// Owner as typed (or the linked speaker's name).
  final String? ownerText;

  /// Linked speaker, if any.
  final String? ownerSpeakerId;

  /// Due text.
  final String? dueText;

  /// Status.
  final TaskStatus status;

  /// Trimmed copy: whitespace collapsed, blank optional fields → null, and
  /// the speaker link resolved with [resolveTaskOwner].
  TaskDraft normalized(Map<String, Speaker> speakersById) {
    String? opt(String? s) {
      if (s == null) return null;
      final c = collapseTaskSpaces(s);
      return c.isEmpty ? null : c;
    }

    final owner = opt(ownerText);
    return TaskDraft(
      task: collapseTaskSpaces(task),
      ownerText: owner,
      ownerSpeakerId: resolveTaskOwner(owner, ownerSpeakerId, speakersById),
      dueText: opt(dueText),
      status: status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskDraft &&
      other.task == task &&
      other.ownerText == ownerText &&
      other.ownerSpeakerId == ownerSpeakerId &&
      other.dueText == dueText &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(task, ownerText, ownerSpeakerId, dueText, status);

  @override
  String toString() =>
      'TaskDraft($task, $ownerText, $ownerSpeakerId, $dueText, $status)';
}

/// The speaker an owner name refers to: [linkedId] while [ownerText] still
/// is that speaker's name; otherwise the single user-named speaker whose
/// name matches [ownerText] exactly (after normalisation); otherwise null.
String? resolveTaskOwner(
  String? ownerText,
  String? linkedId,
  Map<String, Speaker> speakersById,
) {
  if (ownerText == null) return null;
  final key = normalizeForSearch(ownerText);
  if (key.isEmpty) return null;
  if (linkedId != null) {
    final s = speakersById[linkedId];
    if (s != null && normalizeForSearch(s.name) == key) return linkedId;
  }
  final matches = [
    for (final s in speakersById.values)
      if (s.isNamedByUser && normalizeForSearch(s.name) == key) s.id,
  ];
  return matches.length == 1 ? matches.single : null;
}

/// Why a draft cannot be saved.
enum TaskDraftError {
  /// Blank task.
  taskEmpty,

  /// Task longer than [kMaxTaskLength].
  taskTooLong,

  /// Owner longer than [kMaxTaskOwnerLength].
  ownerTooLong,

  /// Due text longer than [kMaxTaskDueLength].
  dueTooLong,
}

/// Validates a normalised [draft]; null when it can be saved.
TaskDraftError? validateTaskDraft(TaskDraft draft) {
  if (draft.task.isEmpty) return TaskDraftError.taskEmpty;
  if (draft.task.length > kMaxTaskLength) return TaskDraftError.taskTooLong;
  if ((draft.ownerText?.length ?? 0) > kMaxTaskOwnerLength) {
    return TaskDraftError.ownerTooLong;
  }
  if ((draft.dueText?.length ?? 0) > kMaxTaskDueLength) {
    return TaskDraftError.dueTooLong;
  }
  return null;
}

/// [task] with the editable fields of a normalised [draft] (status, text,
/// owner, due); identity, source and evidence are kept.
TrackedTask applyTaskDraft(TrackedTask task, TaskDraft draft) => task.copyWith(
  task: draft.task,
  ownerText: draft.ownerText,
  clearOwnerText: draft.ownerText == null,
  ownerSpeakerId: draft.ownerSpeakerId,
  clearOwnerSpeaker: draft.ownerSpeakerId == null,
  dueText: draft.dueText,
  clearDue: draft.dueText == null,
  status: draft.status,
);

/// True when saving [draft] would change [task].
bool taskDraftChanges(TrackedTask task, TaskDraft draft) =>
    task.task != draft.task ||
    task.ownerSpeakerId != draft.ownerSpeakerId ||
    (task.ownerText ?? '') != (draft.ownerText ?? '') ||
    (task.dueText ?? '') != (draft.dueText ?? '') ||
    task.status != draft.status;

// ---------------------------------------------------------------------------
// Pending task updates
// ---------------------------------------------------------------------------

/// What confirming a pending update means.
enum PendingUpdateKind {
  /// A status change to apply on confirmation.
  apply,

  /// A progress note (`new_status == open` while the task is open):
  /// confirmation only acknowledges it; the status is left as is.
  acknowledge,

  /// The task already has the proposed status (e.g. the user changed it
  /// meanwhile): nothing to apply, only to acknowledge.
  alreadyApplied,

  /// The task no longer exists: the update can only be dismissed.
  taskGone,
}

/// Classifies [update] against the current state of its [task] (null when
/// the task was deleted).
PendingUpdateKind classifyPendingUpdate(
  PendingTaskUpdate update,
  TrackedTask? task,
) {
  if (task == null) return PendingUpdateKind.taskGone;
  if (update.newStatus == task.status) {
    return update.newStatus == TaskStatus.open
        ? PendingUpdateKind.acknowledge
        : PendingUpdateKind.alreadyApplied;
  }
  // A progress note never re-opens a task the user closed.
  if (update.newStatus == TaskStatus.open) {
    return PendingUpdateKind.alreadyApplied;
  }
  return PendingUpdateKind.apply;
}

/// A pending update with what the UI needs to show it.
class PendingUpdateView {
  /// Creates a view.
  const PendingUpdateView({
    required this.update,
    required this.task,
    required this.kind,
    this.meetingTitle,
  });

  /// The update.
  final PendingTaskUpdate update;

  /// Its task (null when deleted).
  final TrackedTask? task;

  /// What confirming it does.
  final PendingUpdateKind kind;

  /// Title of the meeting whose minutes proposed it (null when unknown).
  final String? meetingTitle;

  /// True when confirming changes the task's status.
  bool get changesStatus => kind == PendingUpdateKind.apply;
}

/// Views of [updates] (oldest first, ties by id).
List<PendingUpdateView> pendingUpdateViews(
  Iterable<PendingTaskUpdate> updates, {
  required Map<int, TrackedTask> tasksById,
  required Map<String, Meeting> meetingsById,
}) {
  final list = [
    for (final u in updates)
      PendingUpdateView(
        update: u,
        task: tasksById[u.taskId],
        kind: classifyPendingUpdate(u, tasksById[u.taskId]),
        meetingTitle: meetingsById[u.meetingId]?.title,
      ),
  ];
  list.sort((a, b) {
    final c = a.update.createdAt.compareTo(b.update.createdAt);
    return c != 0 ? c : a.update.id.compareTo(b.update.id);
  });
  return list;
}

// ---------------------------------------------------------------------------
// Expected attendees ↔ task owners (recording-start banner)
// ---------------------------------------------------------------------------

/// Titles and honorifics ignored when matching names (normalised with
/// [normalizeForSearch], so «أ.» / «ا» and «ة» / «ه» are unified).
const Set<String> _honorifics = {
  'د',
  'دكتور',
  'الدكتور',
  'دكتوره',
  'الدكتوره',
  'م',
  'مهندس',
  'المهندس',
  'مهندسه',
  'المهندسه',
  'ا',
  'استاذ',
  'الاستاذ',
  'استاذه',
  'الاستاذه',
  'سيد',
  'السيد',
  'سيده',
  'السيده',
  'شيخ',
  'الشيخ',
  'معالي',
  'سعاده',
  'dr',
  'mr',
  'mrs',
  'ms',
  'miss',
  'eng',
  'prof',
  'sir',
};

final RegExp _namePunctuation = RegExp(r'''[.,،;؛:!؟?()\[\]{}"'«»\-_/\\]''');

/// The comparable tokens of a person's name: normalised, punctuation and
/// honorifics removed, «عبد X» joined into one token.
List<String> personNameTokens(String name) {
  final raw = normalizeForSearch(
    name.replaceAll(_namePunctuation, ' '),
  ).split(' ').where((t) => t.isNotEmpty).toList();
  final out = <String>[];
  for (var i = 0; i < raw.length; i++) {
    final t = raw[i];
    if (_honorifics.contains(t)) continue;
    if (t == 'عبد' && i + 1 < raw.length) {
      out.add('عبد${raw[++i]}');
      continue;
    }
    out.add(t);
  }
  return out;
}

/// True when two person names plausibly refer to the same person: after
/// [personNameTokens], one name's tokens are all part of the other's
/// («سارة» ≈ «م. سارة أحمد»).
bool personNamesMatch(String a, String b) {
  final ta = personNameTokens(a).toSet();
  final tb = personNameTokens(b).toSet();
  if (ta.isEmpty || tb.isEmpty) return false;
  return ta.length <= tb.length ? tb.containsAll(ta) : ta.containsAll(tb);
}

/// The open tasks of one expected attendee.
class AttendeeOpenTasks {
  /// Creates an entry.
  const AttendeeOpenTasks({required this.attendee, required this.tasks});

  /// The attendee's name as entered in the meeting context.
  final String attendee;

  /// Their open tasks, newest first.
  final List<TrackedTask> tasks;
}

/// Groups the open tasks among [tasks] by the expected [attendees] who own
/// them (matched with [personNamesMatch] against the owner's label). Each
/// task is listed once, under the first attendee whose name matches it
/// exactly, else the first that matches loosely. Tasks of [excludeMeetingId]
/// (the meeting being recorded) are skipped. Attendees without tasks are
/// omitted; the attendee order is kept.
List<AttendeeOpenTasks> openTasksForAttendees(
  List<String> attendees,
  Iterable<TrackedTask> tasks,
  Map<String, Speaker> speakersById, {
  String? excludeMeetingId,
}) {
  final names = <String>[];
  final seen = <String>{};
  for (final a in attendees) {
    final c = collapseTaskSpaces(a);
    if (c.isEmpty || personNameTokens(c).isEmpty) continue;
    if (seen.add(personNameTokens(c).join(' '))) names.add(c);
  }
  if (names.isEmpty) return const [];
  final byAttendee = {for (final n in names) n: <TrackedTask>[]};
  for (final t in tasks) {
    if (t.status != TaskStatus.open) continue;
    if (excludeMeetingId != null && t.sourceMeetingId == excludeMeetingId) {
      continue;
    }
    final owner = taskOwnerLabel(t, speakersById);
    if (owner == null) continue;
    final ownerKey = personNameTokens(owner).join(' ');
    String? target;
    for (final n in names) {
      if (personNameTokens(n).join(' ') == ownerKey) {
        target = n;
        break;
      }
    }
    target ??= names.where((n) => personNamesMatch(n, owner)).firstOrNull;
    if (target != null) byAttendee[target]!.add(t);
  }
  return [
    for (final n in names)
      if (byAttendee[n]!.isNotEmpty)
        AttendeeOpenTasks(
          attendee: n,
          tasks: byAttendee[n]!..sort(compareTasks),
        ),
  ];
}
