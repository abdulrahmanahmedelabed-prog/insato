// Online (live) speaker assignment.
//
// The tracker sees one VAD segment at a time, in chronological order, and
// decides who is speaking using the segment's voice embedding. It keeps
// meeting-local clusters (`local:1`, `local:2`, …) whose centroids are updated
// incrementally, and links clusters to global voiceprints ([Speaker.centroid])
// so people recognised from earlier meetings get their saved names
// immediately.
//
// Pure Dart (no Flutter imports): runs in isolates and plain unit tests.
//
// Decision rules (see docs/ARCHITECTURE.md, "Speaker identification details"):
//
// * Long segments (≥ `newSpeakerMinDurationMs`) with a usable embedding are
//   scored against every local cluster and every *unclaimed* global
//   voiceprint (a voiceprint already linked to a local cluster is represented
//   by that cluster). Local clusters receive a small `localPreference` bonus so
//   that people already heard in this meeting win close calls.
// * The winner must reach its threshold AND beat the runner-up by
//   `ambiguityMargin`. A clear local winner absorbs the segment (centroid
//   updated); a clear global winner opens a local cluster linked to that
//   speaker. Close calls are resolved by temporal continuity (the previous
//   speaker keeps the floor when it is among the tied candidates) and never
//   update centroids, which keeps clusters from drifting toward each other.
// * Nothing above threshold → a new local cluster `متحدث N`.
// * Short segments or segments without an embedding never create clusters and
//   never update centroids. They inherit the previous speaker when the silence
//   gap is below `continuityGapMs` (unless the embedding clearly points to
//   another local cluster), otherwise take the best local match above
//   threshold, otherwise stay unknown.
// * Multi-device meetings (v1.2 C): a long segment may carry a
//   [ChannelProfile] (SNR per device). Local clusters remember the mean
//   "nearest device" of their speech, and a matching / opposite proximity
//   adds / subtracts up to `channelCueWeight` to the ranking score (never to
//   the similarity checked against the thresholds). Without profiles (one
//   device) nothing changes.
// * Phone-call mode: a profile may name a hard [ChannelProfile.partition]
//   (the side of the call). Such a segment is only compared with clusters
//   opened in the same partition (or without one), continuity is tracked
//   per partition, and new clusters remember their partition. Voiceprint
//   thresholds may depend on the partition ([knownSpeakerThresholdIn]).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../core/models.dart';
import 'channel_cue.dart';
import 'vector_math.dart';

/// Why the tracker produced a given [SpeakerAssignment].
enum AssignmentDecision {
  /// Confident match to an existing meeting-local cluster.
  matchedCluster,

  /// Confident match to a global voiceprint; a new local cluster linked to
  /// that speaker was opened.
  matchedKnownSpeaker,

  /// No candidate was similar enough; a new unlinked local cluster was opened.
  newCluster,

  /// Best candidates were too close to call; the previous speaker (who was
  /// among them) kept the floor.
  ambiguousContinuity,

  /// Best candidates were too close to call and there was no usable
  /// continuity; the best local cluster was chosen without updating it.
  ambiguousBest,

  /// Short or embedding-less segment inherited the previous speaker.
  inherited,

  /// Short segment, or cluster limit reached: assigned to the best local
  /// cluster above threshold without creating or updating clusters.
  weakMatch,

  /// No speaker could be determined.
  unknown,
}

/// Result of [SpeakerTracker.assign] for one segment.
class SpeakerAssignment {
  /// Creates an assignment. Normally only produced by [SpeakerTracker].
  const SpeakerAssignment({
    required this.segmentIndex,
    required this.decision,
    required this.confidence,
    this.clusterKey,
    this.linkedSpeakerId,
    this.autoLabelNumber,
    this.similarity,
    this.margin,
    this.createdCluster = false,
  });

  /// The `segmentIndex` passed to [SpeakerTracker.assign].
  final int segmentIndex;

  /// Meeting-local cluster key (`local:N`), or null when [isUnknown].
  final String? clusterKey;

  /// Global speaker id the cluster is linked to (known voiceprint, or a
  /// speaker record linked through [SpeakerTracker.linkCluster]).
  final String? linkedSpeakerId;

