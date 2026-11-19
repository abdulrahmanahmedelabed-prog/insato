// Add / edit dialog of one task (F9): text, owner (free text or a speaker
// of the voice library), due text and status.

import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/dialogs.dart';
import 'strings.dart';
import 'task_logic.dart';

/// Icon of a task status.
IconData taskStatusIcon(TaskStatus s) => switch (s) {
  TaskStatus.open => Icons.radio_button_unchecked_rounded,
  TaskStatus.done => Icons.check_circle_rounded,
  TaskStatus.cancelled => Icons.cancel_outlined,
};

/// Arabic message of a validation error.
String taskDraftErrorText(TaskDraftError e) => switch (e) {
  TaskDraftError.taskEmpty => TS.taskEmpty,
  TaskDraftError.taskTooLong => TS.taskTooLong(kMaxTaskLength),
  TaskDraftError.ownerTooLong => TS.fieldTooLong(kMaxTaskOwnerLength),
  TaskDraftError.dueTooLong => TS.fieldTooLong(kMaxTaskDueLength),
};

/// Asks for a task. [initial] edits an existing draft (null = new task);
/// [speakersById] backs the speaker picker and the owner link. Returns the
/// normalised, valid draft, or null when cancelled.
Future<TaskDraft?> showTaskEditDialog(
  BuildContext context, {
  TaskDraft? initial,
  required Map<String, Speaker> speakersById,
}) => showDialog<TaskDraft>(
  context: context,
  builder: (context) =>
      TaskEditDialog(initial: initial, speakersById: speakersById),
);

/// The add / edit task dialog.
class TaskEditDialog extends StatefulWidget {
  /// Creates the dialog.
  const TaskEditDialog({super.key, this.initial, this.speakersById = const {}});

  /// Draft being edited (null = new).
  final TaskDraft? initial;

  /// Speakers of the voice library.
  final Map<String, Speaker> speakersById;

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  late final TextEditingController _task = TextEditingController(
    text: widget.initial?.task ?? '',
  );
  late final TextEditingController _owner = TextEditingController(
    text: widget.initial?.ownerText ?? '',
  );
  late final TextEditingController _due = TextEditingController(
    text: widget.initial?.dueText ?? '',
  );
  late String? _linkedSpeaker = widget.initial?.ownerSpeakerId;
  late TaskStatus _status = widget.initial?.status ?? TaskStatus.open;
  TaskDraftError? _error;

  @override
  void dispose() {
    _task.dispose();
    _owner.dispose();
    _due.dispose();
    super.dispose();
  }

  TaskDraft get _draft => TaskDraft(
    task: _task.text,
    ownerText: _owner.text,
    ownerSpeakerId: _linkedSpeaker,
    dueText: _due.text,
    status: _status,
  ).normalized(widget.speakersById);

  void _submit() {
    final draft = _draft;
    final error = validateTaskDraft(draft);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(draft);
  }

  Future<void> _pickSpeaker() async {
    final speakers = widget.speakersById.values.toList()
      ..sort((a, b) {
        if (a.isNamedByUser != b.isNamedByUser) return a.isNamedByUser ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final s = await showSpeakerPicker(
      context,
      title: TS.pickSpeakerTitle,
      speakers: speakers,
    );
    if (s == null || !mounted) return;
    setState(() {
      _owner.text = s.name;
      _linkedSpeaker = s.id;
      if (_error == TaskDraftError.ownerTooLong) _error = null;
    });
  }

  String? _errorFor(Set<TaskDraftError> errors) {
    final e = _error;
    return e != null && errors.contains(e) ? taskDraftErrorText(e) : null;
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linked = resolveTaskOwner(
      collapseTaskSpaces(_owner.text),
      _linkedSpeaker,
      widget.speakersById,
    );
    return AlertDialog(
      title: Text(widget.initial == null ? TS.newTaskTitle : TS.editTaskTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _task,
                autofocus: widget.initial == null,
                minLines: 1,
                maxLines: 4,
                maxLength: kMaxTaskLength,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: TS.taskLabel,
                  hintText: TS.taskHint,
                  errorText: _errorFor(const {
                    TaskDraftError.taskEmpty,
                    TaskDraftError.taskTooLong,
                  }),
                ),
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _owner,
                maxLength: kMaxTaskOwnerLength,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: TS.ownerLabel,
                  hintText: TS.ownerHint,
                  helperText: linked != null ? TS.ownerLinked : null,
                  errorText: _errorFor(const {TaskDraftError.ownerTooLong}),
                  suffixIcon: _owner.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: TS.clearOwner,
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() {
                            _owner.clear();
                            _linkedSpeaker = null;
                          }),
                        ),
                ),
                onChanged: (_) => setState(() {
                  if (_error == TaskDraftError.ownerTooLong) _error = null;
                }),
              ),
              if (widget.speakersById.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _pickSpeaker,
                    icon: const Icon(Icons.record_voice_over_rounded),
                    label: const Text(TS.pickSpeaker),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _due,
                maxLength: kMaxTaskDueLength,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: TS.dueLabel,
                  hintText: TS.dueHint,
                  errorText: _errorFor(const {TaskDraftError.dueTooLong}),
                ),
                onChanged: (_) => _clearError(),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Text(TS.statusLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in TaskStatus.values)
                    ChoiceChip(
                      avatar: Icon(taskStatusIcon(s), size: 18),
                      label: Text(TS.status(s)),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(onPressed: _submit, child: const Text(S.save)),
      ],
    );
  }
}
