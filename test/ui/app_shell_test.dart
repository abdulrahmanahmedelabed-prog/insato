import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katib/core/interfaces.dart';
import 'package:katib/data/secure_settings.dart';
import 'package:katib/session/meeting_session_controller.dart';
import 'package:katib/session/providers.dart';
import 'package:katib/ui/screens/home_shell.dart';
import 'package:katib/ui/screens/meeting_detail_screen.dart';
import 'package:katib/ui/strings_ar.dart';
import 'package:katib/ui/widgets/dialogs.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'harness.dart';

void main() {
  testWidgets('phone shell is Arabic, RTL and shows the empty state', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await pumpApp(t, env);

    final ctx = t.element(find.byType(HomeShell));
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(Localizations.localeOf(ctx).languageCode, 'ar');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text(S.navMeetings), findsWidgets);
    expect(find.text(S.navSpeakers), findsOneWidget);
    expect(find.text(S.navSettings), findsOneWidget);
    expect(find.text(S.noMeetingsTitle), findsOneWidget);
    expect(find.text(S.newMeeting), findsWidgets);
    // All models installed: no banner.
    expect(find.text(S.modelsMissingTitle), findsNothing);
    await env.dispose(t);
  });

  testWidgets('the FAB shows the consent dialog on first use', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await pumpApp(t, env);

    await t.tap(find.byType(FloatingActionButton));
    await settle(t);
    expect(find.byType(ConsentDialog), findsOneWidget);
    expect(find.text(S.consentTitle), findsOneWidget);

    // Accepting is impossible until the acknowledgement is ticked.
    final accept = find.widgetWithText(FilledButton, S.consentAccept);
    expect(t.widget<FilledButton>(accept).onPressed, isNull);
    await t.ensureVisible(find.byType(Checkbox));
    await t.pump();
    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(t.widget<FilledButton>(accept).onPressed, isNotNull);

    // Cancelling starts nothing and records no consent.
    await t.tap(find.text(S.cancel));
    await settle(t);
    expect(find.byType(ConsentDialog), findsNothing);
    final s = await env.run(t, () => AppSettings(env.db).load());
    expect(s.consentAcknowledged, isFalse);
    expect(env.audio.started, isFalse);
    await env.dispose(t);
  });

  testWidgets('after consent was given the FAB starts recording directly', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await env.run(t, () async {
      await AppSettings(env.db).save(
        const AppSettingsData(consentAcknowledged: true, keepAudio: false),
      );
    });
    await pumpApp(t, env);

    await t.tap(find.byType(FloatingActionButton));
    await settle(t, rounds: 10);
    expect(find.byType(ConsentDialog), findsNothing);
    expect(env.audio.started, isTrue);
    expect(find.text(S.stateRecording), findsOneWidget);
    expect(find.text(S.stop), findsOneWidget);

    // Discard the recording: confirmed, then everything is removed.
    await t.tap(find.text(S.discardRecording));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, S.discard));
    await settle(t, rounds: 10);
    expect(env.audio.started, isFalse);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text(S.noMeetingsTitle), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('accepting consent stores it and starts the session', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await env.run(t, () async {
      await AppSettings(env.db).setKeepAudio(false);
    });
    await pumpApp(t, env);

    await t.tap(find.byType(FloatingActionButton));
    await settle(t);
    await t.ensureVisible(find.byType(Checkbox));
    await t.pump();
    await t.tap(find.byType(Checkbox));
    await t.pump();
    await t.tap(find.text(S.consentAccept));
    await settle(t, rounds: 10);

    final s = await env.run(t, () => AppSettings(env.db).load());
    expect(s.consentAcknowledged, isTrue);
    expect(env.audio.started, isTrue);
    final container = ProviderScope.containerOf(
      t.element(find.byType(HomeShell)),
    );
    expect(
      container.read(meetingSessionControllerProvider).phase,
      SessionPhase.recording,
    );
    await t.runAsync(
      () => container.read(meetingSessionControllerProvider.notifier).cancel(),
    );
    await settle(t);
    await env.dispose(t);
  });

  testWidgets('a missing model shows the banner with a link', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv(
      modelStates: {'silero-vad': const ModelState(ModelStatus.ready)},
    );
    await pumpApp(t, env);
    expect(find.text(S.modelsMissingTitle), findsOneWidget);
    expect(find.textContaining('Whisper Turbo'), findsOneWidget);
    await t.tap(find.text(S.openModels));
    await settle(t);
    expect(find.text(S.downloadRequired), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('meetings list shows meetings, search filters them', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await env.run(t, () async {
      await seedMeeting(env);
      await seedMeeting(env, title: 'مراجعة المشروع', withMinutes: false);
    });
    await pumpApp(t, env);

    expect(find.text('اجتماع الميزانية'), findsOneWidget);
    expect(find.text('مراجعة المشروع'), findsOneWidget);
    expect(find.text(S.statusReady), findsNWidgets(2));
    expect(find.text(S.speakersCount(2)), findsNWidgets(2));

    await t.enterText(find.byType(SearchBar), 'الميزانيه');
    await settle(t);
    expect(find.text('اجتماع الميزانية'), findsOneWidget);
    expect(find.text('مراجعة المشروع'), findsNothing);
    await env.dispose(t);
  });

  testWidgets('tapping a meeting on a phone opens its detail page', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await env.run(t, () => seedMeeting(env));
    await pumpApp(t, env);

    await t.tap(find.text('اجتماع الميزانية'));
    await settle(t);
    expect(find.byType(MeetingDetailScreen), findsOneWidget);
    expect(find.text(S.tabMinutes), findsOneWidget);
    expect(find.text('ناقش الفريق ميزانية التسويق للربع القادم.'), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('desktop uses a navigation rail and two panes', (t) async {
    setScreenSize(t, kDesktop);
    final env = UiTestEnv();
    await env.run(t, () => seedMeeting(env));
    await pumpApp(t, env);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text(S.selectMeetingTitle), findsOneWidget);

    await t.tap(find.text('اجتماع الميزانية'));
    await settle(t);
    // Detail shown beside the list (no page pushed).
    expect(find.text('اجتماع الميزانية'), findsWidgets);
    expect(find.byType(MeetingDetailScreen), findsOneWidget);
    expect(find.text(S.selectMeetingTitle), findsNothing);
    expect(find.text('اعتماد ميزانية التسويق'), findsOneWidget);

    // Switch to the voice library from the rail.
    await t.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text(S.navSpeakers),
      ),
    );
    await settle(t);
    expect(find.text(S.voiceLibrary), findsOneWidget);
    expect(find.text('سارة'), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('Ctrl+N starts a new meeting (consent first)', (t) async {
    setScreenSize(t, kDesktop);
    final env = UiTestEnv();
    await pumpApp(t, env);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyN);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(t);
    expect(find.byType(ConsentDialog), findsOneWidget);
    await t.tap(find.text(S.cancel));
    await settle(t);
    await env.dispose(t);
  });
}
