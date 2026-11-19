// Deterministic synthetic speaker embeddings for diarization tests.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:katib/core/models.dart';
import 'package:katib/diarization/vector_math.dart';

/// Seeded generator of speaker centres and noisy embeddings.
class SyntheticVoices {
  SyntheticVoices(int seed, {this.dim = 192}) : rnd = math.Random(seed);

  final int dim;
  final math.Random rnd;
  double? _spare;

  /// Standard normal sample (Box–Muller).
  double gaussian() {
    final s = _spare;
    if (s != null) {
      _spare = null;
      return s;
    }
    double u, v, r;
    do {
      u = rnd.nextDouble() * 2 - 1;
      v = rnd.nextDouble() * 2 - 1;
      r = u * u + v * v;
    } while (r >= 1 || r == 0);
    final f = math.sqrt(-2 * math.log(r) / r);
    _spare = v * f;
    return u * f;
  }

  /// Random unit vector.
  Float32List unit() {
    final v = Float32List(dim);
    for (var i = 0; i < dim; i++) {
      v[i] = gaussian();
    }
    return l2Normalize(v);
  }

  /// `n` speaker centres. When [correlation] > 0 every centre shares a common
  /// component so pairwise centre similarity ≈ [correlation].
  List<Float32List> centres(int n, {double correlation = 0}) {
    final common = unit();
    final a = math.sqrt(correlation);
    final b = math.sqrt(1 - correlation);
    return [
      for (var k = 0; k < n; k++)
        () {
          final u = unit();
          final v = Float32List(dim);
          for (var i = 0; i < dim; i++) {
            v[i] = a * common[i] + b * u[i];
          }
          return l2Normalize(v);
        }(),
    ];
  }

  /// Noisy L2-normalised embedding around [centre] with per-dimension noise
  /// standard deviation [sigma]. Expected cosine to the centre is about
  /// `1 / sqrt(1 + dim·sigma²)`.
  Float32List sample(Float32List centre, double sigma) {
    final v = Float32List(dim);
    for (var i = 0; i < dim; i++) {
      v[i] = centre[i] + sigma * gaussian();
    }
    return l2Normalize(v);
  }
}

/// One synthetic utterance of a conversation.
class Turn {
  Turn(this.speaker, this.startMs, this.endMs, this.embedding);
  final int speaker;
  final int startMs;
  final int endMs;
  final Float32List embedding;
  int get durationMs => endMs - startMs;
}

/// An interleaved conversation: speakers take turns of 1–4 segments,
/// segments last [minMs]..[maxMs] with 150–900 ms pauses.
List<Turn> conversation(
  SyntheticVoices g,
  List<Float32List> centres, {
  required int segments,
  required double sigma,
  int minMs = 1500,
  int maxMs = 6000,
}) {
  final out = <Turn>[];
  var t = 0;
  var speaker = 0;
  while (out.length < segments) {
    final run = 1 + g.rnd.nextInt(4);
    for (var r = 0; r < run && out.length < segments; r++) {
      final d = minMs + g.rnd.nextInt(maxMs - minMs + 1);
      out.add(Turn(speaker, t, t + d, g.sample(centres[speaker], sigma)));
      t += d + 150 + g.rnd.nextInt(750);
    }
    var next = g.rnd.nextInt(centres.length);
    if (centres.length > 1) {
      while (next == speaker) {
        next = g.rnd.nextInt(centres.length);
      }
    }
    speaker = next;
  }
  return out;
}

/// Purity: fraction of items whose label's majority truth equals their truth.
double purity(List<int> truth, List<Object?> labels) {
  final counts = <Object?, Map<int, int>>{};
  for (var i = 0; i < truth.length; i++) {
    final m = counts.putIfAbsent(labels[i], () => {});
    m.update(truth[i], (c) => c + 1, ifAbsent: () => 1);
  }
  var good = 0;
  for (final m in counts.values) {
    good += m.values.reduce(math.max);
  }
  return truth.isEmpty ? 1 : good / truth.length;
}

/// Inverse purity (coverage): how well each true speaker stays in one label.
double coverage(List<int> truth, List<Object?> labels) {
  final counts = <int, Map<Object?, int>>{};
  for (var i = 0; i < truth.length; i++) {
    final m = counts.putIfAbsent(truth[i], () => {});
    m.update(labels[i], (c) => c + 1, ifAbsent: () => 1);
  }
  var good = 0;
  for (final m in counts.values) {
    good += m.values.reduce(math.max);
  }
  return truth.isEmpty ? 1 : good / truth.length;
}

/// A known global speaker with the given voiceprint.
Speaker knownSpeaker(String id, Float32List? centroid, {int count = 20}) =>
    Speaker(
      id: id,
      name: 'Speaker $id',
      colorValue: 0xFF000000,
      isNamedByUser: true,
      createdAt: DateTime.utc(2026),
      centroid: centroid,
      embeddingCount: centroid == null ? 0 : count,
    );

/// Unit vector with cosine [cos] to unit vector [a], built in the plane of
/// [a] and [b] ([b] must not be parallel to [a]).
Float32List rotateTowards(Float32List a, Float32List b, double cos) {
  final proj = dot(a, b);
  final perp = Float32List(a.length);
  for (var i = 0; i < a.length; i++) {
    perp[i] = b[i] - proj * a[i];
  }
  final p = l2Normalize(perp);
  final s = math.sqrt(math.max(0, 1 - cos * cos));
  final out = Float32List(a.length);
  for (var i = 0; i < a.length; i++) {
    out[i] = cos * a[i] + s * p[i];
  }
  return out;
}
