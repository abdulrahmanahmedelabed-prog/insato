// Pure merge logic of a meeting package into a meeting: where every segment
// goes on the merged timeline, which duplicates are dropped, the new
// segment order (indices) and how remote speakers map to the voice library.
//
// Duplicates: when both devices heard the same utterance (their segments
// overlap in time on the aligned timeline and say the same thing — or the
// audio proved both devices were in the same room and the overlap is
// large), only one text is kept: the one recorded with the better
// speech-to-noise ratio. A better remote text replaces the main segment's
// text (the main segment keeps its id, time and speaker); a worse one is
// dropped. The transcript is never doubled.
//
// Pure Dart.

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models.dart';
import '../../core/text_normalize.dart';
import '../../data/repositories.dart'
    show autoSpeakerName, parseAutoSpeakerNumber;
import '../../diarization/vector_math.dart' show cosine, isUsableEmbedding;
import 'package_format.dart';

/// Fraction of the shorter segment two segments must overlap to be
/// considered for de-duplication.
const double kDuplicateOverlap = 0.5;

/// Text similarity (character-bigram Dice) above which overlapping segments
/// are the same utterance.
const double kDuplicateTextSimilarity = 0.45;

/// Overlap above which segments of a same-room recording are the same
/// utterance whatever the recognisers wrote.
const double kSameRoomDuplicateOverlap = 0.8;

/// Character-bigram Dice similarity of two texts after Arabic
/// normalisation (0..1).
double textSimilarity(String a, String b) {
  List<String> grams(String s) {
    final t = normalizeForSearch(s)
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
    return [for (var i = 0; i + 1 < t.length; i++) t.substring(i, i + 2)];
  }

  final ga = grams(a), gb = grams(b);
  if (ga.isEmpty || gb.isEmpty) return 0;
  final counts = <String, int>{};
  for (final g in ga) {
    counts[g] = (counts[g] ?? 0) + 1;
  }
  var common = 0;
  for (final g in gb) {
    final c = counts[g] ?? 0;
    if (c > 0) {
      common++;
      counts[g] = c - 1;
    }
  }
  return 2 * common / (ga.length + gb.length);
}

/// A main-meeting segment with its SNR (dB) when known.
typedef MainSegmentInput = ({TranscriptSegment segment, double? snrDb});

/// A remote segment placed on the merged timeline.
class PlannedRemoteSegment {
  /// Creates the placement.
  const PlannedRemoteSegment({
    required this.source,
    required this.startMs,
    required this.endMs,
    required this.index,
  });

  /// The package segment.
  final PackageSegment source;

  /// Start on the merged timeline.
  final int startMs;

  /// End on the merged timeline.
  final int endMs;

  /// Index in the merged transcript.
  final int index;
}

/// A main segment whose text is replaced by a better remote recording.
class PlannedReplacement {
  /// Creates the replacement.
  const PlannedReplacement({required this.mainSegmentId, required this.source});

  /// Main segment kept (id, time, speaker).
  final String mainSegmentId;

  /// Remote segment whose text / language / confidence it takes.
  final PackageSegment source;
}

/// Output of [planMerge].
class MergePlan {
  /// Creates a plan.
  const MergePlan({
    required this.shiftMs,
    required this.mainTimes,
    required this.mainIndex,
    required this.inserts,
    required this.replacements,
    required this.droppedDuplicates,
    required this.durationMs,
  });

  /// How much the main timeline moves right (the remote recording started
  /// earlier).
  final int shiftMs;

  /// Main segment id → (start, end) on the merged timeline.
  final Map<String, (int, int)> mainTimes;

  /// Main segment id → index in the merged transcript.
  final Map<String, int> mainIndex;

  /// Remote segments added.
  final List<PlannedRemoteSegment> inserts;

  /// Main segments whose text the remote device recorded better.
  final List<PlannedReplacement> replacements;

  /// Remote duplicates dropped because the main recording was better.
  final int droppedDuplicates;

  /// Duration of the merged meeting.
  final int durationMs;

  /// Old main index → new index (for evidence references).
  Map<int, int> indexRemap(List<TranscriptSegment> main) => {
    for (final s in main) s.index: ?mainIndex[s.id],
  };

  /// Remote segments that duplicate a main one.
  int get duplicates => replacements.length + droppedDuplicates;
}

