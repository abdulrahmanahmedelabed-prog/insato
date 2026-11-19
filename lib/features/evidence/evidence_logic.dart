// Pure logic of the evidence feature (F5): mapping evidence ids (segment
// indices) to transcript segments and audio positions, the 1 s pre-roll,
// seek clamping, playback speeds, following playback through the
// transcript and locating a segment in the turn list for scrolling.
//
// No Flutter or plugin imports: unit-testable and usable anywhere.

import '../../core/models.dart';

/// Audio played before the evidence segment starts, so the first syllable
/// is never clipped.
const int kEvidencePreRollMs = 1000;

/// Evidence chips shown inline before the "+N" expander.
const int kEvidenceChipsCollapsed = 4;

/// Playback speeds offered by the player bar, in toggle order.
const List<double> kEvidenceSpeeds = [1.0, 1.5];

/// One evidence reference resolved against the meeting's transcript.
class EvidenceTarget {
  /// Creates a target.
  const EvidenceTarget({
    required this.segmentIndex,
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    this.speakerId,
  });

  /// Creates the target of [segment].
  factory EvidenceTarget.of(TranscriptSegment segment) {
    final start = segment.startMs < 0 ? 0 : segment.startMs;
    return EvidenceTarget(
      segmentIndex: segment.index,
      segmentId: segment.id,
      startMs: start,
      endMs: segment.endMs < start ? start : segment.endMs,
      speakerId: segment.speakerId,
    );
  }

  /// `TranscriptSegment.index` (the id the minutes cite).
  final int segmentIndex;

  /// Row id of the segment.
  final String segmentId;

  /// Segment start in the meeting recording.
  final int startMs;

  /// Segment end in the meeting recording.
  final int endMs;

  /// Speaker of the segment (null = unknown).
  final String? speakerId;

  @override
  bool operator ==(Object other) =>
      other is EvidenceTarget &&
      other.segmentIndex == segmentIndex &&
      other.segmentId == segmentId &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.speakerId == speakerId;

  @override
  int get hashCode =>
      Object.hash(segmentIndex, segmentId, startMs, endMs, speakerId);

  @override
  String toString() => 'EvidenceTarget(#$segmentIndex @$startMs..$endMs)';
}

/// Resolves the evidence ids of a minutes item against [segments].
///
/// Ids that match no segment (deleted lines, model mistakes that slipped
/// through validation) are dropped; duplicates are removed; the result is
/// in chronological order (ties by index) so chips read like a timeline.
List<EvidenceTarget> resolveEvidence(
  Iterable<int> evidence,
  Iterable<TranscriptSegment> segments,
) {
  final byIndex = <int, TranscriptSegment>{};
  for (final s in segments) {
    byIndex.putIfAbsent(s.index, () => s);
  }
  final seen = <int>{};
  final out = <EvidenceTarget>[];
  for (final id in evidence) {
    if (!seen.add(id)) continue;
    final s = byIndex[id];
    if (s != null) out.add(EvidenceTarget.of(s));
  }
  out.sort((a, b) {
    final c = a.startMs.compareTo(b.startMs);
    return c != 0 ? c : a.segmentIndex.compareTo(b.segmentIndex);
  });
  return out;
}

/// Clamps [positionMs] into `0..durationMs` (no upper bound when the
/// duration is unknown, i.e. null or not positive).
int clampSeekMs(int positionMs, int? durationMs) {
  var p = positionMs < 0 ? 0 : positionMs;
  if (durationMs != null && durationMs > 0 && p > durationMs) p = durationMs;
  return p;
}

/// Where playback of an evidence segment starting at [segmentStartMs]
/// begins: [preRollMs] earlier, never before 0 and never past the end of a
/// recording of [durationMs] (a truncated file starts near its end rather
/// than failing). With a known duration the start keeps a small tail so the
/// player has something to play.
int evidencePlaybackStartMs(
  int segmentStartMs, {
  int? durationMs,
  int preRollMs = kEvidencePreRollMs,
}) {
  final start = segmentStartMs - (preRollMs < 0 ? 0 : preRollMs);
  if (durationMs != null && durationMs > 0) {
    const tailMs = 500;
    final latest = durationMs > tailMs ? durationMs - tailMs : 0;
    final p = clampSeekMs(start, null);
    return p > latest ? latest : p;
  }
  return clampSeekMs(start, null);
}

