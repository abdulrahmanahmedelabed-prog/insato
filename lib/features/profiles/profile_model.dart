// The speaker profile (F16) as stored in `SpeakerProfileRecord.profile`.
//
// Shape (version 1, snake_case keys):
//
// {
//   "version": 1,
//   "speaker_name": "سارة",
//   "built_at": ISO-8601,
//   "per_meeting": [MeetingSpeakerStats…],       // raw counts, one per meeting
//   "totals": {…},                               // derived (for readers)
//   "knowledge": [ProfileDomain…],
//   "contributions": [ProfileContribution…],
//   "contribution_counts": {"proposed": 2, …},
//   "style": [ProfileStyleItem…],
//   "summaries": [ProfileSummaryItem…],
//   "tasks": ProfileTasks,
//   "notes_meetings": 3, "low_evidence_meetings": 1,
//   "omitted_by_guardrails": 0,
//   "narrative": ["…", "…"]
// }
//
// Every item cites its evidence as `meeting_id` + `evidence` (a list of
// `TranscriptSegment.index` values of that meeting). Only observable,
// evidence-backed behaviour is stored; see profile_guardrails.dart.
//
// Pure Dart: no Flutter imports, unit-testable.

import '../../core/models.dart';

/// Version of the stored profile shape. A stored profile of another version
/// is rebuilt instead of being merged into.
const int kSpeakerProfileVersion = 1;

DateTime _date(Object? v) =>
    (v is String ? DateTime.tryParse(v) : null) ??
    DateTime.fromMillisecondsSinceEpoch(0);

int _int(Object? v) => v is int
    ? (v < 0 ? 0 : v)
    : v is num
    ? (v.isFinite && v > 0 ? v.round() : 0)
    : 0;

Map<String, int> _intMap(Object? v) => {
  if (v is Map)
    for (final e in v.entries)
      if (e.key is String && (e.key as String).isNotEmpty)
        e.key as String: _int(e.value),
};

/// Order of [DemonstrationLevel]s (mentioned < explained < led).
int levelRank(DemonstrationLevel level) => switch (level) {
  DemonstrationLevel.mentioned => 0,
  DemonstrationLevel.explained => 1,
  DemonstrationLevel.led => 2,
};

// ---------------------------------------------------------------------------
// Deterministic per-meeting statistics
// ---------------------------------------------------------------------------

/// A decision the speaker proposed, as written in a meeting's minutes.
class ProfileDecision {
  /// Creates a decision.
  const ProfileDecision({required this.text, this.evidence = const []});

  /// Decision text (Arabic).
  final String text;

  /// Segment indices of the meeting.
  final List<int> evidence;

  /// JSON form.
  Map<String, dynamic> toJson() => {'text': text, 'evidence': evidence};

  /// Parses [toJson] output.
  factory ProfileDecision.fromJson(Map<String, dynamic> j) => ProfileDecision(
    text: jsonString(j['text']),
    evidence: parseEvidenceIds(j['evidence']),
  );
}

/// Deterministic statistics of one speaker in one meeting, computed from the
/// transcript (never from the minutes engine), plus the decisions the
/// minutes attribute to the speaker.
class MeetingSpeakerStats {
  /// Creates the statistics.
  const MeetingSpeakerStats({
    required this.meetingId,
    required this.meetingTitle,
    required this.meetingAt,
    this.speakingMs = 0,
    this.meetingSpeechMs = 0,
    this.segments = 0,
    this.speechSegments = 0,
    this.turns = 0,
    this.questions = 0,
    this.questionSegments = 0,
    this.languageMs = const {},
    this.languageTransitions = 0,
    this.languageSwitches = 0,
    this.mixedTurns = 0,
    this.interruptionsGiven = 0,
    this.interruptionsReceived = 0,
    this.decisions = const [],
  });

  /// Meeting id.
  final String meetingId;

  /// Meeting title (at computation time).
  final String meetingTitle;

  /// Meeting date.
  final DateTime meetingAt;

