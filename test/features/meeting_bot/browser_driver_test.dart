// Browser discovery, command line, silent microphone file and the DevTools
// page preparation (over a fake socket).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/meeting_bot/browser_driver.dart';
import 'package:insato/features/meeting_bot/cdp.dart';

import 'bot_fakes.dart';

void main() {
  const env = {
    'ProgramFiles(x86)': r'C:\Program Files (x86)',
    'ProgramFiles': r'C:\Program Files',
    'LOCALAPPDATA': r'C:\Users\u\AppData\Local',
  };

  test('Edge is preferred, Chrome is the fallback', () {
    final candidates = browserExecutableCandidates(env);
    expect(
      candidates.first,
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    );
    expect(candidates.where((c) => c.endsWith('msedge.exe')), hasLength(3));
    expect(
      findBrowserExecutable(
        env,
        (p) =>
            p ==
            r'C:\Users\u\AppData\Local\Google\Chrome\Application\chrome.exe',
      ),
      r'C:\Users\u\AppData\Local\Google\Chrome\Application\chrome.exe',
    );
    expect(findBrowserExecutable(env, (_) => false), isNull);
    expect(browserExecutableCandidates(const {}), isEmpty);
  });

  test('a missing browser is reported before anything starts', () async {
    final driver = ChromiumBotBrowserDriver(
      environment: env,
      exists: (_) => false,
    );
    await expectLater(
      driver.launch(BotLaunchOptions(url: Uri.parse('https://x.invalid'))),
      throwsA(
        isA<BotBrowserException>().having(
          (e) => e.failure,
          'failure',
          BotBrowserFailure.notFound,
        ),
      ),
    );
  });

  test('command line: private profile, local DevTools, silent mic', () {
    final args = botBrowserArguments(
      profileDir: r'C:\t\p',
      silenceWavPath: r'C:\t\p\s.wav',
    );
    expect(args, contains('--remote-debugging-port=0'));
    expect(args, contains(r'--user-data-dir=C:\t\p'));
    expect(args, contains('--use-fake-device-for-media-stream'));
    expect(args, contains(r'--use-file-for-fake-audio-capture=C:\t\p\s.wav'));
    expect(args, contains('--lang=en-US'));
    expect(args, contains('--autoplay-policy=no-user-gesture-required'));
    // Never auto-accept permission prompts or run headless (Meet refuses
    // headless browsers).
    expect(args.any((a) => a.contains('fake-ui')), isFalse);
    expect(args.any((a) => a.contains('headless')), isFalse);
  });

  test('the silent microphone is a valid PCM16 WAV of zeros', () {
    final b = silentWavBytes();
    final d = ByteData.sublistView(b);
    expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
    expect(d.getUint16(22, Endian.little), 1);
    expect(d.getUint32(24, Endian.little), 16000);
    expect(d.getUint16(34, Endian.little), 16);
    expect(d.getUint32(40, Endian.little), 32000);
    expect(b.length, 44 + 32000);
    expect(b.skip(44).every((x) => x == 0), isTrue);
  });

  test('page preparation: attach, permissions, minimise, navigate', () async {
    final socket = FakeCdpSocket(
      handler: (method, params) => switch (method) {
        'Target.getTargets' => {
          'targetInfos': [
            {'targetId': 'B', 'type': 'browser'},
            {'targetId': 'T1', 'type': 'page'},
          ],
        },
        'Target.attachToTarget' => {'sessionId': 'S1'},
        'Browser.getWindowForTarget' => {'windowId': 7},
        'Browser.setPermission'
            when (params['permission'] as Map)['name'] == 'notifications' =>
          throw const CdpException('unknown permission', code: -32602),
        _ => <String, Object?>{},
      },
    );
    final cdp = CdpConnection(socket);
    final session = await prepareBotPage(
      cdp,
      url: Uri.parse('https://meet.google.com/abc-defg-hij'),
    );
    expect(session, 'S1');
    expect(socket.methods, [
      'Target.getTargets',
      'Target.attachToTarget',
      'Browser.setPermission',
      'Browser.setPermission',
      'Browser.setPermission',
      'Browser.getWindowForTarget',
      'Browser.setWindowBounds',
      'Page.navigate',
    ]);
    final attach = socket.sent[1]['params'] as Map;
    expect(attach['targetId'], 'T1');
    expect(attach['flatten'], isTrue);
    final perms = {
      for (final m in socket.sent.where(
        (m) => m['method'] == 'Browser.setPermission',
      ))
        ((m['params'] as Map)['permission'] as Map)['name']:
            (m['params'] as Map)['setting'],
    };
    expect(perms, {
      'microphone': 'granted',
      'camera': 'denied',
      'notifications': 'denied',
    });
    final bounds = socket.sent[6]['params'] as Map;
    expect(bounds['windowId'], 7);
    expect((bounds['bounds'] as Map)['windowState'], 'minimized');
    final nav = socket.sent.last;
    expect(nav['sessionId'], 'S1');
    expect(
      (nav['params'] as Map)['url'],
      'https://meet.google.com/abc-defg-hij',
    );
    await cdp.close();
  });

  test(
    'a visible window is not minimised; a missing page is created',
    () async {
      final socket = FakeCdpSocket(
        handler: (method, params) => switch (method) {
          'Target.getTargets' => {'targetInfos': <Object>[]},
          'Target.createTarget' => {'targetId': 'NEW'},
          'Target.attachToTarget' => {'sessionId': 'S2'},
          _ => <String, Object?>{},
        },
      );
      final cdp = CdpConnection(socket);
      await prepareBotPage(
        cdp,
        url: Uri.parse('https://teams.live.com/meet/123456'),
        showWindow: true,
      );
      expect(socket.methods, contains('Target.createTarget'));
      expect(socket.methods, isNot(contains('Browser.setWindowBounds')));
      expect((socket.sent[2]['params'] as Map)['targetId'], 'NEW');
      await cdp.close();
    },
  );
}