/// The speed after [current] in [kEvidenceSpeeds] (wrapping). An unknown
/// speed goes back to the first one.
double nextEvidenceSpeed(double current) {
  final i = kEvidenceSpeeds.indexWhere((s) => (s - current).abs() < 1e-6);
  if (i < 0) return kEvidenceSpeeds.first;
  return kEvidenceSpeeds[(i + 1) % kEvidenceSpeeds.length];
}

/// Fraction `0..1` of [positionMs] in a recording of [durationMs] (0 when
/// the duration is unknown).
double playbackFraction(int positionMs, int? durationMs) {
  if (durationMs == null || durationMs <= 0) return 0;
  return clampSeekMs(positionMs, durationMs) / durationMs;
}

/// Segments sorted for playback following: by start, then index.
List<TranscriptSegment> sortSegmentsByTime(
  Iterable<TranscriptSegment> segments,
) => [...segments]
  ..sort((a, b) {
    final c = a.startMs.compareTo(b.startMs);
    return c != 0 ? c : a.index.compareTo(b.index);
  });

/// The segment being heard at [positionMs] in [sorted] (as returned by
/// [sortSegmentsByTime]): the last segment whose start is at or before the
/// position, provided the position is not more than [gapToleranceMs] past
/// its end (pauses between lines keep the previous line highlighted).
/// Null before the first segment or in a long silence.
TranscriptSegment? segmentAtPosition(
  List<TranscriptSegment> sorted,
  int positionMs, {
  int gapToleranceMs = 1500,
}) {
  if (sorted.isEmpty) return null;
  var lo = 0;
  var hi = sorted.length - 1;
  var found = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (sorted[mid].startMs <= positionMs) {
      found = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  if (found < 0) return null;
  final s = sorted[found];
  if (positionMs <= s.endMs + gapToleranceMs) return s;
  return null;
}

/// Whether playback at [positionMs] is still in the pre-roll of a clip
/// starting at [clipStartMs]: the evidence line stays highlighted instead
/// of the line before it. Null [clipStartMs] = no clip to hold.
bool holdsEvidenceHighlight(int positionMs, int? clipStartMs) =>
    clipStartMs != null && positionMs < clipStartMs;

/// Index in [turnSegmentIds] (one list of segment ids per rendered turn,
/// in display order) of the turn holding [segmentId]; -1 when absent.
int turnIndexOfSegment(List<List<String>> turnSegmentIds, String segmentId) {
  for (var i = 0; i < turnSegmentIds.length; i++) {
    if (turnSegmentIds[i].contains(segmentId)) return i;
  }
  return -1;
}

/// Estimated scroll offset of item [index] of [count] variable-height items
/// in a list whose current scroll extent is [maxScrollExtent], placing the
/// item about [viewportFraction] down a viewport of [viewportHeight].
/// Used to bring a not-yet-built item of a lazy list into the build window
/// before scrolling to it precisely.
double estimateScrollOffset({
  required int index,
  required int count,
  required double maxScrollExtent,
  required double viewportHeight,
  double viewportFraction = 0.3,
}) {
  if (count <= 1 || maxScrollExtent <= 0) return 0;
  final i = index.clamp(0, count - 1);
  final contentHeight = maxScrollExtent + viewportHeight;
  final itemTop = contentHeight * i / count;
  final offset = itemTop - viewportHeight * viewportFraction;
  return offset.clamp(0.0, maxScrollExtent);
}

/// Next probe while searching a lazy list for item [target] that is not
/// built yet: given the indices currently built ([builtMin]..[builtMax]),
/// moves one viewport towards the target from [currentOffset], clamped to
/// `0..maxScrollExtent`. Returns null when the target is inside the built
/// range (it should be scrolled to directly) or no movement is possible.
double? nextScrollProbe({
  required int target,
  required int builtMin,
  required int builtMax,
  required double currentOffset,
  required double viewportHeight,
  required double maxScrollExtent,
}) {
  if (target >= builtMin && target <= builtMax) return null;
  final step = viewportHeight <= 0 ? 400.0 : viewportHeight;
  final next = target < builtMin ? currentOffset - step : currentOffset + step;
  final clamped = next.clamp(0.0, maxScrollExtent < 0 ? 0.0 : maxScrollExtent);
  if ((clamped - currentOffset).abs() < 0.5) return null;
  return clamped;
}
