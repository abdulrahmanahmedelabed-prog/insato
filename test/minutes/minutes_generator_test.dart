import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/minutes/claude_client.dart';
import 'package:insato/minutes/minutes_generator.dart';
import 'package:insato/minutes/minutes_prompt.dart';

import 'fixtures.dart';
import 'sse_fixtures.dart';

void main() {
  final speakers = {
    'a': speaker('a', 'سارة', named: true),
    'b': speaker('b', 'متحدث 2'),
  };
  final segments = [
    seg(0, 0, 4000, 'نبدأ بمراجعة الميزانية', speakerId: 'a'),
    seg(
      1,
      5000,
      9000,
      'I will send the report Thursday',
      speakerId: 'b',
      language: 'en',
    ),
  ];

  ClaudeMinutesEngine engine(
    QueueClient q, {
    MinutesDetailLevel level = MinutesDetailLevel.detailed,
  }) => ClaudeMinutesEngine(
    client: ClaudeClient(apiKey: 'k', client: q.client, delay: (_) async {}),
    detailLevel: level,
    clock: () => DateTime(2026, 11, 19, 15),
  );

  test('generates minutes from the streamed JSON with progress', () async {
    final expected = sampleMinutes();
    final q = QueueClient([
      () => chunkedResponse(
        successStream(
          jsonEncode(expected.contentJson()),
          fallbackTo: 'claude-opus-5',
        ),
      ),
    ]);
    final progress = <double>[];
    final statuses = <String>[];
    final minutes = await engine(q, level: MinutesDetailLevel.concise).generate(
      meeting: meeting(),
      segments: segments,
      speakersById: speakers,
      onProgress: (p, s) {
        progress.add(p);
        statuses.add(s);
      },
    );

    expect(minutes.contentJson(), expected.contentJson());
    expect(minutes.model, 'claude-opus-5');
    expect(minutes.generatedAt, DateTime(2026, 11, 19, 15));
    expect(progress.last, 1.0);
    expect(progress.every((p) => p >= 0 && p <= 1), isTrue);
    expect(statuses.last, 'اكتمل المحضر');
    expect(statuses, contains('يحلّل Claude مجريات الاجتماع…'));

    final body = jsonDecode(q.bodies.single) as Map<String, dynamic>;
    expect((body['system'] as List).single['text'], kMinutesSystemPrompt);
    final user = (body['messages'] as List).single['content'] as String;
    expect(user, contains('<transcript>'));
    expect(user, contains('"concise"'));
    expect(body['output_config']['format']['schema'], minutesJsonSchema());
  });

  test('empty title from the model falls back to the meeting title', () async {
    final content = sampleMinutes().contentJson()..['title'] = '';
    final q = QueueClient([
      () => chunkedResponse(successStream(jsonEncode(content))),
    ]);
    final minutes = await engine(
      q,
    ).generate(meeting: meeting(), segments: segments, speakersById: speakers);
    expect(minutes.title, 'اجتماع الميزانية');
  });

  test(
    'empty transcript throws an Arabic InsatoException without calling the API',
    () async {
      final q = QueueClient([]);
      await expectLater(
        engine(q).generate(
          meeting: meeting(),
          segments: [seg(0, 0, 1000, '   ', speakerId: 'a')],
          speakersById: speakers,
        ),
        throwsA(
          isA<InsatoException>().having(
            (e) => e.messageAr,
            'messageAr',
            contains('لا يوجد كلام مسجّل'),
          ),
        ),
      );
      expect(q.requests, isEmpty);
    },
  );

  test('unparseable output throws MinutesGenerationException', () async {
    final q = QueueClient([() => chunkedResponse(successStream('not json'))]);
    await expectLater(
      engine(q).generate(
        meeting: meeting(),
        segments: segments,
        speakersById: speakers,
      ),
      throwsA(isA<MinutesGenerationException>()),
    );
  });

  group('parseMinutesJson', () {
    test('plain, fenced and wrapped JSON', () {
      expect(parseMinutesJson(' {"a":1} '), {'a': 1});
      expect(parseMinutesJson('```json\n{"a":2}\n```'), {'a': 2});
      expect(parseMinutesJson('Here: {"a":3} done'), {'a': 3});
    });

    test('rejects arrays and garbage', () {
      expect(
        () => parseMinutesJson('[1]'),
        throwsA(isA<MinutesGenerationException>()),
      );
      expect(
        () => parseMinutesJson(''),
        throwsA(isA<MinutesGenerationException>()),
      );
    });
  });
}
