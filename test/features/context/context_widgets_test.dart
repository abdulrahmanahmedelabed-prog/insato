import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/context/context_logic.dart';
import 'package:insato/features/context/glossary_logic.dart';
import 'package:insato/features/context/glossary_screen.dart';
import 'package:insato/features/context/meeting_context_card.dart';
import 'package:insato/features/context/meeting_context_flows.dart';
import 'package:insato/features/context/meeting_context_page.dart';
import 'package:insato/features/context/strings.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';

Finder field(String label) => find.widgetWithText(TextField, label);

/// A page with a button that opens the context form and keeps its result.
class _Opener extends StatefulWidget {
  const _Opener({required this.mode});

  final MeetingContextMode mode;

  @override
  State<_Opener> createState() => _OpenerState();
}

MeetingSetup? lastResult;
bool returned = false;

class _OpenerState extends State<_Opener> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async {
          lastResult = await showMeetingContextPage(context, mode: widget.mode);
          returned = true;
        },
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  setUp(() {
    lastResult = null;
    returned = false;
  });

  group('GlossaryScreen', () {
    testWidgets('add, duplicate check, edit and delete', (t) async {
      setScreenSize(t, const Size(500, 1400));
      final env = UiTestEnv();
      await pumpScreen(t, env, const GlossaryScreen());
      expect(find.text(CS.emptyTitle), findsOneWidget);
      expect(find.text(CS.deepgramOff), findsOneWidget);

      await t.tap(find.text(CS.addTerm));
      await settle(t);
      await t.enterText(field(CS.termLabel), '  Kubernetes ');
      await t.enterText(field(CS.arSpellingLabel), 'كوبرنيتس');
      await t.tap(find.text(CS.category(GlossaryCategory.technical)));
      await t.pump();
      await t.tap(find.text(S.save));
      await settle(t, rounds: 10);
      var terms = await env.run(
        t,
        () => GlossaryRepository(env.db).getGlobal(),
      );
      expect(terms.single.term, 'Kubernetes');
      expect(terms.single.arSpelling, 'كوبرنيتس');
      expect(terms.single.category, GlossaryCategory.technical);
      expect(find.text('Kubernetes'), findsOneWidget);

      // Duplicate.
      await t.tap(find.text(CS.addTerm).last);
      await settle(t);
      await t.enterText(field(CS.termLabel), 'kubernetes');
      await t.tap(find.text(S.save));
      await t.pump();
      expect(find.text(CS.termDuplicate), findsOneWidget);
      await t.tap(find.text(S.cancel));
      await settle(t);

      // Edit.
      await t.tap(find.text('Kubernetes'));
      await settle(t);
      await t.enterText(field(CS.termLabel), 'Kubernetes (K8s)');
      await t.tap(find.text(S.save));
      await settle(t, rounds: 10);
      terms = await env.run(t, () => GlossaryRepository(env.db).getGlobal());
      expect(terms.single.term, 'Kubernetes (K8s)');

      // Delete.
      await t.tap(find.byTooltip(S.delete));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, S.delete));
      await settle(t, rounds: 10);
      terms = await env.run(t, () => GlossaryRepository(env.db).getGlobal());
      expect(terms, isEmpty);
      await env.dispose(t);
    });

    testWidgets('search, filters, speaker names, usage and export', (t) async {
      setScreenSize(t, const Size(500, 1400));
      final env = UiTestEnv();
      await env.run(t, () async {
        final g = GlossaryRepository(env.db);
        await g.add(term: 'Aramco', category: GlossaryCategory.organisation);
        await g.add(term: 'Gemini', category: GlossaryCategory.technical);
        await SpeakerRepository(env.db).create(name: 'سارة');
        await AppSettings(env.db).setAsrEngine(AppSettingsData.asrCloud);
      });
      await pumpScreen(t, env, const GlossaryScreen());
      expect(find.text('Aramco'), findsOneWidget);
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text(CS.deepgramUsage(3, 3, 50)), findsOneWidget);
      expect(find.text(CS.minutesUsage(3)), findsOneWidget);

      await t.tap(
        find.widgetWithText(
          FilterChip,
          CS.category(GlossaryCategory.technical),
        ),
      );
      await t.pump();
      expect(find.text('Aramco'), findsNothing);
      expect(find.text('Gemini'), findsOneWidget);
      await t.tap(find.widgetWithText(FilterChip, CS.allCategories));
      await t.enterText(find.byType(SearchBar), 'aram');
      await t.pump();
      expect(find.text('Aramco'), findsOneWidget);
      expect(find.text('Gemini'), findsNothing);

      await t.ensureVisible(find.text('سارة'));
      expect(find.text(CS.speakerNamesHeader), findsOneWidget);

      await t.tap(find.byTooltip(CS.glossaryMenu));
      await settle(t);
      await t.tap(find.text(CS.exportList));
      await settle(t);
      expect(env.share.copied.single.split('\n'), [
        'Aramco |  | جهة',
        'Gemini |  | مصطلح تقني',
      ]);
      await env.dispose(t);
    });

    testWidgets('import from pasted text', (t) async {
      setScreenSize(t, kPhone);
      final env = UiTestEnv();
      await pumpScreen(t, env, const GlossaryScreen());
      await t.tap(find.byTooltip(CS.glossaryMenu));
      await settle(t);
      await t.tap(find.text(CS.importList));
      await settle(t);
      await t.enterText(
        find.byType(TextField).last,
        'OpenAI | أوبن إيه آي | جهة\n | bad\nDeepgram',
      );
      await t.tap(find.text(CS.importAction));
      await settle(t, rounds: 10);
      final terms = await env.run(
        t,
        () => GlossaryRepository(env.db).getGlobal(),
      );
      expect(terms.map((x) => (x.term, x.category)), [
        ('Deepgram', GlossaryCategory.other),
        ('OpenAI', GlossaryCategory.organisation),
      ]);
      expect(find.text(CS.imported(2, 1)), findsOneWidget);
      await env.dispose(t);
    });
  });

  group('MeetingContextPage', () {
    testWidgets('builds a setup: agenda, attendees, notes, terms', (t) async {
      // Tall enough for the whole form, microphone section included.
      setScreenSize(t, const Size(500, 1800));
      final env = UiTestEnv();
      await env.run(t, () async {
        await SpeakerRepository(env.db).create(name: 'سارة');
        await SpeakerRepository(env.db).create();
      });
      await pumpScreen(
        t,
        env,
        const _Opener(mode: MeetingContextMode.beforeStart),
      );
      await t.tap(find.text('open'));
      await settle(t);
      expect(find.text(CS.setupTitle), findsOneWidget);

      await t.enterText(field(CS.titleLabel), 'لجنة المشتريات');
      for (final item in ['الميزانية', 'التوظيف']) {
        await t.enterText(field(CS.agendaItemLabel), item);
        await t.tap(find.byTooltip(CS.addAgendaItem));
        await t.pump();
      }
      // Empty item is rejected.
      await t.tap(find.byTooltip(CS.addAgendaItem));
      await t.pump();
      expect(find.text(CS.agendaItemEmpty), findsOneWidget);
      // Move "التوظيف" up.
      await t.tap(find.byTooltip(CS.moveUp).last);
      await t.pump();

      // Voice-library suggestion (only named speakers).
      expect(find.widgetWithText(ActionChip, 'سارة'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'متحدث 1'), findsNothing);
      await t.tap(find.widgetWithText(ActionChip, 'سارة'));
      await t.pump();
      expect(find.widgetWithText(ActionChip, 'سارة'), findsNothing);
      await t.enterText(field(CS.attendeeLabel), 'Omar');
      await t.tap(find.byTooltip(CS.addAttendee));
      await t.pump();
      await t.enterText(field(CS.attendeeLabel), 'omar');
      await t.tap(find.byTooltip(CS.addAttendee));
      await t.pump();
      expect(find.text(CS.attendeeDuplicate), findsOneWidget);

      await t.enterText(field(CS.notesLabel), 'متابعة العقد');
      // Let the field's scroll-into-view animation finish first.
      await settle(t);

      await t.ensureVisible(find.text(CS.addMeetingTerm));
      await settle(t);
      await t.tap(find.text(CS.addMeetingTerm));
      await settle(t);
      await t.enterText(field(CS.termLabel), 'Falcon');
      await t.tap(find.text(S.save));
      await settle(t);
      expect(find.widgetWithText(InputChip, 'Falcon'), findsOneWidget);

      await t.tap(find.text(CS.startRecording));
      await settle(t);
      expect(returned, isTrue);
      final r = lastResult!;
      expect(r.title, 'لجنة المشتريات');
      expect(r.context.agenda, ['التوظيف', 'الميزانية']);
      expect(r.context.expectedAttendees, ['سارة', 'Omar']);
      expect(r.context.contextNotes, 'متابعة العقد');
      expect(r.meetingTerms.single.term, 'Falcon');
      await env.dispose(t);
    });

    testWidgets('skip returns an empty setup; close asks before discarding', (
      t,
    ) async {
      setScreenSize(t, const Size(500, 1400));
      final env = UiTestEnv();
      await pumpScreen(
        t,
        env,
        const _Opener(mode: MeetingContextMode.beforeStart),
      );
      await t.tap(find.text('open'));
      await settle(t);
      await t.enterText(field(CS.titleLabel), 'x');
      await t.tap(find.text(CS.skipAndStart));
      await settle(t);
      expect(lastResult, same(MeetingSetup.empty));

      returned = false;
      await t.tap(find.text('open'));
      await settle(t);
      await t.enterText(field(CS.titleLabel), 'x');
      await t.tap(find.byTooltip(S.close));
      await settle(t);
      expect(find.text(CS.discardTitle), findsOneWidget);
      await t.tap(find.text(S.cancel));
      await settle(t);
      expect(returned, isFalse);
      await t.tap(find.byTooltip(S.close));
      await settle(t);
      await t.tap(find.text(CS.discard));
      await settle(t);
      expect(returned, isTrue);
      expect(lastResult, isNull);

      // Unchanged form closes at once.
      returned = false;
      await t.tap(find.text('open'));
      await settle(t);
      await t.tap(find.byTooltip(S.close));
      await settle(t);
      expect(returned, isTrue);
      expect(lastResult, isNull);
      await env.dispose(t);
    });
  });

  group('MeetingContextCard and flows', () {
    testWidgets('editing an existing meeting saves context and terms', (
      t,
    ) async {
      setScreenSize(t, const Size(500, 1400));
      final env = UiTestEnv();
      final seeded = await env.run(t, () => seedMeeting(env));
      await pumpScreen(
        t,
        env,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final m =
                  ref.watch(meetingProvider(seeded.meeting.id)).value ??
                  seeded.meeting;
              return MeetingContextCard(meeting: m);
            },
          ),
        ),
      );
      expect(find.text(CS.contextEmpty), findsOneWidget);
      await t.tap(find.text(CS.addContext));
      await settle(t, rounds: 10);
      expect(find.text(CS.editTitle), findsOneWidget);
      await t.enterText(field(CS.agendaItemLabel), 'ميزانية التسويق');
      await t.tap(find.byTooltip(CS.addAgendaItem));
      await t.pump();
      await t.ensureVisible(find.text(CS.addMeetingTerm));
      await t.tap(find.text(CS.addMeetingTerm));
      await settle(t);
      await t.enterText(field(CS.termLabel), 'Falcon');
      await t.tap(find.text(S.save).last);
      await settle(t);
      await t.tap(find.widgetWithText(TextButton, S.save));
      await settle(t, rounds: 12);

      final m = await env.run(
        t,
        () => MeetingRepository(env.db).get(seeded.meeting.id),
      );
      expect(m!.context.agenda, ['ميزانية التسويق']);
      expect(m.title, seeded.meeting.title);
      final terms = await env.run(
        t,
        () => GlossaryRepository(env.db).getForMeeting(seeded.meeting.id),
      );
      expect(terms.single.term, 'Falcon');
      expect(find.text('1. ميزانية التسويق'), findsOneWidget);
      expect(find.text(CS.meetingTermsCount(1)), findsOneWidget);
      expect(find.text(CS.editContext), findsOneWidget);
      await env.dispose(t);
    });

    testWidgets('new meeting with context starts the session', (t) async {
      setScreenSize(t, const Size(500, 1800));
      final env = UiTestEnv();
      await env.run(
        t,
        () => AppSettings(env.db).save(
          const AppSettingsData(consentAcknowledged: true, keepAudio: false),
        ),
      );
      await pumpScreen(
        t,
        env,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => FilledButton(
              onPressed: () => startNewMeetingWithContext(context, ref),
              child: const Text('new'),
            ),
          ),
        ),
      );
      await t.tap(find.text('new'));
      await settle(t, rounds: 10);
      await t.enterText(field(CS.titleLabel), 'مجلس الإدارة');
      await t.enterText(field(CS.attendeeLabel), 'Omar');
      await t.tap(find.byTooltip(CS.addAttendee));
      await t.pump();
      await t.ensureVisible(find.text(CS.addMeetingTerm));
      await t.tap(find.text(CS.addMeetingTerm));
      await settle(t);
      await t.enterText(field(CS.termLabel), 'Falcon');
      await t.tap(find.text(S.save));
      await settle(t);
      await t.tap(find.text(CS.startRecording));
      await settle(t, rounds: 12);

      final meetings = await env.run(
        t,
        () => MeetingRepository(env.db).getAll(),
      );
      expect(meetings.single.title, 'مجلس الإدارة');
      expect(meetings.single.context.expectedAttendees, ['Omar']);
      final terms = await env.run(
        t,
        () => GlossaryRepository(env.db).getForMeeting(meetings.single.id),
      );
      expect(terms.single.term, 'Falcon');
      expect(env.engines.created, 1);
      final container = ProviderScope.containerOf(
        t.element(find.byType(Scaffold).first),
      );
      final cancelled = container
          .read(meetingSessionControllerProvider.notifier)
          .cancel();
      await settle(t, rounds: 10);
      await cancelled;
      await env.dispose(t);
    });
  });

  test('GlossaryDraft equality used by the page', () {
    expect(const GlossaryDraft(term: 'a'), const GlossaryDraft(term: 'a'));
  });
}
