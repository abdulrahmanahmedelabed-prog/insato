// Real dart:io sockets on localhost: handshake, encryption, admission
// rules, audio, clock pings, removal and the end of the meeting.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/multi_device/guest_client.dart';
import 'package:insato/features/multi_device/host_server.dart';
import 'package:insato/features/multi_device/protocol.dart';
import 'package:insato/features/multi_device/secure_channel.dart';

import 'sim.dart';

const _code = 'K7QM2XPA9DTR';

Future<MultiDeviceHost> _host({int maxGuests = kMaxGuests}) =>
    MultiDeviceHost.start(
      hostName: 'host',
      bindAddress: InternetAddress.loopbackIPv4,
      code: _code,
      kdfIterations: 10,
      localAddresses: () async => ['127.0.0.1'],
      config: HostConfig(
        maxGuests: maxGuests,
        pingInterval: const Duration(milliseconds: 50),
      ),
    );

Future<MultiDeviceGuest> _join(
  MultiDeviceHost host,
  String id, {
  String code = _code,
}) async => MultiDeviceGuest.connect(
  hosts: host.joinInfo.addresses,
  port: host.port,
  pairingKey: await derivePairingKey(code, iterations: 10),
  guestId: id,
  name: 'جهاز $id',
  platform: 'android',
);

Future<T> _next<T extends HostEvent>(MultiDeviceHost h, {String? id}) => h
    .events
    .where((e) => e is T && (id == null || e.guestId == id))
    .cast<T>()
    .first
    .timeout(const Duration(seconds: 5));

Matcher _joinFailure(JoinFailure f) =>
    isA<JoinException>().having((e) => e.failure, 'failure', f);

