// «أضف إلى القاموس» for a jargon finding (F17 → F2): the user confirms or
// corrects the inferred meaning before the term is stored in the glossary
// (the meaning goes into the term's Arabic spelling / translation field).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import 'strings.dart';

/// Opens the dialog for [item] of [meetingId]; returns the stored term, or
/// null when cancelled or failed (a snack bar reports the outcome).
Future<GlossaryTerm?> showAddJargonToGlossaryDialog(
  BuildContext context, {
  required String meetingId,
  required JargonItem item,
}) => showDialog<GlossaryTerm>(
  context: context,
  builder: (_) => AddJargonToGlossaryDialog(meetingId: meetingId, item: item),
);

/// The dialog (see [showAddJargonToGlossaryDialog]).
class AddJargonToGlossaryDialog extends ConsumerStatefulWidget {
  /// Creates the dialog.
  const AddJargonToGlossaryDialog({
    super.key,
    required this.meetingId,
    required this.item,
  });

  /// Meeting the term was found in (scope "this meeting only").
  final String meetingId;

  /// The jargon finding.
  final JargonItem item;

  @override
  ConsumerState<AddJargonToGlossaryDialog> createState() =>
      _AddJargonToGlossaryDialogState();
}

class _AddJargonToGlossaryDialogState
    extends ConsumerState<AddJargonToGlossaryDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _term = TextEditingController(
    text: widget.item.term,
  );
  late final TextEditingController _meaning = TextEditingController(
    text: widget.item.inferredMeaning,
  );
  bool _global = true;
  bool _saving = false;

  @override
  void dispose() {
    _term.dispose();
    _meaning.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    try {
      final term = await ref
          .read(glossaryRepositoryProvider)
          .add(
            term: _term.text,
            arSpelling: _meaning.text.trim(),
            category: GlossaryCategory.technical,
            meetingId: _global ? null : widget.meetingId,
          );
      if (messenger != null) {
        showSnackOn(messenger, scheme, KS.addedToGlossary(term.term));
      }
      if (mounted) Navigator.of(context).pop(term);
    } catch (_) {
      if (messenger != null) {
        showSnackOn(messenger, scheme, KS.addToGlossaryFailed, error: true);
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text(KS.addToGlossaryTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  KS.addToGlossaryNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _term,
                  decoration: const InputDecoration(labelText: KS.termLabel),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? KS.termEmpty : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _meaning,
                  decoration: const InputDecoration(labelText: KS.meaningLabel),
                  minLines: 1,
                  maxLines: 3,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? KS.meaningEmpty : null,
                ),
                const SizedBox(height: 16),
                Text(KS.scopeLabel, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text(KS.scopeGlobal)),
                    ButtonSegment(value: false, label: Text(KS.scopeMeeting)),
                  ],
                  selected: {_global},
                  onSelectionChanged: (s) => setState(() => _global = s.first),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text(S.save),
        ),
      ],
    );
  }
}
