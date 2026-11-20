import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/minutes/minutes_generator.dart';
import 'package:insato/minutes/minutes_prompt.dart';

import 'fixtures.dart';

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

  StructuredMinutesEngine engine(
    _ScriptedBackend b, {
    MinutesDetailLevel level = MinutesDetailLevel.detailed,
  }) => StructuredMinutesEngine(
    backend: b,
    detailLevel: level,
    clock: () => DateTime(2026, 11, 19, 15),
  );

  test('generates minutes from the backend JSON with progress', () async {
    final expected = sampleMinutes();
    final b = _ScriptedBackend(
      jsonEncode(expected.contentJson()),
      model: 'groq/openai/gpt-oss-120b',
      phases: const [
        MinutesBackendProgress(MinutesBackendPhase.connecting),
        MinutesBackendProgress(
          MinutesBackendPhase.waitingForQuota,
          wait: Duration(seconds: 12),
        ),
        MinutesBackendProgress(MinutesBackendPhase.thinking),
        MinutesBackendProgress(MinutesBackendPhase.writing, receivedChars: 900),
      ],
    );
    final progress = <double>[];
    final statuses = <String>[];
    final minutes = await engine(b, level: MinutesDetailLevel.concise).generate(
      meeting: meeting(),
      segments: segments,
      speakersById: speakers,
      onProgress: (p, s) {
        progress.add(p);
        statuses.add(s);
      },
    );

    expect(minutes.contentJson(), expected.contentJson());
    expect(minutes.model, 'groq/openai/gpt-oss-120b');
    expect(minutes.generatedAt, DateTime(2026, 11, 19, 15));
    expect(progress.last, 1.0);
    expect(progress.every((p) => p >= 0 && p <= 1), isTrue);
    expect(statuses.last, 'اكتمل المحضر');
    expect(statuses, contains('يحلّل Groq مجريات الاجتماع…'));
    expect(
      statuses,
      contains('بلغت حدّ الطلبات المجاني، ستُعاد المحاولة بعد 12 ثانية…'),
    );

    final request = b.requests.single;
    expect(request.system, kMinutesSystemPrompt);
    expect(request.user, contains('<transcript>'));
    expect(request.user, contains('"concise"'));
    expect(request.schema, minutesJsonSchema());
    expect(request.context!.segments, hasLength(2));
  });

  test('empty title from the model falls back to the meeting title', () async {
    final content = sampleMinutes().contentJson()..['title'] = '';
    final b = _ScriptedBackend(jsonEncode(content));
    final minutes = await engine(
      b,
    ).generate(meeting: meeting(), segments: segments, speakersById: speakers);
    expect(minutes.title, 'اجتماع الميزانية');
  });

  test(
    'empty transcript throws an Arabic InsatoException without calling the API',
    () async {
      final b = _ScriptedBackend('{}');
      await expectLater(
        engine(b).generate(
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
      expect(b.requests, isEmpty);
    },
  );

  test('unparseable output throws MinutesGenerationException', () async {
    final b = _ScriptedBackend('not json');
    await expectLater(
      engine(b).generate(
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

/// A backend that records requests and answers [text] after replaying
/// [phases].
class _ScriptedBackend implements MinutesBackend {
  _ScriptedBackend(this.text, {this.model = 'fake', this.phases = const []});

  final String text;
  final String model;
  final List<MinutesBackendProgress> phases;
  final List<MinutesBackendRequest> requests = [];

  @override
  String get engineId => 'groq';

  @override
  String get displayName => 'Groq';

  @override
  bool get sendsDataOffDevice => true;

  @override
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  }) async {
    requests.add(request);
    phases.forEach(onProgress ?? (_) {});
    return MinutesBackendResult(text: text, model: model);
  }

  @override
  void close() {}
}
