// Rendered Arabic minutes: summary, attendees, topics, decisions, action
// items (table on wide layouts, cards on phones), open questions, next
// meeting and notes.

import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../format.dart';
import '../strings_ar.dart';
import 'common.dart';

/// Full rendering of [minutes] for [meeting]. Not scrollable itself: place
/// it in a scroll view.
class MinutesView extends StatelessWidget {
  /// Creates the view.
  const MinutesView({super.key, required this.meeting, required this.minutes});

  /// The meeting.
  final Meeting meeting;

  /// Its minutes.
  final Minutes minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = minutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(meeting: meeting, minutes: m),
        if (m.summary.trim().isNotEmpty) ...[
          const SectionHeader(S.summary, icon: Icons.short_text_rounded),
          _Paragraph(m.summary),
        ],
        if (m.attendees.isNotEmpty) ...[
          const SectionHeader(S.attendees, icon: Icons.groups_rounded),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in m.attendees)
                Chip(
                  avatar: Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  label: Text(a),
                ),
            ],
          ),
        ],
        if (m.topics.isNotEmpty) ...[
          const SectionHeader(S.topics, icon: Icons.forum_rounded),
          for (var i = 0; i < m.topics.length; i++)
            _TopicCard(index: i + 1, topic: m.topics[i]),
        ],
        const SectionHeader(S.decisions, icon: Icons.gavel_rounded),
        if (m.decisions.isEmpty)
          const _Muted(S.noneRecorded)
        else
          for (var i = 0; i < m.decisions.length; i++)
            _NumberedItem(
              number: i + 1,
              text: m.decisions[i].text,
              footnote: m.decisions[i].proposedBy == null
                  ? null
                  : S.proposedBy(m.decisions[i].proposedBy!),
            ),
        const SectionHeader(S.actionItems, icon: Icons.task_alt_rounded),
        if (m.actionItems.isEmpty)
          const _Muted(S.noneRecorded)
        else
          ActionItemsView(items: m.actionItems),
        if (m.openQuestions.isNotEmpty) ...[
          const SectionHeader(S.openQuestions, icon: Icons.help_outline_rounded),
          for (final q in m.openQuestions) _Bullet(q),
        ],
        if (m.nextMeeting != null) ...[
          const SectionHeader(S.nextMeeting, icon: Icons.event_rounded),
          _Paragraph(m.nextMeeting!),
        ],
        if (m.notes != null) ...[
          const SectionHeader(S.notes, icon: Icons.sticky_note_2_outlined),
          _Paragraph(m.notes!),
        ],
        const SizedBox(height: 16),
        Text(
          S.generatedBy(
            ltrIsolate(m.model.isEmpty ? 'Claude' : m.model),
            formatArabicDateTime(m.generatedAt.toLocal()),
          ),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.meeting, required this.minutes});

  final Meeting meeting;
  final Minutes minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = minutes.title.trim().isEmpty ? meeting.title : minutes.title;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'محضر اجتماع',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Meta(
                  icon: Icons.calendar_today_rounded,
                  text: formatArabicDateTime(meeting.createdAt.toLocal()),
                ),
                if (meeting.durationMs > 0)
                  _Meta(
                    icon: Icons.timer_outlined,
                    text: formatDurationWords(meeting.durationMs),
                  ),
                if (minutes.languagesDetected.isNotEmpty)
                  _Meta(
                    icon: Icons.translate_rounded,
                    text: minutes.languagesDetected.join('، '),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _NumberedItem extends StatelessWidget {
  const _NumberedItem({required this.number, required this.text, this.footnote});

  final int number;
  final String text;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.secondaryContainer,
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyLarge),
                if (footnote != null)
                  Text(
                    footnote!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.index, required this.topic});

  final int index;
  final MinutesTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index. ${topic.title}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(topic.discussion, style: theme.textTheme.bodyLarge),
              if (topic.speakerNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  S.topicSpeakers(topic.speakerNames.join('، ')),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Action items as a table (wide) or cards (narrow).
class ActionItemsView extends StatelessWidget {
  /// Creates the view.
  const ActionItemsView({super.key, required this.items});

  /// Items.
  final List<ActionItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) =>
          c.maxWidth >= 600 ? _table(context) : _cards(context),
    );
  }

  Widget _table(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final headStyle = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSecondaryContainer,
      fontWeight: FontWeight.w700,
    );
    Widget cell(String text, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(text, style: style ?? theme.textTheme.bodyMedium),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(44),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(1.4),
          3: FlexColumnWidth(1.4),
        },
        border: TableBorder.all(color: scheme.outlineVariant),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: scheme.secondaryContainer),
            children: [
              cell('#', style: headStyle),
              cell(S.task, style: headStyle),
              cell(S.owner, style: headStyle),
              cell(S.due, style: headStyle),
            ],
          ),
          for (var i = 0; i < items.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i.isOdd ? scheme.surfaceContainerLow : null,
              ),
              children: [
                cell('${i + 1}'),
                cell(items[i].task),
                cell(items[i].owner ?? S.notSpecified),
                cell(items[i].dueDate ?? S.notSpecified),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cards(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (final a in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_box_outline_blank_rounded,
                        color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.task, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              _Labeled(
                                icon: Icons.person_outline_rounded,
                                text: '${S.owner}: ${a.owner ?? S.notSpecified}',
                              ),
                              _Labeled(
                                icon: Icons.schedule_rounded,
                                text: '${S.due}: ${a.dueDate ?? S.notSpecified}',
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
          ),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
