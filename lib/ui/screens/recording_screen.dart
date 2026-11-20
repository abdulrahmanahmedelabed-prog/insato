// Live recording: large timer, animated level meter, pause / resume, stop
// (confirmed), discard, current speaker, processing backlog, editable title
// and the live transcript, auto-scrolling as speech is transcribed. Also
// the open tasks of expected attendees (F9), the microphone in use (F18;
// a change applies to the next recording), the far-field profile and, on
// Windows only, the audio source (F13).
// Keyboard: Space toggles pause / resume on desktop.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../features/system_audio/audio_source_selector.dart'
    show audioSourceLabel;
import '../../features/system_audio/mixed_session_audio_source.dart'
    show
        SessionAudioMode,
        audioSourceOfMode,
        resolveSessionAudioMode,
        systemAudioSupportedProvider;
import '../../features/consistency/consistency.dart' show LiveConsistencyBanner;
import '../../features/tasks/tasks.dart' show OpenTasksBanner;
import '../../features/voice/mic_capture.dart' show capturePlatformProvider;
import '../../features/multi_device/widgets.dart' show MultiDeviceRecordingCard;
import '../../features/voice/mic_settings.dart' show MicDeviceChip;
import '../../features/voice/strings.dart' show VoiceStrings;
import '../../session/meeting_session_controller.dart';
import '../../session/providers.dart';
import '../navigation.dart';
import '../strings_ar.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/level_meter.dart';
import '../widgets/speaker_avatar.dart';
import '../widgets/transcript_view.dart';

