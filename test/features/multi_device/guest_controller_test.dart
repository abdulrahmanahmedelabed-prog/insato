// The guest controller over real sockets: a dropped link is retried and the
// host records the device as having left and come back; battery reading.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/multi_device/battery.dart';
import 'package:insato/features/multi_device/guest_client.dart'
    show JoinFailure;
import 'package:insato/features/multi_device/host_server.dart';
import 'package:insato/features/multi_device/hub.dart';
import 'package:insato/features/multi_device/multi_device_providers.dart';
import 'package:insato/features/multi_device/protocol.dart';
import 'package:insato/features/multi_device/secure_channel.dart';
import 'package:insato/features/multi_device/strings.dart';
import 'package:insato/session/providers.dart';

import '../../session/fakes.dart';

/// A TCP proxy whose links can be cut (a Wi-Fi drop).
class _Proxy {
  _Proxy._(this._server, this.target);
  final ServerSocket _server;
  final int target;
  final List<Socket> _links = [];

  static Future<_Proxy> start(int target) async {
    final p = _Proxy._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      target,
    );
    p._server.listen((client) async {
      final upstream = await Socket.connect(
        InternetAddress.loopbackIPv4,
        target,
      );
      p._links.addAll([client, upstream]);
      client.listen(upstream.add, onDone: upstream.destroy, onError: (_) {});
      upstream.listen(client.add, onDone: client.destroy, onError: (_) {});
    });
    return p;
  }

  int get port => _server.port;

  void cut() {
    for (final s in _links) {
      s.destroy();
    }
    _links.clear();
  }

  Future<void> close() async {
    cut();
    await _server.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a dropped guest reconnects; the host logs left / rejoined', () async {
    final db = memoryDb();
    final audio = FakeAudioSource();
    final hooks = FakeHooks();
    final host = await MultiDeviceHost.start(
      hostName: 'المضيف',
      bindAddress: InternetAddress.loopbackIPv4,
      code: 'K7QM2XPA9DTR',
      kdfIterations: 10,
      localAddresses: () async => ['127.0.0.1'],
      config: const HostConfig(pingInterval: Duration(milliseconds: 100)),
    );
    final hub = MultiDeviceHub(host);
    final events = <String>[];
    host.events.listen((e) {
      if (e is GuestConnected) events.add('connected');
      if (e is GuestDisconnected) events.add('left');
    });
    final proxy = await _Proxy.start(host.port);
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
        sessionPlatformHooksProvider.overrideWithValue(hooks),
        guestAudioSourceProvider.overrideWithValue(audio),
        pairingKeyDeriverProvider.overrideWithValue(
          (code) => derivePairingKey(code, iterations: 10),
        ),
        batteryReaderProvider.overrideWithValue(const BatteryReader()),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await proxy.close();
      await hub.close();
      await db.close();
    });
    host.setState(HostState.recording, title: 'اجتماع');
    final ok = await c
        .read(guestSessionControllerProvider.notifier)
        .join(
          JoinTarget(
            hosts: const ['127.0.0.1'],
            port: proxy.port,
            code: 'K7QM2XPA9DTR',
          ),
          name: 'هاتف',
        );
    expect(ok, isTrue);
    await waitUntil(
      () =>
          c.read(guestSessionControllerProvider).phase == GuestPhase.recording,
    );
    expect(audio.started, isTrue);
    await waitUntil(() => hub.connectedIds.isNotEmpty);

    proxy.cut();
    await waitUntil(
      () =>
          c.read(guestSessionControllerProvider).phase ==
          GuestPhase.reconnecting,
    );
    expect(audio.started, isTrue, reason: 'capture continues while away');
    await waitUntil(
      () =>
          c.read(guestSessionControllerProvider).phase == GuestPhase.recording,
      timeout: const Duration(seconds: 15),
    );
    await waitUntil(() => events.length >= 3);
    expect(events.take(3), ['connected', 'left', 'connected']);
    expect(hub.current.single.connected, isTrue);
    expect(hub.current.single.drops, 1);

    await c.read(guestSessionControllerProvider.notifier).leave();
    expect(audio.started, isFalse);
    expect(hooks.stopped, 1);
  });

  test(
    'joining an unreachable host fails with an Arabic explanation',
    () async {
      final db = memoryDb();
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
          sessionPlatformHooksProvider.overrideWithValue(FakeHooks()),
          guestAudioSourceProvider.overrideWithValue(FakeAudioSource()),
          pairingKeyDeriverProvider.overrideWithValue(
            (code) => derivePairingKey(code, iterations: 10),
          ),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final ok = await c
          .read(guestSessionControllerProvider.notifier)
          .join(const JoinTarget(hosts: ['127.0.0.1'], port: 1, code: 'X'));
      expect(ok, isFalse);
      final st = c.read(guestSessionControllerProvider);
      expect(st.phase, GuestPhase.failed);
      expect(st.messageAr, MS.joinFailure(JoinFailure.unreachable));
    },
  );

  group('BatteryReader', () {
    const channel = MethodChannel('insato/battery-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('reads level and charging', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {'level': 57, 'charging': true},
      );
      final r = await const BatteryReader(channel: channel).read();
      expect(r.level, 57);
      expect(r.charging, isTrue);
    });

    test('unknown values and missing plugin give nulls', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {'level': 300},
      );
      expect(
        (await const BatteryReader(channel: channel).read()).level,
        isNull,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'x'),
      );
      expect(
        (await const BatteryReader(channel: channel).read()).level,
        isNull,
      );
      messenger.setMockMethodCallHandler(channel, null);
      final r = await const BatteryReader(channel: channel).read();
      expect(r.level, isNull);
      expect(r.charging, isNull);
    });
  });

  test('strings', () {
    expect(MS.devicesCount(1, 2), contains('1 من 2'));
    expect(MS.battery(40, true), contains('يُشحن'));
    expect(Float32List(0), isEmpty);
  });
}
