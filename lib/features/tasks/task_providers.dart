// Riverpod state of action-item tracking (F9): the tasks screen filter, the
// derived views (filtered list, counts, owner / meeting options, pending
// updates), the open-tasks banner of a meeting being recorded, and
// [TaskActions], the single place that writes tasks and resolves pending
// updates.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../data/repositories_v11.dart';
import 'task_logic.dart';

// ---------------------------------------------------------------------------
// Lookups
// ---------------------------------------------------------------------------

/// Every meeting keyed by id (empty while loading).
final taskMeetingsByIdProvider = Provider<Map<String, Meeting>>((ref) {
  final meetings = ref.watch(meetingsProvider).value ?? const <Meeting>[];
  return {for (final m in meetings) m.id: m};
});

/// Every speaker keyed by id (empty while loading).
final taskSpeakersByIdProvider = Provider<Map<String, Speaker>>(
  (ref) => ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{},
);

// ---------------------------------------------------------------------------
// Tasks screen
// ---------------------------------------------------------------------------

/// The filter of the tasks screen (kept while the app runs).
class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => const TaskFilter();

  /// Replaces the filter.
  void set(TaskFilter filter) => state = filter;

  /// Back to the default (open tasks, no other filter).
  void reset() => state = const TaskFilter();
}

/// Current tasks-screen filter.
final taskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilter>(
  TaskFilterNotifier.new,
);

/// Everything the tasks screen shows for the current filter.
class TasksView {
  /// Creates a view.
  const TasksView({
    required this.all,
    required this.shown,
    required this.statusCounts,
    required this.owners,
    required this.meetings,
    required this.speakersById,
    required this.meetingsById,
  });

  /// Builds the view of [tasks] for [filter].
  factory TasksView.build(
    List<TrackedTask> tasks,
    TaskFilter filter, {
    required Map<String, Speaker> speakersById,
    required Map<String, Meeting> meetingsById,
  }) => TasksView(
    all: tasks,
    shown: filterTasks(
      tasks,
      filter,
      speakersById: speakersById,
      meetingsById: meetingsById,
    ),
    statusCounts: taskStatusCounts(
      tasks,
      filter,
      speakersById: speakersById,
      meetingsById: meetingsById,
    ),
    owners: taskOwnerOptions(tasks, speakersById),
    meetings: taskMeetingOptions(tasks, meetingsById),
    speakersById: speakersById,
    meetingsById: meetingsById,
  );

  /// Every task.
  final List<TrackedTask> all;

  /// Tasks matching the filter, in display order.
  final List<TrackedTask> shown;

  /// Per-status counts ignoring the status filter.
  final Map<TaskStatus, int> statusCounts;

  /// Owner filter options.
  final List<TaskOwnerOption> owners;

  /// Meeting filter options.
  final List<TaskMeetingOption> meetings;

  /// Speakers by id.
  final Map<String, Speaker> speakersById;

  /// Meetings by id.
  final Map<String, Meeting> meetingsById;

  /// Sum of [statusCounts].
  int get totalMatching => statusCounts.values.fold(0, (a, b) => a + b);
}

/// The tasks screen view for the current [taskFilterProvider].
final tasksViewProvider = Provider<AsyncValue<TasksView>>((ref) {
  final filter = ref.watch(taskFilterProvider);
  final speakers = ref.watch(taskSpeakersByIdProvider);
  final meetings = ref.watch(taskMeetingsByIdProvider);
  return ref
      .watch(tasksProvider)
      .whenData(
        (tasks) => TasksView.build(
          tasks,
          filter,
          speakersById: speakers,
          meetingsById: meetings,
        ),
      );
});

/// Tasks keyed by id (empty while loading).
final tasksByIdProvider = Provider<Map<int, TrackedTask>>((ref) {
  final tasks = ref.watch(tasksProvider).value ?? const <TrackedTask>[];
  return {for (final t in tasks) t.id: t};
});

/// Every pending update with its task and meeting, oldest first.
final pendingUpdateViewsProvider = Provider<List<PendingUpdateView>>((ref) {
  final updates =
      ref.watch(pendingTaskUpdatesProvider).value ??
      const <PendingTaskUpdate>[];
  // Wait for the tasks before classifying (else every update looks
  // «task gone» for one frame).
  if (!ref.watch(tasksProvider).hasValue) return const [];
  return pendingUpdateViews(
    updates,
    tasksById: ref.watch(tasksByIdProvider),
    meetingsById: ref.watch(taskMeetingsByIdProvider),
  );
});

/// Pending updates proposed by the minutes of one meeting.
final meetingPendingUpdateViewsProvider = Provider.autoDispose
    .family<List<PendingUpdateView>, String>((ref, meetingId) {
      final updates =
          ref.watch(meetingPendingTaskUpdatesProvider(meetingId)).value ??
          const <PendingTaskUpdate>[];
      if (!ref.watch(tasksProvider).hasValue) return const [];
      return pendingUpdateViews(
        updates,
        tasksById: ref.watch(tasksByIdProvider),
        meetingsById: ref.watch(taskMeetingsByIdProvider),
      );
    });

// ---------------------------------------------------------------------------
// Open-tasks banner (recording start)
// ---------------------------------------------------------------------------

