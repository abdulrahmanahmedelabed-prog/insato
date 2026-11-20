// Live call: the call state machine with an in-memory relay and a fake
// WebRTC network — setup, authentication, safety code, clock sync, live
// lines both ways, echo retraction, mute, reconnection, hang-up and the
// failure paths (wrong code, forged fingerprint, blocked network).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/live_call/call_engine.dart';
import 'package:insato/features/live_call/data_messages.dart';
import 'package:insato/features/live_call/transcript_merge.dart';
import 'package:insato/features/multi_device/clock_sync.dart'
    show MonotonicClock;

import 'fakes.dart';

const _code = 'K7QM2XPA9DTR';

const _fast = CallTimeouts(
  callerWait: Duration(seconds: 5),
  calleeFind: Duration(seconds: 2),
  handshake: Duration(milliseconds: 600),
  media: Duration(milliseconds: 800),
  auth: Duration(milliseconds: 600),
  reconnect: Duration(milliseconds: 300),
  pingInterval: Duration(milliseconds: 20),
  statsInterval: Duration(milliseconds: 50),
);

class _Pair {
  _Pair({String calleeCode = _code, int calleeSkewUs = 0}) {
    caller = LiveCallEngine(
      role: CallRole.caller,
      code: _code,
      signalingUrl: 'wss://relay.test',
      localName: 'حاسوب الأمانة',
      localPlatform: 'windows',
      peerFactory: net.create,
      relayConnector: relay.connect,
      timeouts: _fast,
      kdfIterations: 10,
    );
    callee = LiveCallEngine(
      role: CallRole.callee,
      code: calleeCode,
      signalingUrl: 'wss://relay.test',
      localName: 'هاتف أحمد',
      localPlatform: 'android',
      peerFactory: net.create,
      relayConnector: relay.connect,
      timeouts: _fast,
      kdfIterations: 10,
      clockUs: () => MonotonicClock.instance.nowUs() + calleeSkewUs,
    );
  }

  final relay = MemoryRelay();
  final net = FakePeerNetwork();
  late final LiveCallEngine caller;
  late final LiveCallEngine callee;

  Future<void> start() async {
    await caller.start();
    await callee.start();
  }

  Future<void> dispose() async {
    await caller.dispose();
    await callee.dispose();
  }
}

