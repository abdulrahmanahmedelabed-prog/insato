// Transcript with evidence focus (F5): the same speaker-turn layout as the
// shared `TranscriptView`, plus a highlighted line (the evidence segment or
// the line being heard) that the list scrolls to on request, and a
// long-press "listen from here". Also an evidence-aware replacement of the
// meeting's "النص الكامل" tab.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/actions.dart';
import '../../ui/format.dart';
import '../../ui/screens/meeting_transcript_tab.dart' show showSegmentSheet;
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/speaker_avatar.dart';
import 'evidence_controller.dart';
import 'evidence_logic.dart';
import 'strings.dart';

/// The meeting's full transcript with evidence highlight and scrolling: a
/// drop-in replacement of `MeetingTranscriptTab` (same corrections sheet
/// and speaker renaming).
class EvidenceTranscriptTab extends ConsumerWidget {
  /// Creates the tab.
  const EvidenceTranscriptTab({super.key, required this.meetingId});

  /// Meeting shown.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(segmentsProvider(meetingId));
    final speakers =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};
    return segments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(
          message: S.unexpectedError,
          onRetry: () => ref.invalidate(segmentsProvider(meetingId)),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.notes_rounded,
            title: S.noTranscriptTitle,
            body: S.noTranscriptBody,
          );
        }
        return ReadableWidth(
          child: EvidenceTranscriptView(
            meetingId: meetingId,
            segments: list,
            speakersById: speakers,
            onSegmentTap: (seg) => showSegmentSheet(context, seg),
            onSpeakerTap: (sp) => renameSpeakerFlow(context, ref, sp),
            onSegmentLongPress: (seg) => ref
                .read(evidenceControllerProvider(meetingId).notifier)
                .open(EvidenceTarget.of(seg)),
          ),
        );
      },
    );
  }
}

/// Scrollable transcript of [segments] grouped by speaker turns, with the
/// evidence line of [meetingId] highlighted and scrolled into view.
class EvidenceTranscriptView extends ConsumerStatefulWidget {
  /// Creates the view.
  const EvidenceTranscriptView({
    super.key,
    required this.meetingId,
    required this.segments,
    required this.speakersById,
    this.onSegmentTap,
    this.onSegmentLongPress,
    this.onSpeakerTap,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
    this.header,
  });

  /// Meeting whose evidence state drives the highlight.
  final String meetingId;

  /// Segments (any order).
  final List<TranscriptSegment> segments;

  /// Speakers by id.
  final Map<String, Speaker> speakersById;

  /// Tap on a segment (corrections).
  final ValueChanged<TranscriptSegment>? onSegmentTap;

  /// Long press on a segment (listen from here).
  final ValueChanged<TranscriptSegment>? onSegmentLongPress;

  /// Tap on a speaker name (rename).
  final ValueChanged<Speaker>? onSpeakerTap;

  /// List padding.
  final EdgeInsetsGeometry padding;

  /// Optional widget shown above the first turn.
  final Widget? header;

  @override
  ConsumerState<EvidenceTranscriptView> createState() =>
      _EvidenceTranscriptViewState();
}

