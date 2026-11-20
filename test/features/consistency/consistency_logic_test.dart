// Institutional memory, retrieval and the pure-Dart heuristics of the
// consistency checker (v1.2, D).

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/consistency/consistency_logic.dart';
import 'package:insato/features/consistency/consistency_models.dart';
import 'package:insato/features/official/official_models.dart';
import 'package:insato/features/official/official_templates.dart';

import 'fixtures.dart';

void main() {
  final jan = DateTime(2026, 1, 10);
  final mar = DateTime(2026, 3, 10);
  final jun = DateTime(2026, 6, 16, 10);
  final dec = DateTime(2026, 12, 1);

  group('text rules', () {
    test('negation / cancellation is detected', () {
      expect(expressesNegation('إلغاء عقد الصيانة'), isTrue);
      expect(expressesNegation('تأجيل افتتاح الفرع'), isTrue);
      expect(expressesNegation('عدم تجديد العقد'), isTrue);
      expect(expressesNegation('وإيقاف المشروع'), isTrue);
      expect(expressesNegation('بالإلغاء'), isTrue);
      expect(expressesNegation('Cancel the contract'), isTrue);
      expect(expressesNegation('اعتماد عقد الصيانة'), isFalse);
      expect(expressesNegation('الغرفة الجديدة'), isFalse);
    });

    test('numbers are read with Arabic-Indic digits', () {
      expect(numbersIn('بمبلغ ٥٠٠٠٠ ريال و 3.5٪'), {'50000', '3.5'});
    });

    test('decision relations', () {
      expect(
        relateDecisions(
          'إلغاء عقد الصيانة مع شركة النور',
          'اعتماد عقد الصيانة مع شركة النور',
        ),
        DecisionRelation.opposite,
      );
      expect(
        relateDecisions(
          'اعتماد ميزانية التدريب بمبلغ 70000 ريال',
          'اعتماد ميزانية التدريب بمبلغ 50000 ريال',
        ),
        DecisionRelation.numbersChanged,
      );
      expect(
        relateDecisions('اعتمادُ خطةِ التسويق', 'اعتماد خطة التسويق.'),
        DecisionRelation.same,
      );
      expect(
        relateDecisions('اعتماد خطة التسويق', 'إلغاء رحلة الموظفين'),
        DecisionRelation.none,
      );
      // Same polarity, no numbers: not decidable without an engine.
      expect(
        relateDecisions(
          'اعتماد عقد الصيانة مع شركة النور',
          'تمديد عقد الصيانة مع شركة النور',
        ),
        DecisionRelation.none,
      );
    });
  });

  group('memory', () {
    final m1 = meetingWith(
      'm1',
      jan,
      title: 'مجلس يناير',
      template: 'board',
      minutes: minutesWith(
        decisions: [
          'اعتماد عقد الصيانة مع شركة النور',
          'تعيين مدير جديد للمشتريات',
        ],
        decisionEvidence: [
          [4],
          [6],
        ],
      ),
    );
    final m2 = meetingWith(
      'm2',
      mar,
      title: 'لجنة مارس',
      minutes: minutesWith(decisions: ['اعتماد عقد الصيانة مع شركة النور']),
    );
    final later = meetingWith(
      'm9',
      dec,
      minutes: minutesWith(decisions: ['اعتماد عقد الصيانة مع شركة النور']),
    );
    final current = meetingWith(
      'cur',
      jun,
      title: 'مجلس يونيو',
      template: 'board',
      minutes: minutesWith(
        decisions: ['إلغاء عقد الصيانة مع شركة النور'],
        actions: [('إعداد تقرير الميزانية', 'خالد', 'الأحد')],
      ),
    );
    const approved = OfficialRecord(
      meetingId: 'm1',
      status: OfficialStatus.approved,
      meetingNumber: 12,
      numberYear: 1448,
    );

    InstitutionalMemory memory({Set<String> superseded = const {}}) =>
        buildInstitutionalMemory(
          current: current,
          meetings: [
            MemoryMeeting(
              meeting: m1,
              record: approved,
              template: OfficialTemplates.board,
              supersededKeys: superseded,
            ),
            MemoryMeeting(meeting: m2),
            MemoryMeeting(meeting: later),
            MemoryMeeting(meeting: current),
          ],
          tasks: [
            taskWith(
              1,
              'إعداد تقرير الميزانية',
              owner: 'سارة',
              due: 'الخميس',
              source: 'm1',
            ),
            taskWith(2, 'حجز القاعة', status: TaskStatus.done, source: 'm2'),
            taskWith(3, 'مهمة من الاجتماع الحالي', source: 'cur'),
            taskWith(4, 'مهمة من اجتماع لاحق', source: 'm9'),
            taskWith(5, 'مهمة يدوية قديمة', at: jan),
            taskWith(6, 'مهمة يدوية لاحقة', at: dec),
          ],
        );

    test('indexes earlier decisions and tasks only, with weights', () {
      final mem = memory();
      final decisions = mem.items.where((i) => i.isDecision).toList();
      expect(decisions.map((d) => d.side.meetingId), ['m1', 'm1', 'm2']);
      final resolution = decisions.first;
      expect(resolution.side.kind, SideKind.resolution);
      expect(resolution.side.label, 'قرار رقم (1/12/1448)');
      expect(resolution.side.meetingNumber, '12/1448هـ');
      expect(resolution.side.evidence, [4]);
      expect(resolution.weight, kResolutionMemoryWeight);
      expect(decisions.last.side.kind, SideKind.decision);
      expect(decisions.last.weight, kDecisionMemoryWeight);
      expect(decisions.last.side.label, 'القرار 1');

      final tasks = mem.items.where((i) => !i.isDecision).toList();
      expect(tasks.map((t) => t.side.taskId), [1, 2, 5]);
      expect(tasks[0].side.meetingTitle, 'مجلس يناير');
      expect(tasks[0].side.meetingNumber, '12/1448هـ');
      expect(tasks[1].closed, isTrue);
      expect(tasks[1].weight, kClosedTaskMemoryWeight);
      expect(tasks[2].side.meetingId, isNull);
      expect(tasks[2].side.evidence, isEmpty);
    });

    test('superseded resolutions are left out', () {
      final mem = memory(superseded: {'اعتماد عقد الصيانة مع شركة النور'});
      expect(
        mem.items.where((i) => i.side.meetingId == 'm1' && i.isDecision),
        hasLength(1),
      );
    });

    test('retrieval ranks the approved resolution first', () {
      final items = newItemsOf(current, template: OfficialTemplates.board);
      expect(items.map((i) => i.ref), ['D1', 'A1']);
      final c = retrieveCandidates(memory(), items);
      expect(c['D1']!.first.side.meetingId, 'm1');
      expect(c['D1']!.map((i) => i.side.meetingId), contains('m2'));
      expect(c['D1']!.every((i) => i.isDecision), isTrue);
      expect(c['A1']!.single.side.taskId, 1);
    });

    test('heuristics: contradiction with severity by approval', () {
      final items = newItemsOf(current, template: OfficialTemplates.board);
      final found = heuristicFindings(
        meetingId: 'cur',
        items: items,
        candidates: retrieveCandidates(memory(), items),
      );
      final contradictions = found
          .where((f) => f.kind == FindingKind.contradictsResolution)
          .toList();
      expect(contradictions, hasLength(2));
      expect(contradictions.first.severity, FindingSeverity.high);
      expect(contradictions.first.priorSide.label, 'قرار رقم (1/12/1448)');
      expect(contradictions.first.explanation, contains('مجلس يناير'));
      expect(contradictions.last.severity, FindingSeverity.medium);
      // The task got another owner and deadline: two findings.
      expect(
        found.map((f) => f.kind),
        containsAll([FindingKind.changesOwner, FindingKind.changesDeadline]),
      );
    });
  });

  group('task heuristics', () {
    final cur = meetingWith(
      'cur',
      jun,
      minutes: minutesWith(
        actions: [
          ('إرسال التقرير المالي', 'سارة', 'الخميس'),
          ('حجز قاعة الاجتماعات', null, null),
          ('تحديث موقع الجهة', 'منى', 'الأحد'),
          ('تحديث موقع الجهة', 'خالد', 'الأحد'),
        ],
      ),
    );
    InstitutionalMemory mem() => buildInstitutionalMemory(
      current: cur,
      meetings: const [],
      tasks: [
        taskWith(1, 'ارسال التقرير المالي', owner: 'م. سارة', due: 'الخميس'),
        taskWith(2, 'حجز قاعة الاجتماعات', status: TaskStatus.cancelled),
      ],
    );

    test('duplicate, closed and internal conflicts', () {
      final items = newItemsOf(cur);
      final found = heuristicFindings(
        meetingId: 'cur',
        items: items,
        candidates: retrieveCandidates(mem(), items),
      );
      final byKind = {for (final f in found) f.kind: f};
      expect(byKind[FindingKind.duplicatesTask]!.priorSide.taskId, 1);
      expect(byKind[FindingKind.duplicatesTask]!.severity, FindingSeverity.low);
      final closed = byKind[FindingKind.revisitsClosedTopic]!;
      expect(closed.priorSide.taskId, 2);
      expect(closed.explanation, contains('أُلغيت'));
      final internal = byKind[FindingKind.internalConflict]!;
      expect(internal.newSide.owner, 'خالد');
      expect(internal.priorSide.owner, 'منى');
      expect(internal.explanation, contains('منى'));
      expect(found.any((f) => f.kind == FindingKind.changesOwner), isFalse);
    });
  });

  test('internal conflict between two decisions of the same meeting', () {
    final cur = meetingWith(
      'cur',
      jun,
      minutes: minutesWith(
        decisions: [
          'اعتماد ميزانية التدريب بمبلغ 50000 ريال',
          'اعتماد ميزانية التدريب بمبلغ 80000 ريال',
        ],
      ),
    );
    final found = heuristicFindings(
      meetingId: 'cur',
      items: newItemsOf(cur),
      candidates: const {},
    );
    expect(found.single.kind, FindingKind.internalConflict);
    expect(found.single.newSide.itemIndex, 1);
    expect(found.single.priorSide.itemIndex, 0);
  });

  test('keys, pair keys, merge and dedupe', () {
    const a = FindingSide(
      kind: SideKind.decision,
      text: 'أ',
      meetingId: 'cur',
      itemKey: 'أ',
    );
    const b = FindingSide(kind: SideKind.task, text: 'ب', taskId: 7);
    const h = ConsistencyFinding(
      meetingId: 'cur',
      kind: FindingKind.duplicatesTask,
      severity: FindingSeverity.low,
      newSide: a,
      priorSide: b,
    );
    const e = ConsistencyFinding(
      meetingId: 'cur',
      kind: FindingKind.changesOwner,
      severity: FindingSeverity.high,
      newSide: a,
      priorSide: b,
      origin: FindingOrigin.engine,
    );
    expect(h.key, 'duplicates_task|cur:d:أ|task:7');
    expect(pairKeyOf(a, b), pairKeyOf(b, a));
    // The heuristic wins for the same pair.
    expect(mergeFindings([h], [e]), [h]);
    expect(dedupeFindings([e, h]).first.severity, FindingSeverity.high);
  });

  test('sides and findings round-trip through JSON', () {
    final side = FindingSide(
      kind: SideKind.resolution,
      text: 'قرر المجلس اعتماد الخطة',
      meetingId: 'm1',
      meetingTitle: 'مجلس',
      meetingDate: DateTime.utc(2026, 6, 16, 7),
      meetingNumber: '12/1448هـ',
      itemIndex: 2,
      itemKey: 'اعتماد الخطة',
      label: 'قرار رقم (3/12/1448)',
      owner: 'سارة',
      due: 'الأحد',
      taskId: 4,
      taskStatus: 'done',
      evidence: const [1, 2],
    );
    final back = FindingSide.decode(side.encode());
    expect(back.toJson(), side.toJson());
    expect(back.trackedStatus, TaskStatus.done);
    expect(FindingSide.decode('{oops').text, '');
    expect(
      FindingKind.tryParse('changes_deadline'),
      FindingKind.changesDeadline,
    );
    expect(FindingKind.tryParse('x'), isNull);
    expect(FindingSeverity.parse('x'), FindingSeverity.medium);
    expect(FindingStatus.parse('dismissed'), FindingStatus.dismissed);
  });
}
