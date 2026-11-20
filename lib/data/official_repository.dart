// Storage of official minutes (v1.2, A): the per-meeting official record,
// approved versions, signatures, plus the entity profile and the uploaded
// Word templates (JSON values in the settings table).

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../features/official/official_logic.dart'
    show nameKey, nextMeetingNumber;
import '../features/official/official_models.dart';
import 'database.dart';
import 'repositories.dart' show databaseProvider;

/// Thrown when locked (approved) official minutes would be changed.
class OfficialMinutesLockedException implements Exception {
  /// Creates the exception.
  const OfficialMinutesLockedException();

  /// Arabic message.
  String get messageAr => 'المحضر معتمد ومقفل. أنشئ إصداراً جديداً لتعديله.';

  @override
  String toString() => 'OfficialMinutesLockedException';
}

/// Official records, versions and signatures.
class OfficialMinutesRepository {
  /// Creates the repository over [_db].
  OfficialMinutesRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static OfficialRecord _fromRow(OfficialRecordRow r) {
    Object? json;
    try {
      json = jsonDecode(r.recordJson);
    } on FormatException {
      json = null;
    }
    final rec = OfficialRecord.fromJson(r.meetingId, json);
    // The indexed columns are authoritative for lifecycle fields.
    return rec.copyWith(
      version: r.version,
      status: OfficialStatus.parse(r.status),
    );
  }

