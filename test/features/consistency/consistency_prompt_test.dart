// The engine request of the consistency checker (v1.2, D) and the strict
// validation of its answer: the engine never invents references.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/consistency/consistency_logic.dart';
import 'package:insato/features/consistency/consistency_models.dart';
import 'package:insato/features/consistency/consistency_prompt.dart';
import 'package:insato/features/official/official_models.dart';
import 'package:insato/features/official/official_templates.dart';

import 'fixtures.dart';

void _expectStrict(Object? schema) {
  if (schema is Map) {
    if (schema['type'] == 'object') {
      expect(schema['additionalProperties'], false);
      final props = (schema['properties'] as Map).keys.toSet();
      expect((schema['required'] as List).toSet(), props);
    }
    schema.values.forEach(_expectStrict);
  } else if (schema is List) {
    schema.forEach(_expectStrict);
  }
}

String _answer(List<Map<String, Object?>> findings) =>
    jsonEncode({'findings': findings});

Map<String, Object?> _f(
  String newItem,
  String? prior,
  String kind, {
  String severity = 'high',
  String explanation = '',
  List<int> evidence = const [],
}) => {
  'new_item': newItem,
  'prior_ref': prior,
  'kind': kind,
  'severity': severity,
  'explanation': explanation,
  'evidence_segments': evidence,
};

