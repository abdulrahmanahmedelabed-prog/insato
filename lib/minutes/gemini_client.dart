// Google Gemini API client and the Gemini minutes backend (the default
// minutes engine of Insato v1.1; free API key from Google AI Studio,
// aistudio.google.com/apikey).
//
// Raw HTTP over `package:http` (REST, v1beta):
// * `POST /v1beta/models/{model}:streamGenerateContent?alt=sse` with the key
//   in the `x-goog-api-key` header (never in the URL). Every SSE event is a
//   `GenerateContentResponse` chunk; the answer is the concatenation of
//   `candidates[0].content.parts[].text` (thought parts excluded).
// * Structured output, with a fallback chain when a model rejects a dialect
//   (HTTP 400): `generationConfig.responseJsonSchema` (JSON Schema) →
//   `responseSchema` (OpenAPI subset: no `additionalProperties`, nullable
//   via `nullable`) → plain JSON mode (`responseMimeType` only, schema in the
//   system instruction) parsed tolerantly by the caller. The dialect that
//   worked is remembered for later requests of the same client.
// * `finishReason` (MAX_TOKENS, SAFETY, RECITATION, …) and
//   `promptFeedback.blockReason` become Arabic errors; `CONTINUATION`
//   continues with the returned token.
// * Free tier limits can be very low (a few requests per minute, a few
//   dozen per day). A 429 is never hammered: the per-minute limit is waited
//   out once when Google's `RetryInfo.retryDelay` is short; a daily quota or
//   a long delay fails immediately with a clear Arabic message, and the
//   [GeminiRateGate] keeps later requests from even being sent while the
//   block lasts.
// * `GET /v1beta/models` discovers the models of the key; when the
//   configured model does not exist (404), [GeminiMinutesBackend] switches
//   to the newest Flash model ([pickPreferredGeminiModel]) once.
//
// Privacy: on the free (unpaid) tier Google may use prompts and responses to
// improve its products and human reviewers may read them; a key of a billed
// Cloud project is treated as paid. Settings and the consent sheet say so
// before the first use (see docs/PRIVACY.md).

import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/errors.dart';
import 'claude_client.dart' show RetryDelay, SseParser, parseRetryAfter;
import 'minutes_backend.dart';

/// Default Gemini model: Google's alias of the newest Flash model.
const String kDefaultGeminiModel = 'gemini-flash-latest';

/// REST base of the Gemini API.
final Uri kGeminiApiBase = Uri.parse(
  'https://generativelanguage.googleapis.com/v1beta/',
);

/// Where users create a free Gemini API key.
const String kGeminiApiKeyUrl = 'https://aistudio.google.com/apikey';

/// How the answer format is constrained (see the file comment).
enum GeminiSchemaMode {
  /// `responseJsonSchema` (JSON Schema).
  jsonSchema,

  /// `responseSchema` (OpenAPI subset).
  openApiSchema,

  /// `responseMimeType: application/json` only, schema in the prompt.
  jsonPrompt,
}

/// Coarse request phases.
enum GeminiPhase {
  /// Sending / waiting for the first chunk.
  connecting,

  /// Thought parts are streaming.
  thinking,

  /// Answer text is streaming.
  writing,

  /// A transient failure; waiting before the next attempt.
  retrying,

  /// Rate limited; waiting the delay Google asked for.
  waitingForQuota,
}

/// Token usage reported in `usageMetadata`.
class GeminiUsage {
  /// Creates a usage record.
  const GeminiUsage({
    this.promptTokens = 0,
    this.candidatesTokens = 0,
    this.thoughtsTokens = 0,
  });

  /// `promptTokenCount`.
  final int promptTokens;

  /// `candidatesTokenCount`.
  final int candidatesTokens;

  /// `thoughtsTokenCount`.
  final int thoughtsTokens;

  /// Copy updated from a `usageMetadata` object (later chunks carry the
  /// cumulative counts).
  GeminiUsage merge(Object? json) {
    if (json is! Map) return this;
    int pick(String k, int cur) {
      final v = json[k];
      return v is num ? v.toInt() : cur;
    }

    return GeminiUsage(
      promptTokens: pick('promptTokenCount', promptTokens),
      candidatesTokens: pick('candidatesTokenCount', candidatesTokens),
      thoughtsTokens: pick('thoughtsTokenCount', thoughtsTokens),
    );
  }
}

/// A successful [GeminiClient.generateStructured] call.
class GeminiResult {
  /// Creates a result.
  const GeminiResult({
    required this.text,
    required this.model,
    required this.finishReason,
    required this.schemaMode,
    this.usage = const GeminiUsage(),
  });

  /// The answer text (JSON; in [GeminiSchemaMode.jsonPrompt] possibly with
  /// noise, parse tolerantly).
  final String text;

  /// `modelVersion` reported by the API, or the requested model.
  final String model;

  /// Final `finishReason` (`STOP`).
  final String finishReason;

  /// Dialect that was accepted.
  final GeminiSchemaMode schemaMode;

  /// Token usage.
  final GeminiUsage usage;
}

/// A model listed by `GET /v1beta/models`.
class GeminiModelInfo {
  /// Creates an entry.
  const GeminiModelInfo({
    required this.id,
    this.displayName = '',
    this.methods = const [],
    this.inputTokenLimit,
    this.outputTokenLimit,
    this.thinking = false,
  });

