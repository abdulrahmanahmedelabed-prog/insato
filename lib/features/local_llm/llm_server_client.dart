// HTTP client of the local-network minutes server (F14): Ollama
// (`/api/chat`, NDJSON streaming, `format` = JSON schema) or any
// OpenAI-compatible server such as LM Studio (`/v1/chat/completions`, SSE
// streaming, `response_format` = json_schema).
//
// The API flavour is encoded in the saved server URL (no new setting): a URL
// whose path ends with `/v1` is OpenAI-compatible, any other is Ollama.
// [LlmServerClient.probe] detects the flavour of a server and returns the
// URL to save.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import '../../data/secure_settings.dart';
import 'llm_generator.dart';
import 'strings.dart';

/// API flavour of a local server.
enum LlmServerFlavor {
  /// Ollama native API.
  ollama,

  /// OpenAI-compatible API (LM Studio, llama.cpp server, vLLM, …).
  openAi,
}

/// Default LM Studio URL (OpenAI-compatible).
const String kDefaultLmStudioUrl = 'http://127.0.0.1:1234/v1';

/// Default Ollama URL (same as `AppSettingsData.defaultServerUrl`).
const String kDefaultOllamaUrl = AppSettingsData.defaultServerUrl;

/// Context window requested from Ollama (`num_ctx`) when the model allows
/// it: large enough for most meetings, small enough for 16 GB PCs.
const int kOllamaMaxContext = 16384;

/// Context assumed for an OpenAI-compatible server that does not report the
/// loaded context length.
const int kOpenAiDefaultContext = 8192;

String _trimSlashes(String url) {
  var t = url.trim();
  while (t.endsWith('/')) {
    t = t.substring(0, t.length - 1);
  }
  return t;
}

/// Flavour encoded in a saved server [url].
LlmServerFlavor serverFlavorOfUrl(String url) =>
    Uri.tryParse(_trimSlashes(url))?.path.toLowerCase().endsWith('/v1') ??
        false
    ? LlmServerFlavor.openAi
    : LlmServerFlavor.ollama;

/// [url] rewritten for [flavor]: `/v1` appended or removed; the default
/// Ollama / LM Studio URLs are swapped for each other.
String serverUrlForFlavor(String url, LlmServerFlavor flavor) {
  final t = _trimSlashes(url);
  if (serverFlavorOfUrl(t) == flavor) return t;
  if (flavor == LlmServerFlavor.openAi) {
    return t == kDefaultOllamaUrl ? kDefaultLmStudioUrl : '$t/v1';
  }
  if (t == kDefaultLmStudioUrl) return kDefaultOllamaUrl;
  return t.substring(0, t.length - 3);
}

/// [url] without a trailing `/v1` (the server root, same host and port).
String serverRootUrl(String url) {
  final t = _trimSlashes(url);
  return serverFlavorOfUrl(t) == LlmServerFlavor.openAi
      ? t.substring(0, t.length - 3)
      : t;
}

