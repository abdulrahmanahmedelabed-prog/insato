// Shared builders of the consistency-checker tests.

import 'package:insato/core/models.dart';

/// Minutes with [decisions] and [actions] (task, owner, due).
Minutes minutesWith({
  List<String> decisions = const [],
  List<(String, String?, String?)> actions = const [],
  List<List<int>>? decisionEvidence,
  List<String?>? formal,
}) => Minutes(
  title: 'محضر',
  summary: 'ملخص',
  attendees: const [],
  topics: const [],
  decisions: [
    for (var i = 0; i < decisions.length; i++)
      MinutesDecision(
        text: decisions[i],
        formalText: formal == null ? null : formal[i],
        evidence: decisionEvidence == null ? const [] : decisionEvidence[i],
      ),
  ],
  actionItems: [
    for (final (t, o, d) in actions)
      ActionItem(task: t, owner: o, dueDate: d, evidence: const [1]),
  ],
  openQuestions: const [],
  languagesDetected: const ['العربية'],
  generatedAt: DateTime(2026, 11, 20),
  model: 'test',
);

/// A meeting with [minutes].
Meeting meetingWith(
  String id,
  DateTime at, {
  Minutes? minutes,
  String title = 'اجتماع',
  String? template,
}) => Meeting(
  id: id,
  title: title,
  createdAt: at,
  status: MeetingStatus.ready,
  minutes: minutes,
  context: MeetingContext(template: template),
);

/// A tracked task.
TrackedTask taskWith(
  int id,
  String text, {
  String? owner,
  String? due,
  TaskStatus status = TaskStatus.open,
  String? source,
  DateTime? at,
}) => TrackedTask(
  id: id,
  task: text,
  ownerText: owner,
  dueText: due,
  status: status,
  sourceMeetingId: source,
  evidenceSegmentIds: const [3],
  createdAt: at ?? DateTime(2026, 1, 1),
  updatedAt: at ?? DateTime(2026, 1, 1),
);
