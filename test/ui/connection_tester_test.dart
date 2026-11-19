import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:katib/ui/services/connection_tester.dart';

import '../minutes/sse_fixtures.dart';

http.StreamedResponse jsonError(int status, String type, String message) =>
    http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'type': 'error',
            'error': {'type': type, 'message': message},
          }),
        ),
      ),
      status,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  test('a successful ping reports the served model', () async {
    final q = QueueClient([
      () => chunkedResponse(successStream('{"ok": true}', model: 'claude-x')),
    ]);
    final r = await ClaudeConnectionTester(client: q.client)
        .test(' sk-test ', model: 'claude-x');
    expect(r.ok, isTrue);
    expect(r.model, 'claude-x');
    expect(q.requests.single.headers['x-api-key'], 'sk-test');
    final body = jsonDecode(q.bodies.single) as Map<String, dynamic>;
    expect(body['model'], 'claude-x');
    expect(body['max_tokens'], lessThanOrEqualTo(1024));
    expect((body['output_config'] as Map)['effort'], 'low');
  });

  test('running out of the tiny token budget still proves the key', () async {
    final q = QueueClient([
      () => chunkedResponse(successStream('{"o', stopReason: 'max_tokens')),
    ]);
    final r = await ClaudeConnectionTester(client: q.client).test('k');
    expect(r.ok, isTrue);
  });

  test('a rejected key gives the Arabic invalid-key message', () async {
    final q = QueueClient([
      () => jsonError(401, 'authentication_error', 'invalid x-api-key'),
    ]);
    final r = await ClaudeConnectionTester(client: q.client).test('bad');
    expect(r.ok, isFalse);
    expect(r.messageAr, contains('غير صالح'));
  });

  test('an unknown model is reported', () async {
    final q = QueueClient([
      () => jsonError(404, 'not_found_error', 'model: nope'),
    ]);
    final r = await ClaudeConnectionTester(client: q.client)
        .test('k', model: 'nope');
    expect(r.ok, isFalse);
    expect(r.messageAr, contains('nope'));
  });

  test('an empty key fails without any request', () async {
    final q = QueueClient([]);
    final r = await ClaudeConnectionTester(client: q.client).test('   ');
    expect(r.ok, isFalse);
    expect(q.requests, isEmpty);
  });
}
