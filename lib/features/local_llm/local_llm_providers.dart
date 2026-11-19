// Riverpod providers of the local minutes engines (F14): the GGUF model
// manager, the shared on-device runtime pool and the server client factory.

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/interfaces.dart' show ModelState;
import '../../session/providers.dart' show appPathsProvider;
import '../../speech/model_manager.dart';
import 'llama_runtime.dart';
import 'llm_catalog.dart';
import 'llm_server_client.dart';
import 'local_llm_pool.dart';

/// True on desktop platforms (Windows): the larger models are offered and
/// the desktop model is recommended.
final localLlmIsDesktopProvider = Provider<bool>(
  (ref) => Platform.isWindows || Platform.isLinux || Platform.isMacOS,
);

/// Directory of the GGUF models: `<app support>/models/llm` (a separate
/// directory, managed by its own [ModelManager], so the speech models
/// screen is not affected).
final localLlmModelsDirProvider = FutureProvider<String>((ref) async {
  final base = await ref.watch(appPathsProvider).modelsDir();
  return p.join(base, 'llm');
});

/// The manager downloading / resolving the GGUF models of
/// [LocalLlmCatalog]. Disposed with the container.
final localLlmModelManagerProvider = FutureProvider<ModelManager>((ref) async {
  final dir = await ref.watch(localLlmModelsDirProvider.future);
  final manager = ModelManager(
    dir,
    catalog: LocalLlmCatalog.modelSpecs,
    // Multi-gigabyte files: allow slow links.
    idleTimeout: const Duration(minutes: 2),
  );
  ref.onDispose(manager.dispose);
  await manager.refresh();
  return manager;
});

/// Live state of every GGUF model, keyed by model id.
final localLlmModelStatesProvider = StreamProvider<Map<String, ModelState>>((
  ref,
) async* {
  final manager = await ref.watch(localLlmModelManagerProvider.future);
  yield* manager.statesStream;
});

/// Loads a GGUF model into the native runtime (tests override it).
final localLlmLoaderProvider = Provider<LocalLlmLoader>(
  (ref) => LlamadartTextGenerator.load,
);

/// The shared on-device runtime (keeps the model loaded between requests).
final localLlmPoolProvider = Provider<LocalLlmPool>((ref) {
  final pool = LocalLlmPool(ref.watch(localLlmLoaderProvider));
  ref.onDispose(pool.dispose);
  return pool;
});

/// Creates a client for a server URL (tests inject a mock HTTP client).
final llmServerClientFactoryProvider =
    Provider<LlmServerClient Function(String url)>(
      (ref) =>
          (url) => LlmServerClient(baseUrl: url),
    );
