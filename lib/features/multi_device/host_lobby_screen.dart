// Host lobby (v1.2 C): opens the LAN server, shows the QR code, the
// pairing code and the address, lists the joined devices, and starts the
// meeting through the normal new-meeting flow (consent, context form).

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../session/providers.dart';
import '../../ui/navigation.dart';
import '../../ui/widgets/common.dart';
import '../context/meeting_context_flows.dart' show startNewMeetingWithContext;
import 'multi_device_providers.dart';
import 'protocol.dart';
import 'strings.dart';
import 'widgets.dart';

/// Opens the host lobby.
Future<void> openHostLobbyScreen(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const HostLobbyScreen()));

/// See the file header.
class HostLobbyScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const HostLobbyScreen({super.key});

  @override
  ConsumerState<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends ConsumerState<HostLobbyScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(multiDeviceHostControllerProvider.notifier).open();
    });
  }

  Future<void> _stopHosting() async {
    final ok = await ref
        .read(multiDeviceHostControllerProvider.notifier)
        .close();
    if (!mounted) return;
    if (!ok) {
      showSnack(context, MS.cannotStopWhileRecording, error: true);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(multiDeviceHostControllerProvider);
    final session = ref.watch(meetingSessionControllerProvider);
    final theme = Theme.of(context);
    final hub = lobby.hub;
    final windows = !kIsWeb && Platform.isWindows;

    final Widget body;
    if (hub == null) {
      body = lobby.errorAr != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorBanner(
                message: lobby.errorAr!,
                onRetry: () =>
                    ref.read(multiDeviceHostControllerProvider.notifier).open(),
              ),
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(MS.opening),
                  ],
                ),
              ),
            );
    } else {
      final info = hub.joinInfo;
      final code = formatPairingCode(info.code);
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(MS.hostIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Center(child: QrCodeView(data: info.toUri())),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: const Text(MS.codeLabel),
                  subtitle: Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      code,
                      key: const Key('md-code'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'NotoSans',
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'نسخ',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: code)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lan_rounded),
                  title: const Text(MS.addressLabel),
                  subtitle: info.addresses.isEmpty
                      ? Text(
                          MS.noAddress,
                          style: TextStyle(color: theme.colorScheme.error),
                        )
                      : Directionality(
                          textDirection: TextDirection.ltr,
                          child: SelectableText(
                            [
                              for (final a in info.addresses)
                                formatHostPort(a, info.port),
                            ].join('\n'),
                            key: const Key('md-address'),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const _Note(icon: Icons.wifi_rounded, text: MS.sameNetwork),
          const _Note(icon: Icons.lock_rounded, text: MS.privacyNote),
          if (windows)
            const _Note(icon: Icons.shield_rounded, text: MS.windowsFirewall),
          const SizedBox(height: 16),
          const GuestsPanel(),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(MS.hostEntry)),
      body: SafeArea(child: body),
      bottomNavigationBar: hub == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(
                          session.isActive
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_rounded,
                        ),
                        label: Text(
                          session.isActive
                              ? MS.backToRecording
                              : MS.startMeeting,
                        ),
                        onPressed: () => session.isActive
                            ? openRecordingScreen(context)
                            : startNewMeetingWithContext(context, ref),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: session.isActive ? null : _stopHosting,
                      child: const Text(MS.stopHosting),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
