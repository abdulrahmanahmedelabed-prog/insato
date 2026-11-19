import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:katib/core/errors.dart';
import 'package:katib/minutes/claude_client.dart';

import 'sse_fixtures.dart';

const _schema = {
  'type': 'object',
  'properties': {
    'a': {'type': 'string'},
  },
  'required': ['a'],
  'additionalProperties': false,
};

void main() {
  late List<Duration> delays;

  ClaudeClient makeClient(QueueClient q, {String apiKey = 'sk-test'}) {
    delays = [];
    return ClaudeClient(
      apiKey: apiKey,
      client: q.client,
      delay: (d) async => delays.add(d),
      random: Random(1),
    );
  }

  Future<ClaudeResult> call(ClaudeClient c, {List<int>? deltas}) =>
      c.createStructured(
        system: 'SYS',
        user: 'USER',
        schema: _schema,
        onDelta: deltas?.add,
      );

  test('successful stream: request shape, text, model, usage', () async {
    const answer = '{"a":"قيمة عربية طويلة نسبياً"}';
    final q = QueueClient([() => chunkedResponse(successStream(answer))]);
    final deltas = <int>[];
    final result = await call(makeClient(q), deltas: deltas);

    expect(result.text, answer);
    expect(result.model, 'claude-opus-5-5');
    expect(result.stopReason, 'end_turn');
    expect(result.messageId, 'msg_1');
    expect(result.usage.inputTokens, 1200);
    expect(result.usage.cacheReadInputTokens, 800);
    expect(result.usage.outputTokens, 345);
    expect(result.fallbackFromModels, isEmpty);
    expect(deltas.last, answer.length);
    expect(deltas, orderedEquals([...deltas]..sort()));

    final req = q.requests.single;
    expect(req.method, 'POST');
    expect(req.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(req.headers['x-api-key'], 'sk-test');
    expect(req.headers['anthropic-version'], '2026-10-21');
    expect(req.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
    expect(req.headers['content-type'], startsWith('application/json'));

    final body = jsonDecode(q.bodies.single) as Map<String, dynamic>;
    expect(body['model'], 'claude-opus-5-5');
    expect(body['max_tokens'], 64000);
    expect(body['stream'], true);
    expect(body['thinking'], {'type': 'adaptive'});
    expect(body['fallbacks'], 'default');
    expect(body['output_config'], {
      'effort': 'high',
      'format': {'type': 'json_schema', 'schema': _schema},
    });
    expect(body['system'], [
      {
        'type': 'text',
        'text': 'SYS',
        'cache_control': {'type': 'ephemeral'},
      },
    ]);
    expect(body['messages'], [
      {'role': 'user', 'content': 'USER'},
    ]);
    for (final forbidden in ['temperature', 'top_p', 'top_k']) {
      expect(body.containsKey(forbidden), isFalse);
    }
    expect(jsonEncode(body).contains('budget_tokens'), isFalse);
  });

  test('records the fallback model as the served model', () async {
    final q = QueueClient([
      () => chunkedResponse(
        successStream('{"a":"x"}', fallbackTo: 'claude-opus-5'),
      ),
    ]);
    final result = await call(makeClient(q));
    expect(result.model, 'claude-opus-5');
    expect(result.fallbackFromModels, ['claude-opus-5-5']);
  });

  test('refusal throws a non-retryable MinutesGenerationException', () async {
    final q = QueueClient([
      () => chunkedResponse(successStream('', stopReason: 'refusal')),
    ]);
    await expectLater(
      call(makeClient(q)),
      throwsA(
        isA<MinutesGenerationException>()
            .having((e) => e.retryable, 'retryable', false)
            .having((e) => e.messageAr, 'messageAr', contains('اعتذر')),
      ),
    );
  });

  test('max_tokens throws (truncated output)', () async {
    final q = QueueClient([
      () => chunkedResponse(successStream('{"a":', stopReason: 'max_tokens')),
    ]);
    await expectLater(
      call(makeClient(q)),
      throwsA(
        isA<MinutesGenerationException>().having(
          (e) => e.messageAr,
          'messageAr',
          contains('الحد الأقصى'),
        ),
      ),
    );
  });

  test('429 then success retries, honouring retry-after', () async {
    final q = QueueClient([
      () => chunkedResponse(
        jsonEncode({
          'type': 'error',
          'error': {'type': 'rate_limit_error', 'message': 'slow down'},
        }),
        status: 429,
        headers: {'retry-after': '7'},
      ),
      () => chunkedResponse(successStream('{"a":"ok"}')),
    ]);
    final result = await call(makeClient(q));
    expect(result.text, '{"a":"ok"}');
    expect(q.requests, hasLength(2));
    expect(delays, hasLength(1));
    expect(delays.single.inMilliseconds, inInclusiveRange(7000, 7250));
  });

  test(
    '529/500 and network errors back off exponentially, then give up',
    () async {
      final q = QueueClient([
        () => chunkedResponse('{}', status: 529),
        () => chunkedResponse('{}', status: 500),
        () => throw http.ClientException('connection reset'),
        () => chunkedResponse('{}', status: 529),
      ]);
      await expectLater(
        call(makeClient(q)),
        throwsA(
          isA<MinutesGenerationException>().having(
            (e) => e.retryable,
            'retryable',
            true,
          ),
        ),
      );
      expect(q.requests, hasLength(4));
      expect(delays, hasLength(3));
      // base 2s with jitter in [50%, 100%]: 1-2s, 2-4s, 4-8s.
      expect(delays[0].inMilliseconds, inInclusiveRange(1000, 2000));
      expect(delays[1].inMilliseconds, inInclusiveRange(2000, 4000));
      expect(delays[2].inMilliseconds, inInclusiveRange(4000, 8000));
    },
  );

  test('mid-stream overloaded error event is retried', () async {
    final broken = StringBuffer()
      ..write(
        sseEvent('message_start', {
          'message': {'id': 'm', 'model': 'claude-opus-5-5'},
        }),
      )
      ..write(
        sseEvent('error', {
          'error': {'type': 'overloaded_error', 'message': 'Overloaded'},
        }),
      );
    final q = QueueClient([
      () => chunkedResponse(broken.toString()),
      () => chunkedResponse(successStream('{"a":"b"}')),
    ]);
    final result = await call(makeClient(q));
    expect(result.text, '{"a":"b"}');
    expect(q.requests, hasLength(2));
  });

  test('stream cut before message_delta is retried', () async {
    final q = QueueClient([
      () => chunkedResponse(
        sseEvent('message_start', {
          'message': {'id': 'm', 'model': 'claude-opus-5-5'},
        }),
      ),
      () => chunkedResponse(successStream('{"a":"c"}')),
    ]);
    expect((await call(makeClient(q))).text, '{"a":"c"}');
  });

  test('401 throws MissingApiKeyException without retrying', () async {
    final q = QueueClient([
      () => chunkedResponse(
        jsonEncode({
          'type': 'error',
          'error': {
            'type': 'authentication_error',
            'message': 'invalid x-api-key',
          },
        }),
        status: 401,
      ),
    ]);
    await expectLater(
      call(makeClient(q)),
      throwsA(
        isA<MissingApiKeyException>().having(
          (e) => e.debugDetails,
          'debugDetails',
          contains('invalid x-api-key'),
        ),
      ),
    );
    expect(q.requests, hasLength(1));
  });

  test('400 is non-retryable and carries the API message', () async {
    final q = QueueClient([
      () => chunkedResponse(
        jsonEncode({
          'type': 'error',
          'error': {
            'type': 'invalid_request_error',
            'message': 'schema is invalid',
          },
        }),
        status: 400,
      ),
    ]);
    await expectLater(
      call(makeClient(q)),
      throwsA(
        isA<MinutesGenerationException>()
            .having((e) => e.retryable, 'retryable', false)
            .having(
              (e) => e.debugDetails,
              'debugDetails',
              contains('schema is invalid'),
            ),
      ),
    );
    expect(q.requests, hasLength(1));
  });

  test('empty api key fails fast', () async {
    final q = QueueClient([]);
    await expectLater(
      call(makeClient(q, apiKey: '  ')),
      throwsA(isA<MissingApiKeyException>()),
    );
    expect(q.requests, isEmpty);
  });
}
