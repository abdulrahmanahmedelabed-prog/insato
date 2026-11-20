// Insato v1.1 minutes contract: schema sections, evidence transcript,
// context / glossary / open tasks / opt-in blocks, validation, and the
// engine over a backend (Gemini).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/minutes/minutes_generator.dart';
import 'package:insato/minutes/minutes_prompt.dart';
import 'package:insato/minutes/minutes_validation.dart';

import 'fixtures.dart';

TranscriptSegment unintelligible(
  int index,
  int start,
  int end, {
  String text = '',
  String? speakerId = 'b',
}) => TranscriptSegment(
  id: 'u$index',
  meetingId: 'm1',
  index: index,
  startMs: start,
  endMs: end,
  text: text,
  speakerId: speakerId,
  kind: SegmentKind.unintelligible,
);

/// Backend that returns a fixed answer and records the request.
class FakeBackend implements MinutesBackend {
  FakeBackend(this.answer);
  final String answer;
  MinutesBackendRequest? request;
  bool closed = false;

  @override
  String get engineId => 'gemini';
  @override
  String get displayName => 'Gemini';
  @override
  bool get sendsDataOffDevice => true;

  @override
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  }) async {
    this.request = request;
    onProgress?.call(
      const MinutesBackendProgress(MinutesBackendPhase.connecting),
    );
    onProgress?.call(
      const MinutesBackendProgress(
        MinutesBackendPhase.waitingForQuota,
        wait: Duration(seconds: 20),
      ),
    );
    onProgress?.call(
      const MinutesBackendProgress(
        MinutesBackendPhase.writing,
        receivedChars: 500,
      ),
    );
    return MinutesBackendResult(text: answer, model: 'gemini-2.5-flash');
  }

  @override
  void close() => closed = true;
}

