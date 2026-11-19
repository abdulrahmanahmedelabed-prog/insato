import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/local_llm/llm_generator.dart';

void main() {
  test('stripThinking removes closed and unclosed think blocks', () {
    expect(stripThinking('<think>a\nb</think>\n{"x":1}'), '{"x":1}');
    expect(stripThinking('{"x":1}<think>never closed'), '{"x":1}');
    expect(
      stripThinking('<think>1</think>A<think>2</think>B'),
      'AB',
    );
    expect(stripThinking('  plain  '), 'plain');
  });

  test('estimateTokens is conservative for Arabic', () {
    expect(estimateTokens(''), 0);
    expect(estimateTokens('a'), 1);
    expect(estimateTokens('x' * 100), 40);
  });

  test('schemaPromptSuffix carries the marker and the schema', () {
    const schema = {
      'type': 'object',
      'required': ['a'],
    };
    final s = schemaPromptSuffix(schema);
    expect(s, contains('# Output format (strict)'));
    expect(s, endsWith(jsonEncode(schema)));
  });

  test('request defaults', () {
    const r = LlmGenerationRequest(system: 's', user: 'u', maxTokens: 5);
    expect(r.schema, isNull);
    expect(r.temperature, 0.2);
    const g = LlmGeneration(text: 't', model: 'm');
    expect(g.truncated, isFalse);
  });
}