/// The live recording screen. It follows [meetingSessionControllerProvider]
/// and navigates to the meeting once the session finishes.
class RecordingScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final ScrollController _scroll = ScrollController();
  bool _cancelling = false;
  bool _navigated = false;
  int _lastSegmentCount = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  MeetingSessionController get _controller =>
      ref.read(meetingSessionControllerProvider.notifier);

  Future<void> _togglePause() async {
    final s = ref.read(meetingSessionControllerProvider);
    try {
      if (s.phase == SessionPhase.recording) {
        await _controller.pause();
      } else if (s.phase == SessionPhase.paused) {
        await _controller.resume();
      }
    } on InsatoException catch (e) {
      if (mounted) showSnack(context, e.messageAr, error: true);
    }
  }

  Future<void> _stop() async {
    final ok = await showConfirmDialog(
      context,
      title: S.confirmStopTitle,
      body: S.confirmStopBody,
      confirmLabel: S.stop,
      icon: Icons.stop_circle_outlined,
    );
    if (!ok || !mounted) return;
    // Navigation happens in the session listener (also covers a take ended
    // by the system).
    await _controller.stop();
  }

  Future<void> _discard() async {
    final ok = await showConfirmDialog(
      context,
      title: S.confirmDiscardTitle,
      body: S.confirmDiscardBody,
      confirmLabel: S.discard,
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !mounted) return;
    if (!_controller.canDiscard) {
      // The take ended on its own while the dialog was open: the meeting is
      // being saved, and the session listener opens it when done.
      showSnack(context, S.discardTooLate);
      return;
    }
    setState(() => _cancelling = true);
    final discarded = await _controller.cancel();
    if (!mounted) return;
    if (discarded) {
      Navigator.of(context).maybePop();
      return;
    }
    // A stop began meanwhile and the meeting was saved; the listener ignored
    // the finish while _cancelling was set, so open the meeting here.
    setState(() => _cancelling = false);
    showSnack(context, S.discardTooLate);
    final s = ref.read(meetingSessionControllerProvider);
    if (!_navigated &&
        s.phase == SessionPhase.idle &&
        s.lastMeetingId != null) {
      _navigated = true;
      unawaited(
        openMeeting(
          context,
          ref,
          s.lastMeetingId!,
          replace: true,
          replaceRoute: ModalRoute.of(context),
        ),
      );
    }
  }

  void _finishLater() {
    if (!_controller.finishLater() && mounted) {
      showSnack(context, S.finishLaterUnavailable);
    }
  }

  Future<void> _editTitle(String meetingId, String current) async {
    final title = await showTextInputDialog(
      context,
      title: S.editTitle,
      initialValue: current,
      label: S.meetingTitleLabel,
    );
    if (title == null || title.trim().isEmpty || title.trim() == current) {
      return;
    }
    try {
      // The recording bar and this app bar follow the meeting row, so they
      // show the new title at once; the controller also updates the session
      // title and the Android recording notification.
      await _controller.renameMeeting(meetingId, title.trim());
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          e is InsatoException ? e.messageAr : S.unexpectedError,
          error: true,
        );
      }
    }
  }

  void _onSession(SessionState? prev, SessionState next) {
    if (_cancelling || _navigated || !mounted) return;
    final finished =
        prev != null &&
        prev.phase == SessionPhase.finishing &&
        next.phase == SessionPhase.idle &&
        next.lastMeetingId != null;
    if (finished) {
      _navigated = true;
      final warning = next.warningAr;
      // Show the warning before navigating, while this context is current;
      // the snack lives in the root messenger and survives the page swap.
      if (warning != null) {
        showSnack(context, warning);
        _controller.dismissMessage();
      }
      // Replace this screen's own route: the take can end on its own while
      // a confirm / title dialog is open on top of it.
      unawaited(
        openMeeting(
          context,
          ref,
          next.lastMeetingId!,
          replace: true,
          replaceRoute: ModalRoute.of(context),
        ),
      );
    }
  }

  void _autoScroll(int count) {
    if (count == _lastSegmentCount) return;
    _lastSegmentCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      // Follow the transcript only when the user is near the bottom, so
      // reading older text is not interrupted.
      if (pos.maxScrollExtent - pos.pixels < 280) {
        _scroll.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(meetingSessionControllerProvider, _onSession);
    final s = ref.watch(meetingSessionControllerProvider);
    final meetingId = s.meetingId;
    final meeting = meetingId == null
        ? null
        : ref.watch(meetingProvider(meetingId)).value;
    final title = meeting?.title ?? s.title ?? S.recordingTitle;

    final body = switch (s.phase) {
      SessionPhase.error => _ErrorView(
        state: s,
        onClose: () {
          _controller.dismissMessage();
          Navigator.of(context).maybePop();
        },
      ),
      SessionPhase.idle when !_cancelling => _IdleView(
        lastMeetingId: s.lastMeetingId,
      ),
      _ => _buildActive(context, s, meetingId),
    };

    // Space toggles pause / resume only while the screen itself has focus:
    // when a button is focused, Space must activate that button (the
    // app-level ActivateIntent), so the key event is left to bubble on.
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.space &&
            node.hasPrimaryFocus) {
          final phase = ref.read(meetingSessionControllerProvider).phase;
          if (phase == SessionPhase.recording || phase == SessionPhase.paused) {
            unawaited(_togglePause());
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, overflow: TextOverflow.ellipsis),
          actions: [
            if (meetingId != null && s.isCapturing)
              IconButton(
                tooltip: S.editTitle,
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _editTitle(meetingId, title),
              ),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _buildActive(BuildContext context, SessionState s, String? meetingId) {
    final segments = meetingId == null
        ? const <TranscriptSegment>[]
        : ref.watch(segmentsProvider(meetingId)).value ??
              const <TranscriptSegment>[];
    final speakersById =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};
    _autoScroll(segments.length);

    final transcript = segments.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                s.phase == SessionPhase.preparing ? '' : S.listeningHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        : TranscriptView(
            segments: segments,
            speakersById: speakersById,
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          );

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (meetingId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OpenTasksBanner(meetingId: meetingId),
          ),
        if (meetingId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: LiveConsistencyBanner(meetingId: meetingId),
          ),
        const MultiDeviceRecordingCard(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        ),
        _ControlPanel(
          state: s,
          currentSpeaker: s.currentSpeakerId == null
              ? null
              : speakersById[s.currentSpeakerId],
          onDismissWarning: _controller.dismissMessage,
        ),
        _InputLine(session: s),
      ],
    );
    // Pause / Stop / Discard stay pinned below the (scrollable) panel so
    // they can never be pushed off-screen.
    final actions = _ActionButtons(
      state: s,
      onTogglePause: _togglePause,
      onStop: _stop,
      onDiscard: _discard,
    );

    final content = LayoutBuilder(
      builder: (context, c) {
        // Wide screens and short landscape phones: panel beside the
        // transcript.
        final sideBySide =
            c.maxWidth >= InsatoTheme.wideBreakpoint ||
            (c.maxWidth > c.maxHeight && c.maxHeight < 560);
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: math.min(420, c.maxWidth * 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: SingleChildScrollView(child: panel)),
                    actions,
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _TranscriptPane(child: transcript)),
            ],
          );
        }
        // Capped (not Flexible, which would halve the transcript's space
        // even when the panel is small) and scrollable when it is taller.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: c.maxHeight * 0.5),
              child: SingleChildScrollView(child: panel),
            ),
            actions,
            const Divider(height: 1),
            Expanded(child: _TranscriptPane(child: transcript)),
          ],
        );
      },
    );

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (s.phase == SessionPhase.preparing ||
            s.phase == SessionPhase.finishing)
          Positioned.fill(
            child: _BusyOverlay(
              state: s,
              onFinishLater:
                  s.phase == SessionPhase.finishing &&
                      _controller.canFinishLater
                  ? _finishLater
                  : null,
            ),
          ),
      ],
    );
  }
}

