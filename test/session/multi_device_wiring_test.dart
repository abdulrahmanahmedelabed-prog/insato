// v1.2 C wiring in the session: a source that fuses devices gets every VAD
// segment, its per-device SNR profile reaches the speaker tracker, and the
// take's log is stored before the speaker refinement reads it.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/diarization/channel_cue.dart';
import 'package:insato/diarization/speaker_tracker.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart';

import 'fakes.dart';

class _FusingSource extends FakeAudioSource implements SessionSegmentFuser {
  final List<SpeechSegment> fused = [];
  final List<String> calls = [];
  Map<String, ChannelProfile>? stored;

  @override
  ({SpeechSegment segment, ChannelProfile? channels}) fuseSegment(
    SpeechSegment segment,
  ) {
    fused.add(segment);
    calls.add('fuse');
    return (
      segment: segment,
      channels: ChannelProfile({'host': 5, 'g1': 15 + segment.index * 0.1}),
    );
  }

  @override
  Future<void> finishTake({
    required String meetingId,
    required Map<String, ChannelProfile> segmentProfiles,
  }) async {
    calls.add('finish');
    stored = segmentProfiles;
  }
}

void main() {
  late AppDatabase db;
  late Directory tmp;
  late _FusingSource audio;
  late FakeEnginesFactory engines;
  late ProviderContainer container;
  final refineInputs = <RefinementInput>[];

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('insato_md_session_');
    audio = _FusingSource();
    engines = FakeEnginesFactory();
    refineInputs.clear();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
        appPathsProvider.overrideWithValue(
          AppPaths(documentsDir: () async => tmp, supportDir: () async => tmp),
        ),
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
            channelProfilesOf: (id) async {
              audio.calls.add('load');
              return audio.stored ?? const {};
            },
            runRefinement: (input) {
              audio.calls.add('refine');
              refineInputs.add(input);
              return runRefinementInBackground(input);
            },
          ),
        ),
        sessionAudioSourceProvider.overrideWithValue(audio),
        sessionPlatformHooksProvider.overrideWithValue(FakeHooks()),
        sessionEnginesFactoryProvider.overrideWithValue(engines),
        minutesEngineFactoryProvider.overrideWithValue(() async => null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await tmp.delete(recursive: true);
  });

  test(
    'segments are fused, profiles stored and used by the refinement',
    () async {
      await AppSettings(db).setConsentAcknowledged(true);
      final c = container.read(meetingSessionControllerProvider.notifier);
      final id = await c.start(title: 'اجتماع بعدة أجهزة');
      for (final v in [0, 1, 0]) {
        audio.emit(voiceSamples(v, 2000));
      }
      await waitUntil(
        () =>
            engines.asr.calls >= 3 &&
            container
                    .read(meetingSessionControllerProvider)
                    .pendingProcessing ==
                0,
      );
      await c.stop();
      expect(audio.fused, hasLength(3));
      final segs = await SegmentRepository(db).getForMeeting(id);
      expect(audio.stored!.keys.toSet(), {for (final s in segs) s.id});
      // Stored before the refinement loads it.
      expect(audio.calls.where((x) => x != 'fuse'), [
        'finish',
        'load',
        'refine',
      ]);
      expect(refineInputs.single.channelProfiles, hasLength(3));
    },
  );

  test('pipeline keeps profiles per stored segment only when given', () async {
    final speakers = SpeakerRepository(db);
    final meeting = await MeetingRepository(db).create(title: 't');
    final pipeline = SessionPipeline(
      meetingId: meeting.id,
      processor: InlineSegmentProcessor(
        asr: FakeAsr(),
        embedder: FakeEmbedder(),
      ),
      tracker: SpeakerTracker(knownSpeakers: const []),
      speakers: speakers,
      segments: SegmentRepository(db),
    );
    pipeline.submit(
      speech(0, 0, 2000, 0),
      channels: ChannelProfile({'host': 1, 'g': 9}),
    );
    pipeline.submit(speech(1, 3000, 2000, 1));
    await pipeline.drain();
    expect(pipeline.storedCount, 2);
    expect(pipeline.channelProfiles, hasLength(1));
    expect(pipeline.channelProfiles.values.single.nearest, 'g');
  });
}
