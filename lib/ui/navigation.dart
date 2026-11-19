// Navigation helpers shared by the screens: opening a meeting (two-pane on
// wide layouts, a pushed page on phones), the recording screen, the models
// screen and the settings page.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/meeting_detail_screen.dart';
import 'screens/models_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

/// Holds the meeting selected in the wide two-pane layout.
class SelectedMeetingNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Selects [meetingId] (null clears the selection).
  void select(String? meetingId) => state = meetingId;
}

/// Meeting shown in the detail pane of the wide layout.
final selectedMeetingProvider =
    NotifierProvider<SelectedMeetingNotifier, String?>(
      SelectedMeetingNotifier.new,
    );

/// Requests from deep inside the UI to switch the shell's top-level tab
/// (0 meetings, 1 speakers, 2 settings).
class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Switches to [index].
  void show(int index) => state = index;
}

/// The shell's current top-level tab.
final shellTabProvider = NotifierProvider<ShellTabNotifier, int>(
  ShellTabNotifier.new,
);

/// True when [context] is laid out with the wide (rail + two panes) layout.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= KatibTheme.wideBreakpoint;

/// Opens the meeting [meetingId]: on wide layouts it is selected in the
/// detail pane (returning to the shell); on phones its page is pushed, or
/// replaces the current page when [replace] is set.
Future<void> openMeeting(
  BuildContext context,
  WidgetRef ref,
  String meetingId, {
  bool replace = false,
}) async {
  ref.read(selectedMeetingProvider.notifier).select(meetingId);
  ref.read(shellTabProvider.notifier).show(0);
  final nav = Navigator.of(context);
  if (isWideLayout(context)) {
    nav.popUntil((r) => r.isFirst);
    return;
  }
  final route = MaterialPageRoute<void>(
    builder: (_) => MeetingDetailScreen(meetingId: meetingId),
  );
  if (replace) {
    await nav.pushReplacement(route);
  } else {
    await nav.push(route);
  }
}

/// Pushes the recording screen.
Future<void> openRecordingScreen(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RecordingScreen(),
        fullscreenDialog: true,
      ),
    );

/// Pushes the models screen ([replace] replaces the current page).
Future<void> openModelsScreen(BuildContext context, {bool replace = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => const ModelsScreen());
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}

/// Opens the settings page (pushed above the current page).
Future<void> openSettingsScreen(BuildContext context, {bool replace = false}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => const SettingsScreen(),
  );
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}
