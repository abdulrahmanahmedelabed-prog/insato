// Drift (SQLite) schema for Insato.
//
// The database stores meetings, their transcript segments, the global speaker
// voiceprints shared across meetings, and a small key/value settings table.
// Schema v2 (Insato v1.1) adds meeting context, segment kinds, speaker
// profile flags and the glossary / task / profile / code-finding tables.
// Domain conversion lives in `repositories.dart` and `repositories_v11.dart`;
// this file only defines the schema, the connection and the migration
// strategy ([AppDatabase.migration], tested from a v1 fixture).

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/models.dart' show ActionItem;

part 'database.g.dart';

/// Stores a [DateTime] as UTC milliseconds since the epoch.
///
/// Drift's default `DateTimeColumn` stores whole seconds only; meeting and
/// speaker creation times need millisecond precision so that "newest first"
/// ordering is stable for meetings created in quick succession.
class EpochMillisConverter extends TypeConverter<DateTime, int> {
  /// Creates the converter.
  const EpochMillisConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true).toLocal();

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

/// Global speakers (voiceprints) shared across all meetings.
@DataClassName('SpeakerRow')
class Speakers extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Display name (auto names look like `متحدث 3`).
  TextColumn get name => text()();

  /// ARGB color used for chips and avatars.
  IntColumn get color => integer()();

  /// True once the user explicitly renamed the speaker.
  BoolColumn get isNamedByUser =>
      boolean().withDefault(const Constant(false))();

  /// Creation time (UTC epoch milliseconds in SQL).
  IntColumn get createdAt => integer().map(const EpochMillisConverter())();

  /// L2-normalised centroid as little-endian Float32 bytes; null when the
  /// voice was forgotten or never enrolled.
  BlobColumn get centroid => blob().nullable()();

  /// Number of embeddings averaged into [centroid].
  IntColumn get embeddingCount => integer().withDefault(const Constant(0))();

  /// v2 (F16): the user opted this speaker in to profiles.
  BoolColumn get profileEnabled =>
      boolean().withDefault(const Constant(false))();

  /// v2 (F18): input device the voiceprint was learned on.
  TextColumn get voiceDevice => text().nullable()();

  /// v2 (F15): heard only briefly; voiceprint not used for matching yet.
  BoolColumn get lowConfidence =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Recorded meetings.
@DataClassName('MeetingRow')
class Meetings extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// User-visible title.
  TextColumn get title => text()();

  /// Creation time (UTC epoch milliseconds in SQL).
  IntColumn get createdAt => integer().map(const EpochMillisConverter())();

  /// `MeetingStatus.name` (recording / processing / ready / failed).
  TextColumn get status => text()();

  /// Recorded duration in milliseconds.
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// Absolute path of the archived WAV file, if kept.
  TextColumn get audioPath => text().nullable()();

  /// `Minutes.toJson()` encoded as JSON text.
  TextColumn get minutesJson => text().nullable()();

  /// Arabic, user-facing error message when [status] is `failed`.
  TextColumn get errorMessage => text().nullable()();

  /// v2 (F3): ordered agenda items as a JSON list of strings.
  TextColumn get agendaJson =>
      text().named('agenda').withDefault(const Constant('[]'))();

  /// v2 (F3): expected attendee names as a JSON list of strings.
  TextColumn get expectedAttendeesJson =>
      text().named('expected_attendees').withDefault(const Constant('[]'))();

  /// v2 (F3): free-text context notes.
  TextColumn get contextNotes => text().nullable()();

  /// v2 (F3, reserved for v1.2): minutes template id.
  TextColumn get template => text().nullable()();

  /// v2 (F18): input device used for the recording.
  TextColumn get inputDevice => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Transcript segments of a meeting.
