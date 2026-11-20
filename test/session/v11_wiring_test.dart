// Session-level wiring of the v1.1 features: the F18 microphone recorded on
// the meeting and the far-field VAD request, the device-aware voiceprint
// threshold, voiceprint device tags after learning, and the F16 profile
// hook after minutes are saved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/diarization/speaker_tracker.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/features/profiles/profile_model.dart';
import 'package:insato/features/profiles/profile_service.dart';

import 'fakes.dart';

void main() {
  group('session start', () {
    late AppDatabase db;
    late Directory tmp;
    late FakeAudioSource audio;
    late FakeEnginesFactory engines;
    late ProviderContainer container;
    String? rememberedDevice;

    setUp(() async {
      db = memoryDb();
      tmp = await Directory.systemTemp.createTemp('insato_wiring_');
      audio = FakeAudioSource();
      engines = FakeEnginesFactory();
      rememberedDevice = null;
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
          appPathsProvider.overrideWithValue(
            AppPaths(
              documentsDir: () async => tmp,
              supportDir: () async => tmp,
            ),
          ),
          sessionAudioSourceProvider.overrideWithValue(audio),
          sessionPlatformHooksProvider.overrideWithValue(FakeHooks()),
          sessionEnginesFactoryProvider.overrideWithValue(engines),
          sessionInputDeviceProvider.overrideWithValue(
            () async => rememberedDevice,
          ),
          minutesEngineFactoryProvider.overrideWithValue(() async => null),
        ],
      );
      await AppSettings(db).save(
        const AppSettingsData(consentAcknowledged: true, keepAudio: false),
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      await tmp.delete(recursive: true);
    });

    MeetingSessionController controller() =>
        container.read(meetingSessionControllerProvider.notifier);

    test('the remembered microphone is stored on the meeting', () async {
      rememberedDevice = 'usb|Jabra Speak 510';
      final id = await controller().start();
      final m = await MeetingRepository(db).get(id);
      expect(m!.inputDevice, 'usb|Jabra Speak 510');
      expect(engines.lastRequest!.farField, isFalse);
      await controller().cancel();
    });

    test('an explicit device wins; far field tunes the VAD request', () async {
      rememberedDevice = 'usb|Jabra Speak 510';
      await AppSettings(db).setFarFieldMode(true);
      final id = await controller().start(inputDevice: 'builtin|Mic');
      final m = await MeetingRepository(db).get(id);
      expect(m!.inputDevice, 'builtin|Mic');
      expect(engines.lastRequest!.farField, isTrue);
      await controller().cancel();
    });
  });

  group('the meeting is tagged with the device actually used', () {
    late AppDatabase db;
    late Directory tmp;
    late ReportingFakeAudioSource audio;
    late ProviderContainer container;

    setUp(() async {
      db = memoryDb();
      tmp = await Directory.systemTemp.createTemp('insato_wiring_');
      audio = ReportingFakeAudioSource();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
          appPathsProvider.overrideWithValue(
            AppPaths(
              documentsDir: () async => tmp,
              supportDir: () async => tmp,
            ),
          ),
          sessionAudioSourceProvider.overrideWithValue(audio),
          sessionPlatformHooksProvider.overrideWithValue(FakeHooks()),
          sessionEnginesFactoryProvider.overrideWithValue(FakeEnginesFactory()),
          sessionInputDeviceProvider.overrideWithValue(() async => 'usb|Jabra'),
          minutesEngineFactoryProvider.overrideWithValue(() async => null),
        ],
      );
      await AppSettings(db).save(
        const AppSettingsData(consentAcknowledged: true, keepAudio: false),
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

    test('remembered mic missing at start: untagged (default mic)', () async {
      audio.deviceKey = null;
      final id = await controller().start();
      expect((await MeetingRepository(db).get(id))!.inputDevice, isNull);
      expect(state().inputDeviceKey, isNull);
      expect(state().farField, isFalse);
      await controller().cancel();
    });

    test('remembered mic present: tagged with it', () async {
      audio.deviceKey = 'usb|Jabra';
      final id = await controller().start();
      expect((await MeetingRepository(db).get(id))!.inputDevice, 'usb|Jabra');
      expect(state().inputDeviceKey, 'usb|Jabra');
      await controller().cancel();
    });

    test('a fallback mid-meeting clears the tag', () async {
      audio.deviceKey = 'usb|Jabra';
      final id = await controller().start();
      audio.fallBack();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((await MeetingRepository(db).get(id))!.inputDevice, isNull);
      expect(state().inputDeviceKey, isNull);
      await controller().cancel();
    });

    test('a system-only take is never tagged with the mic', () async {
      audio
        ..deviceKey = 'system|loopback'
        ..source = 'system';
      final id = await controller().start();
      expect(
        (await MeetingRepository(db).get(id))!.inputDevice,
        'system|loopback',
      );
      expect(state().audioSourceInUse, 'system');
      await controller().cancel();
    });
  });

  test('SessionEngineRequest.fromSettings carries far field', () {
    expect(
      SessionEngineRequest.fromSettings(
        const AppSettingsData(farFieldMode: true),
      ).farField,
      isTrue,
    );
    expect(
      SessionEngineRequest.fromSettings(const AppSettingsData()).farField,
      isFalse,
    );
  });

  test('a per-voiceprint threshold decides whether a voice matches', () {
    final known = Speaker(
      id: 'p1',
      name: 'سارة',
      colorValue: 0xFF000000,
      isNamedByUser: true,
      centroid: voiceOf(0),
      embeddingCount: 10,
      createdAt: DateTime(2026),
    );
    // A noisy sample of voice 0 against a strict and a relaxed threshold.
    final e = embeddingOf(0, 7, noise: 0.6);
    SpeakerAssignment assign(double threshold) => SpeakerTracker(
      knownSpeakers: [known],
      matchThreshold: 0.99,
      knownSpeakerThresholdOf: (_) => threshold,
    ).assign(segmentIndex: 0, startMs: 0, endMs: 3000, embedding: e);
    expect(assign(0.1).linkedSpeakerId, 'p1');
    expect(assign(0.999).linkedSpeakerId, isNull);
  });

  group('post processor', () {
    late AppDatabase db;
    late MeetingRepository meetings;
    late SegmentRepository segments;
    late SpeakerRepository speakers;
    FakeMinutesEngine? engine;
    Map<String, dynamic>? profileJson;

    setUp(() {
      db = memoryDb();
      meetings = MeetingRepository(db);
      segments = SegmentRepository(db);
      speakers = SpeakerRepository(db);
      engine = FakeMinutesEngine();
    });
    tearDown(() => db.close());

    PostProcessor post({Future<void> Function(String)? onMinutesSaved}) =>
        PostProcessor(
          db: db,
          meetings: meetings,
          segments: segments,
          speakers: speakers,
          settings: AppSettings(db),
          minutesEngineFactory: () async => MinutesEngineHandle(engine!),
          onMinutesSaved: onMinutesSaved,
        );

    Future<Meeting> seed({String? device}) async {
      final m = await meetings.create(title: 'اجتماع', inputDevice: device);
      final a = await speakers.create(name: 'هدى');
      for (var i = 0; i < 3; i++) {
        await segments.insert(
          TranscriptSegment(
            id: '',
            meetingId: m.id,
            index: i,
            startMs: i * 3000,
            endMs: i * 3000 + 2500,
            text: 'جملة $i',
            speakerId: a.id,
            embedding: embeddingOf(0, i + 1),
          ),
        );
      }
      return m;
    }

    test('profiles are updated after the minutes are saved', () async {
      final m = await seed();
      final calls = <String>[];
      await post(
        onMinutesSaved: (id) async {
          // The minutes are already stored when the hook runs.
          expect((await meetings.get(id))!.minutes, isNotNull);
          calls.add(id);
        },
      ).regenerateMinutes(m.id);
      expect(calls, [m.id]);
    });

    test('a failing profile update never fails the minutes', () async {
      final m = await seed();
      final minutes = await post(
        onMinutesSaved: (_) async => throw StateError('boom'),
      ).regenerateMinutes(m.id);
      expect(minutes, isNotNull);
      expect((await meetings.get(m.id))!.status, MeetingStatus.ready);
    });

    test('deleting a meeting removes it from stored profiles', () async {
      final m1 = await seed();
      final hoda = (await speakers.getAll()).single;
      final m2 = await meetings.create(title: 'اجتماع سري');
      await segments.insert(
        TranscriptSegment(
          id: '',
          meetingId: m2.id,
          index: 0,
          startMs: 0,
          endMs: 4000,
          text: 'محتوى حساس',
          speakerId: hoda.id,
        ),
      );
      final service = SpeakerProfileService(
        meetings: meetings,
        segments: segments,
        speakers: speakers,
        tasks: TaskRepository(db),
        profiles: SpeakerProfileRepository(db),
        notes: SpeakerMeetingNotesRepository(db),
      );
      await service.setEnabled(hoda.id, true);
      SpeakerProfile stored() => SpeakerProfile.tryParse(profileJson!)!;
      var record = await SpeakerProfileRepository(db).get(hoda.id);
      profileJson = record!.profile;
      expect(stored().perMeeting.map((p) => p.meetingId).toSet(), {
        m1.id,
        m2.id,
      });

      final deleted = await PostProcessor(
        db: db,
        meetings: meetings,
        segments: segments,
        speakers: speakers,
        settings: AppSettings(db),
        onMeetingDeleted: service.updateAfterMeeting,
      ).deleteMeeting(m2.id);
      expect(deleted, isTrue);
      record = await SpeakerProfileRepository(db).get(hoda.id);
      profileJson = record!.profile;
      expect(stored().perMeeting.map((p) => p.meetingId), [m1.id]);
      expect(jsonEncode(record.profile), isNot(contains(m2.id)));
      expect(record.evidence.where((e) => e.meetingId == m2.id), isEmpty);
    });

    test('a new voiceprint remembers the meeting microphone', () async {
      final m = await seed(device: 'usb|Jabra');
      await post().learnFromCorrections(m.id);
      final sp = (await speakers.getAll()).single;
      expect(sp.embeddingCount, greaterThan(0));
      expect(sp.voiceDevice, 'usb|Jabra');
    });
  });
}
