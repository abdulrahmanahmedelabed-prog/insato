// Export, import and merge of meeting packages (see package_format.dart for
// the file and merge_planner.dart for the merge rules).

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/errors.dart';
import '../../core/models.dart';
import '../../data/database.dart';
import '../../data/meeting_package_store.dart';
import '../../data/repositories.dart';
import '../../data/secure_settings.dart';
import 'merge_planner.dart';
import 'package_audio.dart';
import 'package_codec.dart';
import 'package_crypto.dart' show kPackageKdfIterations;
import 'package_format.dart';
import 'strings.dart';

const Uuid _uuid = Uuid();

/// What to put in an exported package.
class PackageExportOptions {
  /// Creates the options. Voiceprints are biometric data: off by default.
  const PackageExportOptions({
    this.includeAudio = true,
    this.includeVoiceprints = false,
    this.includeMinutes = true,
    this.password,
  });

  /// Include the recording.
  final bool includeAudio;

  /// Include speaker voiceprints and segment embeddings.
  final bool includeVoiceprints;

  /// Include the minutes.
  final bool includeMinutes;

  /// Encrypt with this password (null / empty: not encrypted).
  final String? password;
}

/// An exported package ready to be shared or saved.
class ExportedPackage {
  /// Creates the result.
  const ExportedPackage({required this.bytes, required this.fileName});

  /// File content.
  final Uint8List bytes;

  /// Suggested file name (`….insato`).
  final String fileName;
}

/// What merging a package into a meeting would do.
class MergePreview {
  /// Creates a preview.
  const MergePreview({
    required this.package,
    required this.target,
    required this.alignment,
    required this.overlapMs,
    required this.plan,
    required this.speakers,
  });

  /// The package.
  final MeetingPackage package;

  /// Meeting merged into.
  final Meeting target;

  /// Where the package's recording sits on the meeting's timeline.
  final RecordingAlignment alignment;

  /// Overlap of the two recordings (ms).
  final int overlapMs;

  /// The merge plan.
  final MergePlan plan;

  /// Remote speaker key → mapping.
  final Map<String, SpeakerMapping> speakers;

  /// Speakers matched in the voice library.
  int get matchedSpeakers => speakers.values.where((m) => !m.creates).length;

  /// Speakers to be created.
  int get newSpeakers => speakers.values.where((m) => m.creates).length;
}

/// Outcome of a merge.
class MergeResult {
  /// Creates the result.
  const MergeResult({
    required this.preview,
    required this.insertedSegments,
    required this.refined,
  });

  /// What was planned.
  final MergePreview preview;

  /// Segments added.
  final int insertedSegments;

  /// Speaker refinement ran without error.
  final bool refined;
}

/// Progress callback (0..1, Arabic status).
typedef PackageProgress = void Function(double progress, String statusAr);

/// Creates, reads and merges meeting packages.
class MeetingPackageService {
  /// Creates the service.
  ///
  /// [recordingsDir]: where recordings live (`AppPaths.recordingsDir`);
  /// [resolveRecording]: resolves a stored `Meeting.audioPath`;
  /// [refine]: speaker refinement after a merge / import
  /// (`PostProcessor.refine`); [isMeetingActive]: true while a meeting is
  /// being recorded.
  MeetingPackageService({
    required AppDatabase db,
    required this._meetings,
    required this._segments,
    required this._speakers,
    required this._settings,
    required this._recordingsDir,
    Future<String> Function(String stored)? resolveRecording,
    this._refine,
    bool Function(String meetingId)? isMeetingActive,
    required this._device,
    required this._appVersion,
    bool runInBackground = true,
    this.kdfIterations = kPackageKdfIterations,
  }) : _db = db,
       _resolve = resolveRecording,
       _isActive = isMeetingActive ?? ((_) => false),
       _background = runInBackground,
       _store = MeetingPackageStore(db);