  /// `N` for the auto label `متحدث N` of an unlinked cluster (null when the
  /// cluster was linked to a known speaker at creation, or when unknown).
  final int? autoLabelNumber;

  /// Cosine similarity between the segment embedding and the chosen cluster /
  /// voiceprint (1.0 for a newly opened cluster; null when no embedding was
  /// compared).
  final double? similarity;

  /// Score gap between the best and second-best candidate (null when fewer
  /// than two candidates were compared or no embedding was used).
  final double? margin;

  /// Heuristic confidence in `[0, 1]` (1 = certain).
  final double confidence;

  /// What rule produced this assignment.
  final AssignmentDecision decision;

  /// True when this segment opened a new local cluster.
  final bool createdCluster;

  /// The id to store on the segment: the linked global speaker id when
  /// available, otherwise the local cluster key; null when unknown.
  String? get speakerKey => linkedSpeakerId ?? clusterKey;

  /// True when no speaker could be determined.
  bool get isUnknown => clusterKey == null;

  @override
  String toString() =>
      'SpeakerAssignment(#$segmentIndex → ${speakerKey ?? 'unknown'}, '
      '${decision.name}, sim=${similarity?.toStringAsFixed(3)}, '
      'conf=${confidence.toStringAsFixed(2)})';
}

/// Immutable snapshot of a meeting-local cluster.
class TrackedCluster {
  /// Creates a snapshot. Normally only produced by [SpeakerTracker].
  const TrackedCluster({
    required this.key,
    required this.centroid,
    required this.count,
    required this.totalMs,
    required this.firstStartMs,
    required this.lastEndMs,
    this.linkedSpeakerId,
    this.autoLabelNumber,
  });

  /// Cluster key, `local:N`.
  final String key;

  /// Global speaker id this cluster is linked to, if any.
  final String? linkedSpeakerId;

  /// `N` of the auto label `متحدث N` (null if linked at creation).
  final int? autoLabelNumber;

  /// L2-normalised centroid (copy; safe to keep).
  final Float32List centroid;

  /// Number of segments that updated the centroid.
  final int count;

  /// Total speech duration of those segments, in ms.
  final int totalMs;

  /// Start of the first segment in this cluster.
  final int firstStartMs;

  /// End of the most recent segment assigned to this cluster.
  final int lastEndMs;

  /// The id to store on segments of this cluster.
  String get speakerKey => linkedSpeakerId ?? key;
}

class _Cluster {
  _Cluster({
    required this.key,
    required this.dimension,
    required this.firstStartMs,
    this.autoLabelNumber,
    this.linkedSpeakerId,
    this.prior,
    this.partition,
  })  : sum = Float64List(dimension),
        centroid = Float32List(dimension);

  final String key;
  final int dimension;
  final int? autoLabelNumber;
  String? linkedSpeakerId;

  /// Hard partition (phone-call side) this cluster was opened in, or null.
  final String? partition;

  /// Normalised voiceprint of the linked speaker (acts as a Bayesian prior).
  Float32List? prior;

  /// Σ wᵢ·eᵢ over confidently assigned, normalised embeddings.
  final Float64List sum;
  double weight = 0;
  int count = 0;

  /// Mean device proximity of the absorbed segments (multi-device cue).
  final ProximityAccumulator proximity = ProximityAccumulator();
  int totalMs = 0;
  int firstStartMs;
  int lastEndMs = 0;
  Float32List centroid;

  void add(Float32List e, double w, int durationMs) {
    addScaledInPlace(sum, e, w);
    weight += w;
    count++;
    totalMs += durationMs;
  }

  void recompute(double priorWeight) {
    final acc = Float64List.fromList(sum);
    final p = prior;
    if (p != null && priorWeight > 0) addScaledInPlace(acc, p, priorWeight);
    centroid = normalizeAccumulator(acc);
  }

  TrackedCluster snapshot() => TrackedCluster(
        key: key,
        linkedSpeakerId: linkedSpeakerId,
        autoLabelNumber: autoLabelNumber,
        centroid: Float32List.fromList(centroid),
        count: count,
        totalMs: totalMs,
        firstStartMs: firstStartMs,
        lastEndMs: lastEndMs,
      );
}

