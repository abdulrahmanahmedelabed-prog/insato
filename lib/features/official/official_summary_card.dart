// Card on the minutes tab of a meeting with an official template (v1.2):
// logo, official title, both dates, lifecycle status, quorum and pending
// votes, with a button to the official minutes screen.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import '../../ui/widgets/dialogs.dart';
import 'official_logic.dart';
import 'official_models.dart';
import 'official_providers.dart';
import 'strings.dart';
import 'official_minutes_screen.dart';

/// The official summary of [meeting] (renders nothing for the simplified
/// template or before minutes exist).
class OfficialSummaryCard extends ConsumerWidget {
  /// Creates the card.
  const OfficialSummaryCard({super.key, required this.meeting});

  /// The meeting.
  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customs = ref.watch(customTemplatesProvider).value ?? const [];
    final choice = resolveTemplate(meeting.context.template, customs);
    if (!choice.isOfficial || meeting.minutes == null) {
      return const SizedBox.shrink();
    }
    final b = ref.watch(officialBundleProvider(meeting.id)).value;
    if (b == null) return const SizedBox.shrink();
    final doc = b.document;
    final theme = Theme.of(context);
    final pending = {
      ...resolutionsNeedingReview(meeting.minutes!, b.record),
      for (final r in doc.resolutions)
        if (r.tally.outcome == VoteOutcome.needsReview) r.index,
    }.length;
    final Uint8List? logo = doc.logo;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (logo != null) ...[
                  Image.memory(logo, width: 48, height: 48),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (doc.entityName.isNotEmpty)
                        Text(doc.entityName, style: theme.textTheme.labelLarge),
                      Text(
                        doc.documentTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        [
                          doc.weekday,
                          if (doc.hijriDate.isNotEmpty) doc.hijriDate,
                          doc.gregorianDate,
                        ].join(' — '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(b.record.status.labelAr),
                  avatar: Icon(
                    b.record.isLocked
                        ? Icons.lock_rounded
                        : Icons.edit_note_rounded,
                    size: 16,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(doc.quorum.statementAr, style: theme.textTheme.bodySmall),
            if (pending > 0)
              Text(
                OS.pendingVotes(pending),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            if (doc.isApproved)
              Text(
                '${OS.hashLabel}: ${formatHash(doc.contentHash).substring(0, 19)}…',
                style: theme.textTheme.labelSmall,
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: () => openOfficialMinutesScreen(context, meeting.id),
                icon: const Icon(Icons.gavel_rounded),
                label: const Text(OS.screenTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before regenerating the minutes of an approved meeting (which then
/// becomes a new draft version). True to go on.
Future<bool> confirmRegenerateOfficial(
  BuildContext context,
  WidgetRef ref,
  String meetingId,
) async {
  final record = await ref
      .read(officialMinutesRepositoryProvider)
      .get(meetingId);
  if (record == null || !record.isLocked || !context.mounted) return true;
  return showConfirmDialog(
    context,
    title: OS.newVersionTitle,
    body: OS.newVersionBody,
    confirmLabel: OS.newVersion,
    icon: Icons.edit_note_rounded,
  );
}
