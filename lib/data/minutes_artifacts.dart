// Persists the v1.1 parts of generated minutes into their own tables, right
// after the minutes are saved (see `PostProcessor`):
//
// * action items → `tasks` (F9; re-generating the minutes keeps tasks the
//   user touched, replaces untouched ones and never re-creates a task the
//   user deleted);
// * `task_updates` → `task_updates_pending` (F9; applied only after the user
//   confirms);
// * `speaker_notes` of opted-in speakers → `speaker_meeting_notes` (F16);
// * `codes` → `code_findings` (F17; reversed-speech results and app
//   findings of an earlier run are carried over).
//
// The mapping is pure (unit-tested); [MinutesArtifactsWriter] applies it in
// one transaction.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../features/codes/reversed_speech_logic.dart';
import 'database.dart';
import 'repositories.dart';
import 'repositories_v11.dart';

/// Name key used to match a speaker name written by the minutes engine to a
/// speaker: whitespace collapsed and trimmed (the engine is told to copy
/// names verbatim).
String speakerNameKey(String name) =>
    name.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Resolves speaker names (as written in minutes) to speaker ids. Names that
/// several speakers share are ambiguous and resolve to null.
class SpeakerNameResolver {
  /// Builds the resolver over the whole [speakersById] (every name is
  /// matched library-wide).
  SpeakerNameResolver(Map<String, Speaker> speakersById)
    : this.scoped(speakersById, const {});

  /// Names resolve first among [meetingSpeakerIds] (the speakers who appear
  /// in the meeting): two library speakers called «محمد» from different
  /// meetings do not make the name ambiguous in a meeting where only one of
  /// them speaks. A name no meeting speaker uses falls back to the whole
  /// [speakersById]. A name shared inside a scope resolves to null.
  SpeakerNameResolver.scoped(
    Map<String, Speaker> speakersById,
    Set<String> meetingSpeakerIds,
  ) {
    final global = _uniqueByName(speakersById.values);
    final local = _uniqueByName([
      for (final id in meetingSpeakerIds) ?speakersById[id],
    ]);
    _byName
      ..addAll(global.$1)
      ..removeWhere((k, _) => local.$2.contains(k))
      ..addAll(local.$1);
  }

  /// (unique name → speaker, every name key seen).
  static (Map<String, Speaker>, Set<String>) _uniqueByName(
    Iterable<Speaker> speakers,
  ) {
    final by = <String, Speaker>{};
    final seen = <String>{};
    final dup = <String>{};
    for (final s in speakers) {
      final k = speakerNameKey(s.name);
      if (k.isEmpty) continue;
      if (!seen.add(k)) dup.add(k);
      by[k] = s;
    }
    by.removeWhere((k, _) => dup.contains(k));
    return (by, seen);
  }

  final Map<String, Speaker> _byName = {};

  /// The speaker called [name], or null when unknown / ambiguous.
  Speaker? speaker(String? name) =>
      name == null ? null : _byName[speakerNameKey(name)];

  /// The id of the speaker called [name], or null.
  String? id(String? name) => speaker(name)?.id;
}

/// F17 findings of [codes] as rows to store (ids 0; speaker resolved by
/// name through [names]).
List<CodeFinding> codeFindingsFromMinutes(
  String meetingId,
  MinutesCodes codes,
  SpeakerNameResolver names, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  CodeFinding f(
    CodeFindingKind kind,
    String? speaker,
    List<int> evidence,
    Map<String, dynamic> payload,
  ) => CodeFinding(
    id: 0,
    meetingId: meetingId,
    kind: kind,
    speakerId: names.id(speaker),
    segmentIds: evidence,
    payload: payload,
    createdAt: at,
  );
  return [
    for (final c in codes.codedSpeech)
      f(CodeFindingKind.speechCoded, c.speaker, c.evidence, c.toJson()),
    for (final j in codes.jargon)
      f(
        CodeFindingKind.jargon,
        j.speakers.isEmpty ? null : j.speakers.first,
        j.evidence,
        j.toJson(),
      ),
    for (final s in codes.spokenCode)
      f(CodeFindingKind.spokenCode, s.speaker, s.evidence, s.toJson()),
    for (final i in codes.implied)
      f(CodeFindingKind.implied, i.speaker, i.evidence, i.toJson()),
    for (final r in codes.references)
      f(CodeFindingKind.reference, r.speaker, r.evidence, r.toJson()),
  ];
}

