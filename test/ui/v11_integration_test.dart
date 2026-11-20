// The v1.1 features are reachable from the app: shell destinations (tasks,
// ask), meeting tabs (tasks, codes) with evidence chips on the minutes, the
// export sheet with Word, the speaker profile and voice enrollment entries,
// the settings sections (glossary, microphone) and the GGUF models, and the
// open-tasks banner on the recording screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/ask/ask.dart';
import 'package:insato/features/codes/codes.dart' show CodesTab, KS;
import 'package:insato/features/context/strings.dart' show CS;
import 'package:insato/features/evidence/evidence.dart';
import 'package:insato/features/export_docx/export_docx.dart';
import 'package:insato/features/export_docx/strings.dart' show XS;
import 'package:insato/features/local_llm/local_engine_settings.dart';
import 'package:insato/features/profiles/profile_screen.dart';
import 'package:insato/features/profiles/strings.dart' show PS;
import 'package:insato/features/tasks/tasks.dart';
import 'package:insato/features/voice/voice.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/ui/screens/meeting_detail_screen.dart';
import 'package:insato/ui/screens/models_screen.dart';
import 'package:insato/ui/screens/settings_screen.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

Future<void> tapTab(WidgetTester t, String label) async {
  final tab = find.descendant(
    of: find.byType(TabBar),
    matching: find.text(label),
  );
  await t.ensureVisible(tab);
  await t.pump();
  await t.tap(tab);
}

void main() {
  testWidgets('phone shell: tasks and ask destinations', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await pumpApp(t, env);
    final bar = find.byType(NavigationBar);
    expect(
      find.descendant(of: bar, matching: find.byType(NavigationDestination)),
      findsNWidgets(5),
    );

    await t.tap(find.descendant(of: bar, matching: find.text(S.navTasks)));
    await settle(t);
    expect(find.byType(TasksScreen), findsOneWidget);

    await t.tap(find.descendant(of: bar, matching: find.text(S.navAsk)));
    await settle(t);
    expect(find.byType(AskMeetingsScreen), findsOneWidget);
    expect(find.text(AS.title), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('desktop rail lists the same five destinations', (t) async {
    setScreenSize(t, kDesktop);
    final env = UiTestEnv();
    await pumpApp(t, env);
    final rail = find.byType(NavigationRail);
    for (final label in [
      S.navMeetings,
      S.navTasks,
      S.navAsk,
      S.navSpeakers,
      S.navSettings,
    ]) {
      expect(
        find.descendant(of: rail, matching: find.text(label)),
        findsOneWidget,
      );
    }
    await env.dispose(t);
  });

  testWidgets('meeting page: evidence chips, tasks and codes tabs, export', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () async {
      final s = await seedMeeting(env);
      final meetings = MeetingRepository(env.db);
      await meetings.saveMinutes(
        s.meeting.id,
        s.meeting.minutes!.copyWith(
          decisions: const [
            MinutesDecision(text: 'اعتماد ميزانية التسويق', evidence: [1]),
          ],
        ),
      );
      await TaskRepository(env.db).create(
        task: 'إعداد تقرير الميزانية',
        ownerText: 'سارة',
        sourceMeetingId: s.meeting.id,
        evidenceSegmentIds: const [1],
      );
      return s;
    });
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));

    // F5: the decision cites segment #1 (00:00:05) with a playable chip.
    expect(find.byType(EvidenceScope), findsOneWidget);
    expect(find.byType(EvidenceChips), findsWidgets);

    // F9 tab.
    await tapTab(t, TS.tasksTitle);
    await settle(t);
    expect(find.byType(MeetingTasksPanel), findsOneWidget);
    expect(find.text('إعداد تقرير الميزانية'), findsOneWidget);

    // F17 tab.
    await tapTab(t, KS.tabTitle);
    await settle(t);
    expect(find.byType(CodesTab), findsOneWidget);

    // F12: the export menu opens the PDF / Word / Markdown sheet.
    await t.tap(find.byTooltip('المزيد'));
    await settle(t);
    expect(find.text(CS.editTitle), findsOneWidget);
    await t.tap(find.text(XS.sheetTitle));
    await settle(t);
    expect(find.byType(ExportShareSheet), findsOneWidget);
    expect(find.text(XS.shareDocx), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('voice library: enroll button, profile and improve voice', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await env.run(t, () => seedMeeting(env));
    await pumpApp(t, env);
    final bar = find.byType(NavigationBar);
    await t.tap(find.descendant(of: bar, matching: find.text(S.navSpeakers)));
    await settle(t);
    expect(find.byType(EnrollVoiceButton), findsOneWidget);
    expect(find.text(VoiceStrings.enrollAction), findsOneWidget);

    await t.tap(find.byTooltip(S.speakerActions).first);
    await settle(t);
    expect(find.text(VoiceStrings.improveAction), findsOneWidget);
    await t.tap(find.text(PS.screenTitle));
    await settle(t);
    expect(find.byType(SpeakerProfileScreen), findsOneWidget);
    expect(find.text(PS.optInTitle), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('settings: glossary and microphone; models: GGUF engine', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await pumpScreen(t, env, const SettingsScreen());
    await t.scrollUntilVisible(
      find.text(CS.glossaryTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(CS.glossaryTitle), findsOneWidget);
    await t.scrollUntilVisible(
      find.text(VoiceStrings.micSection),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(MicSettingsSection), findsOneWidget);
    await env.dispose(t);

    final env2 = UiTestEnv();
    await pumpScreen(t, env2, const ModelsScreen());
    await t.scrollUntilVisible(
      find.text(S.minutesModels),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(LocalEngineSettings), findsOneWidget);
    await env2.dispose(t);
  });

  testWidgets('recording screen shows open tasks of expected attendees', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await env.run(t, () async {
      await AppSettings(env.db).save(
        const AppSettingsData(consentAcknowledged: true, keepAudio: false),
      );
      final other = await MeetingRepository(env.db)
          .create(title: 'اجتماع سابق', status: MeetingStatus.ready);
      await TaskRepository(env.db).create(
        task: 'مراجعة العقد',
        ownerText: 'سارة',
        sourceMeetingId: other.id,
      );
    });
    await pumpApp(t, env);

    // New meeting → context form: expect سارة, then start.
    await t.tap(find.byType(FloatingActionButton));
    await settle(t);
    expect(find.byType(MicDeviceChip), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, CS.attendeeLabel), 'سارة');
    await t.ensureVisible(find.byTooltip(CS.addAttendee));
    await t.pump();
    await t.tap(find.byTooltip(CS.addAttendee));
    await t.pump();
    await t.tap(find.text(CS.startRecording));
    await settle(t, rounds: 10);

    expect(find.byType(OpenTasksBanner), findsOneWidget);
    // سارة has one open task from another meeting.
    expect(find.byType(OpenTasksBannerView), findsOneWidget);
    expect(find.byType(MicDeviceChip), findsOneWidget);

    final container = ProviderScope.containerOf(
      t.element(find.byType(OpenTasksBanner)),
    );
    final cancelled = container
        .read(meetingSessionControllerProvider.notifier)
        .cancel();
    await settle(t, rounds: 10);
    await cancelled;
    await env.dispose(t);
  });
}
