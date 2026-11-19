// Persists the v1.1 parts of generated minutes into their own tables, right
// after the minutes are saved (see `PostProcessor`):
//
// * action items → `tasks` (F9; re-generating the minutes keeps tasks the
//   user touched and replaces untouched ones);
// * `task_updates` → `task_updates_pending` (F9; applied only after the user
//   confirms);
// * `speaker_notes` of opted-in speakers → `speaker_meeting_notes` (F16);
// * `codes` → `code_findings` (F17).
//
// The mapping is pure (unit-tested); [MinutesArtifactsWriter] applies it in
// one transaction.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import 'database.dart';
import 'repositories.dart';
import 'repositories_v11.dart';

/// Name key used to match a speaker name written by the minutes engine to a
/// speaker: whitespace collapsed and trimmed (the engine is told to copy
/// names verbatim).
String speakerNameKey(String name) => name.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Resolves speaker names (as written in minutes) to speaker ids. Names that
/// several speakers share are ambiguous and resolve to null.
class SpeakerNameResolver {
  /// Builds the resolver over [speakersById].
  SpeakerNameResolver(Map<String, Speaker> speakersById) {
    final counts = <String, int>{};
    for (final s in speakersById.values) {
      final k = speakerNameKey(s.name);
      if (k.isEmpty) continue;
      counts[k] = (counts[k] ?? 0) + 1;
      _byName[k] = s;
    }
    counts.forEach((k, n) {
      if (n > 1) _byName.remove(k);
    });
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
  ) =>
      CodeFinding(
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

/// Plans the task sync of a meeting: an action item whose text matches an
/// existing task of the meeting (whitespace / case-insensitive) is kept as
/// is; new items are created; untouched (`updatedAt == createdAt`), still
/// open tasks that disappeared from the minutes are deleted. Tasks the user
/// edited or closed are never deleted.
TaskSyncPlan planTaskSync(
  List<TrackedTask> existing,
  List<ActionItem> actionItems,
) {
  final existingKeys = {for (final t in existing) normalizedKey(t.task)};
  final itemKeys = <String>{};
  final create = <ActionItem>[];
  for (final a in actionItems) {
    final k = normalizedKey(a.task);
    if (k.isEmpty || !itemKeys.add(k)) continue;
    if (!existingKeys.contains(k)) create.add(a);
  }
  final deleteIds = [
    for (final t in existing)
      if (!itemKeys.contains(normalizedKey(t.task)) &&
          t.status == TaskStatus.open &&
          t.updatedAt.isAtSameMomentAs(t.createdAt))
        t.id,
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
  /// `taskUpdates` are ignored).
  Future<MinutesArtifactsReport> persist({
    required String meetingId,
    required Minutes minutes,
    required Map<String, Speaker> speakersById,
    Set<int> openTaskIds = const {},
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final names = SpeakerNameResolver(speakersById);
    return _db.transaction(() async {
      // Tasks (F9).
      final existing = await _tasks.getAll(sourceMeetingId: meetingId);
      final plan = planTaskSync(existing, minutes.actionItems);
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

      // Codes (F17).
      final findings = codeFindingsFromMinutes(
        meetingId,
        minutes.codes,
        names,
        now: at,
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
    (ref) => MinutesArtifactsWriter(ref.watch(databaseProvider)));
