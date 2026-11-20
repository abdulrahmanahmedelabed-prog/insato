import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/local_llm/llm_catalog.dart';
import 'package:insato/features/local_llm/llm_generator.dart';
import 'package:insato/features/local_llm/local_llm_pool.dart';

import 'fakes.dart';

void main() {
  const a = LocalLlmCatalog.qwen3_4b;
  const b = LocalLlmCatalog.qwen3_1_7b;

  late List<FakeGenerator> loaded;
  late int loads;
  Object? loadError;

  Future<LlmTextGenerator> loader(LocalLlmModel m, String path) async {
    loads++;
    await Future<void>.delayed(Duration.zero);
    if (loadError case final e?) throw e;
    final g = FakeGenerator(name: '${m.id}@$path');
    loaded.add(g);
    return g;
  }

  setUp(() {
    loaded = [];
    loads = 0;
    loadError = null;
  });

  test('shares one loaded model between leases', () async {
    final pool = LocalLlmPool(loader);
    final l1 = await pool.acquire(a, '/a');
    final l2 = await pool.acquire(a, '/a');
    expect(loads, 1);
    expect(pool.loadedModelId, a.id);
    expect(l1.modelName, '${a.id}@/a');
    await l1.close();
    await l2.close();
    expect(loaded.single.closed, isFalse, reason: 'kept for idleTimeout');
    await pool.dispose();
    expect(loaded.single.closed, isTrue);
  });

  test('concurrent acquires during loading load once', () async {
    final pool = LocalLlmPool(loader);
    final leases = await Future.wait([
      pool.acquire(a, '/a'),
      pool.acquire(a, '/a'),
      pool.acquire(a, '/a'),
    ]);
    expect(loads, 1);
    for (final l in leases) {
      await l.close();
    }
    await pool.dispose();
  });

  test('unloads after the idle timeout', () async {
    const idle = Duration(milliseconds: 80);
    final pool = LocalLlmPool(loader, idleTimeout: idle);
    var lease = await pool.acquire(a, '/a');
    await lease.close();
    await Future<void>.delayed(idle ~/ 2);
    expect(loaded.single.closed, isFalse);
    // A new lease cancels the timer.
    lease = await pool.acquire(a, '/a');
    await Future<void>.delayed(idle * 2);
    expect(loaded.single.closed, isFalse);
    expect(loads, 1);
    await lease.close();
    await Future<void>.delayed(idle * 2);
    expect(loaded.single.closed, isTrue);
    expect(pool.loadedModelId, isNull);
    await pool.dispose();
  });

  test('a zero idle timeout unloads at once', () async {
    final pool = LocalLlmPool(loader, idleTimeout: Duration.zero);
    final l = await pool.acquire(a, '/a');
    await l.close();
    await Future<void>.delayed(Duration.zero);
    expect(loaded.single.closed, isTrue);
    expect(pool.loadedModelId, isNull);
  });

  test('switching models unloads the idle one', () async {
    final pool = LocalLlmPool(loader);
    final l1 = await pool.acquire(a, '/a');
    await l1.close();
    final l2 = await pool.acquire(b, '/b');
    expect(loaded.first.closed, isTrue);
    expect(pool.loadedModelId, b.id);
    await l2.close();
    await pool.dispose();
  });

  test('another model while one is in use is loaded on its own', () async {
    final pool = LocalLlmPool(loader);
    final l1 = await pool.acquire(a, '/a');
    final own = await pool.acquire(b, '/b');
    expect(loads, 2);
    expect(pool.loadedModelId, a.id);
    await own.close();
    expect(loaded[1].closed, isTrue);
    expect(loaded[0].closed, isFalse);
    await l1.close();
    await pool.dispose();
  });

  test('a failed load is retried by the next acquire', () async {
    final pool = LocalLlmPool(loader);
    loadError = StateError('oom');
    await expectLater(pool.acquire(a, '/a'), throwsStateError);
    expect(pool.loadedModelId, isNull);
    loadError = null;
    final l = await pool.acquire(a, '/a');
    expect(loads, 2);
    await l.close();
    await pool.dispose();
  });

  test('generations are serialised across leases', () async {
    final pool = LocalLlmPool(loader);
    final l1 = await pool.acquire(a, '/a');
    final l2 = await pool.acquire(a, '/a');
    final gen = loaded.single;
    final gate = Completer<void>();
    gen.gate = gate.future;
    gen.responses.addAll(['one', 'two']);
    const req = LlmGenerationRequest(system: 's', user: 'u', maxTokens: 1);
    final f1 = l1.generate(req);
    final f2 = l2.generate(req);
    await Future<void>.delayed(Duration.zero);
    expect(gen.maxConcurrent, 1);
    expect(gen.requests, hasLength(1));
    gate.complete();
    expect((await f1).text, 'one');
    expect((await f2).text, 'two');
    expect(gen.maxConcurrent, 1);
    // A failing generation does not block the next one.
    gen.errors.add(StateError('x'));
    gen.responses.add('three');
    await expectLater(l1.generate(req), throwsStateError);
    expect((await l2.generate(req)).text, 'three');
    await l1.close();
    await l2.close();
    await pool.dispose();
  });

  test('a closed lease refuses to generate; close is idempotent', () async {
    final pool = LocalLlmPool(loader);
    final l = await pool.acquire(a, '/a');
    await l.close();
    await l.close();
    expect(
      () => l.generate(
        const LlmGenerationRequest(system: 's', user: 'u', maxTokens: 1),
      ),
      throwsStateError,
    );
    await pool.dispose();
  });

  test('evict unloads an idle model and refuses one in use', () async {
    final pool = LocalLlmPool(loader);
    expect(await pool.evict(a.id), isTrue, reason: 'nothing loaded');
    final l = await pool.acquire(a, '/a');
    expect(await pool.evict(b.id), isTrue, reason: 'another model');
    expect(await pool.evict(a.id), isFalse);
    expect(loaded.single.closed, isFalse);
    await l.close();
    expect(await pool.evict(a.id), isTrue);
    expect(loaded.single.closed, isTrue);
    expect(pool.loadedModelId, isNull);
    await pool.dispose();
  });

  test('a disposed pool refuses leases', () async {
    final pool = LocalLlmPool(loader);
    await pool.dispose();
    expect(() => pool.acquire(a, '/a'), throwsStateError);
  });
}
