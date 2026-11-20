// Institutional memory and the pure-Dart part of the consistency checker
// (v1.2, D):
//
// * [buildInstitutionalMemory] indexes the decisions of earlier meetings —
//   resolutions of approved official minutes at full weight, decisions of
//   minutes that are not approved at [kDecisionMemoryWeight] — and the
//   tracked tasks (F9), skipping resolutions already superseded;
// * [newItemsOf] lists the decisions (D1…) and action items (A1…) of the
//   meeting being checked;
// * [retrieveCandidates] ranks the memory for each new item with the BM25
//   index and Arabic analysis of "Ask your meetings" (F8);
// * [heuristicFindings] finds the obvious cases without any engine: the
//   same decision taken again, a decision that negates / changes the number
//   of an earlier one, a duplicated task, the same task with another owner
//   or deadline, a closed task assigned again, and conflicts inside the
//   meeting.
//
// No Flutter imports; unit-tested in test/features/consistency/.

import '../../core/models.dart';
import '../../core/text_normalize.dart';
import '../../data/repositories_v11.dart' show similarTaskText, taskMatchKey;
import '../ask/bm25.dart';
import '../ask/search_text.dart';
import '../official/official_models.dart';
import '../official/official_templates.dart';
import '../tasks/task_logic.dart' show personNamesMatch;
import 'consistency_models.dart';

/// Retrieval weight of a decision whose minutes are not approved.
const double kDecisionMemoryWeight = 0.6;

/// Retrieval weight of an approved resolution.
const double kResolutionMemoryWeight = 1.0;

/// Retrieval weight of an open task.
const double kOpenTaskMemoryWeight = 0.8;

/// Retrieval weight of a done / cancelled task.
const double kClosedTaskMemoryWeight = 0.5;

/// At most this many earlier items are compared with one new item.
const int kMaxCandidatesPerItem = 4;

/// An earlier meeting given to [buildInstitutionalMemory].
class MemoryMeeting {
  /// Creates an entry.
  const MemoryMeeting({
    required this.meeting,
    this.record,
    this.template = OfficialTemplates.team,
    this.supersededKeys = const {},
  });

  /// The meeting (with minutes).
  final Meeting meeting;

  /// Its official record, if any.
  final OfficialRecord? record;

  /// Its template (resolution numbering).
  final OfficialTemplate template;

  /// Decision keys annotated «أُلغي رسمياً» (left out of the memory).
  final Set<String> supersededKeys;

  /// True when the minutes are approved.
  bool get approved => record?.status == OfficialStatus.approved;
}

/// One indexed earlier item.
class MemoryItem {
  /// Creates an item.
  const MemoryItem({
    required this.side,
    required this.compareText,
    required this.weight,
    required this.terms,
  });

  /// The item as cited.
  final FindingSide side;

  /// Text compared by the heuristics (plain decision / task text).
  final String compareText;

  /// Retrieval weight.
  final double weight;

  /// Analysed terms.
  final List<String> terms;

  /// True for a done / cancelled task.
  bool get closed {
    final s = side.trackedStatus;
    return s != null && s != TaskStatus.open;
  }

  /// True for a decision / resolution.
  bool get isDecision => side.kind.isDecision;
}

/// The memory of earlier meetings.
class InstitutionalMemory {
  /// Creates a memory over [items].
  InstitutionalMemory(this.items)
    : _index = Bm25Index([for (final i in items) i.terms]);

  /// Indexed items.
  final List<MemoryItem> items;

  final Bm25Index _index;

  /// True when nothing is indexed.
  bool get isEmpty => items.isEmpty;

  /// The best matches of [terms] among items accepted by [where], best
  /// first: BM25 score × item weight, at least [minShared] shared terms.
  List<MemoryItem> search(
    List<String> terms, {
    bool Function(MemoryItem)? where,
    int limit = kMaxCandidatesPerItem,
  }) {
    if (terms.isEmpty || items.isEmpty) return const [];
    final query = weightedQuery(terms);
    final own = terms.toSet();
    final minShared = own.length >= 2 ? 2 : 1;
    final scored = <(MemoryItem, double)>[];
    for (final h in _index.search(query)) {
      final item = items[h.doc];
      if (where != null && !where(item)) continue;
      final shared = item.terms.toSet().intersection(own).length;
      if (shared < minShared) continue;
      scored.add((item, h.score * item.weight));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored.take(limit)) s.$1];
  }
}

