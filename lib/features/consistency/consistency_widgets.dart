// UI of the contradiction & consistency checker (v1.2, D):
//
// * [ConsistencyTab] — the «التناقضات» tab of the meeting screen: run the
//   check, each finding with both sides (meeting, number, Hijri and
//   Gregorian date, resolution label, evidence), dismiss / «تم الإلغاء
//   رسمياً» / undo;
// * [SupersededResolutionsCard] — on the earlier meeting's minutes tab:
//   its resolutions annotated «أُلغي رسمياً» (approved minutes are never
//   edited);
// * [LiveConsistencyBanner] — the subtle banner of the live check on the
//   recording screen (off by default);
// * [ConsistencyLiveSettingTile] — the live-mode switch in Settings.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../data/consistency_repository.dart';
import '../../data/official_repository.dart' show officialRecordProvider;
import '../../data/repositories.dart' show meetingProvider;
import '../../ui/navigation.dart' show openMeeting;
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import '../ask/ask_answer.dart' show AskCitation;
import '../ask/ask_screen.dart' show openAskCitation;
import '../evidence/evidence.dart' show EvidenceChips;
import '../official/official_document.dart' show bothDatesText;
import '../official/official_models.dart' show decisionKeyOf;
import 'consistency_models.dart';
import 'consistency_providers.dart';
import 'strings.dart';

/// Colour of a severity.
Color severityColor(ColorScheme scheme, FindingSeverity s) => switch (s) {
  FindingSeverity.high => scheme.error,
  FindingSeverity.medium => scheme.tertiary,
  FindingSeverity.low => scheme.outline,
};

/// The «التناقضات» tab of [meetingId].
class ConsistencyTab extends ConsumerWidget {
  /// Creates the tab.
  const ConsistencyTab({super.key, required this.meetingId});

  /// Meeting shown.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final meeting = ref.watch(meetingProvider(meetingId)).value;
    final check = ref.watch(consistencyCheckProvider(meetingId));
    final findings =
        ref.watch(consistencyFindingsProvider(meetingId)).value ??
        const <ConsistencyFinding>[];
    final hasMinutes = meeting?.minutes != null;
    final open = [
      for (final f in findings)
        if (f.status == FindingStatus.open) f,
    ]..sort((a, b) => a.severity.rank.compareTo(b.severity.rank));
    final handled = [
      for (final f in findings)
        if (f.status != FindingStatus.open) f,
    ];
    final controller = ref.read(consistencyCheckProvider(meetingId).notifier);

