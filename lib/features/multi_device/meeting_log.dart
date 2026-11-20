// What a multi-device meeting stores besides its transcript (v1.2 C): the
// devices that took part, when each joined / dropped / returned / was
// removed (meeting time), per-device counters, and each transcript
// segment's SNR per device (diarization cue for later speaker refinement).
//
// Stored as JSON in the settings table (`multi_device_log:<meeting id>`),
// deleted with the meeting.

import 'dart:convert';

import '../../data/database.dart';
import '../../data/repositories.dart' show kMultiDeviceLogKeyPrefix;
import '../../diarization/channel_cue.dart';
import 'fusion_engine.dart' show DeviceTimelineEvent;

/// Settings key prefix of the logs.
const String kMultiDeviceLogPrefix = kMultiDeviceLogKeyPrefix;

/// A device of a multi-device meeting.
class LoggedDevice {
  /// Creates a device entry.
  const LoggedDevice({
    required this.id,
    required this.name,
    required this.platform,
    this.segmentsChosen = 0,
    this.framesLost = 0,
    this.framesLate = 0,
  });

  /// Device id.
  final String id;

  /// Display name.
  final String name;

  /// Platform.
  final String platform;

  /// Segments transcribed from this device.
  final int segmentsChosen;

  /// Audio frames lost on the network.
  final int framesLost;

  /// Audio frames that arrived late for the live mix.
  final int framesLate;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'platform': platform,
    'chosen': segmentsChosen,
    'lost': framesLost,
    'late': framesLate,
  };

  /// Parses [toJson] output.
  static LoggedDevice? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    int n(Object? v) => v is int ? v : 0;
    return LoggedDevice(
      id: j['id'] as String,
      name: j['name'] is String ? j['name'] as String : '',
      platform: j['platform'] is String ? j['platform'] as String : '',
      segmentsChosen: n(j['chosen']),
      framesLost: n(j['lost']),
      framesLate: n(j['late']),
    );
  }
}

/// A period during which a device was not connected.
class DeviceGap {
  /// Creates a gap ([endMs] null: until the end of the meeting).
  const DeviceGap({required this.deviceId, required this.startMs, this.endMs});

  /// Device id.
  final String deviceId;

  /// Meeting time the device dropped.
  final int startMs;

  /// Meeting time it came back (null: it did not).
  final int? endMs;
}

/// See the file header.
class MultiDeviceMeetingLog {
  /// Creates a log.
  const MultiDeviceMeetingLog({
    required this.devices,
    required this.events,
    this.segmentProfiles = const {},
  });

  /// Guest devices (the host itself is implicit).
  final List<LoggedDevice> devices;

  /// Joins / drops / returns / removals in meeting time.
  final List<DeviceTimelineEvent> events;

  /// Transcript segment id → SNR per device.
  final Map<String, ChannelProfile> segmentProfiles;

  /// Periods each device was away (a removal ends its participation).
  List<DeviceGap> get gaps {
    final out = <DeviceGap>[];
    final open = <String, int>{};
    for (final e in events) {
      switch (e.kind) {
        case 'left':
          open[e.channelId] = e.atMs;
        case 'rejoined':
          final s = open.remove(e.channelId);
          if (s != null) {
            out.add(
              DeviceGap(deviceId: e.channelId, startMs: s, endMs: e.atMs),
            );
          }
      }
    }
    open.forEach((id, s) => out.add(DeviceGap(deviceId: id, startMs: s)));
    out.sort((a, b) => a.startMs.compareTo(b.startMs));
    return out;
  }

  /// Name of device [id] (the id when unknown).
  String nameOf(String id) {
    for (final d in devices) {
      if (d.id == id) return d.name.isEmpty ? id : d.name;
    }
    return id;
  }

  /// JSON form.
  Map<String, Object?> toJson() => {
    'v': 1,
    'devices': [for (final d in devices) d.toJson()],
    'events': [for (final e in events) e.toJson()],
    'profiles': {
      for (final e in segmentProfiles.entries) e.key: e.value.toJson(),
    },
  };

  /// Parses [toJson] output (tolerant; null when not a log).
  static MultiDeviceMeetingLog? fromJson(Object? j) {
    if (j is! Map) return null;
    final devices = j['devices'];
    final events = j['events'];
    final profiles = j['profiles'];
    return MultiDeviceMeetingLog(
      devices: [
        if (devices is List)
          for (final d in devices) ?LoggedDevice.fromJson(d),
      ],
      events: [
        if (events is List)
          for (final e in events) ?DeviceTimelineEvent.fromJson(e),
      ],
      segmentProfiles: {
        if (profiles is Map)
          for (final e in profiles.entries)
            if (e.key is String)
              e.key as String: ?ChannelProfile.fromJson(e.value),
      },
    );
  }
}

/// Stores [MultiDeviceMeetingLog]s in the settings table.
class MultiDeviceLogStore {
  /// Creates the store over [_db].
  MultiDeviceLogStore(this._db);

  final AppDatabase _db;

  static String _key(String meetingId) => '$kMultiDeviceLogPrefix$meetingId';

  /// Saves [log] for [meetingId].
  Future<void> save(String meetingId, MultiDeviceMeetingLog log) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: _key(meetingId),
          value: jsonEncode(log.toJson()),
        ),
      );

  /// The log of [meetingId] (null for single-device meetings).
  Future<MultiDeviceMeetingLog?> load(String meetingId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(_key(meetingId)))).getSingleOrNull();
    return _parse(row?.value);
  }

  /// Watches the log of [meetingId].
  Stream<MultiDeviceMeetingLog?> watch(String meetingId) =>
      (_db.select(_db.settings)..where((t) => t.key.equals(_key(meetingId))))
          .watchSingleOrNull()
          .map((r) => _parse(r?.value));

  /// Deletes the log of [meetingId].
  Future<void> delete(String meetingId) => (_db.delete(
    _db.settings,
  )..where((t) => t.key.equals(_key(meetingId)))).go();

  /// Segment profiles of [meetingId] (empty when none).
  Future<Map<String, ChannelProfile>> profiles(String meetingId) async =>
      (await load(meetingId))?.segmentProfiles ?? const {};

  static MultiDeviceMeetingLog? _parse(String? s) {
    if (s == null) return null;
    try {
      return MultiDeviceMeetingLog.fromJson(jsonDecode(s));
    } on FormatException {
      return null;
    }
  }
}