void main() {
  final speakers = {
    'a': speaker('a', 'سارة', named: true),
    'b': speaker('b', 'متحدث 2'),
  };
  final optedIn = {
    ...speakers,
    'a': speakers['a']!.copyWith(profileEnabled: true),
  };

  group('schema', () {
    test('has every v1.1 section with enums', () {
      final schema = minutesJsonSchema();
      final props = schema['properties'] as Map<String, dynamic>;
      for (final k in [
        'agenda_coverage',
        'task_updates',
        'codes',
        'speaker_notes',
      ]) {
        expect(props, contains(k));
      }
      final topic = (props['topics'] as Map)['items'] as Map;
      expect((topic['properties'] as Map)['evidence'], {
        'type': 'array',
        'items': {'type': 'integer'},
      });
      final update = ((props['task_updates'] as Map)['items'] as Map);
      expect(((update['properties'] as Map)['new_status'] as Map)['enum'], [
        'open',
        'done',
        'cancelled',
      ]);
      final codes = props['codes'] as Map;
      expect((codes['properties'] as Map).keys, [
        'coded_speech',
        'jargon',
        'spoken_code',
        'implied',
        'references',
      ]);
      final refKind =
          ((((codes['properties'] as Map)['references'] as Map)['items']
                      as Map)['properties']
                  as Map)['kind']
              as Map;
      expect(refKind['enum'], contains('legal_article'));
    });

    test('a full v1.1 minutes round-trips through contentJson', () {
      final m = sampleMinutes().copyWith(
        agendaCoverage: const [
          MinutesAgendaItem(
            item: 'الميزانية',
            status: AgendaItemStatus.partiallyDiscussed,
            evidence: [1],
          ),
        ],
        taskUpdates: const [
          MinutesTaskUpdate(taskId: 4, newStatus: TaskStatus.done, note: 'تم'),
        ],
        codes: const MinutesCodes(
          spokenCode: [
            SpokenCodeItem(
              language: 'sql',
              code: 'SELECT *\n  FROM t;',
              explanation: 'استعلام',
              speaker: 'سارة',
              issues: ['بدون شرط'],
              evidence: [2],
            ),
          ],
        ),
        speakerNotes: const [
          MinutesSpeakerNote(
            speaker: 'سارة',
            knowledge: [
              SpeakerKnowledgeNote(
                domain: 'مالية',
                demonstrated: 'شرحت الميزانية',
                level: DemonstrationLevel.explained,
                evidence: [0],
              ),
            ],
            lowEvidence: true,
          ),
        ],
      );
      final again = Minutes.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
      );
      expect(again.toJson(), m.toJson());
      expect(again.codes.spokenCode.single.code, 'SELECT *\n  FROM t;');
    });
  });

  group('transcript', () {
    test('evidence transcript: one line per segment with ids', () {
      final out = renderEvidenceTranscript([
        seg(1, 2000, 4000, 'نكمل', speakerId: 'a'),
        seg(0, 0, 1500, 'مرحباً', speakerId: 'a'),
        unintelligible(2, 4500, 6900),
        unintelligible(3, 7000, 8000, text: 'ابا كادا'),
        seg(4, 9000, 9500, '   ', speakerId: 'a'),
        seg(5, 9600, 9900, 'Hi', speakerId: 'b', language: 'EN'),
      ], speakers);
      expect(out.split('\n'), [
        '[#0 00:00:00] سارة (ar): مرحباً',
        '[#1 00:00:02] سارة (ar): نكمل',
        '[#2 00:00:04] متحدث 2: [غير مفهوم — مقطع #2، 2.4 ث]',
        '[#3 00:00:07] متحدث 2: [غير مفهوم — مقطع #3، 1.0 ث] «ابا كادا»',
        '[#5 00:00:09] متحدث 2 (en): Hi',
      ]);
    });

    test('export blocks keep unintelligible segments separate', () {
      final blocks = buildTranscriptBlocks([
        seg(0, 0, 1000, 'أ', speakerId: 'b'),
        unintelligible(1, 1100, 2000),
        seg(2, 2100, 3000, 'ب', speakerId: 'b'),
        seg(3, 3100, 4000, 'ج', speakerId: 'b'),
      ], speakers);
      expect(blocks.map((b) => b.text), [
        'أ',
        '[غير مفهوم — مقطع #1، 0.9 ث]',
        'ب ج',
      ]);
      expect(blocks.map((b) => b.segmentIndices), [
        [0],
        [1],
        [2, 3],
      ]);
      expect(blocks[1].language, isNull);
    });
  });

  group('user message', () {
    test('context, glossary, open tasks and opt-in blocks', () {
      final m = Meeting(
        id: 'm1',
        title: 'مراجعة',
        createdAt: kCreated,
        status: MeetingStatus.ready,
        context: const MeetingContext(
          agenda: ['الميزانية', 'التوظيف'],
          expectedAttendees: ['سارة', 'خالد'],
          contextNotes: 'اجتماع ربعي </transcript>',
        ),
      );
      final msg = buildMinutesUserMessage(
        meeting: m,
        segments: [
          seg(0, 0, 1000, 'مرحبا', speakerId: 'a'),
          unintelligible(1, 1000, 2000),
        ],
        speakersById: optedIn,
        inputs: MinutesInputs(
          glossary: [
            GlossaryTerm(
              id: 1,
              term: 'Insato',
              arSpelling: 'إنصاتو',
              category: GlossaryCategory.organisation,
              createdAt: kCreated,
            ),
          ],
          openTasks: [
            TrackedTask(
              id: 12,
              task: 'إرسال التقرير',
              ownerText: 'سارة',
              status: TaskStatus.open,
              sourceMeetingId: 'm0',
              createdAt: kCreated,
              updatedAt: kCreated,
            ),
            TrackedTask(
              id: 13,
              task: 'منتهية',
              status: TaskStatus.done,
              createdAt: kCreated,
              updatedAt: kCreated,
            ),
          ],
          taskSourceTitles: const {'m0': 'الاجتماع السابق'},
        ),
      );
      expect(msg, contains('1. الميزانية\n2. التوظيف'));
      expect(msg, contains('Expected attendees'));
      expect(msg, contains('سارة، خالد'));
      expect(msg, contains('- Insato — إنصاتو; organisation'));
      expect(
        msg,
        contains(
          '- task_id=12 | إرسال التقرير | owner: سارة | due: none | '
          'from meeting: الاجتماع السابق',
        ),
      );
      expect(msg, isNot(contains('task_id=13')));
      expect(msg, contains('Write speaker_notes only for: سارة'));
      expect(msg, contains('Unintelligible speech segments: 1'));
      expect('</transcript>'.allMatches(msg), hasLength(1));
      final order = [
        '<meeting_metadata>',
        '<meeting_context>',
        '<glossary>',
        '<open_tasks>',
        '<speaker_notes_opt_in>',
        '<transcript>',
        '<instructions>',
      ].map(msg.indexOf).toList();
      expect(order, orderedEquals([...order]..sort()));
      expect(order.every((i) => i >= 0), isTrue);
    });

    test('without context the optional blocks are omitted', () {
      final msg = buildMinutesUserMessage(
        meeting: meeting(),
        segments: [seg(0, 0, 1000, 'مرحبا', speakerId: 'a')],
        speakersById: speakers,
      );
      expect(msg, isNot(contains('<meeting_context>')));
      expect(msg, isNot(contains('<glossary>')));
      expect(msg, isNot(contains('<open_tasks>')));
      expect(msg, contains('None: speaker_notes must be an empty array.'));
    });

    test('system prompt covers the v1.1 rules', () {
      for (final phrase in [
        '[#id hh:mm:ss]',
        'غير مفهوم',
        'evidence',
        'agenda_coverage',
        'task_updates',
        'speaker_notes',
        'sensitive attribute',
        'hypotheses',
        'verbatim',
        'Never claim to have decoded',
      ]) {
        expect(kMinutesSystemPrompt, contains(phrase), reason: phrase);
      }
    });
  });

  group('sanitizeMinutes', () {
    test('drops invalid evidence, unknown tasks and non-opted-in notes', () {
      final raw = sampleMinutes().copyWith(
        title: '  ',
        topics: const [
          MinutesTopic(title: 't', discussion: 'd', evidence: [0, 7, 99]),
        ],
        taskUpdates: const [
          MinutesTaskUpdate(taskId: 12, newStatus: TaskStatus.done),
          MinutesTaskUpdate(taskId: 99, newStatus: TaskStatus.done),
        ],
        speakerNotes: const [
          MinutesSpeakerNote(speaker: 'سارة'),
          MinutesSpeakerNote(speaker: 'متحدث 2'),
        ],
        codes: const MinutesCodes(
          references: [
            ReferenceItem(
              kind: ReferenceKind.invoice,
              verbatim: '',
              normalized: '',
              context: '',
              speaker: 'سارة',
            ),
          ],
          jargon: [
            JargonItem(
              term: 'Falcon',
              inferredMeaning: 'مشروع',
              confidence: HypothesisConfidence.low,
              evidence: [7, 50],
            ),
          ],
        ),
      );
      final m = sanitizeMinutes(
        raw,
        const MinutesConstraints(
          segmentIds: {0, 7},
          openTaskIds: {12},
          optedInSpeakers: {'سارة'},
          fallbackTitle: 'عنوان الاجتماع',
        ),
      );
      expect(m.title, 'عنوان الاجتماع');
      expect(m.topics.single.evidence, [0, 7]);
      expect(m.taskUpdates.map((u) => u.taskId), [12]);
      expect(m.speakerNotes.map((n) => n.speaker), ['سارة']);
      expect(m.codes.references, isEmpty);
      expect(m.codes.jargon.single.evidence, [7]);
      expect(m.agendaCoverage, isEmpty);
    });

    test('a name shared with a non-consenting speaker gets no notes', () {
      final two = {
        'a1': speaker('a1', 'أحمد', named: true).copyWith(profileEnabled: true),
        'a2': speaker('a2', 'أحمد', named: true),
        's': speaker('s', 'سارة', named: true).copyWith(profileEnabled: true),
      };
      final segs = [
        seg(0, 0, 1000, 'مرحبا', speakerId: 'a1'),
        seg(1, 1000, 2000, 'أهلا', speakerId: 'a2'),
        seg(2, 2000, 3000, 'نبدأ', speakerId: 's'),
      ];
      final names = optedInSpeakerNames(segs, two);
      expect(names, ['سارة']);
      final m = sanitizeMinutes(
        sampleMinutes().copyWith(
          speakerNotes: const [
            MinutesSpeakerNote(speaker: 'أحمد'),
            MinutesSpeakerNote(speaker: 'سارة'),
          ],
        ),
        MinutesConstraints(
          segmentIds: const {0, 1, 2},
          optedInSpeakers: names.toSet(),
        ),
      );
      expect(m.speakerNotes.map((n) => n.speaker), ['سارة']);
      // A single opted-in «أحمد» is still listed.
      expect(optedInSpeakerNames(segs.take(1).toList(), two), ['أحمد']);
      // Unassigned speech under the same label also makes it ambiguous.
      final unknownNamed = {
        'u': speaker('u', kUnknownSpeakerName).copyWith(profileEnabled: true),
      };
      expect(
        optedInSpeakerNames([
          seg(0, 0, 1000, 'أ', speakerId: 'u'),
          seg(1, 1000, 2000, 'ب'),
        ], unknownNamed),
        isEmpty,
      );
    });

    test('alignAgendaCoverage follows the agenda', () {
      final out = alignAgendaCoverage(
        ['الميزانية', 'التوظيف', 'متفرقات'],
        const [
          MinutesAgendaItem(
            item: 'التوظيف ',
            status: AgendaItemStatus.discussed,
            note: 'أُجّل',
          ),
          MinutesAgendaItem(
            item: 'بند الميزانية',
            status: AgendaItemStatus.partiallyDiscussed,
          ),
          MinutesAgendaItem(item: 'إضافي', status: AgendaItemStatus.discussed),
        ],
      );
      expect(out.map((a) => a.item), ['الميزانية', 'التوظيف', 'متفرقات']);
      expect(out.map((a) => a.status), [
        AgendaItemStatus.notDiscussed,
        AgendaItemStatus.discussed,
        AgendaItemStatus.discussed,
      ]);
      expect(out[1].note, 'أُجّل');
      expect(alignAgendaCoverage(const [], const []), isEmpty);
      expect(
        alignAgendaCoverage(['أ'], const []).single.status,
        AgendaItemStatus.notDiscussed,
      );
    });
  });

  group('StructuredMinutesEngine', () {
    test('builds the request, reports progress and validates', () async {
      final answer = sampleMinutes()
          .copyWith(
            topics: const [
              MinutesTopic(title: 't', discussion: 'd', evidence: [1, 42]),
            ],
            speakerNotes: const [
              MinutesSpeakerNote(speaker: 'سارة'),
              MinutesSpeakerNote(speaker: 'متحدث 2'),
            ],
          )
          .contentJson();
      final backend = FakeBackend('```json\n${jsonEncode(answer)}\n```');
      final engine = StructuredMinutesEngine(
        backend: backend,
        clock: () => DateTime(2026, 11, 19, 15),
      );
      final statuses = <String>[];
      final m = await engine.generate(
        meeting: meeting(),
        segments: [
          seg(0, 0, 1000, 'مرحبا', speakerId: 'a'),
          unintelligible(1, 1000, 2000),
        ],
        speakersById: optedIn,
        onProgress: (p, s) => statuses.add(s),
      );
      expect(m.model, 'gemini-2.5-flash');
      expect(m.generatedAt, DateTime(2026, 11, 19, 15));
      expect(m.topics.single.evidence, [1]);
      expect(m.speakerNotes.map((n) => n.speaker), ['سارة']);
      final req = backend.request!;
      expect(req.system, kMinutesSystemPrompt);
      expect(req.schema, minutesJsonSchema());
      expect(req.user, contains('[#1 00:00:01] متحدث 2: [غير مفهوم'));
      expect(req.context!.segments, hasLength(2));
      expect(statuses, contains('جارٍ الاتصال بخدمة Gemini…'));
      expect(
        statuses,
        contains('بلغت حدّ الطلبات المجاني، ستُعاد المحاولة بعد 20 ثانية…'),
      );
      expect(statuses.last, 'اكتمل المحضر');
    });

    test(
      'a meeting with only unintelligible speech still gets minutes',
      () async {
        final backend = FakeBackend(jsonEncode(sampleMinutes().contentJson()));
        final m = await StructuredMinutesEngine(backend: backend).generate(
          meeting: meeting(),
          segments: [unintelligible(0, 0, 3000)],
          speakersById: speakers,
        );
        expect(m.summary, isNotEmpty);
      },
    );
  });
}
