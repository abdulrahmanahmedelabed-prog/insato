// Live Insato call (v1.2): signaling protocol.
//
// Two layers travel over one WebSocket to the relay (see
// tools/signaling_server.dart, which implements the server side):
//
// 1. Relay frames (JSON text, readable by the relay):
//      client → relay  {"t":"join","room":<64 hex>,"v":1}
//                      {"t":"relay","d":<base64 sealed blob>}
//                      {"t":"ping"}
//      relay → client  {"t":"joined","peers":<n already in the room>}
//                      {"t":"peer","ev":"join"|"leave"}
//                      {"t":"relay","d":<base64>}
//                      {"t":"pong"}
//                      {"t":"error","code":"full"|"bad"|"rate"|"size"}
//    A room holds at most two clients; the relay forwards `relay` frames to
//    the other one and forgets everything when the room empties.
//
// 2. Sealed call messages inside `d` (the relay cannot read or forge them):
//    the frames of [SecureChannel] (multi_device/secure_channel.dart) under
//    the call key K_call (call_code.dart). After decryption a message is
//    JSON {"t": …}:
//      hello    callee → caller  handshake {v, cn, name, platform}
//      welcome  caller → callee  handshake {v, sn, name, platform}
//      ready    callee → caller  session   {}         (proves the keys)
//      offer    caller → callee  session   {sdp}
//      answer   callee → caller  session   {sdp}
//      ice      both             session   {c, mid, idx}
//      bye      both             session   {reason}
//    Handshake frames are sealed with K_call and bind the direction; session
//    frames use per-connection keys HKDF(K_call, cn‖sn) with strictly
//    increasing counters (no replay / reorder).
//
// Peer authentication. The SDP carries each side's DTLS certificate
// fingerprint (`a=fingerprint:`); since the SDP is sealed with a key only
// code holders have, a relay cannot substitute its own certificate, and
// WebRTC's DTLS refuses any other certificate. On top of that, once the
// data channel opens, each side sends MAC(K_call, role ‖ own fingerprint ‖
// peer fingerprint) (data_messages.dart, `auth`), checked against the
// fingerprints seen in the signaled SDPs; and both screens show the same
// short safety code derived from K_call and both fingerprints.
//
// Pure Dart.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'call_code.dart' show kLiveCallProtocolVersion;

// ---------------------------------------------------------------------------
// Relay frames
// ---------------------------------------------------------------------------

/// Largest sealed blob a client sends (SDP with many candidates ≈ 6 KB).
const int kMaxRelayPayloadBytes = 32 * 1024;

/// A frame exchanged with the relay.
sealed class RelayFrame {
  const RelayFrame();

  /// JSON text of the frame.
  String encode();

  /// Parses a frame; null when malformed.
  static RelayFrame? decode(Object? text) {
    if (text is! String || text.length > kMaxRelayPayloadBytes * 2) {
      return null;
    }
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (j is! Map) return null;
    switch (j['t']) {
      case 'join':
        final room = j['room'];
        if (room is! String || !isValidRoomId(room)) return null;
        return RelayJoin(room, version: j['v'] is int ? j['v'] as int : 0);
      case 'joined':
        final n = j['peers'];
        return n is int ? RelayJoined(n) : null;
      case 'peer':
        return switch (j['ev']) {
          'join' => const RelayPeerEvent(joined: true),
          'leave' => const RelayPeerEvent(joined: false),
          _ => null,
        };
      case 'relay':
        final d = j['d'];
        if (d is! String) return null;
        try {
          return RelayData(base64.decode(d));
        } on FormatException {
          return null;
        }
      case 'ping':
        return const RelayPing();
      case 'pong':
        return const RelayPong();
      case 'error':
        return RelayError(j['code'] is String ? j['code'] as String : 'bad');
    }
    return null;
  }
}

/// True for a 64-character lower-case hex room id.
bool isValidRoomId(String room) => RegExp(r'^[0-9a-f]{64}$').hasMatch(room);

