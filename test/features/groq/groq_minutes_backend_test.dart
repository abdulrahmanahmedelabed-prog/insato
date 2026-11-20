import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/features/groq/groq_api.dart';
import 'package:insato/features/groq/groq_minutes_backend.dart';
import 'package:insato/features/groq/strings.dart';
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/minutes/minutes_prompt.dart';

import '../../minutes/fixtures.dart';

const _small = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['summary'],
  'properties': {
    'summary': {'type': 'string'},
  },
};

http.Response _json(Object body, [int status = 200, Map<String, String>? h]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {
      'content-type': 'application/json',
      ...?h,
    });

http.Response _models(List<String> ids) => _json({
      'object': 'list',
      'data': [
        for (final id in ids)
          {
            'id': id,
            'object': 'model',
            'active': true,
            'context_window': id.startsWith('whisper') ? 448 : 131072,
            'owned_by': 'x',
          },
      ],
    });

http.Response _answer(String content, {String model = 'm'}) => _json({
      'id': 'chatcmpl-1',
      'object': 'chat.completion',
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': 'stop',
        },
      ],
    });

http.Response _error(int status, String message,
        {String? code, String? failed, String? retryAfter}) =>
    _json(
      {
        'error': {
          'message': message,
          'type': 'invalid_request_error',
          'code': ?code,
          'failed_generation': ?failed,
        },
      },
      status,
      {'retry-after': ?retryAfter},
    );

/// Records requests; answers `/models` with [models] and chat requests
/// with [chat].
class _Groq {
  _Groq(this.models, this.chat);

  final List<String> models;
  final http.Response Function(Map<String, dynamic> body, int call) chat;
  final List<http.Request> requests = [];
  final List<Map<String, dynamic>> bodies = [];

  MockClient get client => MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/models')) return _models(models);
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        bodies.add(b);
        return chat(b, bodies.length);
      });
}

String _system(Map<String, dynamic> body) =>
    ((body['messages'] as List).first as Map)['content'] as String;

