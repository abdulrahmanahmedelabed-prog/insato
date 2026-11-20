// Offline speaker refinement: agglomerative re-clustering of every segment
// embedding of a meeting, then one-to-one linking of the resulting clusters to
// global voiceprints.
//
// Pure Dart (no Flutter imports): runs in isolates and plain unit tests.
//
// Algorithm overview ([refineSpeakers]):
//
// 1. Validate embeddings (finite, non-zero, majority dimension) and
//    L2-normalise them. Each segment is weighted by its duration
//    (clamped to [0.5 s, maxSegmentWeightSec]) because long segments produce
//    more reliable embeddings.
// 2. User-locked segments become *anchors*: all segments locked to the same
//    speaker start in one cluster (must-link) and clusters anchored to
//    different speakers never merge (cannot-link).
// 3. Weighted average-linkage (UPGMA) agglomerative clustering with cosine
//    similarity, stopping when the best pair falls below `clusterThreshold`.
//    Uses a packed triangular Float32 similarity matrix (n·(n−1)/2 floats,
//    ≈18 MB for 3000 segments), SIMD dot products and a cached
//    nearest-neighbour per row, giving ~O(n²) time in practice.
// 4. Tiny clusters (< `tinyClusterMaxMs` of speech) are merged into the
//    substantial cluster with the highest average linkage when it is
//    ≥ `tinyMergeThreshold` — except that a tiny cluster matching a known
//    voiceprint (≥ `linkThreshold`) only merges into a cluster matching the
//    same voiceprint, so a short utterance of a known speaker is still linked
//    to them in step 5 instead of being attributed to whoever spoke longest.
// 5. Anchored clusters link to their locked speaker. The remaining clusters
//    are linked one-to-one to unclaimed voiceprints by maximum-weight
//    bipartite matching (Hungarian algorithm) on `sim − linkThreshold`, so two
//    clusters never map to the same known speaker. An unlinked cluster whose
//    best voiceprint is already taken by another cluster is merged into that
//    cluster when their centroids are similar enough (the clustering split one
//    person in two).

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/models.dart';
import 'channel_cue.dart';
import 'vector_math.dart';

/// How a [RefinedCluster] got its [RefinedCluster.linkedSpeakerId].
enum ClusterLinkReason {
  /// The cluster contains user-locked segments of that speaker.
  locked,

  /// The cluster centroid matched the speaker's voiceprint.
  voiceprint,

  /// Not linked: a new speaker.
  none,
}

/// One speaker cluster produced by [refineSpeakers].
class RefinedCluster {
  /// Creates a cluster. Normally only produced by [refineSpeakers].
  const RefinedCluster({
    required this.id,
    required this.segmentIds,
    required this.centroid,
    required this.totalMs,
    required this.linkReason,
    this.linkedSpeakerId,
    this.linkSimilarity,
  });

  /// Stable id within one result: `cluster:1`, `cluster:2`, … in order of
  /// first appearance in the input items.
  final String id;

  /// Segment ids in this cluster, in input order.
  final List<String> segmentIds;

  /// L2-normalised, duration-weighted centroid.
  final Float32List centroid;

  /// Total speech duration of the member segments, in ms.
  final int totalMs;

  /// Existing global speaker id, or null for a new speaker.
  final String? linkedSpeakerId;

  /// Cosine similarity between [centroid] and the linked speaker's voiceprint
  /// (null when not linked or the speaker has no voiceprint).
  final double? linkSimilarity;

  /// Why the cluster is (not) linked.
  final ClusterLinkReason linkReason;

  /// True when the cluster should become a new speaker record.
  bool get isNewSpeaker => linkedSpeakerId == null;
}

/// Output of [refineSpeakers].
class RefinementResult {
  /// Creates a result. Normally only produced by [refineSpeakers].
  RefinementResult({
    required List<RefinedCluster> clusters,
    required Map<String, String> clusterIdBySegment,
    required List<String> skippedSegmentIds,
  })  : clusters = List.unmodifiable(clusters),
        clusterIdBySegment = Map.unmodifiable(clusterIdBySegment),
        skippedSegmentIds = List.unmodifiable(skippedSegmentIds),
        _byId = {for (final c in clusters) c.id: c};

  /// Clusters in order of first appearance.
  final List<RefinedCluster> clusters;

  /// Segment id → cluster id for every clustered segment.
  final Map<String, String> clusterIdBySegment;

  /// Segment ids that were not clustered (missing / invalid embedding or a
  /// different embedding dimension). Callers should keep their current
  /// speaker (or inherit from neighbours).
  final List<String> skippedSegmentIds;

  final Map<String, RefinedCluster> _byId;

  /// Cluster id → centroid.
  Map<String, Float32List> get centroids =>
      {for (final c in clusters) c.id: c.centroid};

