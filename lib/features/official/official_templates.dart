// Built-in official minutes templates (v1.2, A) and their rules: sections,
// numbering style, wording, quorum rule, majority rule and signatures.
//
// Templates are deliberately generic (any institution): the wording is
// chosen by the template («قرر المجلس»، «قررت الجمعية العمومية»، «أوصت
// اللجنة»، «قرر المجتمعون»). An institution's own layout is uploaded as a
// Word template in Settings (see `custom_templates.dart`) and linked to one
// of these built-in templates, whose rules it inherits.
//
// Pure Dart, unit-tested.

import '../../core/models.dart' show MinutesStyleHint;

/// How resolutions are numbered.
enum NumberingStyle {
  /// «أولاً»، «ثانياً»، …
  ordinalWords,

  /// «1.»، «2.»، …
  numeric,

  /// «قرار رقم 1/12/1448»: resolution / meeting number / year.
  resolutionCode;

  /// Wire value.
  String get wire => switch (this) {
    ordinalWords => 'ordinal_words',
    numeric => 'numeric',
    resolutionCode => 'resolution_code',
  };

  /// Parses a wire value (default [numeric]).
  static NumberingStyle parse(Object? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => numeric);
}

/// The Arabic ordinal adverbs «أولاً» … «عشرون» used by
/// [NumberingStyle.ordinalWords]; beyond 20 the numeric form is used.
const List<String> kArabicOrdinals = [
  'أولاً',
  'ثانياً',
  'ثالثاً',
  'رابعاً',
  'خامساً',
  'سادساً',
  'سابعاً',
  'ثامناً',
  'تاسعاً',
  'عاشراً',
  'حادي عشر',
  'ثاني عشر',
  'ثالث عشر',
  'رابع عشر',
  'خامس عشر',
  'سادس عشر',
  'سابع عشر',
  'ثامن عشر',
  'تاسع عشر',
  'عشرون',
];

/// Kinds of quorum rule.
enum QuorumKind {
  /// No quorum requirement.
  none,

  /// More than half of the members (half + 1 for an even count).
  halfPlusOne,

  /// At least two thirds of the members.
  twoThirds,

  /// At least [QuorumRule.percent] % of the members.
  percent;

  /// Wire value.
  String get wire => switch (this) {
    none => 'none',
    halfPlusOne => 'half_plus_one',
    twoThirds => 'two_thirds',
    percent => 'percent',
  };
}

/// The quorum rule of a meeting.
class QuorumRule {
  /// Creates a rule. [percent] is used by [QuorumKind.percent] (1..100).
  const QuorumRule(this.kind, {this.percent = 50});

  /// Rule kind.
  final QuorumKind kind;

  /// Percentage for [QuorumKind.percent].
  final int percent;

  /// Members required for a quorum among [members] voting members (0 for
  /// [QuorumKind.none]).
  int requiredCount(int members) {
    if (members <= 0) return 0;
    return switch (kind) {
      QuorumKind.none => 0,
      QuorumKind.halfPlusOne => members ~/ 2 + 1,
      QuorumKind.twoThirds => (members * 2 + 2) ~/ 3,
      QuorumKind.percent => (members * percent.clamp(1, 100) + 99) ~/ 100,
    };
  }

  /// Arabic description.
  String get labelAr => switch (kind) {
    QuorumKind.none => 'دون اشتراط نصاب',
    QuorumKind.halfPlusOne => 'الأغلبية المطلقة (النصف + 1)',
    QuorumKind.twoThirds => 'ثلثا الأعضاء',
    QuorumKind.percent => '$percent% من الأعضاء',
  };

  /// JSON.
  Map<String, dynamic> toJson() => {'kind': kind.wire, 'percent': percent};

  /// Parses [toJson] output, or null.
  static QuorumRule? fromJson(Object? v) {
    if (v is! Map) return null;
    final kind = QuorumKind.values.where((k) => k.wire == v['kind']);
    if (kind.isEmpty) return null;
    final p = v['percent'];
    return QuorumRule(kind.first, percent: p is int ? p.clamp(1, 100) : 50);
  }

  @override
  bool operator ==(Object other) =>
      other is QuorumRule && other.kind == kind && other.percent == percent;

  @override
  int get hashCode => Object.hash(kind, percent);
}

/// Kinds of majority rule for adopting a resolution.
enum MajorityKind {
  /// More votes in favour than against (abstentions not counted).
  simple,

  /// More than half of the members present in favour.
  absolute,

  /// At least two thirds of the members present in favour.
  twoThirds,

  /// Every member present in favour.
  unanimity;

  /// Wire value.
  String get wire => switch (this) {
    simple => 'simple',
    absolute => 'absolute',
    twoThirds => 'two_thirds',
    unanimity => 'unanimity',
  };

  /// Arabic label.
  String get labelAr => switch (this) {
    simple => 'الأغلبية البسيطة',
    absolute => 'الأغلبية المطلقة للحاضرين',
    twoThirds => 'أغلبية الثلثين',
    unanimity => 'الإجماع',
  };
}

