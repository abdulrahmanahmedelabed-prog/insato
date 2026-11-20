// Live Insato call (v1.2): shared widgets — the entry button, the
// persistent streaming indicator, the live transcript, the meeting-page call
// log card and the settings tile.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/time_format.dart';
import 'call_engine.dart';
import 'call_log.dart';
import 'live_call_screens.dart';
import 'live_call_settings_screen.dart';
import 'strings.dart';
import 'transcript_merge.dart';

/// App-bar entry «مكالمة حية».
class LiveCallMenuButton extends StatelessWidget {
  /// Creates the button.
  const LiveCallMenuButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: LCS.menuTooltip,
    icon: const Icon(Icons.wifi_calling_3_rounded),
    onPressed: () => openLiveCallHome(context),
  );
}

/// The persistent «يتم البث والتفريغ» bar, with the elapsed time and a
/// one-tap stop.
class LiveStreamingIndicator extends StatelessWidget {
  /// Creates the indicator.
  const LiveStreamingIndicator({
    super.key,
    required this.since,
    required this.onStop,
    this.reconnecting = false,
  });

  /// Streaming start.
  final DateTime? since;

  /// Stop action.
  final VoidCallback onStop;

  /// Show the reconnecting text instead.
  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = reconnecting
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.errorContainer;
    final fg = reconnecting
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onErrorContainer;
    return Semantics(
      liveRegion: true,
      label: reconnecting ? LCS.reconnecting : LCS.liveIndicator,
      child: Material(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record_rounded, color: fg, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reconnecting ? LCS.reconnecting : LCS.liveIndicator,
                  style: theme.textTheme.titleSmall?.copyWith(color: fg),
                ),
              ),
              if (since != null) _Elapsed(since: since!, color: fg),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onStop,
                icon: Icon(Icons.call_end_rounded, color: fg),
                label: Text(LCS.stop, style: TextStyle(color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.since, required this.color});
  final DateTime since;
  final Color color;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = DateTime.now().difference(widget.since).inMilliseconds;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        formatDuration(ms < 0 ? 0 : ms),
        style: TextStyle(color: widget.color, fontFeatures: const []),
      ),
    );
  }
}

/// The combined live transcript (newest at the bottom).
class LiveTranscriptList extends StatelessWidget {
  /// Creates the list.
  const LiveTranscriptList({
    super.key,
    required this.lines,
    required this.peerName,
  });

  /// Lines in time order.
  final List<LiveLine> lines;

  /// The other device's name.
  final String peerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            LCS.noLinesYet,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    final reversed = lines.reversed.toList(growable: false);
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final l = reversed[i];
        final local = l.origin == LineOrigin.local;
        final side = local ? LCS.thisDevice : peerName;
        final who = l.speakerName.isEmpty ? side : '${l.speakerName} · $side';
        final color = local
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.secondaryContainer;
        return Align(
          alignment: local
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              key: ValueKey(l.key),
              color: color,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(who, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    if (l.pending)
                      Text(
                        LCS.transcribing,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Text(l.text, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Link quality chip.
class CallQualityChip extends StatelessWidget {
  /// Creates the chip.
  const CallQualityChip({super.key, required this.snapshot});

  /// The call.
  final CallSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final q = snapshot.quality;
    final icon = switch (q) {
      CallQuality.good => Icons.signal_cellular_alt_rounded,
      CallQuality.fair => Icons.signal_cellular_alt_2_bar_rounded,
      CallQuality.poor => Icons.signal_cellular_alt_1_bar_rounded,
      CallQuality.unknown => Icons.signal_cellular_null_rounded,
    };
    final rtt = snapshot.stats?.rttMs;
    final relayed = snapshot.stats?.relayed;
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(
        [
          LCS.quality(q),
          if (rtt != null) LCS.rtt(rtt.round()),
          if (relayed != null) relayed ? LCS.viaTurn : LCS.direct,
        ].join(' · '),
      ),
    );
  }
}

/// The call log of a meeting (renders nothing for other meetings).
class LiveCallLogCard extends ConsumerWidget {
  /// Creates the card for [meetingId].
  const LiveCallLogCard({super.key, required this.meetingId});

  /// The meeting.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(liveCallLogProvider(meetingId)).value;
    if (log == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final d = log.duration;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi_calling_3_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(LCS.logTitle, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(LCS.between(log.localName, log.remoteName)),
            if (d != null) Text(formatDurationWords(d.inMilliseconds), style: small),
            if (log.safetyCode != null)
              Text('${LCS.safetyCode}: ${log.safetyCode}', style: small),
            if (log.relayed != null)
              Text(log.relayed! ? LCS.viaTurn : LCS.direct, style: small),
            const SizedBox(height: 4),
            for (final e in log.events)
              Text(
                '• ${formatArabicDateTime(e.at)} — '
                '${LCS.event(e.kind, byRemote: e.byRemote)}',
                style: small,
              ),
          ],
        ),
      ),
    );
  }
}

/// Settings entry «المكالمة الحية».
class LiveCallSettingsTile extends StatelessWidget {
  /// Creates the tile.
  const LiveCallSettingsTile({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.wifi_calling_3_rounded),
      title: const Text(LCS.openSettings),
      subtitle: const Text(LCS.settingsSubtitle),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: () => openLiveCallSettings(context),
    ),
  );
}
