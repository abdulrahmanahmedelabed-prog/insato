// Raw-HTTP client for the Claude Messages API with SSE streaming.
//
// Dart has no official Anthropic SDK, so this talks to
// `POST /v1/messages` directly using `package:http`. Responses are always
// streamed so that very long generations (long meetings, adaptive thinking)
// never trip an idle timeout, and transient failures are retried with
// exponential backoff + jitter, honouring `retry-after`.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/errors.dart';

/// Default model used to write minutes.
const String kDefaultClaudeModel = 'claude-opus-5-5';

/// Messages API endpoint.
final Uri kClaudeMessagesEndpoint =
    Uri.parse('https://api.anthropic.com/v1/messages');

/// `anthropic-version` header value.
const String kAnthropicVersion = '2026-10-21';

/// `anthropic-beta` header value enabling server-side refusal fallbacks.
const String kAnthropicBetaFallback = 'server-side-fallback-2026-07-01';

// ---------------------------------------------------------------------------
// Server-Sent Events parsing
// ---------------------------------------------------------------------------

/// One dispatched Server-Sent Event.
class SseEvent {
  /// Creates an event. [event] defaults to `message` per the SSE spec.
  const SseEvent({this.event = 'message', required this.data, this.id});

  /// The `event:` field (`message` when the server did not send one).
  final String event;

  /// The `data:` payload. Multiple `data:` lines are joined with `\n`.
  final String data;

  /// The last `id:` value seen, if any.
  final String? id;

  @override
  String toString() => 'SseEvent($event, $data)';
}

/// Incremental, spec-compliant Server-Sent Events parser.
///
/// Feed it decoded text in arbitrary chunks with [add]; it returns the events
/// completed by that chunk. It handles:
/// * `\n`, `\r\n` and bare `\r` line endings, including a `\r\n` pair split
///   across two chunks;
/// * lines split across chunks;
/// * multi-line `data:` fields (joined with `\n`);
/// * comment lines (starting with `:`), which are ignored;
/// * a leading byte-order mark;
/// * fields with no colon (`data` alone means an empty value).
///
/// Call [close] at end of stream to dispatch a final event that was not
/// followed by a blank line.
class SseParser {
  final StringBuffer _line = StringBuffer();
  final List<String> _data = <String>[];
  String? _eventType;
  String? _lastId;
  bool _pendingCr = false;
  bool _started = false;
  bool _hasData = false;

  /// Parses [chunk] and returns the events it completed (possibly none).
  List<SseEvent> add(String chunk) {
    final out = <SseEvent>[];
    var start = 0;
    if (!_started && chunk.isNotEmpty) {
      _started = true;
      if (chunk.codeUnitAt(0) == 0xFEFF) start = 1;
    }
    for (var i = start; i < chunk.length; i++) {
      final c = chunk.codeUnitAt(i);
      if (_pendingCr) {
        _pendingCr = false;
        if (c == 0x0A) continue; // second half of a CRLF split across chunks
      }
      if (c == 0x0D) {
        _pendingCr = true;
        _endLine(out);
      } else if (c == 0x0A) {
        _endLine(out);
      } else {
        _line.writeCharCode(c);
      }
    }
    return out;
  }

  /// Flushes a trailing line / event at end of stream.
  List<SseEvent> close() {
    final out = <SseEvent>[];
    if (_line.isNotEmpty) _endLine(out);
    _dispatch(out);
    _pendingCr = false;
    return out;
  }

  void _endLine(List<SseEvent> out) {
    final line = _line.toString();
    _line.clear();
    if (line.isEmpty) {
      _dispatch(out);
      return;
    }
    if (line.startsWith(':')) return; // comment
    final colon = line.indexOf(':');
    String field;
    String value;
    if (colon < 0) {
      field = line;
      value = '';
    } else {
      field = line.substring(0, colon);
      value = line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
    }
    switch (field) {
      case 'data':
        _data.add(value);
        _hasData = true;
      case 'event':
        _eventType = value;
      case 'id':
        if (!value.contains('\u0000')) _lastId = value;
      default:
        // `retry` and unknown fields are ignored.
        break;
    }
  }

  void _dispatch(List<SseEvent> out) {
    if (_hasData) {
      out.add(SseEvent(
        event: (_eventType == null || _eventType!.isEmpty)
            ? 'message'
            : _eventType!,
        data: _data.join('\n'),
        id: _lastId,
      ));
    }
    _data.clear();
    _hasData = false;
    _eventType = null;
  }