  final AppDatabase _db;
  final MeetingRepository _meetings;
  final SegmentRepository _segments;
  final SpeakerRepository _speakers;
  final AppSettings _settings;
  final Future<String> Function() _recordingsDir;
  final Future<String> Function(String stored)? _resolve;
  final Future<void> Function(String meetingId)? _refine;
  final bool Function(String meetingId) _isActive;
  final PackageDevice _device;
  final String _appVersion;
  final bool _background;

  /// PBKDF2 iterations of encrypted exports.
  final int kdfIterations;
  final MeetingPackageStore _store;

  /// The undo store.
  MeetingPackageStore get store => _store;

  /// Runs top-level [f] on [arg], in a background isolate unless the
  /// service was created for tests. ([f] must not be a closure over this
  /// service: only [arg] is sent.)
  Future<T> _work<A, T>(Future<T> Function(A) f, A arg, String name) =>
      _background ? _isolated(f, arg, name) : f(arg);

  Future<String?> _audioFileOf(Meeting m) async {
    final stored = m.audioPath;
    if (stored == null || stored.isEmpty) return null;
    final resolve = _resolve;
    final path = resolve == null
        ? (p.isAbsolute(stored)
              ? stored
              : p.join(await _recordingsDir(), stored))
        : await resolve(stored);
    return await File(path).exists() ? path : null;
  }

  // -------------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------------

  /// Builds the package of [meetingId] (not yet encoded).
  Future<MeetingPackage> buildPackage(
    String meetingId,
    PackageExportOptions options, {
    PackageProgress? onProgress,
  }) async {
    final m = await _meetings.get(meetingId);
    if (m == null) throw const InsatoException(PS.meetingMissing);
    if (_isActive(meetingId) || m.status == MeetingStatus.recording) {
      throw const InsatoException(PS.stillRecording);
    }
    onProgress?.call(0.05, PS.progressReading);
    final segs = await _segments.getForMeeting(meetingId);
    final speakersById = await _speakers.getAllById();
    final wav = await _audioFileOf(m);

    // Per-segment SNR from the recording (kept even without the audio: the
    // merging device uses it to choose between duplicate texts).
    final snr = <String, double>{};
    if (wav != null) {
      onProgress?.call(0.2, PS.progressAnalysing);
      final ranges = [for (final s in segs) (s.id, s.startMs, s.endMs)];
      final values = await _work(_snrTask, (wav, ranges), 'insato-package-snr');
      snr.addAll(values);
    }
    final used = <String>{for (final s in segs) ?s.speakerId};
    final speakers = [
      for (final id in used)
        if (speakersById[id] case final sp?)
          PackageSpeaker(
            key: sp.id,
            name: sp.name,
            colorValue: sp.colorValue,
            isNamedByUser: sp.isNamedByUser,
            centroid: options.includeVoiceprints && !sp.lowConfidence
                ? sp.centroid
                : null,
            embeddingCount: sp.embeddingCount,
          ),
    ];
    final audioBytes = options.includeAudio && wav != null
        ? await File(wav).readAsBytes()
        : null;
    var duration = m.durationMs;
    for (final s in segs) {
      duration = math.max(duration, s.endMs);
    }
    return MeetingPackage(
      manifest: PackageManifest(
        appVersion: _appVersion,
        schemaVersion: AppDatabase.currentSchemaVersion,
        exportedAt: DateTime.now(),
        exportedMonotonicUs: _monotonic.elapsedMicroseconds,
        device: _device,
        meetingId: m.id,
        title: m.title,
        startedAt: m.createdAt,
        durationMs: duration,
        includes: PackageIncludes(
          audio: audioBytes != null,
          voiceprints: options.includeVoiceprints,
          minutes: options.includeMinutes && m.minutes != null,
        ),
        context: m.context,
        inputDevice: m.inputDevice,
      ),
      segments: [
        for (final s in segs)
          PackageSegment(
            index: s.index,
            startMs: s.startMs,
            endMs: s.endMs,
            text: s.text,
            speakerKey: s.speakerId,
            language: s.language,
            kind: s.kind,
            asrConfidence: s.asrConfidence,
            speakerConfidence: s.speakerConfidence,
            speakerLocked: s.speakerLocked,
            snrDb: snr[s.id],
            embedding: options.includeVoiceprints ? s.embedding : null,
          ),
      ],
      speakers: speakers,
      minutes: options.includeMinutes ? m.minutes : null,
      audioWav: audioBytes,
    );
  }

