// The official minutes as a render-ready model (v1.2, A/B): every string an
// export prints — header, both dates, attendance, quorum statement,
// numbered resolutions with their formal wording and vote result,
// signatories and the approval hash. PDF, Word, Markdown, share text and
// uploaded Word templates all render this one model, so they agree.
//
// Pure Dart (no Flutter), unit-tested.

import 'dart:typed_data';

import '../../core/hijri.dart';
import '../../core/models.dart';
import '../../core/time_format.dart';
import 'official_logic.dart';
import 'official_models.dart';
import 'official_templates.dart';

/// A numbered resolution.
class OfficialResolution {
  /// Creates a resolution.
  const OfficialResolution({
    required this.index,
    required this.label,
    required this.text,
    required this.plainText,
    required this.tally,
    this.proposedBy,
    this.evidence = const [],
  });

  /// 0-based index in `Minutes.decisions`.
  final int index;

  /// Number label («أولاً:»، «1.»، «قرار رقم (1/12/1448):»).
  final String label;

  /// Formal wording (falls back to the plain text).
  final String text;

  /// The decision as summarised.
  final String plainText;

  /// Vote tally.
  final VoteTally tally;

  /// Proposer, if known.
  final String? proposedBy;

  /// Evidence segment ids.
  final List<int> evidence;

  /// The vote line printed under the resolution, or null when nothing
  /// was recorded.
  String? get voteLine {
    if (tally.outcome == VoteOutcome.noVote &&
        tally.announcedResult == null &&
        tally.voters.isEmpty) {
      return null;
    }
    final announced = tally.announcedResult == null
        ? ''
        : ' — وأُعلن في الاجتماع: «${tally.announcedResult}»';
    return 'نتيجة التصويت: ${tally.resultAr}$announced';
  }

  /// Names per position (only positions with names), e.g.
  /// `[('معترض', ['سارة'])]`.
  List<(String, List<String>)> get namesByPosition => [
    for (final p in [
      VotePosition.approve,
      VotePosition.object,
      VotePosition.abstain,
      VotePosition.notVoted,
      VotePosition.unclear,
    ])
      if (tally.names(p).isNotEmpty) (p.labelAr, tally.names(p)),
  ];
}

/// One signatory of the minutes.
class OfficialSignatory {
  /// Creates a signatory.
  const OfficialSignatory({
    required this.name,
    required this.role,
    this.signature,
  });

  /// Name (may be empty: a blank line to sign by hand).
  final String name;

  /// Capacity.
  final String role;

  /// Captured signature of the current version, if any.
  final MinutesSignature? signature;
}

/// The render-ready official minutes.
class OfficialDocument {
  /// Creates a document (use [buildOfficialDocument]).
  const OfficialDocument({
    required this.template,
    required this.templateName,
    required this.record,
    required this.entityName,
    required this.bodyName,
    required this.documentTitle,
    required this.minutesTitle,
    required this.hijriDate,
    required this.gregorianDate,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.infoRows,
    required this.opening,
    required this.present,
    required this.absentExcused,
    required this.absentUnexcused,
    required this.guests,
    required this.quorum,
    required this.resolutions,
    required this.signatories,
    required this.contentHash,
    required this.hashMatchesApproval,
    this.logo,
    this.customTemplate,
  });

  /// Rules.
  final OfficialTemplate template;

  /// Template name shown (uploaded template's name or built-in).
  final String templateName;

  /// The official record.
  final OfficialRecord record;

  /// Entity name (may be empty).
  final String entityName;

  /// The body (committee name or template body).
  final String bodyName;

  /// «محضر اجتماع مجلس الإدارة رقم 12/1448هـ».
  final String documentTitle;

  /// Title of the minutes (subject).
  final String minutesTitle;

  /// «1 محرم 1448هـ», or '' outside the Umm al-Qura table.
  final String hijriDate;

  /// «16 يونيو 2026م».
  final String gregorianDate;

  /// Day of the week («الثلاثاء»).
  final String weekday;

  /// «10:00».
  final String startTime;

  /// «11:30», or '' when unknown.
  final String endTime;

  /// (label, value) header rows, empty values omitted.
  final List<(String, String)> infoRows;

  /// The formal opening sentence.
  final String opening;

  /// Present members (with title when set).
  final List<String> present;

  /// Absent with excuse.
  final List<String> absentExcused;

  /// Absent without excuse.
  final List<String> absentUnexcused;

  /// Invited guests.
  final List<String> guests;

  /// Quorum.
  final QuorumResult quorum;

  /// Numbered resolutions.
  final List<OfficialResolution> resolutions;

  /// Signature block.
  final List<OfficialSignatory> signatories;

