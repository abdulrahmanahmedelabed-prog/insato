// Test doubles of the meeting bot: a DevTools socket, a browser driver
// with a scripted page, and a recorder.

import 'dart:async';
import 'dart:convert';

import 'package:insato/features/meeting_bot/bot_audio.dart';
import 'package:insato/features/meeting_bot/bot_runner.dart';
import 'package:insato/features/meeting_bot/bot_scripts.dart';
import 'package:insato/features/meeting_bot/browser_driver.dart';
import 'package:insato/features/meeting_bot/cdp.dart';

/// A DevTools socket answering commands through [handler].
class FakeCdpSocket implements CdpSocket {
  FakeCdpSocket({this.handler});

  /// Returns the `result` map for a command, throws a [CdpException] for
  /// an error reply, or returns null to stay silent.
  Map<String, Object?>? Function(String method, Map<String, Object?> params)?
  handler;

  final _in = StreamController<String>.broadcast();
  final List<Map<String, Object?>> sent = [];
  bool closed = false;

  @override
  Stream<String> get messages => _in.stream;

  /// Pushes a raw message from the "browser".
  void push(Object message) =>
      _in.add(message is String ? message : jsonEncode(message));

  @override
  void send(String message) {
    final m = (jsonDecode(message) as Map).cast<String, Object?>();
    sent.add(m);
    final h = handler;
    if (h == null) return;
    final id = m['id'];
    final method = m['method'] as String;
    final params = (m['params'] as Map? ?? const {}).cast<String, Object?>();
    scheduleMicrotask(() {
      if (_in.isClosed) return;
      try {
        final result = h(method, params);
        if (result != null) push({'id': id, 'result': result});
      } on CdpException catch (e) {
        push({
          'id': id,
          'error': {'code': e.code ?? -32000, 'message': e.message},
        });
      }
    });
  }

  /// Simulates the browser going away.
  Future<void> drop() async {
    if (!_in.isClosed) await _in.close();
  }

  @override
  Future<void> close() async {
    closed = true;
    await drop();
  }

  /// Methods sent so far.
  List<String> get methods => [for (final m in sent) m['method'] as String];
}

/// A page whose state the test sets; records the action groups run.
class FakePage {
  BotPageState state = BotPageState.unknown;
  bool alone = false;
  int? participants;
  bool throwOnProbe = false;
  final List<String> actions = [];

  /// Called after an action group ran (to move the page along).
  void Function(String group)? onAction;
}

/// A browser session over a [FakePage].
class FakeBrowserSession implements BotBrowserSession {
  FakeBrowserSession(this.page, {this.pid = 4242});

  final FakePage page;
  final _gone = Completer<void>();
  bool closed = false;

  @override
  final int? pid;

  /// Simulates the user closing the browser window.
  void crash() {
    if (!_gone.isCompleted) _gone.complete();
  }

  @override
  bool get isAlive => !_gone.isCompleted;

  @override
  Future<void> get exited => _gone.future;

  @override
  Future<Object?> evaluate(String expression) async {
    if (!isAlive) throw const CdpException(CdpConnection.closedMessage);
    // The mode is the second argument of the page script call.
    final mode = _modeOf(expression);
    if (mode == 'probe') {
      if (page.throwOnProbe) throw const CdpException('timeout');
      return jsonEncode({
        'state': kBotPageStateNames[page.state],
        'alone': page.alone,
        'participants': page.participants,
        'url': 'https://example.invalid',
      });
    }
    page.actions.add(mode);
    page.onAction?.call(mode);
    return jsonEncode({
      'done': [mode],
      'missing': <String>[],
    });
  }

  static String _modeOf(String expression) {
    final match = RegExp(r', "([a-z_]+)", \{[^\n]*\}\)$')
        .firstMatch(expression);
    return match?.group(1) ?? '?';
  }

  int windowShown = 0;

  @override
  Future<void> showWindow() async => windowShown++;

  @override
  Future<void> close() async {
    closed = true;
    crash();
  }
}

/// Driver handing out [FakeBrowserSession]s.
class FakeBotDriver implements BotBrowserDriver {
  FakeBotDriver({FakePage? page}) : page = page ?? FakePage();

  final FakePage page;
  BotBrowserException? failWith;
  final List<BotLaunchOptions> launches = [];
  FakeBrowserSession? session;

  @override
  Future<BotBrowserSession> launch(BotLaunchOptions options) async {
    launches.add(options);
    final f = failWith;
    if (f != null) throw f;
    return session = FakeBrowserSession(page);
  }
}

/// Recorder recording its calls.
class FakeBotRecorder implements BotRecorder {
  final List<String> calls = [];
  final List<BotRecordingRequest> requests = [];
  Object? failWith;
  BotCaptureMode mode = BotCaptureMode.processLoopback;

  @override
  Future<BotRecordingStarted> start(BotRecordingRequest request) async {
    calls.add('start');
    requests.add(request);
    final f = failWith;
    if (f != null) throw f;
    return BotRecordingStarted(meetingId: 'meeting-1', mode: mode);
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

/// A settable clock.
class BotClock {
  BotClock([DateTime? start]) : now = start ?? DateTime(2026, 11, 20, 10);

  DateTime now;

  void advance(Duration d) => now = now.add(d);

  DateTime call() => now;
}
