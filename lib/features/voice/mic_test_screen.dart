// "اختبار المايك" screen (F18): live level with warnings, 5 s test
// recording with playback and a quality summary, plus the distance tip.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/level_meter.dart';
import 'audio_quality.dart';
import 'mic_settings.dart';
import 'mic_test_controller.dart';
import 'strings.dart';

/// Opens the microphone test.
Future<void> openMicTest(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const MicTestScreen()));

/// The microphone-test screen.
class MicTestScreen extends ConsumerWidget {
  /// Creates the screen.
  const MicTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(micTestControllerProvider);
    final ctrl = ref.read(micTestControllerProvider.notifier);
    final theme = Theme.of(context);
    final hintText = switch (state.hint) {
      LiveSignalHint.waiting => VoiceStrings.hintWaiting,
      LiveSignalHint.good => VoiceStrings.hintGood,
      LiveSignalHint.tooQuiet => VoiceStrings.hintTooQuiet,
      LiveSignalHint.clipping => VoiceStrings.hintClipping,
    };
    final warnHint =
        state.hint == LiveSignalHint.tooQuiet ||
        state.hint == LiveSignalHint.clipping;
    final starting = state.phase == MicTestPhase.starting;
    final recordingTest = state.phase == MicTestPhase.recordingTest;
    final playing = state.phase == MicTestPhase.playing;
    return Scaffold(
      appBar: AppBar(title: const Text(VoiceStrings.micTest)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  VoiceStrings.micTestIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                const Card(child: InputDeviceTile()),
                if (showsBluetoothWarning(state.device)) ...[
                  const SizedBox(height: 8),
                  const ErrorBanner(
                    message: VoiceStrings.bluetoothWarning,
                    severity: BannerSeverity.warning,
                  ),
                ],
                if (state.warningAr != null) ...[
                  const SizedBox(height: 8),
                  ErrorBanner(
                    message: state.warningAr!,
                    severity: BannerSeverity.warning,
                  ),
                ],
                if (state.phase == MicTestPhase.error) ...[
                  const SizedBox(height: 8),
                  ErrorBanner(
                    message: state.errorAr ?? S.unexpectedError,
                    onRetry: ctrl.startMonitor,
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LevelMeter(
                          level: state.level,
                          active: state.micOpen,
                          height: 64,
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            recordingTest
                                ? VoiceStrings.recordingTest(state.remainingMs)
                                : state.micOpen
                                ? hintText
                                : '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: warnHint && state.micOpen
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (recordingTest && warnHint) ...[
                          const SizedBox(height: 4),
                          Text(
                            hintText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (state.phase == MicTestPhase.monitoring)
                              OutlinedButton.icon(
                                onPressed: ctrl.stopMonitor,
                                icon: const Icon(Icons.mic_off_rounded),
                                label: const Text(VoiceStrings.stopMonitor),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: starting || recordingTest
                                    ? null
                                    : ctrl.startMonitor,
                                icon: const Icon(Icons.hearing_rounded),
                                label: const Text(VoiceStrings.startMonitor),
                              ),
                            FilledButton.icon(
                              onPressed: starting || recordingTest
                                  ? null
                                  : ctrl.recordTest,
                              icon: const Icon(
                                Icons.fiber_manual_record_rounded,
                              ),
                              label: const Text(VoiceStrings.recordTest),
                            ),
                            if (playing)
                              FilledButton.tonalIcon(
                                onPressed: ctrl.stopPlayback,
                                icon: const Icon(Icons.stop_rounded),
                                label: const Text(VoiceStrings.stopPlayback),
                              )
                            else
                              FilledButton.tonalIcon(
                                onPressed: state.canPlay ? ctrl.play : null,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text(VoiceStrings.playTest),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.result != null) ...[
                  const SizedBox(height: 12),
                  _ResultCard(report: state.result!),
                ],
                const SizedBox(height: 12),
                const Card(child: FarFieldTile()),
                const SizedBox(height: 12),
                const ErrorBanner(
                  message: VoiceStrings.distanceTip,
                  severity: BannerSeverity.info,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.report});

  final AudioQualityReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final silent = report.has(AudioQualityIssueKind.noSpeech);
    final ok = report.issues.isEmpty;
    final lines = <(IconData, Color, String)>[
      if (ok) (Icons.check_circle_rounded, scheme.primary, VoiceStrings.testOk),
      if (silent)
        (Icons.cancel_rounded, scheme.error, VoiceStrings.testSilent)
      else ...[
        (
          Icons.graphic_eq_rounded,
          scheme.onSurfaceVariant,
          VoiceStrings.checkLevel(report.speechDbfs),
        ),
        (
          Icons.waves_rounded,
          scheme.onSurfaceVariant,
          VoiceStrings.noiseLevel(report.noiseDbfs),
        ),
        for (final i in report.issues)
          (
            i.blocking ? Icons.cancel_rounded : Icons.warning_amber_rounded,
            i.blocking ? scheme.error : scheme.tertiary,
            VoiceStrings.issue(i.kind),
          ),
      ],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              VoiceStrings.testResult,
              icon: Icons.fact_check_rounded,
            ),
            for (final (icon, color, text) in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(text)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
