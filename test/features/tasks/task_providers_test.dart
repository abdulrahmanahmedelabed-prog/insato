import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';
import 'package:insato/features/tasks/task_logic.dart';
import 'package:insato/features/tasks/task_providers.dart';

import '../../session/fakes.dart';

/// Reads [provider] once its async sources have delivered.
Future<T> settled<T>(
  ProviderContainer c,
  ProviderListenable<T> provider,
) async {
  final sub = c.listen(provider, (_, _) {});
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  final v = sub.read();
  sub.close();
  return v;
}

void main() {
  late AppDatabase db;
  late ProviderContainer c;
  late TaskRepository tasks;
  late PendingTaskUpdateRepository pending;
  late MeetingRepository meetings;
  late TaskActions actions;

  setUp(() {
    db = memoryDb();
    c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    tasks = TaskRepository(db);
    pending = PendingTaskUpdateRepository(db);
    meetings = MeetingRepository(db);
    actions = c.read(taskActionsProvider);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  group('TaskActions', () {
    test('save without edits does not touch the task', () async {
      final speakers = SpeakerRepository(db);
      final sara = await speakers.create(name: 'سارة أحمد');
      final created = DateTime(2026, 11, 1);
      final t = await tasks.create(
        task: 'مراجعة العقد',
        ownerSpeakerId: sara.id,
        ownerText: 'سارة',
        createdAt: created,
      );
      final byId = {sara.id: sara};
      final untouched = TaskDraft.of(t, byId).normalized(byId);
      expect(await actions.save(t, untouched, speakersById: byId), isTrue);
      expect((await tasks.get(t.id))!.updatedAt, created);

      final edited = TaskDraft(
        task: 'مراجعة العقد النهائي',
        ownerText: untouched.ownerText,
        ownerSpeakerId: untouched.ownerSpeakerId,
        dueText: 'الأحد',
      ).normalized(byId);
      expect(await actions.save(t, edited, speakersById: byId), isTrue);
      final saved = (await tasks.get(t.id))!;
      expect(saved.task, 'مراجعة العقد النهائي');
      expect(saved.dueText, 'الأحد');
      expect(saved.ownerSpeakerId, sara.id);
      expect(saved.updatedAt.isAfter(created), isTrue);
    });

    test('invalid drafts are rejected', () async {
      expect(
        () => actions.create(const TaskDraft(task: '')),
        throwsArgumentError,
      );
    });

    test('create, set status and delete', () async {
      final t = await actions.create(
        const TaskDraft(task: 'حجز القاعة', ownerText: 'خالد'),
      );
      expect(t.sourceMeetingId, isNull);
      expect(await actions.setStatus(t, TaskStatus.done), isTrue);
      expect((await tasks.get(t.id))!.status, TaskStatus.done);
      // Same status: no write.
      expect(await actions.setStatus(t, TaskStatus.open), isTrue);
      expect(await actions.delete(t), isTrue);
      expect(await tasks.get(t.id), isNull);
      expect(await actions.setStatus(t, TaskStatus.done), isFalse);
    });

    test('resolve: apply, reject, acknowledge, gone', () async {
      final m1 = await meetings.create(title: 'الأول');
      final m2 = await meetings.create(title: 'الثاني');
      final a = await tasks.create(task: 'أ', sourceMeetingId: m1.id);
      final b = await tasks.create(task: 'ب', sourceMeetingId: m1.id);
      final ups = await pending.replaceForMeeting(m2.id, [
        MinutesTaskUpdate(taskId: a.id, newStatus: TaskStatus.done),
        MinutesTaskUpdate(taskId: b.id, newStatus: TaskStatus.cancelled),
        MinutesTaskUpdate(
          taskId: b.id,
          newStatus: TaskStatus.open,
          note: 'بدأ العمل',
        ),
      ]);
      final views = pendingUpdateViews(
        ups,
        tasksById: {a.id: a, b.id: b},
        meetingsById: {},
      );
      expect(views.map((v) => v.kind), [
        PendingUpdateKind.apply,
        PendingUpdateKind.apply,
        PendingUpdateKind.acknowledge,
      ]);

      expect(
        await actions.resolve(views[0], accept: true),
        PendingResolution.applied,
      );
      expect((await tasks.get(a.id))!.status, TaskStatus.done);

      expect(
        await actions.resolve(views[1], accept: false),
        PendingResolution.dismissed,
      );
      expect((await tasks.get(b.id))!.status, TaskStatus.open);

      // Acknowledging a progress note never changes the status.
      expect(
        await actions.resolve(views[2], accept: true),
        PendingResolution.dismissed,
      );
      expect((await tasks.get(b.id))!.status, TaskStatus.open);
      expect(await pending.getAll(), isEmpty);

      expect(
        await actions.resolve(views[0], accept: true),
        PendingResolution.gone,
      );
    });

    test('applyAll: newest update of a task wins', () async {
      final m1 = await meetings.create(title: 'الأول');
      final m2 = await meetings.create(title: 'الثاني');
      final m3 = await meetings.create(title: 'الثالث');
      final a = await tasks.create(task: 'أ', sourceMeetingId: m1.id);
      final b = await tasks.create(task: 'ب', sourceMeetingId: m1.id);
      await pending.replaceForMeeting(m2.id, [
        MinutesTaskUpdate(taskId: a.id, newStatus: TaskStatus.cancelled),
        MinutesTaskUpdate(taskId: b.id, newStatus: TaskStatus.done),
      ], now: DateTime(2026, 11, 2));
      await pending.replaceForMeeting(m3.id, [
        MinutesTaskUpdate(taskId: a.id, newStatus: TaskStatus.done),
      ], now: DateTime(2026, 11, 3));
      final views = pendingUpdateViews(
        await pending.getAll(),
        tasksById: {a.id: a, b.id: b},
        meetingsById: {},
      );
      expect(await actions.applyAll(views), 2);
      expect((await tasks.get(a.id))!.status, TaskStatus.done);
      expect((await tasks.get(b.id))!.status, TaskStatus.done);
      expect(await pending.getAll(), isEmpty);
    });
  });

  group('providers', () {
    test('tasksViewProvider follows the filter', () async {
      final m = await meetings.create(title: 'اجتماع الميزانية');
      await tasks.create(task: 'أ', sourceMeetingId: m.id, ownerText: 'سارة');
      final done = await tasks.create(task: 'ب', ownerText: 'خالد');
      await tasks.setStatus(done.id, TaskStatus.done);

      var view = (await settled(c, tasksViewProvider)).value!;
      expect(view.all, hasLength(2));
      expect(view.shown.map((t) => t.task), ['أ']);
      expect(view.statusCounts[TaskStatus.done], 1);
      expect(view.totalMatching, 2);
      expect(view.meetings.first.title, 'اجتماع الميزانية');

      c
          .read(taskFilterProvider.notifier)
          .set(const TaskFilter(status: null, meetingKey: kNoMeetingKey));
      view = (await settled(c, tasksViewProvider)).value!;
      expect(view.shown.map((t) => t.task), ['ب']);

      c.read(taskFilterProvider.notifier).reset();
      expect(c.read(taskFilterProvider), const TaskFilter());
    });

    test('pending views and the open-tasks banner', () async {
      final old = await meetings.create(title: 'السابق');
      final current = await meetings.create(
        title: 'الحالي',
        context: const MeetingContext(expectedAttendees: ['م. سارة', 'ليلى']),
      );
      final a = await tasks.create(
        task: 'إعداد التقرير',
        ownerText: 'سارة أحمد',
        sourceMeetingId: old.id,
      );
      await tasks.create(
        task: 'مهمة من الاجتماع الحالي',
        ownerText: 'سارة',
        sourceMeetingId: current.id,
      );
      await pending.replaceForMeeting(current.id, [
        MinutesTaskUpdate(taskId: a.id, newStatus: TaskStatus.done),
      ]);

      final all = await settled(c, pendingUpdateViewsProvider);
      expect(all.single.task?.id, a.id);
      expect(all.single.meetingTitle, 'الحالي');
      expect(
        await settled(c, meetingPendingUpdateViewsProvider(current.id)),
        hasLength(1),
      );
      expect(
        await settled(c, meetingPendingUpdateViewsProvider(old.id)),
        isEmpty,
      );

      final groups = await settled(
        c,
        meetingAttendeeOpenTasksProvider(current.id),
      );
      expect(groups.single.attendee, 'م. سارة');
      expect(groups.single.tasks.single.id, a.id);
      expect(
        await settled(c, meetingAttendeeOpenTasksProvider(old.id)),
        isEmpty,
      );

      final hidden = c.read(hiddenTaskBannersProvider.notifier);
      expect(hidden.isHidden(current.id), isFalse);
      hidden.hide(current.id);
      expect(c.read(hiddenTaskBannersProvider), {current.id});
    });
  });
}
