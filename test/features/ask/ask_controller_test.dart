import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/features/ask/ask_controller.dart';
import 'package:insato/features/ask/ask_prompt.dart';
import 'package:insato/features/ask/ask_retrieval.dart';
import 'package:insato/features/ask/strings.dart';
import 'package:insato/minutes/gemini_client.dart'
    show GeminiQuotaExceededException;
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/session/post_processor.dart'
    show MinutesEngineNotReadyException, MinutesEngineNotReadyReason;
import 'package:insato/session/providers.dart'
    show minutesBackendFactoryProvider;

import 'fakes.dart';
import 'fixtures.dart';

void main() {
  late FakeCorpus corpusLoader;
  late List<FakeBackend> backends;
  late List<Object> nextReplies;
  late Object? factoryError;

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        askCorpusLoaderProvider.overrideWithValue(corpusLoader),
        askRetrievalRunnerProvider.overrideWithValue(
          (job) async => runAskRetrieval(job),
        ),
        askClockProvider.overrideWithValue(() => DateTime(2026, 11, 19)),
        minutesBackendFactoryProvider.overrideWithValue(() async {
          final e = factoryError;
          if (e != null) throw e;
          final b = FakeBackend(nextReplies);
          backends.add(b);
          return b;
        }),
      ],
    );
    addTearDown(c.dispose);
    // Keep the notifier alive.
    c.listen(askControllerProvider, (_, _) {});
    return c;
  }

  setUp(() {
    corpusLoader = FakeCorpus(corpus());
    backends = [];
    nextReplies = [];
    factoryError = null;
  });

  test('answers with linked citations and closes the backend', () async {
    final c = make();
    nextReplies.add(json('اقتُرح الإطلاق في الأول من ديسمبر [M3#2] [M9#1].'));
    final ok = await c
        .read(askControllerProvider.notifier)
        .ask('  متى موعد إطلاق التطبيق؟ ');
    expect(ok, isTrue);
    final s = c.read(askControllerProvider);
    expect(s.busy, isFalse);
    expect(s.messages, hasLength(2));
    expect(s.messages[0].role, AskRole.user);
    expect(s.messages[0].text, 'متى موعد إطلاق التطبيق؟');
    final a = s.messages[1];
    expect(a.role, AskRole.assistant);
    expect(a.failure, isNull);
    expect(a.found, isTrue);
    expect(a.sentOffDevice, isTrue);
    expect(a.engineName, 'Gemini');
    // Aliases: oldest meeting first → the launch meeting is M3.
    final src = a.answer!.sources.single;
    expect(src.meetingId, 'm-launch');
    expect(src.segmentIndex, 2);
    expect(src.startMs, 20000);
    expect(a.text, isNot(contains('[M')));

    final b = backends.single;
    expect(b.closes, greaterThanOrEqualTo(1));
    final req = b.requests.single;
    expect(req.system, kAskSystemPrompt);
    expect(req.schema, askAnswerSchema());
    expect(req.user, contains('[M3#2'));
    expect(req.user, contains('<question>\nمتى موعد إطلاق التطبيق؟'));
    expect(
      req.user.length + req.system.length,
      lessThanOrEqualTo(askPromptCharBudget('gemini') + 1000),
    );
  });

  test('follow-up questions carry the history and earlier citations', () async {
    final c = make();
    nextReplies.addAll([
      json('في الأول من ديسمبر [M3#2].'),
      json('ليلى مسؤولة عن الحملة [M3#3]، كما ذُكر سابقاً [M3#2].'),
    ]);
    final ctrl = c.read(askControllerProvider.notifier);
    await ctrl.ask('متى إطلاق التطبيق؟');
    await ctrl.ask('ومن المسؤول عن الحملة؟');
    final second = backends[1].requests.single.user;
    expect(second, contains('<conversation_history>'));
    expect(second, contains('<user>متى إطلاق التطبيق؟</user>'));
    expect(second, contains('[M3#2]'));
    final answer = c.read(askControllerProvider).messages.last.answer!;
    expect(answer.sources.map((s) => s.segmentIndex), [3, 2]);
  });

  test('answer_found false is shown as not found', () async {
    final c = make();
    nextReplies.add(json('لا تذكر الاجتماعات ذلك.', found: false));
    await c.read(askControllerProvider.notifier).ask('ما لون السيارة؟');
    final a = c.read(askControllerProvider).messages.last;
    expect(a.found, isFalse);
    expect(a.answer!.sources, isEmpty);
  });

  test('no meetings: notice without calling the engine', () async {
    corpusLoader.meetings = [];
    final c = make();
    await c.read(askControllerProvider.notifier).ask('سؤال');
    final a = c.read(askControllerProvider).messages.last;
    expect(a.failure, AskFailure.noMeetings);
    expect(a.text, AS.noMeetings);
    expect(a.retryable, isFalse);
    expect(backends, isEmpty);
  });

  test('engine not ready: settings failure', () async {
    factoryError = const MinutesEngineNotReadyException(
      'وافق على إشعار الخصوصية أولاً.',
      reason: MinutesEngineNotReadyReason.privacyNotAcknowledged,
    );
    final c = make();
    await c.read(askControllerProvider.notifier).ask('سؤال');
    final s = c.read(askControllerProvider);
    expect(s.busy, isFalse);
    expect(s.messages.last.failure, AskFailure.engineNotReady);
    expect(s.messages.last.text, 'وافق على إشعار الخصوصية أولاً.');
  });

  test('quota and other errors keep their Arabic message', () async {
    final c = make();
    nextReplies.addAll([
      const GeminiQuotaExceededException('نفدت الحصة اليومية.', daily: true),
      const MinutesGenerationException('تعذّر الاتصال.'),
      StateError('boom'),
    ]);
    final ctrl = c.read(askControllerProvider.notifier);
    await ctrl.ask('سؤال 1');
    await ctrl.ask('سؤال 2');
    await ctrl.ask('سؤال 3');
    final failures = [
      for (final m in c.read(askControllerProvider).messages)
        if (m.role == AskRole.assistant) (m.failure, m.text),
    ];
    expect(failures[0], (AskFailure.quota, 'نفدت الحصة اليومية.'));
    expect(failures[1], (AskFailure.error, 'تعذّر الاتصال.'));
    expect(failures[2].$1, AskFailure.error);
    expect(backends.every((b) => b.closes > 0), isTrue);
  });

  test('unreadable output', () async {
    final c = make();
    nextReplies.add('{"answer_found": true}');
    await c.read(askControllerProvider.notifier).ask('سؤال');
    final a = c.read(askControllerProvider).messages.last;
    expect(a.failure, AskFailure.error);
    expect(a.text, AS.unreadable);
  });

  test('retry removes the failed exchange and asks again', () async {
    final c = make();
    nextReplies.addAll([
      const MinutesGenerationException('تعذّر الاتصال.'),
      json('الإجابة [M3#2]'),
    ]);
    final ctrl = c.read(askControllerProvider.notifier);
    await ctrl.ask('متى الإطلاق؟');
    final failed = c.read(askControllerProvider).messages.last;
    expect(failed.retryable, isTrue);
    expect(await ctrl.retry(failed.id), isTrue);
    final s = c.read(askControllerProvider);
    expect(s.messages, hasLength(2));
    expect(s.messages.first.text, 'متى الإطلاق؟');
    expect(s.messages.last.answer, isNotNull);
    expect(await ctrl.retry(999), isFalse);
  });

  test(
    'busy: a second question is refused; cancel discards the answer',
    () async {
      final c = make();
      final pending = Completer<String>();
      nextReplies.add(pending);
      final ctrl = c.read(askControllerProvider.notifier);
      final first = ctrl.ask('متى الإطلاق؟');
      await pumpEventQueue();
      expect(c.read(askControllerProvider).busy, isTrue);
      expect(c.read(askControllerProvider).progress!.phase, AskPhase.thinking);
      expect(await ctrl.ask('سؤال آخر'), isFalse);
      expect(await ctrl.ask('   '), isFalse);

      ctrl.cancel();
      var s = c.read(askControllerProvider);
      expect(s.busy, isFalse);
      expect(s.messages.last.failure, AskFailure.cancelled);
      expect(s.messages.last.question, 'متى الإطلاق؟');
      expect(backends.single.closes, greaterThanOrEqualTo(1));

      pending.complete(json('متأخر [M3#2]'));
      await first;
      s = c.read(askControllerProvider);
      expect(s.messages, hasLength(2));
      expect(s.messages.last.failure, AskFailure.cancelled);
    },
  );

  test('clear empties the conversation and forgets aliases', () async {
    final c = make();
    nextReplies.addAll([json('أ [M3#2]'), json('ب')]);
    final ctrl = c.read(askControllerProvider.notifier);
    await ctrl.ask('متى الإطلاق؟');
    ctrl.clear();
    expect(c.read(askControllerProvider).messages, isEmpty);
    await ctrl.ask('سؤال جديد');
    expect(
      backends.last.requests.single.user,
      isNot(contains('<conversation_history>')),
    );
  });

  test('a long question is clipped', () async {
    final c = make();
    nextReplies.add(json('ج'));
    await c
        .read(askControllerProvider.notifier)
        .ask('س' * (kAskMaxQuestionChars + 50));
    expect(
      c.read(askControllerProvider).messages.first.text.length,
      kAskMaxQuestionChars,
    );
  });

  test('progress labels are Arabic and name the engine', () {
    expect(
      const AskProgress(AskPhase.writing, engineName: 'Claude').labelAr,
      contains('Claude'),
    );
    expect(
      const AskProgress(
        AskPhase.waitingForQuota,
        wait: Duration(seconds: 20),
      ).labelAr,
      contains('20'),
    );
    for (final p in MinutesBackendPhase.values) {
      expect(AskProgress(askPhaseOf(p)).labelAr, isNotEmpty);
    }
  });

  test('retrieval runs inline for small corpora', () async {
    final packed = await runAskRetrievalInBackground(
      AskRetrievalJob(
        meetings: corpus(),
        question: 'الميزانية',
        charBudget: 5000,
      ),
    );
    expect(packed.hasMatches, isTrue);
    expect(packed.detailedMeetings.first, 'm-budget');
  });
}