  /// Parses one `Model` object; null without a usable name.
  static GeminiModelInfo? tryParse(Object? j) {
    if (j is! Map) return null;
    var name = j['name'];
    if (name is! String || name.trim().isEmpty) return null;
    name = name.trim();
    if (name.startsWith('models/')) name = name.substring('models/'.length);
    final methods = j['supportedGenerationMethods'];
    int? n(Object? v) => v is num ? v.toInt() : null;
    return GeminiModelInfo(
      id: name,
      displayName: j['displayName'] is String ? j['displayName'] as String : '',
      methods: methods is List
          ? methods.whereType<String>().toList(growable: false)
          : const [],
      inputTokenLimit: n(j['inputTokenLimit']),
      outputTokenLimit: n(j['outputTokenLimit']),
      thinking: j['thinking'] == true,
    );
  }

  /// Model id without the `models/` prefix, e.g. `gemini-2.5-flash`.
  final String id;

  /// Human-readable name.
  final String displayName;

  /// `supportedGenerationMethods`.
  final List<String> methods;

  /// Maximum input tokens.
  final int? inputTokenLimit;

  /// Maximum output tokens.
  final int? outputTokenLimit;

  /// Whether the model thinks.
  final bool thinking;

  /// True when it supports `generateContent`.
  bool get canGenerate => methods.contains('generateContent');
}

final RegExp _flashVersion = RegExp(r'^gemini-(\d+(?:\.\d+)?)-flash(.*)$');
const List<String> _excludedFlashParts = [
  'image',
  'tts',
  'audio',
  'live',
  'embedding',
  'thinking-exp',
  'native',
  'computer',
  'robotics',
];

/// Chooses the best text Flash model of [models] for minutes: supports
/// `generateContent`, is a plain text Flash model (no image / audio / TTS /
/// live variants), newest version first; at equal version a stable model
/// beats a preview / experimental one and the full Flash beats Flash-Lite.
/// Returns null when none qualifies.
String? pickPreferredGeminiModel(Iterable<GeminiModelInfo> models) {
  ({double version, int stability, int lite, String id})? best;
  for (final m in models) {
    if (!m.canGenerate) continue;
    final match = _flashVersion.firstMatch(m.id.toLowerCase());
    if (match == null) continue;
    final rest = match.group(2)!;
    if (_excludedFlashParts.any(rest.contains)) continue;
    final version = double.tryParse(match.group(1)!) ?? 0;
    final preview = rest.contains('preview') || rest.contains('exp');
    final dated = RegExp(r'-\d{2}-\d{2,4}').hasMatch(rest) ||
        RegExp(r'-\d{3}$').hasMatch(rest);
    final stability = preview ? 0 : (dated ? 1 : 2);
    final lite = rest.contains('lite') ? 0 : 1;
    final cand = (version: version, stability: stability, lite: lite, id: m.id);
    if (best == null ||
        cand.version > best.version ||
        (cand.version == best.version &&
            (cand.stability > best.stability ||
                (cand.stability == best.stability &&
                    (cand.lite > best.lite ||
                        (cand.lite == best.lite &&
                            cand.id.length < best.id.length)))))) {
      best = cand;
    }
  }
  return best?.id;
}

/// Converts a strict JSON schema (as produced by `minutesJsonSchema`) to
/// Gemini's `responseSchema` OpenAPI subset: removes
/// `additionalProperties`, turns `"type": ["string", "null"]` into
/// `"type": "string", "nullable": true`, and adds `propertyOrdering` so the
/// answer keeps the schema's key order.
Map<String, dynamic> toGeminiOpenApiSchema(Map<String, dynamic> schema) {
  Object? convert(Object? node) {
    if (node is List) return node.map(convert).toList();
    if (node is! Map) return node;
    final out = <String, dynamic>{};
    node.forEach((k, v) {
      final key = k as String;
      if (key == 'additionalProperties' || key == r'$schema') return;
      if (key == 'type' && v is List) {
        final types = v.whereType<String>().where((t) => t != 'null').toList();
        out['type'] = types.isEmpty ? 'string' : types.first;
        if (v.contains('null')) out['nullable'] = true;
        return;
      }
      out[key] = convert(v);
    });
    final props = out['properties'];
    if (props is Map && props.isNotEmpty) {
      out['propertyOrdering'] = props.keys.toList();
    }
    return out;
  }

  return (convert(schema) as Map).cast<String, dynamic>();
}

/// Parses a Google `Duration` string such as `37s`, `1.5s` or `250ms`.
Duration? parseGoogleDuration(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(ms|s)\s*$').firstMatch(v);
  if (m == null) return null;
  final n = double.parse(m.group(1)!);
  final ms = m.group(2) == 'ms' ? n : n * 1000;
  return Duration(milliseconds: ms.round());
}

/// A parsed Google API error body (`{"error": {code, message, status,
/// details}}`).
class GeminiApiError {
  /// Creates an error.
  const GeminiApiError({
    this.code,
    this.status,
    this.message,
    this.reasons = const [],
    this.retryDelay,
    this.quotaIds = const [],
  });

