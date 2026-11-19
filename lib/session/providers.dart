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

/// File name of a meeting's archived recording inside
/// [AppPaths.recordingsDir]. This (not an absolute path) is what
/// `Meeting.audioPath` stores.
String recordingFileName(String meetingId) => '$meetingId.wav';

final RegExp _meetingWavName = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.wav$',
  caseSensitive: false,
);

/// App directories. Injectable for tests.
///
/// Private data (database, recordings, exports) lives in:
/// * Android / iOS: the app documents directory (private to the app,
///   excluded from backups);
/// * Windows: `%LOCALAPPDATA%\<company>\<product>` (path_provider's
///   application cache directory) — never the user's Documents folder,
///   which is shared with other apps and commonly synced to OneDrive.
class AppPaths {
  /// Creates the paths. [documentsDir], [supportDir], [localDataDir] and
  /// [temporaryDir] default to path_provider's application documents /
  /// support / cache / temporary directories; [isWindows] defaults to the
  /// current platform.
  AppPaths({
    Future<Directory> Function()? documentsDir,
    Future<Directory> Function()? supportDir,
    Future<Directory> Function()? localDataDir,
    Future<Directory> Function()? temporaryDir,
    bool? isWindows,
  }) : _documents = documentsDir ?? getApplicationDocumentsDirectory,
       _support = supportDir ?? getApplicationSupportDirectory,
       _localData = localDataDir ?? getApplicationCacheDirectory,
       _temporary = temporaryDir ?? getTemporaryDirectory,
       _isWindows = isWindows ?? Platform.isWindows;

  final Future<Directory> Function() _documents;
  final Future<Directory> Function() _support;
  final Future<Directory> Function() _localData;
  final Future<Directory> Function() _temporary;
  final bool _isWindows;

  /// File name of the SQLite database (see `driftDatabase(name: 'insato')`).
  static const String databaseName = 'insato';

  static Future<String> _ensure(String path) async {
    await Directory(path).create(recursive: true);
    return path;
  }

  /// Root of the app's private data (see the class comment).
  Future<String> _dataRoot() async =>
      (await (_isWindows ? _localData() : _documents())).path;

  /// `<data root>/recordings` (created on demand): archived meeting WAVs.
  Future<String> recordingsDir() async =>
      _ensure(p.join(await _dataRoot(), 'recordings'));

  /// `<app support>/models` (created on demand): downloaded speech models.
  Future<String> modelsDir() async =>
      _ensure(p.join((await _support()).path, 'models'));

  /// `<data root>/exports` (created on demand): files for sharing.
  Future<String> exportsDir() async =>
      _ensure(p.join(await _dataRoot(), 'exports'));

  /// `<temporary>/share` (created on demand): short-lived files handed to
  /// the share sheet on Android / iOS (see `DefaultShareGateway`).
  Future<String> shareTempDir() async =>
      _ensure(p.join((await _temporary()).path, 'share'));

  /// Directory of `insato.sqlite`: the app documents directory on Android
  /// and iOS (unchanged since v1), `<data root>\data` on Windows.
  Future<String> databaseDir() async => _isWindows
      ? _ensure(p.join(await _dataRoot(), 'data'))
      : (await _documents()).path;

  /// Where v1 kept the database on Windows (the bare Documents folder).
  Future<String> legacyDatabaseDir() async => (await _documents()).path;

  /// Resolves a stored `Meeting.audioPath` to the file's current location.
  ///
  /// New rows store only the file name; older rows an absolute path that may
  /// be stale (the iOS data container moves on app updates, Windows data
  /// moved out of Documents). The file is looked up by name in the current
  /// [recordingsDir]; an absolute stored path is used only when the file is
  /// not there but still exists at that path.
  Future<String> resolveRecording(String stored) async {
    final current = p.join(await recordingsDir(), p.basename(stored));
    if (p.isAbsolute(stored) &&
        stored != current &&
        !await File(current).exists() &&
        await File(stored).exists()) {
      return stored;
    }
    return current;
  }

  /// Windows only: moves data v1 kept in the user's Documents folder
  /// (`insato.sqlite*`, `recordings\<meeting id>.wav`) to the private data
  /// root. Must run before the database is opened. Files whose names are not
  /// Insato's are never touched (Documents is shared with other apps), and
  /// nothing is overwritten. Never throws; a file that cannot be moved stays
  /// where it was.
  Future<void> migrateLegacyWindowsData() async {
    if (!_isWindows) return;
    try {
      final docs = (await _documents()).path;
      final root = await _dataRoot();
      if (p.equals(docs, root)) return;
      final dbDir = await databaseDir();
      final newDb = File(p.join(dbDir, '$databaseName.sqlite'));
      final oldDb = File(p.join(docs, '$databaseName.sqlite'));
      if (!await newDb.exists() && await oldDb.exists()) {
        // The main file first: the journal files are useless without it.
        if (await _move(oldDb, newDb.path)) {
          for (final suffix in const ['-wal', '-shm', '-journal']) {
            final f = File(p.join(docs, '$databaseName.sqlite$suffix'));
            if (await f.exists()) {
              await _move(f, p.join(dbDir, '$databaseName.sqlite$suffix'));
            }
          }
        }
      }
      final oldRec = Directory(p.join(docs, 'recordings'));
      if (await oldRec.exists()) {
        final newRec = await recordingsDir();
        await for (final e in oldRec.list(followLinks: false)) {
          if (e is! File) continue;
          final name = p.basename(e.path);
          if (!_meetingWavName.hasMatch(name)) continue;
          final dst = p.join(newRec, name);
          if (await File(dst).exists()) continue;
          await _move(e, dst);
        }
        if (await oldRec.list().isEmpty) await oldRec.delete();
      }
    } catch (_) {
      // Keep the old layout; [databaseDir] callers fall back to it.
    }
  }

  /// Moves [src] to [dst] (copy + delete across volumes). True on success.
  static Future<bool> _move(File src, String dst) async {
    try {
      await src.rename(dst);
      return true;
    } on FileSystemException {
      try {
        await src.copy(dst);
        await src.delete();
        return true;
      } on FileSystemException {
        try {
          final partial = File(dst);
          if (await partial.exists()) await partial.delete();
        } on FileSystemException {
          // Ignore.
        }
        return false;
      }
    }
  }
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
///
/// Throws [SecureStorageUnavailableException] when the keystore cannot be
/// read right now (the key may exist): callers postpone the run instead of
/// reporting a missing key (see [PostProcessor.generateMinutesIfPossible]).
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

/// Maximum audio (ms) waiting for live transcription before live submission
/// pauses (the meeting is then re-processed from the archive after
/// stopping). Bounds memory and the drain on stop. Overridable in tests.
final liveBacklogLimitMsProvider = Provider<int>((ref) => 15 * 60 * 1000);

// ---------------------------------------------------------------------------
// Recording session engines
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
    paths: ref.watch(appPathsProvider),
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
