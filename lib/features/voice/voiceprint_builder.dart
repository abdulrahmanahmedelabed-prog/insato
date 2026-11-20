// Voiceprint construction for voice enrollment (F1). Pure Dart.
//
// The enrollment take is split into embedding chunks: every VAD segment of
// at least one second, plus 3 s windows (1.5 s hop) sliding over the
// concatenated speech, so short pauses between segments do not starve the
// voiceprint and each part of the reading contributes evenly. The chunk
// embeddings are averaged (weighted by duration) after discarding outliers
// (coughs, a second voice, a door slam), and the agreement of the rest
// becomes a consistency score.

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models.dart' show Speaker, kSampleRate;
import '../../data/repositories.dart' show combineVoiceprints;
import '../../diarization/vector_math.dart';
import 'audio_quality.dart';

/// Where an enrollment chunk comes from.
enum EnrollmentChunkKind {
  /// A whole VAD segment.
  segment,

  /// A sliding window over the concatenated speech.
  window,
}

/// Audio handed to the speaker embedder.
class EnrollmentChunk {
  /// Creates a chunk.
  const EnrollmentChunk({required this.kind, required this.samples});

  /// Origin.
  final EnrollmentChunkKind kind;

  /// Mono samples at [kSampleRate].
  final Float32List samples;

  /// Duration in ms.
  int get durationMs => samplesToMillis(samples.length);
}

/// Plans the chunks to embed for a take: each speech span of at least
/// [minSegmentMs], then [windowMs] windows every [hopMs] over the speech
/// spans joined end to end. When the joined speech is shorter than one
/// window but at least [minSegmentMs], it becomes a single window.
List<EnrollmentChunk> planEnrollmentChunks(
  Float32List audio,
  List<SpeechSpan> speech, {
  int minSegmentMs = 1000,
  int windowMs = 3000,
  int hopMs = 1500,
}) {
  if (windowMs <= 0 || hopMs <= 0) {
    throw ArgumentError('windowMs and hopMs must be positive');
  }
  final spans = normalizeSpans(speech, audio.length);
  final chunks = <EnrollmentChunk>[];
  final minSegment = millisToSamples(minSegmentMs);
  var total = 0;
  for (final s in spans) {
    total += s.length;
    if (s.length >= minSegment) {
      chunks.add(
        EnrollmentChunk(
          kind: EnrollmentChunkKind.segment,
          samples: Float32List.fromList(
            Float32List.sublistView(audio, s.startSample, s.endSample),
          ),
        ),
      );
    }
  }
  if (total == 0) return chunks;
  final joined = Float32List(total);
  var at = 0;
  for (final s in spans) {
    joined.setRange(at, at + s.length, audio, s.startSample);
    at += s.length;
  }
  final win = millisToSamples(windowMs);
  final hop = millisToSamples(hopMs);
  if (joined.length < win) {
    if (joined.length >= minSegment && spans.length > 1) {
      chunks.add(
        EnrollmentChunk(kind: EnrollmentChunkKind.window, samples: joined),
      );
    }
    return chunks;
  }
  for (var start = 0; start + win <= joined.length; start += hop) {
    chunks.add(
      EnrollmentChunk(
        kind: EnrollmentChunkKind.window,
        samples: Float32List.fromList(
          Float32List.sublistView(joined, start, start + win),
        ),
      ),
    );
  }
  return chunks;
}

/// An embedding with its weight (seconds of audio, capped).
class WeightedEmbedding {
  /// Creates a weighted embedding.
  const WeightedEmbedding(this.embedding, this.weight);

  /// The (not necessarily normalised) embedding.
  final Float32List embedding;

  /// Relative weight.
  final double weight;
}

/// Weight of a chunk of [durationMs] (seconds, between 0.5 and 10).
double chunkWeight(int durationMs) =>
    (durationMs / 1000).clamp(0.5, 10).toDouble();

/// A voiceprint built from one enrollment take.
class EnrollmentVoiceprint {
  /// Creates the result.
  const EnrollmentVoiceprint({
    required this.centroid,
    required this.embeddingCount,
    required this.consistency,
    this.mixedVoices = false,
    required this.used,
    required this.rejected,
  });

