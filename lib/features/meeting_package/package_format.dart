// The «حزمة الاجتماع» file format (`.insato`): what an offline Insato device
// hands over to the main meeting by USB, Bluetooth / Nearby Share /
// AirDrop, an SD card or e-mail.
//
// A package is a ZIP archive:
//
//   manifest.json     PackageManifest (format / app / schema version, device,
//                     meeting id / title / start time, what is included and
//                     the SHA-256 + size of every other entry)
//   transcript.json   segments with their times (ms from the recording start),
//                     text, language, kind, confidences, local speaker id,
//                     per-segment SNR, and — only with voiceprints — the
//                     segment's speaker embedding
//   speakers.json     the local speakers of the meeting (name, colour, named
//                     by the user) and — only with voiceprints — their
//                     centroids
//   minutes.json      optional: `Minutes.toJson()`
//   audio.wav         optional: the archived recording (16 kHz mono PCM16)
//
// An encrypted package (password) is a ZIP archive with `envelope.json`
// (KDF / cipher parameters, never the password or the key) and every entry
// above encrypted as `<name>.enc` (package_crypto.dart).
//
// Pure Dart (no Flutter imports): usable in isolates and unit tests.

import 'dart:convert';
import 'dart:typed_data';

import '../../core/models.dart';

/// File extension of a meeting package (without the dot).
const String kPackageExtension = 'insato';

/// MIME type used when sharing a package.
const String kPackageMimeType = 'application/x-insato-package';

/// `format` value of the manifest / envelope.
const String kPackageFormatId = 'insato-meeting-package';

/// Current format version (readers accept versions up to this one).
const int kPackageFormatVersion = 1;

/// Entry names.
abstract final class PackageEntries {
  /// Manifest (always present).
  static const String manifest = 'manifest.json';

  /// Encryption envelope (encrypted packages only, plaintext).
  static const String envelope = 'envelope.json';

  /// Transcript segments.
  static const String transcript = 'transcript.json';

  /// Local speakers.
  static const String speakers = 'speakers.json';

  /// Minutes (optional).
  static const String minutes = 'minutes.json';

  /// Recording (optional).
  static const String audio = 'audio.wav';

  /// Suffix of an encrypted entry.
  static const String encryptedSuffix = '.enc';
}

/// Why a package could not be read.
enum PackageErrorKind {
  /// Not a ZIP archive or not an Insato package.
  notAPackage,

  /// Written by a newer version of the format.
  unsupportedVersion,

  /// The package is encrypted and no password was given.
  passwordRequired,

  /// Wrong password, or the encrypted content was modified.
  wrongPassword,

  /// An entry does not match the SHA-256 / size in the manifest.
  tampered,

  /// A required entry is missing or unreadable.
  corrupt,
}

/// A package that cannot be read.
class PackageException implements Exception {
  /// Creates the exception.
  const PackageException(this.kind, [this.detail]);

  /// What went wrong.
  final PackageErrorKind kind;

  /// Technical detail (entry name, …), never shown as the main message.
  final String? detail;

  @override
  String toString() =>
      'PackageException(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// Digest and size of one entry, as listed in the manifest.
class PackageEntryInfo {
  /// Creates the info.
  const PackageEntryInfo({required this.sha256, required this.size});

  /// Lower-case hex SHA-256 of the entry's plaintext bytes.
  final String sha256;

  /// Plaintext size in bytes.
  final int size;

  /// JSON form.
  Map<String, Object?> toJson() => {'sha256': sha256, 'size': size};

  /// Parses [toJson] output; null when malformed.
  static PackageEntryInfo? fromJson(Object? j) {
    if (j is! Map || j['sha256'] is! String || j['size'] is! int) return null;
    return PackageEntryInfo(
      sha256: j['sha256'] as String,
      size: j['size'] as int,
    );
  }
}

/// The exporting device.
class PackageDevice {
  /// Creates the device.
  const PackageDevice({required this.name, this.platform = ''});

  /// Display name (host name or platform).
  final String name;

  /// `android` / `ios` / `windows` / …
  final String platform;

  /// JSON form.
  Map<String, Object?> toJson() => {'name': name, 'platform': platform};

  /// Parses [toJson] output.
  static PackageDevice fromJson(Object? j) => j is Map
      ? PackageDevice(name: _str(j['name']), platform: _str(j['platform']))
      : const PackageDevice(name: '');
}

/// What a package contains.
class PackageIncludes {
  /// Creates the flags.
  const PackageIncludes({
    required this.audio,
    required this.voiceprints,
    required this.minutes,
  });

  /// `audio.wav` is present.
  final bool audio;

