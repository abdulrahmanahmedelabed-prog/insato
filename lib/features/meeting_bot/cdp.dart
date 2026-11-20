// Minimal Chrome DevTools Protocol client over a local WebSocket (dart:io).
//
// Only what the meeting bot needs: numbered commands with replies, events,
// flattened target sessions (`sessionId` on every message) and clean
// failure when the browser goes away. No Node / Playwright at runtime.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A text-frame transport (a WebSocket in production, a fake in tests).
abstract class CdpSocket {
  /// Incoming text messages; done when the connection closes.
  Stream<String> get messages;

  /// Sends one text message.
  void send(String message);

  /// Closes the connection.
  Future<void> close();
}

/// [CdpSocket] over a dart:io [WebSocket].
class IoCdpSocket implements CdpSocket {
  IoCdpSocket._(this._ws)
    : messages = _ws
          .where((m) => m is String)
          .cast<String>()
          .asBroadcastStream();

  /// Connects to [uri] (`ws://127.0.0.1:<port>/devtools/browser/<id>`).
  static Future<IoCdpSocket> connect(
    Uri uri, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final ws = await WebSocket.connect(uri.toString()).timeout(timeout);
    // DevTools messages (DOM snapshots, page text) can be large.
    ws.pingInterval = const Duration(seconds: 10);
    return IoCdpSocket._(ws);
  }

  final WebSocket _ws;

  @override
  final Stream<String> messages;

  @override
  void send(String message) => _ws.add(message);

  @override
  Future<void> close() async {
    try {
      await _ws.close();
    } catch (_) {
      // Already closed.
    }
  }
}

/// A protocol error reply, a timeout or a closed connection.
class CdpException implements Exception {
  /// Creates the exception.
  const CdpException(this.message, {this.method, this.code});

  /// Description (from the browser, or local).
  final String message;

  /// Command that failed, when known.
  final String? method;

  /// Protocol error code, when the browser replied with an error.
  final int? code;

  /// True when the connection is gone.
  bool get isClosed => code == null && message == CdpConnection.closedMessage;

  @override
  String toString() =>
      'CdpException(${method ?? '-'}: $message${code == null ? '' : ' [$code]'})';
}

/// An event sent by the browser.
class CdpEvent {
  /// Creates an event.
  const CdpEvent(this.method, this.params, {this.sessionId});

  /// Event name, e.g. `Target.detachedFromTarget`.
  final String method;

  /// Event parameters.
  final Map<String, Object?> params;

  /// Target session of the event (null for browser-level events).
  final String? sessionId;
}

/// A DevTools connection: [send] commands, listen to [events].
class CdpConnection {
  /// Wraps [socket]. Commands without a reply after [timeout] fail.
  CdpConnection(this._socket, {this.timeout = const Duration(seconds: 15)}) {
    _sub = _socket.messages.listen(
      _onMessage,
      onError: (Object _) => _onClosed(),
      onDone: _onClosed,
      cancelOnError: true,
    );
  }

  /// Message of the exception thrown once the connection is closed.
  static const String closedMessage = 'connection closed';

  final CdpSocket _socket;

  /// Default reply timeout.
  final Duration timeout;

  // Cancelled by [_onClosed].
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _sub;
  final Map<int, _Pending> _pending = {};
  final _events = StreamController<CdpEvent>.broadcast();
  final Completer<void> _closed = Completer<void>();
  int _nextId = 1;

  /// Browser events.
  Stream<CdpEvent> get events => _events.stream;

  /// Completes when the connection is closed (by either side).
  Future<void> get done => _closed.future;

  /// True once closed.
  bool get isClosed => _closed.isCompleted;

  /// Commands waiting for a reply.
  int get pendingCount => _pending.length;