  /// Time the speaker spoke (sum of their segments).
  final int speakingMs;

  /// Time anyone spoke in the meeting (sum of all content segments).
  final int meetingSpeechMs;

  /// Content segments of the speaker (recognised or unintelligible).
  final int segments;

  /// Recognised (non-empty) speech segments of the speaker.
  final int speechSegments;

  /// Turns: runs of consecutive segments not interrupted by another speaker.
  final int turns;

  /// Questions asked (runs of `?` / `؟` in the speaker's text).
  final int questions;

  /// Speech segments containing at least one question mark.
  final int questionSegments;

  /// Speaking time per language code (`ar`, `en`, …).
  final Map<String, int> languageMs;

  /// Consecutive pairs of the speaker's segments with known languages.
  final int languageTransitions;

  /// Of [languageTransitions], pairs whose languages differ.
  final int languageSwitches;

  /// Turns that use two languages or more.
  final int mixedTurns;

  /// Times the speaker started while someone else was still speaking.
  final int interruptionsGiven;

  /// Times someone else started while the speaker was still speaking.
  final int interruptionsReceived;

  /// Decisions the minutes attribute to the speaker (`proposed_by`).
  final List<ProfileDecision> decisions;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'meeting_id': meetingId,
    'meeting_title': meetingTitle,
    'meeting_at': meetingAt.toIso8601String(),
    'speaking_ms': speakingMs,
    'meeting_speech_ms': meetingSpeechMs,
    'segments': segments,
    'speech_segments': speechSegments,
    'turns': turns,
    'questions': questions,
    'question_segments': questionSegments,
    'language_ms': languageMs,
    'language_transitions': languageTransitions,
    'language_switches': languageSwitches,
    'mixed_turns': mixedTurns,
    'interruptions_given': interruptionsGiven,
    'interruptions_received': interruptionsReceived,
    'decisions': decisions.map((d) => d.toJson()).toList(),
  };

  /// Parses [toJson] output; null when the meeting id is missing.
  static MeetingSpeakerStats? tryParse(Map<String, dynamic> j) {
    final id = jsonString(j['meeting_id']);
    if (id.isEmpty) return null;
    return MeetingSpeakerStats(
      meetingId: id,
      meetingTitle: jsonString(j['meeting_title']),
      meetingAt: _date(j['meeting_at']),
      speakingMs: _int(j['speaking_ms']),
      meetingSpeechMs: _int(j['meeting_speech_ms']),
      segments: _int(j['segments']),
      speechSegments: _int(j['speech_segments']),
      turns: _int(j['turns']),
      questions: _int(j['questions']),
      questionSegments: _int(j['question_segments']),
      languageMs: _intMap(j['language_ms']),
      languageTransitions: _int(j['language_transitions']),
      languageSwitches: _int(j['language_switches']),
      mixedTurns: _int(j['mixed_turns']),
      interruptionsGiven: _int(j['interruptions_given']),
      interruptionsReceived: _int(j['interruptions_received']),
      decisions: jsonObjects(j['decisions'], ProfileDecision.fromJson),
    );
  }

  /// Share of the meeting's speech time (0..1).
  double get talkShare =>
      meetingSpeechMs <= 0 ? 0 : (speakingMs / meetingSpeechMs).clamp(0, 1);
}

/// Share of speech in one language.
class LanguageShare {
  /// Creates a share.
  const LanguageShare({required this.code, required this.ms, required this.share});

  /// Language code (`ar`, `en`, …).
  final String code;

  /// Speaking time in that language.
  final int ms;

  /// Share of the speaker's speech with a known language (0..1).
  final double share;
}