    final children = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.rule_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(DS.header, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                DS.intro,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (check.running) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(check.statusAr ?? DS.checking),
                ),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ] else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
                    onPressed: hasMinutes
                        ? () => unawaited(controller.run())
                        : null,
                    icon: const Icon(Icons.manage_search_rounded),
                    label: Text(
                      check.result == null ? DS.checkNow : DS.checkAgain,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
    if (!check.running && check.errorAr != null) {
      children.add(
        ErrorBanner(
          message: check.errorAr!,
          onRetry: hasMinutes ? () => unawaited(controller.run()) : null,
          onDismiss: controller.clearNotice,
        ),
      );
    } else if (!check.running && check.result != null) {
      children.add(
        ErrorBanner(
          severity: check.noticeAr != null
              ? BannerSeverity.warning
              : BannerSeverity.info,
          message: [DS.summary(check.result!.open), ?check.noticeAr].join('\n'),
          onDismiss: controller.clearNotice,
        ),
      );
    }

    if (!hasMinutes) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: EmptyState(
            icon: Icons.description_outlined,
            title: DS.tabTitle,
            body: DS.noMinutes,
          ),
        ),
      );
    } else if (findings.isEmpty && !check.running) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: EmptyState(
            icon: Icons.verified_outlined,
            title: DS.noFindingsTitle,
            body: check.result == null ? DS.notCheckedBody : DS.noFindingsBody,
          ),
        ),
      );
    }
    if (open.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            DS.openCount(open.length),
            style: theme.textTheme.titleSmall,
          ),
        ),
      );
      for (final f in open) {
        children.add(FindingCard(finding: f, currentMeetingId: meetingId));
      }
    }
    if (handled.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(DS.handled(handled.length)),
            children: [
              for (final f in handled)
                FindingCard(finding: f, currentMeetingId: meetingId),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// One finding with both sides and its actions. Without [actions] (live
/// findings) no buttons are shown.
class FindingCard extends ConsumerWidget {
  /// Creates the card.
  const FindingCard({
    super.key,
    required this.finding,
    required this.currentMeetingId,
    this.actions = true,
  });

  /// The finding.
  final ConsistencyFinding finding;

  /// Meeting whose screen shows the card (its evidence plays in place).
  final String currentMeetingId;

  /// Whether to show dismiss / confirm / undo.
  final bool actions;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action, {
    String? snack,
  }) async {
    try {
      await action();
      if (snack != null && context.mounted) showSnack(context, snack);
    } catch (_) {
      if (context.mounted) showSnack(context, DS.actionFailed, error: true);
    }
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final f = finding;
    final service = ref.read(consistencyServiceProvider);
    if (f.kind.aboutDecisions && f.priorSide.kind.isDecision) {
      final ok = await showConfirmDialog(
        context,
        title: DS.confirmTitle,
        body: DS.confirmBody(
          f.priorSide.label ?? DS.sideKindLabel(f.priorSide.kind),
          f.priorSide.kind == SideKind.resolution,
        ),
        confirmLabel: DS.confirmCancelled,
        icon: Icons.gavel_rounded,
      );
      if (!ok || !context.mounted) return;
      await _act(
        context,
        ref,
        () => service.confirm(f.id!),
        snack: DS.confirmedSnack,
      );
    } else {
      await _act(context, ref, () => service.confirm(f.id!));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = finding;
    final color = severityColor(scheme, f.severity);
    final decisionConfirm =
        f.kind.aboutDecisions && f.priorSide.kind.isDecision;
    final sameMeeting =
        f.kind == FindingKind.internalConflict ||
        f.priorSide.meetingId == currentMeetingId;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DS.severityLabel(f.severity),
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
                Text(DS.kindLabel(f.kind), style: theme.textTheme.titleSmall),
                Text(
                  f.origin == FindingOrigin.engine
                      ? DS.originEngine
                      : DS.originHeuristic,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (f.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(f.explanation, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            FindingSideView(
              title: DS.thisMeeting,
              side: f.newSide,
              currentMeetingId: currentMeetingId,
            ),
            const SizedBox(height: 8),
            FindingSideView(
              title: sameMeeting ? DS.sameMeeting : DS.earlier,
              side: f.priorSide,
              currentMeetingId: currentMeetingId,
            ),
            if (actions && f.id != null) ...[
              const SizedBox(height: 10),
              if (f.status == FindingStatus.open)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => _act(
                        context,
                        ref,
                        () =>
                            ref.read(consistencyServiceProvider).dismiss(f.id!),
                        snack: DS.dismissedSnack,
                      ),
                      child: const Text(DS.dismiss),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _confirm(context, ref),
                      icon: Icon(
                        decisionConfirm
                            ? Icons.gavel_rounded
                            : Icons.check_rounded,
                      ),
                      label: Text(
                        decisionConfirm ? DS.confirmCancelled : DS.acknowledge,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(
                      f.status == FindingStatus.dismissed
                          ? Icons.do_not_disturb_on_outlined
                          : Icons.verified_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f.status == FindingStatus.dismissed
                            ? DS.dismissedLabel
                            : decisionConfirm
                            ? DS.confirmedCancelledLabel
                            : DS.acknowledgedLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _act(
                        context,
                        ref,
                        () =>
                            ref.read(consistencyServiceProvider).reopen(f.id!),
                      ),
                      child: const Text(DS.reopen),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One side of a finding: kind, label, text, meeting (number, both
/// dates), owner / deadline / status, and a link to its evidence.
class FindingSideView extends ConsumerWidget {
  /// Creates the view.
  const FindingSideView({
    super.key,
    required this.title,
    required this.side,
    required this.currentMeetingId,
  });

  /// Header («في هذا الاجتماع» / «سابقاً»).
  final String title;

  /// The side.
  final FindingSide side;

  /// Meeting of the screen showing it.
  final String currentMeetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final meetingId = side.meetingId;
    final here = meetingId == currentMeetingId;
    final otherMeeting = meetingId == null || here
        ? null
        : ref.watch(meetingProvider(meetingId));
    final deleted =
        otherMeeting != null &&
        otherMeeting.hasValue &&
        otherMeeting.value == null;
    final head = [
      DS.sideKindLabel(side.kind),
      if (side.kind.isDecision && side.label != null) side.label!,
      if (side.kind == SideKind.task) DS.taskStatus(side.taskStatus),
    ].join(' — ');
    final meetingLine = meetingId == null
        ? DS.manualTask
        : [
            if (deleted) DS.deletedMeeting,
            if (side.meetingTitle != null) '«${side.meetingTitle}»',
            if (side.meetingNumber != null)
              DS.meetingNumber(side.meetingNumber!),
            if (side.meetingDate != null) bothDatesText(side.meetingDate!),
          ].join(' — ');
    final details = [
      if (side.owner != null) DS.owner(side.owner!),
      if (side.due != null) DS.due(side.due!),
    ].join(' · ');

    Widget? link;
    if (meetingId != null && !deleted) {
      if (here) {
        if (side.evidence.isNotEmpty) {
          link = EvidenceChips(meetingId: meetingId, evidence: side.evidence);
        }
      } else if (side.evidence.isNotEmpty) {
        link = Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => openAskCitation(
              context,
              ref,
              AskCitation(
                number: 1,
                meetingId: meetingId,
                alias: 0,
                meetingTitle: side.meetingTitle ?? '',
                meetingDate: side.meetingDate ?? DateTime.now(),
                segmentIndex: side.evidence.first,
              ),
            ),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text(DS.showEvidence),
          ),
        );
      } else {
        link = Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => openMeeting(context, ref, meetingId),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text(DS.openMeeting),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: BorderDirectional(
          start: BorderSide(color: scheme.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 2),
          Text(head, style: theme.textTheme.labelSmall),
          if (side.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(side.text, style: theme.textTheme.bodyMedium),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(details, style: muted),
          ],
          if (!here && meetingLine.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(meetingLine, style: muted),
          ],
          ?link,
        ],
      ),
    );
  }
}

/// The resolutions of [meeting] annotated «أُلغي رسمياً» by a later
/// meeting. An annotation never edits the minutes: approved minutes keep
/// their content and hash. Renders nothing without annotations.
class SupersededResolutionsCard extends ConsumerWidget {
  /// Creates the card.
  const SupersededResolutionsCard({super.key, required this.meeting});

  /// The earlier meeting.
  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = meeting.minutes;
    if (minutes == null) return const SizedBox.shrink();
    final annotations =
        ref.watch(resolutionAnnotationsProvider(meeting.id)).value ??
        const <ResolutionAnnotation>[];
    // Only annotations whose resolution still exists (regenerated minutes
    // may have changed it).
    final keys = {for (final d in minutes.decisions) decisionKeyOf(d)};
    final shown = [
      for (final a in annotations)
        if (keys.contains(a.decisionKey)) a,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final approved =
        ref.watch(officialRecordProvider(meeting.id)).value?.isLocked ?? false;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.35),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_rounded, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DS.supersededTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            for (final a in shown) ...[
              const SizedBox(height: 8),
              Text(
                DS.supersededBy(
                  '«${minutes.decisions.firstWhere((d) => decisionKeyOf(d) == a.decisionKey).text}»',
                  a.bySide.meetingTitle ?? DS.deletedMeeting,
                  a.bySide.meetingDate == null
                      ? ''
                      : bothDatesText(a.bySide.meetingDate!),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              if (a.bySide.text.isNotEmpty)
                Text(
                  DS.supersedingText(a.bySide.text),
                  style: theme.textTheme.bodySmall,
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => openMeeting(context, ref, a.byMeetingId),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text(DS.openMeeting),
                ),
              ),
            ],
            Text(
              approved ? DS.supersededApprovedNote : DS.supersededNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The live-check banner of the meeting being recorded. While live mode
/// is on (Settings; off by default) it checks the latest lines every
/// [kLiveCheckInterval] with the cloud engine the user accepted, and shows
/// a subtle banner when something may contradict an earlier item.
class LiveConsistencyBanner extends ConsumerStatefulWidget {
  /// Creates the banner.
  const LiveConsistencyBanner({
    super.key,
    required this.meetingId,
    this.interval = kLiveCheckInterval,
  });

  /// Meeting being recorded.
  final String meetingId;

  /// Interval between checks.
  final Duration interval;

  @override
  ConsumerState<LiveConsistencyBanner> createState() =>
      _LiveConsistencyBannerState();
}

class _LiveConsistencyBannerState extends ConsumerState<LiveConsistencyBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(consistencyLiveModeProvider, (_, next) {
      final on = next.value ?? false;
      if (on && _timer == null) {
        _timer = Timer.periodic(widget.interval, (_) {
          unawaited(
            ref.read(liveConsistencyProvider.notifier).tick(widget.meetingId),
          );
        });
      } else if (!on) {
        _timer?.cancel();
        _timer = null;
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _details(List<ConsistencyFinding> findings) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shrinkWrap: true,
          children: [
            Text(
              DS.liveSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              DS.liveSheetNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final f in findings)
              FindingCard(
                finding: f,
                currentMeetingId: widget.meetingId,
                actions: false,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveConsistencyProvider);
    final findings = liveFindingsOf(state, widget.meetingId);
    if (findings.isEmpty || state.hidden) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.rule_rounded, size: 18, color: scheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DS.liveBanner(findings.length),
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => _details(findings),
              child: const Text(DS.liveDetails),
            ),
            IconButton(
              tooltip: DS.liveHide,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () =>
                  ref.read(liveConsistencyProvider.notifier).hide(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings switch of the live mode.
class ConsistencyLiveSettingTile extends ConsumerWidget {
  /// Creates the tile.
  const ConsistencyLiveSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(consistencyLiveModeProvider).value ?? false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.rule_rounded),
      title: const Text(DS.liveTitle),
      subtitle: const Text(DS.liveSubtitle),
      value: on,
      onChanged: (v) =>
          unawaited(ref.read(consistencySettingsStoreProvider).setLiveMode(v)),
    );
  }
}

/// Tab label with the number of open findings.
class ConsistencyTabLabel extends ConsumerWidget {
  /// Creates the label.
  const ConsistencyTabLabel({super.key, required this.meetingId});

  /// The meeting.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(openFindingsCountProvider(meetingId)).value ?? 0;
    return Badge(
      isLabelVisible: n > 0,
      label: Text('$n'),
      offset: const Offset(10, -4),
      child: const Text(DS.tabTitle),
    );
  }
}
