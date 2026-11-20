import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/evidence/evidence.dart';
import 'package:insato/features/profiles/profile_evidence.dart';
import 'package:insato/features/profiles/profile_screen.dart';
import 'package:insato/features/profiles/profile_service.dart';
import 'package:insato/features/profiles/strings.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';
import '../evidence/fake_player.dart';

SpeakerProfileService serviceOf(UiTestEnv env) => SpeakerProfileService(
  meetings: MeetingRepository(env.db),
  segments: SegmentRepository(env.db),
  speakers: SpeakerRepository(env.db),
  tasks: TaskRepository(env.db),
  profiles: SpeakerProfileRepository(env.db),
  notes: SpeakerMeetingNotesRepository(env.db),
  settings: AppSettings(env.db),
  clock: () => DateTime(2026, 11, 19, 12),
);

const String kSensitive = 'بدا متوتراً وغاضباً أثناء النقاش';

/// A meeting where سارة speaks, with notes and a task; سارة opted in.
Future<({Meeting meeting, Speaker sara, Speaker auto})> seedProfile(
  UiTestEnv env, {
  bool enable = true,
  bool build = true,
}) async {
  final seeded = await seedMeeting(env);
  final sara = seeded.sara;
  await SpeakerMeetingNotesRepository(env.db)
      .replaceForMeeting(seeded.meeting.id, {
        sara.id: const MinutesSpeakerNote(
          speaker: 'سارة',
          knowledge: [
            SpeakerKnowledgeNote(
              domain: 'مالية',
              demonstrated: 'شرح بنود ميزانية التسويق',
              level: DemonstrationLevel.explained,
              evidence: [0],
            ),
          ],
          contributions: [
            SpeakerContributionNote(
              kind: ContributionKind.proposed,
              text: 'اقتراح اعتماد الميزانية هذا الأسبوع',
              evidence: [0],
            ),
          ],
          style: [
            SpeakerStyleNote(observation: kSensitive, evidence: [0]),
            SpeakerStyleNote(
              observation: 'افتتاح الاجتماع وتحديد موضوعه',
              evidence: [0],
            ),
          ],
          summary: 'افتتاح الاجتماع وطرح موضوع الميزانية.',
        ),
      });
  await TaskRepository(env.db).create(
    task: 'إعداد تقرير الميزانية',
    ownerSpeakerId: sara.id,
    ownerText: 'سارة',
    sourceMeetingId: seeded.meeting.id,
    evidenceSegmentIds: const [0],
  );
  if (enable) {
    await SpeakerRepository(env.db).setProfileEnabled(sara.id, true);
    await AppSettings(env.db).setProfilesFeatureAcknowledged(true);
    if (build) await serviceOf(env).rebuild(sara.id);
  }
  return seeded;
}

Future<void> pumpProfile(
  WidgetTester t,
  UiTestEnv env,
  String speakerId, {
  EvidenceAudioLocation location = EvidenceAudioLocation.notKept,
  List<FakeEvidencePlayer>? players,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...env.overrides,
        evidenceAudioResolverProvider.overrideWithValue((_) async => location),
        evidencePlayerFactoryProvider.overrideWithValue(() {
          final p = FakeEvidencePlayer();
          players?.add(p);
          return p;
        }),
      ],
      retry: (_, _) => null,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: InsatoTheme.light(),
        home: SpeakerProfileScreen(speakerId: speakerId),
      ),
    ),
  );
  await settle(t);
}

Future<void> scrollTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pump();
}

