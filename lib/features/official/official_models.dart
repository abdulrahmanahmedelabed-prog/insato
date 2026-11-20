// Domain models of official minutes (v1.2, A/B): the entity profile, the
// uploaded Word templates, the per-meeting official record (header data,
// attendance, vote reviews, lifecycle), signatures and approved versions.
//
// Pure Dart (no Flutter), JSON round-trippable with tolerant parsers.

import 'dart:convert';

import '../../core/models.dart';
import 'official_templates.dart';

/// Which calendar year meeting numbers are counted in.
enum NumberYearStyle {
  /// Hijri year: `12/1448هـ`.
  hijri,

  /// Gregorian year: `12/2026`.
  gregorian;

  /// Parses a stored name (default [hijri]).
  static NumberYearStyle parse(Object? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => hijri);
}

/// The institution using the app (Settings → «الجهة والقوالب»).
class EntityProfile {
  /// Creates a profile.
  const EntityProfile({
    this.entityName = '',
    this.logoFile,
    this.committees = const [],
    this.secretaryName = '',
    this.chairName = '',
    this.defaultPlace = '',
    this.yearStyle = NumberYearStyle.hijri,
  });

  /// Nothing configured.
  static const EntityProfile empty = EntityProfile();

  /// Entity name (e.g. «شركة … » or «وزارة …»).
  final String entityName;

  /// Logo file name inside the app's branding folder, or null.
  final String? logoFile;

  /// Councils / committees of the entity (meeting numbers are counted per
  /// committee).
  final List<String> committees;

  /// Default secretary (أمين السر).
  final String secretaryName;

  /// Default chair (رئيس الاجتماع).
  final String chairName;

  /// Default meeting place.
  final String defaultPlace;

  /// Calendar of the meeting-number year.
  final NumberYearStyle yearStyle;

  /// JSON.
  Map<String, dynamic> toJson() => {
    'entity_name': entityName,
    'logo_file': logoFile,
    'committees': committees,
    'secretary_name': secretaryName,
    'chair_name': chairName,
    'default_place': defaultPlace,
    'year_style': yearStyle.name,
  };

  /// Parses [toJson] output (anything else → [empty]).
  static EntityProfile fromJson(Object? v) {
    if (v is! Map) return empty;
    final j = v.cast<String, dynamic>();
    return EntityProfile(
      entityName: jsonString(j['entity_name']),
      logoFile: jsonNonEmpty(j['logo_file']),
      committees: jsonStringList(j['committees']),
      secretaryName: jsonString(j['secretary_name']),
      chairName: jsonString(j['chair_name']),
      defaultPlace: jsonString(j['default_place']),
      yearStyle: NumberYearStyle.parse(j['year_style']),
    );
  }

  /// Copy with replaced fields.
  EntityProfile copyWith({
    String? entityName,
    String? logoFile,
    bool clearLogo = false,
    List<String>? committees,
    String? secretaryName,
    String? chairName,
    String? defaultPlace,
    NumberYearStyle? yearStyle,
  }) => EntityProfile(
    entityName: entityName ?? this.entityName,
    logoFile: clearLogo ? null : (logoFile ?? this.logoFile),
    committees: committees ?? this.committees,
    secretaryName: secretaryName ?? this.secretaryName,
    chairName: chairName ?? this.chairName,
    defaultPlace: defaultPlace ?? this.defaultPlace,
    yearStyle: yearStyle ?? this.yearStyle,
  );
}

/// A Word template uploaded by the user.
class CustomTemplate {
  /// Creates a template record.
  const CustomTemplate({
    required this.id,
    required this.name,
    required this.baseTemplateId,
    required this.fileName,
    this.placeholders = const [],
    required this.uploadedAt,
  });

  /// Stable id (used in `MeetingContext.template` as `custom:<id>`).
  final String id;

  /// Name shown to the user.
  final String name;

  /// The built-in template whose rules (wording, quorum, majority,
  /// signatures, numbering) it uses.
  final String baseTemplateId;

  /// File name inside the app's templates folder.
  final String fileName;

  /// Placeholders found in the file (without braces).
  final List<String> placeholders;

  /// Upload time.
  final DateTime uploadedAt;

  /// The value stored in `MeetingContext.template`.
  String get ref => '$kCustomTemplatePrefix$id';

