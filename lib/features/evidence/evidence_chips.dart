// ▶ evidence chips under a minutes item (topic, decision, action item, code
// finding, agenda coverage…): one chip per cited transcript segment, labelled
// with its timestamp. Tapping plays the recording from the segment (1 s
// pre-roll) or, without the audio, jumps to the transcript line.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import 'evidence_controller.dart';
import 'evidence_logic.dart';
import 'strings.dart';

/// Whether the recording of a meeting can be played (drives the chip icon
/// and tooltip). Re-evaluated whenever the meeting row changes.
final evidenceAudioStatusProvider = FutureProvider.autoDispose
    .family<EvidenceAudioStatus, String>((ref, meetingId) async {
      // Re-check when the meeting changes (audio deleted, recording ended).
      ref.watch(meetingProvider(meetingId));
      try {
        return (await ref.read(evidenceAudioResolverProvider)(meetingId))
            .status;
      } catch (_) {
        return EvidenceAudioStatus.notKept;
      }
    });

/// Evidence chips of one minutes item of [meetingId].
///
/// Renders nothing when [evidence] is empty or cites no existing segment.
class EvidenceChips extends ConsumerStatefulWidget {
  /// Creates the chips.
  const EvidenceChips({
    super.key,
    required this.meetingId,
    required this.evidence,
    this.padding = const EdgeInsets.only(top: 6),
  });

  /// Meeting whose transcript the ids refer to.
  final String meetingId;

  /// Cited `TranscriptSegment.index` values.
  final List<int> evidence;

  /// Space around the chip row.
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<EvidenceChips> createState() => _EvidenceChipsState();
}

class _EvidenceChipsState extends ConsumerState<EvidenceChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.evidence.isEmpty) return const SizedBox.shrink();
    final segments =
        ref.watch(segmentsProvider(widget.meetingId)).value ??
        const <TranscriptSegment>[];
    final targets = resolveEvidence(widget.evidence, segments);
    if (targets.isEmpty) return const SizedBox.shrink();
    final speakers =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};
    final audio = ref.watch(evidenceAudioStatusProvider(widget.meetingId));
    final playable = audio.value == EvidenceAudioStatus.available;
    final active = ref.watch(
      evidenceControllerProvider(widget.meetingId).select(
        (s) => (
          index: s.target?.segmentIndex,
          visible: s.playerVisible,
          highlighted: s.highlightedSegmentIndex,
        ),
      ),
    );

    final shown = _expanded || targets.length <= kEvidenceChipsCollapsed + 1
        ? targets
        : targets.take(kEvidenceChipsCollapsed).toList();
    final hidden = targets.length - shown.length;

    return Padding(
      padding: widget.padding,
      child: Semantics(
        container: true,
        label: ES.evidenceGroupLabel,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final t in shown)
              _EvidenceChip(
                target: t,
                playable: playable,
                selected: active.visible
                    ? active.index == t.segmentIndex
                    : active.highlighted == t.segmentIndex,
                speakerName: t.speakerId == null
                    ? null
                    : speakers[t.speakerId]?.name,
                onPressed: () => ref
                    .read(evidenceControllerProvider(widget.meetingId).notifier)
                    .open(t),
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
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip({
    required this.target,
    required this.playable,
    required this.selected,
    required this.speakerName,
    required this.onPressed,
  });

  final EvidenceTarget target;
  final bool playable;
  final bool selected;
  final String? speakerName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tooltip = playable
        ? ES.playFrom(target.startMs)
        : ES.showLineAt(target.startMs);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: ES.chipSemantics(
          target.segmentIndex,
          target.startMs,
          speakerName,
        ),
        hint: tooltip,
        excludeSemantics: true,
        onTap: onPressed,
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
            formatTimestamp(target.startMs),
            textDirection: TextDirection.ltr,
            style: theme.textTheme.labelMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
