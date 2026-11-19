import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/profiles/profile_model.dart';
import 'package:insato/features/profiles/profile_service.dart';
import 'package:insato/session/providers.dart';

import '../../session/fakes.dart';

/// Exposes a provider [Ref] to the test.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late AppDatabase db;
  late SpeakerRepository speakers;
  late MeetingRepository meetings;
  late SegmentRepository segments;
  late SpeakerProfileRepository profiles;
  late SpeakerMeetingNotesRepository notes;
  late TaskRepository tasks;
  late SpeakerProfileService service;
  late Speaker sara;
  late Speaker omar;
  late Meeting m1;

  Future<Meeting> addMeeting(
    String id,
    DateTime at,
    List<(String speaker, int start, int end, String text, String lang)> segs,
  ) async {
    final m = await meetings.create(
      id: id,
      title: 'اجتماع $id',
      createdAt: at,
      status: MeetingStatus.ready,
    );
    await segments.insertAll([
      for (var i = 0; i < segs.length; i++)
        TranscriptSegment(
          id: '',
          meetingId: m.id,
          index: i,
          startMs: segs[i].$2,
          endMs: segs[i].$3,
          text: segs[i].$4,
          speakerId: segs[i].$1,
          language: segs[i].$5,
        ),
    ]);
    return m;
  }

  setUp(() async {
    db = memoryDb();
    speakers = SpeakerRepository(db);
    meetings = MeetingRepository(db);
    segments = SegmentRepository(db);
    profiles = SpeakerProfileRepository(db);
    notes = SpeakerMeetingNotesRepository(db);
    tasks = TaskRepository(db);
    service = SpeakerProfileService(
      meetings: meetings,
      segments: segments,
      speakers: speakers,
      tasks: tasks,
      profiles: profiles,
      notes: notes,
      settings: AppSettings(db),
      clock: () => DateTime(2026, 11, 19, 12),
    );
    sara = await speakers.create(name: 'سارة');
    omar = await speakers.create(name: 'عمر');
    m1 = await addMeeting('m1', DateTime(2026, 10, 1), [
      (sara.id, 0, 10000, 'لنراجع الميزانية؟', 'ar'),
      (omar.id, 10000, 20000, 'موافق', 'ar'),
      (sara.id, 20000, 30000, 'the budget is final', 'en'),
    ]);
  });

  tearDown(() => db.close());

  test('rebuild stores nothing for a speaker who did not opt in', () async {
    expect(await service.rebuild(sara.id), isNull);
    expect(await service.rebuild('missing'), isNull);
    expect(await profiles.getAll(), isEmpty);
  });

  test('enabling acknowledges the notice and builds from past meetings', () async {
    await service.setEnabled(sara.id, true);
    expect((await AppSettings(db).load()).profilesFeatureAcknowledged, isTrue);
    expect((await speakers.get(sara.id))!.profileEnabled, isTrue);
    final record = (await profiles.get(sara.id))!;
    expect(record.updatedAt, DateTime(2026, 11, 19, 12));
    final p = SpeakerProfile.tryParse(record.profile)!;
    expect(p.speakerName, 'سارة');
    expect(p.totals.meetings, 1);
    expect(p.totals.speakingMs, 20000);
    expect(p.totals.talkShare, closeTo(2 / 3, 1e-9));
    expect(p.totals.turns, 2);
    expect(p.totals.questions, 1);
    expect(p.totals.languages.map((l) => l.code), ['ar', 'en']);
    expect(await profiles.get(omar.id), isNull);
  });

  test('update after a meeting merges notes, tasks and decisions '
      'incrementally', () async {
    await service.setEnabled(sara.id, true);
    final m2 = await addMeeting('m2', DateTime(2026, 11, 1), [
      (omar.id, 0, 5000, 'ما الخطة؟', 'ar'),
      (sara.id, 5000, 25000, 'أقترح تأجيل الإطلاق', 'ar'),
    ]);
    await meetings.saveMinutes(
      m2.id,
      Minutes(
        title: 'محضر',
        summary: 's',
        attendees: const [],
        topics: const [],
        decisions: const [
          MinutesDecision(
            text: 'تأجيل الإطلاق',
            proposedBy: 'سارة',
            evidence: [1],
          ),
        ],
        actionItems: const [],
        openQuestions: const [],
        languagesDetected: const [],
        generatedAt: DateTime(2026, 11, 1),
        model: 'm',
      ),
    );
    await notes.replaceForMeeting(m2.id, {
      sara.id: const MinutesSpeakerNote(
        speaker: 'سارة',
        knowledge: [
          SpeakerKnowledgeNote(
            domain: 'إدارة المشاريع',
            demonstrated: 'رتّبت مراحل الإطلاق',
            level: DemonstrationLevel.led,
            evidence: [1],
          ),
        ],
        summary: 'اقترحت تأجيل الإطلاق.',
      ),
    });
    await tasks.create(
      task: 'تحديث الجدول',
      ownerSpeakerId: sara.id,
      sourceMeetingId: m2.id,
      evidenceSegmentIds: const [1],
    );
    // Change m1 afterwards: the incremental update must not recompute it.
    await segments.insertAll([
      TranscriptSegment(
        id: '',
        meetingId: m1.id,
        index: 3,
        startMs: 30000,
        endMs: 90000,
        text: 'إضافة',
        speakerId: sara.id,
        language: 'ar',
      ),
    ]);

    final updated = await service.updateAfterMeeting(m2.id);
    expect(updated, [sara.id]);
    var p = SpeakerProfile.tryParse((await profiles.get(sara.id))!.profile)!;
    expect(p.perMeeting.map((m) => m.meetingId), ['m1', 'm2']);
    expect(p.perMeeting.first.speakingMs, 20000, reason: 'm1 kept as stored');
    expect(p.perMeeting.last.speakingMs, 20000);
    expect(p.perMeeting.last.decisions.single.text, 'تأجيل الإطلاق');
    expect(p.knowledge.single.domain, 'إدارة المشاريع');
    expect(p.summaries.single.summary, 'اقترحت تأجيل الإطلاق.');
    expect(p.tasks.owned, 1);
    final record = (await profiles.get(sara.id))!;
    expect(
      record.evidence,
      contains(const EvidenceRef(meetingId: 'm2', segmentIndex: 1)),
    );

    // A meeting without opted-in speakers touches nothing.
    final m3 = await addMeeting('m3', DateTime(2026, 11, 2), [
      (omar.id, 0, 5000, 'x', 'ar'),
    ]);
    expect(await service.updateAfterMeeting(m3.id), isEmpty);

    // Rebuild recomputes every meeting.
    p = (await service.rebuild(sara.id))!;
    expect(p.perMeeting.first.speakingMs, 80000);
  });

  test('a speaker reassigned out of a meeting loses its entry', () async {
    await service.setEnabled(sara.id, true);
    final segs = await segments.getForMeeting(m1.id);
    for (final s in segs.where((s) => s.speakerId == sara.id)) {
      await segments.reassignSpeaker(s.id, omar.id);
    }
    expect(await service.updateAfterMeeting(m1.id), [sara.id]);
    final p = SpeakerProfile.tryParse((await profiles.get(sara.id))!.profile)!;
    expect(p.perMeeting, isEmpty);
    expect(p.isEmpty, isTrue);
  });

  test('a missing profile is rebuilt in full on update', () async {
    await speakers.setProfileEnabled(sara.id, true);
    expect(await service.updateAfterMeeting(m1.id), [sara.id]);
    expect(await profiles.get(sara.id), isNotNull);
  });

  test('disable keeps or deletes data; delete removes everything', () async {
    await service.setEnabled(sara.id, true);
    await notes.replaceForMeeting(m1.id, {
      sara.id: const MinutesSpeakerNote(speaker: 'سارة', summary: 'x'),
    });
    await service.setEnabled(sara.id, false);
    expect((await speakers.get(sara.id))!.profileEnabled, isFalse);
    expect(await profiles.get(sara.id), isNotNull);
    expect(await notes.getForSpeaker(sara.id), hasLength(1));

    await service.setEnabled(sara.id, true);
    await service.setEnabled(sara.id, false, deleteData: true);
    expect(await profiles.get(sara.id), isNull);
    expect(await notes.getForSpeaker(sara.id), isEmpty);

    await service.setEnabled(sara.id, true);
    await notes.replaceForMeeting(m1.id, {
      sara.id: const MinutesSpeakerNote(speaker: 'سارة', summary: 'x'),
    });
    await service.deleteProfile(sara.id);
    expect((await speakers.get(sara.id))!.profileEnabled, isFalse);
    expect(await profiles.get(sara.id), isNull);
    expect(await notes.getForSpeaker(sara.id), isEmpty);
    // Disabled: an update after a meeting no longer recreates it.
    expect(await service.updateAfterMeeting(m1.id), isEmpty);
  });

  test('updateProfileAfterMeeting works through providers', () async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await speakers.setProfileEnabled(sara.id, true);
    final ref = container.read(_refProvider);
    expect(await updateProfileAfterMeeting(ref, m1.id), [sara.id]);
    expect(await updateProfileAfterMeeting(ref, 'unknown'), isEmpty);
  });
}
