import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/minutes_artifacts.dart' show SpeakerNameResolver;
import 'package:insato/features/profiles/profile_aggregation.dart';
import 'package:insato/features/profiles/profile_guardrails.dart';
import 'package:insato/features/profiles/profile_model.dart';
import 'package:insato/features/profiles/profile_service.dart';
import 'package:insato/features/profiles/profile_stats.dart';
import 'package:insato/features/profiles/strings.dart';

Meeting meeting(String id, DateTime at, {String? title, Minutes? minutes}) =>
    Meeting(
      id: id,
      title: title ?? 'اجتماع $id',
      createdAt: at,
      status: MeetingStatus.ready,
      minutes: minutes,
    );

TranscriptSegment seg(
  int index,
  int start,
  int end,
  String? speaker,
  String text, {
  String? lang,
  SegmentKind kind = SegmentKind.speech,
  String meetingId = 'm1',
}) => TranscriptSegment(
  id: '$meetingId-$index',
  meetingId: meetingId,
  index: index,
  startMs: start,
  endMs: end,
  text: text,
  speakerId: speaker,
  language: lang,
  kind: kind,
);

SpeakerMeetingNotesRecord notes(
  String meetingId,
  MinutesSpeakerNote n, {
  String speakerId = 'a',
}) => SpeakerMeetingNotesRecord(
  speakerId: speakerId,
  meetingId: meetingId,
  notes: n,
);

