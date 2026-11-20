// Host side of the multi-device transport (v1.2 C): a WebSocket server on
// the LAN (dart:io HttpServer) that admits up to [kMaxGuests] guests holding
// the meeting's pairing code, receives their audio and keeps their clocks
// measured (ping / pong every second).
//
// See protocol.dart (messages) and secure_channel.dart (encryption). A peer
// whose first frame does not authenticate is closed without an answer; a
// removed guest is refused for the rest of the meeting. Nothing here needs
// the internet: the server binds to the LAN and guests connect directly.
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

/// Tuning of [MultiDeviceHost].
class HostConfig {
  /// Creates a configuration.
  const HostConfig({
    this.maxGuests = kMaxGuests,
    this.pingInterval = const Duration(seconds: 1),
    this.idleTimeout = const Duration(seconds: 6),
    this.handshakeTimeout = const Duration(seconds: 10),
  });

  /// Guest limit.
  final int maxGuests;

  /// Clock ping period.
  final Duration pingInterval;

  /// A guest silent for this long is dropped.
  final Duration idleTimeout;

  /// Time allowed for hello + ready.
  final Duration handshakeTimeout;
}

/// A connected guest.
class GuestPeerInfo {
  /// Creates the info.
  const GuestPeerInfo({
    required this.id,
    required this.name,
    required this.platform,
  });

  /// Stable device id chosen by the guest.
  final String id;

  /// Display name.
  final String name;

  /// `android`, `ios`, `windows`, …
  final String platform;
}

/// Events of a [MultiDeviceHost].
sealed class HostEvent {
  const HostEvent(this.guestId);

  /// The guest concerned.
  final String guestId;
}

/// A guest completed the handshake.
class GuestConnected extends HostEvent {
  /// Creates the event.
  GuestConnected(this.info) : super(info.id);

  /// The guest.
  final GuestPeerInfo info;
}

/// A guest's connection ended.
class GuestDisconnected extends HostEvent {
  /// Creates the event.
  const GuestDisconnected(super.guestId, {required this.removed});

  /// True when the host removed the guest.
  final bool removed;
}

/// Audio from a guest.
class GuestAudio extends HostEvent {
  /// Creates the event.
  const GuestAudio(super.guestId, this.frame, this.arrivalUs);

  /// The decoded frame.
  final GuestAudioFrame frame;

  /// Host clock at arrival.
  final int arrivalUs;
}

/// A completed clock exchange.
class GuestClock extends HostEvent {
  /// Creates the event.
  const GuestClock(super.guestId, this.sample);

  /// The exchange.
  final ClockSample sample;
}

/// A guest's device status.
class GuestStatusReport extends HostEvent {
  /// Creates the event.
  const GuestStatusReport(super.guestId, this.status);

  /// The status.
  final GuestStatus status;
}

/// The host's WebSocket server. See the file header.
class MultiDeviceHost {
  MultiDeviceHost._(
    this._server,
    this.joinInfo,
    this._key,
    this._nowUs,
    this.config,
  );