/// Plans the merge of [remote] (placed at [offsetMs]: remote time t is main
/// time t + offset) into [main]. [sameRoom]: the audio alignment proved
/// both devices heard the same sounds.
MergePlan planMerge({
  required List<MainSegmentInput> main,
  required List<PackageSegment> remote,
  required int offsetMs,
  required bool sameRoom,
  int mainDurationMs = 0,
  int remoteDurationMs = 0,
}) {
  final shift = math.max(0, -offsetMs);
  final remoteShift = offsetMs + shift;
  final mainTimes = <String, (int, int)>{
    for (final m in main)
      m.segment.id: (m.segment.startMs + shift, m.segment.endMs + shift),
  };
  final replacements = <PlannedReplacement>[];
  final kept = <(PackageSegment, int, int)>[];
  final replaced = <String>{};
  var dropped = 0;
  for (final r in remote) {
    final rs = r.startMs + remoteShift;
    final re = r.endMs + remoteShift;
    MainSegmentInput? dup;
    var dupScore = 0.0;
    for (final m in main) {
      final (ms, me) = mainTimes[m.segment.id]!;
      final ov = math.min(re, me) - math.max(rs, ms);
      if (ov <= 0) continue;
      final shorter = math.max(1, math.min(re - rs, me - ms));
      final frac = ov / shorter;
      if (frac < kDuplicateOverlap) continue;
      final sim = textSimilarity(r.text, m.segment.text);
      final same =
          sim >= kDuplicateTextSimilarity ||
          (sameRoom && frac >= kSameRoomDuplicateOverlap);
      if (!same) continue;
      final score = frac + sim;
      if (score > dupScore) {
        dup = m;
        dupScore = score;
      }
    }
    if (dup == null) {
      kept.add((r, rs, re));
      continue;
    }
    if (_remoteBetter(r, dup) && replaced.add(dup.segment.id)) {
      replacements.add(
        PlannedReplacement(mainSegmentId: dup.segment.id, source: r),
      );
    } else {
      dropped++;
    }
  }

  // Merged order: by start time; at equal starts the main segment first,
  // then the original order of each side.
  final order =
      <(int start, int side, int ord, Object item)>[
        for (var i = 0; i < main.length; i++)
          (mainTimes[main[i].segment.id]!.$1, 0, i, main[i].segment.id),
        for (var i = 0; i < kept.length; i++) (kept[i].$2, 1, i, i),
      ]..sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        if (c != 0) return c;
        final s = a.$2.compareTo(b.$2);
        return s != 0 ? s : a.$3.compareTo(b.$3);
      });
  final mainIndex = <String, int>{};
  final inserts = <PlannedRemoteSegment>[];
  for (var i = 0; i < order.length; i++) {
    final e = order[i];
    if (e.$2 == 0) {
      mainIndex[e.$4 as String] = i;
    } else {
      final k = kept[e.$4 as int];
      inserts.add(
        PlannedRemoteSegment(
          source: k.$1,
          startMs: k.$2,
          endMs: k.$3,
          index: i,
        ),
      );
    }
  }
  var duration = math.max(
    mainDurationMs + shift,
    remoteDurationMs + remoteShift,
  );
  for (final t in mainTimes.values) {
    duration = math.max(duration, t.$2);
  }
  for (final k in kept) {
    duration = math.max(duration, k.$3);
  }
  return MergePlan(
    shiftMs: shift,
    mainTimes: mainTimes,
    mainIndex: mainIndex,
    inserts: inserts,
    replacements: replacements,
    droppedDuplicates: dropped,
    durationMs: duration,
  );
}

/// Whether the remote recording of a duplicate is better: higher SNR when
/// both are known (a 1 dB margin keeps the main text on a tie), else a
/// recognised text over an unintelligible one, else the higher recogniser
/// confidence; otherwise the main text stays.
bool _remoteBetter(PackageSegment r, MainSegmentInput m) {
  final rText =
      r.kind != SegmentKind.unintelligible && r.text.trim().isNotEmpty;
  final mText = !m.segment.isUnintelligible && m.segment.text.trim().isNotEmpty;
  if (rText != mText) return rText;
  final rs = r.snrDb, ms = m.snrDb;
  if (rs != null && ms != null) return rs > ms + 1;
  final rc = r.asrConfidence, mc = m.segment.asrConfidence;
  if (rc != null && mc != null) return rc > mc + 0.05;
  return false;
}

// ---------------------------------------------------------------------------
// Speakers
// ---------------------------------------------------------------------------

/// How one remote speaker enters the voice library.
class SpeakerMapping {
  /// Maps to an existing speaker.
  const SpeakerMapping.existing(this.speakerId, {this.byVoice = false})
    : newName = null,
      newNamedByUser = false,
      centroid = null,
      embeddingCount = 0;

  /// Creates a new speaker.
  const SpeakerMapping.create({
    required String name,
    required bool namedByUser,
    this.centroid,
    this.embeddingCount = 0,
  }) : speakerId = null,
       byVoice = false,
       newName = name,
       newNamedByUser = namedByUser;

