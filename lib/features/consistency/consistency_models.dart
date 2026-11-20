// Domain models of the contradiction & consistency checker (v1.2, D):
// finding kinds, severities and statuses, the two sides a finding cites
// (a decision / resolution / action item / task with its meeting, number,
// date and evidence), the stored finding and the «أُلغي رسمياً» annotation
// of an earlier resolution.
//
// Pure Dart (no Flutter), JSON round-trippable with tolerant parsers.

import 'dart:convert';

import '../../core/models.dart';

/// What a finding reports.
enum FindingKind {
  /// A new decision contradicts an earlier resolution / decision.
  contradictsResolution,

  /// A new action item duplicates an existing (open) task.
  duplicatesTask,

  /// A new action item gives an existing task another owner.
  changesOwner,

  /// A new action item gives an existing task another deadline.
  changesDeadline,

  /// The meeting re-decides / re-assigns something already closed (a
  /// resolution taken again, a task already done or cancelled).
  revisitsClosedTopic,

  /// Two decisions / action items of the same meeting conflict.
  internalConflict;

  /// Wire value (database, engine schema).
  String get wire => switch (this) {
    contradictsResolution => 'contradicts_resolution',
    duplicatesTask => 'duplicates_task',
    changesOwner => 'changes_owner',
    changesDeadline => 'changes_deadline',
    revisitsClosedTopic => 'revisits_closed_topic',
    internalConflict => 'internal_conflict',
  };

  /// Parses a wire value, or null.
  static FindingKind? tryParse(Object? s) {
    for (final k in values) {
      if (k.wire == s) return k;
    }
    return null;
  }

  /// True when the earlier side is a decision / resolution (the finding
  /// can be confirmed as «تم الإلغاء رسمياً»).
  bool get aboutDecisions =>
      this == contradictsResolution || this == revisitsClosedTopic;
}

/// How serious a finding is.
enum FindingSeverity {
  /// Contradicts an approved resolution, or a direct conflict.
  high,

  /// Probable inconsistency worth checking.
  medium,

  /// Informational (duplicate, repeated decision).
  low;

  /// Wire value.
  String get wire => name;

  /// Sort rank (high first).
  int get rank => index;

  /// Parses a wire value (default [medium]).
  static FindingSeverity parse(Object? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => medium);

  /// Parses a wire value, or null.
  static FindingSeverity? tryParse(Object? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

/// What the user did with a finding.
enum FindingStatus {
  /// Not handled yet.
  open,

  /// Dismissed (not an issue).
  dismissed,

  /// Confirmed (for a resolution: «تم الإلغاء رسمياً»).
  confirmed;

  /// Wire value.
  String get wire => name;

  /// Parses a wire value (default [open]).
  static FindingStatus parse(Object? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => open);
}

/// Who produced a finding.
enum FindingOrigin {
  /// Pure-Dart rules (work offline and with every engine).
  heuristic,

  /// The minutes engine's classification (validated).
  engine;

  /// Parses a stored name (default [heuristic]).
  static FindingOrigin parse(Object? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => heuristic);
}

/// The kind of item a side cites.
enum SideKind {
  /// A resolution of approved official minutes.
  resolution,

  /// A decision of minutes that are not approved (yet).
  decision,

  /// An action item of the meeting's minutes.
  actionItem,

  /// A tracked task (F9).
  task;

  /// Parses a stored name (default [decision]).
  static SideKind parse(Object? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => decision);

  /// True for decisions and resolutions.
  bool get isDecision => this == resolution || this == decision;
}

/// One side of a finding: what was decided / assigned, where and when.
class FindingSide {
  /// Creates a side.
  const FindingSide({
    required this.kind,
    required this.text,
    this.meetingId,
    this.meetingTitle,
    this.meetingDate,
    this.meetingNumber,
    this.itemIndex,
    this.itemKey = '',
    this.label,
    this.owner,
    this.due,
    this.taskId,
    this.taskStatus,
    this.evidence = const [],
  });

  /// Item kind.
  final SideKind kind;

  /// The decision / task text (formal wording when known).
  final String text;

  /// Meeting of the item (null for a manual task).
  final String? meetingId;

  /// Meeting title at check time.
  final String? meetingTitle;

  /// Meeting date.
  final DateTime? meetingDate;

  /// Official meeting number (`12/1448هـ`), if any.
  final String? meetingNumber;

  /// 0-based index in `Minutes.decisions` / `Minutes.actionItems`.
  final int? itemIndex;

  /// Stable key of the item (decision key / task match key).
  final String itemKey;

  /// Resolution label («قرار رقم (1/12/1448)»), if numbered.
  final String? label;

  /// Owner (action items / tasks).
  final String? owner;

  /// Deadline (action items / tasks).
  final String? due;

  /// Task id (tasks).
  final int? taskId;

  /// `TaskStatus.wire` of a task.
  final String? taskStatus;

  /// Evidence segment indices in [meetingId].
  final List<int> evidence;

  /// The task status, when this side is a task.
  TaskStatus? get trackedStatus =>
      taskStatus == null ? null : TaskStatus.parse(taskStatus);

  /// JSON.
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'text': text,
    'meeting_id': meetingId,
    'meeting_title': meetingTitle,
    'meeting_date': meetingDate?.toUtc().toIso8601String(),
    'meeting_number': meetingNumber,
    'item_index': itemIndex,
    'item_key': itemKey,
    'label': label,
    'owner': owner,
    'due': due,
    'task_id': taskId,
    'task_status': taskStatus,
    'evidence': evidence,
  };

  /// Parses [toJson] output (tolerant).
  static FindingSide fromJson(Object? v) {
    if (v is! Map) return const FindingSide(kind: SideKind.decision, text: '');
    int? integer(Object? n) => n is int ? n : (n is num ? n.toInt() : null);
    final rawDate = v['meeting_date'];
    return FindingSide(
      kind: SideKind.parse(v['kind']),
      text: jsonString(v['text']),
      meetingId: jsonNonEmpty(v['meeting_id']),
      meetingTitle: jsonNonEmpty(v['meeting_title']),
      meetingDate: rawDate is String
          ? DateTime.tryParse(rawDate)?.toLocal()
          : null,
      meetingNumber: jsonNonEmpty(v['meeting_number']),
      itemIndex: integer(v['item_index']),
      itemKey: jsonString(v['item_key']),
      label: jsonNonEmpty(v['label']),
      owner: jsonNonEmpty(v['owner']),
      due: jsonNonEmpty(v['due']),
      taskId: integer(v['task_id']),
      taskStatus: jsonNonEmpty(v['task_status']),
      evidence: [
        if (v['evidence'] case final List list)
          for (final e in list)
            if (e is int && e >= 0) e,
      ],
    );
  }

  /// Decodes a stored JSON string (malformed → empty side).
  static FindingSide decode(String json) {
    try {
      return fromJson(jsonDecode(json));
    } on FormatException {
      return fromJson(null);
    }
  }

  /// Encoded [toJson].
  String encode() => jsonEncode(toJson());

  /// The reference of this side used in finding keys.
  String get refKey => switch (kind) {
    SideKind.task => 'task:${taskId ?? itemKey}',
    _ => '${meetingId ?? ''}:${kind.isDecision ? 'd' : 'a'}:$itemKey',
  };
}

/// A stored finding.
class ConsistencyFinding {
  /// Creates a finding.
  const ConsistencyFinding({
    this.id,
    required this.meetingId,
    required this.kind,
    required this.severity,
    required this.newSide,
    required this.priorSide,
    this.status = FindingStatus.open,
    this.origin = FindingOrigin.heuristic,
    this.explanation = '',
    this.createdAt,
    this.resolvedAt,
  });