void main() {
  final earlier = meetingWith(
    'm1',
    DateTime(2026, 1, 10),
    title: 'مجلس يناير',
    template: 'board',
    minutes: minutesWith(
      decisions: ['اعتماد عقد الصيانة مع شركة النور'],
      decisionEvidence: [
        [4],
      ],
    ),
  );
  final current = meetingWith(
    'cur',
    DateTime(2026, 6, 16, 10),
    title: 'مجلس يونيو',
    minutes: minutesWith(
      decisions: [
        'تمديد عقد الصيانة مع شركة النور لسنة إضافية',
        'اعتماد خطة التدريب',
      ],
      decisionEvidence: [
        [2],
        [3],
      ],
      actions: [('إعداد تقرير الصيانة', 'سارة', 'الخميس')],
    ),
  );
  final segments = [
    for (var i = 0; i < 5; i++)
      TranscriptSegment(
        id: 's$i',
        meetingId: 'cur',
        index: i,
        startMs: i * 10000,
        endMs: i * 10000 + 5000,
        text: 'السطر رقم $i عن عقد الصيانة',
      ),
  ];
  final memory = buildInstitutionalMemory(
    current: current,
    meetings: [
      MemoryMeeting(
        meeting: earlier,
        record: const OfficialRecord(
          meetingId: 'm1',
          status: OfficialStatus.approved,
          meetingNumber: 12,
          numberYear: 1448,
        ),
        template: OfficialTemplates.board,
      ),
    ],
    tasks: [
      taskWith(9, 'إعداد تقرير الصيانة الشهري', owner: 'خالد', source: 'm1'),
    ],
  );
  final items = newItemsOf(current);
  final candidates = retrieveCandidates(memory, items);
  ConsistencyPlan plan() => buildConsistencyPlan(
    meeting: current,
    items: items,
    candidates: candidates,
    segments: segments,
    speakersById: const {},
    charBudget: 60000,
  );

  test('the schema is strict', () {
    final schema = consistencyAnswerSchema();
    _expectStrict(schema);
    final item =
        (schema['properties'] as Map)['findings']['items']
            as Map<String, dynamic>;
    expect(
      (item['properties'] as Map)['kind']['enum'],
      containsAll(['contradicts_resolution', 'no_issue']),
    );
    expect((item['properties'] as Map)['prior_ref']['type'], [
      'string',
      'null',
    ]);
  });

  test('the request lists items, candidates with numbers and dates', () {
    final p = plan();
    expect(p.newItems.keys, ['D1', 'A1', 'D2']);
    expect(p.pairs, {
      'D1': {'R1'},
      'A1': {'T1'},
    });
    expect(p.priorItems['R1']!.label, 'قرار رقم (1/12/1448)');
    expect(p.user, contains('[D1] قرار'));
    expect(p.user, contains('[#2 00:00:20]'));
    expect(p.user, contains('[R1] قرار معتمد — قرار رقم (1/12/1448)'));
    expect(p.user, contains('رقم 12/1448هـ'));
    expect(p.user, contains('هـ الموافق'));
    expect(p.user, contains('[T1] مهمة (مفتوحة) — المسؤول: خالد'));
    expect(p.user, contains('D1: R1'));
    expect(p.knownNumbers, containsAll(['1/12/1448', '12/1448']));
    expect(kConsistencySystemPrompt, contains('Never invent references'));
  });

  test('a tight budget keeps the items with candidates first', () {
    final p = buildConsistencyPlan(
      meeting: current,
      items: items,
      candidates: candidates,
      segments: segments,
      speakersById: const {},
      charBudget: 0,
    );
    expect(p.newItems.keys.first, 'D1');
    expect(p.user.length, lessThan(3000));
  });

  test('valid findings are kept and references become labels', () {
    final found = parseConsistencyAnswer(
      _answer([
        _f(
          'D1',
          'R1',
          'contradicts_resolution',
          explanation: '[D1] يمدد العقد الذي قرره [R1] (1/12/1448).',
          evidence: [2, 99],
        ),
        _f('A1', 'T1', 'changes_owner', severity: 'medium'),
        _f('D2', 'D1', 'internal_conflict', severity: 'low'),
        _f('D1', 'R1', 'no_issue'),
      ]),
      plan(),
    );
    expect(found, hasLength(3));
    final c = found.firstWhere(
      (f) => f.kind == FindingKind.contradictsResolution,
    );
    expect(c.origin, FindingOrigin.engine);
    expect(c.priorSide.meetingId, 'm1');
    expect(c.newSide.evidence, [2]);
    expect(c.explanation, contains('قرار رقم (1/12/1448) (1/12/1448)'));
    expect(c.explanation, isNot(contains('[R1]')));
    final owner = found.firstWhere((f) => f.kind == FindingKind.changesOwner);
    expect(owner.priorSide.taskId, 9);
    expect(owner.newSide.evidence, [1]); // the action item's own evidence
    final internal = found.firstWhere(
      (f) => f.kind == FindingKind.internalConflict,
    );
    expect(internal.priorSide.itemIndex, 0);
  });

  test('invented or mismatched references are dropped', () {
    final found = parseConsistencyAnswer(
      _answer([
        _f('D9', 'R1', 'contradicts_resolution'), // unknown new item
        _f('D1', 'R7', 'contradicts_resolution'), // unknown prior
        _f('D2', 'R1', 'contradicts_resolution'), // not a candidate pair
        _f('D1', 'T1', 'contradicts_resolution'), // not D1's candidate
        _f('A1', 'T1', 'contradicts_resolution'), // a task is no resolution
        _f('D1', 'R1', 'duplicates_task'), // needs a task
        _f('D1', 'D1', 'internal_conflict'), // itself
        _f('D1', null, 'contradicts_resolution'), // no prior
        _f('D1', 'R1', 'bogus'), // unknown kind
        _f(
          'D1',
          'R1',
          'contradicts_resolution',
          explanation: 'يخالف [R4] السابق',
        ), // invented reference in the text
        _f(
          'D1',
          'R1',
          'contradicts_resolution',
          explanation: 'يخالف القرار رقم 7/3/1447',
        ), // invented resolution number
        _f(
          'D1',
          'R1',
          'contradicts_resolution',
          explanation: 'كما في المقطع #44',
        ), // unknown segment
      ]),
      plan(),
    );
    expect(found, isEmpty);
  });

  test('malformed answers yield nothing; fenced JSON is repaired', () {
    expect(parseConsistencyAnswer('not json', plan()), isEmpty);
    expect(parseConsistencyAnswer('{"findings": 3}', plan()), isEmpty);
    final fenced =
        '```json\n${_answer([_f('A1', 'T1', 'duplicates_task', severity: 'x')])}\n```';
    final found = parseConsistencyAnswer(fenced, plan());
    expect(found.single.severity, FindingSeverity.medium);
  });

  test('live plan: the excerpt and evidence-backed findings only', () {
    final live = buildLivePlan(
      meetingId: 'cur',
      title: 'مجلس يونيو',
      date: DateTime(2026, 6, 16, 10),
      recent: segments,
      candidates: memory.items,
      speakersById: const {},
      charBudget: 30000,
    );
    expect(live.user, contains('[L1] مقتطف من النقاش الجاري'));
    expect(live.user, contains('[#4 00:00:40]'));
    expect(live.pairs['L1'], {'R1', 'T1'});
    final found = parseConsistencyAnswer(
      _answer([
        _f(
          'L1',
          'R1',
          'contradicts_resolution',
          explanation: '[L1] يخالف [R1]',
          evidence: [3, 4],
        ),
        _f('L1', 'R1', 'contradicts_resolution'), // no evidence → dropped
      ]),
      live,
      segmentText: (i) => 'نص $i',
    );
    expect(found.single.newSide.text, 'نص 3 … نص 4');
    expect(found.single.newSide.evidence, [3, 4]);
    expect(found.single.explanation, startsWith('النقاش الجاري'));
  });
}
