// The bot's browser: a dedicated Microsoft Edge (or Chrome) process driven
// over the Chrome DevTools Protocol.
//
// Why a separate browser rather than an embedded WebView2 (e.g. package
// webview_windows)?
// * Process isolation: the bot's audio comes from its own process tree, so
//   Windows process-loopback capture (by PID) records the meeting and
//   nothing else — not Insato's own playback, not the user's music. An
//   embedded WebView2 would run as a child of Insato itself.
// * No new Flutter plugin, no NuGet download at build time, nothing native
//   for the browser side: Edge ships with Windows 10 / 11 (it is the same
//   engine as the WebView2 runtime), Chrome is used when Edge is missing.
// * A fresh, throw-away profile per run: the bot is always a guest without
//   cookies or accounts, and closing the process ends everything.
// * Its microphone is a silent file (`--use-file-for-fake-audio-capture`),
//   so even a "microphone on" mistake in a join flow can never transmit the
//   user's real microphone; the camera permission is denied.
//
// DevTools listens on 127.0.0.1 only, on a random port
// (`--remote-debugging-port=0`, read back from `DevToolsActivePort`).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'cdp.dart';

/// Why the browser could not be started.
enum BotBrowserFailure {
  /// Neither Edge nor Chrome was found.
  notFound,

  /// The process could not be started or exited at once.
  launchFailed,

  /// DevTools did not come up in time.
  devToolsTimeout,

  /// No page could be opened.
  noPage,
}

/// A browser start failure.
class BotBrowserException implements Exception {
  /// Creates the exception.
  const BotBrowserException(this.failure, [this.details]);

  /// What failed.
  final BotBrowserFailure failure;

  /// Technical details (logs only).
  final String? details;

  @override
  String toString() => 'BotBrowserException(${failure.name}: $details)';
}

/// How to start the bot's browser.
class BotLaunchOptions {
  /// Creates options.
  const BotLaunchOptions({required this.url, this.showWindow = false});

  /// Meeting address to open.
  final Uri url;

  /// Keep the browser window visible (otherwise it is minimised).
  final bool showWindow;
}

/// Starts bot browsers (fake in tests).
abstract class BotBrowserDriver {
  /// Starts a browser on [options.url]. Throws [BotBrowserException].
  Future<BotBrowserSession> launch(BotLaunchOptions options);
}

/// A running bot browser.
abstract class BotBrowserSession {
  /// Process id of the browser (root of its process tree), when known.
  int? get pid;

  /// True until the browser exits or DevTools disconnects.
  bool get isAlive;

  /// Completes when the browser is gone.
  Future<void> get exited;

  /// Evaluates [expression] in the meeting page; returns its value.
  /// Throws [CdpException].
  Future<Object?> evaluate(String expression);

  /// Restores and shows the (minimised) browser window, e.g. for a human
  /// check the user must complete. Throws [CdpException].
  Future<void> showWindow();

  /// Closes the browser (gracefully, then forcefully) and deletes its
  /// profile. Never throws.
  Future<void> close();
}

// ===========================================================================
// Pure helpers (unit-tested)
// ===========================================================================

/// Candidate executables, Edge first, from the Windows environment [env].
List<String> browserExecutableCandidates(Map<String, String> env) {
  final roots = <String>[
    for (final k in const ['ProgramFiles(x86)', 'ProgramFiles', 'LOCALAPPDATA'])
      if ((env[k] ?? '').trim().isNotEmpty) env[k]!.trim(),
  ];
  return [
    for (final r in roots)
      p.windows.join(r, 'Microsoft', 'Edge', 'Application', 'msedge.exe'),
    for (final r in roots)
      p.windows.join(r, 'Google', 'Chrome', 'Application', 'chrome.exe'),
  ];
}

/// The first existing candidate, or null.
String? findBrowserExecutable(
  Map<String, String> env,
  bool Function(String path) exists,
) {
  for (final c in browserExecutableCandidates(env)) {
    if (exists(c)) return c;
  }
  return null;
}

/// Command line of the bot browser.
List<String> botBrowserArguments({
  required String profileDir,
  required String silenceWavPath,
}) => [
  '--remote-debugging-port=0',
  '--remote-debugging-address=127.0.0.1',
  '--user-data-dir=$profileDir',
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-sync',
  '--disable-extensions',
  '--disable-default-apps',
  '--disable-notifications',
  '--lang=en-US',
  '--autoplay-policy=no-user-gesture-required',
  // Keep audio and timers running while the window is minimised.
  '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding',
  '--disable-backgrounding-occluded-windows',
  // The bot's "microphone" is a silent file: it can never send real audio.
  '--use-fake-device-for-media-stream',
  '--use-file-for-fake-audio-capture=$silenceWavPath',
  '--window-size=1280,800',
  'about:blank',
];

