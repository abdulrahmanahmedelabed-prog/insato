// Widget tests of phone-call mode: entry button, setup screen (modes,
// legal consent, guide, level check, start), recording and meeting cards.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart' show CapturePlatform;
import 'package:insato/core/errors.dart';
import 'package:insato/features/context/strings.dart';
import 'package:insato/features/phone_call/phone_call.dart';
import 'package:insato/features/voice/mic_capture.dart'
    show capturePlatformProvider;
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';

class _FakeProbe implements PhoneCallLevelProbe {
  _FakeProbe(this.mode);

  final PhoneCallMode mode;
  final local = StreamController<double>.broadcast();
  final remote = StreamController<double>.broadcast();
  Object? startError;
  int starts = 0;
  int stops = 0;

  @override
  Stream<double> get localLevel => local.stream;

  @override
  Stream<double> get remoteLevel => remote.stream;

  @override
  Future<void> start() async {
    starts++;
    final e = startError;
    if (e != null) throw e;
  }

  @override
  Future<void> stop() async => stops++;
}

class _Probes {
  final created = <_FakeProbe>[];
  Object? nextError;

  PhoneCallLevelProbe call(PhoneCallMode mode) {
    final p = _FakeProbe(mode)..startError = nextError;
    created.add(p);
    return p;
  }

  _FakeProbe get last => created.last;
}

UiTestEnv _env(_Probes probes, {bool windows = true}) {
  final env = UiTestEnv();
  env.extraOverrides.addAll([
    phoneCallProbeFactoryProvider.overrideWithValue(probes.call),
    capturePlatformProvider.overrideWithValue(
      windows ? CapturePlatform.windows : CapturePlatform.android,
    ),
  ]);
  return env;
}

/// Lets subscription cancels and probe calls complete.
Future<void> _realAsync(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await t.pump();
  await t.pump();
}

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pump();
}

