// Live Insato call (v1.2): signaling client — relay socket + authenticated
// handshake + sealed SDP / ICE exchange (protocol in signaling_protocol.dart).
//
// [RelaySocket] abstracts the WebSocket so the handshake is tested with an
// in-memory relay as well as with the reference server on localhost.
//
// Pure Dart + dart:io.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../multi_device/secure_channel.dart'
    show SecureChannel, kPhaseHandshake, kPhaseSession, secureRandomBytes;
import 'call_code.dart';
import 'signaling_protocol.dart';

/// Text WebSocket to the relay.
abstract class RelaySocket {
  /// Incoming text frames; done when the socket closes.
  Stream<String> get messages;

  /// Sends a text frame (ignored once closed).
  void send(String text);

  /// Closes the socket.
  Future<void> close();
}

/// Opens a [RelaySocket] to a relay URL.
typedef RelayConnector = Future<RelaySocket> Function(String url);

/// [RelaySocket] over `dart:io` [WebSocket] (Android, iOS, Windows).
class IoRelaySocket implements RelaySocket {
  IoRelaySocket._(this._ws) {
    _sub = _ws.listen(
      (data) {
        if (data is String) _out.add(data);
      },
      onError: (Object _) => unawaited(close()),
      onDone: () => unawaited(close()),
      cancelOnError: true,
    );
  }

  /// Connects to [url] (`wss://…` or `ws://…`) within [timeout].
  static Future<IoRelaySocket> connect(
    String url, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final ws = await WebSocket.connect(url).timeout(timeout);
    ws.pingInterval = const Duration(seconds: 15);
    return IoRelaySocket._(ws);
  }

  final WebSocket _ws;
  final StreamController<String> _out = StreamController<String>();
  StreamSubscription<Object?>? _sub;
  bool _closed = false;

  @override
  Stream<String> get messages => _out.stream;

  @override
  void send(String text) {
    if (_closed) return;
    try {
      _ws.add(text);
    } catch (_) {
      unawaited(close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    try {
      await _ws.close().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Already gone.
    }
    await _out.close();
  }
}

/// [url] with `room=<roomId>` added to its query.
String relayUrlForRoom(String url, String roomId) {
  final uri = Uri.parse(url);
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'room': roomId})
      .toString();
}

/// Default connector.
Future<RelaySocket> connectIoRelay(String url) => IoRelaySocket.connect(url);

/// Which side of the call this device is.
enum CallRole {
  /// Started the call (shows the code; makes the WebRTC offer).
  caller,

  /// Joined with the code (answers).
  callee;

  /// Wire name.
  String get wire => name;
}

/// Something that happened on the signaling channel.
sealed class SignalingEvent {
  const SignalingEvent();
}

/// Joined the relay room ([peerPresent]: the other side is already there).
class SignalingJoined extends SignalingEvent {
  /// Creates the event.
  const SignalingJoined({required this.peerPresent});

  /// The other side is already in the room.
  final bool peerPresent;
}

/// The handshake completed: the peer proved it knows the code.
class SignalingAuthenticated extends SignalingEvent {
  /// Creates the event.
  const SignalingAuthenticated({
    required this.peerName,
    required this.peerPlatform,
  });

  /// Peer device name.
  final String peerName;

  /// Peer platform id.
  final String peerPlatform;
}

/// The other side is in the relay room (callee: a hello was sent).
class SignalingPeerPresent extends SignalingEvent {
  /// Creates the event.
  const SignalingPeerPresent();
}

/// The peer left the relay room.
class SignalingPeerLeft extends SignalingEvent {
  /// Creates the event.
  const SignalingPeerLeft();
}

/// An SDP offer from the caller.
class SignalingOffer extends SignalingEvent {
  /// Creates the event.
  const SignalingOffer(this.sdp);

  /// SDP.
  final String sdp;
}

/// An SDP answer from the callee.
class SignalingAnswer extends SignalingEvent {
  /// Creates the event.
  const SignalingAnswer(this.sdp);

  /// SDP.
  final String sdp;
}

/// A remote ICE candidate.
class SignalingIce extends SignalingEvent {
  /// Creates the event.
  const SignalingIce(this.candidate);

  /// Candidate.
  final IceCandidateData candidate;
}

/// The peer hung up.
class SignalingBye extends SignalingEvent {
  /// Creates the event.
  const SignalingBye(this.reason);

  /// Reason given by the peer.
  final String reason;
}

/// The relay refused us (`full`, `bad`, …) or the socket closed.
class SignalingClosed extends SignalingEvent {
  /// Creates the event ([relayError] null: the socket just closed).
  const SignalingClosed({this.relayError});

