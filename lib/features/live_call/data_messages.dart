// Live Insato call (v1.2): messages on the WebRTC data channel.
//
// The channel is encrypted by DTLS and bound to the certificates exchanged
// over the authenticated signaling; messages are compact JSON text:
//
//   {"t":"auth","fp":<own fingerprint>,"mac":<b64>}   peer authentication
//   {"t":"ping","a":t1}                               clock sync request
//   {"t":"pong","a":t1,"b":t2,"c":t3}                 clock sync answer
//   {"t":"pend","id","at","dur","snt"}                speech being transcribed
//   {"t":"seg","id","at","dur","snt","text","lang","spk","name","kind","conf"}
//   {"t":"drop","id"}                                 retract a line (echo)
//   {"t":"act","on","lvl"}                            speaking now / level
//   {"t":"mute","on"}                                 microphone muted
//   {"t":"bye","reason"}                              hang-up
//
// Times (`at`, `snt`, t1–t3) are the sender's monotonic clock in µs; the
// receiver maps them to its own clock with the clock-sync estimate.
// `spk` is the sender's speaker id (opaque; namespaced by the receiver),
// `name` its display name on the sender.
//
// Pure Dart.

import 'dart:convert';
import 'dart:typed_data';

import '../../core/models.dart' show SegmentKind;

/// Longest text accepted in one `seg`.
const int kMaxLineTextLength = 4000;

/// A data-channel message.
sealed class CallDataMessage {
  const CallDataMessage();

  /// JSON fields (including `t`).
  Map<String, Object?> toJson();

  /// Wire text.
  String encode() => jsonEncode(toJson());

  /// Parses [text]; null when malformed or unknown.
  static CallDataMessage? decode(String text) {
    if (text.length > kMaxLineTextLength * 4) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final j = decoded;
    int? i(String k) => j[k] is int ? j[k] as int : null;
    String? s(String k) => j[k] is String ? j[k] as String : null;
    bool b(String k) => j[k] == true;
    switch (j['t']) {
      case 'auth':
        final fp = s('fp');
        final mac = s('mac');
        if (fp == null || mac == null) return null;
        try {
          return AuthMessage(fingerprint: fp, mac: base64.decode(mac));
        } on FormatException {
          return null;
        }
      case 'ping':
        final a = i('a');
        return a == null ? null : PingMessage(a);
      case 'pong':
        final a = i('a'), bb = i('b'), c = i('c');
        if (a == null || bb == null || c == null) return null;
        return PongMessage(t1: a, t2: bb, t3: c);
      case 'pend':
        final id = s('id'), at = i('at'), dur = i('dur');
        if (id == null || at == null || dur == null) return null;
        return PendingLineMessage(
          id: id,
          atUs: at,
          durMs: dur,
          sentUs: i('snt') ?? at,
        );
      case 'seg':
        final id = s('id'), at = i('at'), dur = i('dur');
        final txt = s('text');
        if (id == null || at == null || dur == null || txt == null) {
          return null;
        }
        if (txt.length > kMaxLineTextLength) return null;
        final conf = j['conf'];
        return LineMessage(
          id: id,
          atUs: at,
          durMs: dur,
          sentUs: i('snt') ?? at,
          text: txt,
          language: s('lang'),
          speakerKey: s('spk') ?? '',
          speakerName: s('name') ?? '',
          kind: SegmentKind.parse(s('kind')),
          confidence: conf is num ? conf.toDouble() : null,
        );
      case 'drop':
        final id = s('id');
        return id == null ? null : DropLineMessage(id);
      case 'act':
        final lvl = j['lvl'];
        return ActivityMessage(
          speaking: b('on'),
          level: lvl is num ? lvl.toDouble().clamp(0.0, 1.0) : 0,
        );
      case 'mute':
        return MuteMessage(b('on'));
      case 'bye':
        return ByeMessage(s('reason') ?? 'hangup');
    }
    return null;
  }
}

/// Peer authentication (see signaling_protocol.dart).
class AuthMessage extends CallDataMessage {
  /// Creates the message.
  const AuthMessage({required this.fingerprint, required this.mac});

  /// Sender's DTLS fingerprint.
  final String fingerprint;

