// Live Insato call (v1.2): screens — start / join, the consent notice, the
// QR scanner and the in-call screen (code while waiting; live transcript,
// mute, stop, quality, safety code and the streaming indicator while
// active; the outcome and the saved meeting afterwards).
//
// The call screen cannot be left while streaming (back asks to end the
// call), so the streaming indicator is always on screen while the app is in
// the foreground; in the background, Android shows the ongoing notification.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/errors.dart';
import '../../ui/navigation.dart' show openMeeting;
import '../../ui/widgets/common.dart' show showSnack;
import '../../ui/widgets/dialogs.dart' show showConfirmDialog;
import '../../core/time_format.dart' show formatArabicDateTime;
import '../multi_device/multi_device_providers.dart' show qrScanSupported;
import '../multi_device/widgets.dart' show QrCodeView;
import 'call_code.dart';
import 'call_engine.dart';
import 'call_log.dart';
import 'call_settings.dart';
import 'live_call_providers.dart';
import 'live_call_settings_screen.dart';
import 'strings.dart';
import 'widgets.dart';

/// Opens the live-call start screen (or the running call).
Future<void> openLiveCallHome(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LiveCallHomeScreen()),
    );

/// Shows the live-call consent notice; true when accepted.
Future<bool> showLiveCallConsent(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.wifi_calling_3_rounded, color: scheme.primary),
        title: const Text(LCS.consentTitle),
        content: const SizedBox(
          width: 480,
          child: SingleChildScrollView(child: Text(LCS.consentBody)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(LCS.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(LCS.consentAccept),
          ),
        ],
      );
    },
  );
  return r ?? false;
}

/// Runs [action] (start or join), showing the consent notice first when it
/// is required. Returns true when the call was started. Errors are shown.
Future<bool> runLiveCallAction(
  BuildContext context,
  Future<void> Function(bool consentGiven) action,
) async {
  try {
    try {
      await action(false);
    } on CallConsentRequiredException {
      if (!context.mounted) return false;
      if (!await showLiveCallConsent(context)) return false;
      await action(true);
    }
    return true;
  } on InsatoException catch (e) {
    if (context.mounted) showSnack(context, e.messageAr, error: true);
    return false;
  }
}

/// Start / join.
class LiveCallHomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const LiveCallHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(liveCallSettingsProvider).value;
    final call = ref.watch(liveCallControllerProvider);
    final configured = settings?.effectiveSignalingUrl != null;
    final history = ref.watch(liveCallHistoryProvider).value ?? const [];
    final controller = ref.read(liveCallControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text(LCS.title),
        actions: [
          IconButton(
            tooltip: LCS.openSettings,
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => openLiveCallSettings(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(LCS.intro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          if (settings != null && !configured)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(LCS.notConfigured),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => openLiveCallSettings(context),
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text(LCS.openSettings),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (call.isBusy)
            Card(
              child: ListTile(
                leading: const Icon(Icons.fiber_manual_record_rounded),
                title: const Text(LCS.liveIndicator),
                onTap: () => _openCall(context),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_call),
              title: const Text(LCS.startCall),
              subtitle: const Text(LCS.startCallHint),
              enabled: !call.isBusy,
              onTap: () async {
                await controller.reset();
                if (!context.mounted) return;
                final ok = await runLiveCallAction(
                  context,
                  (c) => controller.startCall(consentGiven: c),
                );
                if (ok && context.mounted) await _openCall(context);
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.call_received_rounded),
              title: const Text(LCS.joinCall),
              subtitle: const Text(LCS.joinCallHint),
              enabled: !call.isBusy,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LiveCallJoinScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(LCS.privacyNote, style: theme.textTheme.bodySmall),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(LCS.history, style: theme.textTheme.titleMedium),
            for (final (id, log) in history.take(20))
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(LCS.between(log.localName, log.remoteName)),
                subtitle: Text(formatArabicDateTime(log.startedAt)),
                onTap: () => openMeeting(context, ref, id),
              ),
          ],
        ],
      ),
    );
  }
}

Future<void> _openCall(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => const LiveCallScreen()),
);

/// Joining with a code or a QR scan.
class LiveCallJoinScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LiveCallJoinScreen({super.key});

  @override
  ConsumerState<LiveCallJoinScreen> createState() => _LiveCallJoinScreenState();
}

