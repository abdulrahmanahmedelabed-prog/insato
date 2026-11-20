import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/official/official_document.dart';
import 'package:insato/features/official/official_logic.dart';
import 'package:insato/features/official/official_models.dart';
import 'package:insato/features/official/official_outline.dart';
import 'package:insato/features/official/official_templates.dart';

AttendanceEntry present(String n, {String? speaker}) =>
    AttendanceEntry(name: n, speakerName: speaker);

MinutesVote formal(Map<String, VotePosition> p) => MinutesVote(
  mode: VoteMode.formalVote,
  positions: [
    for (final e in p.entries)
      MinutesVotePosition(speaker: e.key, position: e.value, evidence: [1]),
  ],
  evidence: const [1],
);

void main() {
  group('templates', () {
    test('quorum rules', () {
      const half = QuorumRule(QuorumKind.halfPlusOne);
      expect(half.requiredCount(9), 5);
      expect(half.requiredCount(10), 6);
      const twoThirds = QuorumRule(QuorumKind.twoThirds);
      expect(twoThirds.requiredCount(9), 6);
      expect(twoThirds.requiredCount(10), 7);
      expect(
        const QuorumRule(QuorumKind.percent, percent: 75).requiredCount(10),
        8,
      );
      expect(const QuorumRule(QuorumKind.none).requiredCount(10), 0);
      expect(QuorumRule.fromJson(twoThirds.toJson()), twoThirds);
    });

    test('numbering styles and lookup', () {
      expect(OfficialTemplates.committee.numberLabel(1), 'ثانياً:');
      expect(OfficialTemplates.administrative.numberLabel(0), '1.');
      expect(
        OfficialTemplates.board.numberLabel(2, meetingNumber: 12, year: '1448'),
        'قرار رقم (3/12/1448):',
      );
      expect(OfficialTemplates.byId(null), OfficialTemplates.team);
      expect(OfficialTemplates.byId('nope'), OfficialTemplates.team);
      expect(OfficialTemplates.team.isOfficial, isFalse);
      final hint = OfficialTemplates.committee.styleHint(
        committee: 'لجنة المشتريات',
      );
      expect(hint.bodyName, 'لجنة المشتريات');
      expect(hint.resolutionLead, 'أوصت اللجنة');
    });

    test('resolveTemplate handles uploaded and deleted templates', () {
      final c = CustomTemplate(
        id: 'x1',
        name: 'قالبنا',
        baseTemplateId: 'committee',
        fileName: 'template_x1.docx',
        uploadedAt: DateTime(2026),
      );
      final r = resolveTemplate('custom:x1', [c]);
      expect(r.custom, same(c));
      expect(r.template, OfficialTemplates.committee);
      expect(r.isOfficial, isTrue);
      expect(
        resolveTemplate('custom:gone', [c]).template,
        OfficialTemplates.team,
      );
      expect(
        resolveTemplate('board', const []).template,
        OfficialTemplates.board,
      );
      expect(CustomTemplate.fromJson(c.toJson())!.baseTemplateId, 'committee');
    });
  });

  group('attendance', () {
    test('prefill links expected attendees to speakers and flags the rest', () {
      final list = prefillAttendance(
        expectedAttendees: ['أحمد', 'سارة', ' أحمد '],
        spokenNames: ['أحمد', 'متحدث 2', 'متحدث غير محدد', 'خالد'],
      );
      expect(list.map((a) => a.name), ['أحمد', 'سارة', 'متحدث 2', 'خالد']);
      expect(list[0].status, AttendanceStatus.present);
      expect(list[0].speakerName, 'أحمد');
      expect(list[1].status, AttendanceStatus.absentUnexcused);
      expect(list[1].needsConfirmation, isTrue);
      expect(list[2].needsConfirmation, isTrue);
      expect(list[3].needsConfirmation, isFalse);
      // Re-running keeps existing entries and adds only newcomers.
      final again = prefillAttendance(
        expectedAttendees: ['سارة', 'منى'],
        spokenNames: ['خالد'],
        existing: [list[1].copyWith(status: AttendanceStatus.absentExcused)],
      );
      expect(again.map((a) => a.name), ['سارة', 'منى', 'خالد']);
      expect(again.first.status, AttendanceStatus.absentExcused);
    });

    test('quorum statement', () {
      final sheet = [
        present('أ'),
        present('ب'),
        present('ج'),
        const AttendanceEntry(
          name: 'د',
          status: AttendanceStatus.absentExcused,
        ),
        const AttendanceEntry(
          name: 'هـ',
          status: AttendanceStatus.absentUnexcused,
        ),
        const AttendanceEntry(name: 'ضيف', status: AttendanceStatus.guest),
      ];
      final q = computeQuorum(sheet, const QuorumRule(QuorumKind.halfPlusOne));
      expect((q.members, q.present, q.required, q.met), (5, 3, 3, true));
      expect(q.statementAr, startsWith('اكتمل النصاب'));
      final q2 = computeQuorum(sheet, const QuorumRule(QuorumKind.twoThirds));
      expect(q2.met, isFalse);
      expect(q2.statementAr, startsWith('لم يكتمل النصاب'));
      expect(
        computeQuorum(const [], const QuorumRule(QuorumKind.halfPlusOne)).met,
        isFalse,
      );
      expect(
        computeQuorum(const [], const QuorumRule(QuorumKind.none)).met,
        isTrue,
      );
    });
  });

  group('votes', () {
    final sheet = [
      present('أحمد', speaker: 'متحدث 1'),
      present('سارة'),
      present('خالد'),
      present('منى'),
      const AttendanceEntry(name: 'ضيف', status: AttendanceStatus.guest),
    ];

    test('simple majority with names, non-voters and guests', () {
      final t = tallyVote(
        vote: formal({
          'متحدث 1': VotePosition.approve,
          'سارة': VotePosition.approve,
          'خالد': VotePosition.object,
          'ضيف': VotePosition.object,
        }),
        attendance: sheet,
        rule: const MajorityRule(MajorityKind.simple),
      );
      expect(t.outcome, VoteOutcome.passed);
      expect(t.names(VotePosition.approve), ['أحمد', 'سارة']);
      expect(t.names(VotePosition.notVoted), ['منى']);
      expect(t.count(VotePosition.object), 1);
      expect(t.voters.firstWhere((v) => v.name == 'ضيف').counted, isFalse);
      expect(t.resultAr, contains('اعتُمد'));
    });

    test('tie: chair casting vote decides only when enabled', () {
      final vote = formal({
        'متحدث 1': VotePosition.approve,
        'سارة': VotePosition.object,
      });
      final noCasting = tallyVote(
        vote: vote,
        attendance: sheet,
        rule: const MajorityRule(MajorityKind.simple),
        chair: 'أحمد',
      );
      expect(noCasting.outcome, VoteOutcome.tie);
      final casting = tallyVote(
        vote: vote,
        attendance: sheet,
        rule: const MajorityRule(MajorityKind.simple, chairCastingVote: true),
        chair: 'أحمد',
      );
      expect(casting.outcome, VoteOutcome.passed);
      expect(casting.castingVoteUsed, isTrue);
      expect(casting.resultAr, contains('بترجيح صوت الرئيس'));
    });

    test('two-thirds, absolute and unanimity count members present', () {
      final vote = formal({
        'متحدث 1': VotePosition.approve,
        'سارة': VotePosition.approve,
        'خالد': VotePosition.approve,
        'منى': VotePosition.abstain,
      });
      expect(
        tallyVote(
          vote: vote,
          attendance: sheet,
          rule: const MajorityRule(MajorityKind.twoThirds),
        ).outcome,
        VoteOutcome.passed,
      );
      expect(
        tallyVote(
          vote: vote,
          attendance: sheet,
          rule: const MajorityRule(MajorityKind.absolute),
        ).outcome,
        VoteOutcome.passed,
      );
      expect(
        tallyVote(
          vote: vote,
          attendance: sheet,
          rule: const MajorityRule(MajorityKind.unanimity),
        ).outcome,
        VoteOutcome.failed,
      );
      expect(
        decideVote(
          approve: 2,
          object: 0,
          base: 4,
          rule: const MajorityRule(MajorityKind.absolute),
        ).outcome,
        VoteOutcome.failed,
      );
    });

    test('unclear positions need review only when they matter', () {
      final decisive = tallyVote(
        vote: formal({
          'متحدث 1': VotePosition.approve,
          'سارة': VotePosition.unclear,
          'خالد': VotePosition.object,
        }),
        attendance: sheet,
        rule: const MajorityRule(MajorityKind.simple),
      );
      expect(decisive.outcome, VoteOutcome.needsReview);
      final irrelevant = tallyVote(
        vote: formal({
          'متحدث 1': VotePosition.approve,
          'سارة': VotePosition.approve,
          'منى': VotePosition.approve,
          'خالد': VotePosition.unclear,
        }),
        attendance: sheet,
        rule: const MajorityRule(MajorityKind.simple),
      );
      expect(irrelevant.outcome, VoteOutcome.passed);
    });

    test('the secretary review overrides positions and mode', () {
      final t = tallyVote(
        vote: formal({
          'متحدث 1': VotePosition.approve,
          'سارة': VotePosition.unclear,
        }),
        attendance: sheet,
        rule: const MajorityRule(MajorityKind.simple),
        review: const VoteReview(
          decisionKey: 'k',
          mode: VoteMode.formalVote,
          positions: {'سارة': VotePosition.object, 'خالد': VotePosition.object},
        ),
      );
      expect(t.reviewed, isTrue);
      expect(t.outcome, VoteOutcome.failed);
      final consensus = tallyVote(
        vote: const MinutesVote(mode: VoteMode.consensus, evidence: [3]),
        attendance: sheet,
        rule: const MajorityRule(MajorityKind.simple),
      );
      expect(consensus.outcome, VoteOutcome.consensus);
      expect(consensus.resultAr, 'توافق دون تصويت رسمي');
    });

    test('without an attendance sheet every reported speaker counts', () {
      final t = tallyVote(
        vote: formal({
          'أ': VotePosition.approve,
          'ب': VotePosition.object,
          'ج': VotePosition.approve,
        }),
        attendance: const [],
        rule: const MajorityRule(MajorityKind.simple),
      );
      expect(t.outcome, VoteOutcome.passed);
      expect(t.voters.every((v) => v.counted), isTrue);
    });

    test('reviews apply only to the same decision text', () {
      const d = MinutesDecision(text: 'اعتماد  الميزانية');
      final minutes = _minutes([d]);
      final record = OfficialRecord(
        meetingId: 'm',
        voteReviews: {
          0: VoteReview(
            decisionKey: decisionKeyOf(d),
            mode: VoteMode.consensus,
          ),
        },
      );
      expect(reviewFor(record, minutes, 0), isNotNull);
      final changed = _minutes([const MinutesDecision(text: 'قرار آخر')]);
      expect(reviewFor(record, changed, 0), isNull);
    });
  });

  group('numbers and hash', () {
    test('meeting numbers', () {
      expect(nextMeetingNumber([]), 1);
      expect(nextMeetingNumber([3, null, 11, 2]), 12);
      expect(numberYearOf(DateTime(2026, 6, 16), NumberYearStyle.hijri), 1448);
      expect(numberYearOf(DateTime(2026, 6, 15), NumberYearStyle.hijri), 1447);
      expect(
        numberYearOf(DateTime(2026, 6, 16), NumberYearStyle.gregorian),
        2026,
      );
      expect(
        const OfficialRecord(
          meetingId: 'm',
          meetingNumber: 12,
          numberYear: 1448,
        ).numberText,
        '12/1448هـ',
      );
    });

    test('canonical content is stable, sorted and ignores lifecycle', () {
      final meeting = Meeting(
        id: 'm',
        title: 't',
        createdAt: DateTime.utc(2026, 6, 16, 8),
        status: MeetingStatus.ready,
      );
      final minutes = _minutes([const MinutesDecision(text: 'قرار')]);
      const record = OfficialRecord(meetingId: 'm', place: 'القاعة');
      String c(OfficialRecord r) => canonicalOfficialContent(
        meeting: meeting,
        minutes: minutes,
        record: r,
        entityName: 'الجهة',
        templateId: 'board',
      );
      final a = c(record);
      final approved = c(
        record.copyWith(
          status: OfficialStatus.approved,
          approvedHash: 'x',
          approvedAt: DateTime(2026),
        ),
      );
      expect(a, approved);
      expect(sha256Hex(a), hasLength(64));
      expect(sha256Hex(a), sha256Hex(approved));
      expect(sha256Hex(c(record.copyWith(place: 'أخرى'))), isNot(sha256Hex(a)));
      // Speaker notes are private and never part of the record.
      final withNotes = canonicalOfficialContent(
        meeting: meeting,
        minutes: minutes.copyWith(
          speakerNotes: const [MinutesSpeakerNote(speaker: 'أ')],
        ),
        record: record,
        entityName: 'الجهة',
        templateId: 'board',
      );
      expect(withNotes, a);
      expect(
        sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(formatHash('abcdefgh12'), 'abcd efgh 12');
    });
  });

  group('document and outline', () {
    test('builds the official document with both dates and votes', () {
      final meeting = Meeting(
        id: 'm',
        title: 'اجتماع',
        createdAt: DateTime(2026, 6, 16, 10),
        status: MeetingStatus.ready,
        durationMs: 90 * 60 * 1000,
      );
      final minutes = _minutes([
        MinutesDecision(
          text: 'اعتماد الميزانية',
          formalText: 'قرر المجلس اعتماد الميزانية',
          vote: formal({
            'أحمد': VotePosition.approve,
            'سارة': VotePosition.object,
          }),
        ),
      ]);
      final record = OfficialRecord(
        meetingId: 'm',
        committee: 'مجلس الإدارة',
        meetingNumber: 12,
        numberYear: 1448,
        chair: 'أحمد',
        secretary: 'منى',
        place: 'قاعة الاجتماعات',
        attendance: [present('أحمد'), present('سارة'), present('خالد')],
      );
      final doc = buildOfficialDocument(
        meeting: meeting,
        minutes: minutes,
        record: record,
        profile: const EntityProfile(entityName: 'شركة المثال'),
        choice: const TemplateChoice(OfficialTemplates.board),
      );
      expect(doc.documentTitle, 'محضر اجتماع مجلس الإدارة رقم 12/1448هـ');
      expect(doc.hijriDate, '1 محرم 1448هـ');
      expect(doc.gregorianDate, contains('2026'));
      expect(doc.endTime, '11:30');
      expect(
        doc.opening,
        contains('عقد مجلس الإدارة في شركة المثال اجتماعه رقم 12/1448هـ'),
      );
      expect(doc.opening, contains('1 محرم 1448هـ الموافق'));
      final r = doc.resolutions.single;
      expect(r.label, 'قرار رقم (1/12/1448):');
      expect(r.text, 'قرر المجلس اعتماد الميزانية');
      // 1–1 tie decided by the chair's casting vote (board template).
      expect(r.tally.outcome, VoteOutcome.passed);
      expect(r.tally.castingVoteUsed, isTrue);
      expect(r.voteLine, contains('بترجيح صوت الرئيس'));
      // Board: chair first, every present member, then the secretary.
      expect(doc.signatories.map((s) => s.name), [
        'أحمد',
        'سارة',
        'خالد',
        'منى',
      ]);
      expect(doc.isApproved, isFalse);
      expect(doc.hashLine, isNull);

      final outline = officialOutline(doc, minutes);
      expect(outline.whereType<OutlineResolution>(), hasLength(1));
      expect(outline.last, isA<OutlineSignatures>());
      expect(
        outline.whereType<OutlineParagraph>().map((p) => p.text),
        contains('وانتهى الاجتماع في تمام الساعة 11:30.'),
      );

      final approved = buildOfficialDocument(
        meeting: meeting,
        minutes: minutes,
        record: record.copyWith(
          status: OfficialStatus.approved,
          approvedHash: doc.contentHash,
          approvedAt: DateTime(2026, 6, 17),
        ),
        profile: const EntityProfile(entityName: 'شركة المثال'),
        choice: const TemplateChoice(OfficialTemplates.board),
      );
      expect(approved.isApproved, isTrue);
      expect(approved.hashLine, contains(doc.contentHash));
    });
  });

  group('signatures', () {
    test('strokes round trip through JSON', () {
      final s = MinutesSignature(
        meetingId: 'm',
        version: 1,
        signerName: 'أ',
        strokes: const [
          [
            SignaturePoint(0.123456, 1.5, t: 10),
            SignaturePoint(0.5, 0.5, t: 20),
          ],
        ],
        signedAt: DateTime(2026),
        contentHash: 'h',
      );
      final parsed = MinutesSignature.parseStrokes(s.strokesJson());
      expect(parsed.strokes.single.first.x, closeTo(0.1235, 1e-9));
      expect(parsed.strokes.single.first.y, 1.0);
      expect(parsed.strokes.single.last.t, 20);
      expect(parsed.aspect, 3);
      expect(MinutesSignature.parseStrokes('{bad').strokes, isEmpty);
    });
  });

  test('records round trip', () {
    final r = OfficialRecord(
      meetingId: 'm',
      version: 2,
      status: OfficialStatus.reviewed,
      committee: 'لجنة',
      meetingNumber: 3,
      numberYear: 2026,
      yearStyle: NumberYearStyle.gregorian,
      startTime: DateTime(2026, 1, 1, 9),
      attendance: const [
        AttendanceEntry(
          name: 'أ',
          status: AttendanceStatus.guest,
          title: 'خبير',
        ),
      ],
      quorumOverride: const QuorumRule(QuorumKind.twoThirds),
      majorityOverride: const MajorityRule(MajorityKind.unanimity),
      voteReviews: const {
        1: VoteReview(
          decisionKey: 'k',
          mode: VoteMode.consensus,
          positions: {'أ': VotePosition.abstain},
        ),
      },
    );
    final back = OfficialRecord.fromJson('m', r.toJson());
    expect(back.toJson(), r.toJson());
    expect(back.numberText, '3/2026');
    expect(OfficialRecord.fromJson('m', 'junk').version, 1);
    final p = const EntityProfile(entityName: 'ج', committees: ['أ', 'ب']);
    expect(EntityProfile.fromJson(p.toJson()).committees, ['أ', 'ب']);
  });
}

Minutes _minutes(List<MinutesDecision> decisions) => Minutes(
  title: 'محضر',
  summary: 'ملخص',
  attendees: const [],
  topics: const [],
  decisions: decisions,
  actionItems: const [ActionItem(task: 'مهمة', owner: 'أحمد')],
  openQuestions: const [],
  languagesDetected: const ['العربية'],
  generatedAt: DateTime(2026),
  model: 'test',
);