  /// SHA-256 of the current canonical content.
  final String contentHash;

  /// True when approved and [contentHash] equals the approved hash.
  final bool hashMatchesApproval;

  /// Logo bytes (PNG / JPEG), if configured.
  final Uint8List? logo;

  /// The uploaded Word template used for DOCX, if any.
  final CustomTemplate? customTemplate;

  /// Approved and unchanged since.
  bool get isApproved =>
      record.status == OfficialStatus.approved && hashMatchesApproval;

  /// Status line: «الحالة: معتمد — الإصدار 2».
  String get statusLine {
    final status =
        record.status == OfficialStatus.approved && !hashMatchesApproval
        ? 'مسودة (تغيّر المحتوى بعد الاعتماد)'
        : record.status.labelAr;
    return 'الحالة: $status — الإصدار ${record.version}';
  }

  /// Footer line with the hash, only for approved minutes.
  String? get hashLine =>
      isApproved ? 'رمز التحقق (SHA-256) للمحتوى المعتمد: $contentHash' : null;

  /// Approval line, only for approved minutes.
  String? get approvalLine => isApproved && record.approvedAt != null
      ? 'اعتُمد هذا المحضر بتاريخ ${formatArabicDateTime(record.approvedAt!)}'
            '${_hijriSuffix(record.approvedAt!)}.'
      : null;

  /// Attendance lines (label, names) for non-empty groups.
  List<(String, List<String>)> get attendanceGroups => [
    if (present.isNotEmpty) ('الحاضرون', present),
    if (absentExcused.isNotEmpty) ('الغائبون بعذر', absentExcused),
    if (absentUnexcused.isNotEmpty) ('الغائبون دون عذر', absentUnexcused),
    if (guests.isNotEmpty) ('المدعوون', guests),
  ];
}

String _hijriSuffix(DateTime d) {
  final h = UmmAlQura.fromGregorian(d.toLocal());
  return h == null ? '' : ' (الموافق ${h.formatAr()})';
}

/// «1 محرم 1448هـ» for [date], or '' outside the table.
String hijriDateText(DateTime date) =>
    UmmAlQura.fromGregorian(date.toLocal())?.formatAr() ?? '';

/// «16 يونيو 2026م».
String gregorianDateText(DateTime date) => '${formatArabicShortDate(date)}م';

/// Both dates: «الثلاثاء 1 محرم 1448هـ الموافق 16 يونيو 2026م».
String bothDatesText(DateTime date) {
  final h = hijriDateText(date);
  final g = gregorianDateText(date);
  final day = weekdayText(date);
  return h.isEmpty ? '$day $g' : '$day $h الموافق $g';
}

/// Arabic weekday of [date].
String weekdayText(DateTime date) =>
    formatArabicDate(date).split('،').first.trim();

String _withTitle(AttendanceEntry a) =>
    a.title.trim().isEmpty ? a.name : '${a.name} (${a.title.trim()})';

