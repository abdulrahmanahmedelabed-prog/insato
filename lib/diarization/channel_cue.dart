// Multi-device diarization cue (v1.2 C): which device hears a segment best.
//
// When several phones / PCs record one meeting, the device nearest to the
// talker usually has the highest signal-to-noise ratio. A segment's
// [ChannelProfile] holds the SNR (dB above the channel's noise floor) of
// every device that covered it. Two segments of the same person tend to have
// the same "nearest device", two people sitting at different ends of the
// table tend not to.
//
// The cue is deliberately weak: it only shifts close calls between voice
// embeddings (online in [SpeakerTracker], offline in [refineSpeakers] via
// [augmentWithChannelCue]); a person who walks around or a meeting recorded
// on one device is unaffected (no profile → no cue).
//
// Pure Dart (no Flutter imports).

import 'dart:math' as math;
import 'dart:typed_data';

/// Per-device SNR of one speech segment.
class ChannelProfile {
  /// Creates a profile from `channel id → SNR dB`.
  ChannelProfile(Map<String, double> snrDb)
    : snrDb = Map.unmodifiable({
        for (final e in snrDb.entries)
          if (e.value.isFinite) e.key: e.value,
      });

  /// Channel id → SNR in dB (finite values only).
  final Map<String, double> snrDb;

  /// Softmax temperature (dB): a 3 dB lead gives the nearer device ≈ 73 %.
  static const double temperatureDb = 3;

  /// True when at least two devices covered the segment.
  bool get isInformative => snrDb.length >= 2;

  /// Channel with the highest SNR (null when empty).
  String? get nearest {
    String? best;
    var bestV = double.negativeInfinity;
    for (final e in snrDb.entries) {
      if (e.value > bestV) {
        bestV = e.value;
        best = e.key;
      }
    }
    return best;
  }

  /// Proximity distribution: softmax of the SNRs at [temperatureDb].
  Map<String, double> proximity() => softmaxDb(snrDb);

  /// JSON form (`{"host": 18.2, "g1": 9.5}`), SNRs rounded to 0.1 dB.
  Map<String, Object?> toJson() => {
    for (final e in snrDb.entries) e.key: (e.value * 10).round() / 10,
  };

  /// Parses [toJson] output; null for anything else.
  static ChannelProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = <String, double>{};
    for (final e in json.entries) {
      final v = e.value;
      if (e.key is String && v is num && v.isFinite) {
        m[e.key as String] = v.toDouble();
      }
    }
    return m.isEmpty ? null : ChannelProfile(m);
  }

  @override
  String toString() => 'ChannelProfile($snrDb)';
}

/// Softmax of dB values at [ChannelProfile.temperatureDb].
Map<String, double> softmaxDb(Map<String, double> db) {
  if (db.isEmpty) return const {};
  final maxV = db.values.reduce(math.max);
  var sum = 0.0;
  final out = <String, double>{};
  for (final e in db.entries) {
    final v = math.exp((e.value - maxV) / ChannelProfile.temperatureDb);
    out[e.key] = v;
    sum += v;
  }
  return {for (final e in out.entries) e.key: e.value / sum};
}

/// Centred proximity over [channels]: `p_c − 1/k`, scaled so a one-hot
/// distribution has norm 1 (a tie has norm 0).
List<double> _centred(Map<String, double> p, List<String> channels) {
  final k = channels.length;
  final u = 1 / k;
  final maxNorm = math.sqrt((1 - u) * (1 - u) + (k - 1) * u * u);
  var sum = 0.0;
  for (final c in channels) {
    sum += p[c] ?? 0;
  }
  return [
    for (final c in channels)
      (sum <= 0 ? 0.0 : (p[c] ?? 0) / sum - u) / maxNorm,
  ];
}