/// Statistics summed over all meetings.
class ProfileTotals {
  /// Sums [perMeeting].
  factory ProfileTotals.of(List<MeetingSpeakerStats> perMeeting) {
    var speaking = 0, meetingSpeech = 0, segments = 0, speech = 0;
    var turns = 0, questions = 0, questionSegments = 0;
    var transitions = 0, switches = 0, mixed = 0, given = 0, received = 0;
    var decisions = 0;
    final langs = <String, int>{};
    for (final m in perMeeting) {
      speaking += m.speakingMs;
      meetingSpeech += m.meetingSpeechMs;
      segments += m.segments;
      speech += m.speechSegments;
      turns += m.turns;
      questions += m.questions;
      questionSegments += m.questionSegments;
      transitions += m.languageTransitions;
      switches += m.languageSwitches;
      mixed += m.mixedTurns;
      given += m.interruptionsGiven;
      received += m.interruptionsReceived;
      decisions += m.decisions.length;
      m.languageMs.forEach((k, v) => langs[k] = (langs[k] ?? 0) + v);
    }
    final langTotal = langs.values.fold<int>(0, (a, b) => a + b);
    final shares =
        [
          for (final e in langs.entries)
            if (e.value > 0)
              LanguageShare(
                code: e.key,
                ms: e.value,
                share: langTotal == 0 ? 0 : e.value / langTotal,
              ),
        ]..sort((a, b) {
          final c = b.ms.compareTo(a.ms);
          return c != 0 ? c : a.code.compareTo(b.code);
        });
    return ProfileTotals._(
      meetings: perMeeting.where((m) => m.segments > 0).length,
      speakingMs: speaking,
      meetingSpeechMs: meetingSpeech,
      segments: segments,
      speechSegments: speech,
      turns: turns,
      questions: questions,
      questionSegments: questionSegments,
      languages: shares,
      languageTransitions: transitions,
      languageSwitches: switches,
      mixedTurns: mixed,
      interruptionsGiven: given,
      interruptionsReceived: received,
      decisionsProposed: decisions,
    );
  }

  const ProfileTotals._({
    required this.meetings,
    required this.speakingMs,
    required this.meetingSpeechMs,
    required this.segments,
    required this.speechSegments,
    required this.turns,
    required this.questions,
    required this.questionSegments,
    required this.languages,
    required this.languageTransitions,
    required this.languageSwitches,
    required this.mixedTurns,
    required this.interruptionsGiven,
    required this.interruptionsReceived,
    required this.decisionsProposed,
  });

  /// Meetings in which the speaker spoke.
  final int meetings;

  /// Total speaking time.
  final int speakingMs;

  /// Total speech time of those meetings (all speakers).
  final int meetingSpeechMs;

  /// Content segments.
  final int segments;

  /// Recognised speech segments.
  final int speechSegments;

  /// Turns.
  final int turns;

  /// Questions asked.
  final int questions;

  /// Speech segments with a question.
  final int questionSegments;

  /// Languages, most spoken first.
  final List<LanguageShare> languages;

  /// Language transitions (see [MeetingSpeakerStats.languageTransitions]).
  final int languageTransitions;

  /// Language switches.
  final int languageSwitches;

  /// Turns that mix languages.
  final int mixedTurns;

  /// Interruptions given.
  final int interruptionsGiven;

  /// Interruptions received.
  final int interruptionsReceived;

  /// Decisions the minutes attribute to the speaker.
  final int decisionsProposed;

  /// Share of the speech time of the meetings attended (0..1).
  double get talkShare =>
      meetingSpeechMs <= 0 ? 0 : (speakingMs / meetingSpeechMs).clamp(0, 1);

  /// Mean turn length.
  int get meanTurnMs => turns == 0 ? 0 : (speakingMs / turns).round();

  /// Share of language transitions that switch language (0..1).
  double get codeSwitchRate =>
      languageTransitions == 0 ? 0 : languageSwitches / languageTransitions;

  /// Speech segments that are statements (no question mark).
  int get statementSegments =>
      (speechSegments - questionSegments).clamp(0, speechSegments);

  /// True when there is too little speech for reliable statistics.
  bool get lowEvidence => speakingMs < 60000 || turns < 5;

