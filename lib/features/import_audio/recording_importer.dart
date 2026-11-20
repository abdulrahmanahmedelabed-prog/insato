// Imports an existing audio file (phone-call recording, voice memo, Zoom
// download, …) as a meeting and runs exactly the pipeline of a recorded
// meeting over it:
//
//   check file (size, magic bytes) → speech engines ready?
//   → create meeting (status processing, title / date from the file,
//     Meeting.inputDevice = kImportedInputDevice)
//   → decode to 16 kHz mono and archive as recordings/<id>.wav
//   → PostProcessor.reprocessFromAudio (VAD → ASR of the selected engine +
//     speaker embeddings → SpeakerTracker against voiceprints → offline
//     refinement → voiceprint learning)
//   → the WAV is dropped again when "keep audio" is off
//
// Minutes are written afterwards by the caller (MeetingJobsController), so
// the v1.1 / v1.2 steps (tasks, codes, official minutes, consistency check)
// run as for any meeting. Cancelling, or a failure before the transcript
// exists, deletes the new meeting and its files; a transcription failure
// keeps the meeting with its audio so it can be re-processed later.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../audio/wav_writer.dart';
import '../../core/errors.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../data/secure_settings.dart';
import '../../session/meeting_session_controller.dart';
import '../../session/post_processor.dart';
import '../../session/providers.dart' show recordingFileName;
import 'audio_decoder.dart';
import 'audio_formats.dart';
import 'import_metadata.dart';
import 'import_store.dart';
import 'strings.dart';

/// What to import.
class ImportRequest {
  /// Creates a request.
  const ImportRequest({
    required this.path,
    String? displayName,
    this.title,
    this.viaShare = false,
    this.deleteSourceWhenDone = false,
  }) : displayName = displayName ?? '';

  /// Readable path of the file (a picker / share copy is fine).
  final String path;

  /// Original file name (the path's base name when empty).
  final String displayName;

  /// Meeting title chosen by the user (null / blank = suggested).
  final String? title;

  /// Received through the OS share sheet / "open in".
  final bool viaShare;

  /// Delete [path] afterwards (a temporary copy made for the import).
  final bool deleteSourceWhenDone;

  /// The file name shown to the user.
  String get fileName =>
      displayName.trim().isEmpty ? p.basename(path) : displayName.trim();
}

/// Stage of a running import.
enum ImportStage {
  /// Checking the file and the speech engines.
  checking,

  /// Converting the audio.
  decoding,

  /// Transcription and speaker identification.
  transcribing,
}

/// Progress of a running import.
class ImportProgress {
  /// Creates a progress value.
  const ImportProgress(this.stage, this.fraction, this.statusAr);

  /// Stage.
  final ImportStage stage;

  /// Overall progress 0..1.
  final double fraction;

  /// Arabic status line.
  final String statusAr;
}

/// Cooperative cancellation of an import.
class ImportCancelToken {
  bool _cancelled = false;

  /// True once [cancel] was called.
  bool get isCancelled => _cancelled;

  /// Requests cancellation.
  void cancel() => _cancelled = true;

  /// Throws [OperationCancelledException] when cancelled.
  void throwIfCancelled() {
    if (_cancelled) throw const OperationCancelledException();
  }
}

/// Result of a successful import.
class ImportOutcome {
  /// Creates the outcome.
  const ImportOutcome({
    required this.meetingId,
    required this.durationMs,
    required this.segments,
    required this.failedSegments,
    required this.container,
  });

  /// The new meeting.
  final String meetingId;

  /// Audio duration.
  final int durationMs;

  /// Transcript segments.
  final int segments;

  /// Speech segments that could not be transcribed.
  final int failedSegments;

  /// Detected format.
  final AudioContainer container;
}

/// Share of the overall progress taken by decoding (transcription takes
/// the rest; decoding is much faster than speech recognition).
const double kDecodeProgressShare = 0.15;

/// The Arabic status of the transcription stage from the post-processor's
/// own progress [p] (0..1, see `PostProcessor.reprocessFromAudio`: models
/// up to 0.05, audio analysis to 0.8, completion to 0.9, speakers after).
String transcriptionStatus(double p) {
  if (p < 0.05) return IS.loadingModels;
  if (p < 0.8) {
    final pct = ((p - 0.05) / 0.75 * 100).clamp(0, 100).round();
    return IS.transcribing(pct);
  }
  if (p < 0.95) return IS.finishing;
  return IS.speakers;
}

