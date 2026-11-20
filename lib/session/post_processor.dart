// Everything that happens to a meeting after (or outside of) live recording:
// offline speaker refinement, voiceprint learning, minutes generation,
// re-processing from the archived audio, user corrections (rename / merge /
// reassign) and crash recovery.
//
// Voiceprint policy (decided here, see docs/FEATURES-v1.1.md F15):
//
// * Every speaker heard in a meeting learns from it — user-named speakers,
//   speakers recognised from earlier meetings AND new automatic speakers
//   (`متحدث N`), so an unnamed voice is recognised as the same `متحدث N`
//   next time.
// * Exception: a brand-new automatic speaker with less than
//   [kMinNewSpeakerVoiceprintMs] of speech in the meeting gets no voiceprint
//   yet (too little evidence; it would cause false matches). It stays a
//   speaker and learns once more speech accumulates (e.g. after a reassign).
// * Only segments of at least [kMinLearnSegmentMs] contribute, except
//   user-locked segments (explicit confirmation).
// * Learning is idempotent per segment: a per-meeting ledger (stored in the
//   settings table) records which segment contributed to which speaker. Re-
//   running refinement never double-counts; when a segment moves to another
//   speaker its embedding is removed from the old voiceprint (approximately)
//   and added to the new one.
// * Nothing the user named is ever renamed or renumbered; unnamed speakers
//   that this meeting created and that end up without segments are deleted.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/wav_writer.dart';
import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import '../features/consistency/consistency_providers.dart'
    show startAutomaticConsistencyCheck;
import '../features/official/official_models.dart' show resolveTemplate;
import '../data/database.dart';
import '../data/minutes_artifacts.dart';
import '../data/repositories.dart';
import '../data/secure_settings.dart';
import '../diarization/channel_cue.dart';
import '../diarization/clustering.dart';
import '../diarization/speaker_tracker.dart';
import '../diarization/vector_math.dart';
import '../features/voice/voice_devices.dart'
    show knownSpeakerThresholdFor, voiceDeviceAfterLearning;
import 'meeting_session_controller.dart';
import 'minutes_engines.dart'
    show MinutesQuotaExhaustedException, runWithMinutesEngine;
import 'providers.dart';

/// Minimum speech (ms) of a brand-new automatic speaker before its voiceprint
/// is saved.
const int kMinNewSpeakerVoiceprintMs = 3000;

/// Minimum segment duration (ms) that contributes to a voiceprint (unless the
/// user locked the segment).
const int kMinLearnSegmentMs = 1000;

/// Settings-table key prefix of the per-meeting voiceprint ledger (the
/// repository's [kVoiceprintLedgerKeyPrefix]; one source for both).
const String kVoiceprintLedgerPrefix = kVoiceprintLedgerKeyPrefix;

/// Failed speech segments [PostProcessor.reprocessFromAudio] tolerates out
/// of [attempted] non-silent segments before it refuses to replace the
/// transcript: at most 2, or 5 %. A segment that fails deterministically
/// must not block re-processing forever, while an outage (which fails many
/// segments in a row) must not truncate the transcript.
int maxToleratedReprocessFailures(int attempted) =>
    math.max(2, (math.max(0, attempted) * 0.05).ceil());

/// Default average-linkage similarity for offline re-clustering.
const double kDefaultRefineClusterThreshold = 0.5;

/// Shortest segment (ms) the offline refinement clusters. Shorter segments
/// that still have an embedding (sub-second replies such as «نعم») are too
/// noisy to shape clusters; they are attached afterwards by
/// [scoreRefinedSegments].
const int kMinClusterSegmentMs = 800;

// ===========================================================================
// Minutes engine seam
// ===========================================================================

/// A [MinutesEngine] plus the release of its resources (HTTP client).
class MinutesEngineHandle {
  /// Wraps [engine]; [release] is called once generation finished.
  MinutesEngineHandle(this.engine, {this._release});

  /// The engine.
  final MinutesEngine engine;
  final void Function()? _release;
  bool _released = false;

  /// Releases the engine's resources. Idempotent.
  void release() {
    if (_released) return;
    _released = true;
    _release?.call();
  }
}

/// Creates the minutes engine selected in Settings, or returns null when
/// its API key is not configured. May throw [MinutesEngineNotReadyException]
/// when the engine cannot be used yet for another reason (privacy notice
/// not accepted, local engine unavailable), and
/// [SecureStorageUnavailableException] when the keystore is locked.
typedef MinutesEngineFactory = Future<MinutesEngineHandle?> Function();

/// Why the selected minutes engine cannot run yet.
enum MinutesEngineNotReadyReason {
  /// Its API key is not configured.
  noApiKey,

  /// The user has not accepted the engine's data notice yet (Gemini free
  /// tier: Google may use the data to improve its products).
  privacyNotAcknowledged,

  /// The engine is not available on this device / build (e.g. a local
  /// engine whose model is not downloaded).
  unavailable,
}

/// The selected minutes engine cannot be used yet; [messageAr] says what
/// to do in Settings. A [MissingApiKeyException], so the UI offers to open
/// Settings.
class MinutesEngineNotReadyException extends MissingApiKeyException {
  /// Creates the exception.
  const MinutesEngineNotReadyException(
    super.messageAr, {
    required this.reason,
    super.debugDetails,
  });

  /// Why.
  final MinutesEngineNotReadyReason reason;
}

/// Message used when the factory returns null (no key for the engine).
const String kMinutesNoKeyMessageAr =
    'مفتاح محرك المحضر غير مضبوط. أضِفه من الإعدادات لإنشاء المحضر.';

/// Result of [PostProcessor.generateMinutesIfPossible].
enum MinutesOutcome {
  /// Minutes were generated and saved.
  generated,

  /// No API key for the selected engine, or the engine is not ready (see
  /// [MinutesRun.noticeAr]): the meeting is `ready` without minutes.
  skippedNoApiKey,

  /// The meeting has no transcript: the meeting is `ready` without minutes.
  skippedEmpty,

  /// The stored API key could not be read right now (the keystore is
  /// locked, e.g. iOS before the first unlock): the meeting is `ready`
  /// without minutes and the user can generate them later.
  postponedKeyUnavailable,
}

/// Outcome of [PostProcessor.runMinutesIfPossible] with the reason when the
/// engine was not ready.
class MinutesRun {
  /// Creates a result.
  const MinutesRun(this.outcome, {this.noticeAr});

  /// What happened.
  final MinutesOutcome outcome;

  /// For [MinutesOutcome.skippedNoApiKey]: what the user must do (Arabic).
  final String? noticeAr;
}

// ===========================================================================
// Reports
// ===========================================================================

/// Summary of [PostProcessor.learnFromCorrections] / the learning step.
class LearningReport {
  /// Creates a report.
  const LearningReport({
    this.updatedSpeakers = 0,
    this.learnedSegments = 0,
    this.unlearnedSegments = 0,
  });

  /// Speakers whose voiceprint changed.
  final int updatedSpeakers;

  /// Segment embeddings added to voiceprints.
  final int learnedSegments;

  /// Segment embeddings removed from voiceprints (moved to another speaker).
  final int unlearnedSegments;
}

/// Summary of [PostProcessor.refine].
class RefinementReport {
  /// Creates a report.
  const RefinementReport({
    this.clusters = 0,
    this.relabeledSegments = 0,
    this.createdSpeakerIds = const [],
    this.removedSpeakerIds = const [],
    this.learning = const LearningReport(),
  });

  /// Speaker clusters found.
  final int clusters;

  /// Segments whose speaker changed.
  final int relabeledSegments;

  /// Speakers created for clusters that matched nobody.
  final List<String> createdSpeakerIds;

  /// Unused automatic speakers deleted.
  final List<String> removedSpeakerIds;

  /// Voiceprint learning summary.
  final LearningReport learning;
}

/// Summary of [PostProcessor.reprocessFromAudio].
class ReprocessReport {
  /// Creates a report.
  const ReprocessReport({
    required this.segments,
    required this.failedSegments,
    required this.durationMs,
    required this.refinement,
  });

  /// Transcript segments produced.
  final int segments;

  /// Speech segments that could not be transcribed.
  final int failedSegments;

  /// Audio duration processed.
  final int durationMs;

  /// Refinement summary.
  final RefinementReport refinement;
}

// ===========================================================================
// Pure helpers (unit-tested)
// ===========================================================================

/// Input of the offline clustering ([refineSpeakers]); sendable to isolates.
class RefinementInput {
  /// Creates an input.
  const RefinementInput({
    required this.items,
    required this.knownSpeakers,
    required this.clusterThreshold,
    required this.linkThreshold,
    required this.lockedAssignments,
    this.channelProfiles = const {},
  });

