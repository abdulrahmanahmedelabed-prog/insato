// Guest side of the multi-device transport (v1.2 C): connects to the host
// over the LAN, proves knowledge of the pairing code, answers clock pings,
// and streams timestamped audio frames.
//
// Pure Dart (dart:io); exercised with real sockets on localhost in tests.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SecretKeyData;

import 'clock_sync.dart';
import 'fusion_engine.dart' show GuestAudioFrame;
import 'protocol.dart';
import 'secure_channel.dart';

/// Why joining failed.
enum JoinFailure {
  /// No host answered at the given addresses.
  unreachable,

  /// The host closed the connection without a welcome: usually a wrong
  /// pairing code (the host never answers an unauthenticated peer).
  rejectedOrWrongCode,

  /// The meeting already has [kMaxGuests] guests.
  full,

  /// The host removed this device.
  removed,

  /// The meeting has ended.
  ended,

  /// Incompatible app versions.
  version,
}

/// Joining failed.
class JoinException implements Exception {
  /// Creates the exception.
  const JoinException(this.failure, [this.details]);

  /// The reason.
  final JoinFailure failure;

  /// Technical details.
  final String? details;

  @override
  String toString() => 'JoinException(${failure.name}, $details)';
}

JoinFailure _failureOf(String? reason) => switch (reason) {
  RejectReason.full => JoinFailure.full,
  RejectReason.removed => JoinFailure.removed,
  RejectReason.ended => JoinFailure.ended,
  RejectReason.version => JoinFailure.version,
  _ => JoinFailure.rejectedOrWrongCode,
};

/// Events of a [MultiDeviceGuest].
sealed class GuestClientEvent {
  const GuestClientEvent();
}

/// The host's meeting state changed.
class HostStateChanged extends GuestClientEvent {
  /// Creates the event.
  const HostStateChanged(this.state, this.title);

  /// [HostState] value.
  final String state;

  /// Meeting title.
  final String title;
}

/// The host removed this device.
class GuestKicked extends GuestClientEvent {
  /// Creates the event.
  const GuestKicked();
}

/// The connection ended (not by [MultiDeviceGuest.close]).
class GuestConnectionLost extends GuestClientEvent {
  /// Creates the event.
  const GuestConnectionLost(this.failure);

  /// Set when the host refused the device after the handshake.
  final JoinFailure? failure;
}

/// A guest connection. See the file header.
class MultiDeviceGuest {
  MultiDeviceGuest._(this._ws, this._channel, this._nowUs, this.welcome);