class _Candidate {
  _Candidate.local(this.cluster, this.sim, double bonus)
      : speaker = null,
        score = sim + bonus;
  _Candidate.global(this.speaker, this.sim)
      : cluster = null,
        score = sim;

  final _Cluster? cluster;
  final Speaker? speaker;
  final double sim;
  final double score;

  bool get isLocal => cluster != null;
}

/// Online speaker assignment against global voiceprints and meeting-local
/// clusters. Not thread-safe; use from a single isolate, feeding segments in
/// chronological order.
class SpeakerTracker {
  /// Creates a tracker for one meeting.
  ///
  /// * [knownSpeakers]: global speakers; those with a usable
  ///   [Speaker.centroid] are matchable voiceprints.
  /// * [matchThreshold]: minimum cosine similarity to join a local cluster.
  /// * [knownSpeakerThreshold]: minimum similarity to a global voiceprint
  ///   (defaults to [matchThreshold]).
  /// * [knownSpeakerThresholdOf]: per-voiceprint override of
  ///   [knownSpeakerThreshold] (F18: relaxed for a voiceprint learned on
  ///   another microphone than the meeting's).
  /// * [ambiguityMargin]: required score gap between best and runner-up.
  /// * [localPreference]: score bonus for local clusters over voiceprints.
  /// * [newSpeakerMinDurationMs]: shorter segments never open/update clusters.
  /// * [continuityGapMs]: max silence for inheriting the previous speaker.
  /// * [shortSegmentSwitchMargin]: how much better another local cluster must
  ///   match a short segment (vs. the previous speaker's cluster) to override
  ///   continuity.
  /// * [shortSegmentTurnSwitchMargin]: the same margin when the short
  ///   segment follows a pause of at least [turnTakingGapMs] (a likely turn
  ///   change: short replies such as «نعم» or «موافق» usually come from
  ///   another person).
  /// * [turnTakingGapMs]: silence after which a short segment is treated as
  ///   a possible change of speaker.
  /// * [uncertainInheritConfidence]: confidence cap for a short segment that
  ///   inherits the previous speaker without voice evidence for it (below
  ///   the doubtful threshold, so the transcript and minutes flag it).
  /// * [voiceprintPriorWeight]: weight (in seconds of speech) of a linked
  ///   voiceprint inside its cluster centroid.
  /// * [maxSegmentWeightSec]: cap on a single segment's centroid weight
  ///   (segment weight = its duration in seconds, at least 0.5).
  /// * [maxClusters]: hard cap on local clusters per meeting.
  /// * [knownSpeakerThresholdIn]: phone-call mode, per-voiceprint threshold
  ///   that also depends on the segment's partition (a voiceprint learned
  ///   on a wideband microphone heard through the telephone line); takes
  ///   precedence over [knownSpeakerThresholdOf] when given.
  /// * [firstAutoLabelNumber]: `N` of the first auto label `متحدث N`.
  SpeakerTracker({
    required List<Speaker> knownSpeakers,
    this.matchThreshold = 0.55,
    double? knownSpeakerThreshold,
    this.knownSpeakerThresholdOf,
    this.ambiguityMargin = 0.05,
    this.localPreference = 0.03,
    this.newSpeakerMinDurationMs = 1000,
    this.continuityGapMs = 1500,
    this.shortSegmentSwitchMargin = 0.15,
    this.shortSegmentTurnSwitchMargin = 0.05,
    this.turnTakingGapMs = 250,
    this.uncertainInheritConfidence = 0.35,
    this.voiceprintPriorWeight = 3,
    this.maxSegmentWeightSec = 10,
    this.maxClusters = 64,
    this.channelCueWeight = 0.05,
    this.knownSpeakerThresholdIn,
    int firstAutoLabelNumber = 1,
  })  : knownSpeakerThreshold = knownSpeakerThreshold ?? matchThreshold,
        _nextAutoLabel = firstAutoLabelNumber {
    if (!(matchThreshold > -1 && matchThreshold < 1)) {
      throw ArgumentError.value(matchThreshold, 'matchThreshold');
    }
    if (ambiguityMargin < 0) {
      throw ArgumentError.value(ambiguityMargin, 'ambiguityMargin');
    }
    if (maxClusters < 1) throw ArgumentError.value(maxClusters, 'maxClusters');
    updateKnownSpeakers(knownSpeakers);
  }

