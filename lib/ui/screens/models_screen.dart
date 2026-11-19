// On-device models: the ones the current settings need (VAD, speaker
// model, chosen Whisper) with sizes, download progress, cancel, delete and
// the recommendation; other models below. Also the first-run onboarding
// target when models are missing.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/interfaces.dart';
import '../../session/providers.dart';
import '../../speech/model_catalog.dart';
import '../../speech/model_manager.dart';
import '../format.dart';
import '../strings_ar.dart';
import '../ui_providers.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// The models screen.
class ModelsScreen extends ConsumerWidget {
  /// Creates the screen.
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statesAsync = ref.watch(modelStatesProvider);
    final settings = ref.watch(settingsSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.modelsTitle)),
      body: statesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: e is KatibException ? e.messageAr : S.modelsLoadFailed,
            onRetry: () => ref.invalidate(modelManagerProvider),
          ),
        ),
        data: (states) {
          final needed = neededModelIds(settings, states);
          final missing = missingModelIds(settings, states);
          final others = ModelCatalog.all
              .where((m) => !needed.contains(m.id))
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      S.modelsIntro,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ErrorBanner(
                      severity: BannerSeverity.info,
                      message: settings.usesLocalAsr
                          ? S.recommendationNote
                          : S.cloudModeNote,
                    ),
                    SectionHeader(
                      S.requiredModels,
                      icon: Icons.checklist_rounded,
                      trailing: missing.isEmpty
                          ? null
                          : FilledButton.icon(
                              onPressed: () =>
                                  _downloadAll(context, ref, missing, states),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text(S.downloadRequired),
                            ),
                    ),
                    for (final id in needed)
                      if (ModelCatalog.tryById(id) case final spec?)
                        ModelCard(
                          spec: spec,
                          state:
                              states[id] ??
                              const ModelState(ModelStatus.notDownloaded),
                          inUse: true,
                          selectedWhisper: settings.whisperModelId,
                        ),
                    const SectionHeader(
                      S.otherModels,
                      icon: Icons.inventory_2_outlined,
                    ),
                    for (final spec in others)
                      ModelCard(
                        spec: spec,
                        state:
                            states[spec.id] ??
                            const ModelState(ModelStatus.notDownloaded),
                        inUse: false,
                        selectedWhisper: settings.whisperModelId,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _downloadAll(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
    Map<String, ModelState> states,
  ) {
    for (final id in ids) {
      if (states[id]?.status == ModelStatus.downloading) continue;
      unawaited(downloadModel(context, ref, id));
    }
  }
}

/// Downloads [modelId], reporting failures (not cancellations) in a snack
/// bar.
Future<void> downloadModel(
  BuildContext context,
  WidgetRef ref,
  String modelId,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final manager = await ref.read(modelManagerProvider.future);
    await manager.download(modelId);
  } on ModelDownloadCancelledException {
    // The user cancelled.
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(e is KatibException ? e.messageAr : S.modelFailed),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

/// One model with its status and actions.
class ModelCard extends ConsumerWidget {
  /// Creates the card.
  const ModelCard({
    super.key,
    required this.spec,
    required this.state,
    required this.inUse,
    required this.selectedWhisper,
  });

  /// Model description.
  final ModelSpec spec;

  /// Current status.
  final ModelState state;

  /// True when the current settings use this model.
  final bool inUse;

  /// Whisper model chosen in the settings.
  final String selectedWhisper;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: S.deleteModel,
      body: S.deleteModelBody(spec.displayNameAr),
      confirmLabel: S.delete,
      destructive: true,
    );
    if (!ok) return;
    try {
      final manager = await ref.read(modelManagerProvider.future);
      await manager.delete(spec.id);
    } catch (e) {
      if (context.mounted) {
        showSnack(
          context,
          e is KatibException ? e.messageAr : S.unexpectedError,
          error: true,
        );
      }
    }
  }

  Future<void> _cancel(WidgetRef ref) async {
    final manager = await ref.read(modelManagerProvider.future);
    manager.cancel(spec.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = state.status;
    final isWhisper = spec.kind == ModelKind.asr;
    final percent = (state.progress.clamp(0.0, 1.0) * 100).round();

    final Widget statusLine = switch (status) {
      ModelStatus.ready => _Badge(
        icon: Icons.check_circle_rounded,
        text: S.modelReady,
        color: scheme.primary,
      ),
      ModelStatus.downloading => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: state.progress >= 1 || state.progress <= 0
                ? null
                : state.progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 4),
          Text(
            state.progress >= 1 ? S.finishingInstall : S.downloading(percent),
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
      ModelStatus.failed => Text(
        state.error ?? S.modelFailed,
        style: theme.textTheme.labelMedium?.copyWith(color: scheme.error),
      ),
      ModelStatus.notDownloaded => _Badge(
        icon: Icons.cloud_download_outlined,
        text: S.modelNotDownloaded,
        color: scheme.onSurfaceVariant,
      ),
    };

    final actions = <Widget>[
      if (isWhisper &&
          status == ModelStatus.ready &&
          spec.id != selectedWhisper)
        TextButton(
          onPressed: () =>
              ref.read(appSettingsProvider).setWhisperModelId(spec.id),
          child: const Text(S.useThisModel),
        ),
      if (status == ModelStatus.ready)
        TextButton.icon(
          onPressed: () => _delete(context, ref),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text(S.deleteModel),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
        ),
      if (status == ModelStatus.downloading)
        TextButton.icon(
          onPressed: () => _cancel(ref),
          icon: const Icon(Icons.close_rounded),
          label: const Text(S.cancelDownload),
        ),
      if (status == ModelStatus.notDownloaded || status == ModelStatus.failed)
        FilledButton.tonalIcon(
          onPressed: () => downloadModel(context, ref, spec.id),
          icon: Icon(
            status == ModelStatus.failed
                ? Icons.refresh_rounded
                : Icons.download_rounded,
          ),
          label: Text(status == ModelStatus.failed ? S.retry : S.download),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(switch (spec.kind) {
                    ModelKind.vad => Icons.hearing_rounded,
                    ModelKind.asr => Icons.subtitles_outlined,
                    ModelKind.speaker => Icons.fingerprint_rounded,
                  }, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spec.displayNameAr,
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Pill(S.approxSize(spec.approxSizeMb)),
                            if (spec.recommended) _Pill(S.recommended),
                            if (inUse) _Pill(S.inUse, highlight: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                spec.descriptionAr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              statusLine,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: highlight ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
