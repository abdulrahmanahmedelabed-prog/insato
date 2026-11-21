// The meetings screen on the narrowest phones (320 px wide): nothing
// overflows and every meeting source — recording import, meeting package
// import, meeting bot, phone call, live call, multi-device host and guest —
// is reachable from the one sources menu. On a wide pane each source keeps
// its own app-bar button.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/import_audio/import_audio.dart';
import 'package:insato/features/live_call/live_call_screens.dart';
import 'package:insato/features/live_call/strings.dart';
import 'package:insato/features/meeting_bot/meeting_bot_screen.dart';
import 'package:insato/features/meeting_bot/strings.dart';
import 'package:insato/features/meeting_package/meeting_package.dart';
import 'package:insato/features/multi_device/guest_screens.dart';
import 'package:insato/features/multi_device/host_lobby_screen.dart';
import 'package:insato/features/multi_device/multi_device_providers.dart';
import 'package:insato/features/multi_device/strings.dart';
import 'package:insato/features/phone_call/phone_call_setup_screen.dart';
import 'package:insato/features/phone_call/strings.dart';
import 'package:insato/ui/screens/meetings_screen.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// The narrowest phone layout supported.
const Size kNarrowPhone = Size(320, 640);

/// Package picker that only counts the picks (the user cancels).
class _CountingFiles implements PackageFiles {
  int picks = 0;

  @override
  Future<PickedPackageFile?> pick() async {
    picks++;
    return null;
  }

  @override
  Future<PackageSaveResult> save({
    required Uint8List bytes,
    required String fileName,
    Rect? origin,
  }) async => const PackageSaveResult(done: true);
}

/// Host lobby that never opens sockets or mDNS.
class _IdleHost extends MultiDeviceHostController {
  @override
  Future<void> open() async {}
}

class _Sources {
  int audioPicks = 0;
  final _CountingFiles files = _CountingFiles();

  UiTestEnv env() {
    final env = UiTestEnv();
    env.extraOverrides.addAll([
      audioFilePickerProvider.overrideWithValue(() async {
        audioPicks++;
        return null;
      }),
      sharedAudioInboxProvider.overrideWithValue(null),
      packageFilesProvider.overrideWithValue(files),
      multiDeviceHostControllerProvider.overrideWith(_IdleHost.new),
    ]);
    return env;
  }
}

/// Menu entry keys, in menu order.
const List<String> _entryKeys = [
  'import',
  'meeting-package',
  'meeting-bot',
  'phone-call',
  'live-call',
  'multi-device-host',
  'multi-device-guest',
];

void main() {
  for (final seeded in [false, true]) {
    testWidgets('320 px (${seeded ? 'with meetings' : 'empty'}): no '
        'overflow, one sources menu holding every source', (t) async {
      setScreenSize(t, kNarrowPhone);
      final env = _Sources().env();
      if (seeded) await env.run(t, () => seedMeeting(env));
      await pumpApp(t, env);
      // A RenderFlex overflow would have been reported as an exception.
      expect(t.takeException(), isNull);

      // One menu instead of the separate buttons.
      expect(find.byTooltip(S.meetingSourcesMenu), findsOneWidget);
      expect(find.byType(ImportRecordingButton), findsNothing);
      expect(find.byType(MeetingPackageImportButton), findsNothing);
      expect(find.byType(MeetingBotButton), findsNothing);
      expect(find.byTooltip(LCS.menuTooltip), findsNothing);
      // The title stays readable next to it.
      expect(find.text(S.appName), findsOneWidget);
      final title = t.getRect(find.text(S.appName));
      final menu = t.getRect(find.byTooltip(S.meetingSourcesMenu));
      expect(title.overlaps(menu), isFalse);

      await openSourcesMenu(t);
      expect(t.takeException(), isNull);
      for (final key in _entryKeys) {
        final entry = find.byKey(ValueKey('source-$key'));
        expect(entry, findsOneWidget, reason: key);
        final r = t.getRect(entry);
        expect(
          r.left >= 0 &&
              r.top >= 0 &&
              r.right <= kNarrowPhone.width &&
              r.bottom <= kNarrowPhone.height,
          isTrue,
          reason: '$key is on screen ($r)',
        );
        expect(entry.hitTestable(), findsOneWidget, reason: key);
      }
      for (final label in [
        IS.importTooltip,
        PS.importTooltip,
        BotStrings.entryTooltip,
        PCS.menuTooltip,
        LCS.menuTooltip,
        MS.hostEntry,
        MS.guestEntry,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await env.dispose(t);
    });
  }

  // Each entry really starts its source.
  final Map<String, void Function(WidgetTester t, _Sources s)> opens = {
    'import': (t, s) => expect(s.audioPicks, 1),
    'meeting-package': (t, s) => expect(s.files.picks, 1),
    'meeting-bot': (t, s) =>
        expect(find.byType(MeetingBotScreen), findsOneWidget),
    'phone-call': (t, s) =>
        expect(find.byType(PhoneCallSetupScreen), findsOneWidget),
    'live-call': (t, s) =>
        expect(find.byType(LiveCallHomeScreen), findsOneWidget),
    'multi-device-host': (t, s) =>
        expect(find.byType(HostLobbyScreen), findsOneWidget),
    'multi-device-guest': (t, s) =>
        expect(find.byType(GuestJoinScreen), findsOneWidget),
  };
  assert(opens.keys.toList().join() == _entryKeys.join());
  for (final MapEntry(:key, value: check) in opens.entries) {
    testWidgets('320 px: the "$key" entry opens its source', (t) async {
      setScreenSize(t, kNarrowPhone);
      final sources = _Sources();
      final env = sources.env();
      await pumpApp(t, env);
      await openSourcesMenu(t);
      await t.tap(find.byKey(ValueKey('source-$key')));
      await settle(t);
      check(t, sources);
      await env.dispose(t);
    });
  }

  testWidgets('a wide pane keeps one button per source', (t) async {
    setScreenSize(t, const Size(900, 800));
    final env = _Sources().env();
    await pumpScreen(t, env, MeetingsScreen(onOpen: (_) {}));
    expect(t.takeException(), isNull);
    expect(find.byTooltip(S.meetingSourcesMenu), findsNothing);
    for (final tooltip in [
      IS.importTooltip,
      PS.importTooltip,
      BotStrings.entryTooltip,
      PCS.menuTooltip,
      LCS.menuTooltip,
      MS.menuTooltip,
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
    await env.dispose(t);
  });
}
