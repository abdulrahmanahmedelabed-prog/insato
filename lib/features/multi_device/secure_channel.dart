// Encryption and authentication of multi-device traffic (v1.2 C).
//
// Keys:
// * pairing key K = PBKDF2-HMAC-SHA256(pairing code, fixed salt,
//   [kPairingKdfIterations], 256 bits). The 60-bit random code shown by the
//   host (QR or typed) never travels over the network; the iterations make
//   an offline guess against recorded traffic cost 2^60 × PBKDF2 runs.
// * per connection: the guest's hello carries a random 16-byte client nonce
//   `cn`, the host's welcome a random 16-byte server nonce `sn`;
//   both derive k_c2s / k_s2c = HKDF-SHA256(K, salt = cn‖sn,
//   info = "insato-md1 c2s" / "insato-md1 s2c").
//
// Framing: every WebSocket binary frame is
//   [phase byte][12-byte nonce][ChaCha20-Poly1305 ciphertext + 16-byte tag]
// * phase 0 (handshake) is sealed with K and a random nonce; the associated
//   data names the direction, so a host message can never be reflected to
//   the host (and vice versa);
// * phase 1 (session) is sealed with the direction's connection key; the
//   nonce is the 64-bit message counter, which must strictly increase:
//   replayed, reordered or dropped-and-reinjected frames are rejected.
//
// A frame that fails authentication is an unknown peer (or a wrong code):
// the connection is closed without an answer. Replaying a recorded hello
// gets a fresh server nonce, so the replayer can never produce the guest's
// `ready` (which needs k_c2s); the host additionally refuses a client nonce
// it has already seen in this meeting.
//
// Pure Dart (package:cryptography's pure-Dart ChaCha20-Poly1305, so the same
// code runs on Android, iOS, Windows and in tests).

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// PBKDF2 iterations of the pairing key.
const int kPairingKdfIterations = 60000;

const String _salt = 'insato-multi-device-v1';

/// Phase byte of handshake frames.
const int kPhaseHandshake = 0;

/// Phase byte of session frames.
const int kPhaseSession = 1;

const int _nonceLength = 12;
const int _macLength = 16;

const DartChacha20 _aead = DartChacha20.poly1305Aead();

/// Derives the pairing key from a normalised pairing code (in a background
/// isolate for the real iteration count: ~0.5 s of CPU).
Future<SecretKeyData> derivePairingKey(
  String code, {
  int iterations = kPairingKdfIterations,
}) async {
  if (iterations > 1000) {
    final bytes = await Isolate.run(
      () => _derive(code, iterations),
      debugName: 'insato-pairing-key',
    );
    return SecretKeyData(bytes);
  }
  return SecretKeyData(await _derive(code, iterations));
}

Future<List<int>> _derive(String code, int iterations) async {
  final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final key = await kdf.deriveKeyFromPassword(
    password: code,
    nonce: utf8.encode(_salt),
  );
  return key.extractBytes();
}

/// Derives the two connection keys `(c2s, s2c)`.
Future<(SecretKeyData, SecretKeyData)> deriveConnectionKeys(
  SecretKeyData pairingKey,
  List<int> clientNonce,
  List<int> serverNonce,
) async {
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final salt = [...clientNonce, ...serverNonce];
  Future<SecretKeyData> one(String info) async => SecretKeyData(
    await (await hkdf.deriveKey(
      secretKey: pairingKey,
      nonce: salt,
      info: utf8.encode(info),
    )).extractBytes(),
  );
  return (await one('insato-md1 c2s'), await one('insato-md1 s2c'));
}

/// Random bytes from a secure source.
Uint8List secureRandomBytes(int n, [math.Random? random]) {
  final r = random ?? math.Random.secure();
  return Uint8List.fromList([for (var i = 0; i < n; i++) r.nextInt(256)]);
}

/// One side of an encrypted connection.
class SecureChannel {
  /// Creates the channel of the host ([isHost]) or a guest.
  SecureChannel({required this.pairingKey, required this.isHost});

