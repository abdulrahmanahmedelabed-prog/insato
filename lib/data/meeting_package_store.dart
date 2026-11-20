// Undo snapshots of meeting-package merges («حزمة الاجتماع»).
//
// Before a package is merged into a meeting, everything the merge (and the
// speaker refinement that follows it) may change is captured: the
// meeting's duration / recording / minutes / status, every field of its
// segments except the embeddings, the voice library (voiceprints may be
// learned, speakers created or removed), the meeting's voiceprint ledger
// and the segment-index references of its tasks, pending task updates,
// code findings, speaker notes and official record (the merge renumbers
// segments chronologically and rewrites those references).
//
// Snapshots are a stack per meeting in the settings table
// (`meeting_package_undo:<meeting id>`, JSON list, newest last).
// `MeetingRepository.delete` calls [MeetingPackageStore.deleteForMeeting],
// which also removes the pre-merge recordings the snapshots keep.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import 'database.dart';
import 'repositories.dart' show kVoiceprintLedgerKeyPrefix;

/// Settings key prefix of the undo stacks.
const String kMeetingPackageUndoKeyPrefix = 'meeting_package_undo:';

/// Most snapshots kept per meeting (older ones are dropped with their
/// pre-merge recording).
const int kMaxMergeSnapshots = 5;

/// One segment as it was before a merge.
class SnapshotSegment {
  /// Creates the entry.
  const SnapshotSegment({
    required this.id,
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.speakerId,
    required this.language,
    required this.speakerLocked,
    required this.kind,
    required this.asrConfidence,
    required this.speakerConfidence,
  });

  /// From a row.
  factory SnapshotSegment.ofRow(SegmentRow r) => SnapshotSegment(
    id: r.id,
    index: r.idx,
    startMs: r.startMs,
    endMs: r.endMs,
    text: r.body,
    speakerId: r.speakerId,
    language: r.language,
    speakerLocked: r.speakerLocked,
    kind: r.kind,
    asrConfidence: r.asrConfidence,
    speakerConfidence: r.speakerConfidence,
  );

  /// Segment id.
  final String id;

  /// Index.
  final int index;

  /// Start.
  final int startMs;

  /// End.
  final int endMs;

  /// Text.
  final String text;

  /// Speaker.
  final String? speakerId;

  /// Language.
  final String? language;

  /// Locked by the user.
  final bool speakerLocked;

  /// Kind (wire).
  final String kind;

  /// ASR confidence.
  final double? asrConfidence;

  /// Speaker confidence.
  final double? speakerConfidence;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'idx': index,
    'start': startMs,
    'end': endMs,
    'text': text,
    'speaker': speakerId,
    'language': language,
    'locked': speakerLocked,
    'kind': kind,
    'asr': asrConfidence,
    'spk': speakerConfidence,
  };

  /// Parses [toJson] output.
  static SnapshotSegment fromJson(Map<String, Object?> j) => SnapshotSegment(
    id: j['id'] as String,
    index: j['idx'] as int,
    startMs: j['start'] as int,
    endMs: j['end'] as int,
    text: j['text'] as String,
    speakerId: j['speaker'] as String?,
    language: j['language'] as String?,
    speakerLocked: j['locked'] == true,
    kind: j['kind'] as String,
    asrConfidence: (j['asr'] as num?)?.toDouble(),
    speakerConfidence: (j['spk'] as num?)?.toDouble(),
  );
}

/// The state of a meeting before a merge.
class MergeSnapshot {
  /// Creates a snapshot.
  const MergeSnapshot({
    required this.meetingId,
    required this.takenAt,
    required this.deviceName,
    required this.durationMs,
    required this.audioPath,
    required this.minutesJson,
    required this.status,
    required this.segments,
    required this.speakers,
    required this.ledger,
    required this.taskEvidence,
    required this.updateEvidence,
    required this.codeFindings,
    required this.speakerNotes,
    required this.officialRecord,
    this.insertedSegmentIds = const [],
    this.mergedAudioPath,
  });

  /// Meeting.
  final String meetingId;

  /// When the merge happened.
  final DateTime takenAt;

  /// Device the merged package came from.
  final String deviceName;

  /// Meeting duration before.
  final int durationMs;

  /// Stored recording file name before (kept on disk until the snapshot
  /// is dropped).
  final String? audioPath;

  /// Minutes JSON before.
  final String? minutesJson;

  /// Status before.
  final String status;

  /// Segments before.
  final List<SnapshotSegment> segments;

  /// Speakers rows before (JSON, see [_speakerJson]).
  final List<Map<String, Object?>> speakers;