/// One second of 16 kHz mono PCM16 silence as a WAV file.
Uint8List silentWavBytes({int sampleRate = 16000, int seconds = 1}) {
  final dataBytes = sampleRate * seconds * 2;
  final b = ByteData(44 + dataBytes);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  return b.buffer.asUint8List();
}

/// Prepares a fresh DevTools page session on [cdp]: picks (or creates) a
/// page target, attaches to it, sets the permissions (microphone granted
/// to the silent fake device, camera / notifications denied), minimises
/// the window unless [showWindow], and opens [url]. Returns the session id.
Future<String> prepareBotPage(
  CdpConnection cdp, {
  required Uri url,
  bool showWindow = false,
}) async {
  final targets = await cdp.send('Target.getTargets');
  String? targetId;
  final infos = targets['targetInfos'];
  if (infos is List) {
    for (final t in infos) {
      if (t is Map && t['type'] == 'page' && t['targetId'] is String) {
        targetId = t['targetId'] as String;
        break;
      }
    }
  }
  if (targetId == null) {
    final created = await cdp.send(
      'Target.createTarget',
      params: {'url': 'about:blank'},
    );
    final id = created['targetId'];
    if (id is! String) {
      throw const BotBrowserException(BotBrowserFailure.noPage, 'no target');
    }
    targetId = id;
  }
  final attached = await cdp.send(
    'Target.attachToTarget',
    params: {'targetId': targetId, 'flatten': true},
  );
  final sessionId = attached['sessionId'];
  if (sessionId is! String) {
    throw const BotBrowserException(BotBrowserFailure.noPage, 'no session');
  }
  // Permissions for every origin. Failures are not fatal: the join flows
  // also turn the devices off in the page.
  for (final (name, setting) in const [
    ('microphone', 'granted'),
    ('camera', 'denied'),
    ('notifications', 'denied'),
  ]) {
    try {
      await cdp.send(
        'Browser.setPermission',
        params: {
          'permission': {'name': name},
          'setting': setting,
        },
      );
    } on CdpException {
      // Older browser: keep going.
    }
  }
  if (!showWindow) {
    try {
      final w = await cdp.send(
        'Browser.getWindowForTarget',
        params: {'targetId': targetId},
      );
      final windowId = w['windowId'];
      if (windowId is int) {
        await cdp.send(
          'Browser.setWindowBounds',
          params: {
            'windowId': windowId,
            'bounds': {'windowState': 'minimized'},
          },
        );
      }
    } on CdpException {
      // The window simply stays visible.
    }
  }
  await cdp.send(
    'Page.navigate',
    params: {'url': url.toString()},
    sessionId: sessionId,
  );
  return sessionId;
}

// ===========================================================================
// Edge / Chrome implementation
// ===========================================================================

/// Starts Edge (or Chrome) with a throw-away profile and drives it over
/// DevTools.
class ChromiumBotBrowserDriver implements BotBrowserDriver {
  /// Creates the driver. [environment], [exists] and [createProfileDir]
  /// are injectable for tests.
  ChromiumBotBrowserDriver({
    this.executable,
    this.extraArguments = const [],
    Map<String, String>? environment,
    bool Function(String path)? exists,
    Future<Directory> Function()? createProfileDir,
    this.devToolsTimeout = const Duration(seconds: 45),
  }) : _env = environment ?? Platform.environment,
       _exists = exists ?? ((path) => File(path).existsSync()),
       _createProfileDir =
           createProfileDir ??
           (() => Directory.systemTemp.createTemp('insato_meeting_bot_'));

  final Map<String, String> _env;
  final bool Function(String path) _exists;
  final Future<Directory> Function() _createProfileDir;

  /// How long to wait for DevTools after starting the process.
  final Duration devToolsTimeout;

  /// Browser to start instead of the detected Edge / Chrome.
  final String? executable;

  /// Extra command-line switches (e.g. `--headless=new` for diagnostics).
  final List<String> extraArguments;

