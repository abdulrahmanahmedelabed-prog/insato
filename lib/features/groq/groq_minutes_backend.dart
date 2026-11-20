// The Groq minutes engine (free plan): Groq's OpenAI-compatible chat API
// through the local-server client of F14 ([LlmServerClient] with an API
// key and the fixed base URL [kGroqApiBase]), behind the same
// [LocalLlmMinutesBackend] as the local engines, so long meetings that do
// not fit the per-minute token limit of the free plan are processed
// map-reduce (chunks → notes → minutes) and invalid JSON gets the same
// tolerant parsing and repair pass.
//
// * Structured output: `response_format: json_schema` for the models that
//   support it on Groq (strict for gpt-oss), otherwise `json_object` with
//   the schema in the system prompt; a `json_validate_failed` refusal hands
//   its `failed_generation` to the repair path.
// * Rate limits: a per-minute 429 is waited out (Retry-After) when short,
//   reported as [MinutesBackendPhase.waitingForQuota]; a daily limit or a
//   long wait fails with a clear Arabic message and blocks further requests
//   in [GroqRateGate]. A request larger than the per-minute token limit
//   teaches the limit and is retried once with a smaller context.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import '../../data/secure_settings.dart';
import '../../minutes/minutes_backend.dart';
import '../local_llm/llm_generator.dart';
import '../local_llm/llm_server_client.dart';
import '../local_llm/local_llm_backend.dart';
import '../local_llm/strings.dart';
import 'groq_api.dart';
import 'strings.dart';

/// Share of a learned per-minute token limit used as the context budget
/// (token counts are estimates).
const double kGroqTokenLimitShare = 0.85;

/// Context assumed when Groq does not report a model's window.
const int kGroqDefaultContext = 8192;

/// [LlmTextGenerator] over a Groq chat model.
class GroqTextGenerator implements LlmTextGenerator {
  GroqTextGenerator._({
    required this._client,
    required this.model,
    required this.apiKey,
    required this.gate,
    required this._contextWindow,
    required this.maxAttempts,
    required this.maxQuotaWait,
    required this._sleep,
  }) : _schemaSupported = groqSupportsJsonSchema(model);

  /// Opens [info] for generation with [apiKey]. [httpClient] is injected
  /// into the API client (tests).
  static GroqTextGenerator open({
    required String apiKey,
    required GroqModelInfo info,
    http.Client? httpClient,
    GroqRateGate? gate,
    String baseUrl = kGroqApiBase,
    int maxAttempts = 4,
    Duration maxQuotaWait = const Duration(seconds: 65),
    Future<void> Function(Duration)? sleep,
  }) {
    final g = gate ?? GroqRateGate.shared;
    final client = LlmServerClient(
      baseUrl: baseUrl,
      client: httpClient,
      apiKey: apiKey,
      connectTimeout: const Duration(seconds: 20),
      firstByteTimeout: const Duration(minutes: 5),
      idleTimeout: const Duration(minutes: 3),
      onResponseHeaders: (h) {
        final limit = int.tryParse(h['x-ratelimit-limit-tokens'] ?? '');
        if (limit != null) g.learnTokenLimit(info.id, limit);
      },
    );
    return GroqTextGenerator._(
      client: client,
      model: info.id,
      apiKey: apiKey,
      gate: g,
      contextWindow: info.contextWindow ?? kGroqDefaultContext,
      maxAttempts: maxAttempts,
      maxQuotaWait: maxQuotaWait,
      sleep: sleep ?? Future<void>.delayed,
    );
  }

  final LlmServerClient _client;

  /// Model id on Groq.
  final String model;

  /// The key (rate gate scope).
  final String apiKey;

  /// Rate gate.
  final GroqRateGate gate;

  /// Total attempts for per-minute 429s and transient failures.
  final int maxAttempts;

  /// Longest per-minute wait taken; longer ones fail with a message.
  final Duration maxQuotaWait;

  final int _contextWindow;
  final Future<void> Function(Duration) _sleep;
  bool _schemaSupported;

  /// Receives per-minute quota waits (set by [GroqMinutesBackend]).
  void Function(Duration wait)? onQuotaWait;

  @override
  String get modelName => 'groq/$model';