  /// Row id (null before insertion).
  final int? id;

  /// Meeting checked.
  final String meetingId;

  /// Kind.
  final FindingKind kind;

  /// Severity.
  final FindingSeverity severity;

  /// The item of the checked meeting.
  final FindingSide newSide;

  /// The earlier item (or the other item of the same meeting).
  final FindingSide priorSide;

  /// User decision.
  final FindingStatus status;

  /// Producer.
  final FindingOrigin origin;

  /// Arabic explanation.
  final String explanation;

  /// Creation time.
  final DateTime? createdAt;

  /// When dismissed / confirmed.
  final DateTime? resolvedAt;

  /// Stable key: kind + both sides (a re-check keeps the user's decision).
  String get key => findingKeyOf(kind, newSide, priorSide);

  /// Copy with replaced fields.
  ConsistencyFinding copyWith({
    int? id,
    FindingStatus? status,
    FindingSeverity? severity,
    String? explanation,
    DateTime? resolvedAt,
    bool clearResolved = false,
  }) => ConsistencyFinding(
    id: id ?? this.id,
    meetingId: meetingId,
    kind: kind,
    severity: severity ?? this.severity,
    newSide: newSide,
    priorSide: priorSide,
    status: status ?? this.status,
    origin: origin,
    explanation: explanation ?? this.explanation,
    createdAt: createdAt,
    resolvedAt: clearResolved ? null : (resolvedAt ?? this.resolvedAt),
  );
}

/// The finding key of [kind] between [a] and [b].
String findingKeyOf(FindingKind kind, FindingSide a, FindingSide b) =>
    '${kind.wire}|${a.refKey}|${b.refKey}';

/// The pair key of two sides (kind-independent, order-independent).
String pairKeyOf(FindingSide a, FindingSide b) {
  final x = a.refKey;
  final y = b.refKey;
  return x.compareTo(y) <= 0 ? '$x|$y' : '$y|$x';
}

/// «أُلغي رسمياً»: an earlier resolution superseded by a later meeting's
/// decision (confirmed by the user).
class ResolutionAnnotation {
  /// Creates an annotation.
  const ResolutionAnnotation({
    this.id,
    required this.meetingId,
    required this.decisionIndex,
    required this.decisionKey,
    required this.byMeetingId,
    required this.findingId,
    required this.bySide,
    required this.createdAt,
  });

  /// Row id.
  final int? id;

  /// Meeting of the superseded resolution.
  final String meetingId;

  /// Index of the resolution when annotated.
  final int decisionIndex;

  /// Decision key (the annotation applies only while it matches).
  final String decisionKey;

  /// Meeting whose decision superseded it.
  final String byMeetingId;

  /// The confirmed finding.
  final int findingId;

  /// The superseding decision (snapshot).
  final FindingSide bySide;

  /// When it was confirmed.
  final DateTime createdAt;
}
