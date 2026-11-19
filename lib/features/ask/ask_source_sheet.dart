// The source of a citation in "Ask your meetings" (F8 → F5): a bottom sheet
// that shows the cited moment in its meeting — the cited line with two lines
// of context on each side — plays the recording from that line (when it was
// kept) and offers to open the whole meeting.
//
// Playback goes through the evidence controller of the meeting (F5), so the
// pre-roll, speed and failure handling are the same as on the minutes'
// evidence chips. The sheet watches that controller: closing the sheet stops
// the audio.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../data/repositories.dart'
    show segmentsProvider, speakersByIdProvider;
import '../../minutes/minutes_prompt.dart' show kUnknownSpeakerName;
import '../../ui/format.dart' show ltrIsolate;
import '../../ui/strings_ar.dart';
import '../evidence/evidence.dart';
import 'ask_answer.dart';
import 'strings.dart';

/// Lines of context shown on each side of the cited line.
const int kAskExcerptRadius = 2;

/// The excerpt around a cited segment.
class AskExcerpt {
  /// Creates an excerpt.
  const AskExcerpt({required this.lines, required this.cited});

  /// Lines with content, in transcript order.
  final List<TranscriptSegment> lines;

  /// Position of the cited line in [lines], or -1 when it no longer exists.
  final int cited;

  /// True when the cited line still exists.
  bool get found => cited >= 0;
}

/// Picks the cited segment [segmentIndex] of [segments] (any order) with
/// [radius] lines of content on each side. When the segment no longer
/// exists, the excerpt is empty and [AskExcerpt.found] is false.
AskExcerpt askExcerptAround(
  List<TranscriptSegment> segments,
  int segmentIndex, {
  int radius = kAskExcerptRadius,
}) {
  final sorted = [
    for (final s in segments)
      if (s.hasContent || s.index == segmentIndex) s,
  ]..sort((a, b) => a.index.compareTo(b.index));
  final pos = sorted.indexWhere((s) => s.index == segmentIndex);
  if (pos < 0) return const AskExcerpt(lines: [], cited: -1);
  final first = (pos - radius).clamp(0, sorted.length - 1);
  final last = (pos + radius).clamp(0, sorted.length - 1);
  return AskExcerpt(lines: sorted.sublist(first, last + 1), cited: pos - first);
}

/// The sheet's own wording of an evidence controller notice (the
/// controller's notices refer to the meeting's transcript tab).
String askSourceNotice(String notice) {
  if (notice == ES.audioNotKept) return AS.sourceNoAudio;
  if (notice == ES.audioStillRecording) return AS.sourceStillRecording;
  if (notice == ES.playbackFailed) return AS.sourcePlaybackFailed;
  if (notice == ES.segmentMissing) return AS.sourceSegmentMissing;
  return notice;
}

/// Shows the source of [citation] (which must cite a segment). Resolves to
/// true when the user chose to open the meeting.
Future<bool> showAskSourceSheet(
  BuildContext context,
  AskCitation citation,
) async {
  final open = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AskSourceSheet(citation: citation),
  );
  return open ?? false;
}

/// Body of [showAskSourceSheet].
class AskSourceSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const AskSourceSheet({super.key, required this.citation});

  /// The citation (with a segment).
  final AskCitation citation;

  @override
  ConsumerState<AskSourceSheet> createState() => _AskSourceSheetState();
}

class _AskSourceSheetState extends ConsumerState<AskSourceSheet> {
  String? _notice;

  AskCitation get _c => widget.citation;

  Future<void> _play() async {
    final segment = _c.segmentIndex;
    if (segment == null) return;
    final provider = evidenceControllerProvider(_c.meetingId);
    final state = ref.read(provider);
    final controller = ref.read(provider.notifier);
    setState(() => _notice = null);
    if (state.playerVisible &&
        state.target?.segmentIndex == segment &&
        !state.loading) {
      await controller.togglePlay();
    } else {
      await controller.openIndex(segment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = evidenceControllerProvider(_c.meetingId);
    ref.listen(provider.select((s) => s.noticeSerial), (prev, next) {
      final notice = ref.read(provider).noticeAr;
      if (prev != next && notice != null) {
        setState(() => _notice = askSourceNotice(notice));
      }
    });
    // Watching the controller keeps it (and its audio) alive while the
    // sheet is open.
    final player = ref.watch(provider);
    final playable =
        ref.watch(evidenceAudioStatusProvider(_c.meetingId)).value ==
        EvidenceAudioStatus.available;
    final segmentsAsync = ref.watch(segmentsProvider(_c.meetingId));
    final speakers =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};
    final segment = _c.segmentIndex;
    final excerpt = segment == null || segmentsAsync.value == null
        ? null
        : askExcerptAround(segmentsAsync.value!, segment);
    final heard = player.playerVisible ? player.highlightedSegmentIndex : null;
    final active =
        player.playerVisible && player.target?.segmentIndex == segment;
    final ts = _c.timestamp;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _c.meetingTitle,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            [
              AS.sourceDate(_c.meetingDate),
              if (ts != null) ltrIsolate(ts),
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AS.excerptLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (excerpt == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!excerpt.found)
            Text(AS.sourceSegmentMissing, style: theme.textTheme.bodyMedium)
          else
            for (var i = 0; i < excerpt.lines.length; i++)
              _ExcerptLine(
                segment: excerpt.lines[i],
                speakerName: speakers[excerpt.lines[i].speakerId]?.name,
                cited: i == excerpt.cited,
                heard: heard == excerpt.lines[i].index,
              ),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _notice!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (playable && excerpt != null && excerpt.found)
                FilledButton.tonalIcon(
                  onPressed: active && player.loading ? null : _play,
                  icon: active && player.loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          active && player.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    active && player.playing
                        ? AS.pauseSource(player.positionMs)
                        : AS.playFromHere,
                  ),
                ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text(AS.openMeeting),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExcerptLine extends StatelessWidget {
  const _ExcerptLine({
    required this.segment,
    required this.speakerName,
    required this.cited,
    required this.heard,
  });

  final TranscriptSegment segment;
  final String? speakerName;
  final bool cited;
  final bool heard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = speakerName?.trim() ?? '';
    final text = segment.isUnintelligible
        ? S.unintelligibleSegment(segment.endMs - segment.startMs)
        : segment.text.trim();
    final emphasised = cited || heard;
    return Semantics(
      container: true,
      selected: cited,
      label: cited ? AS.citedLine : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: heard
              ? scheme.secondaryContainer
              : cited
              ? scheme.surfaceContainerHigh
              : null,
          borderRadius: BorderRadius.circular(8),
          border: BorderDirectional(
            start: BorderSide(
              color: cited ? scheme.primary : scheme.outlineVariant,
              width: cited ? 3 : 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${name.isEmpty ? kUnknownSpeakerName : name} · '
              '${ltrIsolate(formatTimestamp(segment.startMs))}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              text,
              style:
                  (emphasised
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(
                        fontStyle: segment.isUnintelligible
                            ? FontStyle.italic
                            : null,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
