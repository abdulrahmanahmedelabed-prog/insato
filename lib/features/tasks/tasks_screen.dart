// Tasks screen (F9): every task extracted from minutes (or added by hand),
// filtered by status / owner / meeting / search, with the updates proposed
// by later minutes awaiting confirmation at the top.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../data/repositories_v11.dart';
import '../../ui/widgets/common.dart';
import 'strings.dart';
import 'task_edit_dialog.dart';
import 'task_flows.dart';
import 'task_logic.dart';
import 'task_providers.dart';
import 'task_widgets.dart';

const String _any = '\u0000any';

/// The tasks screen. Usable as a pushed page ([openTasksScreen]) or as a
/// top-level shell destination.
class TasksScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const TasksScreen({super.key, this.initialMeetingId});

  /// Pre-selects the meeting filter (e.g. opened from a meeting page).
  final String? initialMeetingId;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(taskFilterProvider).query,
  );

  @override
  void initState() {
    super.initState();
    final id = widget.initialMeetingId;
    if (id != null) {
      // Riverpod forbids state changes during build; initState is before.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _update(
          ref
              .read(taskFilterProvider)
              .copyWith(meetingKey: id, allStatuses: true),
        );
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(TaskFilter f) => ref.read(taskFilterProvider.notifier).set(f);

  void _reset() {
    _search.clear();
    ref.read(taskFilterProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(tasksViewProvider);
    final filter = ref.watch(taskFilterProvider);
    final pending = ref.watch(pendingUpdateViewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(TS.tasksTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks-add',
        onPressed: () => addTaskFlow(context, ref),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(TS.addTask),
      ),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: TS.loadFailed,
            onRetry: () => ref.invalidate(tasksProvider),
          ),
        ),
        data: (v) => _body(context, v, filter, pending),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    TasksView v,
    TaskFilter filter,
    List<PendingUpdateView> pending,
  ) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    if (pending.isNotEmpty) children.add(PendingUpdatesCard(views: pending));
    if (v.all.isEmpty) {
      children.add(
        const EmptyState(
          icon: Icons.task_alt_rounded,
          title: TS.emptyTitle,
          body: TS.emptyBody,
        ),
      );
    } else {
      children
        ..add(const SizedBox(height: 8))
        ..add(
          SearchBar(
            controller: _search,
            hintText: TS.searchHint,
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (filter.query.isNotEmpty)
                IconButton(
                  tooltip: TS.clearSearch,
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _search.clear();
                    _update(filter.copyWith(query: ''));
                  },
                ),
            ],
            onChanged: (q) => _update(filter.copyWith(query: q)),
          ),
        )
        ..add(const SizedBox(height: 12))
        ..add(_statusChips(v, filter))
        ..add(const SizedBox(height: 8))
        ..add(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ownerFilter(v, filter),
              _meetingFilter(v, filter),
              if (!filter.isDefault)
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text(TS.clearFilters),
                ),
            ],
          ),
        )
        ..add(const SizedBox(height: 8));
      if (v.shown.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              TS.noMatches,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      } else {
        children.add(
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
              child: Text(
                TS.shownCount(v.shown.length),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
        for (final t in v.shown) {
          children.add(TaskTile(key: ValueKey('task-${t.id}'), task: t));
        }
      }
    }
    // Room for the floating button.
    children.add(const SizedBox(height: 88));
    return ReadableWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: children,
      ),
    );
  }

  Widget _statusChips(TasksView v, TaskFilter filter) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final s in TaskStatus.values)
        ChoiceChip(
          avatar: Icon(taskStatusIcon(s), size: 18),
          label: Text(TS.statusCount(TS.status(s), v.statusCounts[s] ?? 0)),
          selected: filter.status == s,
          onSelected: (_) => _update(filter.copyWith(status: s)),
        ),
      ChoiceChip(
        label: Text(TS.statusCount(TS.allStatuses, v.totalMatching)),
        selected: filter.status == null,
        onSelected: (_) => _update(filter.copyWith(allStatuses: true)),
      ),
    ],
  );

  Widget _ownerFilter(TasksView v, TaskFilter filter) {
    String label(String? key) {
      if (key == null) return TS.anyOwner;
      if (key == kNoOwnerKey) return TS.noOwner;
      return v.owners.where((o) => o.key == key).firstOrNull?.label ??
          TS.anyOwner;
    }

    return _MenuChip(
      icon: Icons.person_outline_rounded,
      tooltip: TS.ownerFilter,
      label: '${TS.ownerFilter}: ${label(filter.ownerKey)}',
      selected: filter.ownerKey != null,
      selectedValue: filter.ownerKey ?? _any,
      items: [
        (_any, TS.anyOwner),
        for (final o in v.owners)
          (o.key, '${o.label ?? TS.noOwner} (${o.count})'),
      ],
      onSelected: (k) => _update(
        k == _any
            ? filter.copyWith(clearOwner: true)
            : filter.copyWith(ownerKey: k),
      ),
    );
  }

  Widget _meetingFilter(TasksView v, TaskFilter filter) {
    String label(String? key) {
      if (key == null) return TS.anyMeeting;
      if (key == kNoMeetingKey) return TS.noMeeting;
      return v.meetingsById[key]?.title ?? TS.anyMeeting;
    }

    return _MenuChip(
      icon: Icons.groups_outlined,
      tooltip: TS.meetingFilter,
      label: '${TS.meetingFilter}: ${label(filter.meetingKey)}',
      selected: filter.meetingKey != null,
      selectedValue: filter.meetingKey ?? _any,
      items: [
        (_any, TS.anyMeeting),
        for (final m in v.meetings)
          (m.key, '${m.title ?? TS.noMeeting} (${m.count})'),
      ],
      onSelected: (k) => _update(
        k == _any
            ? filter.copyWith(clearMeeting: true)
            : filter.copyWith(meetingKey: k),
      ),
    );
  }
}

/// A chip that opens a menu of [items] (value, label).
class _MenuChip extends StatelessWidget {
  const _MenuChip({
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.selected,
    required this.selectedValue,
    required this.items,
    required this.onSelected,
  });

  final IconData icon;
  final String tooltip;
  final String label;
  final bool selected;
  final String selectedValue;
  final List<(String, String)> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: tooltip,
      initialValue: selectedValue,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (value, text) in items)
          CheckedPopupMenuItem<String>(
            value: value,
            checked: value == selectedValue,
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, maxWidth: 320),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.secondaryContainer : null,
            border: Border.all(
              color: selected ? scheme.secondaryContainer : scheme.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the tasks screen as a page (optionally filtered to [meetingId]).
Future<void> openTasksScreen(BuildContext context, {String? meetingId}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TasksScreen(initialMeetingId: meetingId),
      ),
    );