  /// JSON form (derived values, for readers of the stored profile).
  Map<String, dynamic> toJson() => {
    'meetings': meetings,
    'speaking_ms': speakingMs,
    'meeting_speech_ms': meetingSpeechMs,
    'talk_share': double.parse(talkShare.toStringAsFixed(4)),
    'turns': turns,
    'mean_turn_ms': meanTurnMs,
    'questions': questions,
    'question_segments': questionSegments,
    'statement_segments': statementSegments,
    'languages': [
      for (final l in languages)
        {
          'code': l.code,
          'ms': l.ms,
          'share': double.parse(l.share.toStringAsFixed(4)),
        },
    ],
    'code_switch_rate': double.parse(codeSwitchRate.toStringAsFixed(4)),
    'mixed_turns': mixedTurns,
    'interruptions_given': interruptionsGiven,
    'interruptions_received': interruptionsReceived,
    'decisions_proposed': decisionsProposed,
    'low_evidence': lowEvidence,
  };
}

// ---------------------------------------------------------------------------
// Knowledge, contributions, style, summaries (merged per-meeting notes)
// ---------------------------------------------------------------------------

/// How a domain's demonstrated level evolved across meetings.
enum DomainTrend {
  /// Seen in one meeting only.
  single,

  /// Later meetings show a deeper level (explained / led) than earlier ones.
  deepening,

  /// About the same level throughout.
  steady,

  /// Later meetings show a lighter level than earlier ones.
  lighter;

  /// Wire value.
  String get wire => name;

  /// Parses a wire value (default [single]).
  static DomainTrend parse(Object? v) =>
      values.firstWhere((t) => t.wire == v, orElse: () => single);
}

/// One demonstration of knowledge in one meeting.
class ProfileKnowledgeItem {
  /// Creates an item.
  const ProfileKnowledgeItem({
    required this.meetingId,
    required this.meetingAt,
    required this.demonstrated,
    required this.level,
    this.evidence = const [],
    this.lowEvidence = false,
  });

  /// Meeting id.
  final String meetingId;

  /// Meeting date.
  final DateTime meetingAt;

  /// What was demonstrated (descriptive, Arabic).
  final String demonstrated;

  /// Level as evidenced in speech.
  final DemonstrationLevel level;

  /// Segment indices of the meeting.
  final List<int> evidence;

  /// The meeting's notes were marked low-evidence, or nothing is cited.
  final bool lowEvidence;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'meeting_id': meetingId,
    'meeting_at': meetingAt.toIso8601String(),
    'demonstrated': demonstrated,
    'level': level.wire,
    'evidence': evidence,
    'low_evidence': lowEvidence,
  };

  /// Parses [toJson] output.
  factory ProfileKnowledgeItem.fromJson(Map<String, dynamic> j) =>
      ProfileKnowledgeItem(
        meetingId: jsonString(j['meeting_id']),
        meetingAt: _date(j['meeting_at']),
        demonstrated: jsonString(j['demonstrated']),
        level: DemonstrationLevel.parse(j['level']),
        evidence: parseEvidenceIds(j['evidence']),
        lowEvidence: j['low_evidence'] == true,
      );
}

/// Knowledge demonstrated in one domain, across meetings.
class ProfileDomain {
  /// Creates a domain.
  const ProfileDomain({
    required this.domain,
    required this.items,
    required this.trend,
    required this.lowEvidence,
  });

  /// Domain name (Arabic, e.g. «مالية»).
  final String domain;

  /// Demonstrations, oldest first.
  final List<ProfileKnowledgeItem> items;

  /// Evolution across meetings.
  final DomainTrend trend;

  /// Too little evidence to rely on (shown flagged).
  final bool lowEvidence;

  /// Distinct meetings in which the domain appeared.
  int get meetings => items.map((i) => i.meetingId).toSet().length;

  /// Deepest level seen.
  DemonstrationLevel get highestLevel => items.isEmpty
      ? DemonstrationLevel.mentioned
      : items
            .map((i) => i.level)
            .reduce((a, b) => levelRank(b) > levelRank(a) ? b : a);

  /// Number of cited segments.
  int get evidenceCount => items.fold(0, (n, i) => n + i.evidence.length);