  /// Exports [meetingId] as `.insato` bytes.
  Future<ExportedPackage> export(
    String meetingId,
    PackageExportOptions options, {
    PackageProgress? onProgress,
    int? kdfIterations,
  }) async {
    final pkg = await buildPackage(meetingId, options, onProgress: onProgress);
    onProgress?.call(
      0.5,
      options.password?.isNotEmpty == true
          ? PS.progressEncrypting
          : PS.progressPacking,
    );
    final password = options.password;
    final bytes = _background
        ? await encodeMeetingPackageInBackground(
            pkg,
            password: password,
            kdfIterations: kdfIterations ?? this.kdfIterations,
          )
        : await encodeMeetingPackage(
            pkg,
            password: password,
            kdfIterations: kdfIterations ?? this.kdfIterations,
          );
    onProgress?.call(1, PS.progressDone);
    return ExportedPackage(
      bytes: bytes,
      fileName: packageFileName(pkg.manifest.title, pkg.manifest.startedAt),
    );
  }

  // -------------------------------------------------------------------------
  // Import
  // -------------------------------------------------------------------------

  /// Decodes [bytes] (see [decodeMeetingPackage]).
  Future<MeetingPackage> open(Uint8List bytes, {String? password}) =>
      _background
      ? decodeMeetingPackageInBackground(bytes, password: password)
      : decodeMeetingPackage(bytes, password: password);

  /// Creates a new meeting from [pkg]. Returns its id.
  Future<String> importAsNewMeeting(
    MeetingPackage pkg, {
    PackageProgress? onProgress,
  }) async {
    onProgress?.call(0.1, PS.progressImporting);
    final mf = pkg.manifest;
    final meeting = await _meetings.create(
      title: mf.title,
      createdAt: mf.startedAt,
      status: MeetingStatus.processing,
      context: mf.context,
    );
    try {
      if (pkg.audioWav != null) {
        final name = '${meeting.id}.wav';
        await File(p.join(await _recordingsDir(), name))
            .writeAsBytes(pkg.audioWav!, flush: true);
        await _meetings.setAudioPath(meeting.id, name);
      }
      await _meetings.setDuration(meeting.id, pkg.effectiveDurationMs);
      final mapping = await _mapSpeakers(pkg);
      final ids = await _createSpeakers(mapping);
      final ordered = [...pkg.segments]
        ..sort((a, b) {
          final c = a.startMs.compareTo(b.startMs);
          return c != 0 ? c : a.index.compareTo(b.index);
        });
      await _segments.insertAll([
        for (var i = 0; i < ordered.length; i++)
          _remoteSegment(
            meeting.id,
            ordered[i],
            i,
            ordered[i].startMs,
            ordered[i].endMs,
            ids,
          ),
      ]);
      if (pkg.minutes != null) {
        await _meetings.saveMinutes(meeting.id, pkg.minutes!);
      } else {
        await _meetings.updateStatus(meeting.id, MeetingStatus.ready);
      }
      onProgress?.call(0.7, PS.progressRefining);
      await _tryRefine(meeting.id);
      onProgress?.call(1, PS.progressDone);
      return meeting.id;
    } catch (_) {
      await _meetings.delete(meeting.id);
      rethrow;
    }
  }