  /// Context budget: the model window, or the learned per-minute token
  /// limit when smaller (on the free plan one request must fit in it).
  @override
  int get contextTokens {
    final limit = gate.tokenLimitOf(model);
    if (limit == null) return _contextWindow;
    return math.min(_contextWindow, (limit * kGroqTokenLimitShare).floor());
  }

  @override
  bool get enforcesSchema => _schemaSupported;

  @override
  Future<int> countTokens(String text) async => estimateGroqTokens(text);

  /// Throws the quota exception of an active block of [apiKey] in [gate].
  static void checkGate(GroqRateGate gate, String apiKey) =>
      _checkGate(gate, apiKey);

  static void _checkGate(GroqRateGate gate, String apiKey) {
    final b = gate.blockOf(apiKey);
    if (b == null) return;
    if (b.daily) {
      throw const GroqQuotaExceededException(
        GS.dailyQuota,
        daily: true,
        debugDetails: 'blocked locally after a daily-limit 429',
      );
    }
    throw GroqQuotaExceededException(
      GS.minuteQuota(b.remaining),
      daily: false,
      retryAfter: b.remaining,
      debugDetails: 'blocked locally after a 429',
    );
  }

  @override
  Future<LlmGeneration> generate(
    LlmGenerationRequest request, {
    LlmProgressCallback? onProgress,
  }) async {
    var attempt = 1;
    while (true) {
      _checkGate(gate, apiKey);
      try {
        return await _once(request, onProgress);
      } on LlmServerException catch (e) {
        final status = e.statusCode;
        final limit = status == 429 || status == 413
            ? classifyGroqLimit(status!, e.serverMessage)
            : null;
        Duration? wait;
        if (limit != null && limit.kind == GroqLimitKind.perMinute) {
          wait = e.retryAfter ?? limit.wait ?? _backoff(attempt);
          if (wait > maxQuotaWait) {
            gate.block(apiKey, wait);
            throw GroqQuotaExceededException(
              GS.minuteQuota(wait),
              daily: false,
              retryAfter: wait,
              debugDetails: e.debugDetails,
            );
          }
          if (attempt >= maxAttempts) {
            throw GroqQuotaExceededException(
              GS.minuteQuotaRepeated,
              daily: false,
              retryAfter: wait,
              debugDetails: e.debugDetails,
            );
          }
          onQuotaWait?.call(wait);
        } else if (limit == null &&
            e.retryable &&
            (status == null || status >= 500)) {
          if (attempt >= maxAttempts) {
            throw MinutesGenerationException(
              GS.unavailable,
              debugDetails: e.debugDetails,
              cause: e,
              retryable: true,
            );
          }
          wait = _backoff(attempt);
        } else {
          throw mapGroqError(e, apiKey: apiKey, gate: gate, model: model);
        }
        await _sleep(wait);
        attempt++;
      }
    }
  }

  Duration _backoff(int attempt) =>
      Duration(milliseconds: math.min(30000, 1500 * (1 << (attempt - 1))));

  Future<LlmGeneration> _once(
    LlmGenerationRequest request,
    LlmProgressCallback? onProgress,
  ) async {
    final schema = request.schema;
    final extra = groqExtraBody(model);
    if (schema != null && _schemaSupported) {
      try {
        return await _client.chat(
          model: model,
          request: request,
          numCtx: contextTokens,
          onProgress: onProgress,
          stream: false,
          strictSchema: groqSupportsStrictSchema(model),
          maxCompletionTokensField: true,
          extraBody: extra,
        );
      } on LlmServerSchemaRejected {
        _schemaSupported = false;
      }
    }
    final system =
        schema != null && !request.system.contains('# Output format (strict)')
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
      jsonObjectMode: schema != null,
      onProgress: onProgress,
      stream: false,
      maxCompletionTokensField: true,
      extraBody: extra,
    );
  }

  @override
  Future<void> close() async => _client.close();
}

