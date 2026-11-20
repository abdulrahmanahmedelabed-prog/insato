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
import 'package:insato/features/groq/groq_api.dart';
import 'package:insato/features/groq/groq_minutes_backend.dart';
import 'package:insato/features/local_llm/local_minutes_backends.dart';
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

    test('only open tasks of earlier meetings are given to the engine',
        () async {
      final a = await meetings.create(
        title: 'A',
        createdAt: DateTime(2026, 3, 1),
      );
      final b = await meetings.create(
        title: 'B',
        createdAt: DateTime(2026, 3, 5),
      );
      final c = await meetings.create(
        title: 'C',
        createdAt: DateTime(2026, 3, 10),
      );
      final tasks = TaskRepository(db);
      // A's task row was re-created later (regeneration): still A's date.
      final ta = await tasks.create(
        task: 'مهمة أ',
        sourceMeetingId: a.id,
        createdAt: DateTime(2026, 4, 1),
      );
      final tb = await tasks.create(task: 'مهمة ب', sourceMeetingId: b.id);
      final tc = await tasks.create(task: 'مهمة ج', sourceMeetingId: c.id);
      final manual = await tasks.create(
        task: 'مهمة يدوية',
        createdAt: DateTime(2026, 3, 3),
      );
      final forB = await post.minutesInputsFor(b, const {});
      expect(forB.openTasks.map((t) => t.id).toSet(), {ta.id, manual.id});
      expect(forB.taskSourceTitles, {a.id: 'A'});
      final forA = await post.minutesInputsFor(a, const {});
      expect(forA.openTasks, isEmpty);
      final forC = await post.minutesInputsFor(c, const {});
      expect(forC.openTasks.map((t) => t.id).toSet(), {
        ta.id,
        tb.id,
        manual.id,
      });
      expect(forC.openTasks.map((t) => t.id), isNot(contains(tc.id)));

      // Many open tasks of a later meeting never push out earlier ones.
      for (var i = 0; i < PostProcessor.maxOpenTasksInPrompt + 5; i++) {
        await tasks.create(task: 'لاحقة $i', sourceMeetingId: c.id);
      }
      final again = await post.minutesInputsFor(b, const {});
      expect(again.openTasks.map((t) => t.id).toSet(), {ta.id, manual.id});
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
      expect(b, isA<QuotaFallbackMinutesBackend>());
      expect(b.engineId, 'gemini');
      final primary = (b as QuotaFallbackMinutesBackend).primary;
      expect((primary as GeminiMinutesBackend).client.model, 'gemini-2.5-flash');
      expect(b.alternativeEngine, 'groq');
      expect(b.automatic, isFalse);
      b.close();
    });

    test('Groq needs its key and its notice', () async {
      final s = AppSettingsData.defaults.copyWith(
        minutesEngine: AppSettingsData.engineGroq,
        groqModel: 'llama-3.3-70b-versatile',
      );
      final e = await fails(s) as MinutesEngineNotReadyException;
      expect(e.reason, MinutesEngineNotReadyReason.noApiKey);
      expect(e.messageAr, contains('console.groq.com/keys'));
      secure.groq = 'gsk_1';
      final notice = await fails(s) as MinutesEngineNotReadyException;
      expect(notice.reason, MinutesEngineNotReadyReason.privacyNotAcknowledged);
      final b = await createMinutesBackend(
        settings: s.copyWith(groqPrivacyAcknowledged: true),
        secure: secure,
        httpClient: noNetwork,
      );
      final primary = (b as QuotaFallbackMinutesBackend).primary;
      expect(primary, isA<GroqMinutesBackend>());
      expect((primary as GroqMinutesBackend).model, 'llama-3.3-70b-versatile');
      expect(b.engineId, 'groq');
      expect(b.alternativeEngine, 'gemini');
      b.close();
    });

    test('a forced engine (accepted offer) is used without chaining', () async {
      secure.groq = 'gsk_1';
      final s = AppSettingsData.defaults.copyWith(groqPrivacyAcknowledged: true);
      final b = await runWithMinutesEngine(
        AppSettingsData.engineGroq,
        () => createMinutesBackend(
          settings: s,
          secure: secure,
          httpClient: noNetwork,
        ),
      );
      expect(b, isA<GroqMinutesBackend>());
      expect(currentMinutesEngineOverride, isNull);
      b.close();
    });

    test('a removed claude choice behaves as Gemini', () async {
      final e = await fails(
        AppSettingsData.fromMap(const {AppSettings.kMinutesEngine: 'claude'}),
      ) as MinutesEngineNotReadyException;
      expect(e.messageAr, contains('Gemini'));
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

      final backend = _QuotaBackend('local');
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
      expect(minutesEngineDisplayNameAr('groq'), 'Groq');
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

  group('QuotaFallbackMinutesBackend', () {
    const request = MinutesBackendRequest(system: 's', user: 'u', schema: {});
    const geminiDaily = GeminiQuotaExceededException('يومي', daily: true);
    const groqDaily = GroqQuotaExceededException('يومي', daily: true);

    QuotaFallbackMinutesBackend wrap(
      _QuotaBackend primary,
      _QuotaBackend alternative, {
      required bool automatic,
      bool ready = true,
    }) => QuotaFallbackMinutesBackend(
      primary: primary,
      alternativeEngine: alternative.engineId,
      automatic: automatic,
      isAlternativeReady: () async => ready,
      createAlternative: () async => alternative,
    );

    test('offers the other free engine when the daily quota is used up',
        () async {
      final gemini = _QuotaBackend('gemini', error: geminiDaily);
      final groq = _QuotaBackend('groq');
      final b = wrap(gemini, groq, automatic: false);
      final e = await b
          .generateStructured(request)
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(e, isA<MinutesQuotaExhaustedException>());
      final q = e! as MinutesQuotaExhaustedException;
      expect(q.exhaustedEngine, 'gemini');
      expect(q.alternativeEngine, 'groq');
      expect(q.messageAr, contains('Groq'));
      expect(groq.calls, 0);
    });

    test('switches automatically when enabled', () async {
      final groq = _QuotaBackend('groq', error: groqDaily);
      final gemini = _QuotaBackend('gemini');
      final b = wrap(groq, gemini, automatic: true);
      final r = await b.generateStructured(request);
      expect(r.model, 'gemini-model');
      // Later requests go straight to the working engine.
      await b.generateStructured(request);
      expect(groq.calls, 1);
      expect(gemini.calls, 2);
      b.close();
      expect(groq.closed && gemini.closed, isTrue);
    });

    test('per-minute limits, other errors or an unready alternative '
        'propagate unchanged', () async {
      const minute = GeminiQuotaExceededException('دقيقة', daily: false);
      final a = wrap(
        _QuotaBackend('gemini', error: minute),
        _QuotaBackend('groq'),
        automatic: true,
      );
      expect(
        () => a.generateStructured(request),
        throwsA(same(minute)),
      );
      final b = wrap(
        _QuotaBackend('gemini', error: geminiDaily),
        _QuotaBackend('groq'),
        automatic: true,
        ready: false,
      );
      expect(() => b.generateStructured(request), throwsA(same(geminiDaily)));
    });

    test('isDailyQuotaExhausted', () {
      expect(isDailyQuotaExhausted(geminiDaily), isTrue);
      expect(isDailyQuotaExhausted(groqDaily), isTrue);
      expect(
        isDailyQuotaExhausted(
          const GroqQuotaExceededException('x', daily: false),
        ),
        isFalse,
      );
    });

    test('cloudEngineIsReady needs the key and the notice', () async {
      final secure = FakeSecureSettings()..groq = 'gsk';
      const s = AppSettingsData.defaults;
      expect(
        await cloudEngineIsReady('groq', settings: s, secure: secure),
        isFalse,
      );
      expect(
        await cloudEngineIsReady(
          'groq',
          settings: s.copyWith(groqPrivacyAcknowledged: true),
          secure: secure,
        ),
        isTrue,
      );
      expect(
        await cloudEngineIsReady(
          'gemini',
          settings: s.copyWith(geminiPrivacyAcknowledged: true),
          secure: secure,
        ),
        isFalse,
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

class _QuotaBackend implements MinutesBackend {
  _QuotaBackend(this.engineId, {this.error});

  @override
  final String engineId;
  final Object? error;
  int calls = 0;
  bool closed = false;

  @override
  String get displayName => engineId;

  @override
  bool get sendsDataOffDevice => true;

  @override
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  }) async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return MinutesBackendResult(text: '{}', model: '$engineId-model');
  }

  @override
  void close() => closed = true;
}
