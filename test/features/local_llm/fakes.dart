// Test doubles of the local engine (F14).

import 'dart:async';

import 'package:insato/features/local_llm/llm_generator.dart';

/// Scripted [LlmTextGenerator].
class FakeGenerator implements LlmTextGenerator {
  /// Creates a fake answering from [responses] in order.
  FakeGenerator({
    this.name = 'fake-model',
    this.contextTokens = 8192,
    this.enforcesSchema = true,
    this.charsPerToken = 3,
    List<String>? responses,
    this.respond,
  }) : responses = responses ?? [];

  /// Model name.
  final String name;

  @override
  final int contextTokens;

  @override
  bool enforcesSchema;

  /// Token estimate divisor.
  final double charsPerToken;

  /// Answers, consumed in order.
  final List<String> responses;

  /// Answer texts reported as cut off at the token limit
  /// ([LlmGeneration.truncated]).
  final Set<String> truncatedTexts = {};

  /// Dynamic answer (used when [responses] is empty).
  String Function(LlmGenerationRequest request)? respond;

  /// Errors thrown before the answers (consumed in order).
  final List<Object> errors = [];

  /// Received requests.
  final List<LlmGenerationRequest> requests = [];

  /// Blocks generations until completed.
  Future<void>? gate;

  /// True once closed.
  bool closed = false;

  int _running = 0;

  /// Largest number of concurrent generations seen.
  int maxConcurrent = 0;

  @override
  String get modelName => name;

  @override
  Future<int> countTokens(String text) async =>
      (text.length / charsPerToken).ceil();

  @override
  Future<LlmGeneration> generate(
    LlmGenerationRequest request, {
    LlmProgressCallback? onProgress,
  }) async {
    requests.add(request);
    _running++;
    if (_running > maxConcurrent) maxConcurrent = _running;
    try {
      if (gate != null) await gate;
      if (errors.isNotEmpty) throw errors.removeAt(0);
      final text = responses.isNotEmpty
          ? responses.removeAt(0)
          : (respond?.call(request) ?? '{}');
      onProgress?.call(LlmStreamPhase.writing, text.length);
      return LlmGeneration(
        text: text,
        model: name,
        truncated: truncatedTexts.contains(text),
      );
    } finally {
      _running--;
    }
  }

  @override
  Future<void> close() async => closed = true;
}
