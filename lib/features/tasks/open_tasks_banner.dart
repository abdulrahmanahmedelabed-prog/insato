// Recording-start banner (F9): the open tasks (from earlier meetings) of the
// people expected at the meeting being recorded, so they can be followed up.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'strings.dart';
import 'task_logic.dart';
import 'task_providers.dart';

/// Tasks listed per attendee before «+ n more».
const int kBannerTasksPerAttendee = 3;

/// Banner for the meeting [meetingId] (reads its expected attendees from
/// the meeting context). Renders nothing when no attendee owns an open task
/// or the user hid it.
class OpenTasksBanner extends ConsumerWidget {
  /// Creates the banner.
  const OpenTasksBanner({super.key, required this.meetingId});

  /// The meeting being recorded.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenTaskBannersProvider).contains(meetingId);
    if (hidden) return const SizedBox.shrink();
    final groups = ref.watch(meetingAttendeeOpenTasksProvider(meetingId));
    if (groups.isEmpty) return const SizedBox.shrink();
    return OpenTasksBannerView(
      groups: groups,
      onHide: () =>
          ref.read(hiddenTaskBannersProvider.notifier).hide(meetingId),
    );
  }
}

/// The banner's presentation for already computed [groups].
class OpenTasksBannerView extends StatefulWidget {
  /// Creates the view.
  const OpenTasksBannerView({
    super.key,
    required this.groups,
    this.onHide,
    this.initiallyExpanded = false,
  });

  /// Open tasks per attendee.
  final List<AttendeeOpenTasks> groups;

  /// Hides the banner (no hide button when null).
  final VoidCallback? onHide;

  /// Whether the task list starts expanded.
  final bool initiallyExpanded;

  @override
  State<OpenTasksBannerView> createState() => _OpenTasksBannerViewState();
}

class _OpenTasksBannerViewState extends State<OpenTasksBannerView> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = widget.groups.fold<int>(0, (n, g) => n + g.tasks.length);
    final fg = scheme.onSecondaryContainer;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card(
        color: scheme.secondaryContainer,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_late_outlined, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      TS.bannerTitle(total),
                      style: theme.textTheme.titleSmall?.copyWith(color: fg),
                    ),
                  ),
                  IconButton(
                    tooltip: _expanded ? TS.hideDetails : TS.showDetails,
                    color: fg,
                    icon: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                  if (widget.onHide != null)
                    IconButton(
                      tooltip: TS.hideBanner,
                      color: fg,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: widget.onHide,
                    ),
                ],
              ),
              if (_expanded) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Text(
                    TS.bannerBody,
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ),
                for (final g in widget.groups) _group(theme, fg, g),
              ] else
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Text(
                    widget.groups.map((g) => g.attendee).join('، '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(ThemeData theme, Color fg, AttendeeOpenTasks g) {
    final shown = g.tasks.take(kBannerTasksPerAttendee).toList();
    final more = g.tasks.length - shown.length;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8, end: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            g.attendee,
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final t in shown)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 2),
              child: Text(
                t.dueText == null
                    ? '• ${t.task}'
                    : '• ${t.task} — ${TS.dueLine(t.dueText!)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              ),
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 2),
              child: Text(
                TS.moreTasks(more),
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
            ),
        ],
      ),
    );
  }
}