  /// Speaker centroids and segment embeddings are present (biometric data,
  /// opt-in on export).
  final bool voiceprints;

  /// `minutes.json` is present.
  final bool minutes;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'audio': audio,
    'voiceprints': voiceprints,
    'minutes': minutes,
  };

  /// Parses [toJson] output.
  static PackageIncludes fromJson(Object? j) => j is Map
      ? PackageIncludes(
          audio: j['audio'] == true,
          voiceprints: j['voiceprints'] == true,
          minutes: j['minutes'] == true,
        )
      : const PackageIncludes(audio: false, voiceprints: false, minutes: false);
}

/// `manifest.json`.
class PackageManifest {
  /// Creates a manifest.
  const PackageManifest({
    this.formatVersion = kPackageFormatVersion,
    required this.appVersion,
    required this.schemaVersion,
    required this.exportedAt,
    required this.exportedMonotonicUs,
    required this.device,
    required this.meetingId,
    required this.title,
    required this.startedAt,
    required this.durationMs,
    required this.includes,
    this.context = MeetingContext.empty,
    this.inputDevice,
    this.entries = const {},
  });

  /// Format version.
  final int formatVersion;

  /// Insato version that wrote it.
  final String appVersion;

  /// Database schema version of the writer.
  final int schemaVersion;

  /// Wall-clock time of the export (writer's clock).
  final DateTime exportedAt;

  /// Writer's monotonic clock at export (µs since its process started).
  /// With [exportedAt] it documents the writer's clock; it is not
  /// comparable across devices.
  final int exportedMonotonicUs;

  /// Writer device.
  final PackageDevice device;

  /// Meeting id on the writer device.
  final String meetingId;

  /// Meeting title.
  final String title;

  /// Wall-clock start of the recording (sample 0 of `audio.wav`, time 0 of
  /// the segments) on the writer's clock.
  final DateTime startedAt;

  /// Recorded duration.
  final int durationMs;

  /// What is included.
  final PackageIncludes includes;

  /// Agenda, expected attendees, notes, template.
  final MeetingContext context;

  /// Input device of the recording.
  final String? inputDevice;

  /// Entry name → digest / size (all entries but the manifest).
  final Map<String, PackageEntryInfo> entries;

  /// Copy with other [entries].
  PackageManifest withEntries(Map<String, PackageEntryInfo> entries) =>
      PackageManifest(
        formatVersion: formatVersion,
        appVersion: appVersion,
        schemaVersion: schemaVersion,
        exportedAt: exportedAt,
        exportedMonotonicUs: exportedMonotonicUs,
        device: device,
        meetingId: meetingId,
        title: title,
        startedAt: startedAt,
        durationMs: durationMs,
        includes: includes,
        context: context,
        inputDevice: inputDevice,
        entries: entries,
      );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'format': kPackageFormatId,
    'format_version': formatVersion,
    'app_version': appVersion,
    'schema_version': schemaVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'exported_at_ms': exportedAt.millisecondsSinceEpoch,
    'exported_monotonic_us': exportedMonotonicUs,
    'device': device.toJson(),
    'meeting': {
      'id': meetingId,
      'title': title,
      'started_at': startedAt.toUtc().toIso8601String(),
      'started_at_ms': startedAt.millisecondsSinceEpoch,
      'timezone_offset_min': startedAt.toLocal().timeZoneOffset.inMinutes,
      'duration_ms': durationMs,
      'context': {
        'agenda': context.agenda,
        'expected_attendees': context.expectedAttendees,
        'notes': context.contextNotes,
        'template': context.template,
      },
      'input_device': inputDevice,
    },
    'includes': includes.toJson(),
    'entries': {for (final e in entries.entries) e.key: e.value.toJson()},
  };

  /// Parses a manifest. Throws [PackageException].
  static PackageManifest fromJson(Object? j) {
    if (j is! Map || j['format'] != kPackageFormatId) {
      throw const PackageException(PackageErrorKind.notAPackage, 'manifest');
    }
    final version = j['format_version'];
    if (version is! int || version < 1) {
      throw const PackageException(PackageErrorKind.corrupt, 'format_version');
    }
    if (version > kPackageFormatVersion) {
      throw PackageException(PackageErrorKind.unsupportedVersion, '$version');
    }
    final m = j['meeting'];
    if (m is! Map || m['started_at_ms'] is! int) {
      throw const PackageException(PackageErrorKind.corrupt, 'meeting');
    }
    final ctx = m['context'];
    final entries = <String, PackageEntryInfo>{};
    final rawEntries = j['entries'];
    if (rawEntries is Map) {
      for (final e in rawEntries.entries) {
        final info = PackageEntryInfo.fromJson(e.value);
        if (e.key is String && info != null) entries[e.key as String] = info;
      }
    }
    return PackageManifest(
      formatVersion: version,
      appVersion: _str(j['app_version']),
      schemaVersion: j['schema_version'] is int
          ? j['schema_version'] as int
          : 0,
      exportedAt: DateTime.fromMillisecondsSinceEpoch(
        j['exported_at_ms'] is int ? j['exported_at_ms'] as int : 0,
      ),
      exportedMonotonicUs: j['exported_monotonic_us'] is int
          ? j['exported_monotonic_us'] as int
          : 0,
      device: PackageDevice.fromJson(j['device']),
      meetingId: _str(m['id']),
      title: _str(m['title']),
      startedAt: DateTime.fromMillisecondsSinceEpoch(m['started_at_ms'] as int),
      durationMs: m['duration_ms'] is int ? m['duration_ms'] as int : 0,
      includes: PackageIncludes.fromJson(j['includes']),
      context: ctx is Map
          ? MeetingContext(
              agenda: jsonStringList(ctx['agenda']),
              expectedAttendees: jsonStringList(ctx['expected_attendees']),
              contextNotes: jsonNonEmpty(ctx['notes']),
              template: jsonNonEmpty(ctx['template']),
            )
          : MeetingContext.empty,
      inputDevice: jsonNonEmpty(m['input_device']),
      entries: entries,
    );
  }
}