  /// Parses [raw] (any text); missing fields stay null / empty.
  factory GeminiApiError.parse(String raw) {
    try {
      final d = jsonDecode(raw);
      final e = d is Map ? d['error'] : (d is List && d.isNotEmpty ? d.first : null);
      final err = e is Map && e['error'] is Map ? e['error'] as Map : e;
      if (err is! Map) return const GeminiApiError();
      final reasons = <String>[];
      final quotaIds = <String>[];
      Duration? delay;
      final details = err['details'];
      if (details is List) {
        for (final det in details.whereType<Map>()) {
          final type = det['@type'];
          if (type is! String) continue;
          if (type.endsWith('ErrorInfo') && det['reason'] is String) {
            reasons.add(det['reason'] as String);
          } else if (type.endsWith('RetryInfo')) {
            delay = parseGoogleDuration(det['retryDelay']) ?? delay;
          } else if (type.endsWith('QuotaFailure')) {
            final violations = det['violations'];
            if (violations is List) {
              for (final v in violations.whereType<Map>()) {
                for (final k in const ['quotaId', 'quotaMetric']) {
                  if (v[k] is String) quotaIds.add(v[k] as String);
                }
              }
            }
          }
        }
      }
      return GeminiApiError(
        code: err['code'] is num ? (err['code'] as num).toInt() : null,
        status: err['status'] is String ? err['status'] as String : null,
        message: err['message'] is String ? err['message'] as String : null,
        reasons: reasons,
        retryDelay: delay,
        quotaIds: quotaIds,
      );
    } on FormatException {
      return const GeminiApiError();
    }
  }

  /// HTTP-like code.
  final int? code;

  /// gRPC status name (`RESOURCE_EXHAUSTED`, …).
  final String? status;

  /// Developer message (English).
  final String? message;

  /// `ErrorInfo.reason` values (`API_KEY_INVALID`, …).
  final List<String> reasons;

  /// `RetryInfo.retryDelay`.
  final Duration? retryDelay;

  /// `QuotaFailure` quota ids / metrics.
  final List<String> quotaIds;

  /// True when the key itself is invalid / expired.
  bool get isInvalidKey =>
      reasons.any((r) => r.startsWith('API_KEY_')) ||
      (message ?? '').toLowerCase().contains('api key not valid') ||
      (message ?? '').toLowerCase().contains('api key expired');

  /// True when the request is refused for the user's location / billing
  /// requirements rather than its content.
  bool get isUnavailableHere {
    final m = (message ?? '').toLowerCase();
    return status == 'FAILED_PRECONDITION' ||
        m.contains('location is not supported') ||
        m.contains('not available in your country') ||
        m.contains('enable billing');
  }

  /// True when a daily quota (requests per day) is exhausted.
  bool get isDailyQuota =>
      quotaIds.any((q) {
        final l = q.toLowerCase();
        return l.contains('perday') || l.contains('per_day');
      });
}

/// Delivered when the configured model does not exist for the key (HTTP
/// 404); [GeminiMinutesBackend] then discovers another model.
class GeminiModelNotFoundException extends MinutesGenerationException {
  /// Creates the exception.
  const GeminiModelNotFoundException(
    super.messageAr, {
    required this.model,
    super.debugDetails,
  });

  /// The missing model.
  final String model;
}

/// The free-tier quota was reached.
class GeminiQuotaExceededException extends MinutesGenerationException {
  /// Creates the exception.
  const GeminiQuotaExceededException(
    super.messageAr, {
    required this.daily,
    this.retryAfter,
    super.debugDetails,
  }) : super(retryable: !daily);

  /// True when the daily quota is exhausted (retry tomorrow).
  final bool daily;

  /// How long Google asked to wait, when known.
  final Duration? retryAfter;
}

