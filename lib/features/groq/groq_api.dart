// Groq API (free plan) shared pieces: endpoints, the live model list and the
// default model choice, structured-output support per model, rate-limit
// classification and the process-wide rate gate ("never hammer").
//
// Groq is OpenAI-compatible (`https://api.groq.com/openai/v1`, key as
// `Authorization: Bearer`). Free-plan limits are low and per model: requests
// and tokens per minute (RPM / TPM), per day (RPD / TPD), and for Whisper
// audio seconds per hour / day (ASH / ASD). A 429 carries `retry-after`
// (seconds) and a message naming the exhausted limit, e.g.
// `… on tokens per minute (TPM): Limit 8000, Used 6000, Requested 3000.
// Please try again in 7.5s.` A request larger than the per-minute token
// limit is refused (413 or 429) whatever the wait. Every answer carries
// `x-ratelimit-limit-tokens` (the TPM limit of the model), which is learned
// here so later requests are sized to fit.

import '../../core/errors.dart';

/// OpenAI-compatible base URL of Groq (`/models`, `/chat/completions`,
/// `/audio/transcriptions`).
const String kGroqApiBase = 'https://api.groq.com/openai/v1';

/// Where users create a free Groq API key.
const String kGroqApiKeyUrl = 'https://console.groq.com/keys';

/// One entry of `GET /openai/v1/models`.
class GroqModelInfo {
  /// Creates an entry.
  const GroqModelInfo({
    required this.id,
    this.contextWindow,
    this.maxCompletionTokens,
    this.active = true,
    this.ownedBy,
  });

  /// Parses an entry (`id`, `active`, `context_window`,
  /// `max_completion_tokens`, `owned_by`).
  factory GroqModelInfo.fromJson(Map<String, dynamic> j) => GroqModelInfo(
    id: (j['id'] as String).trim(),
    contextWindow: j['context_window'] is int
        ? j['context_window'] as int
        : null,
    maxCompletionTokens: j['max_completion_tokens'] is int
        ? j['max_completion_tokens'] as int
        : null,
    active: j['active'] != false,
    ownedBy: j['owned_by'] as String?,
  );

  /// Model id, e.g. `openai/gpt-oss-120b`.
  final String id;

  /// Context window in tokens, when reported.
  final int? contextWindow;

  /// Maximum answer tokens, when reported.
  final int? maxCompletionTokens;

  /// False for models Groq lists but no longer serves.
  final bool active;

  /// Provider (`Meta`, `OpenAI`, …).
  final String? ownedBy;

  /// True for a text-chat model (not speech, safety classifier, TTS or an
  /// agentic system).
  bool get isChat => isGroqChatModel(id);
}

final RegExp _nonChat = RegExp(
  r'whisper|guard|safeguard|tts|playai|orpheus|compound|embed|vision-only',
  caseSensitive: false,
);

/// True for a text-chat model id (see [GroqModelInfo.isChat]).
bool isGroqChatModel(String id) => !_nonChat.hasMatch(id);

/// Parameter count (billions) in a model id: the largest `<n>b` number
/// (`llama-3.3-70b-versatile` → 70, `openai/gpt-oss-120b` → 120); 0 when
/// none.
double groqModelSizeB(String id) {
  var best = 0.0;
  for (final m in RegExp(
    r'(?:^|[^a-z0-9.])(\d+(?:\.\d+)?)b(?![a-z])',
    caseSensitive: false,
  ).allMatches(id)) {
    final v = double.tryParse(m.group(1)!) ?? 0;
    if (v > best) best = v;
  }
  return best;
}

final RegExp _preferredFamily = RegExp(
  r'llama|qwen|gpt-oss',
  caseSensitive: false,
);

/// The default model for long Arabic minutes from the key's live list: an
/// active chat model with at least 8k context, preferring the Llama / Qwen /
/// gpt-oss families, then the most parameters, then the largest context.
/// Null when the list has no usable chat model.
String? pickPreferredGroqModel(List<GroqModelInfo> models) {
  final ranked = rankGroqModels(models);
  return ranked.isEmpty ? null : ranked.first.id;
}