/// Builds the render-ready document.
///
/// [signatures] are those of the record's current version. [logo] is the
/// entity's logo file content.
OfficialDocument buildOfficialDocument({
  required Meeting meeting,
  required Minutes minutes,
  required OfficialRecord record,
  required EntityProfile profile,
  required TemplateChoice choice,
  List<MinutesSignature> signatures = const [],
  Uint8List? logo,
}) {
  final t = choice.template;
  final committee = record.committee?.trim() ?? '';
  final bodyName = committee.isNotEmpty ? committee : t.bodyName;
  final start = record.startTime ?? meeting.createdAt;
  final end =
      record.endTime ??
      (meeting.durationMs > 0
          ? meeting.createdAt.add(Duration(milliseconds: meeting.durationMs))
          : null);
  final hijri = hijriDateText(start);
  final greg = gregorianDateText(start);
  final weekday = weekdayText(start);
  final number = record.numberText;
  final documentTitle = [
    'محضر اجتماع',
    if (committee.isNotEmpty) committee else t.bodyName,
    if (number != null) 'رقم $number',
  ].join(' ');

  final infoRows = <(String, String)>[
    if (number != null) ('رقم الاجتماع', number),
    ('اليوم', weekday),
    if (hijri.isNotEmpty) ('التاريخ الهجري', hijri),
    ('التاريخ الميلادي', greg),
    ('وقت البدء', formatClock(start)),
    if (end != null) ('وقت الانتهاء', formatClock(end)),
    if (record.place.trim().isNotEmpty) ('المكان', record.place.trim()),
    if (record.chair.trim().isNotEmpty) ('رئيس الاجتماع', record.chair.trim()),
    if (record.secretary.trim().isNotEmpty)
      ('أمين السر', record.secretary.trim()),
  ];

  final quorumRule = record.quorumOverride ?? t.quorum;
  final majority = record.majorityOverride ?? t.majority;
  final quorum = computeQuorum(record.attendance, quorumRule);

  final opening = StringBuffer('عقد $bodyName');
  if (profile.entityName.trim().isNotEmpty) {
    opening.write(' في ${profile.entityName.trim()}');
  }
  opening.write(' اجتماعه');
  if (number != null) opening.write(' رقم $number');
  opening.write(' يوم $weekday');
  opening.write(hijri.isEmpty ? ' $greg' : ' $hijri الموافق $greg');
  opening.write('، في تمام الساعة ${formatClock(start)}');
  if (record.place.trim().isNotEmpty) {
    opening.write('، في ${record.place.trim()}');
  }
  if (record.chair.trim().isNotEmpty) {
    opening.write('، برئاسة ${record.chair.trim()}');
  }
  opening.write('.');

  final resolutions = <OfficialResolution>[
    for (var i = 0; i < minutes.decisions.length; i++)
      () {
        final d = minutes.decisions[i];
        final formal = d.formalText?.trim() ?? '';
        return OfficialResolution(
          index: i,
          label: t.numberLabel(
            i,
            meetingNumber: record.meetingNumber,
            year: record.yearText,
          ),
          text: formal.isNotEmpty ? formal : d.text.trim(),
          plainText: d.text.trim(),
          proposedBy: d.proposedBy,
          evidence: d.evidence,
          tally: tallyVote(
            vote: d.vote,
            attendance: record.attendance,
            rule: majority,
            chair: record.chair,
            review: reviewFor(record, minutes, i),
          ),
        );
      }(),
  ];

  // Signatories.
  final sigs = <String, MinutesSignature>{};
  for (final s in signatures) {
    if (s.version == record.version) sigs[nameKey(s.signerName)] = s;
  }
  final signatories = <OfficialSignatory>[];
  final added = <String>{};
  void addSignatory(String name, String role) {
    final k = nameKey(name);
    if (k.isNotEmpty && !added.add(k)) return;
    signatories.add(
      OfficialSignatory(name: name.trim(), role: role, signature: sigs[k]),
    );
  }

  if (t.signatories == Signatories.chairAndSecretary || !t.isOfficial) {
    addSignatory(record.chair, 'رئيس الاجتماع');
    addSignatory(record.secretary, 'أمين السر');
  } else {
    if (record.chair.trim().isNotEmpty) {
      addSignatory(record.chair, 'رئيس الاجتماع');
    }
    for (final a in record.attendance) {
      if (a.status == AttendanceStatus.present) addSignatory(a.name, 'عضو');
    }
    addSignatory(record.secretary, 'أمين السر');
  }
  // Anyone else who signed (e.g. a member added later) is kept.
  for (final s in sigs.values) {
    if (!added.contains(nameKey(s.signerName))) {
      added.add(nameKey(s.signerName));
      signatories.add(
        OfficialSignatory(
          name: s.signerName,
          role: s.signerRole.isEmpty ? 'عضو' : s.signerRole,
          signature: s,
        ),
      );
    }
  }

  final hash = sha256Hex(
    canonicalOfficialContent(
      meeting: meeting,
      minutes: minutes,
      record: record,
      entityName: profile.entityName,
      templateId: choice.custom?.ref ?? t.id,
    ),
  );

  return OfficialDocument(
    template: t,
    templateName: choice.nameAr,
    record: record,
    entityName: profile.entityName.trim(),
    bodyName: bodyName,
    documentTitle: documentTitle,
    minutesTitle: minutes.title.trim().isEmpty
        ? meeting.title
        : minutes.title.trim(),
    hijriDate: hijri,
    gregorianDate: greg,
    weekday: weekday,
    startTime: formatClock(start),
    endTime: end == null ? '' : formatClock(end),
    infoRows: infoRows,
    opening: opening.toString(),
    present: [
      for (final a in record.attendance)
        if (a.status == AttendanceStatus.present) _withTitle(a),
    ],
    absentExcused: [
      for (final a in record.attendance)
        if (a.status == AttendanceStatus.absentExcused) _withTitle(a),
    ],
    absentUnexcused: [
      for (final a in record.attendance)
        if (a.status == AttendanceStatus.absentUnexcused) _withTitle(a),
    ],
    guests: [
      for (final a in record.attendance)
        if (a.status == AttendanceStatus.guest) _withTitle(a),
    ],
    quorum: quorum,
    resolutions: resolutions,
    signatories: signatories,
    contentHash: hash,
    hashMatchesApproval:
        record.status == OfficialStatus.approved && record.approvedHash == hash,
    logo: logo,
    customTemplate: choice.custom,
  );
}
