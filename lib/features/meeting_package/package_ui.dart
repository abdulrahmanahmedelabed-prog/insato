// UI of «حزمة الاجتماع»: export options, import (open → password →
// new meeting or merge → preview → progress → regenerate minutes), undo of
// a merge, the meetings-screen import button and the listener for packages
// opened from other apps. Arabic, RTL.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/format.dart' show ltrIsolate;
import '../../ui/navigation.dart' show openMeeting;
import '../../ui/widgets/common.dart' show shareOriginOf, showSnackOn;
import 'package_audio.dart' show AlignmentMethod;
import 'package_format.dart';
import 'package_providers.dart';
import 'package_service.dart';
import 'strings.dart';

String _errorText(Object e) => switch (e) {
  PackageException(:final kind) => PS.error(kind),
  InsatoException(:final messageAr) => messageAr,
  _ => PS.failed,
};

/// Runs [task] under a modal progress dialog.
Future<T> runWithPackageProgress<T>(
  BuildContext context,
  String initialStatus,
  Future<T> Function(PackageProgress progress) task,
) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final status = ValueNotifier<(double, String)>((0, initialStatus));
  var open = true;
  unawaited(
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) =>
          PopScope(canPop: false, child: _ProgressDialog(status: status)),
    ).whenComplete(() => open = false),
  );
  try {
    return await task((p, s) => status.value = (p, s));
  } finally {
    if (open && nav.mounted) nav.pop();
    status.dispose();
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.status});

  final ValueNotifier<(double, String)> status;

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: ValueListenableBuilder<(double, String)>(
      valueListenable: status,
      builder: (context, v, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(v.$2, key: const Key('package-progress-status')),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: v.$1 > 0 ? v.$1 : null),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// Export options dialog (returns null when cancelled).
class ExportPackageDialog extends StatefulWidget {
  /// Creates the dialog.
  const ExportPackageDialog({
    super.key,
    required this.hasAudio,
    required this.hasMinutes,
    this.includeAudio = true,
  });

  /// The meeting has a recording.
  final bool hasAudio;

  /// The meeting has minutes.
  final bool hasMinutes;

  /// Initial "include the recording".
  final bool includeAudio;

  @override
  State<ExportPackageDialog> createState() => _ExportPackageDialogState();
}

class _ExportPackageDialogState extends State<ExportPackageDialog> {
  late bool _audio = widget.hasAudio && widget.includeAudio;
  late bool _minutes = widget.hasMinutes;
  bool _voiceprints = false;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final pw = _password.text;
    if (pw.isNotEmpty && pw.length < 6) {
      setState(() => _error = PS.passwordShort);
      return;
    }
    if (pw != _confirm.text) {
      setState(() => _error = PS.passwordMismatch);
      return;
    }
    Navigator.of(context).pop(
      PackageExportOptions(
        includeAudio: _audio,
        includeMinutes: _minutes,
        includeVoiceprints: _voiceprints,
        password: pw.isEmpty ? null : pw,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.inventory_2_outlined),
      title: const Text(PS.exportTitle),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(PS.exportIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('package-include-audio'),
              contentPadding: EdgeInsets.zero,
              value: _audio,
              onChanged: widget.hasAudio
                  ? (v) => setState(() => _audio = v)
                  : null,
              title: const Text(PS.includeAudio),
              subtitle: Text(
                widget.hasAudio ? PS.includeAudioHint : PS.noAudioAvailable,
              ),
            ),
            SwitchListTile(
              key: const Key('package-include-minutes'),
              contentPadding: EdgeInsets.zero,
              value: _minutes,
              onChanged: widget.hasMinutes
                  ? (v) => setState(() => _minutes = v)
                  : null,
              title: const Text(PS.includeMinutes),
            ),
            SwitchListTile(
              key: const Key('package-include-voiceprints'),
              contentPadding: EdgeInsets.zero,
              value: _voiceprints,
              onChanged: (v) => setState(() => _voiceprints = v),
              title: const Text(PS.includeVoiceprints),
              subtitle: Text(
                PS.voiceprintsWarning,
                style: _voiceprints
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('package-password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: PS.password,
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_password.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('package-password-confirm'),
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: PS.passwordConfirm,
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 4),
              Text(PS.passwordHint, style: theme.textTheme.bodySmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(PS.cancel),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text(PS.exportAction),
        ),
      ],
    );
  }
}

/// «تصدير حزمة الاجتماع»: options → package → share sheet / save dialog.
Future<void> exportMeetingPackageFlow(
  BuildContext context,
  WidgetRef ref,
  Meeting meeting,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  final origin = shareOriginOf(context);
  final service = ref.read(meetingPackageServiceProvider);
  final files = ref.read(packageFilesProvider);
  final includeAudio = await service.store.includeAudioPreference();
  if (!context.mounted) return;
  final options = await showDialog<PackageExportOptions>(
    context: context,
    builder: (_) => ExportPackageDialog(
      hasAudio: meeting.audioPath != null,
      hasMinutes: meeting.minutes != null,
      includeAudio: includeAudio,
    ),
  );
  if (options == null || !context.mounted) return;
  if (meeting.audioPath != null) {
    await service.store.setIncludeAudioPreference(options.includeAudio);
  }
  if (!context.mounted) return;
  try {
    final out = await runWithPackageProgress(
      context,
      PS.progressReading,
      (progress) => service.export(meeting.id, options, onProgress: progress),
    );
    final r = await files.save(
      bytes: out.bytes,
      fileName: out.fileName,
      origin: origin,
    );
    if (r.savedPath != null) {
      showSnackOn(messenger, scheme, PS.savedAt(r.savedPath!));
    } else if (r.done) {
      showSnackOn(messenger, scheme, PS.exported);
    }
  } catch (e) {
    showSnackOn(messenger, scheme, _errorText(e), error: true);
  }
}

// ---------------------------------------------------------------------------
// Import
// ---------------------------------------------------------------------------

Future<String?> _askPassword(BuildContext context, {required bool wrong}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _PasswordDialog(wrong: wrong),
    );

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.wrong});

  final bool wrong;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.lock_outline_rounded),
    title: const Text(PS.passwordTitle),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.wrong
              ? PS.error(PackageErrorKind.wrongPassword)
              : PS.passwordBody,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('package-open-password'),
          controller: _c,
          obscureText: true,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(PS.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_c.text),
        child: const Text(PS.openAction),
      ),
    ],
  );
}

