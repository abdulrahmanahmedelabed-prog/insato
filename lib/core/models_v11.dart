// Pure domain models added in Insato v1.1. No Flutter imports (usable from
// isolates and plain `dart test`).
//
// THIS FILE IS A SHARED CONTRACT (see docs/V11-CONTRACTS.md). It is exported
// by `models.dart`, so every module that imports the core models sees these
// types too. It never imports `models.dart` itself.
//
// JSON conventions: snake_case keys, enum values as stable snake_case
// strings ([wire] getters / `parse` factories). Parsers are tolerant: unknown
// enum values fall back to a documented default, malformed entries are
// skipped, missing lists are empty. This keeps minutes stored by v1 (which
// lack every v1.1 key) readable.

import 'models_v12.dart' show MinutesStyleHint;

// ---------------------------------------------------------------------------
// JSON helpers (shared by models.dart and the v1.1 models)
// ---------------------------------------------------------------------------

/// Non-blank strings of a JSON list (anything else → empty list).
List<String> jsonStringList(Object? v) => v is List
    ? v
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false)
    : const [];

/// A trimmed non-blank string, or null.
String? jsonNonEmpty(Object? v) =>
    (v is String && v.trim().isNotEmpty) ? v.trim() : null;

/// A string (trimmed), or '' for anything else.
String jsonString(Object? v) => v is String ? v.trim() : '';

/// Evidence / segment-index list: non-negative integers (numeric strings and
/// whole doubles are accepted), duplicates removed, ascending order.
List<int> parseEvidenceIds(Object? v) {
  if (v is! List) return const [];
  final out = <int>{};
  for (final e in v) {
    int? n;
    if (e is int) {
      n = e;
    } else if (e is double && e.isFinite && e == e.roundToDouble()) {
      n = e.toInt();
    } else if (e is String) {
      n = int.tryParse(e.trim().replaceFirst('#', ''));
    }
    if (n != null && n >= 0) out.add(n);
  }
  return (out.toList()..sort());
}

/// Maps of a JSON list of objects through [f]; non-object entries skipped.
List<T> jsonObjects<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    v is List
    ? v
          .whereType<Map>()
          .map((m) => f(m.cast<String, dynamic>()))
          .toList(growable: false)
    : <T>[];

T _enumByWire<T extends Enum>(
  List<T> values,
  String Function(T) wire,
  Object? raw,
  T fallback,
) {
  if (raw is! String) return fallback;
  final r = raw.trim().toLowerCase();
  for (final v in values) {
    if (wire(v) == r) return v;
  }
  return fallback;
}

String _snake(String camel) => camel.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m.group(0)!.toLowerCase()}',
);

// ---------------------------------------------------------------------------
// Transcript segments (F17 retention)
// ---------------------------------------------------------------------------

/// What a stored transcript segment contains.
enum SegmentKind {
  /// Recognised speech (the normal case).
  speech,

  /// Real speech (VAD) that the recogniser could not decode: empty,
  /// hallucination-filtered or low-confidence output. The text may be empty
  /// or hold the recogniser's low-confidence guess; the audio is the
  /// segment's `startMs..endMs` range of the meeting WAV.
  unintelligible;

  /// Stored / wire value (`speech`, `unintelligible`).
  String get wire => name;

  /// Parses a stored value, defaulting to [speech].
  static SegmentKind parse(String? s) =>
      _enumByWire(values, (v) => v.wire, s, speech);
}

/// Why an ASR engine returned no usable text for a segment. Set on
/// `AsrResult.rejection`; null means "not rejected" (or an engine that does
/// not report it).
enum AsrRejection {
  /// The audio is (near) silence: not speech, safe to drop.
  silence,

  /// The engine decoded voiced audio but produced no text.
  noText,

  /// The engine's output was removed by the hallucination filter.
  filtered,

  /// The engine produced text with a confidence below the threshold.
  lowConfidence;

  /// Wire value for isolate messages (`silence`, `no_text`, …).
  String get wire => _snake(name);

