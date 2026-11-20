import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/diarization/vector_math.dart';
import 'package:insato/features/voice/audio_quality.dart';
import 'package:insato/features/voice/enrollment_controller.dart';
import 'package:insato/features/voice/enrollment_engine.dart';
import 'package:insato/features/voice/enrollment_texts.dart';
import 'package:insato/features/voice/mic_capture.dart';
import 'package:insato/features/voice/mic_test_controller.dart';
import 'package:insato/features/voice/strings.dart';

import '../../session/fakes.dart' show memoryDb, voiceOf;
import 'voice_fakes.dart';

const usb = InputDevice(id: '17', label: 'Jabra', type: InputDeviceType.usb);
const builtIn = InputDevice(
  id: '1',
  label: 'Built-in',
  type: InputDeviceType.builtIn,
);

class Env {
  Env() {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        micCaptureFactoryProvider.overrideWithValue(mics.call),
        capturePlatformProvider.overrideWithValue(CapturePlatform.android),
        meetingRecordingActiveProvider.overrideWith((ref) => busy),
        enrollmentAnalyzerFactoryProvider.overrideWithValue(({
          bool farField = false,
        }) async {
          analyzerFarField = farField;
          final e = analyzerError;
          if (e != null) throw e;
          return analyzer;
        }),
        micTestDirProvider.overrideWithValue(() async => tmp.path),
        testPlaybackFactoryProvider.overrideWithValue(() => player),
      ],
    );
  }

  final AppDatabase db = memoryDb();
  final FakeMicFactory mics = FakeMicFactory(devices: const [builtIn, usb]);
  FakeEnrollmentAnalyzer analyzer = FakeEnrollmentAnalyzer(speaker: 4);
  Object? analyzerError;
  bool? analyzerFarField;
  bool busy = false;
  final FakePlayback player = FakePlayback();
  final Directory tmp = Directory.systemTemp.createTempSync('insato_voice_');
  late final ProviderContainer container;

  Future<void> dispose() async {
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

/// Polls [done] until it holds (5 s limit): the end of a test take writes and
/// analyses a WAV file, whose duration varies on a busy CI runner.
Future<void> waitUntil(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not reached within 5 s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('VoiceEnrollmentController', () {
    late Env env;
    late ProviderSubscription<EnrollmentState> keep;

    setUp(() {
      env = Env();
      keep = env.container.listen(voiceEnrollmentControllerProvider, (_, _) {});
    });
    tearDown(() async {
      keep.close();
      await env.dispose();
    });

    VoiceEnrollmentController ctrl() =>
        env.container.read(voiceEnrollmentControllerProvider.notifier);
    EnrollmentState st() =>
        env.container.read(voiceEnrollmentControllerProvider);

    test('record → analyse → save a new person', () async {
      await ctrl().start();
      expect(st().phase, EnrollmentPhase.recording);
      final mic = env.mics.recording!;
      expect(mic.startedWith, isNull);
      mic.emit(readingTake());
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(st().elapsedMs, greaterThan(12000));
      expect(st().voicedEstimateMs, greaterThan(9000));
      await ctrl().stop();
      expect(st().phase, EnrollmentPhase.review);
      expect(st().analysis!.canSave, isTrue);
      expect(mic.disposed, isTrue);
      expect(env.analyzer.disposed, isTrue);

      final saved = await ctrl().save(name: 'د. سارة');
      expect(saved, isNotNull);
      expect(st().phase, EnrollmentPhase.saved);
      final stored = (await SpeakerRepository(env.db).get(saved!.id))!;
      expect(stored.name, 'د. سارة');
      expect(stored.isNamedByUser, isTrue);
      expect(cosine(stored.centroid!, voiceOf(4)), greaterThan(0.95));
      expect(stored.voiceDevice, isNull);
    });

    test(
      'uses the remembered mic and far field, tags the voiceprint',
      () async {
        await InputDevicePreferences(
          settings: AppSettings(env.db),
          db: env.db,
        ).remember(usb);
        await AppSettings(env.db).setFarFieldMode(true);
        await ctrl().start();
        final mic = env.mics.recording!;
        expect(mic.startedWith, usb);
        expect(env.mics.options.last.autoGainOnAndroid, isTrue);
        mic.emit(readingTake());
        await settle();
        await ctrl().stop();
        expect(env.analyzerFarField, isTrue);
        final saved = await ctrl().save(name: 'منى');
        expect(saved!.voiceDevice, 'usb|Jabra');
      },
    );

    test('auto-stops at the target once enough speech was heard', () async {
      await ctrl().start();
      env.mics.recording!.emit(readingTake(segments: 6, speechMs: 2400));
      await waitUntil(() => st().phase == EnrollmentPhase.review);
      expect(st().phase, EnrollmentPhase.review);
    });

    test('a short take is analysed but cannot be saved', () async {
      await ctrl().start();
      env.mics.recording!.emit(readingTake(segments: 2));
      await settle();
      await ctrl().stop();
      expect(st().phase, EnrollmentPhase.review);
      expect(st().analysis!.canSave, isFalse);
      expect(await ctrl().save(name: 'x'), isNull);
    });

    test('name is required for a new person', () async {
      await ctrl().start();
      env.mics.recording!.emit(readingTake());
      await settle();
      await ctrl().stop();
      expect(await ctrl().save(name: '  '), isNull);
      expect(st().errorAr, VoiceStrings.nameRequired);
      expect(st().phase, EnrollmentPhase.review);
    });

    test('similar voiceprint: stop, then add to it (naming it)', () async {
      final repo = SpeakerRepository(env.db);
      final unnamed = await repo.create(
        centroid: voiceOf(4),
        embeddingCount: 5,
      );
      await ctrl().start();
      env.mics.recording!.emit(readingTake());
      await settle();
      await ctrl().stop();
      expect(await ctrl().save(name: 'منى'), isNull);
      expect(st().similar!.speaker.id, unnamed.id);
      final saved = await ctrl().save(name: 'منى', speakerId: unnamed.id);
      expect(saved!.id, unnamed.id);
      expect(saved.name, 'منى');
      expect(saved.embeddingCount, greaterThan(5));
      expect(await repo.getAll(), hasLength(1));
    });

    test('similar voiceprint: save as a different person anyway', () async {
      final repo = SpeakerRepository(env.db);
      await repo.create(name: 'أحمد', centroid: voiceOf(4), embeddingCount: 5);
      await ctrl().start();
      env.mics.recording!.emit(readingTake());
      await settle();
      await ctrl().stop();
      expect(await ctrl().save(name: 'منى'), isNull);
      expect(st().similar, isNotNull);
      expect(await ctrl().save(name: 'منى', force: true), isNotNull);
      expect(await repo.getAll(), hasLength(2));
    });

    test('name already used by a named speaker → conflict', () async {
      final repo = SpeakerRepository(env.db);
      final other = await repo.create(
        name: 'منى',
        centroid: voiceOf(9),
        embeddingCount: 5,
      );
      await ctrl().start();
      env.mics.recording!.emit(readingTake());
      await settle();
      await ctrl().stop();
      expect(await ctrl().save(name: 'منى'), isNull);
      expect(st().nameConflict!.id, other.id);
      final saved = await ctrl().save(speakerId: other.id);
      expect(saved!.id, other.id);
    });

    test('improve voice of an existing speaker', () async {
      final repo = SpeakerRepository(env.db);
      final s = await repo.create(
        name: 'خالد',
        centroid: voiceOf(4),
        embeddingCount: 10,
        lowConfidence: true,
      );
      await ctrl().start();
      env.mics.recording!.emit(readingTake());
      await settle();
      await ctrl().stop();
      final saved = await ctrl().save(speakerId: s.id);
      expect(saved!.name, 'خالد');
      expect(saved.lowConfidence, isFalse);
      expect(saved.embeddingCount, greaterThan(10));
    });

    test('missing models → error flagged for the models page', () async {
      env.analyzerError = const EnrollmentModelsMissingException();
      await ctrl().start();
      env.mics.recording!.emit(readingTake());
      await settle();
      await ctrl().stop();
      expect(st().phase, EnrollmentPhase.error);
      expect(st().modelsMissing, isTrue);
      expect(st().errorAr, VoiceStrings.speakerModelMissing);
    });

    test('refuses while a meeting is recording', () async {
      env.busy = true;
      env.container.invalidate(meetingRecordingActiveProvider);
      await ctrl().start();
      expect(st().phase, EnrollmentPhase.error);
      expect(st().errorAr, VoiceStrings.busyRecording);
      expect(env.mics.made, isEmpty);
    });

    test('permission denied and start failure release the mic', () async {
      env.mics.permission = false;
      await ctrl().start();
      expect(st().phase, EnrollmentPhase.error);
      expect(env.mics.made.last.disposed, isTrue);
    });

    test('reset discards the take and moves to the next passage', () async {
      ctrl().setLanguage(EnrollmentLanguage.english);
      await ctrl().start();
      final mic = env.mics.recording!;
      mic.emit(tone(1000));
      await ctrl().reset();
      expect(st().phase, EnrollmentPhase.idle);
      expect(st().language, EnrollmentLanguage.english);
      expect(st().passageIndex, 1);
      expect(st().elapsedMs, 0);
      expect(mic.disposed, isTrue);
    });

    test('closing the screen while the mic starts releases it', () async {
      final gate = Completer<void>();
      env.mics.permissionGate = gate.future;
      final starting = ctrl().start();
      await settle();
      keep.close(); // The screen goes away: the provider is disposed.
      await settle();
      gate.complete();
      await starting;
      await settle();
      expect(env.mics.made, isNotEmpty);
      expect(env.mics.made.every((m) => m.disposed), isTrue);
      expect(env.mics.made.any((m) => m.started), isFalse);
      keep = env.container.listen(voiceEnrollmentControllerProvider, (_, _) {});
    });

    test('a take ended by the platform is analysed', () async {
      await ctrl().start();
      final mic = env.mics.recording!;
      mic.emit(readingTake());
      await settle();
      mic.pushState(AudioCaptureState.paused);
      await settle();
      expect(st().warningAr, VoiceStrings.capturePaused);
      mic.pushState(AudioCaptureState.recording);
      await settle();
      expect(st().warningAr, isNull);
      mic.pushState(AudioCaptureState.idle);
      await waitUntil(() => st().phase == EnrollmentPhase.review);
      expect(st().analysis, isNotNull);
      expect(mic.disposed, isTrue);
    });

    test('capture warnings are shown without stopping', () async {
      await ctrl().start();
      env.mics.recording!.warn('تحذير');
      await settle();
      expect(st().warningAr, 'تحذير');
      expect(st().phase, EnrollmentPhase.recording);
    });
  });

  group('MicTestController', () {
    late Env env;
    late ProviderSubscription<MicTestState> keep;

    setUp(() {
      env = Env();
      keep = env.container.listen(micTestControllerProvider, (_, _) {});
    });
    tearDown(() async {
      keep.close();
      await env.dispose();
    });

    MicTestController ctrl() =>
        env.container.read(micTestControllerProvider.notifier);
    MicTestState st() => env.container.read(micTestControllerProvider);

    test('monitor shows level and hints, then stops', () async {
      await ctrl().startMonitor();
      expect(st().phase, MicTestPhase.monitoring);
      final mic = env.mics.recording!;
      expect(mic.archivePath, isNull);
      mic.emit(noise(300));
      mic.emit(tone(3200, amplitude: 0.004));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(st().hint, LiveSignalHint.tooQuiet);
      expect(st().level, 0.5);
      await ctrl().stopMonitor();
      expect(st().phase, MicTestPhase.idle);
      expect(mic.disposed, isTrue);
    });

    test('a capture ended by the platform ends the test', () async {
      await ctrl().startMonitor();
      final mic = env.mics.recording!;
      mic.pushState(AudioCaptureState.idle);
      await waitUntil(() => st().phase == MicTestPhase.error);
      expect(st().errorAr, VoiceStrings.captureEnded);
      expect(mic.disposed, isTrue);

      await ctrl().recordTest();
      final take = env.mics.recording!;
      take.emit(join([noise(500), tone(1500)]));
      await settle();
      take.pushState(AudioCaptureState.idle);
      await waitUntil(() => st().phase == MicTestPhase.recorded);
      expect(st().result, isNotNull);
    });

    test('5 s test: records, summarises, plays and cleans up', () async {
      await ctrl().recordTest();
      expect(st().phase, MicTestPhase.recordingTest);
      final mic = env.mics.recording!;
      expect(mic.archivePath, endsWith('insato_mic_test.wav'));
      mic.emit(join([noise(500), tone(4000), noise(600)]));
      await waitUntil(() => st().phase == MicTestPhase.recorded);
      expect(st().phase, MicTestPhase.recorded);
      expect(st().hasRecording, isTrue);
      expect(st().canPlay, isTrue);
      final report = st().result!;
      expect(report.passed, isTrue);
      expect(report.issues, isEmpty);
      expect(report.speechDbfs, closeTo(-17, 2));

      await ctrl().play();
      expect(st().phase, MicTestPhase.playing);
      expect(env.player.played.single, mic.archivePath);
      env.player.complete();
      await settle();
      expect(st().phase, MicTestPhase.recorded);

      final path = mic.archivePath!;
      keep.close();
      env.container.invalidate(micTestControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(File(path).existsSync(), isFalse);
      expect(env.player.disposed, isTrue);
      keep = env.container.listen(micTestControllerProvider, (_, _) {});
    });

    test('a silent test says nothing was heard', () async {
      await ctrl().recordTest();
      env.mics.recording!.emit(noise(5200));
      await waitUntil(() => st().phase == MicTestPhase.recorded);
      expect(st().result!.has(AudioQualityIssueKind.noSpeech), isTrue);
    });

    test('playback failure is a warning', () async {
      await ctrl().recordTest();
      env.mics.recording!.emit(tone(5200));
      await waitUntil(() => st().phase == MicTestPhase.recorded);
      env.player.playError = StateError('codec');
      await ctrl().play();
      expect(st().phase, MicTestPhase.recorded);
      expect(st().warningAr, VoiceStrings.playbackFailed);
    });

    test('refuses while a meeting is recording', () async {
      env.busy = true;
      env.container.invalidate(meetingRecordingActiveProvider);
      await ctrl().startMonitor();
      expect(st().phase, MicTestPhase.error);
      expect(st().errorAr, VoiceStrings.busyRecording);
    });

    test('remembered mic that is gone → default with a warning', () async {
      await InputDevicePreferences(
        settings: AppSettings(env.db),
        db: env.db,
      ).remember(
        const InputDevice(id: '99', label: 'Rode', type: InputDeviceType.usb),
      );
      await ctrl().startMonitor();
      expect(env.mics.recording!.startedWith, isNull);
      expect(st().warningAr, VoiceStrings.rememberedMissing('Rode'));
      await ctrl().stopMonitor();
    });
  });

  group('InputDevicePreferences', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('remembers id and key, and forgets both for the default', () async {
      final prefs = InputDevicePreferences(settings: AppSettings(db), db: db);
      expect((await prefs.load()).isDefault, isTrue);
      await prefs.remember(usb);
      final r = await prefs.load();
      expect(r.id, '17');
      expect(r.key, 'usb|Jabra');
      expect(r.label, 'Jabra');
      expect((await AppSettings(db).load()).inputDeviceId, '17');
      await prefs.remember(null);
      final d = await prefs.load();
      expect(d.isDefault, isTrue);
      expect(d.label, isNull);
    });

    test('a key without an id is ignored', () async {
      final prefs = InputDevicePreferences(settings: AppSettings(db), db: db);
      await prefs.remember(usb);
      await AppSettings(db).setInputDeviceId(null);
      expect((await prefs.load()).isDefault, isTrue);
    });
  });
}