/// True when [url] points at this device (loopback), so nothing leaves it.
bool isLoopbackServerUrl(String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  if (host == 'localhost' || host.endsWith('.localhost')) return true;
  if (host == '::1' || host == '[::1]' || host == '0:0:0:0:0:0:0:1') {
    return true;
  }
  return RegExp(r'^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);
}

/// The server's error message from a JSON body, or null.
String? serverErrorMessage(String body) {
  try {
    final j = jsonDecode(body);
    if (j is Map) {
      final e = j['error'];
      if (e is String) return e;
      if (e is Map && e['message'] is String) return e['message'] as String;
      if (j['message'] is String) return j['message'] as String;
    }
  } on FormatException {
    // Not JSON.
  }
  final t = body.trim();
  if (t.isEmpty) return null;
  return t.length > 200 ? '${t.substring(0, 200)}…' : t;
}

/// Result of [LlmServerClient.probe].
class LlmServerProbe {
  /// Creates a result.
  const LlmServerProbe({
    required this.flavor,
    required this.url,
    required this.models,
  });

  /// Detected flavour.
  final LlmServerFlavor flavor;

  /// URL to save for this flavour.
  final String url;

  /// Model names available on the server.
  final List<String> models;
}

/// One server request failure, mapped to an Arabic message.
class LlmServerException extends MinutesGenerationException {
  /// Creates the exception.
  const LlmServerException(
    super.messageAr, {
    super.debugDetails,
    super.cause,
    super.retryable,
    this.statusCode,
  });

  /// HTTP status, when the server answered.
  final int? statusCode;
}

/// HTTP client of an Ollama / OpenAI-compatible server.
class LlmServerClient {
  /// Creates a client for the saved [baseUrl] (flavour from the URL).
  /// [client] is closed by [close] only when it was created here.
  LlmServerClient({
    required String baseUrl,
    http.Client? client,
    this.connectTimeout = const Duration(seconds: 10),
    this.firstByteTimeout = const Duration(minutes: 10),
    this.idleTimeout = const Duration(minutes: 3),
  }) : baseUrl = _trimSlashes(baseUrl),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// Base URL as saved (with `/v1` for OpenAI-compatible servers).
  final String baseUrl;

  /// Timeout of short requests (model list, probe, model info).
  final Duration connectTimeout;

  /// Timeout until the first answer bytes of a generation (model loading and
  /// prompt processing happen before it).
  final Duration firstByteTimeout;

  /// Maximum silence between two streamed chunks.
  final Duration idleTimeout;

  final http.Client _client;
  final bool _ownsClient;

  /// Flavour from [baseUrl].
  LlmServerFlavor get flavor => serverFlavorOfUrl(baseUrl);

  Uri _uri(String base, String path) => Uri.parse('$base$path');

  // -------------------------------------------------------------------------
  // Short requests
  // -------------------------------------------------------------------------

  Future<http.Response> _get(Uri uri) => _short(() => _client.get(uri), uri);

  Future<http.Response> _postJson(Uri uri, Map<String, dynamic> body) =>
      _short(
        () => _client.post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(body),
        ),
        uri,
      );

  Future<http.Response> _short(
    Future<http.Response> Function() send,
    Uri uri,
  ) async {
    try {
      return await send().timeout(connectTimeout);
    } on TimeoutException catch (e) {
      throw LlmServerException(
        LS.serverTimeout(baseUrl),
        debugDetails: 'timeout $uri',
        cause: e,
        retryable: true,
      );
    } on InsatoException {
      rethrow;
    } catch (e) {
      throw _connectionError(e, uri);
    }
  }

  LlmServerException _connectionError(Object e, Uri uri) => LlmServerException(
    LS.serverUnreachable(baseUrl),
    debugDetails: '$uri: $e',
    cause: e,
    retryable: e is SocketException || e is http.ClientException,
  );

  LlmServerException _httpError(int status, String body, {String? model}) {
    final msg = serverErrorMessage(body);
    final lower = (msg ?? '').toLowerCase();
    if (model != null &&
        (status == 404 ||
            (lower.contains('model') &&
                (lower.contains('not found') ||
                    lower.contains('does not exist') ||
                    lower.contains('no models loaded'))))) {
      return LlmServerException(
        LS.serverModelMissing(model, flavor == LlmServerFlavor.ollama),
        debugDetails: 'HTTP $status: $msg',
        statusCode: status,
      );
    }
    if (lower.contains('context') &&
        (lower.contains('length') ||
            lower.contains('exceed') ||
            lower.contains('overflow'))) {
      return LlmServerException(
        LS.serverContextExceeded,
        debugDetails: 'HTTP $status: $msg',
        statusCode: status,
      );
    }
    return LlmServerException(
      LS.serverHttpError(status, msg),
      debugDetails: 'HTTP $status: $msg',
      statusCode: status,
      retryable: status >= 500 || status == 429,
    );
  }

  static Map<String, dynamic>? _json(String body) {
    try {
      final j = jsonDecode(body);
      return j is Map<String, dynamic> ? j : null;
    } on FormatException {
      return null;
    }
  }

  /// Model names available on the server (Ollama `/api/tags`, OpenAI
  /// `/v1/models`), sorted.
  Future<List<String>> listModels() =>
      _listModels(baseUrl, flavor);

  Future<List<String>> _listModels(String base, LlmServerFlavor f) async {
    final uri = _uri(base, f == LlmServerFlavor.ollama ? '/api/tags' : '/models');
    final r = await _get(uri);
    if (r.statusCode != 200) throw _httpError(r.statusCode, r.body);
    final j = _json(r.body);
    final list = j?[f == LlmServerFlavor.ollama ? 'models' : 'data'];
    if (list is! List) {
      throw LlmServerException(
        LS.serverNotRecognised(base),
        debugDetails: 'unexpected model list from $uri',
      );
    }
    final names = <String>{
      for (final m in list)
        if (m is Map)
          if ((m['name'] ?? m['model'] ?? m['id']) case final String n
              when n.trim().isNotEmpty)
            n.trim(),
    }.toList()..sort();
    return names;
  }

  /// Detects the server's flavour: the URL's own flavour first, then the
  /// other one. Returns the URL to save and the models.
  Future<LlmServerProbe> probe() async {
    final own = flavor;
    final other = own == LlmServerFlavor.ollama
        ? LlmServerFlavor.openAi
        : LlmServerFlavor.ollama;
    LlmServerException? first;
    for (final f in [own, other]) {
      final url = serverUrlForFlavor(baseUrl, f);
      try {
        final models = await _listModels(url, f);
        return LlmServerProbe(flavor: f, url: url, models: models);
      } on LlmServerException catch (e) {
        first ??= e;
        // A server that is not reachable at all will not answer the other
        // flavour either.
        if (e.statusCode == null && e.cause != null) rethrow;
      }
    }
    throw LlmServerException(
      LS.serverNotRecognised(baseUrl),
      debugDetails: first?.debugDetails,
      cause: first,
    );
  }

  /// The context length of [model] the server allows / has loaded, or null
  /// when unknown. Throws [LlmServerException] when the server is not
  /// reachable or (Ollama) the model does not exist.
  Future<int?> contextLength(String model) async {
    if (flavor == LlmServerFlavor.ollama) {
      // `name` for Ollama versions older than the `model` field.
      final r = await _postJson(_uri(baseUrl, '/api/show'), {
        'model': model,
        'name': model,
      });
      if (r.statusCode != 200) {
        throw _httpError(r.statusCode, r.body, model: model);
      }
      final info = _json(r.body)?['model_info'];
      if (info is Map) {
        for (final e in info.entries) {
          if ('${e.key}'.endsWith('.context_length') && e.value is int) {
            return e.value as int;
          }
        }
      }
      return null;
    }
    // LM Studio's REST API reports the loaded context; other servers do not
    // have it (404) — the default is assumed then.
    // The same host and port without `/v1` (not [serverUrlForFlavor], which
    // swaps the default LM Studio URL for the Ollama one).
    final root = serverRootUrl(baseUrl);
    final http.Response r;
    try {
      r = await _get(
        _uri(root, '/api/v0/models/${Uri.encodeComponent(model)}'),
      );
    } on LlmServerException catch (e) {
      if (e.statusCode == null && e.cause is TimeoutException) return null;
      rethrow;
    }
    if (r.statusCode != 200) return null;
    final j = _json(r.body);
    final loaded = j?['loaded_context_length'];
    if (loaded is int && loaded > 0) return loaded;
    final max = j?['max_context_length'];
    return max is int && max > 0 ? max : null;
  }

  // -------------------------------------------------------------------------
  // Generation
  // -------------------------------------------------------------------------

  /// Runs one chat generation with streaming. [numCtx] is sent to Ollama
  /// (`options.num_ctx`). When [useSchema] is false the schema is not sent
  /// (the caller put it in the prompt). Throws [LlmServerSchemaRejected]
  /// when the server refuses the schema parameter.
  Future<LlmGeneration> chat({
    required String model,
    required LlmGenerationRequest request,
    required int numCtx,
    bool useSchema = true,
    LlmProgressCallback? onProgress,
  }) async {
    final ollama = flavor == LlmServerFlavor.ollama;
    final schema = useSchema ? request.schema : null;
    final messages = [
      {'role': 'system', 'content': request.system},
      {'role': 'user', 'content': request.user},
    ];
    final body = ollama
        ? <String, dynamic>{
            'model': model,
            'messages': messages,
            'stream': true,
            'format': ?schema,
            'options': {
              'num_ctx': numCtx,
              'num_predict': request.maxTokens,
              'temperature': request.temperature,
            },
          }
        : <String, dynamic>{
            'model': model,
            'messages': messages,
            'stream': true,
            'max_tokens': request.maxTokens,
            'temperature': request.temperature,
            if (schema != null)
              'response_format': {
                'type': 'json_schema',
                'json_schema': {
                  'name': 'response',
                  'strict': true,
                  'schema': schema,
                },
              },
          };
    final uri = _uri(baseUrl, ollama ? '/api/chat' : '/chat/completions');
    final abort = Completer<void>();
    final req = http.AbortableRequest('POST', uri, abortTrigger: abort.future)
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = ollama ? 'application/x-ndjson' : 'text/event-stream'
      ..body = jsonEncode(body);

    http.StreamedResponse resp;
    try {
      resp = await _client.send(req).timeout(firstByteTimeout);
    } on TimeoutException catch (e) {
      if (!abort.isCompleted) abort.complete();
      throw LlmServerException(
        LS.serverTimeout(baseUrl),
        debugDetails: 'no response from $uri',
        cause: e,
        retryable: true,
      );
    } catch (e) {
      throw _connectionError(e, uri);
    }
    if (resp.statusCode != 200) {
      final text = await resp.stream.bytesToString().catchError((_) => '');
      if (schema != null &&
          resp.statusCode == 400 &&
          RegExp(
            'format|schema|response_format',
            caseSensitive: false,
          ).hasMatch(text)) {
        throw LlmServerSchemaRejected(serverErrorMessage(text) ?? text);
      }
      throw _httpError(resp.statusCode, text, model: model);
    }

    final answer = StringBuffer();
    var thinkingChars = 0;
    var truncated = false;
    var usedModel = model;
    void onLine(String raw) {
      var line = raw.trim();
      if (line.isEmpty) return;
      if (!ollama) {
        if (!line.startsWith('data:')) return;
        line = line.substring(5).trim();
        if (line == '[DONE]') return;
      }
      final j = _json(line);
      if (j == null) return;
      final err = j['error'];
      if (err != null) {
        throw _httpError(
          200,
          jsonEncode({'error': err}),
          model: model,
        );
      }
      if (j['model'] case final String m when m.isNotEmpty) usedModel = m;
      String? content;
      String? thinking;
      String? finish;
      if (ollama) {
        final msg = j['message'];
        if (msg is Map) {
          content = msg['content'] as String?;
          thinking = msg['thinking'] as String?;
        }
        if (j['done'] == true) finish = j['done_reason'] as String?;
      } else {
        final choices = j['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final c = choices.first as Map;
          final delta = c['delta'];
          if (delta is Map) {
            content = delta['content'] as String?;
            thinking = (delta['reasoning_content'] ?? delta['reasoning'])
                as String?;
          }
          finish = c['finish_reason'] as String?;
        }
      }
      if (thinking != null && thinking.isNotEmpty) {
        thinkingChars += thinking.length;
        onProgress?.call(LlmStreamPhase.thinking, thinkingChars);
      }
      if (content != null && content.isNotEmpty) {
        answer.write(content);
        onProgress?.call(LlmStreamPhase.writing, answer.length);
      }
      if (finish == 'length') truncated = true;
    }

    try {
      await for (final line
          in resp.stream
              .timeout(idleTimeout)
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        onLine(line);
      }
    } on TimeoutException catch (e) {
      if (!abort.isCompleted) abort.complete();
      throw LlmServerException(
        LS.serverStalled,
        debugDetails: 'stream idle on $uri',
        cause: e,
        retryable: true,
      );
    } on InsatoException {
      if (!abort.isCompleted) abort.complete();
      rethrow;
    } catch (e) {
      throw _connectionError(e, uri);
    }
    return LlmGeneration(
      text: stripThinking(answer.toString()),
      model: usedModel,
      truncated: truncated,
    );
  }

  /// Releases the HTTP client (when owned).
  void close() {
    if (_ownsClient) _client.close();
  }
}