/// The resolution label of decision [index] of a meeting, e.g. «قرار رقم
/// (1/12/1448)» for coded numbering, else «القرار 1».
String resolutionLabelOf(
  OfficialTemplate template,
  int index, {
  OfficialRecord? record,
}) {
  if (template.numbering == NumberingStyle.resolutionCode) {
    final l = template.numberLabel(
      index,
      meetingNumber: record?.meetingNumber,
      year: record?.yearText,
    );
    return l.endsWith(':') ? l.substring(0, l.length - 1) : l;
  }
  return '${template.resolutionNoun.isEmpty ? 'القرار' : 'ال${template.resolutionNoun}'} ${index + 1}';
}

/// The side of decision [index] of [m].
FindingSide decisionSide(
  Meeting meeting,
  int index, {
  OfficialRecord? record,
  OfficialTemplate template = OfficialTemplates.team,
  bool approved = false,
}) {
  final d = meeting.minutes!.decisions[index];
  final formal = d.formalText?.trim();
  return FindingSide(
    kind: approved ? SideKind.resolution : SideKind.decision,
    text: formal == null || formal.isEmpty ? d.text.trim() : formal,
    meetingId: meeting.id,
    meetingTitle: meeting.title,
    meetingDate: meeting.createdAt,
    meetingNumber: record?.numberText,
    itemIndex: index,
    itemKey: decisionKeyOf(d),
    label: resolutionLabelOf(template, index, record: record),
    evidence: d.evidence,
  );
}

/// The side of action item [index] of [meeting].
FindingSide actionSide(Meeting meeting, int index, {OfficialRecord? record}) {
  final a = meeting.minutes!.actionItems[index];
  return FindingSide(
    kind: SideKind.actionItem,
    text: a.task.trim(),
    meetingId: meeting.id,
    meetingTitle: meeting.title,
    meetingDate: meeting.createdAt,
    meetingNumber: record?.numberText,
    itemIndex: index,
    itemKey: taskMatchKey(a.task),
    owner: a.owner?.trim(),
    due: a.dueDate?.trim(),
    evidence: a.evidence,
  );
}

/// Indexes the decisions of [meetings] created before [current] (approved
/// resolutions at full weight, other decisions at
/// [kDecisionMemoryWeight], superseded ones left out) and the [tasks] that
/// existed before it (dated by their source meeting; manual tasks by their
/// creation time). [taskOwner] names a task's owner (follows speaker
/// renames).
InstitutionalMemory buildInstitutionalMemory({
  required Meeting current,
  required List<MemoryMeeting> meetings,
  List<TrackedTask> tasks = const [],
  String? Function(TrackedTask task)? taskOwner,
}) {
  final items = <MemoryItem>[];
  final byId = <String, MemoryMeeting>{
    for (final m in meetings) m.meeting.id: m,
  };
  for (final m in meetings) {
    final meeting = m.meeting;
    final minutes = meeting.minutes;
    if (minutes == null || meeting.id == current.id) continue;
    if (!meeting.createdAt.isBefore(current.createdAt)) continue;
    for (var i = 0; i < minutes.decisions.length; i++) {
      final d = minutes.decisions[i];
      if (d.text.trim().isEmpty) continue;
      if (m.supersededKeys.contains(decisionKeyOf(d))) continue;
      final side = decisionSide(
        meeting,
        i,
        record: m.record,
        template: m.template,
        approved: m.approved,
      );
      items.add(
        MemoryItem(
          side: side,
          compareText: d.text,
          weight: m.approved ? kResolutionMemoryWeight : kDecisionMemoryWeight,
          terms: analyzeSearchText('${d.text} ${d.formalText ?? ''}'),
        ),
      );
    }
  }
  for (final t in tasks) {
    final src = t.sourceMeetingId;
    if (src == current.id) continue;
    final source = src == null ? null : byId[src];
    final origin = source?.meeting.createdAt ?? t.createdAt;
    if (!origin.isBefore(current.createdAt)) continue;
    final side = FindingSide(
      kind: SideKind.task,
      text: t.task.trim(),
      meetingId: source?.meeting.id,
      meetingTitle: source?.meeting.title,
      meetingDate: source?.meeting.createdAt,
      meetingNumber: source?.record?.numberText,
      itemKey: taskMatchKey(t.task),
      owner: taskOwner?.call(t) ?? t.ownerText,
      due: t.dueText,
      taskId: t.id,
      taskStatus: t.status.wire,
      evidence: source == null ? const [] : t.evidenceSegmentIds,
    );
    items.add(
      MemoryItem(
        side: side,
        compareText: t.task,
        weight: t.status == TaskStatus.open
            ? kOpenTaskMemoryWeight
            : kClosedTaskMemoryWeight,
        terms: analyzeSearchText(t.task),
      ),
    );
  }
  return InstitutionalMemory(items);
}

