// UI of the recording import: the «استيراد تسجيل» action (file chooser),
// the confirmation dialog with the legal reminder, the progress card of the
// background job (cancel / open meeting), the «مستورد» badge, and the
// listener that offers files shared to the app by other apps.

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../ui/navigation.dart';
import '../../ui/widgets/common.dart';
import 'audio_formats.dart';
import 'import_controller.dart';
import 'import_metadata.dart';
import 'recording_importer.dart';
import 'shared_audio_inbox.dart';
import 'strings.dart';

// ===========================================================================
// File chooser seam
// ===========================================================================

/// A file chosen for import.
class PickedAudio {
  /// Creates the entry.
  const PickedAudio({
    required this.path,
    required this.name,
    this.temporaryCopy = false,
  });

  /// Readable path.
  final String path;

  /// File name shown to the user.
  final String name;

  /// The chooser handed over a copy in the app's cache (Android, iOS),
  /// deleted after the import.
  final bool temporaryCopy;
}

/// Lets the user choose an audio file (null = cancelled).
typedef AudioFilePicker = Future<PickedAudio?> Function();

/// The type group offered to the platform file chooser.
const fs.XTypeGroup kAudioTypeGroup = fs.XTypeGroup(
  label: IS.audioFiles,
  extensions: [
    'wav', 'wave', 'mp3', 'aac', 'm4a', 'mp4', 'm4b', 'mov', '3gp', '3gpp',
    '3g2', 'amr', 'awb', 'ogg', 'oga', 'opus', 'flac', 'caf', 'aif', 'aiff',
    'aifc', 'webm', 'weba', 'mka', 'wma',
  ],
  mimeTypes: kImportMimeTypes,
  uniformTypeIdentifiers: kImportUtis,
);

Future<bool> _isInAppCache(String path) async {
  Future<String?> dir(Future<Directory> Function() f) async {
    try {
      return (await f()).path;
    } catch (_) {
      return null;
    }
  }

  for (final d in [
    await dir(getTemporaryDirectory),
    await dir(getApplicationCacheDirectory),
  ]) {
    if (d != null && d.isNotEmpty && path.startsWith(d)) return true;
  }
  return false;
}

Future<PickedAudio?> _pickWithFileSelector() async {
  final f = await fs.openFile(acceptedTypeGroups: const [kAudioTypeGroup]);
  if (f == null) return null;
  final mobile = Platform.isAndroid || Platform.isIOS;
  return PickedAudio(
    path: f.path,
    name: f.name,
    temporaryCopy: mobile && await _isInAppCache(f.path),
  );
}

/// The file chooser (overridable in tests).
final audioFilePickerProvider = Provider<AudioFilePicker>(
  (ref) => _pickWithFileSelector,
);

// ===========================================================================
// Flows
// ===========================================================================

/// «استيراد تسجيل»: choose a file, confirm, import in the background.
Future<void> importRecordingFlow(BuildContext context, WidgetRef ref) async {
  final busy = ref.read(importJobProvider.notifier).busyReason();
  if (busy != null) {
    showSnack(context, busy, error: true);
    return;
  }
  PickedAudio? picked;
  try {
    picked = await ref.read(audioFilePickerProvider)();
  } catch (_) {
    if (context.mounted) showSnack(context, IS.unreadable, error: true);
    return;
  }
  if (picked == null || !context.mounted) return;
  await confirmAndStartImport(
    context,
    ref,
    path: picked.path,
    name: picked.name,
    deleteSourceWhenDone: picked.temporaryCopy,
  );
}

Future<void> _deleteQuietly(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {
    // A cache copy; the OS cleans it eventually.
  }
}