@DataClassName('SegmentRow')
@TableIndex(name: 'segments_meeting_idx', columns: {#meetingId, #idx})
@TableIndex(name: 'segments_speaker', columns: {#speakerId})
class Segments extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Owning meeting; segments are deleted with their meeting.
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();

  /// Monotonic index within the meeting (0-based).
  IntColumn get idx => integer()();

  /// Start offset in milliseconds.
  IntColumn get startMs => integer()();

  /// End offset in milliseconds.
  IntColumn get endMs => integer()();

  /// Transcribed text.
  TextColumn get body => text().named('text')();

  /// Assigned speaker; set to null when the speaker is deleted.
  TextColumn get speakerId => text()
      .nullable()
      .references(Speakers, #id, onDelete: KeyAction.setNull)();

  /// ISO-639-1 language code reported by the ASR engine.
  TextColumn get language => text().nullable()();

  /// L2-normalised speaker embedding as little-endian Float32 bytes.
  BlobColumn get embedding => blob().nullable()();

  /// True when the user manually assigned the speaker.
  BoolColumn get speakerLocked =>
      boolean().withDefault(const Constant(false))();

  /// v2 (F17): `SegmentKind.wire` — `speech` or `unintelligible`.
  TextColumn get kind => text().withDefault(const Constant('speech'))();

  /// v2: recogniser confidence 0..1 when reported.
  RealColumn get asrConfidence => real().nullable()();

  /// Confidence (0..1) of the automatic speaker assignment; null when
  /// unknown (rows from schema 1 and 2).
  RealColumn get speakerConfidence => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// v2 (F2): custom vocabulary (canonical spellings).
@DataClassName('GlossaryTermRow')
@TableIndex(name: 'glossary_terms_meeting', columns: {#meetingId})
class GlossaryTerms extends Table {
  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The term as it should be spelled.
  TextColumn get term => text()();

  /// Optional Arabic spelling / translation.
  TextColumn get arSpelling => text().nullable()();

  /// `GlossaryCategory.wire`.
  TextColumn get category => text().withDefault(const Constant('other'))();

  /// Meeting for a meeting-only term (F3); null for a global term.
  TextColumn get meetingId => text()
      .nullable()
      .references(Meetings, #id, onDelete: KeyAction.cascade)();

  /// Creation time (UTC epoch milliseconds in SQL).
  IntColumn get createdAt => integer().map(const EpochMillisConverter())();
}

/// v2 (F9): action items tracked across meetings.
@DataClassName('TaskRow')
@TableIndex(name: 'tasks_status', columns: {#status})
@TableIndex(name: 'tasks_source_meeting', columns: {#sourceMeetingId})
class Tasks extends Table {
  /// Auto-increment primary key (the `task_id` shown to the minutes engine).
  IntColumn get id => integer().autoIncrement()();

  /// Task description.
  TextColumn get task => text()();

  /// Owner speaker, set to null when the speaker is deleted.
  TextColumn get ownerSpeakerId => text()
      .nullable()
      .references(Speakers, #id, onDelete: KeyAction.setNull)();

  /// Owner as free text.
  TextColumn get ownerText => text().nullable()();

  /// Deadline as stated.
  TextColumn get dueText => text().nullable()();

  /// `TaskStatus.wire` — open / done / cancelled.
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// Meeting whose minutes created the task; null when deleted / manual.
  TextColumn get sourceMeetingId => text()
      .nullable()
      .references(Meetings, #id, onDelete: KeyAction.setNull)();

  /// Evidence segment indices (JSON list of integers).
  TextColumn get evidenceSegmentIds =>
      text().withDefault(const Constant('[]'))();

  /// Creation time (UTC epoch milliseconds in SQL).
  IntColumn get createdAt => integer().map(const EpochMillisConverter())();

  /// Last update (UTC epoch milliseconds in SQL).
  IntColumn get updatedAt => integer().map(const EpochMillisConverter())();
}

/// v2 (F9): task status changes proposed by minutes, awaiting confirmation.
@DataClassName('PendingTaskUpdateRow')
@TableIndex(name: 'task_updates_pending_meeting', columns: {#meetingId})
@TableIndex(name: 'task_updates_pending_task', columns: {#taskId})
class TaskUpdatesPending extends Table {
  @override
  String get tableName => 'task_updates_pending';

  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Task concerned; deleted with the task.
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();

  /// Meeting whose minutes proposed it; deleted with the meeting.
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();

  /// Proposed `TaskStatus.wire`.
  TextColumn get newStatus => text()();

  /// Arabic note.
  TextColumn get note => text().nullable()();

  /// Evidence segment indices (JSON list of integers).
  TextColumn get evidenceJson =>
      text().named('evidence').withDefault(const Constant('[]'))();

  /// Creation time (UTC epoch milliseconds in SQL).
  IntColumn get createdAt => integer().map(const EpochMillisConverter())();
}

/// v4 (F9): what the user already decided about a meeting's minutes, so a
/// regeneration does not undo it: action items whose task the user deleted
/// (`kind = task`, key = normalised task text) and task updates the user
/// rejected or acknowledged (`kind = update`, key = `taskId|newStatus`).
/// Deleted with the meeting.
@DataClassName('TaskDismissalRow')
class TaskDismissals extends Table {
  @override
  String get tableName => 'task_dismissals';

  /// Meeting whose minutes proposed the item.
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();

  /// `task` or `update`.
  TextColumn get kind => text()();

  /// Dismissed item key (see the class comment).
  TextColumn get itemKey => text()();

  /// When it was dismissed (UTC epoch milliseconds in SQL).
  IntColumn get createdAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {meetingId, kind, itemKey};
}

/// v2 (F16): aggregated speaker profiles (opt-in speakers only).
@DataClassName('SpeakerProfileRow')
class SpeakerProfiles extends Table {
  /// Speaker; the profile is deleted with the speaker.
  TextColumn get speakerId =>
      text().references(Speakers, #id, onDelete: KeyAction.cascade)();

  /// Profile JSON (shape owned by lib/features/profiles).
  TextColumn get profileJson => text()();

  /// Cited evidence as a JSON list of `{meeting_id, segment}`.
  TextColumn get evidenceJson =>
      text().named('evidence').withDefault(const Constant('[]'))();

  /// Last update (UTC epoch milliseconds in SQL).
  IntColumn get updatedAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {speakerId};
}

/// v2 (F16): per-meeting notes of opted-in speakers.
@DataClassName('SpeakerMeetingNoteRow')
@TableIndex(name: 'speaker_meeting_notes_meeting', columns: {#meetingId})
class SpeakerMeetingNotes extends Table {
  /// Speaker; deleted with the speaker.
  TextColumn get speakerId =>
      text().references(Speakers, #id, onDelete: KeyAction.cascade)();

  /// Meeting; deleted with the meeting.
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();

  /// `MinutesSpeakerNote.toJson()`.
  TextColumn get notesJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {speakerId, meetingId};
}

/// v2 (F17): codes, jargon, spoken code, implied speech, references.
@DataClassName('CodeFindingRow')
@TableIndex(name: 'code_findings_meeting', columns: {#meetingId})
class CodeFindings extends Table {
  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Meeting; deleted with the meeting.
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();

  /// `CodeFindingKind.wire`.
  TextColumn get kind => text()();

  /// Speaker who said it; null when unresolved or deleted.
  TextColumn get speakerId => text()
      .nullable()
      .references(Speakers, #id, onDelete: KeyAction.setNull)();

  /// Evidence segment indices (JSON list of integers).
  TextColumn get segmentIdsJson =>
      text().named('segment_ids').withDefault(const Constant('[]'))();

  /// Finding JSON.
  TextColumn get payloadJson => text()();

  /// Creation time (UTC epoch milliseconds in SQL).
  IntColumn get createdAt => integer().map(const EpochMillisConverter())();
}

/// Simple key/value application settings.
@DataClassName('SettingRow')
class Settings extends Table {
  /// Setting key.
  TextColumn get key => text()();

  /// Setting value encoded as text.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The Insato SQLite database.
@DriftDatabase(tables: [
  Speakers,
  Meetings,
  Segments,
  Settings,
  GlossaryTerms,
  Tasks,
  TaskUpdatesPending,
  SpeakerProfiles,
  SpeakerMeetingNotes,
  CodeFindings,
  TaskDismissals,
])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database file `insato.sqlite` in the application
  /// documents directory on a background isolate. Used on Android and iOS;
  /// on Windows the app opens it in a private local app-data folder with
  /// [AppDatabase.inDirectory] instead (see `openAppDatabase` in main.dart),
  /// because Documents is shared with other apps and often synced.
  AppDatabase() : super(driftDatabase(name: 'insato'));

  /// Opens `insato.sqlite` in the directory returned by [directory] on a
  /// background isolate. [tempDirectory] (SQLite's temporary files) defaults
  /// to the platform temporary directory.
  AppDatabase.inDirectory(
    Future<String> Function() directory, {
    Future<String?> Function()? tempDirectory,
  }) : super(driftDatabase(
          name: 'insato',
          native: DriftNativeOptions(
            databaseDirectory: () async => directory(),
            tempDirectoryPath: tempDirectory,
          ),
        ));

  /// Opens the database on an arbitrary [executor], e.g.
  /// `NativeDatabase.memory()` in tests.
  AppDatabase.forExecutor(super.executor);

  /// Current schema version (v1.1 = 2, speaker confidence = 3, task
  /// dismissals = 4).
  static const int currentSchemaVersion = 4;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await _migrateV1ToV2(m);
          if (from < 3 && to >= 3) {
            await m.addColumn(segments, segments.speakerConfidence);
          }
          if (from < 4 && to >= 4) {
            await m.createTable(taskDismissals);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// v1 → v2 (Insato v1.1): new nullable / defaulted columns on existing
  /// tables (existing rows get the defaults: no context, `speech` segments,
  /// profiles off) and the new tables with their indexes. Runs inside the
  /// migration transaction; v1 data is never rewritten.
  Future<void> _migrateV1ToV2(Migrator m) async {
    await m.addColumn(speakers, speakers.profileEnabled);
    await m.addColumn(speakers, speakers.voiceDevice);
    await m.addColumn(speakers, speakers.lowConfidence);
    await m.addColumn(meetings, meetings.agendaJson);
    await m.addColumn(meetings, meetings.expectedAttendeesJson);
    await m.addColumn(meetings, meetings.contextNotes);
    await m.addColumn(meetings, meetings.template);
    await m.addColumn(meetings, meetings.inputDevice);
    await m.addColumn(segments, segments.kind);
    await m.addColumn(segments, segments.asrConfidence);
    await m.createTable(glossaryTerms);
    await m.createTable(tasks);
    await m.createTable(taskUpdatesPending);
    await m.createTable(speakerProfiles);
    await m.createTable(speakerMeetingNotes);
    await m.createTable(codeFindings);
    for (final index in [
      glossaryTermsMeeting,
      tasksStatus,
      tasksSourceMeeting,
      taskUpdatesPendingMeeting,
      taskUpdatesPendingTask,
      speakerMeetingNotesMeeting,
      codeFindingsMeeting,
    ]) {
      await m.createIndex(index);
    }
    await _backfillTasksFromV1Minutes();
  }

  /// v1 minutes already list action items, but tasks (F9) are otherwise
  /// filled only when minutes are generated: without this the Tasks screen,
  /// the open-tasks banner and the next meeting's prompt would ignore every
  /// past meeting. Creates one open task per distinct action item of each
  /// meeting with minutes, dated at the meeting's creation (`updatedAt ==
  /// createdAt`, so a later regeneration treats them like generated,
  /// untouched tasks). The owner is linked when exactly one speaker has
  /// that name. Raw SQL reads, so later schema changes do not affect it; a
  /// corrupt minutes row is skipped and never fails the migration.
  Future<void> _backfillTasksFromV1Minutes() async {
    String key(String s) =>
        s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final ownerIds = <String, String?>{};
    for (final r in await customSelect('SELECT id, name FROM speakers').get()) {
      final k = key(r.read<String>('name'));
      if (k.isEmpty) continue;
      ownerIds[k] = ownerIds.containsKey(k) ? null : r.read<String>('id');
    }
    final rows = await customSelect(
      'SELECT id, minutes_json, created_at FROM meetings '
      'WHERE minutes_json IS NOT NULL',
    ).get();
    for (final r in rows) {
      final List<ActionItem> items;
      try {
        final json = jsonDecode(r.read<String>('minutes_json'));
        final raw = json is Map ? json['action_items'] : null;
        if (raw is! List) continue;
        items = [
          for (final a in raw)
            if (a is Map) ActionItem.fromJson(a.cast<String, dynamic>()),
        ];
      } on Object catch (_) {
        continue; // FormatException / TypeError: corrupt row.
      }
      final at = const EpochMillisConverter().fromSql(r.read<int>('created_at'));
      final seen = <String>{};
      for (final a in items) {
        final k = key(a.task);
        if (k.isEmpty || !seen.add(k)) continue;
        final owner = a.owner;
        await into(tasks).insert(
          TasksCompanion.insert(
            task: a.task.trim(),
            ownerSpeakerId: Value(owner == null ? null : ownerIds[key(owner)]),
            ownerText: Value(owner),
            dueText: Value(a.dueDate),
            status: const Value('open'),
            sourceMeetingId: Value(r.read<String>('id')),
            evidenceSegmentIds: Value(jsonEncode(a.evidence)),
            createdAt: at,
            updatedAt: at,
          ),
        );
      }
    }
  }
}

/// Encodes a float vector as little-endian Float32 bytes for BLOB storage.
Uint8List float32ToBlob(Float32List values) {
  final data = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    data.setFloat32(i * 4, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Decodes little-endian Float32 bytes produced by [float32ToBlob].
///
/// Returns null for null or empty input. Throws [FormatException] when the
/// byte length is not a multiple of 4 (corrupt data).
Float32List? blobToFloat32(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  if (bytes.length % 4 != 0) {
    throw FormatException(
        'Float32 blob length ${bytes.length} is not a multiple of 4');
  }
  final data = ByteData.sublistView(bytes);
  final out = Float32List(bytes.length ~/ 4);
  for (var i = 0; i < out.length; i++) {
    out[i] = data.getFloat32(i * 4, Endian.little);
  }
  return out;
}
