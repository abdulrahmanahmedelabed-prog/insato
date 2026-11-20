// Widget tests of the live call: entry button, start with the consent
// notice, waiting screen (code + QR), the in-call screen (indicator, safety
// code, live transcript, mute, stop, no leaving while streaming), the
// outcome, the join screen, the settings screen and the meeting log card.

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/live_call/call_code.dart';
import 'package:insato/features/live_call/call_engine.dart';
import 'package:insato/features/live_call/call_log.dart';
import 'package:insato/features/live_call/call_settings.dart';
import 'package:insato/features/live_call/live_call_providers.dart';
import 'package:insato/features/live_call/live_call_screens.dart';
import 'package:insato/features/live_call/live_call_settings_screen.dart';
import 'package:insato/features/live_call/peer_transport.dart';
import 'package:insato/features/live_call/strings.dart';
import 'package:insato/features/live_call/transcript_merge.dart';
import 'package:insato/features/live_call/widgets.dart';
import 'package:insato/data/repositories.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';

const _code = 'K7QM2XPA9DTR';

class FakeCallController extends LiveCallController {
  FakeCallController(this.initial);
  final LiveCallState initial;
  final List<String> calls = [];
  bool requireConsent = false;
  LiveCallState? afterStart;

  @override
  LiveCallState build() => initial;

  void push(LiveCallState s) => state = s;

  @override
  Future<void> startCall({bool consentGiven = false}) async {
    calls.add('start:$consentGiven');
    if (requireConsent && !consentGiven) {
      throw const CallConsentRequiredException();
    }
    if (afterStart != null) state = afterStart!;
  }

  @override
  Future<void> joinCall(CallInvite invite, {bool consentGiven = false}) async {
    calls.add('join:${invite.code}');
    if (afterStart != null) state = afterStart!;
  }

  @override
  Future<void> hangUp() async => calls.add('hangup');

  @override
  Future<void> setMuted(bool muted) async => calls.add('mute:$muted');

  @override
  Future<void> reset() async => calls.add('reset');
}

LiveCallState _waiting() => const LiveCallState(
  call: CallSnapshot(
    phase: CallPhase.waitingForPeer,
    role: CallRole.caller,
    invite: CallInvite(
      code: _code,
      signalingUrl: 'wss://relay.test',
      callerName: 'حاسوب',
    ),
  ),
);

LiveCallState _active({bool muted = false}) => LiveCallState(
  meetingId: 'm1',
  call: CallSnapshot(
    phase: CallPhase.active,
    role: CallRole.caller,
    peerName: 'هاتف أحمد',
    safetyCode: '123 456',
    connectedAt: DateTime.now(),
    muted: muted,
    remoteSpeaking: true,
    stats: const LinkStats(rttMs: 90, relayed: false),
    quality: CallQuality.good,
    lines: const [
      LiveLine(
        id: 'a',
        origin: LineOrigin.local,
        atUs: 1,
        durMs: 1000,
        text: 'صباح الخير',
        speakerName: 'سارة',
      ),
      LiveLine(
        id: 'b',
        origin: LineOrigin.remote,
        atUs: 2,
        durMs: 1000,
        text: 'أهلا بكم',
        speakerName: 'أحمد',
      ),
      LiveLine(
        id: 'c',
        origin: LineOrigin.remote,
        atUs: 3,
        durMs: 1000,
        pending: true,
      ),
    ],
  ),
);