  /// `(segmentId, embedding, durationMs)` in chronological order.
  final List<(String, Float32List, int)> items;

  /// Speakers with usable voiceprints.
  final List<Speaker> knownSpeakers;

  /// Average-linkage similarity needed to merge.
  final double clusterThreshold;

  /// Centroid ↔ voiceprint similarity needed to link.
  final double linkThreshold;

  /// Segment id → speaker id locked by the user.
  final Map<String, String> lockedAssignments;

  /// Segment id → SNR per device (v1.2 C multi-device meetings; empty
  /// otherwise).
  final Map<String, ChannelProfile> channelProfiles;
}

/// Runs the clustering; injectable for tests.
typedef RefinementRunner = Future<RefinementResult> Function(
  RefinementInput input,
);

RefinementResult _refineSync(RefinementInput input) => refineSpeakers(
  items: input.items,
  knownSpeakers: input.knownSpeakers,
  clusterThreshold: input.clusterThreshold,
  linkThreshold: input.linkThreshold,
  lockedAssignments: input.lockedAssignments,
  channelProfiles: input.channelProfiles,
);

/// Default [RefinementRunner]: inline for small meetings, in a background
/// isolate for large ones (the similarity matrix is O(n²)).
Future<RefinementResult> runRefinementInBackground(RefinementInput input) {
  if (input.items.length <= 150) return Future.value(_refineSync(input));
  return Isolate.run(
    () => _refineSync(input),
    debugName: 'insato-refine-speakers',
  );
}

/// Chooses the speaker of each refined cluster.
///
/// * Clusters linked by [refineSpeakers] (locked or voiceprint) keep that
///   speaker.
/// * Other clusters (largest first) reuse the live speaker that owns most of
///   their speech (user-named speakers' speech counts double), provided that
///   speaker is not taken by another cluster and is either in
///   [reusableSpeakerIds] (automatic speakers local to this meeting) or its
///   voiceprint matches the cluster centroid at [matchThreshold]. This keeps
///   the labels the user saw live whenever the evidence allows.
/// * Otherwise the cluster maps to null: a new speaker must be created.
Map<String, String?> planClusterSpeakers({
  required List<TranscriptSegment> segments,
  required RefinementResult result,
  required Map<String, Speaker> speakersById,
  required Set<String> reusableSpeakerIds,
  required double matchThreshold,
}) {
  final segById = {for (final s in segments) s.id: s};
  final plan = <String, String?>{};
  final claimed = <String>{};
  for (final c in result.clusters) {
    final id = c.linkedSpeakerId;
    if (id != null && speakersById.containsKey(id) && !claimed.contains(id)) {
      plan[c.id] = id;
      claimed.add(id);
    }
  }
  final unlinked =
      [
        for (final c in result.clusters)
          if (!plan.containsKey(c.id)) c,
      ]..sort((a, b) {
        final bySize = b.totalMs.compareTo(a.totalMs);
        return bySize != 0 ? bySize : a.id.compareTo(b.id);
      });
  for (final c in unlinked) {
    final votes = <String, double>{};
    for (final segId in c.segmentIds) {
      final s = segById[segId];
      final sid = s?.speakerId;
      if (s == null || sid == null) continue;
      final sp = speakersById[sid];
      if (sp == null) continue;
      final dur = math.max(1, s.endMs - s.startMs).toDouble();
      votes[sid] = (votes[sid] ?? 0) + dur * (sp.isNamedByUser ? 2 : 1);
    }
    final ranked = votes.entries.toList()
      ..sort((a, b) {
        final byVotes = b.value.compareTo(a.value);
        return byVotes != 0 ? byVotes : a.key.compareTo(b.key);
      });
    String? chosen;
    for (final e in ranked) {
      if (claimed.contains(e.key)) continue;
      final sp = speakersById[e.key]!;
      final vp = sp.centroid;
      final voiceMatches =
          vp != null &&
          isUsableEmbedding(vp, dimension: c.centroid.length) &&
          cosine(c.centroid, vp) >= matchThreshold;
      if (reusableSpeakerIds.contains(e.key) || voiceMatches) {
        chosen = e.key;
        break;
      }
    }
    if (chosen != null) claimed.add(chosen);
    plan[c.id] = chosen;
  }
  return plan;
}

/// Computes the speaker changes to apply after refinement: segment id → new
/// speaker id, for unlocked segments only.
///
/// Clustered segments take their cluster's speaker. Segments that were not
/// clustered (no usable embedding) keep their speaker, unless that speaker is
/// in [removableSpeakerIds] and no clustered segment keeps it — then they
/// take the speaker of the nearest neighbouring segment, so the removable
/// speaker can be deleted.
///
/// [extraClusterBySegment] adds cluster memberships decided outside the
/// clustering (short segments attached by [scoreRefinedSegments]).
Map<String, String> computeSegmentAssignments({
  required List<TranscriptSegment> segments,
  required RefinementResult result,
  required Map<String, String> speakerByCluster,
  required Set<String> removableSpeakerIds,
  Map<String, String> extraClusterBySegment = const {},
}) {
  final finalSpeaker = <String?>[];
  final anchored = <bool>[];
  for (final s in segments) {
    if (s.speakerLocked) {
      finalSpeaker.add(s.speakerId);
      anchored.add(true);
      continue;
    }
    final cid = result.clusterIdBySegment[s.id] ?? extraClusterBySegment[s.id];
    final sid = cid == null ? null : speakerByCluster[cid];
    finalSpeaker.add(sid ?? s.speakerId);
    anchored.add(sid != null);
  }
  final kept = <String>{
    for (var i = 0; i < segments.length; i++)
      if (anchored[i] && finalSpeaker[i] != null) finalSpeaker[i]!,
  };
  bool isStable(int j) {
    final sid = finalSpeaker[j];
    return sid != null &&
        (anchored[j] ||
            !removableSpeakerIds.contains(sid) ||
            kept.contains(sid));
  }

  for (var i = 0; i < segments.length; i++) {
    if (anchored[i]) continue;
    final sid = finalSpeaker[i];
    if (sid == null ||
        !removableSpeakerIds.contains(sid) ||
        kept.contains(sid)) {
      continue;
    }
    String? replacement;
    int bestGap = 1 << 62;
    for (var j = i - 1; j >= 0; j--) {
      if (!isStable(j)) continue;
      replacement = finalSpeaker[j];
      bestGap = math.max(0, segments[i].startMs - segments[j].endMs);
      break;
    }
    for (var j = i + 1; j < segments.length; j++) {
      if (!isStable(j)) continue;
      final gap = math.max(0, segments[j].startMs - segments[i].endMs);
      if (gap < bestGap) replacement = finalSpeaker[j];
      break;
    }
    if (replacement != null) finalSpeaker[i] = replacement;
  }
  return {
    for (var i = 0; i < segments.length; i++)
      if (!segments[i].speakerLocked &&
          finalSpeaker[i] != null &&
          finalSpeaker[i] != segments[i].speakerId)
        segments[i].id: finalSpeaker[i]!,
  };
}

/// Output of [scoreRefinedSegments].
typedef RefinedSegmentScores = ({
  /// Unclustered segment id → cluster id it was attached to.
  Map<String, String> attach,

  /// Segment id → speaker confidence after refinement.
  Map<String, double> confidence,
});

