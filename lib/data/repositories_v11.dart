// Repositories of the Insato v1.1 tables (schema v2): glossary, tasks and
// their pending updates, speaker profiles and per-meeting speaker notes, and
// F17 code findings. Like `repositories.dart`, this is the only place where
// these drift rows are converted to and from the domain models of
// `core/models_v11.dart`.
//
// THIS FILE IS A SHARED CONTRACT (see docs/V11-CONTRACTS.md): feature modules
// read and write the v1.1 tables only through these classes and providers.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/text_normalize.dart';
import 'database.dart';
import 'repositories.dart';

/// Decodes a stored JSON object; anything malformed → empty map.
Map<String, dynamic> decodeJsonObject(String? json) {
  if (json == null || json.isEmpty) return const {};
  try {
    final v = jsonDecode(json);
    return v is Map ? v.cast<String, dynamic>() : const {};
  } on FormatException {
    return const {};
  }
}

/// Decodes a stored JSON list of [EvidenceRef]s; malformed entries skipped.
List<EvidenceRef> decodeEvidenceRefs(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final v = jsonDecode(json);
    if (v is! List) return const [];
    return [for (final e in v) ?EvidenceRef.tryParse(e)];
  } on FormatException {
    return const [];
  }
}

/// Comparison key of a glossary term or task text: trimmed, inner
/// whitespace collapsed, lower-cased.
String normalizedKey(String s) =>
    s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Matching key of a task text: punctuation removed and the forgiving
/// Arabic normalisation of search (alef / hamza / ta marbuta forms,
/// diacritics, digits, case).
String taskMatchKey(String s) => normalizeForSearch(
  s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' '),
);

Set<String> _taskTokens(String s) => {
  for (final w in taskMatchKey(s).split(' '))
    if (w.isNotEmpty) w.startsWith('ال') && w.length > 3 ? w.substring(2) : w,
};

/// Whether two task texts (as written by an engine or edited by the user)
/// describe the same task: the same [taskMatchKey], a word overlap (Jaccard)
/// of at least 0.6, or one text containing at least 80 % of the other's
/// words when both have two words or more («إرسال التقرير» ≈ «ارسال التقرير
/// للإدارة»).
bool similarTaskText(String a, String b) {
  final ka = taskMatchKey(a);
  final kb = taskMatchKey(b);
  if (ka.isEmpty || kb.isEmpty) return false;
  if (ka == kb) return true;
  final x = _taskTokens(a);
  final y = _taskTokens(b);
  if (x.isEmpty || y.isEmpty) return false;
  final inter = x.intersection(y).length;
  if (inter / x.union(y).length >= 0.6) return true;
  final small = x.length < y.length ? x.length : y.length;
  return small >= 2 && inter / small >= 0.8;
}

/// Kinds of [TaskDismissals] rows.
abstract final class TaskDismissalKind {
  /// An action item whose task the user deleted (key: [taskMatchKey]).
  static const String task = 'task';

  /// A task update the user confirmed or dismissed (key:
  /// [taskUpdateDecisionKey]).
  static const String update = 'update';
}

/// Dismissal key of a task update.
String taskUpdateDecisionKey(int taskId, TaskStatus status) =>
    '$taskId|${status.wire}';

/// User decisions about a meeting's minutes kept across regenerations.
class TaskDismissalRepository {
  /// Creates the repository over [_db].
  TaskDismissalRepository(this._db);

  final AppDatabase _db;

  /// Records a decision (idempotent).
  Future<void> add(
    String meetingId,
    String kind,
    String key, {
    DateTime? now,
  }) async {
    if (key.isEmpty) return;
    await _db
        .into(_db.taskDismissals)
        .insertOnConflictUpdate(
          TaskDismissalsCompanion.insert(
            meetingId: meetingId,
            kind: kind,
            itemKey: key,
            createdAt: now ?? DateTime.now(),
          ),
        );
  }

  /// Keys of [kind] recorded for [meetingId].
  Future<Set<String>> keys(String meetingId, String kind) async => {
    for (final r
        in await (_db.select(_db.taskDismissals)..where(
              (d) => d.meetingId.equals(meetingId) & d.kind.equals(kind),
            ))
            .get())
      r.itemKey,
  };
}

