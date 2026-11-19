import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/tasks/strings.dart';
import 'package:insato/features/tasks/task_logic.dart';

final DateTime t0 = DateTime(2026, 11, 1, 9);

TrackedTask task(
  int id,
  String text, {
  TaskStatus status = TaskStatus.open,
  String? ownerText,
  String? ownerSpeakerId,
  String? due,
  String? meeting,
  DateTime? createdAt,
}) => TrackedTask(
  id: id,
  task: text,
  status: status,
  ownerText: ownerText,
  ownerSpeakerId: ownerSpeakerId,
  dueText: due,
  sourceMeetingId: meeting,
  createdAt: createdAt ?? t0.add(Duration(minutes: id)),
  updatedAt: createdAt ?? t0.add(Duration(minutes: id)),
);

Speaker speaker(String id, String name, {bool named = true}) => Speaker(
  id: id,
  name: name,
  colorValue: 0,
  isNamedByUser: named,
  createdAt: t0,
);

Meeting meeting(String id, String title, DateTime at) =>
    Meeting(id: id, title: title, createdAt: at, status: MeetingStatus.ready);

PendingTaskUpdate pending(
  int id,
  int taskId,
  TaskStatus s, {
  String meetingId = 'm2',
  DateTime? at,
}) => PendingTaskUpdate(
  id: id,
  taskId: taskId,
  meetingId: meetingId,
  newStatus: s,
  createdAt: at ?? t0,
);