/// Maps a Groq HTTP failure to an Arabic [InsatoException]; records daily
/// and long blocks in [gate]; learns the per-minute token limit of [model]
/// from "request too large" refusals.
InsatoException mapGroqError(
  LlmServerException e, {
  required String apiKey,
  required GroqRateGate gate,
  String? model,
  String scope = 'chat',
}) {
  final status = e.statusCode;
  if (status == 401 || status == 403) {
    return MissingApiKeyException(GS.keyInvalid, debugDetails: e.debugDetails);
  }
  if (status == 429 || status == 413) {
    final limit = classifyGroqLimit(status!, e.serverMessage);
    switch (limit.kind) {
      case GroqLimitKind.daily:
        gate.block(
          apiKey,
          e.retryAfter ?? limit.wait ?? GroqRateGate.dailyBlock,
          daily: true,
          scope: scope,
        );
        return GroqQuotaExceededException(
          GS.dailyQuota,
          daily: true,
          retryAfter: e.retryAfter ?? limit.wait,
          debugDetails: e.debugDetails,
        );
      case GroqLimitKind.tooLarge:
        final n = limit.limit;
        if (model != null && n != null) gate.learnTokenLimit(model, n);
        return GroqRequestTooLargeException(
          GS.requestTooLarge,
          limit: n,
          debugDetails: e.debugDetails,
        );
      case GroqLimitKind.perMinute:
        final wait = e.retryAfter ?? limit.wait ?? const Duration(minutes: 1);
        return GroqQuotaExceededException(
          GS.minuteQuota(wait),
          daily: false,
          retryAfter: wait,
          debugDetails: e.debugDetails,
        );
    }
  }
  final msg = (e.serverMessage ?? '').toLowerCase();
  if (model != null &&
      (status == 404 ||
          (msg.contains('model') &&
              (msg.contains('not found') ||
                  msg.contains('does not exist') ||
                  msg.contains('decommissioned'))))) {
    return MinutesGenerationException(
      GS.modelMissing(model),
      debugDetails: e.debugDetails,
    );
  }
  if (status == null) {
    return MinutesGenerationException(
      GS.unavailable,
      debugDetails: e.debugDetails,
      cause: e,
      retryable: true,
    );
  }
  return MinutesGenerationException(
    GS.httpError(status, e.serverMessage),
    debugDetails: e.debugDetails,
    retryable: status >= 500,
  );
}

/// Lists the chat models of [apiKey] (`GET /openai/v1/models`). Throws
/// [MissingApiKeyException] for a refused key, [GroqQuotaExceededException]
/// while blocked, and [MinutesGenerationException] otherwise.
Future<List<GroqModelInfo>> listGroqModels({
  required String apiKey,
  http.Client? httpClient,
  GroqRateGate? gate,
  String baseUrl = kGroqApiBase,
}) async {
  final g = gate ?? GroqRateGate.shared;
  GroqTextGenerator.checkGate(g, apiKey);
  final client = LlmServerClient(
    baseUrl: baseUrl,
    client: httpClient,
    apiKey: apiKey,
    connectTimeout: const Duration(seconds: 20),
  );
  try {
    return [
      for (final e in await client.listModelEntries())
        GroqModelInfo.fromJson(e),
    ];
  } on LlmServerException catch (e) {
    throw mapGroqError(e, apiKey: apiKey, gate: g);
  } finally {
    client.close();
  }
}

/// [MinutesBackend] of Groq: a [LocalLlmMinutesBackend] over a
/// [GroqTextGenerator] (map-reduce when the request does not fit, JSON
/// repair), reporting quota waits and retrying with a smaller context after
/// a "request too large" refusal.
///
/// Model choice: the configured model when the key's live list has it;
/// otherwise (automatic) the ranked list of [rankGroqModels], moving on to
/// the next model when one's free per-minute token limit is too small for
/// the request (the limits are learned from Groq's answers and refusals).
class GroqMinutesBackend implements MinutesBackend {
  /// Creates the backend; the model list is fetched on first use.
  GroqMinutesBackend({
    required this.apiKey,
    this.model,
    http.Client? httpClient,
    GroqRateGate? gate,
    this.baseUrl = kGroqApiBase,
    this._sleep,
    this.onModelDiscovered,
    this.budget = const LocalLlmBudget(
      answerShare: 0.45,
      minAnswerTokens: 768,
      maxAnswerTokens: 16384,
    ),
    this.maxModelSwitches = 6,
  }) : _http = httpClient,
       _gate = gate ?? GroqRateGate.shared;

  /// The key.
  final String apiKey;

  /// Configured model (null = automatic).
  final String? model;

  /// API base (tests).
  final String baseUrl;

  /// Token budgets of the local-engine pipeline.
  final LocalLlmBudget budget;

  /// Most automatic model switches per request.
  final int maxModelSwitches;

