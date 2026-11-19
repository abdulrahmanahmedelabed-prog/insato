import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/minutes/gemini_client.dart';
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/minutes/minutes_prompt.dart';

/// One recorded request.
class Req {
  Req(this.method, this.url, this.headers, this.body);
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;
  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

/// Serves queued responses in order and records requests.
class Server {
  Server(this.responses);
  final List<http.StreamedResponse Function(Req)> responses;
  final List<Req> requests = [];

  http.Client get client => MockClient.streaming((request, bodyStream) async {
    final body = utf8.decode(await bodyStream.toBytes());
    final r = Req(request.method, request.url, request.headers, body);
    requests.add(r);
    if (requests.length > responses.length) {
      throw StateError('unexpected request ${requests.length}: ${r.url}');
    }
    return responses[requests.length - 1](r);
  });
}

http.StreamedResponse sse(List<Object> chunks, {int status = 200}) =>
    http.StreamedResponse(
      Stream.fromIterable([
        for (final c in chunks) utf8.encode('data: ${jsonEncode(c)}\r\n\r\n'),
      ]),
      status,
      headers: {'content-type': 'text/event-stream'},
    );

http.StreamedResponse jsonResponse(
  Object body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.StreamedResponse(
  Stream.value(utf8.encode(jsonEncode(body))),
  status,
  headers: {'content-type': 'application/json', ...headers},
);

Map<String, dynamic> chunk(
  String text, {
  String? finish,
  bool thought = false,
  String? token,
  String model = 'gemini-2.5-flash',
}) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': text, 'thought': ?(thought ? true : null)},
        ],
      },
      'finishReason': ?finish,
      'continuationToken': ?token,
    },
  ],
  'modelVersion': model,
  'usageMetadata': {'promptTokenCount': 100, 'candidatesTokenCount': 20},
};

/// A successful streamed answer of [text] in three chunks after a thought.
http.StreamedResponse answer(String text, {String model = 'gemini-2.5-flash'}) {
  final third = (text.length / 3).ceil();
  final parts = [
    for (var i = 0; i < text.length; i += third)
      text.substring(i, i + third > text.length ? text.length : i + third),
  ];
  return sse([
    chunk('thinking…', thought: true, model: model),
    for (var i = 0; i < parts.length; i++)
      chunk(
        parts[i],
        finish: i == parts.length - 1 ? 'STOP' : null,
        model: model,
      ),
  ]);
}

Map<String, dynamic> googleError(
  int code,
  String status,
  String message, {
  List<Map<String, dynamic>> details = const [],
}) => {
  'error': {
    'code': code,
    'message': message,
    'status': status,
    'details': details,
  },
};

const Map<String, dynamic> schema = {
  'type': 'object',
  'properties': {
    'ok': {'type': 'boolean'},
    'note': {
      'type': ['string', 'null'],
    },
  },
  'required': ['ok', 'note'],
  'additionalProperties': false,
};

