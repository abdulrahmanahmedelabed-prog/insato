import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:katib/diarization/clustering.dart';
import 'package:katib/diarization/vector_math.dart';

import 'synthetic.dart';

typedef Item = (String, Float32List, int);

List<Item> itemsOf(List<Turn> turns) => [
      for (var i = 0; i < turns.length; i++)
        ('s$i', turns[i].embedding, turns[i].durationMs),
    ];

Float32List basis(int k, {int dim = 192}) => Float32List(dim)..[k] = 1;

void main() {
  group('refineSpeakers purity', () {
    for (final speakers in [3, 4, 5, 6]) {
      test('$speakers speakers, interleaved turns', () {
        final g = SyntheticVoices(42 + speakers);
        final centres = g.centres(speakers, correlation: 0.2);
        final turns = conversation(g, centres,
            segments: 300, sigma: 0.06, minMs: 800, maxMs: 7000);
        final result =
            refineSpeakers(items: itemsOf(turns), knownSpeakers: const []);
        final labels = [
          for (var i = 0; i < turns.length; i++)
            result.clusterIdBySegment['s$i'],
        ];
        final truth = [for (final t in turns) t.speaker];
        expect(labels, everyElement(isNotNull));
        expect(purity(truth, labels), greaterThan(0.95));
        expect(coverage(truth, labels), greaterThan(0.95));
        expect(result.clusters.length, speakers);
        expect(result.clusters.every((c) => c.isNewSpeaker), isTrue);
        expect(result.skippedSegmentIds, isEmpty);
        // Ids follow first appearance; s0 is always in cluster:1.
        expect(result.clusterIdBySegment['s0'], 'cluster:1');
        expect([for (final c in result.clusters) c.id],
            [for (var k = 1; k <= speakers; k++) 'cluster:$k']);
        // Centroids are unit vectors close to the true centres.
        for (final c in result.clusters) {
          expect(l2Norm(c.centroid), closeTo(1, 1e-5));
          final truthSpeaker = turns[int.parse(c.segmentIds.first.substring(1))]
              .speaker;
          expect(cosine(c.centroid, centres[truthSpeaker]), greaterThan(0.95));
        }
        final total = turns.fold<int>(0, (s, t) => s + t.durationMs);
        expect(result.clusters.fold<int>(0, (s, c) => s + c.totalMs), total);
      });
    }

    test('noisier than the online tracker can handle', () {
      // Pairwise same-speaker cosine ≈ 0.5: hard for online assignment but
      // average linkage still separates speakers.
      final g = SyntheticVoices(9);
      final centres = g.centres(4);
      final turns = conversation(g, centres, segments: 300, sigma: 0.07);
      final result = refineSpeakers(
          items: itemsOf(turns),
          knownSpeakers: const [],
          clusterThreshold: 0.3);
      final labels = [
        for (var i = 0; i < turns.length; i++) result.clusterIdBySegment['s$i'],
      ];
      final truth = [for (final t in turns) t.speaker];
      expect(purity(truth, labels), greaterThan(0.95));
      expect(coverage(truth, labels), greaterThan(0.95));
    });
  });

  group('edge cases', () {
    test('empty input', () {
      final r = refineSpeakers(items: const [], knownSpeakers: const []);
      expect(r.clusters, isEmpty);
      expect(r.clusterIdBySegment, isEmpty);
      expect(r.skippedSegmentIds, isEmpty);
    });

    test('single segment', () {
      final r = refineSpeakers(
          items: [('only', basis(3), 500)],
          knownSpeakers: [knownSpeaker('k', basis(3))]);
      expect(r.clusters, hasLength(1));
      expect(r.clusterIdBySegment, {'only': 'cluster:1'});
      expect(r.speakerIdForSegment('only'), 'k');
      expect(r.clusters.single.linkReason, ClusterLinkReason.voiceprint);
      expect(r.clusters.single.linkSimilarity, closeTo(1, 1e-6));
    });

    test('all embeddings unusable', () {
      final r = refineSpeakers(items: [
        ('a', Float32List(192), 3000),
        ('b', Float32List(192)..[0] = double.nan, 3000),
        ('c', Float32List(0), 3000),
      ], knownSpeakers: const []);
      expect(r.clusters, isEmpty);
      expect(r.skippedSegmentIds, ['a', 'b', 'c']);
      expect(r.clusterOf('a'), isNull);
      expect(r.speakerIdForSegment('a'), isNull);
    });

    test('minority embedding dimension is skipped', () {
      final r = refineSpeakers(items: [
        ('a', basis(0), 3000),
        ('b', basis(0), 3000),
        ('c', basis(0, dim: 64), 3000),
      ], knownSpeakers: const []);
      expect(r.skippedSegmentIds, ['c']);
      expect(r.clusters, hasLength(1));
      expect(r.clusters.single.segmentIds, ['a', 'b']);
    });

    test('duplicate ids and bad parameters throw', () {
      expect(
          () => refineSpeakers(items: [
                ('a', basis(0), 1000),
                ('a', basis(1), 1000),
              ], knownSpeakers: const []),
          throwsArgumentError);
      expect(
          () => refineSpeakers(
              items: const [],
              knownSpeakers: const [],
              clusterThreshold: double.nan),
          throwsArgumentError);
      expect(
          () => refineSpeakers(
              items: const [], knownSpeakers: const [], maxMatrixItems: 1),
          throwsArgumentError);
    });

    test('accessors expose centroids and links', () {
      final r = refineSpeakers(items: [
        ('a', basis(0), 3000),
        ('b', basis(1), 3000),
      ], knownSpeakers: [knownSpeaker('k', basis(1))]);
      expect(r.centroids.keys, ['cluster:1', 'cluster:2']);
      expect(r.speakerIdByCluster, {'cluster:1': null, 'cluster:2': 'k'});
      expect(r.clusterById('cluster:2')!.segmentIds, ['b']);
      expect(r.clusterById('missing'), isNull);
    });
  });

  group('threshold behaviour', () {
    test('pairs merge only when similarity reaches the threshold', () {
      final a = basis(0);
      final b = rotateTowards(a, basis(1), 0.55);
      final items = [('a', a, 3000), ('b', b, 3000)];
      expect(
          refineSpeakers(
                  items: items, knownSpeakers: const [], clusterThreshold: 0.5)
              .clusters,
          hasLength(1));
      expect(
          refineSpeakers(
                  items: items, knownSpeakers: const [], clusterThreshold: 0.6)
              .clusters,
          hasLength(2));
    });

    test('average linkage does not chain', () {
      // a–b and b–c are similar (0.6) but a–c is not (≈0.0): single linkage
      // would chain all three; average linkage keeps c apart.
      final a = basis(0);
      final b = rotateTowards(a, basis(1), 0.6);
      final c = rotateTowards(b, basis(2), 0.6);
      final c2 = Float32List.fromList(c);
      final r = agglomerativeCluster([a, b, c, c2], threshold: 0.5);
      expect(r[0], r[1]);
      expect(r[2], r[3]);
      expect(r[0], isNot(r[2]));
    });
  });

  group('known speakers', () {
    test('clusters link to matching voiceprints, one-to-one', () {
      final g = SyntheticVoices(3);
      final centres = g.centres(4);
      final turns = conversation(g, centres, segments: 200, sigma: 0.05);
      final known = [
        knownSpeaker('ahmed', centres[1]),
        knownSpeaker('mona', centres[3]),
        knownSpeaker('decoy', g.unit()),
        knownSpeaker('silent', null),
        knownSpeaker('old-model', basis(0, dim: 64)),
      ];
      final r = refineSpeakers(items: itemsOf(turns), knownSpeakers: known);
      expect(r.clusters, hasLength(4));
      for (var i = 0; i < turns.length; i++) {
        final sp = r.speakerIdForSegment('s$i');
        switch (turns[i].speaker) {
          case 1:
            expect(sp, 'ahmed');
          case 3:
            expect(sp, 'mona');
          default:
            expect(sp, isNull);
        }
      }
      final linked = [
        for (final c in r.clusters)
          if (c.linkedSpeakerId != null) c.linkedSpeakerId,
      ];
      expect(linked, unorderedEquals(['ahmed', 'mona']));
    });

    test('two clusters never map to the same known speaker', () {
      final a = basis(0), b = basis(1);
      // The voiceprint is equally similar (≈0.71) to two distinct voices.
      final x = l2Normalize(Float32List(192)
        ..[0] = 1
        ..[1] = 1);
      final r = refineSpeakers(items: [
        ('a1', a, 3000),
        ('a2', a, 3000),
        ('b1', b, 3000),
        ('b2', b, 3000),
      ], knownSpeakers: [
        knownSpeaker('x', x)
      ]);
      expect(r.clusters, hasLength(2));
      expect(r.clusters.where((c) => c.linkedSpeakerId == 'x'), hasLength(1));
    });

    test('optimal assignment beats greedy', () {
      // Cluster A: x 0.95, y 0.90. Cluster B: x 0.92, y 0.30.
      // Greedy would give A→x and leave B unlinked; optimal is A→y, B→x.
      final ca = basis(0), cb = basis(1);
      final x = _withSims(ca, cb, 0.95, 0.92);
      final y = _withSims(ca, cb, 0.90, 0.30);
      final r = refineSpeakers(
        items: [('a', ca, 4000), ('b', cb, 4000)],
        knownSpeakers: [knownSpeaker('x', x), knownSpeaker('y', y)],
        clusterThreshold: 0.99,
        voiceprintMergeThreshold: 2,
      );
      expect(r.speakerIdForSegment('a'), 'y');
      expect(r.speakerIdForSegment('b'), 'x');
    });

    test('below linkThreshold → new speaker', () {
      final r = refineSpeakers(
          items: [('a', basis(0), 3000)],
          knownSpeakers: [
            knownSpeaker('k', rotateTowards(basis(0), basis(1), 0.55))
          ]);
      expect(r.clusters.single.isNewSpeaker, isTrue);
      expect(r.clusters.single.linkReason, ClusterLinkReason.none);
      expect(r.clusters.single.linkSimilarity, isNull);
    });

    test('split person is re-merged through their voiceprint', () {
      final a = basis(0);
      final a2 = rotateTowards(a, basis(1), 0.45);
      final x = l2Normalize(Float32List(192)
        ..[0] = 1
        ..[1] = 0.3);
      final items = [('p', a, 6000), ('q', a2, 6000)];
      final merged = refineSpeakers(
          items: items,
          knownSpeakers: [knownSpeaker('x', x)],
          clusterThreshold: 0.5,
          linkThreshold: 0.6);
      // a–a2 = 0.45 < 0.5 so clustering splits them, then the voiceprint
      // pulls the unlinked half back (centroid similarity 0.45 ≥ 0.4).
      expect(merged.clusters, hasLength(1));
      expect(merged.speakerIdForSegment('q'), 'x');
      final kept = refineSpeakers(
          items: items,
          knownSpeakers: [knownSpeaker('x', x)],
          voiceprintMergeThreshold: 0.5);
      expect(kept.clusters, hasLength(2));
      expect(kept.clusters.where((c) => c.linkedSpeakerId == 'x'),
          hasLength(1));
    });
  });

  group('locked assignments', () {
    late SyntheticVoices g;
    late List<Float32List> centres;
    late List<Turn> turns;
    setUp(() {
      g = SyntheticVoices(21);
      centres = g.centres(3);
      turns = conversation(g, centres, segments: 150, sigma: 0.05);
    });

    test('locked segments keep their speaker and anchor the cluster', () {
      final lockedIdx = [
        for (var i = 0; i < turns.length; i++)
          if (turns[i].speaker == 2) i,
      ].take(3);
      final locked = {for (final i in lockedIdx) 's$i': 'user-picked'};
      final r = refineSpeakers(
          items: itemsOf(turns),
          knownSpeakers: [knownSpeaker('voice-match', centres[2])],
          lockedAssignments: locked);
      for (var i = 0; i < turns.length; i++) {
        if (turns[i].speaker == 2) {
          expect(r.speakerIdForSegment('s$i'), 'user-picked');
        }
      }
      final anchored =
          r.clusters.where((c) => c.linkReason == ClusterLinkReason.locked);
      expect(anchored, hasLength(1));
      // The voiceprint of a different id is not linked to another cluster
      // just because it matches the anchored voice.
      expect(r.clusters.where((c) => c.linkedSpeakerId == 'voice-match'),
          isEmpty);
    });

    test('locked speaker that also has a voiceprint reports similarity', () {
      final first = [
        for (var i = 0; i < turns.length; i++)
          if (turns[i].speaker == 0) i,
      ].first;
      final r = refineSpeakers(
          items: itemsOf(turns),
          knownSpeakers: [knownSpeaker('p', centres[0])],
          lockedAssignments: {'s$first': 'p'});
      final c = r.clusterOf('s$first')!;
      expect(c.linkedSpeakerId, 'p');
      expect(c.linkReason, ClusterLinkReason.locked);
      expect(c.linkSimilarity, greaterThan(0.9));
    });

    test('different locked speakers never merge (cannot-link)', () {
      final ofZero = [
        for (var i = 0; i < turns.length; i++)
          if (turns[i].speaker == 0) i,
      ];
      final r = refineSpeakers(
          items: itemsOf(turns),
          knownSpeakers: const [],
          lockedAssignments: {
            's${ofZero[0]}': 'twin-1',
            's${ofZero[1]}': 'twin-2',
          });
      expect(r.speakerIdForSegment('s${ofZero[0]}'), 'twin-1');
      expect(r.speakerIdForSegment('s${ofZero[1]}'), 'twin-2');
      expect(r.clusterOf('s${ofZero[0]}')!.id,
          isNot(r.clusterOf('s${ofZero[1]}')!.id));
    });

    test('a user correction moves a segment against its voice', () {
      final s0 = [
        for (var i = 0; i < turns.length; i++)
          if (turns[i].speaker == 0) i,
      ];
      final s1 = [
        for (var i = 0; i < turns.length; i++)
          if (turns[i].speaker == 1) i,
      ];
      final r = refineSpeakers(
          items: itemsOf(turns),
          knownSpeakers: const [],
          lockedAssignments: {
            's${s0[0]}': 'A',
            's${s0[1]}': 'A',
            's${s1[0]}': 'A', // the user says this one is A too
          });
      expect(r.speakerIdForSegment('s${s1[0]}'), 'A');
      // The rest of speaker 1 is not dragged into A.
      expect(r.speakerIdForSegment('s${s1[1]}'), isNull);
    });

    test('split half re-merges into an anchored cluster via voiceprint', () {
      final a = basis(0);
      final a2 = rotateTowards(a, basis(1), 0.45);
      final x = l2Normalize(Float32List(192)
        ..[0] = 1
        ..[1] = 0.3);
      final r = refineSpeakers(
          items: [('p', a, 6000), ('q', a2, 6000)],
          knownSpeakers: [knownSpeaker('x', x)],
          lockedAssignments: {'p': 'x'});
      expect(r.clusters, hasLength(1));
      expect(r.speakerIdForSegment('q'), 'x');
      expect(r.clusters.single.linkReason, ClusterLinkReason.locked);
    });

    test('locked segments without embeddings are reported as skipped', () {
      final r = refineSpeakers(items: [
        ('a', basis(0), 3000),
        ('b', Float32List(192), 3000),
      ], knownSpeakers: const [], lockedAssignments: {'b': 'x'});
      expect(r.skippedSegmentIds, ['b']);
      expect(r.clusters.single.linkedSpeakerId, isNull);
    });
  });

  group('tiny clusters', () {
    test('merged into a similar substantial cluster', () {
      final a = basis(0);
      final r = refineSpeakers(items: [
        ('long1', a, 5000),
        ('long2', a, 5000),
        ('tiny', rotateTowards(a, basis(1), 0.4), 900),
      ], knownSpeakers: const []);
      expect(r.clusters, hasLength(1));
      expect(r.clusters.single.segmentIds, ['long1', 'long2', 'tiny']);
    });

    test('kept when nothing is similar enough', () {
      final r = refineSpeakers(items: [
        ('long1', basis(0), 5000),
        ('tiny', rotateTowards(basis(0), basis(1), 0.2), 900),
      ], knownSpeakers: const []);
      expect(r.clusters, hasLength(2));
    });

    test('anchored tiny clusters are never merged away', () {
      final r = refineSpeakers(
          items: [
            ('long1', basis(0), 5000),
            ('tiny', rotateTowards(basis(0), basis(1), 0.45), 900),
          ],
          knownSpeakers: const [],
          lockedAssignments: {'tiny': 'u'});
      expect(r.clusters, hasLength(2));
      expect(r.speakerIdForSegment('tiny'), 'u');
    });
  });

  group('agglomerativeCluster', () {
    test('labels follow first appearance', () {
      final r = agglomerativeCluster(
          [basis(5), basis(1), basis(5), basis(1), basis(9)],
          threshold: 0.5);
      expect(r, [0, 1, 0, 1, 2]);
    });

    test('empty and single input', () {
      expect(agglomerativeCluster([], threshold: 0.5), isEmpty);
      expect(agglomerativeCluster([basis(0)], threshold: 0.5), [0]);
    });

    test('validates argument lengths', () {
      expect(
          () => agglomerativeCluster([basis(0)], threshold: 0.5, weights: []),
          throwsArgumentError);
      expect(
          () => agglomerativeCluster([basis(0)], threshold: 0.5, anchors: []),
          throwsArgumentError);
      expect(
          () => agglomerativeCluster([basis(0), basis(0, dim: 8)],
              threshold: 0.5),
          throwsArgumentError);
    });

    test('dimension not divisible by 4 is handled', () {
      final r = agglomerativeCluster(
          [basis(0, dim: 7), basis(6, dim: 7), basis(0, dim: 7)],
          threshold: 0.5);
      expect(r, [0, 1, 0]);
    });

    test('weights shift the linkage', () {
      // a–b = 0.7, a–c = 0.6, b–c = 0. After {a,b} merge, the linkage to c is
      // 0.3 with equal weights but 0.54 when a dominates.
      final a = basis(0);
      final b = Float32List(192)
        ..[0] = 0.7
        ..[2] = -0.525
        ..[1] = 0.4841;
      final c = Float32List(192)
        ..[0] = 0.6
        ..[2] = 0.8;
      final equal = agglomerativeCluster([a, b, c], threshold: 0.5);
      expect(equal, [0, 0, 1]);
      final weighted =
          agglomerativeCluster([a, b, c], threshold: 0.5, weights: [9, 1, 1]);
      expect(weighted, [0, 0, 0]);
    });

    test('matrix cap attaches deferred items to the nearest cluster', () {
      final g = SyntheticVoices(11);
      final centres = g.centres(4);
      final turns = conversation(g, centres, segments: 400, sigma: 0.05);
      final labels = agglomerativeCluster(
        [for (final t in turns) t.embedding],
        threshold: 0.5,
        weights: [for (final t in turns) t.durationMs / 1000],
        maxMatrixItems: 120,
      );
      final truth = [for (final t in turns) t.speaker];
      expect(purity(truth, labels), greaterThan(0.95));
      expect(labels.toSet(), hasLength(4));
    });

    test('2000 × 256 finishes quickly', () {
      final g = SyntheticVoices(2024, dim: 256);
      final centres = g.centres(8, correlation: 0.1);
      final turns = conversation(g, centres, segments: 2000, sigma: 0.05);
      final sw = Stopwatch()..start();
      final r = refineSpeakers(items: itemsOf(turns), knownSpeakers: const []);
      sw.stop();
      final labels = [
        for (var i = 0; i < turns.length; i++) r.clusterIdBySegment['s$i'],
      ];
      expect(purity([for (final t in turns) t.speaker], labels),
          greaterThan(0.95));
      // Target is < 2 s on a desktop; the bound is generous for slow CI.
      expect(sw.elapsedMilliseconds, lessThan(10000),
          reason: 'took ${sw.elapsedMilliseconds} ms');
      // ignore: avoid_print
      print('refineSpeakers 2000x256: ${sw.elapsedMilliseconds} ms');
    });
  });

  group('hungarianMaximize', () {
    test('matches brute force on random matrices', () {
      final rnd = math.Random(5);
      for (var trial = 0; trial < 200; trial++) {
        final rows = 1 + rnd.nextInt(5);
        final cols = 1 + rnd.nextInt(5);
        final w = [
          for (var r = 0; r < rows; r++)
            [
              for (var c = 0; c < cols; c++)
                rnd.nextBool() ? rnd.nextDouble() : 0.0,
            ],
        ];
        final m = hungarianMaximize(w);
        expect(m, hasLength(rows));
        final usedCols = m.where((c) => c >= 0).toList();
        expect(usedCols.toSet().length, usedCols.length);
        var total = 0.0;
        for (var r = 0; r < rows; r++) {
          if (m[r] >= 0) total += w[r][m[r]];
        }
        expect(total, closeTo(_bruteForce(w), 1e-9));
      }
    });

    test('degenerate shapes', () {
      expect(hungarianMaximize([]), isEmpty);
      expect(hungarianMaximize([[], []]), [-1, -1]);
      expect(() => hungarianMaximize([[1.0], [1.0, 2.0]]), throwsArgumentError);
    });
  });

  group('updateVoiceprint', () {
    test('new voiceprint is the mean of new embeddings', () {
      final (c, n) =
          updateVoiceprint(null, 0, [basis(0), Float32List(192)..[1] = 5]);
      expect(n, 2);
      expect(c[0], closeTo(math.sqrt1_2, 1e-6));
      expect(c[1], closeTo(math.sqrt1_2, 1e-6));
    });

    test('weights old centroid by its count', () {
      final (c, n) = updateVoiceprint(basis(0), 3, [basis(1)]);
      expect(n, 4);
      // normalize(3·e0 + e1)
      expect(c[0] / c[1], closeTo(3, 1e-5));
      expect(l2Norm(c), closeTo(1, 1e-6));
    });

    test('count is capped so voices can drift', () {
      final (c, n) = updateVoiceprint(basis(0), 1000, [basis(1)], cap: 200);
      expect(n, 200);
      expect(c[0] / c[1], closeTo(200, 1e-2));
      final (_, n2) = updateVoiceprint(
          basis(0), 199, [basis(1), basis(1), basis(1)],
          cap: 200);
      expect(n2, 200);
    });

    test('ignores unusable inputs and discards incompatible old centroid', () {
      final (c, n) = updateVoiceprint(basis(0, dim: 64), 50, [
        basis(2),
        Float32List(192),
        Float32List(192)..[0] = double.nan,
      ]);
      expect(n, 1);
      expect(c.length, 192);
      expect(c[2], closeTo(1, 1e-6));
    });

    test('no new embeddings keeps the old voiceprint', () {
      final (c, n) =
          updateVoiceprint(Float32List(4)..[0] = 2, 7, const [], cap: 5);
      expect(n, 5);
      expect(c, [1, 0, 0, 0]);
    });

    test('throws without any usable data or with a bad cap', () {
      expect(() => updateVoiceprint(null, 0, []), throwsArgumentError);
      expect(() => updateVoiceprint(Float32List(3), 4, [Float32List(3)]),
          throwsArgumentError);
      expect(() => updateVoiceprint(basis(0), 1, [basis(1)], cap: 0),
          throwsArgumentError);
    });
  });
}

/// Unit vector with cosine [sa] to orthonormal [a] and [sb] to [b].
Float32List _withSims(Float32List a, Float32List b, double sa, double sb) {
  final rest = math.sqrt(math.max(0, 1 - sa * sa - sb * sb));
  final v = Float32List(a.length);
  for (var i = 0; i < v.length; i++) {
    v[i] = sa * a[i] + sb * b[i];
  }
  v[100] += rest;
  return v;
}

double _bruteForce(List<List<double>> w) {
  final rows = w.length, cols = w.first.length;
  var best = 0.0;
  void go(int r, Set<int> used, double acc) {
    if (r == rows) {
      if (acc > best) best = acc;
      return;
    }
    go(r + 1, used, acc);
    for (var c = 0; c < cols; c++) {
      if (used.contains(c)) continue;
      used.add(c);
      go(r + 1, used, acc + w[r][c]);
      used.remove(c);
    }
  }

  go(0, <int>{}, 0);
  return best;
}
