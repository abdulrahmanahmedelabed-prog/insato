import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/local_llm/llm_generator.dart';
import 'package:insato/features/local_llm/local_llm_backend.dart';
import 'package:insato/features/local_llm/map_reduce.dart';
import 'package:insato/features/local_llm/strings.dart';
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/minutes/minutes_prompt.dart';

import '../../minutes/fixtures.dart';
import 'fakes.dart';

const Map<String, dynamic> _schema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['title', 'summary'],
  'properties': {
    'title': {'type': 'string'},
    'summary': {'type': 'string'},
  },
};

const String _system = 'MINUTES SYSTEM';
const String _minutes = '{"title": "محضر", "summary": "ملخص"}';

final Map<String, Speaker> _speakers = {
  'a': speaker('a', 'سارة', named: true),
  'b': speaker('b', 'متحدث 2'),
};

List<TranscriptSegment> _segments(int n) => [
  for (var i = 0; i < n; i++)
    seg(
      i,
      i * 15000,
      i * 15000 + 14000,
      'المداخلة رقم $i: ناقشنا بند الميزانية والنفقات التشغيلية للربع الرابع '
      'واقترحنا خفض المصروفات بنسبة عشرة في المئة.',
      speakerId: i.isEven ? 'a' : 'b',
    ),
];

MinutesBackendRequest _minutesRequest(List<TranscriptSegment> segs) {
  final ctx = MinutesPromptContext(
    meeting: meeting(),
    segments: segs,
    speakersById: _speakers,
  );
  return MinutesBackendRequest(
    system: _system,
    user: buildMinutesUserMessage(
      meeting: ctx.meeting,
      segments: segs,
      speakersById: _speakers,
    ),
    schema: _schema,
    context: ctx,
  );
}

LocalLlmMinutesBackend _backend(
  FakeGenerator gen, {
  LocalLlmBudget budget = const LocalLlmBudget(),
}) => LocalLlmMinutesBackend(
  engineId: 'local',
  displayName: 'محلي',
  sendsDataOffDevice: false,
  open: () async => gen,
  budget: budget,
);

/// Asserts that every request fit the context window.
void _expectWithinContext(FakeGenerator gen, LocalLlmBudget budget) {
  for (final r in gen.requests) {
    final used =
        (r.system.length / gen.charsPerToken).ceil() +
        (r.user.length / gen.charsPerToken).ceil() +
        r.maxTokens +
        budget.templateOverheadTokens;
    expect(used, lessThanOrEqualTo(gen.contextTokens), reason: r.system);
    expect(r.maxTokens, greaterThan(0));
  }
}

String _notesFor(LlmGenerationRequest r) {
  final ids = RegExp(r'\[#(\d+) ').allMatches(r.user).map((m) => m[1]).toList();
  return jsonEncode({
    'notes': [
      {
        'kind': 'point',
        'text': 'ملاحظة عن المقاطع ${ids.join(',')}',
        'speakers': ['سارة'],
        'evidence': [for (final i in ids.take(3)) int.parse(i!)],
      },
    ],
  });
}