  /// Cluster id → linked existing speaker id (null = new speaker).
  Map<String, String?> get speakerIdByCluster =>
      {for (final c in clusters) c.id: c.linkedSpeakerId};

  /// The cluster with id [clusterId], or null.
  RefinedCluster? clusterById(String clusterId) => _byId[clusterId];

  /// The cluster containing [segmentId], or null when it was skipped.
  RefinedCluster? clusterOf(String segmentId) {
    final id = clusterIdBySegment[segmentId];
    return id == null ? null : _byId[id];
  }

  /// Linked existing speaker id for [segmentId] (null when the segment's
  /// cluster is a new speaker or the segment was skipped).
  String? speakerIdForSegment(String segmentId) =>
      clusterOf(segmentId)?.linkedSpeakerId;
}

/// Re-clusters all segment embeddings of a meeting and links clusters to
/// known speakers. See the file header for the algorithm.
///
/// * [items]: `(segmentId, embedding, durationMs)` per segment, preferably in
///   chronological order (cluster ids follow first appearance). Segment ids
///   must be unique.
/// * [knownSpeakers]: global speakers; usable [Speaker.centroid]s are linkable.
/// * [clusterThreshold]: average-linkage cosine similarity needed to merge
///   (equivalently, cosine distance ≤ `1 − clusterThreshold`).
/// * [linkThreshold]: minimum centroid ↔ voiceprint similarity to link.
/// * [lockedAssignments]: segment id → speaker id fixed by the user. Those
///   segments keep their speaker and anchor their cluster to it.
/// * [tinyClusterMaxMs], [tinyMergeThreshold]: tiny-cluster cleanup
///   (average-linkage similarity; see step 4 in the file header). Also the
///   attach threshold for segments left out of the matrix.
/// * [voiceprintMergeThreshold]: centroid similarity needed to merge an
///   unlinked cluster into the cluster holding its best-matching voiceprint.
/// * [maxSegmentWeightSec]: cap on one segment's weight, in seconds.
/// * [maxMatrixItems]: above this many initial clusters, only the longest
///   segments are clustered agglomeratively and the rest are attached to the
///   nearest cluster, bounding memory to `maxMatrixItems²/2` floats.
/// * [channelProfiles] (v1.2 C, multi-device meetings): segment id → SNR per
///   device. When present, step 3 clusters [augmentWithChannelCue] vectors
///   (voice cosine + a small "same nearest device" term); centroids, tiny
///   cluster cleanup and linking still use the voice embeddings only.
///
/// Throws an [ArgumentError] on duplicate segment ids or invalid thresholds.
RefinementResult refineSpeakers({
  required List<(String segmentId, Float32List embedding, int durationMs)>
      items,
  required List<Speaker> knownSpeakers,
  double clusterThreshold = 0.5,
  double linkThreshold = 0.6,
  Map<String, String> lockedAssignments = const {},
  int tinyClusterMaxMs = 2000,
  double tinyMergeThreshold = 0.3,
  double voiceprintMergeThreshold = 0.4,
  double maxSegmentWeightSec = 4,
  int maxMatrixItems = 3000,
  Map<String, ChannelProfile> channelProfiles = const {},
}) {
  if (!clusterThreshold.isFinite) {
    throw ArgumentError.value(clusterThreshold, 'clusterThreshold');
  }
  if (!linkThreshold.isFinite) {
    throw ArgumentError.value(linkThreshold, 'linkThreshold');
  }
  if (maxMatrixItems < 2) {
    throw ArgumentError.value(maxMatrixItems, 'maxMatrixItems');
  }
  final seen = <String>{};
  for (final it in items) {
    if (!seen.add(it.$1)) {
      throw ArgumentError.value(it.$1, 'items', 'Duplicate segment id');
    }
  }

  // Phone-call mode: segments of different sides never share a cluster.
  final partitions = <String?>{
    for (final it in items) channelProfiles[it.$1]?.partition,
  };
  if (partitions.length >= 2) {
    return _refinePartitioned(
      items: items,
      partitions: partitions,
      knownSpeakers: knownSpeakers,
      clusterThreshold: clusterThreshold,
      linkThreshold: linkThreshold,
      lockedAssignments: lockedAssignments,
      tinyClusterMaxMs: tinyClusterMaxMs,
      tinyMergeThreshold: tinyMergeThreshold,
      voiceprintMergeThreshold: voiceprintMergeThreshold,
      maxSegmentWeightSec: maxSegmentWeightSec,
      maxMatrixItems: maxMatrixItems,
      channelProfiles: channelProfiles,
    );
  }

  // --- 1. Validate & normalise --------------------------------------------
  final dimCounts = <int, int>{};
  for (final it in items) {
    if (isUsableEmbedding(it.$2)) {
      dimCounts.update(it.$2.length, (c) => c + 1, ifAbsent: () => 1);
    }
  }
  int? dim;
  var bestCount = 0;
  dimCounts.forEach((d, c) {
    if (c > bestCount) {
      bestCount = c;
      dim = d;
    }
  });

  final ids = <String>[];
  final vecs = <Float32List>[];
  final durations = <int>[];
  final weights = <double>[];
  final skipped = <String>[];
  for (final it in items) {
    if (dim == null || !isUsableEmbedding(it.$2, dimension: dim)) {
      skipped.add(it.$1);
      continue;
    }
    ids.add(it.$1);
    vecs.add(l2Normalize(it.$2));
    final dur = math.max(0, it.$3);
    durations.add(dur);
    weights.add(_segmentWeight(dur, maxSegmentWeightSec));
  }
  if (ids.isEmpty) {
    return RefinementResult(
        clusters: const [], clusterIdBySegment: const {}, skippedSegmentIds: skipped);
  }
  final d = dim!;

  // --- 2. Anchors -----------------------------------------------------------
  final anchorSpeakers = <String>[]; // anchor index → speaker id
  final anchorIndex = <String, int>{};
  final anchors = List<int?>.filled(ids.length, null);
  for (var i = 0; i < ids.length; i++) {
    final sp = lockedAssignments[ids[i]];
    if (sp == null) continue;
    anchors[i] = anchorIndex.putIfAbsent(sp, () {
      anchorSpeakers.add(sp);
      return anchorSpeakers.length - 1;
    });
  }

  // --- 3. Agglomerative clustering -----------------------------------------
  final channels = <String>{
    for (final id in ids)
      if (channelProfiles[id] case final p? when p.isInformative)
        ...p.snrDb.keys,
  }.toList()..sort();
  final useCue = channels.length >= 2;
  final labels = agglomerativeCluster(
    useCue
        ? [
            for (var i = 0; i < ids.length; i++)
              augmentWithChannelCue(vecs[i], channelProfiles[ids[i]], channels),
          ]
        : vecs,
    threshold: clusterThreshold,
    weights: weights,
    anchors: anchors,
    maxMatrixItems: maxMatrixItems,
    fallbackAttachThreshold: tinyMergeThreshold,
    voiceprints: [
      for (final s in knownSpeakers)
        if (isUsableEmbedding(s.centroid, dimension: d))
          useCue
              ? (Float32List(d + channels.length)
                  ..setAll(0, l2Normalize(s.centroid!)))
              : l2Normalize(s.centroid!),
    ],
    voiceprintThreshold: linkThreshold,
  );

  final groups = <int, _Group>{};
  for (var i = 0; i < ids.length; i++) {
    final g = groups.putIfAbsent(labels[i], () => _Group(d));
    g.add(i, vecs[i], weights[i], durations[i], anchors[i]);
  }
  var clusters = groups.values.toList();
  for (final g in clusters) {
    g.recompute();
  }

  final speakerById = <String, Speaker>{for (final s in knownSpeakers) s.id: s};
  Float32List? voiceprintOf(String speakerId) {
    final c = speakerById[speakerId]?.centroid;
    return isUsableEmbedding(c, dimension: d) ? l2Normalize(c!) : null;
  }

  final allVoiceprints = <(String, Float32List)>[
    for (final s in knownSpeakers)
      if (voiceprintOf(s.id) case final vp?) (s.id, vp),
  ];

  // --- 4. Tiny clusters -----------------------------------------------------
  // Before linking, but never absorbing a tiny cluster that is clearly a
  // known voice into a cluster of someone else: it must reach step 5.
  clusters = _mergeTinyClusters(clusters, tinyClusterMaxMs, tinyMergeThreshold,
      allVoiceprints, linkThreshold);

  // --- 5. Linking -----------------------------------------------------------
  for (final g in clusters) {
    final a = g.anchor;
    if (a != null) {
      g.linkedSpeakerId = anchorSpeakers[a];
      g.linkReason = ClusterLinkReason.locked;
      final vp = voiceprintOf(g.linkedSpeakerId!);
      g.linkSimilarity = vp == null ? null : cosine(g.centroid, vp);
    }
  }
  final claimed = {for (final a in anchorSpeakers) a};
  final candidates = <(String, Float32List)>[
    for (final s in knownSpeakers)
      if (!claimed.contains(s.id))
        if (voiceprintOf(s.id) case final vp?) (s.id, vp),
  ];
  final free = [for (final g in clusters) if (g.anchor == null) g];
  if (free.isNotEmpty && candidates.isNotEmpty) {
    final sims = [
      for (final g in free)
        [for (final c in candidates) cosine(g.centroid, c.$2)],
    ];
    final w = [
      for (final row in sims)
        [for (final s in row) s >= linkThreshold ? s - linkThreshold + 1e-9 : 0.0],
    ];
    final match = hungarianMaximize(w);
    for (var r = 0; r < free.length; r++) {
      final c = match[r];
      if (c < 0 || w[r][c] <= 0) continue;
      free[r].linkedSpeakerId = candidates[c].$1;
      free[r].linkReason = ClusterLinkReason.voiceprint;
      free[r].linkSimilarity = sims[r][c];
    }
  }

  // Unlinked clusters whose best voiceprint went to another cluster (by
  // voiceprint or by a user lock): the clustering probably split one person
  // — merge when the centroids agree too.
  final unlinked = [
    for (final g in clusters)
      if (g.linkedSpeakerId == null) g,
  ]..sort((a, b) => b.totalMs.compareTo(a.totalMs));
  for (final g in unlinked) {
    String? bestId;
    var bestS = double.negativeInfinity;
    for (final (id, vp) in allVoiceprints) {
      final s = cosine(g.centroid, vp);
      if (s > bestS) {
        bestS = s;
        bestId = id;
      }
    }
    if (bestId == null || bestS < linkThreshold) continue;
    _Group? target;
    for (final o in clusters) {
      if (!identical(o, g) && o.linkedSpeakerId == bestId) target = o;
    }
    if (target == null) continue;
    if (cosine(g.centroid, target.centroid) >= voiceprintMergeThreshold) {
      target.absorb(g);
      target.recompute();
      final vp = voiceprintOf(bestId);
      if (vp != null) target.linkSimilarity = cosine(target.centroid, vp);
      clusters.remove(g);
    }
  }

  // --- 6. Output ------------------------------------------------------------
  for (final g in clusters) {
    g.members.sort();
  }
  clusters.sort((a, b) => a.members.first.compareTo(b.members.first));
  final out = <RefinedCluster>[];
  final bySegment = <String, String>{};
  for (var k = 0; k < clusters.length; k++) {
    final g = clusters[k];
    final id = 'cluster:${k + 1}';
    final segIds = [for (final m in g.members) ids[m]];
    for (final s in segIds) {
      bySegment[s] = id;
    }
    out.add(RefinedCluster(
      id: id,
      segmentIds: List.unmodifiable(segIds),
      centroid: g.centroid,
      totalMs: g.totalMs,
      linkedSpeakerId: g.linkedSpeakerId,
      linkSimilarity: g.linkSimilarity,
      linkReason: g.linkReason,
    ));
  }
  return RefinementResult(
      clusters: out, clusterIdBySegment: bySegment, skippedSegmentIds: skipped);
}