/// Scores every unlocked segment with a usable embedding against the
/// refined cluster centroids of [result].
///
/// * A clustered segment keeps its cluster. Its confidence grows with its
///   similarity to its own centroid (relative to [matchThreshold]) and with
///   the margin over the closest other centroid (relative to
///   [ambiguityMargin]); a segment that sounds like two people (overlap, or
///   a turn change without a pause) gets a low confidence.
/// * An unclustered segment (shorter than [kMinClusterSegmentMs], or skipped)
///   is attached to the best centroid when it reaches [attachThreshold] and
///   beats the runner-up by [attachMargin]; its confidence is scaled down
///   because short embeddings are noisy. When no cluster wins it keeps its
///   current speaker with a doubtful confidence ([doubtfulConfidence]).
///
/// Segments without a usable embedding are not scored (their live
/// confidence stays).
RefinedSegmentScores scoreRefinedSegments({
  required List<TranscriptSegment> segments,
  required RefinementResult result,
  double matchThreshold = kDefaultRefineClusterThreshold,
  double ambiguityMargin = 0.05,
  double attachThreshold = 0.45,
  double attachMargin = 0.08,
  double doubtfulConfidence = 0.3,
}) {
  final attach = <String, String>{};
  final confidence = <String, double>{};
  final clusters = result.clusters;
  if (clusters.isEmpty) return (attach: attach, confidence: confidence);
  final dim = clusters.first.centroid.length;
  double clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);
  double score(double sim, double margin) =>
      clamp01(0.5 + (sim - matchThreshold) / 0.5) *
      clamp01(0.5 + margin / math.max(1e-6, 4 * ambiguityMargin));

  for (final s in segments) {
    if (s.speakerLocked) continue;
    final e = s.embedding;
    if (!isUsableEmbedding(e, dimension: dim)) continue;
    final ne = l2Normalize(e!);
    final own = result.clusterIdBySegment[s.id];
    var bestId = '';
    var best = double.negativeInfinity;
    var second = double.negativeInfinity;
    var ownSim = double.negativeInfinity;
    var otherBest = double.negativeInfinity;
    for (final c in clusters) {
      final sim = cosine(ne, c.centroid);
      if (sim > best) {
        second = best;
        best = sim;
        bestId = c.id;
      } else if (sim > second) {
        second = sim;
      }
      if (c.id == own) {
        ownSim = sim;
      } else if (sim > otherBest) {
        otherBest = sim;
      }
    }
    if (own != null) {
      final margin = otherBest.isFinite ? ownSim - otherBest : 1.0;
      confidence[s.id] = score(ownSim, margin);
      continue;
    }
    final margin = second.isFinite ? best - second : 1.0;
    if (best >= attachThreshold && margin >= attachMargin) {
      attach[s.id] = bestId;
      confidence[s.id] = 0.8 * score(best, margin);
    } else {
      confidence[s.id] = doubtfulConfidence;
    }
  }
  return (attach: attach, confidence: confidence);
}

/// Removes [removed] embeddings from a voiceprint ([centroid] averaged over
/// [count] embeddings): `normalize(c·n − Σe)` with count `n − k`.
///
/// The original sum's magnitude is unknown, so `c·n` over-estimates it and
/// the removal is slightly conservative. Returns `(null, 0)` when nothing
/// usable remains. Embeddings of another dimension are ignored.
(Float32List?, int) unlearnFromVoiceprint(
  Float32List centroid,
  int count,
  List<Float32List> removed,
) {
  if (count <= 0 || !isUsableEmbedding(centroid)) return (null, 0);
  final acc = Float64List(centroid.length);
  addScaledInPlace(acc, l2Normalize(centroid), count.toDouble());
  var k = 0;
  for (final e in removed) {
    if (!isUsableEmbedding(e, dimension: centroid.length)) continue;
    addScaledInPlace(acc, l2Normalize(e), -1);
    k++;
  }
  if (k == 0) return (centroid, count);
  final remaining = count - k;
  if (remaining <= 0) return (null, 0);
  final out = normalizeAccumulator(acc);
  if (!isUsableEmbedding(out)) return (null, 0);
  return (out, remaining);
}

/// Carries user-locked speaker assignments from [oldSegments] over to
/// re-transcribed [newSegments]: a new segment overlapping a locked old
/// segment for at least half of its duration (the largest overlap wins)
/// takes that speaker, locked.
List<TranscriptSegment> carryOverLocks(
  List<TranscriptSegment> newSegments,
  List<TranscriptSegment> oldSegments,
) {
  final locked = [
    for (final s in oldSegments)
      if (s.speakerLocked && s.speakerId != null) s,
  ];
  if (locked.isEmpty) return newSegments;
  return [for (final n in newSegments) _carryLock(n, locked)];
}

TranscriptSegment _carryLock(
  TranscriptSegment n,
  List<TranscriptSegment> locked,
) {
  final int dur = math.max(1, n.endMs - n.startMs);
  TranscriptSegment? best;
  var bestOverlap = 0;
  for (final o in locked) {
    final int ov = math.min(n.endMs, o.endMs) - math.max(n.startMs, o.startMs);
    if (ov > bestOverlap) {
      bestOverlap = ov;
      best = o;
    }
  }
  if (best == null || bestOverlap * 2 < dur) return n;
  return TranscriptSegment(
    id: n.id,
    meetingId: n.meetingId,
    index: n.index,
    startMs: n.startMs,
    endMs: n.endMs,
    text: n.text,
    speakerId: best.speakerId,
    language: n.language,
    embedding: n.embedding,
    speakerLocked: true,
    kind: n.kind,
    asrConfidence: n.asrConfidence,
  );
}

/// Encodes a voiceprint ledger (segment id → speaker id).
String encodeVoiceprintLedger(Map<String, String> ledger) => jsonEncode(ledger);

