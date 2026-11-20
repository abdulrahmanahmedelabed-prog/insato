// Pure logic of official minutes (v1.2): attendance pre-fill, quorum,
// vote tallies under a majority rule, meeting-number sequencing and the
// canonical content whose SHA-256 is printed on approved minutes.
//
// Pure Dart, unit-tested.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/hijri.dart';
import '../../core/models.dart';
import '../../minutes/minutes_prompt.dart' show kUnknownSpeakerName;
import 'official_models.dart';
import 'official_templates.dart';

/// Whitespace- and case-insensitive name key.
String nameKey(String s) =>
    s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

final RegExp _autoLabel = RegExp(r'^متحدث\s*[0-9٠-٩]+$');

/// True for automatic speaker labels such as «متحدث 3».
bool isAutoSpeakerLabel(String name) => _autoLabel.hasMatch(name.trim());

// ---------------------------------------------------------------------------
// Attendance
// ---------------------------------------------------------------------------

/// Pre-fills the attendance sheet.
///
/// * every expected attendee (F3) is a member: present when a transcript
///   speaker has the same name (linked to it), otherwise absent without
///   excuse and flagged [AttendanceEntry.needsConfirmation] (people may
///   attend without speaking);
/// * every other speaker who spoke ([spokenNames], by first appearance) is
///   added as present: named speakers as members, automatic labels flagged
///   for confirmation (the secretary renames them);
/// * [existing] entries win: a person already on the sheet is kept as is,
///   so re-running the pre-fill only adds newcomers.
List<AttendanceEntry> prefillAttendance({
  required List<String> expectedAttendees,
  required List<String> spokenNames,
  List<AttendanceEntry> existing = const [],
}) {
  final out = [...existing];
  final keys = <String>{
    for (final e in existing) nameKey(e.name),
    for (final e in existing)
      if (e.speakerName != null) nameKey(e.speakerName!),
  };
  final spoken = <String, String>{
    for (final n in spokenNames)
      if (n.trim().isNotEmpty && n != kUnknownSpeakerName) nameKey(n): n.trim(),
  };
  for (final raw in expectedAttendees) {
    final name = raw.trim();
    final k = nameKey(name);
    if (k.isEmpty || keys.contains(k)) continue;
    keys.add(k);
    final spokeAs = spoken[k];
    out.add(
      AttendanceEntry(
        name: name,
        status: spokeAs != null
            ? AttendanceStatus.present
            : AttendanceStatus.absentUnexcused,
        speakerName: spokeAs,
        needsConfirmation: spokeAs == null,
      ),
    );
  }
  for (final e in spoken.entries) {
    if (keys.contains(e.key)) continue;
    keys.add(e.key);
    out.add(
      AttendanceEntry(
        name: e.value,
        speakerName: e.value,
        needsConfirmation: isAutoSpeakerLabel(e.value),
      ),
    );
  }
  return out;
}

/// Quorum of a meeting.
class QuorumResult {
  /// Creates a result.
  const QuorumResult({
    required this.rule,
    required this.members,
    required this.present,
    required this.required,
  });

  /// The rule applied.
  final QuorumRule rule;

  /// Voting members on the sheet (everyone but guests).
  final int members;

  /// Members present.
  final int present;

  /// Members required.
  final int required;

  /// True when the rule needs no quorum.
  bool get notRequired => rule.kind == QuorumKind.none;

  /// True when the quorum is met (or not required).
  bool get met => notRequired || (members > 0 && present >= required);

  /// The formal statement: «اكتمل النصاب …» / «لم يكتمل النصاب …».
  String get statementAr {
    if (notRequired) {
      return 'لا يشترط لهذا الاجتماع نصاب محدد (حضر $present من الأعضاء).';
    }
    if (members == 0) {
      return 'لم يكتمل النصاب: لم تُحدَّد قائمة الأعضاء بعد.';
    }
    return met
        ? 'اكتمل النصاب بحضور $present من أصل $members أعضاء '
              '(المطلوب $required وفق قاعدة ${rule.labelAr}).'
        : 'لم يكتمل النصاب: حضر $present من أصل $members أعضاء، '
              'والمطلوب $required وفق قاعدة ${rule.labelAr}.';
  }
}