  /// Transforms a byte stream (UTF-8) into a stream of [SseEvent]s.
  static Stream<SseEvent> parseByteStream(Stream<List<int>> bytes) async* {
    final parser = SseParser();
    await for (final text in bytes.transform(utf8.decoder)) {
      for (final e in parser.add(text)) {
        yield e;
      }
    }
    for (final e in parser.close()) {
      yield e;
    }
  }
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

/// Token usage reported by the API.
class ClaudeUsage {
  /// Creates a usage record.
  const ClaudeUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheCreationInputTokens = 0,
    this.cacheReadInputTokens = 0,
  });

  /// Uncached input tokens.
  final int inputTokens;

  /// Output tokens (including thinking).
  final int outputTokens;

  /// Input tokens written to the prompt cache.
  final int cacheCreationInputTokens;

  /// Input tokens read from the prompt cache.
  final int cacheReadInputTokens;

  /// Returns a copy where every field present in [json] overrides this one.
  /// The API reports cumulative counts, so later values replace earlier ones.
  ClaudeUsage mergeJson(Map<String, dynamic>? json) {
    if (json == null) return this;
    int pick(String key, int current) {
      final v = json[key];
      return v is num ? v.toInt() : current;
    }

    return ClaudeUsage(
      inputTokens: pick('input_tokens', inputTokens),
      outputTokens: pick('output_tokens', outputTokens),
      cacheCreationInputTokens:
          pick('cache_creation_input_tokens', cacheCreationInputTokens),
      cacheReadInputTokens:
          pick('cache_read_input_tokens', cacheReadInputTokens),
    );
  }

  @override
  String toString() =>
      'ClaudeUsage(in: $inputTokens, out: $outputTokens, cacheWrite: '
      '$cacheCreationInputTokens, cacheRead: $cacheReadInputTokens)';
}

/// The outcome of a successful [ClaudeClient.createStructured] call.
class ClaudeResult {
  /// Creates a result.
  const ClaudeResult({
    required this.text,
    required this.model,
    required this.stopReason,
    required this.usage,
    this.messageId,
    this.fallbackFromModels = const [],
  });

  /// Concatenated text of all `text` content blocks.
  final String text;

  /// Model that actually served the response (after any server-side
  /// fallback).
  final String model;

  /// The final `stop_reason` (e.g. `end_turn`).
  final String stopReason;

  /// Token usage.
  final ClaudeUsage usage;

  /// API message id, for logs.
  final String? messageId;

  /// Models that declined and were replaced by a server-side fallback, in
  /// order. Empty when no fallback happened.
  final List<String> fallbackFromModels;
}

/// Coarse phases of a request, reported through `onPhase` for UI status.
enum ClaudeStreamPhase {
  /// Sending the request / waiting for response headers.
  connecting,

  /// The model is reasoning (thinking block streaming).
  thinking,

  /// The model is writing the answer (text block streaming).
  writing,

  /// A transient failure occurred; waiting before the next attempt.
  retrying,
}

/// Signature of the delay used between retries (injectable for tests).
typedef RetryDelay = Future<void> Function(Duration duration);

class _RetryableFailure implements Exception {
  _RetryableFailure(this.details, {this.retryAfter, this.cause});
  final String details;
  final Duration? retryAfter;
  final Object? cause;
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

/// Minimal, robust client for the Claude Messages API using streaming
/// structured outputs.
class ClaudeClient {
  /// Creates a client.
  ///
  /// * [client] — injected HTTP client (tests); when omitted an owned client is
  ///   created and closed by [close].
  /// * [model] — model id, default [kDefaultClaudeModel].
  /// * [maxAttempts] — total attempts for retryable failures (default 4).
  /// * [idleTimeout] — maximum silence between bytes (default 10 minutes; the
  ///   server sends `ping` events far more often).
  /// * [delay] — sleeping function used between retries (tests pass a no-op).
  /// * [random] — jitter source.
  ClaudeClient({
    required String apiKey,
    http.Client? client,
    this.model = kDefaultClaudeModel,
    Uri? endpoint,
    this.maxAttempts = 4,
    this.idleTimeout = const Duration(minutes: 10),
    this.baseRetryDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(seconds: 60),
    RetryDelay? delay,
    math.Random? random,
  })  : _apiKey = apiKey.trim(),
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        endpoint = endpoint ?? kClaudeMessagesEndpoint,
        _delay = delay ?? Future<void>.delayed,
        _random = random ?? math.Random();

  final String _apiKey;
  final http.Client _client;
  final bool _ownsClient;
  final RetryDelay _delay;
  final math.Random _random;

  /// Model id sent in every request.
  final String model;