/// Decodes a ledger; corrupt data yields an empty ledger.
Map<String, String> decodeVoiceprintLedger(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final v = jsonDecode(json);
    if (v is! Map) return {};
    return {
      for (final e in v.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  } on FormatException {
    return {};
  }
}

// ===========================================================================
// PostProcessor
// ===========================================================================

/// Post-recording processing and user corrections for meetings.
class PostProcessor {
  /// Creates the processor.
  ///
  /// * [minutesEngineFactory]: null disables minutes generation.
  /// * [enginesFactory]: speech engines for [reprocessFromAudio].
  /// * [isMeetingActive]: true while a meeting is being recorded (such
  ///   meetings are not re-processed or recovered).
  /// * [runRefinement]: clustering runner (default
  ///   [runRefinementInBackground]).
  /// * [paths]: resolves stored recording file names
  ///   ([AppPaths.resolveRecording]); without it `Meeting.audioPath` is used
  ///   as stored.
  PostProcessor({
    required this._db,
    required this._meetings,
    required this._segments,
    required this._speakers,
    required this._settings,
    MinutesEngineFactory? minutesEngineFactory,
    this._enginesFactory,
    this._paths,
    bool Function(String meetingId)? isMeetingActive,
    RefinementRunner? runRefinement,
    this._onMinutesSaved,
    this._onMeetingDeleted,
    this._channelProfilesOf,
  }) : _minutesFactory = minutesEngineFactory,
       _isActive = isMeetingActive ?? ((_) => false),
       _runRefinement = runRefinement ?? runRefinementInBackground;

  final AppDatabase _db;
  final MeetingRepository _meetings;
  final SegmentRepository _segments;
  final SpeakerRepository _speakers;
  final AppSettings _settings;
  final MinutesEngineFactory? _minutesFactory;
  final SessionEnginesFactory? _enginesFactory;
  final AppPaths? _paths;
  final bool Function(String meetingId) _isActive;
  final RefinementRunner _runRefinement;

  /// Runs after new minutes (and their artifacts) were saved: the speaker
  /// profiles (F16) of opted-in speakers are merged with the meeting's
  /// notes. Best-effort: a failure never fails the minutes.
  final Future<void> Function(String meetingId)? _onMinutesSaved;

  /// Runs after a meeting was deleted: drops it from the stored speaker
  /// profiles (F16), so its content no longer shows in anyone's profile.
  /// Best-effort: a failure never fails the delete (profiles can be rebuilt).
  final Future<void> Function(String meetingId)? _onMeetingDeleted;

  /// v1.2 C: segment id → SNR per device of a multi-device meeting (empty
  /// for single-device meetings). Best-effort: a failure means no cue.
  final Future<Map<String, ChannelProfile>> Function(String meetingId)?
  _channelProfilesOf;

  // -------------------------------------------------------------------------
  // Refinement
  // -------------------------------------------------------------------------

  /// Re-clusters all speaker embeddings of [meetingId] and relabels the
  /// transcript (user-locked segments are never changed), then learns
  /// voiceprints (see the policy at the top of this file).
  ///
  /// [sessionCreatedSpeakerIds] are the speakers the live session created;
  /// they may be reused or deleted when the refinement no longer needs them.
  Future<RefinementReport> refine(
    String meetingId, {
    Set<String> sessionCreatedSpeakerIds = const {},
  }) async {
    final segs = await _segments.getForMeeting(meetingId);
    if (segs.isEmpty) return const RefinementReport();
    final settings = await _settings.load();
    final speakersById = await _speakers.getAllById();
    final items = <(String, Float32List, int)>[
      for (final s in segs)
        if (isUsableEmbedding(s.embedding) &&
            s.endMs - s.startMs >= kMinClusterSegmentMs)
          (s.id, s.embedding!, math.max(0, s.endMs - s.startMs)),
    ];
    if (items.isEmpty) {
      return RefinementReport(learning: await learnFromCorrections(meetingId));
    }
    final RefinementReport report;
    try {
      report = await _refineClusters(
        meetingId,
        segs,
        settings,
        speakersById,
        items,
        sessionCreatedSpeakerIds,
      );
    } catch (_) {
      // F15: the voices of this meeting must still get voiceprints, learned
      // from the assignments as they stand (the live labels, or whatever
      // the failed refinement committed). Best effort: the refinement error
      // is what the caller sees.
      try {
        await learnFromCorrections(meetingId);
      } catch (_) {
        // The database itself is failing; nothing more to do here.
      }
      rethrow;
    }
    return RefinementReport(
      clusters: report.clusters,
      relabeledSegments: report.relabeledSegments,
      createdSpeakerIds: report.createdSpeakerIds,
      removedSpeakerIds: report.removedSpeakerIds,
      learning: await learnFromCorrections(meetingId),
    );
  }

  /// Clustering + relabelling part of [refine] (no learning).
  Future<RefinementReport> _refineClusters(
    String meetingId,
    List<TranscriptSegment> segs,
    AppSettingsData settings,
    Map<String, Speaker> speakersById,
    List<(String, Float32List, int)> items,
    Set<String> sessionCreatedSpeakerIds,
  ) async {
    final known = [
      for (final s in speakersById.values)
        if (isUsableEmbedding(s.centroid)) s,
    ];
    final locked = <String, String>{
      for (final s in segs)
        if (s.speakerLocked &&
            s.speakerId != null &&
            speakersById.containsKey(s.speakerId))
          s.id: s.speakerId!,
    };
    var channelProfiles = const <String, ChannelProfile>{};
    final loadProfiles = _channelProfilesOf;
    if (loadProfiles != null) {
      try {
        channelProfiles = await loadProfiles(meetingId);
      } catch (_) {
        // No multi-device cue; the voices alone decide.
      }
    }
    final result = await _runRefinement(
      RefinementInput(
        items: items,
        knownSpeakers: known,
        clusterThreshold: kDefaultRefineClusterThreshold,
        linkThreshold: math.min(0.95, settings.matchThreshold + 0.05),
        lockedAssignments: locked,
        channelProfiles: channelProfiles,
      ),
    );

    final outside = await _segmentCountsBySpeaker(excludeMeetingId: meetingId);
    final inMeeting = {for (final s in segs) ?s.speakerId};
    final reusable = <String>{
      for (final id in sessionCreatedSpeakerIds)
        if (speakersById.containsKey(id)) id,
      for (final id in inMeeting)
        if (speakersById[id] case final sp?
            when !sp.isNamedByUser &&
                sp.centroid == null &&
                (outside[id] ?? 0) == 0)
          id,
    };
    final plan = planClusterSpeakers(
      segments: segs,
      result: result,
      speakersById: speakersById,
      reusableSpeakerIds: reusable,
      matchThreshold: settings.matchThreshold,
    );
    final resolved = <String, String>{};
    final created = <String>[];
    for (final c in result.clusters) {
      final sid = plan[c.id];
      if (sid != null) {
        resolved[c.id] = sid;
      } else {
        final sp = await _speakers.create();
        created.add(sp.id);
        resolved[c.id] = sp.id;
      }
    }
    final removable = {
      for (final id in reusable)
        if (!speakersById[id]!.isNamedByUser) id,
    };
    final scores = scoreRefinedSegments(segments: segs, result: result);
    final changes = computeSegmentAssignments(
      segments: segs,
      result: result,
      speakerByCluster: resolved,
      removableSpeakerIds: removable,
      extraClusterBySegment: scores.attach,
    );
    final relabeled = await _segments.bulkAssignSpeakers(changes);
    await _segments.bulkSetSpeakerConfidence(scores.confidence);

    final counts = await _segmentCountsBySpeaker();
    final removed = <String>[];
    for (final id in removable) {
      if ((counts[id] ?? 0) > 0) continue;
      if (await _speakers.delete(id)) removed.add(id);
    }
    return RefinementReport(
      clusters: result.clusters.length,
      relabeledSegments: relabeled,
      createdSpeakerIds: created,
      removedSpeakerIds: removed,
    );
  }

  Future<Map<String, int>> _segmentCountsBySpeaker({
    String? excludeMeetingId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT speaker_id AS sid, COUNT(*) AS n FROM segments '
          'WHERE speaker_id IS NOT NULL'
          '${excludeMeetingId == null ? '' : ' AND meeting_id <> ?1'} '
          'GROUP BY speaker_id',
          variables: [
            if (excludeMeetingId != null) Variable.withString(excludeMeetingId),
          ],
          readsFrom: {_db.segments},
        )
        .get();
    return {for (final r in rows) r.read<String>('sid'): r.read<int>('n')};
  }

  // -------------------------------------------------------------------------
  // Voiceprint learning
  // -------------------------------------------------------------------------

  /// Brings the voiceprints in line with the current speaker assignments of
  /// [meetingId]: new or moved segments are learned into their speaker's
  /// voiceprint, segments moved away are removed from the previous one.
  /// Idempotent (see the ledger in the file header).
  Future<LearningReport> learnFromCorrections(String meetingId) {
    return _db.transaction(() async {
      final segs = await _segments.getForMeeting(meetingId);
      final speakers = await _speakers.getAllById();
      final ledger = await _loadLedger(meetingId);
      final meetingDevice = (await _meetings.get(meetingId))?.inputDevice;
      final speechMs = <String, int>{};
      for (final s in segs) {
        final sid = s.speakerId;
        if (sid == null) continue;
        speechMs[sid] = (speechMs[sid] ?? 0) + math.max(0, s.endMs - s.startMs);
      }
      final adds = <String, List<Float32List>>{};
      final removes = <String, List<Float32List>>{};
      for (final s in segs) {
        final e = s.embedding;
        if (e == null || !isUsableEmbedding(e)) continue;
        final prev = ledger[s.id];
        final cur = s.speakerId;
        final tomb = prev == null
            ? null
            : voiceprintLedgerTombstoneSpeaker(prev);
        if (tomb != null) {
          // The segment belongs to `tomb` without contributing to any
          // voiceprint (forgotten, or dropped by a merge): while it stays
          // there it is never learned again, and moving it away has nothing
          // to unlearn.
          if (tomb == cur) continue;
          ledger.remove(s.id);
        } else if (prev != null) {
          if (prev == cur) continue;
          // Merges rewrite the ledgers (SpeakerRepository.merge), so a
          // previous speaker that no longer exists was deleted: its
          // voiceprint is gone and there is nothing to unlearn.
          if (speakers.containsKey(prev)) (removes[prev] ??= []).add(e);
          ledger.remove(s.id);
        }
        if (cur == null) continue;
        final sp = speakers[cur];
        if (sp == null || !_eligible(s, sp, speechMs)) continue;
        (adds[cur] ??= []).add(e);
        ledger[s.id] = cur;
      }
      final present = {for (final s in segs) s.id};
      ledger.removeWhere((segId, _) => !present.contains(segId));

      var updated = 0;
      for (final id in {...adds.keys, ...removes.keys}) {
        final sp = speakers[id]!;
        Float32List? centroid = sp.centroid;
        var count = sp.embeddingCount;
        final rem = removes[id];
        if (rem != null && centroid != null) {
          (centroid, count) = unlearnFromVoiceprint(centroid, count, rem);
        }
        final add = adds[id] ?? const <Float32List>[];
        if (add.isNotEmpty) {
          final (c, n) = updateVoiceprint(
            centroid,
            count,
            add,
            cap: kMaxVoiceprintEmbeddingCount,
          );
          await _speakers.updateVoiceprint(id, c, n);
          // F18: the voiceprint remembers the microphone it has adapted to.
          final hadVoice = centroid != null && isUsableEmbedding(centroid);
          final device = voiceDeviceAfterLearning(
            currentDevice: hadVoice ? sp.voiceDevice : null,
            sessionDeviceKey: meetingDevice,
            previousCount: hadVoice ? count : 0,
            learnedCount: add.length,
          );
          if (device != sp.voiceDevice) {
            await _speakers.setVoiceDevice(id, device);
          }
        } else if (centroid == null) {
          // forgetVoice turns this speaker's entries in every stored ledger
          // into tombstones; do the same in the in-memory ledger, or saving
          // it below would overwrite them for this meeting.
          final tombstone = voiceprintLedgerTombstone(id);
          for (final k in ledger.keys.toList()) {
            if (ledger[k] == id) ledger[k] = tombstone;
          }
          await _speakers.forgetVoice(id);
        } else {
          await _speakers.updateVoiceprint(id, centroid, count);
        }
        updated++;
      }
      await _saveLedger(meetingId, ledger);
      return LearningReport(
        updatedSpeakers: updated,
        learnedSegments: adds.values.fold(0, (a, l) => a + l.length),
        unlearnedSegments: removes.values.fold(0, (a, l) => a + l.length),
      );
    });
  }

  static bool _eligible(
    TranscriptSegment s,
    Speaker sp,
    Map<String, int> speechMs,
  ) {
    if (!s.speakerLocked && s.endMs - s.startMs < kMinLearnSegmentMs) {
      return false;
    }
    if (s.speakerLocked || sp.isNamedByUser) return true;
    if (isUsableEmbedding(sp.centroid)) return true;
    return (speechMs[sp.id] ?? 0) >= kMinNewSpeakerVoiceprintMs;
  }

  Future<Map<String, String>> _loadLedger(String meetingId) async {
    final row =
        await (_db.select(
              _db.settings,
            )..where((s) => s.key.equals('$kVoiceprintLedgerPrefix$meetingId')))
            .getSingleOrNull();
    return decodeVoiceprintLedger(row?.value);
  }

  Future<void> _saveLedger(String meetingId, Map<String, String> ledger) async {
    final key = '$kVoiceprintLedgerPrefix$meetingId';
    if (ledger.isEmpty) {
      await (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();
      return;
    }
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: key,
            value: encodeVoiceprintLedger(ledger),
          ),
        );
  }

  // -------------------------------------------------------------------------
  // User corrections
  // -------------------------------------------------------------------------

  /// Renames a speaker everywhere (all meetings, future recognition).
  /// Throws [InsatoException] for a blank name or unknown speaker.
  Future<void> renameSpeaker(String speakerId, String name) async {
    final t = name.trim();
    if (t.isEmpty) {
      throw const InsatoException('يُرجى إدخال اسم للمتحدث.');
    }
    if (!await _speakers.rename(speakerId, t)) {
      throw const InsatoException('المتحدث غير موجود.');
    }
  }

  /// Merges speaker [fromId] into [intoId] (same person): all their segments
  /// in every meeting move to [intoId], voiceprints are combined, and a
  /// user-given name of [fromId] is kept when [intoId] has none.
  ///
  /// The voiceprint ledgers of all meetings are rewritten in the same
  /// transaction (contributions of [fromId] now belong to [intoId], whose
  /// merged voiceprint contains them), so nothing is learned twice and a
  /// later correction is learned normally.
  Future<Speaker> mergeSpeakers(String fromId, String intoId) async {
    try {
      return await _db.transaction(() async {
        // SpeakerRepository.merge rewrites the ledgers in its transaction.
        return await _speakers.merge(fromId, intoId);
      });
    } on StateError catch (e) {
      throw InsatoException(
        'أحد المتحدثَين غير موجود.',
        debugDetails: e.message,
        cause: e,
      );
    }
  }

  /// Assigns [speakerId] (null = no speaker) to one segment and locks it so
  /// refinement keeps it; the voiceprints learn from the correction.
  Future<void> reassignSegment(String segmentId, String? speakerId) async {
    final seg = await _segments.get(segmentId);
    if (seg == null) throw const InsatoException('المقطع غير موجود.');
    if (speakerId != null && await _speakers.get(speakerId) == null) {
      throw const InsatoException('المتحدث غير موجود.');
    }
    await _segments.reassignSpeaker(segmentId, speakerId, locked: true);
    await learnFromCorrections(seg.meetingId);
  }

  /// Deletes a meeting (segments, audio file) and its voiceprint ledger.
  /// Voiceprints keep what they learned from it.
  Future<bool> deleteMeeting(String meetingId) async {
    if (_isActive(meetingId)) {
      throw const InsatoException(
        'لا يمكن حذف اجتماع قيد التسجيل. أوقف التسجيل أولًا.',
      );
    }
    final meeting = await _meetings.get(meetingId);
    final stored = meeting?.audioPath;
    final audio = stored == null || stored.isEmpty
        ? null
        : await _resolveAudio(stored);
    final deleted = await _meetings.delete(meetingId);
    await _saveLedger(meetingId, const {});
    // The repository also deletes the recording when it was given the
    // recordings directory (see recordingsDirProvider); resolving it here
    // keeps the delete complete with [AppPaths] alone (e.g. in tests).
    if (deleted && audio != null) {
      try {
        final f = File(audio);
        if (await f.exists()) await f.delete();
      } on FileSystemException {
        // The row is gone; never fail the user's delete because of the file.
      }
    }
    if (deleted) {
      try {
        await _onMeetingDeleted?.call(meetingId);
      } catch (_) {
        // Profiles are best-effort; the user can rebuild them.
      }
    }
    return deleted;
  }

  // -------------------------------------------------------------------------
  // Minutes
  // -------------------------------------------------------------------------

  /// Generates (or regenerates) the minutes of [meetingId] and stores them
  /// (status `ready`). While generating the status is `processing`.
  ///
  /// Throws [InsatoException] when the transcript is empty,
  /// [MissingApiKeyException] (possibly a [MinutesEngineNotReadyException])
  /// when the selected engine has no key or is not ready, and the engine's
  /// [MinutesGenerationException] on API failure — then the meeting keeps
  /// its previous minutes (status `ready`) or, without minutes, becomes
  /// `failed` with the Arabic error. The transcript is never touched.
  ///
  /// v1.1: the glossary and open tasks are passed to the engine, and the
  /// tasks / pending task updates / speaker notes / code findings of the
  /// minutes are stored with them ([MinutesArtifactsWriter]).
  Future<Minutes> regenerateMinutes(
    String meetingId, {
    void Function(double progress, String statusAr)? onProgress,
  }) async {
    final meeting = await _meetings.get(meetingId);
    if (meeting == null) throw const InsatoException('الاجتماع غير موجود.');
    final segs = await _segments.getForMeeting(meetingId);
    if (segs.isEmpty) {
      throw const InsatoException(
        'لا يوجد كلام مسجّل في هذا الاجتماع لكتابة محضر له.',
      );
    }
    final handle = await _minutesFactory?.call();
    if (handle == null) {
      throw const MinutesEngineNotReadyException(
        kMinutesNoKeyMessageAr,
        reason: MinutesEngineNotReadyReason.noApiKey,
      );
    }
    return _generate(meeting, segs, handle, onProgress);
  }

  /// Automatic minutes after recording: generates them when there is a
  /// transcript and the selected engine is ready; otherwise marks the
  /// meeting `ready` (it was `processing`) and reports why nothing was
  /// generated. API errors propagate like [regenerateMinutes].
  Future<MinutesOutcome> generateMinutesIfPossible(
    String meetingId, {
    void Function(double progress, String statusAr)? onProgress,
  }) async =>
      (await runMinutesIfPossible(meetingId, onProgress: onProgress)).outcome;

  /// Like [generateMinutesIfPossible], with the reason when the engine was
  /// not ready ([MinutesRun.noticeAr]).
  Future<MinutesRun> runMinutesIfPossible(
    String meetingId, {
    void Function(double progress, String statusAr)? onProgress,
  }) async {
    final meeting = await _meetings.get(meetingId);
    if (meeting == null) throw const InsatoException('الاجتماع غير موجود.');
    final segs = await _segments.getForMeeting(meetingId);
    if (!segs.any((s) => s.hasContent)) {
      await _markReadyIfProcessing(meetingId);
      return const MinutesRun(MinutesOutcome.skippedEmpty);
    }
    final MinutesEngineHandle? handle;
    try {
      handle = await _minutesFactory?.call();
    } on SecureStorageUnavailableException {
      // The key may well exist: postpone instead of reporting "no key".
      await _markReadyIfProcessing(meetingId);
      return const MinutesRun(MinutesOutcome.postponedKeyUnavailable);
    } on MinutesEngineNotReadyException catch (e) {
      await _markReadyIfProcessing(meetingId);
      return MinutesRun(MinutesOutcome.skippedNoApiKey, noticeAr: e.messageAr);
    }
    if (handle == null) {
      await _markReadyIfProcessing(meetingId);
      return const MinutesRun(
        MinutesOutcome.skippedNoApiKey,
        noticeAr: kMinutesNoKeyMessageAr,
      );
    }
    await _generate(meeting, segs, handle, onProgress);
    return const MinutesRun(MinutesOutcome.generated);
  }

  /// Maximum open tasks of earlier meetings given to the minutes engine
  /// (newest first), to keep the prompt bounded.
  static const int maxOpenTasksInPrompt = 60;

  /// The v1.1 engine inputs of [meeting]: the effective glossary (global +
  /// meeting terms + named speakers) and the open tasks of earlier meetings
  /// (source meeting created before this one; manual tasks by their own
  /// creation time), newest first, up to [maxOpenTasksInPrompt].
  Future<MinutesInputs> minutesInputsFor(
    Meeting meeting,
    Map<String, Speaker> speakersById,
  ) async {
    final glossary = await GlossaryRepository(_db)
        .getEffective(meeting.id, speakers: speakersById.values);
    // Only tasks that existed before this meeting: regenerating an older
    // meeting must not propose updates for tasks of later meetings. A task
    // is dated by its source meeting (regeneration re-creates task rows with
    // a fresh timestamp), a manual task (or one whose meeting was deleted)
    // by its own creation time. Filtered before the cap, newest first.
    final meetingsById = <String, Meeting?>{};
    final open = <TrackedTask>[];
    for (final t in await TaskRepository(_db).getOpen()) {
      final src = t.sourceMeetingId;
      if (src == meeting.id) continue;
      DateTime origin = t.createdAt;
      if (src != null) {
        final m = meetingsById.containsKey(src)
            ? meetingsById[src]
            : (meetingsById[src] = await _meetings.get(src));
        if (m != null) origin = m.createdAt;
      }
      if (!origin.isBefore(meeting.createdAt)) continue;
      open.add(t);
      if (open.length >= maxOpenTasksInPrompt) break;
    }
    final titles = <String, String>{
      for (final t in open)
        if (t.sourceMeetingId case final id?)
          if (meetingsById[id] case final m?) id: m.title,
    };
    return MinutesInputs(
      glossary: glossary,
      openTasks: open,
      taskSourceTitles: titles,
      style: await _styleHintFor(meeting),
    );
  }

  /// The official register of [meeting]'s template (v1.2), or null for the
  /// simplified team template.
  Future<MinutesStyleHint?> _styleHintFor(Meeting meeting) async {
    try {
      final choice = resolveTemplate(
        meeting.context.template,
        await OfficialSettingsStore(_db).templates(),
      );
      if (!choice.isOfficial) return null;
      final record = await OfficialMinutesRepository(_db).get(meeting.id);
      final profile = await OfficialSettingsStore(_db).profile();
      return choice.template.styleHint(
        committee:
            record?.committee ??
            (profile.committees.isEmpty ? null : profile.committees.first),
        votingMembers: meeting.context.expectedAttendees,
      );
    } on Object {
      return null;
    }
  }

  Future<Minutes> _generate(
    Meeting meeting,
    List<TranscriptSegment> segs,
    MinutesEngineHandle handle,
    void Function(double progress, String statusAr)? onProgress,
  ) async {
    await _meetings.updateStatus(meeting.id, MeetingStatus.processing);
    try {
      final speakersById = await _speakers.getAllById();
      final inputs = await minutesInputsFor(meeting, speakersById);
      final minutes = await handle.engine.generate(
        meeting: meeting,
        segments: segs,
        speakersById: speakersById,
        onProgress: onProgress,
        inputs: inputs,
      );
      await _db.transaction(() async {
        await _meetings.saveMinutes(meeting.id, minutes);
        await MinutesArtifactsWriter(_db).persist(
          meetingId: meeting.id,
          minutes: minutes,
          speakersById: await _speakers.getAllById(),
          openTaskIds: {for (final t in inputs.openTasks) t.id},
          meetingSpeakerIds: {for (final s in segs) ?s.speakerId},
        );
      });
      try {
        await _onMinutesSaved?.call(meeting.id);
      } catch (_) {
        // Profiles are best-effort; the user can rebuild them.
      }
      return minutes;
    } catch (e) {
      final err = e is InsatoException
          ? e
          : MinutesGenerationException(
              'تعذّر إنشاء المحضر.',
              debugDetails: '$e',
              cause: e,
            );
      if (meeting.minutes != null) {
        await _meetings.updateStatus(meeting.id, MeetingStatus.ready);
      } else {
        await _meetings.setError(meeting.id, err.messageAr);
      }
      throw err;
    } finally {
      handle.release();
    }
  }

  Future<void> _markReadyIfProcessing(String meetingId) async {
    final m = await _meetings.get(meetingId);
    if (m != null && m.status == MeetingStatus.processing) {
      await _meetings.updateStatus(meetingId, MeetingStatus.ready);
    }
  }

  // -------------------------------------------------------------------------
  // Re-processing from audio
  // -------------------------------------------------------------------------

  /// Re-runs the whole pipeline (VAD → ASR + embeddings → speaker tracking)
  /// over the archived WAV of [meetingId] with the current settings and
  /// models, replaces the transcript atomically, and refines speakers.
  ///
  /// User-locked speaker assignments are carried over by time overlap
  /// ([carryOverLocks]); manual text edits of the old transcript are lost.
  /// The minutes are left as they are (regenerate them afterwards).
  ///
  /// On failure the old transcript (and the voiceprints learned from it) is
  /// kept and an [InsatoException] is thrown. Failure includes any error of
  /// the voice-activity detection and more failed speech segments than
  /// [maxToleratedReprocessFailures] allows (a few isolated failures are
  /// tolerated and reported in [ReprocessReport.failedSegments]).
  ///
  /// [isCancelled] is polled while the audio is analysed; once it returns
  /// true the run stops with an [OperationCancelledException] and, like any
  /// failure, leaves the old transcript as it was (used by the recording
  /// import, `lib/features/import_audio/`).
  Future<ReprocessReport> reprocessFromAudio(
    String meetingId, {
    void Function(double progress, String statusAr)? onProgress,
    bool Function()? isCancelled,
  }) async {
    void checkCancelled() {
      if (isCancelled?.call() ?? false) {
        throw const OperationCancelledException();
      }
    }

    final factory = _enginesFactory;
    if (factory == null) {
      throw const InsatoException('إعادة المعالجة غير متاحة.');
    }
    if (_isActive(meetingId)) {
      throw const InsatoException('لا يمكن إعادة معالجة اجتماع قيد التسجيل.');
    }
    final meeting = await _meetings.get(meetingId);
    if (meeting == null) throw const InsatoException('الاجتماع غير موجود.');
    final stored = meeting.audioPath;
    final path = stored == null ? null : await _resolveAudio(stored);
    if (path == null || !await File(path).exists()) {
      throw const InsatoException(
        'لا يوجد تسجيل صوتي محفوظ لهذا الاجتماع، لذا تتعذّر إعادة معالجته.',
      );
    }
    void report(double p, String s) => onProgress?.call(p.clamp(0.0, 1.0), s);

    report(0, 'جارٍ تجهيز التسجيل الصوتي…');
    final WavInfo info;
    try {
      await WavWriter.repair(path);
      info = await readWavInfo(path);
    } on Object catch (e) {
      throw InsatoException(
        'ملف التسجيل الصوتي تالف أو بصيغة غير مدعومة.',
        debugDetails: '$e',
        cause: e,
      );
    }
    final totalMs = math.max(1, info.duration.inMilliseconds);

    final settings = await _settings.load();
    final request = SessionEngineRequest.fromSettings(settings);
    report(0.01, 'جارٍ تحميل نماذج التعرّف على الكلام…');
    await factory.ensureReady(request);
    final engines = await factory.create(request);

    final known = [
      for (final s in await _speakers.getAll())
        if (isUsableEmbedding(s.centroid)) s,
    ];
    final collected = <TranscriptSegment>[];
    final pipeline = SessionPipeline(
      meetingId: meetingId,
      processor: engines.processor,
      tracker: SpeakerTracker(
        knownSpeakers: known,
        matchThreshold: settings.matchThreshold,
        knownSpeakerThresholdOf: (sp) => knownSpeakerThresholdFor(
          sp,
          sessionDeviceKey: meeting.inputDevice,
          base: settings.matchThreshold,
        ),
      ),
      speakers: _speakers,
      segments: _segments,
      sink: (s) async {
        collected.add(s);
        return s;
      },
    );
    final segmenterDone = Completer<void>();
    Object? segmenterError;
    final sub = engines.segmenter.segments.listen(
      pipeline.submit,
      onError: (Object e) => segmenterError ??= e,
      onDone: () {
        if (!segmenterDone.isCompleted) segmenterDone.complete();
      },
    );
    final previousStatus = meeting.status;
    var success = false;
    try {
      await _meetings.updateStatus(meetingId, MeetingStatus.processing);
      var fedMs = 0;
      String progressText(int done, int total) =>
          'جارٍ إعادة تفريغ الاجتماع (${(100 * done / total).round()}٪)…';
      try {
        await for (final chunk in readWavChunks(path)) {
          checkCancelled();
          engines.segmenter.accept(chunk);
          fedMs += chunk.length * 1000 ~/ kSampleRate;
          // Bound memory: never queue more than a few segments ahead.
          await pipeline.waitForCapacity(4);
          report(
            0.05 + 0.75 * math.min(1, fedMs / totalMs),
            progressText(math.min(fedMs, totalMs), totalMs),
          );
        }
      } on FormatException catch (e) {
        throw InsatoException(
          'ملف التسجيل الصوتي تالف أو بصيغة غير مدعومة.',
          debugDetails: e.message,
          cause: e,
        );
      } on FileSystemException catch (e) {
        throw InsatoException(
          'تعذّرت قراءة ملف التسجيل الصوتي.',
          debugDetails: e.message,
          cause: e,
        );
      }
      checkCancelled();
      engines.segmenter.flush();
      await engines.segmenter.dispose();
      await segmenterDone.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      await pipeline.drain(
        onProgress: (done, total) {
          report(
            0.8 + 0.1 * (total == 0 ? 1 : done / total),
            'جارٍ إكمال التفريغ…',
          );
        },
      );
      checkCancelled();
      // Never replace a transcript with a partial one: any VAD error means
      // the audio was not fully analysed, and more than a few failed
      // segments (e.g. the network dropped half-way with cloud ASR) mean
      // whole stretches are missing. Throwing here keeps the old transcript
      // and voiceprints untouched (see the catch/finally below).
      if (segmenterError != null) {
        final e = _insato(segmenterError!, 'حدث خطأ أثناء تحليل الصوت.');
        throw InsatoException(
          '${e.messageAr} أُبقي على النص السابق دون تغيير.',
          debugDetails: e.debugDetails,
          cause: segmenterError,
        );
      }
      final failed = pipeline.failedCount;
      if (failed > 0 &&
          (collected.isEmpty ||
              failed >
                  maxToleratedReprocessFailures(
                    pipeline.completedCount - pipeline.skippedCount,
                  ))) {
        final last = pipeline.lastError;
        throw InsatoException(
          'تعذّر تفريغ $failed من المقاطع'
          '${last == null ? '' : ' (${last.messageAr})'}، '
          'لذا أُبقي على النص السابق دون تغيير. حاول مجددًا لاحقًا.',
          debugDetails: last?.debugDetails ?? '$last',
          cause: last,
        );
      }

      report(0.9, 'جارٍ حفظ النص الجديد…');
      final oldSegs = await _segments.getForMeeting(meetingId);
      final existing = await _speakers.getAllById();
      final fresh = [
        for (final s in carryOverLocks(collected, oldSegs))
          s.speakerId == null || existing.containsKey(s.speakerId)
              ? s
              : _clearSpeaker(s),
      ];
      await _db.transaction(() async {
        await _unlearnMeeting(meetingId, oldSegs);
        await (_db.delete(
          _db.segments,
        )..where((s) => s.meetingId.equals(meetingId))).go();
        await _segments.insertAll(fresh);
      });
      await _meetings.setDuration(
        meetingId,
        math.max(meeting.durationMs, info.duration.inMilliseconds),
      );
      report(0.95, 'جارٍ تحسين تمييز المتحدثين…');
      final refinement = await refine(
        meetingId,
        sessionCreatedSpeakerIds: pipeline.createdSpeakerIds,
      );
      // The meeting now has a complete transcript again.
      await _meetings.updateStatus(meetingId, MeetingStatus.ready);
      success = true;
      report(1, 'اكتملت إعادة المعالجة.');
      return ReprocessReport(
        segments: fresh.length,
        failedSegments: pipeline.failedCount,
        durationMs: info.duration.inMilliseconds,
        refinement: refinement,
      );
    } catch (e) {
      pipeline.abort();
      throw _insato(e, 'تعذّرت إعادة معالجة الاجتماع.');
    } finally {
      await sub.cancel();
      await engines.dispose();
      if (!success) {
        await deleteOrphanSpeakers(pipeline.createdSpeakerIds);
        await _meetings.updateStatus(
          meetingId,
          previousStatus,
          clearError: false,
        );
      }
    }
  }

  /// Current location of a stored `Meeting.audioPath`.
  Future<String> _resolveAudio(String stored) async {
    final paths = _paths;
    if (paths == null) return stored;
    try {
      return await paths.resolveRecording(stored);
    } catch (_) {
      return stored;
    }
  }

  static TranscriptSegment _clearSpeaker(TranscriptSegment s) =>
      TranscriptSegment(
        id: s.id,
        meetingId: s.meetingId,
        index: s.index,
        startMs: s.startMs,
        endMs: s.endMs,
        text: s.text,
        language: s.language,
        embedding: s.embedding,
        kind: s.kind,
        asrConfidence: s.asrConfidence,
      );

  /// Removes [oldSegments]' contributions from voiceprints and clears the
  /// meeting's ledger (the segments are about to be replaced).
  Future<void> _unlearnMeeting(
    String meetingId,
    List<TranscriptSegment> oldSegments,
  ) async {
    final ledger = await _loadLedger(meetingId);
    if (ledger.isEmpty) return;
    final bySpeaker = <String, List<Float32List>>{};
    for (final s in oldSegments) {
      final sid = ledger[s.id];
      final e = s.embedding;
      if (sid == null || e == null) continue;
      (bySpeaker[sid] ??= []).add(e);
    }
    for (final entry in bySpeaker.entries) {
      final sp = await _speakers.get(entry.key);
      final c = sp?.centroid;
      if (sp == null || c == null) continue;
      final (nc, n) = unlearnFromVoiceprint(c, sp.embeddingCount, entry.value);
      if (nc == null) {
        await _speakers.forgetVoice(sp.id);
      } else {
        await _speakers.updateVoiceprint(sp.id, nc, n);
      }
    }
    await _saveLedger(meetingId, const {});
  }

  /// Deletes those of [speakerIds] (speakers created by a discarded or
  /// failed run) that are still unused: not named by the user, without any
  /// segment in any meeting, and without a voiceprint. Runs never store
  /// voiceprints before they finish, so a voiceprint means the user merged
  /// an older speaker into this one (or confirmed it) meanwhile. Never
  /// throws; returns the ids deleted.
  Future<List<String>> deleteOrphanSpeakers(Set<String> speakerIds) async {
    final deleted = <String>[];
    if (speakerIds.isEmpty) return deleted;
    try {
      final counts = await _segmentCountsBySpeaker();
      for (final id in speakerIds) {
        if ((counts[id] ?? 0) > 0) continue;
        final sp = await _speakers.get(id);
        if (sp == null || sp.isNamedByUser || sp.centroid != null) continue;
        if (await _speakers.delete(id)) deleted.add(id);
      }
    } catch (_) {
      // Leftover unnamed speakers are harmless.
    }
    return deleted;
  }

  // -------------------------------------------------------------------------
  // Crash recovery
  // -------------------------------------------------------------------------

  /// Finalises meetings left `recording` / `processing` by a crash or a
  /// killed app: repairs the WAV header, restores the duration and marks the
  /// meeting so the user can continue (transcript kept). Meetings that are
  /// currently being recorded are skipped. Returns the number recovered.
  Future<int> recoverInterruptedMeetings() async {
    var recovered = 0;
    for (final m in await _meetings.getAll()) {
      if (m.status != MeetingStatus.recording &&
          m.status != MeetingStatus.processing) {
        continue;
      }
      if (_isActive(m.id)) continue;
      try {
        var durationMs = m.durationMs;
        var hasAudio = false;
        final stored = m.audioPath;
        final path = stored == null ? null : await _resolveAudio(stored);
        if (path != null && await File(path).exists()) {
          try {
            await WavWriter.repair(path);
            final info = await readWavInfo(path);
            durationMs = math.max(durationMs, info.duration.inMilliseconds);
            hasAudio = info.dataBytes > 0;
          } on Object {
            hasAudio = false;
          }
        }
        final segs = await _segments.getForMeeting(m.id);
        if (segs.isNotEmpty) durationMs = math.max(durationMs, segs.last.endMs);
        if (durationMs != m.durationMs) {
          await _meetings.setDuration(m.id, durationMs);
        }
        if (m.status == MeetingStatus.processing && m.minutes != null) {
          await _meetings.updateStatus(m.id, MeetingStatus.ready);
        } else if (m.status == MeetingStatus.processing) {
          await _meetings.setError(
            m.id,
            'توقفت المعالجة قبل اكتمالها. حُفظ النص، ويمكنك إعادة إنشاء '
            'المحضر.',
          );
        } else {
          await _meetings.setError(
            m.id,
            'انقطع التسجيل بشكل غير متوقع. حُفظ النص حتى لحظة الانقطاع'
            '${hasAudio ? '، ويمكنك إعادة معالجته من التسجيل الصوتي' : ''}.',
          );
        }
        recovered++;
      } catch (_) {
        // Try the other meetings; this one stays as it is.
      }
    }
    return recovered;
  }

  static InsatoException _insato(Object e, String fallbackAr) {
    if (e is InsatoException) return e;
    return InsatoException(fallbackAr, debugDetails: '$e', cause: e);
  }
}