/// The microphone chip (tap to change it for the next recording), and
/// chips for the far-field profile and, on Windows, the audio source.
/// Input chips of the recording screen. While a take runs they show what it
/// actually uses (captured at start, updated on a microphone fallback):
/// settings changed meanwhile apply to the next recording only.
class _InputLine extends ConsumerWidget {
  const _InputLine({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsDataProvider).value;
    final platform = ref.watch(capturePlatformProvider);
    final supported = ref.watch(systemAudioSupportedProvider).value ?? true;
    final live = session.isCapturing && session.farField != null;
    final source = live && session.audioSourceInUse != null
        ? session.audioSourceInUse!
        : settings?.audioSource;
    final mode = source == null
        ? null
        : resolveSessionAudioMode(source, platform, systemSupported: supported);
    final farField = live
        ? session.farField!
        : (settings?.farFieldMode ?? false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          if (mode != SessionAudioMode.system)
            MicDeviceChip(inUse: live ? (key: session.inputDeviceKey) : null),
          if (farField)
            const Chip(
              avatar: Icon(Icons.meeting_room_rounded, size: 18),
              label: Text(VoiceStrings.farField),
            ),
          if (mode != null && mode != SessionAudioMode.mic)
            Chip(
              avatar: const Icon(Icons.speaker_rounded, size: 18),
              label: Text(audioSourceLabel(audioSourceOfMode(mode))),
            ),
        ],
      ),
    );
  }
}

class _TranscriptPane extends StatelessWidget {
  const _TranscriptPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
          child: Semantics(
            header: true,
            child: Text(
              S.liveTranscript,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Status part of the controls: warning, state, timer, meter, current
/// speaker, backlog and engine.
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.state,
    required this.currentSpeaker,
    required this.onDismissWarning,
  });

