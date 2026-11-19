// Providers used only by the UI: aggregated views over the data layer that
// the repositories do not offer directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/secure_settings.dart';
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

/// Whether an Anthropic API key is stored. Invalidate after changing it.
final anthropicKeyConfiguredProvider = FutureProvider<bool>((ref) async {
  final key = await ref.watch(secureSettingsProvider).getAnthropicApiKey();
  return key != null && key.isNotEmpty;
});

/// Whether a Deepgram API key is stored. Invalidate after changing it.
final deepgramKeyConfiguredProvider = FutureProvider<bool>((ref) async {
  final key = await ref.watch(secureSettingsProvider).getDeepgramApiKey();
  return key != null && key.isNotEmpty;
});

/// Current settings snapshot, falling back to the defaults while loading.
final settingsSnapshotProvider = Provider<AppSettingsData>(
  (ref) => ref.watch(appSettingsDataProvider).value ?? AppSettingsData.defaults,
);