// ===========================================================================
// Per-meeting background jobs (Riverpod)
// ===========================================================================

/// Kind of [MeetingJobState] job.
enum MeetingJobKind {
  /// Minutes generation.
  minutes,

  /// Re-processing from the archived audio.
  reprocess,

  /// Speaker refinement.
  refine,
}

/// Phase of a [MeetingJobState].
enum MeetingJobPhase {
  /// Nothing ran yet (or cleared).
  idle,

  /// Running.
  running,

  /// Finished successfully (see [MeetingJobState.noticeAr] for skips).
  succeeded,

  /// Failed (see [MeetingJobState.errorAr]).
  failed,
}

/// State of the background job of one meeting.
class MeetingJobState {
  /// Creates a state.
  const MeetingJobState({
    this.kind,
    this.phase = MeetingJobPhase.idle,
    this.progress = 0,
    this.statusAr,
    this.errorAr,
    this.noticeAr,
    this.needsApiKey = false,
    this.alternativeEngine,
  });

  /// Job kind (null when idle).
  final MeetingJobKind? kind;

  /// Phase.
  final MeetingJobPhase phase;

  /// 0..1 progress.
  final double progress;

  /// Arabic status line while running.
  final String? statusAr;

  /// Arabic error when failed.
  final String? errorAr;

