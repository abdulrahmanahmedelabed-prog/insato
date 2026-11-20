import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/multi_device/alignment.dart';
import 'package:insato/features/multi_device/clock_sync.dart';
import 'package:insato/features/multi_device/fusion_engine.dart';

import 'sim.dart';

const int _rate = 16000;

/// One simulated device: hears [signal] (acoustic time, 16 kHz) from
/// [startUs] (true time of its sample 0), delivers 100 ms capture frames
/// [inputLatencyUs] + 0–[jitterUs] after capture, on a CPU clock
/// `offsetUs + t·(1 + driftPpm)`.
class _Device {
  _Device({
    required this.signal,
    required this.startUs,
    required this.inputLatencyUs,
    required this.offsetUs,
    required this.driftPpm,
    this.jitterUs = 15000,
    int seed = 1,
  }) : jitter = Jitter(seed);

  final Float32List signal;
  final int startUs;
  final int inputLatencyUs;
  final double offsetUs;
  final double driftPpm;
  final int jitterUs;
  final Jitter jitter;

  int cpu(int trueUs) => (offsetUs + trueUs * (1 + driftPpm * 1e-6)).round();

  /// Sample index k ↔ acoustic sample (startUs·16/1000 + k).
  int get acousticStart => startUs * _rate ~/ 1000000;
}

class _Event {
  _Event(this.atUs, this.run);
  final int atUs;
  final void Function() run;
}

/// Runs [seconds] of a meeting with a host and [guests]; returns the engine.
FusionEngine _simulate({
  required _Device host,
  required Map<String, _Device> guests,
  required int seconds,
  List<Float32List>? emitted,
  Map<String, (int, int)> offline = const {},
  int netJitterUs = 20000,
}) {
  final clocks = {for (final id in guests.keys) id: ClockSyncEstimator()};
  final engine = FusionEngine(clockOf: (id) => clocks[id]);
  for (final id in guests.keys) {
    engine.guestConnected(id);
  }
  final events = <_Event>[];
  final net = Jitter(42);
  const frame = 1600;
  final endUs = seconds * 1000000;

  // Host frames.
  for (var k = 1; host.startUs + k * 100000 < endUs; k++) {
    final captureEnd = host.startUs + k * 100000;
    final at =
        captureEnd + host.inputLatencyUs + host.jitter.next(host.jitterUs);
    final start = (k - 1) * frame;
    final src = host.acousticStart + start;
    events.add(
      _Event(at, () {
        final out = engine.addHostFrame(
          Float32List.sublistView(host.signal, src, src + frame),
          host.cpu(at),
        );
        emitted?.addAll(out);
      }),
    );
  }
  // Guest frames and pings.
  guests.forEach((id, g) {
    final framer = CaptureTimestamper();
    var seq = 0;
    for (var k = 1; g.startUs + k * 100000 < endUs; k++) {
      final captureEnd = g.startUs + k * 100000;
      final guestArrival =
          captureEnd + g.inputLatencyUs + g.jitter.next(g.jitterUs);
      final hostArrival = guestArrival + 3000 + net.next(netJitterUs);
      final start = (k - 1) * frame;
      final src = g.acousticStart + start;
      final s = seq++;
      final off = offline[id];
      final isOffline =
          off != null && captureEnd >= off.$1 && captureEnd < off.$2;
      events.add(
        _Event(guestArrival, () {
          final captureUs = framer.stamp(
            endIndex: start + frame,
            length: frame,
            arrivalUs: g.cpu(guestArrival),
          );
          if (isOffline) return;
          events.add(
            _Event(hostArrival, () {
              engine.addGuestFrame(
                id,
                GuestAudioFrame(
                  seq: s,
                  startIndex: start,
                  captureUs: captureUs,
                  samples: Float32List.sublistView(g.signal, src, src + frame),
                ),
                host.cpu(hostArrival),
              );
            }),
          );
          events.sort((a, b) => a.atUs.compareTo(b.atUs));
        }),
      );
    }
    for (var t1 = 200000; t1 < endUs; t1 += 1000000) {
      final d1 = 2000 + net.next(6000);
      final d2 = 2000 + net.next(6000) + net.spike(0.1, 40000);
      events.add(
        _Event(t1 + d1 + d2, () {
          clocks[id]!.add(
            ClockSample(
              host.cpu(t1),
              g.cpu(t1 + d1),
              g.cpu(t1 + d1) + 100,
              host.cpu(t1 + d1 + d2 + 100),
            ),
          );
        }),
      );
    }
  });
  events.sort((a, b) => a.atUs.compareTo(b.atUs));
  // Process in time order (events may add later events).
  var i = 0;
  while (i < events.length) {
    final e = events[i++];
    e.run();
  }
  return engine;
}

