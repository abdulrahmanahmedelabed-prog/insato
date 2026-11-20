// Widget tests of the consistency checker (v1.2, D): the «التناقضات» tab
// of the meeting screen (check, both sides with number and Hijri date,
// dismiss / «تم الإلغاء رسمياً» / undo, evidence of the earlier side), the
// annotation shown on the earlier meeting, the automatic check after
// minutes generation, the live banner and the live-mode setting.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/consistency_repository.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/ask/ask_source_sheet.dart';
import 'package:insato/features/consistency/consistency.dart';
import 'package:insato/features/official/official_document.dart'
    show hijriDateText;
import 'package:insato/features/official/official_models.dart';
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/ui/screens/meeting_detail_screen.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import '../../session/fakes.dart';
import '../../ui/harness.dart';
import '../ask/fakes.dart';
import 'fixtures.dart';

final DateTime _jan = DateTime(2026, 1, 10, 10);
final DateTime _jun = DateTime(2026, 6, 16, 10);

/// January board meeting (approved, number 12/1448) with a task, and a
/// June meeting that cancels its resolution.
Future<void> _seed(
  UiTestEnv env,
  WidgetTester t, {
  bool withJune = true,
}) => env.run(t, () async {
  final meetings = MeetingRepository(env.db);
  final segs = SegmentRepository(env.db);
  Future<void> meeting(String id, DateTime at, String title, Minutes m) async {
    await meetings.create(
      id: id,
      title: title,
      createdAt: at,
      status: MeetingStatus.ready,
      context: const MeetingContext(template: 'board'),
    );
    await meetings.saveMinutes(id, m);
    await segs.insertAll([
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
  }

  await meeting(
    'jan',
    _jan,
    'مجلس يناير',
    minutesWith(
      decisions: ['اعتماد عقد الصيانة مع شركة النور'],
      decisionEvidence: [
        [2],
      ],
    ),
  );
  final official = OfficialMinutesRepository(env.db);
  final record = await official.save(
    const OfficialRecord(meetingId: 'jan', meetingNumber: 12, numberYear: 1448),
  );
  await official.approve(
    record: record,
    minutes: (await meetings.get('jan'))!.minutes!,
    hash: 'h',
  );
  await TaskRepository(env.db).create(
    task: 'إعداد تقرير الميزانية',
    ownerText: 'سارة',
    sourceMeetingId: 'jan',
  );
  if (withJune) {
    await meeting(
      'jun',
      _jun,
      'مجلس يونيو',
      minutesWith(
        decisions: ['إلغاء عقد الصيانة مع شركة النور'],
        decisionEvidence: [
          [1],
        ],
      ),
    );
  }
});

UiTestEnv _env({List<Object>? replies}) {
  final env = UiTestEnv();
  env.extraOverrides.add(
    minutesBackendFactoryProvider.overrideWithValue(() async {
      if (replies == null) {
        throw const MinutesEngineNotReadyException(
          'مفتاح Gemini API غير مضبوط.',
          reason: MinutesEngineNotReadyReason.noApiKey,
        );
      }
      return FakeBackend(replies);
    }),
  );
  return env;
}

Future<void> _openTab(WidgetTester t) async {
  // The tab bar scrolls on narrow screens: select the last tab directly.
  expect(find.text(DS.tabTitle), findsOneWidget);
  DefaultTabController.of(t.element(find.byType(TabBar))).animateTo(5);
  await settle(t);
}

Future<List<ConsistencyFinding>> _findings(UiTestEnv env, WidgetTester t) =>
    env.run(t, () => ConsistencyRepository(env.db).forMeeting('jun'));

void main() {
  testWidgets('the tab checks on demand and shows both sides', (t) async {
    setScreenSize(t, const Size(600, 2400));
    final env = _env();
    await _seed(env, t);
    await pumpScreen(t, env, const MeetingDetailScreen(meetingId: 'jun'));
    await _openTab(t);
    expect(find.text(DS.header), findsOneWidget);
    expect(find.text(DS.notCheckedBody), findsOneWidget);

    await t.tap(find.text(DS.checkNow));
    await settleUntil(
      t,
      () => find
          .text(DS.kindLabel(FindingKind.contradictsResolution))
          .evaluate()
          .isNotEmpty,
      reason: 'finding shown',
    );
    // Local rules only: the reason is shown.
    expect(find.textContaining('بالقواعد المحلية فقط'), findsOneWidget);
    expect(find.textContaining('مفتاح Gemini'), findsOneWidget);
    expect(find.text(DS.severityLabel(FindingSeverity.high)), findsOneWidget);
    expect(find.text(DS.thisMeeting), findsOneWidget);
    expect(find.text(DS.earlier), findsOneWidget);
    expect(find.text('قرار معتمد — قرار رقم (1/12/1448)'), findsOneWidget);
    expect(find.textContaining('«مجلس يناير» — رقم 12/1448هـ'), findsOneWidget);
    expect(find.textContaining(hijriDateText(_jan)), findsOneWidget);
    expect(find.text(DS.openCount(1)), findsOneWidget);
    // The tab label shows the open count.
    expect(find.text('1'), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('«تم الإلغاء رسمياً» annotates the earlier meeting; undo', (
    t,
  ) async {
    setScreenSize(t, const Size(600, 2400));
    final env = _env();
    await _seed(env, t);
    await env.run(
      t,
      () => ConsistencyService(
        repository: ConsistencyRepository(env.db),
        meetings: MeetingRepository(env.db),
        segments: SegmentRepository(env.db),
        speakers: SpeakerRepository(env.db),
        official: OfficialMinutesRepository(env.db),
        officialSettings: OfficialSettingsStore(env.db),
        tasks: TaskRepository(env.db),
      ).check('jun'),
    );
    await pumpScreen(t, env, const MeetingDetailScreen(meetingId: 'jun'));
    await _openTab(t);

    await t.tap(find.text(DS.confirmCancelled));
    await settle(t);
    expect(find.text(DS.confirmTitle), findsOneWidget);
    expect(find.textContaining('محضره معتمد ومقفل'), findsOneWidget);
    await t.tap(find.text(DS.confirmCancelled).last);
    await settleUntil(
      t,
      () async =>
          (await ConsistencyRepository(env.db).annotations('jan')).isNotEmpty,
      reason: 'annotation stored',
    );
    final f = (await _findings(env, t)).single;
    expect(f.status, FindingStatus.confirmed);
    await settleUntil(
      t,
      () => find.text(DS.handled(1)).evaluate().isNotEmpty,
      reason: 'handled section',
    );
    await t.tap(find.text(DS.handled(1)));
    await settle(t);
    expect(find.text(DS.confirmedCancelledLabel), findsOneWidget);

    // Undo.
    await t.tap(find.text(DS.reopen));
    await settleUntil(
      t,
      () async =>
          (await ConsistencyRepository(env.db).annotations('jan')).isEmpty,
      reason: 'annotation removed',
    );
    expect((await _findings(env, t)).single.status, FindingStatus.open);
    await env.dispose(t);
  });

  testWidgets('the earlier meeting shows the annotation, minutes untouched', (
    t,
  ) async {
    setScreenSize(t, const Size(600, 2400));
    final env = _env();
    await _seed(env, t);
    final service = ConsistencyService(
      repository: ConsistencyRepository(env.db),
      meetings: MeetingRepository(env.db),
      segments: SegmentRepository(env.db),
      speakers: SpeakerRepository(env.db),
      official: OfficialMinutesRepository(env.db),
      officialSettings: OfficialSettingsStore(env.db),
      tasks: TaskRepository(env.db),
    );
    await env.run(t, () async {
      await service.check('jun');
      final f = (await ConsistencyRepository(env.db).forMeeting('jun')).single;
      await service.confirm(f.id!);
    });
    await pumpScreen(t, env, const MeetingDetailScreen(meetingId: 'jan'));
    expect(find.text(DS.supersededTitle), findsOneWidget);
    expect(
      find.textContaining(
        '«اعتماد عقد الصيانة مع شركة النور» — أُلغي رسمياً '
        'في اجتماع «مجلس يونيو»',
      ),
      findsOneWidget,
    );
    expect(find.text(DS.supersededApprovedNote), findsOneWidget);
    // The resolution itself is still printed as approved.
    expect(find.text('اعتماد عقد الصيانة مع شركة النور'), findsWidgets);
    final record = await env.run(
      t,
      () => OfficialMinutesRepository(env.db).get('jan'),
    );
    expect(record!.status, OfficialStatus.approved);
    await env.dispose(t);
  });

  testWidgets('dismiss, and the earlier evidence opens its source', (t) async {
    setScreenSize(t, const Size(600, 2400));
    final env = _env();
    await _seed(env, t);
    await env.run(
      t,
      () => ConsistencyService(
        repository: ConsistencyRepository(env.db),
        meetings: MeetingRepository(env.db),
        segments: SegmentRepository(env.db),
        speakers: SpeakerRepository(env.db),
        official: OfficialMinutesRepository(env.db),
        officialSettings: OfficialSettingsStore(env.db),
        tasks: TaskRepository(env.db),
      ).check('jun'),
    );
    await pumpScreen(t, env, const MeetingDetailScreen(meetingId: 'jun'));
    await _openTab(t);

    await t.tap(find.text(DS.showEvidence));
    await settle(t, rounds: 10);
    expect(find.byType(AskSourceSheet), findsOneWidget);
    expect(find.text('سطر 2 من مجلس يناير'), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await settle(t);

    await t.tap(find.text(DS.dismiss));
    await settleUntil(
      t,
      () async =>
          (await ConsistencyRepository(env.db).forMeeting('jun'))
              .single
              .status ==
          FindingStatus.dismissed,
      reason: 'dismissed',
    );
    await settleUntil(
      t,
      () => find.text(DS.handled(1)).evaluate().isNotEmpty,
      reason: 'handled section',
    );
    expect(find.text(DS.openCount(1)), findsNothing);
    await env.dispose(t);
  });

  testWidgets('generating minutes runs the check automatically', (t) async {
    setScreenSize(t, const Size(600, 2400));
    final env =
        _env(
            replies: [
              jsonEncode({'findings': []}),
            ],
          )
          ..minutes = (FakeMinutesEngine()
            ..result = minutesWith(
              decisions: ['نلغي عقد الصيانة مع شركة النور نهائياً'],
              decisionEvidence: [
                [1],
              ],
            ));
    await _seed(env, t);
    await pumpScreen(t, env, const MeetingDetailScreen(meetingId: 'jun'));
    await t.tap(find.text(S.regenerateMinutes));
    await settleUntil(
      t,
      () async =>
          (await ConsistencyRepository(env.db).forMeeting('jun')).isNotEmpty,
      reason: 'automatic check stored findings',
    );
    final f = (await _findings(env, t)).single;
    expect(f.kind, FindingKind.contradictsResolution);
    expect(f.newSide.text, 'نلغي عقد الصيانة مع شركة النور نهائياً');
    await env.dispose(t);
  });

  testWidgets('no minutes: the tab explains and cannot check', (t) async {
    setScreenSize(t, const Size(600, 2000));
    final env = _env();
    await env.run(
      t,
      () =>
          MeetingRepository(env.db)
              .create(id: 'x', title: 'بلا محضر', status: MeetingStatus.ready),
    );
    await pumpScreen(t, env, const MeetingDetailScreen(meetingId: 'x'));
    await _openTab(t);
    expect(find.text(DS.noMinutes), findsOneWidget);
    final button = t.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(DS.checkNow),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
    await env.dispose(t);
  });

  testWidgets('live mode: off by default; on → banner with details', (t) async {
    setScreenSize(t, kPhone);
    final env = _env(
      replies: [
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
      ],
    );
    await _seed(env, t, withJune: false);
    await env.run(t, () async {
      await MeetingRepository(env.db)
          .create(id: 'live', title: 'اجتماع جارٍ', createdAt: _jun);
      await SegmentRepository(env.db).insertAll([
        for (var i = 0; i < 5; i++)
          TranscriptSegment(
            id: '',
            meetingId: 'live',
            index: i,
            startMs: i * 1000,
            endMs: i * 1000 + 900,
            text: i == 2 ? 'نقترح إلغاء عقد الصيانة مع شركة النور' : 'كلام $i',
          ),
      ]);
    });
    await pumpScreen(
      t,
      env,
      const Scaffold(
        body: Column(
          children: [
            LiveConsistencyBanner(
              meetingId: 'live',
              interval: Duration(seconds: 1),
            ),
            Expanded(child: ConsistencyLiveSettingTile()),
          ],
        ),
      ),
    );
    // Off by default: nothing happens.
    await t.pump(const Duration(seconds: 3));
    await settle(t);
    expect(find.textContaining('قد يتعارض'), findsNothing);
    expect(
      t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );

    await t.tap(find.byType(SwitchListTile));
    await settleUntil(
      t,
      () => ConsistencySettingsStore(env.db).liveMode(),
      reason: 'live mode on',
    );
    await settleUntil(
      t,
      () => find.text(DS.liveBanner(1)).evaluate().isNotEmpty,
      reason: 'live banner',
    );
    await t.tap(find.text(DS.liveDetails));
    await settle(t);
    expect(find.text(DS.liveSheetTitle), findsOneWidget);
    expect(find.text('نقترح إلغاء عقد الصيانة مع شركة النور'), findsOneWidget);
    expect(find.text(DS.dismiss), findsNothing);
    await t.tapAt(const Offset(10, 10));
    await settle(t);
    await t.tap(find.byTooltip(DS.liveHide));
    await settle(t);
    expect(find.text(DS.liveBanner(1)), findsNothing);
    // Turn it off again so the periodic timer stops.
    await t.tap(find.byType(SwitchListTile));
    await settleUntil(
      t,
      () async => !await ConsistencySettingsStore(env.db).liveMode(),
      reason: 'live mode off',
    );
    await env.dispose(t);
  });
}