  /// Prefix of meeting-local cluster keys.
  static const String localKeyPrefix = 'local:';

  /// True when [key] is a meeting-local cluster key (not a global speaker id).
  static bool isLocalKey(String key) => key.startsWith(localKeyPrefix);

  /// Minimum cosine similarity to join a local cluster.
  final double matchThreshold;

  /// Minimum cosine similarity to match a global voiceprint.
  final double knownSpeakerThreshold;

  /// Per-voiceprint threshold (null: [knownSpeakerThreshold] for all).
  final double Function(Speaker speaker)? knownSpeakerThresholdOf;

  /// Per-voiceprint threshold given the segment's partition (null: no
  /// partition dependence).
  final double Function(Speaker speaker, String? partition)?
      knownSpeakerThresholdIn;

  double _thresholdOf(_Candidate c) {
    if (c.isLocal) return matchThreshold;
    final inPartition = knownSpeakerThresholdIn;
    if (inPartition != null) return inPartition(c.speaker!, _part);
    final of = knownSpeakerThresholdOf;
    return of == null ? knownSpeakerThreshold : of(c.speaker!);
  }

  /// Required gap between best and second-best candidate scores.
  final double ambiguityMargin;

  /// Score bonus for meeting-local clusters.
  final double localPreference;

  /// Segments shorter than this never create or update clusters.
  final double newSpeakerMinDurationMs;

  /// Maximum silence gap for inheriting the previous speaker.
  final int continuityGapMs;

  /// Margin a short segment needs to switch away from the previous speaker.
  final double shortSegmentSwitchMargin;

  /// Smaller switch margin for short segments after a pause.
  final double shortSegmentTurnSwitchMargin;

  /// Pause (ms) after which a short segment may be another speaker.
  final int turnTakingGapMs;

  /// Confidence cap for doubtful inherited short segments.
  final double uncertainInheritConfidence;

  /// Weight (seconds of speech) of a linked voiceprint in its cluster.
  final double voiceprintPriorWeight;

  /// Cap on one segment's centroid weight, in seconds.
  final double maxSegmentWeightSec;

  /// Maximum number of local clusters.
  final int maxClusters;

  /// Largest score shift from the multi-device proximity cue.
  final double channelCueWeight;

  /// Cue bonus of cluster [c] for a segment with proximity [prox].
  double _cueBonus(_Cluster c, Map<String, double>? prox) {
    if (prox == null || channelCueWeight <= 0) return 0;
    final evidence = math.min(1.0, c.proximity.evidence / 3);
    if (evidence <= 0) return 0;
    return channelCueWeight * evidence * proximityCue(prox, c.proximity.mean());
  }

  final List<_Cluster> _clusters = [];
  final Map<String, String> _redirects = {};
  List<Speaker> _known = const [];
  int? _dimension;
  int _nextOrdinal = 1;
  int _nextAutoLabel;
  _Cluster? _last;
  int? _lastEndMs;

  /// Partition of the segment being assigned (null: none).
  String? _part;
  final Map<String, _Cluster?> _lastIn = {};
  final Map<String, int> _lastEndIn = {};

  /// Embedding dimension fixed by the first usable embedding (null before).
  int? get dimension => _dimension;

  /// Snapshots of all local clusters, in creation order.
  List<TrackedCluster> get clusters =>
      List.unmodifiable(_clusters.map((c) => c.snapshot()));

  /// Snapshot of cluster [key] (merged-away keys are followed), or null.
  TrackedCluster? cluster(String key) => _find(key)?.snapshot();

  /// Resolves a cluster key that may have been merged away to the key of the
  /// cluster that absorbed it. Unknown keys are returned unchanged.
  String resolveKey(String key) {
    var k = key;
    for (var guard = 0; guard < 1000; guard++) {
      final next = _redirects[k];
      if (next == null) return k;
      k = next;
    }
    return k;
  }