  /// JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'base': baseTemplateId,
    'file': fileName,
    'placeholders': placeholders,
    'uploaded_at': uploadedAt.toUtc().toIso8601String(),
  };

  /// Parses [toJson] output, or null when malformed.
  static CustomTemplate? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = jsonNonEmpty(v['id']);
    final file = jsonNonEmpty(v['file']);
    if (id == null || file == null) return null;
    return CustomTemplate(
      id: id,
      name: jsonNonEmpty(v['name']) ?? id,
      baseTemplateId: OfficialTemplates.byId(jsonNonEmpty(v['base'])).id,
      fileName: file,
      placeholders: jsonStringList(v['placeholders']),
      uploadedAt:
          DateTime.tryParse(jsonString(v['uploaded_at']))?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Prefix of an uploaded template's id in `MeetingContext.template`.
const String kCustomTemplatePrefix = 'custom:';

/// The template chosen for a meeting: the built-in rules and, for an
/// uploaded template, its record.
class TemplateChoice {
  /// Creates a choice.
  const TemplateChoice(this.template, {this.custom});

  /// Built-in rules.
  final OfficialTemplate template;

  /// The uploaded Word template, if any.
  final CustomTemplate? custom;

  /// Display name.
  String get nameAr => custom?.name ?? template.nameAr;

  /// True for an official layout (any uploaded template, or an official
  /// built-in one).
  bool get isOfficial => custom != null || template.isOfficial;
}

/// Resolves `MeetingContext.template` ([ref]) against the uploaded
/// templates: `custom:<id>` → that template with its base rules (a deleted
/// one falls back to the team template), otherwise the built-in template of
/// that id (unknown / null → team).
TemplateChoice resolveTemplate(String? ref, List<CustomTemplate> customs) {
  if (ref != null && ref.startsWith(kCustomTemplatePrefix)) {
    final id = ref.substring(kCustomTemplatePrefix.length);
    for (final c in customs) {
      if (c.id == id) {
        return TemplateChoice(
          OfficialTemplates.byId(c.baseTemplateId),
          custom: c,
        );
      }
    }
    return const TemplateChoice(OfficialTemplates.team);
  }
  return TemplateChoice(OfficialTemplates.byId(ref));
}

/// Lifecycle of official minutes.
enum OfficialStatus {
  /// Being prepared.
  draft,

  /// Reviewed by the secretary (votes confirmed), awaiting approval.
  reviewed,

  /// Approved: content locked, hash fixed, signatures collected.
  approved;

  /// Arabic label.
  String get labelAr => switch (this) {
    draft => 'مسودة',
    reviewed => 'تمت المراجعة',
    approved => 'معتمد',
  };

  /// Parses a stored name (default [draft]).
  static OfficialStatus parse(Object? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => draft);
}

/// Attendance of one person.
enum AttendanceStatus {
  /// Present (voting member).
  present,

  /// Absent with an excuse.
  absentExcused,

  /// Absent without an excuse.
  absentUnexcused,

  /// Invited guest (present, does not vote or count for the quorum).
  guest;

  /// Wire value.
  String get wire => switch (this) {
    present => 'present',
    absentExcused => 'absent_excused',
    absentUnexcused => 'absent_unexcused',
    guest => 'guest',
  };

  /// Arabic label.
  String get labelAr => switch (this) {
    present => 'حاضر',
    absentExcused => 'غائب بعذر',
    absentUnexcused => 'غائب دون عذر',
    guest => 'مدعو',
  };

  /// Parses a wire value (default [present]).
  static AttendanceStatus parse(Object? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => present);
}

/// One row of the attendance sheet.
class AttendanceEntry {
  /// Creates an entry.
  const AttendanceEntry({
    required this.name,
    this.status = AttendanceStatus.present,
    this.speakerName,
    this.title = '',
    this.needsConfirmation = false,
  });

  /// Person's name as printed.
  final String name;

  /// Attendance.
  final AttendanceStatus status;

  /// The transcript speaker name this person spoke as (links vote
  /// positions), or null.
  final String? speakerName;

  /// Title / capacity (e.g. «عضواً»، «ممثل الإدارة المالية»).
  final String title;

  /// Pre-filled automatically and not yet checked by the secretary.
  final bool needsConfirmation;

  /// True for voting members (anyone but guests).
  bool get isMember => status != AttendanceStatus.guest;

  /// JSON.
  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.wire,
    'speaker': speakerName,
    'title': title,
    'needs_confirmation': needsConfirmation,
  };

  /// Parses [toJson] output, or null without a name.
  static AttendanceEntry? fromJson(Map<String, dynamic> j) {
    final name = jsonNonEmpty(j['name']);
    if (name == null) return null;
    return AttendanceEntry(
      name: name,
      status: AttendanceStatus.parse(j['status']),
      speakerName: jsonNonEmpty(j['speaker']),
      title: jsonString(j['title']),
      needsConfirmation: j['needs_confirmation'] == true,
    );
  }

  /// Copy with replaced fields.
  AttendanceEntry copyWith({
    String? name,
    AttendanceStatus? status,
    String? speakerName,
    bool clearSpeaker = false,
    String? title,
    bool? needsConfirmation,
  }) => AttendanceEntry(
    name: name ?? this.name,
    status: status ?? this.status,
    speakerName: clearSpeaker ? null : (speakerName ?? this.speakerName),
    title: title ?? this.title,
    needsConfirmation: needsConfirmation ?? this.needsConfirmation,
  );
}