enum _ImportChoice { newMeeting, merge }

String _signedDuration(int ms) =>
    '${ms < 0 ? '−' : ''}${ltrIsolate(formatDuration(ms.abs()))}';

/// Summary of a package (device, start, duration, content).
class PackageSummary extends StatelessWidget {
  /// Creates the summary.
  const PackageSummary({super.key, required this.package});

  /// The package.
  final MeetingPackage package;

  @override
  Widget build(BuildContext context) {
    final mf = package.manifest;
    final speakers = {for (final s in package.segments) ?s.speakerKey}.length;
    final content = [
      if (mf.includes.audio) PS.hasAudio,
      if (mf.includes.minutes) PS.hasMinutes,
      if (mf.includes.voiceprints) PS.hasVoiceprints,
      if (package.encrypted) PS.encrypted,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(mf.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _Row(PS.device, mf.device.name),
        _Row(PS.startedAt, formatArabicDateTime(mf.startedAt)),
        _Row(
          PS.duration,
          ltrIsolate(formatDuration(package.effectiveDurationMs)),
        ),
        _Row(PS.segments, '${package.segments.length}'),
        _Row(PS.speakers, '$speakers'),
        _Row(
          PS.contents,
          content.isEmpty ? PS.transcriptOnly : content.join('، '),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: muted)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// The merge preview: device, duration, overlap, offset, duplicates,
/// speakers. Pops true to merge.
class MergePreviewDialog extends StatelessWidget {
  /// Creates the dialog.
  const MergePreviewDialog({super.key, required this.preview});

  /// The preview.
  final MergePreview preview;

  @override
  Widget build(BuildContext context) {
    final a = preview.alignment;
    final plan = preview.plan;
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.merge_rounded),
      title: const Text(PS.previewTitle),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              PS.mergeInto(preview.target.title),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _Row(PS.device, preview.package.manifest.device.name),
            _Row(
              PS.duration,
              ltrIsolate(formatDuration(preview.package.effectiveDurationMs)),
            ),
            _Row(
              PS.overlap,
              preview.overlapMs > 0
                  ? ltrIsolate(formatDuration(preview.overlapMs))
                  : PS.noOverlap,
            ),
            _Row(PS.offset, PS.offsetValue(_signedDuration(a.offsetMs))),
            const SizedBox(height: 8),
            Text(
              a.method == AlignmentMethod.audio
                  ? PS.alignedByAudio(_signedDuration(a.clockErrorMs))
                  : PS.alignedByClock,
              key: const Key('package-alignment-note'),
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Text(PS.newSegments(plan.inserts.length)),
            if (plan.duplicates > 0)
              Text(PS.duplicates(plan.duplicates, plan.replacements.length)),
            Text(
              PS.speakersSummary(preview.matchedSpeakers, preview.newSpeakers),
            ),
            const SizedBox(height: 12),
            Text(PS.undoNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(PS.cancel),
        ),
        FilledButton.icon(
          key: const Key('package-merge-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.merge_rounded),
          label: const Text(PS.mergeAction),
        ),
      ],
    );
  }
}

Future<String?> _chooseMeeting(BuildContext context, WidgetRef ref) async {
  final session = ref.read(meetingSessionControllerProvider);
  final all = await ref.read(meetingRepositoryProvider).getAll();
  final candidates = [
    for (final m in all)
      if (m.status != MeetingStatus.recording &&
          m.status != MeetingStatus.processing &&
          !(session.isActive && session.meetingId == m.id))
        m,
  ];
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text(PS.chooseMeeting),
      children: [
        if (candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(PS.noMeetings),
          ),
        for (final m in candidates)
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(m.title),
            subtitle: Text(formatArabicDateTime(m.createdAt)),
            onTap: () => Navigator.of(context).pop(m.id),
          ),
      ],
    ),
  );
}