void main() {
  group('groq_api', () {
    final infos = [
      for (final m in [
        {'id': 'llama-3.1-8b-instant', 'context_window': 131072},
        {'id': 'llama-3.3-70b-versatile', 'context_window': 131072},
        {'id': 'openai/gpt-oss-120b', 'context_window': 131072},
        {'id': 'qwen/qwen3-32b', 'context_window': 131072},
        {'id': 'moonshotai/kimi-k2-instruct', 'context_window': 131072},
        {'id': 'whisper-large-v3', 'context_window': 448},
        {'id': 'meta-llama/llama-guard-4-12b', 'context_window': 131072},
        {'id': 'old-llama-400b', 'active': false},
        {'id': 'allam-2-7b', 'context_window': 4096},
      ])
        GroqModelInfo.fromJson(m),
    ];

    test('the biggest active Llama / Qwen / gpt-oss chat model is preferred',
        () {
      expect(pickPreferredGroqModel(infos), 'openai/gpt-oss-120b');
      expect(rankGroqModels(infos).map((m) => m.id), [
        'openai/gpt-oss-120b',
        'llama-3.3-70b-versatile',
        'qwen/qwen3-32b',
        'llama-3.1-8b-instant',
        'moonshotai/kimi-k2-instruct',
      ]);
      expect(pickPreferredGroqModel(const []), isNull);
    });

    test('model sizes and structured-output support', () {
      expect(groqModelSizeB('llama-3.3-70b-versatile'), 70);
      expect(groqModelSizeB('meta-llama/llama-4-scout-17b-16e-instruct'), 17);
      expect(groqModelSizeB('openai/gpt-oss-120b'), 120);
      expect(groqModelSizeB('moonshotai/kimi-k2-instruct'), 0);
      expect(groqSupportsJsonSchema('openai/gpt-oss-20b'), isTrue);
      expect(groqSupportsJsonSchema('llama-3.3-70b-versatile'), isFalse);
      expect(groqSupportsStrictSchema('openai/gpt-oss-120b'), isTrue);
      expect(groqSupportsStrictSchema('moonshotai/kimi-k2-instruct'), isFalse);
      expect(groqExtraBody('openai/gpt-oss-120b')['reasoning_effort'], 'low');
      expect(groqExtraBody('qwen/qwen3-32b'), {'reasoning_format': 'hidden'});
      expect(groqExtraBody('llama-3.3-70b-versatile'), isEmpty);
    });

    test('rate-limit messages are classified', () {
      final tooLarge = classifyGroqLimit(
        413,
        'Request too large for model `openai/gpt-oss-120b` in organization '
        '`org_1` service tier `on_demand` on tokens per minute (TPM): Limit '
        '8000, Requested 21345, please reduce your message size and try '
        'again.',
      );
      expect(tooLarge.kind, GroqLimitKind.tooLarge);
      expect(tooLarge.limit, 8000);
      expect(tooLarge.requested, 21345);

      final minute = classifyGroqLimit(
        429,
        'Rate limit reached for model `llama-3.3-70b-versatile` on tokens per '
        'minute (TPM): Limit 12000, Used 11000, Requested 2000. Please try '
        'again in 6.5s.',
      );
      expect(minute.kind, GroqLimitKind.perMinute);
      expect(minute.wait, const Duration(milliseconds: 6500));

      final daily = classifyGroqLimit(
        429,
        'Rate limit reached on tokens per day (TPD): Limit 100000, Used '
        '99500, Requested 3000. Please try again in 1h2m3s.',
      );
      expect(daily.kind, GroqLimitKind.daily);
      expect(daily.wait, const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(classifyGroqLimit(429, null).kind, GroqLimitKind.perMinute);
    });

    test('token estimate: Arabic is denser than English', () {
      expect(estimateGroqTokens('مرحبا بكم'), greaterThan(4));
      expect(estimateGroqTokens('a' * 33), 10);
    });

    test('the rate gate blocks per key and scope and learns limits', () {
      var now = DateTime(2026, 11, 20, 9);
      final gate = GroqRateGate(clock: () => now);
      gate.block('k', const Duration(seconds: 30));
      expect(gate.blockOf('k')!.remaining, const Duration(seconds: 30));
      expect(gate.blockOf('k', scope: 'audio'), isNull);
      expect(gate.blockOf('other'), isNull);
      now = now.add(const Duration(seconds: 31));
      expect(gate.blockOf('k'), isNull);
      gate.learnTokenLimit('m', 6000);
      expect(gate.tokenLimitOf('m'), 6000);
    });
  });

  group('GroqMinutesBackend', () {
    late GroqRateGate gate;
    late List<Duration> sleeps;
    setUp(() {
      gate = GroqRateGate();
      sleeps = [];
    });

    GroqMinutesBackend backend(_Groq g, {String? model}) => GroqMinutesBackend(
          apiKey: 'gsk_test',
          model: model,
          httpClient: g.client,
          gate: gate,
          sleep: (d) async => sleeps.add(d),
        );

    const request = MinutesBackendRequest(
      system: 'Write the minutes.',
      user: 'transcript',
      schema: _small,
    );

    test('gpt-oss: json_schema (strict), non-streaming, key, reasoning',
        () async {
      final g = _Groq(
        ['openai/gpt-oss-120b', 'llama-3.3-70b-versatile'],
        (b, _) => _answer('{"summary":"تم"}', model: 'openai/gpt-oss-120b'),
      );
      final b = backend(g);
      final r = await b.generateStructured(request);
      expect(jsonDecode(r.text), {'summary': 'تم'});
      expect(r.model, 'groq/openai/gpt-oss-120b');
      expect(b.engineId, 'groq');
      expect(b.sendsDataOffDevice, isTrue);

      expect(g.requests.first.url.toString(),
          'https://api.groq.com/openai/v1/models');
      final chat = g.requests.last;
      expect(chat.url.toString(),
          'https://api.groq.com/openai/v1/chat/completions');
      expect(chat.headers['authorization'], 'Bearer gsk_test');
      final body = g.bodies.single;
      expect(body['model'], 'openai/gpt-oss-120b');
      expect(body['stream'], isFalse);
      expect(body['max_completion_tokens'], isA<int>());
      expect(body.containsKey('max_tokens'), isFalse);
      expect(body['reasoning_effort'], 'low');
      final format = body['response_format'] as Map;
      expect(format['type'], 'json_schema');
      expect(format['json_schema']['strict'], isTrue);
      expect(format['json_schema']['schema'], _small);
      expect(_system(body), 'Write the minutes.');
      b.close();
    });

    test('a model without structured outputs uses json_object + prompt',
        () async {
      final g = _Groq(
        ['llama-3.3-70b-versatile'],
        (b, _) => _answer('{"summary":"ok"}'),
      );
      final r = await backend(g).generateStructured(request);
      expect(jsonDecode(r.text), {'summary': 'ok'});
      final body = g.bodies.single;
      expect(body['response_format'], {'type': 'json_object'});
      expect(_system(body), contains('# Output format (strict)'));
      expect(_system(body), contains('JSON'));
    });

    test('a rejected json_schema falls back to json_object', () async {
      final g = _Groq(['openai/gpt-oss-20b'], (b, call) {
        if (call == 1) {
          return _error(
            400,
            'response_format `json_schema` is not supported with this model',
          );
        }
        return _answer('{"summary":"ok"}');
      });
      final r = await backend(g).generateStructured(request);
      expect(jsonDecode(r.text), {'summary': 'ok'});
      expect((g.bodies[0]['response_format'] as Map)['type'], 'json_schema');
      expect(g.bodies[1]['response_format'], {'type': 'json_object'});
      expect(_system(g.bodies[1]), contains('# Output format (strict)'));
    });

    test('json_validate_failed hands failed_generation to the tolerant parser',
        () async {
      final g = _Groq(
        ['llama-3.3-70b-versatile'],
        (b, _) => _error(
          400,
          'Failed to generate JSON. Please adjust your prompt. See '
          "'failed_generation' for more details.",
          code: 'json_validate_failed',
          failed: '```json\n{"summary": "ok",}\n```',
        ),
      );
      final r = await backend(g).generateStructured(request);
      expect(r.text, contains('"summary": "ok"'));
      expect(g.bodies, hasLength(1));
    });

    test('a per-minute 429 is waited out (Retry-After) and reported',
        () async {
      final g = _Groq(['llama-3.3-70b-versatile'], (b, call) {
        if (call == 1) {
          return _error(
            429,
            'Rate limit reached for model `llama-3.3-70b-versatile` on tokens '
            'per minute (TPM): Limit 12000, Used 11000, Requested 2000. '
            'Please try again in 6.5s.',
            retryAfter: '7',
          );
        }
        return _answer('{"summary":"ok"}');
      });
      final progress = <MinutesBackendProgress>[];
      final r = await backend(g)
          .generateStructured(request, onProgress: progress.add);
      expect(jsonDecode(r.text), {'summary': 'ok'});
      expect(sleeps, [const Duration(seconds: 7)]);
      final wait = progress.firstWhere(
          (p) => p.phase == MinutesBackendPhase.waitingForQuota);
      expect(wait.wait, const Duration(seconds: 7));
    });

    test('a long per-minute wait fails with an Arabic message', () async {
      final g = _Groq(
        ['llama-3.3-70b-versatile'],
        (b, _) => _error(429, 'Rate limit reached on requests per minute (RPM)',
            retryAfter: '300'),
      );
      final e = await backend(g)
          .generateStructured(request)
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(e, isA<GroqQuotaExceededException>());
      expect((e! as GroqQuotaExceededException).daily, isFalse);
      expect((e as GroqQuotaExceededException).messageAr,
          GS.minuteQuota(const Duration(seconds: 300)));
      expect(sleeps, isEmpty);
    });

    test('a daily limit fails at once and blocks later requests', () async {
      final g = _Groq(
        ['llama-3.3-70b-versatile'],
        (b, _) => _error(
          429,
          'Rate limit reached for model `llama-3.3-70b-versatile` on tokens '
          'per day (TPD): Limit 100000, Used 99500, Requested 3000. Please '
          'try again in 14m2.5s.',
          retryAfter: '843',
        ),
      );
      final e = await backend(g)
          .generateStructured(request)
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(e, isA<GroqQuotaExceededException>());
      expect((e! as GroqQuotaExceededException).daily, isTrue);
      expect((e as GroqQuotaExceededException).messageAr, GS.dailyQuota);
      expect(sleeps, isEmpty);
      final sent = g.requests.length;
      await expectLater(
        backend(g).generateStructured(request),
        throwsA(isA<GroqQuotaExceededException>()),
      );
      expect(g.requests.length, sent);
    });

    test('a refused key is a MissingApiKeyException', () async {
      final g = _Groq(const [], (b, _) => _answer('{}'));
      final client = MockClient((r) async => _error(401, 'Invalid API Key'));
      final b = GroqMinutesBackend(
        apiKey: 'bad',
        httpClient: client,
        gate: gate,
      );
      await expectLater(
        b.generateStructured(request),
        throwsA(isA<MissingApiKeyException>()
            .having((e) => e.messageAr, 'message', GS.keyInvalid)),
      );
      expect(g.requests, isEmpty);
    });

    test('a configured model the key lacks: the automatic one, persisted',
        () async {
      String? discovered;
      final g = _Groq(
        ['llama-3.3-70b-versatile'],
        (b, _) => _answer('{"summary":"ok"}'),
      );
      final b = GroqMinutesBackend(
        apiKey: 'k',
        model: 'gone-model',
        httpClient: g.client,
        gate: gate,
        onModelDiscovered: (m) => discovered = m,
      );
      await b.generateStructured(request);
      expect(discovered, 'llama-3.3-70b-versatile');
      expect(g.bodies.single['model'], 'llama-3.3-70b-versatile');
    });

    test('too large for the free per-minute limit: next model (automatic)',
        () async {
      final g = _Groq(
        ['openai/gpt-oss-120b', 'meta-llama/llama-4-scout-17b-16e-instruct'],
        (b, call) {
          if (b['model'] == 'openai/gpt-oss-120b') {
            return _error(
              413,
              'Request too large for model `openai/gpt-oss-120b` in '
              'organization `org_1` service tier `on_demand` on tokens per '
              'minute (TPM): Limit 8000, Requested 21000, please reduce your '
              'message size and try again.',
            );
          }
          return _answer('{"summary":"ok"}');
        },
      );
      final segs = [
        for (var i = 0; i < 40; i++)
          seg(i, i * 3000, i * 3000 + 2500, 'نناقش البند رقم $i من الميزانية',
              speakerId: 'a'),
      ];
      final ctx = MinutesPromptContext(
        meeting: meeting(),
        segments: segs,
        speakersById: {'a': speaker('a', 'سارة', named: true)},
      );
      final r = await backend(g).generateStructured(
        MinutesBackendRequest(
          system: kMinutesSystemPrompt,
          user: buildMinutesUserMessage(
            meeting: meeting(),
            segments: segs,
            speakersById: ctx.speakersById,
            detailLevel: MinutesDetailLevel.detailed,
          ),
          schema: minutesJsonSchema(),
          context: ctx,
        ),
      );
      expect(r.model, 'groq/meta-llama/llama-4-scout-17b-16e-instruct');
      // The learned limit is too small for the minutes prompt: the big
      // model is asked once only.
      expect(
        g.bodies.where((b) => b['model'] == 'openai/gpt-oss-120b'),
        hasLength(1),
      );
      expect(gate.tokenLimitOf('openai/gpt-oss-120b'), 8000);
    });

    test('a learned limit splits a long meeting (map-reduce)', () async {
      final g = _Groq(['llama-3.3-70b-versatile'], (b, call) {
        if (call == 1) {
          return _error(
            413,
            'Request too large for model `llama-3.3-70b-versatile` on tokens '
            'per minute (TPM): Limit 4000, Requested 9000.',
          );
        }
        if (_system(b).contains('ONE PART')) {
          return _answer(jsonEncode({
            'notes': [
              {
                'kind': 'decision',
                'text': 'ملاحظة',
                'speakers': ['سارة'],
                'evidence': [1],
              },
            ],
          }));
        }
        return _answer('{"summary":"ok"}');
      });
      final segs = [
        for (var i = 0; i < 60; i++)
          seg(i, i * 3000, i * 3000 + 2500,
              'نناقش البند رقم $i من الميزانية ونقرر الخطوات التالية بالتفصيل',
              speakerId: 'a'),
      ];
      final speakers = {'a': speaker('a', 'سارة', named: true)};
      final progress = <MinutesBackendProgress>[];
      final r = await backend(g, model: 'llama-3.3-70b-versatile')
          .generateStructured(
        MinutesBackendRequest(
          system: 'Write the minutes.',
          user: buildMinutesUserMessage(
            meeting: meeting(),
            segments: segs,
            speakersById: speakers,
            detailLevel: MinutesDetailLevel.detailed,
          ),
          schema: _small,
          context: MinutesPromptContext(
            meeting: meeting(),
            segments: segs,
            speakersById: speakers,
          ),
        ),
        onProgress: progress.add,
      );
      expect(jsonDecode(r.text), {'summary': 'ok'});
      final maps = g.bodies.where((b) => _system(b).contains('ONE PART'));
      expect(maps.length, greaterThanOrEqualTo(2));
      expect(
        progress.any((p) => p.phase == MinutesBackendPhase.processingChunk),
        isTrue,
      );
      // Every request after the refusal fits the learned limit.
      for (final b in g.bodies.skip(1)) {
        final text = (b['messages'] as List)
            .map((m) => (m as Map)['content'] as String)
            .join();
        expect(
          estimateGroqTokens(text) + (b['max_completion_tokens'] as int),
          lessThanOrEqualTo(4000),
        );
      }
    });
  });
}