/// The secretary's confirmed vote of one resolution (B review screen).
/// Keyed by the resolution's index and guarded by [decisionKey], so a
/// review never applies to a different resolution after regeneration.
class VoteReview {
  /// Creates a review.
  const VoteReview({
    required this.decisionKey,
    required this.mode,
    this.positions = const {},
  });

  /// [decisionKeyOf] of the reviewed decision.
  final String decisionKey;

  /// Confirmed mode.
  final VoteMode mode;

  /// Confirmed positions by attendee name.
  final Map<String, VotePosition> positions;

  /// JSON.
  Map<String, dynamic> toJson() => {
    'key': decisionKey,
    'mode': mode.wire,
    'positions': {for (final e in positions.entries) e.key: e.value.wire},
  };

  /// Parses [toJson] output, or null.
  static VoteReview? fromJson(Object? v) {
    if (v is! Map) return null;
    final key = jsonNonEmpty(v['key']);
    if (key == null) return null;
    final raw = v['positions'];
    return VoteReview(
      decisionKey: key,
      mode: VoteMode.parse(v['mode']),
      positions: {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.key is String && (e.key as String).trim().isNotEmpty)
              (e.key as String).trim(): VotePosition.parse(e.value),
      },
    );
  }
}

/// A stable key of a decision's text (whitespace-insensitive).
String decisionKeyOf(MinutesDecision d) =>
    d.text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Per-meeting official data (stored in `official_records`).
class OfficialRecord {
  /// Creates a record.
  const OfficialRecord({
    required this.meetingId,
    this.version = 1,
    this.status = OfficialStatus.draft,
    this.committee,
    this.meetingNumber,
    this.numberYear,
    this.yearStyle = NumberYearStyle.hijri,
    this.place = '',
    this.startTime,
    this.endTime,
    this.chair = '',
    this.secretary = '',
    this.attendance = const [],
    this.quorumOverride,
    this.majorityOverride,
    this.voteReviews = const {},
    this.approvedHash,
    this.approvedAt,
  });

  /// Meeting id.
  final String meetingId;

  /// Version of the minutes (1-based; editing after approval adds one).
  final int version;

  /// Lifecycle status.
  final OfficialStatus status;

  /// Council / committee name (meeting numbers count per committee).
  final String? committee;

  /// Meeting number within the committee and year.
  final int? meetingNumber;

  /// Year of [meetingNumber] (Hijri or Gregorian per [yearStyle]).
  final int? numberYear;

  /// Calendar of [numberYear].
  final NumberYearStyle yearStyle;

  /// Meeting place.
  final String place;

  /// Start time (default: recording start).
  final DateTime? startTime;

  /// End time (default: recording end).
  final DateTime? endTime;

  /// Chair (رئيس الاجتماع).
  final String chair;

  /// Secretary (أمين السر).
  final String secretary;

  /// Attendance sheet.
  final List<AttendanceEntry> attendance;

  /// Meeting-specific quorum rule (null = template's).
  final QuorumRule? quorumOverride;

  /// Meeting-specific majority rule (null = template's).
  final MajorityRule? majorityOverride;

  /// Secretary-confirmed votes by resolution index.
  final Map<int, VoteReview> voteReviews;

  /// SHA-256 of the approved canonical content (approved only).
  final String? approvedHash;

  /// Approval time.
  final DateTime? approvedAt;

