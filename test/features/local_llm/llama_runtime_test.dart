// LlamadartTextGenerator over a fake llamadart backend (no native runtime).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/features/local_llm/llama_runtime.dart';
import 'package:insato/features/local_llm/llm_catalog.dart';
import 'package:insato/features/local_llm/llm_generator.dart';
import 'package:insato/features/local_llm/strings.dart';
import 'package:llamadart/llamadart.dart';

class _FakeBackend implements LlamaBackend {
  final List<String> responses = [];
  final List<String> prompts = [];
  final List<GenerationParams> params = [];
  ModelParams? loadedWith;
  String? loadedPath;
  Object? loadError;
  Object? generateError;
  int contextSize = 12288;
  bool disposed = false;
  int disposeCalls = 0;

  @override
  bool get isReady => true;

  @override
  Future<int> modelLoad(String path, ModelParams params) async {
    if (loadError case final e?) throw e;
    loadedPath = path;
    loadedWith = params;
    return 1;
  }

  @override
  Future<int> modelLoadFromUrl(
    String url,
    ModelParams params, {
    void Function(double progress)? onProgress,
  }) async => throw UnsupportedError('url');

  @override
  Future<void> modelFree(int modelHandle) async {}

  @override
  Future<int> contextCreate(int modelHandle, ModelParams params) async => 1;

  @override
  Future<void> contextFree(int contextHandle) async {}

  @override
  Future<int> getContextSize(int contextHandle) async => contextSize;

  @override
  Stream<List<int>> generate(
    int contextHandle,
    String prompt,
    GenerationParams params, {
    List<LlamaContentPart>? parts,
  }) async* {
    prompts.add(prompt);
    this.params.add(params);
    if (generateError case final e?) throw e;
    final r = responses.isEmpty ? '{}' : responses.removeAt(0);
    // Stream in small pieces like a real decoder.
    for (var i = 0; i < r.length; i += 4) {
      yield utf8.encode(r.substring(i, i + 4 > r.length ? r.length : i + 4));
    }
  }

  @override
  void cancelGeneration() {}

  @override
  Future<List<int>> tokenize(
    int modelHandle,
    String text, {
    bool addSpecial = true,
  }) async => List.generate((text.length / 3).ceil(), (i) => i);

  @override
  Future<String> detokenize(
    int modelHandle,
    List<int> tokens, {
    bool special = false,
  }) async => '';

  @override
  Future<Map<String, String>> modelMetadata(int modelHandle) async => {
    'tokenizer.chat_template':
        '{% for message in messages %}{{ message["role"] + ": " + '
        'message["content"] + "\\n" }}{% endfor %}'
        '{% if add_generation_prompt %}{{ "assistant: " }}{% endif %}',
  };

  @override
  Future<String> getBackendName() async => 'Fake';

  @override
  bool get supportsUrlLoading => false;

  @override
  Future<bool> isGpuSupported() async => false;

  @override
  Future<void> setLogLevel(LlamaLogLevel level) async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    disposeCalls++;
  }

  @override
  Future<({int total, int free})> getVramInfo() async => (total: 0, free: 0);

  @override
  Future<String> applyChatTemplate(
    int modelHandle,
    List<Map<String, dynamic>> messages, {
    String? customTemplate,
    bool addAssistant = true,
  }) async =>
      messages.map((m) => "${m['role']}: ${m['content']}").join('\n');
}

const _model = LocalLlmCatalog.qwen3_4b;

const Map<String, dynamic> _schema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['ok'],
  'properties': {
    'ok': {'type': 'boolean'},
  },
};

