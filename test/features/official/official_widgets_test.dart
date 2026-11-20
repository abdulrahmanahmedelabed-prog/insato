// Widget tests of the official-minutes screens (v1.2): the official
// minutes screen and its lifecycle, attendance, vote review, signature
// capture, entity & templates settings and the template choice on the
// context page.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/official_repository.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/context/context_logic.dart';
import 'package:insato/features/context/meeting_context_page.dart';
import 'package:insato/features/official/attendance_screen.dart';
import 'package:insato/features/official/entity_settings_screen.dart';
import 'package:insato/features/official/official_minutes_screen.dart';
import 'package:insato/features/official/official_models.dart';
import 'package:insato/features/official/official_service.dart';
import 'package:insato/features/official/official_templates.dart';
import 'package:insato/features/official/signature_pad.dart';
import 'package:insato/features/official/strings.dart';
import 'package:insato/features/official/template_placeholders.dart';
import 'package:insato/features/official/vote_review_screen.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';

class _FakePicker implements OfficialFilePicker {
  _FakePicker({this.docx});
  final PickedFile? docx;

  @override
  Future<PickedFile?> pickDocx() async => docx;

  @override
  Future<PickedFile?> pickImage() async => null;
}

Minutes _minutes(List<MinutesVotePosition> positions) => Minutes(
  title: 'محضر',
  summary: 'ملخص',
  attendees: const ['سارة'],
  topics: const [],
  decisions: [
    MinutesDecision(
      text: 'اعتماد الخطة',
      formalText: 'قرر المجلس اعتماد الخطة',
      vote: MinutesVote(
        mode: VoteMode.formalVote,
        positions: positions,
        evidence: const [0],
      ),
    ),
  ],
  actionItems: const [],
  openQuestions: const [],
  languagesDetected: const ['العربية'],
  generatedAt: DateTime(2026, 6, 16, 12),
  model: 'test',
);

/// A board meeting on 1 Muharram 1448 with two members present.
Future<String> _seed(
  UiTestEnv env,
  WidgetTester t, {
  List<MinutesVotePosition> positions = const [
    MinutesVotePosition(
      speaker: 'سارة',
      position: VotePosition.approve,
      evidence: [0],
    ),
  ],
}) => env.run(t, () async {
  await OfficialSettingsStore(env.db).saveProfile(
    const EntityProfile(
      entityName: 'شركة المثال',
      committees: ['مجلس الإدارة'],
      chairName: 'سارة',
      secretaryName: 'منى',
    ),
  );
  final meetings = MeetingRepository(env.db);
  final m = await meetings.create(
    title: 'اجتماع المجلس',
    status: MeetingStatus.ready,
    createdAt: DateTime(2026, 6, 16, 10),
    context: const MeetingContext(
      template: 'board',
      expectedAttendees: ['سارة', 'خالد'],
    ),
  );
  await meetings.saveMinutes(m.id, _minutes(positions));
  await OfficialMinutesRepository(env.db).save(
    OfficialRecord(
      meetingId: m.id,
      committee: 'مجلس الإدارة',
      meetingNumber: 7,
      numberYear: 1448,
      chair: 'سارة',
      secretary: 'منى',
      attendance: const [
        AttendanceEntry(name: 'سارة'),
        AttendanceEntry(name: 'خالد'),
      ],
    ),
    entityName: 'شركة المثال',
  );
  return m.id;
});