/// [refineSpeakers] for items carrying hard partitions
/// ([ChannelProfile.partition], phone-call sides): each partition (items
/// without one form their own group) is refined on its own, then the
/// results are merged. A voiceprint linked by similarity in two partitions
/// stays with the better-matching cluster; user locks are kept as given.
RefinementResult _refinePartitioned({
  required List<(String segmentId, Float32List embedding, int durationMs)>
      items,
  required Set<String?> partitions,
  required List<Speaker> knownSpeakers,
  required double clusterThreshold,
  required double linkThreshold,
  required Map<String, String> lockedAssignments,
  required int tinyClusterMaxMs,
  required double tinyMergeThreshold,
  required double voiceprintMergeThreshold,
  required double maxSegmentWeightSec,
  required int maxMatrixItems,
  required Map<String, ChannelProfile> channelProfiles,
}) {
  final order = <String, int>{
    for (var i = 0; i < items.length; i++) items[i].$1: i,
  };
  final merged = <RefinedCluster>[];
  final skipped = <String>[];
  for (final part in partitions) {
    final group = [
      for (final it in items)
        if (channelProfiles[it.$1]?.partition == part) it,
    ];
    if (group.isEmpty) continue;
    final ids = {for (final it in group) it.$1};
    final r = refineSpeakers(
      items: group,
      knownSpeakers: knownSpeakers,
      clusterThreshold: clusterThreshold,
      linkThreshold: linkThreshold,
      lockedAssignments: {
        for (final e in lockedAssignments.entries)
          if (ids.contains(e.key)) e.key: e.value,
      },
      tinyClusterMaxMs: tinyClusterMaxMs,
      tinyMergeThreshold: tinyMergeThreshold,
      voiceprintMergeThreshold: voiceprintMergeThreshold,
      maxSegmentWeightSec: maxSegmentWeightSec,
      maxMatrixItems: maxMatrixItems,
      channelProfiles: {
        for (final id in ids)
          if (channelProfiles[id] case final p?) id: p.withoutPartition(),
      },
    );
    merged.addAll(r.clusters);
    skipped.addAll(r.skippedSegmentIds);
  }
  // One voiceprint, one cluster (similarity links only).
  final bestBySpeaker = <String, RefinedCluster>{};
  for (final c in merged) {
    final sid = c.linkedSpeakerId;
    if (sid == null || c.linkReason != ClusterLinkReason.voiceprint) continue;
    final cur = bestBySpeaker[sid];
    if (cur == null || (c.linkSimilarity ?? 0) > (cur.linkSimilarity ?? 0)) {
      bestBySpeaker[sid] = c;
    }
  }
  int firstOf(RefinedCluster c) =>
      c.segmentIds.map((id) => order[id] ?? 0).fold(1 << 30, math.min);
  merged.sort((a, b) => firstOf(a).compareTo(firstOf(b)));
  final out = <RefinedCluster>[];
  final bySegment = <String, String>{};
  for (var k = 0; k < merged.length; k++) {
    final c = merged[k];
    final id = 'cluster:${k + 1}';
    final loses = c.linkReason == ClusterLinkReason.voiceprint &&
        !identical(bestBySpeaker[c.linkedSpeakerId], c);
    for (final s in c.segmentIds) {
      bySegment[s] = id;
    }
    out.add(RefinedCluster(
      id: id,
      segmentIds: c.segmentIds,
      centroid: c.centroid,
      totalMs: c.totalMs,
      linkedSpeakerId: loses ? null : c.linkedSpeakerId,
      linkSimilarity: loses ? null : c.linkSimilarity,
      linkReason: loses ? ClusterLinkReason.none : c.linkReason,
    ));
  }
  skipped.sort((a, b) => (order[a] ?? 0).compareTo(order[b] ?? 0));
  return RefinementResult(
      clusters: out, clusterIdBySegment: bySegment, skippedSegmentIds: skipped);
}