void main() {
  late Directory tmp;
  late String path;
  late _FakeBackend backend;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('insato_llama');
    path = '${tmp.path}/${_model.fileName}';
    // A file must exist: llamadart checks local model files before loading.
    File(path).writeAsBytesSync(utf8.encode('GGUF'));
    backend = _FakeBackend();
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<LlamadartTextGenerator> load() =>
      LlamadartTextGenerator.load(_model, path, backend: backend);

  test('loads with the catalog context size and reports it', () async {
    backend.contextSize = 8192;
    final gen = await load();
    expect(backend.loadedPath, path);
    expect(backend.loadedWith!.contextSize, _model.contextTokens);
    expect(gen.contextTokens, 8192);
    expect(gen.modelName, 'Qwen3-4B-Instruct-2507-Q4_K_M');
    expect(gen.enforcesSchema, isTrue);
    await gen.close();
  });

  test('a load failure becomes an Arabic ModelException', () async {
    backend.loadError = LlamaModelException('out of memory');
    await expectLater(
      load(),
      throwsA(
        isA<ModelException>().having(
          (e) => e.messageAr,
          'messageAr',
          LS.localLoadFailed(_model.minRamGb),
        ),
      ),
    );
  });

  test('a backend error is wrapped by llamadart as a load failure', () async {
    backend.loadError = StateError('mmap failed');
    await expectLater(
      load(),
      throwsA(
        isA<ModelException>().having(
          (e) => e.messageAr,
          'messageAr',
          LS.localLoadFailed(_model.minRamGb),
        ),
      ),
    );
  });

  test('an unsupported runtime reports the runtime as unavailable', () async {
    backend.loadError = LlamaUnsupportedException('no GGUF runtime');
    await expectLater(
      load(),
      throwsA(
        isA<ModelException>().having(
          (e) => e.messageAr,
          'messageAr',
          LS.localRuntimeUnavailable,
        ),
      ),
    );
  });

  test('countTokens uses the model tokenizer', () async {
    final gen = await load();
    expect(await gen.countTokens('abcdefghi'), 3);
    await gen.close();
  });

  test('generates with the system and user turns and parameters', () async {
    backend.responses.add('{"ok": true}');
    final gen = await load();
    final progress = <int>[];
    final out = await gen.generate(
      const LlmGenerationRequest(
        system: 'SYSTEM PROMPT',
        user: 'USER MESSAGE',
        maxTokens: 321,
        schema: _schema,
        temperature: 0.1,
      ),
      onProgress: (phase, chars) {
        expect(phase, LlmStreamPhase.writing);
        progress.add(chars);
      },
    );
    expect(jsonDecode(out.text), {'ok': true});
    expect(out.model, gen.modelName);
    expect(out.truncated, isFalse);
    expect(progress, isNotEmpty);
    expect(progress.last, out.text.length);
    expect(backend.prompts.single, contains('system: SYSTEM PROMPT'));
    expect(backend.prompts.single, contains('user: USER MESSAGE'));
    final p = backend.params.single;
    expect(p.maxTokens, 321);
    expect(p.temp, closeTo(0.1, 1e-9));
    // The schema is enforced through a grammar, not the prompt.
    expect(p.grammar, isNotNull);
    expect(backend.prompts.single, isNot(contains('# Output format')));
    await gen.close();
  });

  test('free-text requests carry no grammar', () async {
    backend.responses.add('مرحباً');
    final gen = await load();
    final out = await gen.generate(
      const LlmGenerationRequest(system: 's', user: 'u', maxTokens: 10),
    );
    expect(out.text, 'مرحباً');
    expect(backend.params.single.grammar, isNull);
    await gen.close();
  });

  test('an unsupported schema falls back to the schema in the prompt', () async {
    backend.responses.add('{"n": 3}');
    final gen = await load();
    const schema = {
      'type': 'object',
      'required': ['n'],
      'properties': {
        'n': {'type': 'integer', 'multipleOf': 3},
      },
    };
    final out = await gen.generate(
      const LlmGenerationRequest(
        system: 'SYS',
        user: 'u',
        maxTokens: 50,
        schema: schema,
      ),
    );
    expect(out.text, '{"n": 3}');
    expect(gen.enforcesSchema, isFalse);
    expect(backend.prompts.single, contains('# Output format (strict)'));
    expect(backend.params.single.grammar, isNull);

    // Later requests go straight to the prompt fallback.
    backend.responses.add('{"ok": false}');
    await gen.generate(
      const LlmGenerationRequest(
        system: 'SYS',
        user: 'u',
        maxTokens: 50,
        schema: _schema,
      ),
    );
    expect(backend.prompts.length, 2);
    expect(backend.prompts.last, contains('# Output format (strict)'));
    await gen.close();
  });

  test('inline <think> blocks are removed from the answer', () async {
    backend.responses.add('<think>hmm</think>\n{"ok": true}');
    final gen = await load();
    final out = await gen.generate(
      const LlmGenerationRequest(system: 's', user: 'u', maxTokens: 50),
    );
    expect(out.text, '{"ok": true}');
    await gen.close();
  });

  test('generation errors become MinutesGenerationException', () async {
    backend.generateError = LlamaInferenceException('decode failed');
    final gen = await load();
    await expectLater(
      gen.generate(
        const LlmGenerationRequest(system: 's', user: 'u', maxTokens: 10),
      ),
      throwsA(
        isA<MinutesGenerationException>().having(
          (e) => e.messageAr,
          'messageAr',
          LS.localGenerationFailed,
        ),
      ),
    );
    await gen.close();
  });

  test('context errors report the context message', () async {
    backend.generateError = LlamaContextException('ctx full');
    final gen = await load();
    await expectLater(
      gen.generate(
        const LlmGenerationRequest(system: 's', user: 'u', maxTokens: 10),
      ),
      throwsA(
        isA<MinutesGenerationException>().having(
          (e) => e.messageAr,
          'messageAr',
          LS.contextTooSmall,
        ),
      ),
    );
    await gen.close();
  });

  test('close disposes the engine once', () async {
    final gen = await load();
    await gen.close();
    await gen.close();
    expect(backend.disposeCalls, 1);
  });
}
