// Widget tests of the «الرموز والشيفرات» tab (F17): the five detectors with
// speaker and evidence, hypothesis wording, promoting jargon to the
// glossary, copying code blocks and exporting the section.

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';
import 'package:insato/features/codes/codes.dart';
import 'package:insato/ui/format.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';

class Seeded {
  Seeded(this.meetingId, this.saraId);

  final String meetingId;
  final String saraId;
}

/// A meeting with two speakers, five segments (two unintelligible) and
/// [findings] built from the seeded ids.
Future<Seeded> seed(
  UiTestEnv env,
  List<CodeFinding> Function(String meetingId, String saraId) findings, {
  bool unintelligible = true,
}) async {
  final speakers = SpeakerRepository(env.db);
  final sara = await speakers.create(name: 'سارة');
  final omar = await speakers.create(name: 'عمر');
  final m = await MeetingRepository(env.db)
      .create(title: 'اجتماع المشتريات', status: MeetingStatus.ready);
  await SegmentRepository(env.db).insertAll([
    TranscriptSegment(
      id: '',
      meetingId: m.id,
      index: 0,
      startMs: 0,
      endMs: 4000,
      text: 'نراجع الفاتورة 2024-0042 ضمن مشروع فينيق',
      speakerId: sara.id,
    ),
    TranscriptSegment(
      id: '',
      meetingId: m.id,
      index: 1,
      startMs: 5000,
      endMs: 7500,
      text: unintelligible ? 'ابرم' : 'كلام عادي',
      speakerId: omar.id,
      kind: unintelligible ? SegmentKind.unintelligible : SegmentKind.speech,
    ),
    TranscriptSegment(
      id: '',
      meetingId: m.id,
      index: 2,
      startMs: 8000,
      endMs: 12000,
      text: 'اكتب print hello بايثون، وفينيق متأخر',
      speakerId: omar.id,
    ),
    TranscriptSegment(
      id: '',
      meetingId: m.id,
      index: 3,
      startMs: 61000,
      endMs: 63000,
      text: '',
      speakerId: omar.id,
      kind: unintelligible ? SegmentKind.unintelligible : SegmentKind.speech,
    ),
    TranscriptSegment(
      id: '',
      meetingId: m.id,
      index: 4,
      startMs: 70000,
      endMs: 74000,
      text: 'ربما نؤجل الموضوع إلى الربع القادم',
      speakerId: sara.id,
    ),
  ]);
  final list = findings(m.id, sara.id);
  if (list.isNotEmpty) {
    await CodeFindingRepository(env.db).replaceForMeeting(m.id, list);
  }
  return Seeded(m.id, sara.id);
}

CodeFinding f(
  String meetingId,
  CodeFindingKind kind,
  Map<String, dynamic> payload, {
  String? speakerId,
}) => CodeFinding(
  id: 0,
  meetingId: meetingId,
  kind: kind,
  payload: payload,
  createdAt: DateTime(2026),
  speakerId: speakerId,
);

List<CodeFinding> allFive(String m, String saraId) => [
  f(
    m,
    CodeFindingKind.speechCoded,
    enrichPayload(
      const CodedSpeechItem(
        speaker: 'عمر',
        character: CodedSpeechCharacter.reversedSpeech,
        description: 'مقطع قصير غير مفهوم',
        hypotheses: [
          CodeHypothesis(
            meaning: 'قد يكون اسم المورّد',
            confidence: HypothesisConfidence.low,
            basis: 'ورد بعد ذكر الفاتورة',
          ),
        ],
        evidence: [1],
      ).toJson(),
      checked: {1},
      results: [const ReversedSpeechResult(segment: 1, text: 'مرحبا')],
    ),
  ),
  f(
    m,
    CodeFindingKind.jargon,
    const JargonItem(
      term: 'فينيق',
      inferredMeaning: 'اسم رمزي لمشروع النظام الجديد',
      confidence: HypothesisConfidence.medium,
      evidence: [2, 0],
    ).toJson(),
  ),
  f(
    m,
    CodeFindingKind.spokenCode,
    const SpokenCodeItem(
      language: 'python',
      code: 'print("hello")',
      explanation: 'يطبع تحية',
      speaker: 'عمر',
      issues: ['لا توجد معالجة للأخطاء'],
      evidence: [2],
    ).toJson(),
  ),
  f(
    m,
    CodeFindingKind.implied,
    const ImpliedItem(
      literal: 'ربما نؤجل الموضوع',
      basis: 'تكرار التأجيل',
      confidence: HypothesisConfidence.low,
      speaker: 'متحدث 1',
      possibleMeanings: ['اعتراض غير مباشر على الجدول'],
      evidence: [4],
    ).toJson(),
    speakerId: saraId,
  ),
  f(
    m,
    CodeFindingKind.reference,
    const ReferenceItem(
      kind: ReferenceKind.invoice,
      verbatim: '2024-0042',
      normalized: 'INV-2024-0042',
      context: 'فاتورة المورّد',
      speaker: 'سارة',
      evidence: [0],
    ).toJson(),
  ),
  f(
    m,
    CodeFindingKind.reference,
    const ReferenceItem(
      kind: ReferenceKind.ticket,
      verbatim: '777',
      normalized: '777',
      context: 'تذكرة الدعم',
      speaker: 'عمر',
      evidence: [2],
    ).toJson(),
  ),
];