/// One decision / action item of the checked meeting.
class NewItem {
  /// Creates an item.
  const NewItem({
    required this.ref,
    required this.side,
    required this.compareText,
    required this.terms,
  });

  /// Reference given to the engine (`D1`, `A2`).
  final String ref;

  /// The item as cited.
  final FindingSide side;

  /// Plain text compared by the heuristics.
  final String compareText;

  /// Analysed terms.
  final List<String> terms;

  /// True for a decision.
  bool get isDecision => side.kind.isDecision;
}

/// The decisions (`D1`…) then action items (`A1`…) of [meeting]'s minutes.
List<NewItem> newItemsOf(
  Meeting meeting, {
  OfficialRecord? record,
  OfficialTemplate template = OfficialTemplates.team,
}) {
  final minutes = meeting.minutes;
  if (minutes == null) return const [];
  final approved = record?.status == OfficialStatus.approved;
  return [
    for (var i = 0; i < minutes.decisions.length; i++)
      if (minutes.decisions[i].text.trim().isNotEmpty)
        NewItem(
          ref: 'D${i + 1}',
          side: decisionSide(
            meeting,
            i,
            record: record,
            template: template,
            approved: approved,
          ),
          compareText: minutes.decisions[i].text,
          terms: analyzeSearchText(
            '${minutes.decisions[i].text} '
            '${minutes.decisions[i].formalText ?? ''}',
          ),
        ),
    for (var i = 0; i < minutes.actionItems.length; i++)
      if (minutes.actionItems[i].task.trim().isNotEmpty)
        NewItem(
          ref: 'A${i + 1}',
          side: actionSide(meeting, i, record: record),
          compareText: minutes.actionItems[i].task,
          terms: analyzeSearchText(minutes.actionItems[i].task),
        ),
  ];
}