/// Updates a global voiceprint with new embeddings of the same speaker:
/// `centroid = normalize((c·n + Σeᵢ) / (n + k))` where `n = min(oldCount, cap)`
/// so that old evidence never outweighs `cap` embeddings and voices can drift
/// slowly. New embeddings are normalised first; unusable ones (non-finite,
/// zero, or a different dimension) are ignored. An old centroid that is
/// unusable or of a different dimension (embedding model changed) is
/// discarded.
///
/// Returns the new normalised centroid and count (`min(n + k, cap)`). Throws
/// an [ArgumentError] when there is neither a usable old centroid nor any
/// usable new embedding, or when [cap] < 1.
(Float32List, int) updateVoiceprint(
  Float32List? old,
  int oldCount,
  List<Float32List> newEmbeddings, {
  int cap = 200,
}) {
  if (cap < 1) throw ArgumentError.value(cap, 'cap');
  final usableNew = newEmbeddings.where(isUsableEmbedding).toList();
  int? dim = usableNew.isNotEmpty ? _majorityDim(usableNew) : null;
  final oldUsable = old != null &&
      oldCount > 0 &&
      isUsableEmbedding(old, dimension: dim);
  dim ??= oldUsable ? old.length : null;
  if (dim == null) {
    throw ArgumentError('No usable embeddings to build a voiceprint from');
  }
  final acc = Float64List(dim);
  var n = 0;
  if (oldUsable) {
    n = math.min(oldCount, cap);
    addScaledInPlace(acc, old, n / l2Norm(old));
  }
  var k = 0;
  for (final e in usableNew) {
    if (e.length != dim) continue;
    addScaledInPlace(acc, e, 1 / l2Norm(e));
    k++;
  }
  return (normalizeAccumulator(acc), math.min(n + k, cap));
}