/// Computes the quorum of [attendance] under [rule].
QuorumResult computeQuorum(List<AttendanceEntry> attendance, QuorumRule rule) {
  final members = attendance.where((a) => a.isMember).length;
  final present = attendance
      .where((a) => a.status == AttendanceStatus.present)
      .length;
  return QuorumResult(
    rule: rule,
    members: members,
    present: present,
    required: rule.requiredCount(members),
  );
}

// ---------------------------------------------------------------------------
// Votes
// ---------------------------------------------------------------------------

/// Outcome of a resolution.
enum VoteOutcome {
  /// Adopted by vote.
  passed,

  /// Rejected by vote.
  failed,

  /// Tie under the simple majority without a casting vote.
  tie,

  /// Unclear positions could change the outcome: the secretary must
  /// confirm them.
  needsReview,

  /// Accepted without a formal vote («توافق دون تصويت رسمي»).
  consensus,

  /// No voting moment recorded.
  noVote;

  /// Arabic label.
  String get labelAr => switch (this) {
    passed => 'اعتُمد',
    failed => 'لم يُعتمد',
    tie => 'تساوت الأصوات',
    needsReview => 'بحاجة إلى تأكيد أمين السر',
    consensus => 'توافق دون تصويت رسمي',
    noVote => 'لم يُرصد تصويت',
  };
}

/// One voter's line in a tally.
class VoterPosition {
  /// Creates a line.
  const VoterPosition(this.name, this.position, {this.counted = true});

  /// Attendee (or speaker) name.
  final String name;

  /// Position.
  final VotePosition position;

  /// False for guests / unknown speakers (shown, not counted).
  final bool counted;
}

/// A resolution's tally.
class VoteTally {
  /// Creates a tally.
  const VoteTally({
    required this.mode,
    required this.voters,
    required this.outcome,
    required this.rule,
    this.castingVoteUsed = false,
    this.reviewed = false,
    this.announcedResult,
  });

  /// Mode (after review).
  final VoteMode mode;

  /// Every position (members present first, in sheet order).
  final List<VoterPosition> voters;

  /// Outcome under [rule].
  final VoteOutcome outcome;

  /// Majority rule applied.
  final MajorityRule rule;

  /// The chair's casting vote decided a tie.
  final bool castingVoteUsed;

  /// Confirmed by the secretary.
  final bool reviewed;

  /// Result as announced in the meeting.
  final String? announcedResult;

  /// Number of counted voters with [p].
  int count(VotePosition p) =>
      voters.where((v) => v.counted && v.position == p).length;

  /// Names of counted voters with [p].
  List<String> names(VotePosition p) => [
    for (final v in voters)
      if (v.counted && v.position == p) v.name,
  ];

  /// True when unclear positions remain.
  bool get hasUnclear => count(VotePosition.unclear) > 0;

  /// Counts line: «موافق: 5، معترض: 1، ممتنع: 1، لم يصوّت: 0».
  String get countsAr => [
    for (final p in [
      VotePosition.approve,
      VotePosition.object,
      VotePosition.abstain,
      VotePosition.notVoted,
      if (hasUnclear) VotePosition.unclear,
    ])
      '${p.labelAr}: ${count(p)}',
  ].join('، ');

  /// One-sentence result: «اعتُمد بالأغلبية البسيطة (موافق: 5، …)».
  String get resultAr {
    switch (outcome) {
      case VoteOutcome.consensus:
      case VoteOutcome.noVote:
        final objections = names(VotePosition.object);
        final base = outcome.labelAr;
        return objections.isEmpty
            ? base
            : '$base، مع اعتراض: ${objections.join('، ')}';
      case VoteOutcome.passed:
        final how = rule.kind == MajorityKind.unanimity
            ? 'بالإجماع'
            : 'بـ${rule.kind.labelAr}';
        final casting = castingVoteUsed ? '، بترجيح صوت الرئيس' : '';
        return 'اعتُمد $how$casting ($countsAr)';
      case VoteOutcome.failed:
        final casting = castingVoteUsed ? '، بترجيح صوت الرئيس' : '';
        return 'لم يُعتمد لعدم تحقق ${rule.kind.labelAr}$casting ($countsAr)';
      case VoteOutcome.tie:
        return 'تساوت الأصوات ولم يُعتمد ($countsAr)';
      case VoteOutcome.needsReview:
        return 'النتيجة بحاجة إلى تأكيد مواقف غير واضحة ($countsAr)';
    }
  }
}

