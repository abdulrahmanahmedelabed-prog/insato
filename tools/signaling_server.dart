// Insato live-call signaling relay (reference server, v1.2).
//
// A tiny WebSocket relay that lets two Insato devices find each other over
// the internet. It pairs the two clients that join the same room id and
// forwards opaque blobs between them. It cannot read or forge what it
// forwards: room ids are one-way hashes of the call code and every message
// is sealed end-to-end by the apps (ChaCha20-Poly1305, key derived from the
// call code). Audio never passes through it (WebRTC, peer-to-peer or via
// TURN). It keeps nothing on disk and forgets a room when it empties.
//
// Protocol (JSON text frames; see lib/features/live_call/
// signaling_protocol.dart for the client side):
//   client → relay  {"t":"join","room":<64 hex>,"v":1}   first frame, once
//                   {"t":"relay","d":<base64>}           to the other client
//                   {"t":"ping"}                         keep-alive
//   relay → client  {"t":"joined","peers":0|1}
//                   {"t":"peer","ev":"join"|"leave"}
//                   {"t":"relay","d":<base64>}
//                   {"t":"pong"}
//                   {"t":"error","code":"full"|"bad"|"rate"|"size"}
//
// Run:     dart run tools/signaling_server.dart            (PORT env, 8080)
// Deploy:  see docs/SETUP.md ("مكالمة إنصاتو الحية") — any host that runs
//          a Dart program or a container (Render, Koyeb, Fly.io, a VPS),
//          or the equivalent Cloudflare Worker in tools/signaling/.
//
// Self-contained: only dart: libraries, so it compiles outside the app
// (`dart compile exe tools/signaling_server.dart`).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Limits of the relay.
class RelayLimits {
  /// Creates limits.
  const RelayLimits({
    this.maxFrameChars = 96 * 1024,
    this.maxRooms = 5000,
    this.maxConnections = 10000,
    this.joinTimeout = const Duration(seconds: 10),
    this.idleTimeout = const Duration(seconds: 90),
    this.rateWindow = const Duration(seconds: 10),
    this.maxFramesPerWindow = 200,
  });

  /// Largest accepted text frame.
  final int maxFrameChars;

  /// Concurrent rooms.
  final int maxRooms;

  /// Concurrent sockets.
  final int maxConnections;

  /// A socket must join a room within this time.
  final Duration joinTimeout;

  /// A socket silent for this long is closed (clients ping every 20 s).
  final Duration idleTimeout;

  /// Rate-limit window.
  final Duration rateWindow;

  /// Frames allowed per window per socket.
  final int maxFramesPerWindow;
}

final RegExp _roomPattern = RegExp(r'^[0-9a-f]{64}$');

class _Client {
  _Client(this.socket);
  final WebSocket socket;
  String? room;
  int frames = 0;
  DateTime windowStart = DateTime.now();
  Timer? idle;
  bool closed = false;

  void send(Map<String, Object?> frame) {
    if (closed) return;
    try {
      socket.add(jsonEncode(frame));
    } catch (_) {
      // Socket already closing.
    }
  }
}

/// The relay.
class SignalingRelay {
  /// Creates a relay with [limits].
  SignalingRelay({this.limits = const RelayLimits()});

  /// Limits.
  final RelayLimits limits;

  HttpServer? _server;
  final Map<String, List<_Client>> _rooms = {};
  final Set<_Client> _clients = {};

  /// Bound port (after [start]).
  int get port => _server?.port ?? 0;

  /// Open rooms (for tests and the health page).
  int get roomCount => _rooms.length;

  /// Connected sockets.
  int get connectionCount => _clients.length;

  /// Listens on [address]:[port] (0 = any free port).
  Future<void> start({Object? address, int port = 8080}) async {
    final server = _server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    server.listen(_onRequest, onError: (Object _) {});
  }