/// Remembers rate-limit blocks per API key so that a refused request is not
/// repeated while the block lasts ("never hammer"). One gate per process
/// ([GeminiRateGate.shared]); tests inject their own.
class GeminiRateGate {
  /// Creates a gate; [clock] is injectable for tests.
  GeminiRateGate({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// The process-wide gate.
  static final GeminiRateGate shared = GeminiRateGate();

  final DateTime Function() _clock;
  final Map<int, ({DateTime until, bool daily})> _blocks = {};

  /// How long a daily-quota refusal blocks further requests of the key.
  static const Duration dailyBlock = Duration(minutes: 30);

  /// Records a block of [apiKey] for [duration].
  void block(String apiKey, Duration duration, {bool daily = false}) {
    _blocks[apiKey.hashCode] = (until: _clock().add(duration), daily: daily);
  }

  /// The remaining block of [apiKey], or null when requests may be sent.
  ({Duration remaining, bool daily})? blockOf(String apiKey) {
    final b = _blocks[apiKey.hashCode];
    if (b == null) return null;
    final remaining = b.until.difference(_clock());
    if (remaining <= Duration.zero) {
      _blocks.remove(apiKey.hashCode);
      return null;
    }
    return (remaining: remaining, daily: b.daily);
  }

  /// Forgets every block (e.g. after the user changed the key).
  void clear() => _blocks.clear();
}

class _Retry implements Exception {
  _Retry(this.details, {this.wait, this.quota = false, this.cause});
  final String details;
  final Duration? wait;
  final bool quota;
  final Object? cause;
}

class _SchemaRejected implements Exception {
  _SchemaRejected(this.details);
  final String details;
}

/// Arabic text of a whole number of seconds (rounded up, at least 1).
String _secondsAr(Duration d) {
  final s = math.max(1, (d.inMilliseconds / 1000).ceil());
  return '$s ثانية';
}

/// Minimal, robust client for the Gemini `generateContent` API with
/// structured output (see the file comment).
class GeminiClient {
  /// Creates a client.
  ///
  /// * [client] — injected HTTP client (tests); otherwise an owned one is
  ///   created and closed by [close].
  /// * [model] — model id (a leading `models/` is accepted).
  /// * [stream] — use `streamGenerateContent?alt=sse` (default) for
  ///   progress; false uses `generateContent`.
  /// * [maxAttempts] — total attempts for transient failures (default 3).
  /// * [maxQuotaWait] — longest per-minute rate-limit delay waited out
  ///   automatically (default 65 s); longer ones fail at once.
  /// * [maxOutputTokens] — `generationConfig.maxOutputTokens` (null = the
  ///   model's default, which for Flash models is its maximum).
  GeminiClient({
    required String apiKey,
    http.Client? client,
    String model = kDefaultGeminiModel,
    Uri? baseUri,
    this.stream = true,
    this.maxAttempts = 3,
    this.idleTimeout = const Duration(minutes: 5),
    this.baseRetryDelay = const Duration(seconds: 3),
    this.maxRetryDelay = const Duration(seconds: 60),
    this.maxQuotaWait = const Duration(seconds: 65),
    this.maxContinuations = 3,
    this.maxOutputTokens,
    GeminiRateGate? gate,
    RetryDelay? delay,
    math.Random? random,
  }) : _apiKey = apiKey.trim(),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       model = model.trim().startsWith('models/')
           ? model.trim().substring('models/'.length)
           : model.trim(),
       baseUri = baseUri ?? kGeminiApiBase,
       _gate = gate ?? GeminiRateGate.shared,
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? math.Random();

  final String _apiKey;
  final http.Client _client;
  final bool _ownsClient;
  final GeminiRateGate _gate;
  final RetryDelay _delay;
  final math.Random _random;

  /// Model id sent in every request.
  final String model;

  /// REST base (`…/v1beta/`).
  final Uri baseUri;

  /// Whether responses are streamed (SSE).
  final bool stream;

  /// Total attempts for transient failures.
  final int maxAttempts;

  /// Maximum silence on the connection.
  final Duration idleTimeout;

  /// First backoff step (doubled each retry, with jitter).
  final Duration baseRetryDelay;

  /// Upper bound of a backoff wait.
  final Duration maxRetryDelay;

  /// Longest rate-limit delay waited out automatically.
  final Duration maxQuotaWait;

  /// Continuations followed for `finishReason: CONTINUATION`.
  final int maxContinuations;

  /// `generationConfig.maxOutputTokens`, or null.
  final int? maxOutputTokens;

  GeminiSchemaMode _mode = GeminiSchemaMode.jsonSchema;

  /// Dialect used by the next request (the last one that worked).
  GeminiSchemaMode get schemaMode => _mode;

  /// A client for [newModel] sharing this client's HTTP client, gate and
  /// settings. The returned client never closes the shared HTTP client.
  GeminiClient withModel(String newModel) => GeminiClient(
    apiKey: _apiKey,
    client: _client,
    model: newModel,
    baseUri: baseUri,
    stream: stream,
    maxAttempts: maxAttempts,
    idleTimeout: idleTimeout,
    baseRetryDelay: baseRetryDelay,
    maxRetryDelay: maxRetryDelay,
    maxQuotaWait: maxQuotaWait,
    maxContinuations: maxContinuations,
    maxOutputTokens: maxOutputTokens,
    gate: _gate,
    delay: _delay,
    random: _random,
  ).._mode = _mode;

  Uri _endpoint() {
    final method = stream ? 'streamGenerateContent' : 'generateContent';
    final uri = baseUri.resolve('models/$model:$method');
    return stream ? uri.replace(queryParameters: {'alt': 'sse'}) : uri;
  }

  /// Builds the request body for [mode]. Exposed for tests.
  Map<String, dynamic> buildRequestBody({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
    GeminiSchemaMode mode = GeminiSchemaMode.jsonSchema,
    String? continuationToken,
  }) {
    final config = <String, dynamic>{
      'responseMimeType': 'application/json',
      if (mode == GeminiSchemaMode.jsonSchema) 'responseJsonSchema': schema,
      if (mode == GeminiSchemaMode.openApiSchema)
        'responseSchema': toGeminiOpenApiSchema(schema),
      'maxOutputTokens': ?maxOutputTokens,
    };
    final systemText = mode == GeminiSchemaMode.jsonPrompt
        ? '$system\n\n# Output format\nReturn only one JSON object (no '
              'Markdown, no text before or after it) that conforms to this '
              'JSON Schema; every listed property must be present:\n'
              '${jsonEncode(schema)}'
        : system;
    return {
      'systemInstruction': {
        'parts': [
          {'text': systemText},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': user},
          ],
        },
      ],
      'generationConfig': config,
      'continuationToken': ?continuationToken,
    };
  }

  void _checkKey() {
    if (_apiKey.isEmpty) {
      throw const MissingApiKeyException(
        'لم يُضبط مفتاح Gemini API بعد. أنشئ مفتاحاً مجانياً من Google AI '
        'Studio وأدخله في الإعدادات ثم أعد المحاولة.',
      );
    }
  }

  void _checkGate() {
    final b = _gate.blockOf(_apiKey);
    if (b == null) return;
    if (b.daily) {
      throw const GeminiQuotaExceededException(
        'استُنفدت الحصة المجانية اليومية لخدمة Gemini. أعد المحاولة غداً، أو '
        'اختر محركاً آخر للمحضر من الإعدادات.',
        daily: true,
        debugDetails: 'blocked locally after a daily-quota 429',
      );
    }
    throw GeminiQuotaExceededException(
      'بلغت حدّ الطلبات المجاني لخدمة Gemini مؤقتاً. حاول مجدداً بعد '
      '${_secondsAr(b.remaining)}.',
      daily: false,
      retryAfter: b.remaining,
      debugDetails: 'blocked locally after a 429',
    );
  }

  /// Sends one structured-output request and returns the answer.
  ///
  /// [onDelta] receives the cumulative number of answer characters (resets
  /// on a retry); [onPhase] reports phases with the 1-based attempt and,
  /// for waits, their duration.
  ///
  /// Throws [MissingApiKeyException] (missing / invalid key),
  /// [GeminiQuotaExceededException] (rate limit / daily quota),
  /// [GeminiModelNotFoundException] (unknown model) or
  /// [MinutesGenerationException].
  Future<GeminiResult> generateStructured({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
    void Function(int receivedChars)? onDelta,
    void Function(GeminiPhase phase, int attempt, Duration? wait)? onPhase,
  }) async {
    _checkKey();
    _checkGate();

    _Retry? last;
    var attempt = 1;
    while (true) {
      try {
        onPhase?.call(GeminiPhase.connecting, attempt, null);
        final r = await _withContinuations(
          system,
          user,
          schema,
          onDelta,
          (p) => onPhase?.call(p, attempt, null),
        );
        return r;
      } on _SchemaRejected catch (e) {
        final next = _mode.index + 1;
        if (next >= GeminiSchemaMode.values.length) {
          throw MinutesGenerationException(
            'رفضت خدمة Gemini صيغة الطلب. جرّب نموذجاً آخر من الإعدادات.',
            debugDetails: e.details,
          );
        }
        _mode = GeminiSchemaMode.values[next];
        // A dialect switch is not a failed attempt: retry immediately.
      } on _Retry catch (f) {
        last = f;
        if (attempt >= maxAttempts) break;
        final wait = f.wait ?? _backoff(attempt);
        onPhase?.call(
          f.quota ? GeminiPhase.waitingForQuota : GeminiPhase.retrying,
          attempt,
          wait,
        );
        await _delay(wait);
        attempt++;
      }
    }
    final failure = last;
    if (failure.quota) {
      throw GeminiQuotaExceededException(
        'بلغت حدّ الطلبات المجاني لخدمة Gemini (عدد محدود من الطلبات في '
        'الدقيقة). انتظر دقيقة ثم أعد المحاولة.',
        daily: false,
        retryAfter: failure.wait,
        debugDetails: failure.details,
      );
    }
    throw MinutesGenerationException(
      'تعذّر الاتصال بخدمة Gemini بعد عدة محاولات (الخدمة مشغولة أو الاتصال '
      'غير مستقر). حاول مرة أخرى بعد قليل.',
      debugDetails: failure.details,
      cause: failure.cause,
      retryable: true,
    );
  }

  Duration _backoff(int attempt) {
    final exp = baseRetryDelay.inMilliseconds * math.pow(2, attempt - 1);
    final capped = math.min(exp.toDouble(), maxRetryDelay.inMilliseconds * 1.0);
    final jittered = capped * (0.5 + 0.5 * _random.nextDouble());
    return Duration(milliseconds: jittered.round());
  }

  Future<GeminiResult> _withContinuations(
    String system,
    String user,
    Map<String, dynamic> schema,
    void Function(int)? onDelta,
    void Function(GeminiPhase) phase,
  ) async {
    final text = StringBuffer();
    String? token;
    var usage = const GeminiUsage();
    for (var i = 0; ; i++) {
      final body = jsonEncode(
        buildRequestBody(
          system: system,
          user: user,
          schema: schema,
          mode: _mode,
          continuationToken: token,
        ),
      );
      final base = text.length;
      final part = await _attempt(
        body,
        onDelta == null ? null : (n) => onDelta(base + n),
        phase,
      );
      text.write(part.text);
      usage = part.usage;
      if (part.finishReason == 'CONTINUATION' &&
          part.continuationToken != null &&
          i < maxContinuations) {
        token = part.continuationToken;
        continue;
      }
      if (part.finishReason == 'CONTINUATION') {
        throw const MinutesGenerationException(
          'توقف النموذج قبل إكمال المحضر لأن الناتج تجاوز الحد الأقصى للطول.',
          debugDetails: 'finishReason=CONTINUATION without token / limit',
        );
      }
      if (text.toString().trim().isEmpty) {
        throw _Retry('empty answer (finishReason=${part.finishReason})');
      }
      return GeminiResult(
        text: text.toString(),
        model: part.modelVersion ?? model,
        finishReason: part.finishReason,
        schemaMode: _mode,
        usage: usage,
      );
    }
  }

  Future<_Part> _attempt(
    String body,
    void Function(int)? onDelta,
    void Function(GeminiPhase) phase,
  ) async {
    final abort = Completer<void>();
    void abortRequest() {
      if (!abort.isCompleted) abort.complete();
    }

    final request =
        http.AbortableRequest('POST', _endpoint(), abortTrigger: abort.future)
          ..headers.addAll({
            'content-type': 'application/json',
            'accept': stream ? 'text/event-stream' : 'application/json',
            'x-goog-api-key': _apiKey,
          })
          ..body = body;

    final sendFuture = _client.send(request);
    http.StreamedResponse response;
    try {
      response = await sendFuture.timeout(idleTimeout);
    } on TimeoutException catch (e) {
      abortRequest();
      unawaited(
        sendFuture.then(
          (r) => r.stream.listen(null).cancel(),
          onError: (Object _) {},
        ),
      );
      throw _Retry('timeout waiting for response headers', cause: e);
    } on http.ClientException catch (e) {
      throw _Retry('network error: ${e.message}', cause: e);
    } on IOException catch (e) {
      throw _Retry('network/TLS error (${e.runtimeType}): $e', cause: e);
    }

    try {
      if (response.statusCode != 200) await _handleHttpError(response);
      return stream
          ? await _consumeSse(response, onDelta, phase)
          : await _consumeJson(response, onDelta, phase);
    } finally {
      abortRequest();
    }
  }

  Future<Never> _handleHttpError(http.StreamedResponse response) async {
    String raw;
    try {
      raw = await response.stream.bytesToString().timeout(idleTimeout);
    } catch (_) {
      raw = '';
    }
    final status = response.statusCode;
    final err = GeminiApiError.parse(raw);
    final details =
        'HTTP $status ${err.status ?? ''} ${err.reasons.join(',')}: '
        '${err.message ?? raw}';

    if (err.isInvalidKey || status == 401) {
      throw MissingApiKeyException(
        'مفتاح Gemini API غير صالح أو منتهي الصلاحية. تحقّق من المفتاح في '
        'الإعدادات (يمكن إنشاء مفتاح مجاني من Google AI Studio).',
        debugDetails: details,
      );
    }
    if (status == 403) {
      throw MissingApiKeyException(
        'مفتاح Gemini API لا يملك صلاحية استخدام هذه الخدمة (قد تكون واجهة '
        'Gemini غير مفعّلة لمشروع المفتاح أو أن المفتاح مقيّد). تحقّق من '
        'المفتاح في Google AI Studio.',
        debugDetails: details,
      );
    }
    if (status == 429) {
      final headerDelay = parseRetryAfter(response.headers['retry-after']);
      final wait = err.retryDelay ?? headerDelay;
      if (err.isDailyQuota) {
        _gate.block(_apiKey, GeminiRateGate.dailyBlock, daily: true);
        throw GeminiQuotaExceededException(
          'استُنفدت الحصة المجانية اليومية لخدمة Gemini. أعد المحاولة غداً، '
          'أو اختر محركاً آخر للمحضر من الإعدادات.',
          daily: true,
          retryAfter: wait,
          debugDetails: details,
        );
      }
      final effective = wait ?? const Duration(seconds: 30);
      if (effective > maxQuotaWait) {
        _gate.block(_apiKey, effective);
        throw GeminiQuotaExceededException(
          'بلغت حدّ الطلبات المجاني لخدمة Gemini مؤقتاً. حاول مجدداً بعد '
          '${_secondsAr(effective)}.',
          daily: false,
          retryAfter: effective,
          debugDetails: details,
        );
      }
      throw _Retry(
        details,
        wait: effective + Duration(milliseconds: _random.nextInt(500)),
        quota: true,
      );
    }
    if (status == 404) {
      throw GeminiModelNotFoundException(
        'نموذج Gemini المحدد ($model) غير متاح لهذا المفتاح.',
        model: model,
        debugDetails: details,
      );
    }
    if (status == 400 || status == 422) {
      if (err.isUnavailableHere) {
        throw MinutesGenerationException(
          'خدمة Gemini المجانية غير متاحة لهذا الحساب أو في هذه المنطقة. '
          'اختر محركاً آخر للمحضر من الإعدادات.',
          debugDetails: details,
        );
      }
      final m = (err.message ?? '').toLowerCase();
      final tooLong =
          m.contains('token count') ||
          m.contains('exceeds the maximum') ||
          m.contains('too long');
      if (tooLong) {
        throw MinutesGenerationException(
          'نص الاجتماع أطول من الحد الذي يقبله نموذج Gemini في طلب واحد.',
          debugDetails: details,
        );
      }
      throw _SchemaRejected(details);
    }
    if (status == 408 || status == 409 || status >= 500) {
      throw _Retry(details, wait: parseRetryAfter(response.headers['retry-after']));
    }
    throw MinutesGenerationException(
      'رفضت خدمة Gemini الطلب. ${err.message ?? ''}'.trim(),
      debugDetails: details,
    );
  }

  Future<_Part> _consumeJson(
    http.StreamedResponse response,
    void Function(int)? onDelta,
    void Function(GeminiPhase) phase,
  ) async {
    String raw;
    try {
      raw = await response.stream.bytesToString().timeout(idleTimeout);
    } on TimeoutException catch (e) {
      throw _Retry('body timeout', cause: e);
    } on http.ClientException catch (e) {
      throw _Retry('network error mid-body: ${e.message}', cause: e);
    } on IOException catch (e) {
      throw _Retry('network/TLS error mid-body: $e', cause: e);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw _Retry('invalid JSON body');
    }
    final acc = _Accumulator(onDelta, phase);
    acc.add(decoded);
    return acc.finish(requireFinish: false);
  }

  Future<_Part> _consumeSse(
    http.StreamedResponse response,
    void Function(int)? onDelta,
    void Function(GeminiPhase) phase,
  ) async {
    final acc = _Accumulator(onDelta, phase);
    try {
      final events = SseParser.parseByteStream(
        response.stream.timeout(idleTimeout),
      );
      await for (final event in events) {
        if (event.data.isEmpty) continue;
        Object? decoded;
        try {
          decoded = jsonDecode(event.data);
        } on FormatException {
          continue;
        }
        acc.add(decoded);
      }
    } on TimeoutException catch (e) {
      throw _Retry('stream idle timeout', cause: e);
    } on http.ClientException catch (e) {
      throw _Retry('network error mid-stream: ${e.message}', cause: e);
    } on IOException catch (e) {
      throw _Retry('network/TLS error mid-stream: $e', cause: e);
    } on FormatException catch (e) {
      throw _Retry('invalid UTF-8 in stream: ${e.message}', cause: e);
    }
    return acc.finish(requireFinish: true);
  }

  /// Lists the models available to the key (all pages).
  Future<List<GeminiModelInfo>> listModels() async {
    _checkKey();
    final out = <GeminiModelInfo>[];
    String? pageToken;
    for (var page = 0; page < 10; page++) {
      final uri = baseUri
          .resolve('models')
          .replace(
            queryParameters: {
              'pageSize': '1000',
              'pageToken': ?pageToken,
            },
          );
      http.Response r;
      try {
        r = await _client
            .get(uri, headers: {'x-goog-api-key': _apiKey})
            .timeout(const Duration(seconds: 30));
      } on TimeoutException catch (e) {
        throw MinutesGenerationException(
          'تعذّر الاتصال بخدمة Gemini.',
          debugDetails: 'models.list timeout',
          cause: e,
          retryable: true,
        );
      } on http.ClientException catch (e) {
        throw MinutesGenerationException(
          'تعذّر الاتصال بخدمة Gemini. تحقّق من الاتصال بالإنترنت.',
          debugDetails: 'models.list: ${e.message}',
          cause: e,
          retryable: true,
        );
      } on IOException catch (e) {
        throw MinutesGenerationException(
          'تعذّر الاتصال بخدمة Gemini. تحقّق من الاتصال بالإنترنت.',
          debugDetails: 'models.list: $e',
          cause: e,
          retryable: true,
        );
      }
      if (r.statusCode != 200) {
        final err = GeminiApiError.parse(r.body);
        if (err.isInvalidKey || r.statusCode == 401 || r.statusCode == 403) {
          throw MissingApiKeyException(
            'مفتاح Gemini API غير صالح أو لا يملك صلاحية. تحقّق من المفتاح في '
            'الإعدادات.',
            debugDetails: 'models.list HTTP ${r.statusCode}: ${err.message}',
          );
        }
        throw MinutesGenerationException(
          'تعذّر جلب قائمة نماذج Gemini.',
          debugDetails: 'models.list HTTP ${r.statusCode}: ${err.message}',
          retryable: r.statusCode == 429 || r.statusCode >= 500,
        );
      }
      Object? d;
      try {
        d = jsonDecode(r.body);
      } on FormatException {
        d = null;
      }
      if (d is! Map) break;
      final models = d['models'];
      if (models is List) {
        for (final m in models) {
          final info = GeminiModelInfo.tryParse(m);
          if (info != null) out.add(info);
        }
      }
      final next = d['nextPageToken'];
      if (next is! String || next.isEmpty) break;
      pageToken = next;
    }
    return out;
  }

  /// Closes the HTTP client if this instance created it.
  void close() {
    if (_ownsClient) _client.close();
  }
}

class _Part {
  _Part({
    required this.text,
    required this.finishReason,
    this.modelVersion,
    this.continuationToken,
    this.usage = const GeminiUsage(),
  });
  final String text;
  final String finishReason;
  final String? modelVersion;
  final String? continuationToken;
  final GeminiUsage usage;
}

/// Accumulates `GenerateContentResponse` chunks.
class _Accumulator {
  _Accumulator(this.onDelta, this.phase);
  final void Function(int)? onDelta;
  final void Function(GeminiPhase) phase;
  final StringBuffer text = StringBuffer();
  String? finishReason;
  String? finishMessage;
  String? modelVersion;
  String? continuationToken;
  String? blockReason;
  GeminiUsage usage = const GeminiUsage();
  GeminiPhase _last = GeminiPhase.connecting;