// ---------------------------------------------------------------------------
// Glossary (F2 / F3)
// ---------------------------------------------------------------------------

/// Custom vocabulary: global terms and meeting-only terms.
class GlossaryRepository {
  /// Creates the repository over [_db].
  GlossaryRepository(this._db);

  final AppDatabase _db;

  /// Converts a row to the domain model.
  static GlossaryTerm fromRow(GlossaryTermRow r) => GlossaryTerm(
    id: r.id,
    term: r.term,
    arSpelling: jsonNonEmpty(r.arSpelling),
    category: GlossaryCategory.parse(r.category),
    meetingId: r.meetingId,
    createdAt: r.createdAt,
  );

  SimpleSelectStatement<$GlossaryTermsTable, GlossaryTermRow> _scope(
    String? meetingId,
  ) => _db.select(_db.glossaryTerms)
    ..where(
      (g) => meetingId == null
          ? g.meetingId.isNull()
          : g.meetingId.equals(meetingId),
    )
    ..orderBy([(g) => OrderingTerm.asc(g.term), (g) => OrderingTerm.asc(g.id)]);

  /// Adds a term to the global glossary ([meetingId] null) or to one
  /// meeting. The term is trimmed; when the same term (case- and
  /// whitespace-insensitive) already exists in that scope, it is updated
  /// with the new spelling / category instead of duplicated. Throws
  /// [ArgumentError] for a blank term.
  Future<GlossaryTerm> add({
    required String term,
    String? arSpelling,
    GlossaryCategory category = GlossaryCategory.other,
    String? meetingId,
    DateTime? createdAt,
  }) {
    final t = term.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) throw ArgumentError.value(term, 'term', 'must not be blank');
    return _db.transaction(() async {
      final key = normalizedKey(t);
      final existing = (await _scope(
        meetingId,
      ).get()).where((r) => normalizedKey(r.term) == key).firstOrNull;
      final spelling = jsonNonEmpty(arSpelling);
      if (existing != null) {
        await (_db.update(
          _db.glossaryTerms,
        )..where((g) => g.id.equals(existing.id))).write(
          GlossaryTermsCompanion(
            term: Value(t),
            arSpelling: Value(spelling ?? existing.arSpelling),
            category: Value(category.wire),
          ),
        );
        return fromRow(
          (await (_db.select(
            _db.glossaryTerms,
          )..where((g) => g.id.equals(existing.id))).getSingle()),
        );
      }
      final now = createdAt ?? DateTime.now();
      final id = await _db
          .into(_db.glossaryTerms)
          .insert(
            GlossaryTermsCompanion.insert(
              term: t,
              arSpelling: Value(spelling),
              category: Value(category.wire),
              meetingId: Value(meetingId),
              createdAt: now,
            ),
          );
      return GlossaryTerm(
        id: id,
        term: t,
        arSpelling: spelling,
        category: category,
        meetingId: meetingId,
        createdAt: now,
      );
    });
  }

  /// Replaces the editable fields of [term] (matched by id). Returns true if
  /// it existed. Throws [ArgumentError] for a blank term.
  Future<bool> update(GlossaryTerm term) async {
    final t = term.term.trim();
    if (t.isEmpty) {
      throw ArgumentError.value(term.term, 'term', 'must not be blank');
    }
    final n =
        await (_db.update(
          _db.glossaryTerms,
        )..where((g) => g.id.equals(term.id))).write(
          GlossaryTermsCompanion(
            term: Value(t),
            arSpelling: Value(jsonNonEmpty(term.arSpelling)),
            category: Value(term.category.wire),
          ),
        );
    return n > 0;
  }

  /// Deletes a term. Returns true if it existed.
  Future<bool> delete(int id) async =>
      await (_db.delete(
        _db.glossaryTerms,
      )..where((g) => g.id.equals(id))).go() >
      0;

  /// Global terms, alphabetical.
  Future<List<GlossaryTerm>> getGlobal() async =>
      (await _scope(null).get()).map(fromRow).toList(growable: false);

  /// Like [getGlobal], re-emitted on change.
  Stream<List<GlossaryTerm>> watchGlobal() =>
      _scope(null)
          .watch()
          .map((rows) => rows.map(fromRow).toList(growable: false));

  /// Meeting-only terms of [meetingId], alphabetical.
  Future<List<GlossaryTerm>> getForMeeting(String meetingId) async =>
      (await _scope(meetingId).get()).map(fromRow).toList(growable: false);

  /// Like [getForMeeting], re-emitted on change.
  Stream<List<GlossaryTerm>> watchForMeeting(String meetingId) =>
      _scope(meetingId)
          .watch()
          .map((rows) => rows.map(fromRow).toList(growable: false));

  /// The glossary that applies to [meetingId] (or only the global one when
  /// null): global terms, this meeting's terms (which override a global term
  /// with the same spelling) and — F2 — the names of [speakers] the user
  /// named, as `person` terms with id 0 (unless already present).
  Future<List<GlossaryTerm>> getEffective(
    String? meetingId, {
    Iterable<Speaker> speakers = const [],
  }) async {
    final global = await getGlobal();
    final local = meetingId == null
        ? const <GlossaryTerm>[]
        : await getForMeeting(meetingId);
    return mergeGlossary(global, local, speakers: speakers);
  }
}