  /// Parses [wire] values; null / unknown → null.
  static AsrRejection? tryParse(Object? s) {
    if (s is! String) return null;
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Meeting context (F3)
// ---------------------------------------------------------------------------

/// Pre-meeting context entered by the user (all optional).
class MeetingContext {
  /// Creates a context.
  const MeetingContext({
    this.agenda = const [],
    this.expectedAttendees = const [],
    this.contextNotes,
    this.template,
  });

  /// No context.
  static const MeetingContext empty = MeetingContext();

  /// Ordered agenda items.
  final List<String> agenda;

  /// Names of people expected to attend.
  final List<String> expectedAttendees;

  /// Free-text background notes.
  final String? contextNotes;

  /// Minutes template id (reserved for v1.2 official templates).
  final String? template;

  /// True when nothing was entered.
  bool get isEmpty =>
      agenda.isEmpty &&
      expectedAttendees.isEmpty &&
      (contextNotes == null || contextNotes!.trim().isEmpty) &&
      (template == null || template!.trim().isEmpty);

  /// Copy with replaced fields; `clear*` flags reset nullable fields.
  MeetingContext copyWith({
    List<String>? agenda,
    List<String>? expectedAttendees,
    String? contextNotes,
    bool clearContextNotes = false,
    String? template,
    bool clearTemplate = false,
  }) => MeetingContext(
    agenda: agenda ?? this.agenda,
    expectedAttendees: expectedAttendees ?? this.expectedAttendees,
    contextNotes: clearContextNotes
        ? null
        : (contextNotes ?? this.contextNotes),
    template: clearTemplate ? null : (template ?? this.template),
  );

  @override
  bool operator ==(Object other) =>
      other is MeetingContext &&
      _listEq(other.agenda, agenda) &&
      _listEq(other.expectedAttendees, expectedAttendees) &&
      other.contextNotes == contextNotes &&
      other.template == template;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(agenda),
    Object.hashAll(expectedAttendees),
    contextNotes,
    template,
  );
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Glossary (F2)
// ---------------------------------------------------------------------------

/// Category of a glossary term.
enum GlossaryCategory {
  /// A person's name.
  person,

  /// An organisation, company, team or department.
  organisation,

  /// A technical or domain term, product or acronym.
  technical,

  /// Anything else.
  other;

  /// Stored value.
  String get wire => name;

  /// Parses a stored value, defaulting to [other].
  static GlossaryCategory parse(String? s) =>
      _enumByWire(values, (v) => v.wire, s, other);
}

/// A custom-vocabulary entry (canonical spelling).
class GlossaryTerm {
  /// Creates a term.
  const GlossaryTerm({
    required this.id,
    required this.term,
    required this.category,
    required this.createdAt,
    this.arSpelling,
    this.meetingId,
  });

  /// Database id (0 before insertion).
  final int id;

  /// The term exactly as it should be spelled (any script).
  final String term;

  /// Optional Arabic spelling / translation.
  final String? arSpelling;

  /// Category.
  final GlossaryCategory category;

  /// Meeting id for a meeting-only term (F3); null for a global term.
  final String? meetingId;

  /// Creation time.
  final DateTime createdAt;

  /// True for a term that applies to every meeting.
  bool get isGlobal => meetingId == null;
}

// ---------------------------------------------------------------------------
// Tasks (F9)
// ---------------------------------------------------------------------------

/// Status of a tracked task.
enum TaskStatus {
  /// Not done yet.
  open,

  /// Completed.
  done,

  /// No longer needed.
  cancelled;

  /// Stored / wire value.
  String get wire => name;

  /// Parses a stored value, defaulting to [open].
  static TaskStatus parse(String? s) =>
      _enumByWire(values, (v) => v.wire, s, open);
}

/// An action item tracked across meetings.
class TrackedTask {
  /// Creates a task.
  const TrackedTask({
    required this.id,
    required this.task,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.ownerSpeakerId,
    this.ownerText,
    this.dueText,
    this.sourceMeetingId,
    this.evidenceSegmentIds = const [],
  });

  /// Database id (0 before insertion). Also the `task_id` given to the
  /// minutes engine.
  final int id;

  /// Arabic task description.
  final String task;

  /// Owner as a speaker (voiceprint) when known.
  final String? ownerSpeakerId;

  /// Owner as free text (as written in the minutes or by the user).
  final String? ownerText;

  /// Deadline as stated (free text, e.g. «الخميس القادم»).
  final String? dueText;

  /// Status.
  final TaskStatus status;

  /// Meeting whose minutes created the task (null when entered manually or
  /// the meeting was deleted).
  final String? sourceMeetingId;

  /// Segment indices (in the source meeting) evidencing the task.
  final List<int> evidenceSegmentIds;

  /// Creation time.
  final DateTime createdAt;

  /// Last change.
  final DateTime updatedAt;

  /// Copy with replaced fields.
  TrackedTask copyWith({
    String? task,
    String? ownerSpeakerId,
    bool clearOwnerSpeaker = false,
    String? ownerText,
    bool clearOwnerText = false,
    String? dueText,
    bool clearDue = false,
    TaskStatus? status,
    DateTime? updatedAt,
  }) => TrackedTask(
    id: id,
    task: task ?? this.task,
    ownerSpeakerId: clearOwnerSpeaker
        ? null
        : (ownerSpeakerId ?? this.ownerSpeakerId),
    ownerText: clearOwnerText ? null : (ownerText ?? this.ownerText),
    dueText: clearDue ? null : (dueText ?? this.dueText),
    status: status ?? this.status,
    sourceMeetingId: sourceMeetingId,
    evidenceSegmentIds: evidenceSegmentIds,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// A status change proposed by a meeting's minutes, awaiting the user's
/// confirmation before it is applied to the task.
class PendingTaskUpdate {
  /// Creates a pending update.
  const PendingTaskUpdate({
    required this.id,
    required this.taskId,
    required this.meetingId,
    required this.newStatus,
    required this.createdAt,
    this.note,
    this.evidenceSegmentIds = const [],
  });

  /// Database id (0 before insertion).
  final int id;

  /// The task concerned.
  final int taskId;

  /// The meeting whose minutes proposed the update.
  final String meetingId;

  /// Proposed status (`open` = progress note only, no status change).
  final TaskStatus newStatus;

  /// Arabic note (what was said about the task).
  final String? note;

  /// Segment indices in [meetingId] evidencing the update.
  final List<int> evidenceSegmentIds;

  /// Creation time.
  final DateTime createdAt;
}

// ---------------------------------------------------------------------------
// Evidence references across meetings (F5 / F16)
// ---------------------------------------------------------------------------

/// A pointer to one transcript segment of one meeting.
class EvidenceRef {
  /// Creates a reference.
  const EvidenceRef({required this.meetingId, required this.segmentIndex});

  /// Meeting id.
  final String meetingId;

  /// `TranscriptSegment.index` within the meeting.
  final int segmentIndex;

  /// JSON form `{"meeting_id": …, "segment": …}`.
  Map<String, dynamic> toJson() => {
    'meeting_id': meetingId,
    'segment': segmentIndex,
  };

  /// Parses [toJson] output; null when malformed.
  static EvidenceRef? tryParse(Object? j) {
    if (j is! Map) return null;
    final m = j['meeting_id'];
    final s = j['segment'];
    if (m is! String || m.isEmpty || s is! int || s < 0) return null;
    return EvidenceRef(meetingId: m, segmentIndex: s);
  }

  @override
  bool operator ==(Object other) =>
      other is EvidenceRef &&
      other.meetingId == meetingId &&
      other.segmentIndex == segmentIndex;

  @override
  int get hashCode => Object.hash(meetingId, segmentIndex);
}

// ---------------------------------------------------------------------------
// Speaker profiles (F16)
// ---------------------------------------------------------------------------

/// The aggregated profile of one speaker (stored as JSON; its shape is owned
/// by the profiles feature, `lib/features/profiles`).
class SpeakerProfileRecord {
  /// Creates a record.
  const SpeakerProfileRecord({
    required this.speakerId,
    required this.profile,
    required this.updatedAt,
    this.evidence = const [],
  });

  /// Speaker id (primary key).
  final String speakerId;

  /// Profile JSON (see `lib/features/profiles`).
  final Map<String, dynamic> profile;

  /// All evidence the profile cites.
  final List<EvidenceRef> evidence;

  /// Last rebuild / merge.
  final DateTime updatedAt;
}

/// Per-meeting notes about one opted-in speaker, extracted with the minutes.
class SpeakerMeetingNotesRecord {
  /// Creates a record.
  const SpeakerMeetingNotesRecord({
    required this.speakerId,
    required this.meetingId,
    required this.notes,
  });

  /// Speaker id.
  final String speakerId;

  /// Meeting id.
  final String meetingId;

  /// The notes (the minutes' [MinutesSpeakerNote] for that speaker).
  final MinutesSpeakerNote notes;
}

// ---------------------------------------------------------------------------
// Code findings (F17)
// ---------------------------------------------------------------------------

/// Detector that produced a code finding.
enum CodeFindingKind {
  /// Coded / obfuscated / unintelligible speech.
  speechCoded,

  /// Internal code, codename, abbreviation or jargon.
  jargon,

  /// Source code, commands, SQL or URLs dictated aloud.
  spokenCode,

  /// Indirect / implied speech.
  implied,

  /// Reference numbers and identifiers.
  reference;

  /// Stored value (`speech_coded`, `jargon`, `spoken_code`, `implied`,
  /// `reference`).
  String get wire => _snake(name);

  /// Parses a stored value, defaulting to [jargon].
  static CodeFindingKind parse(String? s) =>
      _enumByWire(values, (v) => v.wire, s, jargon);
}

/// One stored F17 finding of a meeting.
class CodeFinding {
  /// Creates a finding.
  const CodeFinding({
    required this.id,
    required this.meetingId,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.speakerId,
    this.segmentIds = const [],
  });

  /// Database id (0 before insertion).
  final int id;

  /// Meeting id.
  final String meetingId;

  /// Detector.
  final CodeFindingKind kind;

  /// Speaker who said it, when resolved to a voiceprint.
  final String? speakerId;

  /// Segment indices (evidence) in [meetingId].
  final List<int> segmentIds;

  /// The finding (the JSON of the matching `Minutes*` item class, possibly
  /// enriched by post-processing such as a reversed-audio re-ASR result).
  final Map<String, dynamic> payload;

  /// Creation time.
  final DateTime createdAt;
}

// ---------------------------------------------------------------------------
// Minutes v1.1 sections
// ---------------------------------------------------------------------------

/// How an agenda item was covered in the meeting.
enum AgendaItemStatus {
  /// Discussed.
  discussed,

  /// Touched on briefly / not concluded.
  partiallyDiscussed,

  /// Not discussed.
  notDiscussed;

  /// Wire value (`discussed`, `partially_discussed`, `not_discussed`).
  String get wire => _snake(name);

  /// Parses a wire value, defaulting to [notDiscussed].
  static AgendaItemStatus parse(Object? s) =>
      _enumByWire(values, (v) => v.wire, s, notDiscussed);
}

/// Coverage of one agenda item, in agenda order.
class MinutesAgendaItem {
  /// Creates an item.
  const MinutesAgendaItem({
    required this.item,
    required this.status,
    this.note,
    this.evidence = const [],
  });

  /// Agenda item text as given.
  final String item;

  /// Coverage.
  final AgendaItemStatus status;

  /// Arabic note (outcome or why it was not discussed).
  final String? note;

  /// Segment indices.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'item': item,
    'status': status.wire,
    'note': note,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory MinutesAgendaItem.fromJson(Map<String, dynamic> j) =>
      MinutesAgendaItem(
        item: jsonString(j['item']),
        status: AgendaItemStatus.parse(j['status']),
        note: jsonNonEmpty(j['note']),
        evidence: parseEvidenceIds(j['evidence']),
      );
}

/// A progress / status update about an open task (F9), proposed by the
/// minutes and applied only after the user confirms.
class MinutesTaskUpdate {
  /// Creates an update.
  const MinutesTaskUpdate({
    required this.taskId,
    required this.newStatus,
    this.note,
    this.evidence = const [],
  });

  /// `TrackedTask.id` from the open-task list given to the engine.
  final int taskId;

  /// Proposed status (`open` = progress only).
  final TaskStatus newStatus;

  /// Arabic note.
  final String? note;

  /// Segment indices.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'new_status': newStatus.wire,
    'note': note,
    'evidence': evidence,
  };

  /// Parses [toJson] output; null when `task_id` is missing or invalid.
  static MinutesTaskUpdate? tryParse(Map<String, dynamic> j) {
    final raw = j['task_id'];
    final id = raw is int
        ? raw
        : (raw is num && raw == raw.roundToDouble())
        ? raw.toInt()
        : raw is String
        ? int.tryParse(raw.trim())
        : null;
    if (id == null || id <= 0) return null;
    return MinutesTaskUpdate(
      taskId: id,
      newStatus: TaskStatus.parse(j['new_status'] as String?),
      note: jsonNonEmpty(j['note']),
      evidence: parseEvidenceIds(j['evidence']),
    );
  }
}

/// Strength of a hypothesis or inference.
enum HypothesisConfidence {
  /// Weak support.
  low,

  /// Moderate support.
  medium,

  /// Strong support.
  high;

  /// Wire value.
  String get wire => name;

  /// Parses a wire value, defaulting to [low].
  static HypothesisConfidence parse(Object? s) =>
      _enumByWire(values, (v) => v.wire, s, low);
}

/// Level at which a speaker demonstrated knowledge of a domain in one
/// meeting (as evidenced in speech only).
enum DemonstrationLevel {
  /// Mentioned / used the domain's vocabulary.
  mentioned,

  /// Explained something or answered a question in the domain.
  explained,

  /// Led the discussion or a decision in the domain.
  led;

  /// Wire value.
  String get wire => name;

  /// Parses a wire value, defaulting to [mentioned].
  static DemonstrationLevel parse(Object? s) =>
      _enumByWire(values, (v) => v.wire, s, mentioned);
}

/// Knowledge a speaker demonstrated in one domain.
class SpeakerKnowledgeNote {
  /// Creates a note.
  const SpeakerKnowledgeNote({
    required this.domain,
    required this.demonstrated,
    required this.level,
    this.evidence = const [],
  });

  /// Domain in Arabic (e.g. «مالية»).
  final String domain;

  /// What was demonstrated (descriptive, Arabic).
  final String demonstrated;

  /// Level as evidenced in speech.
  final DemonstrationLevel level;

  /// Segment indices.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'domain': domain,
    'demonstrated': demonstrated,
    'level': level.wire,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory SpeakerKnowledgeNote.fromJson(Map<String, dynamic> j) =>
      SpeakerKnowledgeNote(
        domain: jsonString(j['domain']),
        demonstrated: jsonString(j['demonstrated']),
        level: DemonstrationLevel.parse(j['level']),
        evidence: parseEvidenceIds(j['evidence']),
      );
}

/// Kind of a speaker's contribution.
enum ContributionKind {
  /// Proposed something.
  proposed,

  /// Announced / made a decision.
  decided,

  /// Took on a task.
  tookTask,

  /// Answered a question.
  answeredQuestion,

  /// Asked a question.
  askedQuestion,

  /// Raised a concern or objection.
  raisedConcern,

  /// Anything else.
  other;

  /// Wire value (`took_task`, …).
  String get wire => _snake(name);

  /// Parses a wire value, defaulting to [other].
  static ContributionKind parse(Object? s) =>
      _enumByWire(values, (v) => v.wire, s, other);
}

/// One contribution of a speaker.
class SpeakerContributionNote {
  /// Creates a note.
  const SpeakerContributionNote({
    required this.kind,
    required this.text,
    this.evidence = const [],
  });

  /// Kind.
  final ContributionKind kind;

  /// Arabic description.
  final String text;

  /// Segment indices.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'text': text,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory SpeakerContributionNote.fromJson(Map<String, dynamic> j) =>
      SpeakerContributionNote(
        kind: ContributionKind.parse(j['kind']),
        text: jsonString(j['text']),
        evidence: parseEvidenceIds(j['evidence']),
      );
}

/// An observable communication-style observation.
class SpeakerStyleNote {
  /// Creates a note.
  const SpeakerStyleNote({required this.observation, this.evidence = const []});

  /// Descriptive, non-judgemental Arabic observation.
  final String observation;

  /// Segment indices.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'observation': observation,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory SpeakerStyleNote.fromJson(Map<String, dynamic> j) =>
      SpeakerStyleNote(
        observation: jsonString(j['observation']),
        evidence: parseEvidenceIds(j['evidence']),
      );
}

/// Per-meeting notes about one speaker who opted in to profiles (F16).
/// Only observable, evidence-backed behaviour; never sensitive inferences.
class MinutesSpeakerNote {
  /// Creates notes.
  const MinutesSpeakerNote({
    required this.speaker,
    this.knowledge = const [],
    this.contributions = const [],
    this.style = const [],
    this.summary,
    this.lowEvidence = false,
  });

  /// Speaker name exactly as in the transcript.
  final String speaker;

  /// Demonstrated knowledge by domain.
  final List<SpeakerKnowledgeNote> knowledge;

  /// Contributions.
  final List<SpeakerContributionNote> contributions;

  /// Style observations.
  final List<SpeakerStyleNote> style;

  /// Short descriptive Arabic summary of the speaker's role in the meeting.
  final String? summary;

  /// True when the speaker said too little for reliable notes.
  final bool lowEvidence;

  /// All evidence ids cited in these notes (ascending, unique).
  List<int> get allEvidence => parseEvidenceIds([
    for (final k in knowledge) ...k.evidence,
    for (final c in contributions) ...c.evidence,
    for (final s in style) ...s.evidence,
  ]);

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'speaker': speaker,
    'knowledge': knowledge.map((e) => e.toJson()).toList(),
    'contributions': contributions.map((e) => e.toJson()).toList(),
    'style': style.map((e) => e.toJson()).toList(),
    'summary': summary,
    'low_evidence': lowEvidence,
  };

  /// Parses [toJson] output.
  factory MinutesSpeakerNote.fromJson(Map<String, dynamic> j) =>
      MinutesSpeakerNote(
        speaker: jsonString(j['speaker']),
        knowledge: jsonObjects(j['knowledge'], SpeakerKnowledgeNote.fromJson),
        contributions: jsonObjects(
          j['contributions'],
          SpeakerContributionNote.fromJson,
        ),
        style: jsonObjects(j['style'], SpeakerStyleNote.fromJson),
        summary: jsonNonEmpty(j['summary']),
        lowEvidence: j['low_evidence'] == true,
      );
}

/// How coded / unintelligible speech appears (F17 detector 1).
enum CodedSpeechCharacter {
  /// Looks like a real language the recogniser does not support.
  unsupportedLanguage,

  /// Looks like time-reversed speech.
  reversedSpeech,

  /// Spelled-out letters or numbers.
  lettersOrNumbers,

  /// Whispering / very low voice.
  whispering,

  /// Invented or "secret" language, shuffled syllables.
  inventedLanguage,

  /// Cannot be characterised.
  unknown;

  /// Wire value (`unsupported_language`, …).
  String get wire => _snake(name);

  /// Parses a wire value, defaulting to [unknown].
  static CodedSpeechCharacter parse(Object? s) =>
      _enumByWire(values, (v) => v.wire, s, unknown);
}

/// One interpretation hypothesis (never presented as fact).
class CodeHypothesis {
  /// Creates a hypothesis.
  const CodeHypothesis({
    required this.meaning,
    required this.confidence,
    required this.basis,
  });

  /// The hypothesised meaning (Arabic).
  final String meaning;

  /// Confidence.
  final HypothesisConfidence confidence;

  /// Why (Arabic): the contextual clues used.
  final String basis;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'meaning': meaning,
    'confidence': confidence.wire,
    'basis': basis,
  };

  /// Parses [toJson] output.
  factory CodeHypothesis.fromJson(Map<String, dynamic> j) => CodeHypothesis(
    meaning: jsonString(j['meaning']),
    confidence: HypothesisConfidence.parse(j['confidence']),
    basis: jsonString(j['basis']),
  );
}

/// Coded / obfuscated / unintelligible speech.
class CodedSpeechItem {
  /// Creates an item.
  const CodedSpeechItem({
    required this.speaker,
    required this.character,
    required this.description,
    this.hypotheses = const [],
    this.evidence = const [],
  });

