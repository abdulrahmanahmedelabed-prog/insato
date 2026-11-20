// Settings sections of the free Groq engines: minutes (privacy notice, key,
// model chosen from the key's live list or automatic) and cloud
// transcription with Groq Whisper (its own privacy notice for audio, the
// same key, model large-v3 / large-v3-turbo). Rendered by the Settings
// screen under the respective engine choice.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../data/secure_settings.dart';
import '../../ui/screens/settings_screen.dart' show ApiKeyCard, CloudPrivacyCard;
import '../../ui/services/connection_tester.dart';
import '../../ui/strings_ar.dart';
import '../../ui/ui_providers.dart';
import '../../ui/widgets/common.dart';
import 'groq_api.dart';
import 'groq_minutes_backend.dart' show listGroqModels;
import 'strings.dart';

/// The Groq key card (shared by the minutes and transcription sections).
class GroqKeyCard extends ConsumerWidget {
  /// Creates the card. [testModel] is the model reported by the test.
  const GroqKeyCard({super.key, this.testModel, this.onTested});

  /// Configured chat model (null = automatic).
  final String? testModel;

  /// Receives a successful test result.
  final void Function(ConnectionTestResult result)? onTested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApiKeyCard(
          label: GS.keyLabel,
          helper: GS.keyHelper,
          load: () => ref.read(secureSettingsProvider).getGroqApiKey(),
          save: (k) async {
            await ref.read(secureSettingsProvider).setGroqApiKey(k);
            GroqRateGate.shared.clear();
          },
          clear: () => ref.read(secureSettingsProvider).clearGroqApiKey(),
          onChanged: () => ref.invalidate(groqKeyConfiguredProvider),
          test: (k) async {
            final r = await ref
                .read(groqConnectionTesterProvider)
                .test(k, model: testModel);
            if (r.ok) onTested?.call(r);
            return r;
          },
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(GS.keyWhere, style: muted),
            const SelectableText(
              kGroqApiKeyUrl,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ],
    );
  }
}

/// Settings of the Groq minutes engine.
class GroqEngineSettings extends ConsumerWidget {
  /// Creates the section.
  const GroqEngineSettings({
    super.key,
    required this.settings,
    required this.save,
  });

  /// Current settings.
  final AppSettingsData settings;

  /// Runs a write, reporting errors (see `SettingsScreen._save`).
  final Future<bool> Function(BuildContext context, Future<void> Function())
  save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(appSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CloudPrivacyCard(
          title: GS.privacyTitle,
          body: GS.privacyBody,
          acknowledged: settings.groqPrivacyAcknowledged,
          onChanged: (v) =>
              save(context, () => store.setGroqPrivacyAcknowledged(v)),
        ),
        const SizedBox(height: 12),
        GroqKeyCard(
          key: const ValueKey('groq-key'),
          testModel: settings.groqModel,
        ),
        const SizedBox(height: 12),
        GroqModelPicker(
          value: settings.groqModel,
          onSave: (m) => save(context, () => store.setGroqModel(m)),
        ),
      ],
    );
  }
}

/// Chooses the Groq chat model: automatic (default) or one of the models
/// the key can use, listed live from Groq on demand.
class GroqModelPicker extends ConsumerStatefulWidget {
  /// Creates the picker.
  const GroqModelPicker({super.key, required this.value, required this.onSave});

  /// Configured model (null = automatic).
  final String? value;

  /// Persists a model (null = automatic).
  final Future<bool> Function(String? model) onSave;

  @override
  ConsumerState<GroqModelPicker> createState() => _GroqModelPickerState();
}

class _GroqModelPickerState extends ConsumerState<GroqModelPicker> {
  List<GroqModelInfo>? _models;
  bool _busy = false;
  String? _error;

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await ref.read(secureSettingsProvider).getGroqApiKey();
      if (key == null) {
        setState(() => _error = GS.keyMissing);
        return;
      }
      final all = await listGroqModels(apiKey: key);
      if (!mounted) return;
      setState(() => _models = rankGroqModels(all));
    } on InsatoException catch (e) {
      if (mounted) setState(() => _error = e.messageAr);
    } catch (_) {
      if (mounted) setState(() => _error = GS.testUnreachable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = _models;
    final current = widget.value;
    final auto = models == null || models.isEmpty
        ? GS.modelAuto
        : GS.modelAutoWith(models.first.id);
    final ids = <String>[
      for (final m in models ?? const <GroqModelInfo>[]) m.id,
      if (current != null && !(models?.any((m) => m.id == current) ?? false))
        current,
    ];
    String label(String id) {
      final ctx = models
          ?.where((m) => m.id == id)
          .map((m) => m.contextWindow)
          .firstOrNull;
      return ctx == null ? id : '$id · ${GS.contextLabel(ctx)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(GS.modelLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        DropdownButton<String>(
          isExpanded: true,
          value: current ?? '',
          items: [
            DropdownMenuItem(value: '', child: Text(auto)),
            for (final id in ids)
              DropdownMenuItem(
                value: id,
                child: Text(
                  label(id),
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _busy
              ? null
              : (v) async {
                  final ok = await widget.onSave(
                    v == null || v.isEmpty ? null : v,
                  );
                  if (ok && context.mounted) showSnack(context, S.modelSaved);
                },
        ),
        const SizedBox(height: 4),
        Text(
          GS.modelHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_busy ? GS.loadingModels : GS.refreshModels),
          ),
        ),
        if (_error != null)
          ErrorBanner(severity: BannerSeverity.warning, message: _error!),
      ],
    );
  }
}

/// Settings of cloud transcription with Groq Whisper.
class GroqAsrSettings extends ConsumerWidget {
  /// Creates the section.
  const GroqAsrSettings({super.key, required this.settings, required this.save});

  /// Current settings.
  final AppSettingsData settings;

  /// Runs a write, reporting errors.
  final Future<bool> Function(BuildContext context, Future<void> Function())
  save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(appSettingsProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CloudPrivacyCard(
          title: GS.asrPrivacyTitle,
          body: GS.asrPrivacyBody,
          acknowledged: settings.groqAsrPrivacyAcknowledged,
          onChanged: (v) =>
              save(context, () => store.setGroqAsrPrivacyAcknowledged(v)),
        ),
        const SizedBox(height: 12),
        const GroqKeyCard(key: ValueKey('groq-asr-key')),
        const SizedBox(height: 12),
        Text(GS.asrModelLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: AppSettingsData.groqWhisperLargeV3,
              label: Text(GS.asrModelLargeV3),
            ),
            ButtonSegment(
              value: AppSettingsData.groqWhisperLargeV3Turbo,
              label: Text(GS.asrModelTurbo),
            ),
          ],
          selected: {settings.groqAsrModel},
          onSelectionChanged: (v) =>
              save(context, () => store.setGroqAsrModel(v.first)),
        ),
        const SizedBox(height: 4),
        Text(
          GS.asrModelHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The switch of the automatic fallback between the free cloud engines.
class CloudFallbackTile extends ConsumerWidget {
  /// Creates the tile.
  const CloudFallbackTile({super.key, required this.settings, required this.save});

  /// Current settings.
  final AppSettingsData settings;

  /// Runs a write, reporting errors.
  final Future<bool> Function(BuildContext context, Future<void> Function())
  save;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    value: settings.cloudFallbackAuto,
    onChanged: (v) => save(
      context,
      () => ref.read(appSettingsProvider).setCloudFallbackAuto(v),
    ),
    title: const Text(GS.fallbackTitle),
    subtitle: const Text(GS.fallbackSubtitle),
  );
}