void main() {
  testWidgets('official screen: header, quorum, review and approval', (
    t,
  ) async {
    setScreenSize(t, const Size(600, 2400));
    final env = UiTestEnv();
    final id = await _seed(env, t);
    await pumpScreen(t, env, OfficialMinutesScreen(meetingId: id));
    await settle(t, rounds: 12);

    expect(find.text('محضر اجتماع مجلس الإدارة رقم 7/1448هـ'), findsOneWidget);
    expect(find.textContaining('1 محرم 1448هـ'), findsWidgets);
    expect(find.textContaining('اكتمل النصاب'), findsWidgets);
    expect(find.text('قرار رقم (1/7/1448):'), findsOneWidget);

    await t.tap(find.text(OS.markReviewed));
    await settle(t, rounds: 10);
    expect(find.text(OS.approve), findsOneWidget);
    await t.tap(find.text(OS.approve));
    await settle(t);
    await t.tap(find.text(OS.approve).last);
    await settle(t, rounds: 12);

    final record = await env.run(
      t,
      () => OfficialMinutesRepository(env.db).get(id),
    );
    expect(record!.status, OfficialStatus.approved);
    expect(find.text(OS.newVersion), findsOneWidget);
    expect(find.text(OS.sign), findsWidgets);
    await env.dispose(t);
  });

  testWidgets('attendance: changing a status updates the quorum', (t) async {
    setScreenSize(t, const Size(600, 1400));
    final env = UiTestEnv();
    final id = await _seed(env, t);
    await pumpScreen(t, env, AttendanceScreen(meetingId: id));
    await settle(t, rounds: 12);
    expect(find.textContaining('اكتمل النصاب بحضور 2'), findsOneWidget);

    await t.tap(find.text(AttendanceStatus.present.labelAr).last);
    await settle(t);
    await t.tap(find.text(AttendanceStatus.absentExcused.labelAr).last);
    await settle(t, rounds: 12);

    final record = await env.run(
      t,
      () => OfficialMinutesRepository(env.db).get(id),
    );
    expect(record!.attendance.last.status, AttendanceStatus.absentExcused);
    expect(find.textContaining('لم يكتمل النصاب'), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('vote review confirms an unclear position', (t) async {
    setScreenSize(t, const Size(600, 1400));
    final env = UiTestEnv();
    final id = await _seed(
      env,
      t,
      positions: const [
        MinutesVotePosition(
          speaker: 'سارة',
          position: VotePosition.approve,
          evidence: [0],
        ),
        MinutesVotePosition(speaker: 'خالد', position: VotePosition.unclear),
      ],
    );
    await pumpScreen(t, env, VoteReviewScreen(meetingId: id));
    await settle(t, rounds: 12);
    expect(find.text(OS.needsReview), findsOneWidget);
    await t.tap(find.text(VotePosition.unclear.labelAr).last);
    await settle(t);
    await t.tap(find.text(VotePosition.object.labelAr).last);
    await settle(t);
    await t.tap(find.text(OS.confirmVote));
    await settle(t, rounds: 12);

    final record = await env.run(
      t,
      () => OfficialMinutesRepository(env.db).get(id),
    );
    expect(record!.voteReviews[0]!.positions['خالد'], VotePosition.object);
    expect(find.text(OS.confirmed), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('signature capture stores vector strokes', (t) async {
    setScreenSize(t, const Size(600, 1200));
    final env = UiTestEnv();
    final id = await _seed(env, t);
    // Approve through the repository (hash of the current content).
    await env.run(t, () async {
      final repo = OfficialMinutesRepository(env.db);
      final container = ProviderContainer(overrides: env.overrides);
      addTearDown(container.dispose);
      final b = (await container
          .read(officialMinutesServiceProvider)
          .bundle(id))!;
      await repo.approve(
        record: b.record.copyWith(status: OfficialStatus.reviewed),
        minutes: (await MeetingRepository(env.db).get(id))!.minutes!,
        hash: b.document.contentHash,
      );
    });
    final hash = (await env.run(
      t,
      () => OfficialMinutesRepository(env.db).get(id),
    ))!.approvedHash!;
    await pumpScreen(
      t,
      env,
      SignatureCaptureScreen(
        meetingId: id,
        contentHash: hash,
        signerName: 'سارة',
        signerRole: 'رئيس الاجتماع',
      ),
    );
    await settle(t);
    await t.tap(find.text(OS.saveSignature));
    await settle(t);
    expect(find.text(OS.emptySignature), findsOneWidget);

    final pad = find.byType(SignaturePad);
    final box = t.getRect(pad);
    final g = await t.startGesture(box.center - const Offset(100, 0));
    for (var k = 0; k < 10; k++) {
      await g.moveBy(const Offset(20, 2));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await settle(t);
    await t.tap(find.text(OS.saveSignature));
    await settle(t, rounds: 12);
    final sigs = await env.run(
      t,
      () => OfficialMinutesRepository(env.db).signatures(id),
    );
    expect(sigs.single.signerName, 'سارة');
    expect(sigs.single.strokes.single.length, greaterThan(1));
    expect(sigs.single.contentHash, hash);
    await env.dispose(t);
  });

  testWidgets('entity settings: profile, committees and template upload', (
    t,
  ) async {
    setScreenSize(t, const Size(600, 2400));
    final env = UiTestEnv();
    env.extraOverrides.add(
      officialFilePickerProvider.overrideWithValue(
        _FakePicker(docx: PickedFile('قالب الجهة.docx', buildSampleTemplate())),
      ),
    );
    await pumpScreen(t, env, const EntitySettingsScreen());
    await settle(t, rounds: 10);

    await t.enterText(
      find.widgetWithText(TextField, OS.entityName),
      'وزارة المثال',
    );
    await t.enterText(
      find.widgetWithText(TextField, OS.addCommittee),
      'لجنة التدقيق',
    );
    await t.tap(find.byTooltip(OS.addCommittee));
    await settle(t, rounds: 10);
    expect(find.text('لجنة التدقيق'), findsOneWidget);
    await t.tap(find.text(S.save).first);
    // Under a loaded full-suite run the save can take longer than a fixed
    // number of frames: wait for it.
    await settleUntil(
      t,
      () async =>
          (await OfficialSettingsStore(env.db).profile()).entityName ==
          'وزارة المثال',
      reason: 'profile saved',
    );
    final profile = await env.run(
      t,
      () => OfficialSettingsStore(env.db).profile(),
    );
    expect(profile.entityName, 'وزارة المثال');
    expect(profile.committees, ['لجنة التدقيق']);

    await t.tap(find.text(OS.uploadTemplate));
    await settle(t, rounds: 10);
    await t.tap(find.text(OS.uploadTemplate).last);
    await settleUntil(
      t,
      () async =>
          (await OfficialSettingsStore(env.db).templates()).isNotEmpty &&
          find.text('قالب الجهة').evaluate().isNotEmpty,
      reason: 'template uploaded',
    );
    final templates = await env.run(
      t,
      () => OfficialSettingsStore(env.db).templates(),
    );
    expect(templates.single.name, 'قالب الجهة');
    expect(templates.single.baseTemplateId, OfficialTemplates.board.id);
    expect(find.text('قالب الجهة'), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('the context page stores the chosen template', (t) async {
    setScreenSize(t, const Size(600, 2000));
    final env = UiTestEnv();
    MeetingSetup? result;
    await pumpScreen(
      t,
      env,
      Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async =>
                result = await showMeetingContextPage(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await settle(t, rounds: 10);
    expect(find.text(OS.templateHeader), findsOneWidget);
    await t.tap(find.text(OfficialTemplates.team.nameAr));
    await settle(t);
    await t.tap(find.text(OfficialTemplates.committee.nameAr).last);
    await settle(t);
    expect(
      find.text(OfficialTemplates.committee.descriptionAr),
      findsOneWidget,
    );
    await t.tap(find.text('ابدأ التسجيل').last);
    await settle(t);
    expect(result?.context.template, 'committee');
    await env.dispose(t);
  });

  test('picked files keep name and bytes', () {
    final f = PickedFile('a.png', Uint8List(3));
    expect((f.name, f.bytes.length), ('a.png', 3));
  });
}