  /// Voiceprint ledger value before.
  final String? ledger;

  /// Task id → evidence JSON.
  final Map<int, String> taskEvidence;

  /// Pending update id → evidence JSON.
  final Map<int, String> updateEvidence;

  /// Code finding id → (segment ids JSON, payload JSON).
  final Map<int, (String, String)> codeFindings;

  /// Speaker id → notes JSON.
  final Map<String, String> speakerNotes;

  /// Official record JSON.
  final String? officialRecord;

  /// Segments the merge inserted.
  final List<String> insertedSegmentIds;

  /// Recording file the merge wrote (null when the recording was kept).
  final String? mergedAudioPath;

  /// Copy recording what the merge did.
  MergeSnapshot completed({
    required List<String> insertedSegmentIds,
    String? mergedAudioPath,
  }) => MergeSnapshot(
    meetingId: meetingId,
    takenAt: takenAt,
    deviceName: deviceName,
    durationMs: durationMs,
    audioPath: audioPath,
    minutesJson: minutesJson,
    status: status,
    segments: segments,
    speakers: speakers,
    ledger: ledger,
    taskEvidence: taskEvidence,
    updateEvidence: updateEvidence,
    codeFindings: codeFindings,
    speakerNotes: speakerNotes,
    officialRecord: officialRecord,
    insertedSegmentIds: insertedSegmentIds,
    mergedAudioPath: mergedAudioPath,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'v': 1,
    'meeting': meetingId,
    'taken_at': takenAt.millisecondsSinceEpoch,
    'device': deviceName,
    'duration': durationMs,
    'audio': audioPath,
    'minutes': minutesJson,
    'status': status,
    'segments': [for (final s in segments) s.toJson()],
    'speakers': speakers,
    'ledger': ledger,
    'tasks': {for (final e in taskEvidence.entries) '${e.key}': e.value},
    'updates': {for (final e in updateEvidence.entries) '${e.key}': e.value},
    'codes': {
      for (final e in codeFindings.entries)
        '${e.key}': [e.value.$1, e.value.$2],
    },
    'notes': speakerNotes,
    'official': officialRecord,
    'inserted': insertedSegmentIds,
    'merged_audio': mergedAudioPath,
  };

  /// Parses [toJson] output; null when malformed.
  static MergeSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final j = raw.cast<String, Object?>();
      Map<int, String> intMap(Object? v) => {
        for (final e in (v as Map).entries)
          int.parse(e.key as String): e.value as String,
      };
      return MergeSnapshot(
        meetingId: j['meeting'] as String,
        takenAt: DateTime.fromMillisecondsSinceEpoch(j['taken_at'] as int),
        deviceName: j['device'] as String? ?? '',
        durationMs: j['duration'] as int,
        audioPath: j['audio'] as String?,
        minutesJson: j['minutes'] as String?,
        status: j['status'] as String,
        segments: [
          for (final s in j['segments'] as List)
            SnapshotSegment.fromJson((s as Map).cast<String, Object?>()),
        ],
        speakers: [
          for (final s in j['speakers'] as List)
            (s as Map).cast<String, Object?>(),
        ],
        ledger: j['ledger'] as String?,
        taskEvidence: intMap(j['tasks']),
        updateEvidence: intMap(j['updates']),
        codeFindings: {
          for (final e in (j['codes'] as Map).entries)
            int.parse(e.key as String): (
              (e.value as List)[0] as String,
              (e.value as List)[1] as String,
            ),
        },
        speakerNotes: (j['notes'] as Map).cast<String, String>(),
        officialRecord: j['official'] as String?,
        insertedSegmentIds: [
          for (final s in (j['inserted'] as List? ?? const [])) s as String,
        ],
        mergedAudioPath: j['merged_audio'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

Map<String, Object?> _speakerJson(SpeakerRow r) => {
  'id': r.id,
  'name': r.name,
  'color': r.color,
  'named': r.isNamedByUser,
  'created': r.createdAt.millisecondsSinceEpoch,
  'centroid': r.centroid == null ? null : base64Encode(r.centroid!),
  'count': r.embeddingCount,
  'profile': r.profileEnabled,
  'device': r.voiceDevice,
  'low': r.lowConfidence,
};

/// Captures, stores and restores [MergeSnapshot]s.
class MeetingPackageStore {
  /// Creates the store over [db].
  MeetingPackageStore(this._db);

  final AppDatabase _db;

  static String _key(String meetingId) =>
      '$kMeetingPackageUndoKeyPrefix$meetingId';

  /// Settings key of the "include the recording" export preference.
  static const String includeAudioKey = 'meeting_package.include_audio';

  /// Whether exports include the recording (default true). Voiceprints are
  /// deliberately not remembered: they are opted in on every export.
  Future<bool> includeAudioPreference() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(includeAudioKey))).getSingleOrNull();
    return row?.value != 'false';
  }