/// Weighted average-linkage agglomerative clustering of L2-normalised
/// [vectors] with cosine similarity. Merging stops when the best
/// average-linkage similarity is below [threshold].
///
/// * [weights]: per-vector weights (default 1). The linkage between clusters
///   A and B is `Σᵢ∈A Σⱼ∈B wᵢwⱼ·cos(i,j) / (W_A·W_B)`.
/// * [anchors]: optional per-vector anchor ids. Vectors with the same anchor
///   start in the same cluster; clusters with different anchors never merge.
/// * [maxMatrixItems]: when there are more initial clusters, the
///   lowest-weight unanchored vectors are left out of the matrix and attached
///   afterwards to the most similar compatible cluster (if similarity ≥
///   [fallbackAttachThreshold], else they form their own clusters).
/// * [voiceprints] / [voiceprintThreshold]: optional L2-normalised known
///   voiceprints. A deferred vector whose best voiceprint reaches
///   [voiceprintThreshold] is attached only to a cluster whose best
///   voiceprint is the same one (also at the threshold); otherwise it keeps
///   its own cluster so that a later linking step can identify it.
///
/// Returns a cluster label per vector, numbered 0.. in order of first
/// appearance.
List<int> agglomerativeCluster(
  List<Float32List> vectors, {
  required double threshold,
  List<double>? weights,
  List<int?>? anchors,
  int maxMatrixItems = 3000,
  double fallbackAttachThreshold = 0.3,
  List<Float32List> voiceprints = const [],
  double voiceprintThreshold = double.infinity,
}) {
  final n = vectors.length;
  if (weights != null && weights.length != n) {
    throw ArgumentError('weights.length != vectors.length', 'weights');
  }
  if (anchors != null && anchors.length != n) {
    throw ArgumentError('anchors.length != vectors.length', 'anchors');
  }
  if (n == 0) return const [];
  final dim = vectors.first.length;
  for (final v in vectors) {
    if (v.length != dim) {
      throw ArgumentError('All vectors must have the same length', 'vectors');
    }
  }
  final w = [
    for (var i = 0; i < n; i++)
      (weights == null || !(weights[i] > 0) || !weights[i].isFinite)
          ? 1.0
          : weights[i],
  ];

  // Initial clusters: one per anchor group, one per unanchored vector.
  final initialOf = List<int>.filled(n, -1);
  final initMembers = <List<int>>[];
  final initAnchor = <int?>[];
  final anchorToInit = <int, int>{};
  for (var i = 0; i < n; i++) {
    final a = anchors?[i];
    if (a != null) {
      final idx = anchorToInit.putIfAbsent(a, () {
        initMembers.add(<int>[]);
        initAnchor.add(a);
        return initMembers.length - 1;
      });
      initMembers[idx].add(i);
      initialOf[i] = idx;
    }
  }
  final unanchored = [for (var i = 0; i < n; i++) if (initialOf[i] < 0) i];
  // Bound the matrix size: keep the heaviest unanchored vectors.
  final room = math.max(0, maxMatrixItems - initMembers.length);
  List<int> inMatrix = unanchored;
  List<int> deferred = const [];
  if (unanchored.length > room) {
    final sorted = [...unanchored]
      ..sort((a, b) {
        final c = w[b].compareTo(w[a]);
        return c != 0 ? c : a.compareTo(b);
      });
    inMatrix = sorted.sublist(0, room)..sort();
    deferred = sorted.sublist(room)..sort();
  }
  for (final i in inMatrix) {
    initMembers.add([i]);
    initAnchor.add(null);
    initialOf[i] = initMembers.length - 1;
  }

  final m = initMembers.length;
  final pdim = (dim + 3) & ~3;
  final lanes = pdim >> 2;
  // Weighted-mean vectors of the initial clusters, as SIMD lanes.
  final means = Float32x4List(m * lanes);
  final meansF = Float32List.view(means.buffer);
  final clusterW = Float64List(m);
  for (var c = 0; c < m; c++) {
    final acc = Float64List(dim);
    var wc = 0.0;
    for (final i in initMembers[c]) {
      addScaledInPlace(acc, vectors[i], w[i]);
      wc += w[i];
    }
    clusterW[c] = wc;
    final base = c * pdim;
    for (var k = 0; k < dim; k++) {
      meansF[base + k] = acc[k] / wc;
    }
  }

  // Packed lower-triangular similarity matrix: S(i, j), i > j at
  // i*(i-1)/2 + j.
  final sim = Float32List(m * (m - 1) ~/ 2);
  for (var i = 1; i < m; i++) {
    final rowBase = i * (i - 1) ~/ 2;
    final bi = i * lanes;
    for (var j = 0; j < i; j++) {
      final bj = j * lanes;
      var acc = Float32x4.zero();
      for (var l = 0; l < lanes; l++) {
        acc += means[bi + l] * means[bj + l];
      }
      sim[rowBase + j] = acc.x + acc.y + acc.z + acc.w;
    }
  }
  int idx(int i, int j) => i > j ? i * (i - 1) ~/ 2 + j : j * (j - 1) ~/ 2 + i;

  final active = List<bool>.filled(m, true);
  final anchorOf = List<int?>.from(initAnchor);
  final parent = List<int>.generate(m, (i) => i);
  final nn = Int32List(m);
  final nnSim = Float64List(m);
  bool compatible(int a, int b) {
    final x = anchorOf[a], y = anchorOf[b];
    return x == null || y == null || x == y;
  }

  void recomputeRow(int k) {
    var best = -1;
    var bestS = double.negativeInfinity;
    for (var j = 0; j < m; j++) {
      if (j == k || !active[j] || !compatible(k, j)) continue;
      final s = sim[idx(k, j)];
      if (s > bestS) {
        bestS = s;
        best = j;
      }
    }
    nn[k] = best;
    nnSim[k] = bestS;
  }

  for (var k = 0; k < m; k++) {
    recomputeRow(k);
  }

  var remaining = m;
  while (remaining > 1) {
    var a = -1;
    var best = double.negativeInfinity;
    for (var k = 0; k < m; k++) {
      if (active[k] && nn[k] >= 0 && nnSim[k] > best) {
        best = nnSim[k];
        a = k;
      }
    }
    if (a < 0 || best < threshold) break;
    final b = nn[a];
    // Merge b into a (Lance–Williams update for weighted average linkage).
    final wa = clusterW[a], wb = clusterW[b];
    final inv = 1.0 / (wa + wb);
    for (var k = 0; k < m; k++) {
      if (!active[k] || k == a || k == b) continue;
      final ia = idx(a, k);
      sim[ia] = (wa * sim[ia] + wb * sim[idx(b, k)]) * inv;
    }
    clusterW[a] = wa + wb;
    anchorOf[a] ??= anchorOf[b];
    active[b] = false;
    parent[b] = a;
    remaining--;

    recomputeRow(a);
    for (var k = 0; k < m; k++) {
      if (!active[k] || k == a) continue;
      if (nn[k] == a || nn[k] == b) {
        recomputeRow(k);
      } else if (compatible(k, a)) {
        final s = sim[idx(k, a)];
        if (s > nnSim[k]) {
          nn[k] = a;
          nnSim[k] = s;
        }
      }
    }
  }

  int root(int c) {
    var r = c;
    while (parent[r] != r) {
      r = parent[r];
    }
    return r;
  }

  // Raw labels: root initial cluster per vector (−1 for deferred).
  final raw = List<int>.filled(n, -1);
  for (var i = 0; i < n; i++) {
    if (initialOf[i] >= 0) raw[i] = root(initialOf[i]);
  }

  if (deferred.isNotEmpty) {
    // Centroids of final clusters for attaching deferred vectors.
    final cents = <int, Float64List>{};
    for (var i = 0; i < n; i++) {
      final r = raw[i];
      if (r < 0) continue;
      addScaledInPlace(cents.putIfAbsent(r, () => Float64List(dim)),
          vectors[i], w[i]);
    }
    final keys = cents.keys.toList();
    final normed = [for (final k in keys) normalizeAccumulator(cents[k]!)];
    final vps = [
      for (final vp in voiceprints)
        if (vp.length == dim) vp,
    ];
    final clusterVp = [for (final c in normed) _bestVoiceprint(c, vps)];
    var nextLabel = m;
    for (final i in deferred) {
      var best = -1;
      var bestS = double.negativeInfinity;
      for (var c = 0; c < keys.length; c++) {
        final s = dot(vectors[i], normed[c]);
        if (s > bestS) {
          bestS = s;
          best = c;
        }
      }
      var attach = best >= 0 && bestS >= fallbackAttachThreshold;
      if (attach && vps.isNotEmpty) {
        final (vi, vs) = _bestVoiceprint(vectors[i], vps);
        if (vi >= 0 && vs >= voiceprintThreshold) {
          final (ci, cs) = clusterVp[best];
          attach = ci == vi && cs >= voiceprintThreshold;
        }
      }
      raw[i] = attach ? keys[best] : nextLabel++;
    }
  }

  // Renumber by first appearance.
  final renum = <int, int>{};
  return [for (final r in raw) renum.putIfAbsent(r, () => renum.length)];
}