  Future<Map<String, SpeakerMapping>> _mapSpeakers(MeetingPackage pkg) async {
    final settings = await _settings.load();
    return mapRemoteSpeakers(
      remote: pkg.speakers,
      library: await _speakers.getAll(),
      deviceName: pkg.manifest.device.name,
      matchThreshold: math.min(0.95, settings.matchThreshold + 0.05),
    );
  }

  /// Creates the speakers [mapping] asks for. Returns key → speaker id.
  Future<Map<String, String>> _createSpeakers(
    Map<String, SpeakerMapping> mapping, {
    List<String>? created,
  }) async {
    final out = <String, String>{};
    for (final e in mapping.entries) {
      final m = e.value;
      if (!m.creates) {
        out[e.key] = m.speakerId!;
        continue;
      }
      final sp = await _speakers.create(
        name: m.newName,
        isNamedByUser: m.newNamedByUser,
        centroid: m.centroid,
        embeddingCount: m.embeddingCount,
      );
      created?.add(sp.id);
      out[e.key] = sp.id;
    }
    return out;
  }

  TranscriptSegment _remoteSegment(
    String meetingId,
    PackageSegment s,
    int index,
    int startMs,
    int endMs,
    Map<String, String> speakerIds,
  ) {
    final speaker = s.speakerKey == null ? null : speakerIds[s.speakerKey];
    final hasEmbedding = s.embedding != null && s.embedding!.isNotEmpty;
    return TranscriptSegment(
      id: '',
      meetingId: meetingId,
      index: index,
      startMs: startMs,
      endMs: endMs,
      text: s.text,
      speakerId: speaker,
      language: s.language,
      embedding: hasEmbedding ? s.embedding : null,
      // Without an embedding the refinement cannot re-cluster the segment:
      // the remote device's attribution is kept as is (locked), so its
      // speaker is never mistaken for a disposable live label.
      speakerLocked: s.speakerLocked || (speaker != null && !hasEmbedding),
      kind: s.kind,
      asrConfidence: s.asrConfidence,
      speakerConfidence: s.speakerConfidence,
    );
  }

