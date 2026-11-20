// Read-only summary of a meeting's context (F3) for the meeting detail
// screen: agenda, expected attendees, notes and meeting-only terms, with an
// edit button.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import 'glossary_term_dialog.dart';
import 'meeting_context_flows.dart';
import 'strings.dart';

/// The context of [meeting] with an edit button.
class MeetingContextCard extends ConsumerWidget {
  /// Creates the card.
  const MeetingContextCard({super.key, required this.meeting});

  /// The meeting.
  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ctx = meeting.context;
    final terms =
        ref.watch(meetingGlossaryProvider(meeting.id)).value ??
        const <GlossaryTerm>[];
    final notes = ctx.contextNotes?.trim() ?? '';
    final empty = ctx.isEmpty && terms.isEmpty;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.labelLarge),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      CS.contextCardTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      editMeetingContextFlow(context, ref, meeting),
                  icon: Icon(
                    empty ? Icons.add_rounded : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(empty ? CS.addContext : CS.editContext),
                ),
              ],
            ),
            if (empty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8, top: 4),
                child: Text(
                  CS.contextEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (ctx.agenda.isNotEmpty) ...[
              label(CS.agendaCount(ctx.agenda.length)),
              for (var i = 0; i < ctx.agenda.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${i + 1}. ${ctx.agenda[i]}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
            if (ctx.expectedAttendees.isNotEmpty) ...[
              label(CS.attendeesCount(ctx.expectedAttendees.length)),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in ctx.expectedAttendees)
                    Chip(
                      avatar: const Icon(Icons.person_rounded, size: 16),
                      label: Text(a),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (notes.isNotEmpty) ...[
              label(CS.notesHeader),
              Text(notes, style: theme.textTheme.bodyMedium),
            ],
            if (terms.isNotEmpty) ...[
              label(CS.meetingTermsCount(terms.length)),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in terms)
                    Chip(
                      avatar: Icon(glossaryCategoryIcon(t.category), size: 16),
                      label: Text(
                        t.arSpelling == null
                            ? t.term
                            : '${t.term} — ${t.arSpelling}',
                      ),
                      visualDensity: VisualDensity.compact,
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
