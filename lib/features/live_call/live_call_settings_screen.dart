// Live Insato call (v1.2): settings screen — signaling relay URL, device
// name, optional TURN server (credential in secure storage) and relay-only.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'call_code.dart' show normalizeSignalingUrl;
import 'call_settings.dart';
import 'strings.dart';

/// Opens the settings screen.
Future<void> openLiveCallSettings(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LiveCallSettingsScreen()),
    );

/// Live-call settings.
class LiveCallSettingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LiveCallSettingsScreen({super.key});

  @override
  ConsumerState<LiveCallSettingsScreen> createState() =>
      _LiveCallSettingsScreenState();
}

class _LiveCallSettingsScreenState
    extends ConsumerState<LiveCallSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _name = TextEditingController();
  final _turnUrl = TextEditingController();
  final _turnUser = TextEditingController();
  final _turnCredential = TextEditingController();
  LiveCallSettings _loaded = const LiveCallSettings();
  bool _relayOnly = false;
  bool _hasCredential = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final s = await ref.read(liveCallSettingsStoreProvider).load();
    final cred = await ref.read(turnCredentialStoreProvider).read();
    if (!mounted) return;
    setState(() {
      _loaded = s;
      _url.text = s.signalingUrl;
      _name.text = s.deviceName;
      _turnUrl.text = s.turnUrl;
      _turnUser.text = s.turnUsername;
      _relayOnly = s.relayOnly;
      _hasCredential = cred != null && cred.isNotEmpty;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    _turnUrl.dispose();
    _turnUser.dispose();
    _turnCredential.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final url = _url.text.trim();
    final s = _loaded.copyWith(
      signalingUrl: url.isEmpty ? '' : normalizeSignalingUrl(url),
      deviceName: _name.text.trim(),
      turnUrl: _turnUrl.text.trim(),
      turnUsername: _turnUser.text.trim(),
      relayOnly: _relayOnly,
    );
    await ref.read(liveCallSettingsStoreProvider).save(s);
    final cred = _turnCredential.text.trim();
    if (cred.isNotEmpty) {
      await ref.read(turnCredentialStoreProvider).write(cred);
    } else if (_turnUrl.text.trim().isEmpty) {
      await ref.read(turnCredentialStoreProvider).write(null);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(LCS.settingsSaved)));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(LCS.openSettings)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(LCS.signalingHelp, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('signaling-url'),
                    controller: _url,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: LCS.signalingUrl,
                      hintText: LCS.signalingUrlHint,
                      hintTextDirection: TextDirection.ltr,
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      return normalizeSignalingUrl(t) == null
                          ? LCS.invalidUrl
                          : null;
                    },
                  ),
                  if (kBuiltInSignalingUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        LCS.builtInRelay(kBuiltInSignalingUrl),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('device-name'),
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: LCS.deviceName,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(LCS.turnSection, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(LCS.turnHelp, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const ValueKey('turn-url'),
                    controller: _turnUrl,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: LCS.turnUrl,
                      hintText: 'turn:turn.example.com:3478',
                      hintTextDirection: TextDirection.ltr,
                    ),
                  ),
                  TextFormField(
                    key: const ValueKey('turn-user'),
                    controller: _turnUser,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: LCS.turnUser,
                    ),
                  ),
                  TextFormField(
                    key: const ValueKey('turn-credential'),
                    controller: _turnCredential,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: LCS.turnCredential,
                      helperText: _hasCredential
                          ? LCS.turnCredentialSaved
                          : null,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _relayOnly,
                    onChanged: (v) => setState(() => _relayOnly = v),
                    title: const Text(LCS.relayOnly),
                    subtitle: const Text(LCS.relayOnlyHint),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(LCS.save),
                  ),
                ],
              ),
            ),
    );
  }
}