/// Placement error (ms) of guest [id]'s latest frame.
double _placementErrorMs(FusionEngine e, String id, _Device host, _Device g) {
  final st = e.statsOf(id)!;
  final truth = st.lastGuestIndex! + g.acousticStart - host.acousticStart;
  return (st.lastHostPos! - truth) * 1000 / _rate;
}

void main() {
  final room = mixSignals([
    (1, syntheticSpeech(_rate * 75, seed: 5)),
    (1, noise(_rate * 75, seed: 6)),
  ], _rate * 75);

  test('a single device passes through sample for sample, delayed', () {
    final engine = FusionEngine(clockOf: (_) => null);
    final out = <Float32List>[];
    final x = room.sublist(0, _rate * 3);
    for (var k = 0; k < 30; k++) {
      out.addAll(
        engine.addHostFrame(
          Float32List.sublistView(x, k * 1600, (k + 1) * 1600),
          k * 100000,
        ),
      );
    }
    final emittedBeforeFlush = out.fold(0, (a, f) => a + f.length);
    expect(emittedBeforeFlush, _rate * 3 - const FusionConfig().latencySamples);
    out.addAll(engine.flush());
    final all = Float32List.fromList([for (final f in out) ...f]);
    expect(all, x);
    final seg = SpeechSegment(
      index: 0,
      startMs: 500,
      samples: x.sublist(8000, 24000),
    );
    final fused = engine.fuseSegment(seg);
    expect(identical(fused.segment, seg), isTrue);
    expect(fused.profile, isNull);
  });

  test('skewed clocks + unknown input latencies: aligned to < 20 ms', () {
    final host = _Device(
      signal: room,
      startUs: 2000000,
      inputLatencyUs: 20000,
      offsetUs: 0,
      driftPpm: 0,
      seed: 1,
    );
    final guest = _Device(
      signal: mixSignals([
        (0.5, room),
        (1, noise(room.length, seed: 9)),
      ], room.length),
      startUs: 1300000,
      inputLatencyUs: 110000, // Android-like input latency, unknown to NTP
      offsetUs: 5300000,
      driftPpm: 80,
      jitterUs: 25000,
      seed: 2,
    );
    final engine = _simulate(host: host, guests: {'g1': guest}, seconds: 60);
    final err = _placementErrorMs(engine, 'g1', host, guest);
    expect(err.abs(), lessThan(20), reason: 'placement error $err ms');
    expect(err.abs(), lessThan(3), reason: 'cross-correlation lock');
    expect(engine.alignmentOf('g1')!.state, AlignmentState.locked);
    expect(engine.alignmentOf('g1')!.accepted, greaterThan(3));
    final st = engine.statsOf('g1')!;
    expect(st.framesReceived, greaterThan(500));
    // Frames before the clock was known are dropped, never misplaced.
    expect(st.framesDropped, lessThan(40));
  });

  test('without cross-correlation the network estimate alone is off by the '
      'latency difference', () {
    final host = _Device(
      signal: room,
      startUs: 2000000,
      inputLatencyUs: 20000,
      offsetUs: 0,
      driftPpm: 0,
    );
    final guest = _Device(
      signal: Float32List(room.length), // silent: nothing to correlate
      startUs: 1300000,
      inputLatencyUs: 110000,
      offsetUs: -2000000,
      driftPpm: -40,
      seed: 4,
    );
    final engine = _simulate(host: host, guests: {'g1': guest}, seconds: 20);
    final err = _placementErrorMs(engine, 'g1', host, guest);
    expect(err, closeTo(90, 12));
    expect(engine.alignmentOf('g1')!.state, AlignmentState.network);
  });

  test('per segment the nearest device is chosen and its profile recorded', () {
    // Talker A (seconds 20–25) sits by the guest, talker B (30–35) by the
    // host.
    const n = _rate * 45;
    final a = speechAt(n, [(_rate * 21, _rate * 25)], seed: 31);
    final b = speechAt(n, [(_rate * 31, _rate * 35)], seed: 32);
    final hostSig = mixSignals([(0.15, a), (1, b), (1, noise(n, seed: 1))], n);
    final guestSig = mixSignals([(1, a), (0.15, b), (1, noise(n, seed: 2))], n);
    // Plus a shared alignment track early on so the guest locks.
    final cal = syntheticSpeech(_rate * 15, seed: 40);
    for (var i = 0; i < cal.length; i++) {
      hostSig[_rate * 2 + i] += cal[i];
      guestSig[_rate * 2 + i] += 0.6 * cal[i];
    }
    final host = _Device(
      signal: hostSig,
      startUs: 0,
      inputLatencyUs: 20000,
      offsetUs: 0,
      driftPpm: 0,
    );
    final guest = _Device(
      signal: guestSig,
      startUs: 0,
      inputLatencyUs: 60000,
      offsetUs: 900000,
      driftPpm: 30,
      seed: 3,
    );
    final engine = _simulate(host: host, guests: {'g1': guest}, seconds: 44);
    SpeechSegment seg(int fromS, int toS) => SpeechSegment(
      index: 0,
      startMs: fromS * 1000,
      samples: Float32List((toS - fromS) * _rate),
    );
    final fa = engine.fuseSegment(seg(21, 25));
    expect(fa.channelId, 'g1');
    expect(fa.profile!.nearest, 'g1');
    expect(
      fa.profile!.snrDb['g1']! - fa.profile!.snrDb[kHostChannelId]!,
      greaterThan(6),
    );
    // The ASR gets the guest's audio, not the mix.
    final gStart = 21 * _rate;
    final st = engine.statsOf('g1')!;
    expect(st.segmentsChosen, 1);
    var energy = 0.0;
    for (final v in fa.segment.samples) {
      energy += v * v;
    }
    expect(energy, greaterThan(10));
    expect(gStart, greaterThan(0));
    final fb = engine.fuseSegment(seg(31, 35));
    expect(fb.channelId, kHostChannelId);
    expect(fb.profile!.nearest, kHostChannelId);
  });

  test('a guest dropping out leaves a gap; the meeting goes on', () {
    final host = _Device(
      signal: room,
      startUs: 0,
      inputLatencyUs: 20000,
      offsetUs: 0,
      driftPpm: 0,
    );
    final guest = _Device(
      signal: mixSignals([(0.7, room)], room.length),
      startUs: 0,
      inputLatencyUs: 40000,
      offsetUs: 100000,
      driftPpm: 10,
      seed: 8,
    );
    final emitted = <Float32List>[];
    final engine = _simulate(
      host: host,
      guests: {'g1': guest},
      seconds: 40,
      emitted: emitted,
      offline: {'g1': (20000000, 28000000)},
    );
    engine.guestDisconnected('g1');
    engine.guestConnected('g1');
    engine.guestDisconnected('g1', removed: true);
    expect(
      [for (final e in engine.events) e.kind],
      ['joined', 'left', 'rejoined', 'removed'],
    );
    // Output never stopped: the full host timeline minus the latency.
    final total = emitted.fold(0, (a, f) => a + f.length);
    expect(total, engine.hostSamples - const FusionConfig().latencySamples);
    // During the outage only the host covers the audio.
    final gap = engine.fuseSegment(
      SpeechSegment(index: 1, startMs: 23000, samples: Float32List(_rate * 2)),
    );
    expect(gap.channelId, kHostChannelId);
    expect(gap.profile, isNull);
    final before = engine.fuseSegment(
      SpeechSegment(index: 2, startMs: 12000, samples: Float32List(_rate * 2)),
    );
    expect(before.profile, isNotNull);
    expect(engine.statsOf('g1')!.toJson()['received'], greaterThan(0));
  });

  test('pause: guest audio is ignored until resume', () {
    final engine = FusionEngine(
      clockOf: (_) => ClockSyncEstimator()
        ..add(const ClockSample(0, 0, 0, 0))
        ..add(const ClockSample(1, 1, 1, 1))
        ..add(const ClockSample(2, 2, 2, 2)),
    );
    engine.addHostFrame(Float32List(1600), 100000);
    engine.pause();
    engine.addGuestFrame(
      'g',
      GuestAudioFrame(
        seq: 0,
        startIndex: 0,
        captureUs: 50000,
        samples: Float32List(1600),
      ),
      0,
    );
    expect(engine.statsOf('g')!.framesDropped, 1);
    engine.resume(1000000);
    engine.addHostFrame(Float32List(1600), 1100000);
    engine.addGuestFrame(
      'g',
      GuestAudioFrame(
        seq: 1,
        startIndex: 1600,
        captureUs: 500000,
        samples: Float32List(1600),
      ),
      0,
    );
    expect(
      engine.statsOf('g')!.framesDropped,
      2,
      reason: 'captured while paused',
    );
    engine.addGuestFrame(
      'g',
      GuestAudioFrame(
        seq: 2,
        startIndex: 3200,
        captureUs: 1050000,
        samples: Float32List(1600),
      ),
      0,
    );
    expect(engine.statsOf('g')!.framesDropped, 2);
  });

  test('ChannelRing validity, wrap-around and fallback', () {
    final r = ChannelRing(1600, 160);
    r.write(0, Float32List.fromList(List.filled(800, 0.5)));
    expect(r.coverage(0, 800), 1);
    expect(r.coverage(0, 1600), 0.5);
    expect(
      r
          .read(790, 20, fallback: Float32List.fromList(List.filled(20, -1)))
          .sublist(9, 11),
      [0.5, -1],
    );
    // Writing a full ring later invalidates the old blocks.
    r.write(1600, Float32List.fromList(List.filled(1600, 0.25)));
    expect(r.coverage(0, 800), 0);
    expect(r.sampleAt(1700), 0.25);
    expect(r.meanEnergy(0, 100), isNull);
    expect(r.meanEnergy(1600, 160), closeTo(0.0625, 1e-6));
  });
}
