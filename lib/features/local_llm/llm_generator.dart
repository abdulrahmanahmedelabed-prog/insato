// The small text-generation interface the local minutes engines (F14) are
// built on. Two implementations: the on-device llama.cpp runtime
// (llama_runtime.dart) and the local-network server (llm_server_client.dart).
// Tests use fakes.

import 'dart:convert';

/// One generation request (a system prompt and a single user turn).
class LlmGenerationRequest {
  /// Creates a request.
  const LlmGenerationRequest({
    required this.system,
    required this.user,
    required this.maxTokens,
    this.schema,
    this.temperature = 0.2,
  });

  /// System prompt.
  final String system;

  /// User message.
  final String user;

  /// Maximum answer tokens.
  final int maxTokens;

  /// JSON schema the answer must follow (null = free text).
  final Map<String, dynamic>? schema;

  /// Sampling temperature.
  final double temperature;
}

/// Progress of a running generation.
enum LlmStreamPhase {
  /// The model is reasoning (thinking tokens) before answering.
  thinking,

  /// The model is writing the answer.
  writing,
}

/// Receives the cumulative number of answer characters produced so far.
typedef LlmProgressCallback = void Function(LlmStreamPhase phase, int chars);

/// The answer of a generation.
class LlmGeneration {
  /// Creates an answer.
  const LlmGeneration({
    required this.text,
    required this.model,
    this.truncated = false,
  });

  /// Answer text (thinking removed).
  final String text;

  /// Model that produced it.
  final String model;

  /// True when the answer was cut at the token limit / context end.
  final bool truncated;
}

/// A loaded / reachable text-generation model.
abstract class LlmTextGenerator {
  /// Model name recorded on the minutes.
  String get modelName;

  /// Context window (prompt + answer) in tokens.
  int get contextTokens;

  /// True while the runtime constrains answers to the request schema
  /// itself; otherwise callers append [schemaPromptSuffix] to the system
  /// prompt. May turn false after the runtime rejected a schema.
  bool get enforcesSchema;

  /// Number of tokens of [text] (exact when the runtime can tokenize,
  /// otherwise [estimateTokens]).
  Future<int> countTokens(String text);

  /// Generates an answer. When [LlmGenerationRequest.schema] is set and
  /// [enforcesSchema] is true, the runtime constrains the output to it (when
  /// it then finds it cannot, it drops the constraint and appends
  /// [schemaPromptSuffix] itself). Throws an `InsatoException` with an
  /// Arabic message on failure.
  Future<LlmGeneration> generate(
    LlmGenerationRequest request, {
    LlmProgressCallback? onProgress,
  });

  /// Releases the model / connection. Idempotent.
  Future<void> close();
}

/// Conservative token estimate for mixed Arabic / English text when no
/// tokenizer is available (Arabic averages ~2.5–3 characters per token in
/// Qwen-family tokenizers; English ~4).
int estimateTokens(String text) => (text.length / 2.5).ceil();

/// Instruction appended to the system prompt when the runtime cannot
/// enforce [schema] itself.
String schemaPromptSuffix(Map<String, dynamic> schema) =>
    '\n\n# Output format (strict)\n'
    'Answer with one JSON object only — no prose, no Markdown fences, no '
    'comments — that validates against this JSON schema. Include every '
    'required key; use [] for empty lists and null where the schema allows '
    'it.\n${jsonEncode(schema)}';

final RegExp _thinkBlock = RegExp(r'<think>[\s\S]*?(</think>|$)');

/// Removes `<think>…</think>` reasoning blocks some models emit inline.
String stripThinking(String text) => text.replaceAll(_thinkBlock, '').trim();
