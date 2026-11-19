// Small, allocation-conscious vector helpers for speaker embeddings.
//
// Pure Dart (no Flutter imports) so it can run inside worker isolates and in
// plain unit tests. All vectors are `Float32List`; accumulation is done in
// `double` (64-bit) to avoid precision loss when averaging many embeddings.

import 'dart:math' as math;
import 'dart:typed_data';

/// Norms below this are treated as zero (the vector has no direction).
const double kMinNorm = 1e-12;

/// Dot product of [a] and [b].
///
/// Throws an [ArgumentError] when the lengths differ.
double dot(Float32List a, Float32List b) {
  final n = a.length;
  if (b.length != n) {
    throw ArgumentError(
        'Vector length mismatch: ${a.length} vs ${b.length}', 'b');
  }
  var s0 = 0.0, s1 = 0.0, s2 = 0.0, s3 = 0.0;
  var i = 0;
  final limit = n - (n % 4);
  for (; i < limit; i += 4) {
    s0 += a[i] * b[i];
    s1 += a[i + 1] * b[i + 1];
    s2 += a[i + 2] * b[i + 2];
    s3 += a[i + 3] * b[i + 3];
  }
  for (; i < n; i++) {
    s0 += a[i] * b[i];
  }
  return (s0 + s1) + (s2 + s3);
}

/// Euclidean (L2) norm of [v].
double l2Norm(Float32List v) => math.sqrt(dot(v, v));

/// True when every component of [v] is finite (no NaN / ±Infinity).
bool isFiniteVector(Float32List v) {
  for (var i = 0; i < v.length; i++) {
    if (!v[i].isFinite) return false;
  }
  return true;
}

/// True when [v] can be used as a speaker embedding: non-empty, all
/// components finite and a non-zero norm. When [dimension] is given the
/// length must match it as well.
bool isUsableEmbedding(Float32List? v, {int? dimension}) {
  if (v == null || v.isEmpty) return false;
  if (dimension != null && v.length != dimension) return false;
  if (!isFiniteVector(v)) return false;
  final n = l2Norm(v);
  return n.isFinite && n > kMinNorm;
}

/// Returns a new L2-normalised copy of [v].
///
/// A zero (or non-finite) vector has no direction; in that case an all-zero
/// vector of the same length is returned so callers never see NaN.
Float32List l2Normalize(Float32List v) {
  final out = Float32List(v.length);
  final n = l2Norm(v);
  if (!n.isFinite || n <= kMinNorm) return out;
  final inv = 1.0 / n;
  for (var i = 0; i < v.length; i++) {
    out[i] = v[i] * inv;
  }
  return out;
}

/// Normalises [v] in place and returns its original norm (0 when [v] had no
/// direction, in which case it is zero-filled).
double l2NormalizeInPlace(Float32List v) {
  final n = l2Norm(v);
  if (!n.isFinite || n <= kMinNorm) {
    v.fillRange(0, v.length, 0);
    return 0;
  }
  final inv = 1.0 / n;
  for (var i = 0; i < v.length; i++) {
    v[i] = v[i] * inv;
  }
  return n;
}

/// Cosine similarity of [a] and [b] in `[-1, 1]`.
///
/// Fast path for normalised inputs, but correct for any input: the dot
/// product is divided by both norms. Returns 0 when either vector has no
/// direction (zero or non-finite norm). Throws an [ArgumentError] when the
/// lengths differ.
double cosine(Float32List a, Float32List b) {
  final ab = dot(a, b);
  final aa = dot(a, a);
  final bb = dot(b, b);
  if (!(aa > kMinNorm * kMinNorm) || !(bb > kMinNorm * kMinNorm)) return 0;
  final denom = math.sqrt(aa * bb);
  if (!denom.isFinite || !ab.isFinite) return 0;
  final c = ab / denom;
  if (c > 1) return 1;
  if (c < -1) return -1;
  return c;
}

/// Adds `weight * v` to [acc] in place (`acc` is a 64-bit accumulator).
void addScaledInPlace(Float64List acc, Float32List v, [double weight = 1]) {
  if (acc.length != v.length) {
    throw ArgumentError(
        'Vector length mismatch: ${acc.length} vs ${v.length}', 'v');
  }
  for (var i = 0; i < v.length; i++) {
    acc[i] += v[i] * weight;
  }
}

/// Normalises a 64-bit accumulator into a fresh `Float32List`.
///
/// Returns an all-zero vector when [acc] has no direction.
Float32List normalizeAccumulator(Float64List acc) {
  var ss = 0.0;
  for (var i = 0; i < acc.length; i++) {
    ss += acc[i] * acc[i];
  }
  final out = Float32List(acc.length);
  final n = math.sqrt(ss);
  if (!n.isFinite || n <= kMinNorm) return out;
  final inv = 1.0 / n;
  for (var i = 0; i < acc.length; i++) {
    out[i] = acc[i] * inv;
  }
  return out;
}

/// L2-normalised weighted mean of [vectors].
///
/// Each input is normalised before averaging so that loud/quiet segments (or
/// embedders that do not normalise) contribute only their direction. Inputs
/// that are not usable ([isUsableEmbedding]) or have a non-positive / non-finite
/// weight are skipped. [weights] defaults to all ones and must have the same
/// length as [vectors].
///
/// Returns null when nothing usable remains. Throws an [ArgumentError] when the
/// usable vectors have different lengths or [weights] has the wrong length.
Float32List? weightedMeanNormalized(
  List<Float32List> vectors, [
  List<double>? weights,
]) {
  if (weights != null && weights.length != vectors.length) {
    throw ArgumentError(
        'weights.length (${weights.length}) != vectors.length '
            '(${vectors.length})',
        'weights');
  }
  Float64List? acc;
  for (var k = 0; k < vectors.length; k++) {
    final v = vectors[k];
    final w = weights == null ? 1.0 : weights[k];
    if (!w.isFinite || w <= 0) continue;
    if (!isUsableEmbedding(v)) continue;
    acc ??= Float64List(v.length);
    if (acc.length != v.length) {
      throw ArgumentError(
          'Vector length mismatch: ${acc.length} vs ${v.length}', 'vectors');
    }
    addScaledInPlace(acc, v, w / l2Norm(v));
  }
  if (acc == null) return null;
  final out = normalizeAccumulator(acc);
  return isUsableEmbedding(out) ? out : null;
}

/// L2-normalised unweighted mean of [vectors]; see [weightedMeanNormalized].
Float32List? meanNormalized(List<Float32List> vectors) =>
    weightedMeanNormalized(vectors);

/// Index of the largest similarity in [sims] together with the runner-up
/// value, or `(-1, -inf, -inf)` for an empty list.
(int index, double best, double second) bestAndSecond(List<double> sims) {
  var bi = -1;
  var best = double.negativeInfinity;
  var second = double.negativeInfinity;
  for (var i = 0; i < sims.length; i++) {
    final s = sims[i];
    if (s > best) {
      second = best;
      best = s;
      bi = i;
    } else if (s > second) {
      second = s;
    }
  }
  return (bi, best, second);
}
