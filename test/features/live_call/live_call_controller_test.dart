// Live call, end to end on two simulated devices (each with its own
// database, fake microphone and fake speech engines, linked by an
// in-memory relay and WebRTC network): consent gating, configuration,
// streaming, the merged transcript of each device's meeting, the call log
// and the post-call minutes.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/data/database.dart';
import 'package:insato/features/live_call/call_code.dart';
import 'package:insato/features/live_call/call_engine.dart';
import 'package:insato/features/live_call/call_log.dart';
import 'package:insato/features/live_call/call_platform.dart';
import 'package:insato/features/live_call/call_settings.dart';
import 'package:insato/features/live_call/call_transcriber.dart';
import 'package:insato/features/live_call/live_call_providers.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart';

import '../../session/fakes.dart';
import 'fakes.dart';

/// Call platform hooks fake.
class FakeCallHooks implements CallPlatformHooks {
  bool deny = false;
  int started = 0;
  int stopped = 0;
  void Function()? stopButton;

  @override
  Future<void> ensureMicrophonePermission(SessionAudioSource audio) async {
    if (deny) throw const AudioCaptureException('لا إذن');
  }

  @override
  Future<String?> onStreamingStarted({
    required String peerName,
    required void Function() onStopRequested,
  }) async {
    started++;
    stopButton = onStopRequested;
    return null;
  }

  @override
  Future<void> onStreamingStopped() async => stopped++;
}

const fastCallTimeouts = CallTimeouts(
  callerWait: Duration(seconds: 10),
  calleeFind: Duration(seconds: 3),
  handshake: Duration(seconds: 2),
  media: Duration(seconds: 2),
  auth: Duration(seconds: 2),
  reconnect: Duration(milliseconds: 300),
  pingInterval: Duration(milliseconds: 20),
  statsInterval: Duration(milliseconds: 50),
);

/// One simulated device.
class Device {
  Device(this.name, MemoryRelay relay, FakePeerNetwork net) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
        appPathsProvider.overrideWithValue(
          AppPaths(documentsDir: () async => tmp, supportDir: () async => tmp),
        ),
        sessionEnginesFactoryProvider.overrideWithValue(engines),
        sessionAudioSourceProvider.overrideWithValue(FakeAudioSource()),
        sessionPlatformHooksProvider.overrideWithValue(FakeHooks()),
        minutesEngineFactoryProvider.overrideWithValue(
          () async => MinutesEngineHandle(minutes),
        ),
        liveCallAudioSourceProvider.overrideWithValue(audio),
        callPlatformHooksProvider.overrideWithValue(hooks),
        peerTransportFactoryProvider.overrideWithValue(net.create),
        relayConnectorProvider.overrideWithValue(relay.connect),
        callKdfIterationsProvider.overrideWithValue(10),
        callTimeoutsProvider.overrideWithValue(fastCallTimeouts),
        callDeviceNameProvider.overrideWithValue(() => name),
        turnCredentialStoreProvider.overrideWithValue(
          MemoryTurnCredentialStore(),
        ),
      ],
    );
  }

  final String name;
  final AppDatabase db = memoryDb();
  final Directory tmp = Directory.systemTemp.createTempSync('insato_call_');
  final FakeAudioSource audio = FakeAudioSource()..writeWavOnStop = true;
  final FakeEnginesFactory engines = FakeEnginesFactory();
  final FakeCallHooks hooks = FakeCallHooks();
  final FakeMinutesEngine minutes = FakeMinutesEngine();
  late final ProviderContainer container;

  LiveCallController get call =>
      container.read(liveCallControllerProvider.notifier);
  LiveCallState get state => container.read(liveCallControllerProvider);

  Future<void> configure({
    String url = 'wss://relay.test',
    bool consent = true,
  }) => container
      .read(liveCallSettingsStoreProvider)
      .save(
        LiveCallSettings(signalingUrl: url, consentAcknowledged: consent),
      );

  Future<void> dispose() async {
    container.dispose();
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  }
}

