import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/data/database.dart';

void main() {
  test('inDirectory opens insato.sqlite in the given directory', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('insato_db_');
    addTearDown(() => dir.delete(recursive: true));
    final db = AppDatabase.inDirectory(
      () async => dir.path,
      tempDirectory: () async => dir.path,
    );
    await db.into(db.settings).insert(
          SettingsCompanion.insert(key: 'k', value: 'v'),
        );
    expect((await db.select(db.settings).getSingle()).value, 'v');
    await db.close();
    expect(File('${dir.path}/insato.sqlite').existsSync(), isTrue);
  });

  group('float32 blob codec', () {
    test('round-trips values exactly, little-endian', () {
      final v = Float32List.fromList([1.0, -0.5, 0.25, 3.4e38, -1e-7, 0]);
      final blob = float32ToBlob(v);
      expect(blob.length, 24);
      // 1.0f little-endian = 00 00 80 3F
      expect(blob.sublist(0, 4), [0x00, 0x00, 0x80, 0x3F]);
      expect(blobToFloat32(blob), v);
    });

    test('decodes from an unaligned view', () {
      final v = Float32List.fromList([0.1, 0.2, 0.3]);
      final padded = Uint8List(13)..setAll(1, float32ToBlob(v));
      final view = Uint8List.sublistView(padded, 1);
      expect(blobToFloat32(view), v);
    });

    test('null and empty decode to null', () {
      expect(blobToFloat32(null), isNull);
      expect(blobToFloat32(Uint8List(0)), isNull);
    });

    test('rejects lengths that are not a multiple of 4', () {
      expect(() => blobToFloat32(Uint8List(5)), throwsFormatException);
    });
  });

  group('EpochMillisConverter', () {
    test('keeps millisecond precision', () {
      const c = EpochMillisConverter();
      final t = DateTime.utc(2026, 11, 19, 10, 20, 30, 456);
      final sql = c.toSql(t);
      expect(sql, t.millisecondsSinceEpoch);
      expect(c.fromSql(sql).isAtSameMomentAs(t), isTrue);
      expect(c.fromSql(sql).isUtc, isFalse);
    });
  });

  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('enables foreign keys', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    });

    test('creates the expected indexes', () async {
      final rows = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' AND "
              "tbl_name = 'segments'")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(['segments_meeting_idx', 'segments_speaker']));
    });

    test('segment text column is named "text" in SQL', () async {
      final rows =
          await db.customSelect("PRAGMA table_info('segments')").get();
      final cols = rows.map((r) => r.read<String>('name')).toSet();
      expect(cols, containsAll(['id', 'meeting_id', 'idx', 'text',
          'speaker_id', 'embedding', 'speaker_locked']));
    });

    test('rejects segments of unknown meetings', () async {
      await expectLater(
        db.into(db.segments).insert(SegmentsCompanion.insert(
              id: 's1',
              meetingId: 'missing',
              idx: 0,
              startMs: 0,
              endMs: 10,
              body: 'x',
            )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('schema version is 6 (v1.2 consistency checker)', () {
      expect(db.schemaVersion, 6);
      expect(AppDatabase.currentSchemaVersion, 6);
    });

    test('blob columns store raw bytes', () async {
      final v = Float32List.fromList([0.6, 0.8]);
      await db.into(db.speakers).insert(SpeakersCompanion.insert(
            id: 'a',
            name: 'n',
            color: 1,
            createdAt: DateTime.now(),
            centroid: Value(float32ToBlob(v)),
          ));
      final row = await db.select(db.speakers).getSingle();
      expect(blobToFloat32(row.centroid), v);
    });
  });
}