  Future<void> _onRequest(HttpRequest req) async {
    try {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('Insato signaling relay: ok\n');
        await req.response.close();
        return;
      }
      if (_clients.length >= limits.maxConnections) {
        req.response.statusCode = HttpStatus.serviceUnavailable;
        await req.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req);
      ws.pingInterval = const Duration(seconds: 25);
      final c = _Client(ws);
      _clients.add(c);
      c.idle = Timer(limits.joinTimeout, () => _drop(c));
      ws.listen(
        (data) => _onFrame(c, data),
        onDone: () => _drop(c),
        onError: (Object _) => _drop(c),
        cancelOnError: true,
      );
    } catch (_) {
      // Bad upgrade request; nothing to clean up.
    }
  }

  void _touch(_Client c) {
    c.idle?.cancel();
    c.idle = Timer(limits.idleTimeout, () => _drop(c));
  }

  void _onFrame(_Client c, Object? data) {
    if (c.closed) return;
    if (data is! String) return _fail(c, 'bad');
    if (data.length > limits.maxFrameChars) return _fail(c, 'size');
    final now = DateTime.now();
    if (now.difference(c.windowStart) > limits.rateWindow) {
      c.windowStart = now;
      c.frames = 0;
    }
    if (++c.frames > limits.maxFramesPerWindow) return _fail(c, 'rate');
    final Object? j;
    try {
      j = jsonDecode(data);
    } on FormatException {
      return _fail(c, 'bad');
    }
    if (j is! Map) return _fail(c, 'bad');
    switch (j['t']) {
      case 'join':
        final room = j['room'];
        if (c.room != null || room is! String || !_roomPattern.hasMatch(room)) {
          return _fail(c, 'bad');
        }
        final members = _rooms[room];
        if (members == null && _rooms.length >= limits.maxRooms) {
          return _fail(c, 'full');
        }
        final list = members ?? (_rooms[room] = []);
        if (list.length >= 2) return _fail(c, 'full');
        c.room = room;
        for (final other in list) {
          other.send({'t': 'peer', 'ev': 'join'});
        }
        c.send({'t': 'joined', 'peers': list.length});
        list.add(c);
        _touch(c);
      case 'relay':
        final d = j['d'];
        final room = c.room;
        if (room == null || d is! String) return _fail(c, 'bad');
        _touch(c);
        for (final other in _rooms[room] ?? const <_Client>[]) {
          if (!identical(other, c)) other.send({'t': 'relay', 'd': d});
        }
      case 'ping':
        _touch(c);
        c.send({'t': 'pong'});
      case 'pong':
        _touch(c);
      default:
        _fail(c, 'bad');
    }
  }

  void _fail(_Client c, String code) {
    c.send({'t': 'error', 'code': code});
    _drop(c);
  }

  void _drop(_Client c) {
    if (c.closed) return;
    c.closed = true;
    c.idle?.cancel();
    _clients.remove(c);
    final room = c.room;
    if (room != null) {
      final list = _rooms[room];
      list?.remove(c);
      if (list == null || list.isEmpty) {
        _rooms.remove(room);
      } else {
        for (final other in list) {
          other.send({'t': 'peer', 'ev': 'leave'});
        }
      }
    }
    unawaited(c.socket.close().catchError((Object _) {}));
  }

  /// Stops listening and closes every socket.
  Future<void> close() async {
    for (final c in [..._clients]) {
      _drop(c);
    }
    await _server?.close(force: true);
    _server = null;
  }
}

Future<void> main(List<String> args) async {
  final port =
      int.tryParse(Platform.environment['PORT'] ?? '') ??
      (args.isNotEmpty ? int.tryParse(args.first) : null) ??
      8080;
  final relay = SignalingRelay();
  await relay.start(port: port);
  stdout.writeln('Insato signaling relay listening on port ${relay.port}');
  // Only counts are ever logged — never room ids or addresses.
  Timer.periodic(const Duration(minutes: 10), (_) {
    stdout.writeln(
      'rooms=${relay.roomCount} connections=${relay.connectionCount}',
    );
  });
}