  @override
  Future<BotBrowserSession> launch(BotLaunchOptions options) async {
    final exe = executable ?? findBrowserExecutable(_env, _exists);
    if (exe == null) {
      throw const BotBrowserException(BotBrowserFailure.notFound);
    }
    final Directory profile;
    try {
      profile = await _createProfileDir();
    } catch (e) {
      throw BotBrowserException(BotBrowserFailure.launchFailed, '$e');
    }
    final silence = File(p.join(profile.path, 'insato_silence.wav'));
    Process? process;
    CdpConnection? cdp;
    try {
      await silence.writeAsBytes(silentWavBytes(), flush: true);
      process = await Process.start(exe, [
        ...extraArguments,
        ...botBrowserArguments(
          profileDir: profile.path,
          silenceWavPath: silence.path,
        ),
      ]);
      // Drain the pipes so the browser never blocks on a full buffer.
      process.stdout.listen((_) {}, onError: (Object _) {});
      process.stderr.listen((_) {}, onError: (Object _) {});
      var exited = false;
      unawaited(process.exitCode.then((_) => exited = true));

      final portFile = File(p.join(profile.path, 'DevToolsActivePort'));
      final deadline = DateTime.now().add(devToolsTimeout);
      ({int port, String path})? endpoint;
      while (endpoint == null) {
        if (exited) {
          throw const BotBrowserException(
            BotBrowserFailure.launchFailed,
            'browser exited during start-up',
          );
        }
        if (DateTime.now().isAfter(deadline)) {
          throw const BotBrowserException(BotBrowserFailure.devToolsTimeout);
        }
        try {
          if (portFile.existsSync()) {
            endpoint = parseDevToolsActivePort(await portFile.readAsString());
          }
        } on FileSystemException {
          // Being written; try again.
        }
        if (endpoint == null) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
      final socket = await IoCdpSocket.connect(
        Uri.parse('ws://127.0.0.1:${endpoint.port}${endpoint.path}'),
      );
      cdp = CdpConnection(socket);
      final sessionId = await prepareBotPage(
        cdp,
        url: options.url,
        showWindow: options.showWindow,
      );
      return _ChromiumSession(process, cdp, sessionId, profile);
    } catch (e) {
      await cdp?.close();
      process?.kill();
      await _deleteProfile(profile);
      if (e is BotBrowserException) rethrow;
      throw BotBrowserException(BotBrowserFailure.launchFailed, '$e');
    }
  }
}

Future<void> _deleteProfile(Directory dir) async {
  // The browser may hold files for a moment after exiting.
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      return;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }
}

class _ChromiumSession implements BotBrowserSession {
  _ChromiumSession(this._process, this._cdp, this._sessionId, this._profile) {
    unawaited(_process.exitCode.then((_) => _markGone()));
    unawaited(_cdp.done.then((_) => _markGone()));
    unawaited(
      _cdp
          .send('Target.getTargetInfo', sessionId: _sessionId)
          .then((r) {
            final info = r['targetInfo'];
            if (info is Map && info['targetId'] is String) {
              _targetId = info['targetId'] as String;
            }
          })
          .catchError((Object _) {}),
    );
    _detachSub = _cdp.events.listen((e) {
      if (e.method == 'Target.detachedFromTarget' &&
          e.params['sessionId'] == _sessionId) {
        _markGone();
      }
    });
  }

  final Process _process;
  final CdpConnection _cdp;
  final String _sessionId;
  final Directory _profile;
  final Completer<void> _gone = Completer<void>();
  StreamSubscription<CdpEvent>? _detachSub;
  bool _closing = false;
  String? _targetId;

  void _markGone() {
    if (!_gone.isCompleted) _gone.complete();
  }

  @override
  int? get pid => _process.pid;

  @override
  bool get isAlive => !_gone.isCompleted;

  @override
  Future<void> get exited => _gone.future;

  @override
  Future<Object?> evaluate(String expression) => cdpEvaluate(
    _cdp,
    expression,
    sessionId: _sessionId,
    timeout: const Duration(seconds: 10),
  );

  @override
  Future<void> showWindow() async {
    final w = await _cdp.send(
      'Browser.getWindowForTarget',
      params: {'targetId': ?_targetId},
    );
    final windowId = w['windowId'];
    if (windowId is! int) return;
    await _cdp.send(
      'Browser.setWindowBounds',
      params: {
        'windowId': windowId,
        'bounds': {'windowState': 'normal'},
      },
    );
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    await _detachSub?.cancel();
    try {
      await _cdp.send('Browser.close', timeout: const Duration(seconds: 3));
    } catch (_) {
      // Fall through to kill.
    }
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process.kill();
      try {
        await _process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        // Give up waiting; the profile delete below may fail.
      }
    }
    await _cdp.close();
    _markGone();
    await _deleteProfile(_profile);
  }
}