/// Imports recordings (see the file comment). One import at a time is
/// enforced by the caller.
class RecordingImporter {
  /// Creates the importer.
  RecordingImporter({
    required this._meetings,
    required this._post,
    required this._settings,
    required this._engines,
    required this._recordingsDir,
    required this._store,
    this._decoder = const ImportAudioDecoder(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MeetingRepository _meetings;
  final PostProcessor _post;
  final AppSettings _settings;
  final SessionEnginesFactory _engines;
  final Future<String> Function() _recordingsDir;
  final ImportInfoStore _store;
  final ImportAudioDecoder _decoder;
  final DateTime Function() _now;

  /// Imports [request]. Throws [ImportException] for refused files,
  /// [OperationCancelledException] when [cancel] was used, and the
  /// pipeline's [InsatoException]s (models missing, API key, …).
  /// [onMeetingCreated] reports the new meeting's id as soon as it exists
  /// (it is deleted again when the import is cancelled or the audio cannot
  /// be decoded, and kept when only the transcription failed).
  Future<ImportOutcome> importFile(
    ImportRequest request, {
    void Function(ImportProgress progress)? onProgress,
    ImportCancelToken? cancel,
    void Function(String meetingId)? onMeetingCreated,
  }) async {
    final token = cancel ?? ImportCancelToken();
    void report(ImportStage stage, double f, String s) =>
        onProgress?.call(ImportProgress(stage, f.clamp(0.0, 1.0), s));

    try {
      report(ImportStage.checking, 0, IS.checking);
      final file = File(request.path);
      final (container, size, modified) = await _check(file, request.fileName);
      token.throwIfCancelled();

      final settings = await _settings.load();
      // Fail early (no meeting created) when the speech models are missing
      // or the cloud key is not set.
      await _engines.ensureReady(SessionEngineRequest.fromSettings(settings));
      token.throwIfCancelled();

      final audio = await _decoder.open(request.path, container);
      final declared = audio.durationMs;
      if (declared != null && declared > kMaxImportDuration.inMilliseconds) {
        await audio.close();
        throw ImportException(
          ImportFailure.tooLong,
          IS.tooLong(kMaxImportDuration.inHours),
        );
      }

      final recordedAt = resolveRecordingTime(
        containerDate: audio.creationDate,
        fileName: request.fileName,
        modified: modified,
        now: _now(),
      );
      final chosen = request.title?.trim();
      final Meeting meeting;
      try {
        meeting = await _meetings.create(
          title: (chosen == null || chosen.isEmpty)
              ? suggestImportTitle(request.fileName, recordedAt)
              : chosen,
          createdAt: recordedAt,
          status: MeetingStatus.processing,
          inputDevice: kImportedInputDevice,
        );
      } catch (_) {
        await _closeAudioQuietly(audio);
        rethrow;
      }
      onMeetingCreated?.call(meeting.id);
      return await _process(
        request,
        meeting,
        audio,
        container,
        size,
        settings,
        token,
        report,
      );
    } finally {
      if (request.deleteSourceWhenDone) {
        try {
          final f = File(request.path);
          if (await f.exists()) await f.delete();
        } on FileSystemException {
          // A temporary copy; the OS cleans its cache eventually.
        }
      }
    }
  }

  Future<ImportOutcome> _process(
    ImportRequest request,
    Meeting meeting,
    DecodedAudio audio,
    AudioContainer container,
    int size,
    AppSettingsData settings,
    ImportCancelToken token,
    void Function(ImportStage, double, String) report,
  ) async {
    final id = meeting.id;
    final fileName = recordingFileName(id);
    String? wavPath;
    var transcribing = false;
    try {
      await _store.save(
        id,
        ImportInfo(
          fileName: request.fileName,
          format: container.label,
          codec: audio.codec,
          sourceSampleRate: audio.sourceSampleRate,
          sourceChannels: audio.sourceChannels,
          sizeBytes: size,
          importedAt: _now(),
          callRecording: looksLikeCallRecording(request.fileName),
          viaShare: request.viaShare,
        ),
      );
      wavPath = p.join(await _recordingsDir(), fileName);
      final durationMs = await _decodeToWav(
        audio,
        wavPath,
        token,
        (decodedMs) {
          final total = audio.durationMs;
          if (total != null && total > 0) {
            final f = math.min(1.0, decodedMs / total);
            report(
              ImportStage.decoding,
              kDecodeProgressShare * f,
              IS.decoding((f * 100).round()),
            );
          } else {
            report(
              ImportStage.decoding,
              kDecodeProgressShare / 2,
              IS.decodingMinutes(decodedMs ~/ 60000),
            );
          }
        },
      );
      await _meetings.setAudioPath(id, fileName);
      await _meetings.setDuration(id, durationMs);
      token.throwIfCancelled();

      transcribing = true;
      final report0 = await _post.reprocessFromAudio(
        id,
        isCancelled: () => token.isCancelled,
        onProgress: (p, _) => report(
          ImportStage.transcribing,
          kDecodeProgressShare + (1 - kDecodeProgressShare) * p,
          transcriptionStatus(p),
        ),
      );
      if (!settings.keepAudio) {
        await _meetings.setAudioPath(id, null);
        await _deleteQuietly(wavPath);
      }
      return ImportOutcome(
        meetingId: id,
        durationMs: math.max(durationMs, report0.durationMs),
        segments: report0.segments,
        failedSegments: report0.failedSegments,
        container: container,
      );
    } on OperationCancelledException {
      await _closeAudioQuietly(audio);
      await _discard(id, wavPath);
      rethrow;
    } catch (e) {
      if (!transcribing) {
        await _closeAudioQuietly(audio);
        await _discard(id, wavPath);
        if (e is InsatoException) rethrow;
        throw ImportException(
          ImportFailure.decodeFailed,
          IS.decodeFailed,
          debugDetails: '$e',
          cause: e,
        );
      }
      // The audio is archived: keep the meeting so the user can re-process
      // it (models downloaded later, network back).
      final reason = e is InsatoException ? e.messageAr : IS.unexpected;
      try {
        await _meetings.setError(id, IS.transcriptionFailed(reason));
      } catch (_) {
        // The meeting may be gone (deleted meanwhile).
      }
      if (e is InsatoException) rethrow;
      throw InsatoException(IS.unexpected, debugDetails: '$e', cause: e);
    }
  }

  /// Validates [file]: exists, readable, not empty, not too large, audio.
  Future<(AudioContainer, int, DateTime?)> _check(
    File file,
    String fileName,
  ) async {
    final int size;
    DateTime? modified;
    try {
      if (!await file.exists()) {
        throw const ImportException(ImportFailure.notFound, IS.notFound);
      }
      size = await file.length();
      try {
        modified = await file.lastModified();
      } on FileSystemException {
        modified = null;
      }
    } on FileSystemException catch (e) {
      throw ImportException(
        ImportFailure.unreadable,
        IS.unreadable,
        debugDetails: e.message,
        cause: e,
      );
    }
    if (size == 0) {
      throw const ImportException(ImportFailure.empty, IS.emptyFile);
    }
    if (size > kMaxImportBytes) {
      throw ImportException(
        ImportFailure.tooLarge,
        IS.tooLarge(kMaxImportBytes ~/ (1024 * 1024 * 1024)),
      );
    }
    final Uint8List head;
    try {
      final raf = await file.open();
      try {
        head = await raf.read(64);
      } finally {
        await raf.close();
      }
    } on FileSystemException catch (e) {
      throw ImportException(
        ImportFailure.unreadable,
        IS.unreadable,
        debugDetails: e.message,
        cause: e,
      );
    }
    final container = detectAudioContainer(head, fileName);
    if (container == null) {
      throw const ImportException(ImportFailure.notAudio, IS.notAudio);
    }
    return (container, size, modified);
  }

  /// Streams [audio] into a 16 kHz mono WAV at [path]; returns its duration
  /// in milliseconds.
  Future<int> _decodeToWav(
    DecodedAudio audio,
    String path,
    ImportCancelToken token,
    void Function(int decodedMs) onDecoded,
  ) async {
    final WavWriter writer;
    try {
      writer = await WavWriter.open(path);
    } on FileSystemException catch (e) {
      await audio.close();
      throw _writeError(e);
    }
    var samples = 0;
    var lastReport = -1;
    const maxSamples = 8 * 3600 * kSampleRate;
    try {
      await for (final chunk in audio.samples()) {
        token.throwIfCancelled();
        if (chunk.isEmpty) continue;
        samples += chunk.length;
        if (samples > maxSamples + kSampleRate) {
          throw ImportException(
            ImportFailure.tooLong,
            IS.tooLong(kMaxImportDuration.inHours),
          );
        }
        await writer.appendFloat32(chunk);
        final ms = samples * 1000 ~/ kSampleRate;
        // One progress event per 30 s of decoded audio.
        if (ms ~/ 30000 != lastReport) {
          lastReport = ms ~/ 30000;
          onDecoded(ms);
        }
      }
    } on FileSystemException catch (e) {
      await _closeQuietly(writer);
      throw _writeError(e);
    } catch (_) {
      await _closeQuietly(writer);
      rethrow;
    }
    try {
      await writer.close();
    } on FileSystemException catch (e) {
      throw _writeError(e);
    }
    final ms = samples * 1000 ~/ kSampleRate;
    onDecoded(ms);
    if (ms < kMinImportDuration.inMilliseconds) {
      throw const ImportException(ImportFailure.tooShort, IS.tooShort);
    }
    return ms;
  }

  static ImportException _writeError(FileSystemException e) {
    // ENOSPC (28 on Linux / Android / iOS) and ERROR_DISK_FULL (112) /
    // ERROR_HANDLE_DISK_FULL (39) on Windows.
    final code = e.osError?.errorCode;
    final full = code == 28 || code == 112 || code == 39;
    return ImportException(
      full ? ImportFailure.noSpace : ImportFailure.unreadable,
      full ? IS.noSpace : IS.unreadable,
      debugDetails: e.toString(),
      cause: e,
    );
  }

  static Future<void> _closeAudioQuietly(DecodedAudio audio) async {
    try {
      await audio.close();
    } catch (_) {
      // Already released.
    }
  }

  static Future<void> _closeQuietly(WavWriter w) async {
    try {
      await w.close();
    } catch (_) {
      // The file is deleted next.
    }
  }

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Best effort.
    }
  }

  /// Deletes the meeting created by a cancelled / failed import and its
  /// archived audio.
  Future<void> _discard(String meetingId, String? wavPath) async {
    try {
      await _post.deleteMeeting(meetingId);
    } catch (_) {
      // Fall through to the file.
    }
    await _deleteQuietly(wavPath);
  }
}