/// Client asks to enter a room.
class RelayJoin extends RelayFrame {
  /// Creates the frame.
  const RelayJoin(this.room, {this.version = kLiveCallProtocolVersion});

  /// Room id.
  final String room;

  /// Protocol version.
  final int version;

  @override
  String encode() => jsonEncode({'t': 'join', 'room': room, 'v': version});
}

/// Relay confirms the join; [peers] were already in the room.
class RelayJoined extends RelayFrame {
  /// Creates the frame.
  const RelayJoined(this.peers);

  /// Clients already present (0 or 1).
  final int peers;

  @override
  String encode() => jsonEncode({'t': 'joined', 'peers': peers});
}

/// The other client entered or left the room.
class RelayPeerEvent extends RelayFrame {
  /// Creates the frame.
  const RelayPeerEvent({required this.joined});

  /// True on join, false on leave.
  final bool joined;

  @override
  String encode() => jsonEncode({'t': 'peer', 'ev': joined ? 'join' : 'leave'});
}

/// A sealed blob for the other client.
class RelayData extends RelayFrame {
  /// Creates the frame.
  const RelayData(this.data);

  /// Sealed bytes.
  final Uint8List data;

  @override
  String encode() => jsonEncode({'t': 'relay', 'd': base64.encode(data)});
}

/// Keep-alive request.
class RelayPing extends RelayFrame {
  /// Creates the frame.
  const RelayPing();

  @override
  String encode() => '{"t":"ping"}';
}

/// Keep-alive answer.
class RelayPong extends RelayFrame {
  /// Creates the frame.
  const RelayPong();

  @override
  String encode() => '{"t":"pong"}';
}

/// Relay error (`full`: two clients already in the room).
class RelayError extends RelayFrame {
  /// Creates the frame.
  const RelayError(this.code);

  /// Error code.
  final String code;

  @override
  String encode() => jsonEncode({'t': 'error', 'code': code});
}

// ---------------------------------------------------------------------------
// Sealed call messages
// ---------------------------------------------------------------------------

/// A call message (before sealing / after opening).
class CallMessage {
  /// Creates a message of [type] with [body].
  const CallMessage(this.type, [this.body = const {}]);

  /// Message type (`hello`, `welcome`, `ready`, `offer`, `answer`, `ice`,
  /// `bye`).
  final String type;

  /// Fields besides the type.
  final Map<String, Object?> body;

  /// Callee hello.
  factory CallMessage.hello({
    required List<int> clientNonce,
    required String name,
    required String platform,
  }) => CallMessage('hello', {
    'v': kLiveCallProtocolVersion,
    'cn': base64.encode(clientNonce),
    'name': name,
    'platform': platform,
  });

  /// Caller welcome.
  factory CallMessage.welcome({
    required List<int> serverNonce,
    required String name,
    required String platform,
  }) => CallMessage('welcome', {
    'v': kLiveCallProtocolVersion,
    'sn': base64.encode(serverNonce),
    'name': name,
    'platform': platform,
  });

  /// Callee proof of the session keys.
  factory CallMessage.ready() => const CallMessage('ready');

  /// SDP offer.
  factory CallMessage.offer(String sdp) => CallMessage('offer', {'sdp': sdp});

  /// SDP answer.
  factory CallMessage.answer(String sdp) => CallMessage('answer', {'sdp': sdp});

  /// ICE candidate.
  factory CallMessage.ice(IceCandidateData c) => CallMessage('ice', {
    'c': c.candidate,
    'mid': c.sdpMid,
    'idx': c.sdpMLineIndex,
  });

  /// Hang-up.
  factory CallMessage.bye([String reason = 'hangup']) =>
      CallMessage('bye', {'reason': reason});

  /// UTF-8 JSON bytes.
  Uint8List encode() =>
      Uint8List.fromList(utf8.encode(jsonEncode({'t': type, ...body})));