class _LiveCallJoinScreenState extends ConsumerState<LiveCallJoinScreen> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _joining = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join(CallInvite invite) async {
    if (_joining) return;
    setState(() => _joining = true);
    final controller = ref.read(liveCallControllerProvider.notifier);
    await controller.reset();
    if (!mounted) return;
    final ok = await runLiveCallAction(
      context,
      (c) => controller.joinCall(invite, consentGiven: c),
    );
    if (!mounted) return;
    setState(() => _joining = false);
    if (ok) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LiveCallScreen()),
      );
    }
  }

  Future<void> _scan() async {
    final invite = await Navigator.of(context).push<CallInvite>(
      MaterialPageRoute(builder: (_) => const _CallQrScanPage()),
    );
    if (invite != null && mounted) await _join(invite);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(LCS.joinCall)),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (qrScanSupported) ...[
            FilledButton.tonalIcon(
              onPressed: _joining ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text(LCS.scanQr),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            key: const ValueKey('call-code'),
            controller: _code,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: LCS.codeLabel,
              hintText: LCS.codeHint,
            ),
            validator: (v) => CallInvite.tryParse(v ?? '') == null
                ? LCS.invalidCode
                : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _joining
                ? null
                : () {
                    if (!(_form.currentState?.validate() ?? false)) return;
                    unawaited(_join(CallInvite.tryParse(_code.text)!));
                  },
            icon: const Icon(Icons.call_rounded),
            label: const Text(LCS.join),
          ),
          const SizedBox(height: 16),
          Text(LCS.privacyNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _CallQrScanPage extends StatefulWidget {
  const _CallQrScanPage();

  @override
  State<_CallQrScanPage> createState() => _CallQrScanPageState();
}

class _CallQrScanPageState extends State<_CallQrScanPage> {
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
      final invite = CallInvite.tryParse(raw);
      if (invite != null) {
        _done = true;
        Navigator.of(context).pop(invite);
        return;
      }
      setState(() => _error = LCS.notACallCode);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(LCS.scanQr)),
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
              _error ?? LCS.scanHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The call screen.
class LiveCallScreen extends ConsumerWidget {
  /// Creates the screen.
  const LiveCallScreen({super.key});

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final end = await showConfirmDialog(
      context,
      title: LCS.leaveTitle,
      body: LCS.leaveBody,
      confirmLabel: LCS.stop,
      destructive: true,
      icon: Icons.call_end_rounded,
    );
    if (end) await ref.read(liveCallControllerProvider.notifier).hangUp();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveCallControllerProvider);
    final call = state.call;
    final controller = ref.read(liveCallControllerProvider.notifier);
    final busy = state.isBusy;
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy) unawaited(_confirmLeave(context, ref));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            call == null || call.peerName.isEmpty
                ? LCS.title
                : '${LCS.entry} — ${call.peerName}',
          ),
        ),
        body: SafeArea(
          child: call == null
              ? const Center(child: Text(LCS.ended))
              : switch (call.phase) {
                  CallPhase.active || CallPhase.reconnecting => _ActiveCall(
                    state: state,
                    call: call,
                    onStop: () => unawaited(controller.hangUp()),
                    onMute: (m) => unawaited(controller.setMuted(m)),
                  ),
                  CallPhase.ended || CallPhase.failed => _CallOutcome(
                    state: state,
                    call: call,
                  ),
                  CallPhase.waitingForPeer => _Waiting(
                    call: call,
                    onCancel: () => unawaited(controller.hangUp()),
                  ),
                  _ => _Progress(
                    text: LCS.phase(call.phase),
                    onCancel: () => unawaited(controller.hangUp()),
                  ),
                },
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.text, required this.onCancel});
  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onCancel, child: const Text(LCS.cancel)),
        ],
      ),
    ),
  );
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.call, required this.onCancel});
  final CallSnapshot call;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invite = call.invite;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (invite != null) ...[
          Center(child: QrCodeView(data: invite.toUri())),
          const SizedBox(height: 12),
          Text(
            LCS.yourCode,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              invite.displayCode,
              key: const ValueKey('call-code-display'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        const Text(LCS.waiting, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text(LCS.cancel),
          ),
        ),
      ],
    );
  }
}

class _ActiveCall extends StatelessWidget {
  const _ActiveCall({
    required this.state,
    required this.call,
    required this.onStop,
    required this.onMute,
  });
  final LiveCallState state;
  final CallSnapshot call;
  final VoidCallback onStop;
  final ValueChanged<bool> onMute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        LiveStreamingIndicator(
          since: call.connectedAt,
          onStop: onStop,
          reconnecting: call.phase == CallPhase.reconnecting,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CallQualityChip(snapshot: call),
              if (call.safetyCode != null)
                Tooltip(
                  message: LCS.safetyHint,
                  child: Chip(
                    avatar: const Icon(Icons.verified_user_rounded, size: 18),
                    label: Text('${LCS.safetyCode}: ${call.safetyCode}'),
                  ),
                ),
              if (call.remoteSpeaking)
                Chip(
                  avatar: const Icon(Icons.graphic_eq_rounded, size: 18),
                  label: Text('${call.peerName} — ${LCS.speakingNow}'),
                ),
              if (call.muted) const Chip(label: Text(LCS.mutedChip)),
              if (call.peerMuted) Chip(label: Text(LCS.peerMuted(call.peerName))),
            ],
          ),
        ),
        if (state.warningAr != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              state.warningAr!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: LiveTranscriptList(lines: call.lines, peerName: call.peerName),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: call.muted ? LCS.unmute : LCS.mute,
                onPressed: () => onMute(!call.muted),
                icon: Icon(
                  call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('stop-call'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: onStop,
                  icon: const Icon(Icons.call_end_rounded),
                  label: const Text(LCS.stop),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CallOutcome extends ConsumerWidget {
  const _CallOutcome({required this.state, required this.call});
  final LiveCallState state;
  final CallSnapshot call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saved = state.savedMeetingId;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              call.phase == CallPhase.failed
                  ? Icons.error_outline_rounded
                  : Icons.call_end_rounded,
              size: 48,
              color: call.phase == CallPhase.failed
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(LCS.ended, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              LCS.endReason(call.endReason, call.peerName),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (state.saving) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text(LCS.saving),
            ] else if (saved != null) ...[
              Text(state.warningAr ?? LCS.saved, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final route = ModalRoute.of(context);
                  await ref.read(liveCallControllerProvider.notifier).reset();
                  if (!context.mounted) return;
                  await openMeeting(context, ref, saved, replaceRoute: route);
                },
                icon: const Icon(Icons.description_rounded),
                label: const Text(LCS.openMeeting),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref.read(liveCallControllerProvider.notifier).reset();
                if (context.mounted) Navigator.of(context).maybePop();
              },
              child: const Text(LCS.close),
            ),
          ],
        ),
      ),
    );
  }
}
