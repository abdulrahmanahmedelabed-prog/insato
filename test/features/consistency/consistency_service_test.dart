// The consistency checker over a real (in-memory) database: memory loading,
// heuristics without an engine, the engine request and merge, keeping the
// user's decisions across re-checks, «تم الإلغاء رسمياً» as an annotation
// that never edits approved minutes, and the live check.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/consistency_repository.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/official_repository.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';
import 'package:insato/features/consistency/consistency_models.dart';
import 'package:insato/features/consistency/consistency_prompt.dart';
import 'package:insato/features/consistency/consistency_service.dart';
import 'package:insato/features/consistency/strings.dart';
import 'package:insato/features/official/official_models.dart';
import 'package:insato/session/post_processor.dart'
    show MinutesEngineNotReadyException, MinutesEngineNotReadyReason;

import '../../session/fakes.dart' show memoryDb;
import '../ask/fakes.dart';
import 'fixtures.dart';

class _Env {
  _Env() : db = memoryDb();

  final AppDatabase db;
  late final meetings = MeetingRepository(db);
  late final segments = SegmentRepository(db);
  late final official = OfficialMinutesRepository(db);
  late final repo = ConsistencyRepository(db);
  late final tasks = TaskRepository(db);
  FakeBackend? backend;
  Object? factoryError;
  int factoryCalls = 0;

  ConsistencyService service() => ConsistencyService(
    repository: repo,
    meetings: meetings,
    segments: segments,
    speakers: SpeakerRepository(db),
    official: official,
    officialSettings: OfficialSettingsStore(db),
    tasks: tasks,
    backendFactory: () async {
      factoryCalls++;
      final e = factoryError;
      if (e != null) throw e;
      return backend!;
    },
    clock: () => DateTime(2026, 11, 20, 9),
  );

  Future<Meeting> meeting(
    String id,
    DateTime at,
    Minutes minutes, {
    String title = 'اجتماع',
    String? template,
  }) async {
    final m = await meetings.create(
      id: id,
      title: title,
      createdAt: at,
      status: MeetingStatus.ready,
      context: MeetingContext(template: template),
    );
    await meetings.saveMinutes(m.id, minutes);
    await segments.insertAll([
      for (var i = 0; i < 4; i++)
        TranscriptSegment(
          id: '',
          meetingId: id,
          index: i,
          startMs: i * 5000,
          endMs: i * 5000 + 4000,
          text: 'سطر $i من $title',
        ),
    ]);
    return (await meetings.get(id))!;
  }

  /// January board meeting (approved, number 12/1448) and a June meeting
  /// that cancels its resolution and re-assigns its task.
  Future<void> seed() async {
    await meeting(
      'jan',
      DateTime(2026, 1, 10),
      minutesWith(
        decisions: ['اعتماد عقد الصيانة مع شركة النور'],
        decisionEvidence: [
          [2],
        ],
      ),
      title: 'مجلس يناير',
      template: 'board',
    );
    final record = await official.save(
      const OfficialRecord(
        meetingId: 'jan',
        meetingNumber: 12,
        numberYear: 1448,
      ),
    );
    await official.approve(
      record: record,
      minutes: (await meetings.get('jan'))!.minutes!,
      hash: 'approved-hash',
    );
    await tasks.create(
      task: 'إعداد تقرير الميزانية',
      ownerText: 'سارة',
      dueText: 'الخميس',
      sourceMeetingId: 'jan',
      evidenceSegmentIds: const [3],
    );
    await meeting(
      'jun',
      DateTime(2026, 6, 16, 10),
      minutesWith(
        decisions: ['إلغاء عقد الصيانة مع شركة النور', 'اعتماد خطة التدريب'],
        decisionEvidence: [
          [1],
          [2],
        ],
        actions: [('إعداد تقرير الميزانية', 'خالد', 'الخميس')],
      ),
      title: 'مجلس يونيو',
      template: 'board',
    );
  }
}