/// Imports a package: [file] (or one the user picks) is opened (asking for
/// its password when needed); with [intoMeetingId] it is merged into that
/// meeting, otherwise the user chooses between a new meeting and a merge.
Future<void> importMeetingPackageFlow(
  BuildContext context,
  WidgetRef ref, {
  String? intoMeetingId,
  PickedPackageFile? file,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  final service = ref.read(meetingPackageServiceProvider);
  void fail(Object e) =>
      showSnackOn(messenger, scheme, _errorText(e), error: true);

  PickedPackageFile? picked = file;
  if (picked == null) {
    try {
      picked = await ref.read(packageFilesProvider).pick();
    } catch (e) {
      fail(e);
      return;
    }
  }
  if (picked == null || !context.mounted) return;

  MeetingPackage? pkg;
  String? password;
  var wrong = false;
  while (pkg == null) {
    try {
      final pw = password;
      final bytes = picked.bytes;
      pkg = await runWithPackageProgress(
        context,
        PS.progressOpening,
        (_) => service.open(bytes, password: pw),
      );
    } on PackageException catch (e) {
      if (e.kind == PackageErrorKind.passwordRequired ||
          (e.kind == PackageErrorKind.wrongPassword && password != null)) {
        if (!context.mounted) return;
        wrong = e.kind == PackageErrorKind.wrongPassword;
        password = await _askPassword(context, wrong: wrong);
        if (password == null || password.isEmpty) return;
        continue;
      }
      fail(e);
      return;
    } catch (e) {
      fail(e);
      return;
    }
    if (!context.mounted) return;
  }
  if (!context.mounted) return;

  var target = intoMeetingId;
  if (target == null) {
    final opened = pkg;
    final choice = await showDialog<_ImportChoice>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.inventory_2_outlined),
        title: const Text(PS.importTitle),
        scrollable: true,
        content: SizedBox(width: 480, child: PackageSummary(package: opened)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(PS.cancel),
          ),
          OutlinedButton.icon(
            key: const Key('package-as-new'),
            onPressed: () =>
                Navigator.of(context).pop(_ImportChoice.newMeeting),
            icon: const Icon(Icons.add_rounded),
            label: const Text(PS.asNewMeeting),
          ),
          FilledButton.icon(
            key: const Key('package-merge'),
            onPressed: () => Navigator.of(context).pop(_ImportChoice.merge),
            icon: const Icon(Icons.merge_rounded),
            label: const Text(PS.mergeIntoExisting),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _ImportChoice.newMeeting) {
      try {
        final opened = pkg;
        final id = await runWithPackageProgress(
          context,
          PS.progressImporting,
          (progress) =>
              service.importAsNewMeeting(opened, onProgress: progress),
        );
        showSnackOn(messenger, scheme, PS.imported);
        if (context.mounted) await openMeeting(context, ref, id);
      } catch (e) {
        fail(e);
      }
      return;
    }
    target = await _chooseMeeting(context, ref);
    if (target == null || !context.mounted) return;
  }
  await _mergeFlow(context, ref, target, pkg);
}

