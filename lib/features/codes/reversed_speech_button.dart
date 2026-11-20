// «حاول فك الكلام المعكوس»: starts the reversed-speech post-processing of a
// meeting (F17) and shows its progress and outcome inline.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../evidence/evidence.dart';
import 'reversed_speech.dart';
import 'strings.dart';

/// Button + progress of the reversed-speech run of [meetingId]. Disabled
/// (with the reason) when the audio was not kept, the meeting has no
/// unintelligible segment, or the meeting is being recorded / processed.
class ReversedSpeechButton extends ConsumerWidget {
  /// Creates the button.
  const ReversedSpeechButton({super.key, required this.meetingId});

  /// The meeting.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = reversedSpeechControllerProvider(meetingId);
    final state = ref.watch(provider);
    final segments =
        ref.watch(segmentsProvider(meetingId)).value ??
        const <TranscriptSegment>[];
    final count = segments.where((s) => s.isUnintelligible).length;
    final audio = ref.watch(evidenceAudioStatusProvider(meetingId)).value;
    final jobRunning = ref.watch(
      meetingJobsProvider(meetingId).select((j) => j.isRunning),
    );

    String? blocked;
    if (count == 0) {
      blocked = KS.reverseNothing;
    } else if (audio == EvidenceAudioStatus.recording || jobRunning) {
      blocked = KS.reverseBusy;
    } else if (audio == EvidenceAudioStatus.notKept) {
      blocked = KS.reverseNoAudio;
    }
    final canStart = !state.isRunning && blocked == null && audio != null;

    final children = <Widget>[];
    if (state.isRunning) {
      final p = state.progress;
      children.addAll([
        Semantics(
          liveRegion: true,
          child: Text(
            p?.statusAr ?? KS.reverseLoading,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: p?.fraction,
          semanticsLabel: KS.reverseButton,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => ref.read(provider.notifier).cancel(),
            child: const Text(KS.reverseCancel),
          ),
        ),
      ]);
    } else {
      children.add(
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Tooltip(
            message: blocked ?? KS.reverseHint,
            child: FilledButton.tonalIcon(
              onPressed: canStart
                  ? () => ref.read(provider.notifier).start()
                  : null,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text(KS.reverseButton),
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 6));
      children.add(
        Text(
          blocked ?? KS.reverseHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
      final report = state.report;
      final message = switch (state.phase) {
        ReversedSpeechPhase.done when report != null =>
          report.cancelled
              ? KS.reverseCancelled
              : KS.reverseDone(report.analysed, report.found, report.failed),
        ReversedSpeechPhase.failed => state.errorAr ?? S.unexpectedError,
        _ => null,
      };
      if (message != null) {
        final failed = state.phase == ReversedSpeechPhase.failed;
        children.addAll([
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  failed
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: failed ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: failed ? scheme.error : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: S.dismiss,
                  onPressed: () => ref.read(provider.notifier).clear(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ]);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