/// Notes of [notes] whose speaker resolves to a speaker with a profile
/// enabled (F16 opt-in), keyed by speaker id. Notes about anyone else are
/// dropped, never stored.
Map<String, MinutesSpeakerNote> optedInSpeakerNotes(
  List<MinutesSpeakerNote> notes,
  SpeakerNameResolver names,
) {
  final out = <String, MinutesSpeakerNote>{};
  for (final n in notes) {
    final s = names.speaker(n.speaker);
    if (s == null || !s.profileEnabled) continue;
    out.putIfAbsent(s.id, () => n);
  }
  return out;
}

/// Task updates worth proposing: about a task in [openTaskIds] (the open
/// tasks given to the engine), not created by this meeting, at most one per
/// task (the first).
List<MinutesTaskUpdate> validTaskUpdates(
  List<MinutesTaskUpdate> updates,
  Set<int> openTaskIds,
) {
  final seen = <int>{};
  return [
    for (final u in updates)
      if (openTaskIds.contains(u.taskId) && seen.add(u.taskId)) u,
  ];
}

/// What to do with the tasks of one meeting after its minutes were
/// (re)generated.
class TaskSyncPlan {
  /// Creates a plan.
  const TaskSyncPlan({required this.create, required this.deleteIds});

  /// Action items to create as new tasks.
  final List<ActionItem> create;

  /// Tasks to delete: created by an earlier version of these minutes,
  /// never touched by the user, and no longer in the minutes.
  final List<int> deleteIds;
}

/// Whether action item [a] is the same task as the stored [t]: similar
/// text ([similarTaskText], forgiving Arabic spelling and rewording), or
/// overlapping evidence with at least one shared word (the user may have
/// reworded the task, but it still cites the same moment).
bool sameTask(TrackedTask t, ActionItem a) {
  if (similarTaskText(t.task, a.task)) return true;
  if (t.evidenceSegmentIds.isEmpty || a.evidence.isEmpty) return false;
  if (t.evidenceSegmentIds.toSet().intersection(a.evidence.toSet()).isEmpty) {
    return false;
  }
  final x = taskMatchKey(t.task).split(' ').toSet();
  final y = taskMatchKey(a.task).split(' ').toSet();
  return x.intersection(y).any((w) => w.length > 2);
}

bool _untouchedOpen(TrackedTask t) =>
    t.status == TaskStatus.open && t.updatedAt.isAtSameMomentAs(t.createdAt);

/// Plans the task sync of a meeting. Each action item is matched to at most
/// one existing task of the meeting ([sameTask]; tasks the user touched —
/// edited, done, cancelled — are tried first) and then kept as is; an item
/// matching no task is created, unless it matches an item whose task the
/// user deleted ([dismissedKeys], `taskMatchKey` values), which never comes
/// back. Untouched (`updatedAt == createdAt`), still open tasks that no item
/// matches any more are deleted; tasks the user edited or closed never are.
TaskSyncPlan planTaskSync(
  List<TrackedTask> existing,
  List<ActionItem> actionItems, {
  Set<String> dismissedKeys = const {},
}) {
  final ordered = [
    ...existing.where((t) => !_untouchedOpen(t)),
    ...existing.where(_untouchedOpen),
  ];
  final matched = <int>{};
  final seen = <String>{};
  final create = <ActionItem>[];
  for (final a in actionItems) {
    final k = taskMatchKey(a.task);
    if (k.isEmpty || !seen.add(k)) continue;
    TrackedTask? hit;
    for (final t in ordered) {
      if (!matched.contains(t.id) && sameTask(t, a)) {
        hit = t;
        break;
      }
    }
    if (hit != null) {
      matched.add(hit.id);
    } else if (!dismissedKeys.contains(k) &&
        !dismissedKeys.any((d) => similarTaskText(d, a.task))) {
      create.add(a);
    }
  }
  final deleteIds = [
    for (final t in existing)
      if (!matched.contains(t.id) && _untouchedOpen(t)) t.id,
  ];
  return TaskSyncPlan(create: create, deleteIds: deleteIds);
}

