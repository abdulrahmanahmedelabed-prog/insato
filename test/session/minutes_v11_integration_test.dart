// v1.1 minutes flow in the post processor (inputs → engine → artefacts) and
// the minutes-engine selection (Gemini by default).

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/local_llm/local_minutes_backends.dart';
import 'package:insato/minutes/claude_client.dart';
import 'package:insato/minutes/gemini_client.dart';
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/session/minutes_engines.dart';
import 'package:insato/session/post_processor.dart';

import 'fakes.dart';

void main() {
  group('PostProcessor v1.1 minutes', () {
    late AppDatabase db;
    late MeetingRepository meetings;
    late SpeakerRepository speakers;
    late FakeMinutesEngine engine;
    late PostProcessor post;
    Object? factoryError;

    setUp(() {
      db = memoryDb();
      meetings = MeetingRepository(db);
      speakers = SpeakerRepository(db);
      engine = FakeMinutesEngine();
      factoryError = null;
      post = PostProcessor(
        db: db,
        meetings: meetings,
        segments: SegmentRepository(db),
        speakers: speakers,
        settings: AppSettings(db),
        minutesEngineFactory: () async {
          final e = factoryError;
          if (e != null) throw e;
          return MinutesEngineHandle(engine);
        },
      );
    });
    tearDown(() => db.close());

    test('passes glossary and open tasks, stores the artefacts', () async {
      final earlier = await meetings.create(title: 'الاجتماع السابق');
      final m = await meetings.create(
        title: 'اجتماع اليوم',
        context: const MeetingContext(agenda: ['الميزانية']),
      );
      final sara = await speakers.create(name: 'سارة', isNamedByUser: true);
      await speakers.setProfileEnabled(sara.id, true);
      await SegmentRepository(db).insertAll([
        TranscriptSegment(
          id: '',
          meetingId: m.id,
          index: 0,
          startMs: 0,
          endMs: 2000,
          text: 'سأرسل التقرير',
          speakerId: sara.id,
        ),
        TranscriptSegment(
          id: '',
          meetingId: m.id,
          index: 1,
          startMs: 2000,
          endMs: 3000,
          text: '',
          speakerId: sara.id,
          kind: SegmentKind.unintelligible,
        ),
      ]);
      await GlossaryRepository(db).add(term: 'Insato');
      await GlossaryRepository(db).add(term: 'KPI', meetingId: m.id);
      final old = await TaskRepository(db)
          .create(task: 'تجهيز العرض', sourceMeetingId: earlier.id);
      engine.result = Minutes(
        title: 'محضر',
        summary: 'ملخص',
        attendees: const ['سارة'],
        topics: const [],
        decisions: const [],
        actionItems: const [
          ActionItem(task: 'إرسال التقرير', owner: 'سارة', evidence: [0]),
        ],
        openQuestions: const [],
        languagesDetected: const [],
        generatedAt: DateTime(2026, 11, 19),
        model: 'gemini-2.5-flash',
        taskUpdates: [
          MinutesTaskUpdate(taskId: old.id, newStatus: TaskStatus.done),
        ],
        speakerNotes: const [MinutesSpeakerNote(speaker: 'سارة')],
        codes: const MinutesCodes(
          codedSpeech: [
            CodedSpeechItem(
              speaker: 'سارة',
              character: CodedSpeechCharacter.unknown,
              description: 'مقطع غير مفهوم',
              evidence: [1],
            ),
          ],
        ),
      );

      final run = await post.runMinutesIfPossible(m.id);
      expect(run.outcome, MinutesOutcome.generated);

      final inputs = engine.lastInputs;
      expect(inputs.glossary.map((g) => g.term), ['Insato', 'KPI', 'سارة']);
      expect(inputs.openTasks.map((t) => t.id), [old.id]);
      expect(inputs.taskSourceTitles[earlier.id], 'الاجتماع السابق');

      final saved = (await meetings.get(m.id))!;
      expect(saved.minutes!.model, 'gemini-2.5-flash');
      final tasks = await TaskRepository(db).getAll(sourceMeetingId: m.id);
      expect(tasks.single.ownerSpeakerId, sara.id);
      final pending = await PendingTaskUpdateRepository(db).getAll();
      expect(pending.single.taskId, old.id);
      expect(
        (await SpeakerMeetingNotesRepository(db).getForSpeaker(sara.id))
            .single
            .meetingId,
        m.id,
      );
      final codes = await CodeFindingRepository(db).getForMeeting(m.id);
      expect(codes.single.kind, CodeFindingKind.speechCoded);
      expect(codes.single.segmentIds, [1]);

      // The tasks of this meeting are not given back as "open tasks".
      await post.regenerateMinutes(m.id);
      expect(engine.lastInputs.openTasks.map((t) => t.id), [old.id]);
      expect(
        await TaskRepository(db).getAll(sourceMeetingId: m.id),
        hasLength(1),
      );
    });

    test('an engine that is not ready is reported with its reason', () async {
      final m = await meetings.create(
        title: 'm',
        status: MeetingStatus.processing,
      );
      await SegmentRepository(db).insert(
        TranscriptSegment(
          id: '',
          meetingId: m.id,
          index: 0,
          startMs: 0,
          endMs: 1000,
          text: 'نص',
        ),
      );
      factoryError = const MinutesEngineNotReadyException(
        'وافق على تنبيه الخصوصية',
        reason: MinutesEngineNotReadyReason.privacyNotAcknowledged,
      );
      final run = await post.runMinutesIfPossible(m.id);
      expect(run.outcome, MinutesOutcome.skippedNoApiKey);
      expect(run.noticeAr, 'وافق على تنبيه الخصوصية');
      expect((await meetings.get(m.id))!.status, MeetingStatus.ready);
      await expectLater(
        post.regenerateMinutes(m.id),
        throwsA(isA<MinutesEngineNotReadyException>()),
      );
      expect(engine.calls, 0);
    });
  });

  group('createMinutesBackend', () {
    late FakeSecureSettings secure;
    final noNetwork = MockClient((_) async => http.Response('', 500));

    setUp(() => secure = FakeSecureSettings());

    Future<Object> fails(
      AppSettingsData s, {
      LocalMinutesBackendBuilder? local,
    }) async {
      try {
        await createMinutesBackend(
          settings: s,
          secure: secure,
          local: local,
          httpClient: noNetwork,
        );
      } catch (e) {
        return e;
      }
      fail('expected an exception');
    }

    test('Gemini is the default and needs a key and the notice', () async {
      const s = AppSettingsData.defaults;
      final noKey = await fails(s) as MinutesEngineNotReadyException;
      expect(noKey.reason, MinutesEngineNotReadyReason.noApiKey);
      expect(noKey.messageAr, contains('aistudio.google.com/apikey'));

      secure.gemini = 'AIza-1';
      final noNotice = await fails(s) as MinutesEngineNotReadyException;
      expect(
        noNotice.reason,
        MinutesEngineNotReadyReason.privacyNotAcknowledged,
      );

      final b = await createMinutesBackend(
        settings: s.copyWith(
          geminiPrivacyAcknowledged: true,
          geminiModel: 'gemini-2.5-flash',
        ),
        secure: secure,
        httpClient: noNetwork,
      );
      expect(b, isA<GeminiMinutesBackend>());
      expect(b.engineId, 'gemini');
      expect((b as GeminiMinutesBackend).client.model, 'gemini-2.5-flash');
      b.close();
    });

    test('Claude needs its key', () async {
      final s = AppSettingsData.defaults.copyWith(
        minutesEngine: AppSettingsData.engineClaude,
        claudeModel: 'claude-x',
      );
      final e = await fails(s) as MinutesEngineNotReadyException;
      expect(e.reason, MinutesEngineNotReadyReason.noApiKey);
      expect(e.messageAr, contains('Claude'));
      secure.anthropic = 'sk-ant';
      final b = await createMinutesBackend(
        settings: s,
        secure: secure,
        httpClient: noNetwork,
      );
      expect(b, isA<ClaudeMinutesBackend>());
      expect((b as ClaudeMinutesBackend).client.model, 'claude-x');
    });

    test('local engines come from the F14 builders', () async {
      final s = AppSettingsData.defaults.copyWith(
        minutesEngine: AppSettingsData.engineLocal,
      );
      final missing = await fails(s) as MinutesEngineNotReadyException;
      expect(missing.reason, MinutesEngineNotReadyReason.unavailable);

      final notDownloaded = await fails(
        s,
        local: LocalMinutesBackendBuilder(
          build: (_) async => null,
          unavailableMessageAr: 'نزّل النموذج أولاً',
        ),
      ) as MinutesEngineNotReadyException;
      expect(notDownloaded.messageAr, 'نزّل النموذج أولاً');

      final backend = ClaudeMinutesBackend(
        ClaudeClient(apiKey: 'x', client: noNetwork),
      );
      final b = await createMinutesBackend(
        settings: s,
        secure: secure,
        local: LocalMinutesBackendBuilder(
          build: (_) async => backend,
          unavailableMessageAr: '',
        ),
      );
      expect(identical(b, backend), isTrue);
    });

    test('display names', () {
      expect(minutesEngineDisplayNameAr('gemini'), 'Gemini');
      expect(minutesEngineDisplayNameAr('claude'), 'Claude');
      expect(minutesEngineDisplayNameAr('local'), contains('المحلي'));
    });

    test('keystore failures propagate (postpone, not "no key")', () async {
      final locked = _LockedSecure();
      await expectLater(
        createMinutesBackend(
          settings: AppSettingsData.defaults,
          secure: locked,
        ),
        throwsA(isA<SecureStorageUnavailableException>()),
      );
    });
  });

  test('MinutesBackendRequest defaults', () {
    const r = MinutesBackendRequest(system: 's', user: 'u', schema: {});
    expect(r.context, isNull);
    expect(r.expectedChars, isNull);
    expect(const InsatoException('x').messageAr, 'x');
  });
}

class _LockedSecure extends FakeSecureSettings {
  @override
  Future<String?> getGeminiApiKey() async =>
      throw const SecureStorageUnavailableException('مقفل');
}
