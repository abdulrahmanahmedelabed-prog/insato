// Riverpod wiring of the whole app (flutter_riverpod 3, no code generation).
//
// Import this one file from the UI: it re-exports the data-layer providers
// (database, repositories, settings, DB streams) and adds the session-level
// ones (model manager, export, minutes engine, recording session, per-meeting
// background jobs).
//
// Tests override the seams: [databaseProvider] (in-memory drift DB),
// [appPathsProvider] (temp dirs), [sessionAudioSourceProvider],
// [sessionEnginesFactoryProvider], [sessionPlatformHooksProvider],
// [minutesEngineFactoryProvider], [secureSettingsProvider].

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/audio_capture_service.dart';
import '../core/interfaces.dart';
import '../data/repositories.dart';
import '../data/secure_settings.dart';
import '../minutes/claude_client.dart';
import '../minutes/export_service.dart';
import '../minutes/minutes_generator.dart';
import '../minutes/minutes_prompt.dart';
import '../speech/model_manager.dart';
import 'meeting_session_controller.dart';
import 'post_processor.dart';

export '../audio/audio_capture_service.dart' show audioCaptureServiceProvider;
export '../data/repositories.dart'
    show
        databaseProvider,
        meetingProvider,
        meetingRepositoryProvider,
        meetingSpeakersProvider,
        meetingsProvider,
        segmentRepositoryProvider,
        segmentsProvider,
        speakerRepositoryProvider,
        speakersByIdProvider,
        speakersProvider;
export '../data/secure_settings.dart'
    show appSettingsDataProvider, appSettingsProvider, secureSettingsProvider;

// ---------------------------------------------------------------------------
// File-system locations
// ---------------------------------------------------------------------------

/// App directories. Injectable for tests.
class AppPaths {
  /// Creates the paths. [documentsDir] and [supportDir] default to
  /// path_provider's application documents / support directories.
  AppPaths({
    Future<Directory> Function()? documentsDir,
    Future<Directory> Function()? supportDir,
  }) : _documents = documentsDir ?? getApplicationDocumentsDirectory,
       _support = supportDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _documents;
  final Future<Directory> Function() _support;

  static Future<String> _ensure(String path) async {
    await Directory(path).create(recursive: true);
    return path;
  }

  /// `<app documents>/recordings` (created on demand): archived meeting WAVs.
  Future<String> recordingsDir() async =>
      _ensure(p.join((await _documents()).path, 'recordings'));

  /// `<app support>/models` (created on demand): downloaded speech models.
  Future<String> modelsDir() async =>
      _ensure(p.join((await _support()).path, 'models'));

  /// `<app documents>/exports` (created on demand): files for sharing.
  Future<String> exportsDir() async =>
      _ensure(p.join((await _documents()).path, 'exports'));
}

/// App directories.
final appPathsProvider = Provider<AppPaths>((ref) => AppPaths());

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// The on-device model manager (models under `<app support>/models`). The
/// disk is scanned once when created. Disposed with the container.
final modelManagerProvider = FutureProvider<ModelManager>((ref) async {
  final dir = await ref.watch(appPathsProvider).modelsDir();
  final manager = ModelManager(dir);
  ref.onDispose(manager.dispose);
  await manager.refresh();
  return manager;
});

/// Live status of every downloadable model, keyed by model id.
final modelStatesProvider = StreamProvider<Map<String, ModelState>>((
  ref,
) async* {
  final manager = await ref.watch(modelManagerProvider.future);
  yield* manager.statesStream;
});

// ---------------------------------------------------------------------------
// Export & minutes
// ---------------------------------------------------------------------------

/// Markdown / PDF / plain-text export of minutes and transcripts.
final exportServiceProvider = Provider<ExportService>((ref) => ExportService());

/// Creates a Claude minutes engine from the stored API key and the user's
/// model / detail settings; yields null when no key is configured.
final minutesEngineFactoryProvider = Provider<MinutesEngineFactory>((ref) {
  final secure = ref.watch(secureSettingsProvider);
  final settings = ref.watch(appSettingsProvider);
  return () async {
    final key = await secure.getAnthropicApiKey();
    if (key == null) return null;
    final s = await settings.load();
    final client = ClaudeClient(apiKey: key, model: s.claudeModel);
    return MinutesEngineHandle(
      ClaudeMinutesEngine(
        client: client,
        detailLevel: MinutesDetailLevel.parse(s.minutesDetail),
      ),
      release: client.close,
    );
  };
});

// ---------------------------------------------------------------------------
// Recording session seams
// ---------------------------------------------------------------------------

/// Builds the speech engines of a session (sherpa-onnx + optional Deepgram).
final sessionEnginesFactoryProvider = Provider<SessionEnginesFactory>((ref) {
  return SherpaSessionEnginesFactory(
    modelManager: () => ref.read(modelManagerProvider.future),
    secureSettings: ref.watch(secureSettingsProvider),
  );
});

/// Audio capture used by recording sessions.
final sessionAudioSourceProvider = Provider<SessionAudioSource>(
  (ref) => AudioCaptureSessionSource(ref.watch(audioCaptureServiceProvider)),
);

/// Permission / foreground service / wakelock integration.
final sessionPlatformHooksProvider = Provider<SessionPlatformHooks>(
  (ref) => DefaultSessionPlatformHooks(),
);

/// Post-recording processing and speaker corrections.
final postProcessorProvider = Provider<PostProcessor>((ref) {
  return PostProcessor(
    db: ref.watch(databaseProvider),
    meetings: ref.watch(meetingRepositoryProvider),
    segments: ref.watch(segmentRepositoryProvider),
    speakers: ref.watch(speakerRepositoryProvider),
    settings: ref.watch(appSettingsProvider),
    minutesEngineFactory: ref.watch(minutesEngineFactoryProvider),
    enginesFactory: ref.watch(sessionEnginesFactoryProvider),
    isMeetingActive: (id) {
      final s = ref.read(meetingSessionControllerProvider);
      return s.isActive && s.meetingId == id;
    },
  );
});

/// The live recording session (one at a time).
final meetingSessionControllerProvider =
    NotifierProvider<MeetingSessionController, SessionState>(
      MeetingSessionController.new,
    );

/// Background job (minutes / re-processing / refinement) of one meeting,
/// keyed by meeting id. Not auto-disposed: jobs keep running while no screen
/// listens (e.g. minutes generated right after stopping a recording).
final meetingJobsProvider =
    NotifierProvider.family<MeetingJobsController, MeetingJobState, String>(
      MeetingJobsController.new,
    );