/// The usable chat models of [models] in preference order (see
/// [pickPreferredGroqModel]); the minutes engine falls back along this list
/// when a model's free per-minute limit is too small for the request.
List<GroqModelInfo> rankGroqModels(List<GroqModelInfo> models) {
  final usable = models
      .where((m) => m.active && m.isChat && (m.contextWindow ?? 8192) >= 8192)
      .toList();
  int rank(GroqModelInfo a, GroqModelInfo b) {
    final fa = _preferredFamily.hasMatch(a.id) ? 1 : 0;
    final fb = _preferredFamily.hasMatch(b.id) ? 1 : 0;
    if (fa != fb) return fb - fa;
    final s = groqModelSizeB(b.id).compareTo(groqModelSizeB(a.id));
    if (s != 0) return s;
    final c = (b.contextWindow ?? 0).compareTo(a.contextWindow ?? 0);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  usable.sort(rank);
  return usable;
}

/// Token estimate for Groq's tokenizers: Arabic letters ~2 characters per
/// token, other text (English prompt, JSON) ~3.3 (rounded up).
int estimateGroqTokens(String text) {
  var arabic = 0;
  for (final c in text.runes) {
    if ((c >= 0x0600 && c <= 0x06FF) || (c >= 0x0750 && c <= 0x077F)) {
      arabic++;
    }
  }
  return (arabic / 2.0 + (text.length - arabic) / 3.3).ceil();
}

/// True when Groq accepts `response_format: json_schema` for [model] (its
/// structured-outputs list: gpt-oss, Kimi K2, Llama 4). Other models use
/// `json_object` mode with the schema in the prompt.
bool groqSupportsJsonSchema(String model) => RegExp(
  r'gpt-oss|kimi-k2|llama-4-(maverick|scout)',
  caseSensitive: false,
).hasMatch(model);

/// True when [model] supports strict (constrained) JSON schemas on Groq.
bool groqSupportsStrictSchema(String model) =>
    RegExp('gpt-oss', caseSensitive: false).hasMatch(model);

/// Provider options per model: reasoning models keep their reasoning out of
/// the answer (and gpt-oss reasons briefly to save the small free quota).
Map<String, dynamic> groqExtraBody(String model) {
  final m = model.toLowerCase();
  if (m.contains('gpt-oss')) {
    return const {'reasoning_effort': 'low', 'include_reasoning': false};
  }
  if (m.contains('qwen3') || m.contains('qwq') || m.contains('deepseek-r1')) {
    return const {'reasoning_format': 'hidden'};
  }
  return const {};
}

// ---------------------------------------------------------------------------
// Rate limits
// ---------------------------------------------------------------------------

/// What a Groq 429 / 413 refers to.
enum GroqLimitKind {
  /// A per-minute (or per-hour audio) limit: wait and retry.
  perMinute,

  /// A daily limit (RPD, TPD, ASD): nothing more today.
  daily,

  /// One request asks for more tokens than the per-minute limit allows;
  /// waiting does not help, the request must be smaller.
  tooLarge,
}

/// A parsed Groq rate-limit refusal.
class GroqLimit {
  /// Creates a description.
  const GroqLimit(this.kind, {this.limit, this.requested, this.wait});

  /// Kind.
  final GroqLimitKind kind;

  /// The limit's value (e.g. TPM), when stated.
  final int? limit;

  /// Tokens requested, when stated.
  final int? requested;

  /// Waiting time stated in the message ("try again in 1m2.5s").
  final Duration? wait;
}

/// Parses Groq's "Please try again in 1h2m3.5s" duration.
Duration? parseGroqTryAgain(String? message) {
  if (message == null) return null;
  final m = RegExp(
    r'try again in\s+((?:\d+(?:\.\d+)?[hms]\s*)+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (m == null) return null;
  var ms = 0.0;
  for (final p in RegExp(r'(\d+(?:\.\d+)?)([hms])').allMatches(m.group(1)!)) {
    final v = double.parse(p.group(1)!);
    ms += switch (p.group(2)) {
      'h' => v * 3600000,
      'm' => v * 60000,
      _ => v * 1000,
    };
  }
  return Duration(milliseconds: ms.round());
}

/// Classifies a Groq refusal from its HTTP [status] and [message].
GroqLimit classifyGroqLimit(int status, String? message) {
  final msg = message ?? '';
  final lower = msg.toLowerCase();
  int? number(String label) {
    final m = RegExp(
      '$label\\s*:?\\s*(\\d+)',
      caseSensitive: false,
    ).firstMatch(msg);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  final limit = number('limit');
  final requested = number('requested');
  final wait = parseGroqTryAgain(msg);
  final daily =
      RegExp(r'\((rpd|tpd|asd)\)', caseSensitive: false).hasMatch(msg) ||
      lower.contains('per day');
  final perMinuteTokens =
      RegExp(r'\(tpm\)', caseSensitive: false).hasMatch(msg) ||
      lower.contains('tokens per minute');
  if (!daily &&
      (status == 413 ||
          (perMinuteTokens &&
              limit != null &&
              requested != null &&
              requested > limit))) {
    return GroqLimit(
      GroqLimitKind.tooLarge,
      limit: limit,
      requested: requested,
      wait: wait,
    );
  }
  return GroqLimit(
    daily ? GroqLimitKind.daily : GroqLimitKind.perMinute,
    limit: limit,
    requested: requested,
    wait: wait,
  );
}

/// The free quota of Groq was reached.
class GroqQuotaExceededException extends MinutesGenerationException {
  /// Creates the exception.
  const GroqQuotaExceededException(
    super.messageAr, {
    required this.daily,
    this.retryAfter,
    super.debugDetails,
  }) : super(retryable: !daily);

  /// True when a daily limit is exhausted (retry tomorrow).
  final bool daily;

  /// How long Groq asked to wait, when known.
  final Duration? retryAfter;
}

/// One request was larger than the per-minute token limit ([limit]); the
/// backend retries with a smaller context (map-reduce).
class GroqRequestTooLargeException extends MinutesGenerationException {
  /// Creates the exception.
  const GroqRequestTooLargeException(
    super.messageAr, {
    required this.limit,
    super.debugDetails,
  });

  /// The per-minute token limit, when stated.
  final int? limit;
}

/// Remembers Groq rate-limit blocks per API key and the per-minute token
/// limit learned per model. One gate per process ([GroqRateGate.shared]);
/// tests inject their own.
class GroqRateGate {
  /// Creates a gate; [clock] is injectable for tests.
  GroqRateGate({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// The process-wide gate.
  static final GroqRateGate shared = GroqRateGate();

  final DateTime Function() _clock;
  final Map<String, ({DateTime until, bool daily})> _blocks = {};
  final Map<String, int> _tokenLimits = {};

  /// How long a daily refusal without a stated wait blocks further
  /// requests.
  static const Duration dailyBlock = Duration(minutes: 30);

  String _k(String apiKey, String scope) => '$scope:${apiKey.hashCode}';

  /// Records a block of [apiKey] for [scope] (`chat`, `audio`) for
  /// [duration].
  void block(
    String apiKey,
    Duration duration, {
    bool daily = false,
    String scope = 'chat',
  }) {
    _blocks[_k(apiKey, scope)] = (until: _clock().add(duration), daily: daily);
  }

  /// The remaining block, or null when requests may be sent.
  ({Duration remaining, bool daily})? blockOf(
    String apiKey, {
    String scope = 'chat',
  }) {
    final k = _k(apiKey, scope);
    final b = _blocks[k];
    if (b == null) return null;
    final remaining = b.until.difference(_clock());
    if (remaining <= Duration.zero) {
      _blocks.remove(k);
      return null;
    }
    return (remaining: remaining, daily: b.daily);
  }

  /// Records the per-minute token limit of [model] (from
  /// `x-ratelimit-limit-tokens` or a refusal).
  void learnTokenLimit(String model, int tokens) {
    if (tokens > 0) _tokenLimits[model] = tokens;
  }

  /// The per-minute token limit learned for [model], if any.
  int? tokenLimitOf(String model) => _tokenLimits[model];

  /// Forgets every block (e.g. after the user changed the key).
  void clear() => _blocks.clear();
}