  /// Speaker name as in the transcript.
  final String speaker;

  /// Characterisation.
  final CodedSpeechCharacter character;

  /// Arabic description (duration, context).
  final String description;

  /// Interpretation hypotheses (may be empty).
  final List<CodeHypothesis> hypotheses;

  /// Segment indices (the unintelligible segments).
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'speaker': speaker,
    'character': character.wire,
    'description': description,
    'hypotheses': hypotheses.map((h) => h.toJson()).toList(),
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory CodedSpeechItem.fromJson(Map<String, dynamic> j) => CodedSpeechItem(
    speaker: jsonString(j['speaker']),
    character: CodedSpeechCharacter.parse(j['character']),
    description: jsonString(j['description']),
    hypotheses: jsonObjects(j['hypotheses'], CodeHypothesis.fromJson),
    evidence: parseEvidenceIds(j['evidence']),
  );
}

/// An internal code, codename, abbreviation or jargon term.
class JargonItem {
  /// Creates an item.
  const JargonItem({
    required this.term,
    required this.inferredMeaning,
    required this.confidence,
    this.speakers = const [],
    this.evidence = const [],
  });

  /// The term as used (original script).
  final String term;

  /// Meaning inferred from context (Arabic; shown as «مستنتج»).
  final String inferredMeaning;

