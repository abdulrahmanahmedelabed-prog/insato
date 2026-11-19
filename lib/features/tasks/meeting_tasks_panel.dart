// Meeting-detail section of action-item tracking (F9): the tasks created by
// this meeting's minutes and the updates it proposed for earlier tasks.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/repositories_v11.dart';
import '../../ui/widgets/common.dart';
import 'strings.dart';
import 'task_logic.dart';
import 'task_providers.dart';
import 'tasks_screen.dart';
import 'task_widgets.dart';

/// Tasks of one meeting plus its proposed updates, for a meeting-detail tab
/// or section. Self-contained (watches its own providers); not scrollable
/// unless [scrollable] (use false inside an outer scroll view).
class MeetingTasksPanel extends ConsumerWidget {
  /// Creates the panel for [meetingId].
  const MeetingTasksPanel({
    super.key,
    required this.meetingId,
    this.scrollable = true,
  });

  /// The meeting.
  final String meetingId;

  /// Whether the panel is its own scroll view (a tab) or a plain column.
  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(meetingTasksProvider(meetingId));
    final pending = ref.watch(meetingPendingUpdateViewsProvider(meetingId));
    final theme = Theme.of(context);
    final children = <Widget>[
      SectionHeader(
        TS.meetingTasksHeader,
        icon: Icons.task_alt_rounded,
        trailing: TextButton(
          onPressed: () => openTasksScreen(context),
          child: const Text(TS.openTasksScreen),
        ),
      ),
      ...tasks.when(
        loading: () => const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        error: (e, _) => [
          ErrorBanner(
            message: TS.loadFailed,
            onRetry: () => ref.invalidate(meetingTasksProvider(meetingId)),
          ),
        ],
        data: (list) => list.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Text(
                    TS.meetingTasksEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ]
            : [
                for (final t in [...list]..sort(compareTasks))
                  TaskTile(
                    key: ValueKey('task-${t.id}'),
                    task: t,
                    showSource: false,
                    evidenceLinks: true,
                  ),
              ],
      ),
      if (pending.isNotEmpty)
        PendingUpdatesCard(
          views: pending,
          title: TS.meetingUpdatesHeader,
          showSourceMeeting: false,
          evidenceLinks: true,
        ),
    ];
    if (!scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }
    return ReadableWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: children,
      ),
    );
  }
}