  /// Messages endpoint.
  final Uri endpoint;

  /// Total attempts for retryable failures.
  final int maxAttempts;

  /// Maximum allowed silence on the connection.
  final Duration idleTimeout;

  /// First backoff step (doubled each retry, with jitter).
  final Duration baseRetryDelay;

  /// Upper bound for any single wait, including `retry-after`.
  final Duration maxRetryDelay;

  /// Builds the JSON request body. Exposed for tests and diagnostics.
  Map<String, dynamic> buildRequestBody({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
    String effort = 'high',
    int maxTokens = 64000,
  }) {
    return {
      'model': model,
      'max_tokens': maxTokens,
      'stream': true,
      'thinking': {'type': 'adaptive'},
      'output_config': {
        'effort': effort,
        'format': {'type': 'json_schema', 'schema': schema},
      },
      'fallbacks': 'default',
      'system': [
        {
          'type': 'text',
          'text': system,
          'cache_control': {'type': 'ephemeral'},
        },
      ],
      'messages': [
        {'role': 'user', 'content': user},
      ],
    };
  }

  /// Sends one structured-output request and returns the generated text.
  ///
  /// [onDelta] receives the cumulative number of answer characters received
  /// so far (resets to 0 if a retry restarts the stream). [onPhase] reports
  /// coarse phases and the 1-based attempt number.
  ///
  /// Throws:
  /// * [MissingApiKeyException] when the key is empty or rejected (401/403).
  /// * [MinutesGenerationException] for refusals, truncated output, invalid
  ///   requests (non-retryable) or exhausted retries (`retryable: true`).
  Future<ClaudeResult> createStructured({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
    String effort = 'high',
    int maxTokens = 64000,
    void Function(int receivedChars)? onDelta,
    void Function(ClaudeStreamPhase phase, int attempt)? onPhase,
  }) async {
    if (_apiKey.isEmpty) {
      throw const MissingApiKeyException(
        'لم يُضبط مفتاح Claude API بعد. أدخل المفتاح من الإعدادات ثم أعد المحاولة.',
      );
    }
    final body = jsonEncode(buildRequestBody(
      system: system,
      user: user,
      schema: schema,
      effort: effort,
      maxTokens: maxTokens,
    ));

    _RetryableFailure? last;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        onPhase?.call(ClaudeStreamPhase.connecting, attempt);
        return await _attempt(body, onDelta, (p) => onPhase?.call(p, attempt));
      } on _RetryableFailure catch (f) {
        last = f;
        if (attempt == maxAttempts) break;
        onPhase?.call(ClaudeStreamPhase.retrying, attempt);
        await _delay(_backoff(attempt, f.retryAfter));
      }
    }
    throw MinutesGenerationException(
      'تعذّر الاتصال بخدمة Claude بعد عدة محاولات (الخدمة مشغولة أو الاتصال '
      'غير مستقر). حاول مرة أخرى بعد قليل.',
      debugDetails: last?.details,
      cause: last?.cause,
      retryable: true,
    );
  }

  /// Closes the underlying HTTP client if this instance created it.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Backoff before retry number [attempt] (1-based): honours [retryAfter]
  /// when present, otherwise `base * 2^(attempt-1)` with full jitter in
  /// [50%, 100%], capped at [maxRetryDelay].
  Duration _backoff(int attempt, Duration? retryAfter) {
    final capMs = maxRetryDelay.inMilliseconds;
    if (retryAfter != null) {
      final ms = retryAfter.inMilliseconds.clamp(0, capMs);
      // Small jitter so many clients do not reconnect in lockstep.
      return Duration(milliseconds: ms + _random.nextInt(250));
    }
    final exp = baseRetryDelay.inMilliseconds * math.pow(2, attempt - 1);
    final capped = math.min(exp.toDouble(), capMs.toDouble());
    final jittered = capped * (0.5 + 0.5 * _random.nextDouble());
    return Duration(milliseconds: jittered.round());
  }

  Future<ClaudeResult> _attempt(
    String body,
    void Function(int)? onDelta,
    void Function(ClaudeStreamPhase) phase,
  ) async {
    final request = http.Request('POST', endpoint)
      ..headers.addAll({
        'content-type': 'application/json',
        'accept': 'text/event-stream',
        'x-api-key': _apiKey,
        'anthropic-version': kAnthropicVersion,
        'anthropic-beta': kAnthropicBetaFallback,
      })
      ..body = body;

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(idleTimeout);
    } on TimeoutException catch (e) {
      throw _RetryableFailure('timeout waiting for response headers', cause: e);
    } on http.ClientException catch (e) {
      throw _RetryableFailure('network error: ${e.message}', cause: e);
    }

    if (response.statusCode != 200) {
      await _handleHttpError(response);
    }
    return _consumeStream(response, onDelta, phase);
  }

  Future<Never> _handleHttpError(http.StreamedResponse response) async {
    String raw;
    try {
      raw = await response.stream.bytesToString().timeout(idleTimeout);
    } catch (_) {
      raw = '';
    }
    final status = response.statusCode;
    final (type, message) = _parseApiError(raw);
    final details = 'HTTP $status${type == null ? '' : ' $type'}: '
        '${message ?? raw}';

    if (status == 401 || status == 403) {
      throw MissingApiKeyException(
        'مفتاح Claude API غير صالح أو لا يملك صلاحية استخدام النموذج. تحقّق من '
        'المفتاح في الإعدادات.',
        debugDetails: details,
      );
    }
    final shouldRetryHeader = response.headers['x-should-retry'];
    final retryable = shouldRetryHeader == 'true' ||
        (shouldRetryHeader != 'false' &&
            (status == 408 || status == 409 || status == 429 || status >= 500));
    if (retryable) {
      throw _RetryableFailure(details,
          retryAfter: parseRetryAfter(response.headers['retry-after']));
    }
    if (status == 413) {
      throw MinutesGenerationException(
        'نص الاجتماع أطول من الحد الذي تقبله خدمة Claude في طلب واحد.',
        debugDetails: details,
      );
    }
    if (status == 404) {
      throw MinutesGenerationException(
        'النموذج المطلوب غير متاح لهذا الحساب ($model).',
        debugDetails: details,
      );
    }
    throw MinutesGenerationException(
      'رفضت خدمة Claude الطلب. ${message ?? ''}'.trim(),
      debugDetails: details,
    );
  }

  Future<ClaudeResult> _consumeStream(
    http.StreamedResponse response,
    void Function(int)? onDelta,
    void Function(ClaudeStreamPhase) phase,
  ) async {
    final text = StringBuffer();
    final blockTypes = <int, String>{};
    final fallbackFrom = <String>[];
    String? servedModel;
    String? messageId;
    String? stopReason;
    var usage = const ClaudeUsage();
    var sawMessageStop = false;
    var lastPhase = ClaudeStreamPhase.connecting;

    void setPhase(ClaudeStreamPhase p) {
      if (p != lastPhase) {
        lastPhase = p;
        phase(p);
      }
    }

    try {
      final events = SseParser.parseByteStream(
        response.stream.timeout(idleTimeout),
      );
      await for (final event in events) {
        if (event.data.isEmpty) continue;
        Map<String, dynamic> payload;
        try {
          final decoded = jsonDecode(event.data);
          if (decoded is! Map<String, dynamic>) continue;
          payload = decoded;
        } on FormatException {
          continue; // malformed event: ignore rather than abort a long stream
        }
        final type = (payload['type'] as String?) ?? event.event;
        switch (type) {
          case 'message_start':
            final message = payload['message'];
            if (message is Map<String, dynamic>) {
              servedModel = (message['model'] as String?) ?? servedModel;
              messageId = message['id'] as String?;
              usage = usage.mergeJson(
                  message['usage'] as Map<String, dynamic>?);
            }
          case 'content_block_start':
            final index = (payload['index'] as num?)?.toInt() ?? -1;
            final block = payload['content_block'];
            if (block is Map<String, dynamic>) {
              final blockType = (block['type'] as String?) ?? '';
              blockTypes[index] = blockType;
              if (blockType == 'text') {
                setPhase(ClaudeStreamPhase.writing);
                final initial = block['text'];
                if (initial is String && initial.isNotEmpty) {
                  text.write(initial);
                  onDelta?.call(text.length);
                }
              } else if (blockType == 'thinking' ||
                  blockType == 'redacted_thinking') {
                setPhase(ClaudeStreamPhase.thinking);
              } else if (blockType == 'fallback') {
                final from = block['from'];
                final to = block['to'];
                if (from is Map && from['model'] is String) {
                  fallbackFrom.add(from['model'] as String);
                }
                if (to is Map && to['model'] is String) {
                  servedModel = to['model'] as String;
                }
              }
            }
          case 'content_block_delta':
            final index = (payload['index'] as num?)?.toInt() ?? -1;
            final delta = payload['delta'];
            if (delta is Map<String, dynamic> &&
                delta['type'] == 'text_delta' &&
                blockTypes[index] == 'text') {
              final t = delta['text'];
              if (t is String && t.isNotEmpty) {
                text.write(t);
                onDelta?.call(text.length);
              }
            }
          case 'message_delta':
            final delta = payload['delta'];
            if (delta is Map<String, dynamic> &&
                delta['stop_reason'] is String) {
              stopReason = delta['stop_reason'] as String;
            }
            usage = usage.mergeJson(payload['usage'] as Map<String, dynamic>?);
          case 'message_stop':
            sawMessageStop = true;
          case 'error':
            final error = payload['error'];
            final errType =
                error is Map ? error['type'] as String? : null;
            final errMsg = error is Map ? error['message'] as String? : null;
            final details = 'stream error ${errType ?? ''}: ${errMsg ?? ''}';
            if (errType == 'overloaded_error' ||
                errType == 'rate_limit_error' ||
                errType == 'api_error' ||
                errType == 'timeout_error') {
              throw _RetryableFailure(details);
            }
            if (errType == 'authentication_error' ||
                errType == 'permission_error') {
              throw MissingApiKeyException(
                'مفتاح Claude API غير صالح أو لا يملك صلاحية استخدام النموذج.',
                debugDetails: details,
              );
            }
            throw MinutesGenerationException(
              'حدث خطأ أثناء توليد المحضر. ${errMsg ?? ''}'.trim(),
              debugDetails: details,
            );
          default:
            // ping, content_block_stop and unknown events are ignored.
            break;
        }
        if (sawMessageStop) break;
      }
    } on TimeoutException catch (e) {
      throw _RetryableFailure('stream idle timeout', cause: e);
    } on http.ClientException catch (e) {
      throw _RetryableFailure('network error mid-stream: ${e.message}',
          cause: e);
    } on FormatException catch (e) {
      throw _RetryableFailure('invalid UTF-8 in stream: ${e.message}',
          cause: e);
    }

    if (stopReason == null) {
      // The connection ended before the message completed.
      throw _RetryableFailure(
          'stream ended prematurely (message_stop: $sawMessageStop)');
    }
    switch (stopReason) {
      case 'refusal':
        throw MinutesGenerationException(
          'اعتذر النموذج عن إنشاء المحضر لهذا المحتوى.',
          debugDetails: 'stop_reason=refusal model=$servedModel',
        );
      case 'max_tokens':
        throw MinutesGenerationException(
          'توقف النموذج قبل إكمال المحضر لأن الناتج تجاوز الحد الأقصى للطول.',
          debugDetails: 'stop_reason=max_tokens chars=${text.length}',
        );
      case 'model_context_window_exceeded':
        throw MinutesGenerationException(
          'نص الاجتماع أطول من السعة التي يستطيع النموذج معالجتها.',
          debugDetails: 'stop_reason=model_context_window_exceeded',
        );
    }
    return ClaudeResult(
      text: text.toString(),
      model: servedModel ?? model,
      stopReason: stopReason,
      usage: usage,
      messageId: messageId,
      fallbackFromModels: List.unmodifiable(fallbackFrom),
    );
  }
}

