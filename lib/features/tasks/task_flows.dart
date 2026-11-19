// User flows of action-item tracking (F9): add / edit / delete a task,
// change its status with undo, and resolve the updates proposed by minutes.
// Each flow captures what it needs (actions, messenger) before its first
// await, so it completes even when the calling tile is rebuilt away (a task
// marked done leaves the «open» list at once).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import 'strings.dart';
import 'task_edit_dialog.dart';
import 'task_logic.dart';
import 'task_providers.dart';

/// Snack confirming a status change.
String taskStatusSnack(TaskStatus s) => switch (s) {
  TaskStatus.open => TS.reopened,
  TaskStatus.done => TS.markedDone,
  TaskStatus.cancelled => TS.cancelled,
};

void _snackWithUndo(
  ScaffoldMessengerState messenger,
  String message,
  Future<void> Function() undo,
) {
  if (!messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: TS.undo, onPressed: () => undo()),
      ),
    );
}

/// Sets [task]'s status, with an undo action restoring the previous one.
Future<void> setTaskStatusFlow(
  BuildContext context,
  WidgetRef ref,
  TrackedTask task,
  TaskStatus status,
) async {
  if (task.status == status) return;
  final actions = ref.read(taskActionsProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  try {
    final ok = await actions.setStatus(task, status);
    if (messenger == null) return;
    if (!ok) {
      showSnackOn(messenger, scheme, TS.saveFailed, error: true);
      return;
    }
    _snackWithUndo(messenger, taskStatusSnack(status), () async {
      try {
        await actions.setStatus(task.copyWith(status: status), task.status);
      } catch (_) {
        showSnackOn(messenger, scheme, TS.saveFailed, error: true);
      }
    });
  } catch (_) {
    if (messenger != null) {
      showSnackOn(messenger, scheme, TS.saveFailed, error: true);
    }
  }
}

/// Opens the edit dialog for [task] and saves the result.
Future<void> editTaskFlow(
  BuildContext context,
  WidgetRef ref,
  TrackedTask task,
) async {
  final actions = ref.read(taskActionsProvider);
  final speakers = ref.read(taskSpeakersByIdProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  final draft = await showTaskEditDialog(
    context,
    initial: TaskDraft.of(task, speakers),
    speakersById: speakers,
  );
  if (draft == null) return;
  try {
    final ok = await actions.save(task, draft, speakersById: speakers);
    if (messenger != null) {
      showSnackOn(messenger, scheme, ok ? TS.saved : TS.saveFailed, error: !ok);
    }
  } catch (_) {
    if (messenger != null) {
      showSnackOn(messenger, scheme, TS.saveFailed, error: true);
    }
  }
}

/// Opens the dialog for a new manual task and stores it.
Future<void> addTaskFlow(BuildContext context, WidgetRef ref) async {
  final actions = ref.read(taskActionsProvider);
  final speakers = ref.read(taskSpeakersByIdProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  final draft = await showTaskEditDialog(context, speakersById: speakers);
  if (draft == null) return;
  try {
    await actions.create(draft);
    if (messenger != null) showSnackOn(messenger, scheme, TS.added);
  } catch (_) {
    if (messenger != null) {
      showSnackOn(messenger, scheme, TS.saveFailed, error: true);
    }
  }
}

/// Asks for confirmation, then deletes [task].
Future<void> deleteTaskFlow(
  BuildContext context,
  WidgetRef ref,
  TrackedTask task,
) async {
  final actions = ref.read(taskActionsProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  final ok = await showConfirmDialog(
    context,
    title: TS.deleteTitle,
    body: TS.deleteBody(task.task),
    confirmLabel: S.delete,
    destructive: true,
    icon: Icons.delete_outline_rounded,
  );
  if (!ok) return;
  try {
    await actions.delete(task);
    if (messenger != null) showSnackOn(messenger, scheme, TS.deleted);
  } catch (_) {
    if (messenger != null) {
      showSnackOn(messenger, scheme, TS.saveFailed, error: true);
    }
  }
}

/// Applies ([accept]) or removes one proposed update.
Future<void> resolvePendingFlow(
  BuildContext context,
  WidgetRef ref,
  PendingUpdateView view, {
  required bool accept,
}) async {
  final actions = ref.read(taskActionsProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  try {
    final r = await actions.resolve(view, accept: accept);
    if (messenger == null) return;
    switch (r) {
      case PendingResolution.applied:
        showSnackOn(messenger, scheme, TS.applied);
      case PendingResolution.dismissed:
        showSnackOn(messenger, scheme, TS.dismissed);
      case PendingResolution.gone:
        showSnackOn(messenger, scheme, TS.updateGone, error: true);
    }
  } catch (_) {
    if (messenger != null) {
      showSnackOn(messenger, scheme, TS.saveFailed, error: true);
    }
  }
}

/// Asks for confirmation, then applies every status-changing update of
/// [views].
Future<void> applyAllPendingFlow(
  BuildContext context,
  WidgetRef ref,
  List<PendingUpdateView> views,
) async {
  final applicable = applicableUpdates(views);
  if (applicable.isEmpty) return;
  final actions = ref.read(taskActionsProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  final ok = await showConfirmDialog(
    context,
    title: TS.applyAllTitle,
    body: TS.applyAllBody(applicable.length),
    confirmLabel: TS.apply,
    icon: Icons.done_all_rounded,
  );
  if (!ok) return;
  try {
    final n = await actions.applyAll(applicable);
    if (messenger != null) {
      showSnackOn(messenger, scheme, TS.appliedCount(n));
    }
  } catch (_) {
    if (messenger != null) {
      showSnackOn(messenger, scheme, TS.saveFailed, error: true);
    }
  }
}
