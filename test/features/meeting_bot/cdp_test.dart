// DevTools protocol client over a fake socket.

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/meeting_bot/cdp.dart';

import 'bot_fakes.dart';

void main() {
  test('replies complete the matching command; ids increase', () async {
    final socket = FakeCdpSocket(
      handler: (method, params) => {'echo': method, 'x': params['x']},
    );
    final cdp = CdpConnection(socket);
    final a = cdp.send('A.one', params: {'x': 1});
    final b = cdp.send('B.two', params: {'x': 2}, sessionId: 'S1');
    expect((await b)['echo'], 'B.two');
    expect((await a)['x'], 1);
    expect(socket.sent[0]['id'], 1);
    expect(socket.sent[1]['id'], 2);
    expect(socket.sent[0].containsKey('sessionId'), isFalse);
    expect(socket.sent[1]['sessionId'], 'S1');
    expect(cdp.pendingCount, 0);
    await cdp.close();
    expect(socket.closed, isTrue);
  });

  test('error replies become CdpException with code and method', () async {
    final socket = FakeCdpSocket(
      handler: (method, params) =>
          throw const CdpException('No target', code: -32602),
    );
    final cdp = CdpConnection(socket);
    await expectLater(
      cdp.send('Target.attachToTarget'),
      throwsA(
        isA<CdpException>()
            .having((e) => e.code, 'code', -32602)
            .having((e) => e.method, 'method', 'Target.attachToTarget')
            .having((e) => e.message, 'message', 'No target'),
      ),
    );
    await cdp.close();
  });

  test('events carry their session; junk is ignored', () async {
    final socket = FakeCdpSocket();
    final cdp = CdpConnection(socket);
    final events = <CdpEvent>[];
    cdp.events.listen(events.add);
    socket
      ..push('not json')
      ..push([1, 2])
      ..push({'id': 99, 'result': {}}) // reply to nothing
      ..push({
        'method': 'Target.detachedFromTarget',
        'params': {'sessionId': 'S1'},
        'sessionId': 'S0',
      })
      ..push({'method': 'Page.loadEventFired'});
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.method), [
      'Target.detachedFromTarget',
      'Page.loadEventFired',
    ]);
    expect(events.first.sessionId, 'S0');
    expect(events.first.params['sessionId'], 'S1');
    expect(events.last.sessionId, isNull);
    await cdp.close();
  });

  test('a command without a reply times out', () async {
    final cdp = CdpConnection(
      FakeCdpSocket(),
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      cdp.send('Runtime.evaluate'),
      throwsA(
        isA<CdpException>().having((e) => e.message, 'message', 'timeout'),
      ),
    );
    expect(cdp.pendingCount, 0);
    await cdp.close();
  });

  test('a dropped connection fails pending and later commands', () async {
    final socket = FakeCdpSocket();
    final cdp = CdpConnection(socket);
    final pending = cdp.send('Runtime.evaluate');
    await socket.drop();
    await expectLater(
      pending,
      throwsA(isA<CdpException>().having((e) => e.isClosed, 'closed', true)),
    );
    await cdp.done;
    expect(cdp.isClosed, isTrue);
    await expectLater(cdp.send('Browser.close'), throwsA(isA<CdpException>()));
  });

  test('cdpEvaluate returns the value or throws the JS exception', () async {
    var throwJs = false;
    final socket = FakeCdpSocket(
      handler: (method, params) {
        expect(method, 'Runtime.evaluate');
        expect(params['returnByValue'], isTrue);
        if (throwJs) {
          return {
            'result': {'type': 'object'},
            'exceptionDetails': {
              'text': 'Uncaught',
              'exception': {'description': 'ReferenceError: x'},
            },
          };
        }
        return {
          'result': {'type': 'string', 'value': '{"state":"lobby"}'},
        };
      },
    );
    final cdp = CdpConnection(socket);
    expect(await cdpEvaluate(cdp, '1+1', sessionId: 'S'), '{"state":"lobby"}');
    expect(socket.sent.last['sessionId'], 'S');
    throwJs = true;
    await expectLater(
      cdpEvaluate(cdp, 'x', sessionId: 'S'),
      throwsA(
        isA<CdpException>().having(
          (e) => e.message,
          'message',
          contains('ReferenceError'),
        ),
      ),
    );
    await cdp.close();
  });

  test('DevToolsActivePort parsing', () {
    expect(parseDevToolsActivePort('53123\n/devtools/browser/abc-def\n'), (
      port: 53123,
      path: '/devtools/browser/abc-def',
    ));
    expect(parseDevToolsActivePort('\r\n9222\r\n/devtools/browser/x\r\n'), (
      port: 9222,
      path: '/devtools/browser/x',
    ));
    expect(parseDevToolsActivePort(''), isNull);
    expect(parseDevToolsActivePort('53123\n'), isNull);
    expect(parseDevToolsActivePort('abc\n/devtools/browser/x'), isNull);
    expect(parseDevToolsActivePort('70000\n/devtools/browser/x'), isNull);
    expect(parseDevToolsActivePort('9222\n/json/version'), isNull);
  });
}
