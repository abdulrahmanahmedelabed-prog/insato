import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';
import 'package:insato/features/tasks/tasks.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';

Finder field(String label) => find.widgetWithText(TextField, label);

Finder menuItem(String text) =>
    find.widgetWithText(CheckedPopupMenuItem<String>, text);

void main() {
  group('TasksScreen', () {
    testWidgets('empty state, add a task, mark it done and undo', (t) async {
      setScreenSize(t, const Size(500, 1400));
      final env = UiTestEnv();
      await pumpScreen(t, env, const TasksScreen());
      expect(find.text(TS.emptyTitle), findsOneWidget);

      await t.tap(find.text(TS.addTask));
      await settle(t);
      // Blank task is rejected inline.
      await t.tap(find.text(S.save));
      await t.pump();
      expect(find.text(TS.taskEmpty), findsOneWidget);
      await t.enterText(field(TS.taskLabel), '  إعداد   الميزانية ');
      await t.enterText(field(TS.ownerLabel), 'خالد');
      await t.enterText(field(TS.dueLabel), 'الخميس');
      await t.tap(find.text(S.save));
      await settle(t, rounds: 10);

      final repo = TaskRepository(env.db);
      var all = await env.run(t, repo.getAll);
      expect(all.single.task, 'إعداد الميزانية');
      expect(all.single.ownerText, 'خالد');
      expect(all.single.dueText, 'الخميس');
      expect(find.text('إعداد الميزانية'), findsOneWidget);
      expect(find.text(TS.ownerLine('خالد')), findsOneWidget);
      expect(find.text(TS.dueLine('الخميس')), findsOneWidget);
      expect(find.text(TS.shownCount(1)), findsOneWidget);

      await t.tap(find.byTooltip(TS.markDoneSemantics('إعداد الميزانية')));
      await settle(t, rounds: 10);
      all = await env.run(t, repo.getAll);
      expect(all.single.status, TaskStatus.done);
      // Default filter shows open tasks only.
      expect(find.text('إعداد الميزانية'), findsNothing);
      expect(find.text(TS.noMatches), findsOneWidget);
      expect(find.text(TS.markedDone), findsOneWidget);

      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(TS.undo));
      await settle(t, rounds: 10);
      all = await env.run(t, repo.getAll);
      expect(all.single.status, TaskStatus.open);
      expect(find.text('إعداد الميزانية'), findsOneWidget);
      await env.dispose(t);
    });

    testWidgets('filters by status, owner and meeting; edits', (t) async {
      setScreenSize(t, const Size(500, 1600));
      final env = UiTestEnv();
      final repo = TaskRepository(env.db);
      await env.run(t, () async {
        final m = await MeetingRepository(env.db)
            .create(title: 'اجتماع التسويق', status: MeetingStatus.ready);
        await repo.create(
          task: 'مراجعة الحملة',
          ownerText: 'سارة',
          sourceMeetingId: m.id,
          evidenceSegmentIds: const [1, 2],
          createdAt: DateTime(2026, 11, 2),
        );
        await repo.create(
          task: 'حجز القاعة',
          ownerText: 'خالد',
          createdAt: DateTime(2026, 11, 1),
        );
        final done = await repo.create(task: 'إرسال المحضر');
        await repo.setStatus(done.id, TaskStatus.done);
      });
      await pumpScreen(t, env, const TasksScreen());

      expect(find.text('مراجعة الحملة'), findsOneWidget);
      expect(find.text('حجز القاعة'), findsOneWidget);
      expect(find.text('إرسال المحضر'), findsNothing);
      expect(find.text(TS.sourceLine('اجتماع التسويق')), findsOneWidget);
      expect(find.text(TS.evidenceCount(2)), findsOneWidget);
      expect(
        find.text(TS.statusCount(TS.status(TaskStatus.done), 1)),
        findsOneWidget,
      );

      await t.tap(find.text(TS.statusCount(TS.status(TaskStatus.done), 1)));
      await settle(t);
      expect(find.text('إرسال المحضر'), findsOneWidget);
      expect(find.text('حجز القاعة'), findsNothing);

      await t.tap(find.text(TS.statusCount(TS.allStatuses, 3)));
      await settle(t);
      expect(find.text(TS.shownCount(3)), findsOneWidget);

      // Owner filter.
      await t.tap(find.byTooltip(TS.ownerFilter));
      await settle(t);
      await t.tap(menuItem('سارة (1)'));
      await settle(t);
      expect(find.text('مراجعة الحملة'), findsOneWidget);
      expect(find.text('حجز القاعة'), findsNothing);
      await t.tap(find.text(TS.clearFilters));
      await settle(t);

      // Meeting filter: manual tasks.
      await t.tap(find.byTooltip(TS.meetingFilter));
      await settle(t);
      await t.tap(menuItem('${TS.noMeeting} (2)'));
      await settle(t);
      expect(find.text('حجز القاعة'), findsOneWidget);
      expect(find.text('مراجعة الحملة'), findsNothing);

      // Edit via tap.
      await t.tap(find.text('حجز القاعة'));
      await settle(t);
      expect(find.text(TS.editTaskTitle), findsOneWidget);
      await t.enterText(field(TS.taskLabel), 'حجز القاعة الكبرى');
      await t.tap(find.text(TS.status(TaskStatus.cancelled)).last);
      await t.pump();
      await t.tap(find.text(S.save));
      await settle(t, rounds: 10);
      final all = await env.run(t, repo.getAll);
      final edited = all.firstWhere((x) => x.task.startsWith('حجز'));
      expect(edited.task, 'حجز القاعة الكبرى');
      expect(edited.status, TaskStatus.cancelled);
      expect(edited.ownerText, 'خالد');
      await env.dispose(t);
    });

    testWidgets('pending updates: apply and reject', (t) async {
      setScreenSize(t, const Size(500, 1600));
      final env = UiTestEnv();
      final repo = TaskRepository(env.db);
      late int a, b;
      await env.run(t, () async {
        final meetings = MeetingRepository(env.db);
        final m1 = await meetings.create(title: 'الأول');
        final m2 = await meetings.create(title: 'المتابعة');
        a = (await repo.create(
          task: 'إعداد التقرير',
          sourceMeetingId: m1.id,
        )).id;
        b = (await repo.create(
          task: 'تحديث الموقع',
          sourceMeetingId: m1.id,
        )).id;
        await PendingTaskUpdateRepository(env.db).replaceForMeeting(m2.id, [
          MinutesTaskUpdate(
            taskId: a,
            newStatus: TaskStatus.done,
            note: 'أُرسل التقرير أمس',
          ),
          MinutesTaskUpdate(taskId: b, newStatus: TaskStatus.cancelled),
        ]);
      });
      await pumpScreen(t, env, const TasksScreen());
      expect(find.text('${TS.pendingHeader} (2)'), findsOneWidget);
      expect(find.text('«أُرسل التقرير أمس»'), findsOneWidget);
      expect(find.text(TS.proposedIn('المتابعة')), findsNWidgets(2));
      expect(find.text(TS.applyAll(2)), findsOneWidget);

      await t.tap(find.text(TS.apply).first);
      await settle(t, rounds: 10);
      expect((await env.run(t, () => repo.get(a)))!.status, TaskStatus.done);
      expect(find.text(TS.applied), findsOneWidget);

      await t.tap(find.text(TS.reject));
      await settle(t, rounds: 10);
      expect((await env.run(t, () => repo.get(b)))!.status, TaskStatus.open);
      expect(find.textContaining(TS.pendingHeader), findsNothing);
      final left = await env.run(
        t,
        () => PendingTaskUpdateRepository(env.db).getAll(),
      );
      expect(left, isEmpty);
      await env.dispose(t);
    });
  });

  group('MeetingTasksPanel', () {
    testWidgets('lists the meeting tasks and its proposed updates', (t) async {
      setScreenSize(t, const Size(500, 1400));
      final env = UiTestEnv();
      late String meetingId;
      await env.run(t, () async {
        final meetings = MeetingRepository(env.db);
        final old = await meetings.create(title: 'السابق');
        final m = await meetings.create(title: 'الحالي');
        meetingId = m.id;
        final repo = TaskRepository(env.db);
        final prev = await repo.create(
          task: 'مهمة سابقة',
          sourceMeetingId: old.id,
        );
        await repo.create(task: 'مهمة جديدة', sourceMeetingId: m.id);
        await PendingTaskUpdateRepository(env.db).replaceForMeeting(m.id, [
          MinutesTaskUpdate(
            taskId: prev.id,
            newStatus: TaskStatus.open,
            note: 'نصف العمل منجز',
          ),
        ]);
      });
      await pumpScreen(
        t,
        env,
        Scaffold(body: MeetingTasksPanel(meetingId: meetingId)),
      );
      expect(find.text(TS.meetingTasksHeader), findsOneWidget);
      expect(find.text('مهمة جديدة'), findsOneWidget);
      expect(find.text('${TS.meetingUpdatesHeader} (1)'), findsOneWidget);
      expect(find.text(TS.progressOnly), findsOneWidget);
      await t.tap(find.text(TS.acknowledge));
      await settle(t, rounds: 10);
      expect(find.text(TS.progressOnly), findsNothing);

      await t.tap(find.text(TS.openTasksScreen));
      await settle(t);
      expect(find.text(TS.tasksTitle), findsOneWidget);
      await env.dispose(t);
    });

    testWidgets('empty meeting', (t) async {
      final env = UiTestEnv();
      final id = await env.run(
        t,
        () async => (await MeetingRepository(env.db).create(title: 'م')).id,
      );
      await pumpScreen(
        t,
        env,
        Scaffold(body: MeetingTasksPanel(meetingId: id)),
      );
      expect(find.text(TS.meetingTasksEmpty), findsOneWidget);
      await env.dispose(t);
    });
  });

  group('OpenTasksBanner', () {
    testWidgets('shows attendee tasks, expands and hides', (t) async {
      setScreenSize(t, const Size(500, 1200));
      final env = UiTestEnv();
      late String meetingId;
      await env.run(t, () async {
        final meetings = MeetingRepository(env.db);
        final old = await meetings.create(title: 'السابق');
        final m = await meetings.create(
          title: 'الحالي',
          context: const MeetingContext(
            expectedAttendees: ['د. سارة أحمد', 'خالد'],
          ),
        );
        meetingId = m.id;
        final repo = TaskRepository(env.db);
        for (var i = 1; i <= 4; i++) {
          await repo.create(
            task: 'مهمة سارة $i',
            ownerText: 'سارة',
            sourceMeetingId: old.id,
            createdAt: DateTime(2026, 11, i),
          );
        }
        await repo.create(
          task: 'مهمة خالد',
          ownerText: 'خالد',
          dueText: 'الأحد',
        );
        await repo.create(task: 'مهمة ليلى', ownerText: 'ليلى');
      });
      await pumpScreen(
        t,
        env,
        Scaffold(body: OpenTasksBanner(meetingId: meetingId)),
      );
      expect(find.text(TS.bannerTitle(5)), findsOneWidget);
      expect(find.text('د. سارة أحمد، خالد'), findsOneWidget);

      await t.tap(find.byTooltip(TS.showDetails));
      await t.pump();
      expect(find.text('• مهمة سارة 4'), findsOneWidget);
      expect(find.text('• مهمة سارة 1'), findsNothing);
      expect(find.text(TS.moreTasks(1)), findsOneWidget);
      expect(find.text('• مهمة خالد — ${TS.dueLine('الأحد')}'), findsOneWidget);
      expect(find.textContaining('ليلى'), findsNothing);

      await t.tap(find.byTooltip(TS.hideBanner));
      await t.pump();
      expect(find.text(TS.bannerTitle(5)), findsNothing);
      await env.dispose(t);
    });

    testWidgets('nothing without expected attendees', (t) async {
      final env = UiTestEnv();
      final id = await env.run(t, () async {
        final m = await MeetingRepository(env.db).create(title: 'م');
        await TaskRepository(env.db).create(task: 'x', ownerText: 'سارة');
        return m.id;
      });
      await pumpScreen(t, env, Scaffold(body: OpenTasksBanner(meetingId: id)));
      expect(find.byType(Card), findsNothing);
      await env.dispose(t);
    });
  });
}
