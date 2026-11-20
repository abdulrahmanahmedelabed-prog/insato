// Optional password protection of a meeting package.
//
// Key: PBKDF2-HMAC-SHA256(password, 16-byte random salt, [iterations]) →
// 256-bit key. Every entry is encrypted with AES-256-GCM in chunks of
// [kPackageChunkSize] bytes so a long recording never needs one huge
// buffer:
//
//   entry.enc = prefix (8 random bytes) ‖ Σ chunk_i (ciphertext ‖ 16-byte tag)
//   nonce_i   = prefix ‖ uint32 big-endian i
//   aad_i     = "insato-pkg-v1|" ‖ entry name ‖ "|" ‖ i ‖ "|" ‖ last (0/1)
//
// The entry name in the AAD stops entries from being swapped, the chunk
// index stops chunks from being reordered, and the "last" flag detects a
// file truncated at a chunk boundary. A wrong password and modified
// ciphertext both fail authentication (they cannot be told apart).
//
// Pure Dart (package:cryptography's Dart implementation, synchronous calls),
// so it runs in a background isolate.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'package_format.dart';

/// Plaintext bytes per encrypted chunk.
const int kPackageChunkSize = 1 << 20;

/// Default PBKDF2 iterations.
const int kPackageKdfIterations = 150000;

const int _tagLength = 16;
const int _prefixLength = 8;

/// Parameters stored in `envelope.json`.
class PackageEnvelope {
  /// Creates the envelope.
  const PackageEnvelope({
    required this.salt,
    required this.iterations,
    this.chunkSize = kPackageChunkSize,
  });

  /// PBKDF2 salt.
  final Uint8List salt;

  /// PBKDF2 iterations.
  final int iterations;

  /// Plaintext bytes per chunk.
  final int chunkSize;

  /// New envelope with a random salt.
  factory PackageEnvelope.random({int iterations = kPackageKdfIterations}) {
    final r = math.Random.secure();
    return PackageEnvelope(
      salt: Uint8List.fromList([for (var i = 0; i < 16; i++) r.nextInt(256)]),
      iterations: iterations,
    );
  }

  /// JSON form.
  Map<String, Object?> toJson() => {
    'format': kPackageFormatId,
    'format_version': kPackageFormatVersion,
    'encryption': {
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'chunk_size': chunkSize,
    },
  };

  /// Parses [toJson] output. Throws [PackageException].
  static PackageEnvelope fromJson(Object? j) {
    if (j is! Map || j['format'] != kPackageFormatId) {
      throw const PackageException(PackageErrorKind.notAPackage, 'envelope');
    }
    final v = j['format_version'];
    if (v is int && v > kPackageFormatVersion) {
      throw PackageException(PackageErrorKind.unsupportedVersion, '$v');
    }
    final e = j['encryption'];
    if (e is! Map ||
        e['cipher'] != 'AES-256-GCM' ||
        e['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        e['iterations'] is! int ||
        e['salt'] is! String) {
      throw const PackageException(PackageErrorKind.corrupt, 'envelope');
    }
    final iterations = e['iterations'] as int;
    final chunk = e['chunk_size'] is int ? e['chunk_size'] as int : 0;
    if (iterations < 1 || iterations > 10000000 || chunk < 1024) {
      throw const PackageException(PackageErrorKind.corrupt, 'envelope');
    }
    try {
      return PackageEnvelope(
        salt: base64Decode(e['salt'] as String),
        iterations: iterations,
        chunkSize: chunk,
      );
    } on FormatException {
      throw const PackageException(PackageErrorKind.corrupt, 'envelope');
    }
  }
}

/// Derives the 256-bit package key from [password].
Future<SecretKeyData> derivePackageKey(
  String password,
  PackageEnvelope envelope,
) async {
  final kdf = DartPbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: envelope.iterations,
    bits: 256,
    // Runs in a background isolate: no need to yield to an event loop.
    pauseFrequency: 1 << 30,
  );
  final key = await kdf.deriveKeyFromPassword(
    password: password,
    nonce: envelope.salt,
  );
  return SecretKeyData(await key.extractBytes());
}

