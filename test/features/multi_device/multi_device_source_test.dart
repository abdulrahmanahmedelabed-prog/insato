// The host's session source over a real hub (localhost sockets) and a real
// guest client.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/features/multi_device/fusion_engine.dart';
import 'package:insato/features/multi_device/guest_client.dart';
import 'package:insato/features/multi_device/host_server.dart';
import 'package:insato/features/multi_device/hub.dart';
import 'package:insato/features/multi_device/meeting_log.dart';
import 'package:insato/features/multi_device/multi_device_source.dart';
import 'package:insato/features/multi_device/protocol.dart';
import 'package:insato/features/multi_device/secure_channel.dart';
import 'package:insato/features/multi_device/clock_sync.dart';

import '../../session/fakes.dart';
import 'sim.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late MultiDeviceHub hub;
  late FakeAudioSource local;
  late MultiDeviceSessionAudioSource source;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('insato_md_');
    final host = await MultiDeviceHost.start(
      hostName: 'المضيف',
      bindAddress: InternetAddress.loopbackIPv4,
      code: 'K7QM2XPA9DTR',
      kdfIterations: 10,
      localAddresses: () async => ['127.0.0.1'],
      config: const HostConfig(pingInterval: Duration(milliseconds: 40)),
    );
    hub = MultiDeviceHub(host, viewInterval: const Duration(milliseconds: 20));
    local = FakeAudioSource();
    source = MultiDeviceSessionAudioSource(
      local: local,
      hub: hub,
      logStore: MultiDeviceLogStore(db),
      config: const FusionConfig(latencySamples: 1600),
    );
  });

  tearDown(() async {
    await source.dispose();
    await hub.close();
    await db.close();
    await tmp.delete(recursive: true);
  });

  test(
    'without guests the take is the host signal, archived, full length',
    () async {
      final out = <Float32List>[];
      source.frames.listen(out.add);
      final path = '${tmp.path}/a.wav';
      await source.start(archivePath: path);
      expect(local.archivePath, isNull, reason: 'the fused stream is archived');
      final x = syntheticSpeech(16000);
      for (var k = 0; k < 10; k++) {
        local.emit(Float32List.sublistView(x, k * 1600, (k + 1) * 1600));
      }
      await Future<void>.delayed(Duration.zero);
      await source.stop();
      await Future<void>.delayed(Duration.zero);
      final all = Float32List.fromList([for (final f in out) ...f]);
      expect(all, x);
      expect((await readWavInfo(path)).frameCount, 16000);
      final seg = SpeechSegment(
        index: 0,
        startMs: 100,
        samples: Float32List(1600),
      );
      expect(source.fuseSegment(seg).channels, isNull);
      expect(source.activeAudioSource, 'mic');
    },
  );

  test('a guest is recorded, fused per segment and logged', () async {
    final guest = await MultiDeviceGuest.connect(
      hosts: ['127.0.0.1'],
      port: hub.host.port,
      pairingKey: await derivePairingKey('K7QM2XPA9DTR', iterations: 10),
      guestId: 'phone-1',
      name: 'هاتف سارة',
      platform: 'android',
    );
    final states = <String>[];
    guest.events.listen((e) {
      if (e is HostStateChanged) states.add(e.state);
    });
    await waitUntil(() => hub.clockOf('phone-1')?.isReady ?? false);
    final out = <Float32List>[];
    source.frames.listen(out.add);
    await source.start();
    await waitUntil(() => states.contains(HostState.recording));

    // The guest sits by the talker: it hears her 4× louder.
    final talk = mixSignals([
      (1, syntheticSpeech(16000 * 3, seed: 8)),
      (1, noise(16000 * 3)),
    ], 16000 * 3);
    // Real-time pacing on a fixed schedule (not "as fast as possible"): both
    // devices then estimate the same sample clock, so the guest's frames land
    // where the host expects them however loaded the test machine is. Each
    // host frame is only captured once the guest's frame of the same instant
    // has reached the host, so the mix always sees it within its latency.
    final framer = GuestAudioFramer();
    final t0 = MonotonicClock.instance.nowUs() + 20000;
    var sent = 0;
    for (var k = 0; k < 30; k++) {
      final due = t0 + k * 100000;
      final wait = due - MonotonicClock.instance.nowUs();
      if (wait > 0) await Future<void>.delayed(Duration(microseconds: wait));
      final f = Float32List.sublistView(talk, k * 1600, (k + 1) * 1600);
      for (final (start, us, s) in framer.add(
        Float32List.fromList([for (final v in f) v * 0.8]),
        due,
      )) {
        guest.sendAudio(startIndex: start, captureUs: us, samples: s);
        sent++;
      }
      await waitUntil(
        () => (source.engine!.statsOf('phone-1')?.framesReceived ?? 0) >= sent,
      );
      local.emit(Float32List.fromList([for (final v in f) v * 0.2]));
    }
    final fused = source.fuseSegment(
      SpeechSegment(index: 0, startMs: 1000, samples: Float32List(16000)),
    );
    expect(fused.channels, isNotNull);
    expect(
      fused.channels!.snrDb.keys,
      unorderedEquals([kHostChannelId, 'phone-1']),
    );
    expect(fused.channels!.nearest, 'phone-1');
    // The guest's own (louder) audio goes to ASR, not the host's.
    double energy(Float32List x) => x.fold(0.0, (a, v) => a + v * v);
    final hostPart = Float32List.fromList([
      for (var i = 16000; i < 32000; i++) talk[i] * 0.2,
    ]);
    expect(energy(fused.segment.samples) / energy(hostPart), greaterThan(8));

    final views = hub.current;
    expect(views.single.name, 'هاتف سارة');
    expect(views.single.connected, isTrue);

    await source.pause();
    await waitUntil(() => states.contains(HostState.paused));
    await source.resume();
    await source.stop();
    await waitUntil(() => states.contains(HostState.ended));
    expect(out.fold(0, (a, f) => a + f.length), 30 * 1600);

    await source.finishTake(
      meetingId: 'm1',
      segmentProfiles: {'seg-1': fused.channels!},
    );
    final log = (await MultiDeviceLogStore(db).load('m1'))!;
    expect(log.devices.single.name, 'هاتف سارة');
    expect(log.devices.single.segmentsChosen, 1);
    expect(log.events.first.kind, 'joined');
    expect(log.segmentProfiles['seg-1']!.nearest, 'phone-1');
    expect(await MultiDeviceLogStore(db).profiles('m1'), hasLength(1));
    await guest.close();
  });

  test('a guest dropping mid-meeting is recorded as a gap', () async {
    final guest = await MultiDeviceGuest.connect(
      hosts: ['127.0.0.1'],
      port: hub.host.port,
      pairingKey: await derivePairingKey('K7QM2XPA9DTR', iterations: 10),
      guestId: 'pc-2',
      name: 'حاسوب',
      platform: 'windows',
    );
    await waitUntil(() => hub.connectedIds.contains('pc-2'));
    await source.start();
    for (var k = 0; k < 20; k++) {
      local.emit(Float32List(1600));
    }
    await guest.close();
    await waitUntil(() => hub.connectedIds.isEmpty);
    for (var k = 0; k < 20; k++) {
      local.emit(Float32List(1600));
    }
    await source.stop();
    await source.finishTake(meetingId: 'm2', segmentProfiles: const {});
    final log = (await MultiDeviceLogStore(db).load('m2'))!;
    expect([for (final e in log.events) e.kind], ['joined', 'left']);
    expect(log.gaps.single.deviceId, 'pc-2');
    expect(log.gaps.single.endMs, isNull);
    expect(log.gaps.single.startMs, 2000);
    expect(hub.current.single.connected, isFalse);
    expect(hub.current.single.drops, 1);
    expect(networkQualityOf(rttMs: 5), NetworkQuality.good);
    expect(networkQualityOf(rttMs: 100), NetworkQuality.fair);
    expect(networkQualityOf(rttMs: 5, lossRate: 0.2), NetworkQuality.poor);
  });

  test('log JSON tolerates junk and computes gaps', () {
    final log = MultiDeviceMeetingLog.fromJson({
      'devices': [
        {'id': 'a', 'name': 'أ'},
        'junk',
      ],
      'events': [
        {'id': 'a', 'kind': 'joined', 'at_ms': 0},
        {'id': 'a', 'kind': 'left', 'at_ms': 1000},
        {'id': 'a', 'kind': 'rejoined', 'at_ms': 5000},
        {'id': 'a', 'kind': 'bad'},
      ],
      'profiles': {
        's': {'host': 3, 'a': 9},
        'x': 'y',
      },
    })!;
    expect(log.devices.single.id, 'a');
    expect(log.nameOf('a'), 'أ');
    expect(log.nameOf('zz'), 'zz');
    expect(log.gaps.single.endMs, 5000);
    expect(log.segmentProfiles.keys, ['s']);
    expect(MultiDeviceMeetingLog.fromJson('x'), isNull);
  });
}
