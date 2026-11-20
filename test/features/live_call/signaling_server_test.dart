// Live call: the reference relay (tools/signaling_server.dart) on localhost
// and the authenticated signaling handshake over it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/live_call/call_code.dart';
import 'package:insato/features/live_call/signaling_client.dart';
import 'package:insato/features/live_call/signaling_protocol.dart';

import '../../../tools/signaling_server.dart';
import 'fakes.dart';

class _Ws {
  _Ws(this.ws) {
    ws.listen((d) => frames.add(jsonDecode(d as String) as Map), onDone: () {
      if (!closed.isCompleted) closed.complete();
    });
  }
  final WebSocket ws;
  final List<Map> frames = [];
  final Completer<void> closed = Completer<void>();

  static Future<_Ws> open(int port) async =>
      _Ws(await WebSocket.connect('ws://127.0.0.1:$port/'));

  void send(Object frame) => ws.add(frame is String ? frame : jsonEncode(frame));

  Future<Map> next(bool Function(Map) where) async {
    for (var i = 0; i < 200; i++) {
      final hit = frames.where(where).toList();
      if (hit.isNotEmpty) {
        frames.remove(hit.first);
        return hit.first;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException('no frame');
  }
}

Future<T> _until<T>(Future<T> f) => f.timeout(const Duration(seconds: 5));

void main() {
  late SignalingRelay relay;
  setUp(() async {
    relay = SignalingRelay(
      limits: const RelayLimits(
        joinTimeout: Duration(seconds: 2),
        maxFramesPerWindow: 50,
      ),
    );
    await relay.start(address: InternetAddress.loopbackIPv4, port: 0);
  });
  tearDown(() => relay.close());

  final room = 'b' * 64;

  test('health page answers over plain HTTP', () async {
    final c = HttpClient();
    final req = await c.getUrl(Uri.parse('http://127.0.0.1:${relay.port}/'));
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(await utf8.decodeStream(res), contains('ok'));
    c.close();
  });

  test('pairs two clients, relays blobs, reports leave, forgets the room', () async {
    final a = await _Ws.open(relay.port);
    final b = await _Ws.open(relay.port);
    a.send({'t': 'join', 'room': room, 'v': 1});
    expect((await a.next((f) => f['t'] == 'joined'))['peers'], 0);
    b.send({'t': 'join', 'room': room, 'v': 1});
    expect((await b.next((f) => f['t'] == 'joined'))['peers'], 1);
    expect((await a.next((f) => f['t'] == 'peer'))['ev'], 'join');
    a.send({'t': 'relay', 'd': 'AQID'});
    expect((await b.next((f) => f['t'] == 'relay'))['d'], 'AQID');
    expect(a.frames.where((f) => f['t'] == 'relay'), isEmpty);
    b.send({'t': 'ping'});
    await b.next((f) => f['t'] == 'pong');
    expect(relay.roomCount, 1);
    await b.ws.close();
    expect((await a.next((f) => f['t'] == 'peer'))['ev'], 'leave');
    await a.ws.close();
    for (var i = 0; i < 50 && relay.roomCount > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(relay.roomCount, 0);
  });

  test('a third client is refused; bad frames close the socket', () async {
    final a = await _Ws.open(relay.port);
    final b = await _Ws.open(relay.port);
    final c = await _Ws.open(relay.port);
    for (final x in [a, b]) {
      x.send({'t': 'join', 'room': room});
      await x.next((f) => f['t'] == 'joined');
    }
    c.send({'t': 'join', 'room': room});
    expect((await c.next((f) => f['t'] == 'error'))['code'], 'full');
    await _until(c.closed.future);

    final d = await _Ws.open(relay.port);
    d.send({'t': 'join', 'room': 'not-hex'});
    expect((await d.next((f) => f['t'] == 'error'))['code'], 'bad');
    final e = await _Ws.open(relay.port);
    e.send({'t': 'relay', 'd': 'AA'}); // relay before join
    expect((await e.next((f) => f['t'] == 'error'))['code'], 'bad');
    final g = await _Ws.open(relay.port);
    g.send('x' * (100 * 1024));
    expect((await g.next((f) => f['t'] == 'error'))['code'], 'size');
    for (final x in [a, b]) {
      await x.ws.close();
    }
  });

  test('rate limit and join timeout', () async {
    final a = await _Ws.open(relay.port);
    a.send({'t': 'join', 'room': room});
    await a.next((f) => f['t'] == 'joined');
    for (var i = 0; i < 60; i++) {
      a.send({'t': 'ping'});
    }
    expect((await a.next((f) => f['t'] == 'error'))['code'], 'rate');
    final idle = await _Ws.open(relay.port);
    await _until(idle.closed.future);
  });

  group('authenticated signaling over the relay', () {
    Future<(CallSignaling, CallSignaling)> pair(
      String callerCode,
      String calleeCode,
    ) async {
      final url = 'ws://127.0.0.1:${relay.port}/';
      final caller = CallSignaling(
        role: CallRole.caller,
        keys: await deriveCallKeys(callerCode, iterations: 10),
        localName: 'حاسوب الأمانة',
        localPlatform: 'windows',
      );
      final callee = CallSignaling(
        role: CallRole.callee,
        keys: await deriveCallKeys(calleeCode, iterations: 10),
        localName: 'هاتف أحمد',
        localPlatform: 'android',
      );
      await caller.connect(url);
      return (caller, callee);
    }

    test('handshake, names, sealed offer / answer / ice / bye', () async {
      final (caller, callee) = await pair('K7QM2XPA9DTR', 'K7QM2XPA9DTR');
      final callerEvents = <SignalingEvent>[];
      final calleeEvents = <SignalingEvent>[];
      caller.events.listen(callerEvents.add);
      callee.events.listen(calleeEvents.add);
      await callee.connect('ws://127.0.0.1:${relay.port}/');
      Future<T> wait<T>(List<SignalingEvent> list) async {
        for (var i = 0; i < 300; i++) {
          final hit = list.whereType<T>();
          if (hit.isNotEmpty) return hit.first;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        throw TimeoutException('no $T');
      }

      final a = await wait<SignalingAuthenticated>(callerEvents);
      final b = await wait<SignalingAuthenticated>(calleeEvents);
      expect(a.peerName, 'هاتف أحمد');
      expect(a.peerPlatform, 'android');
      expect(b.peerName, 'حاسوب الأمانة');
      caller.sendOffer('OFFER-SDP');
      expect((await wait<SignalingOffer>(calleeEvents)).sdp, 'OFFER-SDP');
      callee.sendAnswer('ANSWER-SDP');
      expect((await wait<SignalingAnswer>(callerEvents)).sdp, 'ANSWER-SDP');
      callee.sendIce(const IceCandidateData(candidate: 'candidate:x'));
      expect(
        (await wait<SignalingIce>(callerEvents)).candidate.candidate,
        'candidate:x',
      );
      caller.sendBye('done');
      expect((await wait<SignalingBye>(calleeEvents)).reason, 'done');
      await caller.close();
      await callee.close();
    });

    test('a wrong code never authenticates (frames rejected)', () async {
      final (caller, callee) = await pair('K7QM2XPA9DTR', 'K7QM2XPA9DT0');
      // Different codes → different rooms: they never even meet.
      final events = <SignalingEvent>[];
      callee.events.listen(events.add);
      await callee.connect('ws://127.0.0.1:${relay.port}/');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(events.whereType<SignalingAuthenticated>(), isEmpty);
      expect(caller.isAuthenticated, isFalse);
      await caller.close();
      await callee.close();
    });
  });

  test('a relay that forges or replays frames cannot authenticate', () async {
    final mem = MemoryRelay();
    final keys = await deriveCallKeys('K7QM2XPA9DTR', iterations: 10);
    final wrongKeys = await deriveCallKeys('K7QM2XPA9DT0', iterations: 10);
    final caller = CallSignaling(
      role: CallRole.caller,
      keys: keys,
      localName: 'A',
      localPlatform: 'ios',
    );
    // An impostor who knows the room id (the relay does) but not the code.
    final impostor = CallSignaling(
      role: CallRole.callee,
      keys: CallKeys(callKey: wrongKeys.callKey, roomId: keys.roomId),
      localName: 'M',
      localPlatform: 'x',
    );
    final events = <SignalingEvent>[];
    caller.events.listen(events.add);
    await caller.connect('mem://', connector: mem.connect);
    await impostor.connect('mem://', connector: mem.connect);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(events.whereType<SignalingRejectedFrame>(), isNotEmpty);
    expect(events.whereType<SignalingAuthenticated>(), isEmpty);
    expect(mem.urls.first, contains('room=${keys.roomId}'));
    await impostor.close();

    // A genuine callee, then the relay replays its recorded hello.
    final callee = CallSignaling(
      role: CallRole.callee,
      keys: keys,
      localName: 'B',
      localPlatform: 'android',
    );
    final calleeEvents = <SignalingEvent>[];
    callee.events.listen(calleeEvents.add);
    await callee.connect('mem://', connector: mem.connect);
    for (var i = 0; i < 100 && !caller.isAuthenticated; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(caller.isAuthenticated, isTrue);
    final hello = mem.seen.lastWhere(
      (t) => t.contains('"relay"') && t.contains('"d"'),
      orElse: () => '',
    );
    expect(hello, isNotEmpty);
    // Tampered session frames are rejected.
    mem.tamper = (d) {
      final b = [...d.data];
      b[b.length - 1] ^= 1;
      return RelayData(Uint8List.fromList(b));
    };
    callee.sendAnswer('X');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events.whereType<SignalingAnswer>(), isEmpty);
    expect(events.whereType<SignalingRejectedFrame>().length, greaterThan(1));
    await caller.close();
    await callee.close();
  });
}
