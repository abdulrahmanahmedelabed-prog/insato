// Template choice (v1.2): a dropdown of the built-in templates and the
// institution's uploaded Word templates, used on the pre-meeting context
// page and on the official minutes screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/official_repository.dart' show customTemplatesProvider;
import 'official_models.dart';
import 'official_templates.dart';
import 'strings.dart';

/// The `MeetingContext.template` value of [ref]: null for the default team
/// template.
String? templateRefValue(String? ref) =>
    ref == null || ref == OfficialTemplates.team.id ? null : ref;

/// A dropdown choosing the meeting's template. [value] is the
/// `MeetingContext.template` value (null = team).
class TemplatePickerField extends ConsumerWidget {
  /// Creates the field.
  const TemplatePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// Current value.
  final String? value;

  /// Called with the new value (null = team).
  final ValueChanged<String?> onChanged;

  /// False disables the field.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customs = ref.watch(customTemplatesProvider).value ?? const [];
    final choice = resolveTemplate(value, customs);
    final current = choice.custom?.ref ?? choice.template.id;
    final items = <DropdownMenuItem<String>>[
      for (final t in OfficialTemplates.all)
        DropdownMenuItem(value: t.id, child: Text(t.nameAr)),
      for (final c in customs)
        DropdownMenuItem(
          value: c.ref,
          child: Text(
            '${c.name} (${OfficialTemplates.byId(c.baseTemplateId).nameAr})',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('template-$current-${customs.length}'),
          initialValue: current,
          isExpanded: true,
          decoration: const InputDecoration(labelText: OS.templateLabel),
          items: items,
          onChanged: enabled ? (v) => onChanged(templateRefValue(v)) : null,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
          child: Text(
            choice.custom == null
                ? choice.template.descriptionAr
                : OS.uploadedBasedOn(choice.template.nameAr),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
