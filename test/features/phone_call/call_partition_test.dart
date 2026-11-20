// Hard call-side partitions in live speaker tracking and offline refinement.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/diarization/channel_cue.dart';
import 'package:insato/diarization/clustering.dart';
import 'package:insato/diarization/speaker_tracker.dart';
import 'package:insato/diarization/vector_math.dart';

import '../../diarization/synthetic.dart' show knownSpeaker;

Float32List _v(List<(int, double)> parts, {int dim = 16}) {
  final v = Float32List(dim);
  for (final (k, c) in parts) {
    v[k] += c;
  }
  return l2Normalize(v);
}

ChannelProfile _side(String p) => ChannelProfile(const {}, partition: p);

void main() {
  group('SpeakerTracker partitions', () {
    test('the same-sounding voice on both sides gives two speakers', () {
      final voice = _v([(0, 1)]);
      final plain = SpeakerTracker(knownSpeakers: const []);
      final a = plain.assign(
        segmentIndex: 0,
        startMs: 0,
        endMs: 3000,
        embedding: voice,
      );
      final b = plain.assign(
        segmentIndex: 1,
        startMs: 4000,
        endMs: 7000,
        embedding: voice,
      );
      expect(b.clusterKey, a.clusterKey);

      final t = SpeakerTracker(knownSpeakers: const []);
      final r = t.assign(
        segmentIndex: 0,
        startMs: 0,
        endMs: 3000,
        embedding: voice,
        channels: _side('remote'),
      );
      final l = t.assign(
        segmentIndex: 1,
        startMs: 4000,
        endMs: 7000,
        embedding: voice,
        channels: _side('local'),
      );
      expect(l.clusterKey, isNot(r.clusterKey));
      expect(l.decision, AssignmentDecision.newCluster);
      final r2 = t.assign(
        segmentIndex: 2,
        startMs: 8000,
        endMs: 11000,
        embedding: voice,
        channels: _side('remote'),
      );
      expect(r2.clusterKey, r.clusterKey);
    });

    test('continuity is tracked per side', () {
      final t = SpeakerTracker(knownSpeakers: const []);
      final r = t.assign(
        segmentIndex: 0,
        startMs: 0,
        endMs: 3000,
        embedding: _v([(1, 1)]),
        channels: _side('remote'),
      );
      // A local turn overlaps the end of the remote one.
      t.assign(
        segmentIndex: 1,
        startMs: 2500,
        endMs: 5000,
        embedding: _v([(2, 1)]),
        channels: _side('local'),
      );
      // A short remote reply without an embedding inherits the remote
      // speaker, not the local one who spoke last.
      final short = t.assign(
        segmentIndex: 2,
        startMs: 3600,
        endMs: 4000,
        channels: _side('remote'),
      );
      expect(short.decision, AssignmentDecision.inherited);
      expect(short.clusterKey, r.clusterKey);
    });

    test('voiceprint thresholds may depend on the side', () {
      final vp = _v([(3, 1)]);
      // Similarity 0.5 to the voiceprint.
      final seg = _v([(3, 0.5), (4, 0.866)]);
      double threshold(sp, String? partition) =>
          partition == 'remote' ? 0.45 : 0.55;
      final t = SpeakerTracker(
        knownSpeakers: [knownSpeaker('k', vp)],
        knownSpeakerThresholdIn: threshold,
      );
      final local = t.assign(
        segmentIndex: 0,
        startMs: 0,
        endMs: 3000,
        embedding: seg,
        channels: _side('local'),
      );
      expect(local.linkedSpeakerId, isNull);
      final remote = t.assign(
        segmentIndex: 1,
        startMs: 4000,
        endMs: 7000,
        embedding: seg,
        channels: _side('remote'),
      );
      expect(remote.linkedSpeakerId, 'k');
      expect(remote.decision, AssignmentDecision.matchedKnownSpeaker);
    });
  });

  group('refineSpeakers partitions', () {
    final voice = _v([(5, 1)]);
    final items = <(String, Float32List, int)>[
      ('r1', voice, 3000),
      ('l1', voice, 3000),
      ('r2', voice, 3000),
      ('l2', voice, 3000),
    ];

    test('without partitions one voice is one cluster', () {
      final r = refineSpeakers(items: items, knownSpeakers: const []);
      expect(r.clusters, hasLength(1));
    });

    test('sides are never clustered together', () {
      final r = refineSpeakers(
        items: items,
        knownSpeakers: const [],
        channelProfiles: {
          'r1': _side('remote'),
          'r2': _side('remote'),
          'l1': _side('local'),
          'l2': _side('local'),
        },
      );
      expect(r.clusters, hasLength(2));
      expect(r.clusterIdBySegment['r1'], r.clusterIdBySegment['r2']);
      expect(r.clusterIdBySegment['l1'], r.clusterIdBySegment['l2']);
      expect(r.clusterIdBySegment['r1'], isNot(r.clusterIdBySegment['l1']));
      // Ids follow first appearance.
      expect(r.clusterIdBySegment['r1'], 'cluster:1');
      expect(r.clusterIdBySegment['l1'], 'cluster:2');
    });

    test('a voiceprint links to one side only; locks are kept', () {
      final r = refineSpeakers(
        items: items,
        knownSpeakers: [knownSpeaker('k', voice)],
        channelProfiles: {
          'r1': _side('remote'),
          'r2': _side('remote'),
          'l1': _side('local'),
          'l2': _side('local'),
        },
      );
      final linked = r.clusters.where((c) => c.linkedSpeakerId == 'k');
      expect(linked, hasLength(1));

      final locked = refineSpeakers(
        items: items,
        knownSpeakers: const [],
        lockedAssignments: const {'l1': 'x'},
        channelProfiles: {
          'r1': _side('remote'),
          'r2': _side('remote'),
          'l1': _side('local'),
          'l2': _side('local'),
        },
      );
      expect(locked.clusterOf('l2')?.linkedSpeakerId, 'x');
      expect(locked.clusterOf('r1')?.linkedSpeakerId, isNull);
    });

    test('segments without a side form their own group', () {
      final r = refineSpeakers(
        items: items,
        knownSpeakers: const [],
        channelProfiles: {'r1': _side('remote'), 'r2': _side('remote')},
      );
      expect(r.clusters, hasLength(2));
      expect(r.clusterIdBySegment['l1'], r.clusterIdBySegment['l2']);
    });
  });
}
