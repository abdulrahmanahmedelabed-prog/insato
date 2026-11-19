import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/features/ask/ask.dart';
import 'package:insato/features/ask/ask_retrieval.dart';
import 'package:insato/session/post_processor.dart'
    show MinutesEngineNotReadyException, MinutesEngineNotReadyReason;
import 'package:insato/session/providers.dart'
    show minutesBackendFactoryProvider;
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';
import 'fakes.dart';
import 'fixtures.dart';

void main() {
  late UiTestEnv env;
  late List<Object> replies;
  late Object? factoryError;
  late List<AskCitation> opened;
  late int settingsOpened;

  setUp(() {
    env = UiTestEnv();
    replies = [];
    factoryError = null;
    opened = [];
    settingsOpened = 0;
  });

  Future<void> pump(WidgetTester t) async {
    setScreenSize(t, kPhone);
    final List<Override> overrides = [
      ...env.overrides,
      askCorpusLoaderProvider.overrideWithValue(FakeCorpus(corpus())),
      askRetrievalRunnerProvider.overrideWithValue(
        (job) async => runAskRetrieval(job),
      ),
      minutesBackendFactoryProvider.overrideWithValue(() async {
        final e = factoryError;
        if (e != null) throw e;
        return FakeBackend(replies);
      }),
      askCitationOpenerProvider.overrideWithValue(
        (context, ref, c) async => opened.add(c),
      ),
      askSettingsOpenerProvider.overrideWithValue(
        (context) async => settingsOpened++,
      ),
    ];
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: InsatoTheme.light(),
          home: const AskMeetingsScreen(),
        ),
      ),
    );
    await settle(t);
  }

  Future<void> ask(WidgetTester t, String question) async {
    await t.enterText(find.byType(TextField), question);
    await t.pump();
    await t.tap(find.byTooltip(AS.send));
    await settle(t);
  }

  testWidgets('empty state: examples, privacy notice, RTL', (t) async {
    await pump(t);
    expect(find.text(AS.title), findsOneWidget);
    expect(find.text(AS.emptyTitle), findsOneWidget);
    expect(find.textContaining('Gemini'), findsWidgets);
    expect(find.textContaining('مراجعون بشريون'), findsOneWidget);
    expect(
      Directionality.of(t.element(find.byType(AskMeetingsScreen))),
      TextDirection.rtl,
    );
    final send = t.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.send_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(send.onPressed, isNull);

    await t.tap(find.text(AS.examples.first));
    await t.pump();
    expect(find.widgetWithText(TextField, AS.examples.first), findsOneWidget);
    await env.dispose(t);
  });

  testWidgets('answer with tappable citations and sources', (t) async {
    final semantics = t.ensureSemantics();
    replies.add(json('اقتُرح الإطلاق في الأول من ديسمبر [M3#2].'));
    await pump(t);
    await ask(t, 'متى إطلاق التطبيق؟');

    expect(find.text('متى إطلاق التطبيق؟'), findsOneWidget);
    expect(find.text(AS.sources), findsOneWidget);
    expect(find.text('اجتماع إطلاق التطبيق'), findsOneWidget);
    expect(find.textContaining('00:00:20'), findsOneWidget);
    expect(find.text(AS.answeredBy('Gemini')), findsOneWidget);

    await t.tap(find.text('اجتماع إطلاق التطبيق'));
    await t.pump();
    expect(opened.single.meetingId, 'm-launch');
    expect(opened.single.segmentIndex, 2);

    await t.tap(find.bySemanticsLabel(RegExp('^المصدر 1')));
    await t.pump();
    expect(opened, hasLength(2));

    await t.tap(find.byTooltip(AS.copyAnswer));
    await t.pump();
    expect(env.share.copied.single, contains('1. اجتماع إطلاق التطبيق'));
    semantics.dispose();
    await env.dispose(t);
  });

  testWidgets('engine not ready offers settings', (t) async {
    factoryError = const MinutesEngineNotReadyException(
      'أضف مفتاح Gemini من الإعدادات.',
      reason: MinutesEngineNotReadyReason.noApiKey,
    );
    await pump(t);
    await ask(t, 'سؤال');
    expect(find.text('أضف مفتاح Gemini من الإعدادات.'), findsOneWidget);
    await t.tap(find.text(AS.openSettings));
    await t.pump();
    expect(settingsOpened, 1);
    await env.dispose(t);
  });

  testWidgets('a failure can be retried; new conversation clears', (t) async {
    replies.addAll([
      const MinutesGenerationException('تعذّر الاتصال.'),
      json('الإجابة الثانية [M2]'),
    ]);
    await pump(t);
    await ask(t, 'سؤال');
    expect(find.text('تعذّر الاتصال.'), findsOneWidget);
    await t.tap(find.text(AS.retry));
    await settle(t);
    expect(find.text('تعذّر الاتصال.'), findsNothing);
    expect(find.textContaining('الإجابة الثانية'), findsOneWidget);

    await t.tap(find.byTooltip(AS.clear));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, AS.clear));
    await settle(t);
    expect(find.text(AS.emptyTitle), findsOneWidget);
    await env.dispose(t);
  });
}
