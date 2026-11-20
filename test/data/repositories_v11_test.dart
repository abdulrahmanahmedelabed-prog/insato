import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/minutes_artifacts.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';
import 'package:insato/features/codes/reversed_speech_logic.dart';

Minutes minutesWith({
  List<ActionItem> actionItems = const [],
  List<MinutesTaskUpdate> taskUpdates = const [],
  List<MinutesSpeakerNote> speakerNotes = const [],
  MinutesCodes codes = MinutesCodes.empty,
}) => Minutes(
  title: 'ت',
  summary: 'م',
  attendees: const [],
  topics: const [],
  decisions: const [],
  actionItems: actionItems,
  openQuestions: const [],
  languagesDetected: const [],
  generatedAt: DateTime.utc(2026, 11, 19),
  model: 'gemini-flash-latest',
  taskUpdates: taskUpdates,
  speakerNotes: speakerNotes,
  codes: codes,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late MeetingRepository meetings;
  late SpeakerRepository speakers;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    meetings = MeetingRepository(db);
    speakers = SpeakerRepository(db);
  });
  tearDown(() => db.close());

  group('GlossaryRepository', () {
    test('adds, dedupes per scope and merges the effective glossary', () async {
      final repo = GlossaryRepository(db);
      final m = await meetings.create(title: 'm');
      final a = await repo.add(
        term: '  Insato  ',
        arSpelling: 'إنصاتو',
        category: GlossaryCategory.technical,
      );
      expect(a.term, 'Insato');
      expect(a.isGlobal, isTrue);
      // Same term, different case → updated, not duplicated.
      final again = await repo.add(
        term: 'insato',
        category: GlossaryCategory.organisation,
      );
      expect(again.id, a.id);
      expect(again.arSpelling, 'إنصاتو');
      expect(again.category, GlossaryCategory.organisation);
      expect(await repo.getGlobal(), hasLength(1));

      await repo.add(term: 'KPI', meetingId: m.id, arSpelling: 'مؤشر أداء');
      await repo.add(term: 'insato', meetingId: m.id, arSpelling: 'انصاتو');
      expect(await repo.getForMeeting(m.id), hasLength(2));

      final named = await speakers.create(name: 'سارة', isNamedByUser: true);
      await speakers.create(name: 'متحدث 1', isNamedByUser: false);
      final eff = await repo.getEffective(
        m.id,
        speakers: await speakers.getAll(),
      );
      expect(eff.map((t) => t.term), ['insato', 'KPI', 'سارة']);
      expect(eff.first.arSpelling, 'انصاتو'); // meeting term overrides
      expect(eff.last.category, GlossaryCategory.person);
      expect(eff.last.id, 0);
      expect(named.isNamedByUser, isTrue);

      expect(() => repo.add(term: '  '), throwsArgumentError);
      expect(await repo.delete(a.id), isTrue);
      expect(await repo.getGlobal(), isEmpty);

      // Meeting terms go with the meeting.
      await meetings.delete(m.id);
      expect(await repo.getForMeeting(m.id), isEmpty);
    });

    test('update changes fields', () async {
      final repo = GlossaryRepository(db);
      final t = await repo.add(term: 'API');
      expect(
        await repo.update(
          GlossaryTerm(
            id: t.id,
            term: 'API',
            arSpelling: 'واجهة برمجة التطبيقات',
            category: GlossaryCategory.technical,
            createdAt: t.createdAt,
          ),
        ),
        isTrue,
      );
      final g = (await repo.getGlobal()).single;
      expect(g.arSpelling, 'واجهة برمجة التطبيقات');
      expect(g.category, GlossaryCategory.technical);
    });
  });

  group('TaskRepository & pending updates', () {
    test('CRUD, filters and confirm/dismiss', () async {
      final tasks = TaskRepository(db);
      final pending = PendingTaskUpdateRepository(db);
      final m1 = await meetings.create(title: 'm1');
      final m2 = await meetings.create(title: 'm2');
      final sp = await speakers.create(name: 'أحمد', isNamedByUser: true);
      final t0 = DateTime(2026, 1, 1);
      final t = await tasks.create(
        task: ' إرسال التقرير ',
        ownerSpeakerId: sp.id,
        ownerText: 'أحمد',
        dueText: 'الخميس',
        sourceMeetingId: m1.id,
        evidenceSegmentIds: const [5, 2, 2],
        createdAt: t0,
      );
      expect(t.task, 'إرسال التقرير');
      expect(t.evidenceSegmentIds, [2, 5]);
      final loaded = (await tasks.get(t.id))!;
      expect(loaded.ownerSpeakerId, sp.id);
      expect(loaded.dueText, 'الخميس');
      expect(loaded.createdAt, t0);
      expect(await tasks.getOpen(), hasLength(1));
      expect(await tasks.getAll(sourceMeetingId: m2.id), isEmpty);

      final proposed = await pending.replaceForMeeting(
        m2.id,
        const [
              MinutesTaskUpdate(
                taskId: 0 + 1,
                newStatus: TaskStatus.done,
                note: 'أُرسل',
                evidence: [7],
              ),
            ]
            .map(
              (u) => MinutesTaskUpdate(
                taskId: t.id,
                newStatus: u.newStatus,
                note: u.note,
                evidence: u.evidence,
              ),
            )
            .toList(),
      );
      expect(proposed.single.evidenceSegmentIds, [7]);
      expect(await pending.getAll(meetingId: m2.id), hasLength(1));

      final done = await pending.confirm(
        proposed.single.id,
        now: DateTime(2026, 2, 1),
      );
      expect(done!.status, TaskStatus.done);
      expect(done.updatedAt, DateTime(2026, 2, 1));
      expect(await pending.getAll(), isEmpty);
      expect(await pending.confirm(proposed.single.id), isNull);

      final again = await pending.replaceForMeeting(m2.id, [
        MinutesTaskUpdate(taskId: t.id, newStatus: TaskStatus.cancelled),
      ]);
      expect(await pending.dismiss(again.single.id), isTrue);
      expect((await tasks.get(t.id))!.status, TaskStatus.done);

      // Speaker deletion keeps the task, clears the owner link.
      await speakers.delete(sp.id);
      expect((await tasks.get(t.id))!.ownerSpeakerId, isNull);
      // Meeting deletion keeps the task, clears its source.
      await meetings.delete(m1.id);
      expect((await tasks.get(t.id))!.sourceMeetingId, isNull);

      expect(await tasks.setStatus(t.id, TaskStatus.open), isTrue);
      expect(
        await tasks.update((await tasks.get(t.id))!.copyWith(task: 'جديد')),
        isTrue,
      );
      expect((await tasks.get(t.id))!.task, 'جديد');
      expect(await tasks.delete(t.id), isTrue);
      expect(await tasks.get(t.id), isNull);
    });
  });

  group('profiles, notes and code findings', () {
    test('round-trip and cascade', () async {
      final profiles = SpeakerProfileRepository(db);
      final notes = SpeakerMeetingNotesRepository(db);
      final codes = CodeFindingRepository(db);
      final m = await meetings.create(title: 'm');
      final sp = await speakers.create(name: 'سارة', isNamedByUser: true);

      await profiles.upsert(
        SpeakerProfileRecord(
          speakerId: sp.id,
          profile: const {'summary': 'ملخص'},
          evidence: [EvidenceRef(meetingId: m.id, segmentIndex: 3)],
          updatedAt: DateTime(2026, 3, 1),
        ),
      );
      final p = (await profiles.get(sp.id))!;
      expect(p.profile['summary'], 'ملخص');
      expect(p.evidence.single.segmentIndex, 3);

      await notes.replaceForMeeting(m.id, {
        sp.id: const MinutesSpeakerNote(speaker: 'سارة', summary: 'أدارت'),
      });
      expect((await notes.getForSpeaker(sp.id)).single.notes.summary, 'أدارت');
      expect(await notes.getForMeeting(m.id), hasLength(1));

      final stored = await codes.replaceForMeeting(m.id, [
        CodeFinding(
          id: 0,
          meetingId: 'ignored',
          kind: CodeFindingKind.reference,
          speakerId: sp.id,
          segmentIds: const [4, 1],
          payload: const {'verbatim': 'INV-2026-001'},
          createdAt: DateTime(2000),
        ),
      ]);
      expect(stored.single.meetingId, m.id);
      final f = (await codes.getForMeeting(m.id)).single;
      expect(f.kind, CodeFindingKind.reference);
      expect(f.segmentIds, [1, 4]);
      expect(await codes.updatePayload(f.id, {'verbatim': 'X'}), isTrue);
      expect(
        (await codes.getByKind(CodeFindingKind.reference))
            .single
            .payload['verbatim'],
        'X',
      );

      await speakers.delete(sp.id);
      expect(await profiles.get(sp.id), isNull);
      expect(await notes.getForMeeting(m.id), isEmpty);
      expect((await codes.getForMeeting(m.id)).single.speakerId, isNull);
      await meetings.delete(m.id);
      expect(await codes.getForMeeting(m.id), isEmpty);
    });

    test('merging speakers moves v1.1 rows to the survivor', () async {
      final m = await meetings.create(title: 'm');
      final a = await speakers.create(name: 'متحدث 1');
      final b = await speakers.create(name: 'أحمد', isNamedByUser: true);
      final tasks = TaskRepository(db);
      final t = await tasks.create(task: 'x', ownerSpeakerId: a.id);
      await SpeakerMeetingNotesRepository(db).replaceForMeeting(m.id, {
        a.id: const MinutesSpeakerNote(speaker: 'متحدث 1'),
      });
      await speakers.setProfileEnabled(a.id, true);
      final merged = await speakers.merge(a.id, b.id);
      expect(merged.profileEnabled, isTrue);
      expect((await tasks.get(t.id))!.ownerSpeakerId, b.id);
      expect(
        (await SpeakerMeetingNotesRepository(db).getForMeeting(m.id))
            .single
            .speakerId,
        b.id,
      );
    });
  });

  group('minutes artefacts', () {
    test('pure helpers', () {
      final a = Speaker(
        id: 'a',
        name: 'أحمد  علي',
        colorValue: 0,
        isNamedByUser: true,
        createdAt: DateTime(2026),
        profileEnabled: true,
      );
      final b = Speaker(
        id: 'b',
        name: 'متحدث 2',
        colorValue: 0,
        isNamedByUser: false,
        createdAt: DateTime(2026),
      );
      final dup1 = Speaker(
        id: 'd1',
        name: 'سارة',
        colorValue: 0,
        isNamedByUser: true,
        createdAt: DateTime(2026),
      );
      final dup2 = Speaker(
        id: 'd2',
        name: 'سارة',
        colorValue: 0,
        isNamedByUser: true,
        createdAt: DateTime(2026),
      );
      final names = SpeakerNameResolver({
        'a': a,
        'b': b,
        'd1': dup1,
        'd2': dup2,
      });
      expect(names.id('أحمد علي'), 'a');
      expect(names.id('متحدث 2'), 'b');
      expect(names.id('سارة'), isNull, reason: 'ambiguous');
      expect(names.id('غير موجود'), isNull);

      final notes = optedInSpeakerNotes(const [
        MinutesSpeakerNote(speaker: 'أحمد علي'),
        MinutesSpeakerNote(speaker: 'متحدث 2'), // not opted in → dropped
      ], names);
      expect(notes.keys, ['a']);

      expect(
        validTaskUpdates(
          const [
            MinutesTaskUpdate(taskId: 1, newStatus: TaskStatus.done),
            MinutesTaskUpdate(taskId: 1, newStatus: TaskStatus.open),
            MinutesTaskUpdate(taskId: 9, newStatus: TaskStatus.done),
          ],
          {1, 2},
        ).map((u) => (u.taskId, u.newStatus)),
        [(1, TaskStatus.done)],
      );

      final findings = codeFindingsFromMinutes(
        'm',
        const MinutesCodes(
          jargon: [
            JargonItem(
              term: 'Falcon',
              inferredMeaning: 'اسم مشروع',
              confidence: HypothesisConfidence.medium,
              speakers: ['متحدث 2'],
              evidence: [3],
            ),
          ],
          references: [
            ReferenceItem(
              kind: ReferenceKind.invoice,
              verbatim: 'INV-7',
              normalized: 'INV-7',
              context: 'فاتورة',
              speaker: 'أحمد علي',
              evidence: [5],
            ),
          ],
        ),
        names,
      );
      expect(findings.map((f) => (f.kind, f.speakerId)), [
        (CodeFindingKind.jargon, 'b'),
        (CodeFindingKind.reference, 'a'),
      ]);
      expect(findings.map((f) => f.segmentIds), [
        [3],
        [5],
      ]);
      expect(findings.last.payload['verbatim'], 'INV-7');
    });

    test('names resolve among the meeting speakers first', () {
      Speaker sp(String id, String name, {bool opted = false}) => Speaker(
        id: id,
        name: name,
        colorValue: 0,
        isNamedByUser: true,
        createdAt: DateTime(2026),
        profileEnabled: opted,
      );
      final all = {
        'm1': sp('m1', 'محمد', opted: true),
        'm2': sp('m2', 'محمد'),
        'r': sp('r', 'ريم'),
      };
      // Only m1 speaks in this meeting.
      final scoped = SpeakerNameResolver.scoped(all, {'m1'});
      expect(scoped.id('محمد'), 'm1');
      expect(scoped.id('ريم'), 'r', reason: 'unique library-wide');
      expect(
        optedInSpeakerNotes(const [
          MinutesSpeakerNote(speaker: 'محمد'),
        ], scoped).keys,
        ['m1'],
      );
      // Both speak: still ambiguous.
      expect(SpeakerNameResolver.scoped(all, {'m1', 'm2'}).id('محمد'), isNull);
      // Library-wide only: ambiguous.
      expect(SpeakerNameResolver(all).id('محمد'), isNull);
    });

    test('persist scopes names to the meeting speakers', () async {
      final writer = MinutesArtifactsWriter(db);
      final m = await meetings.create(title: 'm');
      final a = await speakers.create(name: 'محمد', isNamedByUser: true);
      await speakers.create(name: 'محمد', isNamedByUser: true);
      await speakers.setProfileEnabled(a.id, true);
      final report = await writer.persist(
        meetingId: m.id,
        minutes: minutesWith(
          actionItems: const [ActionItem(task: 'إرسال العرض', owner: 'محمد')],
          speakerNotes: const [MinutesSpeakerNote(speaker: 'محمد')],
          codes: const MinutesCodes(
            implied: [
              ImpliedItem(
                literal: 'ربما',
                basis: 'نبرة',
                confidence: HypothesisConfidence.low,
                speaker: 'محمد',
              ),
            ],
          ),
        ),
        speakersById: await speakers.getAllById(),
        meetingSpeakerIds: {a.id},
      );
      expect(report.speakerNotes, 1);
      final task = (await TaskRepository(db).getAll(sourceMeetingId: m.id))
          .single;
      expect(task.ownerSpeakerId, a.id);
      expect(
        (await CodeFindingRepository(db).getForMeeting(m.id)).single.speakerId,
        a.id,
      );
    });

    test('planTaskSync keeps edited tasks and drops stale untouched ones', () {
      final t0 = DateTime(2026);
      TrackedTask task(
        int id,
        String text, {
        TaskStatus status = TaskStatus.open,
        DateTime? updated,
      }) => TrackedTask(
        id: id,
        task: text,
        status: status,
        createdAt: t0,
        updatedAt: updated ?? t0,
      );
      final plan = planTaskSync(
        [
          task(1, 'Send  report'),
          task(2, 'old untouched'),
          task(3, 'old edited', updated: DateTime(2026, 2)),
          task(4, 'old done', status: TaskStatus.done),
        ],
        const [
          ActionItem(task: 'send report'),
          ActionItem(task: 'new task'),
          ActionItem(task: 'NEW task'),
          ActionItem(task: ' '),
        ],
      );
      expect(plan.create.map((a) => a.task), ['new task']);
      expect(plan.deleteIds, [2]);
    });

    test('planTaskSync matches reworded tasks one to one', () {
      final t0 = DateTime(2026);
      TrackedTask task(
        int id,
        String text, {
        TaskStatus status = TaskStatus.open,
        DateTime? updated,
        List<int> evidence = const [],
      }) => TrackedTask(
        id: id,
        task: text,
        status: status,
        createdAt: t0,
        updatedAt: updated ?? t0,
        evidenceSegmentIds: evidence,
      );
      // A done task reworded with other spelling: no duplicate.
      var plan = planTaskSync(
        [task(1, 'إرسال التقرير', status: TaskStatus.done)],
        const [ActionItem(task: 'ارسال التقرير للإدارة')],
      );
      expect(plan.create, isEmpty);
      // An edited task found again through its evidence.
      plan = planTaskSync(
        [
          task(
            1,
            'تجهيز عرض الميزانية للمجلس',
            updated: DateTime(2026, 2),
            evidence: [7],
          ),
        ],
        const [
          ActionItem(task: 'إعداد الميزانية', evidence: [7]),
        ],
      );
      expect(plan.create, isEmpty);
      expect(plan.deleteIds, isEmpty);
      // An unrelated item is created; an untouched reworded task is kept.
      plan = planTaskSync(
        [task(1, 'حجز القاعة'), task(2, 'إرسال التقرير')],
        const [
          ActionItem(task: 'حجز قاعة'),
          ActionItem(task: 'مراجعة العقد'),
        ],
      );
      expect(plan.create.map((a) => a.task), ['مراجعة العقد']);
      expect(plan.deleteIds, [2]);
      // Two items never consume the same task.
      plan = planTaskSync(
        [task(1, 'إرسال التقرير')],
        const [
          ActionItem(task: 'إرسال التقرير'),
          ActionItem(task: 'ارسال التقرير للادارة'),
        ],
      );
      expect(plan.create.map((a) => a.task), ['ارسال التقرير للادارة']);
      // Dismissed items never come back.
      plan = planTaskSync(
        const [],
        const [
          ActionItem(task: 'حجز القاعة'),
          ActionItem(task: 'مراجعة العقد'),
        ],
        dismissedKeys: {taskMatchKey('حجز القاعه')},
      );
      expect(plan.create.map((a) => a.task), ['مراجعة العقد']);
      expect(similarTaskText('إرسال', 'إرسال الفاتورة للعميل'), isFalse);
    });

    test('regenerating never restores a deleted task nor a decided update',
        () async {
      final writer = MinutesArtifactsWriter(db);
      final tasks = TaskRepository(db);
      final pending = PendingTaskUpdateRepository(db);
      final m0 = await meetings.create(title: 'earlier');
      final m = await meetings.create(title: 'm');
      final earlier = await tasks.create(
        task: 'تجهيز العرض',
        sourceMeetingId: m0.id,
      );
      final minutes = minutesWith(
        actionItems: const [
          ActionItem(task: 'حجز القاعة'),
          ActionItem(task: 'إرسال التقرير'),
        ],
        taskUpdates: [
          MinutesTaskUpdate(taskId: earlier.id, newStatus: TaskStatus.done),
        ],
      );
      Future<void> persist(Minutes x) => writer.persist(
        meetingId: m.id,
        minutes: x,
        speakersById: const {},
        openTaskIds: {earlier.id},
      );
      await persist(minutes);
      // The user deletes one task and rejects the proposed update.
      final room = (await tasks.getAll(sourceMeetingId: m.id)).firstWhere(
        (t) => t.task == 'حجز القاعة',
      );
      expect(await tasks.deleteByUser(room), isTrue);
      expect(await pending.dismiss((await pending.getAll()).single.id), isTrue);

      await persist(minutes);
      expect(
        (await tasks.getAll(sourceMeetingId: m.id)).map((t) => t.task),
        ['إرسال التقرير'],
      );
      expect(await pending.getAll(meetingId: m.id), isEmpty);
      expect((await tasks.get(earlier.id))!.status, TaskStatus.open);

      // A different status for the same task is still proposed.
      await persist(
        minutesWith(
          taskUpdates: [
            MinutesTaskUpdate(
              taskId: earlier.id,
              newStatus: TaskStatus.cancelled,
            ),
          ],
        ),
      );
      expect(
        (await pending.getAll(meetingId: m.id)).single.newStatus,
        TaskStatus.cancelled,
      );
      // A stale untouched task removed by persist is not remembered.
      expect(
        await TaskDismissalRepository(db).keys(m.id, TaskDismissalKind.task),
        {taskMatchKey('حجز القاعة')},
      );
      // Tombstones go with the meeting.
      await meetings.delete(m.id);
      expect(
        await TaskDismissalRepository(db).keys(m.id, TaskDismissalKind.task),
        isEmpty,
      );
    });

    test('writer persists and regenerating replaces', () async {
      final writer = MinutesArtifactsWriter(db);
      final tasks = TaskRepository(db);
      final m0 = await meetings.create(title: 'earlier');
      final m = await meetings.create(title: 'm');
      final sp = await speakers.create(name: 'أحمد', isNamedByUser: true);
      await speakers.setProfileEnabled(sp.id, true);
      final earlier = await tasks.create(
        task: 'تجهيز العرض',
        sourceMeetingId: m0.id,
      );
      final byId = await speakers.getAllById();

      final first = await writer.persist(
        meetingId: m.id,
        minutes: minutesWith(
          actionItems: const [
            ActionItem(task: 'إرسال التقرير', owner: 'أحمد', evidence: [4]),
          ],
          taskUpdates: [
            MinutesTaskUpdate(
              taskId: earlier.id,
              newStatus: TaskStatus.done,
              evidence: const [2],
            ),
            const MinutesTaskUpdate(taskId: 999, newStatus: TaskStatus.done),
          ],
          speakerNotes: const [MinutesSpeakerNote(speaker: 'أحمد')],
          codes: const MinutesCodes(
            implied: [
              ImpliedItem(
                literal: 'ربما نؤجل',
                basis: 'نبرة',
                confidence: HypothesisConfidence.low,
                speaker: 'أحمد',
              ),
            ],
          ),
        ),
        speakersById: byId,
        openTaskIds: {earlier.id, 999},
      );
      expect(first.tasksCreated, 1);
      expect(first.pendingTaskUpdates, 1);
      expect(first.speakerNotes, 1);
      expect(first.codeFindings, 1);
      final created = (await tasks.getAll(sourceMeetingId: m.id)).single;
      expect(created.ownerSpeakerId, sp.id);
      expect(created.ownerText, 'أحمد');
      expect(created.evidenceSegmentIds, [4]);

      // Regenerated minutes: same task kept (not duplicated), a new one
      // added, no updates / notes / codes any more.
      final second = await writer.persist(
        meetingId: m.id,
        minutes: minutesWith(
          actionItems: const [
            ActionItem(task: 'إرسال  التقرير'),
            ActionItem(task: 'حجز القاعة'),
          ],
        ),
        speakersById: byId,
        openTaskIds: {earlier.id},
      );
      expect(second.tasksCreated, 1);
      expect(second.tasksDeleted, 0);
      expect(await tasks.getAll(sourceMeetingId: m.id), hasLength(2));
      expect(await PendingTaskUpdateRepository(db).getAll(), isEmpty);
      expect(
        await SpeakerMeetingNotesRepository(db).getForMeeting(m.id),
        isEmpty,
      );
      expect(await CodeFindingRepository(db).getForMeeting(m.id), isEmpty);
    });

    test('regenerating keeps reversed-speech results and app findings', () async {
      final writer = MinutesArtifactsWriter(db);
      final codes = CodeFindingRepository(db);
      final m = await meetings.create(title: 'm');
      final byId = await speakers.getAllById();
      Minutes coded(List<int> evidence) => minutesWith(
        codes: MinutesCodes(
          codedSpeech: [
            CodedSpeechItem(
              speaker: 'متحدث 1',
              character: CodedSpeechCharacter.unknown,
              description: 'كلام غير مفهوم',
              evidence: evidence,
            ),
          ],
        ),
      );
      await writer.persist(
        meetingId: m.id,
        minutes: coded(const [3]),
        speakersById: byId,
      );
      // The user runs reversed speech: the engine finding is enriched and
      // an app finding is added for segment 9.
      final engine = (await codes.getForMeeting(m.id)).single;
      const r3 = ReversedSpeechResult(segment: 3, text: 'نص معكوس');
      const r9 = ReversedSpeechResult(segment: 9, text: 'كلمة أخرى');
      await codes.replaceForMeeting(m.id, [
        CodeFinding(
          id: 0,
          meetingId: m.id,
          kind: CodeFindingKind.speechCoded,
          segmentIds: engine.segmentIds,
          payload: enrichPayload(engine.payload, checked: {3}, results: [r3]),
          createdAt: DateTime(2026),
        ),
        CodeFinding(
          id: 0,
          meetingId: m.id,
          kind: CodeFindingKind.speechCoded,
          segmentIds: const [9],
          payload: enrichPayload(
            {
              ...const CodedSpeechItem(
                speaker: 'متحدث 1',
                character: CodedSpeechCharacter.unknown,
                description: 'app',
                evidence: [9],
              ).toJson(),
              kFindingOriginKey: kOriginApp,
            },
            checked: {9},
            results: [r9],
          ),
          createdAt: DateTime(2026),
        ),
      ]);

      // Regenerated minutes cite segment 3 again (new wording).
      await writer.persist(
        meetingId: m.id,
        minutes: coded(const [3, 4]),
        speakersById: byId,
      );
      final after = await codes.getForMeeting(m.id);
      expect(after, hasLength(2));
      expect(readReversedResults(after[0].payload).map((r) => r.text), [
        'نص معكوس',
      ]);
      expect(readReversedChecked(after[0].payload), {3});
      expect(after[1].payload[kFindingOriginKey], kOriginApp);
      expect(readReversedResults(after[1].payload).single.text, 'كلمة أخرى');

      // Now the engine cites segment 9 too: the app finding merges into it.
      await writer.persist(
        meetingId: m.id,
        minutes: coded(const [3, 9]),
        speakersById: byId,
      );
      final merged = await codes.getForMeeting(m.id);
      expect(merged, hasLength(1));
      expect(readReversedResults(merged.single.payload).map((r) => r.segment),
          [3, 9]);
      expect(merged.single.payload[kFindingOriginKey], isNull);
    });
  });
}
