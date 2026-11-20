// Widgets of action-item tracking (F9): one task row, and the card of
// updates proposed by minutes awaiting the user's confirmation.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../data/repositories.dart' show meetingsProvider;
import '../evidence/evidence_chips.dart' show EvidenceChips;
import '../../ui/navigation.dart';
import '../../ui/strings_ar.dart';
import 'strings.dart';
import 'task_edit_dialog.dart';
import 'task_flows.dart';
import 'task_logic.dart';
import 'task_providers.dart';

enum _TaskAction { edit, done, reopen, cancel, openMeeting, delete }

/// Colours of a status.
(Color, Color) taskStatusColors(ColorScheme scheme, TaskStatus s) =>
    switch (s) {
      TaskStatus.open => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      TaskStatus.done => (scheme.primaryContainer, scheme.onPrimaryContainer),
      TaskStatus.cancelled => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

/// Small coloured pill showing a task status.
class TaskStatusPill extends StatelessWidget {
  /// Creates a pill.
  const TaskStatusPill({super.key, required this.status});

  /// The status.
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = taskStatusColors(theme.colorScheme, status);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(taskStatusIcon(status), size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            TS.status(status),
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One task: a status toggle, the text with owner / due / source lines,
/// and a menu (edit, status, open meeting, delete). Tapping edits.
class TaskTile extends ConsumerWidget {
  /// Creates a tile.
  const TaskTile({
    super.key,
    required this.task,
    this.showSource = true,
    this.evidenceLinks = false,
    this.onOpenMeeting,
  });

  /// The task.
  final TrackedTask task;

  /// Whether to show the source meeting line (off inside that meeting).
  final bool showSource;

  /// Whether the cited transcript segments are shown as playable
  /// [EvidenceChips] (inside the source meeting's page, under its
  /// `EvidenceScope`) instead of a plain count.
  final bool evidenceLinks;

  /// Opens a meeting (default: [openMeeting]).
  final void Function(String meetingId)? onOpenMeeting;

  void _open(BuildContext context, WidgetRef ref, String meetingId) {
    final cb = onOpenMeeting;
    if (cb != null) {
      cb(meetingId);
    } else {
      openMeeting(context, ref, meetingId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speakers = ref.watch(taskSpeakersByIdProvider);
    final meetings = ref.watch(taskMeetingsByIdProvider);
    final meetingsLoaded = ref.watch(meetingsProvider).hasValue;
    final owner = taskOwnerLabel(task, speakers);
    final sourceId = task.sourceMeetingId;
    final meeting = sourceId == null ? null : meetings[sourceId];
    final closed = task.status != TaskStatus.open;
    final muted = theme.colorScheme.onSurfaceVariant;
    final lineStyle = theme.textTheme.bodySmall?.copyWith(color: muted);
    final chips =
        evidenceLinks && sourceId != null && task.evidenceSegmentIds.isNotEmpty;

    final lines = <Widget>[
      if (owner != null)
        _Line(icon: Icons.person_outline_rounded, text: TS.ownerLine(owner)),
      if (task.dueText != null)
        _Line(icon: Icons.event_outlined, text: TS.dueLine(task.dueText!)),
      if (showSource && meeting != null)
        _Line(icon: Icons.groups_outlined, text: TS.sourceLine(meeting.title)),
      if (showSource && sourceId != null && meeting == null && meetingsLoaded)
        const _Line(icon: Icons.groups_outlined, text: TS.sourceDeleted),
      if (task.evidenceSegmentIds.isNotEmpty && !chips)
        _Line(
          icon: Icons.graphic_eq_rounded,
          text: TS.evidenceCount(task.evidenceSegmentIds.length),
        ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => editTaskFlow(context, ref, task),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 0, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: closed
                    ? TS.reopenSemantics(task.task)
                    : TS.markDoneSemantics(task.task),
                isSelected: task.status == TaskStatus.done,
                icon: Icon(
                  taskStatusIcon(task.status),
                  color: task.status == TaskStatus.done
                      ? theme.colorScheme.primary
                      : muted,
                ),
                onPressed: () => setTaskStatusFlow(
                  context,
                  ref,
                  task,
                  closed ? TaskStatus.open : TaskStatus.done,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.task,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: closed
                              ? TextDecoration.lineThrough
                              : null,
                          color: closed ? muted : null,
                        ),
                      ),
                      if (closed) ...[
                        const SizedBox(height: 4),
                        TaskStatusPill(status: task.status),
                      ],
                      if (lines.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        DefaultTextStyle.merge(
                          style: lineStyle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: lines,
                          ),
                        ),
                      ],
                      if (chips)
                        EvidenceChips(
                          meetingId: sourceId,
                          evidence: task.evidenceSegmentIds,
                        ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<_TaskAction>(
                tooltip: TS.taskMenu,
                onSelected: (a) => switch (a) {
                  _TaskAction.edit => editTaskFlow(context, ref, task),
                  _TaskAction.done => setTaskStatusFlow(
                    context,
                    ref,
                    task,
                    TaskStatus.done,
                  ),
                  _TaskAction.reopen => setTaskStatusFlow(
                    context,
                    ref,
                    task,
                    TaskStatus.open,
                  ),
                  _TaskAction.cancel => setTaskStatusFlow(
                    context,
                    ref,
                    task,
                    TaskStatus.cancelled,
                  ),
                  _TaskAction.openMeeting => _open(context, ref, sourceId!),
                  _TaskAction.delete => deleteTaskFlow(context, ref, task),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _TaskAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text(TS.edit),
                    ),
                  ),
                  if (task.status != TaskStatus.done)
                    const PopupMenuItem(
                      value: _TaskAction.done,
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline_rounded),
                        title: Text(TS.markDone),
                      ),
                    ),
                  if (task.status != TaskStatus.open)
                    const PopupMenuItem(
                      value: _TaskAction.reopen,
                      child: ListTile(
                        leading: Icon(Icons.replay_rounded),
                        title: Text(TS.reopen),
                      ),
                    ),
                  if (task.status != TaskStatus.cancelled)
                    const PopupMenuItem(
                      value: _TaskAction.cancel,
                      child: ListTile(
                        leading: Icon(Icons.cancel_outlined),
                        title: Text(TS.cancelTask),
                      ),
                    ),
                  if (showSource && meeting != null)
                    const PopupMenuItem(
                      value: _TaskAction.openMeeting,
                      child: ListTile(
                        leading: Icon(Icons.open_in_new_rounded),
                        title: Text(TS.openMeeting),
                      ),
                    ),
                  const PopupMenuItem(
                    value: _TaskAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text(S.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Card listing updates proposed by minutes, each with apply / reject (or
/// acknowledge), and «apply all» when several change a status.
class PendingUpdatesCard extends ConsumerWidget {
  /// Creates the card for [views].
  const PendingUpdatesCard({
    super.key,
    required this.views,
    this.title = TS.pendingHeader,
    this.showSourceMeeting = true,
    this.showExplanation = true,
    this.evidenceLinks = false,
  });

  /// Updates to show (oldest first).
  final List<PendingUpdateView> views;

  /// Whether evidence is shown as playable [EvidenceChips] (inside the
  /// page of the meeting that proposed the updates).
  final bool evidenceLinks;

  /// Card title.
  final String title;

  /// Whether each row names the meeting that proposed it.
  final bool showSourceMeeting;

  /// Whether to show the explanation under the title.
  final bool showExplanation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (views.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final applicable = applicableUpdates(views);
    return Card(
      color: scheme.tertiaryContainer.withValues(alpha: 0.45),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(Icons.update_rounded, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$title (${views.length})',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            if (showExplanation) ...[
              const SizedBox(height: 4),
              Text(
                TS.pendingBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            for (final v in views)
              PendingUpdateTile(
                key: ValueKey('pending-${v.update.id}'),
                view: v,
                showSourceMeeting: showSourceMeeting,
                evidenceLinks: evidenceLinks,
              ),
            if (applicable.length > 1)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () =>
                      applyAllPendingFlow(context, ref, applicable),
                  icon: const Icon(Icons.done_all_rounded),
                  label: Text(TS.applyAll(applicable.length)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One proposed update: task, proposal, note, source and the actions.
class PendingUpdateTile extends ConsumerWidget {
  /// Creates a row.
  const PendingUpdateTile({
    super.key,
    required this.view,
    this.showSourceMeeting = true,
    this.evidenceLinks = false,
  });

  /// The update.
  final PendingUpdateView view;

  /// Whether to name the meeting that proposed it.
  final bool showSourceMeeting;

  /// Whether evidence is shown as playable [EvidenceChips] (the segments
  /// belong to the meeting that proposed the update).
  final bool evidenceLinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final u = view.update;
    final proposal = switch (view.kind) {
      PendingUpdateKind.apply => TS.proposedStatus(u.newStatus),
      PendingUpdateKind.acknowledge => TS.progressOnly,
      PendingUpdateKind.alreadyApplied => TS.alreadyApplied,
      PendingUpdateKind.taskGone => TS.taskGone,
    };
    final note = u.note;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            view.task?.task ?? TS.taskGone,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (view.kind == PendingUpdateKind.apply) ...[
                TaskStatusPill(status: u.newStatus),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(proposal, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text('«$note»', style: theme.textTheme.bodyMedium),
          ],
          if (showSourceMeeting && view.meetingTitle != null) ...[
            const SizedBox(height: 2),
            Text(
              TS.proposedIn(view.meetingTitle!),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          if (u.evidenceSegmentIds.isNotEmpty && evidenceLinks)
            EvidenceChips(
              meetingId: u.meetingId,
              evidence: u.evidenceSegmentIds,
            )
          else if (u.evidenceSegmentIds.isNotEmpty)
            Text(
              TS.evidenceCount(u.evidenceSegmentIds.length),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              children: [
                if (view.changesStatus) ...[
                  TextButton(
                    onPressed: () =>
                        resolvePendingFlow(context, ref, view, accept: false),
                    child: const Text(TS.reject),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        resolvePendingFlow(context, ref, view, accept: true),
                    child: const Text(TS.apply),
                  ),
                ] else
                  FilledButton.tonal(
                    onPressed: () =>
                        resolvePendingFlow(context, ref, view, accept: false),
                    child: const Text(TS.acknowledge),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
