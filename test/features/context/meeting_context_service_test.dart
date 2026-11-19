import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/context/context_logic.dart';
import 'package:insato/features/context/glossary_logic.dart';
import 'package:insato/features/context/meeting_context_service.dart';
import 'package:insato/features/context/session_keyterms.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/session/providers.dart';

import '../../session/fakes.dart';

/// Records the upcoming setup visible while the engines are created.
class _SpyEngines extends FakeEnginesFactory {
  MeetingSetup? Function()? read;
  MeetingSetup? seen;

  @override
  Future<SessionEngines> create(SessionEngineRequest request) {
    seen = read?.call();
    return super.create(request);
  }
}

void main() {
  late AppDatabase db;
  late Directory tmp;
  late _SpyEngines engines;
  late ProviderContainer container;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('insato_ctx_');
    engines = _SpyEngines();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
        appPathsProvider.overrideWithValue(
          AppPaths(documentsDir: () async => tmp, supportDir: () async => tmp),
        ),
        sessionAudioSourceProvider.overrideWithValue(FakeAudioSource()),
        sessionPlatformHooksProvider.overrideWithValue(FakeHooks()),
        sessionEnginesFactoryProvider.overrideWithValue(engines),
        minutesEngineFactoryProvider.overrideWithValue(() async => null),
      ],
    );
    engines.read = () => container.read(upcomingMeetingSetupProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await tmp.delete(recursive: true);
  });

  MeetingContextService service() =>
      container.read(meetingContextServiceProvider);

  test('syncMeetingTerms stores, updates and removes meeting terms', () async {
    final m = await MeetingRepository(db).create(title: 'م');
    final glossary = GlossaryRepository(db);
    await glossary.add(term: 'Global');
    await service().syncMeetingTerms(m.id, const [
      GlossaryDraft(term: 'Falcon', category: GlossaryCategory.technical),
      GlossaryDraft(term: 'Hawk'),
    ]);
    var terms = await glossary.getForMeeting(m.id);
    expect(terms.map((t) => t.term), ['Falcon', 'Hawk']);
    final falcon = terms.first;

    await service().syncMeetingTerms(m.id, [
      GlossaryDraft(
        id: falcon.id,
        term: 'Falcon X',
        arSpelling: 'فالكون',
        category: GlossaryCategory.technical,
      ),
    ]);
    terms = await glossary.getForMeeting(m.id);
    expect(terms.single.id, falcon.id);
    expect(terms.single.term, 'Falcon X');
    expect(terms.single.arSpelling, 'فالكون');
    // The global glossary is untouched.
    expect((await glossary.getGlobal()).map((t) => t.term), ['Global']);
  });

  test('loadSetup and save round-trip a meeting context', () async {
    final meetings = MeetingRepository(db);
    final m = await meetings.create(title: 'قديم');
    await GlossaryRepository(db).add(term: 'Falcon', meetingId: m.id);
    final setup = await service().loadSetup(m);
    expect(setup.title, 'قديم');
    expect(setup.meetingTerms.single.term, 'Falcon');

    await service().save(
      m,
      MeetingSetup(
        title: ' جديد ',
        context: const MeetingContext(
          agenda: ['الميزانية', ' التوظيف '],
          expectedAttendees: ['سارة', 'سارة'],
          contextNotes: 'متابعة',
        ),
        meetingTerms: [
          ...setup.meetingTerms,
          const GlossaryDraft(term: 'Osprey'),
        ],
      ),
    );
    final saved = (await meetings.get(m.id))!;
    expect(saved.title, 'جديد');
    expect(saved.context.agenda, ['الميزانية', 'التوظيف']);
    expect(saved.context.expectedAttendees, ['سارة']);
    expect(saved.context.contextNotes, 'متابعة');
    expect(
      (await GlossaryRepository(db).getForMeeting(m.id)).map((t) => t.term),
      ['Falcon', 'Osprey'],
    );
  });

  test('save throws for a deleted meeting', () async {
    final meetings = MeetingRepository(db);
    final m = await meetings.create(title: 'x');
    await meetings.delete(m.id);
    await expectLater(
      service().save(m, const MeetingSetup(title: 'y')),
      throwsStateError,
    );
  });

  test('startWithSetup starts the session with the context and terms '
      'and exposes the setup while the engines are created', () async {
    final r = await service().startWithSetup(
      const MeetingSetup(
        title: 'لجنة',
        context: MeetingContext(agenda: ['أ'], expectedAttendees: ['Omar']),
        meetingTerms: [GlossaryDraft(term: 'Falcon')],
      ),
    );
    expect(r.termsSaved, isTrue);
    final meeting = (await MeetingRepository(db).get(r.meetingId))!;
    expect(meeting.title, 'لجنة');
    expect(meeting.context.agenda, ['أ']);
    expect(meeting.context.expectedAttendees, ['Omar']);
    expect(
      (await GlossaryRepository(db).getForMeeting(r.meetingId)).single.term,
      'Falcon',
    );
    expect(engines.seen?.context.expectedAttendees, ['Omar']);
    expect(container.read(upcomingMeetingSetupProvider), isNull);
    expect(await AppSettings(db).consentAcknowledged, isTrue);
    await container.read(meetingSessionControllerProvider.notifier).cancel();
  });

  test('startWithSetup clears the upcoming setup when start fails', () async {
    await container
        .read(meetingSessionControllerProvider.notifier)
        .start(consentGiven: true);
    await expectLater(
      service().startWithSetup(const MeetingSetup(title: 'x')),
      throwsA(anything),
    );
    expect(container.read(upcomingMeetingSetupProvider), isNull);
    await container.read(meetingSessionControllerProvider.notifier).cancel();
  });

  test(
    'resolveSessionKeyterms combines upcoming, speakers and global',
    () async {
      final speakers = SpeakerRepository(db);
      await speakers.create(name: 'سارة');
      await speakers.create();
      final glossary = GlossaryRepository(db);
      await glossary.add(term: 'Kubernetes', arSpelling: 'كوبرنيتس');
      final m = await MeetingRepository(db).create(title: 'm');
      await glossary.add(term: 'Other meeting term', meetingId: m.id);
      final keys = await resolveSessionKeyterms(
        glossary: glossary,
        speakers: speakers,
        upcoming: const MeetingSetup(
          context: MeetingContext(expectedAttendees: ['Omar']),
          meetingTerms: [GlossaryDraft(term: 'Falcon')],
        ),
      );
      expect(keys, ['Falcon', 'Omar', 'سارة', 'Kubernetes', 'كوبرنيتس']);
      expect(
        await resolveSessionKeyterms(glossary: glossary, speakers: speakers),
        ['سارة', 'Kubernetes', 'كوبرنيتس'],
      );
    },
  );
}
