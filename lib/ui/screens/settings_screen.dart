// Settings: minutes engine (Gemini free tier by default with its privacy
// notice, key and model; Claude key and model; local engines when
// available) and minutes detail, transcription engine (on-device Whisper or Deepgram with key),
// Whisper model, language hint, keep-audio, custom vocabulary (F2),
// microphone (F18: device, far field, test) and audio source (F13, Windows
// only), speaker matching sensitivity, models, privacy and about.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../data/secure_settings.dart';
import '../../features/context/glossary_screen.dart' show GlossaryScreen;
import '../../features/context/strings.dart' show CS;
import '../../features/local_llm/local_minutes_backends.dart';
import '../../features/official/entity_settings_screen.dart'
    show EntitySettingsTile;
import '../../features/system_audio/audio_source_selector.dart'
    show AudioSourceSelector;
import '../../features/voice/mic_settings.dart' show MicSettingsSection;
import '../../minutes/claude_client.dart';
import '../../minutes/gemini_client.dart';
import '../../speech/model_catalog.dart';
import '../format.dart';
import '../navigation.dart';
import '../services/connection_tester.dart';
import '../strings_ar.dart';
import '../ui_providers.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// App version shown in "about" (keep in sync with pubspec.yaml).
const String kAppVersion = '1.1.0-beta.2';

/// Minimum of the speaker-matching sensitivity slider.
const double kMinMatchThreshold = 0.45;

/// Maximum of the speaker-matching sensitivity slider.
const double kMaxMatchThreshold = 0.75;