void main() {
  test(
    'a guest joins, streams audio, answers pings and reports status',
    () async {
      final host = await _host();
      addTearDown(host.close);
      expect(JoinInfo.tryParse(host.joinInfo.toUri())!.port, host.port);
      final connected = _next<GuestConnected>(host);
      host.setState(HostState.recording, title: 'اجتماع اللجنة');
      final guest = await _join(host, 'g1');
      addTearDown(guest.close);
      expect(guest.welcome.sessionId, host.joinInfo.sessionId);
      expect(guest.welcome.state, HostState.recording);
      final c = await connected;
      expect(c.info.name, 'جهاز g1');
      expect(host.guests.single.id, 'g1');

      final states = guest.events
          .where((e) => e is HostStateChanged)
          .cast<HostStateChanged>()
          .first;
      expect((await states).title, 'اجتماع اللجنة');

      final clock = await _next<GuestClock>(host);
      expect(clock.sample.rttUs, greaterThanOrEqualTo(0));
      expect(clock.sample.t4, greaterThanOrEqualTo(clock.sample.t1));

      final audio = _next<GuestAudio>(host);
      final samples = syntheticSpeech(1600);
      guest.sendAudio(startIndex: 3200, captureUs: 123456, samples: samples);
      final a = await audio;
      expect(a.frame.seq, 0);
      expect(a.frame.startIndex, 3200);
      expect(a.frame.captureUs, 123456);
      expect(a.frame.samples[100], closeTo(samples[100], 1e-4));

      final status = _next<GuestStatusReport>(host);
      guest.sendStatus(
        const GuestStatus(battery: 80, charging: false, level: 0.3),
      );
      expect((await status).status.battery, 80);

      final gone = _next<GuestDisconnected>(host);
      await guest.close();
      expect((await gone).removed, isFalse);
      expect(host.guests, isEmpty);
    },
  );

  test('a wrong pairing code is refused without an answer', () async {
    final host = await _host();
    addTearDown(host.close);
    var events = 0;
    final sub = host.events.listen((_) => events++);
    addTearDown(sub.cancel);
    await expectLater(
      _join(host, 'g1', code: 'AAAAAAAAAAAA'),
      throwsA(_joinFailure(JoinFailure.rejectedOrWrongCode)),
    );
    expect(events, 0);
    expect(host.guests, isEmpty);
  });

  test('raw or plaintext traffic is closed (unknown peer)', () async {
    final host = await _host();
    addTearDown(host.close);
    final ws = await WebSocket.connect(
      'ws://127.0.0.1:${host.port}$kMultiDevicePath',
    );
    ws.add(utf8.encode('{"t":"hello"}'));
    await ws.drain<void>().timeout(const Duration(seconds: 5));
    expect(ws.closeCode, isNotNull);
    // Other paths are not served.
    final client = HttpClient();
    final req = await client.get('127.0.0.1', host.port, '/');
    final res = await req.close();
    expect(res.statusCode, HttpStatus.notFound);
    client.close(force: true);
  });

  test('a replayed hello is refused', () async {
    final host = await _host();
    addTearDown(host.close);
    final key = await derivePairingKey(_code, iterations: 10);
    final ch = SecureChannel(pairingKey: key, isHost: false);
    final hello = ch.sealHandshake(
      encodeJsonMessage(MsgType.hello, {
        'v': kMultiDeviceProtocolVersion,
        'id': 'g1',
        'name': '',
        'platform': '',
        'cn': base64Encode(secureRandomBytes(16)),
      }),
    );
    Future<bool> answered() async {
      final ws = await WebSocket.connect(
        'ws://127.0.0.1:${host.port}$kMultiDevicePath',
      );
      ws.add(hello);
      final first = await ws.first
          .timeout(const Duration(seconds: 3), onTimeout: () => null)
          .catchError((Object _) => null);
      await ws.close();
      return first != null;
    }

    expect(await answered(), isTrue, reason: 'first hello gets a welcome');
    expect(await answered(), isFalse, reason: 'replay gets nothing');
  });

  test(
    'at most four guests; a returning guest replaces its old link',
    () async {
      final host = await _host();
      addTearDown(host.close);
      final guests = <MultiDeviceGuest>[];
      for (var i = 1; i <= 4; i++) {
        final c = _next<GuestConnected>(host, id: 'g$i');
        guests.add(await _join(host, 'g$i'));
        await c;
      }
      addTearDown(() async {
        for (final g in guests) {
          await g.close();
        }
      });
      await expectLater(
        _join(host, 'g5'),
        throwsA(_joinFailure(JoinFailure.full)),
      );
      // g2 reconnects (e.g. after a Wi-Fi hiccup) while its old link lingers.
      final back = _next<GuestConnected>(host, id: 'g2');
      final again = await _join(host, 'g2');
      guests.add(again);
      await back;
      expect(host.guests.length, 4);
    },
  );

  test('a removed guest is told, and cannot come back', () async {
    final host = await _host();
    addTearDown(host.close);
    final c = _next<GuestConnected>(host);
    final guest = await _join(host, 'g1');
    await c;
    final kicked = guest.events
        .where((e) => e is GuestKicked)
        .cast<GuestKicked>()
        .first;
    final gone = _next<GuestDisconnected>(host);
    await host.remove('g1');
    expect((await gone).removed, isTrue);
    await kicked.timeout(const Duration(seconds: 5));
    await expectLater(
      _join(host, 'g1'),
      throwsA(_joinFailure(JoinFailure.removed)),
    );
  });

  test('closing the host ends the meeting for guests', () async {
    final host = await _host();
    final c = _next<GuestConnected>(host);
    final guest = await _join(host, 'g1');
    await c;
    final ended = guest.events
        .where((e) => e is HostStateChanged)
        .cast<HostStateChanged>()
        .firstWhere((e) => e.state == HostState.ended);
    await host.close();
    await ended.timeout(const Duration(seconds: 5));
    expect(guest.isOpen, isFalse);
  });

  test('an unreachable host fails fast', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    await expectLater(
      MultiDeviceGuest.connect(
        hosts: ['127.0.0.1'],
        port: port,
        pairingKey: await derivePairingKey(_code, iterations: 10),
        guestId: 'g',
      ),
      throwsA(_joinFailure(JoinFailure.unreachable)),
    );
  });

  test('GuestAudioFramer splits and timestamps frames', () {
    final f = GuestAudioFramer();
    final out = f.add(Float32List(4000), 1000000);
    expect([for (final x in out) x.$1], [0, 1600, 3200]);
    expect([for (final x in out) x.$3.length], [1600, 1600, 800]);
    expect(out[1].$2 - out[0].$2, 100000);
    expect(f.sampleCount, 4000);
    expect(f.add(Float32List(0), 0), isEmpty);
  });
}
