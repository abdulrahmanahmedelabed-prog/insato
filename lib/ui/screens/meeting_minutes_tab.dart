// "المحضر" tab: rendered minutes with a regenerate button, streaming
// generation progress, errors with retry, and the API-key prompt.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/post_processor.dart';
import '../../session/providers.dart';
import '../navigation.dart';
import '../strings_ar.dart';
import '../ui_providers.dart';
import '../widgets/common.dart';
import '../widgets/minutes_view.dart';

/// Minutes of [meeting] and their generation controls.
class MeetingMinutesTab extends ConsumerWidget {
  /// Creates the tab.
  const MeetingMinutesTab({super.key, required this.meeting});

  /// The meeting.
  final Meeting meeting;

  void _generate(WidgetRef ref) {
    unawaited(
      ref.read(meetingJobsProvider(meeting.id).notifier).generateMinutes(),
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    await openSettingsScreen(context);
    ref.invalidate(anthropicKeyConfiguredProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(meetingJobsProvider(meeting.id));
    final session = ref.watch(meetingSessionControllerProvider);
    final keyConfigured = ref.watch(anthropicKeyConfiguredProvider).value;
    final isLive = session.isActive && session.meetingId == meeting.id;
    final minutesJob = job.kind == MeetingJobKind.minutes;
    final generating = minutesJob && job.isRunning;
    final otherJobRunning = job.isRunning && !minutesJob;
    final minutes = meeting.minutes;

    final children = <Widget>[];

    if (generating) {
      children.add(_GeneratingCard(job: job));
    } else if (minutesJob && job.phase == MeetingJobPhase.failed) {
      children.add(
        ErrorBanner(
          message: job.errorAr ?? S.unexpectedError,
          onRetry: job.needsApiKey ? null : () => _generate(ref),
          extraAction: job.needsApiKey
              ? FilledButton.tonal(
                  onPressed: () => _openSettings(context, ref),
                  child: const Text(S.addApiKey),
                )
              : null,
          onDismiss: () =>
              ref.read(meetingJobsProvider(meeting.id).notifier).clear(),
        ),
      );
    } else if (minutesJob &&
        job.phase == MeetingJobPhase.succeeded &&
        job.needsApiKey &&
        job.noticeAr != null) {
      children.add(
        ErrorBanner(
          severity: BannerSeverity.info,
          message: job.noticeAr!,
          extraAction: FilledButton.tonal(
            onPressed: () => _openSettings(context, ref),
            child: const Text(S.addApiKey),
          ),
          onDismiss: () =>
              ref.read(meetingJobsProvider(meeting.id).notifier).clear(),
        ),
      );
    } else if (meeting.status == MeetingStatus.failed &&
        meeting.errorMessage != null) {
      children.add(
        ErrorBanner(
          message: meeting.errorMessage!,
          onRetry: isLive || otherJobRunning ? null : () => _generate(ref),
        ),
      );
    } else if (meeting.status == MeetingStatus.processing && !isLive) {
      children.add(
        const ErrorBanner(
          severity: BannerSeverity.info,
          message: S.meetingProcessing,
        ),
      );
    }

    if (keyConfigured == false && minutes == null && !job.needsApiKey) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ErrorBanner(
            severity: BannerSeverity.warning,
            title: S.apiKeyMissingTitle,
            message: S.apiKeyMissingBody,
            extraAction: FilledButton.tonal(
              onPressed: () => _openSettings(context, ref),
              child: const Text(S.addApiKey),
            ),
          ),
        ),
      );
    }

    final canGenerate = !isLive && !job.isRunning;
    if (minutes != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 12,
            children: [
              Text(
                S.regenerateHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              OutlinedButton.icon(
                onPressed: canGenerate ? () => _generate(ref) : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(S.regenerateMinutes),
              ),
            ],
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
      children.add(MinutesView(meeting: meeting, minutes: minutes));
    } else if (!generating) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: EmptyState(
            icon: Icons.description_outlined,
            title: isLive ? S.meetingStillRecording : S.noMinutesTitle,
            body: isLive ? null : S.noMinutesBody,
            action: isLive
                ? null
                : FilledButton.icon(
                    onPressed: canGenerate ? () => _generate(ref) : null,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text(S.generateMinutes),
                  ),
          ),
        ),
      );
    }

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratingCard extends StatelessWidget {
  const _GeneratingCard({required this.job});

  final MeetingJobState job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      job.statusAr ?? S.meetingProcessing,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: job.progress > 0 ? job.progress : null,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