/// The settings screen.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  /// Runs [write], showing the Arabic error on failure. Returns whether the
  /// write succeeded, so callers only confirm a save that really happened.
  Future<bool> _save(
    BuildContext context,
    Future<void> Function() write,
  ) async {
    try {
      await write();
      return true;
    } catch (e) {
      if (context.mounted) {
        showSnack(
          context,
          e is InsatoException ? e.messageAr : S.unexpectedError,
          error: true,
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appSettingsDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.navSettings)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: S.unexpectedError,
            onRetry: () => ref.invalidate(appSettingsDataProvider),
          ),
        ),
        data: (s) => _buildList(context, ref, s),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, AppSettingsData s) {
    final store = ref.read(appSettingsProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -------------------------------------------- Minutes engine
              const SectionHeader(S.sectionClaude, icon: Icons.auto_awesome),
              MinutesEngineSettings(settings: s, save: _save),
              const SizedBox(height: 16),
              Text(S.minutesDetail, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: AppSettingsData.detailDetailed,
                    label: Text(S.detailDetailed),
                    icon: Icon(Icons.article_outlined),
                  ),
                  ButtonSegment(
                    value: AppSettingsData.detailConcise,
                    label: Text(S.detailConcise),
                    icon: Icon(Icons.short_text_rounded),
                  ),
                ],
                selected: {s.minutesDetail},
                onSelectionChanged: (v) =>
                    _save(context, () => store.setMinutesDetail(v.first)),
              ),
              const SizedBox(height: 4),
              Text(S.minutesDetailHelper, style: muted),

              // ------------------------------------------------------- ASR
              const SectionHeader(S.sectionAsr, icon: Icons.graphic_eq_rounded),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: AppSettingsData.asrLocal,
                    label: Text(S.asrLocal),
                    icon: Icon(Icons.phone_android_rounded),
                  ),
                  ButtonSegment(
                    value: AppSettingsData.asrCloud,
                    label: Text(S.asrCloud),
                    icon: Icon(Icons.cloud_outlined),
                  ),
                ],
                selected: {s.asrEngine},
                onSelectionChanged: (v) =>
                    _save(context, () => store.setAsrEngine(v.first)),
              ),
              const SizedBox(height: 4),
              Text(
                s.usesLocalAsr ? S.asrLocalHelper : S.asrCloudHelper,
                style: muted,
              ),
              const SizedBox(height: 12),
              if (!s.usesLocalAsr)
                ApiKeyCard(
                  label: S.deepgramKey,
                  load: () =>
                      ref.read(secureSettingsProvider).getDeepgramApiKey(),
                  save: (k) =>
                      ref.read(secureSettingsProvider).setDeepgramApiKey(k),
                  clear: () =>
                      ref.read(secureSettingsProvider).clearDeepgramApiKey(),
                  onChanged: () =>
                      ref.invalidate(deepgramKeyConfiguredProvider),
                )
              else
                _WhisperChoice(
                  selected: s.whisperModelId,
                  onSelect: (id) =>
                      _save(context, () => store.setWhisperModelId(id)),
                ),
              const SizedBox(height: 4),
              _LanguageTile(
                hint: s.languageHint,
                onSelect: (code) =>
                    _save(context, () => store.setLanguageHint(code)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.keepAudio,
                onChanged: (v) => _save(context, () => store.setKeepAudio(v)),
                title: const Text(S.keepAudio),
                subtitle: const Text(S.keepAudioHelper),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: const Text(CS.glossaryTitle),
                  subtitle: const Text(CS.glossarySubtitle),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GlossaryScreen(),
                    ),
                  ),
                ),
              ),

              const EntitySettingsTile(),

              // ------------------------------------- Microphone & source
              const MicSettingsSection(),
              const AudioSourceSelector(),

              // -------------------------------------------------- Speakers
              const SectionHeader(
                S.sectionSpeakers,
                icon: Icons.record_voice_over_rounded,
              ),
              ThresholdSlider(
                value: s.matchThreshold,
                onChanged: (v) =>
                    _save(context, () => store.setMatchThreshold(v)),
              ),

              // ---------------------------------------------------- Models
              const SectionHeader(S.sectionModels, icon: Icons.memory_rounded),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: const Text(S.manageModels),
                  subtitle: const Text(S.manageModelsSubtitle),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => openModelsScreen(context),
                ),
              ),

              // --------------------------------------------------- Privacy
              const SectionHeader(
                S.sectionPrivacy,
                icon: Icons.shield_outlined,
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(S.privacyBody, style: theme.textTheme.bodyMedium),
                ),
              ),

              // ----------------------------------------------------- About
              const SectionHeader(S.sectionAbout, icon: Icons.info_outline),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_note_rounded),
                      title: const Text(S.appName),
                      subtitle: const Text(S.aboutBody),
                      trailing: LtrText(kAppVersion, style: muted),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.gavel_rounded),
                      title: const Text(S.licenses),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: S.appName,
                        applicationVersion: kAppVersion,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restart_alt_rounded),
                      title: const Text(S.resetSettings),
                      onTap: () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: S.resetSettings,
                          body: S.resetSettingsBody,
                          confirmLabel: S.confirm,
                        );
                        if (!ok || !context.mounted) return;
                        // SecureSettings.resetToDefaults clears only the
                        // preference keys; API keys, meetings and the
                        // per-meeting voiceprint ledgers kept in the same
                        // table are not affected.
                        final done = await _save(
                          context,
                          store.resetToDefaults,
                        );
                        if (done && context.mounted) {
                          showSnack(context, S.settingsReset);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Obscured API key editor with save / clear and an optional connection
/// test. The stored key is never displayed back in full.
class ApiKeyCard extends StatefulWidget {
  /// Creates the card.
  const ApiKeyCard({
    super.key,
    required this.label,
    required this.load,
    required this.save,
    required this.clear,
    this.helper,
    this.test,
    this.onChanged,
  });

  /// Field label.
  final String label;

  /// Helper text.
  final String? helper;

  /// Reads the stored key.
  final Future<String?> Function() load;

  /// Stores a key.
  final Future<void> Function(String key) save;

  /// Clears the key.
  final Future<void> Function() clear;

  /// Tests a key (null hides the button).
  final Future<ConnectionTestResult> Function(String key)? test;

  /// Called after the stored key changed.
  final VoidCallback? onChanged;

  @override
  State<ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<ApiKeyCard> {
  final TextEditingController _c = TextEditingController();
  bool _obscure = true;
  bool _configured = false;

  /// The stored key could not be read (e.g. a locked device): its state is
  /// unknown, so neither "configured" nor "not configured" is shown.
  bool _unreadable = false;
  bool _busy = false;
  ConnectionTestResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    String? k;
    var unreadable = false;
    try {
      k = await widget.load();
    } catch (_) {
      // SecureStorageUnavailableException (or another keystore failure):
      // the key may exist, so do not report it as missing.
      unreadable = true;
    }
    if (!mounted) return;
    setState(() {
      _unreadable = unreadable;
      if (!unreadable) _configured = k != null && k.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final k = _c.text.trim();
    if (k.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.save(k);
      widget.onChanged?.call();
      _c.clear();
      await _refresh();
      if (mounted) showSnack(context, S.keySaved);
    } catch (_) {
      if (mounted) showSnack(context, S.unexpectedError, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    try {
      await widget.clear();
      widget.onChanged?.call();
      await _refresh();
      if (mounted) showSnack(context, S.keyCleared);
    } catch (_) {
      if (mounted) showSnack(context, S.unexpectedError, error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _result = null;
        });
      }
    }
  }

  Future<void> _test() async {
    final test = widget.test;
    if (test == null) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    ConnectionTestResult? r;
    try {
      var key = _c.text.trim();
      if (key.isEmpty) key = (await widget.load()) ?? '';
      r = await test(key);
      if (!mounted) return;
      // A key that just passed the test is worth keeping.
      if (r.ok && _c.text.trim().isNotEmpty) {
        await widget.save(_c.text.trim());
        widget.onChanged?.call();
        _c.clear();
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          e is InsatoException ? e.messageAr : S.unexpectedError,
          error: true,
        );
      }
    } finally {
      // Always re-enable the card; the test result stays visible even when
      // saving the key afterwards failed.
      if (mounted) {
        setState(() {
          _busy = false;
          _result = r;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = _result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _unreadable
                      ? Icons.lock_clock_rounded
                      : _configured
                      ? Icons.verified_rounded
                      : Icons.key_off_rounded,
                  color: _configured && !_unreadable
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _unreadable
                        ? S.keyUnreadable
                        : _configured
                        ? S.keyConfigured
                        : S.keyNotConfigured,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                if (_configured && !_unreadable)
                  TextButton(
                    onPressed: _busy ? null : _clear,
                    child: const Text(S.clearKey),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _c,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.visiblePassword,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: widget.label,
                helperText: widget.helper,
                helperMaxLines: 3,
                hintText: _configured ? '••••••••••••' : null,
                hintTextDirection: TextDirection.ltr,
                suffixIcon: IconButton(
                  tooltip: _obscure ? S.showKey : S.hideKey,
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (widget.test != null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _test,
                    icon: const Icon(Icons.wifi_tethering_rounded),
                    label: const Text(S.testConnection),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text(S.save),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (r != null) ...[
              const SizedBox(height: 10),
              ErrorBanner(
                severity: r.ok ? BannerSeverity.info : BannerSeverity.error,
                message: r.ok
                    ? S.connectionOk(ltrIsolate(r.model ?? '—'))
                    : r.messageAr,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Text field for a model id (Claude, Gemini).
class ModelIdField extends StatefulWidget {
  /// Creates the field.
  const ModelIdField({
    super.key,
    required this.value,
    required this.onSave,
    required this.label,
    required this.helper,
    required this.defaultModel,
  });

  /// Current model id.
  final String value;

  /// Persists a model id; completes with false when the save failed (the
  /// callee has already reported the error).
  final Future<bool> Function(String model) onSave;

  /// Field label.
  final String label;

  /// Helper text.
  final String helper;

  /// Saved when the field is left blank.
  final String defaultModel;

  @override
  State<ModelIdField> createState() => _ModelIdFieldState();
}

/// Text field for the Claude model id.
class ClaudeModelField extends ModelIdField {
  /// Creates the field.
  const ClaudeModelField({
    super.key,
    required super.value,
    required super.onSave,
  }) : super(
         label: S.claudeModel,
         helper: S.claudeModelHelper,
         defaultModel: kDefaultClaudeModel,
       );
}

class _ModelIdFieldState extends State<ModelIdField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(ModelIdField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _c.text != widget.value) {
      _c.text = widget.value;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final v = _c.text.trim().isEmpty ? widget.defaultModel : _c.text.trim();
    _c.text = v;
    final ok = await widget.onSave(v);
    if (!mounted) return;
    if (ok) {
      showSnack(context, S.modelSaved);
    } else {
      // Show the model that is really in use again.
      _c.text = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      textDirection: TextDirection.ltr,
      autocorrect: false,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        suffixIcon: IconButton(
          tooltip: S.save,
          icon: const Icon(Icons.check_rounded),
          onPressed: _submit,
        ),
      ),
    );
  }
}

/// The minutes-engine part of Settings: engine choice, then the selected
/// engine's configuration (Gemini: privacy notice, key, model; Claude: key,
/// model; local engines: their own settings).
class MinutesEngineSettings extends ConsumerWidget {
  /// Creates the section.
  const MinutesEngineSettings({
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
    final s = settings;
    final store = ref.read(appSettingsProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final local = ref.watch(localMinutesBackendBuilderProvider);
    final server = ref.watch(serverMinutesBackendBuilderProvider);
    final engines = <ButtonSegment<String>>[
      const ButtonSegment(
        value: AppSettingsData.engineGemini,
        label: Text(S.engineGemini),
        icon: Icon(Icons.cloud_outlined),
      ),
      const ButtonSegment(
        value: AppSettingsData.engineClaude,
        label: Text(S.engineClaude),
        icon: Icon(Icons.auto_awesome_outlined),
      ),
      if (local != null || s.minutesEngine == AppSettingsData.engineLocal)
        const ButtonSegment(
          value: AppSettingsData.engineLocal,
          label: Text(S.engineLocal),
          icon: Icon(Icons.phone_android_rounded),
        ),
      if (server != null || s.minutesEngine == AppSettingsData.engineServer)
        const ButtonSegment(
          value: AppSettingsData.engineServer,
          label: Text(S.engineServer),
          icon: Icon(Icons.dns_outlined),
        ),
    ];
    final selectedBuilder = switch (s.minutesEngine) {
      AppSettingsData.engineLocal => local,
      AppSettingsData.engineServer => server,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: S.minutesEngine,
          child: LayoutBuilder(
            builder: (context, c) {
              // Four segments with icons need ~140 px each; below that each
              // label would wrap to a glyph or two per line. Narrow screens
              // drop the icons and scroll sideways (like the audio-source
              // selector), so every label stays on one line.
              final narrow = c.maxWidth < 140.0 * engines.length;
              final button = SegmentedButton<String>(
                segments: narrow
                    ? [
                        for (final e in engines)
                          ButtonSegment<String>(
                            value: e.value,
                            label: e.label,
                            tooltip: e.tooltip,
                          ),
                      ]
                    : engines,
                selected: {s.minutesEngine},
                showSelectedIcon: !narrow,
                onSelectionChanged: (v) =>
                    save(context, () => store.setMinutesEngine(v.first)),
              );
              if (!narrow) return button;
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: button,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(S.minutesEngineHelper(s.minutesEngine), style: muted),
        const SizedBox(height: 12),
        if (s.minutesEngine == AppSettingsData.engineGemini) ...[
          GeminiPrivacyCard(
            acknowledged: s.geminiPrivacyAcknowledged,
            onChanged: (v) =>
                save(context, () => store.setGeminiPrivacyAcknowledged(v)),
          ),
          const SizedBox(height: 12),
          ApiKeyCard(
            key: const ValueKey('gemini-key'),
            label: S.geminiKey,
            helper: S.geminiKeyHelper,
            load: () => ref.read(secureSettingsProvider).getGeminiApiKey(),
            save: (k) async {
              await ref.read(secureSettingsProvider).setGeminiApiKey(k);
              GeminiRateGate.shared.clear();
            },
            clear: () => ref.read(secureSettingsProvider).clearGeminiApiKey(),
            onChanged: () => ref.invalidate(geminiKeyConfiguredProvider),
            test: (k) async {
              final r = await ref
                  .read(geminiConnectionTesterProvider)
                  .test(k, model: s.geminiModel);
              final suggested = r.model;
              if (r.ok && suggested != null && suggested != s.geminiModel) {
                await store.setGeminiModel(suggested);
              }
              return r;
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(S.geminiKeyWhere, style: muted),
              const SelectableText(
                kGeminiApiKeyUrl,
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ModelIdField(
            value: s.geminiModel,
            label: S.geminiModel,
            helper: S.geminiModelHelper,
            defaultModel: kDefaultGeminiModel,
            onSave: (m) => save(context, () => store.setGeminiModel(m)),
          ),
        ] else if (s.minutesEngine == AppSettingsData.engineClaude) ...[
          ApiKeyCard(
            key: const ValueKey('anthropic-key'),
            label: S.anthropicKey,
            helper: S.anthropicKeyHelper,
            load: () => ref.read(secureSettingsProvider).getAnthropicApiKey(),
            save: (k) => ref.read(secureSettingsProvider).setAnthropicApiKey(k),
            clear: () =>
                ref.read(secureSettingsProvider).clearAnthropicApiKey(),
            onChanged: () => ref.invalidate(anthropicKeyConfiguredProvider),
            test: (k) => ref
                .read(claudeConnectionTesterProvider)
                .test(k, model: s.claudeModel),
          ),
          const SizedBox(height: 12),
          ClaudeModelField(
            value: s.claudeModel,
            onSave: (m) => save(context, () => store.setClaudeModel(m)),
          ),
        ] else if (selectedBuilder?.settings != null)
          selectedBuilder!.settings!(context)
        else
          const ErrorBanner(
            severity: BannerSeverity.warning,
            message: S.engineUnavailable,
          ),
      ],
    );
  }
}

/// The Gemini free-tier data notice, accepted before anything is sent.
class GeminiPrivacyCard extends StatelessWidget {
  /// Creates the card.
  const GeminiPrivacyCard({
    super.key,
    required this.acknowledged,
    required this.onChanged,
  });

  /// Whether the notice was accepted.
  final bool acknowledged;

  /// Records acceptance / withdrawal.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: acknowledged ? null : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.geminiPrivacyTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(S.geminiPrivacyBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (acknowledged)
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text(S.geminiPrivacyAccepted)),
                  TextButton(
                    onPressed: () => onChanged(false),
                    child: const Text(S.geminiPrivacyWithdraw),
                  ),
                ],
              )
            else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: () => onChanged(true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(S.geminiPrivacyAccept),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhisperChoice extends StatelessWidget {
  const _WhisperChoice({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.whisperModel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final m in ModelCatalog.ofKind(ModelKind.asr))
          Semantics(
            selected: m.id == selected,
            inMutuallyExclusiveGroup: true,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                m.id == selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: m.id == selected ? scheme.primary : null,
              ),
              title: Text(m.displayNameAr),
              subtitle: Text(
                '${m.descriptionAr}\n${S.approxSize(m.approxSizeMb)}',
              ),
              isThreeLine: true,
              onTap: () => onSelect(m.id),
            ),
          ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.hint, required this.onSelect});

  final String? hint;
  final ValueChanged<String?> onSelect;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text(S.languageHint),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('auto'),
            child: _option(context, S.languageAuto, hint == null),
          ),
          for (final code in S.commonLanguageCodes)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(code),
              child: _option(context, S.languageName(code)!, hint == code),
            ),
        ],
      ),
    );
    if (picked == null) return;
    onSelect(picked == 'auto' ? null : picked);
  }

  Widget _option(BuildContext context, String label, bool selected) => Row(
    children: [
      Icon(
        selected ? Icons.check_rounded : null,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final name = hint == null
        ? S.languageAuto
        : (S.languageName(hint) ?? hint!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.translate_rounded),
      title: const Text(S.languageHint),
      subtitle: Text('$name\n${S.languageHintHelper}'),
      isThreeLine: true,
      onTap: () => _pick(context),
    );
  }
}

/// Speaker-matching sensitivity slider (0.45 … 0.75) saved on release.
class ThresholdSlider extends StatefulWidget {
  /// Creates the slider.
  const ThresholdSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Stored threshold.
  final double value;

  /// Persists a new threshold.
  final ValueChanged<double> onChanged;

  @override
  State<ThresholdSlider> createState() => _ThresholdSliderState();
}

class _ThresholdSliderState extends State<ThresholdSlider> {
  double? _dragging;

  @override
  void didUpdateWidget(ThresholdSlider old) {
    super.didUpdateWidget(old);
    // The stored value caught up with the drag.
    if (old.value != widget.value) _dragging = null;
  }

  double get _value =>
      (_dragging ?? widget.value).clamp(kMinMatchThreshold, kMaxMatchThreshold);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _value.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.matchSensitivity,
                style: theme.textTheme.titleSmall,
              ),
            ),
            LtrText(label, style: theme.textTheme.titleSmall),
          ],
        ),
        Slider(
          value: _value,
          min: kMinMatchThreshold,
          max: kMaxMatchThreshold,
          divisions: 30,
          label: label,
          semanticFormatterCallback: (v) => v.toStringAsFixed(2),
          onChanged: (v) => setState(() => _dragging = v),
          onChangeEnd: (v) {
            final rounded = double.parse(v.toStringAsFixed(2));
            if (rounded == widget.value) {
              setState(() => _dragging = null);
            } else {
              widget.onChanged(rounded);
            }
          },
        ),
        Row(
          children: [
            Text(S.lenient, style: theme.textTheme.labelSmall),
            const Spacer(),
            Text(S.strict, style: theme.textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          S.matchSensitivityHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
