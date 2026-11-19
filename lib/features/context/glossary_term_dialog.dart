// Add / edit dialog of one glossary term (F2), used by the glossary screen
// and for meeting-only terms in the context sheet (F3).

import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../ui/strings_ar.dart';
import 'glossary_logic.dart';
import 'strings.dart';

/// Icon of a glossary category.
IconData glossaryCategoryIcon(GlossaryCategory c) => switch (c) {
  GlossaryCategory.person => Icons.person_rounded,
  GlossaryCategory.organisation => Icons.apartment_rounded,
  GlossaryCategory.technical => Icons.memory_rounded,
  GlossaryCategory.other => Icons.label_rounded,
};

/// Arabic message of a validation error.
String glossaryDraftErrorText(GlossaryDraftError e) => switch (e) {
  GlossaryDraftError.empty => CS.termEmpty,
  GlossaryDraftError.tooLong => CS.termTooLong(kMaxGlossaryTermLength),
  GlossaryDraftError.duplicate => CS.termDuplicate,
};

/// Asks for a term. [initial] edits an existing draft; [existing] are the
/// other terms of the same scope (for the duplicate check). Returns the
/// normalised draft (keeping `initial.id`), or null when cancelled.
Future<GlossaryDraft?> showGlossaryTermDialog(
  BuildContext context, {
  GlossaryDraft? initial,
  Iterable<GlossaryDraft> existing = const [],
  GlossaryCategory defaultCategory = GlossaryCategory.other,
}) => showDialog<GlossaryDraft>(
  context: context,
  builder: (context) => GlossaryTermDialog(
    initial: initial,
    existing: existing.toList(growable: false),
    defaultCategory: defaultCategory,
  ),
);

/// The add / edit term dialog.
class GlossaryTermDialog extends StatefulWidget {
  /// Creates the dialog.
  const GlossaryTermDialog({
    super.key,
    this.initial,
    this.existing = const [],
    this.defaultCategory = GlossaryCategory.other,
  });

  /// Term being edited (null = new).
  final GlossaryDraft? initial;

  /// Other terms of the scope.
  final List<GlossaryDraft> existing;

  /// Category preselected for a new term.
  final GlossaryCategory defaultCategory;

  @override
  State<GlossaryTermDialog> createState() => _GlossaryTermDialogState();
}

class _GlossaryTermDialogState extends State<GlossaryTermDialog> {
  late final TextEditingController _term = TextEditingController(
    text: widget.initial?.term ?? '',
  );
  late final TextEditingController _ar = TextEditingController(
    text: widget.initial?.arSpelling ?? '',
  );
  late GlossaryCategory _category =
      widget.initial?.category ?? widget.defaultCategory;
  String? _error;

  @override
  void dispose() {
    _term.dispose();
    _ar.dispose();
    super.dispose();
  }

  void _submit() {
    final draft = GlossaryDraft(
      id: widget.initial?.id,
      term: _term.text,
      arSpelling: _ar.text,
      category: _category,
    ).normalized();
    final others = [
      for (final e in widget.existing)
        if (!identical(e, widget.initial) &&
            (widget.initial?.id == null || e.id != widget.initial!.id))
          e,
    ];
    final error = validateGlossaryDraft(draft, existing: others);
    if (error != null) {
      setState(() => _error = glossaryDraftErrorText(error));
      return;
    }
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      icon: Icon(
        Icons.spellcheck_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(editing ? CS.editTerm : CS.addTerm),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _term,
              autofocus: true,
              maxLength: kMaxGlossaryTermLength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: CS.termLabel,
                hintText: CS.termHint,
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ar,
              maxLength: kMaxGlossarySpellingLength,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: CS.arSpellingLabel,
                hintText: CS.arSpellingHint,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text(
              CS.categoryLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in GlossaryCategory.values)
                  ChoiceChip(
                    avatar: Icon(glossaryCategoryIcon(c), size: 18),
                    label: Text(CS.category(c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
          ],
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