  /// Replaces the set of global voiceprints (e.g. after the user renamed or
  /// forgot a speaker mid-meeting). Priors of linked clusters are refreshed.
  void updateKnownSpeakers(List<Speaker> knownSpeakers) {
    _known = List.unmodifiable(knownSpeakers);
    for (final c in _clusters) {
      final id = c.linkedSpeakerId;
      if (id == null) continue;
      c.prior = _priorFor(id, c.dimension);
      c.recompute(voiceprintPriorWeight);
    }
  }

  /// Assigns one segment. Call in chronological order.
  ///
  /// [embedding] may be null (segment too short/silent to embed). Embeddings
  /// that are non-finite, zero, or of a different dimension than the first
  /// usable one are treated as missing.
  ///
  /// [channels] (multi-device meetings): SNR per device for this segment;
  /// see the file header.
  SpeakerAssignment assign({
    required int segmentIndex,
    required int startMs,
    required int endMs,
    Float32List? embedding,
    ChannelProfile? channels,
  }) {
    final durationMs = math.max(0, endMs - startMs);
    final e = _prepare(embedding);
    final profile = channels != null && channels.isInformative ? channels : null;
    final prox = profile?.proximity();
    final part = _part = channels?.partition;
    // Clusters this segment may join: all of them, or (phone-call mode)
    // those of its partition and those opened without one.
    final pool = part == null
        ? _clusters
        : [
            for (final c in _clusters)
              if (c.partition == null || c.partition == part) c,
          ];

    var prev = part == null ? _last : _lastIn[part];
    if (prev != null && !pool.contains(prev)) prev = null;
    final prevEnd = part == null ? _lastEndMs : _lastEndIn[part];
    final gap = prevEnd == null ? null : math.max(0, startMs - prevEnd);
    final continuity = prev != null && gap != null && gap < continuityGapMs;

    // --- No embedding --------------------------------------------------------
    if (e == null) {
      if (continuity) {
        // After a real pause a short reply ("نعم", "تمام") is usually
        // someone else answering: keep the label but mark it doubtful.
        final c = _continuityConfidence(gap);
        return _commit(
          segmentIndex: segmentIndex,
          cluster: prev,
          endMs: endMs,
          decision: AssignmentDecision.inherited,
          confidence: gap >= turnTakingGapMs
              ? math.min(c, uncertainInheritConfidence)
              : c,
        );
      }
      return _unknown(segmentIndex, endMs);
    }

    final localSims = <double>[
      for (final c in pool) cosine(e, c.centroid),
    ];

    // --- Short segment: never create or update clusters ---------------------
    if (durationMs < newSpeakerMinDurationMs) {
      final (bi, best, second) = bestAndSecond(localSims);
      final margin = second.isFinite ? best - second : null;
      if (continuity) {
        final prevSim = localSims[pool.indexOf(prev)];
        // After a real pause the floor may have changed hands, so a smaller
        // margin is enough to switch to another local speaker.
        final afterPause = gap >= turnTakingGapMs;
        final switchMargin = afterPause
            ? math.min(shortSegmentSwitchMargin, shortSegmentTurnSwitchMargin)
            : shortSegmentSwitchMargin;
        if (bi >= 0 &&
            !identical(pool[bi], prev) &&
            best >= matchThreshold &&
            best - prevSim >= switchMargin) {
          return _commit(
            segmentIndex: segmentIndex,
            cluster: pool[bi],
            endMs: endMs,
            decision: AssignmentDecision.weakMatch,
            similarity: best,
            margin: best - prevSim,
            confidence:
                0.6 * _matchConfidence(best, best - prevSim, matchThreshold),
          );
        }
        // The voice does not resemble the previous speaker either: inherit
        // the label, but flag it as doubtful.
        final c = _continuityConfidence(gap);
        final doubtful = prevSim < matchThreshold &&
            (afterPause || prevSim < matchThreshold - 0.1);
        return _commit(
          segmentIndex: segmentIndex,
          cluster: prev,
          endMs: endMs,
          decision: AssignmentDecision.inherited,
          similarity: prevSim,
          confidence: doubtful ? math.min(c, uncertainInheritConfidence) : c,
        );
      }
      if (bi >= 0 && best >= matchThreshold) {
        return _commit(
          segmentIndex: segmentIndex,
          cluster: pool[bi],
          endMs: endMs,
          decision: AssignmentDecision.weakMatch,
          similarity: best,
          margin: margin,
          confidence:
              0.6 * _matchConfidence(best, margin ?? 1, matchThreshold),
        );
      }
      return _unknown(segmentIndex, endMs, similarity: bi >= 0 ? best : null);
    }

    // --- Long segment --------------------------------------------------------
    final candidates = <_Candidate>[
      for (var i = 0; i < pool.length; i++)
        _Candidate.local(
          pool[i],
          localSims[i],
          localPreference + _cueBonus(pool[i], prox),
        ),
      for (final s in _unclaimedKnown(e.length))
        _Candidate.global(s, cosine(e, s.centroid!)),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final best = candidates.isEmpty ? null : candidates.first;
    final secondScore =
        candidates.length > 1 ? candidates[1].score : double.negativeInfinity;
    final margin = best == null || !secondScore.isFinite
        ? null
        : best.score - secondScore;

    final bestQualifies = best != null &&
        best.sim >= _thresholdOf(best);

    if (bestQualifies) {
      final clear = margin == null || margin >= ambiguityMargin;
      if (clear) {
        final threshold = _thresholdOf(best);
        final conf = _matchConfidence(best.sim, margin ?? 1, threshold);
        if (best.isLocal) {
          final c = best.cluster!;
          _absorb(c, e, durationMs, startMs, profile);
          return _commit(
            segmentIndex: segmentIndex,
            cluster: c,
            endMs: endMs,
            decision: AssignmentDecision.matchedCluster,
            similarity: best.sim,
            margin: margin,
            confidence: conf,
          );
        }
        if (_clusters.length < maxClusters) {
          final c = _newCluster(
            startMs,
            e.length,
            linkTo: best.speaker!.id,
            partition: part,
          );
          _absorb(c, e, durationMs, startMs, profile);
          return _commit(
            segmentIndex: segmentIndex,
            cluster: c,
            endMs: endMs,
            decision: AssignmentDecision.matchedKnownSpeaker,
            similarity: best.sim,
            margin: margin,
            confidence: conf,
            created: true,
          );
        }
      } else {
        // Too close to call. Candidates within the margin of the winner:
        final tied = candidates
            .where((c) => c.score >= best.score - ambiguityMargin)
            .toList();
        final ambiguousConf =
            0.5 * _matchConfidence(best.sim, margin, matchThreshold);
        if (continuity) {
          for (final c in tied) {
            if (identical(c.cluster, prev) && c.sim >= matchThreshold) {
              return _commit(
                segmentIndex: segmentIndex,
                cluster: prev,
                endMs: endMs,
                decision: AssignmentDecision.ambiguousContinuity,
                similarity: c.sim,
                margin: margin,
                confidence: ambiguousConf,
              );
            }
          }
        }
        // Prefer an existing local cluster among the tied candidates.
        for (final c in tied) {
          if (c.isLocal && c.sim >= matchThreshold) {
            return _commit(
              segmentIndex: segmentIndex,
              cluster: c.cluster!,
              endMs: endMs,
              decision: AssignmentDecision.ambiguousBest,
              similarity: c.sim,
              margin: margin,
              confidence: ambiguousConf,
            );
          }
        }
        // Only voiceprints are tied: do not commit to a name; a fresh,
        // unlinked cluster lets offline refinement decide later.
      }
    }

    if (_clusters.length >= maxClusters) {
      final (bi, bestSim, second) = bestAndSecond(localSims);
      if (bi >= 0) {
        return _commit(
          segmentIndex: segmentIndex,
          cluster: pool[bi],
          endMs: endMs,
          decision: AssignmentDecision.weakMatch,
          similarity: bestSim,
          margin: second.isFinite ? bestSim - second : null,
          confidence: 0.2,
        );
      }
      return _unknown(segmentIndex, endMs);
    }

    final c = _newCluster(startMs, e.length, partition: part);
    _absorb(c, e, durationMs, startMs, profile);
    final bestSim = best?.sim;
    return _commit(
      segmentIndex: segmentIndex,
      cluster: c,
      endMs: endMs,
      decision: AssignmentDecision.newCluster,
      similarity: 1,
      margin: margin,
      confidence: bestSim == null
          ? 1
          : _clamp01(0.5 + (matchThreshold - bestSim) / 0.5),
      created: true,
    );
  }

  /// Links cluster [clusterKey] to global speaker [speakerId] (e.g. after the
  /// session created a speaker record for a new cluster, or the user named
  /// it). If another cluster is already linked to [speakerId], the two
  /// clusters are merged (they are the same person). [voiceprint] overrides
  /// the speaker's centroid from the known-speaker list as the cluster prior.
  ///
  /// Returns the key of the surviving cluster. Throws an [ArgumentError] for
  /// an unknown cluster key.
  String linkCluster(String clusterKey, String speakerId,
      {Float32List? voiceprint}) {
    final c = _find(clusterKey);
    if (c == null) throw ArgumentError.value(clusterKey, 'clusterKey');
    final other = _clusters.firstWhereOrNull(
        (o) => !identical(o, c) && o.linkedSpeakerId == speakerId);
    c.linkedSpeakerId = speakerId;
    final vp = voiceprint != null && isUsableEmbedding(voiceprint, dimension: c.dimension)
        ? l2Normalize(voiceprint)
        : _priorFor(speakerId, c.dimension);
    c.prior = vp;
    c.recompute(voiceprintPriorWeight);
    if (other != null) {
      return mergeClusters(c.key, other.key);
    }
    return c.key;
  }

  /// Merges cluster [fromKey] into [intoKey] (the user said they are the same
  /// person). The surviving cluster is the older of the two; its key is
  /// returned and the other key is redirected to it ([resolveKey]).
  ///
  /// Throws an [ArgumentError] for unknown keys or when both clusters are
  /// linked to different global speakers.
  String mergeClusters(String fromKey, String intoKey) {
    final a = _find(fromKey);
    final b = _find(intoKey);
    if (a == null) throw ArgumentError.value(fromKey, 'fromKey');
    if (b == null) throw ArgumentError.value(intoKey, 'intoKey');
    if (identical(a, b)) return b.key;
    if (a.linkedSpeakerId != null &&
        b.linkedSpeakerId != null &&
        a.linkedSpeakerId != b.linkedSpeakerId) {
      throw ArgumentError(
          'Cannot merge clusters linked to different speakers '
          '(${a.linkedSpeakerId} vs ${b.linkedSpeakerId})');
    }
    final ia = _clusters.indexOf(a);
    final ib = _clusters.indexOf(b);
    final keep = ia < ib ? a : b;
    final drop = ia < ib ? b : a;
    for (var i = 0; i < keep.sum.length; i++) {
      keep.sum[i] += drop.sum[i];
    }
    keep.weight += drop.weight;
    keep.proximity.addAll(drop.proximity);
    keep.count += drop.count;
    keep.totalMs += drop.totalMs;
    keep.firstStartMs = math.min(keep.firstStartMs, drop.firstStartMs);
    keep.lastEndMs = math.max(keep.lastEndMs, drop.lastEndMs);
    keep.linkedSpeakerId ??= drop.linkedSpeakerId;
    keep.prior ??= drop.prior;
    keep.recompute(voiceprintPriorWeight);
    _clusters.remove(drop);
    _redirects[drop.key] = keep.key;
    if (identical(_last, drop)) _last = keep;
    for (final k in _lastIn.keys.toList()) {
      if (identical(_lastIn[k], drop)) _lastIn[k] = keep;
    }
    return keep.key;
  }

  // ---------------------------------------------------------------------------

  _Cluster? _find(String key) {
    final k = resolveKey(key);
    for (final c in _clusters) {
      if (c.key == k) return c;
    }
    return null;
  }

  Float32List? _prepare(Float32List? embedding) {
    if (embedding == null) return null;
    final dim = _dimension;
    if (!isUsableEmbedding(embedding, dimension: dim)) return null;
    _dimension ??= embedding.length;
    return l2Normalize(embedding);
  }

  Float32List? _priorFor(String speakerId, int dimension) {
    for (final s in _known) {
      if (s.id != speakerId) continue;
      final c = s.centroid;
      if (c != null && isUsableEmbedding(c, dimension: dimension)) {
        return l2Normalize(c);
      }
    }
    return null;
  }

  Iterable<Speaker> _unclaimedKnown(int dimension) sync* {
    final claimed = {
      for (final c in _clusters)
        if (c.linkedSpeakerId != null) c.linkedSpeakerId!,
    };
    for (final s in _known) {
      if (claimed.contains(s.id)) continue;
      if (!isUsableEmbedding(s.centroid, dimension: dimension)) continue;
      yield s;
    }
  }

  _Cluster _newCluster(
    int startMs,
    int dimension, {
    String? linkTo,
    String? partition,
  }) {
    final c = _Cluster(
      partition: partition,
      key: '$localKeyPrefix${_nextOrdinal++}',
      dimension: dimension,
      firstStartMs: startMs,
      autoLabelNumber: linkTo == null ? _nextAutoLabel++ : null,
      linkedSpeakerId: linkTo,
      prior: linkTo == null ? null : _priorFor(linkTo, dimension),
    );
    _clusters.add(c);
    return c;
  }

  void _absorb(
    _Cluster c,
    Float32List e,
    int durationMs,
    int startMs, [
    ChannelProfile? profile,
  ]) {
    final w = (durationMs / 1000).clamp(0.5, math.max(0.5, maxSegmentWeightSec));
    c.add(e, w.toDouble(), durationMs);
    if (profile != null) c.proximity.add(profile, w.toDouble());
    c.firstStartMs = math.min(c.firstStartMs, startMs);
    c.recompute(voiceprintPriorWeight);
  }

  SpeakerAssignment _commit({
    required int segmentIndex,
    required _Cluster cluster,
    required int endMs,
    required AssignmentDecision decision,
    required double confidence,
    double? similarity,
    double? margin,
    bool created = false,
  }) {
    cluster.lastEndMs = math.max(cluster.lastEndMs, endMs);
    _last = cluster;
    _lastEndMs = math.max(_lastEndMs ?? endMs, endMs);
    final part = _part;
    if (part != null) {
      _lastIn[part] = cluster;
      _lastEndIn[part] = math.max(_lastEndIn[part] ?? endMs, endMs);
    }
    return SpeakerAssignment(
      segmentIndex: segmentIndex,
      clusterKey: cluster.key,
      linkedSpeakerId: cluster.linkedSpeakerId,
      autoLabelNumber: cluster.autoLabelNumber,
      similarity: similarity,
      margin: margin,
      confidence: _clamp01(confidence),
      decision: decision,
      createdCluster: created,
    );
  }

  SpeakerAssignment _unknown(int segmentIndex, int endMs,
      {double? similarity}) {
    // An unknown segment breaks continuity: the next short segment must not
    // inherit across it.
    _last = null;
    _lastEndMs = math.max(_lastEndMs ?? endMs, endMs);
    final part = _part;
    if (part != null) {
      _lastIn[part] = null;
      _lastEndIn[part] = math.max(_lastEndIn[part] ?? endMs, endMs);
    }
    return SpeakerAssignment(
      segmentIndex: segmentIndex,
      similarity: similarity,
      confidence: 0,
      decision: AssignmentDecision.unknown,
    );
  }

  double _continuityConfidence(int? gap) {
    final g = (gap ?? continuityGapMs).toDouble();
    return 0.3 + 0.3 * _clamp01(1 - g / math.max(1, continuityGapMs));
  }

  double _matchConfidence(double sim, double margin, double threshold) =>
      _clamp01(0.5 + (sim - threshold) / 0.5) *
      _clamp01(0.5 + margin / math.max(1e-6, 4 * ambiguityMargin));

  static double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);
}
