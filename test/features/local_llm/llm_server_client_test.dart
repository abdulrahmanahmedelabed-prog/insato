// Ollama / OpenAI-compatible server client over a mock HTTP server.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/features/local_llm/llm_generator.dart';
import 'package:insato/features/local_llm/llm_server_client.dart';
import 'package:insato/features/local_llm/strings.dart';

typedef _Handler = FutureOr<http.StreamedResponse> Function(
  http.BaseRequest request,
  String body,
);

/// A mock server; records each request with its body.
class _Server {
  _Server(this.handler);

  final _Handler handler;
  final List<(http.BaseRequest, String)> log = [];

  late final MockClient client = MockClient.streaming((req, bodyStream) async {
    final body = await bodyStream.bytesToString();
    log.add((req, body));
    return handler(req, body);
  });

  Map<String, dynamic> jsonBody(int i) =>
      jsonDecode(log[i].$2) as Map<String, dynamic>;
}

http.StreamedResponse _json(Object body, [int status = 200]) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );

http.StreamedResponse _text(String body, [int status = 200]) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), status);

/// Streams [lines] in uneven byte chunks (splitting multi-byte characters).
http.StreamedResponse _lines(List<String> lines) {
  final bytes = utf8.encode(lines.map((l) => '$l\n').join());
  Stream<List<int>> chunks() async* {
    for (var i = 0; i < bytes.length; i += 7) {
      yield bytes.sublist(i, i + 7 > bytes.length ? bytes.length : i + 7);
    }
  }

  return http.StreamedResponse(chunks(), 200);
}

String _ollamaLine(String content, {bool done = false, String? reason}) =>
    jsonEncode({
      'model': 'qwen3:8b',
      'message': {'role': 'assistant', 'content': content},
      'done': done,
      'done_reason': ?reason,
    });

String _sse(Map<String, dynamic> delta, {String? finish}) =>
    'data: ${jsonEncode({
      'model': 'lmstudio-model',
      'choices': [
        {'index': 0, 'delta': delta, 'finish_reason': finish},
      ],
    })}';

const Map<String, dynamic> _schema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['ok'],
  'properties': {
    'ok': {'type': 'boolean'},
  },
};

const _req = LlmGenerationRequest(
  system: 'SYS',
  user: 'USER',
  maxTokens: 200,
  schema: _schema,
);

Matcher _serverError(String message) => throwsA(
  isA<LlmServerException>().having((e) => e.messageAr, 'messageAr', message),
);

