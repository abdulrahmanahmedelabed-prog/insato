// Phone-call mode in the post-processing: side partitions in the speaker
// refinement, telephone voiceprint tags and the minutes hint.

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/phone_call/phone_call.dart';
import 'package:insato/session/post_processor.dart';

import '../../session/fakes.dart' show embeddingOf, memoryDb;

void main() {
  late AppDatabase db;
  late MeetingRepository meetings;
  late SegmentRepository segments;
  late SpeakerRepository speakers;
  late PhoneCallLogStore store;
  late PostProcessor post;
  late Meeting meeting;

  setUp(() async {
    db = memoryDb();
    meetings = MeetingRepository(db);
    segments = SegmentRepository(db);
    speakers = SpeakerRepository(db);
    store = PhoneCallLogStore(db);
    post = PostProcessor(
      db: db,
      meetings: meetings,
      segments: segments,
      speakers: speakers,
      settings: AppSettings(db),
      channelProfilesOf: store.partitions,
      callHintOf: store.minutesHint,
      segmentVoiceDevicesOf: store.segmentVoiceDevices,
    );
    meeting = await meetings.create(
      title: 'مكالمة مع الفرع',
      inputDevice: 'builtIn|Mic',
    );
  });
  tearDown(() => db.close());

  var seed = 0;
  Future<TranscriptSegment> add(int i, int voice, String? speakerId) =>
      segments.insert(
        TranscriptSegment(
          id: '',
          meetingId: meeting.id,
          index: i,
          startMs: i * 4000,
          endMs: i * 4000 + 3000,
          text: 'جملة $i',
          speakerId: speakerId,
          embedding: embeddingOf(voice, ++seed, noise: 0.05),
        ),
      );

  test('refinement keeps the sides apart; remote voiceprints are tagged '
      'as telephone; the minutes know the call', () async {
    final local = await speakers.create(name: 'سارة', isNamedByUser: true);
    final remote = await speakers.create();
    // The same-sounding voice on both sides (e.g. one person heard in the
    // room and a relative on the line): the voices alone would merge them.
    final sides = <String, CallSide>{};
    for (var i = 0; i < 6; i++) {
      final isRemote = i.isOdd;
      final s = await add(i, 0, isRemote ? remote.id : local.id);
      sides[s.id] = isRemote ? CallSide.remote : CallSide.local;
    }
    await store.save(
      meeting.id,
      PhoneCallLog(mode: PhoneCallMode.phoneLink, sides: sides),
    );

    final report = await post.refine(
      meeting.id,
      sessionCreatedSpeakerIds: {remote.id},
    );
    expect(report.clusters, 2);
    final after = await segments.getForMeeting(meeting.id);
    final bySide = <CallSide, Set<String?>>{};
    for (final s in after) {
      (bySide[sides[s.id]!] ??= {}).add(s.speakerId);
    }
    expect(bySide[CallSide.local], hasLength(1));
    expect(bySide[CallSide.remote], hasLength(1));
    expect(bySide[CallSide.local], isNot(bySide[CallSide.remote]));

    final localId = bySide[CallSide.local]!.single!;
    final remoteId = bySide[CallSide.remote]!.single!;
    expect((await speakers.get(localId))!.voiceDevice, 'builtIn|Mic');
    expect(
      (await speakers.get(remoteId))!.voiceDevice,
      kTelephoneVoiceDeviceKey,
    );

    final inputs = await post.minutesInputsFor(
      meeting,
      await speakers.getAllById(),
    );
    expect(inputs.call?.mode, 'phone_link');
    expect(inputs.call?.remoteSegmentIds, {
      for (final e in sides.entries)
        if (e.value == CallSide.remote) e.key,
    });
  });

  test('ordinary meetings get no call hint', () async {
    final inputs = await post.minutesInputsFor(
      meeting,
      await speakers.getAllById(),
    );
    expect(inputs.call, isNull);
  });
}
