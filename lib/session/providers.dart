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
// [minutesEngineFactoryProvider], [minutesBackendFactoryProvider],
// [secureSettingsProvider].

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/interfaces.dart';
import '../data/repositories.dart';
import '../data/repositories_v11.dart';
import '../data/secure_settings.dart';
import '../features/context/session_keyterms.dart';
import '../features/local_llm/local_minutes_backends.dart';
import '../features/multi_device/multi_device_providers.dart'
    show multiDeviceAwareSource, multiDeviceLogStoreProvider;
import '../features/phone_call/phone_call_providers.dart'
    show phoneCallAwareSource, phoneCallLogStoreProvider;
import '../features/official/official_service.dart'
    show officialMinutesServiceProvider;
import '../features/profiles/profile_service.dart'
    show speakerProfileServiceProvider;
import '../features/system_audio/mixed_session_audio_source.dart'
    show mixedSessionAudioSourceProvider;
import '../features/voice/mic_capture.dart' show inputDevicePreferencesProvider;
import '../minutes/export_service.dart';
import '../minutes/minutes_backend.dart';
import '../minutes/minutes_generator.dart';
import '../minutes/minutes_prompt.dart';
import '../speech/model_manager.dart';
import 'meeting_session_controller.dart';
import 'minutes_engines.dart';
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
export '../data/repositories_v11.dart';
export '../data/official_repository.dart';
export '../data/minutes_artifacts.dart' show minutesArtifactsWriterProvider;
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

  /// `<data root>/branding` (created on demand): the entity logo (v1.2).
  Future<String> brandingDir() async =>
      _ensure(p.join(await _dataRoot(), 'branding'));

  /// `<data root>/templates` (created on demand): uploaded Word templates
  /// (v1.2).
  Future<String> templatesDir() async =>
      _ensure(p.join(await _dataRoot(), 'templates'));

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

/// Creates the backend of the minutes engine selected in Settings (Gemini
/// by default, Claude, on-device or local server; see
/// [createMinutesBackend]). Also used by "Ask your meetings" (F8). The
/// caller closes the backend after use.
///
/// Throws `MinutesEngineNotReadyException` (no key, Gemini notice not
/// accepted, engine unavailable) and [SecureStorageUnavailableException]
/// (keystore locked).
final minutesBackendFactoryProvider =
    Provider<Future<MinutesBackend> Function()>((ref) {
      final secure = ref.watch(secureSettingsProvider);
      final settings = ref.watch(appSettingsProvider);
      final local = ref.watch(localMinutesBackendBuilderProvider);
      final server = ref.watch(serverMinutesBackendBuilderProvider);
      return () async => createMinutesBackend(
        settings: await settings.load(),
        secure: secure,
        local: local,
        server: server,
        onGeminiModelDiscovered: (model) {
          // Remember the model that works for this key; ignore storage errors.
          settings.setGeminiModel(model).catchError((Object _) {});
        },
      );
    });

/// Creates the minutes engine selected in Settings with the user's detail
/// level (see [minutesBackendFactoryProvider]).
///
/// Throws `MinutesEngineNotReadyException` when the engine cannot be used
/// yet and [SecureStorageUnavailableException] when the keystore cannot be
/// read right now (the key may exist): callers postpone the run instead of
/// reporting a missing key (see [PostProcessor.generateMinutesIfPossible]).
final minutesEngineFactoryProvider = Provider<MinutesEngineFactory>((ref) {
  final backendFactory = ref.watch(minutesBackendFactoryProvider);
  final settings = ref.watch(appSettingsProvider);
  return () async {
    final backend = await backendFactory();
    final s = await settings.load();
    return MinutesEngineHandle(
      StructuredMinutesEngine(
        backend: backend,
        detailLevel: MinutesDetailLevel.parse(s.minutesDetail),
      ),
      release: backend.close,
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
  final glossary = ref.watch(glossaryRepositoryProvider);
  final speakers = ref.watch(speakerRepositoryProvider);
  return SherpaSessionEnginesFactory(
    modelManager: () => ref.read(modelManagerProvider.future),
    secureSettings: ref.watch(secureSettingsProvider),
    // F2 / F3: Deepgram keyterms — the meeting-only terms and expected
    // attendees of the meeting being started (its id does not exist yet),
    // the names of user-named speakers and the global glossary.
    keyterms: () => resolveSessionKeyterms(
      glossary: glossary,
      speakers: speakers,
      upcoming: ref.read(upcomingMeetingSetupProvider),
    ),
  );
});

/// Audio capture used by recording sessions: the F18 device-aware
/// microphone (remembered input device, far field, fallback to the default
/// microphone), mixed with the system audio on Windows (F13) as the
/// audio-source setting says.
///
/// v1.2 C: while a multi-device lobby is open the source also records the
/// guests ([multiDeviceAwareSource]).
///
/// Phone-call mode: while a call setup is armed the source is the Phone Link
/// (two channels) or speakerphone source instead ([phoneCallAwareSource]).
final sessionAudioSourceProvider = Provider<SessionAudioSource>(
  (ref) => phoneCallAwareSource(
    ref,
    () =>
        multiDeviceAwareSource(ref, ref.watch(mixedSessionAudioSourceProvider)),
  ),
);

/// Resolves the key of the microphone a new recording will use
/// (`Meeting.inputDevice`, F18; null = system default). Overridable in
/// tests. Never throws.
final sessionInputDeviceProvider = Provider<Future<String?> Function()>((ref) {
  final prefs = ref.watch(inputDevicePreferencesProvider);
  return () async {
    try {
      return (await prefs.load()).key;
    } catch (_) {
      return null;
    }
  };
});

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
    // F16: merge the new speaker notes into opted-in speakers' profiles.
    onMinutesSaved: (id) async {
      // v1.2: regenerated minutes of an approved meeting become a new draft
      // version (the approved one stays in the history).
      try {
        await ref.read(officialMinutesServiceProvider).onMinutesChanged(id);
      } catch (_) {
        // Best effort; the official screen detects a changed hash too.
      }
      await ref.read(speakerProfileServiceProvider).updateAfterMeeting(id);
    },
    // F16: a deleted meeting leaves the stored profiles.
    onMeetingDeleted: (id) =>
        ref.read(speakerProfileServiceProvider).updateAfterMeeting(id),
    // v1.2 C: nearest-device cue of multi-device meetings.
    // Phone-call mode: the side of each segment is a hard partition.
    channelProfilesOf: (id) async => {
      ...await ref.read(multiDeviceLogStoreProvider).profiles(id),
      ...await ref.read(phoneCallLogStoreProvider).partitions(id),
    },
    // Phone-call mode: remote voices in the minutes, telephone voiceprints.
    callHintOf: (id) => ref.read(phoneCallLogStoreProvider).minutesHint(id),
    segmentVoiceDevicesOf: (id) =>
        ref.read(phoneCallLogStoreProvider).segmentVoiceDevices(id),
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
