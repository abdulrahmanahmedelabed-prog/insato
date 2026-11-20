// Widget tests of v1.2 C: entry menu, host lobby (real server on
// localhost), guest join + recording screens (real sockets), recording
// card and the meeting-page log card.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/multi_device/fusion_engine.dart';
import 'package:insato/features/multi_device/guest_client.dart';
import 'package:insato/features/multi_device/guest_screens.dart';
import 'package:insato/features/multi_device/host_lobby_screen.dart';
import 'package:insato/features/multi_device/host_server.dart';
import 'package:insato/features/multi_device/hub.dart';
import 'package:insato/features/multi_device/meeting_log.dart';
import 'package:insato/features/multi_device/multi_device_providers.dart';
import 'package:insato/features/multi_device/protocol.dart';
import 'package:insato/features/multi_device/secure_channel.dart';
import 'package:insato/features/multi_device/strings.dart';
import 'package:insato/features/multi_device/widgets.dart';
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';

const _code = 'K7QM2XPA9DTR';

Future<MultiDeviceHost> _startHost() => MultiDeviceHost.start(
  hostName: 'حاسوب الأمانة',
  bindAddress: InternetAddress.loopbackIPv4,
  code: _code,
  kdfIterations: 10,
  localAddresses: () async => ['127.0.0.1'],
  config: const HostConfig(pingInterval: Duration(milliseconds: 50)),
);

Future<void> _pump(WidgetTester t, ProviderContainer c, Widget child) async {
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: InsatoTheme.light(),
        home: child,
      ),
    ),
  );
  await settle(t);
}