void main() {
  group('pure helpers', () {
    test('profilePercent rounds and clamps', () {
      expect(profilePercent(0.456), 46);
      expect(profilePercent(-1), 0);
      expect(profilePercent(2), 100);
    });

    test('line sheet reason follows the evidence notice', () {
      expect(profileLineSheetReason(ES.audioNotKept), PS.lineSheetNoAudio);
      expect(
        profileLineSheetReason(ES.audioStillRecording),
        PS.lineSheetRecording,
      );
      expect(profileLineSheetReason(ES.playbackFailed), PS.lineSheetFailed);
      expect(profileLineSheetReason(null), PS.lineSheetNoAudio);
    });

    test('meeting label: title and date, or deleted', () {
      final m = Meeting(
        id: 'm',
        title: 'اجتماع الميزانية',
        createdAt: DateTime(2026, 11, 19),
        status: MeetingStatus.ready,
      );
      expect(
        profileMeetingLabel({'m': m}, 'm'),
        PS.evidenceMeeting('اجتماع الميزانية', DateTime(2026, 11, 19)),
      );
      expect(profileMeetingLabel({'m': m}, 'x'), PS.deletedMeeting);
    });
  });

  testWidgets('not enabled: opt-in tile and notice, no profile actions', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(t, () => seedProfile(env, enable: false));
    await pumpProfile(t, env, s.sara.id);

    expect(find.text(PS.screenTitleFor('سارة')), findsOneWidget);
    expect(find.text(PS.optInTitle), findsOneWidget);
    expect(find.textContaining(PS.optInNotice), findsOneWidget);
    expect(find.text(PS.notEnabledTitle), findsOneWidget);
    expect(find.byTooltip(PS.rebuildTooltip), findsNothing);
    expect(find.byTooltip(PS.deleteProfile), findsNothing);
    final tile = t.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isFalse);
    await env.dispose(t);
  });

  testWidgets('enabling shows the one-time notice, then builds the profile', (
    t,
  ) async {
    setScreenSize(t, const Size(500, 1400));
    final env = UiTestEnv();
    final s = await env.run(t, () => seedProfile(env, enable: false));
    await pumpProfile(t, env, s.sara.id);

    await t.tap(find.byType(SwitchListTile));
    await settle(t);
    expect(find.text(PS.noticeTitle), findsOneWidget);
    await t.tap(find.text(PS.noticeAccept));
    await settle(t, rounds: 12);

    final speaker = await env.run(
      t,
      () => SpeakerRepository(env.db).get(s.sara.id),
    );
    expect(speaker!.profileEnabled, isTrue);
    final record = await env.run(
      t,
      () => SpeakerProfileRepository(env.db).get(s.sara.id),
    );
    expect(record, isNotNull);
    expect(find.text(PS.disclaimer), findsOneWidget);
    expect(find.byTooltip(PS.rebuildTooltip), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('shows every section with evidence; guardrails applied', (
    t,
  ) async {
    setScreenSize(t, const Size(500, 1200));
    final env = UiTestEnv();
    final s = await env.run(t, () => seedProfile(env));
    await pumpProfile(t, env, s.sara.id);

    expect(find.text(PS.disclaimer), findsOneWidget);
    expect(find.text(PS.omittedNote(1)), findsOneWidget);
    // Knowledge: the domain card, expanded to show the evidence.
    expect(find.text('مالية'), findsOneWidget);
    await t.tap(find.text('مالية'));
    await settle(t);
    expect(find.text('شرح بنود ميزانية التسويق'), findsOneWidget);
    expect(
      find.text(PS.levelLabel(DemonstrationLevel.explained)),
      findsOneWidget,
    );

    await scrollTo(t, find.text(PS.sectionLanguages));
    expect(find.text('العربية'), findsOneWidget);

    await scrollTo(t, find.text(PS.statTalkShare));
    expect(find.text(PS.statTurns), findsOneWidget);
    expect(find.text(PS.statsLowEvidence), findsOneWidget);
    await scrollTo(t, find.text('افتتاح الاجتماع وتحديد موضوعه'));
    // The sensitive observation never reaches the screen.
    expect(find.text(kSensitive), findsNothing);

    await scrollTo(t, find.text('اقتراح اعتماد الميزانية هذا الأسبوع'));
    expect(
      find.text('${PS.contributionKind(ContributionKind.proposed)} · 1'),
      findsOneWidget,
    );
    await scrollTo(t, find.text('اعتماد ميزانية التسويق'));
    expect(find.text(PS.decisionsTitle), findsOneWidget);
    await scrollTo(t, find.text('إعداد تقرير الميزانية'));
    expect(find.text(PS.taskStatus(TaskStatus.open)), findsWidgets);

    await scrollTo(t, find.text('افتتاح الاجتماع وطرح موضوع الميزانية.'));
    expect(find.text(PS.meetingSummaries), findsOneWidget);
    expect(find.textContaining('المشاركة المرصودة'), findsOneWidget);

    // Evidence chips are labelled with the meeting.
    expect(
      find.text(PS.evidenceMeeting('اجتماع الميزانية', s.meeting.createdAt)),
      findsWidgets,
    );
    await env.dispose(t);
  });

  testWidgets('evidence without audio shows the cited line', (t) async {
    setScreenSize(t, const Size(500, 1200));
    final env = UiTestEnv();
    final s = await env.run(t, () => seedProfile(env));
    await pumpProfile(t, env, s.sara.id);

    await t.tap(find.text('مالية'));
    await settle(t);
    final chip = find.byTooltip(ES.showLineAt(0)).first;
    await t.tap(chip);
    await settle(t);
    expect(find.text(PS.lineSheetTitle), findsOneWidget);
    expect(find.text('مرحبًا بكم في اجتماع الميزانية'), findsOneWidget);
    expect(find.text(PS.lineSheetNoAudio), findsOneWidget);
    expect(find.text(PS.openMeeting), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('evidence with audio plays in the docked player', (t) async {
    setScreenSize(t, const Size(500, 1200));
    final env = UiTestEnv();
    final s = await env.run(t, () => seedProfile(env));
    final players = <FakeEvidencePlayer>[];
    await pumpProfile(
      t,
      env,
      s.sara.id,
      location: const EvidenceAudioLocation(
        EvidenceAudioStatus.available,
        '/r/x.wav',
      ),
      players: players,
    );
    await t.tap(find.text('مالية'));
    await settle(t);
    await t.tap(find.byTooltip(ES.playFrom(0)).first);
    await settle(t);
    expect(find.text(PS.lineSheetTitle), findsNothing);
    expect(find.byType(EvidencePlayerBar), findsOneWidget);
    expect(players, hasLength(1));
    expect(players.single.calls, containsAll(['open:/r/x.wav', 'play']));
    await env.dispose(t);
  });

  testWidgets('rebuild recomputes; delete removes profile and opt-in', (
    t,
  ) async {
    setScreenSize(t, const Size(500, 1200));
    final env = UiTestEnv();
    final s = await env.run(t, () => seedProfile(env));
    // Drop the stored profile so the rebuild visibly writes it again.
    await env.run(t, () => SpeakerProfileRepository(env.db).delete(s.sara.id));
    await pumpProfile(t, env, s.sara.id);
    expect(find.text(PS.emptyTitle), findsOneWidget);

    await t.tap(find.byTooltip(PS.rebuildTooltip));
    await settle(t, rounds: 12);
    expect(find.text(PS.rebuilt), findsOneWidget);
    expect(find.text(PS.disclaimer), findsOneWidget);

    await t.tap(find.byTooltip(PS.deleteProfile));
    await settle(t);
    expect(find.text(PS.deleteTitle), findsOneWidget);
    await t.tap(find.text(S.delete));
    await settle(t, rounds: 12);

    final record = await env.run(
      t,
      () => SpeakerProfileRepository(env.db).get(s.sara.id),
    );
    expect(record, isNull);
    final notes = await env.run(
      t,
      () => SpeakerMeetingNotesRepository(env.db).getForSpeaker(s.sara.id),
    );
    expect(notes, isEmpty);
    final speaker = await env.run(
      t,
      () => SpeakerRepository(env.db).get(s.sara.id),
    );
    expect(speaker!.profileEnabled, isFalse);
    expect(find.text(PS.notEnabledTitle), findsOneWidget);
    expect(find.text(PS.deletedSnack), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('missing speaker', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await pumpProfile(t, env, 'nobody');
    expect(find.text(PS.speakerMissing), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('wide window keeps the readable layout', (t) async {
    setScreenSize(t, kDesktop);
    final env = UiTestEnv();
    final s = await env.run(t, () => seedProfile(env));
    await pumpProfile(t, env, s.sara.id);
    expect(find.text(PS.disclaimer), findsOneWidget);
    expect(t.takeException(), isNull);
    await env.dispose(t);
  });
}
