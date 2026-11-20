// Post-processing of the minutes an engine returned, before they are stored:
// the engine's output is never trusted blindly.
//
// * evidence ids that are not segment ids of the meeting are removed (F5);
// * `agenda_coverage` is aligned with the meeting's agenda: one entry per
//   agenda item, in order (missing → not discussed) (F3);
// * `task_updates` keep only ids of the open tasks given to the engine (F9);
// * `speaker_notes` keep only speakers who opted in (F16);
// * votes (v1.2, B) never invent anything: positions of speakers who are not
//   in the transcript are dropped, a position without valid evidence becomes
//   "unclear", duplicates keep the first, and a voting moment without any
//   evidence is reported as "none" (see [sanitizeVote]);
// * an empty title falls back to the meeting title.
//
// Pure Dart, unit-tested.

import '../core/models.dart';

/// The constraints [sanitizeMinutes] enforces.
class MinutesConstraints {
  /// Creates constraints.
  const MinutesConstraints({
    required this.segmentIds,
    this.agenda = const [],
    this.openTaskIds = const {},
    this.optedInSpeakers = const {},
    this.fallbackTitle = '',
    this.speakerNames,
  });

  /// `TranscriptSegment.index` values present in the transcript.
  final Set<int> segmentIds;

  /// The meeting's agenda, in order.
  final List<String> agenda;

  /// Ids of the open tasks given to the engine.
  final Set<int> openTaskIds;

  /// Speaker names (as in the transcript) that opted in to notes.
  final Set<String> optedInSpeakers;

  /// Title used when the engine returned none.
  final String fallbackTitle;

  /// Speaker names as rendered in the transcript (v1.2 vote validation);
  /// null skips the speaker check.
  final Set<String>? speakerNames;
}