void main() {
  testWidgets('meetings app bar opens the live call screen', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await pumpApp(t, env);
    // Phone width: the entry sits in the meetings-screen sources menu.
    await openSourcesMenu(t);
    expect(find.text(LCS.menuTooltip), findsOneWidget);
    await t.tap(find.text(LCS.menuTooltip));
    await settle(t);
    expect(find.byType(LiveCallHomeScreen), findsOneWidget);
    expect(find.text(LCS.startCall), findsOneWidget);
    expect(find.text(LCS.joinCall), findsOneWidget);
    // No relay configured yet.
    expect(find.text(LCS.notConfigured), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('start: consent notice first, then the code and QR', (t) async {
    setScreenSize(t, const Size(420, 1200));
    final env = UiTestEnv();
    final fake = FakeCallController(const LiveCallState())
      ..requireConsent = true
      ..afterStart = _waiting();
    env.extraOverrides.add(liveCallControllerProvider.overrideWith(() => fake));
    await pumpScreen(t, env, const LiveCallHomeScreen());
    await t.tap(find.text(LCS.startCall));
    await settle(t);
    expect(find.text(LCS.consentTitle), findsOneWidget);
    // Cancelling starts nothing.
    await t.tap(find.text(LCS.cancel));
    await settle(t);
    expect(fake.calls, ['reset', 'start:false']);
    expect(find.byType(LiveCallScreen), findsNothing);
    await t.tap(find.text(LCS.startCall));
    await settle(t);
    await t.tap(find.text(LCS.consentAccept));
    await settle(t);
    expect(fake.calls.last, 'start:true');
    expect(find.byType(LiveCallScreen), findsOneWidget);
    expect(find.text('K7QM-2XPA-9DTR'), findsOneWidget);
    expect(find.text(LCS.waiting), findsOneWidget);
    await t.tap(find.text(LCS.cancel));
    await settle(t);
    expect(fake.calls.last, 'hangup');
    await env.dispose(t);
  });

  testWidgets('in call: indicator, safety code, transcript, mute, stop', (
    t,
  ) async {
    setScreenSize(t, const Size(420, 1000));
    final env = UiTestEnv();
    final fake = FakeCallController(_active());
    env.extraOverrides.add(liveCallControllerProvider.overrideWith(() => fake));
    await pumpScreen(t, env, const LiveCallScreen());
    expect(find.text(LCS.liveIndicator), findsOneWidget);
    expect(find.text('${LCS.safetyCode}: 123 456'), findsOneWidget);
    expect(find.textContaining('جيدة'), findsOneWidget);
    expect(find.textContaining(LCS.speakingNow), findsOneWidget);
    expect(find.text('صباح الخير'), findsOneWidget);
    expect(find.text('أهلا بكم'), findsOneWidget);
    expect(find.text('سارة · ${LCS.thisDevice}'), findsOneWidget);
    expect(find.text('أحمد · هاتف أحمد'), findsOneWidget);
    expect(find.text(LCS.transcribing), findsOneWidget);

    await t.tap(find.byTooltip(LCS.mute));
    await t.pump();
    expect(fake.calls.last, 'mute:true');
    fake.push(_active(muted: true));
    await t.pump();
    expect(find.text(LCS.mutedChip), findsOneWidget);
    expect(find.byTooltip(LCS.unmute), findsOneWidget);

    // Back while streaming asks to end the call.
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await settle(t);
    expect(find.text(LCS.leaveTitle), findsOneWidget);
    await t.tap(find.text(LCS.cancel).last);
    await settle(t);
    expect(fake.calls, isNot(contains('hangup')));

    // One tap on stop (the button, or the indicator's).
    await t.tap(find.byKey(const ValueKey('stop-call')));
    await t.pump();
    expect(fake.calls.last, 'hangup');

    // Ended: saving, then the saved meeting.
    final ended = _active().call!.copyWith(
      phase: CallPhase.ended,
      endReason: CallEndReason.remoteHangUp,
    );
    fake.push(LiveCallState(call: ended, saving: true, meetingId: 'm1'));
    await t.pump();
    expect(find.text(LCS.saving), findsOneWidget);
    expect(find.text('أنهى هاتف أحمد المكالمة.'), findsOneWidget);
    fake.push(LiveCallState(call: ended, savedMeetingId: 'm1'));
    await t.pump();
    expect(find.text(LCS.openMeeting), findsOneWidget);
    expect(find.text(LCS.liveIndicator), findsNothing);
    await env.dispose(t);
  });

  testWidgets('failures explain what happened', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final fake = FakeCallController(
      const LiveCallState(
        call: CallSnapshot(
          phase: CallPhase.failed,
          role: CallRole.callee,
          endReason: CallEndReason.securityFailure,
        ),
      ),
    );
    env.extraOverrides.add(liveCallControllerProvider.overrideWith(() => fake));
    await pumpScreen(t, env, const LiveCallScreen());
    expect(
      find.text(LCS.endReason(CallEndReason.securityFailure, '')),
      findsOneWidget,
    );
    await env.dispose(t);
  });

  testWidgets('join: invalid code is refused, a valid one joins', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final fake = FakeCallController(const LiveCallState())
      ..afterStart = _waiting();
    env.extraOverrides.add(liveCallControllerProvider.overrideWith(() => fake));
    await pumpScreen(t, env, const LiveCallJoinScreen());
    // No camera scanner off Android / iOS.
    expect(find.text(LCS.scanQr), findsNothing);
    await t.enterText(find.byKey(const ValueKey('call-code')), 'abc');
    await t.tap(find.text(LCS.join));
    await settle(t);
    expect(find.text(LCS.invalidCode), findsOneWidget);
    expect(fake.calls, isEmpty);
    await t.enterText(
      find.byKey(const ValueKey('call-code')),
      'k7qm-2xpa-9dtr',
    );
    await t.tap(find.text(LCS.join));
    await settle(t);
    expect(fake.calls, ['reset', 'join:$_code']);
    expect(find.byType(LiveCallScreen), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('settings: URL validation, TURN credential in secure store', (
    t,
  ) async {
    setScreenSize(t, const Size(420, 1400));
    final env = UiTestEnv();
    final creds = MemoryTurnCredentialStore();
    env.extraOverrides.add(turnCredentialStoreProvider.overrideWithValue(creds));
    await pumpScreen(t, env, const LiveCallSettingsScreen());
    await t.enterText(find.byKey(const ValueKey('signaling-url')), 'ftp://x');
    await t.tap(find.text(LCS.save));
    await settle(t);
    expect(find.text(LCS.invalidUrl), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('signaling-url')),
      'relay.example.com',
    );
    await t.enterText(
      find.byKey(const ValueKey('turn-url')),
      'turn:t.example:3478',
    );
    await t.enterText(find.byKey(const ValueKey('turn-user')), 'u1');
    await t.enterText(find.byKey(const ValueKey('turn-credential')), 's3cret');
    await t.tap(find.text(LCS.relayOnly));
    await t.tap(find.text(LCS.save));
    await settle(t);
    final s = await env.run(t, () => LiveCallSettingsStore(env.db).load());
    expect(s.signalingUrl, 'wss://relay.example.com');
    expect(s.turnUrls, ['turn:t.example:3478']);
    expect(s.turnUsername, 'u1');
    expect(s.relayOnly, isTrue);
    expect(creds.value, 's3cret');
    // The secret never lands in the settings table.
    expect(s.toJson().toString(), isNot(contains('s3cret')));
    await env.dispose(t);
  });

  testWidgets('the meeting page shows the call log', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final start = DateTime(2026, 11, 20, 10);
    final id = await env.run(t, () async {
      final m = await MeetingRepository(env.db).create(title: 'مكالمة');
      await LiveCallLogStore(env.db).save(
        m.id,
        LiveCallLog(
          role: 'caller',
          localName: 'حاسوب الأمانة',
          remoteName: 'هاتف أحمد',
          startedAt: start,
          endedAt: start.add(const Duration(minutes: 5)),
          safetyCode: '123 456',
          relayed: false,
          events: [
            CallLogEvent(at: start, kind: 'start'),
            CallLogEvent(
              at: start.add(const Duration(minutes: 5)),
              kind: 'stop',
              byRemote: true,
            ),
          ],
        ),
      );
      return m.id;
    });
    await pumpScreen(t, env, Scaffold(body: LiveCallLogCard(meetingId: id)));
    expect(find.text(LCS.logTitle), findsOneWidget);
    expect(find.text(LCS.between('حاسوب الأمانة', 'هاتف أحمد')), findsOneWidget);
    expect(find.textContaining(LCS.event('start', byRemote: false)), findsOneWidget);
    expect(find.textContaining(LCS.event('stop', byRemote: true)), findsOneWidget);
    expect(find.text('${LCS.safetyCode}: 123 456'), findsOneWidget);
    await env.dispose(t);
  });
}