  /// The record of [meetingId], or null.
  Future<OfficialRecord?> get(String meetingId) async {
    final row = await (_db.select(
      _db.officialRecords,
    )..where((t) => t.meetingId.equals(meetingId))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Watches the record of [meetingId].
  Stream<OfficialRecord?> watch(String meetingId) =>
      (_db.select(_db.officialRecords)
            ..where((t) => t.meetingId.equals(meetingId)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _fromRow(r));

  /// Inserts or replaces [record]. [entityName] keys the meeting-number
  /// sequence. Throws [OfficialMinutesLockedException] when the stored
  /// record is approved and [record] is not an approval of the same version
  /// (use [startNewVersion] first).
  Future<OfficialRecord> save(
    OfficialRecord record, {
    String entityName = '',
    bool allowLocked = false,
  }) => _db.transaction(() async {
    final current = await get(record.meetingId);
    if (!allowLocked &&
        current != null &&
        current.isLocked &&
        current.version == record.version) {
      throw const OfficialMinutesLockedException();
    }
    await _write(record, entityName);
    return record;
  });

  Future<void> _write(OfficialRecord record, String entityName) => _db
      .into(_db.officialRecords)
      .insertOnConflictUpdate(
        OfficialRecordsCompanion.insert(
          meetingId: record.meetingId,
          entityKey: Value(nameKey(entityName)),
          committee: Value(nameKey(record.committee ?? '')),
          numberYear: Value(record.numberYear),
          meetingNumber: Value(record.meetingNumber),
          status: Value(record.status.name),
          version: Value(record.version),
          recordJson: record.encode(),
          updatedAt: _clock(),
        ),
      );

  /// Next meeting number of [entityName] / [committee] in [year], ignoring
  /// [exceptMeetingId].
  Future<int> nextNumber({
    required String entityName,
    String? committee,
    required int year,
    String? exceptMeetingId,
  }) async {
    final rows =
        await (_db.select(_db.officialRecords)..where(
              (t) =>
                  t.entityKey.equals(nameKey(entityName)) &
                  t.committee.equals(nameKey(committee ?? '')) &
                  t.numberYear.equals(year),
            ))
            .get();
    return nextMeetingNumber([
      for (final r in rows)
        if (r.meetingId != exceptMeetingId) r.meetingNumber,
    ]);
  }

  /// Approves the current version: stores the record as approved with
  /// [hash] and keeps a snapshot of [minutes] and the record in the history.
  Future<OfficialRecord> approve({
    required OfficialRecord record,
    required Minutes minutes,
    required String hash,
    String entityName = '',
  }) => _db.transaction(() async {
    final at = _clock();
    final approved = record.copyWith(
      status: OfficialStatus.approved,
      approvedHash: hash,
      approvedAt: at,
    );
    await _write(approved, entityName);
    await _db
        .into(_db.minutesVersions)
        .insertOnConflictUpdate(
          MinutesVersionsCompanion.insert(
            meetingId: record.meetingId,
            version: record.version,
            minutesJson: jsonEncode(minutes.toJson()),
            recordJson: approved.encode(),
            contentHash: hash,
            approvedAt: at,
          ),
        );
    return approved;
  });

  /// Unlocks approved minutes as a new draft version (the approved one
  /// stays in the history with its signatures). No-op when not approved.
  Future<OfficialRecord?> startNewVersion(
    String meetingId, {
    String entityName = '',
  }) => _db.transaction(() async {
    final current = await get(meetingId);
    if (current == null || !current.isLocked) return current;
    final next = current.copyWith(
      version: current.version + 1,
      status: OfficialStatus.draft,
      clearApproval: true,
    );
    await _write(next, entityName);
    return next;
  });

  static MinutesVersion? _versionFromRow(MinutesVersionRow r) {
    try {
      final m = jsonDecode(r.minutesJson);
      if (m is! Map) return null;
      return MinutesVersion(
        meetingId: r.meetingId,
        version: r.version,
        minutes: Minutes.fromJson(m.cast<String, dynamic>()),
        record: OfficialRecord.fromJson(r.meetingId, jsonDecode(r.recordJson)),
        contentHash: r.contentHash,
        approvedAt: r.approvedAt,
      );
    } on FormatException {
      return null;
    }
  }

  /// Approved versions of [meetingId], newest first.
  Future<List<MinutesVersion>> versions(String meetingId) async {
    final rows =
        await (_db.select(_db.minutesVersions)
              ..where((t) => t.meetingId.equals(meetingId))
              ..orderBy([(t) => OrderingTerm.desc(t.version)]))
            .get();
    return [for (final r in rows) ?_versionFromRow(r)];
  }

  /// Watches [versions].
  Stream<List<MinutesVersion>> watchVersions(String meetingId) =>
      (_db.select(_db.minutesVersions)
            ..where((t) => t.meetingId.equals(meetingId))
            ..orderBy([(t) => OrderingTerm.desc(t.version)]))
          .watch()
          .map((rows) => [for (final r in rows) ?_versionFromRow(r)]);

  static MinutesSignature _sigFromRow(MinutesSignatureRow r) {
    final parsed = MinutesSignature.parseStrokes(r.strokesJson);
    return MinutesSignature(
      id: r.id,
      meetingId: r.meetingId,
      version: r.version,
      signerName: r.signerName,
      signerRole: r.signerRole,
      strokes: parsed.strokes,
      aspectRatio: parsed.aspect,
      signedAt: r.signedAt,
      contentHash: r.contentHash,
    );
  }

  /// Stores [s], replacing an earlier signature of the same signer for the
  /// same version. Signatures are only accepted on approved minutes, for
  /// the approved version and hash.
  Future<MinutesSignature> addSignature(MinutesSignature s) =>
      _db.transaction(() async {
        final rec = await get(s.meetingId);
        if (rec == null ||
            !rec.isLocked ||
            rec.version != s.version ||
            rec.approvedHash != s.contentHash) {
          throw StateError('signatures need the approved version');
        }
        final existing = await signatures(s.meetingId, version: s.version);
        for (final e in existing) {
          if (nameKey(e.signerName) == nameKey(s.signerName)) {
            await (_db.delete(
              _db.minutesSignatures,
            )..where((t) => t.id.equals(e.id!))).go();
          }
        }
        final id = await _db
            .into(_db.minutesSignatures)
            .insert(
              MinutesSignaturesCompanion.insert(
                meetingId: s.meetingId,
                version: s.version,
                signerName: s.signerName.trim(),
                signerRole: Value(s.signerRole),
                strokesJson: s.strokesJson(),
                contentHash: s.contentHash,
                signedAt: s.signedAt,
              ),
            );
        return MinutesSignature(
          id: id,
          meetingId: s.meetingId,
          version: s.version,
          signerName: s.signerName.trim(),
          signerRole: s.signerRole,
          strokes: s.strokes,
          aspectRatio: s.aspectRatio,
          signedAt: s.signedAt,
          contentHash: s.contentHash,
        );
      });

  /// Deletes signature [id].
  Future<void> deleteSignature(int id) =>
      (_db.delete(_db.minutesSignatures)..where((t) => t.id.equals(id))).go();

  SimpleSelectStatement<$MinutesSignaturesTable, MinutesSignatureRow> _sigs(
    String meetingId,
    int? version,
  ) => _db.select(_db.minutesSignatures)
    ..where(
      (t) =>
          t.meetingId.equals(meetingId) &
          (version == null ? const Constant(true) : t.version.equals(version)),
    )
    ..orderBy([(t) => OrderingTerm.asc(t.id)]);

  /// Signatures of [meetingId] (of [version] when given), oldest first.
  Future<List<MinutesSignature>> signatures(
    String meetingId, {
    int? version,
  }) async => [
    for (final r in await _sigs(meetingId, version).get()) _sigFromRow(r),
  ];

  /// Watches [signatures].
  Stream<List<MinutesSignature>> watchSignatures(
    String meetingId, {
    int? version,
  }) => _sigs(
    meetingId,
    version,
  ).watch().map((rows) => [for (final r in rows) _sigFromRow(r)]);
}

/// The entity profile and uploaded templates, stored as JSON in the
/// settings table.
class OfficialSettingsStore {
  /// Creates the store over [_db].
  OfficialSettingsStore(this._db);

  final AppDatabase _db;

  /// Settings key of the entity profile.
  static const String kProfile = 'official_entity_profile';

  /// Settings key of the uploaded templates list.
  static const String kTemplates = 'official_custom_templates';

  Future<String?> _read(String key) async => (await (_db.select(
    _db.settings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Stream<String?> _watch(String key) => (_db.select(
    _db.settings,
  )..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value);

  Future<void> _write(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  static Object? _decode(String? s) {
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  static List<CustomTemplate> _templates(String? s) {
    final d = _decode(s);
    return d is List ? [for (final e in d) ?CustomTemplate.fromJson(e)] : [];
  }

  /// The entity profile.
  Future<EntityProfile> profile() async =>
      EntityProfile.fromJson(_decode(await _read(kProfile)));

  /// Watches the entity profile.
  Stream<EntityProfile> watchProfile() =>
      _watch(kProfile).map((s) => EntityProfile.fromJson(_decode(s)));

  /// Saves the entity profile.
  Future<void> saveProfile(EntityProfile p) =>
      _write(kProfile, jsonEncode(p.toJson()));

  /// Uploaded templates, in upload order.
  Future<List<CustomTemplate>> templates() async =>
      _templates(await _read(kTemplates));

  /// Watches the uploaded templates.
  Stream<List<CustomTemplate>> watchTemplates() =>
      _watch(kTemplates).map(_templates);

  /// Replaces the uploaded templates list.
  Future<void> saveTemplates(List<CustomTemplate> list) =>
      _write(kTemplates, jsonEncode([for (final t in list) t.toJson()]));
}

/// [OfficialMinutesRepository] over the app database.
final officialMinutesRepositoryProvider = Provider<OfficialMinutesRepository>(
  (ref) => OfficialMinutesRepository(ref.watch(databaseProvider)),
);

/// [OfficialSettingsStore] over the app database.
final officialSettingsStoreProvider = Provider<OfficialSettingsStore>(
  (ref) => OfficialSettingsStore(ref.watch(databaseProvider)),
);

/// The official record of a meeting.
final officialRecordProvider = StreamProvider.autoDispose
    .family<OfficialRecord?, String>(
      (ref, id) => ref.watch(officialMinutesRepositoryProvider).watch(id),
    );

/// Approved versions of a meeting, newest first.
final minutesVersionsProvider = StreamProvider.autoDispose
    .family<List<MinutesVersion>, String>(
      (ref, id) =>
          ref.watch(officialMinutesRepositoryProvider).watchVersions(id),
    );

/// All signatures of a meeting.
final minutesSignaturesProvider = StreamProvider.autoDispose
    .family<List<MinutesSignature>, String>(
      (ref, id) =>
          ref.watch(officialMinutesRepositoryProvider).watchSignatures(id),
    );

/// The entity profile.
final entityProfileProvider = StreamProvider<EntityProfile>(
  (ref) => ref.watch(officialSettingsStoreProvider).watchProfile(),
);

/// The uploaded Word templates.
final customTemplatesProvider = StreamProvider<List<CustomTemplate>>(
  (ref) => ref.watch(officialSettingsStoreProvider).watchTemplates(),
);