Future<void> _until(
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > timeout) fail('condition not met in $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

LiveLine _local(LiveCallEngine e, String id, String text, {int offsetMs = 0}) =>
    LiveLine(
      id: id,
      origin: LineOrigin.local,
      atUs: e.nowUs() - 2000000 + offsetMs * 1000,
      durMs: 1800,
      text: text,
      speakerKey: 'spk-$id',
      speakerName: 'متحدث 1',
      language: 'ar',
    );

void main() {
  test('caller waits with its code; nothing streams before a person joins', () async {
    final p = _Pair();
    await p.caller.start();
    expect(p.caller.snapshot.phase, CallPhase.waitingForPeer);
    expect(p.caller.snapshot.invite!.code, _code);
    expect(p.caller.snapshot.invite!.signalingUrl, 'wss://relay.test');
    expect(p.net.peers, isEmpty); // No microphone / WebRTC yet.
    await p.caller.hangUp();
    expect(p.caller.snapshot.phase, CallPhase.ended);
    expect(p.caller.snapshot.endReason, CallEndReason.localHangUp);
    await p.dispose();
  });

  test('full call: auth, safety code, sync, lines both ways, hang-up', () async {
    final p = _Pair(calleeSkewUs: 5 * 1000 * 1000);
    final callerEvents = <CallTranscriptEvent>[];
    final calleeEvents = <CallTranscriptEvent>[];
    p.caller.transcriptEvents.listen(callerEvents.add);
    p.callee.transcriptEvents.listen(calleeEvents.add);
    await p.start();
    await _until(
      () =>
          p.caller.snapshot.phase == CallPhase.active &&
          p.callee.snapshot.phase == CallPhase.active,
    );
    final a = p.caller.snapshot, b = p.callee.snapshot;
    expect(a.peerName, 'هاتف أحمد');
    expect(b.peerName, 'حاسوب الأمانة');
    expect(a.peerPlatform, 'android');
    expect(a.safetyCode, isNotNull);
    expect(a.safetyCode, b.safetyCode);
    expect(a.connectedAt, isNotNull);
    // STUN by default.
    expect(p.net.configs.first.iceServers.first.urls.first, startsWith('stun:'));
    // ICE candidates were signaled (sealed) both ways.
    await _until(() => p.net.peers.every((x) => x.remoteCandidates.isNotEmpty));

    await _until(() => p.caller.snapshot.clockSynced && p.callee.snapshot.clockSynced);
    // Callee's clock runs 5 s ahead: the caller sees an offset of +5 s.
    expect(p.caller.clockSync.offsetAt(p.caller.nowUs()), closeTo(5e6, 5e4));

    // Pending, then final, from the callee.
    final t0 = p.callee.nowUs() - 1500000;
    p.callee.localPending('c1', t0, 1200);
    await _until(() => p.caller.snapshot.lines.any((l) => l.id == 'c1'));
    expect(p.caller.snapshot.lines.single.pending, isTrue);
    expect(
      p.callee.localFinal(
        LiveLine(
          id: 'c1',
          origin: LineOrigin.local,
          atUs: t0,
          durMs: 1200,
          text: 'صباح الخير جميعا',
          speakerKey: 'S9',
          speakerName: 'أحمد',
        ),
      ),
      isTrue,
    );
    await _until(
      () => p.caller.snapshot.lines.any((l) => l.id == 'c1' && !l.pending),
    );
    final remote = p.caller.snapshot.lines.singleWhere((l) => l.id == 'c1');
    expect(remote.origin, LineOrigin.remote);
    expect(remote.speakerName, 'أحمد');
    expect(remote.speakerKey, 'S9');
    // Mapped back onto the caller's clock (5 s skew removed).
    expect(remote.atUs, closeTo(t0 - 5e6, 5e4));
    expect(callerEvents.whereType<RemoteLineFinal>().single.line.text,
        'صباح الخير جميعا');

    // A line of the caller, later in time: ordered after.
    expect(p.caller.localFinal(_local(p.caller, 'h1', 'أهلا بكم', offsetMs: 4000)), isTrue);
    await _until(() => p.callee.snapshot.lines.length == 2);
    expect(p.caller.snapshot.lines.map((l) => l.id), ['c1', 'h1']);
    expect(p.callee.snapshot.lines.map((l) => l.id), ['c1', 'h1']);

    // Speaking indicator.
    p.callee.localActivity(speaking: true, level: 0.6);
    await _until(() => p.caller.snapshot.remoteSpeaking);
    expect(p.caller.snapshot.remoteLevel, closeTo(0.6, 0.01));

    // Stats.
    await _until(() => p.caller.snapshot.quality == CallQuality.good);

    await p.callee.hangUp();
    await _until(() => p.caller.snapshot.phase.isOver);
    expect(p.caller.snapshot.phase, CallPhase.ended);
    expect(p.caller.snapshot.endReason, CallEndReason.remoteHangUp);
    expect(p.callee.snapshot.endReason, CallEndReason.localHangUp);
    await p.dispose();
  });

  test('echo: a local copy of the peer speech is retracted on one side only', () async {
    final p = _Pair();
    final callerEvents = <CallTranscriptEvent>[];
    p.caller.transcriptEvents.listen(callerEvents.add);
    await p.start();
    await _until(() => p.callee.snapshot.phase == CallPhase.active &&
        p.caller.snapshot.phase == CallPhase.active);
    // The callee says something; it also reaches the caller's microphone
    // 400 ms later through the loudspeaker.
    final orig = _local(p.callee, 'o1', 'سنرسل التقرير إلى اللجنة غدا');
    // The caller's echo is stored first (arrives before the original).
    final echo = LiveLine(
      id: 'e1',
      origin: LineOrigin.local,
      atUs: orig.atUs + 400000,
      durMs: 1800,
      text: 'سنرسل التقرير الى اللجنه غدا',
    );
    expect(p.caller.localFinal(echo), isTrue);
    expect(p.callee.localFinal(orig), isTrue);
    await _until(() => callerEvents.whereType<LocalLineRetracted>().isNotEmpty);
    expect(callerEvents.whereType<LocalLineRetracted>().single.id, 'e1');
    await _until(() => !p.callee.snapshot.lines.any((l) => l.id == 'e1'));
    expect(p.caller.snapshot.lines.map((l) => l.id), ['o1']);
    expect(p.callee.snapshot.lines.map((l) => l.id), ['o1']);

    // An echo produced after the original arrived is dropped at once.
    final orig2 = _local(p.callee, 'o2', 'الموعد القادم يوم الأحد صباحا');
    p.callee.localFinal(orig2);
    await _until(() => p.caller.snapshot.lines.any((l) => l.id == 'o2'));
    final remoteO2 = p.caller.snapshot.lines.firstWhere((l) => l.id == 'o2');
    final late = LiveLine(
      id: 'e2',
      origin: LineOrigin.local,
      atUs: remoteO2.atUs + 300000,
      durMs: 1500,
      text: 'الموعد القادم يوم الاحد صباحا',
    );
    expect(p.caller.localFinal(late), isFalse);
    await p.dispose();
  });

  test('mute is signaled; link drop → reconnecting → active', () async {
    final p = _Pair();
    await p.start();
    await _until(() => p.caller.snapshot.phase == CallPhase.active &&
        p.callee.snapshot.phase == CallPhase.active);
    await p.callee.setMuted(true);
    expect(p.net.peers.where((x) => x.muted), hasLength(1));
    await _until(() => p.caller.snapshot.peerMuted);
    await p.callee.setMuted(false);
    await _until(() => !p.caller.snapshot.peerMuted);

    final phases = <CallPhase>[];
    p.caller.snapshots.listen((s) => phases.add(s.phase));
    await p.net.drop(recover: true);
    await _until(() => phases.contains(CallPhase.reconnecting));
    await _until(() => p.caller.snapshot.phase == CallPhase.active);

    // A drop that does not recover ends the call (normally: it was active).
    await p.net.drop();
    await _until(() => p.caller.snapshot.phase.isOver);
    expect(p.caller.snapshot.endReason, CallEndReason.networkLost);
    expect(p.caller.snapshot.phase, CallPhase.ended);
    await p.dispose();
  });

  test('wrong code: the callee never finds the call', () async {
    final p = _Pair(calleeCode: 'K7QM2XPA9DT0');
    await p.start();
    await _until(() => p.callee.snapshot.phase.isOver);
    // Different code → different room: the call is simply not found.
    expect(p.callee.snapshot.endReason, CallEndReason.notFound);
    expect(p.callee.snapshot.phase, CallPhase.failed);
    expect(p.caller.snapshot.phase, CallPhase.waitingForPeer);
    expect(p.net.peers, isEmpty);
    await p.dispose();
  });

  test('a forged certificate fingerprint is refused before streaming', () async {
    final p = _Pair();
    p.net.tamperData = (from, text) {
      final j = jsonOf(text);
      if (j['t'] != 'auth') return text;
      return AuthMessage(
        fingerprint: 'sha-256 00:11:22',
        mac: Uint8List(32),
      ).encode();
    };
    await p.start();
    await _until(() => p.caller.snapshot.phase.isOver &&
        p.callee.snapshot.phase.isOver);
    expect(p.caller.snapshot.endReason, CallEndReason.securityFailure);
    expect(p.caller.snapshot.connectedAt, isNull);
    expect(p.caller.snapshot.phase, CallPhase.failed);
    await p.dispose();
  });

  test('a blocked network fails with connectFailed', () async {
    final p = _Pair();
    p.net.blocked = true;
    await p.start();
    // Whichever side gives up first fails with connectFailed; the caller
    // then waits for a new attempt with the same code, the callee fails too.
    await _until(() => p.callee.snapshot.phase.isOver);
    expect(p.callee.snapshot.endReason, CallEndReason.connectFailed);
    await _until(
      () =>
          p.caller.snapshot.phase == CallPhase.waitingForPeer ||
          p.caller.snapshot.endReason == CallEndReason.connectFailed,
    );
    expect(p.caller.snapshot.connectedAt, isNull);
    await p.dispose();
  });

  test('an unreachable relay fails at once', () async {
    final e = LiveCallEngine(
      role: CallRole.caller,
      code: _code,
      signalingUrl: 'wss://nowhere',
      localName: 'x',
      localPlatform: 'ios',
      peerFactory: FakePeerNetwork().create,
      relayConnector: (_) async => throw StateError('offline'),
      kdfIterations: 10,
    );
    await e.start();
    expect(e.snapshot.phase, CallPhase.failed);
    expect(e.snapshot.endReason, CallEndReason.relayUnavailable);
    await e.dispose();
  });

  test('a third device with the code is refused (room full)', () async {
    final p = _Pair();
    await p.start();
    await _until(() => p.caller.snapshot.phase == CallPhase.active);
    final third = LiveCallEngine(
      role: CallRole.callee,
      code: _code,
      signalingUrl: 'wss://relay.test',
      localName: 'دخيل',
      localPlatform: 'android',
      peerFactory: p.net.create,
      relayConnector: p.relay.connect,
      timeouts: _fast,
      kdfIterations: 10,
    );
    await third.start();
    await _until(() => third.snapshot.phase.isOver);
    expect(third.snapshot.endReason, CallEndReason.callFull);
    expect(p.caller.snapshot.phase, CallPhase.active);
    await third.dispose();
    await p.dispose();
  });
}