  /// Sends [method] with [params] (to the target [sessionId] when given)
  /// and returns the reply's `result`. Throws [CdpException].
  Future<Map<String, Object?>> send(
    String method, {
    Map<String, Object?> params = const {},
    String? sessionId,
    Duration? timeout,
  }) {
    if (isClosed) {
      return Future.error(CdpException(closedMessage, method: method));
    }
    final id = _nextId++;
    final pending = _Pending(method);
    _pending[id] = pending;
    pending.timer = Timer(timeout ?? this.timeout, () {
      if (_pending.remove(id) != null && !pending.completer.isCompleted) {
        pending.completer.completeError(
          CdpException('timeout', method: method),
        );
      }
    });
    final message = <String, Object?>{
      'id': id,
      'method': method,
      'params': params,
      'sessionId': ?sessionId,
    };
    try {
      _socket.send(jsonEncode(message));
    } catch (e) {
      _pending.remove(id);
      pending.timer?.cancel();
      return Future.error(CdpException('send failed: $e', method: method));
    }
    return pending.completer.future;
  }

  /// Closes the connection; pending commands fail.
  Future<void> close() async {
    if (isClosed) return;
    await _socket.close();
    _onClosed();
  }

  void _onMessage(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return; // Not ours to interpret.
    }
    if (decoded is! Map) return;
    final id = decoded['id'];
    if (id is int) {
      final pending = _pending.remove(id);
      if (pending == null) return; // Late reply after a timeout.
      pending.timer?.cancel();
      final error = decoded['error'];
      if (error is Map) {
        final code = error['code'];
        pending.completer.completeError(
          CdpException(
            '${error['message'] ?? 'error'}',
            method: pending.method,
            code: code is int ? code : -1,
          ),
        );
        return;
      }
      final result = decoded['result'];
      pending.completer.complete(
        result is Map ? result.cast<String, Object?>() : const {},
      );
      return;
    }
    final method = decoded['method'];
    if (method is String && !_events.isClosed) {
      final params = decoded['params'];
      final session = decoded['sessionId'];
      _events.add(
        CdpEvent(
          method,
          params is Map ? params.cast<String, Object?>() : const {},
          sessionId: session is String ? session : null,
        ),
      );
    }
  }

  void _onClosed() {
    if (_closed.isCompleted) return;
    _closed.complete();
    final sub = _sub;
    _sub = null;
    unawaited(sub?.cancel());
    final pending = _pending.values.toList();
    _pending.clear();
    for (final p in pending) {
      p.timer?.cancel();
      if (!p.completer.isCompleted) {
        p.completer.completeError(
          CdpException(closedMessage, method: p.method),
        );
      }
    }
    unawaited(_events.close());
  }
}

class _Pending {
  _Pending(this.method);

  final String method;
  final Completer<Map<String, Object?>> completer =
      Completer<Map<String, Object?>>();
  Timer? timer;
}

/// Evaluates [expression] in the target [sessionId] and returns its value
/// (`returnByValue`). A JavaScript exception becomes a [CdpException].
Future<Object?> cdpEvaluate(
  CdpConnection cdp,
  String expression, {
  required String sessionId,
  Duration? timeout,
}) async {
  final reply = await cdp.send(
    'Runtime.evaluate',
    params: {
      'expression': expression,
      'returnByValue': true,
      'awaitPromise': true,
    },
    sessionId: sessionId,
    timeout: timeout,
  );
  final details = reply['exceptionDetails'];
  if (details is Map) {
    final ex = details['exception'];
    final text = ex is Map
        ? ex['description'] ?? details['text']
        : details['text'];
    throw CdpException('$text', method: 'Runtime.evaluate');
  }
  final result = reply['result'];
  return result is Map ? result['value'] : null;
}

/// Port and browser WebSocket path from the `DevToolsActivePort` file that
/// Chromium writes into its profile when started with
/// `--remote-debugging-port=0` (line 1: port, line 2: path). Null when the
/// content is incomplete.
({int port, String path})? parseDevToolsActivePort(String content) {
  final lines = const LineSplitter()
      .convert(content)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 2) return null;
  final port = int.tryParse(lines[0]);
  if (port == null || port <= 0 || port > 65535) return null;
  final path = lines[1];
  if (!path.startsWith('/devtools/browser/')) return null;
  return (port: port, path: path);
}
