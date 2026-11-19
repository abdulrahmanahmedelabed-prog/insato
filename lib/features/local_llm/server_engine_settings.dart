// Settings of the local-server minutes engine (F14): server type (Ollama /
// LM Studio-OpenAI), URL, connection test with automatic type detection,
// model picker and an honest privacy line. Rendered by Settings under the
// engine choice (`LocalMinutesBackendBuilder.settings`).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../data/secure_settings.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import 'llm_server_client.dart';
import 'local_llm_providers.dart';
import 'strings.dart';

/// Server engine settings (URL, type, connection test, model).
class ServerEngineSettings extends ConsumerStatefulWidget {
  /// Creates the section.
  const ServerEngineSettings({super.key});

  @override
  ConsumerState<ServerEngineSettings> createState() =>
      _ServerEngineSettingsState();
}

class _ServerEngineSettingsState extends ConsumerState<ServerEngineSettings> {
  final TextEditingController _url = TextEditingController();
  String? _savedUrl;
  String? _urlError;
  bool _busy = false;
  List<String>? _models;
  String? _status;
  bool _statusIsError = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  AppSettingsData get _settings =>
      ref.read(appSettingsDataProvider).value ?? AppSettingsData.defaults;

  Future<bool> _write(Future<void> Function() write) async {
    try {
      await write();
      return true;
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          e is InsatoException ? e.messageAr : S.unexpectedError,
          error: true,
        );
      }
      return false;
    }
  }

  Future<void> _saveUrl(String raw) async {
    final n = AppSettingsData.normalizeServerUrl(raw);
    if (n == null) {
      setState(() => _urlError = LS.urlInvalid);
      return;
    }
    setState(() => _urlError = null);
    if (n == _settings.serverUrl) {
      _url.text = n;
      return;
    }
    final ok = await _write(
      () => ref.read(appSettingsProvider).setServerUrl(n),
    );
    if (!ok || !mounted) return;
    _url.text = n;
    setState(() {
      _models = null;
      _status = null;
    });
  }

  Future<void> _setFlavor(LlmServerFlavor flavor) async {
    final next = serverUrlForFlavor(_settings.serverUrl, flavor);
    _url.text = next;
    await _saveUrl(next);
  }

  /// Probes the server (detecting its type), saves the detected URL and
  /// lists the models.
  Future<void> _test() async {
    if (_busy) return;
    final typed = AppSettingsData.normalizeServerUrl(_url.text);
    if (typed == null) {
      setState(() => _urlError = LS.urlInvalid);
      return;
    }
    if (typed != _settings.serverUrl) await _saveUrl(typed);
    if (!mounted) return;
    setState(() {
      _busy = true;
      _status = LS.testing;
      _statusIsError = false;
    });
    final client = ref.read(llmServerClientFactoryProvider)(typed);
    try {
      final probe = await client.probe();
      var status = LS.connected(
        probe.flavor == LlmServerFlavor.ollama
            ? LS.flavorOllama
            : LS.flavorOpenAi,
        probe.models.length,
      );
      if (probe.url != typed) {
        final ok = await _write(
          () => ref.read(appSettingsProvider).setServerUrl(probe.url),
        );
        if (ok) {
          _url.text = probe.url;
          status = '$status\n${LS.flavorDetected(probe.url)}';
        }
      }
      if (probe.models.isEmpty) status = '$status\n${LS.noServerModels}';
      if (!mounted) return;
      setState(() {
        _models = probe.models;
        _status = status;
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e is InsatoException ? e.messageAr : S.unexpectedError;
        _statusIsError = true;
      });
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickModel(String? model) async {
    if (model == null || model == _settings.serverModel) return;
    final ok = await _write(
      () => ref.read(appSettingsProvider).setServerModel(model),
    );
    if (ok && mounted) showSnack(context, LS.serverModelChosen(model));
  }

  @override
  Widget build(BuildContext context) {
    final s =
        ref.watch(appSettingsDataProvider).value ?? AppSettingsData.defaults;
    if (_savedUrl != s.serverUrl) {
      // Follow the stored URL (first build, or changed elsewhere).
      _savedUrl = s.serverUrl;
      _url.text = s.serverUrl;
    }
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final flavor = serverFlavorOfUrl(s.serverUrl);
    final loopback = isLoopbackServerUrl(s.serverUrl);
    final models = <String>{...?_models, ?s.serverModel}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(LS.serverIntro, style: muted),
        const SizedBox(height: 8),
        _PrivacyLine(loopback: loopback),
        const SizedBox(height: 12),
        Semantics(
          label: LS.flavorLabel,
          child: SegmentedButton<LlmServerFlavor>(
            segments: const [
              ButtonSegment(
                value: LlmServerFlavor.ollama,
                label: Text(LS.flavorOllama),
              ),
              ButtonSegment(
                value: LlmServerFlavor.openAi,
                label: Text(LS.flavorOpenAi),
              ),
            ],
            selected: {flavor},
            onSelectionChanged: _busy ? null : (v) => _setFlavor(v.first),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('server-url'),
          controller: _url,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: _saveUrl,
          decoration: InputDecoration(
            labelText: LS.urlLabel,
            helperText: LS.urlHelper,
            helperMaxLines: 3,
            errorText: _urlError,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: LS.saveUrl,
              icon: const Icon(Icons.save_outlined),
              onPressed: () => _saveUrl(_url.text),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('server-test'),
              onPressed: _busy ? null : _test,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: const Text(LS.testConnection),
            ),
          ],
        ),
        if (_status != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _status!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _statusIsError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (models.isEmpty)
          Text(LS.serverModelNone, style: muted)
        else
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('server-model:${s.serverModel}'),
                  initialValue: s.serverModel,
                  isExpanded: true,
                  hint: const Text(LS.serverModelHint),
                  decoration: const InputDecoration(
                    labelText: LS.serverModelLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in models)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          m,
                          textDirection: TextDirection.ltr,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy ? null : _pickModel,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: LS.refreshModels,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _busy ? null : _test,
              ),
            ],
          ),
        const SizedBox(height: 8),
        Text(LS.serverModelAdvice, style: muted),
      ],
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.loopback});

  final bool loopback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = loopback ? scheme.primary : scheme.tertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          loopback ? Icons.lock_outline_rounded : Icons.lan_outlined,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            loopback ? LS.serverPrivacyLoopback : LS.serverPrivacyLan,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