  /// Arabic notice after success (e.g. minutes skipped without API key).
  final String? noticeAr;

  /// True when the job could not run because the selected engine is not
  /// set up (key missing, privacy notice not accepted, …).
  final bool needsApiKey;

  /// When the job failed because the free daily quota of the selected cloud
  /// engine is used up: the other free cloud engine (ready to use) that the
  /// UI offers instead (`MinutesQuotaExhaustedException`).
  final String? alternativeEngine;

  /// True while running.
  bool get isRunning => phase == MeetingJobPhase.running;
}

/// Runs minutes generation, re-processing and refinement for one meeting,
/// one job at a time, exposing progress. Errors never escape: they land in
/// [MeetingJobState.errorAr] and the methods return false.
class MeetingJobsController extends Notifier<MeetingJobState> {
  /// Creates the controller of [meetingId].
  MeetingJobsController(this.meetingId);

  /// Meeting this controller works on.
  final String meetingId;

  Future<bool>? _running;

  @override
  MeetingJobState build() => const MeetingJobState();

  void _set(MeetingJobState s) {
    if (ref.mounted) state = s;
  }

  Future<bool> _run(
    MeetingJobKind kind,
    String startStatus,
    Future<MeetingJobState> Function(void Function(double, String)) job,
  ) {
    final running = _running;
    if (running != null) return running;
    final session = ref.read(meetingSessionControllerProvider);
    if (session.isActive && session.meetingId == meetingId) {
      _set(
        MeetingJobState(
          kind: kind,
          phase: MeetingJobPhase.failed,
          errorAr: 'الاجتماع قيد التسجيل. أوقف التسجيل أولًا.',
        ),
      );
      return Future.value(false);
    }
    _set(
      MeetingJobState(
        kind: kind,
        phase: MeetingJobPhase.running,
        statusAr: startStatus,
      ),
    );
    void progress(double p, String s) => _set(
      MeetingJobState(
        kind: kind,
        phase: MeetingJobPhase.running,
        progress: p.clamp(0.0, 1.0),
        statusAr: s,
      ),
    );
    final f = () async {
      try {
        final done = await job(progress);
        _set(done);
        return done.phase == MeetingJobPhase.succeeded;
      } catch (e) {
        _set(
          MeetingJobState(
            kind: kind,
            phase: MeetingJobPhase.failed,
            errorAr: e is InsatoException
                ? e.messageAr
                : 'حدث خطأ غير متوقع أثناء معالجة الاجتماع.',
            needsApiKey: e is MissingApiKeyException,
            alternativeEngine: e is MinutesQuotaExhaustedException
                ? e.alternativeEngine
                : null,
          ),
        );
        return false;
      }
    }();
    _running = f;
    return f.whenComplete(() => _running = null);
  }

