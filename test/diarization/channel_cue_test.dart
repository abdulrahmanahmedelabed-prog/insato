import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/diarization/channel_cue.dart';
import 'package:insato/diarization/clustering.dart';
import 'package:insato/diarization/speaker_tracker.dart';

Float32List _unit(List<double> v) {
  final n = math.sqrt(v.fold(0.0, (a, x) => a + x * x));
  return Float32List.fromList([for (final x in v) x / n]);
}

Float32List _basis(int i, {int d = 16}) => Float32List(d)..[i] = 1;

double _dot(Float32List a, Float32List b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

void main() {
  final nearHost = ChannelProfile({'host': 20, 'g1': 5});
  final nearGuest = ChannelProfile({'host': 4, 'g1': 19});
  final tie = ChannelProfile({'host': 10, 'g1': 10});

  group('ChannelProfile / proximityCue', () {
    test('nearest, softmax, JSON', () {
      expect(nearHost.nearest, 'host');
      expect(nearHost.proximity()['host'], greaterThan(0.99));
      expect(nearHost.isInformative, isTrue);
      expect(ChannelProfile({'host': 3}).isInformative, isFalse);
      expect(ChannelProfile({'a': double.nan}).snrDb, isEmpty);
      final back = ChannelProfile.fromJson(nearGuest.toJson())!;
      expect(back.snrDb, {'host': 4.0, 'g1': 19.0});
      expect(ChannelProfile.fromJson('x'), isNull);
      expect(ChannelProfile.fromJson({'a': 'b'}), isNull);
    });

    test('same device agrees, other device disagrees, ties are neutral', () {
      expect(
        proximityCue(nearHost.proximity(), nearHost.proximity()),
        closeTo(1, 0.02),
      );
      expect(
        proximityCue(nearHost.proximity(), nearGuest.proximity()),
        closeTo(-1, 0.02),
      );
      expect(
        proximityCue(tie.proximity(), nearHost.proximity()).abs(),
        lessThan(1e-9),
      );
      expect(proximityCue({'host': 1}, {'host': 1}), 0);
      expect(proximityCue({'host': 0.9, 'g1': 0.1}, {'g2': 0.9, 'g3': 0.1}), 0);
    });

    test('weakly separated profiles give a weak cue', () {
      final weak = ChannelProfile({'host': 11, 'g1': 10}).proximity();
      final c = proximityCue(weak, nearHost.proximity());
      expect(c, greaterThan(0));
      expect(c, lessThan(0.6));
    });

    test('accumulator averages per channel and merges', () {
      final a = ProximityAccumulator()
        ..add(nearHost, 2)
        ..add(tie, 0)
        ..add(ChannelProfile({'host': 1}), 5);
      expect(a.evidence, 2);
      expect(a.mean()['host'], greaterThan(0.99));
      final b = ProximityAccumulator()..add(nearGuest, 2);
      a.addAll(b);
      expect(a.mean()['host'], closeTo(0.5, 0.02));
    });

    test('augmented vectors stay unit length; no profile = unchanged', () {
      final e = _unit([1, 2, 3, 4]);
      final plain = augmentWithChannelCue(e, null, ['g1', 'host']);
      expect(plain.sublist(0, 4), e);
      expect(plain.sublist(4), [0, 0]);
      final a = augmentWithChannelCue(e, nearHost, ['g1', 'host']);
      final b = augmentWithChannelCue(e, nearGuest, ['g1', 'host']);
      expect(_dot(a, a), closeTo(1, 1e-5));
      expect(_dot(a, b), lessThan(_dot(a, a) - 0.1));
    });
  });

  group('SpeakerTracker with channel profiles', () {
    // Two clusters with orthogonal voices, then a segment exactly between
    // them: a close call that the nearest device settles.
    SpeakerTracker seeded() {
      final t = SpeakerTracker(knownSpeakers: const []);
      t.assign(
        segmentIndex: 0,
        startMs: 0,
        endMs: 4000,
        embedding: _basis(0),
        channels: nearHost,
      );
      t.assign(
        segmentIndex: 1,
        startMs: 10000,
        endMs: 14000,
        embedding: _basis(1),
        channels: nearGuest,
      );
      return t;
    }

    final between = _unit([1, 1, ...List.filled(14, 0.0)]);

    test('without a profile the close call stays ambiguous', () {
      final a = seeded().assign(
        segmentIndex: 2,
        startMs: 30000,
        endMs: 34000,
        embedding: between,
      );
      expect(a.decision, AssignmentDecision.ambiguousBest);
    });

    test('the nearest device decides a close call', () {
      final t = seeded();
      final toGuest = t.assign(
        segmentIndex: 2,
        startMs: 30000,
        endMs: 34000,
        embedding: between,
        channels: nearGuest,
      );
      expect(toGuest.decision, AssignmentDecision.matchedCluster);
      expect(toGuest.clusterKey, 'local:2');
      final toHost = seeded().assign(
        segmentIndex: 2,
        startMs: 30000,
        endMs: 34000,
        embedding: between,
        channels: nearHost,
      );
      expect(toHost.clusterKey, 'local:1');
      expect(toHost.decision, AssignmentDecision.matchedCluster);
    });

    test('a clear voice match is never overruled by the device', () {
      final a = seeded().assign(
        segmentIndex: 2,
        startMs: 30000,
        endMs: 34000,
        embedding: _basis(0),
        channels: nearGuest,
      );
      expect(a.clusterKey, 'local:1');
    });

    test('one-device meetings are unchanged', () {
      List<String?> run(bool withProfile) {
        final t = SpeakerTracker(knownSpeakers: const []);
        final r = <String?>[];
        for (var i = 0; i < 6; i++) {
          r.add(
            t
                .assign(
                  segmentIndex: i,
                  startMs: i * 5000,
                  endMs: i * 5000 + 3000,
                  embedding: i.isEven
                      ? _basis(0)
                      : _unit([0.6, 0.8, ...List.filled(14, 0.0)]),
                  channels: withProfile ? ChannelProfile({'host': 12}) : null,
                )
                .clusterKey,
          );
        }
        return r;
      }

      expect(run(true), run(false));
    });
  });

  test(
    'offline refinement splits similar voices heard by different devices',
    () {
      final a = _basis(0);
      final b = _unit([
        0.55,
        math.sqrt(1 - 0.55 * 0.55),
        ...List.filled(14, 0.0),
      ]);
      final items = [
        for (var i = 0; i < 4; i++) ('a$i', a, 3000),
        for (var i = 0; i < 4; i++) ('b$i', b, 3000),
      ];
      final merged = refineSpeakers(items: items, knownSpeakers: const []);
      expect(merged.clusters.length, 1);
      final split = refineSpeakers(
        items: items,
        knownSpeakers: const [],
        channelProfiles: {
          for (var i = 0; i < 4; i++) 'a$i': nearHost,
          for (var i = 0; i < 4; i++) 'b$i': nearGuest,
        },
      );
      expect(split.clusters.length, 2);
      expect(split.clusterOf('a0')!.id, split.clusterOf('a3')!.id);
      expect(split.clusterOf('a0')!.id, isNot(split.clusterOf('b0')!.id));
      // Centroids stay voice-only (linking to voiceprints is unaffected).
      expect(split.clusterOf('a0')!.centroid.length, 16);
    },
  );
}
