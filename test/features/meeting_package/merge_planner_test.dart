import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/meeting_package/merge_planner.dart';
import 'package:insato/features/meeting_package/package_format.dart';

TranscriptSegment _m(
  String id,
  int idx,
  int s,
  int e,
  String text, {
  double? asr,
}) => TranscriptSegment(
  id: id,
  meetingId: 'm',
  index: idx,
  startMs: s,
  endMs: e,
  text: text,
  asrConfidence: asr,
);

PackageSegment _r(
  int idx,
  int s,
  int e,
  String text, {
  double? snr,
  String? speaker,
  double? asr,
}) => PackageSegment(
  index: idx,
  startMs: s,
  endMs: e,
  text: text,
  snrDb: snr,
  speakerKey: speaker,
  asrConfidence: asr,
);

Float32List _unit(List<double> v) {
  final out = Float32List.fromList(v);
  var n = 0.0;
  for (final x in out) {
    n += x * x;
  }
  for (var i = 0; i < out.length; i++) {
    out[i] /= n == 0 ? 1 : n;
  }
  return out;
}

Speaker _sp(
  String id,
  String name, {
  bool named = true,
  Float32List? centroid,
}) => Speaker(
  id: id,
  name: name,
  colorValue: 0,
  isNamedByUser: named,
  createdAt: DateTime(2026),
  centroid: centroid,
  embeddingCount: centroid == null ? 0 : 5,
);