  /// Generates the minutes. With [automatic] (after recording) a missing key
  /// or empty transcript is a successful skip with a notice; otherwise it is
  /// a failure. Returns true when minutes were generated (or skipped
  /// automatically).
  ///
  /// v1.2 (D): once new minutes are saved, the consistency checker runs in
  /// the background (heuristics, then the selected engine).
  ///
  /// [engine] runs this job once with another minutes engine than the one
  /// selected in Settings (the free cloud engine offered after a daily
  /// quota ran out, see [MeetingJobState.alternativeEngine]).
  Future<bool> generateMinutes({bool automatic = false, String? engine}) {
    final post = ref.read(postProcessorProvider);
    var generated = false;
    final job = _run(MeetingJobKind.minutes, 'جارٍ إعداد المحضر…', (
      progress,
    ) async {
      if (!automatic) {
        Future<Minutes> run() =>
            post.regenerateMinutes(meetingId, onProgress: progress);
        await (engine == null ? run() : runWithMinutesEngine(engine, run));
        generated = true;
        return const MeetingJobState(
          kind: MeetingJobKind.minutes,
          phase: MeetingJobPhase.succeeded,
          progress: 1,
          noticeAr: 'تم إنشاء المحضر.',
        );
      }
      final run = await post.runMinutesIfPossible(
        meetingId,
        onProgress: progress,
      );
      generated = run.outcome == MinutesOutcome.generated;
      return switch (run.outcome) {
        MinutesOutcome.generated => const MeetingJobState(
          kind: MeetingJobKind.minutes,
          phase: MeetingJobPhase.succeeded,
          progress: 1,
          noticeAr: 'تم إنشاء المحضر.',
        ),
        MinutesOutcome.skippedNoApiKey => MeetingJobState(
          kind: MeetingJobKind.minutes,
          phase: MeetingJobPhase.succeeded,
          progress: 1,
          needsApiKey: true,
          noticeAr:
              'لم يُنشأ المحضر. ${run.noticeAr ?? kMinutesNoKeyMessageAr}',
        ),
        MinutesOutcome.skippedEmpty => const MeetingJobState(
          kind: MeetingJobKind.minutes,
          phase: MeetingJobPhase.succeeded,
          progress: 1,
          noticeAr: 'لم يُلتقط أي كلام في هذا الاجتماع، لذا لم يُنشأ محضر.',
        ),
        MinutesOutcome.postponedKeyUnavailable => const MeetingJobState(
          kind: MeetingJobKind.minutes,
          phase: MeetingJobPhase.succeeded,
          progress: 1,
          noticeAr:
              'تعذّرت قراءة مفتاح محرك المحضر المحفوظ الآن لأن الجهاز مقفل، فأُجّل '
              'المحضر. افتح قفل الجهاز ثم اضغط «إنشاء المحضر».',
        ),
      };
    });
    return job.then((ok) {
      if (ok && generated && ref.mounted) {
        startAutomaticConsistencyCheck(ref, meetingId);
      }
      return ok;
    });
  }