  void _setPhase(GeminiPhase p) {
    if (p != _last) {
      _last = p;
      phase(p);
    }
  }

  void add(Object? chunk) {
    if (chunk is List) {
      for (final c in chunk) {
        add(c);
      }
      return;
    }
    if (chunk is! Map) return;
    final error = chunk['error'];
    if (error is Map) {
      final err = GeminiApiError.parse(jsonEncode({'error': error}));
      final code = err.code ?? 0;
      final details = 'stream error $code ${err.status}: ${err.message}';
      if (code == 429 || code >= 500 || err.status == 'UNAVAILABLE') {
        throw _Retry(details, wait: err.retryDelay, quota: code == 429);
      }
      throw MinutesGenerationException(
        'حدث خطأ أثناء توليد المحضر في خدمة Gemini. ${err.message ?? ''}'
            .trim(),
        debugDetails: details,
      );
    }
    if (chunk['modelVersion'] is String) {
      modelVersion = chunk['modelVersion'] as String;
    }
    usage = usage.merge(chunk['usageMetadata']);
    final feedback = chunk['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] is String) {
      blockReason = feedback['blockReason'] as String;
    }
    final candidates = chunk['candidates'];
    if (candidates is! List || candidates.isEmpty) return;
    final c = candidates.first;
    if (c is! Map) return;
    final content = c['content'];
    if (content is Map && content['parts'] is List) {
      for (final p in (content['parts'] as List).whereType<Map>()) {
        final t = p['text'];
        if (t is! String || t.isEmpty) continue;
        if (p['thought'] == true) {
          _setPhase(GeminiPhase.thinking);
          continue;
        }
        _setPhase(GeminiPhase.writing);
        text.write(t);
        onDelta?.call(text.length);
      }
    }
    if (c['finishReason'] is String) {
      finishReason = c['finishReason'] as String;
      if (c['finishMessage'] is String) {
        finishMessage = c['finishMessage'] as String;
      }
    }
    if (c['continuationToken'] is String) {
      continuationToken = c['continuationToken'] as String;
    }
  }

