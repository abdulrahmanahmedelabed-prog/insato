// Extension points of the on-device and local-server minutes engines (F14).
//
// OWNED BY THE F14 FEATURE (lib/features/local_llm). The shared engine
// selection (`createMinutesBackend` in lib/session/minutes_engines.dart)
// reads these providers: while a provider yields null, its engine is not
// offered in Settings and selecting it reports that it is unavailable.
// F14 implements the engines by returning a builder here; nothing else in
// the app needs to change.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show BuildContext, Widget;

import '../../data/secure_settings.dart';
import '../../minutes/minutes_backend.dart';

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

/// On-device GGUF engine (`minutesEngine == 'local'`); null = not available
/// in this build.
final localMinutesBackendBuilderProvider =
    Provider<LocalMinutesBackendBuilder?>((ref) => null);

/// Local-network server engine, Ollama / LM Studio
/// (`minutesEngine == 'server'`); null = not available in this build.
final serverMinutesBackendBuilderProvider =
    Provider<LocalMinutesBackendBuilder?>((ref) => null);
