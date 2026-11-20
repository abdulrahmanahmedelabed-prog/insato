// What a phone-call meeting stores besides its transcript: the call mode
// (meeting metadata), the side of every stored segment and a few counters.
//
// Stored as JSON in the settings table (`phone_call_log:<meeting id>`),
// deleted with the meeting (`MeetingRepository.delete`). Read back by the
// speaker refinement (hard partitions), voiceprint learning (telephone
// channel tag) and the minutes prompt (remote speakers).

import 'dart:convert';

import '../../core/models.dart' show MinutesCallHint;
import '../../data/database.dart';
import '../../data/repositories.dart' show kPhoneCallLogKeyPrefix;
import '../../diarization/channel_cue.dart';
import 'phone_call_models.dart';

/// The phone-call record of one meeting.
class PhoneCallLog {
  /// Creates a log.
  const PhoneCallLog({
    required this.mode,
    this.sides = const {},
    this.bleedSuppressed = 0,
    this.overlaps = 0,
    this.unattributed = 0,
  });

  /// How the call was captured.
  final PhoneCallMode mode;

  /// Stored segment id → side.
  final Map<String, CallSide> sides;

  /// Segments whose microphone activity was the remote voice (echo).
  final int bleedSuppressed;

  /// Segments in which both sides spoke.
  final int overlaps;

  /// Segments that could not be attributed (speakerphone).
  final int unattributed;

  /// Segments of [side].
  int count(CallSide side) => sides.values.where((s) => s == side).length;

  /// Remote-side segment ids.
  Set<String> get remoteSegmentIds => {
    for (final e in sides.entries)
      if (e.value == CallSide.remote) e.key,
  };

  /// Hard partitions for the speaker refinement.
  Map<String, ChannelProfile> get partitions => {
    for (final e in sides.entries)
      e.key: ChannelProfile(const {}, partition: e.value.partition),
  };

  /// Minutes prompt hint.
  MinutesCallHint get minutesHint => MinutesCallHint(
    mode: mode.storageName,
    remoteSegmentIds: remoteSegmentIds,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'v': 1,
    'mode': mode.storageName,
    'sides': {
      for (final e in sides.entries)
        e.key: e.value == CallSide.remote ? 'r' : 'l',
    },
    'bleed': bleedSuppressed,
    'overlaps': overlaps,
    'unattributed': unattributed,
  };

  /// Parses [toJson] output; null when not a log.
  static PhoneCallLog? fromJson(Object? j) {
    if (j is! Map) return null;
    final mode = PhoneCallMode.fromStorage(j['mode']);
    if (mode == null) return null;
    final raw = j['sides'];
    final sides = <String, CallSide>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key;
        if (k is! String) continue;
        if (e.value == 'r') sides[k] = CallSide.remote;
        if (e.value == 'l') sides[k] = CallSide.local;
      }
    }
    int n(Object? v) => v is int && v >= 0 ? v : 0;
    return PhoneCallLog(
      mode: mode,
      sides: sides,
      bleedSuppressed: n(j['bleed']),
      overlaps: n(j['overlaps']),
      unattributed: n(j['unattributed']),
    );
  }
}

/// Reads and writes [PhoneCallLog]s.
class PhoneCallLogStore {
  /// Creates the store over [_db].
  PhoneCallLogStore(this._db);

  final AppDatabase _db;

  static String _key(String meetingId) => '$kPhoneCallLogKeyPrefix$meetingId';

  /// Saves [log] for [meetingId].
  Future<void> save(String meetingId, PhoneCallLog log) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: _key(meetingId),
          value: jsonEncode(log.toJson()),
        ),
      );

  /// The log of [meetingId] (null when it was not a phone call).
  Future<PhoneCallLog?> load(String meetingId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(_key(meetingId)))).getSingleOrNull();
    return _parse(row?.value);
  }

  /// Watches the log of [meetingId].
  Stream<PhoneCallLog?> watch(String meetingId) =>
      (_db.select(_db.settings)..where((t) => t.key.equals(_key(meetingId))))
          .watchSingleOrNull()
          .map((r) => _parse(r?.value));

  /// Hard diarization partitions of [meetingId] (empty when none).
  Future<Map<String, ChannelProfile>> partitions(String meetingId) async =>
      (await load(meetingId))?.partitions ?? const {};

  /// Segment id → [kTelephoneVoiceDeviceKey] for remote-side segments.
  Future<Map<String, String>> segmentVoiceDevices(String meetingId) async => {
    for (final id
        in (await load(meetingId))?.remoteSegmentIds ?? const <String>{})
      id: kTelephoneVoiceDeviceKey,
  };

  /// The minutes prompt hint of [meetingId] (null when not a call).
  Future<MinutesCallHint?> minutesHint(String meetingId) async =>
      (await load(meetingId))?.minutesHint;

  static PhoneCallLog? _parse(String? s) {
    if (s == null) return null;
    try {
      return PhoneCallLog.fromJson(jsonDecode(s));
    } on FormatException {
      return null;
    }
  }
}
