// "المتحدثون" tab: speakers of one meeting with their share of the talk
// time, and rename / merge / "not the same person" actions, "improve voice"
// (F1) and the speaker profile (F16).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../features/profiles/profile_screen.dart' show openSpeakerProfile;
import '../../features/profiles/strings.dart' show PS;
import '../../features/voice/voice.dart'
    show ImproveVoiceMenuTile, openVoiceEnrollment;
import '../../session/providers.dart';
import '../actions.dart';
import '../format.dart';
import '../strings_ar.dart';
import '../widgets/common.dart';
import '../widgets/speaker_avatar.dart';

/// Speakers of [meetingId] with talk-time bars.
class MeetingSpeakersTab extends ConsumerWidget {
  /// Creates the tab.
  const MeetingSpeakersTab({super.key, required this.meetingId});

  /// Meeting shown.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakers = ref.watch(meetingSpeakersProvider(meetingId));
    final segments =
        ref.watch(segmentsProvider(meetingId)).value ??
        const <TranscriptSegment>[];
    return speakers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(
          message: S.unexpectedError,
          onRetry: () => ref.invalidate(meetingSpeakersProvider(meetingId)),
        ),
      ),
      data: (list) {
        final talk = {
          for (final t in computeTalkTimes(segments)) t.speakerId: t,
        };
        final unassigned = talk[null];
        if (list.isEmpty && unassigned == null) {
          return const EmptyState(
            icon: Icons.groups_outlined,
            title: S.noMeetingSpeakers,
          );
        }
        final sorted = [...list]
          ..sort(
            (a, b) => (talk[b.id]?.speakingMs ?? 0).compareTo(
              talk[a.id]?.speakingMs ?? 0,
            ),
          );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          children: [
            ReadableWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    S.renameSpeakerBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final s in sorted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SpeakerTalkCard(speaker: s, talk: talk[s.id]),
                    ),
                  if (unassigned != null)
                    SpeakerTalkCard(speaker: null, talk: unassigned),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A speaker with its talk-time share bar and actions.
class SpeakerTalkCard extends ConsumerWidget {
  /// Creates the card. A null [speaker] shows unassigned speech.
  const SpeakerTalkCard({super.key, required this.speaker, this.talk});

  /// The speaker.
  final Speaker? speaker;

  /// Talk time (null = no speech).
  final SpeakerTalkTime? talk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = speaker;
    final color = s == null ? scheme.outline : Color(s.colorValue);
    final ms = talk?.speakingMs ?? 0;
    final percent = talk?.percent ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SpeakerAvatar(speaker: s, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s?.name ?? S.unknownSpeaker,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        [
                          if (s != null && !s.isNamedByUser) S.autoNamed,
                          S.segmentsCount(talk?.segmentCount ?? 0),
                        ].join(' · '),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s != null) _SpeakerMenu(speaker: s),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Semantics(
                label: S.talkTime(formatDurationWords(ms), percent),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: talk?.share ?? 0,
                        minHeight: 10,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.talkTime(ltrDuration(ms), percent),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (s != null && !s.isNamedByUser)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => renameSpeakerFlow(context, ref, s),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text(S.renameSpeakerTitle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _SpeakerAction { profile, improve, rename, merge, forget }

class _SpeakerMenu extends ConsumerWidget {
  const _SpeakerMenu({required this.speaker});

  final Speaker speaker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_SpeakerAction>(
      tooltip: S.speakerActions,
      onSelected: (a) {
        switch (a) {
          case _SpeakerAction.profile:
            openSpeakerProfile(context, speaker.id);
          case _SpeakerAction.improve:
            openVoiceEnrollment(context, speaker: speaker);
          case _SpeakerAction.rename:
            renameSpeakerFlow(context, ref, speaker);
          case _SpeakerAction.merge:
            mergeSpeakerFlow(context, ref, speaker);
          case _SpeakerAction.forget:
            forgetVoiceFlow(context, ref, speaker);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _SpeakerAction.profile,
          child: ListTile(
            leading: Icon(Icons.badge_outlined),
            title: Text(PS.screenTitle),
          ),
        ),
        const PopupMenuItem(
          value: _SpeakerAction.improve,
          child: ImproveVoiceMenuTile(),
        ),
        const PopupMenuItem(
          value: _SpeakerAction.rename,
          child: ListTile(
            leading: Icon(Icons.edit_rounded),
            title: Text(S.rename),
          ),
        ),
        const PopupMenuItem(
          value: _SpeakerAction.merge,
          child: ListTile(
            leading: Icon(Icons.merge_rounded),
            title: Text(S.merge),
          ),
        ),
        PopupMenuItem(
          value: _SpeakerAction.forget,
          enabled: speaker.centroid != null,
          child: const ListTile(
            leading: Icon(Icons.voice_over_off_rounded),
            title: Text(S.forgetVoice),
          ),
        ),
      ],
    );
  }
}
