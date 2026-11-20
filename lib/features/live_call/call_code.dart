// Live Insato call (v1.2): call codes, the QR payload and the keys derived
// from a code.
//
// A call is identified by a 12-character Crockford base32 code (60 random
// bits, shown as `K7QM-2XPA-9DTR`, same alphabet and normalisation as the
// multi-device join code). The code never travels over the network:
//
//   K      = PBKDF2-HMAC-SHA256(code, 60 000 iterations)   (multi_device)
//   K_call = HKDF-SHA256(K, info = "insato-call v1 key")   → seals signaling
//   room   = HKDF-SHA256(K, info = "insato-call v1 room")  → relay room id
//
// The relay (signaling server) only ever sees the room id — a one-way hash
// of the code — and sealed blobs it cannot open or forge.
//
// QR payload: `insato://call?v=1&k=<code>&u=<signaling url>&n=<name>`.
// The URL lets a joiner use the caller's relay without configuring one.
//
// Pure Dart.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../multi_device/protocol.dart'
    show formatPairingCode, normalizePairingCode, randomBase32;
import '../multi_device/secure_channel.dart'
    show derivePairingKey, kPairingKdfIterations;

export '../multi_device/protocol.dart'
    show formatPairingCode, normalizePairingCode;

/// Version of the live-call protocol (QR, relay and data channel).
const int kLiveCallProtocolVersion = 1;

/// Length of a call code.
const int kCallCodeLength = 12;

/// A new random call code.
String newCallCode() => randomBase32(kCallCodeLength);

/// Keys of one call, derived from its code.
class CallKeys {
  /// Creates the keys.
  const CallKeys({required this.callKey, required this.roomId});

  /// Key sealing every signaling message (and the fingerprint MACs).
  final SecretKeyData callKey;

  /// Relay room id (64 hex characters).
  final String roomId;
}

/// Derives [CallKeys] from a normalised [code]. [iterations] is lowered in
/// tests only.
Future<CallKeys> deriveCallKeys(
  String code, {
  int iterations = kPairingKdfIterations,
}) async {
  final base = await derivePairingKey(code, iterations: iterations);
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  Future<List<int>> expand(String info) async => (await hkdf.deriveKey(
    secretKey: base,
    nonce: utf8.encode('insato-call'),
    info: utf8.encode(info),
  )).extractBytes();
  final key = SecretKeyData(await expand('insato-call v1 key'));
  final room = await expand('insato-call v1 room');
  return CallKeys(callKey: key, roomId: hexOf(room));
}

/// Lower-case hex of [bytes].
String hexOf(List<int> bytes) {
  final b = StringBuffer();
  for (final x in bytes) {
    b.write(x.toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}

/// Normalises a signaling URL typed by the user: trims it, accepts `https`
/// / `http` as `wss` / `ws`, and requires a host. Returns null when it is
/// not a usable WebSocket URL. Plain `ws://` is accepted (the relay only
/// carries sealed messages) but the UI recommends `wss://`.
String? normalizeSignalingUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'wss://$s';
  final Uri uri;
  try {
    uri = Uri.parse(s);
  } on FormatException {
    return null;
  }
  final scheme = switch (uri.scheme.toLowerCase()) {
    'wss' || 'https' => 'wss',
    'ws' || 'http' => 'ws',
    _ => null,
  };
  if (scheme == null || uri.host.isEmpty) return null;
  return uri.replace(scheme: scheme).toString();
}

/// Everything a joiner needs (QR payload or typed code).
class CallInvite {
  /// Creates an invite.
  const CallInvite({
    required this.code,
    this.signalingUrl,
    this.callerName = '',
  });

  /// Normalised call code.
  final String code;

  /// Relay URL of the caller (null: the joiner's configured relay).
  final String? signalingUrl;

  /// Caller's device name (display only; the authenticated name comes from
  /// the handshake).
  final String callerName;

  /// The code as shown to people (`K7QM-2XPA-9DTR`).
  String get displayCode => formatPairingCode(code);

  /// QR payload.
  String toUri() => Uri(
    scheme: 'insato',
    host: 'call',
    queryParameters: {
      'v': '$kLiveCallProtocolVersion',
      'k': code,
      'u': ?signalingUrl,
      if (callerName.isNotEmpty) 'n': callerName,
    },
  ).toString();

  /// Parses a QR payload or a typed code (`K7QM-2XPA-9DTR`); null when it is
  /// neither.
  static CallInvite? tryParse(String text) {
    final t = text.trim();
    final typed = normalizePairingCode(t);
    if (typed != null) return CallInvite(code: typed);
    final Uri uri;
    try {
      uri = Uri.parse(t);
    } on FormatException {
      return null;
    }
    if (uri.scheme != 'insato' || uri.host != 'call') return null;
    final q = uri.queryParameters;
    if (q['v'] != '$kLiveCallProtocolVersion') return null;
    final code = normalizePairingCode(q['k'] ?? '');
    if (code == null) return null;
    final rawUrl = q['u'];
    final url = rawUrl == null ? null : normalizeSignalingUrl(rawUrl);
    if (rawUrl != null && url == null) return null;
    return CallInvite(code: code, signalingUrl: url, callerName: q['n'] ?? '');
  }
}
