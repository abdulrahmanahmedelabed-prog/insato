// Storage of the consistency checker (v1.2, D): findings per meeting and
// the «أُلغي رسمياً» annotations of earlier resolutions (schema v6).

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/consistency/consistency_models.dart';
import 'database.dart';
import 'repositories.dart' show databaseProvider;

/// Findings and resolution annotations.
class ConsistencyRepository {
  /// Creates the repository over [_db].
  ConsistencyRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static ConsistencyFinding _fromRow(ConsistencyFindingRow r) =>
      ConsistencyFinding(
        id: r.id,
        meetingId: r.meetingId,
        kind: FindingKind.tryParse(r.kind) ?? FindingKind.contradictsResolution,
        severity: FindingSeverity.parse(r.severity),
        status: FindingStatus.parse(r.status),
        origin: FindingOrigin.parse(r.origin),
        explanation: r.explanation,
        newSide: FindingSide.decode(r.newSideJson),
        priorSide: FindingSide.decode(r.priorSideJson),
        createdAt: r.createdAt,
        resolvedAt: r.resolvedAt,
      );

  SimpleSelectStatement<$ConsistencyFindingsTable, ConsistencyFindingRow>
  _forMeeting(String meetingId) => _db.select(_db.consistencyFindings)
    ..where((f) => f.meetingId.equals(meetingId))
    ..orderBy([(f) => OrderingTerm.asc(f.id)]);

  /// Findings of [meetingId] (insertion order).
  Future<List<ConsistencyFinding>> forMeeting(String meetingId) async => [
    for (final r in await _forMeeting(meetingId).get()) _fromRow(r),
  ];

  /// Watches the findings of [meetingId].
  Stream<List<ConsistencyFinding>> watchForMeeting(String meetingId) =>
      _forMeeting(meetingId)
          .watch()
          .map((rows) => [for (final r in rows) _fromRow(r)]);

