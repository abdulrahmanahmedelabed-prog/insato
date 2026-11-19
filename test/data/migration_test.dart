// Schema migration v1 (Insato 1.0) → v2 (Insato 1.1), verified against the
// drift schema snapshots in drift_schemas/ (regenerate the helpers with
// `dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/`
// after adding a schema version).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;

/// Inserts a small but complete v1 data set (a speaker with a voiceprint, a
/// meeting with stored v1 minutes, two segments and a setting) using v1's
/// raw SQL shape.
void seedV1(dynamic raw) {
  final minutes = jsonEncode({
    'title': 'اجتماع قديم',
    'summary': 'ملخص',
    'attendees': ['أحمد'],
    'topics': [
      {
        'title': 'بند',
        'discussion': 'نقاش',
        'speakers': ['أحمد'],
      },
    ],
    'decisions': [
      {'text': 'قرار', 'proposed_by': 'أحمد'},
    ],
    'action_items': [
      {'task': 'مهمة', 'owner': 'أحمد', 'due': null},
    ],
    'open_questions': <String>[],
    'languages_detected': ['العربية'],
    'next_meeting': null,
    'notes': null,
    'generated_at': '2026-01-02T03:04:05.000Z',
    'model': 'claude-opus-5-5',
  });
  raw.execute(
    'INSERT INTO speakers (id, name, color, is_named_by_user, created_at, '
    'centroid, embedding_count) VALUES (?, ?, ?, 1, ?, ?, 3)',
    [
      'sp1',
      'أحمد',
      0xFF1565C0,
      1700000000000,
      float32ToBlob(Float32List.fromList([0.6, 0.8])),
    ],
  );
  raw.execute(
    'INSERT INTO meetings (id, title, created_at, duration_ms, status, '
    'audio_path, minutes_json, error_message) '
    'VALUES (?, ?, ?, 60000, ?, ?, ?, NULL)',
    ['m1', 'اجتماع قديم', 1700000001000, 'ready', 'm1.wav', minutes],
  );
  for (final (i, text) in [(0, 'مرحبا'), (1, 'نبدأ الاجتماع')]) {
    raw.execute(
      'INSERT INTO segments (id, meeting_id, idx, start_ms, end_ms, text, '
      'speaker_id, language, embedding, speaker_locked) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, 0)',
      ['s$i', 'm1', i, i * 2000, i * 2000 + 1500, text, 'sp1', 'ar'],
    );
  }
  raw.execute(
    "INSERT INTO settings (key, value) VALUES ('asr_engine', 'cloud')",
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v1 → v2 produces exactly the v2 schema', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase.forExecutor(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('v2 → v3 produces exactly the v3 schema', () async {
    final schema = await verifier.schemaAt(2);
    final db = AppDatabase.forExecutor(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('v1 → v3 produces exactly the v3 schema', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase.forExecutor(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('a fresh database is created at the current version', () async {
    final schema = await verifier.schemaAt(AppDatabase.currentSchemaVersion);
    final db = AppDatabase.forExecutor(schema.newConnection());
    await verifier.migrateAndValidate(db, AppDatabase.currentSchemaVersion);
    await db.close();
  });

  test('v1 data survives the migration with v1.1 defaults', () async {
    final schema = await verifier.schemaAt(1);
    seedV1(schema.rawDatabase);
    final db = AppDatabase.forExecutor(schema.newConnection());
    addTearDown(db.close);

    final meeting = await MeetingRepository(db).get('m1');
    expect(meeting, isNotNull);
    expect(meeting!.title, 'اجتماع قديم');
    expect(meeting.status, MeetingStatus.ready);
    expect(meeting.context, MeetingContext.empty);
    expect(meeting.inputDevice, isNull);
    final minutes = meeting.minutes!;
    expect(minutes.topics.single.evidence, isEmpty);
    expect(minutes.actionItems.single.task, 'مهمة');
    expect(minutes.taskUpdates, isEmpty);
    expect(minutes.codes.isEmpty, isTrue);
    expect(minutes.speakerNotes, isEmpty);
    expect(minutes.model, 'claude-opus-5-5');

    final segs = await SegmentRepository(db).getForMeeting('m1');
    expect(segs.map((s) => s.text), ['مرحبا', 'نبدأ الاجتماع']);
    expect(segs.every((s) => s.kind == SegmentKind.speech), isTrue);
    expect(segs.every((s) => s.asrConfidence == null), isTrue);

    final sp = (await SpeakerRepository(db).get('sp1'))!;
    expect(sp.isNamedByUser, isTrue);
    expect(sp.embeddingCount, 3);
    expect(sp.centroid, isNotNull);
    expect(sp.profileEnabled, isFalse);
    expect(sp.lowConfidence, isFalse);
    expect(sp.voiceDevice, isNull);

    // The new tables exist, are empty and usable with foreign keys on.
    expect(await GlossaryRepository(db).getGlobal(), isEmpty);
    final task = await TaskRepository(db)
        .create(task: 'متابعة', ownerSpeakerId: 'sp1', sourceMeetingId: 'm1');
    expect((await TaskRepository(db).get(task.id))!.ownerSpeakerId, 'sp1');
    await MeetingRepository(db)
        .updateContext('m1', const MeetingContext(agenda: ['بند 1']));
    expect((await MeetingRepository(db).get('m1'))!.context.agenda, ['بند 1']);
  });

  test('an on-disk v1 file is upgraded when opened by the app', () async {
    final dir = await Directory.systemTemp.createTemp('insato_mig_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/insato.sqlite');

    final old = v1.DatabaseAtV1(NativeDatabase(file));
    // Opening runs v1's createAll and stamps user_version = 1.
    await old.customSelect('SELECT 1').get();
    final raw = _RawExec(old);
    await raw.seed();
    await old.close();

    final db = AppDatabase.forExecutor(NativeDatabase(file));
    addTearDown(db.close);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, AppDatabase.currentSchemaVersion);
    final segs = await SegmentRepository(db).getForMeeting('m1');
    expect(segs, hasLength(2));
    expect(segs.first.kind, SegmentKind.speech);
    expect(
      (await MeetingRepository(db).get('m1'))!.minutes!.title,
      'اجتماع قديم',
    );
  });
}

/// Seeds a v1 database through drift's executor (same rows as [seedV1]).
class _RawExec {
  _RawExec(this.db);
  final GeneratedDatabase db;

  Future<void> seed() async {
    final collected = <(String, List<Object?>)>[];
    seedV1(_Collector(collected));
    for (final (sql, args) in collected) {
      await db.customStatement(sql, args);
    }
  }
}

class _Collector {
  _Collector(this.out);
  final List<(String, List<Object?>)> out;
  void execute(String sql, [List<Object?> args = const []]) =>
      out.add((sql, args));
}