Future<void> pumpTab(WidgetTester t, UiTestEnv env, String meetingId) =>
    pumpScreen(t, env, Scaffold(body: CodesTab(meetingId: meetingId)));

Future<void> scrollTo(WidgetTester t, Finder finder) async {
  await t.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pump();
}

void main() {
  testWidgets('empty state without findings or unintelligible speech', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(
      t,
      () => seed(env, (_, _) => const [], unintelligible: false),
    );
    await pumpTab(t, env, s.meetingId);
    expect(find.text(KS.emptyTitle), findsOneWidget);
    expect(find.text(KS.codedSpeechTitle), findsNothing);
    await env.dispose(t);
  });

  testWidgets('unintelligible segments alone still show the tab', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(t, () => seed(env, (_, _) => const []));
    await pumpTab(t, env, s.meetingId);
    expect(find.text(KS.emptyTitle), findsNothing);
    expect(find.text(KS.otherUnintelligibleTitle), findsOneWidget);
    // Both segments, never dropped, with their speaker and duration.
    expect(find.text(KS.speakerLine('عمر')), findsNWidgets(2));
    expect(find.text(KS.duration(2500)), findsOneWidget);
    expect(find.text(KS.asrGuess('ابرم')), findsOneWidget);
    expect(find.byType(ReversedSpeechButton), findsOneWidget);
    // The four other sections say they are empty.
    expect(find.text(KS.noneInSection), findsNWidgets(4));
    await env.dispose(t);
  });

  testWidgets('five sections with speaker, evidence and hypotheses', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(t, () => seed(env, allFive));
    await pumpTab(t, env, s.meetingId);

    expect(find.text(KS.intro), findsOneWidget);
    // 1. Coded speech: characterisation and hypothesis with confidence.
    expect(find.text(KS.codedSpeechTitle), findsOneWidget);
    expect(
      find.text(KS.character(CodedSpeechCharacter.reversedSpeech)),
      findsOneWidget,
    );
    expect(find.text(KS.possibleMeanings), findsOneWidget);
    expect(
      find.text(
        '${KS.hypothesis} · ${KS.confidence(HypothesisConfidence.low)}',
      ),
      findsWidgets,
    );
    expect(find.text('قد يكون اسم المورّد'), findsOneWidget);
    expect(find.text(KS.basis('ورد بعد ذكر الفاتورة')), findsOneWidget);
    expect(find.text(KS.reversedResultTitle), findsOneWidget);
    expect(find.text('«مرحبا»'), findsOneWidget);
    expect(find.text(KS.totalDuration(2500)), findsOneWidget);
    // Segment 3 is unintelligible and not covered by the finding.
    expect(find.text(KS.otherUnintelligibleTitle), findsOneWidget);
    // Evidence chips: timestamps of the cited segments.
    expect(find.text('00:00:05'), findsWidgets);

    // 2. Jargon: inferred badge, first use, speakers from the transcript.
    await scrollTo(t, find.text('فينيق'));
    expect(
      find.text(
        '${KS.inferred} · ${KS.confidence(HypothesisConfidence.medium)}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(KS.inferredMeaning('اسم رمزي لمشروع النظام الجديد')),
      findsOneWidget,
    );
    expect(find.text(KS.firstUse('00:00:00')), findsOneWidget);
    expect(find.text(KS.speakersLine(['سارة', 'عمر'])), findsOneWidget);
    expect(find.text(KS.mostUsedBy('سارة')), findsOneWidget);
    expect(find.text(KS.addToGlossary), findsOneWidget);

    // 3. Spoken code.
    await scrollTo(t, find.byType(CodeBlock));
    expect(find.text('Python'), findsOneWidget);
    expect(find.text('يطبع تحية'), findsOneWidget);
    expect(find.text('• لا توجد معالجة للأخطاء'), findsOneWidget);
    expect(find.text(KS.reconstructedNote), findsOneWidget);

    // 4. Implied speech: speaker resolved through the voice library.
    await scrollTo(t, find.text(KS.literal('ربما نؤجل الموضوع')));
    expect(find.text(KS.impliedMeanings), findsOneWidget);
    expect(find.text('• اعتراض غير مباشر على الجدول'), findsOneWidget);
    expect(find.text('متحدث 1', findRichText: true), findsNothing);
    expect(find.text(KS.speakerLine('سارة')), findsWidgets);

    // 5. References: digits checked against the transcript.
    await scrollTo(t, find.text('INV-2024-0042'));
    expect(find.text(KS.referenceKind(ReferenceKind.invoice)), findsOneWidget);
    expect(find.text(KS.asSaid(autoIsolate('2024-0042'))), findsOneWidget);
    expect(find.text(KS.verified), findsOneWidget);
    await scrollTo(t, find.text('777'));
    expect(find.text(KS.unverified), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('references are a data table on wide screens', (t) async {
    setScreenSize(t, kDesktop);
    final env = UiTestEnv();
    final s = await env.run(t, () => seed(env, allFive));
    await pumpTab(t, env, s.meetingId);
    await scrollTo(t, find.byType(DataTable));
    expect(find.text(KS.colKind), findsOneWidget);
    expect(find.text(KS.colCheck), findsOneWidget);
    expect(find.text('INV-2024-0042'), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('copy code block and export the section', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(t, () => seed(env, allFive));
    await pumpTab(t, env, s.meetingId);

    await t.tap(find.text(KS.exportCopy));
    await settle(t);
    final md = env.share.copied.single;
    expect(md, contains('## ${KS.exportTitle}'));
    expect(md, contains('```python\nprint("hello")\n```'));
    expect(md, contains('**سارة**: ${KS.literal('ربما نؤجل الموضوع')}'));
    expect(find.text(S.copied), findsOneWidget);

    await t.tap(find.text(KS.exportShare));
    await settle(t);
    expect(env.share.sharedTexts.single, md);

    await scrollTo(t, find.byTooltip(KS.copyCode));
    await t.tap(find.byTooltip(KS.copyCode));
    await settle(t);
    expect(env.share.copied.last, 'print("hello")');
    await env.dispose(t);
  });

  testWidgets('promote jargon to the glossary with a confirmed meaning', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(t, () => seed(env, allFive));
    await pumpTab(t, env, s.meetingId);

    await scrollTo(t, find.text(KS.addToGlossary));
    await t.tap(find.text(KS.addToGlossary));
    await settle(t);
    expect(find.text(KS.addToGlossaryTitle), findsOneWidget);
    expect(find.text(KS.addToGlossaryNote), findsOneWidget);

    // A blank meaning is refused.
    final meaning = find.widgetWithText(TextFormField, KS.meaningLabel);
    await t.enterText(meaning, '  ');
    await t.tap(find.text(S.save));
    await t.pump();
    expect(find.text(KS.meaningEmpty), findsOneWidget);

    await t.enterText(meaning, 'منصة المشتريات الجديدة');
    await t.tap(find.text(KS.scopeMeeting));
    await t.pump();
    await t.tap(find.text(S.save));
    await settle(t);

    expect(find.text(KS.addToGlossaryTitle), findsNothing);
    final terms = await env.run(
      t,
      () => GlossaryRepository(env.db).getForMeeting(s.meetingId),
    );
    expect(terms.single.term, 'فينيق');
    expect(terms.single.arSpelling, 'منصة المشتريات الجديدة');
    expect(terms.single.meetingId, s.meetingId);
    await settle(t);
    expect(find.text(KS.inGlossary), findsOneWidget);
    expect(find.text(KS.addToGlossary), findsNothing);
    await env.dispose(t);
  });

  testWidgets('jargon already in the global glossary is marked', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(t, () async {
      final s = await seed(env, allFive);
      await GlossaryRepository(env.db).add(term: 'فينيق', arSpelling: 'x');
      return s;
    });
    await pumpTab(t, env, s.meetingId);
    await scrollTo(t, find.text(KS.inGlossary));
    expect(find.text(KS.inGlossary), findsOneWidget);
    expect(find.text(KS.addToGlossary), findsNothing);
    await env.dispose(t);
  });

  testWidgets('no hypotheses: says nothing was decoded', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(
      t,
      () => seed(
        env,
        (m, _) => [
          f(
            m,
            CodeFindingKind.speechCoded,
            const CodedSpeechItem(
              speaker: '',
              character: CodedSpeechCharacter.unknown,
              description: '',
              evidence: [1, 3],
            ).toJson(),
          ),
        ],
      ),
    );
    await pumpTab(t, env, s.meetingId);
    expect(find.text(KS.noHypotheses), findsOneWidget);
    expect(find.text(KS.possibleMeanings), findsNothing);
    expect(find.text(KS.speakerLine(KS.unknownSpeaker)), findsOneWidget);
    // Both unintelligible segments are covered by the finding.
    expect(find.text(KS.otherUnintelligibleTitle), findsNothing);
    await env.dispose(t);
  });

  testWidgets('reversed-speech button explains why it is disabled', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final s = await env.run(t, () => seed(env, (_, _) => const []));
    await pumpTab(t, env, s.meetingId);
    // No recording was kept for this meeting.
    expect(find.text(KS.reverseNoAudio), findsOneWidget);
    final button = t.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(KS.reverseButton),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
    await env.dispose(t);
  });
}