Future<void> until(
  FutureOr<bool> Function() cond, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final sw = Stopwatch()..start();
  while (!await cond()) {
    if (sw.elapsed > timeout) fail('condition not met in $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late MemoryRelay relay;
  late FakePeerNetwork net;
  late Device a;
  late Device b;
  setUp(() {
    relay = MemoryRelay();
    net = FakePeerNetwork();
    a = Device('حاسوب الأمانة', relay, net);
    b = Device('هاتف أحمد', relay, net);
  });
  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  test('consent is required before the first call; nothing connects', () async {
    await a.configure(consent: false);
    await expectLater(
      a.call.startCall(),
      throwsA(isA<CallConsentRequiredException>()),
    );
    expect(relay.connections, 0);
    expect(net.peers, isEmpty);
    expect(a.state.call, isNull);
    // Accepting the notice stores it and starts the call.
    await a.call.startCall(consentGiven: true);
    expect(relay.connections, 1);
    final s = await a.container.read(liveCallSettingsStoreProvider).load();
    expect(s.consentAcknowledged, isTrue);
    await a.call.hangUp();
    await a.call.finished;
    expect(a.hooks.started, 0); // Never streamed.
  });

  test('no relay configured / no microphone / missing models', () async {
    await a.configure(url: '');
    await expectLater(
      a.call.startCall(),
      throwsA(isA<CallNotConfiguredException>()),
    );
    await a.configure();
    a.hooks.deny = true;
    await expectLater(a.call.startCall(), throwsA(isA<AudioCaptureException>()));
    a.hooks.deny = false;
    a.engines.notReady = const ModelException('نماذج ناقصة');
    await expectLater(a.call.startCall(), throwsA(isA<ModelException>()));
    expect(relay.connections, 0);
  });

  test('two devices: live lines, merged meetings, call log, minutes', () async {
    await a.configure();
    // The joiner has no relay of its own: the QR invite carries it.
    await b.configure(url: '');
    await a.call.startCall();
    await until(() => a.state.call!.phase == CallPhase.waitingForPeer);
    final invite = a.state.call!.invite!;
    await b.call.joinCall(CallInvite.tryParse(invite.toUri())!);
    await until(() => a.state.meetingId != null && b.state.meetingId != null);
    await until(() => a.audio.started && b.audio.started);
    expect(a.hooks.started, 1);
    expect(b.hooks.started, 1);
    // The transcription runs with short segments.
    expect(a.engines.lastRequest!.maxSegmentSeconds, kCallMaxSegmentSeconds);

    // A speaks, then (later) B; B's room also has silence.
    a.audio.emit(voiceSamples(0, 1500));
    await until(() => b.state.call!.lines.any((l) => !l.pending));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    b.audio.emit(voiceSamples(null, 500)); // silence → dropped placeholder
    b.audio.emit(voiceSamples(1, 1500));
    await until(
      () => a.state.call!.lines.where((l) => !l.pending).length == 2,
    );
    expect(a.state.call!.lines.where((l) => l.pending), isEmpty);
    expect(
      a.state.call!.lines.map((l) => l.text),
      ['كلام 0', 'كلام 1'],
    );

    // Mute on B: silence goes to its VAD, the flag reaches A.
    await b.call.setMuted(true);
    await until(() => a.state.call!.peerMuted);
    b.audio.emit(voiceSamples(2, 1000));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(a.state.call!.lines.where((l) => !l.pending), hasLength(2));
    await b.call.setMuted(false);

    // One tap on A's notification button ends the call on both devices.
    a.hooks.stopButton!();
    await until(() => a.state.call!.phase.isOver && b.state.call!.phase.isOver);
    await a.call.finished;
    await b.call.finished;
    expect(a.state.call!.endReason, CallEndReason.localHangUp);
    expect(b.state.call!.endReason, CallEndReason.remoteHangUp);
    expect(a.hooks.stopped, 1);
    expect(b.hooks.stopped, 1);

    for (final (d, peer) in [(a, b), (b, a)]) {
      final id = d.state.savedMeetingId!;
      final meetings = d.container.read(meetingRepositoryProvider);
      final m = (await meetings.get(id))!;
      expect(m.title, contains('مكالمة مع ${peer.name}'));
      expect(m.audioPath, isNotNull); // This device's microphone.
      final segs = await d.container
          .read(segmentRepositoryProvider)
          .getForMeeting(id);
      expect(segs.map((s) => s.text), ['كلام 0', 'كلام 1']);
      expect(segs.map((s) => s.index), [0, 1]);
      expect(segs[0].startMs <= segs[1].startMs, isTrue);
      final speakers = await d.container
          .read(speakerRepositoryProvider)
          .getAllById();
      final remoteSeg = d == a ? segs[1] : segs[0];
      expect(remoteSeg.speakerLocked, isTrue);
      expect(speakers[remoteSeg.speakerId]!.name, 'متحدث 1 (${peer.name})');
      final log = (await d.container.read(liveCallLogStoreProvider).load(id))!;
      expect(log.localName, d.name);
      expect(log.remoteName, peer.name);
      expect(log.endedAt, isNotNull);
      expect(log.safetyCode, isNotNull);
      expect(log.events.first.kind, 'start');
      expect(log.events.last.kind, 'stop');
      expect(log.events.last.byRemote, d == b);
      expect(
        log.events.where((e) => e.kind == 'mute'),
        hasLength(1),
      );
      expect(log.events.firstWhere((e) => e.kind == 'mute').byRemote, d == a);
      await until(() => d.minutes.calls > 0);
    }
    // The log is deleted with the meeting.
    final id = a.state.savedMeetingId!;
    await a.container.read(meetingRepositoryProvider).delete(id);
    expect(await a.container.read(liveCallLogStoreProvider).load(id), isNull);
  });

  test('a recording in progress blocks a call', () async {
    await a.configure();
    await a.container
        .read(meetingSessionControllerProvider.notifier)
        .start(consentGiven: true);
    await expectLater(a.call.startCall(), throwsA(isA<CallBusyException>()));
    await a.container.read(meetingSessionControllerProvider.notifier).stop();
  });
}