  /// Remembers [include] for the next export.
  Future<void> setIncludeAudioPreference(bool include) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: includeAudioKey, value: '$include'),
      );

  /// Captures the current state of [meetingId] (call before merging).
  Future<MergeSnapshot> capture(
    String meetingId, {
    required String deviceName,
  }) => _db.transaction(() async {
    final m = await (_db.select(
      _db.meetings,
    )..where((t) => t.id.equals(meetingId))).getSingle();
    final segs =
        await (_db.select(_db.segments)
              ..where((s) => s.meetingId.equals(meetingId))
              ..orderBy([(s) => OrderingTerm.asc(s.idx)]))
            .get();
    final speakers = await _db.select(_db.speakers).get();
    final ledger =
        await (_db.select(_db.settings)..where(
              (s) => s.key.equals('$kVoiceprintLedgerKeyPrefix$meetingId'),
            ))
            .getSingleOrNull();
    final tasks = await (_db.select(
      _db.tasks,
    )..where((t) => t.sourceMeetingId.equals(meetingId))).get();
    final updates = await (_db.select(
      _db.taskUpdatesPending,
    )..where((t) => t.meetingId.equals(meetingId))).get();
    final codes = await (_db.select(
      _db.codeFindings,
    )..where((t) => t.meetingId.equals(meetingId))).get();
    final notes = await (_db.select(
      _db.speakerMeetingNotes,
    )..where((t) => t.meetingId.equals(meetingId))).get();
    final official = await (_db.select(
      _db.officialRecords,
    )..where((t) => t.meetingId.equals(meetingId))).getSingleOrNull();
    return MergeSnapshot(
      meetingId: meetingId,
      takenAt: DateTime.now(),
      deviceName: deviceName,
      durationMs: m.durationMs,
      audioPath: m.audioPath,
      minutesJson: m.minutesJson,
      status: m.status,
      segments: [for (final s in segs) SnapshotSegment.ofRow(s)],
      speakers: [for (final s in speakers) _speakerJson(s)],
      ledger: ledger?.value,
      taskEvidence: {for (final t in tasks) t.id: t.evidenceSegmentIds},
      updateEvidence: {for (final u in updates) u.id: u.evidenceJson},
      codeFindings: {
        for (final c in codes) c.id: (c.segmentIdsJson, c.payloadJson),
      },
      speakerNotes: {for (final n in notes) n.speakerId: n.notesJson},
      officialRecord: official?.recordJson,
    );
  });

  /// The undo stack of [meetingId], oldest first.
  Future<List<MergeSnapshot>> stack(String meetingId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(_key(meetingId)))).getSingleOrNull();
    return _decode(row?.value);
  }

  static List<MergeSnapshot> _decode(String? json) {
    if (json == null) return const [];
    try {
      final v = jsonDecode(json);
      if (v is! List) return const [];
      return [for (final s in v) ?MergeSnapshot.fromJson(s)];
    } on FormatException {
      return const [];
    }
  }

  /// Whether [meetingId] has a merge to undo, re-emitted on change.
  Stream<MergeSnapshot?> watchLatest(String meetingId) =>
      (_db.select(_db.settings)..where((s) => s.key.equals(_key(meetingId))))
          .watchSingleOrNull()
          .map((r) {
            final list = _decode(r?.value);
            return list.isEmpty ? null : list.last;
          });

  /// Pushes [snapshot]. Returns the snapshots dropped to stay within
  /// [kMaxMergeSnapshots] (their pre-merge recordings can be deleted).
  Future<List<MergeSnapshot>> push(MergeSnapshot snapshot) =>
      _db.transaction(() async {
        final list = [...await stack(snapshot.meetingId), snapshot];
        final dropped = <MergeSnapshot>[];
        while (list.length > kMaxMergeSnapshots) {
          dropped.add(list.removeAt(0));
        }
        await _write(snapshot.meetingId, list);
        return dropped;
      });

  Future<void> _write(String meetingId, List<MergeSnapshot> list) async {
    if (list.isEmpty) {
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(_key(meetingId)))).go();
      return;
    }
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: _key(meetingId),
            value: jsonEncode([for (final s in list) s.toJson()]),
          ),
        );
  }

  /// Restores the latest snapshot of [meetingId] and pops it. Returns it
  /// (null when there is nothing to undo).
  ///
  /// Voiceprints and deleted speakers come back as they were before the
  /// merge; names and colours the user changed since are kept. Speakers
  /// that only the merge created are deleted once they have no segments.
  Future<MergeSnapshot?> restoreLatest(String meetingId) =>
      _db.transaction(() async {
        final list = [...await stack(meetingId)];
        if (list.isEmpty) return null;
        final snap = list.removeLast();
        await _restore(snap);
        await _write(meetingId, list);
        return snap;
      });

  Future<void> _restore(MergeSnapshot snap) async {
    final id = snap.meetingId;
    // 1. Speakers that existed: bring back missing rows and voiceprints.
    final current = {
      for (final s in await _db.select(_db.speakers).get()) s.id: s,
    };
    final before = <String>{};
    for (final j in snap.speakers) {
      final sid = j['id'] as String;
      before.add(sid);
      final centroid = j['centroid'] == null
          ? null
          : base64Decode(j['centroid'] as String);
      final count = j['count'] as int? ?? 0;
      if (!current.containsKey(sid)) {
        await _db
            .into(_db.speakers)
            .insert(
              SpeakersCompanion.insert(
                id: sid,
                name: j['name'] as String,
                color: j['color'] as int,
                isNamedByUser: Value(j['named'] == true),
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  j['created'] as int,
                ),
                centroid: Value(centroid),
                embeddingCount: Value(count),
                profileEnabled: Value(j['profile'] == true),
                voiceDevice: Value(j['device'] as String?),
                lowConfidence: Value(j['low'] == true),
              ),
            );
      } else {
        await (_db.update(_db.speakers)..where((s) => s.id.equals(sid))).write(
          SpeakersCompanion(
            centroid: Value(centroid),
            embeddingCount: Value(count),
            voiceDevice: Value(j['device'] as String?),
            lowConfidence: Value(j['low'] == true),
          ),
        );
      }
    }
    // 2. Segments: remove the merged ones, restore the others.
    final keep = {for (final s in snap.segments) s.id};
    await (_db.delete(
      _db.segments,
    )..where((s) => s.meetingId.equals(id) & s.id.isNotIn(keep.toList()))).go();
    for (final s in snap.segments) {
      await (_db.update(_db.segments)..where((t) => t.id.equals(s.id))).write(
        SegmentsCompanion(
          idx: Value(s.index),
          startMs: Value(s.startMs),
          endMs: Value(s.endMs),
          body: Value(s.text),
          speakerId: Value(s.speakerId),
          language: Value(s.language),
          speakerLocked: Value(s.speakerLocked),
          kind: Value(s.kind),
          asrConfidence: Value(s.asrConfidence),
          speakerConfidence: Value(s.speakerConfidence),
        ),
      );
    }
    // 3. Speakers the merge created and nobody uses any more.
    final used = {
      for (final r
          in await _db
              .customSelect(
                'SELECT DISTINCT speaker_id AS sid FROM segments '
                'WHERE speaker_id IS NOT NULL',
                readsFrom: {_db.segments},
              )
              .get())
        r.read<String>('sid'),
    };
    for (final sp in current.keys) {
      if (before.contains(sp) || used.contains(sp)) continue;
      await (_db.delete(_db.speakers)..where((s) => s.id.equals(sp))).go();
    }
    // 4. Meeting fields and references.
    await (_db.update(_db.meetings)..where((m) => m.id.equals(id))).write(
      MeetingsCompanion(
        durationMs: Value(snap.durationMs),
        audioPath: Value(snap.audioPath),
        minutesJson: Value(snap.minutesJson),
        status: Value(snap.status),
      ),
    );
    final ledgerKey = '$kVoiceprintLedgerKeyPrefix$id';
    if (snap.ledger == null) {
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(ledgerKey))).go();
    } else {
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(key: ledgerKey, value: snap.ledger!),
          );
    }
    for (final e in snap.taskEvidence.entries) {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(e.key))).write(
        TasksCompanion(evidenceSegmentIds: Value(e.value)),
      );
    }
    for (final e in snap.updateEvidence.entries) {
      await (_db.update(_db.taskUpdatesPending)
            ..where((t) => t.id.equals(e.key)))
          .write(TaskUpdatesPendingCompanion(evidenceJson: Value(e.value)));
    }
    for (final e in snap.codeFindings.entries) {
      await (_db.update(
        _db.codeFindings,
      )..where((t) => t.id.equals(e.key))).write(
        CodeFindingsCompanion(
          segmentIdsJson: Value(e.value.$1),
          payloadJson: Value(e.value.$2),
        ),
      );
    }
    for (final e in snap.speakerNotes.entries) {
      await (_db.update(_db.speakerMeetingNotes)
            ..where((t) => t.meetingId.equals(id) & t.speakerId.equals(e.key)))
          .write(SpeakerMeetingNotesCompanion(notesJson: Value(e.value)));
    }
    if (snap.officialRecord != null) {
      await (_db.update(
        _db.officialRecords,
      )..where((t) => t.meetingId.equals(id))).write(
        OfficialRecordsCompanion(recordJson: Value(snap.officialRecord!)),
      );
    }
  }

  /// Rewrites the segment-index references of [meetingId] outside the
  /// minutes (tasks, pending task updates, code findings, speaker notes,
  /// official record) with [remapList] (a JSON list of ints) and
  /// [remapJson] (any JSON document).
  Future<void> rewriteReferences(
    String meetingId, {
    required String Function(String json) remapList,
    required String Function(String json) remapJson,
  }) => _db.transaction(() async {
    for (final t in await (_db.select(
      _db.tasks,
    )..where((t) => t.sourceMeetingId.equals(meetingId))).get()) {
      await (_db.update(_db.tasks)..where((r) => r.id.equals(t.id))).write(
        TasksCompanion(
          evidenceSegmentIds: Value(remapList(t.evidenceSegmentIds)),
        ),
      );
    }
    for (final u in await (_db.select(
      _db.taskUpdatesPending,
    )..where((t) => t.meetingId.equals(meetingId))).get()) {
      await (_db.update(
        _db.taskUpdatesPending,
      )..where((r) => r.id.equals(u.id))).write(
        TaskUpdatesPendingCompanion(
          evidenceJson: Value(remapList(u.evidenceJson)),
        ),
      );
    }
    for (final c in await (_db.select(
      _db.codeFindings,
    )..where((t) => t.meetingId.equals(meetingId))).get()) {
      await (_db.update(
        _db.codeFindings,
      )..where((r) => r.id.equals(c.id))).write(
        CodeFindingsCompanion(
          segmentIdsJson: Value(remapList(c.segmentIdsJson)),
          payloadJson: Value(remapJson(c.payloadJson)),
        ),
      );
    }
    for (final n in await (_db.select(
      _db.speakerMeetingNotes,
    )..where((t) => t.meetingId.equals(meetingId))).get()) {
      await (_db.update(_db.speakerMeetingNotes)..where(
            (r) =>
                r.meetingId.equals(meetingId) & r.speakerId.equals(n.speakerId),
          ))
          .write(
            SpeakerMeetingNotesCompanion(
              notesJson: Value(remapJson(n.notesJson)),
            ),
          );
    }
    final o = await (_db.select(
      _db.officialRecords,
    )..where((t) => t.meetingId.equals(meetingId))).getSingleOrNull();
    if (o != null) {
      await (_db.update(
        _db.officialRecords,
      )..where((r) => r.meetingId.equals(meetingId))).write(
        OfficialRecordsCompanion(recordJson: Value(remapJson(o.recordJson))),
      );
    }
  });

  /// Deletes the undo stack of a meeting being deleted and the recordings
  /// it kept (pre-merge recordings and earlier merged ones; the meeting's
  /// current recording is deleted by the caller). [recordingsDir] resolves
  /// stored file names. Never throws.
  static Future<void> deleteForMeeting(
    AppDatabase db,
    String meetingId, {
    String? currentAudioPath,
    Future<String> Function()? recordingsDir,
  }) async {
    try {
      final store = MeetingPackageStore(db);
      final list = await store.stack(meetingId);
      await store._write(meetingId, const []);
      await deleteSnapshotFiles(
        list,
        keep: {?currentAudioPath},
        recordingsDir: recordingsDir,
      );
    } catch (_) {
      // Best effort: the meeting itself is already deleted.
    }
  }

  /// Deletes the recordings referenced by [snapshots] except [keep]
  /// (stored names). Never throws.
  static Future<void> deleteSnapshotFiles(
    List<MergeSnapshot> snapshots, {
    Set<String> keep = const {},
    Future<String> Function()? recordingsDir,
  }) async {
    final names = <String>{
      for (final s in snapshots) ...{?s.audioPath, ?s.mergedAudioPath},
    }..removeAll(keep);
    if (names.isEmpty) return;
    String? dir;
    try {
      dir = recordingsDir == null ? null : await recordingsDir();
    } catch (_) {
      dir = null;
    }
    for (final n in names) {
      final path = p.isAbsolute(n) ? n : (dir == null ? null : p.join(dir, n));
      if (path == null) continue;
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Best effort.
      }
    }
  }
}