  final SessionState state;
  final Speaker? currentSpeaker;
  final VoidCallback onDismissWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = state;
    final paused = s.phase == SessionPhase.paused;
    final elapsed = formatDuration(s.elapsed.inMilliseconds, alwaysHours: true);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.warningAr != null) ...[
            ErrorBanner(
              severity: BannerSeverity.warning,
              message: s.warningAr!,
              onDismiss: onDismissWarning,
            ),
            const SizedBox(height: 8),
          ],
          _StateLabel(phase: s.phase),
          const SizedBox(height: 4),
          Center(
            child: LtrText(
              elapsed,
              semanticsLabel:
                  '${S.elapsedTime}: ${formatDurationWords(s.elapsed.inMilliseconds)}',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: paused ? scheme.onSurfaceVariant : scheme.onSurface,
                fontFamily: 'NotoSans',
              ),
            ),
          ),
          const SizedBox(height: 8),
          LevelMeter(
            level: s.level,
            active: s.phase == SessionPhase.recording,
            height: 64,
            color: scheme.primary,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                '${S.currentSpeaker}:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (currentSpeaker != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: SpeakerChip(
                    key: ValueKey(currentSpeaker!.id),
                    speaker: currentSpeaker,
                    dense: true,
                  ),
                )
              else
                Text(
                  s.currentSpeakerLabel ?? S.noSpeakerYet,
                  style: theme.textTheme.labelLarge,
                ),
            ],
          ),
          if (s.liveTranscriptionPaused) ...[
            const SizedBox(height: 10),
            Center(
              child: Chip(
                avatar: Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 18,
                  color: scheme.tertiary,
                ),
                label: const Text(S.liveTranscriptionPaused),
              ),
            ),
          ],
          if (s.pendingProcessing > 0 || s.failedSegments > 0) ...[
            const SizedBox(height: 10),
            _Backlog(state: s),
          ],
          if (s.engineDescription != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                S.engine(s.engineDescription!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Discard, pause / resume and stop, kept outside the scrollable panel.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.state,
    required this.onTogglePause,
    required this.onStop,
    required this.onDiscard,
  });

  final SessionState state;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paused = state.phase == SessionPhase.paused;
    final capturing = state.isCapturing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: capturing ? onDiscard : null,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text(S.discardRecording),
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                minimumSize: const Size(0, 52),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: paused ? S.resume : S.pause,
            excludeSemantics: true,
            onTap: capturing ? onTogglePause : null,
            child: SizedBox.square(
              dimension: 76,
              child: FilledButton.tonal(
                onPressed: capturing ? onTogglePause : null,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: capturing ? onStop : null,
              icon: const Icon(Icons.stop_rounded),
              label: const Text(S.stop),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                minimumSize: const Size(0, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateLabel extends StatefulWidget {
  const _StateLabel({required this.phase});

  final SessionPhase phase;

  @override
  State<_StateLabel> createState() => _StateLabelState();
}

class _StateLabelState extends State<_StateLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_StateLabel old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.phase == SessionPhase.recording) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (String label, Color color) = switch (widget.phase) {
      SessionPhase.recording => (S.stateRecording, scheme.error),
      SessionPhase.paused => (S.statePaused, scheme.onSurfaceVariant),
      SessionPhase.preparing => (S.statePreparing, scheme.primary),
      SessionPhase.finishing => (S.stateFinishing, scheme.primary),
      _ => ('', scheme.onSurfaceVariant),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.25, end: 1).animate(_pulse),
            child: Icon(
              widget.phase == SessionPhase.paused
                  ? Icons.pause_circle_filled_rounded
                  : Icons.fiber_manual_record_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Backlog extends StatelessWidget {
  const _Backlog({required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = state;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: s.isProcessingBehind
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.pendingProcessing > 0)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.backlog(s.pendingProcessing, s.pendingAudioMs),
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          if (s.isProcessingBehind) ...[
            const SizedBox(height: 4),
            Text(
              S.processingBehind,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
          if (s.failedSegments > 0) ...[
            const SizedBox(height: 4),
            Text(
              S.failedSegments(s.failedSegments),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.state, this.onFinishLater});

  final SessionState state;

  /// Skips the remaining transcription; null hides the action.
  final VoidCallback? onFinishLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.surface.withValues(alpha: 0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.progress == null)
                    const CircularProgressIndicator()
                  else
                    LinearProgressIndicator(
                      value: state.progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    state.statusAr ??
                        (state.phase == SessionPhase.preparing
                            ? S.statePreparing
                            : S.stateFinishing),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (onFinishLater != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      S.finishLaterHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onFinishLater,
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text(S.finishLater),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.state, required this.onClose});

  final SessionState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final e = state.error;
    final isModel = e is ModelException;
    final isKey = e is MissingApiKeyException;
    return Consumer(
      builder: (context, ref, _) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(
              title: state.meetingId == null && state.lastMeetingId == null
                  ? S.startFailedTitle
                  : null,
              message: state.errorAr ?? S.unexpectedError,
              retryLabel: isModel
                  ? S.openModels
                  : isKey
                  ? S.openSettings
                  : S.close,
              onRetry: () {
                final c = ref.read(meetingSessionControllerProvider.notifier);
                c.dismissMessage();
                if (isModel) {
                  openModelsScreen(context, replace: true);
                } else if (isKey) {
                  openSettingsScreen(context, replace: true);
                } else {
                  onClose();
                }
              },
              extraAction: isModel || isKey
                  ? TextButton(onPressed: onClose, child: const Text(S.close))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _IdleView extends ConsumerWidget {
  const _IdleView({required this.lastMeetingId});

  final String? lastMeetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = lastMeetingId;
    return EmptyState(
      icon: Icons.mic_off_rounded,
      title: S.noActiveRecording,
      action: id == null
          ? TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text(S.close),
            )
          : FilledButton(
              onPressed: () => openMeeting(context, ref, id, replace: true),
              child: const Text(S.openMeeting),
            ),
    );
  }
}