  /// MAC(K_call, role ‖ own ‖ peer fingerprint).
  final Uint8List mac;

  @override
  Map<String, Object?> toJson() => {
    't': 'auth',
    'fp': fingerprint,
    'mac': base64.encode(mac),
  };
}

/// Clock-sync request.
class PingMessage extends CallDataMessage {
  /// Creates the message.
  const PingMessage(this.t1);

  /// Sender time.
  final int t1;

  @override
  Map<String, Object?> toJson() => {'t': 'ping', 'a': t1};
}

/// Clock-sync answer.
class PongMessage extends CallDataMessage {
  /// Creates the message.
  const PongMessage({required this.t1, required this.t2, required this.t3});

  /// Requester's send time (echoed).
  final int t1;

  /// Our receive time.
  final int t2;

  /// Our send time.
  final int t3;

  @override
  Map<String, Object?> toJson() => {'t': 'pong', 'a': t1, 'b': t2, 'c': t3};
}

/// Speech detected and being transcribed (partial result placeholder).
class PendingLineMessage extends CallDataMessage {
  /// Creates the message.
  const PendingLineMessage({
    required this.id,
    required this.atUs,
    required this.durMs,
    required this.sentUs,
  });

  /// Line id (the final `seg` reuses it).
  final String id;

  /// Start (sender clock, µs).
  final int atUs;

  /// Duration.
  final int durMs;

  /// Send time (sender clock).
  final int sentUs;

  @override
  Map<String, Object?> toJson() => {
    't': 'pend',
    'id': id,
    'at': atUs,
    'dur': durMs,
    'snt': sentUs,
  };
}

/// A transcribed line.
class LineMessage extends CallDataMessage {
  /// Creates the message.
  const LineMessage({
    required this.id,
    required this.atUs,
    required this.durMs,
    required this.sentUs,
    required this.text,
    required this.speakerKey,
    required this.speakerName,
    this.language,
    this.kind = SegmentKind.speech,
    this.confidence,
  });

  /// Line id.
  final String id;

  /// Start (sender clock, µs).
  final int atUs;

  /// Duration.
  final int durMs;

  /// Send time (sender clock).
  final int sentUs;

  /// Text.
  final String text;

  /// Sender's speaker id ('' = unknown).
  final String speakerKey;

  /// Sender's speaker name.
  final String speakerName;

  /// Language code.
  final String? language;

  /// Speech or unintelligible.
  final SegmentKind kind;

  /// Recogniser confidence.
  final double? confidence;

  @override
  Map<String, Object?> toJson() => {
    't': 'seg',
    'id': id,
    'at': atUs,
    'dur': durMs,
    'snt': sentUs,
    'text': text,
    'lang': ?language,
    'spk': speakerKey,
    'name': speakerName,
    'kind': kind.wire,
    'conf': ?confidence,
  };
}

/// Retracts a line (it was an echo, or the speech was silence).
class DropLineMessage extends CallDataMessage {
  /// Creates the message.
  const DropLineMessage(this.id);

  /// Line id.
  final String id;

  @override
  Map<String, Object?> toJson() => {'t': 'drop', 'id': id};
}

/// Speaking indicator and microphone level.
class ActivityMessage extends CallDataMessage {
  /// Creates the message.
  const ActivityMessage({required this.speaking, required this.level});

  /// Speech detected right now.
  final bool speaking;

  /// Level 0..1.
  final double level;

  @override
  Map<String, Object?> toJson() => {
    't': 'act',
    'on': speaking,
    'lvl': double.parse(level.toStringAsFixed(2)),
  };
}

/// Microphone muted / unmuted.
class MuteMessage extends CallDataMessage {
  /// Creates the message.
  const MuteMessage(this.muted);

  /// Muted.
  final bool muted;

  @override
  Map<String, Object?> toJson() => {'t': 'mute', 'on': muted};
}

/// Hang-up.
class ByeMessage extends CallDataMessage {
  /// Creates the message.
  const ByeMessage(this.reason);

  /// Reason.
  final String reason;

  @override
  Map<String, Object?> toJson() => {'t': 'bye', 'reason': reason};
}