  /// Relay error code, if any.
  final String? relayError;
}

/// A frame that failed authentication arrived (wrong code or forgery).
class SignalingRejectedFrame extends SignalingEvent {
  /// Creates the event.
  const SignalingRejectedFrame();
}

/// Authenticated signaling of one call.
///
/// The caller waits for the callee's sealed `hello`, answers with `welcome`
/// and accepts the callee once its `ready` (sealed with the fresh session
/// key) arrives. The callee sends `hello` as soon as it knows the caller is
/// in the room. Every SDP / ICE / bye message afterwards is sealed with the
/// session keys. Frames that do not authenticate are dropped (and reported
/// as [SignalingRejectedFrame]).
class CallSignaling {
  /// Creates the signaling of [role] for a call with [keys].
  CallSignaling({
    required this.role,
    required this.keys,
    required this.localName,
    required this.localPlatform,
    this._random,
  });

  /// Our role.
  final CallRole role;

  /// Keys of the call.
  final CallKeys keys;

  /// Our device name (sent sealed).
  final String localName;

  /// Our platform id.
  final String localPlatform;

  final math.Random? _random;
  final StreamController<SignalingEvent> _events =
      StreamController<SignalingEvent>.broadcast();
  RelaySocket? _socket;
  StreamSubscription<String>? _sub;
  Timer? _keepAlive;
  SecureChannel? _channel;
  Uint8List? _clientNonce;
  final Set<String> _seenClientNonces = {};
  bool _authenticated = false;
  bool _helloSent = false;
  bool _closed = false;
  Future<void> _tail = Future<void>.value();
  SignalingAuthenticated? _pendingAuth;

  /// Events (broadcast).
  Stream<SignalingEvent> get events => _events.stream;

  /// True once the peer proved the code.
  bool get isAuthenticated => _authenticated;