void main() {
  group('countQuestions / normalizeLanguageCode', () {
    test('counts runs of Arabic and Latin question marks', () {
      expect(countQuestions('لماذا تأخر التسليم؟ ومتى ننتهي؟؟'), 2);
      expect(countQuestions('Why? Really?!'), 2);
      expect(countQuestions('لا أسئلة هنا.'), 0);
      expect(countQuestions('؟?'), 1);
    });

    test('normalises language codes', () {
      expect(normalizeLanguageCode('en-US'), 'en');
      expect(normalizeLanguageCode(' AR '), 'ar');
      expect(normalizeLanguageCode(''), isNull);
      expect(normalizeLanguageCode(null), isNull);
    });
  });

  group('computeMeetingSpeakerStats', () {
    final m = meeting('m1', DateTime(2026, 11, 1));

    test('null when the speaker did not speak', () {
      expect(
        computeMeetingSpeakerStats(
          meeting: m,
          segments: [seg(0, 0, 1000, 'b', 'hi')],
          speakerId: 'a',
        ),
        isNull,
      );
    });

    test('talk time, turns, questions, languages, switches, overlaps', () {
      final segments = [
        // Turn 1 of a: Arabic then English (mixed turn, one switch).
        seg(0, 0, 4000, 'a', 'لنبدأ بالميزانية؟', lang: 'ar'),
        seg(1, 4000, 6000, 'a', 'the marketing budget', lang: 'en-US'),
        // b starts 1 s before a's segment ends → a received an interruption.
        seg(2, 5000, 9000, 'b', 'موافق', lang: 'ar'),
        // a starts 600 ms before b ends → a gave one.
        seg(3, 8400, 10400, 'a', 'Why not now? ولماذا ننتظر؟', lang: 'en'),
        // Unintelligible segment of a: counted in time, not in languages.
        seg(
          4,
          11000,
          12000,
          'a',
          '',
          kind: SegmentKind.unintelligible,
        ),
        seg(5, 12000, 14000, null, 'unassigned', lang: 'en'),
        // Empty speech segment: no content, ignored.
        seg(6, 14000, 15000, 'a', '   ', lang: 'ar'),
      ];
      final s = computeMeetingSpeakerStats(
        meeting: m,
        segments: segments.reversed.toList(),
        speakerId: 'a',
        decisions: const [ProfileDecision(text: 'اعتماد', evidence: [3])],
      )!;
      expect(s.meetingId, 'm1');
      expect(s.speakingMs, 4000 + 2000 + 2000 + 1000);
      expect(s.meetingSpeechMs, 4000 + 2000 + 4000 + 2000 + 1000 + 2000);
      expect(s.segments, 4);
      expect(s.speechSegments, 3);
      // Turns: [0,1], [3,4] (null-speaker segment 5 ends the second turn).
      expect(s.turns, 2);
      expect(s.questions, 3);
      expect(s.questionSegments, 2);
      expect(s.languageMs, {'ar': 4000, 'en': 4000});
      // ar→en (switch), en→en.
      expect(s.languageTransitions, 2);
      expect(s.languageSwitches, 1);
      expect(s.mixedTurns, 1);
      expect(s.interruptionsGiven, 1);
      expect(s.interruptionsReceived, 1);
      expect(s.decisions.single.text, 'اعتماد');
      expect(s.talkShare, closeTo(9000 / 15000, 1e-9));
    });

    test('small overlaps are not interruptions', () {
      final s = computeMeetingSpeakerStats(
        meeting: m,
        segments: [
          seg(0, 0, 3000, 'b', 'x'),
          seg(1, 2700, 5000, 'a', 'y'),
        ],
        speakerId: 'a',
      )!;
      expect(s.interruptionsGiven, 0);
    });
  });

  group('ProfileTotals', () {
    test('sums meetings and derives rates', () {
      final t = ProfileTotals.of([
        MeetingSpeakerStats(
          meetingId: 'm1',
          meetingTitle: '',
          meetingAt: DateTime(2026),
          speakingMs: 30000,
          meetingSpeechMs: 100000,
          segments: 5,
          speechSegments: 5,
          turns: 3,
          questions: 2,
          questionSegments: 2,
          languageMs: const {'ar': 20000, 'en': 10000},
          languageTransitions: 4,
          languageSwitches: 1,
        ),
        MeetingSpeakerStats(
          meetingId: 'm2',
          meetingTitle: '',
          meetingAt: DateTime(2026, 2),
          speakingMs: 50000,
          meetingSpeechMs: 100000,
          segments: 4,
          speechSegments: 4,
          turns: 5,
          languageMs: const {'ar': 50000},
          languageTransitions: 4,
          languageSwitches: 1,
        ),
      ]);
      expect(t.meetings, 2);
      expect(t.talkShare, closeTo(0.4, 1e-9));
      expect(t.meanTurnMs, 10000);
      expect(t.languages.map((l) => l.code), ['ar', 'en']);
      expect(t.languages.first.share, closeTo(70000 / 80000, 1e-9));
      expect(t.codeSwitchRate, closeTo(0.25, 1e-9));
      expect(t.statementSegments, 7);
      expect(t.lowEvidence, isFalse);
      expect(ProfileTotals.of(const []).lowEvidence, isTrue);
    });
  });

  group('guardrails', () {
    test('drops emotional, psychological and sensitive inferences', () {
      for (final bad in [
        'بدا غاضباً أثناء النقاش',
        'يتحدث بتوتر واضح',
        'شخصيته انطوائية',
        'حالته الصحية لا تسمح',
        'يبدو متديناً',
        'توجهه السياسي محافظ',
        'كبير السن نسبياً',
        'لا يصلح للقيادة',
        'يستحق الترقية: ترقيته مستحقة',
        'Seems anxious and nervous',
        'تقييم الأداء: 7/10',
      ]) {
        expect(violatesProfileGuardrails(bad), isTrue, reason: bad);
      }
    });

    test('keeps descriptive, observable wording', () {
      for (final ok in [
        'يطرح أسئلة توضيحية قبل اتخاذ القرار',
        'يستشهد بالأرقام عند عرض الميزانية',
        'شرح بنية الشبكات العصبية في النظام',
        'لخّص النقاط المتفق عليها في نهاية الاجتماع',
        'Explained the deployment pipeline step by step',
        'تحسين الأداء التقني للتطبيق',
      ]) {
        expect(violatesProfileGuardrails(ok), isFalse, reason: ok);
      }
    });

    test('knowledge is checked for scores only', () {
      expect(violatesKnowledgeGuardrails('شرح أعراض المرض وعلاجه'), isFalse);
      expect(violatesKnowledgeGuardrails('مستواه 8/10 في المالية'), isTrue);
    });

    test('normalizeProfileText unifies Arabic forms', () {
      expect(normalizeProfileText('  إدارةُ   المشاريع '), 'اداره المشاريع');
    });
  });

  group('domains', () {
    test('domainKey merges article and spelling variants', () {
      expect(domainKey('المالية'), domainKey('مالية'));
      expect(domainKey('هندسة البرمجيات'), domainKey('الهندسة برمجيات'));
      expect(domainKey('قانون'), isNot(domainKey('مالية')));
    });

    ProfileKnowledgeItem item(String m, int month, DemonstrationLevel l) =>
        ProfileKnowledgeItem(
          meetingId: m,
          meetingAt: DateTime(2026, month),
          demonstrated: 'x',
          level: l,
          evidence: const [1],
        );

    test('trend', () {
      expect(
        computeDomainTrend([item('m1', 1, DemonstrationLevel.led)]),
        DomainTrend.single,
      );
      expect(
        computeDomainTrend([
          item('m2', 2, DemonstrationLevel.led),
          item('m1', 1, DemonstrationLevel.mentioned),
        ]),
        DomainTrend.deepening,
      );
      expect(
        computeDomainTrend([
          item('m1', 1, DemonstrationLevel.explained),
          item('m2', 2, DemonstrationLevel.mentioned),
          item('m3', 3, DemonstrationLevel.mentioned),
        ]),
        DomainTrend.lighter,
      );
      expect(
        computeDomainTrend([
          item('m1', 1, DemonstrationLevel.explained),
          item('m1', 1, DemonstrationLevel.mentioned),
          item('m2', 2, DemonstrationLevel.explained),
        ]),
        DomainTrend.steady,
      );
    });
  });

  group('aggregateSpeakerProfile', () {
    final m1 = meeting('m1', DateTime(2026, 10, 1), title: 'الميزانية');
    final m2 = meeting('m2', DateTime(2026, 11, 1), title: 'الإطلاق');
    final meetings = {'m1': m1, 'm2': m2};

    SpeakerProfile build({
      List<SpeakerMeetingNotesRecord>? notesList,
      List<MeetingSpeakerStats>? stats,
      List<TrackedTask> tasks = const [],
    }) => aggregateSpeakerProfile(
      speakerName: 'سارة',
      perMeeting:
          stats ??
          [
            MeetingSpeakerStats(
              meetingId: 'm2',
              meetingTitle: 'old title',
              meetingAt: DateTime(2000),
              speakingMs: 120000,
              meetingSpeechMs: 300000,
              segments: 12,
              speechSegments: 12,
              turns: 6,
              languageMs: const {'ar': 120000},
            ),
            MeetingSpeakerStats(
              meetingId: 'm1',
              meetingTitle: 'الميزانية',
              meetingAt: DateTime(2026, 10, 1),
              speakingMs: 60000,
              meetingSpeechMs: 300000,
              segments: 8,
              speechSegments: 8,
              turns: 4,
              languageMs: const {'ar': 30000, 'en': 30000},
              decisions: const [
                ProfileDecision(text: 'اعتماد الميزانية', evidence: [4]),
              ],
            ),
            MeetingSpeakerStats(
              meetingId: 'gone',
              meetingTitle: 'deleted',
              meetingAt: DateTime(2026),
              speakingMs: 999999,
              segments: 1,
            ),
          ],
      notes:
          notesList ??
          [
            notes(
              'm2',
              const MinutesSpeakerNote(
                speaker: 'سارة',
                knowledge: [
                  SpeakerKnowledgeNote(
                    domain: 'المالية',
                    demonstrated: 'قادت نقاش توزيع الميزانية',
                    level: DemonstrationLevel.led,
                    evidence: [3, 5],
                  ),
                ],
                contributions: [
                  SpeakerContributionNote(
                    kind: ContributionKind.proposed,
                    text: 'اقترحت تأجيل الإطلاق أسبوعاً',
                    evidence: [7],
                  ),
                  SpeakerContributionNote(
                    kind: ContributionKind.tookTask,
                    text: 'تولّت إعداد التقرير',
                    evidence: [9],
                  ),
                ],
                style: [
                  SpeakerStyleNote(
                    observation: 'تستشهد بالأرقام عند العرض',
                    evidence: [3],
                  ),
                  SpeakerStyleNote(
                    observation: 'بدت متوترة في النهاية',
                    evidence: [11],
                  ),
                ],
                summary: 'قادت نقاش الميزانية واقترحت موعداً جديداً للإطلاق.',
              ),
            ),
            notes(
              'm1',
              const MinutesSpeakerNote(
                speaker: 'سارة',
                knowledge: [
                  SpeakerKnowledgeNote(
                    domain: 'مالية',
                    demonstrated: 'ذكرت بنود الميزانية',
                    level: DemonstrationLevel.mentioned,
                    evidence: [1],
                  ),
                  SpeakerKnowledgeNote(
                    domain: 'قانون',
                    demonstrated: 'أشارت إلى بند في العقد',
                    level: DemonstrationLevel.mentioned,
                    evidence: [2],
                  ),
                ],
                contributions: [
                  SpeakerContributionNote(
                    kind: ContributionKind.proposed,
                    text: 'اقترحت مراجعة العقد',
                    evidence: [],
                  ),
                ],
                summary: 'شاركت باقتراح واحد.',
              ),
            ),
            notes(
              'deleted-meeting',
              const MinutesSpeakerNote(speaker: 'سارة', summary: 'x'),
            ),
          ],
      tasks: tasks,
      meetingsById: meetings,
      builtAt: DateTime(2026, 11, 19, 12),
    );

    test('merges notes by domain with evidence, trend and low evidence', () {
      final p = build();
      expect(p.speakerName, 'سارة');
      // Deleted meeting dropped; others sorted by date with fresh titles.
      expect(p.perMeeting.map((m) => m.meetingId), ['m1', 'm2']);
      expect(p.perMeeting.last.meetingTitle, 'الإطلاق');
      expect(p.totals.speakingMs, 180000);
      expect(p.totals.decisionsProposed, 1);
      expect(p.notesMeetings, 2);

      expect(p.knowledge.map((d) => d.domain), ['المالية', 'قانون']);
      final finance = p.knowledge.first;
      expect(finance.meetings, 2);
      expect(finance.highestLevel, DemonstrationLevel.led);
      expect(finance.trend, DomainTrend.deepening);
      expect(finance.lowEvidence, isFalse);
      expect(finance.items.first.meetingId, 'm1');
      final law = p.knowledge.last;
      expect(law.lowEvidence, isTrue, reason: 'one meeting, one segment');

      // Newest first; the item without evidence is flagged.
      expect(p.contributions.first.meetingId, 'm2');
      expect(p.contributions.last.text, 'اقترحت مراجعة العقد');
      expect(p.contributions.last.lowEvidence, isTrue);
      expect(p.contributionCounts[ContributionKind.proposed], 2);

      // The emotional observation is dropped by the guardrails.
      expect(p.style.map((s) => s.observation), ['تستشهد بالأرقام عند العرض']);
      expect(p.omittedByGuardrails, 1);
      expect(p.summaries.first.meetingId, 'm2');

      expect(
        p.evidence,
        containsAll(const [
          EvidenceRef(meetingId: 'm2', segmentIndex: 3),
          EvidenceRef(meetingId: 'm2', segmentIndex: 7),
          EvidenceRef(meetingId: 'm1', segmentIndex: 4),
        ]),
      );
    });

    test('narrative is descriptive and built from the summaries', () {
      final p = build(
        tasks: [
          TrackedTask(
            id: 1,
            task: 'إعداد التقرير',
            status: TaskStatus.done,
            createdAt: DateTime(2026, 11),
            updatedAt: DateTime(2026, 11),
            ownerSpeakerId: 'a',
            sourceMeetingId: 'm2',
            evidenceSegmentIds: const [9],
          ),
          TrackedTask(
            id: 2,
            task: 'مراجعة العقد',
            status: TaskStatus.open,
            createdAt: DateTime(2026, 10),
            updatedAt: DateTime(2026, 10),
            ownerSpeakerId: 'a',
            sourceMeetingId: 'gone',
            evidenceSegmentIds: const [1],
          ),
        ],
      );
      expect(p.tasks.owned, 2);
      expect(p.tasks.completed, 1);
      expect(p.tasks.items.first.meetingId, isNull);
      expect(p.tasks.items.first.evidence, isEmpty);
      final text = p.narrative.join('\n');
      expect(text, contains('اجتماعان'));
      expect(text, contains('30٪'));
      expect(text, contains(PS.contributionRole(ContributionKind.proposed)));
      expect(text, contains('المالية'));
      expect(text, contains('قيادة النقاش في'));
      expect(text, contains('إنجاز 1 من 2'));
      expect(text, contains('قادت نقاش الميزانية'));
      expect(text, isNot(contains('متوترة')));
      for (final line in p.narrative) {
        expect(violatesProfileGuardrails(line), isFalse, reason: line);
      }
    });

    test('no notes: statistics only, with a hint', () {
      final p = build(notesList: const []);
      expect(p.knowledge, isEmpty);
      expect(p.narrative.last, PS.narrativeNoNotes);
      expect(p.isEmpty, isFalse);
    });

    test('JSON round trip', () {
      final p = build();
      final back = SpeakerProfile.tryParse(p.toJson())!;
      expect(back.toJson(), p.toJson());
      expect(p.toJson()['totals']['talk_share'], 0.3);
      expect(SpeakerProfile.tryParse({'version': 99}), isNull);
      expect(SpeakerProfile.tryParse(null), isNull);
    });
  });

  test('decisionsProposedBy resolves names', () {
    final speakers = {
      'a': Speaker(
        id: 'a',
        name: 'سارة',
        colorValue: 0,
        isNamedByUser: true,
        createdAt: DateTime(2026),
      ),
    };
    final minutes = Minutes(
      title: 't',
      summary: 's',
      attendees: const [],
      topics: const [],
      decisions: const [
        MinutesDecision(text: 'قرار 1', proposedBy: ' سارة ', evidence: [2]),
        MinutesDecision(text: 'قرار 2', proposedBy: 'أحمد'),
      ],
      actionItems: const [],
      openQuestions: const [],
      languagesDetected: const [],
      generatedAt: DateTime(2026),
      model: 'm',
    );
    final d = decisionsProposedBy(minutes, 'a', SpeakerNameResolver(speakers));
    expect(d.single.text, 'قرار 1');
    expect(d.single.evidence, [2]);
    expect(decisionsProposedBy(null, 'a', SpeakerNameResolver(speakers)), isEmpty);
  });
}