  /// One finding, or null.
  Future<ConsistencyFinding?> get(int id) async {
    final row = await (_db.select(
      _db.consistencyFindings,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Replaces the open findings of [meetingId] with [findings]. Findings
  /// the user already dismissed or confirmed are kept, and a new finding
  /// with the same key as one of them is not added again (a re-check does
  /// not undo the user's decisions). Returns the stored open findings.
  Future<List<ConsistencyFinding>> replaceOpen(
    String meetingId,
    List<ConsistencyFinding> findings,
  ) => _db.transaction(() async {
    final existing = await forMeeting(meetingId);
    final handled = {
      for (final f in existing)
        if (f.status != FindingStatus.open) f.key,
    };
    await (_db.delete(_db.consistencyFindings)..where(
          (f) =>
              f.meetingId.equals(meetingId) &
              f.status.equals(FindingStatus.open.wire),
        ))
        .go();
    final now = _clock();
    final out = <ConsistencyFinding>[];
    final added = <String>{};
    for (final f in findings) {
      final key = f.key;
      if (handled.contains(key) || !added.add(key)) continue;
      final id = await _db
          .into(_db.consistencyFindings)
          .insert(
            ConsistencyFindingsCompanion.insert(
              meetingId: meetingId,
              kind: f.kind.wire,
              severity: f.severity.wire,
              status: Value(FindingStatus.open.wire),
              origin: Value(f.origin.name),
              findingKey: key,
              explanation: Value(f.explanation),
              newSideJson: f.newSide.encode(),
              priorSideJson: f.priorSide.encode(),
              priorMeetingId: Value(
                await _existingMeeting(f.priorSide.meetingId),
              ),
              createdAt: now,
            ),
          );
      out.add(f.copyWith(id: id));
    }
    return out;
  });

  Future<String?> _existingMeeting(String? id) async {
    if (id == null) return null;
    final row = await (_db.select(
      _db.meetings,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    return row?.id;
  }

  /// Sets the status of finding [id]. Returns false when it does not exist.
  Future<bool> setStatus(int id, FindingStatus status) async =>
      await (_db.update(
        _db.consistencyFindings,
      )..where((f) => f.id.equals(id))).write(
        ConsistencyFindingsCompanion(
          status: Value(status.wire),
          resolvedAt: Value(status == FindingStatus.open ? null : _clock()),
        ),
      ) >
      0;

  /// Confirms finding [finding] and, when [annotate] is given, adds the
  /// annotation of the earlier resolution — in one transaction.
  Future<void> confirm(
    ConsistencyFinding finding, {
    ResolutionAnnotation? annotate,
  }) => _db.transaction(() async {
    await setStatus(finding.id!, FindingStatus.confirmed);
    if (annotate != null) {
      await (_db.delete(
        _db.resolutionAnnotations,
      )..where((a) => a.findingId.equals(finding.id!))).go();
      await _db
          .into(_db.resolutionAnnotations)
          .insert(
            ResolutionAnnotationsCompanion.insert(
              meetingId: annotate.meetingId,
              decisionIndex: annotate.decisionIndex,
              decisionKey: annotate.decisionKey,
              byMeetingId: annotate.byMeetingId,
              findingId: finding.id!,
              bySideJson: annotate.bySide.encode(),
              createdAt: annotate.createdAt,
            ),
          );
    }
  });

  /// Re-opens finding [id] and removes its annotation.
  Future<void> reopen(int id) => _db.transaction(() async {
    await setStatus(id, FindingStatus.open);
    await (_db.delete(
      _db.resolutionAnnotations,
    )..where((a) => a.findingId.equals(id))).go();
  });

  static ResolutionAnnotation _annotationFromRow(ResolutionAnnotationRow r) =>
      ResolutionAnnotation(
        id: r.id,
        meetingId: r.meetingId,
        decisionIndex: r.decisionIndex,
        decisionKey: r.decisionKey,
        byMeetingId: r.byMeetingId,
        findingId: r.findingId,
        bySide: FindingSide.decode(r.bySideJson),
        createdAt: r.createdAt,
      );

  SimpleSelectStatement<$ResolutionAnnotationsTable, ResolutionAnnotationRow>
  _annotations(String meetingId) => _db.select(_db.resolutionAnnotations)
    ..where((a) => a.meetingId.equals(meetingId))
    ..orderBy([(a) => OrderingTerm.asc(a.decisionIndex)]);

  /// Annotations of the resolutions of [meetingId].
  Future<List<ResolutionAnnotation>> annotations(String meetingId) async => [
    for (final r in await _annotations(meetingId).get()) _annotationFromRow(r),
  ];

  /// Watches the annotations of [meetingId].
  Stream<List<ResolutionAnnotation>> watchAnnotations(String meetingId) =>
      _annotations(meetingId)
          .watch()
          .map((rows) => [for (final r in rows) _annotationFromRow(r)]);

  /// Every annotation (meeting id → decision keys superseded).
  Future<Map<String, Set<String>>> supersededKeys() async {
    final out = <String, Set<String>>{};
    for (final r in await _db.select(_db.resolutionAnnotations).get()) {
      (out[r.meetingId] ??= {}).add(r.decisionKey);
    }
    return out;
  }

  /// Number of open findings per meeting.
  Stream<int> watchOpenCount(String meetingId) =>
      (_db.select(_db.consistencyFindings)..where(
            (f) =>
                f.meetingId.equals(meetingId) &
                f.status.equals(FindingStatus.open.wire),
          ))
          .watch()
          .map((rows) => rows.length);
}

/// [ConsistencyRepository] over the app database.
final consistencyRepositoryProvider = Provider<ConsistencyRepository>(
  (ref) => ConsistencyRepository(ref.watch(databaseProvider)),
);

/// The findings of a meeting.
final consistencyFindingsProvider = StreamProvider.autoDispose
    .family<List<ConsistencyFinding>, String>(
      (ref, id) => ref.watch(consistencyRepositoryProvider).watchForMeeting(id),
    );

/// Number of open findings of a meeting (tab badge).
final openFindingsCountProvider = StreamProvider.autoDispose
    .family<int, String>(
      (ref, id) => ref.watch(consistencyRepositoryProvider).watchOpenCount(id),
    );

/// The annotations of a meeting's resolutions.
final resolutionAnnotationsProvider = StreamProvider.autoDispose
    .family<List<ResolutionAnnotation>, String>(
      (ref, id) =>
          ref.watch(consistencyRepositoryProvider).watchAnnotations(id),
    );

/// Settings of the checker (settings table).
class ConsistencySettingsStore {
  /// Creates the store over [_db].
  ConsistencySettingsStore(this._db);

  final AppDatabase _db;

  /// Settings key of the live mode (off by default).
  static const String kLiveMode = 'consistency_live_mode';

  /// Whether the live check during recording is on.
  Future<bool> liveMode() async =>
      (await (_db.select(
        _db.settings,
      )..where((t) => t.key.equals(kLiveMode))).getSingleOrNull())?.value ==
      'true';

  /// Watches [liveMode].
  Stream<bool> watchLiveMode() =>
      (_db.select(_db.settings)..where((t) => t.key.equals(kLiveMode)))
          .watchSingleOrNull()
          .map((r) => r?.value == 'true');

  /// Turns the live check on or off.
  Future<void> setLiveMode(bool on) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: kLiveMode, value: on.toString()),
      );
}

/// [ConsistencySettingsStore] over the app database.
final consistencySettingsStoreProvider = Provider<ConsistencySettingsStore>(
  (ref) => ConsistencySettingsStore(ref.watch(databaseProvider)),
);

/// Whether the live check during recording is on (off by default).
final consistencyLiveModeProvider = StreamProvider<bool>(
  (ref) => ref.watch(consistencySettingsStoreProvider).watchLiveMode(),
);