  /// The pairing key K.
  final SecretKeyData pairingKey;

  /// True on the host side.
  final bool isHost;

  SecretKeyData? _sendKey;
  SecretKeyData? _receiveKey;
  int _sendCounter = 0;
  int _receiveCounter = 0;

  /// True once the connection keys are installed.
  bool get hasSessionKeys => _sendKey != null;

  String get _sendDir => isHost ? 's2c' : 'c2s';
  String get _receiveDir => isHost ? 'c2s' : 's2c';

  static List<int> _aad(int phase, String dir) =>
      utf8.encode('insato-md1|$phase|$dir');

  /// Installs the connection keys derived from both nonces.
  Future<void> establish(List<int> clientNonce, List<int> serverNonce) async {
    final (c2s, s2c) = await deriveConnectionKeys(
      pairingKey,
      clientNonce,
      serverNonce,
    );
    _sendKey = isHost ? s2c : c2s;
    _receiveKey = isHost ? c2s : s2c;
    _sendCounter = 0;
    _receiveCounter = 0;
  }

  /// Seals a handshake message with the pairing key.
  Uint8List sealHandshake(Uint8List message) => _seal(
    kPhaseHandshake,
    pairingKey,
    secureRandomBytes(_nonceLength),
    message,
    _sendDir,
  );

  /// Opens a handshake frame; null when it is not authentic.
  Uint8List? openHandshake(Uint8List frame) =>
      _open(frame, kPhaseHandshake, pairingKey, _receiveDir);

  /// Seals a session message (requires [establish]).
  Uint8List seal(Uint8List message) {
    final key = _sendKey;
    if (key == null) throw StateError('No session keys');
    final nonce = Uint8List(_nonceLength);
    ByteData.sublistView(nonce).setUint64(4, ++_sendCounter);
    return _seal(kPhaseSession, key, nonce, message, _sendDir);
  }

  /// Opens a session frame; null when not authentic or replayed.
  Uint8List? open(Uint8List frame) {
    final key = _receiveKey;
    if (key == null || frame.length < 1 + _nonceLength + _macLength) {
      return null;
    }
    final counter = ByteData.sublistView(
      frame,
      1,
      1 + _nonceLength,
    ).getUint64(4);
    if (counter <= _receiveCounter) return null;
    final out = _open(frame, kPhaseSession, key, _receiveDir);
    if (out != null) _receiveCounter = counter;
    return out;
  }

  /// Phase byte of [frame] (null when empty).
  static int? phaseOf(Uint8List frame) => frame.isEmpty ? null : frame[0];

  static Uint8List _seal(
    int phase,
    SecretKeyData key,
    Uint8List nonce,
    Uint8List message,
    String dir,
  ) {
    final box = _aead.encryptSync(
      message,
      secretKey: key,
      nonce: nonce,
      aad: _aad(phase, dir),
    );
    final out = Uint8List(
      1 + _nonceLength + box.cipherText.length + _macLength,
    );
    out[0] = phase;
    out.setRange(1, 1 + _nonceLength, nonce);
    out.setRange(
      1 + _nonceLength,
      1 + _nonceLength + box.cipherText.length,
      box.cipherText,
    );
    out.setRange(out.length - _macLength, out.length, box.mac.bytes);
    return out;
  }

  static Uint8List? _open(
    Uint8List frame,
    int phase,
    SecretKeyData key,
    String dir,
  ) {
    if (frame.length < 1 + _nonceLength + _macLength || frame[0] != phase) {
      return null;
    }
    final box = SecretBox(
      Uint8List.sublistView(frame, 1 + _nonceLength, frame.length - _macLength),
      nonce: Uint8List.sublistView(frame, 1, 1 + _nonceLength),
      mac: Mac(Uint8List.sublistView(frame, frame.length - _macLength)),
    );
    try {
      final clear = _aead.decryptSync(
        box,
        secretKey: key,
        aad: _aad(phase, dir),
      );
      return clear is Uint8List ? clear : Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      return null;
    } catch (_) {
      return null;
    }
  }
}