  /// L2-normalised centroid.
  final Float32List centroid;

  /// Evidence count to store with the voiceprint (see
  /// [buildEnrollmentVoiceprint]).
  final int embeddingCount;

  /// Mean cosine similarity of the kept embeddings to [centroid] (0..1).
  final double consistency;

  /// True when the embeddings split into two clearly different voices,
  /// each holding at least a quarter of the take (see [detectMixedVoices]).
  final bool mixedVoices;

  /// Whether the take is fit for a voiceprint (one consistent voice).
  bool get isConsistent =>
      !mixedVoices && consistency >= kMinEnrollmentConsistency;

  /// Embeddings kept.
  final int used;

  /// Embeddings discarded as outliers or unusable.
  final int rejected;
}

/// Lowest acceptable [EnrollmentVoiceprint.consistency]: below it the take
/// most likely mixes voices or is dominated by noise.
const double kMinEnrollmentConsistency = 0.5;

/// Upper bound of the evidence count one enrollment take adds. Windows
/// overlap, so their raw number overstates the independent evidence; a
/// 15 s take counts like about a dozen meeting segments.
const int kMaxEnrollmentEmbeddingCount = 12;

/// Builds the voiceprint of a take from chunk [embeddings].
///
/// Unusable vectors and those of a minority dimension are dropped. The rest
/// is averaged (normalised, weighted); then embeddings whose similarity to
/// that mean is below `max(minSimilarity, median − outlierMargin)` are
/// discarded (at most a third of them) and the mean is recomputed.
/// Returns null when no usable embedding remains.
EnrollmentVoiceprint? buildEnrollmentVoiceprint(
  List<WeightedEmbedding> embeddings, {
  double outlierMargin = 0.15,
  double minSimilarity = 0.2,
  int maxCount = kMaxEnrollmentEmbeddingCount,
}) {
  final usable = embeddings
      .where((e) => isUsableEmbedding(e.embedding) && e.weight > 0)
      .toList();
  if (usable.isEmpty) return null;
  // Majority dimension (a model switch mid-take is impossible, but be safe).
  final dims = <int, int>{};
  for (final e in usable) {
    dims[e.embedding.length] = (dims[e.embedding.length] ?? 0) + 1;
  }
  final dim = dims.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final same = usable.where((e) => e.embedding.length == dim).toList();

  Float32List? mean(List<WeightedEmbedding> items) => weightedMeanNormalized(
    [for (final e in items) e.embedding],
    [for (final e in items) e.weight],
  );

  final first = mean(same);
  if (first == null) return null;
  var kept = same;
  if (same.length >= 3) {
    final sims = [for (final e in same) cosine(e.embedding, first)];
    final sorted = [...sims]..sort();
    final median = sorted[sorted.length ~/ 2];
    final cut = math.max(minSimilarity, median - outlierMargin);
    final order = List<int>.generate(same.length, (i) => i)
      ..sort((a, b) => sims[a].compareTo(sims[b]));
    final maxDrop = same.length ~/ 3;
    final drop = <int>{};
    for (final i in order) {
      if (drop.length >= maxDrop) break;
      if (sims[i] < cut) drop.add(i);
    }
    kept = [
      for (var i = 0; i < same.length; i++)
        if (!drop.contains(i)) same[i],
    ];
  }
  final centroid = mean(kept) ?? first;
  var sum = 0.0;
  for (final e in kept) {
    sum += cosine(e.embedding, centroid);
  }
  final consistency = (sum / kept.length).clamp(0.0, 1.0).toDouble();
  final mixed = detectMixedVoices([for (final e in same) e.embedding]);
  return EnrollmentVoiceprint(
    centroid: centroid,
    embeddingCount: math.max(1, math.min(kept.length, maxCount)),
    consistency: consistency,
    mixedVoices: mixed,
    used: kept.length,
    rejected: embeddings.length - kept.length,
  );
}

/// Similarity below which two halves of a take count as different voices
/// (about the meeting match threshold).
const double kDifferentVoiceSimilarity = 0.5;

