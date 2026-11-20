// Secretary review of detected votes (v1.2, B): for each resolution the
// engine's voting moment and every present member's position, which the
// secretary confirms or corrects (especially «غير واضح») before approval.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import 'official_document.dart';
import 'official_logic.dart';
import 'official_models.dart';
import 'official_providers.dart';
import 'official_service.dart';
import 'strings.dart';

/// Opens the vote review of [meetingId].
Future<void> openVoteReviewScreen(BuildContext context, String meetingId) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VoteReviewScreen(meetingId: meetingId),
      ),
    );

/// The vote review screen.
class VoteReviewScreen extends ConsumerWidget {
  /// Creates the screen.
  const VoteReviewScreen({super.key, required this.meetingId});

  /// Meeting reviewed.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officialBundleProvider(meetingId));
    final minutes = ref.watch(meetingProvider(meetingId)).value?.minutes;
    return Scaffold(
      appBar: AppBar(title: const Text(OS.voteReview)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(S.unexpectedError)),
        data: (b) {
          if (b == null || minutes == null) {
            return const EmptyState(
              icon: Icons.how_to_vote_outlined,
              title: OS.noMinutes,
            );
          }
          final doc = b.document;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (b.record.isLocked)
                      const ErrorBanner(
                        severity: BannerSeverity.info,
                        message: OS.lockedHint,
                      ),
                    Text(
                      OS.voteReviewIntro,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (doc.resolutions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(OS.noResolutions),
                      ),
                    for (final r in doc.resolutions)
                      ResolutionVoteCard(
                        key: ValueKey('vote-${r.index}-${b.record.version}'),
                        resolution: r,
                        decision: minutes.decisions[r.index],
                        record: b.record,
                        reviewed: reviewFor(b.record, minutes, r.index) != null,
                        enabled: !b.record.isLocked,
                        onSave: (review) async {
                          try {
                            await ref
                                .read(officialMinutesServiceProvider)
                                .setVoteReview(
                                  b.record,
                                  minutes,
                                  r.index,
                                  review,
                                );
                            if (context.mounted) {
                              showSnack(context, OS.voteSaved);
                            }
                          } on OfficialActionException catch (e) {
                            if (context.mounted) {
                              showSnack(context, e.messageAr, error: true);
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One resolution with editable mode and positions.
class ResolutionVoteCard extends StatefulWidget {
  /// Creates the card.
  const ResolutionVoteCard({
    super.key,
    required this.resolution,
    required this.decision,
    required this.record,
    required this.reviewed,
    required this.enabled,
    required this.onSave,
  });

  /// The resolution (with its current tally).
  final OfficialResolution resolution;

  /// The underlying decision.
  final MinutesDecision decision;

  /// The record (attendance).
  final OfficialRecord record;

  /// A review is stored.
  final bool reviewed;

  /// Editable.
  final bool enabled;

  /// Saves a review.
  final Future<void> Function(VoteReview review) onSave;

  @override
  State<ResolutionVoteCard> createState() => _ResolutionVoteCardState();
}

class _ResolutionVoteCardState extends State<ResolutionVoteCard> {
  late VoteMode _mode = widget.resolution.tally.mode;
  late final Map<String, VotePosition> _positions = {
    for (final v in widget.resolution.tally.voters) v.name: v.position,
  };
  late final Set<String> _counted = {
    for (final v in widget.resolution.tally.voters)
      if (v.counted) v.name,
  };
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.resolution;
    final needs =
        !widget.reviewed &&
        widget.decision.vote.positions.any(
          (p) => p.position == VotePosition.unclear,
        );
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.label, style: theme.textTheme.titleSmall),
                ),
                if (widget.reviewed)
                  const Chip(
                    avatar: Icon(Icons.check_rounded, size: 16),
                    label: Text(OS.confirmed),
                    visualDensity: VisualDensity.compact,
                  )
                else if (needs)
                  Chip(
                    avatar: Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    label: const Text(OS.needsReview),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(r.text, style: theme.textTheme.bodyMedium),
            if (r.voteLine != null) ...[
              const SizedBox(height: 6),
              Text(r.voteLine!, style: theme.textTheme.bodySmall),
            ],
            if (widget.decision.vote.evidence.isNotEmpty)
              Text(
                OS.evidence(widget.decision.vote.evidence),
                style: theme.textTheme.labelSmall,
              ),
            const SizedBox(height: 10),
            Text(OS.voteMode, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<VoteMode>(
              segments: [
                for (final m in VoteMode.values)
                  ButtonSegment(value: m, label: Text(m.labelAr)),
              ],
              selected: {_mode},
              onSelectionChanged: widget.enabled
                  ? (v) => setState(() => _mode = v.first)
                  : null,
            ),
            if (_positions.isNotEmpty) const SizedBox(height: 8),
            for (final e in _positions.entries)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _counted.contains(e.key)
                          ? e.key
                          : '${e.key} (${OS.notCounted})',
                    ),
                  ),
                  DropdownButton<VotePosition>(
                    value: e.value,
                    onChanged: widget.enabled
                        ? (p) =>
                              setState(() => _positions[e.key] = p ?? e.value)
                        : null,
                    items: [
                      for (final p in VotePosition.values)
                        DropdownMenuItem(value: p, child: Text(p.labelAr)),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: !widget.enabled || _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        await widget.onSave(
                          VoteReview(
                            decisionKey: decisionKeyOf(widget.decision),
                            mode: _mode,
                            positions: Map.of(_positions),
                          ),
                        );
                        if (mounted) setState(() => _saving = false);
                      },
                icon: const Icon(Icons.how_to_vote_rounded),
                label: const Text(OS.confirmVote),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