final DartAesGcm _aes = DartAesGcm.with256bits();

List<int> _aad(String name, int index, bool last) =>
    utf8.encode('insato-pkg-v1|$name|$index|${last ? 1 : 0}');

List<int> _nonce(Uint8List prefix, int index) {
  final n = Uint8List(12)..setRange(0, _prefixLength, prefix);
  ByteData.sublistView(n).setUint32(_prefixLength, index, Endian.big);
  return n;
}

/// Encrypts entry [name] with [key] (see the file comment for the layout).
Uint8List encryptEntry(
  String name,
  Uint8List plain,
  SecretKeyData key, {
  int chunkSize = kPackageChunkSize,
  math.Random? random,
}) {
  final r = random ?? math.Random.secure();
  final prefix = Uint8List.fromList([
    for (var i = 0; i < _prefixLength; i++) r.nextInt(256),
  ]);
  final chunks = plain.isEmpty
      ? 1
      : (plain.length + chunkSize - 1) ~/ chunkSize;
  final out = Uint8List(_prefixLength + plain.length + chunks * _tagLength)
    ..setRange(0, _prefixLength, prefix);
  var o = _prefixLength;
  for (var i = 0; i < chunks; i++) {
    final start = i * chunkSize;
    final end = math.min(plain.length, start + chunkSize);
    final box = _aes.encryptSync(
      Uint8List.sublistView(plain, start, end),
      secretKeyData: key,
      nonce: _nonce(prefix, i),
      aad: _aad(name, i, i == chunks - 1),
    );
    out.setRange(o, o + box.cipherText.length, box.cipherText);
    o += box.cipherText.length;
    out.setRange(o, o + _tagLength, box.mac.bytes);
    o += _tagLength;
  }
  return out;
}

/// Decrypts entry [name]. Throws [PackageException] (`wrongPassword`) when
/// authentication fails and `corrupt` when the layout is impossible.
Uint8List decryptEntry(
  String name,
  Uint8List data,
  SecretKeyData key, {
  int chunkSize = kPackageChunkSize,
}) {
  if (data.length < _prefixLength + _tagLength) {
    throw PackageException(PackageErrorKind.corrupt, name);
  }
  final prefix = Uint8List.sublistView(data, 0, _prefixLength);
  final body = data.length - _prefixLength;
  final full = chunkSize + _tagLength;
  final chunks = (body + full - 1) ~/ full;
  final plainLength = body - chunks * _tagLength;
  final rem = body % full;
  if (plainLength < 0 || (rem != 0 && rem < _tagLength)) {
    throw PackageException(PackageErrorKind.corrupt, name);
  }
  final out = Uint8List(plainLength);
  var i0 = _prefixLength;
  var o = 0;
  for (var i = 0; i < chunks; i++) {
    final ctLen = math.min(chunkSize, data.length - i0 - _tagLength);
    if (ctLen < 0) throw PackageException(PackageErrorKind.corrupt, name);
    final box = SecretBox(
      Uint8List.sublistView(data, i0, i0 + ctLen),
      nonce: _nonce(prefix, i),
      mac: Mac(
        Uint8List.sublistView(data, i0 + ctLen, i0 + ctLen + _tagLength),
      ),
    );
    final List<int> plain;
    try {
      plain = _aes.decryptSync(
        box,
        secretKeyData: key,
        aad: _aad(name, i, i == chunks - 1),
      );
    } on SecretBoxAuthenticationError {
      throw PackageException(PackageErrorKind.wrongPassword, name);
    }
    out.setRange(o, o + plain.length, plain);
    o += plain.length;
    i0 += ctLen + _tagLength;
  }
  return out;
}