/// The earlier items worth comparing with each new item (by
/// [NewItem.ref]): decisions with earlier decisions / resolutions, action
/// items with tasks. Items without candidates are omitted.
Map<String, List<MemoryItem>> retrieveCandidates(
  InstitutionalMemory memory,
  List<NewItem> items, {
  int perItem = kMaxCandidatesPerItem,
}) {
  final out = <String, List<MemoryItem>>{};
  for (final n in items) {
    final hits = memory.search(
      n.terms,
      where: (m) => m.isDecision == n.isDecision,
      limit: perItem,
    );
    if (hits.isNotEmpty) out[n.ref] = hits;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Heuristics
// ---------------------------------------------------------------------------

/// Words that cancel, refuse, postpone or negate (normalised with
/// [normalizeForSearch]).
const Set<String> _negationWords = {
  'الغاء', 'الغي', 'يلغي', 'نلغي', 'تلغي', 'الغيت', 'ملغي', 'ملغاه', //
  'عدم', 'رفض', 'يرفض', 'نرفض', 'رفضت', 'مرفوض', //
  'تاجيل', 'يوجل', 'نوجل', 'توجل', 'اجل', 'موجل', //
  'ايقاف', 'وقف', 'يوقف', 'نوقف', 'توقف', 'تعليق', 'يعلق', 'سحب', //
  'منع', 'يمنع', 'حظر', 'لا', 'لن', 'ليس', 'دون', 'بدون', //
  'cancel', 'cancelled', 'canceled', 'reject', 'rejected', 'not', 'no',
  'postpone', 'postponed', 'suspend', 'suspended', 'stop', 'stopped',
  'drop', 'dropped', 'without',
};

final Set<String> _negationStems = {
  for (final w in _negationWords) ...analyzeSearchText(w),
};

final RegExp _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// True when [text] cancels, refuses, postpones or negates something
/// («إلغاء…»، «عدم…»، «تأجيل…»، «لن…»).
bool expressesNegation(String text) {
  for (final m in _wordPattern.allMatches(normalizeForSearch(text))) {
    var w = m.group(0)!;
    if (_negationWords.contains(w)) return true;
    if (w.length > 3 && w.startsWith('و')) {
      w = w.substring(1);
      if (_negationWords.contains(w)) return true;
    }
    for (final p in const ['بال', 'لل', 'فال', 'ال', 'ب', 'ف', 'ل']) {
      if (w.length - p.length >= 2 &&
          w.startsWith(p) &&
          _negationWords.contains(w.substring(p.length))) {
        return true;
      }
    }
  }
  return false;
}

/// Content terms of [text]: analysed terms without negation words.
Set<String> contentTerms(String text) => {
  for (final t in analyzeSearchText(text))
    if (!_negationStems.contains(t)) t,
};

/// Numbers in [text] (Arabic-Indic digits converted).
Set<String> numbersIn(String text) => {
  for (final m in RegExp(
    r'\d+(?:[.,]\d+)?',
  ).allMatches(normalizeForSearch(text)))
    m.group(0)!.replaceAll(',', '.'),
};

/// Jaccard overlap of the content terms of [a] and [b], and the number of
/// shared terms.
(double, int) contentOverlap(String a, String b) {
  final x = contentTerms(a);
  final y = contentTerms(b);
  if (x.isEmpty || y.isEmpty) return (0, 0);
  final inter = x.intersection(y).length;
  return (inter / x.union(y).length, inter);
}

/// How two decision texts relate.
enum DecisionRelation {
  /// Unrelated (or not decidable without an engine).
  none,

  /// The same decision.
  same,

  /// About the same subject with opposite polarity (one cancels, refuses,
  /// postpones or negates).
  opposite,

  /// About the same subject with different numbers (amount, date, count).
  numbersChanged,
}

/// Minimum content overlap for [DecisionRelation.opposite].
const double kOppositeOverlap = 0.5;

/// Minimum content overlap for [DecisionRelation.numbersChanged].
const double kNumbersOverlap = 0.6;

/// Compares two decision texts (pure rules).
DecisionRelation relateDecisions(String a, String b) {
  if (taskMatchKey(a).isNotEmpty && taskMatchKey(a) == taskMatchKey(b)) {
    return DecisionRelation.same;
  }
  final (overlap, shared) = contentOverlap(a, b);
  if (shared >= 2 &&
      overlap >= kOppositeOverlap &&
      expressesNegation(a) != expressesNegation(b)) {
    return DecisionRelation.opposite;
  }
  if (shared >= 2 && overlap >= kNumbersOverlap) {
    final na = numbersIn(a);
    final nb = numbersIn(b);
    if (na.isNotEmpty && nb.isNotEmpty && !_sameSet(na, nb)) {
      return DecisionRelation.numbersChanged;
    }
  }
  return DecisionRelation.none;
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

bool _differentOwner(String? a, String? b) {
  final x = a?.trim() ?? '';
  final y = b?.trim() ?? '';
  return x.isNotEmpty && y.isNotEmpty && !personNamesMatch(x, y);
}

bool _differentDue(String? a, String? b) {
  final x = normalizeForSearch(a ?? '');
  final y = normalizeForSearch(b ?? '');
  return x.isNotEmpty && y.isNotEmpty && x != y;
}

/// «قرار رقم (1/12/1448) في اجتماع «…»» — how a side is named in an
/// explanation.
String sideReference(FindingSide s) {
  final where = s.meetingTitle == null ? '' : ' في اجتماع «${s.meetingTitle}»';
  return switch (s.kind) {
    SideKind.resolution || SideKind.decision => '${s.label ?? 'القرار'}$where',
    SideKind.task => 'المهمة «${s.text}»$where',
    SideKind.actionItem => 'المهمة «${s.text}»',
  };
}

/// The obvious findings of the checked meeting, without any engine:
/// each new item against its [candidates] (see [retrieveCandidates]), and
/// the meeting's items against each other.
List<ConsistencyFinding> heuristicFindings({
  required String meetingId,
  required List<NewItem> items,
  required Map<String, List<MemoryItem>> candidates,
}) {
  final out = <ConsistencyFinding>[];
  ConsistencyFinding f(
    FindingKind kind,
    FindingSeverity severity,
    FindingSide a,
    FindingSide b,
    String explanation,
  ) => ConsistencyFinding(
    meetingId: meetingId,
    kind: kind,
    severity: severity,
    newSide: a,
    priorSide: b,
    explanation: explanation,
  );

  for (final n in items) {
    for (final c in candidates[n.ref] ?? const <MemoryItem>[]) {
      final prior = c.side;
      if (n.isDecision && c.isDecision) {
        final approved = prior.kind == SideKind.resolution;
        switch (relateDecisions(n.compareText, c.compareText)) {
          case DecisionRelation.same:
            out.add(
              f(
                FindingKind.revisitsClosedTopic,
                FindingSeverity.low,
                n.side,
                prior,
                'اتُّخذ هذا القرار نفسه سابقاً (${sideReference(prior)}).',
              ),
            );
          case DecisionRelation.opposite:
            out.add(
              f(
                FindingKind.contradictsResolution,
                approved ? FindingSeverity.high : FindingSeverity.medium,
                n.side,
                prior,
                'يبدو أن هذا القرار يعكس ${sideReference(prior)} '
                '(إلغاء أو رفض أو تأجيل لما تقرر سابقاً).',
              ),
            );
          case DecisionRelation.numbersChanged:
            out.add(
              f(
                FindingKind.contradictsResolution,
                FindingSeverity.medium,
                n.side,
                prior,
                'تختلف الأرقام عمّا ورد في ${sideReference(prior)} '
                '(${numbersIn(c.compareText).join('، ')} ← '
                '${numbersIn(n.compareText).join('، ')}).',
              ),
            );
          case DecisionRelation.none:
            break;
        }
      } else if (!n.isDecision && prior.kind == SideKind.task) {
        if (!similarTaskText(n.compareText, c.compareText)) continue;
        if (c.closed) {
          final done = prior.trackedStatus == TaskStatus.done;
          out.add(
            f(
              FindingKind.revisitsClosedTopic,
              FindingSeverity.low,
              n.side,
              prior,
              done
                  ? 'هذه المهمة أُنجزت سابقاً (${sideReference(prior)}).'
                  : 'هذه المهمة أُلغيت سابقاً (${sideReference(prior)}).',
            ),
          );
          continue;
        }
        final owner = _differentOwner(n.side.owner, prior.owner);
        final due = _differentDue(n.side.due, prior.due);
        if (owner) {
          out.add(
            f(
              FindingKind.changesOwner,
              FindingSeverity.medium,
              n.side,
              prior,
              'المهمة نفسها مسندة سابقاً إلى «${prior.owner}» وأُسندت الآن '
              'إلى «${n.side.owner}».',
            ),
          );
        }
        if (due) {
          out.add(
            f(
              FindingKind.changesDeadline,
              FindingSeverity.medium,
              n.side,
              prior,
              'تغيّر موعد المهمة من «${prior.due}» إلى «${n.side.due}».',
            ),
          );
        }
        if (!owner && !due) {
          out.add(
            f(
              FindingKind.duplicatesTask,
              FindingSeverity.low,
              n.side,
              prior,
              'هذه المهمة مفتوحة أصلاً (${sideReference(prior)}).',
            ),
          );
        }
      }
    }
  }

  // Conflicts inside the meeting.
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final a = items[i];
      final b = items[j];
      if (a.isDecision && b.isDecision) {
        final r = relateDecisions(b.compareText, a.compareText);
        if (r == DecisionRelation.opposite ||
            r == DecisionRelation.numbersChanged) {
          out.add(
            f(
              FindingKind.internalConflict,
              FindingSeverity.medium,
              b.side,
              a.side,
              r == DecisionRelation.opposite
                  ? 'قراران في الاجتماع نفسه متعارضان '
                        '(${a.side.label ?? a.ref} و${b.side.label ?? b.ref}).'
                  : 'قراران في الاجتماع نفسه بأرقام مختلفة '
                        '(${a.side.label ?? a.ref} و${b.side.label ?? b.ref}).',
            ),
          );
        }
      } else if (!a.isDecision && !b.isDecision) {
        if (!similarTaskText(a.compareText, b.compareText)) continue;
        final owner = _differentOwner(a.side.owner, b.side.owner);
        final due = _differentDue(a.side.due, b.side.due);
        if (owner || due) {
          out.add(
            f(
              FindingKind.internalConflict,
              FindingSeverity.medium,
              b.side,
              a.side,
              owner
                  ? 'المهمة نفسها أُسندت في الاجتماع إلى «${a.side.owner}» '
                        'وإلى «${b.side.owner}».'
                  : 'المهمة نفسها وردت في الاجتماع بموعدين مختلفين '
                        '(«${a.side.due}» و«${b.side.due}»).',
            ),
          );
        }
      }
    }
  }
  return dedupeFindings(out);
}

/// Removes repeated keys (first wins) and sorts by severity, then kind.
List<ConsistencyFinding> dedupeFindings(Iterable<ConsistencyFinding> list) {
  final seen = <String>{};
  final out = [
    for (final f in list)
      if (seen.add(f.key)) f,
  ];
  out.sort((a, b) {
    final s = a.severity.rank.compareTo(b.severity.rank);
    return s != 0 ? s : a.kind.index.compareTo(b.kind.index);
  });
  return out;
}

/// Merges engine findings into the heuristic ones: a pair of sides already
/// reported by a heuristic keeps the heuristic finding.
List<ConsistencyFinding> mergeFindings(
  List<ConsistencyFinding> heuristic,
  List<ConsistencyFinding> engine,
) {
  final pairs = {for (final f in heuristic) pairKeyOf(f.newSide, f.priorSide)};
  return dedupeFindings([
    ...heuristic,
    for (final f in engine)
      if (!pairs.contains(pairKeyOf(f.newSide, f.priorSide))) f,
  ]);
}
