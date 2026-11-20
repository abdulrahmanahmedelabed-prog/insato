import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/features/groq/groq_api.dart';
import 'package:insato/features/groq/strings.dart';
import 'package:insato/ui/services/connection_tester.dart';

http.Response _models(List<Map<String, dynamic>> data) => http.Response(
  jsonEncode({'object': 'list', 'data': data}),
  200,
  headers: const {'content-type': 'application/json'},
);

const _list = [
  {'id': 'llama-3.3-70b-versatile', 'active': true, 'context_window': 131072},
  {'id': 'openai/gpt-oss-120b', 'active': true, 'context_window': 131072},
  {'id': 'whisper-large-v3', 'active': true, 'context_window': 448},
];

void main() {
  group('GroqConnectionTester', () {
    test('lists models with the key and reports the automatic choice',
        () async {
      final seen = <http.Request>[];
      final t = GroqConnectionTester(
        client: MockClient((r) async {
          seen.add(r);
          return _models(_list);
        }),
        gate: GroqRateGate(),
      );
      final r = await t.test(' gsk_test ');
      expect(r.ok, isTrue);
      expect(r.model, 'openai/gpt-oss-120b');
      expect(seen.single.method, 'GET');
      expect(seen.single.url.toString(),
          'https://api.groq.com/openai/v1/models');
      expect(seen.single.headers['authorization'], 'Bearer gsk_test');
    });

    test('a configured model the key has is kept', () async {
      final t = GroqConnectionTester(
        client: MockClient((_) async => _models(_list)),
        gate: GroqRateGate(),
      );
      final r = await t.test('k', model: 'llama-3.3-70b-versatile');
      expect(r.ok, isTrue);
      expect(r.model, 'llama-3.3-70b-versatile');
    });

    test('a rejected key gives the Arabic invalid-key message', () async {
      final t = GroqConnectionTester(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'Invalid API Key', 'type': 'invalid_request_error'},
            }),
            401,
          ),
        ),
        gate: GroqRateGate(),
      );
      final r = await t.test('bad');
      expect(r.ok, isFalse);
      expect(r.messageAr, GS.keyInvalid);
    });

    test('no usable chat model is reported', () async {
      final t = GroqConnectionTester(
        client: MockClient(
          (_) async => _models(const [
            {'id': 'whisper-large-v3', 'active': true},
          ]),
        ),
        gate: GroqRateGate(),
      );
      final r = await t.test('k');
      expect(r.ok, isFalse);
      expect(r.messageAr, GS.noModel);
    });

    test('an empty key fails without any request', () async {
      var calls = 0;
      final t = GroqConnectionTester(
        client: MockClient((_) async {
          calls++;
          return _models(_list);
        }),
      );
      final r = await t.test('   ');
      expect(r.ok, isFalse);
      expect(r.messageAr, GS.testNoKey);
      expect(calls, 0);
    });
  });
}
