// The on-device runtime of the local minutes engine (F14): a GGUF model run
// in-process by llama.cpp through `llamadart`.
//
// JSON output is constrained by the request's JSON schema
// (`responseFormat: json_schema`, converted to a llama.cpp grammar by
// llamadart). When the runtime rejects a schema (LlamaUnsupportedException)
// the generator falls back to the schema in the prompt; the backend then
// parses tolerantly and repairs once.
//
// This file is the only one that touches llamadart; everything else uses the
// [LlmTextGenerator] interface so it can be tested without the native
// runtime.

import 'package:llamadart/llamadart.dart';

import '../../core/errors.dart';
import 'llm_catalog.dart';
import 'llm_generator.dart';
import 'strings.dart';

/// [LlmTextGenerator] over a loaded llamadart [LlamaEngine].
class LlamadartTextGenerator implements LlmTextGenerator {
  LlamadartTextGenerator._(this._engine, this._model, this.contextTokens);

  /// Loads [model] from [path] with its context size. Throws
  /// [ModelException] with an Arabic message when it cannot be loaded (most
  /// often: not enough memory). [backend] replaces the native llama.cpp
  /// backend (tests); the engine owns and disposes it.
  static Future<LlamadartTextGenerator> load(
    LocalLlmModel model,
    String path, {
    LlamaBackend? backend,
  }) async {
    final LlamaEngine engine;
    try {
      engine = await LlamaEngine.load(
        LlamaModel(ModelSource.path(path)),
        params: ModelParams(contextSize: model.contextTokens),
        backend: backend,
      );
    } on LlamaUnsupportedException catch (e) {
      // This platform / build has no runtime for GGUF models.
      throw ModelException(
        LS.localRuntimeUnavailable,
        debugDetails: 'llamadart load ${model.id}: $e',
        cause: e,
      );
    } on LlamaBackendInitializationException catch (e) {
      throw ModelException(
        LS.localRuntimeUnavailable,
        debugDetails: 'llamadart load ${model.id}: $e',
        cause: e,
      );
    } on LlamaException catch (e) {
      // Out of memory, corrupt file, … (llamadart wraps backend failures in
      // LlamaModelException).
      throw ModelException(
        LS.localLoadFailed(model.minRamGb),
        debugDetails: 'llamadart load ${model.id}: $e',
        cause: e,
      );
    } on Object catch (e) {
      // Native library missing / FFI failure.
      throw ModelException(
        LS.localRuntimeUnavailable,
        debugDetails: 'llamadart load ${model.id}: $e',
        cause: e,
      );
    }
    var ctx = model.contextTokens;
    try {
      final actual = await engine.getContextSize();
      if (actual > 0) ctx = actual;
    } on LlamaException {
      // Keep the requested size.
    }
    return LlamadartTextGenerator._(engine, model, ctx);
  }

  final LlamaEngine _engine;
  final LocalLlmModel _model;
  bool _schemaSupported = true;
  bool _closed = false;

  @override
  final int contextTokens;

  @override
  String get modelName => _model.modelLabel;

  @override
  bool get enforcesSchema => _schemaSupported;

  @override
  Future<int> countTokens(String text) async {
    try {
      return await _engine.getTokenCount(text);
    } on LlamaException {
      return estimateTokens(text);
    }
  }

  @override
  Future<LlmGeneration> generate(
    LlmGenerationRequest request, {
    LlmProgressCallback? onProgress,
  }) async {
    final schema = request.schema;
    if (schema != null && _schemaSupported) {
      try {
        return await _run(request, schema, onProgress);
      } on LlamaUnsupportedException {
        _schemaSupported = false;
      }
    }
    final system = schema != null &&
            !request.system.contains('# Output format (strict)')
        ? '${request.system}${schemaPromptSuffix(schema)}'
        : request.system;
    return _run(
      LlmGenerationRequest(
        system: system,
        user: request.user,
        maxTokens: request.maxTokens,
        temperature: request.temperature,
      ),
      null,
      onProgress,
    );
  }

  Future<LlmGeneration> _run(
    LlmGenerationRequest request,
    Map<String, dynamic>? schema,
    LlmProgressCallback? onProgress,
  ) async {
    final answer = StringBuffer();
    var thinking = 0;
    var truncated = false;
    try {
      final stream = _engine.create(
        [
          LlamaChatMessage.fromText(
            role: LlamaChatRole.system,
            text: request.system,
          ),
          LlamaChatMessage.fromText(
            role: LlamaChatRole.user,
            text: request.user,
          ),
        ],
        params: GenerationParams(
          maxTokens: request.maxTokens,
          temp: request.temperature,
          topP: 0.9,
          penalty: 1.05,
        ),
        // Qwen3 hybrid models would otherwise spend the budget reasoning.
        enableThinking: false,
        responseFormat: schema == null
            ? null
            : {
                'type': 'json_schema',
                'json_schema': {'name': 'response', 'schema': schema},
              },
      );
      await for (final chunk in stream) {
        final t = chunk.thinking;
        if (t.isNotEmpty) {
          thinking += t.length;
          onProgress?.call(LlmStreamPhase.thinking, thinking);
        }
        final text = chunk.text;
        if (text.isNotEmpty) {
          answer.write(text);
          onProgress?.call(LlmStreamPhase.writing, answer.length);
        }
        if (chunk.finishReason == LlamaFinishReason.length) truncated = true;
      }
    } on LlamaUnsupportedException {
      if (schema != null) rethrow;
      throw const MinutesGenerationException(LS.localGenerationFailed);
    } on LlamaContextException catch (e) {
      throw MinutesGenerationException(
        LS.contextTooSmall,
        debugDetails: 'llamadart context: $e',
        cause: e,
      );
    } on LlamaException catch (e) {
      throw MinutesGenerationException(
        LS.localGenerationFailed,
        debugDetails: 'llamadart generate: $e',
        cause: e,
      );
    }
    return LlmGeneration(
      text: stripThinking(answer.toString()),
      model: modelName,
      truncated: truncated,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _engine.dispose();
    } on LlamaException {
      // Already released.
    }
  }
}