/// Applies [rule] to the counts. [base] is the number of members present
/// (or of voters when no attendance is known). [chairPosition] is used for
/// the casting vote. Returns the outcome and whether the casting vote was
/// used.
({VoteOutcome outcome, bool casting}) decideVote({
  required int approve,
  required int object,
  required int base,
  required MajorityRule rule,
  VotePosition? chairPosition,
}) {
  switch (rule.kind) {
    case MajorityKind.simple:
      if (approve > object) {
        return (outcome: VoteOutcome.passed, casting: false);
      }
      if (object > approve) {
        return (outcome: VoteOutcome.failed, casting: false);
      }
      if (approve == 0) return (outcome: VoteOutcome.failed, casting: false);
      if (rule.chairCastingVote) {
        if (chairPosition == VotePosition.approve) {
          return (outcome: VoteOutcome.passed, casting: true);
        }
        if (chairPosition == VotePosition.object) {
          return (outcome: VoteOutcome.failed, casting: true);
        }
      }
      return (outcome: VoteOutcome.tie, casting: false);
    case MajorityKind.absolute:
      return (
        outcome: approve * 2 > base ? VoteOutcome.passed : VoteOutcome.failed,
        casting: false,
      );
    case MajorityKind.twoThirds:
      return (
        outcome: base > 0 && approve * 3 >= base * 2
            ? VoteOutcome.passed
            : VoteOutcome.failed,
        casting: false,
      );
    case MajorityKind.unanimity:
      return (
        outcome: base > 0 && approve == base
            ? VoteOutcome.passed
            : VoteOutcome.failed,
        casting: false,
      );
  }
}

/// Tallies [vote] (the engine's report, possibly overridden by the
/// secretary's [review]) against the [attendance] sheet:
///
/// * a speaker's position is assigned to the attendee linked to that
///   speaker name (or with the same name); members present without a
///   position "did not vote"; positions of guests or of unknown speakers
///   are listed but not counted;
/// * without an attendance sheet every reported speaker counts;
/// * consensus / no vote never produce counts; a formal vote is decided by
///   [decideVote]; while unclear positions could change the outcome it is
///   [VoteOutcome.needsReview].
VoteTally tallyVote({
  required MinutesVote vote,
  required List<AttendanceEntry> attendance,
  required MajorityRule rule,
  String chair = '',
  VoteReview? review,
}) {
  final mode = review?.mode ?? vote.mode;
  final byKey = <String, VotePosition>{};
  for (final p in vote.positions) {
    byKey.putIfAbsent(nameKey(p.speaker), () => p.position);
  }

  final voters = <VoterPosition>[];
  final used = <String>{};
  final present = attendance
      .where((a) => a.status == AttendanceStatus.present)
      .toList();
  for (final a in present) {
    final keys = [
      nameKey(a.name),
      if (a.speakerName != null) nameKey(a.speakerName!),
    ];
    VotePosition? pos = review?.positions[a.name];
    if (pos == null) {
      for (final k in keys) {
        if (byKey[k] != null) {
          pos = byKey[k];
          break;
        }
      }
    }
    used.addAll(keys);
    voters.add(VoterPosition(a.name, pos ?? VotePosition.notVoted));
  }
  final known = attendance.isNotEmpty;
  for (final p in vote.positions) {
    final k = nameKey(p.speaker);
    if (used.contains(k)) continue;
    used.add(k);
    final entry = attendance.where(
      (a) =>
          nameKey(a.name) == k ||
          (a.speakerName != null && nameKey(a.speakerName!) == k),
    );
    final reviewed = review?.positions[p.speaker];
    voters.add(
      VoterPosition(
        entry.isNotEmpty ? entry.first.name : p.speaker,
        reviewed ?? p.position,
        counted: !known,
      ),
    );
  }

  VoteOutcome outcome;
  var casting = false;
  if (mode == VoteMode.consensus) {
    outcome = VoteOutcome.consensus;
  } else if (mode == VoteMode.none) {
    outcome = VoteOutcome.noVote;
  } else {
    int n(VotePosition p) =>
        voters.where((v) => v.counted && v.position == p).length;
    final a = n(VotePosition.approve);
    final o = n(VotePosition.object);
    final u = n(VotePosition.unclear);
    final base = known ? present.length : voters.where((v) => v.counted).length;
    VotePosition? chairPos;
    if (chair.trim().isNotEmpty) {
      for (final v in voters) {
        if (v.counted && nameKey(v.name) == nameKey(chair)) {
          chairPos = v.position;
        }
      }
    }
    if (u > 0) {
      final best = decideVote(
        approve: a + u,
        object: o,
        base: base,
        rule: rule,
        chairPosition: chairPos == VotePosition.unclear
            ? VotePosition.approve
            : chairPos,
      );
      final worst = decideVote(
        approve: a,
        object: o + u,
        base: base,
        rule: rule,
        chairPosition: chairPos == VotePosition.unclear
            ? VotePosition.object
            : chairPos,
      );
      if (best.outcome == worst.outcome) {
        outcome = best.outcome;
        casting = best.casting && worst.casting;
      } else {
        outcome = VoteOutcome.needsReview;
      }
    } else {
      final r = decideVote(
        approve: a,
        object: o,
        base: base,
        rule: rule,
        chairPosition: chairPos,
      );
      outcome = r.outcome;
      casting = r.casting;
    }
  }
  return VoteTally(
    mode: mode,
    voters: voters,
    outcome: outcome,
    rule: rule,
    castingVoteUsed: casting,
    reviewed: review != null,
    announcedResult: vote.announcedResult,
  );
}

