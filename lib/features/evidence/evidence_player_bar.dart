// Mini player for evidence clips (F5): shown under the meeting tabs while a
// clip is open. Play / pause, scrub, replay the clip from its pre-roll,
// speed 1× / 1.5×, the line being heard, and a jump to the transcript line.
//
// Media controls and the timeline stay left-to-right (as in every media
// player, also in Arabic UIs); the text around them follows the app's RTL.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/format.dart';
import '../../ui/strings_ar.dart';
import 'evidence_controller.dart';
import 'evidence_logic.dart';
import 'strings.dart';

/// The evidence player of [meetingId]; collapses to nothing when closed.
class EvidencePlayerBar extends ConsumerStatefulWidget {
  /// Creates the bar.
  const EvidencePlayerBar({super.key, required this.meetingId});

  /// Meeting whose recording is played.
  final String meetingId;

  @override
  ConsumerState<EvidencePlayerBar> createState() => _EvidencePlayerBarState();
}

class _EvidencePlayerBarState extends ConsumerState<EvidencePlayerBar> {
  /// Position under the finger while scrubbing (null when not dragging).
  double? _dragMs;

  EvidenceController get _ctrl =>
      ref.read(evidenceControllerProvider(widget.meetingId).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evidenceControllerProvider(widget.meetingId));
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.bottomCenter,
      child: state.playerVisible && state.target != null
          ? _bar(context, state)
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _bar(BuildContext context, EvidenceState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = state.target!;
    final segments =
        ref.watch(segmentsProvider(widget.meetingId)).value ??
        const <TranscriptSegment>[];
    final speakers =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};
    TranscriptSegment? line;
    for (final s in segments) {
      if (s.id == (state.highlightedSegmentId ?? target.segmentId)) {
        line = s;
        break;
      }
    }
    final speakerName = line?.speakerId == null
        ? null
        : speakers[line!.speakerId]?.name;
    final lineText = line == null
        ? null
        : line.isUnintelligible
        ? S.unintelligibleSegment(line.endMs - line.startMs)
        : line.text.trim();

    final duration = state.durationMs;
    final position = _dragMs?.round() ?? state.positionMs;
    final canScrub = duration != null && duration > 0 && !state.loading;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          [
                            ES.clipTitle(target.segmentIndex),
                            ?speakerName,
                          ].join(' · '),
                          style: theme.textTheme.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (state.loading)
                          Text(ES.loadingAudio, style: labelStyle)
                        else if (lineText != null && lineText.isNotEmpty)
                          Text(
                            lineText,
                            textDirection: detectTextDirection(lineText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: ES.showInTranscript,
                    icon: const Icon(Icons.notes_rounded),
                    onPressed: _ctrl.showInTranscript,
                  ),
                  IconButton(
                    tooltip: ES.closePlayer,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _ctrl.closePlayer,
                  ),
                ],
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 32,
                      child: state.loading
                          ? const Center(child: LinearProgressIndicator())
                          : Semantics(
                              label: ES.seekLabel,
                              child: Slider(
                                min: 0,
                                max: canScrub ? duration.toDouble() : 1,
                                value: canScrub
                                    ? clampSeekMs(position, duration).toDouble()
                                    : 0,
                                semanticFormatterCallback: (v) =>
                                    formatTimestamp(v.round()),
                                onChanged: canScrub
                                    ? (v) => setState(() => _dragMs = v)
                                    : null,
                                onChangeEnd: canScrub
                                    ? (v) {
                                        setState(() => _dragMs = null);
                                        _ctrl.seekTo(v.round());
                                      }
                                    : null,
                              ),
                            ),
                    ),
                    Row(
                      children: [
                        Text(formatTimestamp(position), style: labelStyle),
                        const Spacer(),
                        IconButton(
                          tooltip: ES.replayClip,
                          icon: const Icon(Icons.replay_rounded),
                          onPressed: state.loading ? null : _ctrl.replayClip,
                        ),
                        IconButton.filledTonal(
                          tooltip: state.playing ? ES.pause : ES.play,
                          icon: Icon(
                            state.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          onPressed: state.loading ? null : _ctrl.togglePlay,
                        ),
                        Semantics(
                          button: true,
                          label: ES.speedSemantics(state.speed),
                          excludeSemantics: true,
                          onTap: _ctrl.cycleSpeed,
                          child: Tooltip(
                            message: ES.speedTooltip,
                            child: TextButton(
                              onPressed: _ctrl.cycleSpeed,
                              child: Text(ES.speedLabel(state.speed)),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          duration == null
                              ? '--:--:--'
                              : formatTimestamp(duration),
                          style: labelStyle,
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
    );
  }
}

/// Wraps the meeting-detail tab view: switches to the transcript tab when an
/// evidence chip falls back to the transcript line (or "show in transcript"
/// is pressed), shows the fallback notices, keeps the evidence controller
/// alive across tabs and docks the [EvidencePlayerBar] under [child].
///
/// Place it under the screen's `DefaultTabController` (or pass
/// [tabController]).
class EvidenceScope extends ConsumerWidget {
  /// Creates the scope.
  const EvidenceScope({
    super.key,
    required this.meetingId,
    required this.child,
    this.transcriptTabIndex = 1,
    this.tabController,
    this.showPlayerBar = true,
  });

  /// The meeting.
  final String meetingId;

  /// Usually the `TabBarView` of the meeting screen.
  final Widget child;

  /// Index of the transcript tab.
  final int transcriptTabIndex;

  /// Tab controller; defaults to `DefaultTabController.maybeOf(context)`.
  final TabController? tabController;

  /// Whether to dock the player bar under [child].
  final bool showPlayerBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = evidenceControllerProvider(meetingId);
    ref
      ..listen(provider.select((s) => s.transcriptJumpSerial), (prev, next) {
        if (prev == null || next == prev) return;
        final tabs = tabController ?? DefaultTabController.maybeOf(context);
        if (tabs != null &&
            transcriptTabIndex >= 0 &&
            transcriptTabIndex < tabs.length &&
            tabs.index != transcriptTabIndex) {
          tabs.animateTo(transcriptTabIndex);
        }
      })
      ..listen(provider.select((s) => s.noticeSerial), (prev, next) {
        if (prev == null || next == prev) return;
        final notice = ref.read(provider).noticeAr;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (notice == null || messenger == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(notice),
              duration: const Duration(seconds: 4),
            ),
          );
      });
    if (!showPlayerBar) return child;
    return Column(
      children: [
        Expanded(child: child),
        EvidencePlayerBar(meetingId: meetingId),
      ],
    );
  }
}
