// Writes and reads `.insato` meeting packages (format: package_format.dart,
// encryption: package_crypto.dart). Pure Dart; the heavy calls are meant
// to run in a background isolate ([encodeMeetingPackageInBackground],
// [decodeMeetingPackageInBackground]).

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart' show SecretKeyData;
import 'package:crypto/crypto.dart' as crypto;

import '../../core/models.dart';
import 'package_crypto.dart';
import 'package_format.dart';

/// Lower-case hex SHA-256 of [bytes].
String sha256Hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// Builds the archive bytes of [package].
///
/// The manifest's entry table is (re)computed from the entries written.
/// With a non-empty [password] every entry is encrypted (see
/// package_crypto.dart); [kdfIterations] is for tests.
Future<Uint8List> encodeMeetingPackage(
  MeetingPackage package, {
  String? password,
  int kdfIterations = kPackageKdfIterations,
  int chunkSize = kPackageChunkSize,
}) async {
  final includes = package.manifest.includes;
  final plain = <String, Uint8List>{
    PackageEntries.transcript: _json(
      transcriptJson([
        for (final s in package.segments)
          includes.voiceprints ? s : s.withoutEmbedding(),
      ]),
    ),
    PackageEntries.speakers: _json(
      speakersJson([
        for (final s in package.speakers)
          includes.voiceprints
              ? s
              : PackageSpeaker(
                  key: s.key,
                  name: s.name,
                  colorValue: s.colorValue,
                  isNamedByUser: s.isNamedByUser,
                ),
      ]),
    ),
    if (includes.minutes && package.minutes != null)
      PackageEntries.minutes: _json(package.minutes!.toJson()),
    if (includes.audio && package.audioWav != null)
      PackageEntries.audio: package.audioWav!,
  };
  final manifest = PackageManifest(
    formatVersion: package.manifest.formatVersion,
    appVersion: package.manifest.appVersion,
    schemaVersion: package.manifest.schemaVersion,
    exportedAt: package.manifest.exportedAt,
    exportedMonotonicUs: package.manifest.exportedMonotonicUs,
    device: package.manifest.device,
    meetingId: package.manifest.meetingId,
    title: package.manifest.title,
    startedAt: package.manifest.startedAt,
    durationMs: package.manifest.durationMs,
    includes: PackageIncludes(
      audio: plain.containsKey(PackageEntries.audio),
      voiceprints: includes.voiceprints,
      minutes: plain.containsKey(PackageEntries.minutes),
    ),
    context: package.manifest.context,
    inputDevice: package.manifest.inputDevice,
    entries: {
      for (final e in plain.entries)
        e.key: PackageEntryInfo(
          sha256: sha256Hex(e.value),
          size: e.value.length,
        ),
    },
  );
  plain[PackageEntries.manifest] = _json(manifest.toJson());

  final archive = Archive();
  if (password == null || password.isEmpty) {
    // Manifest first, so a reader can stop early.
    for (final name in [
      PackageEntries.manifest,
      ...plain.keys.where((k) => k != PackageEntries.manifest),
    ]) {
      archive.add(_entry(name, plain[name]!));
    }
  } else {
    final envelope = PackageEnvelope.random(iterations: kdfIterations);
    final env = PackageEnvelope(
      salt: envelope.salt,
      iterations: envelope.iterations,
      chunkSize: chunkSize,
    );
    final key = await derivePackageKey(password, env);
    archive.add(_entry(PackageEntries.envelope, _json(env.toJson())));
    for (final name in [
      PackageEntries.manifest,
      ...plain.keys.where((k) => k != PackageEntries.manifest),
    ]) {
      // Ciphertext does not compress: store it.
      final sealed = encryptEntry(
        name,
        plain[name]!,
        key,
        chunkSize: chunkSize,
      );
      archive.add(
        ArchiveFile.noCompress(
          '$name${PackageEntries.encryptedSuffix}',
          sealed.length,
          sealed,
        ),
      );
    }
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

ArchiveFile _entry(String name, Uint8List bytes) => name == PackageEntries.audio
    // PCM barely compresses; storing it keeps export fast.
    ? ArchiveFile.noCompress(name, bytes.length, bytes)
    : ArchiveFile.bytes(name, bytes);

Uint8List _json(Object? value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

/// What [peekMeetingPackage] can tell without the password.
class PackageHeader {
  /// Creates the header.
  const PackageHeader({required this.encrypted, this.manifest});

  /// Password protected.
  final bool encrypted;

  /// The manifest (null when encrypted).
  final PackageManifest? manifest;
}

Archive _open(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const PackageException(PackageErrorKind.notAPackage, 'zip');
  }
}

Uint8List _read(Archive a, String name) {
  final f = a.find(name);
  if (f == null || !f.isFile) {
    throw PackageException(PackageErrorKind.corrupt, name);
  }
  try {
    final b = f.readBytes();
    if (b == null) throw PackageException(PackageErrorKind.corrupt, name);
    return b;
  } on PackageException {
    rethrow;
  } catch (_) {
    // CRC / inflate errors of a damaged archive.
    throw PackageException(PackageErrorKind.corrupt, name);
  }
}

Object? _decodeJson(Uint8List bytes, String name) {
  try {
    return jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw PackageException(PackageErrorKind.corrupt, name);
  }
}

/// Reads whether [bytes] is an encrypted package and, if not, its manifest.
/// Throws [PackageException] for anything that is not a package.
PackageHeader peekMeetingPackage(Uint8List bytes) {
  final a = _open(bytes);
  if (a.find(PackageEntries.envelope) != null) {
    PackageEnvelope.fromJson(
      _decodeJson(_read(a, PackageEntries.envelope), PackageEntries.envelope),
    );
    return const PackageHeader(encrypted: true);
  }
  if (a.find(PackageEntries.manifest) == null) {
    throw const PackageException(PackageErrorKind.notAPackage, 'manifest');
  }
  return PackageHeader(
    encrypted: false,
    manifest: PackageManifest.fromJson(
      _decodeJson(_read(a, PackageEntries.manifest), PackageEntries.manifest),
    ),
  );
}

/// Decodes and verifies a package. Every entry listed in the manifest must
/// be present with the listed SHA-256 and size (else `tampered` /
/// `corrupt`); an encrypted package needs [password].
Future<MeetingPackage> decodeMeetingPackage(
  Uint8List bytes, {
  String? password,
}) async {
  final a = _open(bytes);
  final envelopeFile = a.find(PackageEntries.envelope);
  final encrypted = envelopeFile != null;
  SecretKeyData? key;
  PackageEnvelope? envelope;
  if (encrypted) {
    envelope = PackageEnvelope.fromJson(
      _decodeJson(_read(a, PackageEntries.envelope), PackageEntries.envelope),
    );
    if (password == null || password.isEmpty) {
      throw const PackageException(PackageErrorKind.passwordRequired);
    }
    key = await derivePackageKey(password, envelope);
  } else if (a.find(PackageEntries.manifest) == null) {
    throw const PackageException(PackageErrorKind.notAPackage, 'manifest');
  }

  Uint8List entry(String name) {
    if (!encrypted) return _read(a, name);
    return decryptEntry(
      name,
      _read(a, '$name${PackageEntries.encryptedSuffix}'),
      key!,
      chunkSize: envelope!.chunkSize,
    );
  }

  final manifest = PackageManifest.fromJson(
    _decodeJson(entry(PackageEntries.manifest), PackageEntries.manifest),
  );
  for (final required in const [
    PackageEntries.transcript,
    PackageEntries.speakers,
  ]) {
    if (!manifest.entries.containsKey(required)) {
      throw PackageException(PackageErrorKind.corrupt, required);
    }
  }
  final verified = <String, Uint8List>{};
  for (final e in manifest.entries.entries) {
    final name = e.key;
    final present = encrypted
        ? a.find('$name${PackageEntries.encryptedSuffix}') != null
        : a.find(name) != null;
    if (!present) throw PackageException(PackageErrorKind.corrupt, name);
    final data = entry(name);
    if (data.length != e.value.size || sha256Hex(data) != e.value.sha256) {
      throw PackageException(PackageErrorKind.tampered, name);
    }
    verified[name] = data;
  }
  final segments = parseTranscriptJson(
    _decodeJson(
      verified[PackageEntries.transcript]!,
      PackageEntries.transcript,
    ),
  );
  final speakers = parseSpeakersJson(
    _decodeJson(verified[PackageEntries.speakers]!, PackageEntries.speakers),
  );
  Minutes? minutes;
  final mBytes = verified[PackageEntries.minutes];
  if (mBytes != null) {
    final j = _decodeJson(mBytes, PackageEntries.minutes);
    try {
      if (j is Map) minutes = Minutes.fromJson(j.cast<String, dynamic>());
    } on TypeError {
      throw const PackageException(
        PackageErrorKind.corrupt,
        PackageEntries.minutes,
      );
    }
  }
  return MeetingPackage(
    manifest: manifest,
    segments: segments,
    speakers: speakers,
    minutes: minutes,
    audioWav: verified[PackageEntries.audio],
    encrypted: encrypted,
  );
}

/// [encodeMeetingPackage] in a background isolate.
Future<Uint8List> encodeMeetingPackageInBackground(
  MeetingPackage package, {
  String? password,
  int kdfIterations = kPackageKdfIterations,
}) => Isolate.run(
  () => encodeMeetingPackage(
    package,
    password: password,
    kdfIterations: kdfIterations,
  ),
  debugName: 'insato-package-encode',
);

/// [decodeMeetingPackage] in a background isolate.
Future<MeetingPackage> decodeMeetingPackageInBackground(
  Uint8List bytes, {
  String? password,
}) => Isolate.run(
  () => decodeMeetingPackage(bytes, password: password),
  debugName: 'insato-package-decode',
);