/// The secretary's review of decision [index] of [minutes] when it still
/// matches that decision's text, else null.
VoteReview? reviewFor(OfficialRecord record, Minutes minutes, int index) {
  final r = record.voteReviews[index];
  if (r == null || index >= minutes.decisions.length) return null;
  return r.decisionKey == decisionKeyOf(minutes.decisions[index]) ? r : null;
}

/// Indices of resolutions whose votes still need the secretary (unclear
/// positions not confirmed by a review).
List<int> resolutionsNeedingReview(Minutes minutes, OfficialRecord record) => [
  for (var i = 0; i < minutes.decisions.length; i++)
    if (reviewFor(record, minutes, i) == null &&
        minutes.decisions[i].vote.positions.any(
          (p) => p.position == VotePosition.unclear,
        ))
      i,
];

// ---------------------------------------------------------------------------
// Meeting numbers
// ---------------------------------------------------------------------------

/// The year a meeting on [date] counts in under [style].
int numberYearOf(DateTime date, NumberYearStyle style) =>
    style == NumberYearStyle.hijri
    ? (UmmAlQura.fromGregorian(date.toLocal())?.year ?? date.toLocal().year)
    : date.toLocal().year;

/// Next number after the [existing] numbers of the same entity, committee
/// and year (1 when none).
int nextMeetingNumber(Iterable<int?> existing) {
  var max = 0;
  for (final n in existing) {
    if (n != null && n > max) max = n;
  }
  return max + 1;
}

// ---------------------------------------------------------------------------
// Canonical content and hash
// ---------------------------------------------------------------------------

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return v.map(_sorted).toList();
  return v;
}

/// The canonical content of official minutes: a JSON text with sorted keys
/// of everything printed as the official record — the minutes content
/// (without the private speaker notes and the code findings, which are not
/// part of the record and are never printed), the header data, attendance,
/// rules and the secretary's vote reviews. Lifecycle fields (status,
/// approval time, hash) are excluded, so approving does not change it.
String canonicalOfficialContent({
  required Meeting meeting,
  required Minutes minutes,
  required OfficialRecord record,
  required String entityName,
  required String templateId,
}) {
  final content = minutes.contentJson()
    ..remove('speaker_notes')
    ..remove('codes');
  final rec = record.toJson()
    ..remove('status')
    ..remove('approved_hash')
    ..remove('approved_at');
  return jsonEncode(
    _sorted({
      'format': 'insato-official-minutes/1',
      'meeting_id': meeting.id,
      'meeting_created_at': meeting.createdAt.toUtc().toIso8601String(),
      'entity': entityName.trim(),
      'template': templateId,
      'minutes': content,
      'record': rec,
    }),
  );
}

/// SHA-256 (lower-case hex) of [canonical] as UTF-8.
String sha256Hex(String canonical) =>
    sha256.convert(utf8.encode(canonical)).toString();

/// A short form of a hash for display: groups of four, e.g. `3f2a 9c0b …`.
String formatHash(String hex) {
  final b = StringBuffer();
  for (var i = 0; i < hex.length; i += 4) {
    if (i > 0) b.write(' ');
    b.write(hex.substring(i, i + 4 > hex.length ? hex.length : i + 4));
  }
  return b.toString();
}