  /// Count of demonstrations per level.
  Map<DemonstrationLevel, int> get levelCounts {
    final out = <DemonstrationLevel, int>{};
    for (final i in items) {
      out[i.level] = (out[i.level] ?? 0) + 1;
    }
    return out;
  }

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'domain': domain,
    'meetings': meetings,
    'highest_level': highestLevel.wire,
    'trend': trend.wire,
    'low_evidence': lowEvidence,
    'items': items.map((i) => i.toJson()).toList(),
  };

  /// Parses [toJson] output.
  factory ProfileDomain.fromJson(Map<String, dynamic> j) => ProfileDomain(
    domain: jsonString(j['domain']),
    items: jsonObjects(j['items'], ProfileKnowledgeItem.fromJson),
    trend: DomainTrend.parse(j['trend']),
    lowEvidence: j['low_evidence'] == true,
  );
}

/// One contribution in one meeting.
class ProfileContribution {
  /// Creates a contribution.
  const ProfileContribution({
    required this.meetingId,
    required this.meetingAt,
    required this.kind,
    required this.text,
    this.evidence = const [],
    this.lowEvidence = false,
  });

  /// Meeting id.
  final String meetingId;

  /// Meeting date.
  final DateTime meetingAt;

  /// Kind.
  final ContributionKind kind;

  /// Description (Arabic).
  final String text;

  /// Segment indices.
  final List<int> evidence;

  /// Weakly supported.
  final bool lowEvidence;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'meeting_id': meetingId,
    'meeting_at': meetingAt.toIso8601String(),
    'kind': kind.wire,
    'text': text,
    'evidence': evidence,
    'low_evidence': lowEvidence,
  };

  /// Parses [toJson] output.
  factory ProfileContribution.fromJson(Map<String, dynamic> j) =>
      ProfileContribution(
        meetingId: jsonString(j['meeting_id']),
        meetingAt: _date(j['meeting_at']),
        kind: ContributionKind.parse(j['kind']),
        text: jsonString(j['text']),
        evidence: parseEvidenceIds(j['evidence']),
        lowEvidence: j['low_evidence'] == true,
      );
}

/// One observable communication-style observation.
class ProfileStyleItem {
  /// Creates an observation.
  const ProfileStyleItem({
    required this.meetingId,
    required this.meetingAt,
    required this.observation,
    this.evidence = const [],
    this.lowEvidence = false,
  });

  /// Meeting id.
  final String meetingId;

  /// Meeting date.
  final DateTime meetingAt;

  /// Descriptive observation (Arabic).
  final String observation;

  /// Segment indices.
  final List<int> evidence;

  /// Weakly supported.
  final bool lowEvidence;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'meeting_id': meetingId,
    'meeting_at': meetingAt.toIso8601String(),
    'observation': observation,
    'evidence': evidence,
    'low_evidence': lowEvidence,
  };

  /// Parses [toJson] output.
  factory ProfileStyleItem.fromJson(Map<String, dynamic> j) => ProfileStyleItem(
    meetingId: jsonString(j['meeting_id']),
    meetingAt: _date(j['meeting_at']),
    observation: jsonString(j['observation']),
    evidence: parseEvidenceIds(j['evidence']),
    lowEvidence: j['low_evidence'] == true,
  );
}

/// The per-meeting summary of the speaker's role.
class ProfileSummaryItem {
  /// Creates a summary.
  const ProfileSummaryItem({
    required this.meetingId,
    required this.meetingAt,
    required this.summary,
    this.lowEvidence = false,
  });

  /// Meeting id.
  final String meetingId;

  /// Meeting date.
  final DateTime meetingAt;

  /// Summary (Arabic).
  final String summary;

  /// The meeting's notes were marked low-evidence.
  final bool lowEvidence;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'meeting_id': meetingId,
    'meeting_at': meetingAt.toIso8601String(),
    'summary': summary,
    'low_evidence': lowEvidence,
  };

  /// Parses [toJson] output.
  factory ProfileSummaryItem.fromJson(Map<String, dynamic> j) =>
      ProfileSummaryItem(
        meetingId: jsonString(j['meeting_id']),
        meetingAt: _date(j['meeting_at']),
        summary: jsonString(j['summary']),
        lowEvidence: j['low_evidence'] == true,
      );
}