  /// `12/1448هـ` / `12/2026`, or null without a number.
  String? get numberText {
    final n = meetingNumber;
    if (n == null) return null;
    final y = numberYear;
    if (y == null) return '$n';
    return yearStyle == NumberYearStyle.hijri ? '$n/$yهـ' : '$n/$y';
  }

  /// The year as used in resolution codes (`1448` / `2026`), or null.
  String? get yearText => numberYear?.toString();

  /// Content locked (approved).
  bool get isLocked => status == OfficialStatus.approved;

  /// JSON of the fields kept in `record_json` (everything; the indexed
  /// columns duplicate some of them).
  Map<String, dynamic> toJson() => {
    'version': version,
    'status': status.name,
    'committee': committee,
    'meeting_number': meetingNumber,
    'number_year': numberYear,
    'year_style': yearStyle.name,
    'place': place,
    'start_time': startTime?.toUtc().toIso8601String(),
    'end_time': endTime?.toUtc().toIso8601String(),
    'chair': chair,
    'secretary': secretary,
    'attendance': attendance.map((a) => a.toJson()).toList(),
    'quorum': quorumOverride?.toJson(),
    'majority': majorityOverride?.toJson(),
    'vote_reviews': {
      for (final e in voteReviews.entries) '${e.key}': e.value.toJson(),
    },
    'approved_hash': approvedHash,
    'approved_at': approvedAt?.toUtc().toIso8601String(),
  };

  /// Parses [toJson] output (tolerant).
  static OfficialRecord fromJson(String meetingId, Object? v) {
    if (v is! Map) return OfficialRecord(meetingId: meetingId);
    final j = v.cast<String, dynamic>();
    DateTime? time(Object? s) =>
        s is String ? DateTime.tryParse(s)?.toLocal() : null;
    int? integer(Object? n) => n is int ? n : (n is num ? n.toInt() : null);
    final reviews = <int, VoteReview>{};
    final rawReviews = j['vote_reviews'];
    if (rawReviews is Map) {
      for (final e in rawReviews.entries) {
        final i = int.tryParse('${e.key}');
        final r = VoteReview.fromJson(e.value);
        if (i != null && i >= 0 && r != null) reviews[i] = r;
      }
    }
    return OfficialRecord(
      meetingId: meetingId,
      version: (integer(j['version']) ?? 1).clamp(1, 1 << 30),
      status: OfficialStatus.parse(j['status']),
      committee: jsonNonEmpty(j['committee']),
      meetingNumber: integer(j['meeting_number']),
      numberYear: integer(j['number_year']),
      yearStyle: NumberYearStyle.parse(j['year_style']),
      place: jsonString(j['place']),
      startTime: time(j['start_time']),
      endTime: time(j['end_time']),
      chair: jsonString(j['chair']),
      secretary: jsonString(j['secretary']),
      attendance: [
        for (final a in jsonObjects(j['attendance'], AttendanceEntry.fromJson))
          ?a,
      ],
      quorumOverride: QuorumRule.fromJson(j['quorum']),
      majorityOverride: MajorityRule.fromJson(j['majority']),
      voteReviews: reviews,
      approvedHash: jsonNonEmpty(j['approved_hash']),
      approvedAt: time(j['approved_at']),
    );
  }

  /// Encoded [toJson].
  String encode() => jsonEncode(toJson());

  /// Copy with replaced fields.
  OfficialRecord copyWith({
    int? version,
    OfficialStatus? status,
    String? committee,
    bool clearCommittee = false,
    int? meetingNumber,
    bool clearNumber = false,
    int? numberYear,
    NumberYearStyle? yearStyle,
    String? place,
    DateTime? startTime,
    DateTime? endTime,
    String? chair,
    String? secretary,
    List<AttendanceEntry>? attendance,
    QuorumRule? quorumOverride,
    bool clearQuorum = false,
    MajorityRule? majorityOverride,
    bool clearMajority = false,
    Map<int, VoteReview>? voteReviews,
    String? approvedHash,
    DateTime? approvedAt,
    bool clearApproval = false,
  }) => OfficialRecord(
    meetingId: meetingId,
    version: version ?? this.version,
    status: status ?? this.status,
    committee: clearCommittee ? null : (committee ?? this.committee),
    meetingNumber: clearNumber ? null : (meetingNumber ?? this.meetingNumber),
    numberYear: clearNumber ? null : (numberYear ?? this.numberYear),
    yearStyle: yearStyle ?? this.yearStyle,
    place: place ?? this.place,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    chair: chair ?? this.chair,
    secretary: secretary ?? this.secretary,
    attendance: attendance ?? this.attendance,
    quorumOverride: clearQuorum
        ? null
        : (quorumOverride ?? this.quorumOverride),
    majorityOverride: clearMajority
        ? null
        : (majorityOverride ?? this.majorityOverride),
    voteReviews: voteReviews ?? this.voteReviews,
    approvedHash: clearApproval ? null : (approvedHash ?? this.approvedHash),
    approvedAt: clearApproval ? null : (approvedAt ?? this.approvedAt),
  );
}

