// Live Insato call (v1.2): stores the other device's lines in this device's
// meeting, and puts the merged transcript in time order at the end.
//
// * Remote lines become transcript rows of the meeting with their time on
//   this device's recording timeline (clock-synchronised), a speaker record
//   per remote speaker, and `speakerLocked: true` — they carry no voice
//   embedding here, so the speaker refinement must never move them.
// * Remote speakers: a speaker the other device recognised by name (a
//   renamed voiceprint, e.g. «أحمد») maps to the speaker of that name in
//   this device's library when there is one, else to a new speaker of that
//   name; an anonymous one (`متحدث 2`) becomes «متحدث 2 (<device>)». Users
//   can merge them with their own speakers as usual.
// * While the call runs, remote rows use indices from [kRemoteIndexBase];
//   [finalizeOrder] renumbers all rows by start time.

import 'dart:math' as math;

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;

import '../../core/models.dart';
import '../../data/database.dart';
import '../../data/repositories.dart';
import 'transcript_merge.dart';

/// Index base of remote rows during the call.
const int kRemoteIndexBase = 1000000;

/// Display name of a remote speaker: its own name when the other device
/// knows it, else the auto label qualified with the device name.
String remoteSpeakerName(String speakerName, String deviceName) {
  final n = speakerName.trim();
  final d = deviceName.trim().isEmpty ? 'الطرف الآخر' : deviceName.trim();
  if (n.isEmpty) return 'متحدث ($d)';
  if (parseAutoSpeakerNumber(n) != null) return '$n ($d)';
  return n;
}

/// Writes a call's remote lines into a meeting.
class CallMeetingWriter {
  /// Creates the writer.
  CallMeetingWriter({
    required this.db,
    required this.meetingId,
    required this.remoteDeviceName,
    required this._segments,
    required this._speakers,
  });

  /// Database (for deletions).
  final AppDatabase db;

  /// Meeting.
  final String meetingId;

  /// The other device's name.
  final String remoteDeviceName;

  final SegmentRepository _segments;
  final SpeakerRepository _speakers;
  final Map<String, String> _speakerByKey = {};
  final Set<String> _createdSpeakers = {};
  final Set<String> _remoteRows = {};
  int _nextRemoteIndex = kRemoteIndexBase;
  Future<void> _tail = Future<void>.value();

  /// Speakers created for remote voices.
  Set<String> get createdSpeakerIds => Set.unmodifiable(_createdSpeakers);

  /// Remote rows stored.
  int get remoteCount => _remoteRows.length;

  /// Runs [f] after every earlier write (rows arrive faster than SQLite).
  Future<void> _serial(Future<void> Function() f) {
    final next = _tail.then((_) => f()).catchError((Object _) {});
    _tail = next;
    return next;
  }

  /// Completes when every queued write is done.
  Future<void> flush() => _tail;

  static int _ms(int atUs, int captureStartUs) =>
      math.max(0, (atUs - captureStartUs) ~/ 1000);

  Future<String> _speakerFor(LiveLine line) async {
    final key = line.speakerKey.isEmpty
        ? '?${line.speakerName}'
        : line.speakerKey;
    final known = _speakerByKey[key];
    if (known != null && await _speakers.get(known) != null) return known;
    final name = remoteSpeakerName(line.speakerName, remoteDeviceName);
    final all = await _speakers.getAll();
    final norm = name.trim().toLowerCase();
    for (final s in all) {
      if (s.name.trim().toLowerCase() == norm) {
        return _speakerByKey[key] = s.id;
      }
    }
    final created = await _speakers.create(name: name);
    _createdSpeakers.add(created.id);
    return _speakerByKey[key] = created.id;
  }

  /// Stores a final remote [line] ([captureStartUs]: this clock's time of
  /// the recording's first sample).
  Future<void> insertRemote(LiveLine line, int captureStartUs) => _serial(
    () async {
      if (_remoteRows.contains(line.id)) {
        await _update(line, captureStartUs);
        return;
      }
      final speakerId = await _speakerFor(line);
      final start = _ms(line.atUs, captureStartUs);
      await _segments.insert(
        TranscriptSegment(
          id: line.id,
          meetingId: meetingId,
          index: _nextRemoteIndex++,
          startMs: start,
          endMs: start + math.max(0, line.durMs),
          text: line.text,
          speakerId: speakerId,
          language: line.language,
          speakerLocked: true,
          kind: line.kind,
          asrConfidence: line.confidence,
        ),
      );
      _remoteRows.add(line.id);
    },
  );

  Future<void> _update(LiveLine line, int captureStartUs) async {
    final old = await _segments.get(line.id);
    if (old == null) return;
    final start = _ms(line.atUs, captureStartUs);
    await _segments.update(
      TranscriptSegment(
        id: old.id,
        meetingId: old.meetingId,
        index: old.index,
        startMs: start,
        endMs: start + math.max(0, line.durMs),
        text: line.pending ? old.text : line.text,
        speakerId: old.speakerId,
        language: old.language,
        speakerLocked: old.speakerLocked,
        kind: old.kind,
        asrConfidence: old.asrConfidence,
        speakerConfidence: old.speakerConfidence,
      ),
    );
  }

  /// Moves remote rows whose time was corrected.
  Future<void> retime(List<LiveLine> lines, int captureStartUs) => _serial(
    () async {
      for (final l in lines) {
        if (_remoteRows.contains(l.id)) await _update(l, captureStartUs);
      }
    },
  );

  /// Deletes a row (a remote line the peer retracted, or one of ours found
  /// to be an echo).
  Future<void> delete(String segmentId) => _serial(() async {
    await (db.delete(db.segments)
          ..where(
            (s) => s.id.equals(segmentId) & s.meetingId.equals(meetingId),
          ))
        .go();
    _remoteRows.remove(segmentId);
  });

  /// Renumbers every row of the meeting by start time (local before remote
  /// on ties). Returns the number of rows.
  Future<int> finalizeOrder() async {
    await flush();
    final rows = [...await _segments.getForMeeting(meetingId)]
      ..sort((a, b) {
        final c = a.startMs.compareTo(b.startMs);
        if (c != 0) return c;
        final ra = _remoteRows.contains(a.id) ? 1 : 0;
        final rb = _remoteRows.contains(b.id) ? 1 : 0;
        return ra != rb ? ra - rb : a.index.compareTo(b.index);
      });
    await db.transaction(() async {
      for (var i = 0; i < rows.length; i++) {
        final s = rows[i];
        if (s.index == i) continue;
        await (db.update(db.segments)..where((t) => t.id.equals(s.id))).write(
          SegmentsCompanion(idx: Value(i)),
        );
      }
    });
    return rows.length;
  }
}