void main() {
  testWidgets('the meetings screen offers host and guest entries', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await pumpApp(t, env);
    // Phone width: the sources collapse into one menu with both entries.
    await openSourcesMenu(t);
    expect(find.text(MS.hostEntry), findsOneWidget);
    expect(find.text(MS.guestEntry), findsOneWidget);
    await t.tap(find.text(MS.guestEntry));
    await settle(t);
    expect(find.byType(GuestJoinScreen), findsOneWidget);
    // No camera scanner off Android / iOS; no mDNS in tests.
    expect(find.text(MS.scanUnavailable), findsOneWidget);
    expect(find.text(MS.noneFound), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('host lobby: QR, code, address, live guest, removal, stop', (
    t,
  ) async {
    setScreenSize(t, const Size(420, 1400));
    final env = UiTestEnv();
    final c = ProviderContainer(
      overrides: [
        ...env.overrides,
        multiDeviceHostStarterProvider.overrideWithValue(_startHost),
      ],
    );
    addTearDown(c.dispose);
    await t.runAsync(
      () => c.read(multiDeviceHostControllerProvider.notifier).open(),
    );
    final hub = c.read(multiDeviceHubProvider)!;
    await _pump(t, c, const HostLobbyScreen());
    expect(find.byType(QrCodeView), findsOneWidget);
    expect(find.text('K7QM-2XPA-9DTR'), findsOneWidget);
    expect(find.text('127.0.0.1:${hub.host.port}'), findsOneWidget);
    expect(find.text(MS.noDevices), findsOneWidget);
    expect(find.text(MS.startMeeting), findsOneWidget);

    final guest = (await t.runAsync(
      () async => MultiDeviceGuest.connect(
        hosts: ['127.0.0.1'],
        port: hub.host.port,
        pairingKey: await derivePairingKey(_code, iterations: 10),
        guestId: 'phone-1',
        name: 'هاتف سارة',
        platform: 'android',
      ),
    ))!;
    await settleUntil(t, () => find.text('هاتف سارة').evaluate().isNotEmpty);
    expect(find.text(MS.connected), findsOneWidget);
    expect(find.text(MS.platform('android')), findsOneWidget);
    expect(find.text(MS.batteryUnknown), findsOneWidget);

    await t.tap(find.byTooltip(MS.remove));
    await settle(t);
    expect(find.text(MS.removeTitle('هاتف سارة')), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, MS.remove));
    await settleUntil(t, () => find.text('هاتف سارة').evaluate().isEmpty);
    await settleUntil(t, () => !guest.isOpen);
    // WebSocket.close arms a 5 s fallback timer in the test's fake time.
    await t.pump(const Duration(seconds: 6));

    await t.tap(find.text(MS.stopHosting));
    await settleUntil(t, () => c.read(multiDeviceHubProvider) == null);
    await settleUntil(t, () => hub.isClosed);
    await t.pump(const Duration(seconds: 6));
    await env.dispose(t);
  });

  testWidgets('guest: validation, wrong code, join, record, leave', (t) async {
    setScreenSize(t, const Size(420, 1400));
    final env = UiTestEnv();
    final host = (await t.runAsync(_startHost))!;
    final hub = MultiDeviceHub(host);
    final audioFrames = <GuestAudio>[];
    final sub = host.events.listen((e) {
      if (e is GuestAudio) audioFrames.add(e);
    });
    final c = ProviderContainer(
      overrides: [
        ...env.overrides,
        guestAudioSourceProvider.overrideWithValue(env.audio),
        pairingKeyDeriverProvider.overrideWithValue(
          (code) => derivePairingKey(code, iterations: 10),
        ),
      ],
    );
    addTearDown(c.dispose);
    await _pump(t, c, const GuestJoinScreen());

    // Empty form.
    await t.ensureVisible(find.byKey(const Key('md-join')));
    await t.tap(find.byKey(const Key('md-join')));
    await settle(t);
    expect(find.text(MS.invalidCode), findsOneWidget);
    expect(find.text(MS.invalidAddress), findsOneWidget);

    // Wrong code.
    await t.enterText(find.byKey(const Key('md-join-code')), 'AAAA-AAAA-AAAA');
    await t.enterText(
      find.byKey(const Key('md-join-address')),
      '127.0.0.1:${host.port}',
    );
    await t.enterText(find.byKey(const Key('md-join-name')), 'هاتف خالد');
    await t.ensureVisible(find.byKey(const Key('md-join')));
    await t.tap(find.byKey(const Key('md-join')));
    await settleUntil(
      t,
      () => find
          .text(MS.joinFailure(JoinFailure.rejectedOrWrongCode))
          .evaluate()
          .isNotEmpty,
    );

    // Right code: joins and waits for the meeting.
    await t.enterText(find.byKey(const Key('md-join-code')), 'k7qm 2xpa 9dtr');
    await t.ensureVisible(find.byKey(const Key('md-join')));
    await t.tap(find.byKey(const Key('md-join')));
    await settleUntil(
      t,
      () => find.text(MS.waiting).evaluate().isNotEmpty,
      reason: 'joined',
    );
    expect(find.byType(GuestRecordingScreen), findsOneWidget);
    expect(find.text(MS.hostLabel('حاسوب الأمانة')), findsOneWidget);
    expect(hub.current.single.name, 'هاتف خالد');

    // The host starts recording: the guest captures and streams.
    host.setState(HostState.recording, title: 'اجتماع اللجنة');
    await settleUntil(t, () => find.text(MS.recording).evaluate().isNotEmpty);
    expect(find.text(MS.meetingLabel('اجتماع اللجنة')), findsOneWidget);
    expect(env.audio.started, isTrue);
    expect(env.hooks.started, 1);
    for (var i = 0; i < 3; i++) {
      env.audio.emit(Float32List(1600));
    }
    await settleUntil(t, () => audioFrames.length >= 3);
    expect(audioFrames.first.frame.startIndex, 0);
    expect(audioFrames[1].frame.startIndex, 1600);

    host.setState(HostState.paused);
    await settleUntil(t, () => find.text(MS.paused).evaluate().isNotEmpty);

    // Leaving releases the microphone and the host sees the device go.
    await t.tap(find.byKey(const Key('md-guest-leave')));
    await settleUntil(t, () => hub.connectedIds.isEmpty);
    await t.pump(const Duration(seconds: 6)); // WebSocket.close fallback
    expect(c.read(guestSessionControllerProvider).phase, GuestPhase.idle);
    expect(env.hooks.stopped, 1);
    await t.runAsync(() async {
      await sub.cancel();
      await hub.close();
    });
    await env.dispose(t);
  });

  testWidgets('guest: the host ending the meeting ends the guest', (t) async {
    setScreenSize(t, const Size(420, 1400));
    final env = UiTestEnv();
    final host = (await t.runAsync(_startHost))!;
    final c = ProviderContainer(
      overrides: [
        ...env.overrides,
        guestAudioSourceProvider.overrideWithValue(env.audio),
        pairingKeyDeriverProvider.overrideWithValue(
          (code) => derivePairingKey(code, iterations: 10),
        ),
      ],
    );
    addTearDown(c.dispose);
    host.setState(HostState.recording, title: 'اجتماع');
    await t.runAsync(
      () => c
          .read(guestSessionControllerProvider.notifier)
          .join(
            JoinTarget(
              hosts: const ['127.0.0.1'],
              port: host.port,
              code: _code,
            ),
          ),
    );
    await _pump(t, c, const GuestRecordingScreen());
    await settleUntil(t, () => find.text(MS.recording).evaluate().isNotEmpty);
    await t.runAsync(host.close);
    await settleUntil(t, () => find.text(MS.ended).evaluate().isNotEmpty);
    expect(env.audio.started, isFalse);
    await t.tap(find.byKey(const Key('md-guest-done')));
    await settle(t);
    expect(c.read(guestSessionControllerProvider).phase, GuestPhase.idle);
    await env.dispose(t);
  });

  testWidgets('recording card is hidden without a hub; log card shows gaps', (
    t,
  ) async {
    final env = UiTestEnv();
    await env.run(
      t,
      () => MultiDeviceLogStore(env.db).save(
        'm1',
        const MultiDeviceMeetingLog(
          devices: [
            LoggedDevice(
              id: 'g1',
              name: 'هاتف سارة',
              platform: 'ios',
              segmentsChosen: 12,
            ),
          ],
          events: [
            DeviceTimelineEvent(channelId: 'g1', kind: 'joined', atMs: 0),
            DeviceTimelineEvent(channelId: 'g1', kind: 'left', atMs: 65000),
            DeviceTimelineEvent(
              channelId: 'g1',
              kind: 'rejoined',
              atMs: 125000,
            ),
          ],
        ),
      ),
    );
    await pumpScreen(
      t,
      env,
      const Scaffold(
        body: Column(
          children: [
            MultiDeviceRecordingCard(),
            MultiDeviceLogCard(meetingId: 'm1'),
            MultiDeviceLogCard(meetingId: 'other'),
          ],
        ),
      ),
    );
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text(MS.logTitle), findsOneWidget);
    expect(find.textContaining('هاتف سارة'), findsWidgets);
    expect(find.textContaining(MS.chosen(12)), findsOneWidget);
    expect(
      find.text(MS.gap('هاتف سارة', '00:01:05', '00:02:05')),
      findsOneWidget,
    );
    await env.dispose(t);
  });
}