  /// Starts a server on [port] (0 = any free port) of [bindAddress] with a
  /// new random session id and pairing code ([code] for tests).
  static Future<MultiDeviceHost> start({
    String hostName = '',
    int port = 0,
    Object? bindAddress,
    String? code,
    int kdfIterations = kPairingKdfIterations,
    int Function()? nowUs,
    Future<List<String>> Function()? localAddresses,
    HostConfig config = const HostConfig(),
  }) async {
    final pairing = code ?? randomBase32(kPairingCodeLength);
    final key = await derivePairingKey(pairing, iterations: kdfIterations);
    final server = await HttpServer.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      port,
    );
    final addrs = await (localAddresses ?? lanAddresses)();
    final info = JoinInfo(
      sessionId: randomBase32(8),
      addresses: addrs,
      port: server.port,
      code: pairing,
      hostName: hostName,
    );
    final host = MultiDeviceHost._(
      server,
      info,
      key,
      nowUs ?? MonotonicClock.instance.nowUs,
      config,
    );
    host._serve();
    return host;
  }

  final HttpServer _server;
  final SecretKeyData _key;
  final int Function() _nowUs;

  /// Tuning.
  final HostConfig config;

  /// What guests need to join (QR payload, code, address).
  final JoinInfo joinInfo;

  final _events = StreamController<HostEvent>.broadcast();
  final Set<_HostConnection> _connections = {};
  final Map<String, _HostConnection> _active = {};
  final Set<String> _blocked = {};
  final Set<String> _seenNonces = {};
  Timer? _pinger;
  int _pingId = 0;
  String _state = HostState.lobby;
  String _title = '';
  bool _closed = false;

  /// Guest events.
  Stream<HostEvent> get events => _events.stream;

  /// Connected guests.
  List<GuestPeerInfo> get guests => [for (final c in _active.values) c.info!];

  /// Current meeting state sent to guests.
  String get state => _state;

  /// Port the server listens on.
  int get port => _server.port;

  /// Host clock (µs).
  int nowUs() => _nowUs();

  void _serve() {
    _server.listen((req) async {
      if (_closed ||
          req.uri.path != kMultiDevicePath ||
          !WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      try {
        final ws = await WebSocketTransformer.upgrade(req);
        if (_closed) {
          await ws.close();
          return;
        }
        final c = _HostConnection(this, ws);
        _connections.add(c);
        c.start();
      } catch (_) {
        // Bad upgrade: nothing to clean up.
      }
    }, onError: (Object _) {});
    _pinger = Timer.periodic(config.pingInterval, (_) => _pingAll());
  }

  void _pingAll() {
    final now = _nowUs();
    for (final c in _active.values.toList()) {
      if (now - c.lastHeardUs > config.idleTimeout.inMicroseconds) {
        unawaited(c.close());
        continue;
      }
      c.sendControl({'t': 'ping', 'id': ++_pingId, 't1': _nowUs()});
    }
  }

  /// Tells every guest the meeting state ([HostState]) and title.
  void setState(String state, {String? title}) {
    _state = state;
    if (title != null) _title = title;
    for (final c in _active.values) {
      c.sendControl({'t': 'state', 'state': _state, 'title': _title});
    }
  }

  /// Removes guest [guestId] for the rest of the meeting.
  Future<void> remove(String guestId) async {
    _blocked.add(guestId);
    final c = _active[guestId];
    if (c == null) return;
    c.removed = true;
    c.sendControl({'t': 'kick'});
    await c.close();
  }

  /// Ends the meeting for all guests and stops the server.
  Future<void> close() async {
    if (_closed) return;
    _state = HostState.ended;
    for (final c in _active.values) {
      c.sendControl({'t': 'state', 'state': HostState.ended, 'title': _title});
    }
    _closed = true;
    _pinger?.cancel();
    for (final c in _connections.toList()) {
      await c.close();
    }
    await _server.close(force: true);
    await _events.close();
  }

  void _emit(HostEvent e) {
    if (!_events.isClosed) _events.add(e);
  }
}

enum _Phase { hello, ready, active, closed }

class _HostConnection {
  _HostConnection(this.host, this.ws);

  final MultiDeviceHost host;
  final WebSocket ws;
  late final SecureChannel channel = SecureChannel(
    pairingKey: host._key,
    isHost: true,
  );
  _Phase phase = _Phase.hello;
  GuestPeerInfo? info;
  Timer? _handshakeTimer;
  int lastHeardUs = 0;
  bool removed = false;
  bool replaced = false;
  StreamSubscription<Object?>? _sub;

  void start() {
    lastHeardUs = host._nowUs();
    _handshakeTimer = Timer(host.config.handshakeTimeout, () {
      if (phase != _Phase.active) unawaited(close());
    });
    _sub = ws.listen(
      _onData,
      onDone: _onDone,
      onError: (Object _) => _onDone(),
      cancelOnError: true,
    );
  }

  void _onData(Object? data) {
    final arrival = host._nowUs();
    if (data is! List<int>) {
      unawaited(close());
      return;
    }
    final frame = data is Uint8List ? data : Uint8List.fromList(data);
    try {
      switch (phase) {
        case _Phase.hello:
          _onHello(frame);
        case _Phase.ready:
          _onReady(frame);
        case _Phase.active:
          _onSession(frame, arrival);
        case _Phase.closed:
          break;
      }
    } on FormatException {
      unawaited(close());
    }
  }

  void _send(Uint8List frame) {
    if (phase == _Phase.closed) return;
    try {
      ws.add(frame);
    } catch (_) {
      unawaited(close());
    }
  }

  void sendControl(Map<String, Object?> body) {
    if (phase != _Phase.active) return;
    _send(channel.seal(encodeJsonMessage(MsgType.control, body)));
  }

  void _reject(String reason) {
    _send(
      channel.sealHandshake(
        encodeJsonMessage(MsgType.reject, {'reason': reason}),
      ),
    );
    unawaited(close());
  }

