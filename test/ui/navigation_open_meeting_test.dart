// openMeeting keeps the current tab on phones (Back returns to it) and
// switches to Meetings on wide layouts, where the detail is a pane.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/ui/navigation.dart';
import 'package:insato/ui/screens/meeting_detail_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

class _Opener extends ConsumerWidget {
  const _Opener(this.meetingId);

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => openMeeting(context, ref, meetingId),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  Future<ProviderContainer> open(WidgetTester t, Size size) async {
    setScreenSize(t, size);
    final env = UiTestEnv();
    addTearDown(() => env.dispose(t));
    final seeded = await env.run(t, () => seedMeeting(env));
    await pumpScreen(t, env, _Opener(seeded.meeting.id));
    final container = ProviderScope.containerOf(
      t.element(find.byType(_Opener)),
    );
    container.read(shellTabProvider.notifier).show(ShellTab.tasks);
    await t.tap(find.text('open'));
    await settle(t);
    return container;
  }

  testWidgets('phones: Back returns to the tab the meeting was opened from', (
    t,
  ) async {
    final c = await open(t, kPhone);
    expect(c.read(shellTabProvider), ShellTab.tasks);
    Navigator.of(t.element(find.byType(MeetingDetailScreen))).pop();
    await settle(t);
    expect(find.text('open'), findsOneWidget);
    expect(c.read(shellTabProvider), ShellTab.tasks);
  });

  testWidgets('wide layouts show the meeting in the Meetings tab', (t) async {
    final c = await open(t, kDesktop);
    expect(c.read(shellTabProvider), ShellTab.meetings);
  });
}
