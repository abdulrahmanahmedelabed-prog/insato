// App shell: bottom NavigationBar on phones, NavigationRail with a
// two-pane meetings list / detail on wide screens (the same destinations
// and widgets on every platform: meetings, tasks, ask your meetings, voice
// library, settings), a "recording in progress" bar, and the Ctrl+N
// shortcut for a new meeting (with the optional meeting-context form).

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/time_format.dart';
import '../../features/ask/ask.dart' show AskMeetingsScreen;
import '../../features/meeting_package/meeting_package.dart'
    show IncomingPackageListener;
import '../../features/tasks/tasks.dart' show TasksScreen;
import '../../session/meeting_session_controller.dart';
import '../../session/providers.dart';
import '../actions.dart';
import '../navigation.dart';
import '../strings_ar.dart';
import '../widgets/common.dart';
import 'meeting_detail_screen.dart';
import 'meetings_screen.dart';
import 'settings_screen.dart';
import 'speakers_screen.dart';

/// Root page of the app.
class HomeShell extends ConsumerWidget {
  /// Creates the shell.
  const HomeShell({super.key});

  static const List<({IconData icon, IconData selectedIcon, String label})>
  _destinations = [
    (
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
      label: S.navMeetings,
    ),
    (
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt_rounded,
      label: S.navTasks,
    ),
    (
      icon: Icons.question_answer_outlined,
      selectedIcon: Icons.question_answer_rounded,
      label: S.navAsk,
    ),
    (
      icon: Icons.record_voice_over_outlined,
      selectedIcon: Icons.record_voice_over_rounded,
      label: S.navSpeakers,
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: S.navSettings,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    final wide = isWideLayout(context);
    final selected = ref.watch(selectedMeetingProvider);

    void select(int i) => ref.read(shellTabProvider.notifier).show(i);

    Widget meetingsPane() {
      if (!wide) {
        return MeetingsScreen(onOpen: (id) => openMeeting(context, ref, id));
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 400,
            child: MeetingsScreen(
              selectedId: selected,
              onOpen: (id) =>
                  ref.read(selectedMeetingProvider.notifier).select(id),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? const Scaffold(
                    body: EmptyState(
                      icon: Icons.description_outlined,
                      title: S.selectMeetingTitle,
                      body: S.selectMeetingBody,
                    ),
                  )
                : MeetingDetailScreen(
                    key: ValueKey(selected),
                    meetingId: selected,
                    embedded: true,
                  ),
          ),
        ],
      );
    }

    final body = switch (index) {
      ShellTab.tasks => const TasksScreen(),
      ShellTab.ask => const AskMeetingsScreen(embedded: true),
      ShellTab.speakers => const SpeakersScreen(),
      ShellTab.settings => const SettingsScreen(),
      _ => meetingsPane(),
    };

    final content = _RecordingBar(child: body);

    final scaffold = wide
        ? Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: select,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.9,
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    child: Tooltip(
                      message: S.newMeetingShortcut,
                      child: FloatingActionButton(
                        heroTag: 'rail-new-meeting',
                        elevation: 0,
                        onPressed: () => startNewMeeting(context, ref),
                        child: const Icon(Icons.mic_rounded),
                      ),
                    ),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          )
        : Scaffold(
            body: content,
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            startNewMeeting(context, ref),
      },
      // Meeting packages opened from other apps (Android / iOS).
      child: Focus(
        autofocus: true,
        child: IncomingPackageListener(child: scaffold),
      ),
    );
  }
}

/// Thin bar shown above [child] while a meeting is being recorded and the
/// recording screen is not on top. The bar consumes the top (status bar)
/// inset, so [child] (whose app bars would add it again) gets it removed.
class _RecordingBar extends ConsumerWidget {
  const _RecordingBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(meetingSessionControllerProvider);
    // Same tree shape whether or not the bar shows, so [child] keeps its
    // state (scroll position, search) when a recording starts or stops.
    return Column(
      children: [
        if (s.isCapturing) _bar(context, ref, s),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: s.isCapturing,
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _bar(BuildContext context, WidgetRef ref, SessionState s) {
    final scheme = Theme.of(context).colorScheme;
    // The live title: a rename during the recording updates the row, not
    // the session state.
    final id = s.meetingId;
    final liveTitle = id == null
        ? null
        : ref.watch(meetingProvider(id)).value?.title;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => openRecordingScreen(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record_rounded,
                    color: scheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      liveTitle ?? s.title ?? S.recordingInProgress,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                  LtrText(
                    formatDuration(s.elapsed.inMilliseconds),
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  const SizedBox(width: 8),
                  // Shrinks (ellipsis) on narrow phones instead of
                  // overflowing the bar.
                  Flexible(
                    child: Text(
                      S.backToRecording,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
