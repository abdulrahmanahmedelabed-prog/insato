// Repositories: the only place where drift rows are converted to and from the
// pure domain models of `core/models.dart`.
//
// All methods are safe to call concurrently from the main isolate; operations
// that read-then-write run inside a drift transaction.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import 'database.dart';

const Uuid _uuid = Uuid();

/// Prefix of automatically generated speaker names (`متحدث 1`, `متحدث 2`, …).
const String kAutoSpeakerPrefix = 'متحدث';

/// Upper bound for [Speaker.embeddingCount] after a merge, so voiceprints can
/// still drift slowly with new evidence (see docs/ARCHITECTURE.md).
const int kMaxVoiceprintEmbeddingCount = 200;

/// Fixed palette of pleasant, mutually distinct ARGB colors for speakers.
///
/// New speakers get the least-used palette color (ties resolved in palette
/// order), so the first twelve speakers always have distinct colors.
const List<int> kSpeakerPalette = [
  0xFF1565C0, // blue
  0xFF2E7D32, // green
  0xFFEF6C00, // orange
  0xFF6A1B9A, // purple
  0xFF00838F, // cyan
  0xFFC62828, // red
  0xFF4E342E, // brown
  0xFFAD1457, // pink
  0xFF283593, // indigo
  0xFF827717, // olive
  0xFF00695C, // teal
  0xFF37474F, // blue grey
];

final RegExp _autoNamePattern =
    RegExp('^$kAutoSpeakerPrefix\\s+([0-9٠-٩۰-۹]+)\$');

/// Returns N if [name] is an auto speaker name like `متحدث N` (Latin,
/// Arabic-Indic or Extended Arabic-Indic digits), otherwise null.
int? parseAutoSpeakerNumber(String name) {
  final m = _autoNamePattern.firstMatch(name.trim());
  if (m == null) return null;
  final digits = m.group(1)!.runes.map((r) {
    if (r >= 0x0660 && r <= 0x0669) return r - 0x0660;
    if (r >= 0x06F0 && r <= 0x06F9) return r - 0x06F0;
    return r - 0x30;
  });
  var n = 0;
  for (final d in digits) {
    n = n * 10 + d;
  }
  return n;
}

/// Formats the auto speaker name for [n], e.g. `متحدث 3`.
String autoSpeakerName(int n) => '$kAutoSpeakerPrefix $n';

/// Smallest positive N such that `متحدث N` is not among [existingNames].
int nextAutoSpeakerNumber(Iterable<String> existingNames) {
  final used = <int>{
    for (final name in existingNames) ?parseAutoSpeakerNumber(name),
  };
  var n = 1;
  while (used.contains(n)) {
    n++;
  }
  return n;
}