  /// Connects to the relay at [url] and joins the call's room.
  Future<void> connect(String url, {RelayConnector? connector}) async {
    // The room id also goes in the URL so relays that shard by room (the
    // Cloudflare Worker routes each room to one Durable Object) can route
    // the socket before the first frame; the reference server ignores it.
    final socket = await (connector ?? connectIoRelay)(
      relayUrlForRoom(url, keys.roomId),
    );
    if (_closed) {
      await socket.close();
      return;
    }
    _socket = socket;
    _sub = socket.messages.listen(
      _onText,
      onDone: () => _emit(const SignalingClosed()),
    );
    socket.send(RelayJoin(keys.roomId).encode());
    _keepAlive = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _socket?.send(const RelayPing().encode()),
    );
  }

  void _emit(SignalingEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _onText(String text) {
    final frame = RelayFrame.decode(text);
    switch (frame) {
      case RelayJoined(:final peers):
        _emit(SignalingJoined(peerPresent: peers > 0));
        if (peers > 0) _peerPresent();
      case RelayPeerEvent(:final joined):
        if (joined) {
          _peerPresent();
        } else {
          _peerLeft();
        }
      case RelayData(:final data):
        // Strictly in order: a `ready` must never overtake the key setup of
        // the hello before it.
        _tail = _tail.then((_) => _onSealed(data)).catchError((Object _) {});
      case RelayError(:final code):
        _emit(SignalingClosed(relayError: code));
      case RelayPing():
        _socket?.send(const RelayPong().encode());
      case RelayPong() || RelayJoin() || null:
        break;
    }
  }

  void _peerPresent() {
    _emit(const SignalingPeerPresent());
    if (role != CallRole.callee || _authenticated) return;
    // A (re)appearing caller: start a fresh handshake.
    final cn = _clientNonce = secureRandomBytes(16, _random);
    final ch = _channel = SecureChannel(
      pairingKey: keys.callKey,
      isHost: false,
    );
    _helloSent = true;
    _sendRaw(
      ch.sealHandshake(
        CallMessage.hello(
          clientNonce: cn,
          name: localName,
          platform: localPlatform,
        ).encode(),
      ),
    );
  }

  void _peerLeft() {
    if (_authenticated) {
      _authenticated = false;
      _channel = null;
      _pendingAuth = null;
      _helloSent = false;
    }
    _emit(const SignalingPeerLeft());
  }

  Future<void> _onSealed(Uint8List frame) async {
    final phase = SecureChannel.phaseOf(frame);
    if (phase == kPhaseHandshake) {
      if (role == CallRole.caller) {
        await _callerOnHello(frame);
      } else {
        await _calleeOnWelcome(frame);
      }
      return;
    }
    if (phase != kPhaseSession) return;
    final ch = _channel;
    if (ch == null || !ch.hasSessionKeys) return;
    final clear = ch.open(frame);
    final msg = clear == null ? null : CallMessage.decode(clear);
    if (msg == null) {
      _emit(const SignalingRejectedFrame());
      return;
    }
    switch (msg.type) {
      case 'ready':
        final auth = _pendingAuth;
        if (role == CallRole.caller && !_authenticated && auth != null) {
          _authenticated = true;
          _emit(auth);
        }
      case 'offer':
        if (role == CallRole.callee && _authenticated) {
          _emit(SignalingOffer(msg.str('sdp')));
        }
      case 'answer':
        if (role == CallRole.caller && _authenticated) {
          _emit(SignalingAnswer(msg.str('sdp')));
        }
      case 'ice':
        final c = msg.candidate;
        if (_authenticated && c != null) _emit(SignalingIce(c));
      case 'bye':
        if (_authenticated) _emit(SignalingBye(msg.str('reason')));
    }
  }

  Future<void> _callerOnHello(Uint8List frame) async {
    // A new hello always comes from a probe: refuse it while a callee is
    // connected (a third party with the code must not take the call over).
    if (_authenticated) return;
    final probe = SecureChannel(pairingKey: keys.callKey, isHost: true);
    final clear = probe.openHandshake(frame);
    final msg = clear == null ? null : CallMessage.decode(clear);
    if (msg == null || msg.type != 'hello') {
      _emit(const SignalingRejectedFrame());
      return;
    }
    final cn = msg.bytes('cn');
    if (msg.body['v'] != kLiveCallProtocolVersion ||
        cn == null ||
        cn.length != 16) {
      _emit(const SignalingRejectedFrame());
      return;
    }
    final key = hexOf(cn);
    if (!_seenClientNonces.add(key)) return; // Replayed hello.
    final sn = secureRandomBytes(16, _random);
    _sendRaw(
      probe.sealHandshake(
        CallMessage.welcome(
          serverNonce: sn,
          name: localName,
          platform: localPlatform,
        ).encode(),
      ),
    );
    await probe.establish(cn, sn);
    _channel = probe;
    _pendingAuth = SignalingAuthenticated(
      peerName: _cleanName(msg.str('name')),
      peerPlatform: _cleanName(msg.str('platform')),
    );
  }

  Future<void> _calleeOnWelcome(Uint8List frame) async {
    final ch = _channel;
    final cn = _clientNonce;
    if (ch == null || cn == null || !_helloSent || ch.hasSessionKeys) return;
    final clear = ch.openHandshake(frame);
    final msg = clear == null ? null : CallMessage.decode(clear);
    if (msg == null || msg.type != 'welcome') {
      _emit(const SignalingRejectedFrame());
      return;
    }
    final sn = msg.bytes('sn');
    if (msg.body['v'] != kLiveCallProtocolVersion ||
        sn == null ||
        sn.length != 16) {
      _emit(const SignalingRejectedFrame());
      return;
    }
    await ch.establish(cn, sn);
    _sendRaw(ch.seal(CallMessage.ready().encode()));
    _authenticated = true;
    _emit(
      SignalingAuthenticated(
        peerName: _cleanName(msg.str('name')),
        peerPlatform: _cleanName(msg.str('platform')),
      ),
    );
  }

  static String _cleanName(String s) {
    final t = s.replaceAll(RegExp(r'[\u0000-\u001f]'), ' ').trim();
    return t.length > 60 ? t.substring(0, 60) : t;
  }

  void _sendRaw(Uint8List sealed) =>
      _socket?.send(RelayData(sealed).encode());

  void _sendSealed(CallMessage m) {
    final ch = _channel;
    if (ch == null || !ch.hasSessionKeys || !_authenticated) return;
    _sendRaw(ch.seal(m.encode()));
  }

  /// Sends the SDP offer (caller).
  void sendOffer(String sdp) => _sendSealed(CallMessage.offer(sdp));

  /// Sends the SDP answer (callee).
  void sendAnswer(String sdp) => _sendSealed(CallMessage.answer(sdp));

  /// Sends a local ICE candidate.
  void sendIce(IceCandidateData c) => _sendSealed(CallMessage.ice(c));

  /// Tells the peer we hang up.
  void sendBye([String reason = 'hangup']) =>
      _sendSealed(CallMessage.bye(reason));

  /// Leaves the relay. Idempotent.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _keepAlive?.cancel();
    await _sub?.cancel();
    await _socket?.close();
    await _events.close();
  }
}