/// Maximum-weight one-to-one assignment for a (possibly rectangular)
/// non-negative weight matrix `weights[row][col]` (Hungarian algorithm,
/// O(n³) with n = max(rows, cols)).
///
/// Returns, for each row, the assigned column or −1. Rows may be assigned to
/// a column with weight 0; callers treat those as unassigned.
List<int> hungarianMaximize(List<List<double>> weights) {
  final rows = weights.length;
  if (rows == 0) return const [];
  final cols = weights.first.length;
  for (final r in weights) {
    if (r.length != cols) {
      throw ArgumentError('Ragged weight matrix', 'weights');
    }
  }
  if (cols == 0) return List<int>.filled(rows, -1);
  final size = math.max(rows, cols);
  var maxW = 0.0;
  for (final r in weights) {
    for (final x in r) {
      if (x.isFinite && x > maxW) maxW = x;
    }
  }
  // Cost (1-based arrays, e-maxx formulation): minimise maxW − weight.
  double cost(int i, int j) {
    if (i > rows || j > cols) return maxW;
    final x = weights[i - 1][j - 1];
    return maxW - (x.isFinite && x > 0 ? x : 0);
  }

  final u = Float64List(size + 1);
  final v = Float64List(size + 1);
  final p = Int32List(size + 1); // p[j] = row matched to column j
  final way = Int32List(size + 1);
  for (var i = 1; i <= size; i++) {
    p[0] = i;
    var j0 = 0;
    final minv = Float64List(size + 1)..fillRange(0, size + 1, double.infinity);
    final used = List<bool>.filled(size + 1, false);
    do {
      used[j0] = true;
      final i0 = p[j0];
      var delta = double.infinity;
      var j1 = 0;
      for (var j = 1; j <= size; j++) {
        if (used[j]) continue;
        final cur = cost(i0, j) - u[i0] - v[j];
        if (cur < minv[j]) {
          minv[j] = cur;
          way[j] = j0;
        }
        if (minv[j] < delta) {
          delta = minv[j];
          j1 = j;
        }
      }
      for (var j = 0; j <= size; j++) {
        if (used[j]) {
          u[p[j]] += delta;
          v[j] -= delta;
        } else {
          minv[j] -= delta;
        }
      }
      j0 = j1;
    } while (p[j0] != 0);
    do {
      final j1 = way[j0];
      p[j0] = p[j1];
      j0 = j1;
    } while (j0 != 0);
  }
  final result = List<int>.filled(rows, -1);
  for (var j = 1; j <= size; j++) {
    final i = p[j];
    if (i >= 1 && i <= rows && j <= cols) result[i - 1] = j - 1;
  }
  return result;
}