/// The server refused the JSON-schema parameter (old Ollama, a server
/// without structured output); retry with the schema in the prompt.
class LlmServerSchemaRejected implements Exception {
  /// Creates the signal.
  const LlmServerSchemaRejected(this.message);

  /// Server message.
  final String message;

  @override
  String toString() => 'LlmServerSchemaRejected: $message';
}

/// [LlmTextGenerator] over a local server model.
class ServerTextGenerator implements LlmTextGenerator {
  ServerTextGenerator._(this._client, this.model, this.contextTokens);

  /// Connects to [model] on the server of [client]: checks that it exists
  /// and reads its context length (see [kOllamaMaxContext],
  /// [kOpenAiDefaultContext]).
  static Future<ServerTextGenerator> connect(
    LlmServerClient client,
    String model,
  ) async {
    final reported = await client.contextLength(model);
    final ctx = client.flavor == LlmServerFlavor.ollama
        ? (reported == null || reported > kOllamaMaxContext
              ? kOllamaMaxContext
              : reported)
        : (reported ?? kOpenAiDefaultContext);
    return ServerTextGenerator._(client, model, ctx);
  }

  final LlmServerClient _client;

  /// Model name on the server.
  final String model;

  @override
  final int contextTokens;

  bool _schemaSupported = true;

