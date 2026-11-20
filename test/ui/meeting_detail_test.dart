import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/codes/strings.dart';
import 'package:insato/features/groq/strings.dart';
import 'package:insato/session/minutes_engines.dart';
import 'package:insato/ui/screens/meeting_detail_screen.dart';
import 'package:insato/ui/screens/meeting_transcript_tab.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:insato/ui/widgets/minutes_view.dart';
import 'package:material_ui/material_ui.dart';

import '../session/fakes.dart';
import 'harness.dart';

void main() {
  testWidgets('minutes tab renders every section', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));

    expect(find.byType(MinutesView), findsOneWidget);
    expect(find.text('محضر اجتماع الميزانية'), findsOneWidget);
    expect(find.text(S.summary), findsOneWidget);
    expect(
      find.text('ناقش الفريق ميزانية التسويق للربع القادم.'),
      findsOneWidget,
    );
    expect(find.text(S.decisions), findsOneWidget);
    expect(find.text('اعتماد ميزانية التسويق'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('إعداد تقرير الميزانية'),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('إعداد تقرير الميزانية'), findsOneWidget);
    expect(find.text(S.regenerateMinutes), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('regenerating minutes runs the engine and shows the result', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv()..minutes = FakeMinutesEngine();
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));

    await t.tap(find.text(S.regenerateMinutes));
    await settle(t, rounds: 12);
    expect(env.minutes!.calls, 1);
    expect(find.text('ملخص 2 مقاطع'), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('a used-up daily quota offers the other free engine once', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final engine = _QuotaThenOkEngine();
    final env = UiTestEnv()..minutes = engine;
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));

    await t.tap(find.text(S.regenerateMinutes));
    await settle(t, rounds: 12);
    expect(find.text(GS.quotaOffer('Gemini', 'Groq')), findsOneWidget);
    final offer = find.text(GS.useAlternative('Groq'));
    expect(offer, findsOneWidget);

    await t.tap(offer);
    await settle(t, rounds: 12);
    expect(engine.calls, 2);
    // The second run was forced onto Groq; Settings were not changed.
    expect(engine.overrides, [null, 'groq']);
    expect(find.text(GS.useAlternative('Groq')), findsNothing);
    await env.dispose(t);
  });

  testWidgets('without minutes or key the API-key prompt is shown', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env, withMinutes: false));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));

    expect(find.text(S.noMinutesTitle), findsOneWidget);
    expect(find.text(S.apiKeyMissingTitle), findsOneWidget);
    expect(find.text(S.addApiKey), findsOneWidget);

    // Generating without a key fails with the Arabic message.
    await t.ensureVisible(find.text(S.generateMinutes));
    await t.pump();
    await t.tap(find.text(S.generateMinutes));
    await settle(t, rounds: 10);
    expect(find.textContaining('مفتاح محرك المحضر غير مضبوط'), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('transcript lays out each segment in its own direction', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));
    await t.tap(find.text(S.tabTranscript));
    await settle(t);

    final en = t.widget<Text>(
      find.text('We should finalize the marketing budget this week'),
    );
    expect(en.textDirection, TextDirection.ltr);
    final ar = t.widget<Text>(find.text('مرحبًا بكم في اجتماع الميزانية'));
    expect(ar.textDirection, TextDirection.rtl);
    // Timestamps are forced LTR.
    final ts = t.widget<Text>(find.text('00:00:05'));
    expect(ts.textDirection, TextDirection.ltr);
    await env.dispose(t);
  });

  testWidgets('tapping a speaker renames it with the memory explanation', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));
    await t.tap(find.text(S.tabTranscript));
    await settle(t);

    await t.tap(find.bySemanticsLabel(seeded.auto.name).first);
    await settle(t);
    expect(find.text(S.renameSpeakerBody), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Omar');
    await t.tap(find.text(S.save));
    await settle(t, rounds: 10);

    final sp = await env.run(
      t,
      () => SpeakerRepository(env.db).get(seeded.auto.id),
    );
    expect(sp!.name, 'Omar');
    expect(sp.isNamedByUser, isTrue);
    await env.dispose(t);
  });

  testWidgets('a segment can be reassigned to another speaker', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));
    await t.tap(find.text(S.tabTranscript));
    await settle(t);

    await t.tap(find.text('We should finalize the marketing budget this week'));
    await settle(t);
    expect(find.byType(SegmentSheet), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'سارة'));
    await settle(t, rounds: 10);

    final segs = await env.run(
      t,
      () => SegmentRepository(env.db).getForMeeting(seeded.meeting.id),
    );
    final en = segs.firstWhere((s) => s.text.startsWith('We'));
    expect(en.speakerId, seeded.sara.id);
    expect(en.speakerLocked, isTrue);
    await env.dispose(t);
  });

  testWidgets('speakers tab shows talk-time shares', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));
    await t.tap(find.text(S.tabSpeakers));
    await settle(t);

    expect(find.text('سارة'), findsOneWidget);
    expect(find.text(seeded.auto.name), findsOneWidget);
    expect(find.textContaining('50٪'), findsNWidgets(2));
    await env.dispose(t);
  });

  testWidgets('share sends the plain-text minutes', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));

    await t.tap(find.byTooltip(S.shareText));
    await settle(t, rounds: 10);
    expect(env.share.sharedTexts, hasLength(1));
    expect(env.share.sharedTexts.single, contains('اعتماد ميزانية التسويق'));
    await env.dispose(t);
  });

  testWidgets('shared codes are checked against the transcript', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () async {
      final s = await seedMeeting(env);
      final meetings = MeetingRepository(env.db);
      final m = (await meetings.get(s.meeting.id))!;
      await meetings.saveMinutes(
        m.id,
        m.minutes!.copyWith(
          codes: const MinutesCodes(
            references: [
              ReferenceItem(
                kind: ReferenceKind.other,
                verbatim: 'marketing budget',
                normalized: 'marketing budget',
                context: 'الميزانية',
                speaker: 'سارة',
                evidence: [1],
              ),
            ],
          ),
        ),
      );
      return s;
    });
    await pumpScreen(t, env, MeetingDetailScreen(meetingId: seeded.meeting.id));
    await t.tap(find.byTooltip(S.shareText));
    await settle(t, rounds: 10);
    final text = env.share.sharedTexts.single;
    expect(text, contains('00:00:05'));
    expect(text, isNot(contains(KS.noEvidenceToVerify)));
    expect(text, contains(KS.verified));
    await env.dispose(t);
  });
}

/// Fails like an exhausted Gemini daily quota first, then succeeds;
/// records the engine forced for each run.
class _QuotaThenOkEngine extends FakeMinutesEngine {
  final List<String?> overrides = [];

  @override
  Future<Minutes> generate({
    required Meeting meeting,
    required List<TranscriptSegment> segments,
    required Map<String, Speaker> speakersById,
    void Function(double progress, String status)? onProgress,
    MinutesInputs inputs = MinutesInputs.none,
  }) async {
    overrides.add(currentMinutesEngineOverride);
    if (overrides.length == 1) {
      calls++;
      throw MinutesQuotaExhaustedException(
        GS.quotaOffer('Gemini', 'Groq'),
        exhaustedEngine: 'gemini',
        alternativeEngine: 'groq',
      );
    }
    return super.generate(
      meeting: meeting,
      segments: segments,
      speakersById: speakersById,
      onProgress: onProgress,
      inputs: inputs,
    );
  }
}