  /// Confidence of the inference.
  final HypothesisConfidence confidence;

  /// Speakers who used it, most frequent first.
  final List<String> speakers;

  /// Segment indices (first use first).
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'term': term,
    'inferred_meaning': inferredMeaning,
    'confidence': confidence.wire,
    'speakers': speakers,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory JargonItem.fromJson(Map<String, dynamic> j) => JargonItem(
    term: jsonString(j['term']),
    inferredMeaning: jsonString(j['inferred_meaning']),
    confidence: HypothesisConfidence.parse(j['confidence']),
    speakers: jsonStringList(j['speakers']),
    evidence: parseEvidenceIds(j['evidence']),
  );
}

/// Source code / commands / SQL / URLs dictated aloud, reconstructed.
class SpokenCodeItem {
  /// Creates an item.
  const SpokenCodeItem({
    required this.language,
    required this.code,
    required this.explanation,
    required this.speaker,
    this.issues = const [],
    this.evidence = const [],
  });

  /// Detected language (`python`, `sql`, `bash`, `url`, …).
  final String language;

  /// Reconstructed, formatted code.
  final String code;

  /// Short Arabic explanation.
  final String explanation;

  /// Potential issues (Arabic).
  final List<String> issues;

  /// Speaker name as in the transcript.
  final String speaker;

