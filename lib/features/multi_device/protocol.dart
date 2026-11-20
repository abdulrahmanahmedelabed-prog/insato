// Multi-device wire protocol (v1.2 C): join codes, QR payload, messages.
//
// Joining. The host shows a QR code and, for manual entry, a 12-character
// pairing code (Crockford base32, 60 random bits, shown as `K7QM-2XPA-9DTR`)
// plus its LAN address and port. The QR payload is
//
//   insato://join?v=1&s=<session id>&a=<ip>[,<ip>…]&p=<port>&k=<code>&n=<name>
//
// The session key is derived from the pairing code (see secure_channel.dart);
// the code never travels over the network.
//
// Messages travel inside encrypted WebSocket binary frames. After
// decryption a message is `type byte + body`:
//
//   0x01 hello    guest → host  JSON {v, id, name, platform, cn}
//   0x02 welcome  host → guest  JSON {v, sid, sn, title, state, host}
//   0x03 reject   host → guest  JSON {reason}
//   0x04 ready    guest → host  JSON {}
//   0x10 audio    guest → host  binary: seq u32, start index u64,
//                               capture µs i64, encoded PCM (pcm_codec.dart)
//   0x11 control  both ways     JSON {t: ping|pong|status|state|kick|bye, …}
//
// Pure Dart.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'fusion_engine.dart' show GuestAudioFrame;
import 'pcm_codec.dart';

/// Protocol version.
const int kMultiDeviceProtocolVersion = 1;

/// mDNS / DNS-SD service type of Insato hosts.
const String kMultiDeviceServiceType = '_insato._tcp';

/// WebSocket path on the host.
const String kMultiDevicePath = '/insato/v1';

/// Maximum number of guests per meeting.
const int kMaxGuests = 4;

/// Crockford base32 alphabet (no I, L, O, U).
const String _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Length of the pairing code.
const int kPairingCodeLength = 12;

/// A random [length]-character Crockford base32 string.
String randomBase32(int length, [math.Random? random]) {
  final r = random ?? math.Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < length; i++) _crockford.codeUnitAt(r.nextInt(32)),
  ]);
}

/// Normalises a typed pairing code: upper case, separators removed,
/// I/L → 1, O → 0. Returns null unless exactly [kPairingCodeLength]
/// valid characters remain.
String? normalizePairingCode(String input) {
  final b = StringBuffer();
  for (final ch in input.toUpperCase().split('')) {
    if (ch == '-' || ch == ' ' || ch == '_' || ch.trim().isEmpty) continue;
    final c = switch (ch) {
      'I' || 'L' => '1',
      'O' => '0',
      final x => x,
    };
    if (!_crockford.contains(c)) return null;
    b.write(c);
  }
  final s = b.toString();
  return s.length == kPairingCodeLength ? s : null;
}

/// `K7QM2XPA9DTR` → `K7QM-2XPA-9DTR`.
String formatPairingCode(String code) {
  final parts = <String>[];
  for (var i = 0; i < code.length; i += 4) {
    parts.add(code.substring(i, math.min(code.length, i + 4)));
  }
  return parts.join('-');
}

/// Everything a guest needs to join.
class JoinInfo {
  /// Creates join information.
  const JoinInfo({
    required this.sessionId,
    required this.addresses,
    required this.port,
    required this.code,
    this.hostName = '',
  });

  /// Random session id (also advertised over mDNS).
  final String sessionId;

  /// Host LAN addresses (IPv4 first).
  final List<String> addresses;

  /// WebSocket port.
  final int port;

  /// Normalised pairing code.
  final String code;

  /// Host device name (display only).
  final String hostName;

  /// QR payload.
  String toUri() => Uri(
    scheme: 'insato',
    host: 'join',
    queryParameters: {
      'v': '$kMultiDeviceProtocolVersion',
      's': sessionId,
      'a': addresses.join(','),
      'p': '$port',
      'k': code,
      if (hostName.isNotEmpty) 'n': hostName,
    },
  ).toString();

  /// Address shown for manual entry (`192.168.1.5:47800`).
  String get displayAddress =>
      addresses.isEmpty ? '' : formatHostPort(addresses.first, port);

  /// Parses a QR payload; null when it is not an Insato join code.
  static JoinInfo? tryParse(String text) {
    final Uri uri;
    try {
      uri = Uri.parse(text.trim());
    } on FormatException {
      return null;
    }
    if (uri.scheme != 'insato' || uri.host != 'join') return null;
    final q = uri.queryParameters;
    if (q['v'] != '$kMultiDeviceProtocolVersion') return null;
    final port = int.tryParse(q['p'] ?? '');
    final code = normalizePairingCode(q['k'] ?? '');
    final sid = q['s'] ?? '';
    final addrs = [
      for (final a in (q['a'] ?? '').split(','))
        if (a.trim().isNotEmpty) a.trim(),
    ];
    if (port == null || port <= 0 || port > 65535 || code == null) return null;
    if (sid.isEmpty || addrs.isEmpty) return null;
    return JoinInfo(
      sessionId: sid,
      addresses: addrs,
      port: port,
      code: code,
      hostName: q['n'] ?? '',
    );
  }
}