/// Asks for confirmation (title, legal reminder) and starts the import of
/// [path]. Returns true when the import started.
Future<bool> confirmAndStartImport(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  required String name,
  bool viaShare = false,
  bool deleteSourceWhenDone = false,
}) async {
  final jobs = ref.read(importJobProvider.notifier);
  final busy = jobs.busyReason();
  if (busy != null) {
    showSnack(context, busy, error: true);
    if (deleteSourceWhenDone) await _deleteQuietly(path);
    return false;
  }
  DateTime? modified;
  try {
    modified = await File(path).lastModified();
  } catch (_) {
    modified = null;
  }
  final suggested = suggestImportTitle(
    name,
    resolveRecordingTime(
      fileName: name,
      // A share / picker copy carries the copy's time, not the call's.
      modified: deleteSourceWhenDone ? null : modified,
    ),
  );
  if (!context.mounted) return false;
  final title = await showImportConfirmDialog(
    context,
    fileName: name,
    suggestedTitle: suggested,
  );
  if (title == null) {
    if (deleteSourceWhenDone) await _deleteQuietly(path);
    return false;
  }
  unawaited(
    jobs.start(
      ImportRequest(
        path: path,
        displayName: name,
        // An untouched suggestion is recomputed with the container date.
        title: title.trim() == suggested ? null : title,
        viaShare: viaShare,
        deleteSourceWhenDone: deleteSourceWhenDone,
      ),
    ),
  );
  return true;
}

/// The confirmation dialog: editable title, source file, legal reminder
/// with a required checkbox. Returns the title, or null when cancelled.
Future<String?> showImportConfirmDialog(
  BuildContext context, {
  required String fileName,
  required String suggestedTitle,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _ImportConfirmDialog(fileName: fileName, suggestedTitle: suggestedTitle),
);

class _ImportConfirmDialog extends StatefulWidget {
  const _ImportConfirmDialog({
    required this.fileName,
    required this.suggestedTitle,
  });

  final String fileName;
  final String suggestedTitle;

  @override
  State<_ImportConfirmDialog> createState() => _ImportConfirmDialogState();
}

class _ImportConfirmDialogState extends State<_ImportConfirmDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.suggestedTitle,
  );
  bool _confirmed = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.upload_file_rounded),
      title: const Text(IS.confirmTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(IS.confirmBody),
          const SizedBox(height: 12),
          Text(
            IS.sourceFile(widget.fileName),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('import-title'),
            controller: _title,
            decoration: const InputDecoration(
              labelText: IS.titleLabel,
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gavel_rounded, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    IS.legalNotice,
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
          CheckboxListTile(
            key: const ValueKey('import-legal'),
            value: _confirmed,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(IS.legalCheckbox),
            onChanged: (v) => setState(() => _confirmed = v ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(IS.cancel),
        ),
        FilledButton(
          onPressed: _confirmed
              ? () {
                  final t = _title.text.trim();
                  Navigator.of(
                    context,
                  ).pop(t.isEmpty ? widget.suggestedTitle : t);
                }
              : null,
          child: const Text(IS.startImport),
        ),
      ],
    );
  }
}

// ===========================================================================
// Widgets
// ===========================================================================

/// App-bar action «استيراد تسجيل».
class ImportRecordingButton extends ConsumerWidget {
  /// Creates the button.
  const ImportRecordingButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: IS.importTooltip,
    icon: const Icon(Icons.upload_file_rounded),
    onPressed: () => importRecordingFlow(context, ref),
  );
}

/// Small «مستورد» badge of imported meetings.
class ImportedBadge extends StatelessWidget {
  /// Creates the badge.
  const ImportedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: IS.importedBadgeSemantics,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_file_rounded,
              size: 14,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              IS.importedBadge,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress / result of the import job, shown above the meetings list.
/// [onOpen] opens a meeting.
class ImportProgressCard extends ConsumerWidget {
  /// Creates the card.
  const ImportProgressCard({
    super.key,
    required this.onOpen,
    this.padding = EdgeInsets.zero,
  });

  /// Opens a meeting.
  final ValueChanged<String> onOpen;