  /// Segment indices.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'language': language,
    'code': code,
    'explanation': explanation,
    'issues': issues,
    'speaker': speaker,
    'evidence': evidence,
  };

  /// Parses [toJson] output (code keeps its whitespace).
  factory SpokenCodeItem.fromJson(Map<String, dynamic> j) => SpokenCodeItem(
    language: jsonString(j['language']),
    code: j['code'] is String ? j['code'] as String : '',
    explanation: jsonString(j['explanation']),
    issues: jsonStringList(j['issues']),
    speaker: jsonString(j['speaker']),
    evidence: parseEvidenceIds(j['evidence']),
  );
}

/// Indirect / implied speech (flagged cautiously, never as fact).
class ImpliedItem {
  /// Creates an item.
  const ImpliedItem({
    required this.literal,
    required this.basis,
    required this.confidence,
    required this.speaker,
    this.possibleMeanings = const [],
    this.evidence = const [],
  });

  /// What was literally said (Arabic rendering).
  final String literal;

  /// Possible meanings (Arabic).
  final List<String> possibleMeanings;

  /// Why it may be implied (Arabic).
  final String basis;

  /// Confidence.
  final HypothesisConfidence confidence;

  /// Speaker name as in the transcript.
  final String speaker;

  /// Segment indices.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'literal': literal,
    'possible_meanings': possibleMeanings,
    'basis': basis,
    'confidence': confidence.wire,
    'speaker': speaker,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory ImpliedItem.fromJson(Map<String, dynamic> j) => ImpliedItem(
    literal: jsonString(j['literal']),
    possibleMeanings: jsonStringList(j['possible_meanings']),
    basis: jsonString(j['basis']),
    confidence: HypothesisConfidence.parse(j['confidence']),
    speaker: jsonString(j['speaker']),
    evidence: parseEvidenceIds(j['evidence']),
  );
}

