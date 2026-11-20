// v1.2 minutes contract: formal resolutions and vote detection in the
// schema, the prompt and the validation; v1 / v1.1 JSON stays readable.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/minutes/gemini_client.dart';
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/minutes/minutes_generator.dart';
import 'package:insato/minutes/minutes_prompt.dart';
import 'package:insato/minutes/minutes_validation.dart';

import 'fixtures.dart';

class _FakeBackend implements MinutesBackend {
  _FakeBackend(this.answer);
  final String answer;
  MinutesBackendRequest? request;

  @override
  String get engineId => 'fake';
  @override
  String get displayName => 'fake';
  @override
  bool get sendsDataOffDevice => false;
  @override
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  }) async {
    this.request = request;
    return MinutesBackendResult(text: answer, model: 'fake-model');
  }

  @override
  void close() {}
}

void _strict(Object? node, String path) {
  if (node is Map) {
    if (node['type'] == 'object') {
      expect(node['additionalProperties'], false, reason: path);
      final props = (node['properties'] as Map).keys.toSet();
      expect((node['required'] as List).toSet(), props, reason: path);
    }
    node.forEach((k, v) => _strict(v, '$path.$k'));
  } else if (node is List) {
    for (final e in node) {
      _strict(e, path);
    }
  }
}

void main() {
  group('schema', () {
    final schema = minutesJsonSchema();
    final decision = schema['properties']['decisions']['items'] as Map;

    test('decisions carry formal_text and a strict vote object', () {
      expect(decision['required'], containsAll(['formal_text', 'vote']));
      final vote = decision['properties']['vote'] as Map;
      expect(vote['required'], [
        'mode',
        'announced_result',
        'positions',
        'evidence',
      ]);
      expect(vote['properties']['mode']['enum'], [
        'formal_vote',
        'consensus',
        'none',
      ]);
      expect(
        vote['properties']['positions']['items']['properties']['position']['enum'],
        ['approve', 'object', 'abstain', 'not_voted', 'unclear'],
      );
      _strict(schema, r'$');
    });

    test('Gemini conversion keeps the vote enums', () {
      final g = toGeminiOpenApiSchema(schema);
      final v = g['properties']['decisions']['items']['properties']['vote'];
      expect(v['properties']['mode']['enum'], hasLength(3));
      expect(jsonEncode(g), isNot(contains('additionalProperties')));
    });
  });

  group('JSON compatibility', () {
    test('v1 / v1.1 decisions parse to no vote and round-trip', () {
      final d = MinutesDecision.fromJson({'text': 'قرار', 'proposed_by': null});
      expect(d.vote.isEmpty, isTrue);
      expect(d.formalText, isNull);
      final full = MinutesDecision.fromJson({
        'text': 'قرار',
        'formal_text': 'قرر المجلس',
        'vote': {
          'mode': 'formal_vote',
          'announced_result': 'أُقرّ بالإجماع',
          'positions': [
            {
              'speaker': 'سارة',
              'position': 'abstain',
              'evidence': [3],
            },
            {'speaker': '', 'position': 'approve'},
            'junk',
          ],
          'evidence': [3, '4'],
        },
      });
      expect(full.vote.mode, VoteMode.formalVote);
      expect(full.vote.positions.single.position, VotePosition.abstain);
      expect(full.vote.evidence, [3, 4]);
      expect(MinutesDecision.fromJson(full.toJson()).toJson(), full.toJson());
      expect(VotePosition.parse('maybe'), VotePosition.unclear);
      expect(VoteMode.parse(null), VoteMode.none);
    });
  });

  group('sanitizeVote', () {
    const c = MinutesConstraints(
      segmentIds: {1, 2, 3},
      speakerNames: {'سارة', 'متحدث 2'},
    );

    test('drops unknown speakers and segments, never invents', () {
      final v = sanitizeVote(
        const MinutesVote(
          mode: VoteMode.formalVote,
          positions: [
            MinutesVotePosition(
              speaker: 'سارة',
              position: VotePosition.approve,
              evidence: [1, 99],
            ),
            MinutesVotePosition(
              speaker: 'سارة',
              position: VotePosition.object,
              evidence: [2],
            ),
            MinutesVotePosition(
              speaker: 'أحمد المخترع',
              position: VotePosition.approve,
              evidence: [2],
            ),
            MinutesVotePosition(
              speaker: 'متحدث 2 (؟)',
              position: VotePosition.object,
              evidence: [77],
            ),
            MinutesVotePosition(
              speaker: 'متحدث غير محدد',
              position: VotePosition.approve,
              evidence: [3],
            ),
          ],
          evidence: [1],
        ),
        c,
      );
      expect(v.mode, VoteMode.formalVote);
      expect(v.positions.map((p) => p.speaker), ['سارة', 'متحدث 2']);
      expect(v.positions.first.evidence, [1]);
      // A position without valid evidence is only "unclear".
      expect(v.positions.last.position, VotePosition.unclear);
    });

    test('a voting moment without evidence becomes "none"', () {
      final v = sanitizeVote(
        const MinutesVote(
          mode: VoteMode.consensus,
          announcedResult: '  ',
          positions: [
            MinutesVotePosition(speaker: 'سارة', position: VotePosition.object),
          ],
          evidence: [42],
        ),
        c,
      );
      expect(v.mode, VoteMode.none);
      expect(v.positions, isEmpty);
      expect(v.evidence, isEmpty);
      expect(v.announcedResult, isNull);
    });
  });

  test('the engine passes the style hint and validates votes', () async {
    final answer = jsonEncode({
      'title': 'محضر',
      'summary': 'ملخص',
      'decisions': [
        {
          'text': 'اعتماد الخطة',
          'proposed_by': 'سارة',
          'evidence': [0],
          'formal_text': 'قرر المجلس اعتماد الخطة',
          'vote': {
            'mode': 'formal_vote',
            'announced_result': null,
            'positions': [
              {
                'speaker': 'سارة',
                'position': 'approve',
                'evidence': [0],
              },
              {
                'speaker': 'شخص مخترع',
                'position': 'object',
                'evidence': [1],
              },
            ],
            'evidence': [0, 1],
          },
        },
      ],
    });
    final backend = _FakeBackend(answer);
    final engine = StructuredMinutesEngine(backend: backend);
    final m = await engine.generate(
      meeting: meeting(),
      segments: [
        seg(0, 0, 2000, 'أوافق على الخطة', speakerId: 'a'),
        seg(1, 2000, 4000, 'وأنا أعترض', speakerId: 'b'),
      ],
      speakersById: {
        'a': speaker('a', 'سارة', named: true),
        'b': speaker('b', 'متحدث 2'),
      },
      inputs: const MinutesInputs(
        style: MinutesStyleHint(
          templateName: 'محضر مجلس إدارة',
          bodyName: 'مجلس الإدارة',
          resolutionLead: 'قرر المجلس',
          votingMembers: ['سارة', 'خالد'],
        ),
      ),
    );
    final user = backend.request!.user;
    expect(user, contains('<minutes_template>'));
    expect(user, contains('«قرر المجلس …»'));
    expect(user, contains('سارة، خالد'));
    final d = m.decisions.single;
    expect(d.formalText, 'قرر المجلس اعتماد الخطة');
    expect(d.vote.positions.map((p) => p.speaker), ['سارة']);
    expect(kMinutesSystemPrompt, contains('توافق دون تصويت رسمي'));
    expect(kMinutesSystemPrompt, contains('Never invent votes'));
  });

  test('without a template the neutral register is requested', () {
    final user = buildMinutesUserMessage(
      meeting: meeting(),
      segments: [seg(0, 0, 1000, 'نص', speakerId: 'a')],
      speakersById: {'a': speaker('a', 'سارة')},
    );
    expect(user, contains('قرر المجتمعون'));
  });
}