/// The majority rule of a meeting body.
class MajorityRule {
  /// Creates a rule.
  const MajorityRule(this.kind, {this.chairCastingVote = false});

  /// Rule kind.
  final MajorityKind kind;

  /// On a tie under [MajorityKind.simple], the chair's vote decides.
  final bool chairCastingVote;

  /// Arabic description.
  String get labelAr => chairCastingVote && kind == MajorityKind.simple
      ? '${kind.labelAr}، ويرجَّح الجانب الذي فيه الرئيس عند التساوي'
      : kind.labelAr;

  /// JSON.
  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'chair_casting_vote': chairCastingVote,
  };

  /// Parses [toJson] output, or null.
  static MajorityRule? fromJson(Object? v) {
    if (v is! Map) return null;
    final kind = MajorityKind.values.where((k) => k.wire == v['kind']);
    if (kind.isEmpty) return null;
    return MajorityRule(
      kind.first,
      chairCastingVote: v['chair_casting_vote'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MajorityRule &&
      other.kind == kind &&
      other.chairCastingVote == chairCastingVote;

  @override
  int get hashCode => Object.hash(kind, chairCastingVote);
}

/// Who signs the minutes.
enum Signatories {
  /// The chair and the secretary.
  chairAndSecretary,

  /// Every member present (plus the secretary).
  allPresentMembers,
}

/// Sections of an official document, in order.
enum OfficialSection {
  /// Entity, meeting number, dates, place, chair, secretary.
  header,

  /// Present / absent / guests.
  attendance,

  /// Quorum statement.
  quorum,

  /// Agenda coverage.
  agenda,

  /// Executive summary.
  summary,

  /// Discussion by topic.
  discussion,

  /// Numbered resolutions with votes.
  resolutions,

  /// Action items.
  actionItems,

  /// Open questions.
  openQuestions,

  /// Next meeting.
  nextMeeting,

  /// Reliability notes.
  notes,

  /// Signature block.
  signatures,
}

/// A built-in minutes template.
class OfficialTemplate {
  /// Creates a template.
  const OfficialTemplate({
    required this.id,
    required this.nameAr,
    required this.descriptionAr,
    required this.bodyName,
    required this.resolutionLead,
    required this.resolutionNoun,
    required this.resolutionsHeading,
    required this.sections,
    required this.numbering,
    required this.quorum,
    required this.majority,
    required this.signaturesRequired,
    required this.signatories,
    required this.isOfficial,
  });

  /// Stable id stored in `MeetingContext.template`.
  final String id;

  /// Arabic name (e.g. «مجلس إدارة»).
  final String nameAr;

  /// One-line Arabic description.
  final String descriptionAr;

  /// The meeting body as named in prose (e.g. «مجلس الإدارة»).
  final String bodyName;

  /// How a resolution starts (e.g. «قرر المجلس»).
  final String resolutionLead;

  /// «قرار» or «توصية».
  final String resolutionNoun;

  /// Heading of the resolutions section («القرارات» / «التوصيات»).
  final String resolutionsHeading;

  /// Sections in order.
  final List<OfficialSection> sections;

  /// Resolution numbering.
  final NumberingStyle numbering;

  /// Default quorum rule.
  final QuorumRule quorum;

  /// Default majority rule.
  final MajorityRule majority;

  /// The minutes must be signed before they are final.
  final bool signaturesRequired;

  /// Who signs.
  final Signatories signatories;

  /// False for the simplified team template (no official header, quorum,
  /// lifecycle or signatures; the v1.1 layout).
  final bool isOfficial;

  /// Label of resolution [index] (0-based) of meeting [meetingNumber] /
  /// [year].
  String numberLabel(int index, {int? meetingNumber, String? year}) {
    final n = index + 1;
    switch (numbering) {
      case NumberingStyle.ordinalWords:
        return n <= kArabicOrdinals.length
            ? '${kArabicOrdinals[index]}:'
            : '$n.';
      case NumberingStyle.numeric:
        return '$n.';
      case NumberingStyle.resolutionCode:
        final parts = [
          '$n',
          if (meetingNumber != null) '$meetingNumber',
          if (year != null && year.isNotEmpty) year,
        ];
        return '$resolutionNoun رقم (${parts.join('/')}):';
    }
  }

  /// The style hint given to the minutes engine. [bodyName] may be
  /// replaced by the meeting's committee / council name.
  MinutesStyleHint styleHint({
    String? committee,
    List<String> votingMembers = const [],
  }) => MinutesStyleHint(
    templateName: 'محضر $nameAr',
    bodyName: (committee == null || committee.trim().isEmpty)
        ? bodyName
        : committee.trim(),
    resolutionLead: resolutionLead,
    votingMembers: votingMembers,
  );
}

const List<OfficialSection> _fullSections = [
  OfficialSection.header,
  OfficialSection.attendance,
  OfficialSection.quorum,
  OfficialSection.agenda,
  OfficialSection.summary,
  OfficialSection.discussion,
  OfficialSection.resolutions,
  OfficialSection.actionItems,
  OfficialSection.openQuestions,
  OfficialSection.nextMeeting,
  OfficialSection.notes,
  OfficialSection.signatures,
];

/// The built-in templates.
abstract final class OfficialTemplates {
  /// Simplified team meeting (the v1.1 layout; the default).
  static const OfficialTemplate team = OfficialTemplate(
    id: 'team',
    nameAr: 'اجتماع فريق (مبسّط)',
    descriptionAr: 'محضر مختصر دون نصاب أو تواقيع، كما في الإصدارات السابقة.',
    bodyName: 'المجتمعون',
    resolutionLead: 'اتفق المجتمعون على',
    resolutionNoun: 'قرار',
    resolutionsHeading: 'القرارات',
    sections: [
      OfficialSection.summary,
      OfficialSection.agenda,
      OfficialSection.discussion,
      OfficialSection.resolutions,
      OfficialSection.actionItems,
      OfficialSection.openQuestions,
      OfficialSection.nextMeeting,
      OfficialSection.notes,
    ],
    numbering: NumberingStyle.numeric,
    quorum: QuorumRule(QuorumKind.none),
    majority: MajorityRule(MajorityKind.simple),
    signaturesRequired: false,
    signatories: Signatories.chairAndSecretary,
    isOfficial: false,
  );

  /// Board of directors.
  static const OfficialTemplate board = OfficialTemplate(
    id: 'board',
    nameAr: 'مجلس إدارة',
    descriptionAr:
        'نصاب النصف + 1، أغلبية بسيطة مع ترجيح صوت الرئيس، '
        'وتوقيع الأعضاء الحاضرين.',
    bodyName: 'مجلس الإدارة',
    resolutionLead: 'قرر المجلس',
    resolutionNoun: 'قرار',
    resolutionsHeading: 'القرارات',
    sections: _fullSections,
    numbering: NumberingStyle.resolutionCode,
    quorum: QuorumRule(QuorumKind.halfPlusOne),
    majority: MajorityRule(MajorityKind.simple, chairCastingVote: true),
    signaturesRequired: true,
    signatories: Signatories.allPresentMembers,
    isOfficial: true,
  );

  /// General assembly.
  static const OfficialTemplate generalAssembly = OfficialTemplate(
    id: 'general_assembly',
    nameAr: 'جمعية عمومية',
    descriptionAr:
        'نصاب النصف + 1، أغلبية مطلقة للحاضرين، وتوقيع رئيس '
        'الاجتماع وأمين السر.',
    bodyName: 'الجمعية العمومية',
    resolutionLead: 'قررت الجمعية العمومية',
    resolutionNoun: 'قرار',
    resolutionsHeading: 'القرارات',
    sections: _fullSections,
    numbering: NumberingStyle.resolutionCode,
    quorum: QuorumRule(QuorumKind.halfPlusOne),
    majority: MajorityRule(MajorityKind.absolute),
    signaturesRequired: true,
    signatories: Signatories.chairAndSecretary,
    isOfficial: true,
  );

  /// Committee.
  static const OfficialTemplate committee = OfficialTemplate(
    id: 'committee',
    nameAr: 'لجنة',
    descriptionAr:
        'توصيات مرقّمة (أولاً، ثانياً…)، نصاب النصف + 1، أغلبية '
        'بسيطة مع ترجيح صوت الرئيس، وتوقيع الأعضاء.',
    bodyName: 'اللجنة',
    resolutionLead: 'أوصت اللجنة',
    resolutionNoun: 'توصية',
    resolutionsHeading: 'التوصيات',
    sections: _fullSections,
    numbering: NumberingStyle.ordinalWords,
    quorum: QuorumRule(QuorumKind.halfPlusOne),
    majority: MajorityRule(MajorityKind.simple, chairCastingVote: true),
    signaturesRequired: true,
    signatories: Signatories.allPresentMembers,
    isOfficial: true,
  );

  /// Administrative / government meeting.
  static const OfficialTemplate administrative = OfficialTemplate(
    id: 'administrative',
    nameAr: 'اجتماع إداري / حكومي',
    descriptionAr:
        'قرارات مرقّمة دون اشتراط نصاب، وتوقيع رئيس الاجتماع '
        'وأمين السر.',
    bodyName: 'المجتمعون',
    resolutionLead: 'قرر المجتمعون',
    resolutionNoun: 'قرار',
    resolutionsHeading: 'القرارات',
    sections: _fullSections,
    numbering: NumberingStyle.numeric,
    quorum: QuorumRule(QuorumKind.none),
    majority: MajorityRule(MajorityKind.simple),
    signaturesRequired: true,
    signatories: Signatories.chairAndSecretary,
    isOfficial: true,
  );

  /// Every built-in template, in display order.
  static const List<OfficialTemplate> all = [
    team,
    board,
    generalAssembly,
    committee,
    administrative,
  ];

  /// The built-in template [id], or [team] (also for null / unknown ids).
  static OfficialTemplate byId(String? id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return team;
  }
}