  Future<bool> _tryRefine(String meetingId) async {
    final refine = _refine;
    if (refine == null) return true;
    try {
      await refine(meetingId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Merge
  // -------------------------------------------------------------------------

  Future<String?> _writeRemoteWav(MeetingPackage pkg) async {
    final wav = pkg.audioWav;
    if (wav == null) return null;
    final path = p.join(await _recordingsDir(), 'import-${_uuid.v4()}.wav');
    await File(path).writeAsBytes(wav, flush: true);
    return path;
  }

  /// What merging [pkg] into [meetingId] would do (alignment, duplicates,
  /// speakers). Nothing is written.
  Future<MergePreview> previewMerge(
    String meetingId,
    MeetingPackage pkg, {
    PackageProgress? onProgress,
  }) async {
    final remoteWav = await _writeRemoteWav(pkg);
    try {
      return await _preview(meetingId, pkg, remoteWav, onProgress);
    } finally {
      await _deleteQuietly(remoteWav);
    }
  }

  Future<MergePreview> _preview(
    String meetingId,
    MeetingPackage pkg,
    String? remoteWav,
    PackageProgress? onProgress,
  ) async {
    final target = await _meetings.get(meetingId);
    if (target == null) throw const InsatoException(PS.meetingMissing);
    if (_isActive(meetingId) ||
        target.status == MeetingStatus.recording ||
        target.status == MeetingStatus.processing) {
      throw const InsatoException(PS.stillRecording);
    }
    onProgress?.call(0.1, PS.progressAligning);
    final mainSegs = await _segments.getForMeeting(meetingId);
    final mainWav = await _audioFileOf(target);
    final wallClock = pkg.manifest.startedAt
        .difference(target.createdAt)
        .inMilliseconds;
    final mainRanges = [for (final s in mainSegs) (s.id, s.startMs, s.endMs)];
    final remoteRanges = [
      for (var i = 0; i < pkg.segments.length; i++)
        (i, pkg.segments[i].startMs, pkg.segments[i].endMs),
    ];
    final analysis = await _work(_analysisTask, (
      mainWav: mainWav,
      remoteWav: remoteWav,
      wallClockOffsetMs: wallClock,
      mainRanges: mainRanges,
      remoteRanges: remoteRanges,
      mainDurationMs: target.durationMs,
    ), 'insato-package-align');
    onProgress?.call(0.5, PS.progressPlanning);
    final remote = [
      for (var i = 0; i < pkg.segments.length; i++)
        _withSnr(
          pkg.segments[i],
          pkg.segments[i].snrDb ?? analysis.remoteSnr[i],
        ),
    ];
    final remoteMs = analysis.remoteMs ?? pkg.effectiveDurationMs;
    final plan = planMerge(
      main: [
        for (final s in mainSegs) (segment: s, snrDb: analysis.mainSnr[s.id]),
      ],
      remote: remote,
      offsetMs: analysis.alignment.offsetMs,
      sameRoom: analysis.alignment.sameRoom,
      mainDurationMs: math.max(target.durationMs, analysis.mainMs),
      remoteDurationMs: remoteMs,
    );
    return MergePreview(
      package: pkg,
      target: target,
      alignment: analysis.alignment,
      overlapMs: overlapMs(
        math.max(target.durationMs, analysis.mainMs),
        remoteMs,
        analysis.alignment.offsetMs,
      ),
      plan: plan,
      speakers: await _mapSpeakers(pkg),
    );
  }

  static PackageSegment _withSnr(PackageSegment s, double? snr) =>
      PackageSegment(
        index: s.index,
        startMs: s.startMs,
        endMs: s.endMs,
        text: s.text,
        speakerKey: s.speakerKey,
        language: s.language,
        kind: s.kind,
        asrConfidence: s.asrConfidence,
        speakerConfidence: s.speakerConfidence,
        speakerLocked: s.speakerLocked,
        snrDb: snr,
        embedding: s.embedding,
      );

  /// Merges [pkg] into [meetingId] (a snapshot is kept for [undoLastMerge]),
  /// then re-runs the speaker refinement.
  Future<MergeResult> merge(
    String meetingId,
    MeetingPackage pkg, {
    PackageProgress? onProgress,
  }) async {
    final remoteWav = await _writeRemoteWav(pkg);
    String? mergedName;
    final created = <String>[];
    var committed = false;
    try {
      final preview = await _preview(meetingId, pkg, remoteWav, onProgress);
      onProgress?.call(0.6, PS.progressMerging);
      final target = preview.target;
      final plan = preview.plan;
      final snapshot = await _store.capture(
        meetingId,
        deviceName: pkg.manifest.device.name,
      );
      final mainSegs = await _segments.getForMeeting(meetingId);

      // Merged recording: needed when the remote audio comes in, or when
      // the main timeline moves (the remote recording started earlier).
      final mainWav = await _audioFileOf(target);
      if (remoteWav != null || (plan.shiftMs > 0 && mainWav != null)) {
        mergedName =
            '$meetingId-merged-${DateTime.now().millisecondsSinceEpoch}.wav';
        final out = p.join(await _recordingsDir(), mergedName);
        final shiftSamples = plan.shiftMs * kSampleRate ~/ 1000;
        final remoteStart =
            (preview.alignment.offsetMs + plan.shiftMs) * kSampleRate ~/ 1000;
        final mode = preview.alignment.sameRoom
            ? AudioMergeMode.preferMain
            : AudioMergeMode.mix;
        await _work(_mergeAudioTask, (
          outPath: out,
          mainWav: mainWav,
          mainStart: shiftSamples,
          remoteWav: remoteWav,
          remoteStart: remoteStart,
          mode: mode,
        ), 'insato-package-audio');
      }

      onProgress?.call(0.75, PS.progressMerging);
      final speakerIds = await _createSpeakers(
        preview.speakers,
        created: created,
      );
      final remap = plan.indexRemap(mainSegs);
      final inserted = <String>[];
      await _db.transaction(() async {
        final replacements = {
          for (final r in plan.replacements) r.mainSegmentId: r.source,
        };
        for (final s in mainSegs) {
          final (start, end) = plan.mainTimes[s.id]!;
          final r = replacements[s.id];
          await (_db.update(
            _db.segments,
          )..where((t) => t.id.equals(s.id))).write(
            SegmentsCompanion(
              idx: Value(plan.mainIndex[s.id]!),
              startMs: Value(start),
              endMs: Value(end),
              body: r == null ? const Value.absent() : Value(r.text),
              language: r == null
                  ? const Value.absent()
                  : Value(r.language ?? s.language),
              kind: r == null ? const Value.absent() : Value(r.kind.wire),
              asrConfidence: r == null
                  ? const Value.absent()
                  : Value(r.asrConfidence),
            ),
          );
        }
        final stored = await _segments.insertAll([
          for (final ins in plan.inserts)
            _remoteSegment(
              meetingId,
              ins.source,
              ins.index,
              ins.startMs,
              ins.endMs,
              speakerIds,
            ),
        ]);
        inserted.addAll(stored.map((s) => s.id));
        final minutes = target.minutes;
        await (_db.update(
          _db.meetings,
        )..where((m) => m.id.equals(meetingId))).write(
          MeetingsCompanion(
            durationMs: Value(plan.durationMs),
            audioPath: mergedName == null
                ? const Value.absent()
                : Value(mergedName),
            minutesJson: minutes == null
                ? const Value.absent()
                : Value(jsonEncode(remapEvidenceJson(minutes.toJson(), remap))),
          ),
        );
        await _store.rewriteReferences(
          meetingId,
          remapList: (json) => _remapJsonText(json, remap, list: true),
          remapJson: (json) => _remapJsonText(json, remap, list: false),
        );
        final dropped = await _store.push(
          snapshot.completed(
            insertedSegmentIds: inserted,
            mergedAudioPath: mergedName,
          ),
        );
        if (dropped.isNotEmpty) {
          final remaining = await _store.stack(meetingId);
          await MeetingPackageStore.deleteSnapshotFiles(
            dropped,
            keep: {
              ?(mergedName ?? target.audioPath),
              for (final s in remaining) ...{?s.audioPath, ?s.mergedAudioPath},
            },
            recordingsDir: _recordingsDir,
          );
        }
      });
      mergedName = null; // Owned by the meeting now.
      committed = true;
      onProgress?.call(0.85, PS.progressRefining);
      final refined = await _tryRefine(meetingId);
      onProgress?.call(1, PS.progressDone);
      return MergeResult(
        preview: preview,
        insertedSegments: inserted.length,
        refined: refined,
      );
    } catch (_) {
      if (mergedName != null) {
        await _deleteQuietly(p.join(await _recordingsDir(), mergedName));
      }
      if (!committed) {
        // Speakers created for a merge that did not happen.
        for (final id in created) {
          try {
            await _speakers.delete(id);
          } catch (_) {
            // Best effort.
          }
        }
      }
      rethrow;
    } finally {
      await _deleteQuietly(remoteWav);
    }
  }

  static String _remapJsonText(
    String json,
    Map<int, int> remap, {
    required bool list,
  }) {
    try {
      final v = jsonDecode(json);
      final out = list && v is List
          ? [for (final x in v) x is int ? (remap[x] ?? x) : x]
          : remapEvidenceJson(v, remap);
      return jsonEncode(out);
    } on FormatException {
      return json;
    }
  }

  /// Undoes the latest merge into [meetingId]. Returns false when there was
  /// nothing to undo.
  Future<bool> undoLastMerge(String meetingId) async {
    if (_isActive(meetingId)) throw const InsatoException(PS.stillRecording);
    final snap = await _store.restoreLatest(meetingId);
    if (snap == null) return false;
    final merged = snap.mergedAudioPath;
    if (merged != null && merged != snap.audioPath) {
      await _deleteQuietly(p.join(await _recordingsDir(), merged));
    }
    return true;
  }

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort.
    }
  }
}

final Stopwatch _monotonic = Stopwatch()..start();

Future<T> _isolated<A, T>(Future<T> Function(A) f, A arg, String name) =>
    Isolate.run(() => f(arg), debugName: name);

Future<Map<String, double>> _snrTask(
  (String, List<(String, int, int)>) args,
) async {
  final (wav, ranges) = args;
  final audio = await WavFileAlignmentAudio.open(wav);
  final floor = noiseFloorOf(audio.profile);
  return <String, double>{
    for (final (id, a, b) in ranges)
      id: ?segmentSnrDb(audio.profile, floor, a, b),
  };
}

typedef _AnalysisArgs = ({
  String? mainWav,
  String? remoteWav,
  int wallClockOffsetMs,
  List<(String, int, int)> mainRanges,
  List<(int, int, int)> remoteRanges,
  int mainDurationMs,
});

typedef _Analysis = ({
  RecordingAlignment alignment,
  Map<String, double> mainSnr,
  Map<int, double> remoteSnr,
  int mainMs,
  int? remoteMs,
});

Future<_Analysis> _analysisTask(_AnalysisArgs a) async {
  final main = a.mainWav == null
      ? null
      : await WavFileAlignmentAudio.open(a.mainWav!);
  final remote = a.remoteWav == null
      ? null
      : await WavFileAlignmentAudio.open(a.remoteWav!);
  final alignment = main != null && remote != null
      ? await alignRecordings(
          main: main,
          remote: remote,
          wallClockOffsetMs: a.wallClockOffsetMs,
        )
      : RecordingAlignment(
          offsetMs: a.wallClockOffsetMs,
          wallClockOffsetMs: a.wallClockOffsetMs,
          method: AlignmentMethod.wallClock,
        );
  final mainSnr = <String, double>{};
  if (main != null) {
    final floor = noiseFloorOf(main.profile);
    for (final (id, s, e) in a.mainRanges) {
      final v = segmentSnrDb(main.profile, floor, s, e);
      if (v != null) mainSnr[id] = v;
    }
  }
  final remoteSnr = <int, double>{};
  if (remote != null) {
    final floor = noiseFloorOf(remote.profile);
    for (final (i, s, e) in a.remoteRanges) {
      final v = segmentSnrDb(remote.profile, floor, s, e);
      if (v != null) remoteSnr[i] = v;
    }
  }
  return (
    alignment: alignment,
    mainSnr: mainSnr,
    remoteSnr: remoteSnr,
    mainMs: main?.durationMs ?? a.mainDurationMs,
    remoteMs: remote?.durationMs,
  );
}

Future<int> _mergeAudioTask(
  ({
    String outPath,
    String? mainWav,
    int mainStart,
    String? remoteWav,
    int remoteStart,
    AudioMergeMode mode,
  })
  a,
) async => writeMergedWav(
  outPath: a.outPath,
  main: a.mainWav == null ? null : await WavFileAlignmentAudio.open(a.mainWav!),
  mainStartSample: a.mainStart,
  remote: a.remoteWav == null
      ? null
      : await WavFileAlignmentAudio.open(a.remoteWav!),
  remoteStartSample: a.remoteStart,
  mode: a.mode,
);

/// File name of a package: the title (characters no file system accepts
/// removed) and the date, e.g. `اجتماع الميزانية 2026-11-19.insato`.
String packageFileName(String title, DateTime startedAt) {
  final t = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final d = startedAt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${d.year}-${two(d.month)}-${two(d.day)}';
  final base = t.isEmpty ? 'insato' : (t.length > 60 ? t.substring(0, 60) : t);
  return '$base $date.$kPackageExtension';
}
