// The host lobby around a real meeting: while it is open the session
// records through the multi-device source; once the meeting ends the
// guests are released and the lobby closes.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/multi_device/guest_client.dart';
import 'package:insato/features/multi_device/host_server.dart';
import 'package:insato/features/multi_device/meeting_log.dart';
import 'package:insato/features/multi_device/multi_device_providers.dart';
import 'package:insato/features/multi_device/multi_device_source.dart';
import 'package:insato/features/multi_device/protocol.dart';
import 'package:insato/features/multi_device/secure_channel.dart';
import 'package:insato/features/system_audio/mixed_session_audio_source.dart'
    show mixedSessionAudioSourceProvider;
import 'package:insato/session/providers.dart';

import '../../session/fakes.dart';

void main() {
  test('a meeting records guests and closes the lobby when it ends', () async {
    final db = memoryDb();
    final tmp = await Directory.systemTemp.createTemp('insato_md_host_');
    final local = FakeAudioSource();
    final engines = FakeEnginesFactory();
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
        appPathsProvider.overrideWithValue(
          AppPaths(documentsDir: () async => tmp, supportDir: () async => tmp),
        ),
        mixedSessionAudioSourceProvider.overrideWithValue(local),
        sessionPlatformHooksProvider.overrideWithValue(FakeHooks()),
        sessionEnginesFactoryProvider.overrideWithValue(engines),
        minutesEngineFactoryProvider.overrideWithValue(() async => null),
        multiDeviceHostStarterProvider.overrideWithValue(
          () => MultiDeviceHost.start(
            bindAddress: InternetAddress.loopbackIPv4,
            code: 'K7QM2XPA9DTR',
            kdfIterations: 10,
            localAddresses: () async => ['127.0.0.1'],
          ),
        ),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
      await tmp.delete(recursive: true);
    });
    // Keep the lobby alive like the lobby screen does.
    c.listen(multiDeviceHostControllerProvider, (_, _) {});
    expect(c.read(sessionAudioSourceProvider), same(local));

    await c.read(multiDeviceHostControllerProvider.notifier).open();
    final hub = c.read(multiDeviceHubProvider)!;
    expect(
      c.read(sessionAudioSourceProvider),
      isA<MultiDeviceSessionAudioSource>(),
    );

    final guest = await MultiDeviceGuest.connect(
      hosts: ['127.0.0.1'],
      port: hub.host.port,
      pairingKey: await derivePairingKey('K7QM2XPA9DTR', iterations: 10),
      guestId: 'g1',
      name: 'هاتف',
    );
    final states = <String>[];
    final titles = <String>[];
    guest.events.listen((e) {
      if (e is HostStateChanged) {
        states.add(e.state);
        titles.add(e.title);
      }
    });
    await waitUntil(() => hub.connectedIds.isNotEmpty);

    await AppSettings(db).setConsentAcknowledged(true);
    final session = c.read(meetingSessionControllerProvider.notifier);
    final id = await session.start(title: 'اجتماع اللجنة');
    await waitUntil(() => states.contains(HostState.recording));
    await waitUntil(() => titles.contains('اجتماع اللجنة'));
    // The lobby cannot close mid-meeting.
    expect(
      await c.read(multiDeviceHostControllerProvider.notifier).close(),
      isFalse,
    );

    for (final v in [0, 1]) {
      local.emit(voiceSamples(v, 2000));
    }
    await session.stop();
    await waitUntil(() => states.contains(HostState.ended));
    await waitUntil(() => c.read(multiDeviceHubProvider) == null);
    expect(hub.isClosed, isTrue);
    expect(c.read(sessionAudioSourceProvider), same(local));
    // The take's device log was stored with the meeting.
    final log = await MultiDeviceLogStore(db).load(id);
    expect(log, isNotNull);
    expect(log!.devices.single.id, 'g1');
    expect(log.events.first.kind, 'joined');
    await waitUntil(() => !guest.isOpen);
  });

  test('a failing server start reports an Arabic error', () async {
    final db = memoryDb();
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureSettingsProvider.overrideWithValue(FakeSecureSettings()),
        multiDeviceHostStarterProvider.overrideWithValue(
          () async => throw const SocketException('no network'),
        ),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    c.listen(multiDeviceHostControllerProvider, (_, _) {});
    await c.read(multiDeviceHostControllerProvider.notifier).open();
    final s = c.read(multiDeviceHostControllerProvider);
    expect(s.isOpen, isFalse);
    expect(s.errorAr, isNotNull);
    expect(JoinInfo.tryParse('x'), isNull);
  });
}