void main() {
  late _Env env;
  setUp(() => env = _Env());
  tearDown(() => env.db.close());

  test(
    'without an engine the heuristics still find the obvious cases',
    () async {
      await env.seed();
      env.factoryError = const MinutesEngineNotReadyException(
        'مفتاح Gemini API غير مضبوط.',
        reason: MinutesEngineNotReadyReason.noApiKey,
      );
      final r = await env.service().check('jun');
      expect(r.engineUsed, isFalse);
      expect(r.engineNoticeAr, contains('مفتاح Gemini'));
      expect(r.engineNoticeAr, startsWith('فُحص الاجتماع بالقواعد المحلية'));
      final found = await env.repo.forMeeting('jun');
      expect(r.open, found.length);
      final c = found.firstWhere(
        (f) => f.kind == FindingKind.contradictsResolution,
      );
      expect(c.severity, FindingSeverity.high);
      expect(c.priorSide.kind, SideKind.resolution);
      expect(c.priorSide.label, 'قرار رقم (1/12/1448)');
      expect(c.priorSide.meetingNumber, '12/1448هـ');
      expect(c.priorSide.meetingTitle, 'مجلس يناير');
      expect(c.priorSide.evidence, [2]);
      expect(c.newSide.evidence, [1]);
      expect(
        found
            .firstWhere((f) => f.kind == FindingKind.changesOwner)
            .priorSide
            .owner,
        'سارة',
      );
    },
  );

  test(
    'the engine classifies candidate pairs; invalid ones are dropped',
    () async {
      await env.seed();
      env.backend = FakeBackend([
        jsonEncode({
          'findings': [
            {
              'new_item': 'D2',
              'prior_ref': 'D1',
              'kind': 'internal_conflict',
              'severity': 'medium',
              'explanation': '[D2] لا يتسق مع [D1].',
              'evidence_segments': [2],
            },
            {
              'new_item': 'D1',
              'prior_ref': 'R9',
              'kind': 'contradicts_resolution',
              'severity': 'high',
              'explanation': 'مرجع مختلق',
              'evidence_segments': [],
            },
          ],
        }),
      ]);
      final r = await env.service().check('jun');
      expect(r.engineUsed, isTrue);
      expect(r.engineNoticeAr, isNull);
      final req = env.backend!.requests.single;
      expect(req.system, kConsistencySystemPrompt);
      expect(req.user, contains('مجلس يناير'));
      expect(req.user, contains('قرار رقم (1/12/1448)'));
      expect(env.backend!.closes, 1);
      final found = await env.repo.forMeeting('jun');
      final engine = found.where((f) => f.origin == FindingOrigin.engine);
      expect(engine.single.kind, FindingKind.internalConflict);
      expect(
        engine.single.explanation,
        'قرار رقم (2) لا يتسق مع قرار رقم (1).',
      );
      // The heuristic findings are kept alongside.
      expect(
        found.any((f) => f.kind == FindingKind.contradictsResolution),
        isTrue,
      );
    },
  );

  test('an engine failure keeps the heuristic findings', () async {
    await env.seed();
    env.backend = FakeBackend([Exception('boom')]);
    final r = await env.service().check('jun');
    expect(r.engineUsed, isFalse);
    expect(r.engineNoticeAr, contains(DS.engineFailed));
    expect(r.open, greaterThan(0));
    expect(env.backend!.closes, 1);
  });

  test('nothing to compare → the engine is not called', () async {
    await env.meeting(
      'solo',
      DateTime(2026, 2, 1),
      minutesWith(decisions: ['اعتماد خطة التدريب']),
    );
    final r = await env.service().check('solo');
    expect(r.open, 0);
    expect(env.factoryCalls, 0);
  });

  test('no minutes → an Arabic error', () async {
    await env.meetings.create(id: 'empty', status: MeetingStatus.ready);
    await expectLater(env.service().check('empty'), throwsA(isA<Exception>()));
  });

  test('re-checking keeps dismissed and confirmed findings', () async {
    await env.seed();
    env.factoryError = Exception('offline');
    final service = env.service();
    await service.check('jun');
    final first = await env.repo.forMeeting('jun');
    final owner = first.firstWhere((f) => f.kind == FindingKind.changesOwner);
    await service.dismiss(owner.id!);
    final r = await service.check('jun');
    final again = await env.repo.forMeeting('jun');
    expect(again.length, first.length);
    expect(
      again.where((f) => f.kind == FindingKind.changesOwner).single.status,
      FindingStatus.dismissed,
    );
    expect(r.open, first.length - 1);
  });

  test('«تم الإلغاء رسمياً» annotates the approved resolution without '
      'editing it, and is undoable', () async {
    await env.seed();
    env.factoryError = Exception('offline');
    final service = env.service();
    await service.check('jun');
    final c = (await env.repo.forMeeting('jun'))
        .firstWhere((f) => f.kind == FindingKind.contradictsResolution);
    final minutesBefore = jsonEncode(
      (await env.meetings.get('jan'))!.minutes!.toJson(),
    );
    await service.confirm(c.id!);

    expect((await env.repo.get(c.id!))!.status, FindingStatus.confirmed);
    final a = (await env.repo.annotations('jan')).single;
    expect(a.decisionIndex, 0);
    expect(a.decisionKey, 'اعتماد عقد الصيانة مع شركة النور');
    expect(a.byMeetingId, 'jun');
    expect(a.bySide.text, 'إلغاء عقد الصيانة مع شركة النور');
    // Approved minutes stay locked, unchanged, same version and hash.
    final record = (await env.official.get('jan'))!;
    expect(record.status, OfficialStatus.approved);
    expect(record.version, 1);
    expect(record.approvedHash, 'approved-hash');
    expect(
      jsonEncode((await env.meetings.get('jan'))!.minutes!.toJson()),
      minutesBefore,
    );
    expect(await env.official.versions('jan'), hasLength(1));

    // The superseded resolution is no longer in the memory.
    final memory = await service.loadMemory((await env.meetings.get('jun'))!);
    expect(memory.items.where((i) => i.isDecision), isEmpty);

    await service.reopen(c.id!);
    expect(await env.repo.annotations('jan'), isEmpty);
    expect((await env.repo.get(c.id!))!.status, FindingStatus.open);
  });

  test('confirming a task finding only marks it confirmed', () async {
    await env.seed();
    env.factoryError = Exception('offline');
    final service = env.service();
    await service.check('jun');
    final t = (await env.repo.forMeeting('jun'))
        .firstWhere((f) => f.kind == FindingKind.changesOwner);
    await service.confirm(t.id!);
    expect((await env.repo.get(t.id!))!.status, FindingStatus.confirmed);
    expect(await env.repo.annotations('jan'), isEmpty);
  });

  group('live check', () {
    List<TranscriptSegment> recent() => [
      for (var i = 0; i < 4; i++)
        TranscriptSegment(
          id: 'l$i',
          meetingId: 'live',
          index: i,
          startMs: i * 1000,
          endMs: i * 1000 + 900,
          text: i == 2
              ? 'نقترح إلغاء عقد الصيانة مع شركة النور'
              : 'حديث عام رقم $i',
        ),
    ];

    test('a cloud engine reports evidence-backed findings', () async {
      await env.seed();
      env.backend = FakeBackend([
        jsonEncode({
          'findings': [
            {
              'new_item': 'L1',
              'prior_ref': 'R1',
              'kind': 'contradicts_resolution',
              'severity': 'high',
              'explanation': 'يقترح [L1] إلغاء ما قرره [R1].',
              'evidence_segments': [2],
            },
          ],
        }),
      ]);
      final found = await env.service().liveCheck(
        meetingId: 'live',
        title: 'اجتماع جارٍ',
        createdAt: DateTime(2026, 11, 20),
        recent: recent(),
      );
      expect(found.single.newSide.text, contains('إلغاء عقد الصيانة'));
      expect(found.single.priorSide.label, 'قرار رقم (1/12/1448)');
      expect(env.backend!.requests.single.user, contains('[L1]'));
      // Nothing is stored.
      expect(await env.repo.forMeeting('live'), isEmpty);
    });

    test('a local engine is never used', () async {
      await env.seed();
      env.backend = FakeBackend(['{}'], engineId: 'local', offDevice: false);
      final found = await env.service().liveCheck(
        meetingId: 'live',
        title: 'اجتماع جارٍ',
        createdAt: DateTime(2026, 11, 20),
        recent: recent(),
      );
      expect(found, isEmpty);
      expect(env.backend!.requests, isEmpty);
      expect(env.backend!.closes, 1);
    });

    test('nothing related → no request', () async {
      await env.seed();
      env.backend = FakeBackend([]);
      final found = await env.service().liveCheck(
        meetingId: 'live',
        title: 'اجتماع جارٍ',
        createdAt: DateTime(2026, 11, 20),
        recent: [
          for (final s in recent())
            if (s.index != 2) s,
        ],
      );
      expect(found, isEmpty);
      expect(env.factoryCalls, 0);
    });
  });
}
