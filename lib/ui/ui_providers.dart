// Providers used only by the UI: aggregated views over the data layer that
// the repositories do not offer directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/secure_settings.dart';
import '../features/local_llm/local_minutes_backends.dart';
import '../session/providers.dart';
import 'format.dart';

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

/// Whether an Anthropic API key is stored; null when the keystore cannot be
/// read right now (e.g. a locked iOS device), so the UI does not claim the
/// key is missing. Invalidate after changing it.
final anthropicKeyConfiguredProvider = FutureProvider<bool?>(
  (ref) => _keyConfigured(ref.watch(secureSettingsProvider).getAnthropicApiKey),
);

/// Whether a Gemini API key is stored; null when unknown (see
/// [anthropicKeyConfiguredProvider]). Invalidate after changing it.
final geminiKeyConfiguredProvider = FutureProvider<bool?>(
  (ref) => _keyConfigured(ref.watch(secureSettingsProvider).getGeminiApiKey),
);

/// Whether the minutes engine selected in Settings can run: its key is
/// stored (and, for Gemini, the free-tier data notice was accepted; for a
/// local engine, it is available in this build). Null while unknown (e.g.
/// a locked keystore). Invalidate [anthropicKeyConfiguredProvider] /
/// [geminiKeyConfiguredProvider] after changing a key.
final minutesEngineReadyProvider = Provider<bool?>((ref) {
  final s = ref.watch(appSettingsDataProvider).value;
  if (s == null) return null;
  switch (s.minutesEngine) {
    case AppSettingsData.engineClaude:
      return ref.watch(anthropicKeyConfiguredProvider).value;
    case AppSettingsData.engineLocal:
      return ref.watch(localMinutesBackendBuilderProvider) != null;
    case AppSettingsData.engineServer:
      return ref.watch(serverMinutesBackendBuilderProvider) != null;
    default:
      final key = ref.watch(geminiKeyConfiguredProvider).value;
      if (key == null) return null;
      return key && s.geminiPrivacyAcknowledged;
  }
});

/// Whether a Deepgram API key is stored; null when unknown (see
/// [anthropicKeyConfiguredProvider]). Invalidate after changing it.
final deepgramKeyConfiguredProvider = FutureProvider<bool?>(
  (ref) => _keyConfigured(ref.watch(secureSettingsProvider).getDeepgramApiKey),
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