/// One transcript segment of a package.
class PackageSegment {
  /// Creates a segment.
  const PackageSegment({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.speakerKey,
    this.language,
    this.kind = SegmentKind.speech,
    this.asrConfidence,
    this.speakerConfidence,
    this.speakerLocked = false,
    this.snrDb,
    this.embedding,
  });

  /// Index on the writer device.
  final int index;

  /// Start (ms from the recording start).
  final int startMs;

  /// End (ms from the recording start).
  final int endMs;

  /// Text.
  final String text;

  /// Key of the speaker in `speakers.json` (null: unassigned).
  final String? speakerKey;

  /// Language code.
  final String? language;

  /// Speech / unintelligible.
  final SegmentKind kind;

  /// Recogniser confidence.
  final double? asrConfidence;

  /// Speaker-assignment confidence.
  final double? speakerConfidence;

  /// The writer's user assigned the speaker by hand.
  final bool speakerLocked;

  /// Speech-to-noise ratio of the segment in the writer's recording (dB),
  /// when the recording was available at export.
  final double? snrDb;

  /// Speaker embedding (voiceprint packages only).
  final Float32List? embedding;

  /// Duration.
  int get durationMs => endMs - startMs;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'index': index,
    'start_ms': startMs,
    'end_ms': endMs,
    'text': text,
    'speaker': speakerKey,
    'language': language,
    'kind': kind.wire,
    'asr_confidence': asrConfidence,
    'speaker_confidence': speakerConfidence,
    'speaker_locked': speakerLocked,
    'snr_db': snrDb,
    if (embedding != null) 'embedding': encodeFloat32Base64(embedding!),
  };

  /// Parses [toJson] output; null when malformed.
  static PackageSegment? fromJson(Object? j) {
    if (j is! Map || j['start_ms'] is! int || j['end_ms'] is! int) return null;
    final start = j['start_ms'] as int;
    final end = j['end_ms'] as int;
    if (start < 0 || end < start) return null;
    return PackageSegment(
      index: j['index'] is int ? j['index'] as int : 0,
      startMs: start,
      endMs: end,
      text: _str(j['text']),
      speakerKey: jsonNonEmpty(j['speaker']),
      language: jsonNonEmpty(j['language']),
      kind: SegmentKind.parse(_str(j['kind'])),
      asrConfidence: _double(j['asr_confidence']),
      speakerConfidence: _double(j['speaker_confidence']),
      speakerLocked: j['speaker_locked'] == true,
      snrDb: _double(j['snr_db']),
      embedding: decodeFloat32Base64(j['embedding']),
    );
  }

  /// Copy without the embedding.
  PackageSegment withoutEmbedding() => PackageSegment(
    index: index,
    startMs: startMs,
    endMs: endMs,
    text: text,
    speakerKey: speakerKey,
    language: language,
    kind: kind,
    asrConfidence: asrConfidence,
    speakerConfidence: speakerConfidence,
    speakerLocked: speakerLocked,
    snrDb: snrDb,
  );
}