  void _onHello(Uint8List frame) {
    final m = channel.openHandshake(frame);
    if (m == null || m.isEmpty || m[0] != MsgType.hello) {
      // Unknown peer or wrong pairing code: no answer.
      unawaited(close());
      return;
    }
    final j = decodeJsonBody(m);
    final id = j['id'], name = j['name'], platform = j['platform'];
    final cn = j['cn'];
    if (id is! String || id.isEmpty || id.length > 64 || cn is! String) {
      throw const FormatException('Bad hello');
    }
    final nonce = base64Decode(cn);
    if (nonce.length != 16 || !host._seenNonces.add(cn)) {
      unawaited(close()); // replayed hello
      return;
    }
    if (j['v'] != kMultiDeviceProtocolVersion) {
      return _reject(RejectReason.version);
    }
    if (host._state == HostState.ended) return _reject(RejectReason.ended);
    if (host._blocked.contains(id)) return _reject(RejectReason.removed);
    if (_full(id)) return _reject(RejectReason.full);
    info = GuestPeerInfo(
      id: id,
      name: name is String ? _clip(name, 60) : '',
      platform: platform is String ? _clip(platform, 20) : '',
    );
    final sn = secureRandomBytes(16);
    _send(
      channel.sealHandshake(
        encodeJsonMessage(MsgType.welcome, {
          'v': kMultiDeviceProtocolVersion,
          'sid': host.joinInfo.sessionId,
          'sn': base64Encode(sn),
          'cn': cn,
          'title': host._title,
          'state': host._state,
          'host': host.joinInfo.hostName,
        }),
      ),
    );
    phase = _Phase.ready;
    // Keys are derived asynchronously; frames arriving meanwhile wait.
    _pending = channel.establish(nonce, sn);
  }

  Future<void>? _pending;
  final List<Uint8List> _queued = [];

  void _onReady(Uint8List frame) {
    final pending = _pending;
    if (pending != null) {
      _queued.add(frame);
      if (_queued.length > 1) return;
      unawaited(
        pending.then((_) {
          _pending = null;
          final q = [..._queued];
          _queued.clear();
          for (final f in q) {
            _onData(f);
          }
        }, onError: (Object _) => close()),
      );
      return;
    }
    final m = channel.open(frame);
    if (m == null || m.isEmpty || m[0] != MsgType.ready) {
      unawaited(close());
      return;
    }
    final id = info!.id;
    if (host._blocked.contains(id)) return _rejectActive(RejectReason.removed);
    if (_full(id)) return _rejectActive(RejectReason.full);
    _handshakeTimer?.cancel();
    final old = host._active[id];
    if (old != null && !identical(old, this)) {
      old.replaced = true;
      unawaited(old.close());
      host._emit(GuestDisconnected(id, removed: false));
    }
    host._active[id] = this;
    phase = _Phase.active;
    lastHeardUs = host._nowUs();
    host._emit(GuestConnected(info!));
    sendControl({'t': 'state', 'state': host._state, 'title': host._title});
  }

  void _rejectActive(String reason) {
    phase = _Phase.active;
    sendControl({'t': 'reject', 'reason': reason});
    unawaited(close());
  }

  bool _full(String id) {
    final others = host._active.keys.where((k) => k != id).length;
    return others >= host.config.maxGuests;
  }

  void _onSession(Uint8List frame, int arrival) {
    final m = channel.open(frame);
    if (m == null || m.isEmpty) {
      unawaited(close());
      return;
    }
    lastHeardUs = arrival;
    final id = info!.id;
    switch (m[0]) {
      case MsgType.audio:
        host._emit(GuestAudio(id, decodeAudioMessage(m), arrival));
      case MsgType.control:
        final j = decodeJsonBody(m);
        switch (j['t']) {
          case 'pong':
            final t1 = j['t1'], t2 = j['t2'], t3 = j['t3'];
            if (t1 is int && t2 is int && t3 is int) {
              host._emit(GuestClock(id, ClockSample(t1, t2, t3, arrival)));
            }
          case 'status':
            host._emit(GuestStatusReport(id, GuestStatus.fromJson(j)));
          case 'bye':
            unawaited(close());
        }
    }
  }

  void _onDone() {
    if (phase == _Phase.closed) return;
    unawaited(close());
  }

  Future<void> close() async {
    if (phase == _Phase.closed) return;
    final wasActive = phase == _Phase.active;
    phase = _Phase.closed;
    _handshakeTimer?.cancel();
    host._connections.remove(this);
    final id = info?.id;
    if (wasActive && id != null && identical(host._active[id], this)) {
      host._active.remove(id);
      if (!replaced) host._emit(GuestDisconnected(id, removed: removed));
    }
    try {
      await ws.close(WebSocketStatus.normalClosure);
    } catch (_) {
      // Already gone.
    }
    await _sub?.cancel();
  }

  static String _clip(String s, int n) =>
      s.length <= n ? s : s.substring(0, n);
}

/// The device's LAN IPv4 addresses (private ranges first; loopback and
/// link-local excluded). Empty when none is found.
Future<List<String>> lanAddresses() async {
  try {
    final ifs = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    final all = [
      for (final i in ifs)
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal) a.address,
    ];
    all.sort((a, b) => _rank(a).compareTo(_rank(b)));
    return all;
  } catch (_) {
    return const [];
  }
}

int _rank(String ip) {
  if (ip.startsWith('192.168.')) return 0;
  if (ip.startsWith('10.')) return 1;
  final p = ip.split('.');
  if (p.length == 4 && p[0] == '172') {
    final b = int.tryParse(p[1]) ?? 0;
    if (b >= 16 && b <= 31) return 1;
  }
  return 2;
}
