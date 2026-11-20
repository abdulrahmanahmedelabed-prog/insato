// Pure domain models added in Insato v1.2 to the minutes JSON (B — vote
// detection). No Flutter imports. Exported by `models.dart`.
//
// Same JSON conventions as models_v11.dart: snake_case keys, enum values as
// stable snake_case wire strings, tolerant parsers (unknown enum values fall
// back to a documented default, malformed entries are skipped). Minutes
// stored by v1 / v1.1 have no `formal_text` / `vote` keys and parse to
// "no vote".

import 'models_v11.dart';

/// A member's position in a vote on a resolution.
enum VotePosition {
  /// In favour (موافق).
  approve,

  /// Against (معترض).
  object,

  /// Abstained (ممتنع).
  abstain,

  /// Present but did not vote (لم يصوّت).
  notVoted,

  /// The transcript does not make the position clear (غير واضح): the
  /// secretary confirms it before approval.
  unclear;

  /// Wire value (`approve`, `object`, `abstain`, `not_voted`, `unclear`).
  String get wire => switch (this) {
    approve => 'approve',
    object => 'object',
    abstain => 'abstain',
    notVoted => 'not_voted',
    unclear => 'unclear',
  };

  /// Arabic label.
  String get labelAr => switch (this) {
    approve => 'موافق',
    object => 'معترض',
    abstain => 'ممتنع',
    notVoted => 'لم يصوّت',
    unclear => 'غير واضح',
  };

  /// Parses a wire value, defaulting to [unclear].
  static VotePosition parse(Object? s) {
    if (s is String) {
      final r = s.trim().toLowerCase();
      for (final v in values) {
        if (v.wire == r) return v;
      }
    }
    return unclear;
  }
}

/// How a resolution was adopted.
enum VoteMode {
  /// An explicit vote was held («نصوّت»، «من الموافق؟»، رفع الأيدي…).
  formalVote,

  /// Accepted without a formal vote and without objection
  /// («توافق دون تصويت رسمي»).
  consensus,

  /// No vote and no recorded agreement round (or not determinable).
  none;

  /// Wire value (`formal_vote`, `consensus`, `none`).
  String get wire => switch (this) {
    formalVote => 'formal_vote',
    consensus => 'consensus',
    none => 'none',
  };

  /// Arabic label.
  String get labelAr => switch (this) {
    formalVote => 'تصويت رسمي',
    consensus => 'توافق دون تصويت رسمي',
    none => 'لم يُرصد تصويت',
  };

  /// Parses a wire value, defaulting to [none].
  static VoteMode parse(Object? s) {
    if (s is String) {
      final r = s.trim().toLowerCase();
      for (final v in values) {
        if (v.wire == r) return v;
      }
    }
    return none;
  }
}

/// One speaker's position in a vote.
class MinutesVotePosition {
  /// Creates a position.
  const MinutesVotePosition({
    required this.speaker,
    required this.position,
    this.evidence = const [],
  });

  /// Speaker name exactly as in the transcript.
  final String speaker;

  /// The position.
  final VotePosition position;

  /// Segment indices where the position was expressed.
  final List<int> evidence;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'speaker': speaker,
    'position': position.wire,
    'evidence': evidence,
  };

  /// Parses [toJson] output.
  factory MinutesVotePosition.fromJson(Map<String, dynamic> j) =>
      MinutesVotePosition(
        speaker: jsonString(j['speaker']),
        position: VotePosition.parse(j['position']),
        evidence: parseEvidenceIds(j['evidence']),
      );

  @override
  bool operator ==(Object other) =>
      other is MinutesVotePosition &&
      other.speaker == speaker &&
      other.position == position &&
      _intListEq(other.evidence, evidence);

  @override
  int get hashCode => Object.hash(speaker, position, Object.hashAll(evidence));
}

bool _intListEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The voting moment of a resolution, as reported by the minutes engine.
class MinutesVote {
  /// Creates a vote.
  const MinutesVote({
    this.mode = VoteMode.none,
    this.positions = const [],
    this.announcedResult,
    this.evidence = const [],
  });

  /// No vote recorded (also what v1 / v1.1 minutes parse to).
  static const MinutesVote none = MinutesVote();

  /// How the resolution was adopted.
  final VoteMode mode;

  /// Positions of the speakers who expressed one.
  final List<MinutesVotePosition> positions;

  /// The result as announced in the meeting (e.g. «أُقرّ بالإجماع»), or null.
  final String? announcedResult;

  /// Segment indices of the voting moment.
  final List<int> evidence;

  /// True when nothing was recorded.
  bool get isEmpty =>
      mode == VoteMode.none && positions.isEmpty && announcedResult == null;

  /// JSON (schema shape).
  Map<String, dynamic> toJson() => {
    'mode': mode.wire,
    'announced_result': announcedResult,
    'positions': positions.map((p) => p.toJson()).toList(),
    'evidence': evidence,
  };

  /// Parses [toJson] output; anything that is not an object is [none].
  static MinutesVote fromJson(Object? v) {
    if (v is! Map) return none;
    final j = v.cast<String, dynamic>();
    return MinutesVote(
      mode: VoteMode.parse(j['mode']),
      positions: [
        for (final p in jsonObjects(
          j['positions'],
          MinutesVotePosition.fromJson,
        ))
          if (p.speaker.isNotEmpty) p,
      ],
      announcedResult: jsonNonEmpty(j['announced_result']),
      evidence: parseEvidenceIds(j['evidence']),
    );
  }

  /// Copy with replaced fields.
  MinutesVote copyWith({
    VoteMode? mode,
    List<MinutesVotePosition>? positions,
    String? announcedResult,
    bool clearAnnouncedResult = false,
    List<int>? evidence,
  }) => MinutesVote(
    mode: mode ?? this.mode,
    positions: positions ?? this.positions,
    announcedResult: clearAnnouncedResult
        ? null
        : (announcedResult ?? this.announcedResult),
    evidence: evidence ?? this.evidence,
  );
}

/// The official register the minutes engine writes in (v1.2, A): given to
/// the engine in the user message's `<minutes_template>` block.
class MinutesStyleHint {
  /// Creates a hint.
  const MinutesStyleHint({
    required this.templateName,
    required this.bodyName,
    required this.resolutionLead,
    this.votingMembers = const [],
  });

  /// Template name in Arabic (e.g. «محضر مجلس إدارة»).
  final String templateName;

  /// The meeting body (e.g. «المجلس», «اللجنة»), possibly the configured
  /// committee name.
  final String bodyName;

  /// How a resolution starts (e.g. «قرر المجلس», «أوصت اللجنة»).
  final String resolutionLead;

  /// Expected voting members (names as entered), for context only.
  final List<String> votingMembers;
}
