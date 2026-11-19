// Keeps the on-device model loaded between requests (F14).
//
// Loading a multi-gigabyte GGUF file takes seconds, and "Ask your meetings"
// creates a backend per question, so the loaded model is shared: each
// backend gets a lease; generations are serialised (llama.cpp runs one at a
// time per engine); the model is unloaded after [LocalLlmPool.idleTimeout]
// without leases, or at once when another model is needed.

import 'dart:async';

import 'llm_catalog.dart';
import 'llm_generator.dart';

/// Loads [model] from the GGUF file at [path].
typedef LocalLlmLoader =
    Future<LlmTextGenerator> Function(LocalLlmModel model, String path);

/// Shares one loaded on-device model between backends.
class LocalLlmPool {
  /// Creates a pool loading models with [loader].
  LocalLlmPool(this._loader, {this.idleTimeout = const Duration(minutes: 3)});

  final LocalLlmLoader _loader;

  /// How long an unused model stays loaded.
  final Duration idleTimeout;

  _Slot? _slot;
  Timer? _idleTimer;
  Future<void> _lock = Future<void>.value();
  bool _disposed = false;

  /// Id of the model currently loaded (or loading), for tests / diagnostics.
  String? get loadedModelId => _slot?.modelId;

  /// A lease on [model] (loaded from [path] if needed). Close the lease when
  /// done; the model stays loaded for [idleTimeout].
  Future<LlmTextGenerator> acquire(LocalLlmModel model, String path) async {
    if (_disposed) throw StateError('LocalLlmPool disposed');
    _idleTimer?.cancel();
    _idleTimer = null;
    var slot = _slot;
    if (slot != null && (slot.modelId != model.id || slot.path != path)) {
      if (slot.leases == 0) {
        _slot = null;
        await slot.dispose();
      } else {
        // Another model is still in use (rare): load this one on its own.
        final own = await _loader(model, path);
        return _Lease(own, this, null);
      }
      slot = null;
    }
    slot ??= _slot = _Slot(model.id, path, _loader(model, path));
    slot.leases++;
    try {
      final gen = await slot.generator;
      return _Lease(gen, this, slot);
    } catch (_) {
      slot.leases--;
      if (identical(_slot, slot)) _slot = null;
      rethrow;
    }
  }

  Future<T> _serialised<T>(Future<T> Function() run) {
    final previous = _lock;
    final done = Completer<void>();
    _lock = done.future;
    return previous.then((_) => run()).whenComplete(done.complete);
  }

  void _release(_Slot slot) {
    slot.leases--;
    if (slot.leases > 0 || !identical(_slot, slot)) return;
    _idleTimer?.cancel();
    if (idleTimeout == Duration.zero) {
      _slot = null;
      unawaited(slot.dispose());
      return;
    }
    _idleTimer = Timer(idleTimeout, () {
      if (identical(_slot, slot) && slot.leases == 0) {
        _slot = null;
        unawaited(slot.dispose());
      }
    });
  }

  /// Unloads [modelId] now when it is loaded and no lease uses it (e.g.
  /// before its file is deleted: Windows cannot delete a mapped file).
  /// Returns false when a lease still uses it (nothing is unloaded); true
  /// otherwise.
  Future<bool> evict(String modelId) async {
    final slot = _slot;
    if (slot == null || slot.modelId != modelId) return true;
    if (slot.leases > 0) return false;
    _idleTimer?.cancel();
    _idleTimer = null;
    _slot = null;
    await slot.dispose();
    return true;
  }

  /// Unloads everything.
  Future<void> dispose() async {
    _disposed = true;
    _idleTimer?.cancel();
    final slot = _slot;
    _slot = null;
    if (slot != null) await slot.dispose();
  }
}

class _Slot {
  _Slot(this.modelId, this.path, this.generator);

  final String modelId;
  final String path;
  final Future<LlmTextGenerator> generator;
  int leases = 0;

  Future<void> dispose() async {
    try {
      await (await generator).close();
    } catch (_) {
      // Load failed or already closed.
    }
  }
}

class _Lease implements LlmTextGenerator {
  _Lease(this._inner, this._pool, this._slot);

  final LlmTextGenerator _inner;
  final LocalLlmPool _pool;

  /// Null for a model loaded outside the pool (closed with the lease).
  final _Slot? _slot;
  bool _closed = false;

  @override
  String get modelName => _inner.modelName;

  @override
  int get contextTokens => _inner.contextTokens;

  @override
  bool get enforcesSchema => _inner.enforcesSchema;

  @override
  Future<int> countTokens(String text) => _inner.countTokens(text);

  @override
  Future<LlmGeneration> generate(
    LlmGenerationRequest request, {
    LlmProgressCallback? onProgress,
  }) {
    if (_closed) throw StateError('lease closed');
    return _pool._serialised(
      () => _inner.generate(request, onProgress: onProgress),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final slot = _slot;
    if (slot == null) {
      await _inner.close();
    } else {
      _pool._release(slot);
    }
  }
}