/// Picks the least-used color of [kSpeakerPalette] given the colors already
/// assigned; ties go to the earliest palette entry.
int pickSpeakerColor(Iterable<int> usedColors) {
  final counts = <int, int>{for (final c in kSpeakerPalette) c: 0};
  for (final c in usedColors) {
    if (counts.containsKey(c)) counts[c] = counts[c]! + 1;
  }
  var best = kSpeakerPalette.first;
  var bestCount = counts[best]!;
  for (final c in kSpeakerPalette) {
    if (counts[c]! < bestCount) {
      best = c;
      bestCount = counts[c]!;
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Voiceprint ledgers
// ---------------------------------------------------------------------------
//
// The post-processor keeps, per meeting, a ledger `segment id → speaker id`
// in the `settings` table (key [kVoiceprintLedgerKeyPrefix] + meeting id,
// JSON object value) recording which voiceprint each segment's embedding was
// learned into. When a voiceprint stops containing those embeddings (forget,
// or a merge that drops one side's centroid) the entries are turned into
// *tombstones*: [voiceprintLedgerTombstone] of the speaker id. A tombstone
// means "assigned to that speaker, but not contributing to any voiceprint":
// nothing is unlearned when the segment moves away, and nothing is learned
// again while it stays with that speaker.

/// Settings-table key prefix of the per-meeting voiceprint ledgers (same
/// value as the post-processor's `kVoiceprintLedgerPrefix`).
const String kVoiceprintLedgerKeyPrefix = 'voiceprint_ledger:';

/// Settings key prefix of a multi-device meeting's log (v1.2 C,
/// `lib/features/multi_device/meeting_log.dart`), deleted with the meeting.
const String kMultiDeviceLogKeyPrefix = 'multi_device_log:';

/// Prefix of a ledger tombstone value. Never starts a real (UUID) speaker id.
const String kVoiceprintLedgerTombstonePrefix = '!';

/// The ledger value recording that a segment belongs to [speakerId] without
/// contributing to its voiceprint.
String voiceprintLedgerTombstone(String speakerId) =>
    '$kVoiceprintLedgerTombstonePrefix$speakerId';

/// The speaker id of a tombstone ledger [value], or null for a live entry.
String? voiceprintLedgerTombstoneSpeaker(String value) =>
    value.startsWith(kVoiceprintLedgerTombstonePrefix)
        ? value.substring(kVoiceprintLedgerTombstonePrefix.length)
        : null;

Map<String, String> _decodeLedger(String json) {
  try {
    final v = jsonDecode(json);
    if (v is! Map) return {};
    return {
      for (final e in v.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  } on FormatException {
    return {};
  }
}

/// Whether [a] keeps its own centroid in `combineVoiceprints(a, na, b, nb)`
/// (i.e. the embeddings learned into [a] are still in the result).
bool _survivesCombine(Float32List? a, int countA, Float32List? b, int countB) {
  final hasA = a != null && a.isNotEmpty;
  final hasB = b != null && b.isNotEmpty;
  if (!hasA) return false;
  if (!hasB || a.length == b.length) return true;
  return math.max(countA, 1) >= math.max(countB, 1);
}

/// Combines two voiceprint centroids weighted by their embedding counts and
/// L2-normalises the result.
///
/// If one side has no centroid (or a zero count) the other side is returned
/// (normalised). Returns null when neither side has a usable centroid. When
/// dimensions differ (e.g. after switching embedding models) the centroid
/// with more evidence wins.
({Float32List? centroid, int count}) combineVoiceprints(
  Float32List? a,
  int countA,
  Float32List? b,
  int countB,
) {
  final hasA = a != null && a.isNotEmpty;
  final hasB = b != null && b.isNotEmpty;
  final na = hasA ? math.max(countA, 1) : 0;
  final nb = hasB ? math.max(countB, 1) : 0;
  final total = math.min(na + nb, kMaxVoiceprintEmbeddingCount);
  if (!hasA && !hasB) return (centroid: null, count: 0);
  if (!hasB) return (centroid: _normalized(a!), count: total);
  if (!hasA) return (centroid: _normalized(b), count: total);
  if (a.length != b.length) {
    return na >= nb
        ? (centroid: _normalized(a), count: math.min(na, total))
        : (centroid: _normalized(b), count: math.min(nb, total));
  }
  final out = Float32List(a.length);
  for (var i = 0; i < a.length; i++) {
    out[i] = (a[i] * na + b[i] * nb) / (na + nb);
  }
  return (centroid: _normalized(out), count: total);
}

Float32List _normalized(Float32List v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }
  final norm = math.sqrt(sum);
  final out = Float32List(v.length);
  if (norm == 0 || norm.isNaN) {
    out.setAll(0, v);
    return out;
  }
  for (var i = 0; i < v.length; i++) {
    out[i] = v[i] / norm;
  }
  return out;
}

String _pad2(int v) => v.toString().padLeft(2, '0');

/// Decodes a stored JSON list of strings; anything malformed → empty list.
List<String> decodeJsonStringList(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    return jsonStringList(jsonDecode(json));
  } on FormatException {
    return const [];
  }
}

/// Decodes a stored JSON list of integers (evidence ids); malformed → empty.
List<int> decodeJsonIntList(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    return parseEvidenceIds(jsonDecode(json));
  } on FormatException {
    return const [];
  }
}

/// Trims every field of [c], drops blank list items, and turns blank
/// notes / template into null.
MeetingContext normalizeMeetingContext(MeetingContext c) => MeetingContext(
      agenda: jsonStringList(c.agenda),
      expectedAttendees: jsonStringList(c.expectedAttendees),
      contextNotes: jsonNonEmpty(c.contextNotes),
      template: jsonNonEmpty(c.template),
    );

/// Default title for a meeting created at [t], e.g. `اجتماع 2026/11/19 14:05`.
String defaultMeetingTitle(DateTime t) =>
    'اجتماع ${t.year}/${_pad2(t.month)}/${_pad2(t.day)} '
    '${_pad2(t.hour)}:${_pad2(t.minute)}';

// ---------------------------------------------------------------------------
// Meetings
// ---------------------------------------------------------------------------

/// CRUD for [Meeting]s. Deleting a meeting cascades to its segments.
class MeetingRepository {
  /// Creates a repository over [db]. [recordingsDir] returns the directory
  /// archived recordings live in now (`AppPaths.recordingsDir`); [delete]
  /// uses it to find the file of a stored bare file name. Without it only an
  /// absolute stored path can be deleted.
  MeetingRepository(this._db, {this._recordingsDir});

  final AppDatabase _db;
  final Future<String> Function()? _recordingsDir;

  /// Converts a row to a domain [Meeting]. Corrupt minutes JSON is treated as
  /// absent minutes rather than failing the whole list.
  static Meeting fromRow(MeetingRow r) => Meeting(
        id: r.id,
        title: r.title,
        createdAt: r.createdAt,
        status: MeetingStatus.parse(r.status),
        durationMs: r.durationMs,
        audioPath: r.audioPath,
        minutes: _decodeMinutes(r.minutesJson),
        errorMessage: r.errorMessage,
        context: MeetingContext(
          agenda: decodeJsonStringList(r.agendaJson),
          expectedAttendees: decodeJsonStringList(r.expectedAttendeesJson),
          contextNotes: jsonNonEmpty(r.contextNotes),
          template: jsonNonEmpty(r.template),
        ),
        inputDevice: jsonNonEmpty(r.inputDevice),
      );

  static Minutes? _decodeMinutes(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return Minutes.fromJson(decoded.cast<String, dynamic>());
      }
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
    return null;
  }

  /// Creates a new meeting in [MeetingStatus.recording] state.
  ///
  /// [title] defaults to [defaultMeetingTitle]; [id] defaults to a new UUID.
  ///
  /// [context] (F3) and [inputDevice] (F18) are stored when given.
  Future<Meeting> create({
    String? title,
    DateTime? createdAt,
    String? id,
    MeetingStatus status = MeetingStatus.recording,
    MeetingContext context = MeetingContext.empty,
    String? inputDevice,
  }) async {
    final now = createdAt ?? DateTime.now();
    final t = title?.trim();
    final ctx = normalizeMeetingContext(context);
    final device = jsonNonEmpty(inputDevice);
    final meeting = Meeting(
      id: id ?? _uuid.v4(),
      title: (t == null || t.isEmpty) ? defaultMeetingTitle(now) : t,
      createdAt: now,
      status: status,
      context: ctx,
      inputDevice: device,
    );
    await _db.into(_db.meetings).insert(MeetingsCompanion.insert(
          id: meeting.id,
          title: meeting.title,
          createdAt: meeting.createdAt,
          status: meeting.status.name,
          agendaJson: Value(jsonEncode(ctx.agenda)),
          expectedAttendeesJson: Value(jsonEncode(ctx.expectedAttendees)),
          contextNotes: Value(ctx.contextNotes),
          template: Value(ctx.template),
          inputDevice: Value(device),
        ));
    return meeting;
  }

  /// All meetings, newest first, re-emitted on every change.
  Stream<List<Meeting>> watchAll() => (_db.select(_db.meetings)
        ..orderBy([
          (m) => OrderingTerm.desc(m.createdAt),
          (m) => OrderingTerm.desc(m.rowId),
        ]))
      .watch()
      .map((rows) => rows.map(fromRow).toList(growable: false));

  /// All meetings, newest first.
  Future<List<Meeting>> getAll() async {
    final rows = await (_db.select(_db.meetings)
          ..orderBy([
            (m) => OrderingTerm.desc(m.createdAt),
            (m) => OrderingTerm.desc(m.rowId),
          ]))
        .get();
    return rows.map(fromRow).toList(growable: false);
  }

  /// The meeting with [id] (null if deleted / missing), re-emitted on change.
  Stream<Meeting?> watch(String id) =>
      (_db.select(_db.meetings)..where((m) => m.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : fromRow(r));

  /// The meeting with [id], or null.
  Future<Meeting?> get(String id) async {
    final r = await (_db.select(_db.meetings)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : fromRow(r);
  }

  Future<bool> _update(String id, MeetingsCompanion c) async {
    final n = await (_db.update(_db.meetings)..where((m) => m.id.equals(id)))
        .write(c);
    return n > 0;
  }

  /// Renames the meeting. Blank titles are ignored. Returns true if updated.
  Future<bool> updateTitle(String id, String title) {
    final t = title.trim();
    if (t.isEmpty) return Future.value(false);
    return _update(id, MeetingsCompanion(title: Value(t)));
  }

  /// Sets the status. Moving away from [MeetingStatus.failed] clears the
  /// error message unless [clearError] is explicitly false.
  Future<bool> updateStatus(String id, MeetingStatus status,
      {bool? clearError}) {
    final clear = clearError ?? status != MeetingStatus.failed;
    return _update(
      id,
      MeetingsCompanion(
        status: Value(status.name),
        errorMessage: clear ? const Value(null) : const Value.absent(),
      ),
    );
  }

  /// Replaces the meeting's context (F3: agenda, expected attendees, notes,
  /// template). Items are trimmed and blank ones dropped. Returns true if
  /// the meeting existed.
  Future<bool> updateContext(String id, MeetingContext context) {
    final ctx = normalizeMeetingContext(context);
    return _update(
      id,
      MeetingsCompanion(
        agendaJson: Value(jsonEncode(ctx.agenda)),
        expectedAttendeesJson: Value(jsonEncode(ctx.expectedAttendees)),
        contextNotes: Value(ctx.contextNotes),
        template: Value(ctx.template),
      ),
    );
  }

  /// Records the input device of the recording (F18; null = default).
  Future<bool> setInputDevice(String id, String? device) => _update(
      id, MeetingsCompanion(inputDevice: Value(jsonNonEmpty(device))));

  /// Sets the recorded duration in milliseconds.
  Future<bool> setDuration(String id, int durationMs) =>
      _update(id, MeetingsCompanion(durationMs: Value(math.max(0, durationMs))));

  /// Sets (or clears, with null) the archived audio path.
  Future<bool> setAudioPath(String id, String? audioPath) =>
      _update(id, MeetingsCompanion(audioPath: Value(audioPath)));

  /// Stores [minutes] for the meeting. When [markReady] is true (default) the
  /// status becomes [MeetingStatus.ready] and any error is cleared.
  Future<bool> saveMinutes(String id, Minutes minutes,
      {bool markReady = true}) {
    return _update(
      id,
      MeetingsCompanion(
        minutesJson: Value(jsonEncode(minutes.toJson())),
        status: markReady
            ? Value(MeetingStatus.ready.name)
            : const Value.absent(),
        errorMessage: markReady ? const Value(null) : const Value.absent(),
      ),
    );
  }

  /// Removes stored minutes (e.g. before regenerating).
  Future<bool> clearMinutes(String id) =>
      _update(id, const MeetingsCompanion(minutesJson: Value(null)));

  /// Marks the meeting as [MeetingStatus.failed] with an Arabic, user-facing
  /// [messageAr].
  Future<bool> setError(String id, String messageAr) => _update(
        id,
        MeetingsCompanion(
          status: Value(MeetingStatus.failed.name),
          errorMessage: Value(messageAr),
        ),
      );

  /// Deletes the meeting, its segments (cascade) and its archived audio file
  /// if present. Returns true if a meeting row was deleted.
  ///
  /// `audioPath` is a bare file name (`<id>.wav`) for new rows and possibly a
  /// stale absolute path for older ones (the iOS container moves on updates,
  /// Windows data moved out of Documents). Both the stored absolute path and
  /// the file of that name in the current recordings directory are deleted.
  /// A failure to delete the audio file does not undo the database deletion.
  Future<bool> delete(String id) async {
    final row = await (_db.select(_db.meetings)
          ..where((m) => m.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return false;
    final n =
        await (_db.delete(_db.meetings)..where((m) => m.id.equals(id))).go();
    // v1.2 C: the multi-device log (devices, gaps, per-segment SNRs).
    await (_db.delete(_db.settings)
          ..where((s) => s.key.equals('$kMultiDeviceLogKeyPrefix$id')))
        .go();
    final stored = row.audioPath;
    if (stored != null && stored.isNotEmpty) {
      for (final path in await _audioCandidates(stored)) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } on FileSystemException {
          // The row is gone; the file would stay behind in the app's private
          // recordings folder, which the OS does not clean. Never fail the
          // user's delete because of it.
        }
      }
    }
    return n > 0;
  }

  Future<Set<String>> _audioCandidates(String stored) async {
    final out = <String>{};
    if (p.isAbsolute(stored)) out.add(stored);
    final dirOf = _recordingsDir;
    if (dirOf != null) {
      try {
        out.add(p.join(await dirOf(), p.basename(stored)));
      } catch (_) {
        // Directory unavailable: only the stored path can be tried.
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Segments
// ---------------------------------------------------------------------------

/// CRUD for [TranscriptSegment]s.
class SegmentRepository {
  /// Creates a repository over [db].
  SegmentRepository(this._db);

  final AppDatabase _db;

  /// Converts a row to a domain [TranscriptSegment].
  static TranscriptSegment fromRow(SegmentRow r) => TranscriptSegment(
        id: r.id,
        meetingId: r.meetingId,
        index: r.idx,
        startMs: r.startMs,
        endMs: r.endMs,
        text: r.body,
        speakerId: r.speakerId,
        language: r.language,
        embedding: _safeBlob(r.embedding),
        speakerLocked: r.speakerLocked,
        kind: SegmentKind.parse(r.kind),
        asrConfidence: r.asrConfidence,
        speakerConfidence: r.speakerConfidence,
      );

  static SegmentsCompanion _toCompanion(TranscriptSegment s, String id) =>
      SegmentsCompanion.insert(
        id: id,
        meetingId: s.meetingId,
        idx: s.index,
        startMs: s.startMs,
        endMs: s.endMs,
        body: s.text,
        speakerId: Value(s.speakerId),
        language: Value(s.language),
        embedding: Value(s.embedding == null || s.embedding!.isEmpty
            ? null
            : float32ToBlob(s.embedding!)),
        speakerLocked: Value(s.speakerLocked),
        kind: Value(s.kind.wire),
        asrConfidence: Value(s.asrConfidence),
        speakerConfidence: Value(s.speakerConfidence),
      );

  /// Inserts [segment]. An empty [TranscriptSegment.id] is replaced by a new
  /// UUID. Returns the stored segment.
  ///
  /// Throws a drift/sqlite exception if the meeting or speaker does not exist
  /// (foreign keys are enforced) or the id is already taken.
  Future<TranscriptSegment> insert(TranscriptSegment segment) async {
    final id = segment.id.isEmpty ? _uuid.v4() : segment.id;
    await _db.into(_db.segments).insert(_toCompanion(segment, id));
    return id == segment.id ? segment : _withId(segment, id);
  }

  /// Inserts all [segments] in one batch (empty ids get new UUIDs).
  Future<List<TranscriptSegment>> insertAll(
      List<TranscriptSegment> segments) async {
    final stored = [
      for (final s in segments) s.id.isEmpty ? _withId(s, _uuid.v4()) : s,
    ];
    await _db.batch((b) {
      b.insertAll(_db.segments, [for (final s in stored) _toCompanion(s, s.id)]);
    });
    return stored;
  }

  static TranscriptSegment _withId(TranscriptSegment s, String id) =>
      TranscriptSegment(
        id: id,
        meetingId: s.meetingId,
        index: s.index,
        startMs: s.startMs,
        endMs: s.endMs,
        text: s.text,
        speakerId: s.speakerId,
        language: s.language,
        embedding: s.embedding,
        speakerLocked: s.speakerLocked,
        kind: s.kind,
        asrConfidence: s.asrConfidence,
        speakerConfidence: s.speakerConfidence,
      );

  /// Overwrites every stored field of [segment] (matched by id; meetingId is
  /// not changed). A null [TranscriptSegment.speakerId] clears the speaker.
  /// Returns true if the segment existed.
  Future<bool> update(TranscriptSegment segment) async {
    final c = _toCompanion(segment, segment.id).copyWith(
      id: const Value.absent(),
      meetingId: const Value.absent(),
    );
    final n = await (_db.update(_db.segments)
          ..where((s) => s.id.equals(segment.id)))
        .write(c);
    return n > 0;
  }

  /// Segments of [meetingId] ordered by index, re-emitted on change.
  Stream<List<TranscriptSegment>> watchForMeeting(String meetingId) =>
      _forMeeting(meetingId)
          .watch()
          .map((rows) => rows.map(fromRow).toList(growable: false));

  /// Segments of [meetingId] ordered by index.
  Future<List<TranscriptSegment>> getForMeeting(String meetingId) async =>
      (await _forMeeting(meetingId).get())
          .map(fromRow)
          .toList(growable: false);

  SimpleSelectStatement<$SegmentsTable, SegmentRow> _forMeeting(
          String meetingId) =>
      _db.select(_db.segments)
        ..where((s) => s.meetingId.equals(meetingId))
        ..orderBy([
          (s) => OrderingTerm.asc(s.idx),
          (s) => OrderingTerm.asc(s.startMs),
        ]);

  /// The segment with [id], or null.
  Future<TranscriptSegment?> get(String id) async {
    final r = await (_db.select(_db.segments)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : fromRow(r);
  }

  /// Next free index for a new segment of [meetingId] (0 when empty).
  Future<int> nextIndex(String meetingId) async {
    final maxIdx = _db.segments.idx.max();
    final row = await (_db.selectOnly(_db.segments)
          ..addColumns([maxIdx])
          ..where(_db.segments.meetingId.equals(meetingId)))
        .getSingle();
    final v = row.read(maxIdx);
    return v == null ? 0 : v + 1;
  }

  /// Assigns [speakerId] (null = unassigned) to one segment. [locked] marks a
  /// manual assignment that refinement must not override. Returns true if the
  /// segment existed.
  Future<bool> reassignSpeaker(String segmentId, String? speakerId,
      {bool locked = true}) async {
    final n = await (_db.update(_db.segments)
          ..where((s) => s.id.equals(segmentId)))
        .write(SegmentsCompanion(
      speakerId: Value(speakerId),
      speakerLocked: Value(locked),
      // A manual assignment is certain; an automatic one is not known.
      speakerConfidence: Value(locked ? 1.0 : null),
    ));
    return n > 0;
  }

  /// Assigns speakers to many segments in one transaction (map of segment id
  /// to speaker id, null = unassigned).
  ///
  /// When [respectLocked] is true (default) segments whose speaker the user
  /// locked are left unchanged. Returns the number of segments updated.
  Future<int> bulkAssignSpeakers(Map<String, String?> assignments,
      {bool respectLocked = true}) {
    if (assignments.isEmpty) return Future.value(0);
    return _db.transaction(() async {
      var total = 0;
      for (final e in assignments.entries) {
        final q = _db.update(_db.segments)
          ..where((s) => respectLocked
              ? s.id.equals(e.key) & s.speakerLocked.equals(false)
              : s.id.equals(e.key));
        total += await q.write(SegmentsCompanion(speakerId: Value(e.value)));
      }
      return total;
    });
  }

  /// Stores the speaker-assignment confidence of many segments in one
  /// transaction (segment id → confidence, null = unknown). User-locked
  /// segments are left unchanged. Returns the number of segments updated.
  Future<int> bulkSetSpeakerConfidence(Map<String, double?> confidences) {
    if (confidences.isEmpty) return Future.value(0);
    return _db.transaction(() async {
      var total = 0;
      for (final e in confidences.entries) {
        final q = _db.update(_db.segments)
          ..where((s) => s.id.equals(e.key) & s.speakerLocked.equals(false));
        total += await q.write(
            SegmentsCompanion(speakerConfidence: Value(e.value)));
      }
      return total;
    });
  }

  /// Segments of [meetingId] with the given [SegmentKind.unintelligible]
  /// kind (F17), ordered by index.
  Future<List<TranscriptSegment>> getUnintelligible(String meetingId) async =>
      (await (_forMeeting(meetingId)
                ..where((s) => s.kind.equals(SegmentKind.unintelligible.wire)))
              .get())
          .map(fromRow)
          .toList(growable: false);

  /// Changes the kind of one segment, e.g. after the user transcribed an
  /// unintelligible segment by hand or a reversed-audio re-ASR succeeded
  /// (F17). Returns true if the segment existed.
  Future<bool> setKind(String segmentId, SegmentKind kind) async {
    final n = await (_db.update(_db.segments)
          ..where((s) => s.id.equals(segmentId)))
        .write(SegmentsCompanion(kind: Value(kind.wire)));
    return n > 0;
  }

  /// Replaces the text of one segment (user correction). Returns true if the
  /// segment existed.
  Future<bool> updateText(String segmentId, String text) async {
    final n = await (_db.update(_db.segments)
          ..where((s) => s.id.equals(segmentId)))
        .write(SegmentsCompanion(body: Value(text)));
    return n > 0;
  }

  /// Deletes one segment. Returns true if it existed.
  Future<bool> delete(String segmentId) async {
    final n = await (_db.delete(_db.segments)
          ..where((s) => s.id.equals(segmentId)))
        .go();
    return n > 0;
  }
}

// ---------------------------------------------------------------------------
// Speakers
// ---------------------------------------------------------------------------

/// CRUD and voiceprint maintenance for global [Speaker]s.
class SpeakerRepository {
  /// Creates a repository over [db].
  SpeakerRepository(this._db);

  final AppDatabase _db;

  /// Converts a row to a domain [Speaker].
  static Speaker fromRow(SpeakerRow r) => Speaker(
        id: r.id,
        name: r.name,
        colorValue: r.color,
        isNamedByUser: r.isNamedByUser,
        createdAt: r.createdAt,
        centroid: _safeBlob(r.centroid),
        embeddingCount: r.centroid == null ? 0 : r.embeddingCount,
        profileEnabled: r.profileEnabled,
        voiceDevice: r.voiceDevice,
        lowConfidence: r.lowConfidence,
      );

  /// Creates a speaker.
  ///
  /// Without [name] the speaker gets the auto name `متحدث N` with the smallest
  /// unused N among existing speakers. The color is the least-used entry of
  /// [kSpeakerPalette] unless [colorValue] is given. [isNamedByUser] defaults
  /// to true exactly when a [name] is supplied.
  Future<Speaker> create({
    String? name,
    bool? isNamedByUser,
    int? colorValue,
    Float32List? centroid,
    int embeddingCount = 0,
    DateTime? createdAt,
    String? id,
    String? voiceDevice,
    bool lowConfidence = false,
  }) {
    return _db.transaction(() async {
      final existing = await _db.select(_db.speakers).get();
      final given = name?.trim();
      final hasName = given != null && given.isNotEmpty;
      final resolvedName = hasName
          ? given
          : autoSpeakerName(
              nextAutoSpeakerNumber(existing.map((s) => s.name)));
      final hasCentroid = centroid != null && centroid.isNotEmpty;
      final speaker = Speaker(
        id: id ?? _uuid.v4(),
        name: resolvedName,
        colorValue:
            colorValue ?? pickSpeakerColor(existing.map((s) => s.color)),
        isNamedByUser: isNamedByUser ?? hasName,
        createdAt: createdAt ?? DateTime.now(),
        centroid: hasCentroid ? centroid : null,
        embeddingCount: hasCentroid ? math.max(embeddingCount, 1) : 0,
        voiceDevice: jsonNonEmpty(voiceDevice),
        lowConfidence: lowConfidence,
      );
      await _db.into(_db.speakers).insert(SpeakersCompanion.insert(
            id: speaker.id,
            name: speaker.name,
            color: speaker.colorValue,
            isNamedByUser: Value(speaker.isNamedByUser),
            createdAt: speaker.createdAt,
            centroid: Value(hasCentroid ? float32ToBlob(centroid) : null),
            embeddingCount: Value(speaker.embeddingCount),
            voiceDevice: Value(speaker.voiceDevice),
            lowConfidence: Value(speaker.lowConfidence),
          ));
      return speaker;
    });
  }

  SimpleSelectStatement<$SpeakersTable, SpeakerRow> _all() =>
      _db.select(_db.speakers)
        ..orderBy([
          (s) => OrderingTerm.asc(s.createdAt),
          (s) => OrderingTerm.asc(s.rowId),
        ]);

  /// All speakers in creation order, re-emitted on change.
  Stream<List<Speaker>> watchAll() => _all()
      .watch()
      .map((rows) => rows.map(fromRow).toList(growable: false));

  /// All speakers in creation order.
  Future<List<Speaker>> getAll() async =>
      (await _all().get()).map(fromRow).toList(growable: false);

  /// All speakers keyed by id (convenient for rendering transcripts).
  Future<Map<String, Speaker>> getAllById() async =>
      {for (final s in await getAll()) s.id: s};

  /// The speaker with [id], or null.
  Future<Speaker?> get(String id) async {
    final r = await (_db.select(_db.speakers)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : fromRow(r);
  }

  /// The speaker with [id] (null if missing), re-emitted on change.
  Stream<Speaker?> watch(String id) =>
      (_db.select(_db.speakers)..where((s) => s.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : fromRow(r));

  /// Renames the speaker everywhere and marks it as named by the user.
  ///
  /// Throws [ArgumentError] for a blank name. Returns true if it existed.
  Future<bool> rename(String id, String name) async {
    final t = name.trim();
    if (t.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    final n = await (_db.update(_db.speakers)..where((s) => s.id.equals(id)))
        .write(SpeakersCompanion(name: Value(t), isNamedByUser: const Value(true)));
    return n > 0;
  }

  /// Enables or disables the speaker profile (F16, opt-in). Disabling does
  /// not delete an existing profile; use `SpeakerProfileRepository.delete`
  /// for that. Returns true if it existed.
  Future<bool> setProfileEnabled(String id, bool enabled) async {
    final n = await (_db.update(_db.speakers)..where((s) => s.id.equals(id)))
        .write(SpeakersCompanion(profileEnabled: Value(enabled)));
    return n > 0;
  }

  /// Records the input device the voiceprint was learned on (F18; null =
  /// unknown / default). Returns true if it existed.
  Future<bool> setVoiceDevice(String id, String? device) async {
    final n = await (_db.update(_db.speakers)..where((s) => s.id.equals(id)))
        .write(SpeakersCompanion(voiceDevice: Value(jsonNonEmpty(device))));
    return n > 0;
  }

  /// Flags the voiceprint as low-confidence (F15: < 3 s of speech; not used
  /// for matching) or clears the flag. Returns true if it existed.
  Future<bool> setLowConfidence(String id, bool low) async {
    final n = await (_db.update(_db.speakers)..where((s) => s.id.equals(id)))
        .write(SpeakersCompanion(lowConfidence: Value(low)));
    return n > 0;
  }

  /// Changes the speaker's color. Returns true if it existed.
  Future<bool> setColor(String id, int colorValue) async {
    final n = await (_db.update(_db.speakers)..where((s) => s.id.equals(id)))
        .write(SpeakersCompanion(color: Value(colorValue)));
    return n > 0;
  }

  /// Stores a new voiceprint [centroid] (already L2-normalised by the caller)
  /// averaged over [embeddingCount] embeddings. Returns true if it existed.
  Future<bool> updateVoiceprint(
      String id, Float32List centroid, int embeddingCount) async {
    final has = centroid.isNotEmpty;
    final n = await (_db.update(_db.speakers)..where((s) => s.id.equals(id)))
        .write(SpeakersCompanion(
      centroid: Value(has ? float32ToBlob(centroid) : null),
      embeddingCount: Value(has ? math.max(embeddingCount, 1) : 0),
    ));
    return n > 0;
  }

  /// Forgets the speaker's voiceprint ("not a voiceprint"): the speaker and
  /// its segment assignments stay, but it is never matched by voice again
  /// until re-enrolled. Returns true if it existed.
  ///
  /// In the same transaction, every voiceprint-ledger entry of the speaker
  /// (all meetings) becomes a tombstone: those segments no longer feed any
  /// voiceprint, so a later correction must not subtract them from a
  /// re-enrolled voiceprint, nor silently learn them again.
  Future<bool> forgetVoice(String id) => _db.transaction(() async {
        final n =
            await (_db.update(_db.speakers)..where((s) => s.id.equals(id)))
                .write(const SpeakersCompanion(
          centroid: Value(null),
          embeddingCount: Value(0),
        ));
        await _rewriteLedgers({id: voiceprintLedgerTombstone(id)});
        return n > 0;
      });

  /// Rewrites every voiceprint ledger value `v` to `remap[v]` (when present)
  /// and removes the entries whose value is in [drop]. Only changed rows are
  /// written; a ledger left empty is deleted.
  Future<void> _rewriteLedgers(Map<String, String> remap,
      {Set<String> drop = const {}}) async {
    if (remap.isEmpty && drop.isEmpty) return;
    final rows = await (_db.select(_db.settings)
          ..where((s) => s.key.like('$kVoiceprintLedgerKeyPrefix%')))
        .get();
    for (final row in rows) {
      // LIKE treats `_` as a wildcard: check the prefix exactly.
      if (!row.key.startsWith(kVoiceprintLedgerKeyPrefix)) continue;
      final ledger = _decodeLedger(row.value);
      var changed = false;
      for (final e in ledger.entries.toList()) {
        if (drop.contains(e.value)) {
          ledger.remove(e.key);
          changed = true;
          continue;
        }
        final to = remap[e.value];
        if (to != null && to != e.value) {
          ledger[e.key] = to;
          changed = true;
        }
      }
      if (!changed) continue;
      if (ledger.isEmpty) {
        await (_db.delete(_db.settings)..where((s) => s.key.equals(row.key)))
            .go();
      } else {
        await (_db.update(_db.settings)..where((s) => s.key.equals(row.key)))
            .write(SettingsCompanion(value: Value(jsonEncode(ledger))));
      }
    }
  }

  /// Merges speaker [fromId] into [intoId] atomically:
  ///
  /// 1. every segment of [fromId] (in all meetings) is reassigned to [intoId]
  ///    (lock flags are preserved);
  /// 2. the voiceprints are combined, weighted by embedding counts
  ///    ([combineVoiceprints]);
  /// 3. if only [fromId] carried a user-given name, [intoId] adopts it;
  /// 4. [fromId] is deleted;
  /// 5. the voiceprint ledgers of all meetings are rewritten: entries of
  ///    [fromId] move to [intoId] when [fromId]'s centroid went into the
  ///    combined voiceprint, and become tombstones of [intoId] otherwise (no
  ///    usable centroid, or the smaller side of a dimension mismatch); the
  ///    entries of [intoId] become tombstones when its own centroid was
  ///    dropped. So the ledger only claims contributions the voiceprint
  ///    really contains.
  ///
  /// Returns the merged speaker. Throws [StateError] if either speaker is
  /// missing. Merging a speaker into itself is a no-op.
  Future<Speaker> merge(String fromId, String intoId) {
    return _db.transaction(() async {
      final into = await get(intoId);
      if (into == null) throw StateError('Speaker $intoId not found');
      if (fromId == intoId) return into;
      final from = await get(fromId);
      if (from == null) throw StateError('Speaker $fromId not found');

      await (_db.update(_db.segments)
            ..where((s) => s.speakerId.equals(fromId)))
          .write(SegmentsCompanion(speakerId: Value(intoId)));
      // v1.1 rows that point at the speaker follow it (notes / a profile
      // that [intoId] already has are kept; [fromId]'s duplicates go with
      // the cascade below).
      await (_db.update(_db.tasks)
            ..where((t) => t.ownerSpeakerId.equals(fromId)))
          .write(TasksCompanion(ownerSpeakerId: Value(intoId)));
      await (_db.update(_db.codeFindings)
            ..where((c) => c.speakerId.equals(fromId)))
          .write(CodeFindingsCompanion(speakerId: Value(intoId)));
      for (final table in const ['speaker_meeting_notes', 'speaker_profiles']) {
        await _db.customUpdate(
          'UPDATE OR IGNORE $table SET speaker_id = ?1 WHERE speaker_id = ?2',
          variables: [Variable.withString(intoId), Variable.withString(fromId)],
          updates: {
            if (table == 'speaker_profiles') _db.speakerProfiles
            else _db.speakerMeetingNotes,
          },
        );
      }

      final combined = combineVoiceprints(into.centroid, into.embeddingCount,
          from.centroid, from.embeddingCount);
      final adoptName = from.isNamedByUser && !into.isNamedByUser;
      final merged = Speaker(
        id: into.id,
        name: adoptName ? from.name : into.name,
        colorValue: into.colorValue,
        isNamedByUser: into.isNamedByUser || from.isNamedByUser,
        createdAt: into.createdAt,
        centroid: combined.centroid,
        embeddingCount: combined.count,
        profileEnabled: into.profileEnabled || from.profileEnabled,
        voiceDevice: into.voiceDevice ?? from.voiceDevice,
        lowConfidence: combined.centroid != null &&
            into.lowConfidence &&
            from.lowConfidence,
      );
      await (_db.update(_db.speakers)..where((s) => s.id.equals(intoId)))
          .write(SpeakersCompanion(
        name: Value(merged.name),
        isNamedByUser: Value(merged.isNamedByUser),
        profileEnabled: Value(merged.profileEnabled),
        voiceDevice: Value(merged.voiceDevice),
        lowConfidence: Value(merged.lowConfidence),
        centroid: Value(merged.centroid == null
            ? null
            : float32ToBlob(merged.centroid!)),
        embeddingCount: Value(merged.embeddingCount),
      ));
      await (_db.delete(_db.speakers)..where((s) => s.id.equals(fromId))).go();

      final fromKept = _survivesCombine(from.centroid, from.embeddingCount,
          into.centroid, into.embeddingCount);
      final intoKept = _survivesCombine(into.centroid, into.embeddingCount,
          from.centroid, from.embeddingCount);
      final intoTomb = voiceprintLedgerTombstone(intoId);
      await _rewriteLedgers({
        fromId: fromKept ? intoId : intoTomb,
        voiceprintLedgerTombstone(fromId): intoTomb,
        if (!intoKept) intoId: intoTomb,
      });
      return merged;
    });
  }

  /// Deletes the speaker. Its segments become unassigned (FK `SET NULL`).
  /// Returns true if it existed.
  ///
  /// In the same transaction, the voiceprint-ledger entries of the speaker
  /// (live or tombstone, all meetings) are removed: its voiceprint is gone,
  /// so there is nothing left to unlearn from those segments.
  Future<bool> delete(String id) => _db.transaction(() async {
        final n = await (_db.delete(_db.speakers)
              ..where((s) => s.id.equals(id)))
            .go();
        await _rewriteLedgers(const {},
            drop: {id, voiceprintLedgerTombstone(id)});
        return n > 0;
      });

  Selectable<Speaker> _forMeeting(String meetingId) => _db.customSelect(
        'SELECT sp.*, MIN(sg.idx) AS first_idx FROM speakers sp '
        'INNER JOIN segments sg ON sg.speaker_id = sp.id '
        'WHERE sg.meeting_id = ?1 '
        'GROUP BY sp.id ORDER BY first_idx ASC',
        variables: [Variable.withString(meetingId)],
        readsFrom: {_db.speakers, _db.segments},
      ).map((row) => fromRow(_db.speakers.map(row.data)));

  /// Speakers that appear in [meetingId], ordered by first appearance.
  Future<List<Speaker>> speakersForMeeting(String meetingId) =>
      _forMeeting(meetingId).get();

  /// Like [speakersForMeeting], re-emitted on change.
  Stream<List<Speaker>> watchSpeakersForMeeting(String meetingId) =>
      _forMeeting(meetingId).watch();
}

/// Decodes a Float32 blob, treating corrupt data as absent.
Float32List? _safeBlob(Uint8List? bytes) {
  try {
    return blobToFloat32(bytes);
  } on FormatException {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// The app database. Override it in `ProviderScope` (e.g. with an instance
/// opened in `main()` or an in-memory database in tests); by default the
/// on-device database is opened lazily and closed with the container.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Directory of archived recordings (`AppPaths.recordingsDir`), used by
/// [MeetingRepository.delete] to find the file of a stored file name.
/// Overridden at app start (see `main.dart`); null in plain tests.
final recordingsDirProvider =
    Provider<Future<String> Function()?>((ref) => null);

/// [MeetingRepository] over [databaseProvider].
final meetingRepositoryProvider = Provider<MeetingRepository>(
    (ref) => MeetingRepository(ref.watch(databaseProvider),
        recordingsDir: ref.watch(recordingsDirProvider)));

/// [SegmentRepository] over [databaseProvider].
final segmentRepositoryProvider = Provider<SegmentRepository>(
    (ref) => SegmentRepository(ref.watch(databaseProvider)));

/// [SpeakerRepository] over [databaseProvider].
final speakerRepositoryProvider = Provider<SpeakerRepository>(
    (ref) => SpeakerRepository(ref.watch(databaseProvider)));

/// All meetings, newest first.
final meetingsProvider = StreamProvider<List<Meeting>>(
    (ref) => ref.watch(meetingRepositoryProvider).watchAll());

/// One meeting by id (null when deleted).
final meetingProvider = StreamProvider.autoDispose.family<Meeting?, String>(
    (ref, id) => ref.watch(meetingRepositoryProvider).watch(id));

/// Segments of a meeting ordered by index.
final segmentsProvider =
    StreamProvider.autoDispose.family<List<TranscriptSegment>, String>(
        (ref, meetingId) =>
            ref.watch(segmentRepositoryProvider).watchForMeeting(meetingId));

/// All global speakers in creation order.
final speakersProvider = StreamProvider<List<Speaker>>(
    (ref) => ref.watch(speakerRepositoryProvider).watchAll());

/// All global speakers keyed by id.
final speakersByIdProvider = StreamProvider<Map<String, Speaker>>((ref) => ref
    .watch(speakerRepositoryProvider)
    .watchAll()
    .map((list) => {for (final s in list) s.id: s}));

/// Speakers appearing in a meeting, ordered by first appearance.
final meetingSpeakersProvider =
    StreamProvider.autoDispose.family<List<Speaker>, String>((ref, meetingId) =>
        ref.watch(speakerRepositoryProvider).watchSpeakersForMeeting(meetingId));