  _Part finish({required bool requireFinish}) {
    final block = blockReason;
    if (block != null && block != 'BLOCK_REASON_UNSPECIFIED') {
      throw MinutesGenerationException(
        'رفضت مرشّحات الأمان في Gemini معالجة نص هذا الاجتماع ($block). '
        'جرّب محركاً آخر للمحضر.',
        debugDetails: 'promptFeedback.blockReason=$block',
      );
    }
    final reason = finishReason;
    if (reason == null) {
      if (requireFinish || text.isEmpty) {
        throw _Retry('stream ended without finishReason (${text.length} chars)');
      }
      return _Part(
        text: text.toString(),
        finishReason: 'STOP',
        modelVersion: modelVersion,
        usage: usage,
      );
    }
    final detail = 'finishReason=$reason ${finishMessage ?? ''}';
    switch (reason) {
      case 'STOP':
      case 'FINISH_REASON_UNSPECIFIED':
      case 'CONTINUATION':
        break;
      case 'MAX_TOKENS':
        throw MinutesGenerationException(
          'توقف النموذج قبل إكمال المحضر لأن الناتج تجاوز الحد الأقصى للطول.',
          debugDetails: detail,
        );
      case 'SAFETY':
      case 'PROHIBITED_CONTENT':
      case 'BLOCKLIST':
      case 'SPII':
        throw MinutesGenerationException(
          'أوقفت مرشّحات الأمان في Gemini كتابة المحضر لهذا المحتوى. جرّب '
          'محركاً آخر للمحضر.',
          debugDetails: detail,
        );
      case 'RECITATION':
        throw MinutesGenerationException(
          'أوقف Gemini الإجابة لأنها تشبه نصاً منشوراً (حماية حقوق النشر). '
          'أعد المحاولة أو جرّب محركاً آخر.',
          debugDetails: detail,
        );
      case 'MALFORMED_RESPONSE':
      case 'OTHER':
        throw _Retry(detail);
      default:
        throw MinutesGenerationException(
          'لم يُكمل Gemini كتابة المحضر ($reason).',
          debugDetails: detail,
        );
    }
    return _Part(
      text: text.toString(),
      finishReason: reason,
      modelVersion: modelVersion,
      continuationToken: continuationToken,
      usage: usage,
    );
  }
}

/// [MinutesBackend] over the Gemini API (the default engine).
class GeminiMinutesBackend implements MinutesBackend {
  /// Wraps [client]. [onModelDiscovered] is called when the configured model
  /// did not exist and another one was chosen (to remember it in
  /// settings).
  GeminiMinutesBackend(GeminiClient client, {this.onModelDiscovered})
    : _root = client,
      _client = client;

