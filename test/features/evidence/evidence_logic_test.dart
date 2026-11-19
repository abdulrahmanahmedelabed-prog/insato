import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/evidence/evidence_logic.dart';
import 'package:insato/features/evidence/strings.dart';

TranscriptSegment seg(
  int index,
  int startMs,
  int endMs, {
  String? speaker,
  String? id,
}) => TranscriptSegment(
  id: id ?? 's$index',
  meetingId: 'm',
  index: index,
  startMs: startMs,
  endMs: endMs,
  text: 'line $index',
  speakerId: speaker,
);

void main() {
  group('resolveEvidence (index → time mapping)', () {
    final segments = [
      seg(0, 0, 2000),
      seg(1, 2500, 5000, speaker: 'a'),
      seg(2, 5200, 9000),
      seg(42, 751000, 754000, speaker: 'b'),
    ];

    test('maps segment indices (not row ids) to start/end times', () {
      final r = resolveEvidence([42, 1], segments);
      expect(r.map((t) => t.segmentIndex), [1, 42]);
      expect(r.first.startMs, 2500);
      expect(r.first.endMs, 5000);
      expect(r.first.segmentId, 's1');
      expect(r.first.speakerId, 'a');
      expect(r.last.startMs, 751000);
    });

    test('drops unknown ids and duplicates, sorts chronologically', () {
      final r = resolveEvidence([2, 99, 0, 2, -1, 0], segments);
      expect(r.map((t) => t.segmentIndex), [0, 2]);
    });

    test('empty input or transcript gives nothing', () {
      expect(resolveEvidence(const [], segments), isEmpty);
      expect(resolveEvidence(const [1], const []), isEmpty);
    });

    test('ties on start time are ordered by index; first row wins', () {
      final r = resolveEvidence(
        [5, 4],
        [seg(5, 1000, 2000), seg(4, 1000, 1500), seg(4, 3000, 4000, id: 'x')],
      );
      expect(r.map((t) => t.segmentIndex), [4, 5]);
      expect(r.first.segmentId, 's4');
    });

    test('negative / inverted times are normalised', () {
      final t = EvidenceTarget.of(seg(1, -50, -100));
      expect(t.startMs, 0);
      expect(t.endMs, 0);
    });

    test('value equality', () {
      expect(
        EvidenceTarget.of(seg(1, 10, 20)),
        EvidenceTarget.of(seg(1, 10, 20)),
      );
      expect(
        EvidenceTarget.of(seg(1, 10, 20)).hashCode,
        EvidenceTarget.of(seg(1, 10, 20)).hashCode,
      );
      expect(
        EvidenceTarget.of(seg(1, 10, 20)),
        isNot(EvidenceTarget.of(seg(1, 10, 21))),
      );
    });
  });

  group('pre-roll and seek clamping', () {
    test('starts one second before the segment', () {
      expect(kEvidencePreRollMs, 1000);
      expect(evidencePlaybackStartMs(751000), 750000);
      expect(evidencePlaybackStartMs(751000, durationMs: 3600000), 750000);
    });

    test('never before the start of the recording', () {
      expect(evidencePlaybackStartMs(0), 0);
      expect(evidencePlaybackStartMs(400), 0);
      expect(evidencePlaybackStartMs(1000), 0);
      expect(evidencePlaybackStartMs(-300), 0);
    });

    test('never past the end of a (truncated) recording', () {
      expect(evidencePlaybackStartMs(90000, durationMs: 60000), 59500);
      expect(evidencePlaybackStartMs(60200, durationMs: 60000), 59200);
      expect(evidencePlaybackStartMs(61000, durationMs: 60000), 59500);
      expect(evidencePlaybackStartMs(5000, durationMs: 300), 0);
    });

    test('unknown duration leaves the upper bound open', () {
      expect(evidencePlaybackStartMs(90000, durationMs: null), 89000);
      expect(evidencePlaybackStartMs(90000, durationMs: 0), 89000);
    });

    test('custom pre-roll; a negative pre-roll counts as none', () {
      expect(evidencePlaybackStartMs(5000, preRollMs: 2000), 3000);
      expect(evidencePlaybackStartMs(5000, preRollMs: -10), 5000);
    });

    test('clampSeekMs', () {
      expect(clampSeekMs(-5, 1000), 0);
      expect(clampSeekMs(500, 1000), 500);
      expect(clampSeekMs(1500, 1000), 1000);
      expect(clampSeekMs(1500, null), 1500);
      expect(clampSeekMs(1500, 0), 1500);
    });

    test('playbackFraction', () {
      expect(playbackFraction(500, 1000), 0.5);
      expect(playbackFraction(5000, 1000), 1);
      expect(playbackFraction(-1, 1000), 0);
      expect(playbackFraction(500, null), 0);
    });
  });

  group('speeds', () {
    test('toggle 1× ↔ 1.5×, unknown resets to 1×', () {
      expect(kEvidenceSpeeds, [1.0, 1.5]);
      expect(nextEvidenceSpeed(1.0), 1.5);
      expect(nextEvidenceSpeed(1.5), 1.0);
      expect(nextEvidenceSpeed(2.0), 1.0);
    });

    test('labels are LTR numbers', () {
      expect(ES.speedLabel(1.0), '1×');
      expect(ES.speedLabel(1.5), '1.5×');
    });
  });

  group('segmentAtPosition (follow playback)', () {
    final sorted = sortSegmentsByTime([
      seg(2, 5200, 9000),
      seg(0, 1000, 2000),
      seg(1, 2500, 5000),
      seg(3, 20000, 21000),
    ]);

    test('sorts by time', () {
      expect(sorted.map((s) => s.index), [0, 1, 2, 3]);
    });

    test('finds the segment being heard', () {
      expect(segmentAtPosition(sorted, 1000)?.index, 0);
      expect(segmentAtPosition(sorted, 3000)?.index, 1);
      expect(segmentAtPosition(sorted, 5200)?.index, 2);
      expect(segmentAtPosition(sorted, 20500)?.index, 3);
    });

    test('short pauses keep the previous line; long silences none', () {
      expect(segmentAtPosition(sorted, 2200)?.index, 0);
      expect(segmentAtPosition(sorted, 10000)?.index, 2);
      expect(segmentAtPosition(sorted, 15000), isNull);
      expect(segmentAtPosition(sorted, 500), isNull);
      expect(segmentAtPosition(const [], 500), isNull);
    });

    test('custom tolerance', () {
      expect(segmentAtPosition(sorted, 2200, gapToleranceMs: 0), isNull);
    });
  });

  test('holdsEvidenceHighlight during the pre-roll only', () {
    expect(holdsEvidenceHighlight(750000, 751000), isTrue);
    expect(holdsEvidenceHighlight(751000, 751000), isFalse);
    expect(holdsEvidenceHighlight(760000, 751000), isFalse);
    expect(holdsEvidenceHighlight(0, null), isFalse);
  });

  group('scrolling helpers', () {
    test('turnIndexOfSegment', () {
      final turns = [
        ['a', 'b'],
        ['c'],
        ['d', 'e', 'f'],
      ];
      expect(turnIndexOfSegment(turns, 'a'), 0);
      expect(turnIndexOfSegment(turns, 'c'), 1);
      expect(turnIndexOfSegment(turns, 'f'), 2);
      expect(turnIndexOfSegment(turns, 'z'), -1);
    });

    test('estimateScrollOffset is proportional and clamped', () {
      expect(
        estimateScrollOffset(
          index: 0,
          count: 100,
          maxScrollExtent: 9000,
          viewportHeight: 1000,
        ),
        0,
      );
      expect(
        estimateScrollOffset(
          index: 50,
          count: 100,
          maxScrollExtent: 9000,
          viewportHeight: 1000,
        ),
        closeTo(5000 - 300, 1e-9),
      );
      expect(
        estimateScrollOffset(
          index: 500,
          count: 100,
          maxScrollExtent: 9000,
          viewportHeight: 1000,
        ),
        lessThanOrEqualTo(9000),
      );
      expect(
        estimateScrollOffset(
          index: 3,
          count: 1,
          maxScrollExtent: 9000,
          viewportHeight: 1000,
        ),
        0,
      );
      expect(
        estimateScrollOffset(
          index: 3,
          count: 10,
          maxScrollExtent: 0,
          viewportHeight: 1000,
        ),
        0,
      );
    });

    test('nextScrollProbe moves one viewport towards the target', () {
      expect(
        nextScrollProbe(
          target: 5,
          builtMin: 3,
          builtMax: 8,
          currentOffset: 100,
          viewportHeight: 800,
          maxScrollExtent: 5000,
        ),
        isNull,
      );
      expect(
        nextScrollProbe(
          target: 20,
          builtMin: 3,
          builtMax: 8,
          currentOffset: 100,
          viewportHeight: 800,
          maxScrollExtent: 5000,
        ),
        900,
      );
      expect(
        nextScrollProbe(
          target: 1,
          builtMin: 3,
          builtMax: 8,
          currentOffset: 500,
          viewportHeight: 800,
          maxScrollExtent: 5000,
        ),
        0,
      );
      // Already at the edge: no movement possible.
      expect(
        nextScrollProbe(
          target: 1,
          builtMin: 3,
          builtMax: 8,
          currentOffset: 0,
          viewportHeight: 800,
          maxScrollExtent: 5000,
        ),
        isNull,
      );
      expect(
        nextScrollProbe(
          target: 99,
          builtMin: 3,
          builtMax: 8,
          currentOffset: 4800,
          viewportHeight: 800,
          maxScrollExtent: 5000,
        ),
        5000,
      );
    });
  });

  group('strings', () {
    test('chip semantics and tooltips carry the timestamp', () {
      expect(ES.playFrom(751000), contains('00:12:31'));
      expect(ES.showLineAt(751000), contains('00:12:31'));
      expect(ES.chipSemantics(42, 751000, 'سارة'), contains('42'));
      expect(ES.chipSemantics(42, 751000, 'سارة'), contains('سارة'));
      expect(ES.chipSemantics(42, 751000, null), isNot(contains('المتحدث')));
      expect(ES.moreEvidence(3), '+3');
    });
  });
}