void main() {
  group('URL helpers', () {
    test('flavour is encoded by a trailing /v1', () {
      expect(
        serverFlavorOfUrl('http://127.0.0.1:11434'),
        LlmServerFlavor.ollama,
      );
      expect(
        serverFlavorOfUrl('http://127.0.0.1:1234/v1'),
        LlmServerFlavor.openAi,
      );
      expect(serverFlavorOfUrl('http://h:1234/V1/'), LlmServerFlavor.openAi);
      expect(serverFlavorOfUrl('http://h/v1x'), LlmServerFlavor.ollama);
      expect(serverFlavorOfUrl('not a url ::'), LlmServerFlavor.ollama);
    });

    test('serverUrlForFlavor swaps defaults and adds / removes /v1', () {
      expect(
        serverUrlForFlavor(kDefaultOllamaUrl, LlmServerFlavor.openAi),
        kDefaultLmStudioUrl,
      );
      expect(
        serverUrlForFlavor(kDefaultLmStudioUrl, LlmServerFlavor.ollama),
        kDefaultOllamaUrl,
      );
      expect(
        serverUrlForFlavor('http://pc.local:8080/', LlmServerFlavor.openAi),
        'http://pc.local:8080/v1',
      );
      expect(
        serverUrlForFlavor('http://pc.local:8080/v1', LlmServerFlavor.ollama),
        'http://pc.local:8080',
      );
      expect(
        serverUrlForFlavor('http://pc.local:8080/v1/', LlmServerFlavor.openAi),
        'http://pc.local:8080/v1',
      );
    });

    test('serverRootUrl keeps host and port', () {
      expect(serverRootUrl(kDefaultLmStudioUrl), 'http://127.0.0.1:1234');
      expect(serverRootUrl('http://h:9/v1/'), 'http://h:9');
      expect(serverRootUrl('http://h:9/'), 'http://h:9');
    });

    test('loopback detection', () {
      for (final u in [
        'http://127.0.0.1:11434',
        'http://127.5.6.7',
        'http://localhost:1234/v1',
        'http://app.localhost',
        'http://[::1]:11434',
      ]) {
        expect(isLoopbackServerUrl(u), isTrue, reason: u);
      }
      for (final u in [
        'http://192.168.1.10:11434',
        'http://pc.local:1234/v1',
        'http://127.0.0.1.evil.com',
        'garbage',
      ]) {
        expect(isLoopbackServerUrl(u), isFalse, reason: u);
      }
    });

    test('serverErrorMessage reads the common error shapes', () {
      expect(
        serverErrorMessage('{"error":"model not found"}'),
        'model not found',
      );
      expect(
        serverErrorMessage('{"error":{"message":"bad schema","type":"x"}}'),
        'bad schema',
      );
      expect(serverErrorMessage('{"message":"m"}'), 'm');
      expect(serverErrorMessage('  plain text  '), 'plain text');
      expect(serverErrorMessage(''), isNull);
      expect(serverErrorMessage('x' * 300), hasLength(201));
    });

    test('model labels', () {
      expect(
        serverModelLabel(LlmServerFlavor.ollama, 'qwen3:8b'),
        'ollama/qwen3:8b',
      );
      expect(
        serverModelLabel(LlmServerFlavor.openAi, 'qwen3-8b'),
        'openai-compatible/qwen3-8b',
      );
    });
  });

  group('model list and probe', () {
    test('Ollama /api/tags', () async {
      final s = _Server((req, _) {
        expect(req.method, 'GET');
        expect(req.url.toString(), 'http://127.0.0.1:11434/api/tags');
        return _json({
          'models': [
            {'name': 'qwen3:8b', 'model': 'qwen3:8b'},
            {'name': ' llama3.2:3b '},
            {'name': ''},
            {'name': 'qwen3:8b'},
            'junk',
          ],
        });
      });
      final c = LlmServerClient(
        baseUrl: '$kDefaultOllamaUrl/',
        client: s.client,
      );
      expect(c.baseUrl, kDefaultOllamaUrl);
      expect(await c.listModels(), ['llama3.2:3b', 'qwen3:8b']);
    });

    test('OpenAI /v1/models', () async {
      final s = _Server((req, _) {
        expect(req.url.toString(), 'http://127.0.0.1:1234/v1/models');
        return _json({
          'data': [
            {'id': 'qwen3-8b'},
            {'id': 'text-embedding-nomic'},
          ],
        });
      });
      final c = LlmServerClient(baseUrl: kDefaultLmStudioUrl, client: s.client);
      expect(await c.listModels(), ['qwen3-8b', 'text-embedding-nomic']);
    });

    test('probe finds the other flavour and returns its URL', () async {
      final s = _Server((req, _) {
        if (req.url.path == '/v1/models') {
          return _json({
            'data': [
              {'id': 'm1'},
            ],
          });
        }
        return _text('not found', 404);
      });
      final c = LlmServerClient(
        baseUrl: 'http://192.168.1.5:1234',
        client: s.client,
      );
      final probe = await c.probe();
      expect(probe.flavor, LlmServerFlavor.openAi);
      expect(probe.url, 'http://192.168.1.5:1234/v1');
      expect(probe.models, ['m1']);
      expect(s.log.map((e) => e.$1.url.path), ['/api/tags', '/v1/models']);
    });

    test('probe of an unknown server reports it is not recognised', () async {
      final s = _Server((req, _) => _json({'hello': 'world'}));
      final c = LlmServerClient(baseUrl: 'http://h:1', client: s.client);
      await expectLater(
        c.probe(),
        _serverError(LS.serverNotRecognised('http://h:1')),
      );
    });

    test(
      'probe of an unreachable server does not try the other flavour',
      () async {
        final s = _Server(
          (req, _) => throw const SocketException('Connection refused'),
        );
        final c = LlmServerClient(baseUrl: 'http://h:1', client: s.client);
        await expectLater(
          c.probe(),
          throwsA(
            isA<LlmServerException>()
                .having(
                  (e) => e.messageAr,
                  'messageAr',
                  LS.serverUnreachable('http://h:1'),
                )
                .having((e) => e.retryable, 'retryable', isTrue),
          ),
        );
        expect(s.log, hasLength(1));
      },
    );

    test('a slow server times out', () async {
      final s = _Server((req, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _json({'models': []});
      });
      final c = LlmServerClient(
        baseUrl: 'http://h:1',
        client: s.client,
        connectTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        c.listModels(),
        _serverError(LS.serverTimeout('http://h:1')),
      );
    });
  });

  group('context length', () {
    test('Ollama reads model_info.*.context_length', () async {
      final s = _Server((req, body) {
        expect(req.url.path, '/api/show');
        expect(jsonDecode(body), {'model': 'qwen3:8b', 'name': 'qwen3:8b'});
        return _json({
          'model_info': {
            'general.architecture': 'qwen3',
            'qwen3.context_length': 40960,
          },
        });
      });
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      expect(await c.contextLength('qwen3:8b'), 40960);
    });

    test('Ollama: a missing model is reported with a pull hint', () async {
      final s = _Server(
        (req, _) => _json({'error': "model 'x' not found"}, 404),
      );
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      await expectLater(
        c.contextLength('x'),
        _serverError(LS.serverModelMissing('x', true)),
      );
    });

    test('LM Studio at its default URL is asked on its own port', () async {
      final s = _Server((req, _) {
        expect(
          req.url.toString(),
          'http://127.0.0.1:1234/api/v0/models/qwen3-8b',
        );
        return _json({
          'id': 'qwen3-8b',
          'loaded_context_length': 8192,
          'max_context_length': 32768,
        });
      });
      final c = LlmServerClient(baseUrl: kDefaultLmStudioUrl, client: s.client);
      expect(await c.contextLength('qwen3-8b'), 8192);
    });

    test('OpenAI servers without the LM Studio API give null', () async {
      final s = _Server((req, _) => _text('', 404));
      final c = LlmServerClient(baseUrl: 'http://h:8080/v1', client: s.client);
      expect(await c.contextLength('m'), isNull);
      expect(s.log.single.$1.url.toString(), 'http://h:8080/api/v0/models/m');
    });

    test('max_context_length is used when nothing is loaded', () async {
      final s = _Server((req, _) => _json({'max_context_length': 4096}));
      final c = LlmServerClient(baseUrl: 'http://h:8080/v1', client: s.client);
      expect(await c.contextLength('m'), 4096);
    });
  });

  group('chat', () {
    test('Ollama: request shape and NDJSON streaming', () async {
      final s = _Server(
        (req, _) => _lines([
          _ollamaLine('{"ok":'),
          _ollamaLine(' trueé'),
          '',
          'not json',
          _ollamaLine('}', done: true, reason: 'stop'),
        ]),
      );
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      final progress = <int>[];
      final out = await c.chat(
        model: 'qwen3:8b',
        request: _req,
        numCtx: 16384,
        onProgress: (phase, n) => progress.add(n),
      );
      expect(out.text, '{"ok": trueé}');
      expect(out.model, 'qwen3:8b');
      expect(out.truncated, isFalse);
      expect(progress, [6, 12, 13]);
      final req = s.log.single.$1;
      expect(req.url.toString(), 'http://127.0.0.1:11434/api/chat');
      expect(req.headers['content-type'], startsWith('application/json'));
      final body = s.jsonBody(0);
      expect(body['model'], 'qwen3:8b');
      expect(body['stream'], isTrue);
      expect(body['format'], _schema);
      expect(body['options'], {
        'num_ctx': 16384,
        'num_predict': 200,
        'temperature': 0.2,
      });
      expect(body['messages'], [
        {'role': 'system', 'content': 'SYS'},
        {'role': 'user', 'content': 'USER'},
      ]);
    });

    test('Ollama: done_reason length marks the answer truncated', () async {
      final s = _Server(
        (req, _) =>
            _lines([_ollamaLine('{"ok"', done: true, reason: 'length')]),
      );
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      final out = await c.chat(model: 'm', request: _req, numCtx: 4096);
      expect(out.truncated, isTrue);
    });

    test('Ollama: thinking is reported and kept out of the answer', () async {
      final s = _Server(
        (req, _) => _lines([
          jsonEncode({
            'message': {'content': '', 'thinking': 'hmm'},
            'done': false,
          }),
          _ollamaLine('<think>inline</think>{"ok":true}', done: true),
        ]),
      );
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      final phases = <LlmStreamPhase>[];
      final out = await c.chat(
        model: 'm',
        request: _req,
        numCtx: 4096,
        onProgress: (phase, _) => phases.add(phase),
      );
      expect(out.text, '{"ok":true}');
      expect(phases.first, LlmStreamPhase.thinking);
      expect(phases.last, LlmStreamPhase.writing);
    });

    test('OpenAI: request shape and SSE streaming', () async {
      final s = _Server(
        (req, _) => _lines([
          ': keep-alive',
          _sse({'role': 'assistant'}),
          _sse({'reasoning_content': 'think'}),
          _sse({'content': '{"ok":'}),
          '',
          _sse({'content': 'false}'}, finish: 'stop'),
          'data: [DONE]',
        ]),
      );
      final c = LlmServerClient(baseUrl: kDefaultLmStudioUrl, client: s.client);
      final out = await c.chat(model: 'qwen3-8b', request: _req, numCtx: 8192);
      expect(out.text, '{"ok":false}');
      expect(out.model, 'lmstudio-model');
      expect(out.truncated, isFalse);
      final req = s.log.single.$1;
      expect(req.url.toString(), 'http://127.0.0.1:1234/v1/chat/completions');
      expect(req.headers['accept'], 'text/event-stream');
      final body = s.jsonBody(0);
      expect(body['max_tokens'], 200);
      expect(body['stream'], isTrue);
      expect(body.containsKey('options'), isFalse);
      expect(body['response_format'], {
        'type': 'json_schema',
        'json_schema': {'name': 'response', 'strict': true, 'schema': _schema},
      });
    });

    test('OpenAI: finish_reason length marks the answer truncated', () async {
      final s = _Server(
        (req, _) => _lines([
          _sse({'content': '{'}, finish: 'length'),
        ]),
      );
      final c = LlmServerClient(baseUrl: kDefaultLmStudioUrl, client: s.client);
      expect(
        (await c.chat(model: 'm', request: _req, numCtx: 1)).truncated,
        isTrue,
      );
    });

    test('useSchema false sends no schema', () async {
      final s = _Server((req, _) => _lines([_ollamaLine('x', done: true)]));
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      await c.chat(model: 'm', request: _req, numCtx: 1, useSchema: false);
      expect(s.jsonBody(0).containsKey('format'), isFalse);
    });

    test('a 400 about the schema signals LlmServerSchemaRejected', () async {
      final s = _Server(
        (req, _) => _json({
          'error': 'json: cannot unmarshal object into Go struct field .format',
        }, 400),
      );
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      await expectLater(
        c.chat(model: 'm', request: _req, numCtx: 1),
        throwsA(isA<LlmServerSchemaRejected>()),
      );
    });

    test('HTTP errors are mapped to Arabic messages', () async {
      var status = 404;
      var body = '{"error":"model \\"m\\" not found, try pulling it first"}';
      final s = _Server((req, _) => _text(body, status));
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      await expectLater(
        c.chat(model: 'm', request: _req, numCtx: 1),
        _serverError(LS.serverModelMissing('m', true)),
      );

      status = 500;
      body = '{"error":"the input length exceeds the context length"}';
      await expectLater(
        c.chat(model: 'm', request: _req, numCtx: 1),
        _serverError(LS.serverContextExceeded),
      );

      status = 503;
      body = 'busy';
      await expectLater(
        c.chat(model: 'm', request: _req, numCtx: 1),
        throwsA(
          isA<LlmServerException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.retryable, 'retryable', isTrue)
              .having(
                (e) => e.messageAr,
                'messageAr',
                LS.serverHttpError(503, 'busy'),
              ),
        ),
      );
    });

    test('an error inside the stream is reported', () async {
      final s = _Server(
        (req, _) => _lines([
          _ollamaLine('{"ok"'),
          jsonEncode({'error': 'model runner has unexpectedly stopped'}),
        ]),
      );
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      await expectLater(
        c.chat(model: 'm', request: _req, numCtx: 1),
        throwsA(isA<LlmServerException>()),
      );
    });

    test('a connection failure is reported as unreachable', () async {
      final s = _Server((req, _) => throw http.ClientException('refused'));
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      await expectLater(
        c.chat(model: 'm', request: _req, numCtx: 1),
        _serverError(LS.serverUnreachable(kDefaultOllamaUrl)),
      );
    });

    test('a stalled stream times out', () async {
      final s = _Server((req, _) {
        final ctrl = StreamController<List<int>>();
        ctrl.add(utf8.encode('${_ollamaLine('{')}\n'));
        // Never closed.
        return http.StreamedResponse(ctrl.stream, 200);
      });
      final c = LlmServerClient(
        baseUrl: kDefaultOllamaUrl,
        client: s.client,
        idleTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        c.chat(model: 'm', request: _req, numCtx: 1),
        _serverError(LS.serverStalled),
      );
    });

    test('no response before the first-byte timeout', () async {
      final s = _Server((req, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return _lines([]);
      });
      final c = LlmServerClient(
        baseUrl: kDefaultOllamaUrl,
        client: s.client,
        firstByteTimeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        c.chat(model: 'm', request: _req, numCtx: 1),
        _serverError(LS.serverTimeout(kDefaultOllamaUrl)),
      );
    });
  });

  group('ServerTextGenerator', () {
    test('Ollama context is capped; the label names the flavour', () async {
      final s = _Server(
        (req, _) => _json({
          'model_info': {'qwen3.context_length': 40960},
        }),
      );
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      final g = await ServerTextGenerator.connect(c, 'qwen3:8b');
      expect(g.contextTokens, kOllamaMaxContext);
      expect(g.modelName, 'ollama/qwen3:8b');
      expect(g.enforcesSchema, isTrue);
      expect(await g.countTokens('x' * 10), estimateTokens('x' * 10));
    });

    test('a small Ollama model context is kept; unknown = cap', () async {
      var info = <String, dynamic>{'llama.context_length': 4096};
      final s = _Server((req, _) => _json({'model_info': info}));
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      expect((await ServerTextGenerator.connect(c, 'm')).contextTokens, 4096);
      info = {};
      expect(
        (await ServerTextGenerator.connect(c, 'm')).contextTokens,
        kOllamaMaxContext,
      );
    });

    test('OpenAI default context when not reported', () async {
      final s = _Server((req, _) => _text('', 404));
      final c = LlmServerClient(baseUrl: 'http://h:8080/v1', client: s.client);
      final g = await ServerTextGenerator.connect(c, 'm');
      expect(g.contextTokens, kOpenAiDefaultContext);
      expect(g.modelName, 'openai-compatible/m');
    });

    test('falls back to the schema in the prompt once rejected', () async {
      final s = _Server((req, body) {
        if (req.url.path == '/api/show') return _json({'model_info': {}});
        final j = jsonDecode(body) as Map<String, dynamic>;
        if (j.containsKey('format')) {
          return _json({'error': 'invalid format'}, 400);
        }
        return _lines([_ollamaLine('{"ok":true}', done: true)]);
      });
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      final g = await ServerTextGenerator.connect(c, 'm');
      final out = await g.generate(_req);
      expect(out.text, '{"ok":true}');
      expect(g.enforcesSchema, isFalse);
      final retry = s.jsonBody(2);
      expect(retry.containsKey('format'), isFalse);
      final system = (retry['messages'] as List).first as Map;
      expect(system['content'], startsWith('SYS'));
      expect(system['content'], contains('# Output format (strict)'));

      // The next request skips the schema parameter directly.
      await g.generate(_req);
      expect(s.log, hasLength(4));
      expect(s.jsonBody(3).containsKey('format'), isFalse);
    });

    test('the prompt suffix is not appended twice', () async {
      final s = _Server((req, body) {
        if (req.url.path == '/api/show') return _json({'model_info': {}});
        if ((jsonDecode(body) as Map).containsKey('format')) {
          return _json({'error': 'invalid format'}, 400);
        }
        return _lines([_ollamaLine('{}', done: true)]);
      });
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      final g = await ServerTextGenerator.connect(c, 'm');
      await g.generate(
        LlmGenerationRequest(
          system: 'SYS${schemaPromptSuffix(_schema)}',
          user: 'u',
          maxTokens: 10,
          schema: _schema,
        ),
      );
      final system =
          ((s.jsonBody(2)['messages'] as List).first as Map)['content']
              as String;
      expect('# Output format (strict)'.allMatches(system), hasLength(1));
    });

    test('server errors propagate as InsatoException', () async {
      final s = _Server((req, _) {
        if (req.url.path == '/api/show') return _json({'model_info': {}});
        return _text('boom', 500);
      });
      final c = LlmServerClient(baseUrl: kDefaultOllamaUrl, client: s.client);
      final g = await ServerTextGenerator.connect(c, 'm');
      await expectLater(g.generate(_req), throwsA(isA<InsatoException>()));
    });
  });
}