  /// Called when the configured model was not available and another was
  /// chosen (persist it).
  final void Function(String model)? onModelDiscovered;

  final http.Client? _http;
  final GroqRateGate _gate;
  final Future<void> Function(Duration)? _sleep;
  List<GroqModelInfo>? _models;
  final Map<String, (LocalLlmMinutesBackend, GroqTextGenerator)> _open = {};
  bool _closed = false;

  @override
  String get engineId => AppSettingsData.engineGroq;

  @override
  String get displayName => GS.displayName;

  @override
  bool get sendsDataOffDevice => true;

  (LocalLlmMinutesBackend, GroqTextGenerator) _backendFor(GroqModelInfo info) =>
      _open[info.id] ??= () {
        final gen = GroqTextGenerator.open(
          apiKey: apiKey,
          info: info,
          httpClient: _http,
          gate: _gate,
          baseUrl: baseUrl,
          sleep: _sleep,
        );
        return (
          LocalLlmMinutesBackend(
            engineId: AppSettingsData.engineGroq,
            displayName: GS.displayName,
            sendsDataOffDevice: true,
            openPhase: MinutesBackendPhase.connecting,
            budget: budget,
            open: () async => gen,
          ),
          gen,
        );
      }();

  /// Whether the fixed part of [request] (system prompt, schema, a minimal
  /// answer and notes) fits the model's known budget.
  bool _fits(GroqTextGenerator gen, MinutesBackendRequest request) {
    final schema = jsonEncode(request.schema);
    final fixed =
        estimateGroqTokens(request.system) +
        estimateGroqTokens(schema) +
        budget.templateOverheadTokens +
        budget.minAnswerTokens +
        (request.context == null ? 256 : 512);
    return fixed <= gen.contextTokens;
  }

  static bool _tooSmall(InsatoException e) =>
      e is GroqRequestTooLargeException ||
      e.messageAr == LS.contextTooSmall ||
      e.messageAr == LS.answerTruncated;

  @override
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  }) async {
    if (_closed) throw const MinutesGenerationException(LS.engineClosed);
    onProgress?.call(
      const MinutesBackendProgress(MinutesBackendPhase.connecting),
    );
    final models = _models ??= await listGroqModels(
      apiKey: apiKey,
      httpClient: _http,
      gate: _gate,
      baseUrl: baseUrl,
    );
    final wanted = model?.trim();
    final configured = wanted == null || wanted.isEmpty
        ? null
        : models.where((m) => m.id == wanted && m.active).firstOrNull;
    final candidates = configured != null
        ? [configured]
        : rankGroqModels(models);
    if (candidates.isEmpty) {
      throw const MinutesGenerationException(GS.noModel);
    }
    if (configured == null && wanted != null && wanted.isNotEmpty) {
      onModelDiscovered?.call(candidates.first.id);
    }
    void onWait(Duration d) => onProgress?.call(
      MinutesBackendProgress(MinutesBackendPhase.waitingForQuota, wait: d),
    );

    InsatoException? last;
    var switches = 0;
    for (final info in candidates) {
      if (switches > maxModelSwitches) break;
      final (inner, gen) = _backendFor(info);
      if (configured == null && !_fits(gen, request)) {
        // Known too small: try the next model without sending anything.
        last ??= const GroqRequestTooLargeException(
          GS.requestTooLarge,
          limit: null,
        );
        continue;
      }
      switches++;
      gen.onQuotaWait = onWait;
      for (var round = 0; round < 2; round++) {
        try {
          return await inner.generateStructured(
            request,
            onProgress: onProgress,
          );
        } on MinutesGenerationException catch (e) {
          if (!_tooSmall(e)) rethrow;
          last = e;
          // A newly learned limit: retry this model once with the smaller
          // context; otherwise move on to the next model.
          if (e is! GroqRequestTooLargeException || round == 1) break;
          if (configured == null && !_fits(gen, request)) break;
        }
      }
    }
    final e = last;
    if (e is GroqRequestTooLargeException || e == null) {
      throw MinutesGenerationException(
        GS.requestTooLarge,
        debugDetails: e?.debugDetails ?? 'no Groq model fits the request',
      );
    }
    throw e;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final (inner, _) in _open.values) {
      inner.close();
    }
    _open.clear();
  }
}