/// A task owned by the speaker (F9).
class ProfileTask {
  /// Creates a task entry.
  const ProfileTask({
    required this.taskId,
    required this.task,
    required this.status,
    this.meetingId,
    this.evidence = const [],
  });

  /// Task id.
  final int taskId;

  /// Task text.
  final String task;

  /// Status.
  final TaskStatus status;

  /// Source meeting (null when manual or deleted).
  final String? meetingId;

  /// Segment indices of [meetingId].
  final List<int> evidence;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'task': task,
    'status': status.wire,
    'meeting_id': meetingId,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory ProfileTask.fromJson(Map<String, dynamic> j) => ProfileTask(
    taskId: _int(j['task_id']),
    task: jsonString(j['task']),
    status: TaskStatus.parse(j['status'] is String ? j['status'] : null),
    meetingId: jsonNonEmpty(j['meeting_id']),
    evidence: parseEvidenceIds(j['evidence']),
  );
}

/// Tasks owned by the speaker.
class ProfileTasks {
  /// Creates the summary.
  const ProfileTasks({this.items = const []});

  /// Tasks, newest first.
  final List<ProfileTask> items;

  /// Tasks owned.
  int get owned => items.length;

  /// Completed.
  int get completed => items.where((t) => t.status == TaskStatus.done).length;

  /// Still open.
  int get open => items.where((t) => t.status == TaskStatus.open).length;

  /// Cancelled.
  int get cancelled =>
      items.where((t) => t.status == TaskStatus.cancelled).length;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'owned': owned,
    'completed': completed,
    'open': open,
    'cancelled': cancelled,
    'items': items.map((t) => t.toJson()).toList(),
  };

  /// Parses [toJson] output.
  factory ProfileTasks.fromJson(Object? j) => ProfileTasks(
    items: j is Map ? jsonObjects(j['items'], ProfileTask.fromJson) : const [],
  );
}

// ---------------------------------------------------------------------------
// The profile
// ---------------------------------------------------------------------------

/// The aggregated profile of one speaker.
class SpeakerProfile {
  /// Creates a profile.
  SpeakerProfile({
    required this.speakerName,
    required this.builtAt,
    this.perMeeting = const [],
    this.knowledge = const [],
    this.contributions = const [],
    this.style = const [],
    this.summaries = const [],
    this.tasks = const ProfileTasks(),
    this.notesMeetings = 0,
    this.lowEvidenceMeetings = 0,
    this.omittedByGuardrails = 0,
    this.narrative = const [],
  }) : totals = ProfileTotals.of(perMeeting);

  /// Speaker name at build time.
  final String speakerName;

  /// When the profile was built / last merged.
  final DateTime builtAt;

  /// Deterministic statistics per meeting, oldest first.
  final List<MeetingSpeakerStats> perMeeting;

  /// Sum of [perMeeting].
  final ProfileTotals totals;

  /// Demonstrated knowledge by domain, most evidenced first.
  final List<ProfileDomain> knowledge;

  /// Contributions, newest first.
  final List<ProfileContribution> contributions;

  /// Style observations, newest first.
  final List<ProfileStyleItem> style;

  /// Per-meeting summaries, newest first.
  final List<ProfileSummaryItem> summaries;

  /// Tasks owned.
  final ProfileTasks tasks;

  /// Meetings with stored notes.
  final int notesMeetings;

  /// Of [notesMeetings], those whose notes were marked low-evidence.
  final int lowEvidenceMeetings;

  /// Note items dropped by the guardrails.
  final int omittedByGuardrails;

  /// Narrative summary paragraphs (descriptive Arabic).
  final List<String> narrative;

