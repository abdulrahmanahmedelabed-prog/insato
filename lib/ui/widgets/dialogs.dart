// Reusable dialogs: confirmation, single-line text input, the recording
// consent reminder and a speaker picker.

import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../strings_ar.dart';
import 'speaker_avatar.dart';

/// Asks for confirmation. Returns true only when [confirmLabel] was pressed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: icon == null
            ? null
            : Icon(icon, color: destructive ? scheme.error : scheme.primary),
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Asks for one line of text. Returns the trimmed text, or null when
/// cancelled. Blank input is rejected with [emptyError].
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? body,
  String initialValue = '',
  required String label,
  String? hint,
  String confirmLabel = S.save,
  String emptyError = S.nameEmpty,
  int maxLines = 1,
  TextDirection? textDirection,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      body: body,
      initialValue: initialValue,
      label: label,
      hint: hint,
      confirmLabel: confirmLabel,
      emptyError: emptyError,
      maxLines: maxLines,
      textDirection: textDirection,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.body,
    required this.initialValue,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.emptyError,
    required this.maxLines,
    required this.textDirection,
  });

  final String title;
  final String? body;
  final String initialValue;
  final String label;
  final String? hint;
  final String confirmLabel;
  final String emptyError;
  final int maxLines;
  final TextDirection? textDirection;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialValue,
  )..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialValue.length,
    );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) {
      setState(() => _error = widget.emptyError);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.body != null) ...[
                Text(
                  widget.body!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _c,
                autofocus: true,
                maxLines: widget.maxLines,
                minLines: 1,
                textDirection: widget.textDirection,
                textInputAction: widget.maxLines == 1
                    ? TextInputAction.done
                    : TextInputAction.newline,
                onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hint,
                  errorText: _error,
                ),
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
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// The recording-consent reminder shown before the first recording. The
/// user must tick the acknowledgement before accepting. Returns true when
/// accepted.
Future<bool> showConsentDialog(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ConsentDialog(),
  );
  return r ?? false;
}

/// Dialog explaining recording consent and privacy.
class ConsentDialog extends StatefulWidget {
  /// Creates the dialog.
  const ConsentDialog({super.key});

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _ack = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.record_voice_over_rounded, color: scheme.primary),
      title: const Text(S.consentTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(S.consentBody),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _ack,
                onChanged: (v) => setState(() => _ack = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(S.consentCheckbox),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(S.cancel),
        ),
        FilledButton.icon(
          onPressed: _ack ? () => Navigator.of(context).pop(true) : null,
          icon: const Icon(Icons.mic_rounded),
          label: const Text(S.consentAccept),
        ),
      ],
    );
  }
}

/// Lets the user pick one of [speakers]. Returns null when cancelled.
Future<Speaker?> showSpeakerPicker(
  BuildContext context, {
  required String title,
  String? body,
  required List<Speaker> speakers,
}) {
  return showDialog<Speaker>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (body != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (speakers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(S.noOtherSpeakers),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in speakers)
                        ListTile(
                          leading: SpeakerAvatar(speaker: s),
                          title: Text(s.name),
                          subtitle: s.isNamedByUser
                              ? null
                              : const Text(S.autoNamed),
                          onTap: () => Navigator.of(context).pop(s),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(S.cancel),
          ),
        ],
      );
    },
  );
}