  @override
  String get modelName => serverModelLabel(_client.flavor, model);

  @override
  bool get enforcesSchema => _schemaSupported;

  @override
  Future<int> countTokens(String text) async => estimateTokens(text);

  @override
  Future<LlmGeneration> generate(
    LlmGenerationRequest request, {
    LlmProgressCallback? onProgress,
  }) async {
    final schema = request.schema;
    if (schema != null && _schemaSupported) {
      try {
        return await _client.chat(
          model: model,
          request: request,
          numCtx: contextTokens,
          onProgress: onProgress,
        );
      } on LlmServerSchemaRejected {
        _schemaSupported = false;
      }
    }
    final system = schema != null &&
            !request.system.contains('# Output format (strict)')
        ? '${request.system}${schemaPromptSuffix(schema)}'
        : request.system;
    return _client.chat(
      model: model,
      request: LlmGenerationRequest(
        system: system,
        user: request.user,
        maxTokens: request.maxTokens,
        schema: schema,
        temperature: request.temperature,
      ),
      numCtx: contextTokens,
      useSchema: false,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> close() async => _client.close();
}

/// A model label for `Minutes.model`: `ollama/<model>` or
/// `openai-compatible/<model>`.
String serverModelLabel(LlmServerFlavor flavor, String model) =>
    flavor == LlmServerFlavor.ollama ? 'ollama/$model' : 'openai-compatible/$model';
