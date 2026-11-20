// Shared widgets of v1.2 C: QR code, guest list with live status, the
// recording-screen card, the meeting-page log card and the entry menu.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

import '../../core/time_format.dart';
import '../../ui/widgets/dialogs.dart';
import 'alignment.dart' show AlignmentState;
import 'host_lobby_screen.dart';
import 'guest_screens.dart';
import 'hub.dart';
import 'multi_device_providers.dart';
import 'strings.dart';

/// A QR code of [data] drawn with package:qr (no extra dependency).
class QrCodeView extends StatelessWidget {
  /// Creates the view.
  const QrCodeView({super.key, required this.data, this.size = 220});

  /// Encoded text.
  final String data;

  /// Side length.
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return Semantics(
      label: MS.scanQr,
      image: true,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _QrPainter(image)),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);
  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final cell = size.shortestSide / n;
    final paint = Paint()..color = Colors.black;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (image.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell + 0.3, cell + 0.3),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => !identical(old.image, image);
}

IconData _platformIcon(String p) => switch (p) {
  'windows' || 'macos' || 'linux' => Icons.laptop_rounded,
  _ => Icons.smartphone_rounded,
};

IconData _batteryIcon(int pct, bool? charging) {
  if (charging == true) return Icons.battery_charging_full_rounded;
  if (pct >= 90) return Icons.battery_full_rounded;
  if (pct >= 60) return Icons.battery_5_bar_rounded;
  if (pct >= 30) return Icons.battery_3_bar_rounded;
  if (pct >= 15) return Icons.battery_2_bar_rounded;
  return Icons.battery_alert_rounded;
}

/// One guest: name, connection, battery, network, level, remove.
class GuestTile extends ConsumerWidget {
  /// Creates the tile.
  const GuestTile({super.key, required this.guest});

  /// The guest.
  final GuestView guest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = guest;
    final name = g.name.isEmpty ? MS.unnamedDevice : g.name;
    final qualityColor = switch (g.quality) {
      NetworkQuality.good => Colors.green.shade700,
      NetworkQuality.fair => Colors.orange.shade800,
      NetworkQuality.poor => scheme.error,
    };
    final chips = <Widget>[
      _Chip(
        icon: g.connected ? Icons.link_rounded : Icons.link_off_rounded,
        label: g.connected ? MS.connected : MS.disconnected,
        color: g.connected ? Colors.green.shade700 : scheme.error,
      ),
      if (g.connected)
        _Chip(
          icon: Icons.network_check_rounded,
          label: g.rttMs == null
              ? MS.quality(g.quality)
              : '${MS.quality(g.quality)} · ${MS.rtt(g.rttMs!)}',
          color: qualityColor,
        ),
      _Chip(
        icon: g.battery == null
            ? Icons.battery_unknown_rounded
            : _batteryIcon(g.battery!, g.charging),
        label: g.battery == null
            ? MS.batteryUnknown
            : MS.battery(g.battery!, g.charging),
        color: g.battery != null && g.battery! < 15 && g.charging != true
            ? scheme.error
            : scheme.onSurfaceVariant,
      ),
      if (g.connected && g.alignment != null)
        _Chip(
          icon: g.alignment == AlignmentState.locked
              ? Icons.sync_rounded
              : Icons.sync_problem_rounded,
          label: g.alignment == AlignmentState.locked
              ? MS.aligned
              : MS.aligning,
          color: scheme.onSurfaceVariant,
        ),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_platformIcon(g.platform), color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleSmall),
                      if (g.platform.isNotEmpty)
                        Text(
                          MS.platform(g.platform),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: MS.remove,
                  icon: const Icon(Icons.person_remove_rounded),
                  onPressed: () => _confirmRemove(context, ref, name),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: chips),
            if (g.connected) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'مستوى الصوت',
                value: '${(g.level * 100).round()}٪',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: g.level.clamp(0.0, 1.0),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: MS.removeTitle(name),
      body: MS.removeBody,
      confirmLabel: MS.remove,
      destructive: true,
      icon: Icons.person_remove_rounded,
    );
    if (!ok) return;
    await ref.read(multiDeviceHostControllerProvider.notifier).remove(guest.id);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    ],
  );
}

/// The guests of the open hub.
class GuestsPanel extends ConsumerWidget {
  /// Creates the panel.
  const GuestsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guests = ref.watch(guestViewsProvider).value ?? const [];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(MS.devicesTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (guests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(MS.noDevices, style: theme.textTheme.bodyMedium),
          )
        else
          for (final g in guests) GuestTile(key: ValueKey(g.id), guest: g),
      ],
    );
  }
}

/// Recording screen: the extra devices (nothing when not hosting).
class MultiDeviceRecordingCard extends ConsumerWidget {
  /// Creates the card.
  const MultiDeviceRecordingCard({super.key, this.padding = EdgeInsets.zero});

  /// Outer padding (only when shown).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(multiDeviceHubProvider) == null) {
      return const SizedBox.shrink();
    }
    final guests = ref.watch(guestViewsProvider).value ?? const [];
    final connected = guests.where((g) => g.connected).length;
    return Padding(
      padding: padding,
      child: Card(
        child: ExpansionTile(
          leading: const Icon(Icons.devices_rounded),
          title: const Text(MS.hostEntry),
          subtitle: Text(MS.devicesCount(connected, guests.length)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: const [GuestsPanel()],
        ),
      ),
    );
  }
}

/// Meeting page: devices of a multi-device meeting and their gaps (nothing
/// for single-device meetings).
class MultiDeviceLogCard extends ConsumerWidget {
  /// Creates the card for [meetingId].
  const MultiDeviceLogCard({super.key, required this.meetingId});

  /// The meeting.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(multiDeviceLogProvider(meetingId)).value;
    if (log == null || log.devices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    String t(int ms) => formatTimestamp(ms);
    final lines = <String>[
      for (final gap in log.gaps)
        MS.gap(
          log.nameOf(gap.deviceId),
          t(gap.startMs),
          gap.endMs == null ? null : t(gap.endMs!),
        ),
      for (final e in log.events)
        if (e.kind == 'removed')
          MS.removedAt(log.nameOf(e.channelId), t(e.atMs)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(MS.logTitle, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(MS.logDevices(log.devices.length)),
            for (final d in log.devices)
              Text(
                '• ${d.name.isEmpty ? MS.unnamedDevice : d.name}'
                '${d.platform.isEmpty ? '' : ' (${MS.platform(d.platform)})'}'
                ' — ${MS.chosen(d.segmentsChosen)}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            if (lines.isEmpty)
              Text(MS.noGaps, style: theme.textTheme.bodySmall)
            else
              for (final l in lines)
                Text(
                  l,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// App-bar menu with the two entries (host / guest).
class MultiDeviceMenuButton extends StatelessWidget {
  /// Creates the button.
  const MultiDeviceMenuButton({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: MS.menuTooltip,
    icon: const Icon(Icons.devices_rounded),
    onSelected: (v) =>
        v == 0 ? openHostLobbyScreen(context) : openGuestJoinScreen(context),
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 0,
        child: ListTile(
          leading: Icon(Icons.cast_connected_rounded),
          title: Text(MS.hostEntry),
        ),
      ),
      PopupMenuItem(
        value: 1,
        child: ListTile(
          leading: Icon(Icons.mic_external_on_rounded),
          title: Text(MS.guestEntry),
        ),
      ),
    ],
  );
}
