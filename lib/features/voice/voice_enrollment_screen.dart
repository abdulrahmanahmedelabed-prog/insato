// "إضافة شخص بصوته" (F1): name, reading passage (Arabic / English), live
// level and speech progress, quality checks, then save — or "improve voice"
// for an existing speaker.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../ui/navigation.dart' show openModelsScreen;
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/level_meter.dart';
import 'audio_quality.dart';
import 'enrollment_controller.dart';
import 'enrollment_engine.dart';
import 'enrollment_texts.dart';
import 'strings.dart';
import 'voice_devices.dart';

/// Opens the enrollment screen: a new person, or (with [speaker]) "improve
/// voice" for an existing one. Completes with the saved speaker, or null.
Future<Speaker?> openVoiceEnrollment(
  BuildContext context, {
  Speaker? speaker,
}) => Navigator.of(context).push<Speaker>(
  MaterialPageRoute<Speaker>(
    builder: (_) => VoiceEnrollmentScreen(speaker: speaker),
    fullscreenDialog: true,
  ),
);

/// The enrollment screen.
class VoiceEnrollmentScreen extends ConsumerStatefulWidget {
  /// Creates the screen; with [speaker] it improves that speaker's voiceprint.
  const VoiceEnrollmentScreen({super.key, this.speaker});

  /// Speaker to improve (null = add a new person).
  final Speaker? speaker;

  @override
  ConsumerState<VoiceEnrollmentScreen> createState() =>
      _VoiceEnrollmentScreenState();
}

class _VoiceEnrollmentScreenState extends ConsumerState<VoiceEnrollmentScreen> {
  final TextEditingController _name = TextEditingController();

  bool get _improving => widget.speaker != null;

  /// Improving an auto-named voice also lets the user name it.
  bool get _showName => !_improving || !widget.speaker!.isNamedByUser;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  VoiceEnrollmentController get _ctrl =>
      ref.read(voiceEnrollmentControllerProvider.notifier);