Future<void> _mergeFlow(
  BuildContext context,
  WidgetRef ref,
  String meetingId,
  MeetingPackage pkg,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  final service = ref.read(meetingPackageServiceProvider);
  try {
    final preview = await runWithPackageProgress(
      context,
      PS.progressAligning,
      (progress) => service.previewMerge(meetingId, pkg, onProgress: progress),
    );
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => MergePreviewDialog(preview: preview),
    );
    if (ok != true || !context.mounted) return;
    final result = await runWithPackageProgress(
      context,
      PS.progressMerging,
      (progress) => service.merge(meetingId, pkg, onProgress: progress),
    );
    showSnackOn(messenger, scheme, PS.merged(result.insertedSegments));
    if (!context.mounted) return;
    final regenerate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.description_outlined),
        title: const Text(PS.regenerateTitle),
        content: const Text(PS.regenerateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(PS.later),
          ),
          FilledButton(
            key: const Key('package-regenerate'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(PS.regenerateAction),
          ),
        ],
      ),
    );
    if (regenerate == true) {
      unawaited(
        ref.read(meetingJobsProvider(meetingId).notifier).generateMinutes(),
      );
    }
  } catch (e) {
    showSnackOn(messenger, scheme, _errorText(e), error: true);
  }
}

/// «التراجع عن دمج الحزمة» with confirmation.
Future<void> undoMeetingPackageMergeFlow(
  BuildContext context,
  WidgetRef ref,
  String meetingId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  final service = ref.read(meetingPackageServiceProvider);
  final latest = (await service.store.stack(meetingId)).lastOrNull;
  if (!context.mounted) return;
  if (latest == null) {
    showSnackOn(messenger, scheme, PS.nothingToUndo);
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.undo_rounded),
      title: const Text(PS.undoTitle),
      content: Text(PS.undoBody(latest.deviceName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(PS.cancel),
        ),
        FilledButton(
          key: const Key('package-undo-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(PS.undoAction),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final undone = await service.undoLastMerge(meetingId);
    showSnackOn(messenger, scheme, undone ? PS.undone : PS.nothingToUndo);
  } catch (e) {
    showSnackOn(messenger, scheme, _errorText(e), error: true);
  }
}

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

/// Meetings-screen app-bar button «استيراد حزمة اجتماع».
class MeetingPackageImportButton extends ConsumerWidget {
  /// Creates the button.
  const MeetingPackageImportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: PS.importTooltip,
    icon: const Icon(Icons.move_to_inbox_rounded),
    onPressed: () => importMeetingPackageFlow(context, ref),
  );
}

/// Opens the import flow for packages handed over by other apps (Android
/// "open with" / share, iOS "Open in إنصاتو"). Place it under the app's
/// navigator (home shell).
class IncomingPackageListener extends ConsumerStatefulWidget {
  /// Creates the listener.
  const IncomingPackageListener({super.key, required this.child});

  /// The page.
  final Widget child;

  @override
  ConsumerState<IncomingPackageListener> createState() =>
      _IncomingPackageListenerState();
}

class _IncomingPackageListenerState
    extends ConsumerState<IncomingPackageListener>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _sub;
  late final IncomingPackages _source;
  final List<String> _queue = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _source = ref.read(incomingPackagesProvider);
    _sub = _source.files.listen(_onFile);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_source.poll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_source.poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onFile(String path) {
    _queue.add(path);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty && mounted) {
        final path = _queue.removeAt(0);
        PickedPackageFile? file;
        try {
          final f = File(path);
          file = PickedPackageFile(
            f.uri.pathSegments.last,
            await f.readAsBytes(),
          );
          // The copy handed over by the system is no longer needed.
          await f.delete();
        } catch (_) {
          file = null;
        }
        if (file == null || !mounted) continue;
        await importMeetingPackageFlow(context, ref, file: file);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