// -----------------------------------------------------------------------------

double _segmentWeight(int durationMs, double maxSec) =>
    (durationMs / 1000).clamp(0.5, math.max(0.5, maxSec)).toDouble();

int _majorityDim(List<Float32List> vs) {
  final counts = <int, int>{};
  for (final v in vs) {
    counts.update(v.length, (c) => c + 1, ifAbsent: () => 1);
  }
  var best = vs.first.length;
  var bestC = 0;
  counts.forEach((d, c) {
    if (c > bestC) {
      bestC = c;
      best = d;
    }
  });
  return best;
}

class _Group {
  _Group(this.dim) : sum = Float64List(dim);

  final int dim;
  final List<int> members = [];
  final Float64List sum;
  double weight = 0;
  int totalMs = 0;
  int? anchor;
  Float32List centroid = Float32List(0);
  String? linkedSpeakerId;
  double? linkSimilarity;
  ClusterLinkReason linkReason = ClusterLinkReason.none;

  void add(int i, Float32List v, double w, int durationMs, int? a) {
    members.add(i);
    addScaledInPlace(sum, v, w);
    weight += w;
    totalMs += durationMs;
    anchor ??= a;
  }

  void absorb(_Group o) {
    members.addAll(o.members);
    for (var k = 0; k < dim; k++) {
      sum[k] += o.sum[k];
    }
    weight += o.weight;
    totalMs += o.totalMs;
    anchor ??= o.anchor;
  }