/// Kind of a reference number / identifier.
enum ReferenceKind {
  /// Contract number.
  contract,

  /// Invoice number.
  invoice,

  /// Ticket / issue number.
  ticket,

  /// Article of a law / regulation.
  legalArticle,

  /// Product code / SKU / model.
  product,

  /// Bank / customer account number.
  account,

  /// Monetary amount.
  amount,

  /// Date or time.
  date,

  /// Phone number.
  phone,

  /// Anything else.
  other;

  /// Wire value (`legal_article`, …).
  String get wire => _snake(name);

  /// Parses a wire value, defaulting to [other].
  static ReferenceKind parse(Object? s) =>
      _enumByWire(values, (v) => v.wire, s, other);
}

/// A reference number / identifier quoted in the meeting.
class ReferenceItem {
  /// Creates an item.
  const ReferenceItem({
    required this.kind,
    required this.verbatim,
    required this.normalized,
    required this.context,
    required this.speaker,
    this.evidence = const [],
  });

  /// Kind.
  final ReferenceKind kind;

  /// Exactly as it appears in the transcript.
  final String verbatim;

  /// Normalised form (Western digits, canonical separators).
  final String normalized;

  /// What it refers to (Arabic).
  final String context;

  /// Speaker name as in the transcript.
  final String speaker;