void main() {
  test('textSimilarity tolerates spelling variants and punctuation', () {
    expect(
      textSimilarity('نبدأ بمراجعة الميزانية.', 'نبدا بمراجعه الميزانيه'),
      greaterThan(0.9),
    );
    expect(textSimilarity('مرحبا', 'the budget'), lessThan(0.1));
    expect(textSimilarity('', 'x'), 0);
  });

  group('planMerge', () {
    test('interleaves remote segments by aligned time and renumbers', () {
      final plan = planMerge(
        main: [
          (segment: _m('a', 0, 0, 2000, 'افتتاح'), snrDb: null),
          (segment: _m('b', 1, 10000, 12000, 'البند الثاني'), snrDb: null),
        ],
        remote: [
          _r(0, 0, 1500, 'رأي الفريق الميداني'),
          _r(1, 9000, 9800, 'سؤال من الميدان'),
        ],
        offsetMs: 4000,
        sameRoom: false,
        mainDurationMs: 12000,
        remoteDurationMs: 10000,
      );
      expect(plan.shiftMs, 0);
      expect(plan.mainIndex, {'a': 0, 'b': 2});
      expect(
        [for (final i in plan.inserts) (i.index, i.startMs, i.endMs)],
        [(1, 4000, 5500), (3, 13000, 13800)],
      );
      expect(plan.duplicates, 0);
      expect(plan.durationMs, 14000);
      expect(
        plan.indexRemap([
          _m('a', 0, 0, 2000, ''),
          _m('b', 1, 10000, 12000, ''),
        ]),
        {0: 0, 1: 2},
      );
    });

    test(
      'a remote recording that started earlier shifts the main timeline',
      () {
        final plan = planMerge(
          main: [(segment: _m('a', 0, 1000, 3000, 'نعم'), snrDb: null)],
          remote: [_r(0, 0, 2000, 'قبل وصول الجهاز الرئيسي')],
          offsetMs: -5000,
          sameRoom: false,
          mainDurationMs: 3000,
          remoteDurationMs: 9000,
        );
        expect(plan.shiftMs, 5000);
        expect(plan.mainTimes['a'], (6000, 8000));
        expect(plan.inserts.single.startMs, 0);
        expect(plan.inserts.single.index, 0);
        expect(plan.mainIndex['a'], 1);
        expect(plan.durationMs, 9000);
      },
    );

    test('duplicates keep the better-SNR text and never double it', () {
      final plan = planMerge(
        main: [
          (segment: _m('a', 0, 1000, 4000, 'نبدأ بمراجعة الميزانية'), snrDb: 8),
          (segment: _m('b', 1, 5000, 8000, 'نوافق على الخطة'), snrDb: 30),
        ],
        remote: [
          // Same utterances, heard by both devices.
          _r(0, 1050, 4020, 'نبدا بمراجعة الميزانيه للربع', snr: 25),
          _r(1, 4980, 7900, 'نوافق على الخطه', snr: 12),
          // Only the remote device heard this one.
          _r(2, 9000, 9500, 'شكرا'),
        ],
        offsetMs: 0,
        sameRoom: true,
      );
      expect(plan.replacements, hasLength(1));
      expect(plan.replacements.single.mainSegmentId, 'a');
      expect(
        plan.replacements.single.source.text,
        'نبدا بمراجعة الميزانيه للربع',
      );
      expect(plan.droppedDuplicates, 1);
      expect(plan.inserts.single.source.text, 'شكرا');
      expect(plan.inserts.single.index, 2);
    });

    test(
      'same room: a large overlap is a duplicate even if the texts differ',
      () {
        final plan = planMerge(
          main: [(segment: _m('a', 0, 0, 3000, 'Budget review'), snrDb: 20)],
          remote: [_r(0, 100, 2900, 'مراجعة الميزانية', snr: 10)],
          offsetMs: 0,
          sameRoom: true,
        );
        expect(plan.inserts, isEmpty);
        expect(plan.droppedDuplicates, 1);
      },
    );

    test('different rooms: overlapping but different speech is kept', () {
      final plan = planMerge(
        main: [(segment: _m('a', 0, 0, 3000, 'Budget review'), snrDb: 20)],
        remote: [_r(0, 100, 2900, 'مراجعة الجدول الزمني', snr: 10)],
        offsetMs: 0,
        sameRoom: false,
      );
      expect(plan.inserts, hasLength(1));
      expect(plan.duplicates, 0);
    });

    test(
      'without SNR: recognised text beats unintelligible, then confidence',
      () {
        final plan = planMerge(
          main: [
            (
              segment: _m(
                'a',
                0,
                0,
                3000,
                '',
              ).copyWith(kind: SegmentKind.unintelligible),
              snrDb: null,
            ),
            (
              segment: _m('b', 1, 4000, 6000, 'تمت الموافقة', asr: 0.5),
              snrDb: null,
            ),
          ],
          remote: [
            _r(0, 0, 3000, 'وصلنا إلى اتفاق'),
            _r(1, 4000, 6000, 'تمت الموافقه', asr: 0.9),
          ],
          offsetMs: 0,
          sameRoom: true,
        );
        expect(
          {for (final r in plan.replacements) r.mainSegmentId},
          {'a', 'b'},
        );
      },
    );
  });

  group('mapRemoteSpeakers', () {
    final voiceA = _unit([1, 0, 0, 0]);
    final voiceB = _unit([0, 1, 0, 0]);

    test('voiceprints map to the library; others become device speakers', () {
      final map = mapRemoteSpeakers(
        remote: [
          PackageSpeaker(
            key: 'r1',
            name: 'متحدث 1',
            colorValue: 0,
            isNamedByUser: false,
            centroid: _unit([0.98, 0.05, 0, 0]),
          ),
          const PackageSpeaker(
            key: 'r2',
            name: 'متحدث 2',
            colorValue: 0,
            isNamedByUser: false,
          ),
          const PackageSpeaker(
            key: 'r3',
            name: 'سارة',
            colorValue: 0,
            isNamedByUser: true,
          ),
          const PackageSpeaker(
            key: 'r4',
            name: 'خالد',
            colorValue: 0,
            isNamedByUser: true,
          ),
        ],
        library: [
          _sp('lib-a', 'أحمد', centroid: voiceA),
          _sp('lib-b', 'منى', centroid: voiceB),
          _sp('lib-s', 'سارة'),
          _sp('lib-auto', 'متحدث 2 (جهاز: هاتف ب)', named: false),
        ],
        deviceName: 'هاتف ب',
        matchThreshold: 0.6,
      );
      expect(map['r1']!.speakerId, 'lib-a');
      expect(map['r1']!.byVoice, isTrue);
      // Name already taken by an earlier import: next number.
      expect(map['r2']!.creates, isTrue);
      expect(map['r2']!.newName, 'متحدث 3 (جهاز: هاتف ب)');
      expect(map['r2']!.newNamedByUser, isFalse);
      expect(map['r3']!.speakerId, 'lib-s');
      expect(map['r4']!.newName, 'خالد');
      expect(map['r4']!.newNamedByUser, isTrue);
    });

    test('a library voice is used once; a weak match creates a speaker', () {
      final map = mapRemoteSpeakers(
        remote: [
          PackageSpeaker(
            key: 'x',
            name: 'متحدث 1',
            colorValue: 0,
            isNamedByUser: false,
            centroid: _unit([0.9, 0.1, 0, 0]),
          ),
          PackageSpeaker(
            key: 'y',
            name: 'متحدث 2',
            colorValue: 0,
            isNamedByUser: false,
            centroid: _unit([0.99, 0.01, 0, 0]),
          ),
          PackageSpeaker(
            key: 'z',
            name: 'متحدث 3',
            colorValue: 0,
            isNamedByUser: false,
            centroid: _unit([0, 0, 1, 0]),
          ),
        ],
        library: [_sp('lib-a', 'أحمد', centroid: voiceA)],
        deviceName: '',
        matchThreshold: 0.6,
      );
      expect(map['y']!.speakerId, 'lib-a');
      expect(map['x']!.creates, isTrue);
      expect(map['x']!.newName, 'متحدث 1');
      expect(map['z']!.creates, isTrue);
      expect(map['z']!.centroid, isNotNull);
    });
  });

  test('remapEvidenceJson rewrites only segment references', () {
    final out = remapEvidenceJson(
      {
        'title': 'x',
        'count': 3,
        'topics': [
          {
            'evidence': [0, 1, 7],
            'n': 1,
          },
        ],
        'notes': [
          {'segment': 1, 'meeting_id': 'm'},
        ],
        'segment_ids': [1],
      },
      {0: 2, 1: 5},
    );
    expect(out, {
      'title': 'x',
      'count': 3,
      'topics': [
        {
          'evidence': [2, 5, 7],
          'n': 1,
        },
      ],
      'notes': [
        {'segment': 5, 'meeting_id': 'm'},
      ],
      'segment_ids': [5],
    });
  });
}
