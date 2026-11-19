// Drift (SQLite) schema for Insato.
//
// The database stores meetings, their transcript segments, the global speaker
// voiceprints shared across meetings, and a small key/value settings table.
// Domain conversion lives in `repositories.dart`; this file only defines the
// schema, the connection and the migration strategy.

import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

  @override
  Set<Column<Object>> get primaryKey => {id};
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
@DriftDatabase(tables: [Speakers, Meetings, Segments, Settings])
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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Version 1 is the first schema; future versions add steps here.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
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