/// Similarity in `[-1, 1]` between a segment's proximity [a] and a reference
/// proximity [b] (e.g. a speaker cluster's mean), over the channels both
/// cover (at least two, else 0). The cosine of the centred distributions is
/// scaled by how decisive each one is, so near-ties give a cue near 0.
double proximityCue(Map<String, double> a, Map<String, double> b) {
  final common = [
    for (final c in a.keys)
      if (b.containsKey(c)) c,
  ]..sort();
  if (common.length < 2) return 0;
  final va = _centred(a, common);
  final vb = _centred(b, common);
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < va.length; i++) {
    dot += va[i] * vb[i];
    na += va[i] * va[i];
    nb += vb[i] * vb[i];
  }
  if (na <= 1e-12 || nb <= 1e-12) return 0;
  final cos = dot / math.sqrt(na * nb);
  final reliability = math.sqrt(math.min(1.0, math.sqrt(na) * math.sqrt(nb)));
  return (cos * reliability).clamp(-1.0, 1.0);
}

/// Running mean of segment proximities (one per speaker cluster).
class ProximityAccumulator {
  final Map<String, double> _sum = {};
  final Map<String, double> _weight = {};

  /// Total weight added (≈ seconds of informative speech).
  double get evidence => _weight.values.fold(0.0, math.max);

  /// Adds [profile] with weight [w] (ignored when not informative).
  void add(ChannelProfile profile, double w) {
    if (!profile.isInformative || !(w > 0)) return;
    for (final e in profile.proximity().entries) {
      _sum.update(e.key, (v) => v + e.value * w, ifAbsent: () => e.value * w);
      _weight.update(e.key, (v) => v + w, ifAbsent: () => w);
    }
  }

  /// Adds everything of [other] (cluster merge).
  void addAll(ProximityAccumulator other) {
    other._sum.forEach((k, v) {
      _sum.update(k, (x) => x + v, ifAbsent: () => v);
    });
    other._weight.forEach((k, v) {
      _weight.update(k, (x) => x + v, ifAbsent: () => v);
    });
  }

  /// Mean proximity per channel (each channel averaged over the segments
  /// that covered it).
  Map<String, double> mean() => {
    for (final e in _sum.entries)
      if ((_weight[e.key] ?? 0) > 0) e.key: e.value / _weight[e.key]!,
  };
}

/// Weight β² of the channel cue in [augmentWithChannelCue].
const double kChannelCueWeight = 0.08;

/// Embedding for offline clustering with the channel cue folded in:
/// `[√(1 − β²‖v‖²)·e, β·v]`, where `e` is the L2-normalised voice embedding
/// and `v` the centred proximity of [profile] over [channels] (norm ≤ 1).
/// The dot product of two such vectors is ≈ the voice cosine plus
/// `β²·v_i·v_j`, and still a cosine (unit norm). Without an informative
/// profile `v = 0` and the voice part is unchanged.
Float32List augmentWithChannelCue(
  Float32List normalizedEmbedding,
  ChannelProfile? profile,
  List<String> channels, {
  double weight = kChannelCueWeight,
}) {
  final d = normalizedEmbedding.length;
  final out = Float32List(d + channels.length);
  List<double>? v;
  if (profile != null && profile.isInformative) {
    final present = [
      for (final c in channels)
        if (profile.snrDb.containsKey(c)) c,
    ];
    if (present.length >= 2) {
      final centred = _centred(profile.proximity(), present);
      v = [
        for (final c in channels)
          present.contains(c) ? centred[present.indexOf(c)] : 0.0,
      ];
    }
  }
  var vv = 0.0;
  if (v != null) {
    for (final x in v) {
      vv += x * x;
    }
    vv = math.min(1.0, vv);
  }
  final beta = math.sqrt(weight);
  final scale = math.sqrt(math.max(0.0, 1 - weight * vv));
  for (var i = 0; i < d; i++) {
    out[i] = normalizedEmbedding[i] * scale;
  }
  if (v != null) {
    final norm = math.sqrt(v.fold(0.0, (a, x) => a + x * x));
    final f = norm > 1 ? 1 / norm : 1.0;
    for (var i = 0; i < channels.length; i++) {
      out[d + i] = beta * v[i] * f;
    }
  }
  return out;
}