class _EvidenceTranscriptViewState
    extends ConsumerState<EvidenceTranscriptView> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _segmentKeys = {};
  final Map<int, GlobalKey> _turnKeys = {};
  List<TranscriptTurn> _turns = const [];
  List<List<String>> _turnIds = const [];
  int _scrollRequest = 0;

  @override
  void initState() {
    super.initState();
    _rebuildTurns();
    final s = ref.read(evidenceControllerProvider(widget.meetingId));
    final id = s.highlightedSegmentId;
    if (id != null && s.focusSerial > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_scrollTo(id, precise: true));
      });
    }
  }

  @override
  void didUpdateWidget(EvidenceTranscriptView old) {
    super.didUpdateWidget(old);
    if (!identical(old.segments, widget.segments)) _rebuildTurns();
  }

  @override
  void dispose() {
    _scrollRequest++;
    _scroll.dispose();
    super.dispose();
  }

  void _rebuildTurns() {
    _turns = groupTurns(widget.segments);
    _turnIds = [
      for (final t in _turns) [for (final s in t.segments) s.id],
    ];
    final live = {for (final s in widget.segments) s.id};
    _segmentKeys.removeWhere((id, _) => !live.contains(id));
    _turnKeys.removeWhere((i, _) => i >= _turns.length);
  }

  GlobalKey _keyOfSegment(String id) =>
      _segmentKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'seg-$id'));

  GlobalKey _keyOfTurn(int i) =>
      _turnKeys.putIfAbsent(i, () => GlobalKey(debugLabel: 'turn-$i'));

  /// Brings the line [segmentId] into view. [precise] centres it about a
  /// third down the viewport, searching the lazy list when it is not built;
  /// otherwise it only scrolls when an already-built line leaves the view
  /// (following playback without yanking a user who scrolled away).
  Future<void> _scrollTo(String segmentId, {required bool precise}) async {
    final request = ++_scrollRequest;
    final turn = turnIndexOfSegment(_turnIds, segmentId);
    if (turn < 0) return;
    final extra = widget.header == null ? 0 : 1;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 300);
    for (var attempt = 0; attempt < 16; attempt++) {
      if (!mounted || request != _scrollRequest) return;
      final ctx = _segmentKeys[segmentId]?.currentContext;
      if (ctx != null) {
        if (!ctx.mounted) return;
        if (precise) {
          await Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: duration,
            curve: Curves.easeOutCubic,
          );
        } else {
          await Scrollable.ensureVisible(
            ctx,
            duration: duration,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
          if (!ctx.mounted) return;
          await Scrollable.ensureVisible(
            ctx,
            duration: duration,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        }
        return;
      }
      if (!precise || !_scroll.hasClients) return;
      final pos = _scroll.position;
      double? target;
      if (attempt == 0) {
        target = estimateScrollOffset(
          index: turn + extra,
          count: _turns.length + extra,
          maxScrollExtent: pos.maxScrollExtent,
          viewportHeight: pos.viewportDimension,
        );
      } else {
        var builtMin = -1;
        var builtMax = -1;
        for (final e in _turnKeys.entries) {
          if (e.value.currentContext == null) continue;
          if (builtMin < 0 || e.key < builtMin) builtMin = e.key;
          if (e.key > builtMax) builtMax = e.key;
        }
        if (builtMin < 0) return;
        target = nextScrollProbe(
          target: turn,
          builtMin: builtMin,
          builtMax: builtMax,
          currentOffset: pos.pixels,
          viewportHeight: pos.viewportDimension,
          maxScrollExtent: pos.maxScrollExtent,
        );
        // Built range covers the turn but its line is not laid out yet:
        // wait one more frame.
      }
      if (target != null) _scroll.jumpTo(target);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = evidenceControllerProvider(widget.meetingId);
    final focus = ref.watch(
      provider.select(
        (s) => (
          id: s.highlightedSegmentId,
          serial: s.focusSerial,
          playing: s.playing,
        ),
      ),
    );
    ref.listen(
      provider.select(
        (s) => (id: s.highlightedSegmentId, serial: s.focusSerial),
      ),
      (prev, next) {
        final id = next.id;
        if (id == null) return;
        final precise = prev == null || prev.serial != next.serial;
        if (!precise && prev.id == id) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_scrollTo(id, precise: precise));
        });
      },
    );
    final extra = widget.header == null ? 0 : 1;
    return ListView.builder(
      controller: _scroll,
      padding: widget.padding,
      itemCount: _turns.length + extra,
      itemBuilder: (context, i) {
        if (i < extra) return widget.header!;
        final index = i - extra;
        final turn = _turns[index];
        return KeyedSubtree(
          key: _keyOfTurn(index),
          child: EvidenceTurnTile(
            key: ValueKey(turn.segments.first.id),
            turn: turn,
            speaker: turn.speakerId == null
                ? null
                : widget.speakersById[turn.speakerId],
            highlightedSegmentId: focus.id,
            playing: focus.playing,
            segmentKey: _keyOfSegment,
            onSegmentTap: widget.onSegmentTap,
            onSegmentLongPress: widget.onSegmentLongPress,
            onSpeakerTap: widget.onSpeakerTap,
          ),
        );
      },
    );
  }
}