(String?, String?) _parseApiError(String raw) {
  if (raw.isEmpty) return (null, null);
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded['error'] is Map) {
      final error = decoded['error'] as Map;
      return (error['type'] as String?, error['message'] as String?);
    }
  } on FormatException {
    // Not JSON (e.g. a proxy's HTML error page).
  }
  return (null, null);
}

/// Parses a `retry-after` header value: either delay-seconds (integer or
/// decimal) or an HTTP-date. Returns null when absent or unparseable.
Duration? parseRetryAfter(String? value, {DateTime? now}) {
  if (value == null) return null;
  final v = value.trim();
  if (v.isEmpty) return null;
  final seconds = double.tryParse(v);
  if (seconds != null) {
    if (seconds.isNaN || seconds < 0) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }
  try {
    final date = parseHttpDate(v);
    final diff = date.difference((now ?? DateTime.now()).toUtc());
    return diff.isNegative ? Duration.zero : diff;
  } on FormatException {
    return null;
  }
}

/// Parses an RFC 7231 IMF-fixdate such as `Wed, 21 Oct 2015 07:28:00 GMT`.
DateTime parseHttpDate(String value) {
  const months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  final m = RegExp(
    r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+GMT$',
  ).firstMatch(value);
  if (m == null) throw FormatException('Not an HTTP date', value);
  final month = months[m.group(2)!.toLowerCase()];
  if (month == null) throw FormatException('Bad month', value);
  return DateTime.utc(
    int.parse(m.group(3)!),
    month,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  );
}
