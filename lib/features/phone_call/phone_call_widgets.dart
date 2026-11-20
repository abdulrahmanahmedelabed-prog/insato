// Phone-call mode entry points shown by the shared screens:
// * [PhoneCallMenuButton] – meetings app bar: opens the setup screen.
// * [PhoneCallRecordingCard] – recording screen: armed call, per-side
//   levels and counters, headphones advice.
// * [PhoneCallMeetingCard] – meeting page: the call mode of a meeting.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../session/providers.dart'
    show meetingSessionControllerProvider, sessionAudioSourceProvider;
import 'call_session_audio.dart';
import 'phone_call_check.dart' show PhoneCallLevelRow;
import 'phone_call_models.dart';
import 'phone_call_providers.dart';
import 'phone_call_setup_screen.dart';
import 'strings.dart';

/// App-bar button opening the phone-call setup.
class PhoneCallMenuButton extends ConsumerWidget {
  /// Creates the button.
  const PhoneCallMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: PCS.menuTooltip,
    icon: const Icon(Icons.phone_in_talk_rounded),
    onPressed: () => startPhoneCallFlow(context, ref),
  );
}

/// Recording screen: the call mode of the running (or next) take; nothing
/// for ordinary meetings.
class PhoneCallRecordingCard extends ConsumerWidget {
  /// Creates the card.
  const PhoneCallRecordingCard({super.key, this.padding = EdgeInsets.zero});

  /// Outer padding (only when shown).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(phoneCallSessionPlanProvider);
    if (plan == null) return const SizedBox.shrink();
    final active = ref.watch(
      meetingSessionControllerProvider.select((s) => s.isActive),
    );
    final source = ref.watch(sessionAudioSourceProvider);
    final call = source is CallSessionAudio ? source as CallSessionAudio : null;
    final phoneLink = plan.setup.mode == PhoneCallMode.phoneLink;
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.phone_in_talk_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      PCS.recordingTitle(phoneLink),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (!active)
                    TextButton(
                      onPressed: () =>
                          ref.read(phoneCallSetupProvider.notifier).disarm(),
                      child: const Text(PCS.disarm),
                    ),
                ],
              ),
              if (!active) const Text(PCS.armed),
              if (active && call != null) _LiveCall(call: call),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveCall extends StatelessWidget {
  const _LiveCall({required this.call});

  final CallSessionAudio call;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phoneLink = call.callMode == PhoneCallMode.phoneLink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<double>(
          stream: call.localLevel,
          builder: (_, s) => PhoneCallLevelRow(
            label: phoneLink ? PCS.levelLocal : PCS.levelRoom,
            icon: Icons.mic_rounded,
            level: s.data ?? 0,
          ),
        ),
        if (phoneLink)
          StreamBuilder<double>(
            stream: call.remoteLevel,
            builder: (_, s) => PhoneCallLevelRow(
              label: PCS.levelRemote,
              icon: Icons.phone_in_talk_rounded,
              level: s.data ?? 0,
            ),
          ),
        StreamBuilder<CallLiveStats>(
          stream: call.liveStats,
          initialData: call.stats,
          builder: (_, s) {
            final st = s.data ?? const CallLiveStats();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  PCS.counters(st.localSegments, st.remoteSegments),
                  style: theme.textTheme.bodySmall,
                ),
                if (st.unattributed > 0)
                  Text(
                    PCS.unattributed(st.unattributed),
                    style: theme.textTheme.bodySmall,
                  ),
                if (phoneLink && st.bleedSuppressed > 0)
                  Text(
                    PCS.bleed(st.bleedSuppressed),
                    style: theme.textTheme.bodySmall,
                  ),
                if (phoneLink && st.suggestHeadphones)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.headphones_rounded,
                          size: 18,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(child: Text(PCS.headphones)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Meeting page: how the call was captured (nothing for other meetings).
class PhoneCallMeetingCard extends ConsumerWidget {
  /// Creates the card for [meetingId].
  const PhoneCallMeetingCard({super.key, required this.meetingId});

  /// The meeting.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(phoneCallLogProvider(meetingId)).value;
    if (log == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final phoneLink = log.mode == PhoneCallMode.phoneLink;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_in_talk_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(PCS.meetingCardTitle, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(PCS.modeLine(phoneLink)),
            Text(
              PCS.counters(
                log.count(CallSide.local),
                log.count(CallSide.remote),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (phoneLink && log.bleedSuppressed > 0)
              Text(
                PCS.bleed(log.bleedSuppressed),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
