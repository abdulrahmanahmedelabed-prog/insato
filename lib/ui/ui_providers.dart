// Providers used only by the UI: aggregated views over the data layer that
// the repositories do not offer directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/secure_settings.dart';
import '../core/interfaces.dart' show ModelStatus;
import '../features/local_llm/llm_catalog.dart';
import '../features/local_llm/local_llm_providers.dart';
import '../features/local_llm/local_minutes_backends.dart';
import '../features/local_llm/strings.dart';
import '../session/providers.dart';
import 'format.dart';
import 'strings_ar.dart';

/// Number of distinct meetings each speaker appears in (speaker id → count),
/// kept live from the segments table.
final speakerMeetingCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT speaker_id, COUNT(DISTINCT meeting_id) AS n FROM segments '
        'WHERE speaker_id IS NOT NULL GROUP BY speaker_id',
        readsFrom: {db.segments},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('speaker_id'): r.read<int>('n'),
        },
      );
});

/// Ids of models the current settings need but that are not installed;
/// null while settings or model states are still loading (or unreadable).
final missingModelsProvider = Provider<List<String>?>((ref) {
  final settings = ref.watch(appSettingsDataProvider).value;
  final states = ref.watch(modelStatesProvider).value;
  if (settings == null || states == null) return null;
  return missingModelIds(settings, states);
});

/// Whether a Gemini API key is stored; null when the keystore cannot be
/// read right now (e.g. a locked iOS device), so the UI does not claim the
/// key is missing. Invalidate after changing it.
final geminiKeyConfiguredProvider = FutureProvider<bool?>(
  (ref) => _keyConfigured(ref.watch(secureSettingsProvider).getGeminiApiKey),
);

/// Whether a Groq API key is stored (minutes and cloud transcription); null
/// when unknown (see [geminiKeyConfiguredProvider]). Invalidate after
/// changing it.
final groqKeyConfiguredProvider = FutureProvider<bool?>(
  (ref) => _keyConfigured(ref.watch(secureSettingsProvider).getGroqApiKey),
);

/// Whether the minutes engine selected in Settings can run, and if not,
/// why (the Arabic message the minutes tab shows).
class MinutesEngineReadiness {
  /// Creates a readiness.
  const MinutesEngineReadiness({required this.ready, this.messageAr});

  /// The engine can write minutes now.
  final bool ready;

  /// What the user should do (when not [ready]).
  final String? messageAr;
}

/// Readiness of the minutes engine selected in Settings, with a reason
/// specific to the engine: its key stored (and, for Gemini, the free-tier
/// data notice accepted), the on-device model downloaded, the server model
/// chosen. Null while unknown (a locked keystore, model states loading).
/// Invalidate [geminiKeyConfiguredProvider] / [groqKeyConfiguredProvider]
/// after changing a key.
final minutesEngineReadinessProvider = Provider<MinutesEngineReadiness?>((
  ref,
) {
  final s = ref.watch(appSettingsDataProvider).value;
  if (s == null) return null;
  switch (s.minutesEngine) {
    case AppSettingsData.engineGroq:
      final key = ref.watch(groqKeyConfiguredProvider).value;
      if (key == null) return null;
      if (!key) {
        return const MinutesEngineReadiness(
          ready: false,
          messageAr: S.groqKeyMissingBody,
        );
      }
      return MinutesEngineReadiness(
        ready: s.groqPrivacyAcknowledged,
        messageAr: s.groqPrivacyAcknowledged ? null : S.groqPrivacyPendingBody,
      );
    case AppSettingsData.engineLocal:
      if (ref.watch(localMinutesBackendBuilderProvider) == null) {
        return const MinutesEngineReadiness(
          ready: false,
          messageAr: LS.localUnavailable,
        );
      }
      final model = LocalLlmCatalog.resolve(
        s.localLlmModelId,
        desktop: ref.watch(localLlmIsDesktopProvider),
      );
      final states = ref.watch(localLlmModelStatesProvider).value;
      if (states == null) return null;
      final ready = states[model.id]?.status == ModelStatus.ready;
      return MinutesEngineReadiness(
        ready: ready,
        messageAr: ready ? null : LS.localUnavailable,
      );
    case AppSettingsData.engineServer:
      final ready =
          ref.watch(serverMinutesBackendBuilderProvider) != null &&
          (s.serverModel?.trim().isNotEmpty ?? false);
      return MinutesEngineReadiness(
        ready: ready,
        messageAr: ready ? null : LS.serverUnavailable,
      );
    default:
      final key = ref.watch(geminiKeyConfiguredProvider).value;
      if (key == null) return null;
      if (!key) {
        return const MinutesEngineReadiness(
          ready: false,
          messageAr: S.apiKeyMissingBody,
        );
      }
      return MinutesEngineReadiness(
        ready: s.geminiPrivacyAcknowledged,
        messageAr: s.geminiPrivacyAcknowledged
            ? null
            : S.geminiPrivacyPendingBody,
      );
  }
});

/// Whether the minutes engine selected in Settings can run (see
/// [minutesEngineReadinessProvider]); null while unknown.
final minutesEngineReadyProvider = Provider<bool?>(
  (ref) => ref.watch(minutesEngineReadinessProvider)?.ready,
);

Future<bool?> _keyConfigured(Future<String?> Function() read) async {
  try {
    final key = await read();
    return key != null && key.isNotEmpty;
  } on SecureStorageUnavailableException {
    return null;
  }
}

/// Current settings snapshot, falling back to the defaults while loading.
final settingsSnapshotProvider = Provider<AppSettingsData>(
  (ref) => ref.watch(appSettingsDataProvider).value ?? AppSettingsData.defaults,
);