/// Counts of what [MinutesArtifactsWriter.persist] stored.
class MinutesArtifactsReport {
  /// Creates a report.
  const MinutesArtifactsReport({
    this.tasksCreated = 0,
    this.tasksDeleted = 0,
    this.pendingTaskUpdates = 0,
    this.speakerNotes = 0,
    this.codeFindings = 0,
  });

  /// New tasks from action items.
  final int tasksCreated;

  /// Untouched tasks of an earlier minutes version removed.
  final int tasksDeleted;

  /// Task updates awaiting confirmation.
  final int pendingTaskUpdates;

  /// Speaker notes stored (opted-in speakers only).
  final int speakerNotes;

  /// Code findings stored.
  final int codeFindings;
}

/// Stores the v1.1 artefacts of a meeting's minutes (see the file comment).
class MinutesArtifactsWriter {
  /// Creates the writer over [_db].
  MinutesArtifactsWriter(this._db)
    : _tasks = TaskRepository(_db),
      _pending = PendingTaskUpdateRepository(_db),
      _notes = SpeakerMeetingNotesRepository(_db),
      _codes = CodeFindingRepository(_db);

  final AppDatabase _db;
  final TaskRepository _tasks;
  final PendingTaskUpdateRepository _pending;
  final SpeakerMeetingNotesRepository _notes;
  final CodeFindingRepository _codes;

  /// Persists [minutes] of [meetingId] (one transaction). [openTaskIds] are
  /// the ids of the open tasks given to the engine (other task ids in
  /// `taskUpdates` are ignored). [meetingSpeakerIds] (the speakers in the
  /// meeting's segments) scope name matching first
  /// ([SpeakerNameResolver.scoped]).
  Future<MinutesArtifactsReport> persist({
    required String meetingId,
    required Minutes minutes,
    required Map<String, Speaker> speakersById,
    Set<int> openTaskIds = const {},
    Set<String>? meetingSpeakerIds,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final names = SpeakerNameResolver.scoped(
      speakersById,
      meetingSpeakerIds ?? const {},
    );
    return _db.transaction(() async {
      // Tasks (F9).
      final existing = await _tasks.getAll(sourceMeetingId: meetingId);
      final plan = planTaskSync(
        existing,
        minutes.actionItems,
        dismissedKeys: await TaskDismissalRepository(
          _db,
        ).keys(meetingId, TaskDismissalKind.task),
      );
      for (final id in plan.deleteIds) {
        await _tasks.delete(id);
      }
      for (final a in plan.create) {
        await _tasks.create(
          task: a.task,
          ownerSpeakerId: names.id(a.owner),
          ownerText: a.owner,
          dueText: a.dueDate,
          sourceMeetingId: meetingId,
          evidenceSegmentIds: a.evidence,
          createdAt: at,
        );
      }
      // Only tasks that still exist, are still open and come from another
      // meeting can receive updates.
      final ownIds = {for (final t in existing) t.id};
      final stillOpen = {for (final t in await _tasks.getOpen()) t.id};
      final updates = validTaskUpdates(
        minutes.taskUpdates,
        openTaskIds.intersection(stillOpen).difference(ownIds),
      );
      await _pending.replaceForMeeting(meetingId, updates, now: at);

      // Speaker notes (F16, opted-in speakers only).
      final notes = optedInSpeakerNotes(minutes.speakerNotes, names);
      await _notes.replaceForMeeting(meetingId, notes);

      // Codes (F17). Reversed-speech results (user-run, slow) and app
      // findings survive the replacement.
      final previous = await _codes.getForMeeting(meetingId);
      final findings = carryOverReversedFindings(
        previous: previous,
        engine: codeFindingsFromMinutes(
          meetingId,
          minutes.codes,
          names,
          now: at,
        ),
      );
      await _codes.replaceForMeeting(meetingId, findings, now: at);

      return MinutesArtifactsReport(
        tasksCreated: plan.create.length,
        tasksDeleted: plan.deleteIds.length,
        pendingTaskUpdates: updates.length,
        speakerNotes: notes.length,
        codeFindings: findings.length,
      );
    });
  }
}

/// [MinutesArtifactsWriter] over [databaseProvider].
final minutesArtifactsWriterProvider = Provider<MinutesArtifactsWriter>(
  (ref) => MinutesArtifactsWriter(ref.watch(databaseProvider)),
);