  Future<void> _save({String? speakerId, bool force = false}) async {
    final name = _name.text.trim();
    final saved = await _ctrl.save(
      name: _showName && name.isNotEmpty ? name : null,
      speakerId: speakerId ?? widget.speaker?.id,
      force: force,
    );
    if (saved == null || !mounted) return;
    final improved = (speakerId ?? widget.speaker?.id) != null;
    showSnack(
      context,
      improved
          ? VoiceStrings.savedImproved(saved.name)
          : VoiceStrings.savedNew(saved.name),
    );
    Navigator.of(context).maybePop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceEnrollmentControllerProvider);
    final theme = Theme.of(context);
    final title = _improving
        ? VoiceStrings.improveTitle(widget.speaker!.name)
        : VoiceStrings.enrollTitle;
    return PopScope(
      canPop: !state.isRecording && !state.isBusy,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
          children: [
            ReadableWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _improving
                        ? VoiceStrings.improveIntro
                        : VoiceStrings.enrollIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_showName) ...[
                    TextField(
                      controller: _name,
                      enabled:
                          state.phase != EnrollmentPhase.saving &&
                          state.phase != EnrollmentPhase.saved,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: VoiceStrings.nameLabel,
                        hintText: VoiceStrings.nameHint,
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _PassageCard(state: state),
                  const SizedBox(height: 12),
                  if (state.device != null) _DeviceLine(state: state),
                  if (state.warningAr != null) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(
                      message: state.warningAr!,
                      severity: BannerSeverity.warning,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _RecorderPanel(state: state),
                  const SizedBox(height: 16),
                  ..._phaseContent(context, state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _phaseContent(BuildContext context, EnrollmentState state) {
    switch (state.phase) {
      case EnrollmentPhase.idle:
        return [
          FilledButton.icon(
            onPressed: _ctrl.start,
            icon: const Icon(Icons.mic_rounded),
            label: const Text(VoiceStrings.startRecording),
          ),
        ];
      case EnrollmentPhase.starting:
        return const [Center(child: CircularProgressIndicator())];
      case EnrollmentPhase.recording:
        return [
          FilledButton.tonalIcon(
            onPressed: _ctrl.stop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text(VoiceStrings.stopRecording),
          ),
        ];
      case EnrollmentPhase.analyzing:
        return const [_BusyLine(text: VoiceStrings.analyzing)];
      case EnrollmentPhase.saving:
        return const [_BusyLine(text: VoiceStrings.saving)];
      case EnrollmentPhase.saved:
        return const [];
      case EnrollmentPhase.error:
        return [
          ErrorBanner(
            message: state.errorAr ?? S.unexpectedError,
            onRetry: _ctrl.reset,
            extraAction: state.modelsMissing
                ? TextButton(
                    onPressed: () => openModelsScreen(context),
                    child: const Text(VoiceStrings.openModels),
                  )
                : null,
          ),
        ];
      case EnrollmentPhase.review:
        return _review(context, state);
    }
  }

  List<Widget> _review(BuildContext context, EnrollmentState state) {
    final analysis = state.analysis!;
    final similar = state.similar;
    final conflict = state.nameConflict;
    return [
      _ChecksCard(analysis: analysis),
      const SizedBox(height: 12),
      if (state.errorAr != null) ...[
        ErrorBanner(message: state.errorAr!),
        const SizedBox(height: 12),
      ],
      if (conflict != null) ...[
        ErrorBanner(
          message: VoiceStrings.nameTaken(conflict.name),
          severity: BannerSeverity.warning,
          extraAction: TextButton(
            onPressed: () => _save(speakerId: conflict.id),
            child: const Text(VoiceStrings.improveExisting),
          ),
        ),
        const SizedBox(height: 12),
      ] else if (similar != null) ...[
        ErrorBanner(
          message: similar.speaker.isNamedByUser
              ? VoiceStrings.similarVoice(
                  similar.speaker.name,
                  (similar.similarity * 100).round(),
                )
              : VoiceStrings.similarUnnamedVoice(
                  similar.speaker.name,
                  (similar.similarity * 100).round(),
                ),
          severity: BannerSeverity.info,
          extraAction: Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _save(speakerId: similar.speaker.id),
                child: Text(VoiceStrings.addToSimilar(similar.speaker.name)),
              ),
              TextButton(
                onPressed: () => _save(force: true),
                child: const Text(VoiceStrings.saveAsNewAnyway),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _ctrl.reset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(VoiceStrings.recordAgain),
          ),
          if (analysis.canSave && conflict == null && similar == null)
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text(VoiceStrings.saveVoice),
            ),
        ],
      ),
    ];
  }
}

class _BusyLine extends StatelessWidget {
  const _BusyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _PassageCard extends ConsumerWidget {
  const _PassageCard({required this.state});

  final EnrollmentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ctrl = ref.read(voiceEnrollmentControllerProvider.notifier);
    final locked = state.isRecording || state.isBusy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  VoiceStrings.passageLanguage,
                  style: theme.textTheme.labelLarge,
                ),
                SegmentedButton<EnrollmentLanguage>(
                  segments: const [
                    ButtonSegment(
                      value: EnrollmentLanguage.arabic,
                      label: Text(VoiceStrings.languageArabic),
                    ),
                    ButtonSegment(
                      value: EnrollmentLanguage.english,
                      label: Text(VoiceStrings.languageEnglish),
                    ),
                  ],
                  selected: {state.language},
                  onSelectionChanged: locked
                      ? null
                      : (v) => ctrl.setLanguage(v.first),
                ),
                TextButton.icon(
                  onPressed: locked ? null : ctrl.nextPassage,
                  icon: const Icon(Icons.autorenew_rounded),
                  label: const Text(VoiceStrings.otherPassage),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(VoiceStrings.readAloud, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Directionality(
              textDirection: state.language.isRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: SelectableText(
                state.passage,
                textAlign: TextAlign.start,
                style: theme.textTheme.titleMedium?.copyWith(height: 1.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceLine extends StatelessWidget {
  const _DeviceLine({required this.state});

  final EnrollmentState state;

  @override
  Widget build(BuildContext context) {
    final device = state.device!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              isBluetoothInput(device.type)
                  ? Icons.bluetooth_audio_rounded
                  : Icons.mic_external_on_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                VoiceStrings.recordedOn(device.label),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (isBluetoothInput(device.type)) ...[
          const SizedBox(height: 8),
          const ErrorBanner(
            message: VoiceStrings.bluetoothEnrollWarning,
            severity: BannerSeverity.warning,
          ),
        ],
      ],
    );
  }
}

class _RecorderPanel extends StatelessWidget {
  const _RecorderPanel({required this.state});

  final EnrollmentState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recording = state.isRecording;
    final voicedFraction =
        (state.voicedEstimateMs / const AudioQualityConfig().minVoicedMs).clamp(
          0.0,
          1.0,
        );
    final hintText = switch (state.hint) {
      LiveSignalHint.waiting => VoiceStrings.hintWaiting,
      LiveSignalHint.good => VoiceStrings.hintGood,
      LiveSignalHint.tooQuiet => VoiceStrings.hintTooQuiet,
      LiveSignalHint.clipping => VoiceStrings.hintClipping,
    };
    final keepReading =
        recording &&
        state.elapsedMs >= kEnrollmentTargetMs &&
        state.voicedEstimateMs < kEnrollmentLiveVoicedMs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LevelMeter(level: state.level, active: recording, height: 56),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  recording
                      ? Icons.fiber_manual_record_rounded
                      : Icons.timer_outlined,
                  size: 18,
                  color: recording
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recording ? VoiceStrings.recording : '',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  VoiceStrings.elapsedOf(state.elapsedMs, kEnrollmentTargetMs),
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: VoiceStrings.voicedProgressLabel,
              value: '${(voicedFraction * 100).round()}٪',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: voicedFraction,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              VoiceStrings.voicedProgress(
                state.voicedEstimateMs,
                const AudioQualityConfig().minVoicedMs,
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (recording) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  keepReading ? VoiceStrings.keepReading : hintText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        state.hint == LiveSignalHint.clipping ||
                            state.hint == LiveSignalHint.tooQuiet
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecksCard extends StatelessWidget {
  const _ChecksCard({required this.analysis});

  final EnrollmentAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final q = analysis.quality;
    final vp = analysis.voiceprint;
    final lines = <(bool ok, bool blocking, String text)>[
      (
        !q.has(AudioQualityIssueKind.noSpeech) &&
            !q.has(AudioQualityIssueKind.tooLittleSpeech),
        true,
        VoiceStrings.checkSpeech(q.voicedMs),
      ),
      if (!q.has(AudioQualityIssueKind.noSpeech))
        (
          !q.has(AudioQualityIssueKind.tooQuiet) &&
              !q.has(AudioQualityIssueKind.quiet),
          q.has(AudioQualityIssueKind.tooQuiet),
          VoiceStrings.checkLevel(q.speechDbfs),
        ),
      if (!q.has(AudioQualityIssueKind.clipping) &&
          !q.has(AudioQualityIssueKind.someClipping))
        (true, false, VoiceStrings.checkNoClipping),
      if (vp != null)
        (
          !analysis.voiceIssues.contains(EnrollmentVoiceIssue.inconsistent),
          true,
          VoiceStrings.checkConsistency((vp.consistency * 100).round()),
        ),
      for (final i in q.issues)
        if (i.kind != AudioQualityIssueKind.tooLittleSpeech &&
            i.kind != AudioQualityIssueKind.tooQuiet &&
            i.kind != AudioQualityIssueKind.quiet)
          (false, i.blocking, VoiceStrings.issue(i.kind)),
      for (final i in q.issues)
        if (i.kind == AudioQualityIssueKind.tooLittleSpeech ||
            i.kind == AudioQualityIssueKind.tooQuiet ||
            i.kind == AudioQualityIssueKind.quiet)
          (false, i.blocking, VoiceStrings.issue(i.kind)),
      if (analysis.voiceIssues.contains(EnrollmentVoiceIssue.inconsistent))
        (false, true, VoiceStrings.inconsistentVoice),
      if (analysis.voiceIssues.contains(EnrollmentVoiceIssue.noVoiceprint) &&
          !q.has(AudioQualityIssueKind.noSpeech))
        (false, true, VoiceStrings.noVoiceprint),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              VoiceStrings.checksTitle,
              icon: analysis.canSave
                  ? Icons.verified_rounded
                  : Icons.report_problem_rounded,
            ),
            for (final (ok, blocking, text) in lines)
              _CheckLine(ok: ok, blocking: blocking, text: text),
          ],
        ),
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.ok,
    required this.blocking,
    required this.text,
  });

  final bool ok;
  final bool blocking;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = ok
        ? (Icons.check_circle_rounded, scheme.primary)
        : blocking
        ? (Icons.cancel_rounded, scheme.error)
        : (Icons.warning_amber_rounded, scheme.tertiary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// "Improve voice" menu entry for speaker menus (voice library, meeting
/// speakers tab). Opens the enrollment screen for [speaker].
class ImproveVoiceMenuTile extends StatelessWidget {
  /// Creates the tile (use as a `PopupMenuItem` child).
  const ImproveVoiceMenuTile({super.key});

  @override
  Widget build(BuildContext context) => const ListTile(
    leading: Icon(Icons.record_voice_over_rounded),
    title: Text(VoiceStrings.improveAction),
  );
}

/// "Add a person by voice" button for the voice library.
class EnrollVoiceButton extends StatelessWidget {
  /// Creates the button. [extended] shows the label (floating action
  /// button style).
  const EnrollVoiceButton({super.key, this.extended = true});

  /// Whether the label is shown.
  final bool extended;

  @override
  Widget build(BuildContext context) {
    void open() => openVoiceEnrollment(context);
    return extended
        ? FloatingActionButton.extended(
            heroTag: 'insato-enroll-voice',
            onPressed: open,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text(VoiceStrings.enrollAction),
          )
        : FloatingActionButton(
            heroTag: 'insato-enroll-voice',
            tooltip: VoiceStrings.enrollAction,
            onPressed: open,
            child: const Icon(Icons.person_add_alt_1_rounded),
          );
  }
}
