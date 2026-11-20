// Details of an imported recording, kept in the settings table under
// `import_info:<meeting id>` (deleted with the meeting by
// `MeetingRepository.delete`). Imported meetings are also tagged through
// `Meeting.inputDevice` ([kImportedInputDevice]), which is what the badge
// reads, so the list needs no extra query.

import 'dart:convert';

import '../../core/models.dart';
import '../../data/database.dart';
import '../../data/repositories.dart' show kImportInfoKeyPrefix;
import 'audio_formats.dart';

/// Whether [meeting] was created from an imported recording.
bool isImportedMeeting(Meeting meeting) =>
    meeting.inputDevice == kImportedInputDevice;

/// What is remembered about the original file of an imported meeting.
class ImportInfo {
  /// Creates the info.
  const ImportInfo({
    required this.fileName,
    required this.format,
    required this.importedAt,
    this.codec,
    this.sourceSampleRate,
    this.sourceChannels,
    this.sizeBytes,
    this.callRecording = false,
    this.viaShare = false,
  });

  /// Original file name.
  final String fileName;

  /// Container label (`M4A`, `MP3`, …).
  final String format;

  /// Codec reported by the decoder.
  final String? codec;

  /// Original sample rate.
  final int? sourceSampleRate;

  /// Original channels.
  final int? sourceChannels;

  /// Original size.
  final int? sizeBytes;

  /// When it was imported.
  final DateTime importedAt;

  /// The file name looked like a phone-call recording.
  final bool callRecording;

  /// Received through the OS share sheet / "open in".
  final bool viaShare;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'file_name': fileName,
    'format': format,
    if (codec != null) 'codec': codec,
    if (sourceSampleRate != null) 'sample_rate': sourceSampleRate,
    if (sourceChannels != null) 'channels': sourceChannels,
    if (sizeBytes != null) 'size': sizeBytes,
    'imported_at': importedAt.toUtc().toIso8601String(),
    'call': callRecording,
    'share': viaShare,
  };

  /// Parses [json]; null when malformed.
  static ImportInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['file_name'];
    final format = json['format'];
    final at = DateTime.tryParse('${json['imported_at']}');
    if (name is! String || format is! String || at == null) return null;
    int? asInt(Object? v) => v is int ? v : null;
    return ImportInfo(
      fileName: name,
      format: format,
      codec: json['codec'] as String?,
      sourceSampleRate: asInt(json['sample_rate']),
      sourceChannels: asInt(json['channels']),
      sizeBytes: asInt(json['size']),
      importedAt: at.toLocal(),
      callRecording: json['call'] == true,
      viaShare: json['share'] == true,
    );
  }
}

/// Stores [ImportInfo] in the settings table.
class ImportInfoStore {
  /// Creates the store over [_db].
  ImportInfoStore(this._db);

  final AppDatabase _db;

  static String _key(String meetingId) => '$kImportInfoKeyPrefix$meetingId';

  /// Saves [info] for [meetingId].
  Future<void> save(String meetingId, ImportInfo info) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: _key(meetingId),
          value: jsonEncode(info.toJson()),
        ),
      );

  /// The info of [meetingId], or null.
  Future<ImportInfo?> load(String meetingId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(_key(meetingId)))).getSingleOrNull();
    final v = row?.value;
    if (v == null) return null;
    try {
      return ImportInfo.fromJson(jsonDecode(v));
    } on FormatException {
      return null;
    }
  }
}
