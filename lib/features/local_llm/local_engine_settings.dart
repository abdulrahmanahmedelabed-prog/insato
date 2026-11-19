// Settings of the on-device minutes engine (F14): the GGUF model choice
// (`localLlmModelId`), download / cancel / delete with progress, sizes and
// RAM requirements, and the honest quality / speed trade-off. Rendered by
// Settings under the engine choice (`LocalMinutesBackendBuilder.settings`).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/interfaces.dart' show ModelState, ModelStatus;
import '../../data/secure_settings.dart';
import '../../speech/model_manager.dart'
    show ModelDownloadCancelledException;
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import 'llm_catalog.dart';
import 'local_llm_providers.dart';
import 'strings.dart';

/// On-device engine settings: model list with download management.
class LocalEngineSettings extends ConsumerWidget {
  /// Creates the section.
  const LocalEngineSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsDataProvider).value ??
        AppSettingsData.defaults;
    final desktop = ref.watch(localLlmIsDesktopProvider);
    final states = ref.watch(localLlmModelStatesProvider);
    final chosen = LocalLlmCatalog.resolve(s.localLlmModelId, desktop: desktop);
    final models = LocalLlmCatalog.forDevice(desktop: desktop);
    if (!models.contains(chosen)) models.insert(0, chosen);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final stateMap = states.value ?? const <String, ModelState>{};
    final chosenState = stateMap[chosen.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(LS.localIntro, style: muted),
        const SizedBox(height: 4),
        Text(LS.downloadAdvice, style: muted),
        const SizedBox(height: 12),
        Text(LS.modelsHeader, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (states.hasError)
          Text(
            LS.modelsLoadFailed,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        for (final m in models)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LocalModelCard(
              model: m,
              selected: m.id == chosen.id,
              state:
                  stateMap[m.id] ?? const ModelState(ModelStatus.notDownloaded),
              loading: states.isLoading && !states.hasValue,
            ),
          ),
        if (states.hasValue && chosenState?.status != ModelStatus.ready) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LS.selectedNotDownloaded,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(LS.ramNote, style: muted),
      ],
    );
  }
}

/// One catalog model: selection, size / RAM, status and actions.
class LocalModelCard extends ConsumerWidget {
  /// Creates the card.
  const LocalModelCard({
    super.key,
    required this.model,
    required this.selected,
    required this.state,
    this.loading = false,
  });

  /// The model.
  final LocalLlmModel model;

  /// True when it is the model in use.
  final bool selected;

  /// Download state.
  final ModelState state;

  /// True while the states are not known yet.
  final bool loading;

  Future<void> _select(BuildContext context, WidgetRef ref) async {
    if (selected) return;
    try {
      await ref.read(appSettingsProvider).setLocalLlmModelId(model.id);
      if (context.mounted) {
        showSnack(context, LS.modelChosen(model.displayNameAr));
      }
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }

  void _error(BuildContext context, Object e) => showSnack(
    context,
    e is InsatoException ? e.messageAr : S.unexpectedError,
    error: true,
  );

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    try {
      final manager = await ref.read(localLlmModelManagerProvider.future);
      // The card follows the progress through the states stream; errors are
      // also stored in the state and shown on the card.
      unawaited(
        manager.download(model.id).catchError((Object e) {
          if (e is ModelDownloadCancelledException || messenger == null) {
            return;
          }
          showSnackOn(
            messenger,
            scheme,
            e is InsatoException ? e.messageAr : S.unexpectedError,
            error: true,
          );
        }),
      );
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    try {
      final manager = await ref.read(localLlmModelManagerProvider.future);
      manager.cancel(model.id);
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: LS.deleteTitle,
      body: LS.deleteBody(model.displayNameAr, model.sizeGbText),
      confirmLabel: S.delete,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    try {
      final manager = await ref.read(localLlmModelManagerProvider.future);
      await manager.delete(model.id);
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final percent = (state.progress * 100).clamp(0, 100).floor();
    final statusText = switch (state.status) {
      ModelStatus.notDownloaded => LS.notDownloaded,
      ModelStatus.downloading => LS.downloading(percent),
      ModelStatus.ready => LS.downloaded,
      ModelStatus.failed => LS.failed(state.error),
    };
    final statusColor = switch (state.status) {
      ModelStatus.ready => scheme.primary,
      ModelStatus.failed => scheme.error,
      _ => scheme.onSurfaceVariant,
    };

    final Widget action = loading
        ? const SizedBox.shrink()
        : switch (state.status) {
            ModelStatus.notDownloaded || ModelStatus.failed =>
              FilledButton.tonalIcon(
                key: ValueKey('download-${model.id}'),
                onPressed: () => _download(context, ref),
                icon: const Icon(Icons.download_rounded),
                label: const Text(LS.download),
              ),
            ModelStatus.downloading => OutlinedButton.icon(
              key: ValueKey('cancel-${model.id}'),
              onPressed: () => _cancel(context, ref),
              icon: const Icon(Icons.close_rounded),
              label: const Text(LS.cancelDownload),
            ),
            ModelStatus.ready => TextButton.icon(
              key: ValueKey('delete-${model.id}'),
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text(LS.deleteModel),
            ),
          };

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            selected: selected,
            button: true,
            inMutuallyExclusiveGroup: true,
            child: InkWell(
              key: ValueKey('select-${model.id}'),
              onTap: () => _select(context, ref),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? scheme.primary : scheme.outline,
                        semanticLabel: selected ? LS.selected : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  model.displayNameAr,
                                  style: theme.textTheme.titleSmall,
                                ),
                                if (model.recommended)
                                  const _Badge(text: LS.recommended),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(model.descriptionAr, style: muted),
                            const SizedBox(height: 4),
                            Text(
                              LS.sizeAndRam(model.sizeGbText, model.minRamGb),
                              style: muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (state.status == ModelStatus.downloading)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(48, 4, 12, 0),
              child: LinearProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                semanticsLabel: statusText,
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(48, 4, 8, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Semantics(
                  liveRegion: state.status == ModelStatus.downloading,
                  child: Text(
                    loading ? '' : statusText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