  /// The client given to the constructor; owns the HTTP client.
  final GeminiClient _root;
  GeminiClient _client;

  /// Called with the model chosen after a 404.
  final void Function(String model)? onModelDiscovered;

  /// The client in use (tests).
  GeminiClient get client => _client;

  @override
  String get engineId => 'gemini';

  @override
  String get displayName => 'Gemini';

  @override
  bool get sendsDataOffDevice => true;

  @override
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  }) async {
    var discovered = false;
    while (true) {
      try {
        var attempt = 1;
        final r = await _client.generateStructured(
          system: request.system,
          user: request.user,
          schema: request.schema,
          onPhase: (phase, a, wait) {
            attempt = a;
            onProgress?.call(
              MinutesBackendProgress(switch (phase) {
                GeminiPhase.connecting => MinutesBackendPhase.connecting,
                GeminiPhase.thinking => MinutesBackendPhase.thinking,
                GeminiPhase.writing => MinutesBackendPhase.writing,
                GeminiPhase.retrying => MinutesBackendPhase.retrying,
                GeminiPhase.waitingForQuota =>
                  MinutesBackendPhase.waitingForQuota,
              }, attempt: a, wait: wait),
            );
          },
          onDelta: (chars) => onProgress?.call(
            MinutesBackendProgress(
              MinutesBackendPhase.writing,
              attempt: attempt,
              receivedChars: chars,
            ),
          ),
        );
        return MinutesBackendResult(text: r.text, model: r.model);
      } on GeminiModelNotFoundException {
        if (discovered) rethrow;
        discovered = true;
        final models = await _client.listModels();
        final pick = pickPreferredGeminiModel(models);
        if (pick == null || pick == _client.model) rethrow;
        _client = _client.withModel(pick);
        onModelDiscovered?.call(pick);
      }
    }
  }

  @override
  void close() => _root.close();
}
