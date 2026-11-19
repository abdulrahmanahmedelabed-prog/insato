// Transcript grouped into speaker turns: speaker chip + LTR timestamp header,
// then each segment's text laid out in its own detected direction (English
// segments LTR, Arabic RTL), tappable for corrections.

import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../format.dart';
import '../strings_ar.dart';
import 'common.dart';
import 'speaker_avatar.dart';

/// Scrollable transcript of [segments] grouped by speaker turns.
class TranscriptView extends StatelessWidget {
  /// Creates the view.
  const TranscriptView({
    super.key,
    required this.segments,
    required this.speakersById,
    this.onSegmentTap,
    this.onSpeakerTap,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
    this.header,
  });

  /// Segments (any order).
  final List<TranscriptSegment> segments;

  /// Speakers by id.
  final Map<String, Speaker> speakersById;

  /// Tap on a segment (reassign / edit).
  final ValueChanged<TranscriptSegment>? onSegmentTap;

  /// Tap on a speaker name (rename).
  final ValueChanged<Speaker>? onSpeakerTap;

  /// Scroll controller (live auto-scroll).
  final ScrollController? controller;

  /// List padding.
  final EdgeInsetsGeometry padding;

  /// Optional widget shown above the first turn.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final turns = groupTurns(segments);
    final extra = header == null ? 0 : 1;
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: turns.length + extra,
      itemBuilder: (context, i) {
        if (i < extra) return header!;
        final turn = turns[i - extra];
        return TranscriptTurnTile(
          key: ValueKey(turn.segments.first.id),
          turn: turn,
          speaker: turn.speakerId == null ? null : speakersById[turn.speakerId],
          onSegmentTap: onSegmentTap,
          onSpeakerTap: onSpeakerTap,
        );
      },
    );
  }
}

/// One speaker turn of a transcript.
class TranscriptTurnTile extends StatelessWidget {
  /// Creates the tile.
  const TranscriptTurnTile({
    super.key,
    required this.turn,
    required this.speaker,
    this.onSegmentTap,
    this.onSpeakerTap,
  });

  /// The turn.
  final TranscriptTurn turn;

  /// Its speaker (null = unknown or deleted).
  final Speaker? speaker;

  /// Segment tap.
  final ValueChanged<TranscriptSegment>? onSegmentTap;

  /// Speaker tap.
  final ValueChanged<Speaker>? onSpeakerTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sp = speaker;
    final tint = sp == null ? scheme.outlineVariant : Color(sp.colorValue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: SpeakerChip(
                  speaker: sp,
                  dense: true,
                  onTap: sp == null || onSpeakerTap == null
                      ? null
                      : () => onSpeakerTap!(sp),
                  tooltip: sp == null ? null : S.renameSpeakerTitle,
                ),
              ),
              const SizedBox(width: 8),
              LtrText(
                formatTimestamp(turn.startMs),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsetsDirectional.only(start: 14),
            padding: const EdgeInsetsDirectional.only(start: 12),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: tint, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final seg in turn.segments)
                  _SegmentText(
                    key: ValueKey(seg.id),
                    segment: seg,
                    speakerName: sp?.name ?? S.unknownSpeaker,
                    onTap: onSegmentTap == null
                        ? null
                        : () => onSegmentTap!(seg),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentText extends StatelessWidget {
  const _SegmentText({
    super.key,
    required this.segment,
    required this.speakerName,
    this.onTap,
  });

  final TranscriptSegment segment;
  final String speakerName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dir = detectTextDirection(segment.text);
    final lang = segment.language;
    final langName = lang == null || lang.startsWith('ar')
        ? null
        : S.languageName(lang);
    return Semantics(
      button: onTap != null,
      label:
          '$speakerName${segment.isSpeakerUncertain ? '، ${S.speakerUncertain}' : ''}، '
          '${formatTimestamp(segment.startMs)}: ${segment.text}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  segment.text,
                  textDirection: dir,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.bodyLarge,
                ),
                if (langName != null ||
                    segment.speakerLocked ||
                    segment.isSpeakerUncertain)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (langName != null)
                          Text(
                            langName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        if (segment.isSpeakerUncertain)
                          Row(
                            key: const ValueKey('speaker-uncertain'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.help_outline_rounded,
                                size: 12,
                                color: scheme.tertiary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                onTap == null
                                    ? S.speakerUncertain
                                    : S.speakerUncertainTapToFix,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        if (segment.speakerLocked)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                S.lockedByUser,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