/// Pure merge used by [GlossaryRepository.getEffective]: [local] terms
/// override [global] ones with the same key; named [speakers] are appended
/// as `person` terms (id 0) when no term has their name. Order: global /
/// local terms alphabetically, then speaker names.
List<GlossaryTerm> mergeGlossary(
  List<GlossaryTerm> global,
  List<GlossaryTerm> local, {
  Iterable<Speaker> speakers = const [],
}) {
  final byKey = <String, GlossaryTerm>{};
  for (final t in [...global, ...local]) {
    byKey[normalizedKey(t.term)] = t;
  }
  final out = byKey.values.toList()
    ..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  for (final s in speakers) {
    if (!s.isNamedByUser) continue;
    final name = s.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) continue;
    final key = normalizedKey(name);
    if (byKey.containsKey(key)) continue;
    final term = GlossaryTerm(
      id: 0,
      term: name,
      category: GlossaryCategory.person,
      createdAt: epoch,
    );
    byKey[key] = term;
    out.add(term);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Tasks (F9)
// ---------------------------------------------------------------------------

/// Action items tracked across meetings.
class TaskRepository {
  /// Creates the repository over [_db].
  TaskRepository(this._db);

  final AppDatabase _db;

  /// Converts a row to the domain model.
  static TrackedTask fromRow(TaskRow r) => TrackedTask(
    id: r.id,
    task: r.task,
    ownerSpeakerId: r.ownerSpeakerId,
    ownerText: jsonNonEmpty(r.ownerText),
    dueText: jsonNonEmpty(r.dueText),
    status: TaskStatus.parse(r.status),
    sourceMeetingId: r.sourceMeetingId,
    evidenceSegmentIds: decodeJsonIntList(r.evidenceSegmentIds),
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  SimpleSelectStatement<$TasksTable, TaskRow> _query({
    TaskStatus? status,
    String? sourceMeetingId,
  }) => _db.select(_db.tasks)
    ..where((t) {
      Expression<bool> e = const Constant(true);
      if (status != null) e = e & t.status.equals(status.wire);
      if (sourceMeetingId != null) {
        e = e & t.sourceMeetingId.equals(sourceMeetingId);
      }
      return e;
    })
    ..orderBy([
      (t) => OrderingTerm.desc(t.createdAt),
      (t) => OrderingTerm.desc(t.id),
    ]);

  /// Creates a task. Throws [ArgumentError] for a blank [task].
  Future<TrackedTask> create({
    required String task,
    String? ownerSpeakerId,
    String? ownerText,
    String? dueText,
    TaskStatus status = TaskStatus.open,
    String? sourceMeetingId,
    List<int> evidenceSegmentIds = const [],
    DateTime? createdAt,
  }) async {
    final t = task.trim();
    if (t.isEmpty) throw ArgumentError.value(task, 'task', 'must not be blank');
    final now = createdAt ?? DateTime.now();
    final evidence = parseEvidenceIds(evidenceSegmentIds);
    final id = await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            task: t,
            ownerSpeakerId: Value(ownerSpeakerId),
            ownerText: Value(jsonNonEmpty(ownerText)),
            dueText: Value(jsonNonEmpty(dueText)),
            status: Value(status.wire),
            sourceMeetingId: Value(sourceMeetingId),
            evidenceSegmentIds: Value(jsonEncode(evidence)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return TrackedTask(
      id: id,
      task: t,
      ownerSpeakerId: ownerSpeakerId,
      ownerText: jsonNonEmpty(ownerText),
      dueText: jsonNonEmpty(dueText),
      status: status,
      sourceMeetingId: sourceMeetingId,
      evidenceSegmentIds: evidence,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// One task, or null.
  Future<TrackedTask?> get(int id) async {
    final r = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : fromRow(r);
  }

  /// Tasks, newest first, optionally filtered by [status] and/or source
  /// meeting.
  Future<List<TrackedTask>> getAll({
    TaskStatus? status,
    String? sourceMeetingId,
  }) async => (await _query(
    status: status,
    sourceMeetingId: sourceMeetingId,
  ).get()).map(fromRow).toList(growable: false);

  /// Like [getAll], re-emitted on change.
  Stream<List<TrackedTask>> watchAll({
    TaskStatus? status,
    String? sourceMeetingId,
  }) => _query(
    status: status,
    sourceMeetingId: sourceMeetingId,
  ).watch().map((rows) => rows.map(fromRow).toList(growable: false));

  /// Open tasks, newest first.
  Future<List<TrackedTask>> getOpen() => getAll(status: TaskStatus.open);

  /// Saves the editable fields of [task] (text, owner, due, status) and
  /// stamps `updatedAt` (default now). Returns true if it existed.
  Future<bool> update(TrackedTask task, {DateTime? now}) async {
    final t = task.task.trim();
    if (t.isEmpty) {
      throw ArgumentError.value(task.task, 'task', 'must not be blank');
    }
    final n = await (_db.update(_db.tasks)..where((r) => r.id.equals(task.id)))
        .write(
          TasksCompanion(
            task: Value(t),
            ownerSpeakerId: Value(task.ownerSpeakerId),
            ownerText: Value(jsonNonEmpty(task.ownerText)),
            dueText: Value(jsonNonEmpty(task.dueText)),
            status: Value(task.status.wire),
            updatedAt: Value(now ?? DateTime.now()),
          ),
        );
    return n > 0;
  }

  /// Changes the status and stamps `updatedAt`. Returns true if it existed.
  Future<bool> setStatus(int id, TaskStatus status, {DateTime? now}) async {
    final n = await (_db.update(_db.tasks)..where((t) => t.id.equals(id)))
        .write(
          TasksCompanion(
            status: Value(status.wire),
            updatedAt: Value(now ?? DateTime.now()),
          ),
        );
    return n > 0;
  }

  /// Deletes a task (and its pending updates). Returns true if it existed.
  /// Used for stale untouched tasks of regenerated minutes; a deletion by
  /// the user goes through [deleteByUser].
  Future<bool> delete(int id) async =>
      await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go() > 0;

  /// Deletes [task] at the user's request. When it came from a meeting's
  /// minutes, its action item is remembered as dismissed so regenerating
  /// those minutes does not bring it back. Returns true if it existed.
  Future<bool> deleteByUser(TrackedTask task, {DateTime? now}) =>
      _db.transaction(() async {
        final deleted = await delete(task.id);
        final src = task.sourceMeetingId;
        if (deleted && src != null) {
          await TaskDismissalRepository(_db).add(
            src,
            TaskDismissalKind.task,
            taskMatchKey(task.task),
            now: now,
          );
        }
        return deleted;
      });
}

/// Status changes proposed by minutes, awaiting the user's confirmation.
class PendingTaskUpdateRepository {
  /// Creates the repository over [_db].
  PendingTaskUpdateRepository(this._db);

  final AppDatabase _db;

  /// Converts a row to the domain model.
  static PendingTaskUpdate fromRow(PendingTaskUpdateRow r) => PendingTaskUpdate(
    id: r.id,
    taskId: r.taskId,
    meetingId: r.meetingId,
    newStatus: TaskStatus.parse(r.newStatus),
    note: jsonNonEmpty(r.note),
    evidenceSegmentIds: decodeJsonIntList(r.evidenceJson),
    createdAt: r.createdAt,
  );

  SimpleSelectStatement<$TaskUpdatesPendingTable, PendingTaskUpdateRow> _query({
    String? meetingId,
  }) => _db.select(_db.taskUpdatesPending)
    ..where(
      (u) => meetingId == null
          ? const Constant(true)
          : u.meetingId.equals(meetingId),
    )
    ..orderBy([(u) => OrderingTerm.asc(u.id)]);

  /// Replaces every pending update proposed by [meetingId] with [updates]
  /// (e.g. after the minutes were regenerated), except those the user
  /// already decided on.
  Future<List<PendingTaskUpdate>> replaceForMeeting(
    String meetingId,
    List<MinutesTaskUpdate> updates, {
    DateTime? now,
  }) => _db.transaction(() async {
    await (_db.delete(
      _db.taskUpdatesPending,
    )..where((u) => u.meetingId.equals(meetingId))).go();
    final at = now ?? DateTime.now();
    // Updates the user already confirmed or dismissed are not proposed
    // again by regenerated minutes (a different status still is).
    final decided = await TaskDismissalRepository(
      _db,
    ).keys(meetingId, TaskDismissalKind.update);
    final out = <PendingTaskUpdate>[];
    for (final u in updates) {
      if (decided.contains(taskUpdateDecisionKey(u.taskId, u.newStatus))) {
        continue;
      }
      final evidence = parseEvidenceIds(u.evidence);
      final id = await _db
          .into(_db.taskUpdatesPending)
          .insert(
            TaskUpdatesPendingCompanion.insert(
              taskId: u.taskId,
              meetingId: meetingId,
              newStatus: u.newStatus.wire,
              note: Value(jsonNonEmpty(u.note)),
              evidenceJson: Value(jsonEncode(evidence)),
              createdAt: at,
            ),
          );
      out.add(
        PendingTaskUpdate(
          id: id,
          taskId: u.taskId,
          meetingId: meetingId,
          newStatus: u.newStatus,
          note: jsonNonEmpty(u.note),
          evidenceSegmentIds: evidence,
          createdAt: at,
        ),
      );
    }
    return out;
  });

  /// All pending updates (oldest first), optionally of one meeting.
  Future<List<PendingTaskUpdate>> getAll({String? meetingId}) async =>
      (await _query(
        meetingId: meetingId,
      ).get()).map(fromRow).toList(growable: false);

  /// Like [getAll], re-emitted on change.
  Stream<List<PendingTaskUpdate>> watchAll({String? meetingId}) =>
      _query(meetingId: meetingId)
          .watch()
          .map((rows) => rows.map(fromRow).toList(growable: false));

  /// Applies the pending update [id] to its task (status → `newStatus`,
  /// `updatedAt` → [now]) and removes it. Returns the updated task, or null
  /// when the update (or its task) no longer exists.
  Future<TrackedTask?> confirm(int id, {DateTime? now}) =>
      _db.transaction(() async {
        final r = await (_db.select(
          _db.taskUpdatesPending,
        )..where((u) => u.id.equals(id))).getSingleOrNull();
        if (r == null) return null;
        await (_db.delete(
          _db.taskUpdatesPending,
        )..where((u) => u.id.equals(id))).go();
        final at = now ?? DateTime.now();
        await _remember(r, at);
        final n =
            await (_db.update(
              _db.tasks,
            )..where((t) => t.id.equals(r.taskId))).write(
              TasksCompanion(
                status: Value(TaskStatus.parse(r.newStatus).wire),
                updatedAt: Value(at),
              ),
            );
        if (n == 0) return null;
        final row = await (_db.select(
          _db.tasks,
        )..where((t) => t.id.equals(r.taskId))).getSingle();
        return TaskRepository.fromRow(row);
      });

  /// Discards the pending update [id]. Returns true if it existed. The
  /// decision is remembered: regenerating the minutes does not propose it
  /// again.
  Future<bool> dismiss(int id, {DateTime? now}) => _db.transaction(() async {
    final r = await (_db.select(
      _db.taskUpdatesPending,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    if (r == null) return false;
    await (_db.delete(
      _db.taskUpdatesPending,
    )..where((u) => u.id.equals(id))).go();
    await _remember(r, now ?? DateTime.now());
    return true;
  });

  Future<void> _remember(PendingTaskUpdateRow r, DateTime at) =>
      TaskDismissalRepository(_db).add(
        r.meetingId,
        TaskDismissalKind.update,
        taskUpdateDecisionKey(r.taskId, TaskStatus.parse(r.newStatus)),
        now: at,
      );
}

// ---------------------------------------------------------------------------
// Speaker profiles (F16)
// ---------------------------------------------------------------------------

/// Aggregated profiles of opted-in speakers.
class SpeakerProfileRepository {
  /// Creates the repository over [_db].
  SpeakerProfileRepository(this._db);

  final AppDatabase _db;

  /// Converts a row to the domain model.
  static SpeakerProfileRecord fromRow(SpeakerProfileRow r) =>
      SpeakerProfileRecord(
        speakerId: r.speakerId,
        profile: decodeJsonObject(r.profileJson),
        evidence: decodeEvidenceRefs(r.evidenceJson),
        updatedAt: r.updatedAt,
      );

  /// The profile of [speakerId], or null.
  Future<SpeakerProfileRecord?> get(String speakerId) async {
    final r = await (_db.select(
      _db.speakerProfiles,
    )..where((p) => p.speakerId.equals(speakerId))).getSingleOrNull();
    return r == null ? null : fromRow(r);
  }

  /// Like [get], re-emitted on change.
  Stream<SpeakerProfileRecord?> watch(String speakerId) =>
      (_db.select(_db.speakerProfiles)
            ..where((p) => p.speakerId.equals(speakerId)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : fromRow(r));

  /// All profiles.
  Future<List<SpeakerProfileRecord>> getAll() async =>
      (await _db.select(_db.speakerProfiles).get())
          .map(fromRow)
          .toList(growable: false);

  /// Inserts or replaces the profile of `record.speakerId`.
  Future<void> upsert(SpeakerProfileRecord record) => _db
      .into(_db.speakerProfiles)
      .insertOnConflictUpdate(
        SpeakerProfilesCompanion.insert(
          speakerId: record.speakerId,
          profileJson: jsonEncode(record.profile),
          evidenceJson: Value(
            jsonEncode(record.evidence.map((e) => e.toJson()).toList()),
          ),
          updatedAt: record.updatedAt,
        ),
      );

  /// Deletes the profile of [speakerId]. Returns true if it existed.
  Future<bool> delete(String speakerId) async =>
      await (_db.delete(
        _db.speakerProfiles,
      )..where((p) => p.speakerId.equals(speakerId))).go() >
      0;
}

/// Per-meeting notes of opted-in speakers, extracted with the minutes.
class SpeakerMeetingNotesRepository {
  /// Creates the repository over [_db].
  SpeakerMeetingNotesRepository(this._db);

  final AppDatabase _db;

  /// Converts a row to the domain model.
  static SpeakerMeetingNotesRecord fromRow(SpeakerMeetingNoteRow r) =>
      SpeakerMeetingNotesRecord(
        speakerId: r.speakerId,
        meetingId: r.meetingId,
        notes: MinutesSpeakerNote.fromJson(decodeJsonObject(r.notesJson)),
      );

  /// Replaces the notes of [meetingId] with [notesBySpeakerId].
  Future<void> replaceForMeeting(
    String meetingId,
    Map<String, MinutesSpeakerNote> notesBySpeakerId,
  ) => _db.transaction(() async {
    await (_db.delete(
      _db.speakerMeetingNotes,
    )..where((n) => n.meetingId.equals(meetingId))).go();
    for (final e in notesBySpeakerId.entries) {
      await _db
          .into(_db.speakerMeetingNotes)
          .insert(
            SpeakerMeetingNotesCompanion.insert(
              speakerId: e.key,
              meetingId: meetingId,
              notesJson: jsonEncode(e.value.toJson()),
            ),
          );
    }
  });

  /// Notes of one speaker across meetings (meeting order unspecified; join
  /// with the meetings for dates).
  Future<List<SpeakerMeetingNotesRecord>> getForSpeaker(
    String speakerId,
  ) async =>
      (await (_db.select(
            _db.speakerMeetingNotes,
          )..where((n) => n.speakerId.equals(speakerId))).get())
          .map(fromRow)
          .toList(growable: false);

  /// Like [getForSpeaker], re-emitted on change.
  Stream<List<SpeakerMeetingNotesRecord>> watchForSpeaker(String speakerId) =>
      (_db.select(_db.speakerMeetingNotes)
            ..where((n) => n.speakerId.equals(speakerId)))
          .watch()
          .map((rows) => rows.map(fromRow).toList(growable: false));

  /// Notes stored for [meetingId].
  Future<List<SpeakerMeetingNotesRecord>> getForMeeting(
    String meetingId,
  ) async =>
      (await (_db.select(
            _db.speakerMeetingNotes,
          )..where((n) => n.meetingId.equals(meetingId))).get())
          .map(fromRow)
          .toList(growable: false);

  /// Deletes every note of [speakerId] (e.g. profile disabled and deleted).
  Future<int> deleteForSpeaker(String speakerId) => (_db.delete(
    _db.speakerMeetingNotes,
  )..where((n) => n.speakerId.equals(speakerId))).go();
}

// ---------------------------------------------------------------------------
// Code findings (F17)
// ---------------------------------------------------------------------------

/// Stored F17 findings of meetings.
class CodeFindingRepository {
  /// Creates the repository over [_db].
  CodeFindingRepository(this._db);

  final AppDatabase _db;

  /// Converts a row to the domain model.
  static CodeFinding fromRow(CodeFindingRow r) => CodeFinding(
    id: r.id,
    meetingId: r.meetingId,
    kind: CodeFindingKind.parse(r.kind),
    speakerId: r.speakerId,
    segmentIds: decodeJsonIntList(r.segmentIdsJson),
    payload: decodeJsonObject(r.payloadJson),
    createdAt: r.createdAt,
  );

  SimpleSelectStatement<$CodeFindingsTable, CodeFindingRow> _forMeeting(
    String meetingId,
  ) => _db.select(_db.codeFindings)
    ..where((c) => c.meetingId.equals(meetingId))
    ..orderBy([(c) => OrderingTerm.asc(c.id)]);

  /// Replaces every finding of [meetingId] with [findings] (their `id`,
  /// `meetingId` and `createdAt` are ignored / overwritten).
  Future<List<CodeFinding>> replaceForMeeting(
    String meetingId,
    List<CodeFinding> findings, {
    DateTime? now,
  }) => _db.transaction(() async {
    await (_db.delete(
      _db.codeFindings,
    )..where((c) => c.meetingId.equals(meetingId))).go();
    final at = now ?? DateTime.now();
    final out = <CodeFinding>[];
    for (final f in findings) {
      final ids = parseEvidenceIds(f.segmentIds);
      final id = await _db
          .into(_db.codeFindings)
          .insert(
            CodeFindingsCompanion.insert(
              meetingId: meetingId,
              kind: f.kind.wire,
              speakerId: Value(f.speakerId),
              segmentIdsJson: Value(jsonEncode(ids)),
              payloadJson: jsonEncode(f.payload),
              createdAt: at,
            ),
          );
      out.add(
        CodeFinding(
          id: id,
          meetingId: meetingId,
          kind: f.kind,
          speakerId: f.speakerId,
          segmentIds: ids,
          payload: f.payload,
          createdAt: at,
        ),
      );
    }
    return out;
  });

  /// Findings of [meetingId] in insertion order.
  Future<List<CodeFinding>> getForMeeting(String meetingId) async =>
      (await _forMeeting(meetingId).get()).map(fromRow).toList(growable: false);

  /// Like [getForMeeting], re-emitted on change.
  Stream<List<CodeFinding>> watchForMeeting(String meetingId) =>
      _forMeeting(meetingId)
          .watch()
          .map((rows) => rows.map(fromRow).toList(growable: false));

  /// Findings of one kind across all meetings (e.g. every jargon term).
  Future<List<CodeFinding>> getByKind(CodeFindingKind kind) async =>
      (await (_db.select(_db.codeFindings)
                ..where((c) => c.kind.equals(kind.wire))
                ..orderBy([(c) => OrderingTerm.asc(c.id)]))
              .get())
          .map(fromRow)
          .toList(growable: false);

  /// Replaces the payload of one finding (e.g. enriched by a reversed-audio
  /// re-ASR). Returns true if it existed.
  Future<bool> updatePayload(int id, Map<String, dynamic> payload) async =>
      await (_db.update(_db.codeFindings)..where((c) => c.id.equals(id))).write(
        CodeFindingsCompanion(payloadJson: Value(jsonEncode(payload))),
      ) >
      0;

  /// Deletes one finding. Returns true if it existed.
  Future<bool> delete(int id) async =>
      await (_db.delete(_db.codeFindings)..where((c) => c.id.equals(id))).go() >
      0;
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// [GlossaryRepository] over [databaseProvider].
final glossaryRepositoryProvider = Provider<GlossaryRepository>(
  (ref) => GlossaryRepository(ref.watch(databaseProvider)),
);

/// [TaskRepository] over [databaseProvider].
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(databaseProvider)),
);

/// [PendingTaskUpdateRepository] over [databaseProvider].
final pendingTaskUpdateRepositoryProvider =
    Provider<PendingTaskUpdateRepository>(
      (ref) => PendingTaskUpdateRepository(ref.watch(databaseProvider)),
    );

/// [SpeakerProfileRepository] over [databaseProvider].
final speakerProfileRepositoryProvider = Provider<SpeakerProfileRepository>(
  (ref) => SpeakerProfileRepository(ref.watch(databaseProvider)),
);

/// [SpeakerMeetingNotesRepository] over [databaseProvider].
final speakerMeetingNotesRepositoryProvider =
    Provider<SpeakerMeetingNotesRepository>(
      (ref) => SpeakerMeetingNotesRepository(ref.watch(databaseProvider)),
    );

/// [CodeFindingRepository] over [databaseProvider].
final codeFindingRepositoryProvider = Provider<CodeFindingRepository>(
  (ref) => CodeFindingRepository(ref.watch(databaseProvider)),
);

/// Global glossary terms, alphabetical.
final globalGlossaryProvider = StreamProvider<List<GlossaryTerm>>(
  (ref) => ref.watch(glossaryRepositoryProvider).watchGlobal(),
);

/// Meeting-only glossary terms of a meeting.
final meetingGlossaryProvider = StreamProvider.autoDispose
    .family<List<GlossaryTerm>, String>(
      (ref, meetingId) =>
          ref.watch(glossaryRepositoryProvider).watchForMeeting(meetingId),
    );

/// All tracked tasks, newest first.
final tasksProvider = StreamProvider<List<TrackedTask>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAll(),
);

/// Open tasks, newest first.
final openTasksProvider = StreamProvider<List<TrackedTask>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAll(status: TaskStatus.open),
);

/// Tasks created by one meeting's minutes.
final meetingTasksProvider = StreamProvider.autoDispose
    .family<List<TrackedTask>, String>(
      (ref, meetingId) => ref
          .watch(taskRepositoryProvider)
          .watchAll(sourceMeetingId: meetingId),
    );

/// All pending task updates awaiting confirmation.
final pendingTaskUpdatesProvider = StreamProvider<List<PendingTaskUpdate>>(
  (ref) => ref.watch(pendingTaskUpdateRepositoryProvider).watchAll(),
);

/// Pending task updates proposed by one meeting.
final meetingPendingTaskUpdatesProvider = StreamProvider.autoDispose
    .family<List<PendingTaskUpdate>, String>(
      (ref, meetingId) => ref
          .watch(pendingTaskUpdateRepositoryProvider)
          .watchAll(meetingId: meetingId),
    );

/// Profile of one speaker (null when none).
final speakerProfileProvider = StreamProvider.autoDispose
    .family<SpeakerProfileRecord?, String>(
      (ref, speakerId) =>
          ref.watch(speakerProfileRepositoryProvider).watch(speakerId),
    );

/// Per-meeting notes of one speaker.
final speakerMeetingNotesProvider = StreamProvider.autoDispose
    .family<List<SpeakerMeetingNotesRecord>, String>(
      (ref, speakerId) => ref
          .watch(speakerMeetingNotesRepositoryProvider)
          .watchForSpeaker(speakerId),
    );

/// F17 findings of one meeting.
final codeFindingsProvider = StreamProvider.autoDispose
    .family<List<CodeFinding>, String>(
      (ref, meetingId) =>
          ref.watch(codeFindingRepositoryProvider).watchForMeeting(meetingId),
    );