/// `host:port`, IPv6 in brackets.
String formatHostPort(String host, int port) =>
    host.contains(':') ? '[$host]:$port' : '$host:$port';

/// Parses `192.168.1.5:47800` / `[fe80::1]:47800` / `host` (with
/// [defaultPort]); null when malformed.
(String, int)? parseHostPort(String input, {int? defaultPort}) {
  final s = input.trim();
  if (s.isEmpty) return null;
  String host;
  String? portText;
  if (s.startsWith('[')) {
    final close = s.indexOf(']');
    if (close < 0) return null;
    host = s.substring(1, close);
    final rest = s.substring(close + 1);
    if (rest.isNotEmpty) {
      if (!rest.startsWith(':')) return null;
      portText = rest.substring(1);
    }
  } else if (s.split(':').length == 2) {
    final i = s.indexOf(':');
    host = s.substring(0, i);
    portText = s.substring(i + 1);
  } else {
    host = s;
  }
  if (host.isEmpty || host.contains(' ')) return null;
  final port = portText == null ? defaultPort : int.tryParse(portText);
  if (port == null || port <= 0 || port > 65535) return null;
  return (host, port);
}

/// Message type bytes.
abstract final class MsgType {
  /// Guest hello (handshake).
  static const int hello = 0x01;

  /// Host welcome (handshake).
  static const int welcome = 0x02;

  /// Host rejection (handshake).
  static const int reject = 0x03;

  /// Guest ready (first session-key message).
  static const int ready = 0x04;

  /// Audio frame.
  static const int audio = 0x10;

  /// JSON control message.
  static const int control = 0x11;
}

/// Reasons a host rejects a guest.
abstract final class RejectReason {
  /// Already [kMaxGuests] guests.
  static const String full = 'full';

  /// The host removed this device earlier in the meeting.
  static const String removed = 'removed';

  /// Incompatible protocol version.
  static const String version = 'version';

  /// The meeting has ended.
  static const String ended = 'ended';
}

/// Host meeting states sent to guests.
abstract final class HostState {
  /// Waiting for the meeting to start.
  static const String lobby = 'lobby';

  /// Recording: guests stream audio.
  static const String recording = 'recording';

  /// Paused: guests stop streaming.
  static const String paused = 'paused';

  /// Meeting over.
  static const String ended = 'ended';
}

/// `type + JSON` message bytes.
Uint8List encodeJsonMessage(int type, Map<String, Object?> body) {
  final json = utf8.encode(jsonEncode(body));
  return Uint8List(json.length + 1)
    ..[0] = type
    ..setRange(1, json.length + 1, json);
}

/// Decodes the JSON body of a message; throws [FormatException].
Map<String, Object?> decodeJsonBody(Uint8List message) {
  final d = jsonDecode(utf8.decode(Uint8List.sublistView(message, 1)));
  if (d is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object');
  }
  return d;
}

/// Encodes an audio message.
Uint8List encodeAudioMessage(GuestAudioFrame f) {
  final pcm = encodePcm16(floatToInt16(f.samples));
  final out = Uint8List(1 + 4 + 8 + 8 + pcm.length);
  final bd = ByteData.sublistView(out);
  out[0] = MsgType.audio;
  bd.setUint32(1, f.seq & 0xFFFFFFFF);
  bd.setInt64(5, f.startIndex);
  bd.setInt64(13, f.captureUs);
  out.setRange(21, out.length, pcm);
  return out;
}

/// Decodes an audio message; throws [FormatException].
GuestAudioFrame decodeAudioMessage(Uint8List m) {
  if (m.length < 21 || m[0] != MsgType.audio) {
    throw const FormatException('Bad audio message');
  }
  final bd = ByteData.sublistView(m);
  return GuestAudioFrame(
    seq: bd.getUint32(1),
    startIndex: bd.getInt64(5),
    captureUs: bd.getInt64(13),
    samples: int16ToFloat(decodePcm16(Uint8List.sublistView(m, 21))),
  );
}

/// Guest device status (battery may be unknown).
class GuestStatus {
  /// Creates a status.
  const GuestStatus({this.battery, this.charging, this.level = 0});

  /// Battery percentage (0–100), null when unknown.
  final int? battery;

  /// Charging, null when unknown.
  final bool? charging;

  /// Recent input level 0..1.
  final double level;

  /// Control message body.
  Map<String, Object?> toJson() => {
    't': 'status',
    'battery': battery,
    'charging': charging,
    'level': (level * 1000).round() / 1000,
  };

  /// Parses a status body (tolerant).
  static GuestStatus fromJson(Map<String, Object?> j) {
    final b = j['battery'];
    final c = j['charging'];
    final l = j['level'];
    return GuestStatus(
      battery: b is int && b >= 0 && b <= 100 ? b : null,
      charging: c is bool ? c : null,
      level: l is num && l.isFinite ? l.toDouble().clamp(0.0, 1.0) : 0,
    );
  }
}
