import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart' show kUncertainSpeakerConfidence;
import 'package:insato/diarization/speaker_tracker.dart';
import 'package:insato/diarization/vector_math.dart';

import 'synthetic.dart';

/// Unit basis vector e_k in [dim] dimensions.
Float32List basis(int k, {int dim = 192}) => Float32List(dim)..[k] = 1;

void main() {
  group('purity on synthetic conversations', () {
    for (final speakers in [3, 4, 5, 6]) {
      test('$speakers interleaved speakers', () {
        final g = SyntheticVoices(1000 + speakers);
        final centres = g.centres(speakers, correlation: 0.15);
        final turns =
            conversation(g, centres, segments: 240, sigma: 0.045);
        final tracker = SpeakerTracker(knownSpeakers: const []);
        final labels = <String?>[];
        for (var i = 0; i < turns.length; i++) {
          final t = turns[i];
          labels.add(tracker
              .assign(
                  segmentIndex: i,
                  startMs: t.startMs,
                  endMs: t.endMs,
                  embedding: t.embedding)
              .speakerKey);
        }
        final truth = [for (final t in turns) t.speaker];
        expect(labels, everyElement(isNotNull));
        expect(purity(truth, labels), greaterThan(0.95));
        expect(coverage(truth, labels), greaterThan(0.95));
        expect(tracker.clusters.length, lessThanOrEqualTo(speakers + 1));
        // Auto labels are 1..N in creation order.
        expect([for (final c in tracker.clusters) c.autoLabelNumber],
            [for (var k = 1; k <= tracker.clusters.length; k++) k]);
      });
    }

    test('short and embedding-less segments follow their speaker', () {
      final g = SyntheticVoices(77);
      final centres = g.centres(3);
      final turns = conversation(g, centres,
          segments: 200, sigma: 0.045, minMs: 400, maxMs: 5000);
      final tracker = SpeakerTracker(knownSpeakers: const []);
      final truth = <int>[];
      final labels = <String?>[];
      for (var i = 0; i < turns.length; i++) {
        final t = turns[i];
        // Every 7th segment has no embedding at all.
        final a = tracker.assign(
            segmentIndex: i,
            startMs: t.startMs,
            endMs: t.endMs,
            embedding: i % 7 == 3 ? null : t.embedding);
        if (!a.isUnknown) {
          truth.add(t.speaker);
          labels.add(a.speakerKey);
        }
      }
      expect(labels.length, greaterThan(180));
      expect(purity(truth, labels), greaterThan(0.9));
    });
  });

  group('cluster creation and matching', () {
    test('first long segment opens local:1 labelled 1', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      final a = tracker.assign(
          segmentIndex: 0, startMs: 0, endMs: 2000, embedding: basis(0));
      expect(a.clusterKey, 'local:1');
      expect(a.speakerKey, 'local:1');
      expect(a.autoLabelNumber, 1);
      expect(a.decision, AssignmentDecision.newCluster);
      expect(a.createdCluster, isTrue);
      expect(a.confidence, 1);
      expect(SpeakerTracker.isLocalKey(a.speakerKey!), isTrue);
      expect(tracker.dimension, 192);
      final c = tracker.cluster('local:1')!;
      expect(c.count, 1);
      expect(c.totalMs, 2000);
      expect(c.centroid[0], closeTo(1, 1e-6));
    });

    test('threshold decides between joining and opening a cluster', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      final a = basis(0);
      tracker.assign(segmentIndex: 0, startMs: 0, endMs: 2000, embedding: a);
      final above = rotateTowards(a, basis(1), 0.60);
      final r1 = tracker.assign(
          segmentIndex: 1, startMs: 10000, endMs: 12000, embedding: above);
      expect(r1.clusterKey, 'local:1');
      expect(r1.decision, AssignmentDecision.matchedCluster);
      expect(r1.similarity, closeTo(0.60, 1e-5));
      expect(tracker.cluster('local:1')!.count, 2);

      // Below threshold relative to the updated centroid → new cluster.
      final centroid = tracker.cluster('local:1')!.centroid;
      final below = rotateTowards(centroid, basis(5), 0.50);
      final r2 = tracker.assign(
          segmentIndex: 2, startMs: 20000, endMs: 22000, embedding: below);
      expect(r2.clusterKey, 'local:2');
      expect(r2.autoLabelNumber, 2);
      expect(r2.decision, AssignmentDecision.newCluster);
    });

    test('centroid is the duration-weighted mean of absorbed embeddings', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      final a = basis(0);
      final b = rotateTowards(a, basis(1), 0.8);
      tracker.assign(segmentIndex: 0, startMs: 0, endMs: 1000, embedding: a);
      tracker.assign(
          segmentIndex: 1, startMs: 9000, endMs: 12000, embedding: b);
      final expected = weightedMeanNormalized([a, b], [1, 3])!;
      final c = tracker.cluster('local:1')!;
      expect(cosine(c.centroid, expected), closeTo(1, 1e-6));
      expect(c.totalMs, 4000);
      expect(c.lastEndMs, 12000);
      expect(c.firstStartMs, 0);
    });

    test('invalid embeddings are treated as missing', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      final nan = Float32List(192)..[0] = double.nan;
      expect(
          tracker
              .assign(
                  segmentIndex: 0, startMs: 0, endMs: 3000, embedding: nan)
              .decision,
          AssignmentDecision.unknown);
      tracker.assign(
          segmentIndex: 1, startMs: 10000, endMs: 13000, embedding: basis(0));
      // Wrong dimension after the dimension was fixed: inherits (gap small).
      final r = tracker.assign(
          segmentIndex: 2,
          startMs: 13500,
          endMs: 16000,
          embedding: Float32List(64)..[0] = 1);
      expect(r.decision, AssignmentDecision.inherited);
      expect(r.clusterKey, 'local:1');
      // Zero vector after a long gap: unknown.
      final z = tracker.assign(
          segmentIndex: 3,
          startMs: 30000,
          endMs: 33000,
          embedding: Float32List(192));
      expect(z.isUnknown, isTrue);
      expect(z.speakerKey, isNull);
      expect(tracker.clusters, hasLength(1));
    });

    test('maxClusters caps cluster creation', () {
      final tracker = SpeakerTracker(knownSpeakers: const [], maxClusters: 2);
      for (var k = 0; k < 4; k++) {
        tracker.assign(
            segmentIndex: k,
            startMs: k * 10000,
            endMs: k * 10000 + 2000,
            embedding: basis(k));
      }
      expect(tracker.clusters, hasLength(2));
    });

    test('rejects invalid configuration', () {
      expect(() => SpeakerTracker(knownSpeakers: const [], matchThreshold: 1),
          throwsArgumentError);
      expect(() => SpeakerTracker(knownSpeakers: const [], maxClusters: 0),
          throwsArgumentError);
      expect(
          () => SpeakerTracker(
              knownSpeakers: const [], ambiguityMargin: -0.1),
          throwsArgumentError);
    });
  });

  group('margin and continuity', () {
    late SpeakerTracker tracker;
    late Float32List a, b, between;

    setUp(() {
      tracker = SpeakerTracker(knownSpeakers: const []);
      a = basis(0);
      b = basis(1);
      // Equidistant from a and b: cos = 0.7 to both.
      between = Float32List(192)
        ..[0] = 0.7
        ..[1] = 0.7
        ..[2] = 0.1414;
      tracker.assign(segmentIndex: 0, startMs: 0, endMs: 2000, embedding: a);
      tracker.assign(
          segmentIndex: 1, startMs: 2500, endMs: 4500, embedding: b);
    });

    test('tie resolved by continuity without touching centroids', () {
      final r = tracker.assign(
          segmentIndex: 2, startMs: 5000, endMs: 7000, embedding: between);
      expect(r.decision, AssignmentDecision.ambiguousContinuity);
      expect(r.clusterKey, 'local:2');
      expect(r.margin, lessThan(0.05));
      expect(r.confidence, lessThan(0.5));
      expect(tracker.cluster('local:2')!.count, 1);
      expect(tracker.cluster('local:1')!.count, 1);
    });

    test('tie without continuity picks best local cluster, no update', () {
      final r = tracker.assign(
          segmentIndex: 2, startMs: 60000, endMs: 62000, embedding: between);
      expect(r.decision, AssignmentDecision.ambiguousBest);
      expect(r.clusterKey, anyOf('local:1', 'local:2'));
      expect(r.createdCluster, isFalse);
      expect(tracker.clusters.map((c) => c.count), [1, 1]);
    });

    test('clear winner is accepted even right after another speaker', () {
      final nearA = rotateTowards(a, basis(3), 0.9);
      final r = tracker.assign(
          segmentIndex: 2, startMs: 5000, endMs: 7000, embedding: nearA);
      expect(r.decision, AssignmentDecision.matchedCluster);
      expect(r.clusterKey, 'local:1');
      expect(r.confidence, greaterThan(0.7));
    });
  });

  group('short segments', () {
    test('inherit previous speaker within the continuity gap', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      tracker.assign(
          segmentIndex: 0, startMs: 0, endMs: 3000, embedding: basis(0));
      tracker.assign(
          segmentIndex: 1, startMs: 3500, endMs: 6000, embedding: basis(1));
      // Short, noisy segment slightly closer to local:1 → still local:2.
      final noisy = rotateTowards(basis(0), basis(1), 0.62);
      final r = tracker.assign(
          segmentIndex: 2, startMs: 6400, endMs: 7000, embedding: noisy);
      expect(r.decision, AssignmentDecision.inherited);
      expect(r.clusterKey, 'local:2');
      final n = tracker.assign(
          segmentIndex: 3, startMs: 7200, endMs: 7800);
      expect(n.decision, AssignmentDecision.inherited);
      expect(n.clusterKey, 'local:2');
      expect(tracker.cluster('local:2')!.count, 1);
    });

    test('switch to a clearly different known cluster', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      tracker.assign(
          segmentIndex: 0, startMs: 0, endMs: 3000, embedding: basis(0));
      tracker.assign(
          segmentIndex: 1, startMs: 3500, endMs: 6000, embedding: basis(1));
      final r = tracker.assign(
          segmentIndex: 2,
          startMs: 6200,
          endMs: 6900,
          embedding: rotateTowards(basis(0), basis(9), 0.9));
      expect(r.decision, AssignmentDecision.weakMatch);
      expect(r.clusterKey, 'local:1');
      expect(tracker.cluster('local:1')!.count, 1);
    });

    test('after a long gap: best match, never a new cluster', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      final r0 = tracker.assign(
          segmentIndex: 0, startMs: 0, endMs: 800, embedding: basis(0));
      expect(r0.isUnknown, isTrue);
      expect(tracker.clusters, isEmpty);

      tracker.assign(
          segmentIndex: 1, startMs: 1000, endMs: 4000, embedding: basis(0));
      final r2 = tracker.assign(
          segmentIndex: 2,
          startMs: 20000,
          endMs: 20700,
          embedding: rotateTowards(basis(0), basis(1), 0.8));
      expect(r2.decision, AssignmentDecision.weakMatch);
      expect(r2.clusterKey, 'local:1');
      final r3 = tracker.assign(
          segmentIndex: 3, startMs: 40000, endMs: 40700, embedding: basis(7));
      expect(r3.isUnknown, isTrue);
      final r4 =
          tracker.assign(segmentIndex: 4, startMs: 60000, endMs: 60500);
      expect(r4.isUnknown, isTrue);
      expect(tracker.clusters, hasLength(1));
      expect(tracker.cluster('local:1')!.count, 1);
    });

    group('short replies after a pause (turn taking)', () {
      // cos 0.65 to basis(0) (local:1) and 0.57 to basis(1) (local:2).
      final reply = Float32List(192)
        ..[0] = 0.65
        ..[1] = 0.57
        ..[2] = 0.5026;

      SpeakerTracker twoSpeakers() {
        final t = SpeakerTracker(knownSpeakers: const []);
        t.assign(segmentIndex: 0, startMs: 0, endMs: 3000, embedding: basis(0));
        t.assign(
            segmentIndex: 1, startMs: 3500, endMs: 6000, embedding: basis(1));
        return t;
      }

      test('a modestly closer other voice wins after a pause', () {
        final r = twoSpeakers().assign(
            segmentIndex: 2, startMs: 6400, endMs: 7000, embedding: reply);
        expect(r.decision, AssignmentDecision.weakMatch);
        expect(r.clusterKey, 'local:1');
      });

      test('the same reply without a pause stays with the speaker', () {
        final r = twoSpeakers().assign(
            segmentIndex: 2, startMs: 6100, endMs: 6700, embedding: reply);
        expect(r.decision, AssignmentDecision.inherited);
        expect(r.clusterKey, 'local:2');
      });

      test('embedding-less reply after a pause is inherited as doubtful', () {
        final r =
            twoSpeakers().assign(segmentIndex: 2, startMs: 6400, endMs: 6800);
        expect(r.decision, AssignmentDecision.inherited);
        expect(r.clusterKey, 'local:2');
        expect(r.confidence, lessThan(kUncertainSpeakerConfidence));
        final glued =
            twoSpeakers().assign(segmentIndex: 2, startMs: 6100, endMs: 6500);
        expect(glued.confidence,
            greaterThanOrEqualTo(kUncertainSpeakerConfidence));
      });

      test('a voice unlike everyone is inherited as doubtful', () {
        final r = twoSpeakers().assign(
            segmentIndex: 2, startMs: 6400, endMs: 7000, embedding: basis(5));
        expect(r.decision, AssignmentDecision.inherited);
        expect(r.confidence, lessThan(kUncertainSpeakerConfidence));
      });
    });

    test('long segments without embeddings inherit or stay unknown', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      expect(
          tracker.assign(segmentIndex: 0, startMs: 0, endMs: 5000).isUnknown,
          isTrue);
      tracker.assign(
          segmentIndex: 1, startMs: 6000, endMs: 9000, embedding: basis(0));
      expect(
          tracker
              .assign(segmentIndex: 2, startMs: 9100, endMs: 15000)
              .clusterKey,
          'local:1');
      expect(
          tracker
              .assign(segmentIndex: 3, startMs: 30000, endMs: 35000)
              .isUnknown,
          isTrue);
    });
  });

  group('global voiceprints', () {
    test('known speakers are recognised and linked once', () {
      final g = SyntheticVoices(5);
      final centres = g.centres(4);
      final known = [
        knownSpeaker('ahmed', centres[0]),
        knownSpeaker('sara', centres[2]),
        knownSpeaker('forgotten', null),
        knownSpeaker('other-model', Float32List(64)..[0] = 1),
      ];
      final tracker = SpeakerTracker(knownSpeakers: known);
      final turns = conversation(g, centres, segments: 120, sigma: 0.045);
      final truth = <int>[];
      final keys = <String?>[];
      for (var i = 0; i < turns.length; i++) {
        final t = turns[i];
        final a = tracker.assign(
            segmentIndex: i,
            startMs: t.startMs,
            endMs: t.endMs,
            embedding: t.embedding);
        truth.add(t.speaker);
        keys.add(a.speakerKey);
        if (t.speaker == 0) expect(a.speakerKey, 'ahmed');
        if (t.speaker == 2) expect(a.speakerKey, 'sara');
        if (t.speaker == 1 || t.speaker == 3) {
          expect(SpeakerTracker.isLocalKey(a.speakerKey!), isTrue);
        }
      }
      expect(purity(truth, keys), greaterThan(0.95));
      final linked = tracker.clusters
          .where((c) => c.linkedSpeakerId != null)
          .map((c) => c.linkedSpeakerId)
          .toList();
      expect(linked.toSet(), {'ahmed', 'sara'});
      expect(linked, hasLength(2), reason: 'a voiceprint is claimed once');
      // Linked clusters carry no auto label; unknown voices are numbered 1..
      final auto = tracker.clusters
          .where((c) => c.linkedSpeakerId == null)
          .map((c) => c.autoLabelNumber)
          .toList();
      expect(auto, [1, 2]);
    });

    test('first match to a voiceprint opens a linked cluster', () {
      final tracker = SpeakerTracker(
          knownSpeakers: [knownSpeaker('x', basis(0))]);
      final r = tracker.assign(
          segmentIndex: 0,
          startMs: 0,
          endMs: 3000,
          embedding: rotateTowards(basis(0), basis(1), 0.8));
      expect(r.decision, AssignmentDecision.matchedKnownSpeaker);
      expect(r.createdCluster, isTrue);
      expect(r.linkedSpeakerId, 'x');
      expect(r.speakerKey, 'x');
      expect(r.autoLabelNumber, isNull);
      // The voiceprint acts as a prior: centroid lies between both.
      final c = tracker.cluster(r.clusterKey!)!;
      expect(cosine(c.centroid, basis(0)), greaterThan(0.8));
    });

    test('a local cluster wins a close call against a voiceprint', () {
      final v = basis(0);
      final tracker =
          SpeakerTracker(knownSpeakers: [knownSpeaker('x', basis(1))]);
      tracker.assign(segmentIndex: 0, startMs: 0, endMs: 3000, embedding: v);
      // cos 0.70 to local:1 and 0.71 to x: local preference wins.
      final e = Float32List(192)
        ..[0] = 0.70
        ..[1] = 0.71
        ..[2] = 0.07;
      final r = tracker.assign(
          segmentIndex: 1, startMs: 50000, endMs: 53000, embedding: e);
      expect(r.clusterKey, 'local:1');
      expect(r.linkedSpeakerId, isNull);
    });

    test('ambiguous between two voiceprints opens an unlinked cluster', () {
      final tracker = SpeakerTracker(knownSpeakers: [
        knownSpeaker('x', basis(0)),
        knownSpeaker('y', basis(1)),
      ]);
      final e = Float32List(192)
        ..[0] = 0.7
        ..[1] = 0.7
        ..[2] = 0.14;
      final r = tracker.assign(
          segmentIndex: 0, startMs: 0, endMs: 3000, embedding: e);
      expect(r.decision, AssignmentDecision.newCluster);
      expect(r.linkedSpeakerId, isNull);
      expect(r.autoLabelNumber, 1);
    });

    test('knownSpeakerThreshold is independent of matchThreshold', () {
      final tracker = SpeakerTracker(
          knownSpeakers: [knownSpeaker('x', basis(0))],
          knownSpeakerThreshold: 0.8);
      final r = tracker.assign(
          segmentIndex: 0,
          startMs: 0,
          endMs: 3000,
          embedding: rotateTowards(basis(0), basis(1), 0.7));
      expect(r.linkedSpeakerId, isNull);
      expect(r.decision, AssignmentDecision.newCluster);
    });

    test('updateKnownSpeakers makes new voiceprints matchable', () {
      final tracker = SpeakerTracker(knownSpeakers: const []);
      tracker.updateKnownSpeakers([knownSpeaker('z', basis(4))]);
      final r = tracker.assign(
          segmentIndex: 0, startMs: 0, endMs: 3000, embedding: basis(4));
      expect(r.speakerKey, 'z');
    });

    test('firstAutoLabelNumber offsets auto labels', () {
      final tracker =
          SpeakerTracker(knownSpeakers: const [], firstAutoLabelNumber: 4);
      final r = tracker.assign(
          segmentIndex: 0, startMs: 0, endMs: 3000, embedding: basis(0));
      expect(r.autoLabelNumber, 4);
      expect(r.clusterKey, 'local:1');
    });
  });

  group('linking and merging', () {
    late SpeakerTracker tracker;
    setUp(() {
      tracker = SpeakerTracker(knownSpeakers: const []);
      for (var k = 0; k < 3; k++) {
        tracker.assign(
            segmentIndex: k,
            startMs: k * 10000,
            endMs: k * 10000 + 3000,
            embedding: basis(k));
      }
    });

    test('linkCluster makes later assignments report the speaker id', () {
      expect(tracker.linkCluster('local:2', 'spk-2'), 'local:2');
      final r = tracker.assign(
          segmentIndex: 3, startMs: 50000, endMs: 53000, embedding: basis(1));
      expect(r.speakerKey, 'spk-2');
      expect(r.clusterKey, 'local:2');
      expect(r.autoLabelNumber, 2, reason: 'auto number is kept');
    });

    test('linking two clusters to one speaker merges them', () {
      tracker.linkCluster('local:2', 'p');
      final kept = tracker.linkCluster('local:3', 'p');
      expect(kept, 'local:2');
      expect(tracker.clusters.map((c) => c.key), ['local:1', 'local:2']);
      expect(tracker.resolveKey('local:3'), 'local:2');
      expect(tracker.cluster('local:3')!.key, 'local:2');
      final c = tracker.cluster('local:2')!;
      expect(c.count, 2);
      expect(c.totalMs, 6000);
      expect(c.speakerKey, 'p');
      // Last speaker was local:3 → continuity follows the merged cluster.
      final r = tracker.assign(segmentIndex: 3, startMs: 23200, endMs: 23500);
      expect(r.clusterKey, 'local:2');
    });

    test('mergeClusters keeps the older cluster and rejects conflicts', () {
      expect(tracker.mergeClusters('local:1', 'local:3'), 'local:1');
      expect(tracker.mergeClusters('local:1', 'local:1'), 'local:1');
      tracker.linkCluster('local:1', 'a');
      tracker.linkCluster('local:2', 'b');
      expect(() => tracker.mergeClusters('local:1', 'local:2'),
          throwsArgumentError);
      expect(() => tracker.mergeClusters('local:9', 'local:2'),
          throwsArgumentError);
      expect(() => tracker.linkCluster('nope', 'a'), throwsArgumentError);
    });

    test('linkCluster accepts an explicit voiceprint prior', () {
      tracker.linkCluster('local:1', 'q', voiceprint: basis(1));
      final c = tracker.cluster('local:1')!;
      expect(cosine(c.centroid, basis(1)), greaterThan(0.5));
    });
  });

  test('SpeakerAssignment.toString is informative', () {
    final tracker = SpeakerTracker(knownSpeakers: const []);
    final r = tracker.assign(
        segmentIndex: 0, startMs: 0, endMs: 3000, embedding: basis(0));
    expect(r.toString(), contains('local:1'));
    expect(r.toString(), contains('newCluster'));
  });
}