/// Whether [embeddings] contain two clearly different voices: a 2-means
/// split (seeded with the least similar pair) whose smaller side holds at
/// least [minShare] of the embeddings and whose two centroids are less
/// similar than [maxSimilarity].
bool detectMixedVoices(
  List<Float32List> embeddings, {
  double minShare = 0.25,
  double maxSimilarity = kDifferentVoiceSimilarity,
}) {
  final items = embeddings.where(isUsableEmbedding).toList();
  if (items.length < 4) return false;
  final dim = items.first.length;
  if (items.any((e) => e.length != dim)) return false;
  var a = 0;
  var b = 1;
  var lowest = double.infinity;
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final c = cosine(items[i], items[j]);
      if (c < lowest) {
        lowest = c;
        a = i;
        b = j;
      }
    }
  }
  var ca = l2Normalize(items[a]);
  var cb = l2Normalize(items[b]);
  var inA = <int>[];
  for (var iter = 0; iter < 8; iter++) {
    final nextA = <int>[];
    final nextB = <int>[];
    for (var i = 0; i < items.length; i++) {
      (cosine(items[i], ca) >= cosine(items[i], cb) ? nextA : nextB).add(i);
    }
    if (nextA.isEmpty || nextB.isEmpty) return false;
    final ma = meanNormalized([for (final i in nextA) items[i]]);
    final mb = meanNormalized([for (final i in nextB) items[i]]);
    if (ma == null || mb == null) return false;
    final stable = nextA.length == inA.length;
    ca = ma;
    cb = mb;
    inA = nextA;
    if (stable && iter > 0) break;
  }
  final smaller = math.min(inA.length, items.length - inA.length);
  if (smaller / items.length < minShare) return false;
  return cosine(ca, cb) < maxSimilarity;
}

/// The voiceprint of [speaker] after adding an enrollment [sample]: the two
/// are combined weighted by their evidence counts ([combineVoiceprints]).
/// A missing or incompatible (other embedding model) old voiceprint is
/// replaced by the sample.
({Float32List centroid, int count}) improvedVoiceprint(
  Speaker speaker,
  EnrollmentVoiceprint sample,
) {
  final old = speaker.centroid;
  final compatible =
      old != null &&
      isUsableEmbedding(old, dimension: sample.centroid.length) &&
      speaker.embeddingCount > 0;
  if (!compatible) {
    return (centroid: sample.centroid, count: sample.embeddingCount);
  }
  final combined = combineVoiceprints(
    old,
    speaker.embeddingCount,
    sample.centroid,
    sample.embeddingCount,
  );
  return (
    centroid: combined.centroid ?? sample.centroid,
    count: combined.count,
  );
}

/// A stored voiceprint that resembles a new enrollment.
class SimilarVoice {
  /// Creates the match.
  const SimilarVoice(this.speaker, this.similarity);

  /// The resembling speaker.
  final Speaker speaker;

  /// Cosine similarity of the voiceprints.
  final double similarity;
}

/// Similarity from which a new enrollment is reported as probably the same
/// person as an existing voiceprint.
const double kSameVoiceSimilarity = 0.7;

/// The existing voiceprint most similar to [centroid] when it reaches
/// [threshold] (null otherwise). [excludeId] is skipped (the speaker being
/// improved); voiceprints of another dimension are ignored.
SimilarVoice? findSimilarVoice(
  Float32List centroid,
  List<Speaker> speakers, {
  String? excludeId,
  double threshold = kSameVoiceSimilarity,
}) {
  SimilarVoice? best;
  for (final s in speakers) {
    if (s.id == excludeId) continue;
    final c = s.centroid;
    if (!isUsableEmbedding(c, dimension: centroid.length)) continue;
    final sim = cosine(centroid, c!);
    if (sim >= threshold && (best == null || sim > best.similarity)) {
      best = SimilarVoice(s, sim);
    }
  }
  return best;
}

/// A named speaker whose name equals [name] (trimmed, case-insensitive for
/// Latin letters), other than [excludeId]; null if none.
Speaker? findSpeakerNamed(
  String name,
  List<Speaker> speakers, {
  String? excludeId,
}) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return null;
  for (final s in speakers) {
    if (s.id == excludeId) continue;
    if (s.name.trim().toLowerCase() == n) return s;
  }
  return null;
}