void main() {
  group('single request', () {
    test('a request that fits is sent as is', () async {
      final gen = FakeGenerator(responses: [_minutes]);
      final backend = _backend(gen);
      final phases = <MinutesBackendPhase>[];
      final req = _minutesRequest(_segments(5));
      final out = await backend.generateStructured(
        req,
        onProgress: (p) => phases.add(p.phase),
      );
      expect(out.text, _minutes);
      expect(out.model, 'fake-model');
      final r = gen.requests.single;
      expect(r.system, _system);
      expect(r.user, req.user);
      expect(r.schema, _schema);
      expect(
        r.maxTokens,
        lessThanOrEqualTo(const LocalLlmBudget().maxAnswerTokens),
      );
      expect(phases.first, MinutesBackendPhase.loadingModel);
      expect(phases, contains(MinutesBackendPhase.writing));
      _expectWithinContext(gen, const LocalLlmBudget());
      expect(backend.sendsDataOffDevice, isFalse);
    });

    test(
      'the schema goes into the prompt when the runtime cannot enforce it',
      () async {
        final gen = FakeGenerator(responses: [_minutes], enforcesSchema: false);
        await _backend(gen).generateStructured(_minutesRequest(_segments(2)));
        expect(gen.requests.single.system, startsWith(_system));
        expect(
          gen.requests.single.system,
          contains('# Output format (strict)'),
        );
      },
    );

    test('an invalid answer gets one repair pass', () async {
      final gen = FakeGenerator(
        responses: ['Here are the minutes: {"title": "محضر"', _minutes],
      );
      final out = await _backend(gen)
          .generateStructured(_minutesRequest(_segments(3)));
      expect(out.text, _minutes);
      expect(gen.requests, hasLength(2));
      final repair = gen.requests.last;
      expect(repair.system, kJsonRepairSystemPrompt);
      expect(repair.temperature, 0);
      expect(repair.schema, _schema);
      expect(repair.user, contains('{"title": "محضر"'));
      expect(repair.user, startsWith('<answer>'));
    });

    test(
      'when the repair fails too, the decodable answer is returned',
      () async {
        final gen = FakeGenerator(responses: ['{"title": "محضر"}', 'garbage']);
        final out = await _backend(gen)
            .generateStructured(_minutesRequest(_segments(3)));
        expect(out.text, '{"title": "محضر"}');
      },
    );

    test('a failing repair request keeps the original answer', () async {
      final gen = FakeGenerator(responses: ['not json']);
      gen.respond = (_) => throw const MinutesGenerationException('x');
      final out = await _backend(gen)
          .generateStructured(_minutesRequest(_segments(3)));
      expect(out.text, 'not json');
    });

    test('a long non-minutes request is shortened to the window', () async {
      final gen = FakeGenerator(
        contextTokens: 4096,
        responses: ['{"answer": "x"}'],
      );
      final user =
          'السؤال: ما القرارات؟\n<context>\n${List.generate(800, (i) => 'سطر سياق رقم $i').join('\n')}\n</context>\nأجب بإيجاز.';
      final out = await _backend(gen).generateStructured(
        MinutesBackendRequest(
          system: 'ASK',
          user: user,
          schema: const {
            'type': 'object',
            'required': ['answer'],
          },
        ),
      );
      expect(out.text, '{"answer": "x"}');
      final sent = gen.requests.single.user;
      expect(sent.length, lessThan(user.length));
      expect(
        sent,
        startsWith('السؤال: ما القرارات؟\n<context>\nسطر سياق رقم 0'),
      );
      expect(sent, endsWith('</context>\nأجب بإيجاز.'));
      _expectWithinContext(gen, const LocalLlmBudget());
    });

    test('a window too small for anything is reported', () async {
      final gen = FakeGenerator(contextTokens: 1100);
      await expectLater(
        _backend(gen).generateStructured(
          MinutesBackendRequest(
            system: 'S',
            user: 'x' * 20000,
            schema: _schema,
          ),
        ),
        throwsA(
          isA<MinutesGenerationException>().having(
            (e) => e.messageAr,
            'messageAr',
            LS.contextTooSmall,
          ),
        ),
      );
    });
  });

  group('lifecycle', () {
    test('a failed open is retried by the next request', () async {
      var opens = 0;
      final gen = FakeGenerator(responses: [_minutes]);
      final backend = LocalLlmMinutesBackend(
        engineId: 'server',
        displayName: 'خادم',
        sendsDataOffDevice: true,
        openPhase: MinutesBackendPhase.connecting,
        open: () async {
          opens++;
          if (opens == 1) throw const ModelException('load failed');
          return gen;
        },
      );
      final req = _minutesRequest(_segments(2));
      await expectLater(
        backend.generateStructured(req),
        throwsA(isA<ModelException>()),
      );
      expect((await backend.generateStructured(req)).text, _minutes);
      expect(opens, 2);
      // The generator is opened once and reused.
      gen.responses.add(_minutes);
      await backend.generateStructured(req);
      expect(opens, 2);
    });

    test('close releases the generator; later requests fail', () async {
      final gen = FakeGenerator(responses: [_minutes]);
      final backend = _backend(gen);
      final req = _minutesRequest(_segments(2));
      await backend.generateStructured(req);
      backend
        ..close()
        ..close();
      await Future<void>.delayed(Duration.zero);
      expect(gen.closed, isTrue);
      await expectLater(
        backend.generateStructured(req),
        throwsA(
          isA<MinutesGenerationException>().having(
            (e) => e.messageAr,
            'messageAr',
            LS.engineClosed,
          ),
        ),
      );
    });

    test('close before any request opens nothing', () {
      var opened = false;
      LocalLlmMinutesBackend(
        engineId: 'local',
        displayName: 'x',
        sendsDataOffDevice: false,
        open: () async {
          opened = true;
          return FakeGenerator();
        },
      ).close();
      expect(opened, isFalse);
    });
  });

  group('map-reduce', () {
    test('a long transcript is summarised part by part', () async {
      const budget = LocalLlmBudget();
      final segs = _segments(120);
      final gen = FakeGenerator(contextTokens: 4096);
      gen.respond = (r) =>
          r.system.startsWith(_system) ? _minutes : _notesFor(r);
      final progress = <MinutesBackendProgress>[];
      final out = await _backend(gen)
          .generateStructured(_minutesRequest(segs), onProgress: progress.add);
      expect(out.text, _minutes);

      final maps = gen.requests
          .where((r) => r.system.startsWith(kChunkNotesSystemPrompt))
          .toList();
      expect(maps.length, greaterThan(2));
      // Every segment is read in exactly one part, in order.
      final seen = [
        for (final r in maps)
          for (final m in RegExp(r'\[#(\d+) ').allMatches(r.user))
            int.parse(m[1]!),
      ];
      expect(seen, [for (var i = 0; i < 120; i++) i]);
      expect(maps.first.user, contains('part 1 of ${maps.length}'));
      expect(
        maps.every((r) => r.schema!['required'].toString() == '[notes]'),
        isTrue,
      );

      final reduce = gen.requests.last;
      expect(reduce.system, _system);
      expect(reduce.schema, _schema);
      expect(reduce.user, contains(kReduceTranscriptIntro));
      expect(reduce.user, contains('Part 1 of ${maps.length}'));
      expect(reduce.user, contains('(speakers: سارة)'));
      expect(reduce.user, isNot(contains('المداخلة رقم 5:')));

      _expectWithinContext(gen, budget);

      final fractions = [
        for (final p in progress)
          if (p.phase == MinutesBackendPhase.processingChunk) p.fraction!,
      ];
      expect(fractions, isNotEmpty);
      expect(fractions.every((f) => f >= 0 && f <= 1), isTrue);
      expect(fractions.last, greaterThan(0.5));
    });

    test('notes too long for the final step are condensed', () async {
      const budget = LocalLlmBudget();
      final segs = _segments(200);
      final gen = FakeGenerator(contextTokens: 4096);
      var condenseCalls = 0;
      gen.respond = (r) {
        if (r.system.startsWith(_system)) return _minutes;
        if (r.system.startsWith(kCondenseNotesSystemPrompt)) {
          condenseCalls++;
          return jsonEncode({
            'notes': [
              {
                'kind': 'decision',
                'text': 'خفض النفقات',
                'speakers': ['سارة'],
                'evidence': [1],
              },
            ],
          });
        }
        // Verbose notes: one long note per segment.
        final ids = RegExp(r'\[#(\d+) ').allMatches(r.user).map((m) => m[1]!);
        return jsonEncode({
          'notes': [
            for (final i in ids)
              {
                'kind': 'point',
                'text': 'ملاحظة مفصلة طويلة جداً عن المداخلة $i ' * 3,
                'speakers': ['سارة'],
                'evidence': [int.parse(i)],
              },
          ],
        });
      };
      final out = await _backend(gen).generateStructured(_minutesRequest(segs));
      expect(out.text, _minutes);
      expect(condenseCalls, greaterThan(0));
      final reduce = gen.requests.last;
      expect(reduce.system, _system);
      expect(reduce.user, contains('[decision] خفض النفقات'));
      _expectWithinContext(gen, budget);
    });

    test('notes still too long after condensing are cut to fit', () async {
      const budget = LocalLlmBudget(maxCondenseRounds: 0);
      final segs = _segments(200);
      final gen = FakeGenerator(contextTokens: 4096);
      gen.respond = (r) {
        if (r.system.startsWith(_system)) return _minutes;
        return jsonEncode({
          'notes': [
            {
              // One giant note line (longer than the reduce budget).
              'kind': 'point',
              'text': 'نص طويل ' * 900,
              'speakers': <String>[],
              'evidence': [1],
            },
          ],
        });
      };
      final out = await _backend(
        gen,
        budget: budget,
      ).generateStructured(_minutesRequest(segs));
      expect(out.text, _minutes);
      _expectWithinContext(gen, budget);
      // The beginning of the notes is kept, not just a part header.
      expect(gen.requests.last.user, contains('[point] نص طويل نص طويل'));
    });

    test('unreadable notes of a part are replaced by a marker', () async {
      final segs = _segments(60);
      final gen = FakeGenerator(contextTokens: 4096);
      gen.respond = (r) {
        if (r.system.startsWith(_system)) return _minutes;
        return 'لا أستطيع'; // Map and repair both fail.
      };
      final out = await _backend(gen).generateStructured(_minutesRequest(segs));
      expect(out.text, _minutes);
      expect(gen.requests.last.user, contains(LS.chunkNotesUnreadable));
      expect(
        gen.requests.where((r) => r.system.startsWith(kJsonRepairSystemPrompt)),
        isNotEmpty,
      );
    });

    test('a context too small for map-reduce is reported', () async {
      final gen = FakeGenerator(contextTokens: 1200);
      gen.respond = (r) => '{"notes": []}';
      await expectLater(
        _backend(gen).generateStructured(_minutesRequest(_segments(80))),
        throwsA(
          isA<MinutesGenerationException>().having(
            (e) => e.messageAr,
            'messageAr',
            LS.contextTooSmall,
          ),
        ),
      );
    });
  });

  group('helpers', () {
    test('budgets are clamped', () {
      const b = LocalLlmBudget();
      expect(b.answerTokens(1000), b.minAnswerTokens);
      expect(b.answerTokens(12288), (12288 * 0.4).round());
      expect(b.answerTokens(100000), b.maxAnswerTokens);
      expect(b.mapAnswerTokens(1000), b.minMapAnswerTokens);
      expect(b.mapAnswerTokens(100000), b.maxMapAnswerTokens);
    });

    test('conformsToSchemaKeys', () {
      expect(conformsToSchemaKeys(_minutes, _schema), isTrue);
      expect(conformsToSchemaKeys('```json\n$_minutes\n```', _schema), isTrue);
      expect(
        conformsToSchemaKeys('<think>x</think>$_minutes', _schema),
        isTrue,
      );
      expect(conformsToSchemaKeys('{"title": "x"}', _schema), isFalse);
      expect(conformsToSchemaKeys('nope', _schema), isFalse);
      expect(conformsToSchemaKeys('{}', const {'type': 'object'}), isTrue);
    });

    test('fitUserMessage cuts the context block at its end', () {
      final body = List.generate(50, (i) => 'line $i').join('\n');
      final user = 'Q\n<context>\n$body\n</context>\nEND';
      expect(fitUserMessage(user, user.length), user);
      final fitted = fitUserMessage(user, 120);
      expect(fitted.length, lessThanOrEqualTo(120));
      expect(fitted, startsWith('Q\n<context>\nline 0\n'));
      expect(fitted, endsWith('\n…\n</context>\nEND'));
    });

    test('fitUserMessage drops the middle without a context block', () {
      final user = '${'a' * 100}${'b' * 100}';
      final fitted = fitUserMessage(user, 53);
      expect(fitted.length, lessThanOrEqualTo(53));
      expect(fitted, startsWith('a'));
      expect(fitted, endsWith('b'));
      expect(fitted, contains('\n…\n'));
    });

    test('repair user message wraps the answer', () {
      expect(
        buildJsonRepairUserMessage('X'),
        startsWith('<answer>\nX\n</answer>'),
      );
    });
  });
}