  /// Outer padding (only when shown).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(importJobProvider);
    if (s.phase == ImportPhase.idle) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final jobs = ref.read(importJobProvider.notifier);
    final failed = s.phase == ImportPhase.failed;
    final (IconData icon, Color color) = switch (s.phase) {
      ImportPhase.running => (Icons.upload_file_rounded, scheme.primary),
      ImportPhase.succeeded => (Icons.check_circle_rounded, scheme.primary),
      ImportPhase.failed => (Icons.error_rounded, scheme.error),
      _ => (Icons.info_outline_rounded, scheme.onSurfaceVariant),
    };
    final id = s.meetingId;
    return Padding(
      padding: padding,
      child: Card(
        key: const ValueKey('import-progress-card'),
        color: failed ? scheme.errorContainer : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      failed ? IS.failedTitle : IS.progressTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              if (s.fileName case final name?) ...[
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (s.isRunning) ...[
                LinearProgressIndicator(
                  value: s.progress <= 0 ? null : s.progress,
                  semanticsLabel: s.statusAr,
                ),
                const SizedBox(height: 6),
                Text(s.statusAr ?? '', style: theme.textTheme.bodyMedium),
              ] else ...[
                Text(
                  s.errorAr ?? s.noticeAr ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: failed ? scheme.onErrorContainer : null,
                  ),
                ),
                if (s.phase == ImportPhase.succeeded) ...[
                  const SizedBox(height: 4),
                  Text(
                    IS.minutesFollow,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  if (s.isRunning)
                    TextButton.icon(
                      onPressed: s.cancelling ? null : jobs.cancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text(IS.cancelImport),
                    ),
                  if (!s.isRunning && s.needsModels)
                    TextButton(
                      onPressed: () => openModelsScreen(context),
                      child: const Text(IS.openModels),
                    ),
                  if (!s.isRunning && id != null)
                    TextButton(
                      onPressed: () {
                        jobs.dismiss();
                        onOpen(id);
                      },
                      child: const Text(IS.openMeeting),
                    ),
                  if (!s.isRunning)
                    TextButton(
                      onPressed: jobs.dismiss,
                      child: const Text(IS.dismiss),
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

/// Offers the audio files other apps share to Insato (Android share /
/// "open with", iOS "Open in"): the first file is imported after the usual
/// confirmation. Wraps the app shell.
class SharedAudioListener extends ConsumerStatefulWidget {
  /// Creates the listener.
  const SharedAudioListener({super.key, required this.child, this.onImport});

  /// The shell.
  final Widget child;

  /// Called after an import started (e.g. to show the meetings tab).
  final VoidCallback? onImport;

  @override
  ConsumerState<SharedAudioListener> createState() =>
      _SharedAudioListenerState();
}

class _SharedAudioListenerState extends ConsumerState<SharedAudioListener>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _sub;
  bool _draining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final inbox = ref.read(sharedAudioInboxProvider);
    if (inbox != null) {
      _sub = inbox.arrivals.listen((_) => _drain());
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drain();
  }

  Future<void> _drain() async {
    final inbox = ref.read(sharedAudioInboxProvider);
    if (inbox == null || _draining || !mounted) return;
    _draining = true;
    try {
      final files = await inbox.takePending();
      if (files.isEmpty || !mounted) return;
      final usable = files.where((f) => f.path != null).toList();
      for (final extra in usable.skip(1)) {
        await _deleteQuietly(extra.path!);
      }
      if (!mounted) return;
      if (usable.isEmpty) {
        final tooLarge = files.any((f) => f.error == 'too_large');
        showSnack(
          context,
          tooLarge ? IS.sharedTooLarge : IS.sharedReceiveFailed,
          error: true,
        );
        return;
      }
      if (files.length > 1) showSnack(context, IS.onlyFirstShared);
      final first = usable.first;
      final started = await confirmAndStartImport(
        context,
        ref,
        path: first.path!,
        name: first.name,
        viaShare: true,
        deleteSourceWhenDone: true,
      );
      if (started) widget.onImport?.call();
    } finally {
      _draining = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
