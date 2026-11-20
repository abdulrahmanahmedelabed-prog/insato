// Evidence links of the speaker profile (F16 → F5). A profile spans many
// meetings, so each claim shows the meeting it comes from and one chip per
// cited transcript line. Tapping a chip plays that meeting's recording from
// the line (in a player docked under the profile); without the recording it
// shows the cited line itself, with a shortcut to the meeting.
//
// The profile screen owns which meeting is playing (only one at a time) and
// passes [ProfileEvidenceOpener] down to the links.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../evidence/evidence.dart';
import 'strings.dart';

/// Opens the evidence [target] of [meetingId].
typedef ProfileEvidenceOpener = void Function(
  String meetingId,
  EvidenceTarget target,
);

/// Title and date of the meetings that still exist, by id.
final profileMeetingsByIdProvider = Provider.autoDispose<Map<String, Meeting>?>(
  (ref) {
    final list = ref.watch(meetingsProvider).value;
    return list == null ? null : {for (final m in list) m.id: m};
  },
);

/// Label of the meeting [meetingId] («العنوان · التاريخ»), or
/// [PS.deletedMeeting] when it no longer exists.
String profileMeetingLabel(
  Map<String, Meeting>? meetings,
  String meetingId, {
  DateTime? fallbackAt,
}) {
  final m = meetings?[meetingId];
  if (m == null) {
    return meetings == null && fallbackAt != null
        ? formatArabicShortDate(fallbackAt)
        : PS.deletedMeeting;
  }
  return PS.evidenceMeeting(m.title.trim(), m.createdAt);
}

/// The meeting a profile item comes from, followed by its evidence chips.
class ProfileEvidenceLinks extends ConsumerWidget {
  /// Creates the links.
  const ProfileEvidenceLinks({
    super.key,
    required this.meetingId,
    required this.evidence,
    required this.onOpen,
    this.meetingAt,
    this.showMeeting = true,
  });

  /// Meeting whose transcript [evidence] refers to.
  final String meetingId;

  /// Cited `TranscriptSegment.index` values.
  final List<int> evidence;

  /// Called when a chip is tapped.
  final ProfileEvidenceOpener onOpen;

  /// Meeting date stored in the profile (shown while meetings load).
  final DateTime? meetingAt;

  /// Whether to show the meeting label before the chips.
  final bool showMeeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meetings = ref.watch(profileMeetingsByIdProvider);
    final exists = meetings?.containsKey(meetingId) ?? false;
    final label = profileMeetingLabel(
      meetings,
      meetingId,
      fallbackAt: meetingAt,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showMeeting)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  exists ? Icons.event_note_rounded : Icons.event_busy_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          if (exists && evidence.isNotEmpty)
            _ProfileEvidenceChips(
              meetingId: meetingId,
              evidence: evidence,
              onOpen: onOpen,
            ),
        ],
      ),
    );
  }
}

class _ProfileEvidenceChips extends ConsumerStatefulWidget {
  const _ProfileEvidenceChips({
    required this.meetingId,
    required this.evidence,
    required this.onOpen,
  });

  final String meetingId;
  final List<int> evidence;
  final ProfileEvidenceOpener onOpen;

  @override
  ConsumerState<_ProfileEvidenceChips> createState() =>
      _ProfileEvidenceChipsState();
}

class _ProfileEvidenceChipsState extends ConsumerState<_ProfileEvidenceChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final segments =
        ref.watch(segmentsProvider(widget.meetingId)).value ??
        const <TranscriptSegment>[];
    final targets = resolveEvidence(widget.evidence, segments);
    if (targets.isEmpty) return const SizedBox.shrink();
    final speakers =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};
    final playable =
        ref.watch(evidenceAudioStatusProvider(widget.meetingId)).value ==
        EvidenceAudioStatus.available;
    // Watching the controller keeps it (and its audio) alive while the
    // chips are on screen, and marks the clip being played.
    final active = ref.watch(
      evidenceControllerProvider(widget.meetingId)
          .select((s) => s.playerVisible ? s.target?.segmentIndex : null),
    );
    final shown = _expanded || targets.length <= kEvidenceChipsCollapsed + 1
        ? targets
        : targets.take(kEvidenceChipsCollapsed).toList();
    final hidden = targets.length - shown.length;
    return Semantics(
      container: true,
      label: ES.evidenceGroupLabel,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final t in shown)
            _chip(
              context,
              t,
              playable: playable,
              selected: active == t.segmentIndex,
              speakerName: t.speakerId == null
                  ? null
                  : speakers[t.speakerId]?.name,
            ),
          if (hidden > 0)
            Tooltip(
              message: ES.showAllEvidence,
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(ES.moreEvidence(hidden)),
                onPressed: () => setState(() => _expanded = true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    EvidenceTarget t, {
    required bool playable,
    required bool selected,
    required String? speakerName,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tooltip = playable
        ? ES.playFrom(t.startMs)
        : ES.showLineAt(t.startMs);
    void open() => widget.onOpen(widget.meetingId, t);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: ES.chipSemantics(t.segmentIndex, t.startMs, speakerName),
        hint: tooltip,
        excludeSemantics: true,
        onTap: open,
        child: InputChip(
          visualDensity: VisualDensity.compact,
          selected: selected,
          showCheckmark: false,
          avatar: Icon(
            playable ? Icons.play_arrow_rounded : Icons.subject_rounded,
            size: 18,
            color: selected ? scheme.onSecondaryContainer : scheme.primary,
          ),
          label: Text(
            formatTimestamp(t.startMs),
            textDirection: TextDirection.ltr,
            style: theme.textTheme.labelMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          onPressed: open,
        ),
      ),
    );
  }
}

/// Why the cited line is shown instead of the audio, from the evidence
/// controller's notice.
String profileLineSheetReason(String? noticeAr) {
  if (noticeAr == ES.audioStillRecording) return PS.lineSheetRecording;
  if (noticeAr == ES.playbackFailed) return PS.lineSheetFailed;
  return PS.lineSheetNoAudio;
}

/// Shows the cited line [target] of [meetingId] (used when its recording
/// cannot be played). Resolves to true when "open meeting" was chosen.
Future<bool> showProfileEvidenceLineSheet(
  BuildContext context, {
  required String meetingId,
  required EvidenceTarget target,
  required String reason,
}) async {
  final opened = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _LineSheet(meetingId: meetingId, target: target, reason: reason),
  );
  return opened ?? false;
}

class _LineSheet extends ConsumerWidget {
  const _LineSheet({
    required this.meetingId,
    required this.target,
    required this.reason,
  });

  final String meetingId;
  final EvidenceTarget target;
  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final segments =
        ref.watch(segmentsProvider(meetingId)).value ??
        const <TranscriptSegment>[];
    TranscriptSegment? line;
    for (final s in segments) {
      if (s.index == target.segmentIndex) {
        line = s;
        break;
      }
    }
    final speakers =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};
    final speakerName = line?.speakerId == null
        ? null
        : speakers[line!.speakerId]?.name;
    final text = line == null
        ? ES.segmentMissing
        : line.isUnintelligible
        ? S.unintelligibleSegment(line.endMs - line.startMs)
        : line.text.trim();
    final meetings = ref.watch(profileMeetingsByIdProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(PS.lineSheetTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              profileMeetingLabel(meetings, meetingId),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        formatTimestamp(target.startMs),
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (speakerName != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            speakerName,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              reason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text(PS.openMeeting),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