  /// Connects to the first reachable of [hosts] on [port] and completes the
  /// handshake. Throws [JoinException].
  static Future<MultiDeviceGuest> connect({
    required List<String> hosts,
    required int port,
    required SecretKeyData pairingKey,
    required String guestId,
    String name = '',
    String platform = '',
    int Function()? nowUs,
    Duration attemptTimeout = const Duration(seconds: 4),
    Duration idleTimeout = const Duration(seconds: 6),
  }) async {
    final clock = nowUs ?? MonotonicClock.instance.nowUs;
    WebSocket? ws;
    Object? lastError;
    for (final h in hosts) {
      final uri = Uri(
        scheme: 'ws',
        host: h,
        port: port,
        path: kMultiDevicePath,
      );
      try {
        ws = await runInSocketZone(() => WebSocket.connect(uri.toString()))
            .timeout(attemptTimeout);
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (ws == null) {
      throw JoinException(JoinFailure.unreachable, '$lastError');
    }
    final channel = SecureChannel(pairingKey: pairingKey, isHost: false);
    final cn = secureRandomBytes(16);
    final cnText = base64Encode(cn);
    final incoming = StreamIterator<Object?>(ws.cast<Object?>());
    // Writing a close frame to a connection the peer already closed makes
    // dart:io report an uncaught error: only close what is still open.
    var peerClosed = false;
    try {
      ws.add(
        channel.sealHandshake(
          encodeJsonMessage(MsgType.hello, {
            'v': kMultiDeviceProtocolVersion,
            'id': guestId,
            'name': name,
            'platform': platform,
            'cn': cnText,
          }),
        ),
      );
      final has = await incoming.moveNext().timeout(attemptTimeout * 2);
      peerClosed = !has;
      if (!has || incoming.current is! List<int>) {
        throw const JoinException(JoinFailure.rejectedOrWrongCode);
      }
      final m = channel.openHandshake(
        Uint8List.fromList(incoming.current! as List<int>),
      );
      if (m == null || m.isEmpty) {
        throw const JoinException(JoinFailure.rejectedOrWrongCode);
      }
      final j = decodeJsonBody(m);
      if (m[0] == MsgType.reject) {
        throw JoinException(_failureOf(j['reason'] as String?));
      }
      final sn = j['sn'];
      if (m[0] != MsgType.welcome || sn is! String || j['cn'] != cnText) {
        throw const JoinException(JoinFailure.rejectedOrWrongCode);
      }
      await channel.establish(cn, base64Decode(sn));
      ws.add(channel.seal(encodeJsonMessage(MsgType.ready, const {})));
      final guest = MultiDeviceGuest._(
        ws,
        channel,
        clock,
        WelcomeInfo(
          sessionId: j['sid'] is String ? j['sid'] as String : '',
          hostName: j['host'] is String ? j['host'] as String : '',
          title: j['title'] is String ? j['title'] as String : '',
          state: j['state'] is String ? j['state'] as String : HostState.lobby,
        ),
      );
      guest._listen(incoming, idleTimeout);
      return guest;
    } on JoinException {
      await incoming.cancel();
      if (!peerClosed) await ws.close();
      rethrow;
    } catch (e) {
      await incoming.cancel();
      if (!peerClosed) await ws.close();
      if (e is TimeoutException || e is FormatException) {
        throw JoinException(JoinFailure.rejectedOrWrongCode, '$e');
      }
      throw JoinException(JoinFailure.unreachable, '$e');
    }
  }

  final WebSocket _ws;
  final SecureChannel _channel;
  final int Function() _nowUs;

  /// What the host said when admitting this device.
  final WelcomeInfo welcome;

  // Single-subscription: events before the first listener are buffered.
  final _events = StreamController<GuestClientEvent>();
  Timer? _idle;
  int _lastHeardUs = 0;
  bool _closed = false;
  bool _peerClosed = false;
  bool _kicked = false;
  JoinFailure? _failure;
  int _seq = 0;

  /// Connection events.
  Stream<GuestClientEvent> get events => _events.stream;

  /// True until the connection ended.
  bool get isOpen => !_closed;

  void _listen(StreamIterator<Object?> it, Duration idleTimeout) {
    _lastHeardUs = _nowUs();
    _idle = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_nowUs() - _lastHeardUs > idleTimeout.inMicroseconds) {
        unawaited(_end(lost: true));
      }
    });
    unawaited(() async {
      try {
        while (await it.moveNext()) {
          _onData(it.current);
          if (_closed) break;
        }
        if (!_closed) _peerClosed = true;
      } catch (_) {
        // Connection error: treated as lost below.
        _peerClosed = true;
      }
      await _end(lost: true);
    }());
  }

  void _onData(Object? data) {
    final arrival = _nowUs();
    if (data is! List<int>) return;
    final m = _channel.open(
      data is Uint8List ? data : Uint8List.fromList(data),
    );
    if (m == null || m.isEmpty || m[0] != MsgType.control) return;
    _lastHeardUs = arrival;
    final Map<String, Object?> j;
    try {
      j = decodeJsonBody(m);
    } on FormatException {
      return;
    }
    switch (j['t']) {
      case 'ping':
        _sendControl({
          't': 'pong',
          'id': j['id'],
          't1': j['t1'],
          't2': arrival,
          't3': _nowUs(),
        });
      case 'state':
        final s = j['state'];
        final t = j['title'];
        if (s is String) {
          _emit(HostStateChanged(s, t is String ? t : ''));
        }
      case 'kick':
        _kicked = true;
        _emit(const GuestKicked());
      case 'reject':
        _failure = _failureOf(j['reason'] as String?);
    }
  }

  void _emit(GuestClientEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _send(Uint8List message) {
    if (_closed) return;
    try {
      _ws.add(_channel.seal(message));
    } catch (_) {
      unawaited(_end(lost: true));
    }
  }

  void _sendControl(Map<String, Object?> body) =>
      _send(encodeJsonMessage(MsgType.control, body));

  /// Sends an audio frame (the sequence number is filled in).
  void sendAudio({
    required int startIndex,
    required int captureUs,
    required Float32List samples,
  }) {
    _send(
      encodeAudioMessage(
        GuestAudioFrame(
          seq: _seq++,
          startIndex: startIndex,
          captureUs: captureUs,
          samples: samples,
        ),
      ),
    );
  }

  /// Sends the device status.
  void sendStatus(GuestStatus status) => _sendControl(status.toJson());

  /// Leaves the meeting.
  Future<void> close() async {
    if (_closed) return;
    _sendControl({'t': 'bye'});
    await _end(lost: false);
  }

  Future<void> _end({required bool lost}) async {
    if (_closed) return;
    _closed = true;
    _idle?.cancel();
    if (lost && !_kicked) _emit(GuestConnectionLost(_failure));
    if (!_peerClosed) {
      try {
        await _ws.close(WebSocketStatus.normalClosure);
      } catch (_) {
        // Already closed.
      }
    }
    // Not awaited: a single-subscription controller nobody listens to
    // never delivers its done event.
    unawaited(_events.close());
  }
}

/// The host's welcome.
class WelcomeInfo {
  /// Creates the info.
  const WelcomeInfo({
    required this.sessionId,
    required this.hostName,
    required this.title,
    required this.state,
  });

  /// Session id.
  final String sessionId;

  /// Host device name.
  final String hostName;

  /// Meeting title (may be empty before the meeting starts).
  final String title;

  /// [HostState] at admission.
  final String state;
}

/// Splits capture frames into timestamped network frames (≤ 100 ms).
class GuestAudioFramer {
  /// Creates a framer using [timestamper] for capture times.
  GuestAudioFramer({CaptureTimestamper? timestamper, this.maxSamples = 1600})
    : timestamper = timestamper ?? CaptureTimestamper();

  /// Maps sample index → device clock.
  final CaptureTimestamper timestamper;

  /// Largest frame.
  final int maxSamples;

  int _index = 0;

  /// Samples seen since the capture started.
  int get sampleCount => _index;

  /// Capture restarted / resumed: timestamps are re-estimated.
  void discontinuity() => timestamper.reset();

  /// Splits [samples] (arrived at [arrivalUs]) into `(startIndex,
  /// captureUs, samples)` frames.
  List<(int, int, Float32List)> add(Float32List samples, int arrivalUs) {
    if (samples.isEmpty) return const [];
    final start = _index;
    final firstUs = timestamper.stamp(
      endIndex: start + samples.length,
      length: samples.length,
      arrivalUs: arrivalUs,
    );
    _index += samples.length;
    final out = <(int, int, Float32List)>[];
    for (var o = 0; o < samples.length; o += maxSamples) {
      final n = samples.length - o < maxSamples
          ? samples.length - o
          : maxSamples;
      out.add((
        start + o,
        firstUs + (o * kUsPerSample).round(),
        Float32List.sublistView(samples, o, o + n),
      ));
    }
    return out;
  }
}