  /// Count of contributions per kind.
  Map<ContributionKind, int> get contributionCounts {
    final out = <ContributionKind, int>{};
    for (final c in contributions) {
      out[c.kind] = (out[c.kind] ?? 0) + 1;
    }
    return out;
  }

  /// Distinct meetings covered (statistics or notes).
  Set<String> get meetingIds => {
    for (final m in perMeeting)
      if (m.segments > 0) m.meetingId,
    for (final d in knowledge)
      for (final i in d.items) i.meetingId,
    for (final c in contributions) c.meetingId,
    for (final s in style) s.meetingId,
    for (final s in summaries) s.meetingId,
  };

  /// Every evidence reference the profile cites (unique, stable order).
  List<EvidenceRef> get evidence {
    final out = <EvidenceRef>{};
    void add(String? meetingId, List<int> ids) {
      if (meetingId == null || meetingId.isEmpty) return;
      for (final i in ids) {
        out.add(EvidenceRef(meetingId: meetingId, segmentIndex: i));
      }
    }

    for (final d in knowledge) {
      for (final i in d.items) {
        add(i.meetingId, i.evidence);
      }
    }
    for (final c in contributions) {
      add(c.meetingId, c.evidence);
    }
    for (final s in style) {
      add(s.meetingId, s.evidence);
    }
    for (final m in perMeeting) {
      for (final d in m.decisions) {
        add(m.meetingId, d.evidence);
      }
    }
    for (final t in tasks.items) {
      add(t.meetingId, t.evidence);
    }
    return out.toList(growable: false);
  }

  /// True when nothing was observed yet.
  bool get isEmpty =>
      totals.segments == 0 &&
      knowledge.isEmpty &&
      contributions.isEmpty &&
      style.isEmpty &&
      summaries.isEmpty &&
      tasks.items.isEmpty;

  /// JSON form (stored in `SpeakerProfileRecord.profile`).
  Map<String, dynamic> toJson() => {
    'version': kSpeakerProfileVersion,
    'speaker_name': speakerName,
    'built_at': builtAt.toIso8601String(),
    'per_meeting': perMeeting.map((m) => m.toJson()).toList(),
    'totals': totals.toJson(),
    'knowledge': knowledge.map((d) => d.toJson()).toList(),
    'contributions': contributions.map((c) => c.toJson()).toList(),
    'contribution_counts': {
      for (final e in contributionCounts.entries) e.key.wire: e.value,
    },
    'style': style.map((s) => s.toJson()).toList(),
    'summaries': summaries.map((s) => s.toJson()).toList(),
    'tasks': tasks.toJson(),
    'notes_meetings': notesMeetings,
    'low_evidence_meetings': lowEvidenceMeetings,
    'omitted_by_guardrails': omittedByGuardrails,
    'narrative': narrative,
  };

  /// Parses [toJson] output; null when the JSON is not a profile of the
  /// current [kSpeakerProfileVersion].
  static SpeakerProfile? tryParse(Map<String, dynamic>? j) {
    if (j == null || j['version'] != kSpeakerProfileVersion) return null;
    final perMeeting = <MeetingSpeakerStats>[
      for (final m in jsonObjects(j['per_meeting'], MeetingSpeakerStats.tryParse))
        ?m,
    ];
    return SpeakerProfile(
      speakerName: jsonString(j['speaker_name']),
      builtAt: _date(j['built_at']),
      perMeeting: perMeeting,
      knowledge: jsonObjects(j['knowledge'], ProfileDomain.fromJson),
      contributions: jsonObjects(
        j['contributions'],
        ProfileContribution.fromJson,
      ),
      style: jsonObjects(j['style'], ProfileStyleItem.fromJson),
      summaries: jsonObjects(j['summaries'], ProfileSummaryItem.fromJson),
      tasks: ProfileTasks.fromJson(j['tasks']),
      notesMeetings: _int(j['notes_meetings']),
      lowEvidenceMeetings: _int(j['low_evidence_meetings']),
      omittedByGuardrails: _int(j['omitted_by_guardrails']),
      narrative: jsonStringList(j['narrative']),
    );
  }
}
