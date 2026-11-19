import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart';

import 'fakes.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late FakeAudioSource audio;
  late FakeHooks hooks;
  late FakeEnginesFactory engines;
  late FakeSecureSettings secure;
  late ProviderContainer container;
  FakeMinutesEngine? minutes;
  Object? documentsError;
  RefinementRunner? refinementRunner;
  int backlogLimitMs = 15 * 60 * 1000;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('insato_session_');
    audio = FakeAudioSource();
    hooks = FakeHooks();
    engines = FakeEnginesFactory();
    secure = FakeSecureSettings();
    minutes = null;
    documentsError = null;
    refinementRunner = null;
    backlogLimitMs = 15 * 60 * 1000;
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureSettingsProvider.overrideWithValue(secure),
        appPathsProvider.overrideWithValue(
          AppPaths(
            documentsDir: () async {
              final e = documentsError;
              if (e != null) throw e;
              return tmp;
            },
            supportDir: () async => tmp,
          ),
        ),
        liveBacklogLimitMsProvider.overrideWith((ref) => backlogLimitMs),
        postProcessorProvider.overrideWith(
          (ref) => PostProcessor(
            db: db,
            meetings: ref.watch(meetingRepositoryProvider),
            segments: ref.watch(segmentRepositoryProvider),
            speakers: ref.watch(speakerRepositoryProvider),
            settings: ref.watch(appSettingsProvider),
            minutesEngineFactory: ref.watch(minutesEngineFactoryProvider),
            enginesFactory: ref.watch(sessionEnginesFactoryProvider),
            paths: ref.watch(appPathsProvider),
            runRefinement: (input) {
              final r = refinementRunner;
              return r == null ? runRefinementInBackground(input) : r(input);
            },
            isMeetingActive: (id) {
              final s = ref.read(meetingSessionControllerProvider);
              return s.isActive && s.meetingId == id;
            },
          ),
        ),
        sessionAudioSourceProvider.overrideWithValue(audio),
        sessionPlatformHooksProvider.overrideWithValue(hooks),
        sessionEnginesFactoryProvider.overrideWithValue(engines),
        minutesEngineFactoryProvider.overrideWithValue(() async {
          final m = minutes;
          return m == null ? null : MinutesEngineHandle(m);
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await tmp.delete(recursive: true);
  });

  MeetingSessionController controller() =>
      container.read(meetingSessionControllerProvider.notifier);
  SessionState state() => container.read(meetingSessionControllerProvider);
  Future<void> consent() => AppSettings(db).setConsentAcknowledged(true);

  /// Speaks voices (2 s each) separated by 0.5 s pauses.
  Future<void> speak(List<int?> voices) async {
    final target = engines.asr.calls + voices.length;
    for (final v in voices) {
      audio.emit(voiceSamples(v, 2000));
    }
    await waitUntil(
      () => engines.asr.calls >= target && state().pendingProcessing == 0,
    );
  }

  test('requires recording consent first', () async {
    final c = controller();
    await expectLater(c.start(), throwsA(isA<ConsentRequiredException>()));
    expect(state().phase, SessionPhase.error);
    expect(state().errorAr, contains('موافقتهم'));
    expect(await MeetingRepository(db).getAll(), isEmpty);
    expect(engines.created, 0);

    final id = await c.start(consentGiven: true);
    expect(await AppSettings(db).consentAcknowledged, isTrue);
    expect(state().phase, SessionPhase.recording);
    expect(state().meetingId, id);
    await c.cancel();
  });

  test('records, transcribes with speakers and finishes the meeting', () async {
    await consent();
    final c = controller();
    final id = await c.start(title: '  اجتماع الميزانية  ');
    expect(hooks.started, 1);
    expect(audio.archivePath, '${tmp.path}/recordings/$id.wav');
    expect(state().title, 'اجتماع الميزانية');
    expect(state().engineDescription, 'fake');

    await speak([0, 0, 1, null, 0, 1]);
    expect(state().liveSegments, 5);
    expect(state().currentSpeakerLabel, 'متحدث 2');

    final stopped = await c.stop();
    expect(stopped, id);
    expect(state().phase, SessionPhase.idle);
    expect(state().lastMeetingId, id);
    expect(hooks.stopped, 1);
    expect(engines.lastSegmenter!.flushed, isTrue);
    expect(engines.lastSegmenter!.disposed, isTrue);

    final meetings = MeetingRepository(db);
    final segs = await SegmentRepository(db).getForMeeting(id);
    expect(segs.map((s) => s.text), [
      'كلام 0',
      'كلام 1',
      'كلام 2',
      'كلام 4',
      'كلام 5',
    ]);
    final byId = await SpeakerRepository(db).getAllById();
    expect(segs.map((s) => byId[s.speakerId]!.name).toList(), [
      'متحدث 1',
      'متحدث 1',
      'متحدث 2',
      'متحدث 1',
      'متحدث 2',
    ]);

    // Minutes are skipped without an API key; the meeting becomes ready.
    await waitUntil(
      () =>
          container.read(meetingJobsProvider(id)).phase ==
          MeetingJobPhase.succeeded,
    );
    expect(container.read(meetingJobsProvider(id)).needsApiKey, isTrue);
    final m = (await meetings.get(id))!;
    expect(m.status, MeetingStatus.ready);
    expect(m.durationMs, 12000);
    expect(m.minutes, isNull);
    // Only the file name is stored (iOS container paths change on updates).
    expect(m.audioPath, '$id.wav');
    // Both new speakers have ≥ 3 s of speech: voiceprints were learned.
    final after = await SpeakerRepository(db).getAll();
    expect(after, hasLength(2));
    expect(
      after.every((s) => s.centroid != null && s.embeddingCount >= 2),
      isTrue,
    );
  });

  test('generates minutes automatically when a key exists', () async {
    await consent();
    minutes = FakeMinutesEngine();
    final c = controller();
    final id = await c.start();
    expect(state().title, startsWith('اجتماع '));
    await speak([2, 2]);
    await c.stop();
    final meetings = MeetingRepository(db);
    await waitUntil(
      () =>
          container.read(meetingJobsProvider(id)).phase ==
          MeetingJobPhase.succeeded,
    );
    final m = (await meetings.get(id))!;
    expect(m.status, MeetingStatus.ready);
    expect(m.minutes!.attendees, ['متحدث 1']);
    expect(minutes!.calls, 1);
  });

  test('a known voice is labelled with its saved name', () async {
    await consent();
    final speakers = SpeakerRepository(db);
    final huda = await speakers.create(
      name: 'هدى',
      centroid: voiceOf(3),
      embeddingCount: 30,
    );
    final c = controller();
    final id = await c.start();
    await speak([3, 4, 3]);
    expect(state().currentSpeakerLabel, 'هدى');
    await c.stop();
    final segs = await SegmentRepository(db).getForMeeting(id);
    expect(segs[0].speakerId, huda.id);
    expect(segs[2].speakerId, huda.id);
    expect((await speakers.get(segs[1].speakerId!))!.name, 'متحدث 1');
  });

  test('missing microphone permission leaves nothing behind', () async {
    await consent();
    hooks.deny = true;
    await expectLater(
      controller().start(),
      throwsA(isA<AudioCaptureException>()),
    );
    expect(state().phase, SessionPhase.error);
    expect(await MeetingRepository(db).getAll(), isEmpty);
    expect(engines.created, 0);
    controller().dismissMessage();
    expect(state().phase, SessionPhase.idle);
  });

  test('missing models are reported with ModelException', () async {
    await consent();
    engines.notReady = const ModelException(
      'لا يمكن بدء التسجيل قبل تنزيل النماذج التالية.',
    );
    await expectLater(controller().start(), throwsA(isA<ModelException>()));
    expect(state().error, isA<ModelException>());
    expect(await MeetingRepository(db).getAll(), isEmpty);
  });

  test('a capture failure at start rolls everything back', () async {
    await consent();
    audio.startError = const AudioCaptureException('الميكروفون مشغول.');
    await expectLater(
      controller().start(),
      throwsA(isA<AudioCaptureException>()),
    );
    expect(state().errorAr, 'الميكروفون مشغول.');
    expect(await MeetingRepository(db).getAll(), isEmpty);
    expect(hooks.started, 1);
    expect(hooks.stopped, 1);
    expect(engines.lastSegmenter!.disposed, isTrue);
  });

  test('cancel discards the meeting and its new speakers', () async {
    await consent();
    final c = controller();
    final id = await c.start();
    await speak([0, 1]);
    expect(await SpeakerRepository(db).getAll(), hasLength(2));
    await c.cancel();
    expect(state().phase, SessionPhase.idle);
    expect(await MeetingRepository(db).get(id), isNull);
    expect(await SpeakerRepository(db).getAll(), isEmpty);
    expect(File('${tmp.path}/recordings/$id.wav').existsSync(), isFalse);
    expect(hooks.stopped, 1);
  });

  test('pause and resume', () async {
    await consent();
    final c = controller();
    await c.start();
    await c.pause();
    expect(state().phase, SessionPhase.paused);
    expect(audio.paused, isTrue);
    await c.resume();
    expect(state().phase, SessionPhase.recording);
    expect(audio.paused, isFalse);
    await expectLater(c.start(), throwsA(isA<InsatoException>()));
    await c.cancel();
  });

  test('a take ended by the system is saved like a normal stop', () async {
    await consent();
    final c = controller();
    final id = await c.start();
    await speak([0]);
    audio.endBySystem();
    await waitUntil(() => state().phase == SessionPhase.idle);
    expect(state().lastMeetingId, id);
    expect(state().warningAr, isNotNull);
    expect(await SegmentRepository(db).getForMeeting(id), hasLength(1));
  });

  test('stop without a session returns null', () async {
    expect(await controller().stop(), isNull);
  });

  test('failed segments are reported after stopping', () async {
    await consent();
    engines.asr = FakeAsr(failIndices: {1});
    final c = controller();
    final id = await c.start();
    await speak([0, 0, 0]);
    expect(state().failedSegments, 1);
    await c.stop();
    expect(state().warningAr, contains('تعذّر تفريغ 1'));
    expect(await SegmentRepository(db).getForMeeting(id), hasLength(2));
  });

  test('defaultSessionTitle uses the Arabic date', () {
    final t = defaultSessionTitle(DateTime(2026, 11, 19, 14, 5));
    expect(t, startsWith('اجتماع '));
    expect(t, contains('2026'));
    expect(t, contains('14:05'));
  });

  test('SessionState helpers', () {
    const s = SessionState(phase: SessionPhase.paused, pendingAudioMs: 70000);
    expect(s.isActive, isTrue);
    expect(s.isCapturing, isTrue);
    expect(s.canStart, isFalse);
    expect(s.isProcessingBehind, isTrue);
    final e = s.copyWith(
      phase: SessionPhase.error,
      error: const InsatoException('خطأ'),
      warningAr: 'تحذير',
    );
    expect(e.errorAr, 'خطأ');
    expect(e.canStart, isTrue);
    expect(e.copyWith(clearError: true, clearWarning: true).errorAr, isNull);
    expect(e.copyWith(clearWarning: true).warningAr, isNull);
    expect(
      const SessionState(
        currentSpeakerId: 'x',
        currentSpeakerLabel: 'y',
      ).copyWith(clearCurrentSpeaker: true).currentSpeakerLabel,
      isNull,
    );
  });

  test('keeps no archive when keepAudio is off', () async {
    await consent();
    await AppSettings(db).setKeepAudio(false);
    final c = controller();
    final id = await c.start();
    expect(audio.archivePath, isNull);
    await speak([0]);
    await c.stop();
    expect((await MeetingRepository(db).get(id))!.audioPath, isNull);
  });

  group('review fixes', () {
    test(
      'a failure after the engines loaded does not hang start (session-1)',
      () async {
        await consent();
        // recordingsDir() fails: start() throws before it listens to the
        // segmenter, whose single-subscription stream never closes.
        documentsError = const FileSystemException('disk gone');
        await expectLater(
          controller().start().timeout(const Duration(seconds: 15)),
          throwsA(isA<InsatoException>()),
        );
        expect(state().phase, SessionPhase.error);
        expect(state().isActive, isFalse);
        expect(engines.lastSegmenter!.disposed, isTrue);
        // The processor was released after the segmenter.
        expect(engines.asr.disposed, isTrue);
        expect(await MeetingRepository(db).getAll(), isEmpty);
      },
    );

    test('refinement failure still learns voiceprints (session-3)', () async {
      await consent();
      refinementRunner = (_) async => throw StateError('isolate died');
      final c = controller();
      final id = await c.start();
      await speak([0, 0, 1, 1]);
      await c.stop();
      expect(state().phase, SessionPhase.idle);
      expect(state().warningAr, contains('أُبقيت التسميات الأولية'));
      final all = await SpeakerRepository(db).getAll();
      expect(all, hasLength(2));
      // Both voices have 4 s of speech: they must be recognisable next time.
      expect(all.every((s) => s.centroid != null), isTrue);
      expect(all.every((s) => s.embeddingCount == 2), isTrue);
      expect(await SegmentRepository(db).getForMeeting(id), hasLength(4));
    });

    test('a live backlog over the cap pauses live transcription and the '
        'meeting is completed from the archive (session-4)', () async {
      await consent();
      backlogLimitMs = 3000;
      audio.writeWavOnStop = true;
      // Live: one segment per chunk; re-processing: split the WAV by voice.
      engines.segmenterBuilder = () =>
          engines.created == 1 ? FakeSegmenter() : RunSegmenter();
      final gate = engines.asr.gate = Completer<void>();
      final c = controller();
      final id = await c.start();
      for (final v in [0, null, 1, null, 0]) {
        audio.emit(voiceSamples(v, 2000));
      }
      await waitUntil(() => state().liveTranscriptionPaused);
      expect(state().warningAr, contains('أُوقف التفريغ المباشر'));
      // Only 4.5 s of audio entered the queue, not 10 s.
      expect(state().pendingAudioMs, lessThanOrEqualTo(4000));
      gate.complete();
      engines.asr.gate = null;
      await c.stop();
      expect(state().warningAr, contains('يُعاد الآن تفريغ الاجتماع'));
      await waitUntil(
        () =>
            container.read(meetingJobsProvider(id)).kind ==
                MeetingJobKind.minutes &&
            container.read(meetingJobsProvider(id)).phase ==
                MeetingJobPhase.succeeded,
      );
      final segs = await SegmentRepository(db).getForMeeting(id);
      expect(segs.map((s) => s.text), ['كلام 0', 'كلام 1', 'كلام 2']);
      expect(
        (await MeetingRepository(db).get(id))!.status,
        MeetingStatus.ready,
      );
    });

    test('an overflowed meeting whose re-processing fails is marked '
        'incomplete', () async {
      await consent();
      backlogLimitMs = 1000; // the archive stays an empty (corrupt) file
      final gate = engines.asr.gate = Completer<void>();
      final c = controller();
      final id = await c.start();
      audio.emit(voiceSamples(0, 2000));
      audio.emit(voiceSamples(1, 2000));
      await waitUntil(() => state().liveTranscriptionPaused);
      gate.complete();
      await c.stop();
      final meetings = MeetingRepository(db);
      final sw = Stopwatch()..start();
      while ((await meetings.get(id))!.errorMessage !=
          kIncompleteTranscriptAr) {
        if (sw.elapsed > const Duration(seconds: 10)) fail('not marked');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect((await meetings.get(id))!.status, MeetingStatus.failed);
      expect(
        container.read(meetingJobsProvider(id)).kind,
        MeetingJobKind.reprocess,
      );
      // The live part of the transcript is kept.
      expect(await SegmentRepository(db).getForMeeting(id), hasLength(1));
    });

    test('finishLater skips the remaining transcription (session-4)', () async {
      await consent();
      final gate = engines.asr.gate = Completer<void>();
      final c = controller();
      final id = await c.start();
      audio.emit(voiceSamples(0, 2000));
      audio.emit(voiceSamples(1, 2000));
      await waitUntil(() => state().pendingProcessing == 2);
      expect(c.canFinishLater, isFalse); // not stopping yet
      final stopping = c.stop();
      await waitUntil(() => c.canFinishLater);
      expect(c.finishLater(), isTrue);
      expect(await stopping.timeout(const Duration(seconds: 5)), id);
      expect(state().phase, SessionPhase.idle);
      expect(state().lastMeetingId, id);
      expect(state().warningAr, contains('دون إكمال التفريغ'));
      final m = (await MeetingRepository(db).get(id))!;
      expect(m.status, MeetingStatus.failed);
      expect(m.errorMessage, kIncompleteTranscriptAr);
      expect(m.audioPath, '$id.wav');
      // No automatic minutes on an incomplete transcript.
      expect(
        container.read(meetingJobsProvider(id)).phase,
        MeetingJobPhase.idle,
      );
      expect(hooks.stopped, 1);
      gate.complete();
    });

    test(
      'discard during an automatic stop keeps the meeting (session-5)',
      () async {
        await consent();
        final c = controller();
        final id = await c.start();
        await speak([0]);
        final gate = engines.asr.gate = Completer<void>();
        audio.emit(voiceSamples(1, 2000));
        await waitUntil(() => state().pendingProcessing == 1);
        expect(c.canDiscard, isTrue);
        // The platform ends the take while the discard dialog is open.
        audio.endBySystem();
        await waitUntil(() => state().phase == SessionPhase.finishing);
        expect(c.canDiscard, isFalse);
        final discarding = c.cancel();
        gate.complete();
        expect(await discarding, isFalse);
        expect(state().phase, SessionPhase.idle);
        expect(state().lastMeetingId, id);
        expect(await MeetingRepository(db).get(id), isNotNull);
        expect(await SegmentRepository(db).getForMeeting(id), hasLength(2));
        expect(hooks.stopped, 1);
      },
    );

    test('discard keeps a speaker the user merged an older voice into '
        '(session-6)', () async {
      await consent();
      final speakers = SpeakerRepository(db);
      final meetings = MeetingRepository(db);
      // An older unnamed speaker with a voiceprint and a segment elsewhere.
      final older = await meetings.create(title: 'قديم');
      final old = await speakers.create(
        centroid: voiceOf(5),
        embeddingCount: 12,
      );
      await SegmentRepository(db).insert(
        TranscriptSegment(
          id: '',
          meetingId: older.id,
          index: 0,
          startMs: 0,
          endMs: 2000,
          text: 'قديم',
          speakerId: old.id,
        ),
      );
      final c = controller();
      final id = await c.start();
      await speak([0]);
      final live = (await SegmentRepository(db).getForMeeting(id))
          .single
          .speakerId!;
      expect(live, isNot(old.id));
      // During the recording the user merges the older speaker into the
      // live one, then discards the recording.
      await container.read(postProcessorProvider).mergeSpeakers(old.id, live);
      expect(await c.cancel(), isTrue);
      final kept = await speakers.get(live);
      expect(kept, isNotNull);
      expect(kept!.embeddingCount, 12);
      expect(
        (await SegmentRepository(db).getForMeeting(older.id)).single.speakerId,
        live,
      );
    });
  });

  group('renameMeeting (ui-live-title-edit)', () {
    test(
      'renames the live meeting, its session title and notification',
      () async {
        await consent();
        final c = controller();
        final id = await c.start(title: 'قديم');
        expect(await c.renameMeeting(id, '  جديد  '), isTrue);
        expect((await MeetingRepository(db).get(id))!.title, 'جديد');
        expect(state().title, 'جديد');
        expect(hooks.titles, ['جديد']);
        expect(await c.renameMeeting(id, '   '), isFalse);
        expect(hooks.titles, ['جديد']);
        await c.cancel();
      },
    );

    test('renaming another meeting leaves the session untouched', () async {
      final other = await MeetingRepository(db)
          .create(title: 'سابق', status: MeetingStatus.ready);
      await consent();
      final c = controller();
      await c.start(title: 'حالي');
      expect(await c.renameMeeting(other.id, 'مُعدَّل'), isTrue);
      expect((await MeetingRepository(db).get(other.id))!.title, 'مُعدَّل');
      expect(state().title, 'حالي');
      expect(hooks.titles, isEmpty);
      expect(await c.renameMeeting('missing', 'x'), isFalse);
      await c.cancel();
    });
  });

  test(
    'cancel after the take ended saves the meeting and returns false',
    () async {
      await consent();
      final c = controller();
      final id = await c.start();
      await speak([0]);
      final stopping = c.stop();
      expect(c.canDiscard, isFalse);
      expect(await c.cancel(), isFalse);
      expect(await stopping, id);
      expect(await MeetingRepository(db).get(id), isNotNull);
    },
  );

  group('MeetingJobsController', () {
    test(
      'automatic minutes are postponed when the key store is locked',
      () async {
        container.dispose();
        container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appPathsProvider.overrideWithValue(
              AppPaths(
                documentsDir: () async => tmp,
                supportDir: () async => tmp,
              ),
            ),
            minutesEngineFactoryProvider.overrideWithValue(
              () async => throw const SecureStorageUnavailableException('مقفل'),
            ),
          ],
        );
        final meetings = MeetingRepository(db);
        final m = await meetings.create(status: MeetingStatus.processing);
        await SegmentRepository(db).insert(
          TranscriptSegment(
            id: 's1',
            meetingId: m.id,
            index: 0,
            startMs: 0,
            endMs: 2000,
            text: 'مرحبًا',
          ),
        );
        final jobs = container.read(meetingJobsProvider(m.id).notifier);
        expect(await jobs.generateMinutes(automatic: true), isTrue);
        final job = container.read(meetingJobsProvider(m.id));
        expect(job.needsApiKey, isFalse);
        expect(job.noticeAr, contains('مقفل'));
        expect((await meetings.get(m.id))!.status, MeetingStatus.ready);
      },
    );

    test('manual minutes without a key fail with needsApiKey', () async {
      final meetings = MeetingRepository(db);
      final m = await meetings.create(status: MeetingStatus.ready);
      final speaker = await SpeakerRepository(db).create();
      await SegmentRepository(db).insert(
        TranscriptSegment(
          id: '',
          meetingId: m.id,
          index: 0,
          startMs: 0,
          endMs: 1000,
          text: 'نص',
          speakerId: speaker.id,
        ),
      );
      final jobs = container.read(meetingJobsProvider(m.id).notifier);
      expect(await jobs.generateMinutes(), isFalse);
      final st = container.read(meetingJobsProvider(m.id));
      expect(st.phase, MeetingJobPhase.failed);
      expect(st.needsApiKey, isTrue);
      expect(st.errorAr, contains('مفتاح محرك المحضر'));

      minutes = FakeMinutesEngine();
      expect(await jobs.generateMinutes(), isTrue);
      expect(
        container.read(meetingJobsProvider(m.id)).noticeAr,
        'تم إنشاء المحضر.',
      );
      expect((await meetings.get(m.id))!.minutes, isNotNull);
      expect(await jobs.refineSpeakers(), isTrue);
      jobs.clear();
      expect(
        container.read(meetingJobsProvider(m.id)).phase,
        MeetingJobPhase.idle,
      );
    });

    test('jobs refuse to run on the meeting being recorded', () async {
      await consent();
      final id = await controller().start();
      final jobs = container.read(meetingJobsProvider(id).notifier);
      expect(await jobs.refineSpeakers(), isFalse);
      expect(
        container.read(meetingJobsProvider(id)).errorAr,
        contains('قيد التسجيل'),
      );
      await controller().cancel();
    });

    test('reprocess without audio reports an Arabic error', () async {
      final m = await MeetingRepository(db).create(status: MeetingStatus.ready);
      final jobs = container.read(meetingJobsProvider(m.id).notifier);
      expect(await jobs.reprocessFromAudio(), isFalse);
      expect(
        container.read(meetingJobsProvider(m.id)).errorAr,
        contains('تسجيل صوتي'),
      );
    });
  });
}