/// One speaker turn with an optionally highlighted line.
class EvidenceTurnTile extends StatelessWidget {
  /// Creates the tile.
  const EvidenceTurnTile({
    super.key,
    required this.turn,
    required this.speaker,
    this.highlightedSegmentId,
    this.playing = false,
    this.segmentKey,
    this.onSegmentTap,
    this.onSegmentLongPress,
    this.onSpeakerTap,
  });

  /// The turn.
  final TranscriptTurn turn;

  /// Its speaker (null = unknown or deleted).
  final Speaker? speaker;

  /// Line to highlight (may belong to another turn).
  final String? highlightedSegmentId;

  /// Whether the highlighted line is being heard.
  final bool playing;

  /// Key of each line (for scrolling); null = plain value keys.
  final Key Function(String segmentId)? segmentKey;

  /// Segment tap.
  final ValueChanged<TranscriptSegment>? onSegmentTap;

  /// Segment long press.
  final ValueChanged<TranscriptSegment>? onSegmentLongPress;

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
                  EvidenceSegmentLine(
                    key: segmentKey?.call(seg.id) ?? ValueKey(seg.id),
                    segment: seg,
                    speakerName: sp?.name ?? S.unknownSpeaker,
                    highlighted: seg.id == highlightedSegmentId,
                    playing: playing && seg.id == highlightedSegmentId,
                    onTap: onSegmentTap == null
                        ? null
                        : () => onSegmentTap!(seg),
                    onLongPress: onSegmentLongPress == null
                        ? null
                        : () => onSegmentLongPress!(seg),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One transcript line, highlighted when it is the evidence focus.
class EvidenceSegmentLine extends StatelessWidget {
  /// Creates the line.
  const EvidenceSegmentLine({
    super.key,
    required this.segment,
    required this.speakerName,
    this.highlighted = false,
    this.playing = false,
    this.onTap,
    this.onLongPress,
  });

  /// The segment.
  final TranscriptSegment segment;

  /// Name read by screen readers.
  final String speakerName;

  /// Whether this is the evidence / playback line.
  final bool highlighted;

  /// Whether the line is being heard right now.
  final bool playing;

  /// Tap action.
  final VoidCallback? onTap;

  /// Long-press action.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unintelligible = segment.isUnintelligible;
    final shown = unintelligible
        ? [
            S.unintelligibleSegment(segment.endMs - segment.startMs),
            if (segment.text.trim().isNotEmpty) '«${segment.text.trim()}»',
          ].join(' ')
        : segment.text;
    final dir = detectTextDirection(shown);
    final lang = segment.language;
    final langName = unintelligible || lang == null || lang.startsWith('ar')
        ? null
        : S.languageName(lang);
    final baseStyle = unintelligible
        ? theme.textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: scheme.onSurfaceVariant,
          )
        : theme.textTheme.bodyLarge;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: onTap != null,
      selected: highlighted,
      label: [
        if (highlighted) ES.highlightedLine,
        '$speakerName، ${formatTimestamp(segment.startMs)}: $shown',
      ].join('، '),
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null ? null : ES.play,
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.tertiaryContainer.withValues(alpha: 0.7)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            shown,
                            textDirection: dir,
                            textAlign: TextAlign.start,
                            style: highlighted
                                ? baseStyle?.copyWith(
                                    color: scheme.onTertiaryContainer,
                                  )
                                : baseStyle,
                          ),
                          if (langName != null || segment.speakerLocked)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  if (langName != null)
                                    Text(
                                      langName,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
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
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
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
                    if (playing)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: Icon(
                          Icons.volume_up_rounded,
                          size: 18,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