/// Open tasks (of other meetings) owned by the expected attendees of
/// [meetingId], grouped by attendee. Empty when the meeting has no expected
/// attendees or none of them owns an open task.
final meetingAttendeeOpenTasksProvider = Provider.autoDispose
    .family<List<AttendeeOpenTasks>, String>((ref, meetingId) {
      final meeting = ref.watch(meetingProvider(meetingId)).value;
      if (meeting == null) return const [];
      final attendees = meeting.context.expectedAttendees;
      if (attendees.isEmpty) return const [];
      final open = ref.watch(openTasksProvider).value;
      if (open == null || open.isEmpty) return const [];
      return openTasksForAttendees(
        attendees,
        open,
        ref.watch(taskSpeakersByIdProvider),
        excludeMeetingId: meetingId,
      );
    });

/// Meetings whose open-tasks banner the user hid (for this app run).
class HiddenTaskBannersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Hides the banner of [meetingId].
  void hide(String meetingId) => state = {...state, meetingId};

  /// True when the banner of [meetingId] was hidden.
  bool isHidden(String meetingId) => state.contains(meetingId);
}

/// Hidden open-tasks banners.
final hiddenTaskBannersProvider =
    NotifierProvider<HiddenTaskBannersNotifier, Set<String>>(
      HiddenTaskBannersNotifier.new,
    );

// ---------------------------------------------------------------------------
// Writes
// ---------------------------------------------------------------------------

/// Result of resolving one pending update.
enum PendingResolution {
  /// The proposed status was applied to the task.
  applied,

  /// The update was removed without changing the task.
  dismissed,

  /// The update no longer existed (handled elsewhere).
  gone,
}

/// Every write of the tasks feature.
class TaskActions {
  /// Creates the actions over the repositories.
  TaskActions(this._tasks, this._pending);

  final TaskRepository _tasks;
  final PendingTaskUpdateRepository _pending;

  /// Sets [task]'s status. Returns false when the task no longer exists.
  Future<bool> setStatus(TrackedTask task, TaskStatus status) {
    if (task.status == status) return Future.value(true);
    return _tasks.setStatus(task.id, status);
  }

  /// Saves the normalised [draft] over [task]; no write (and no
  /// `updatedAt` stamp) when nothing changed. Returns false when the task
  /// no longer exists. Throws [ArgumentError] for an invalid draft.
  /// [speakersById] are the speakers the dialog was opened with (see
  /// [taskEditChanges]).
  Future<bool> save(
    TrackedTask task,
    TaskDraft draft, {
    Map<String, Speaker> speakersById = const {},
  }) async {
    final error = validateTaskDraft(draft);
    if (error != null) throw ArgumentError.value(draft, 'draft', error.name);
    if (!taskEditChanges(task, draft, speakersById)) return true;
    return _tasks.update(applyTaskDraft(task, draft));
  }

  /// Creates a manual task from the normalised [draft]. Throws
  /// [ArgumentError] for an invalid draft.
  Future<TrackedTask> create(TaskDraft draft) {
    final error = validateTaskDraft(draft);
    if (error != null) throw ArgumentError.value(draft, 'draft', error.name);
    return _tasks.create(
      task: draft.task,
      ownerSpeakerId: draft.ownerSpeakerId,
      ownerText: draft.ownerText,
      dueText: draft.dueText,
      status: draft.status,
    );
  }

  /// Deletes [task] (its pending updates go with it). A task from a
  /// meeting's minutes is not re-created when those minutes are regenerated.
  Future<bool> delete(TrackedTask task) => _tasks.deleteByUser(task);

  /// Resolves [view] with the user's choice: [accept] applies a status
  /// change (only when [PendingUpdateView.changesStatus]); every other case
  /// — rejection, acknowledging a progress note, an update that is already
  /// applied or whose task is gone — just removes it.
  Future<PendingResolution> resolve(
    PendingUpdateView view, {
    required bool accept,
  }) async {
    if (accept && view.changesStatus) {
      final task = await _pending.confirm(view.update.id);
      return task == null ? PendingResolution.gone : PendingResolution.applied;
    }
    final removed = await _pending.dismiss(view.update.id);
    return removed ? PendingResolution.dismissed : PendingResolution.gone;
  }

  /// Applies every status-changing update of [views] (in order; when two
  /// updates target the same task, the newest wins) and removes the
  /// others targeting the same tasks. Returns the number applied.
  Future<int> applyAll(List<PendingUpdateView> views) async {
    final latest = <int, PendingUpdateView>{};
    for (final v in views) {
      if (!v.changesStatus) continue;
      final prev = latest[v.update.taskId];
      if (prev == null || !v.update.createdAt.isBefore(prev.update.createdAt)) {
        latest[v.update.taskId] = v;
      }
    }
    var applied = 0;
    for (final v in views) {
      if (!v.changesStatus) continue;
      if (identical(latest[v.update.taskId], v)) {
        if (await _pending.confirm(v.update.id) != null) applied++;
      } else {
        await _pending.dismiss(v.update.id);
      }
    }
    return applied;
  }
}

/// [TaskActions] over the repositories.
final taskActionsProvider = Provider<TaskActions>(
  (ref) => TaskActions(
    ref.watch(taskRepositoryProvider),
    ref.watch(pendingTaskUpdateRepositoryProvider),
  ),
);

/// The applicable (status-changing) views among [views].
List<PendingUpdateView> applicableUpdates(List<PendingUpdateView> views) => [
  for (final v in views)
    if (v.changesStatus) v,
];