  /// Segment indices.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'verbatim': verbatim,
    'normalized': normalized,
    'context': context,
    'speaker': speaker,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory ReferenceItem.fromJson(Map<String, dynamic> j) => ReferenceItem(
    kind: ReferenceKind.parse(j['kind']),
    verbatim: jsonString(j['verbatim']),
    normalized: jsonString(j['normalized']),
    context: jsonString(j['context']),
    speaker: jsonString(j['speaker']),
    evidence: parseEvidenceIds(j['evidence']),
  );
}

/// The F17 section of the minutes.
class MinutesCodes {
  /// Creates the section.
  const MinutesCodes({
    this.codedSpeech = const [],
    this.jargon = const [],
    this.spokenCode = const [],
    this.implied = const [],
    this.references = const [],
  });

  /// Nothing found.
  static const MinutesCodes empty = MinutesCodes();

  /// Detector 1.
  final List<CodedSpeechItem> codedSpeech;

  /// Detector 2.
  final List<JargonItem> jargon;

  /// Detector 3.
  final List<SpokenCodeItem> spokenCode;

  /// Detector 4.
  final List<ImpliedItem> implied;

  /// Detector 5.
  final List<ReferenceItem> references;

  /// True when every detector list is empty.
  bool get isEmpty =>
      codedSpeech.isEmpty &&
      jargon.isEmpty &&
      spokenCode.isEmpty &&
      implied.isEmpty &&
      references.isEmpty;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'coded_speech': codedSpeech.map((e) => e.toJson()).toList(),
    'jargon': jargon.map((e) => e.toJson()).toList(),
    'spoken_code': spokenCode.map((e) => e.toJson()).toList(),
    'implied': implied.map((e) => e.toJson()).toList(),
    'references': references.map((e) => e.toJson()).toList(),
  };

  /// Parses [toJson] output; anything but an object → [empty].
  factory MinutesCodes.fromJson(Object? j) {
    if (j is! Map) return empty;
    final m = j.cast<String, dynamic>();
    return MinutesCodes(
      codedSpeech: jsonObjects(m['coded_speech'], CodedSpeechItem.fromJson),
      jargon: jsonObjects(m['jargon'], JargonItem.fromJson),
      spokenCode: jsonObjects(m['spoken_code'], SpokenCodeItem.fromJson),
      implied: jsonObjects(m['implied'], ImpliedItem.fromJson),
      references: jsonObjects(m['references'], ReferenceItem.fromJson),
    );
  }
}

// ---------------------------------------------------------------------------
// Minutes engine inputs (F2, F9)
// ---------------------------------------------------------------------------

/// Extra, per-request inputs of a minutes engine beyond the meeting (whose
/// `Meeting.context` carries agenda / attendees / notes), its transcript and
/// the speakers (whose `Speaker.profileEnabled` selects F16 notes).
class MinutesInputs {
  /// Creates inputs.
  const MinutesInputs({
    this.glossary = const [],
    this.openTasks = const [],
    this.taskSourceTitles = const {},
    this.style,
  });

  /// No extra inputs (v1 behaviour).
  static const MinutesInputs none = MinutesInputs();

  /// Canonical spellings: global terms plus this meeting's terms (F2/F3).
  final List<GlossaryTerm> glossary;

  /// Open tasks from earlier meetings (F9); the engine may report progress
  /// on them in `Minutes.taskUpdates` (by [TrackedTask.id]).
  final List<TrackedTask> openTasks;

  /// Titles of the meetings the [openTasks] came from (meeting id → title).
  final Map<String, String> taskSourceTitles;

  /// v1.2 (A): official register of the chosen template; null = the
  /// neutral default.
  final MinutesStyleHint? style;
}
