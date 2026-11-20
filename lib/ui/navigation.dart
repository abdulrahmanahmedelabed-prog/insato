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

/// Indices of the shell's top-level destinations.
abstract final class ShellTab {
  /// Meetings (list, and detail pane on wide layouts).
  static const int meetings = 0;

  /// Tracked tasks (F9).
  static const int tasks = 1;

  /// Ask your meetings (F8).
  static const int ask = 2;

  /// Voice library.
  static const int speakers = 3;

  /// Settings.
  static const int settings = 4;
}

/// Requests from deep inside the UI to switch the shell's top-level tab
/// (see [ShellTab]).
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
    MediaQuery.sizeOf(context).width >= InsatoTheme.wideBreakpoint;

/// Opens the meeting [meetingId]: on wide layouts it is selected in the
/// detail pane of the Meetings tab (returning to the shell); on phones its
/// page is pushed over the current tab (Back returns there), or replaces the
/// current page when [replace] is set (the shell then shows Meetings).
///
/// [replaceRoute] names the page to replace (the caller's own route): any
/// dialog open above it is closed first, so the meeting page replaces that
/// page and not the dialog (which a plain pushReplacement would replace,
/// leaving the caller's page underneath).
Future<void> openMeeting(
  BuildContext context,
  WidgetRef ref,
  String meetingId, {
  bool replace = false,
  Route<dynamic>? replaceRoute,
}) async {
  ref.read(selectedMeetingProvider.notifier).select(meetingId);
  final nav = Navigator.of(context);
  if (isWideLayout(context)) {
    // The detail is a pane of the Meetings tab.
    ref.read(shellTabProvider.notifier).show(ShellTab.meetings);
    nav.popUntil((r) => r.isFirst);
    return;
  }
  // Phones: the meeting page is pushed over the current tab, so Back
  // returns to it with its state (an Ask draft, a task filter). After a
  // recording (a replace), the Meetings list is the natural page beneath.
  if (replace || replaceRoute != null) {
    ref.read(shellTabProvider.notifier).show(ShellTab.meetings);
  }
  final route = MaterialPageRoute<void>(
    builder: (_) => MeetingDetailScreen(meetingId: meetingId),
  );
  if (replaceRoute != null) {
    if (replaceRoute.isActive) {
      // Closed dialogs complete with null (read as "cancelled").
      nav.popUntil((r) => r == replaceRoute);
      await nav.pushReplacement(route);
    } else {
      await nav.push(route);
    }
  } else if (replace) {
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
  final route = MaterialPageRoute<void>(builder: (_) => const SettingsScreen());
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}