String _key(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Returns [m] with the constraints of [c] enforced (see the file comment).
Minutes sanitizeMinutes(Minutes m, MinutesConstraints c) {
  List<int> ev(List<int> ids) => [
    for (final i in ids)
      if (c.segmentIds.contains(i)) i,
  ];

  final codes = m.codes;
  return m.copyWith(
    title: m.title.trim().isEmpty ? c.fallbackTitle : m.title,
    topics: [
      for (final t in m.topics)
        MinutesTopic(
          title: t.title,
          discussion: t.discussion,
          speakerNames: t.speakerNames,
          evidence: ev(t.evidence),
        ),
    ],
    decisions: [
      for (final d in m.decisions)
        MinutesDecision(
          text: d.text,
          proposedBy: d.proposedBy,
          evidence: ev(d.evidence),
          formalText: d.formalText,
          vote: sanitizeVote(d.vote, c),
        ),
    ],
    actionItems: [
      for (final a in m.actionItems)
        ActionItem(
          task: a.task,
          owner: a.owner,
          dueDate: a.dueDate,
          evidence: ev(a.evidence),
        ),
    ],
    agendaCoverage: alignAgendaCoverage(c.agenda, [
      for (final a in m.agendaCoverage)
        MinutesAgendaItem(
          item: a.item,
          status: a.status,
          note: a.note,
          evidence: ev(a.evidence),
        ),
    ]),
    taskUpdates: [
      for (final u in m.taskUpdates)
        if (c.openTaskIds.contains(u.taskId))
          MinutesTaskUpdate(
            taskId: u.taskId,
            newStatus: u.newStatus,
            note: u.note,
            evidence: ev(u.evidence),
          ),
    ],
    codes: MinutesCodes(
      codedSpeech: [
        for (final x in codes.codedSpeech)
          CodedSpeechItem(
            speaker: x.speaker,
            character: x.character,
            description: x.description,
            hypotheses: x.hypotheses,
            evidence: ev(x.evidence),
          ),
      ],
      jargon: [
        for (final x in codes.jargon)
          if (x.term.isNotEmpty)
            JargonItem(
              term: x.term,
              inferredMeaning: x.inferredMeaning,
              confidence: x.confidence,
              speakers: x.speakers,
              evidence: ev(x.evidence),
            ),
      ],
      spokenCode: [
        for (final x in codes.spokenCode)
          if (x.code.trim().isNotEmpty)
            SpokenCodeItem(
              language: x.language,
              code: x.code,
              explanation: x.explanation,
              issues: x.issues,
              speaker: x.speaker,
              evidence: ev(x.evidence),
            ),
      ],
      implied: [
        for (final x in codes.implied)
          ImpliedItem(
            literal: x.literal,
            possibleMeanings: x.possibleMeanings,
            basis: x.basis,
            confidence: x.confidence,
            speaker: x.speaker,
            evidence: ev(x.evidence),
          ),
      ],
      references: [
        for (final x in codes.references)
          if (x.verbatim.isNotEmpty)
            ReferenceItem(
              kind: x.kind,
              verbatim: x.verbatim,
              normalized: x.normalized,
              context: x.context,
              speaker: x.speaker,
              evidence: ev(x.evidence),
            ),
      ],
    ),
    speakerNotes: [
      for (final n in m.speakerNotes)
        if (c.optedInSpeakers.contains(n.speaker.trim()))
          MinutesSpeakerNote(
            speaker: n.speaker.trim(),
            knowledge: [
              for (final k in n.knowledge)
                SpeakerKnowledgeNote(
                  domain: k.domain,
                  demonstrated: k.demonstrated,
                  level: k.level,
                  evidence: ev(k.evidence),
                ),
            ],
            contributions: [
              for (final k in n.contributions)
                SpeakerContributionNote(
                  kind: k.kind,
                  text: k.text,
                  evidence: ev(k.evidence),
                ),
            ],
            style: [
              for (final k in n.style)
                SpeakerStyleNote(
                  observation: k.observation,
                  evidence: ev(k.evidence),
                ),
            ],
            summary: n.summary,
            lowEvidence: n.lowEvidence,
          ),
    ],
  );
}

/// [vote] with the v1.2 rules of [c] enforced: evidence ids limited to the
/// transcript; positions of unknown speakers (not in
/// [MinutesConstraints.speakerNames]) or of the unidentified-speaker label
/// dropped; one position per speaker (the first); a position other than
/// "unclear" / "not_voted" without valid evidence downgraded to "unclear";
/// a formal vote or consensus without any evidence (neither its own nor a
/// position's) becomes "none", keeping only stated positions with evidence.
MinutesVote sanitizeVote(MinutesVote vote, MinutesConstraints c) {
  List<int> ev(List<int> ids) => [
    for (final i in ids)
      if (c.segmentIds.contains(i)) i,
  ];
  final known = c.speakerNames == null
      ? null
      : {for (final n in c.speakerNames!) _key(n)};
  final seen = <String>{};
  final positions = <MinutesVotePosition>[];
  for (final p in vote.positions) {
    final name = p.speaker.replaceAll(' (؟)', '').trim();
    final k = _key(name);
    if (k.isEmpty || k == _key('متحدث غير محدد')) continue;
    if (known != null && !known.contains(k)) continue;
    if (!seen.add(k)) continue;
    final e = ev(p.evidence);
    final position =
        e.isEmpty &&
            p.position != VotePosition.unclear &&
            p.position != VotePosition.notVoted
        ? VotePosition.unclear
        : p.position;
    positions.add(
      MinutesVotePosition(speaker: name, position: position, evidence: e),
    );
  }
  final evidence = ev(vote.evidence);
  var mode = vote.mode;
  final supported =
      evidence.isNotEmpty || positions.any((p) => p.evidence.isNotEmpty);
  if (mode != VoteMode.none && !supported) mode = VoteMode.none;
  return MinutesVote(
    mode: mode,
    positions: mode == VoteMode.none
        ? [
            for (final p in positions)
              if (p.evidence.isNotEmpty) p,
          ]
        : positions,
    announcedResult: vote.announcedResult?.trim().isEmpty ?? true
        ? null
        : vote.announcedResult!.trim(),
    evidence: mode == VoteMode.none ? const [] : evidence,
  );
}

/// One coverage entry per [agenda] item, in agenda order. An entry of
/// [coverage] matches an item by text (whitespace / case-insensitive),
/// otherwise the entry at the same position is used when its text does not
/// match another agenda item; items left without an entry are reported as
/// not discussed. Without an agenda the result is empty.
List<MinutesAgendaItem> alignAgendaCoverage(
  List<String> agenda,
  List<MinutesAgendaItem> coverage,
) {
  if (agenda.isEmpty) return const [];
  final agendaKeys = agenda.map(_key).toList();
  final used = <int>{};
  final out = <MinutesAgendaItem>[];
  for (var i = 0; i < agenda.length; i++) {
    var match = -1;
    for (var j = 0; j < coverage.length; j++) {
      if (!used.contains(j) && _key(coverage[j].item) == agendaKeys[i]) {
        match = j;
        break;
      }
    }
    if (match < 0 &&
        i < coverage.length &&
        !used.contains(i) &&
        !agendaKeys.contains(_key(coverage[i].item))) {
      match = i;
    }
    if (match < 0) {
      out.add(
        MinutesAgendaItem(
          item: agenda[i],
          status: AgendaItemStatus.notDiscussed,
        ),
      );
      continue;
    }
    used.add(match);
    final c = coverage[match];
    out.add(
      MinutesAgendaItem(
        item: agenda[i],
        status: c.status,
        note: c.note,
        evidence: c.evidence,
      ),
    );
  }
  return out;
}
