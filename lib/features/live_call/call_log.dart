// Live Insato call (v1.2): the call log of a meeting — both device names,
// when streaming started and stopped (and who stopped it), reconnections,
// mutes, the safety code and how the media travelled.
//
// Stored as JSON in the settings table (`live_call_log:<meeting id>`),
// deleted with the meeting (MeetingRepository.delete).

import 'dart:convert';

import 'package:drift/drift.dart' show Value, StringExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repositories.dart'
    show databaseProvider, kLiveCallLogKeyPrefix;

/// Settings key prefix of call logs.
const String kLiveCallLogPrefix = kLiveCallLogKeyPrefix;

/// One event of a call.
class CallLogEvent {
  /// Creates an event.
  const CallLogEvent({required this.at, required this.kind, this.byRemote = false});

  /// When.
  final DateTime at;

  /// `start`, `stop`, `reconnecting`, `reconnected`, `mute`, `unmute`.
  final String kind;

  /// True when the other device caused it.
  final bool byRemote;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'kind': kind,
    if (byRemote) 'remote': true,
  };

  /// Parses [toJson] output.
  static CallLogEvent? fromJson(Object? j) {
    if (j is! Map || j['kind'] is! String || j['at'] is! String) return null;
    final at = DateTime.tryParse(j['at'] as String);
    if (at == null) return null;
    return CallLogEvent(
      at: at.toLocal(),
      kind: j['kind'] as String,
      byRemote: j['remote'] == true,
    );
  }
}

/// The log of one call.
class LiveCallLog {
  /// Creates a log.
  const LiveCallLog({
    required this.role,
    required this.localName,
    required this.remoteName,
    required this.startedAt,
    this.localPlatform = '',
    this.remotePlatform = '',
    this.endedAt,
    this.endReason,
    this.relayHost = '',
    this.relayed,
    this.safetyCode,
    this.events = const [],
  });

  /// `caller` or `callee`.
  final String role;

  /// This device's name.
  final String localName;

  /// Platform of this device.
  final String localPlatform;

  /// The other device's name.
  final String remoteName;

  /// Its platform.
  final String remotePlatform;

  /// Streaming started.
  final DateTime startedAt;

  /// Streaming stopped.
  final DateTime? endedAt;

  /// Why (`localHangUp`, `remoteHangUp`, `networkLost`, …).
  final String? endReason;

  /// Host name of the signaling relay.
  final String relayHost;

  /// Media went through a TURN relay.
  final bool? relayed;

  /// Safety code shown during the call.
  final String? safetyCode;

  /// Events in order.
  final List<CallLogEvent> events;

  /// Copy with changes.
  LiveCallLog copyWith({
    DateTime? endedAt,
    String? endReason,
    bool? relayed,
    String? safetyCode,
    List<CallLogEvent>? events,
  }) => LiveCallLog(
    role: role,
    localName: localName,
    localPlatform: localPlatform,
    remoteName: remoteName,
    remotePlatform: remotePlatform,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    endReason: endReason ?? this.endReason,
    relayHost: relayHost,
    relayed: relayed ?? this.relayed,
    safetyCode: safetyCode ?? this.safetyCode,
    events: events ?? this.events,
  );

  /// Adds an event.
  LiveCallLog withEvent(CallLogEvent e) => copyWith(events: [...events, e]);

  /// JSON form.
  Map<String, Object?> toJson() => {
    'v': 1,
    'role': role,
    'local': localName,
    'localPlatform': localPlatform,
    'remote': remoteName,
    'remotePlatform': remotePlatform,
    'start': startedAt.toUtc().toIso8601String(),
    'end': ?endedAt?.toUtc().toIso8601String(),
    'reason': ?endReason,
    'relay': relayHost,
    'turn': ?relayed,
    'sas': ?safetyCode,
    'events': [for (final e in events) e.toJson()],
  };

  /// Parses [toJson] output; null when malformed.
  static LiveCallLog? fromJson(Object? j) {
    if (j is! Map) return null;
    final start = j['start'] is String
        ? DateTime.tryParse(j['start'] as String)
        : null;
    if (start == null) return null;
    String s(String k) => j[k] is String ? j[k] as String : '';
    final end = j['end'] is String ? DateTime.tryParse(j['end'] as String) : null;
    final events = j['events'];
    return LiveCallLog(
      role: s('role'),
      localName: s('local'),
      localPlatform: s('localPlatform'),
      remoteName: s('remote'),
      remotePlatform: s('remotePlatform'),
      startedAt: start.toLocal(),
      endedAt: end?.toLocal(),
      endReason: j['reason'] is String ? j['reason'] as String : null,
      relayHost: s('relay'),
      relayed: j['turn'] is bool ? j['turn'] as bool : null,
      safetyCode: j['sas'] is String ? j['sas'] as String : null,
      events: [
        if (events is List)
          for (final e in events) ?CallLogEvent.fromJson(e),
      ],
    );
  }

  /// Duration of the streaming (null while running).
  Duration? get duration => endedAt?.difference(startedAt);
}

/// Stores [LiveCallLog]s in the settings table.
class LiveCallLogStore {
  /// Creates the store.
  LiveCallLogStore(this._db);

  final AppDatabase _db;

  static String _key(String meetingId) => '$kLiveCallLogPrefix$meetingId';

  /// Saves [log] for [meetingId].
  Future<void> save(String meetingId, LiveCallLog log) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion(
          key: Value(_key(meetingId)),
          value: Value(jsonEncode(log.toJson())),
        ),
      );

  /// The log of [meetingId] (null when the meeting was not a call).
  Future<LiveCallLog?> load(String meetingId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(_key(meetingId)))).getSingleOrNull();
    return _parse(row?.value);
  }

  /// Watches the log of [meetingId].
  Stream<LiveCallLog?> watch(String meetingId) =>
      (_db.select(_db.settings)..where((t) => t.key.equals(_key(meetingId))))
          .watchSingleOrNull()
          .map((r) => _parse(r?.value));

  /// All call logs, newest first (meeting id → log).
  Stream<List<(String, LiveCallLog)>> watchAll() =>
      (_db.select(_db.settings)
            ..where((t) => t.key.like('$kLiveCallLogPrefix%')))
          .watch()
          .map((rows) {
            final out = <(String, LiveCallLog)>[
              for (final r in rows)
                if (_parse(r.value) case final log?)
                  (r.key.substring(kLiveCallLogPrefix.length), log),
            ]..sort((a, b) => b.$2.startedAt.compareTo(a.$2.startedAt));
            return out;
          });

  static LiveCallLog? _parse(String? s) {
    if (s == null) return null;
    try {
      return LiveCallLog.fromJson(jsonDecode(s));
    } on FormatException {
      return null;
    }
  }
}

/// The log store.
final liveCallLogStoreProvider = Provider<LiveCallLogStore>(
  (ref) => LiveCallLogStore(ref.watch(databaseProvider)),
);

/// The call log of a meeting.
final liveCallLogProvider = StreamProvider.autoDispose
    .family<LiveCallLog?, String>(
      (ref, meetingId) => ref.watch(liveCallLogStoreProvider).watch(meetingId),
    );

/// Every call, newest first.
final liveCallHistoryProvider =
    StreamProvider.autoDispose<List<(String, LiveCallLog)>>(
      (ref) => ref.watch(liveCallLogStoreProvider).watchAll(),
    );
