// Extension points of the on-device and local-server minutes engines (F14).
//
// OWNED BY THE F14 FEATURE (lib/features/local_llm). The shared engine
// selection (`createMinutesBackend` in lib/session/minutes_engines.dart)
// reads these providers: while a provider yields null, its engine is not
// offered in Settings and selecting it reports that it is unavailable.
// Both engines are implemented: the builders return a backend once the
// engine can run (model downloaded / server model chosen) and null before,
// with an Arabic explanation.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show BuildContext, Widget;

import '../../data/secure_settings.dart';
import '../../minutes/minutes_backend.dart';
import 'llm_catalog.dart';
import 'llm_server_client.dart';
import 'local_engine_settings.dart';
import 'local_llm_backend.dart';
import 'local_llm_providers.dart';
import 'server_engine_settings.dart';
import 'strings.dart';

/// Builds a [MinutesBackend] for the current [AppSettingsData]; returns null
/// when the engine cannot run yet (e.g. its model is not downloaded or no
/// server model is chosen) — the user then sees [unavailableMessageAr].
class LocalMinutesBackendBuilder {
  /// Creates a builder.
  const LocalMinutesBackendBuilder({
    required this.build,
    required this.unavailableMessageAr,
    this.settings,
  });

  /// Creates the backend (the caller closes it after use).
  final Future<MinutesBackend?> Function(AppSettingsData settings) build;

  /// Arabic explanation shown when [build] returns null.
  final String unavailableMessageAr;

  /// The engine's settings (model choice, server URL, …), shown in Settings
  /// under the engine choice while this engine is selected.
  final Widget Function(BuildContext context)? settings;
}

/// On-device GGUF engine (`minutesEngine == 'local'`): llama.cpp through
/// llamadart, model chosen with `localLlmModelId` (null = the recommended
/// model of the device class). [LocalMinutesBackendBuilder.build] returns
/// null while that model is not downloaded.
final localMinutesBackendBuilderProvider =
    Provider<LocalMinutesBackendBuilder?>((ref) {
      final pool = ref.watch(localLlmPoolProvider);
      final desktop = ref.watch(localLlmIsDesktopProvider);
      return LocalMinutesBackendBuilder(
        build: (settings) async {
          final model = LocalLlmCatalog.resolve(
            settings.localLlmModelId,
            desktop: desktop,
          );
          final m = await ref.read(localLlmModelManagerProvider.future);
          if (!m.isReady(model.id)) return null;
          final path = await m.filePath(model.id);
          return LocalLlmMinutesBackend(
            engineId: AppSettingsData.engineLocal,
            displayName: LS.localDisplayName,
            sendsDataOffDevice: false,
            open: () => pool.acquire(model, path),
          );
        },
        unavailableMessageAr: LS.localUnavailable,
        settings: (context) => const LocalEngineSettings(),
      );
    });

/// Local-network server engine, Ollama / LM Studio
/// (`minutesEngine == 'server'`), at `serverUrl` with `serverModel`.
/// [LocalMinutesBackendBuilder.build] returns null while no model is chosen.
final serverMinutesBackendBuilderProvider =
    Provider<LocalMinutesBackendBuilder?>((ref) {
      final clientFor = ref.watch(llmServerClientFactoryProvider);
      return LocalMinutesBackendBuilder(
        build: (settings) async {
          final model = settings.serverModel;
          if (model == null || model.trim().isEmpty) return null;
          final url = settings.serverUrl;
          return LocalLlmMinutesBackend(
            engineId: AppSettingsData.engineServer,
            displayName: LS.serverDisplayName,
            sendsDataOffDevice: !isLoopbackServerUrl(url),
            openPhase: MinutesBackendPhase.connecting,
            open: () async {
              final client = clientFor(url);
              try {
                return await ServerTextGenerator.connect(client, model);
              } catch (_) {
                client.close();
                rethrow;
              }
            },
          );
        },
        unavailableMessageAr: LS.serverUnavailable,
        settings: (context) => const ServerEngineSettings(),
      );
    });