/// A point of a signature stroke (logical pixels of the capture pad,
/// normalised to 0..1 of its width / height) with the time since the
/// stroke started.
class SignaturePoint {
  /// Creates a point.
  const SignaturePoint(this.x, this.y, {this.t = 0});

  /// 0..1 across the pad.
  final double x;

  /// 0..1 down the pad.
  final double y;

  /// Milliseconds since the first point of the signature.
  final int t;
}

/// A signature captured on the device: vector strokes, signer, time.
class MinutesSignature {
  /// Creates a signature.
  const MinutesSignature({
    this.id,
    required this.meetingId,
    required this.version,
    required this.signerName,
    this.signerRole = '',
    required this.strokes,
    required this.signedAt,
    required this.contentHash,
    this.aspectRatio = 3,
  });

  /// Row id (null before insertion).
  final int? id;

  /// Meeting id.
  final String meetingId;

  /// Minutes version signed.
  final int version;

  /// Signer's name.
  final String signerName;

  /// Capacity (رئيس الاجتماع، أمين السر، عضو…).
  final String signerRole;

  /// Strokes (each a list of normalised points).
  final List<List<SignaturePoint>> strokes;

  /// When it was signed.
  final DateTime signedAt;

  /// Hash of the approved content the signer saw.
  final String contentHash;

  /// Width / height of the pad (to draw without distortion).
  final double aspectRatio;

  /// JSON of the strokes: `{"aspect": 3, "strokes": [[[x, y, t], …], …]}`
  /// (coordinates rounded to 4 decimals).
  String strokesJson() => jsonEncode({
    'aspect': aspectRatio,
    'strokes': [
      for (final s in strokes)
        [
          for (final p in s) [_r(p.x), _r(p.y), p.t],
        ],
    ],
  });

  static double _r(double v) => (v.clamp(0.0, 1.0) * 10000).round() / 10000;

  /// Parses [strokesJson] output into (strokes, aspect ratio).
  static ({List<List<SignaturePoint>> strokes, double aspect}) parseStrokes(
    String json,
  ) {
    try {
      final d = jsonDecode(json);
      if (d is! Map) return (strokes: const [], aspect: 3);
      final a = d['aspect'];
      final out = <List<SignaturePoint>>[];
      final raw = d['strokes'];
      if (raw is List) {
        for (final s in raw) {
          if (s is! List) continue;
          final pts = <SignaturePoint>[];
          for (final p in s) {
            if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
              pts.add(
                SignaturePoint(
                  (p[0] as num).toDouble().clamp(0.0, 1.0),
                  (p[1] as num).toDouble().clamp(0.0, 1.0),
                  t: p.length > 2 && p[2] is num ? (p[2] as num).toInt() : 0,
                ),
              );
            }
          }
          if (pts.isNotEmpty) out.add(pts);
        }
      }
      return (strokes: out, aspect: a is num && a > 0 ? a.toDouble() : 3.0);
    } on FormatException {
      return (strokes: const [], aspect: 3);
    }
  }

  /// True when nothing was drawn.
  bool get isEmpty => strokes.every((s) => s.isEmpty);
}

/// An approved version kept in the history.
class MinutesVersion {
  /// Creates a version.
  const MinutesVersion({
    required this.meetingId,
    required this.version,
    required this.minutes,
    required this.record,
    required this.contentHash,
    required this.approvedAt,
  });

  /// Meeting id.
  final String meetingId;

  /// Version number.
  final int version;

  /// The minutes as approved.
  final Minutes minutes;

  /// The official record as approved.
  final OfficialRecord record;

  /// SHA-256 of the canonical content.
  final String contentHash;

  /// Approval time.
  final DateTime approvedAt;
}