void main() {
  group('PhoneCallCheckTracker', () {
    test('needs three readings per side; speakerphone has one side', () {
      final t = PhoneCallCheckTracker(PhoneCallMode.phoneLink);
      for (var i = 0; i < 3; i++) {
        t.addLocal(0.3);
      }
      expect(t.localOk, isTrue);
      expect(t.ready, isFalse);
      t
        ..addRemote(0.05)
        ..addRemote(0.2)
        ..addRemote(0.2);
      expect(t.remoteOk, isFalse);
      t.addRemote(0.5);
      expect(t.ready, isTrue);
      t.reset();
      expect(t.ready, isFalse);

      final s = PhoneCallCheckTracker(PhoneCallMode.speakerphone);
      expect(s.remoteOk, isTrue);
      for (var i = 0; i < 3; i++) {
        s.addLocal(0.2);
      }
      expect(s.ready, isTrue);
    });
  });

  testWidgets('guide: Android and iPhone steps for Phone Link', (t) async {
    setScreenSize(t, const Size(420, 2000));
    final env = UiTestEnv();
    await pumpScreen(
      t,
      env,
      const Scaffold(
        body: SingleChildScrollView(
          child: PhoneCallGuide(mode: PhoneCallMode.phoneLink),
        ),
      ),
    );
    expect(find.text(PCS.guideTitle), findsOneWidget);
    expect(find.text(PCS.androidSteps.first), findsOneWidget);
    expect(find.text(PCS.iphoneSteps[2]), findsNothing);
    for (final tip in PCS.phoneLinkTips) {
      expect(find.text(tip), findsOneWidget);
    }
    await t.tap(find.text(PCS.iphone));
    await t.pump();
    expect(find.text(PCS.iphoneSteps[2]), findsOneWidget);
    expect(find.text(PCS.androidSteps.first), findsNothing);
    expect(find.text('5'), findsOneWidget); // numbered steps
    await env.dispose(t);
  });

  testWidgets('guide: speakerphone steps without platform switch', (t) async {
    setScreenSize(t, const Size(420, 2000));
    final env = UiTestEnv();
    await pumpScreen(
      t,
      env,
      const Scaffold(
        body: SingleChildScrollView(
          child: PhoneCallGuide(mode: PhoneCallMode.speakerphone),
        ),
      ),
    );
    expect(find.text(PCS.speakerGuideTitle), findsOneWidget);
    for (final s in PCS.speakerSteps) {
      expect(find.text(s), findsOneWidget);
    }
    expect(find.text(PCS.iphone), findsNothing);
    await env.dispose(t);
  });

  testWidgets('check panel: both levels move, then ready; errors shown', (
    t,
  ) async {
    setScreenSize(t, const Size(420, 1400));
    final probes = _Probes();
    final env = _env(probes);
    final controller = PhoneCallCheckController(
      probes.call,
      PhoneCallMode.phoneLink,
    );
    await pumpScreen(
      t,
      env,
      Scaffold(body: PhoneCallCheckPanel(controller: controller)),
    );
    expect(find.text(PCS.levelLocal), findsOneWidget);
    expect(find.text(PCS.levelRemote), findsOneWidget);
    expect(find.text(PCS.levelWaiting), findsNWidgets(2));
    await t.tap(find.text(PCS.checkStart));
    await t.pump();
    expect(find.text(PCS.checkStop), findsOneWidget);
    final p = probes.last;
    for (var i = 0; i < 3; i++) {
      p.local.add(0.4);
    }
    await t.pump();
    await t.pump();
    expect(find.text(PCS.levelOk), findsOneWidget);
    expect(find.text(PCS.checkReady), findsNothing);
    for (var i = 0; i < 3; i++) {
      p.remote.add(0.6);
    }
    await t.pump();
    await t.pump();
    expect(find.text(PCS.levelOk), findsNWidgets(2));
    expect(find.text(PCS.checkReady), findsOneWidget);
    final bars = t
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((b) => b.value)
        .toList();
    expect(bars, [0.4, 0.6]);
    await t.tap(find.text(PCS.checkStop));
    await _realAsync(t);
    expect(p.stops, 1);
    expect(find.text(PCS.checkStart), findsOneWidget);

    probes.nextError = const AudioCaptureException('لا يوجد ميكروفون');
    await t.tap(find.text(PCS.checkStart));
    await _realAsync(t);
    expect(find.text(PCS.checkFailed('لا يوجد ميكروفون')), findsOneWidget);
    expect(probes.last.stops, 1);
    controller.dispose();
    await env.dispose(t);
  });

  testWidgets('setup: consent and check gate the start; the call is armed '
      'and the new-meeting flow opens', (t) async {
    setScreenSize(t, const Size(420, 900));
    final probes = _Probes();
    final env = _env(probes);
    await pumpApp(t, env);
    await t.tap(find.byTooltip(PCS.menuTooltip));
    await settle(t);
    expect(find.byType(PhoneCallSetupScreen), findsOneWidget);
    expect(find.text(PCS.modePhoneLinkHint), findsOneWidget);
    expect(find.text(PCS.legalBody), findsOneWidget);

    final start = find.byKey(const ValueKey('phone-call-start'));
    final anyway = find.byKey(const ValueKey('phone-call-start-anyway'));
    await _scrollTo(t, anyway);
    expect(t.widget<FilledButton>(start).onPressed, isNull);
    expect(t.widget<TextButton>(anyway).onPressed, isNull);

    await _scrollTo(t, find.byKey(const ValueKey('phone-call-consent')));
    await t.tap(find.byKey(const ValueKey('phone-call-consent')));
    await t.pump();
    await _scrollTo(t, anyway);
    expect(t.widget<FilledButton>(start).onPressed, isNull);
    expect(t.widget<TextButton>(anyway).onPressed, isNotNull);

    await _scrollTo(t, find.text(PCS.checkStart));
    await t.tap(find.text(PCS.checkStart));
    await t.pump();
    for (var i = 0; i < 3; i++) {
      probes.last.local.add(0.3);
      probes.last.remote.add(0.3);
    }
    await t.pump();
    await t.pump();
    await _scrollTo(t, start);
    expect(t.widget<FilledButton>(start).onPressed, isNotNull);
    expect(anyway, findsNothing);

    final container = ProviderScope.containerOf(
      t.element(find.byType(PhoneCallSetupScreen)),
    );
    await t.tap(start);
    await settle(t);
    // The check released the microphone before leaving.
    expect(probes.last.stops, 1);
    final armed = container.read(phoneCallSetupProvider);
    expect(armed?.mode, PhoneCallMode.phoneLink);
    expect(armed?.languageChoice, isNull);
    expect(container.read(phoneCallSessionPlanProvider), isNotNull);
    // The usual new-meeting flow continues (consent, then context form).
    expect(find.byType(PhoneCallSetupScreen), findsNothing);
    expect(
      find.text(CS.skipAndStart).evaluate().isNotEmpty ||
          find.byType(AlertDialog).evaluate().isNotEmpty,
      isTrue,
    );
    await env.dispose(t);
  });

  testWidgets('setup off Windows: Phone Link disabled, speakerphone chosen', (
    t,
  ) async {
    setScreenSize(t, const Size(420, 900));
    final probes = _Probes();
    final env = _env(probes, windows: false);
    await pumpScreen(t, env, const PhoneCallSetupScreen());
    expect(find.text(PCS.modePhoneLinkWindowsOnly), findsOneWidget);
    final tiles = t.widgetList<ListTile>(
      find.ancestor(
        of: find.text(PCS.modePhoneLink),
        matching: find.byType(ListTile),
      ),
    );
    expect(tiles.single.enabled, isFalse);
    await _scrollTo(t, find.text(PCS.speakerGuideTitle));
    expect(find.text(PCS.speakerGuideTitle), findsOneWidget);
    await _scrollTo(t, find.text(PCS.checkStart));
    expect(find.text(PCS.levelRoom), findsOneWidget);
    expect(find.text(PCS.levelRemote), findsNothing);
    await env.dispose(t);
  });

  testWidgets('recording card: armed call can be cancelled', (t) async {
    setScreenSize(t, const Size(420, 900));
    final env = _env(_Probes());
    await pumpScreen(t, env, const Scaffold(body: PhoneCallRecordingCard()));
    expect(find.text(PCS.armed), findsNothing);
    final container = ProviderScope.containerOf(
      t.element(find.byType(PhoneCallRecordingCard)),
    );
    container
        .read(phoneCallSetupProvider.notifier)
        .arm(const PhoneCallSetup(mode: PhoneCallMode.speakerphone));
    await t.pump();
    expect(find.text(PCS.recordingTitle(false)), findsOneWidget);
    expect(find.text(PCS.armed), findsOneWidget);
    await t.tap(find.text(PCS.disarm));
    await t.pump();
    expect(container.read(phoneCallSetupProvider), isNull);
    expect(find.text(PCS.armed), findsNothing);
    await env.dispose(t);
  });

  testWidgets('meeting card shows the call mode of a meeting', (t) async {
    setScreenSize(t, const Size(420, 900));
    final env = UiTestEnv();
    await env.run(
      t,
      () => PhoneCallLogStore(env.db).save(
        'm1',
        const PhoneCallLog(
          mode: PhoneCallMode.phoneLink,
          sides: {
            'a': CallSide.remote,
            'b': CallSide.remote,
            'c': CallSide.local,
          },
          bleedSuppressed: 2,
        ),
      ),
    );
    await pumpScreen(
      t,
      env,
      const Scaffold(
        body: Column(
          children: [
            PhoneCallMeetingCard(meetingId: 'm1'),
            PhoneCallMeetingCard(meetingId: 'other'),
          ],
        ),
      ),
    );
    expect(find.text(PCS.meetingCardTitle), findsOneWidget);
    expect(find.text(PCS.modeLine(true)), findsOneWidget);
    expect(find.text(PCS.counters(1, 2)), findsOneWidget);
    expect(find.text(PCS.bleed(2)), findsOneWidget);
    await env.dispose(t);
  });
}