  /// Re-processes the meeting from its archived audio.
  Future<bool> reprocessFromAudio() {
    final post = ref.read(postProcessorProvider);
    return _run(MeetingJobKind.reprocess, 'جارٍ إعادة المعالجة…', (
      progress,
    ) async {
      final r = await post.reprocessFromAudio(meetingId, onProgress: progress);
      return MeetingJobState(
        kind: MeetingJobKind.reprocess,
        phase: MeetingJobPhase.succeeded,
        progress: 1,
        noticeAr: r.failedSegments > 0
            ? 'اكتملت إعادة المعالجة، وتعذّر تفريغ ${r.failedSegments} من '
                  'المقاطع. يمكنك الآن إعادة إنشاء المحضر.'
            : 'اكتملت إعادة المعالجة. يمكنك الآن إعادة إنشاء المحضر.',
      );
    });
  }

  /// Re-runs speaker refinement.
  Future<bool> refineSpeakers() {
    final post = ref.read(postProcessorProvider);
    return _run(MeetingJobKind.refine, 'جارٍ تحسين تمييز المتحدثين…', (
      progress,
    ) async {
      await post.refine(meetingId);
      return const MeetingJobState(
        kind: MeetingJobKind.refine,
        phase: MeetingJobPhase.succeeded,
        progress: 1,
        noticeAr: 'تم تحسين تمييز المتحدثين.',
      );
    });
  }

  /// Clears a finished job's state.
  void clear() {
    if (_running == null) _set(const MeetingJobState());
  }
}