/// One local speaker of a package.
class PackageSpeaker {
  /// Creates a speaker.
  const PackageSpeaker({
    required this.key,
    required this.name,
    required this.colorValue,
    required this.isNamedByUser,
    this.centroid,
    this.embeddingCount = 0,
  });

  /// Key referenced by [PackageSegment.speakerKey] (the writer's speaker
  /// id).
  final String key;

  /// Name on the writer device.
  final String name;

  /// ARGB colour.
  final int colorValue;

  /// The writer's user named the speaker.
  final bool isNamedByUser;

  /// Voiceprint centroid (voiceprint packages only).
  final Float32List? centroid;

  /// Embeddings averaged into [centroid].
  final int embeddingCount;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'key': key,
    'name': name,
    'color': colorValue,
    'named_by_user': isNamedByUser,
    if (centroid != null) 'centroid': encodeFloat32Base64(centroid!),
    if (centroid != null) 'embedding_count': embeddingCount,
  };

  /// Parses [toJson] output; null when malformed.
  static PackageSpeaker? fromJson(Object? j) {
    if (j is! Map || j['key'] is! String) return null;
    return PackageSpeaker(
      key: j['key'] as String,
      name: _str(j['name']),
      colorValue: j['color'] is int ? j['color'] as int : 0xFF37474F,
      isNamedByUser: j['named_by_user'] == true,
      centroid: decodeFloat32Base64(j['centroid']),
      embeddingCount: j['embedding_count'] is int
          ? j['embedding_count'] as int
          : 0,
    );
  }
}

/// Everything a package carries, decoded and verified.
class MeetingPackage {
  /// Creates the contents.
  const MeetingPackage({
    required this.manifest,
    required this.segments,
    required this.speakers,
    this.minutes,
    this.audioWav,
    this.encrypted = false,
  });

  /// Manifest.
  final PackageManifest manifest;

  /// Segments in the writer's order.
  final List<PackageSegment> segments;

  /// Local speakers.
  final List<PackageSpeaker> speakers;

  /// Minutes, when included.
  final Minutes? minutes;

  /// `audio.wav` bytes, when included.
  final Uint8List? audioWav;

  /// The package was password-protected.
  final bool encrypted;

  /// Speakers by key.
  Map<String, PackageSpeaker> get speakersByKey => {
    for (final s in speakers) s.key: s,
  };

  /// End of the last segment or the manifest's duration, whichever is later.
  int get effectiveDurationMs {
    var d = manifest.durationMs;
    for (final s in segments) {
      if (s.endMs > d) d = s.endMs;
    }
    return d;
  }
}

/// `transcript.json` body.
Map<String, Object?> transcriptJson(List<PackageSegment> segments) => {
  'segments': [for (final s in segments) s.toJson()],
};

/// Parses `transcript.json`. Throws [PackageException] when malformed.
List<PackageSegment> parseTranscriptJson(Object? j) {
  final raw = j is Map ? j['segments'] : null;
  if (raw is! List) {
    throw const PackageException(PackageErrorKind.corrupt, 'transcript');
  }
  return [for (final s in raw) ?PackageSegment.fromJson(s)];
}

/// `speakers.json` body.
Map<String, Object?> speakersJson(List<PackageSpeaker> speakers) => {
  'speakers': [for (final s in speakers) s.toJson()],
};

/// Parses `speakers.json`. Throws [PackageException] when malformed.
List<PackageSpeaker> parseSpeakersJson(Object? j) {
  final raw = j is Map ? j['speakers'] : null;
  if (raw is! List) {
    throw const PackageException(PackageErrorKind.corrupt, 'speakers');
  }
  return [for (final s in raw) ?PackageSpeaker.fromJson(s)];
}

/// Little-endian Float32 bytes, base64.
String encodeFloat32Base64(Float32List v) {
  final data = ByteData(v.length * 4);
  for (var i = 0; i < v.length; i++) {
    data.setFloat32(i * 4, v[i], Endian.little);
  }
  return base64Encode(data.buffer.asUint8List());
}

/// Inverse of [encodeFloat32Base64]; null for anything malformed.
Float32List? decodeFloat32Base64(Object? s) {
  if (s is! String || s.isEmpty) return null;
  try {
    final bytes = base64Decode(s);
    if (bytes.length % 4 != 0) return null;
    final data = ByteData.sublistView(bytes);
    final out = Float32List(bytes.length ~/ 4);
    for (var i = 0; i < out.length; i++) {
      out[i] = data.getFloat32(i * 4, Endian.little);
      if (!out[i].isFinite) return null;
    }
    return out;
  } on FormatException {
    return null;
  }
}

String _str(Object? v) => v is String ? v : '';

double? _double(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