void main() {
  final sara = speaker('s1', 'سارة أحمد');
  final auto = speaker('s2', 'متحدث 2', named: false);
  final speakers = {sara.id: sara, auto.id: auto};
  final m1 = meeting('m1', 'اجتماع الميزانية', DateTime(2026, 11, 10));
  final m2 = meeting('m2', 'اجتماع التسويق', DateTime(2026, 11, 15));
  final meetings = {m1.id: m1, m2.id: m2};

  group('owners', () {
    test('label prefers the linked speaker, then free text', () {
      expect(
        taskOwnerLabel(
          task(1, 'x', ownerSpeakerId: 's1', ownerText: 'سارة'),
          speakers,
        ),
        'سارة أحمد',
      );
      expect(
        taskOwnerLabel(
          task(1, 'x', ownerSpeakerId: 'gone', ownerText: '  خالد   علي '),
          speakers,
        ),
        'خالد علي',
      );
      expect(taskOwnerLabel(task(1, 'x', ownerText: '   '), speakers), isNull);
      expect(taskOwnerLabel(task(1, 'x'), speakers), isNull);
    });

    test('key unifies spellings and free text with linked speakers', () {
      final a = task(1, 'a', ownerSpeakerId: 's1');
      final b = task(2, 'b', ownerText: 'سارة احمد');
      expect(taskOwnerKey(a, speakers), taskOwnerKey(b, speakers));
      expect(taskOwnerKey(task(3, 'c'), speakers), kNoOwnerKey);
    });

    test('options: most tasks first, no-owner last', () {
      final opts = taskOwnerOptions([
        task(1, 'a', ownerText: 'خالد'),
        task(2, 'b', ownerSpeakerId: 's1'),
        task(3, 'c', ownerText: 'سارة أحمد'),
        task(4, 'd'),
        task(5, 'e'),
        task(6, 'f'),
      ], speakers);
      expect(opts.map((o) => o.count), [2, 1, 3]);
      expect(opts.first.label, 'سارة أحمد');
      expect(opts.last.key, kNoOwnerKey);
      expect(opts.last.label, isNull);
    });
  });

  group('meetings', () {
    test('options: newest meeting first, unknown / manual last', () {
      final opts = taskMeetingOptions([
        task(1, 'a', meeting: 'm1'),
        task(2, 'b', meeting: 'm2'),
        task(3, 'c', meeting: 'deleted'),
        task(4, 'd'),
      ], meetings);
      expect(opts.map((o) => o.key), ['m2', 'm1', kNoMeetingKey]);
      expect(opts.last.count, 2);
      expect(opts.first.title, 'اجتماع التسويق');
    });
  });

  group('filtering', () {
    final tasks = [
      task(1, 'إعداد الميزانية', ownerText: 'خالد', meeting: 'm1'),
      task(2, 'حجز القاعة', status: TaskStatus.done, meeting: 'm1'),
      task(
        3,
        'مراجعة العقد',
        ownerSpeakerId: 's1',
        meeting: 'm2',
        due: 'الخميس',
      ),
      task(4, 'إرسال الدعوات', status: TaskStatus.cancelled),
    ];

    List<int> ids(TaskFilter f) => filterTasks(
      tasks,
      f,
      speakersById: speakers,
      meetingsById: meetings,
    ).map((t) => t.id).toList();

    test('default shows open tasks, newest first', () {
      expect(ids(const TaskFilter()), [3, 1]);
      expect(const TaskFilter().isDefault, isTrue);
    });

    test('all statuses sort open, done, cancelled', () {
      expect(ids(TaskFilter.none), [3, 1, 2, 4]);
    });

    test('owner, meeting and search filters', () {
      final sKey = taskOwnerKey(tasks[2], speakers);
      expect(ids(TaskFilter(ownerKey: sKey)), [3]);
      expect(ids(const TaskFilter(status: null, meetingKey: 'm1')), [1, 2]);
      expect(ids(const TaskFilter(status: null, meetingKey: kNoMeetingKey)), [
        4,
      ]);
      expect(ids(const TaskFilter(ownerKey: kNoOwnerKey)), isEmpty);
      // Search matches the task, the owner and the due text, normalised.
      expect(ids(const TaskFilter(query: 'الميزانيه')), [1]);
      expect(ids(const TaskFilter(query: 'سارة')), [3]);
      expect(ids(const TaskFilter(query: 'الخميس العقد')), [3]);
      expect(ids(const TaskFilter(query: 'غير موجود')), isEmpty);
    });

    test('status counts ignore only the status filter', () {
      final c = taskStatusCounts(
        tasks,
        const TaskFilter(meetingKey: 'm1'),
        speakersById: speakers,
        meetingsById: meetings,
      );
      expect(c, {
        TaskStatus.open: 1,
        TaskStatus.done: 1,
        TaskStatus.cancelled: 0,
      });
    });

    test('copyWith clears and keeps fields', () {
      const f = TaskFilter(ownerKey: 'o', meetingKey: 'm', query: 'q');
      expect(f.copyWith(allStatuses: true).status, isNull);
      expect(f.copyWith(clearOwner: true).ownerKey, isNull);
      expect(f.copyWith(clearMeeting: true).meetingKey, isNull);
      expect(f.copyWith(status: TaskStatus.done).ownerKey, 'o');
      expect(f.isDefault, isFalse);
      expect(f, const TaskFilter(ownerKey: 'o', meetingKey: 'm', query: 'q'));
    });
  });

  group('drafts', () {
    test('normalised: trimmed, blanks become null, owner linked', () {
      final d = const TaskDraft(
        task: '  إعداد   التقرير ',
        ownerText: ' سارة  أحمد ',
        dueText: '   ',
      ).normalized(speakers);
      expect(d.task, 'إعداد التقرير');
      expect(d.ownerText, 'سارة أحمد');
      expect(d.ownerSpeakerId, 's1');
      expect(d.dueText, isNull);
    });

    test('renamed owner drops the speaker link', () {
      final d = const TaskDraft(
        task: 'x',
        ownerText: 'خالد',
        ownerSpeakerId: 's1',
      ).normalized(speakers);
      expect(d.ownerSpeakerId, isNull);
      expect(d.ownerText, 'خالد');
    });

    test('auto-named speakers are linked only explicitly', () {
      expect(resolveTaskOwner('متحدث 2', null, speakers), isNull);
      expect(resolveTaskOwner('متحدث 2', 's2', speakers), 's2');
      expect(resolveTaskOwner(null, 's1', speakers), isNull);
    });

    test('ambiguous names are not linked', () {
      final twins = {'a': speaker('a', 'منى'), 'b': speaker('b', 'منى')};
      expect(resolveTaskOwner('منى', null, twins), isNull);
      expect(resolveTaskOwner('منى', 'b', twins), 'b');
    });

    test('validation', () {
      expect(
        validateTaskDraft(const TaskDraft(task: '')),
        TaskDraftError.taskEmpty,
      );
      expect(
        validateTaskDraft(TaskDraft(task: 'x' * (kMaxTaskLength + 1))),
        TaskDraftError.taskTooLong,
      );
      expect(
        validateTaskDraft(
          TaskDraft(task: 'x', ownerText: 'x' * (kMaxTaskOwnerLength + 1)),
        ),
        TaskDraftError.ownerTooLong,
      );
      expect(
        validateTaskDraft(
          TaskDraft(task: 'x', dueText: 'x' * (kMaxTaskDueLength + 1)),
        ),
        TaskDraftError.dueTooLong,
      );
      expect(validateTaskDraft(const TaskDraft(task: 'x')), isNull);
    });

    test('of / apply / changes round-trip', () {
      final t = task(
        7,
        'مراجعة العقد',
        ownerSpeakerId: 's1',
        ownerText: 'سارة',
        due: 'غدًا',
        meeting: 'm1',
      );
      final d = TaskDraft.of(t, speakers);
      expect(d.ownerText, 'سارة أحمد');
      // The owner field shows the speaker's newer name: a raw comparison
      // sees a change, but saving the untouched dialog is not an edit.
      expect(taskDraftChanges(t, d.normalized(speakers)), isTrue);
      expect(taskEditChanges(t, d.normalized(speakers), speakers), isFalse);
      expect(
        taskEditChanges(
          t,
          TaskDraft(
            task: d.task,
            ownerText: d.ownerText,
            ownerSpeakerId: d.ownerSpeakerId,
            dueText: d.dueText,
            status: TaskStatus.done,
          ).normalized(speakers),
          speakers,
        ),
        isTrue,
      );
      final same = TaskDraft(
        task: t.task,
        ownerText: t.ownerText,
        ownerSpeakerId: t.ownerSpeakerId,
        dueText: t.dueText,
        status: t.status,
      );
      expect(taskDraftChanges(t, same), isFalse);

      final edited = const TaskDraft(
        task: 'مراجعة العقد النهائي',
        status: TaskStatus.done,
      );
      final applied = applyTaskDraft(t, edited);
      expect(applied.task, 'مراجعة العقد النهائي');
      expect(applied.ownerSpeakerId, isNull);
      expect(applied.ownerText, isNull);
      expect(applied.dueText, isNull);
      expect(applied.status, TaskStatus.done);
      expect(applied.sourceMeetingId, 'm1');
      expect(applied.id, 7);
    });
  });

  group('pending updates', () {
    test('classification', () {
      final open = task(1, 'a');
      final done = task(2, 'b', status: TaskStatus.done);
      expect(
        classifyPendingUpdate(pending(1, 1, TaskStatus.done), open),
        PendingUpdateKind.apply,
      );
      expect(
        classifyPendingUpdate(pending(1, 1, TaskStatus.open), open),
        PendingUpdateKind.acknowledge,
      );
      expect(
        classifyPendingUpdate(pending(1, 2, TaskStatus.done), done),
        PendingUpdateKind.alreadyApplied,
      );
      // A progress note never re-opens a closed task.
      expect(
        classifyPendingUpdate(pending(1, 2, TaskStatus.open), done),
        PendingUpdateKind.alreadyApplied,
      );
      expect(
        classifyPendingUpdate(pending(1, 2, TaskStatus.cancelled), done),
        PendingUpdateKind.apply,
      );
      expect(
        classifyPendingUpdate(pending(1, 9, TaskStatus.done), null),
        PendingUpdateKind.taskGone,
      );
    });

    test('views are ordered and carry the meeting title', () {
      final views = pendingUpdateViews(
        [
          pending(3, 1, TaskStatus.done, at: t0.add(const Duration(hours: 1))),
          pending(2, 1, TaskStatus.open, meetingId: 'x'),
          pending(1, 1, TaskStatus.done),
        ],
        tasksById: {1: task(1, 'a')},
        meetingsById: meetings,
      );
      expect(views.map((v) => v.update.id), [1, 2, 3]);
      expect(views.first.meetingTitle, 'اجتماع التسويق');
      expect(views[1].meetingTitle, isNull);
      expect(views.first.changesStatus, isTrue);
      expect(views[1].changesStatus, isFalse);
    });
  });

  group('attendees', () {
    test('name tokens drop honorifics and join «عبد X»', () {
      expect(personNameTokens('د. عبد الله  محمد'), ['عبدالله', 'محمد']);
      expect(personNameTokens('Eng. John Smith'), ['john', 'smith']);
      expect(personNameTokens('الأستاذة سارة'), ['ساره']);
      expect(personNameTokens('  '), isEmpty);
    });

    test('names match on a token subset', () {
      expect(personNamesMatch('سارة', 'م. سارة أحمد'), isTrue);
      expect(personNamesMatch('سارة أحمد', 'سارة'), isTrue);
      expect(personNamesMatch('سارة خالد', 'سارة أحمد'), isFalse);
      expect(personNamesMatch('د.', 'سارة'), isFalse);
    });

    test('open tasks grouped by attendee, exact match preferred', () {
      final tasks = [
        task(1, 'a', ownerText: 'سارة', meeting: 'm1'),
        task(2, 'b', ownerSpeakerId: 's1', meeting: 'm1'),
        task(3, 'c', ownerText: 'سارة', status: TaskStatus.done),
        task(4, 'd', ownerText: 'خالد', meeting: 'current'),
        task(5, 'e', ownerText: 'منى'),
        task(6, 'f'),
      ];
      final groups = openTasksForAttendees(
        ['م. سارة أحمد', 'سارة', '  ', 'خالد', 'سارة'],
        tasks,
        speakers,
        excludeMeetingId: 'current',
      );
      expect(groups.map((g) => g.attendee), ['م. سارة أحمد', 'سارة']);
      // «سارة أحمد» (linked) goes to the exact match, «سارة» to its own.
      expect(groups[0].tasks.map((t) => t.id), [2]);
      expect(groups[1].tasks.map((t) => t.id), [1]);
    });

    test('no attendees or no matches give nothing', () {
      expect(
        openTasksForAttendees([], [task(1, 'a', ownerText: 'x')], {}),
        isEmpty,
      );
      expect(
        openTasksForAttendees(['ليلى'], [task(1, 'a', ownerText: 'سارة')], {}),
        isEmpty,
      );
    });
  });

  group('strings', () {
    test('Arabic counts', () {
      expect(TS.shownCount(1), 'مهمة واحدة');
      expect(TS.shownCount(2), 'مهمتان');
      expect(TS.shownCount(5), '5 مهام');
      expect(TS.shownCount(11), '11 مهمة');
      expect(TS.evidenceCount(2), 'مستندة إلى مقطعين');
      expect(TS.status(TaskStatus.cancelled), 'ملغاة');
    });
  });
}