  /// Existing speaker (null: create one).
  final String? speakerId;

  /// Matched by voiceprint (else by the user-given name).
  final bool byVoice;

  /// Name of the speaker to create.
  final String? newName;

  /// Whether the created speaker counts as named by the user.
  final bool newNamedByUser;

  /// Voiceprint of the speaker to create.
  final Float32List? centroid;

  /// Embeddings in [centroid].
  final int embeddingCount;

  /// True when a speaker is created.
  bool get creates => speakerId == null;
}

/// Name of an automatic remote speaker: `متحدث N (جهاز: …)`.
String deviceSpeakerName(int n, String deviceName) {
  final d = deviceName.trim();
  return d.isEmpty ? autoSpeakerName(n) : '${autoSpeakerName(n)} (جهاز: $d)';
}

/// Maps the package's speakers to the library.
///
/// * With voiceprints: a remote centroid matching a library voiceprint at
///   [matchThreshold] (best match, each library speaker used once) maps to
///   it.
/// * A speaker the remote user named maps to the library speaker the user
///   gave the same name (exactly one), else it is created with that name.
/// * Every other speaker becomes a new automatic speaker
///   `متحدث N (جهاز: …)`, numbered after the remote label when it was an
///   automatic one, avoiding names already in use; its voiceprint (if
///   included) comes with it.
Map<String, SpeakerMapping> mapRemoteSpeakers({
  required List<PackageSpeaker> remote,
  required List<Speaker> library,
  required String deviceName,
  required double matchThreshold,
}) {
  final out = <String, SpeakerMapping>{};
  final used = <String>{};
  final names = {for (final s in library) s.name.trim()};

  // Voice matches, best pairs first.
  final pairs = <(double, PackageSpeaker, Speaker)>[];
  for (final r in remote) {
    final c = r.centroid;
    if (c == null || !isUsableEmbedding(c)) continue;
    for (final s in library) {
      final v = s.centroid;
      if (v == null || s.lowConfidence) continue;
      if (!isUsableEmbedding(v, dimension: c.length)) continue;
      final sim = cosine(c, v);
      if (sim >= matchThreshold) pairs.add((sim, r, s));
    }
  }
  pairs.sort((a, b) => b.$1.compareTo(a.$1));
  for (final (_, r, s) in pairs) {
    if (out.containsKey(r.key) || used.contains(s.id)) continue;
    out[r.key] = SpeakerMapping.existing(s.id, byVoice: true);
    used.add(s.id);
  }

  var nextAuto = 1;
  for (final r in remote) {
    if (out.containsKey(r.key)) continue;
    if (r.isNamedByUser && r.name.trim().isNotEmpty) {
      final key = normalizeForSearch(r.name);
      final same = [
        for (final s in library)
          if (s.isNamedByUser && normalizeForSearch(s.name) == key) s,
      ];
      if (same.length == 1 && !used.contains(same.first.id)) {
        out[r.key] = SpeakerMapping.existing(same.first.id);
        used.add(same.first.id);
        continue;
      }
      out[r.key] = SpeakerMapping.create(
        name: r.name.trim(),
        namedByUser: true,
        centroid: r.centroid,
        embeddingCount: r.embeddingCount,
      );
      names.add(r.name.trim());
      continue;
    }
    var n = parseAutoSpeakerNumber(r.name) ?? nextAuto;
    while (names.contains(deviceSpeakerName(n, deviceName))) {
      n++;
    }
    nextAuto = math.max(nextAuto, n + 1);
    final name = deviceSpeakerName(n, deviceName);
    names.add(name);
    out[r.key] = SpeakerMapping.create(
      name: name,
      namedByUser: false,
      centroid: r.centroid,
      embeddingCount: r.embeddingCount,
    );
  }
  return out;
}

/// Rewrites segment-index references in a JSON value: every int (or list
/// of ints) under a key named `evidence`, `segment`, `segments` or
/// `segment_ids`, recursively. Unknown indices are kept.
Object? remapEvidenceJson(Object? value, Map<int, int> remap) =>
    _remap(value, remap, inEvidence: false);

const Set<String> _evidenceKeys = {
  'evidence',
  'segment',
  'segments',
  'segment_ids',
};

Object? _remap(Object? v, Map<int, int> remap, {required bool inEvidence}) {
  if (v is int) return inEvidence ? (remap[v] ?? v) : v;
  if (v is List) {
    return [for (final x in v) _remap(x, remap, inEvidence: inEvidence)];
  }
  if (v is Map) {
    return {
      for (final e in v.entries)
        e.key: _remap(
          e.value,
          remap,
          inEvidence: _evidenceKeys.contains(e.key),
        ),
    };
  }
  return v;
}