  void recompute() => centroid = normalizeAccumulator(sum);
}

/// Index and cosine of the voiceprint in [vps] most similar to [v]
/// ((-1, -∞) when [vps] is empty).
(int, double) _bestVoiceprint(Float32List v, List<Float32List> vps) {
  var best = -1;
  var bestS = double.negativeInfinity;
  for (var k = 0; k < vps.length; k++) {
    final s = cosine(v, vps[k]);
    if (s > bestS) {
      bestS = s;
      best = k;
    }
  }
  return (best, bestS);
}

/// Weighted average-linkage similarity of two groups of L2-normalised
/// vectors: `Σᵢ∈A Σⱼ∈B wᵢwⱼ·cos(i,j) / (W_A·W_B)` = `ΣA·ΣB / (W_A·W_B)`.
/// Unlike the cosine of the two centroids it is not inflated by the spread
/// of the larger group.
double _averageLinkage(_Group a, _Group b) {
  if (a.weight <= 0 || b.weight <= 0) return double.negativeInfinity;
  var s = 0.0;
  for (var k = 0; k < a.dim; k++) {
    s += a.sum[k] * b.sum[k];
  }
  return s / (a.weight * b.weight);
}

/// Merges each unanchored cluster shorter than [tinyMaxMs] into the non-tiny
/// cluster with the highest average linkage, when it reaches
/// [mergeThreshold]. A tiny cluster that matches a known voiceprint
/// (`≥ linkThreshold`) is merged only into a cluster that matches the same
/// voiceprint; otherwise it is kept so the linking step can identify it.
List<_Group> _mergeTinyClusters(
  List<_Group> clusters,
  int tinyMaxMs,
  double mergeThreshold,
  List<(String, Float32List)> voiceprints,
  double linkThreshold,
) {
  final result = [...clusters];
  bool isTiny(_Group g) => g.anchor == null && g.totalMs < tinyMaxMs;
  final vps = [for (final (_, vp) in voiceprints) vp];
  final tiny = result.where(isTiny).toList()
    ..sort((a, b) => a.totalMs.compareTo(b.totalMs));
  for (final t in tiny) {
    _Group? target;
    var bestS = double.negativeInfinity;
    for (final g in result) {
      if (identical(g, t) || isTiny(g)) continue;
      final s = _averageLinkage(t, g);
      if (s > bestS) {
        bestS = s;
        target = g;
      }
    }
    if (target == null || bestS < mergeThreshold) continue;
    final (tv, ts) = _bestVoiceprint(t.centroid, vps);
    if (tv >= 0 && ts >= linkThreshold) {
      final (gv, gs) = _bestVoiceprint(target.centroid, vps);
      if (gv != tv || gs < linkThreshold) continue;
    }
    target.absorb(t);
    target.recompute();
    result.remove(t);
  }
  return result;
}