  /// Parses [bytes]; null when malformed.
  static CallMessage? decode(List<int> bytes) {
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (j is! Map || j['t'] is! String) return null;
    return CallMessage(j['t'] as String, {
      for (final e in j.entries)
        if (e.key is String && e.key != 't') e.key as String: e.value,
    });
  }

  /// String field [key] ('' when absent).
  String str(String key) => body[key] is String ? body[key] as String : '';

  /// Base64 field [key] decoded (null when absent / malformed).
  Uint8List? bytes(String key) {
    final v = body[key];
    if (v is! String) return null;
    try {
      return base64.decode(v);
    } on FormatException {
      return null;
    }
  }

  /// The candidate of an `ice` message (null when malformed).
  IceCandidateData? get candidate {
    final c = body['c'];
    if (c is! String || c.length > 2048) return null;
    final mid = body['mid'];
    final idx = body['idx'];
    return IceCandidateData(
      candidate: c,
      sdpMid: mid is String ? mid : null,
      sdpMLineIndex: idx is int ? idx : null,
    );
  }
}

/// An ICE candidate as signaled.
class IceCandidateData {
  /// Creates a candidate.
  const IceCandidateData({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  /// `candidate:` line.
  final String candidate;

  /// Media id.
  final String? sdpMid;

  /// Media line index.
  final int? sdpMLineIndex;

  /// True for a relay (TURN) candidate.
  bool get isRelay => candidate.contains(' typ relay');

  @override
  bool operator ==(Object other) =>
      other is IceCandidateData &&
      other.candidate == candidate &&
      other.sdpMid == sdpMid &&
      other.sdpMLineIndex == sdpMLineIndex;

  @override
  int get hashCode => Object.hash(candidate, sdpMid, sdpMLineIndex);
}

// ---------------------------------------------------------------------------
// DTLS fingerprints, MACs and the safety code
// ---------------------------------------------------------------------------

/// The DTLS certificate fingerprints in [sdp] (`a=fingerprint:<alg> <hex>`),
/// normalised to `alg HEX` (algorithm lower case, hex upper case without
/// spaces). Session-level and media-level lines are both returned, without
/// duplicates.
List<String> sdpFingerprints(String sdp) {
  final out = <String>{};
  for (final raw in const LineSplitter().convert(sdp)) {
    final line = raw.trim();
    if (!line.startsWith('a=fingerprint:')) continue;
    final parts = line.substring('a=fingerprint:'.length).trim().split(
      RegExp(r'\s+'),
    );
    if (parts.length != 2) continue;
    out.add('${parts[0].toLowerCase()} ${parts[1].toUpperCase()}');
  }
  return out.toList();
}

/// The single fingerprint of [sdp]; null when it has none or several
/// different ones (we only ever create one certificate per connection).
String? sdpFingerprint(String sdp) {
  final f = sdpFingerprints(sdp);
  return f.length == 1 ? f.single : null;
}

/// MAC proving that the sender (of [role] `caller` / `callee`) knows the
/// call key and sees the fingerprints [own] (its certificate) and [peer]
/// (the certificate it received).
Future<Uint8List> fingerprintMac({
  required SecretKey callKey,
  required String role,
  required String own,
  required String peer,
}) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('insato-call v1 fp|$role|$own|$peer'),
    secretKey: callKey,
  );
  return Uint8List.fromList(mac.bytes);
}

/// Constant-time comparison.
bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}

/// Six-digit safety code both screens show: HMAC(K_call, sorted
/// fingerprints) → 0…999999, formatted `123 456`. Equal on both devices
/// exactly when they share the code and see the same two certificates.
Future<String> safetyCode({
  required SecretKey callKey,
  required String fingerprintA,
  required String fingerprintB,
}) async {
  final pair = [fingerprintA, fingerprintB]..sort();
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('insato-call v1 sas|${pair[0]}|${pair[1]}'),
    secretKey: callKey,
  );
  final b = mac.bytes;
  final n =
      ((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]) & 0x7fffffff;
  final s = (n % 1000000).toString().padLeft(6, '0');
  return '${s.substring(0, 3)} ${s.substring(3)}';
}