void main() {
  late List<Duration> waits;
  late GeminiRateGate gate;

  GeminiClient client(Server s, {String model = 'gemini-flash-latest'}) =>
      GeminiClient(
        apiKey: ' AIza-test ',
        client: s.client,
        model: model,
        gate: gate,
        delay: (d) async => waits.add(d),
      );

  setUp(() {
    waits = [];
    gate = GeminiRateGate();
  });

  group('request', () {
    test('streams, sends the key in a header and the JSON schema', () async {
      final s = Server([(_) => answer('{"ok": true, "note": null}')]);
      final phases = <GeminiPhase>[];
      final deltas = <int>[];
      final r = await client(s).generateStructured(
        system: 'SYS',
        user: 'USER',
        schema: schema,
        onDelta: deltas.add,
        onPhase: (p, a, w) => phases.add(p),
      );
      expect(jsonDecode(r.text), {'ok': true, 'note': null});
      expect(r.model, 'gemini-2.5-flash');
      expect(r.finishReason, 'STOP');
      expect(r.schemaMode, GeminiSchemaMode.jsonSchema);
      expect(r.usage.promptTokens, 100);
      expect(deltas.last, r.text.length);
      expect(phases, [
        GeminiPhase.connecting,
        GeminiPhase.thinking,
        GeminiPhase.writing,
      ]);

      final req = s.requests.single;
      expect(req.method, 'POST');
      expect(
        req.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-flash-latest:streamGenerateContent?alt=sse',
      );
      expect(req.url.queryParameters.containsKey('key'), isFalse);
      expect(req.headers['x-goog-api-key'], 'AIza-test');
      final body = req.json;
      expect(body['systemInstruction'], {
        'parts': [
          {'text': 'SYS'},
        ],
      });
      expect(body['contents'], [
        {
          'role': 'user',
          'parts': [
            {'text': 'USER'},
          ],
        },
      ]);
      final config = body['generationConfig'] as Map<String, dynamic>;
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseJsonSchema'], schema);
      expect(config.containsKey('responseSchema'), isFalse);
      expect(body.containsKey('temperature'), isFalse);
    });

    test('non-streaming mode uses generateContent', () async {
      final s = Server([
        (_) =>
            jsonResponse(chunk('{"ok": false, "note": "x"}', finish: 'STOP')),
      ]);
      final c = GeminiClient(
        apiKey: 'k',
        client: s.client,
        model: 'models/gemini-2.5-flash',
        stream: false,
        gate: gate,
      );
      final r = await c.generateStructured(
        system: 's',
        user: 'u',
        schema: schema,
      );
      expect(jsonDecode(r.text)['note'], 'x');
      expect(
        s.requests.single.url.path,
        '/v1beta/models/gemini-2.5-flash:generateContent',
      );
    });

    test('an empty key fails before any request', () async {
      final s = Server([]);
      final c = GeminiClient(apiKey: '  ', client: s.client, gate: gate);
      await expectLater(
        c.generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(isA<MissingApiKeyException>()),
      );
      expect(s.requests, isEmpty);
    });
  });

  group('schema fallback chain', () {
    test('400 → responseSchema (OpenAPI) → plain JSON mode', () async {
      final bad = googleError(
        400,
        'INVALID_ARGUMENT',
        'Invalid JSON payload received. Unknown name "responseJsonSchema"',
      );
      final s = Server([
        (_) => jsonResponse(bad, status: 400),
        (_) => jsonResponse(bad, status: 400),
        (_) => answer('```json\n{"ok": true, "note": null}\n```'),
        (_) => answer('{"ok": true, "note": null}'),
      ]);
      final c = client(s);
      final r = await c.generateStructured(
        system: 'SYS',
        user: 'u',
        schema: schema,
      );
      expect(r.schemaMode, GeminiSchemaMode.jsonPrompt);
      expect(waits, isEmpty, reason: 'dialect switches are immediate');
      final second = s.requests[1].json['generationConfig'] as Map;
      expect(second.containsKey('responseJsonSchema'), isFalse);
      final openApi = second['responseSchema'] as Map;
      expect(openApi.containsKey('additionalProperties'), isFalse);
      expect((openApi['properties'] as Map)['note'], {
        'type': 'string',
        'nullable': true,
      });
      expect(openApi['propertyOrdering'], ['ok', 'note']);
      final third = s.requests[2].json;
      final config = third['generationConfig'] as Map;
      expect(config.keys, ['responseMimeType']);
      final sys =
          ((third['systemInstruction'] as Map)['parts'] as List).single['text']
              as String;
      expect(sys, startsWith('SYS'));
      expect(sys, contains('"additionalProperties":false'));

      // The working dialect is remembered.
      await c.generateStructured(system: 'S', user: 'u', schema: schema);
      expect((s.requests[3].json['generationConfig'] as Map).keys, [
        'responseMimeType',
      ]);
    });

    test('every dialect rejected → Arabic error', () async {
      final bad = googleError(400, 'INVALID_ARGUMENT', 'bad schema');
      final s = Server([
        for (var i = 0; i < 3; i++) (_) => jsonResponse(bad, status: 400),
      ]);
      await expectLater(
        client(s).generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(
          isA<MinutesGenerationException>().having(
            (e) => e.messageAr,
            'messageAr',
            contains('Gemini'),
          ),
        ),
      );
      expect(s.requests, hasLength(3));
    });

    test('toGeminiOpenApiSchema converts the minutes schema', () {
      final converted = toGeminiOpenApiSchema(minutesJsonSchema());
      final text = jsonEncode(converted);
      expect(text, isNot(contains('additionalProperties')));
      expect(text, isNot(contains('"null"')));
      final topics = (converted['properties'] as Map)['topics'] as Map;
      final item = topics['items'] as Map;
      expect(item['propertyOrdering'], [
        'title',
        'discussion',
        'speakers',
        'evidence',
      ]);
      final next = (converted['properties'] as Map)['next_meeting'];
      expect(next, {'type': 'string', 'nullable': true});
    });
  });

  group('errors', () {
    test(
      'invalid key (400 API_KEY_INVALID) → MissingApiKeyException',
      () async {
        final s = Server([
          (_) => jsonResponse(
            googleError(
              400,
              'INVALID_ARGUMENT',
              'API key not valid. Please pass a valid API key.',
              details: [
                {
                  '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                  'reason': 'API_KEY_INVALID',
                  'domain': 'googleapis.com',
                },
              ],
            ),
            status: 400,
          ),
        ]);
        await expectLater(
          client(s).generateStructured(system: 's', user: 'u', schema: schema),
          throwsA(
            isA<MissingApiKeyException>().having(
              (e) => e.messageAr,
              'messageAr',
              contains('مفتاح Gemini'),
            ),
          ),
        );
        expect(s.requests, hasLength(1));
      },
    );

    test('403 → MissingApiKeyException', () async {
      final s = Server([
        (_) => jsonResponse(
          googleError(403, 'PERMISSION_DENIED', 'denied'),
          status: 403,
        ),
      ]);
      await expectLater(
        client(s).generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(isA<MissingApiKeyException>()),
      );
    });

    test('unsupported location → clear Arabic error, no retry', () async {
      final s = Server([
        (_) => jsonResponse(
          googleError(
            400,
            'FAILED_PRECONDITION',
            'User location is not supported for the API use.',
          ),
          status: 400,
        ),
      ]);
      await expectLater(
        client(s).generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(
          isA<MinutesGenerationException>().having(
            (e) => e.messageAr,
            'messageAr',
            contains('غير متاحة'),
          ),
        ),
      );
      expect(s.requests, hasLength(1));
    });

    test('404 → GeminiModelNotFoundException', () async {
      final s = Server([
        (_) => jsonResponse(
          googleError(404, 'NOT_FOUND', 'models/x is not found'),
          status: 404,
        ),
      ]);
      await expectLater(
        client(
          s,
          model: 'x',
        ).generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(
          isA<GeminiModelNotFoundException>().having(
            (e) => e.model,
            'model',
            'x',
          ),
        ),
      );
    });

    test('5xx and dropped streams are retried with backoff', () async {
      final s = Server([
        (_) => jsonResponse(
          googleError(503, 'UNAVAILABLE', 'The model is overloaded.'),
          status: 503,
        ),
        // Stream ends without a finishReason.
        (_) => sse([chunk('{"ok": tr')]),
        (_) => answer('{"ok": true, "note": null}'),
      ]);
      final phases = <GeminiPhase>[];
      final r = await client(s).generateStructured(
        system: 's',
        user: 'u',
        schema: schema,
        onPhase: (p, a, w) => phases.add(p),
      );
      expect(jsonDecode(r.text)['ok'], isTrue);
      expect(waits, hasLength(2));
      expect(phases.where((p) => p == GeminiPhase.retrying), hasLength(2));
    });

    test('network errors exhaust attempts → retryable error', () async {
      var n = 0;
      final c = GeminiClient(
        apiKey: 'k',
        client: MockClient((_) async {
          n++;
          throw http.ClientException('offline');
        }),
        gate: gate,
        delay: (d) async => waits.add(d),
      );
      await expectLater(
        c.generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(
          isA<MinutesGenerationException>().having(
            (e) => e.retryable,
            'retryable',
            isTrue,
          ),
        ),
      );
      expect(n, 3);
    });

    test('finish reasons and prompt blocks become Arabic errors', () async {
      Future<Object?> run(http.StreamedResponse Function(Req) resp) async {
        final s = Server([resp]);
        try {
          await client(s)
              .generateStructured(system: 's', user: 'u', schema: schema);
          return null;
        } catch (e) {
          return e;
        }
      }

      final maxTokens = await run(
        (_) => sse([chunk('{"a', finish: 'MAX_TOKENS')]),
      );
      expect(
        (maxTokens as MinutesGenerationException).messageAr,
        contains('الحد الأقصى'),
      );
      final safety = await run((_) => sse([chunk('', finish: 'SAFETY')]));
      expect(
        (safety as MinutesGenerationException).messageAr,
        contains('الأمان'),
      );
      final recitation = await run(
        (_) => sse([chunk('{}', finish: 'RECITATION')]),
      );
      expect(
        (recitation as MinutesGenerationException).messageAr,
        contains('حقوق النشر'),
      );
      final blocked = await run(
        (_) => sse([
          {
            'promptFeedback': {'blockReason': 'PROHIBITED_CONTENT'},
          },
        ]),
      );
      expect(
        (blocked as MinutesGenerationException).messageAr,
        contains('PROHIBITED_CONTENT'),
      );
    });

    test('an error object inside the stream is handled', () async {
      final s = Server([
        (_) => sse([googleError(500, 'INTERNAL', 'boom')]),
        (_) => answer('{"ok": true, "note": null}'),
      ]);
      final r = await client(s)
          .generateStructured(system: 's', user: 'u', schema: schema);
      expect(jsonDecode(r.text)['ok'], isTrue);
    });

    test('CONTINUATION is followed with the token', () async {
      final s = Server([
        (_) =>
            sse([chunk('{"ok": true,', finish: 'CONTINUATION', token: 'T1')]),
        (_) => sse([chunk(' "note": null}', finish: 'STOP')]),
      ]);
      final r = await client(s)
          .generateStructured(system: 's', user: 'u', schema: schema);
      expect(jsonDecode(r.text), {'ok': true, 'note': null});
      expect(s.requests[1].json['continuationToken'], 'T1');
      expect(s.requests[0].json.containsKey('continuationToken'), isFalse);
    });
  });

  group('rate limits (never hammer)', () {
    Map<String, dynamic> quota({required String quotaId, String? retryDelay}) =>
        googleError(
          429,
          'RESOURCE_EXHAUSTED',
          'You exceeded your current quota.',
          details: [
            {
              '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
              'violations': [
                {
                  'quotaMetric': 'generativelanguage.googleapis.com/generate_content_free_tier_requests',
                  'quotaId': quotaId,
                },
              ],
            },
            if (retryDelay != null)
              {
                '@type': 'type.googleapis.com/google.rpc.RetryInfo',
                'retryDelay': retryDelay,
              },
          ],
        );

    test('a short per-minute delay is waited out once', () async {
      final s = Server([
        (_) => jsonResponse(
          quota(
            quotaId: 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier',
            retryDelay: '20s',
          ),
          status: 429,
        ),
        (_) => answer('{"ok": true, "note": null}'),
      ]);
      Duration? announced;
      await client(s).generateStructured(
        system: 's',
        user: 'u',
        schema: schema,
        onPhase: (p, a, w) {
          if (p == GeminiPhase.waitingForQuota) announced = w;
        },
      );
      expect(waits.single.inSeconds, 20);
      expect(announced!.inSeconds, 20);
    });

    test('a daily quota fails at once and blocks later requests', () async {
      final s = Server([
        (_) => jsonResponse(
          quota(
            quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier',
            retryDelay: '30s',
          ),
          status: 429,
        ),
      ]);
      final c = client(s);
      await expectLater(
        c.generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(
          isA<GeminiQuotaExceededException>()
              .having((e) => e.daily, 'daily', isTrue)
              .having((e) => e.retryable, 'retryable', isFalse)
              .having((e) => e.messageAr, 'messageAr', contains('اليومية')),
        ),
      );
      expect(waits, isEmpty);
      // The next call is refused locally: no request reaches Google.
      await expectLater(
        c.generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(isA<GeminiQuotaExceededException>()),
      );
      expect(s.requests, hasLength(1));
    });

    test('a long delay fails with the waiting time in Arabic', () async {
      final s = Server([
        (_) => jsonResponse(
          quota(quotaId: 'PerMinute', retryDelay: '120s'),
          status: 429,
        ),
      ]);
      await expectLater(
        client(s).generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(
          isA<GeminiQuotaExceededException>()
              .having((e) => e.daily, 'daily', isFalse)
              .having((e) => e.messageAr, 'messageAr', contains('120 ثانية')),
        ),
      );
      expect(gate.blockOf('AIza-test'), isNotNull);
    });

    test('repeated 429s give up after the attempts', () async {
      final s = Server([
        for (var i = 0; i < 3; i++)
          (_) => jsonResponse(
            quota(quotaId: 'PerMinute', retryDelay: '5s'),
            status: 429,
          ),
      ]);
      await expectLater(
        client(s).generateStructured(system: 's', user: 'u', schema: schema),
        throwsA(isA<GeminiQuotaExceededException>()),
      );
      expect(s.requests, hasLength(3));
      expect(waits, hasLength(2));
    });

    test('Retry-After header is used when RetryInfo is missing', () async {
      final s = Server([
        (_) => jsonResponse(
          googleError(429, 'RESOURCE_EXHAUSTED', 'slow down'),
          status: 429,
          headers: {'retry-after': '7'},
        ),
        (_) => answer('{"ok": true, "note": null}'),
      ]);
      await client(s)
          .generateStructured(system: 's', user: 'u', schema: schema);
      expect(waits.single.inSeconds, 7);
    });

    test('rate gate expires', () {
      var now = DateTime(2026, 1, 1);
      final g = GeminiRateGate(clock: () => now);
      g.block('k', const Duration(seconds: 10));
      expect(g.blockOf('k')!.daily, isFalse);
      expect(g.blockOf('other'), isNull);
      now = now.add(const Duration(seconds: 11));
      expect(g.blockOf('k'), isNull);
    });
  });

  group('models', () {
    test('listModels pages and parses', () async {
      final s = Server([
        (_) => jsonResponse({
          'models': [
            {
              'name': 'models/gemini-2.5-flash',
              'displayName': 'Gemini 2.5 Flash',
              'supportedGenerationMethods': ['generateContent', 'countTokens'],
              'inputTokenLimit': 1048576,
              'outputTokenLimit': 65536,
              'thinking': true,
            },
          ],
          'nextPageToken': 'P2',
        }),
        (_) => jsonResponse({
          'models': [
            {
              'name': 'models/text-embedding-004',
              'supportedGenerationMethods': ['embedContent'],
            },
          ],
        }),
      ]);
      final models = await client(s).listModels();
      expect(models.map((m) => m.id), [
        'gemini-2.5-flash',
        'text-embedding-004',
      ]);
      expect(models.first.canGenerate, isTrue);
      expect(models.first.outputTokenLimit, 65536);
      expect(models.last.canGenerate, isFalse);
      expect(s.requests[1].url.queryParameters['pageToken'], 'P2');
      expect(s.requests.first.method, 'GET');
      expect(s.requests.first.headers['x-goog-api-key'], 'AIza-test');
    });

    test('pickPreferredGeminiModel prefers the newest stable text Flash', () {
      GeminiModelInfo m(String id, {bool gen = true}) => GeminiModelInfo(
        id: id,
        methods: gen ? const ['generateContent'] : const [],
      );
      expect(
        pickPreferredGeminiModel([
          m('gemini-2.0-flash'),
          m('gemini-2.5-flash'),
          m('gemini-2.5-flash-lite'),
          m('gemini-2.5-flash-image'),
          m('gemini-2.5-flash-preview-tts'),
          m('gemini-2.5-pro'),
          m('gemini-3-flash-preview'),
          m('gemini-3.5-flash', gen: false),
        ]),
        'gemini-3-flash-preview',
      );
      expect(
        pickPreferredGeminiModel([
          m('gemini-3-flash-preview'),
          m('gemini-3-flash'),
          m('gemini-3-flash-lite'),
        ]),
        'gemini-3-flash',
      );
      expect(
        pickPreferredGeminiModel([
          m('gemini-2.5-flash-001'),
          m('gemini-2.5-flash'),
        ]),
        'gemini-2.5-flash',
      );
      expect(pickPreferredGeminiModel([m('gemini-2.5-pro')]), isNull);
    });

    test('backend switches to a discovered model after a 404', () async {
      final s = Server([
        (_) => jsonResponse(
          googleError(404, 'NOT_FOUND', 'not found'),
          status: 404,
        ),
        (_) => jsonResponse({
          'models': [
            {
              'name': 'models/gemini-2.5-flash',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        }),
        (r) => answer('{"ok": true, "note": null}'),
      ]);
      final discovered = <String>[];
      final backend = GeminiMinutesBackend(
        client(s, model: 'gemini-flash-latest'),
        onModelDiscovered: discovered.add,
      );
      final progress = <MinutesBackendProgress>[];
      final r = await backend.generateStructured(
        const MinutesBackendRequest(system: 's', user: 'u', schema: schema),
        onProgress: progress.add,
      );
      expect(r.model, 'gemini-2.5-flash');
      expect(discovered, ['gemini-2.5-flash']);
      expect(s.requests[2].url.path, contains('gemini-2.5-flash:'));
      expect(backend.engineId, 'gemini');
      expect(backend.sendsDataOffDevice, isTrue);
      expect(
        progress.map((p) => p.phase),
        containsAll([
          MinutesBackendPhase.connecting,
          MinutesBackendPhase.writing,
        ]),
      );
      expect(progress.last.receivedChars, greaterThan(0));
      backend.close();
    });
  });

  test('parseGoogleDuration', () {
    expect(parseGoogleDuration('37s'), const Duration(seconds: 37));
    expect(parseGoogleDuration('1.5s'), const Duration(milliseconds: 1500));
    expect(parseGoogleDuration('250ms'), const Duration(milliseconds: 250));
    expect(parseGoogleDuration('soon'), isNull);
    expect(parseGoogleDuration(5), isNull);
  });

  test('GeminiApiError.parse tolerates junk', () {
    expect(GeminiApiError.parse('<html>').status, isNull);
    expect(GeminiApiError.parse('').isInvalidKey, isFalse);
    final list = GeminiApiError.parse(
      jsonEncode([googleError(429, 'RESOURCE_EXHAUSTED', 'x')]),
    );
    expect(list.code, 429);
  });

  test('a stream that never delivers bytes times out and is retried', () async {
    var n = 0;
    final c = GeminiClient(
      apiKey: 'k',
      client: MockClient.streaming((req, body) async {
        n++;
        if (n == 1) {
          return http.StreamedResponse(
            const Stream<List<int>>.empty().asBroadcastStream().timeout(
              const Duration(milliseconds: 1),
            ),
            200,
          );
        }
        return answer('{"ok": true, "note": null}');
      }),
      gate: gate,
      idleTimeout: const Duration(milliseconds: 50),
      delay: (d) async => waits.add(d),
    );
    final r = await c.generateStructured(
      system: 's',
      user: 'u',
      schema: schema,
    );
    expect(jsonDecode(r.text)['ok'], isTrue);
    expect(n, 2);
  });
}
