// Guest screens (v1.2 C): joining a host (QR scan on Android / iOS, hosts
// found on the LAN, or the code and address typed by hand — the only way on
// Windows, where no maintained camera QR scanner exists) and the minimal
// recording screen of a guest device.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../ui/widgets/level_meter.dart';
import 'discovery.dart';
import 'multi_device_providers.dart';
import 'protocol.dart';
import 'strings.dart';

/// Opens the join screen (or the guest recording screen when joined).
Future<void> openGuestJoinScreen(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const GuestJoinScreen()));

/// Joining a host as an extra device.
class GuestJoinScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GuestJoinScreen({super.key});

  @override
  ConsumerState<GuestJoinScreen> createState() => _GuestJoinScreenState();
}

class _GuestJoinScreenState extends ConsumerState<GuestJoinScreen> {
  final _code = TextEditingController();
  final _address = TextEditingController();
  late final TextEditingController _name = TextEditingController(
    text: defaultDeviceName(),
  );
  final _form = GlobalKey<FormState>();
  StreamSubscription<List<DiscoveredHost>>? _browse;
  late final MultiDeviceDiscovery _discovery;
  List<DiscoveredHost>? _hosts;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    final discovery = _discovery = ref.read(multiDeviceDiscoveryProvider);
    _browse = discovery.browse().listen((h) {
      if (mounted) setState(() => _hosts = h);
    });
  }

  @override
  void dispose() {
    unawaited(_browse?.cancel());
    unawaited(_discovery.stopBrowsing());
    _code.dispose();
    _address.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _join(JoinTarget target) async {
    setState(() => _joining = true);
    final ok = await ref
        .read(guestSessionControllerProvider.notifier)
        .join(target, name: _name.text);
    if (!mounted) return;
    setState(() => _joining = false);
    if (ok) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const GuestRecordingScreen()),
      );
    }
  }

  Future<void> _joinManual() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final code = normalizePairingCode(_code.text)!;
    final (host, port) = parseHostPort(_address.text)!;
    await _join(JoinTarget(hosts: [host], port: port, code: code));
  }

  Future<void> _scan() async {
    final info = await Navigator.of(context)
        .push<JoinInfo>(MaterialPageRoute(builder: (_) => const _QrScanPage()));
    if (info == null || !mounted) return;
    _code.text = formatPairingCode(info.code);
    _address.text = info.displayAddress;
    await _join(JoinTarget.fromInfo(info));
  }

  @override
  Widget build(BuildContext context) {
    final guest = ref.watch(guestSessionControllerProvider);
    final theme = Theme.of(context);
    if (guest.isActive && !_joining) {
      return const GuestRecordingScreen();
    }
    final hosts = _hosts;
    return Scaffold(
      appBar: AppBar(title: const Text(MS.guestEntry)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(MS.guestIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(MS.sameNetwork, style: theme.textTheme.bodySmall),
              if (guest.messageAr != null && !guest.isActive) ...[
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      guest.messageAr!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (qrScanSupported)
                FilledButton.icon(
                  onPressed: _joining ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text(MS.scanQr),
                )
              else
                Text(MS.scanUnavailable, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(MS.nearbyHosts, style: theme.textTheme.titleSmall),
              if (hosts == null)
                const ListTile(
                  leading: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text(MS.searching),
                )
              else if (hosts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(MS.noneFound, style: theme.textTheme.bodySmall),
                )
              else
                for (final h in hosts)
                  ListTile(
                    leading: const Icon(Icons.cast_connected_rounded),
                    title: Text(h.name),
                    subtitle: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(h.displayAddress),
                    ),
                    onTap: () =>
                        setState(() => _address.text = h.displayAddress),
                  ),
              const Divider(height: 32),
              Text(MS.manualEntry, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('md-join-code'),
                controller: _code,
                textDirection: TextDirection.ltr,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: MS.codeLabel,
                  hintText: MS.codeHint,
                  prefixIcon: Icon(Icons.password_rounded),
                ),
                validator: (v) => normalizePairingCode(v ?? '') == null
                    ? MS.invalidCode
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('md-join-address'),
                controller: _address,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: MS.addressLabel,
                  hintText: MS.addressHint,
                  prefixIcon: Icon(Icons.lan_rounded),
                ),
                validator: (v) =>
                    parseHostPort(v ?? '') == null ? MS.invalidAddress : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('md-join-name'),
                controller: _name,
                decoration: const InputDecoration(
                  labelText: MS.deviceName,
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('md-join'),
                onPressed: _joining ? null : _joinManual,
                icon: _joining
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text(MS.join),
              ),
              const SizedBox(height: 12),
              Text(MS.privacyNote, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final info = JoinInfo.tryParse(raw);
      if (info != null) {
        _done = true;
        Navigator.of(context).pop(info);
        return;
      }
      setState(() => _error = MS.notAJoinCode);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(MS.scanQr)),
    body: Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: Text(
              _error ?? MS.scanHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The minimal screen of a guest device while it records for a host.
class GuestRecordingScreen extends ConsumerWidget {
  /// Creates the screen.
  const GuestRecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(guestSessionControllerProvider);
    final theme = Theme.of(context);
    final (icon, text, color) = switch (s.phase) {
      GuestPhase.connecting => (
        Icons.sync_rounded,
        MS.connecting,
        theme.colorScheme.primary,
      ),
      GuestPhase.waiting => (
        Icons.hourglass_top_rounded,
        MS.waiting,
        theme.colorScheme.primary,
      ),
      GuestPhase.recording => (
        Icons.fiber_manual_record_rounded,
        MS.recording,
        theme.colorScheme.error,
      ),
      GuestPhase.paused => (
        Icons.pause_circle_rounded,
        MS.paused,
        theme.colorScheme.onSurfaceVariant,
      ),
      GuestPhase.reconnecting => (
        Icons.wifi_off_rounded,
        MS.reconnecting,
        Colors.orange.shade800,
      ),
      GuestPhase.ended => (
        Icons.check_circle_rounded,
        MS.ended,
        Colors.green.shade700,
      ),
      GuestPhase.removed => (
        Icons.person_off_rounded,
        MS.removed,
        theme.colorScheme.error,
      ),
      GuestPhase.failed => (
        Icons.error_rounded,
        s.messageAr ?? MS.gaveUp,
        theme.colorScheme.error,
      ),
      GuestPhase.idle => (
        Icons.mic_off_rounded,
        MS.guestIntro,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    final active = s.isActive;
    return Scaffold(
      appBar: AppBar(title: const Text(MS.guestTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(
              text,
              key: const Key('md-guest-status'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (s.hostName.isNotEmpty)
              Text(MS.hostLabel(s.hostName), textAlign: TextAlign.center),
            if (s.title.isNotEmpty)
              Text(MS.meetingLabel(s.title), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (active)
              LevelMeter(
                level: s.level,
                active: s.phase == GuestPhase.recording,
              ),
            const SizedBox(height: 24),
            Text(
              MS.guestNoStorage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            Text(
              MS.privacyNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: active
              ? OutlinedButton.icon(
                  key: const Key('md-guest-leave'),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(MS.leave),
                  onPressed: () async {
                    await ref
                        .read(guestSessionControllerProvider.notifier)
                        .leave();
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                )
              : FilledButton(
                  key: const Key('md-guest-done'),
                  onPressed: () {
                    ref.read(guestSessionControllerProvider.notifier).reset();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text(MS.done),
                ),
        ),
      ),
    );
  }
}
