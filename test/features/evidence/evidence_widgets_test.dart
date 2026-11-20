import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/evidence/evidence.dart';
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';
import 'fake_player.dart';

const int kSegments = 200;

String lineText(int i) => 'السطر رقم $i';

Future<String> seed(UiTestEnv env) async {
  final speakers = SpeakerRepository(env.db);
  final a = await speakers.create(name: 'سارة');
  final b = await speakers.create(name: 'عمر');
  final m = await MeetingRepository(env.db)
      .create(title: 'اجتماع', status: MeetingStatus.ready);
  await SegmentRepository(env.db).insertAll([
    for (var i = 0; i < kSegments; i++)
      TranscriptSegment(
        id: '',
        meetingId: m.id,
        index: i,
        startMs: i * 4000,
        endMs: i * 4000 + 3000,
        text: lineText(i),
        speakerId: i.isEven ? a.id : b.id,
      ),
  ]);
  return m.id;
}

class Page extends StatelessWidget {
  const Page({super.key, required this.meetingId, required this.evidence});

  final String meetingId;
  final List<int> evidence;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        bottom: const TabBar(
          tabs: [
            Tab(text: 'minutes'),
            Tab(text: 'transcript'),
          ],
        ),
      ),
      body: EvidenceScope(
        meetingId: meetingId,
        child: TabBarView(
          children: [
            ListView(
              children: [
                const Text('topic'),
                EvidenceChips(meetingId: meetingId, evidence: evidence),
              ],
            ),
            EvidenceTranscriptTab(meetingId: meetingId),
          ],
        ),
      ),
    ),
  );
}

Future<void> pumpPage(
  WidgetTester t,
  UiTestEnv env,
  String meetingId,
  List<int> evidence, {
  required EvidenceAudioLocation location,
  required List<FakeEvidencePlayer> players,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...env.overrides,
        evidenceAudioResolverProvider.overrideWithValue((_) async => location),
        evidencePlayerFactoryProvider.overrideWithValue(() {
          final p = FakeEvidencePlayer();
          players.add(p);
          return p;
        }),
      ],
      retry: (_, _) => null,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: InsatoTheme.light(),
        home: Page(meetingId: meetingId, evidence: evidence),
      ),
    ),
  );
  await settle(t);
}

bool isHighlighted(WidgetTester t, int i) => t
    .widget<EvidenceSegmentLine>(
      find.ancestor(
        of: find.text(lineText(i)),
        matching: find.byType(EvidenceSegmentLine),
      ),
    )
    .highlighted;

void main() {
  testWidgets('chip plays with pre-roll; player bar controls; jump to line', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final id = await env.run(t, () => seed(env));
    final players = <FakeEvidencePlayer>[];
    await pumpPage(
      t,
      env,
      id,
      const [150, 3],
      location: const EvidenceAudioLocation(
        EvidenceAudioStatus.available,
        '/r/x.wav',
      ),
      players: players,
    );

    // Chronological chips with LTR timestamps and play icons.
    expect(find.text('00:00:12'), findsOneWidget);
    expect(find.text('00:10:00'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
    expect(find.byType(EvidencePlayerBar), findsOneWidget);
    expect(find.text(ES.clipTitle(150)), findsNothing);

    await t.tap(find.text('00:10:00'));
    await settle(t);
    final p = players.single;
    expect(p.calls, ['open:/r/x.wav', 'seek:599000', 'play']);
    expect(find.text('${ES.clipTitle(150)} · سارة'), findsOneWidget);
    expect(find.text(lineText(150)), findsOneWidget);
    expect(find.byTooltip(ES.pause), findsOneWidget);

    await t.tap(find.byTooltip(ES.pause));
    await settle(t);
    expect(p.calls.last, 'pause');
    expect(find.byTooltip(ES.play), findsOneWidget);

    await t.tap(find.text('1×'));
    await settle(t);
    expect(find.text('1.5×'), findsOneWidget);

    await t.tap(find.byTooltip(ES.replayClip));
    await settle(t);
    expect(p.calls.sublist(p.calls.length - 3), [
      'seek:599000',
      'play',
      'rate:1.5',
    ]);

    // Jump to the transcript: tab switches, far line scrolled in and lit.
    await t.tap(find.byTooltip(ES.showInTranscript));
    await settle(t, rounds: 12);
    expect(find.byType(EvidenceTranscriptView), findsOneWidget);
    expect(find.text(lineText(150)), findsWidgets);
    expect(isHighlighted(t, 150), isTrue);
    expect(find.text(lineText(0)), findsNothing);

    await t.tap(find.byTooltip(ES.closePlayer));
    await settle(t);
    expect(find.text('${ES.clipTitle(150)} · سارة'), findsNothing);
    expect(p.calls.last, 'pause');

    await env.dispose(t);
  });

  testWidgets('without audio the chip jumps to the transcript line', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final id = await env.run(t, () => seed(env));
    final players = <FakeEvidencePlayer>[];
    await pumpPage(
      t,
      env,
      id,
      const [120],
      location: EvidenceAudioLocation.notKept,
      players: players,
    );
    expect(find.byIcon(Icons.subject_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    await t.tap(find.text('00:08:00'));
    await settle(t, rounds: 12);
    expect(players, isEmpty);
    expect(find.text(ES.audioNotKept), findsOneWidget);
    expect(find.byType(EvidenceTranscriptView), findsOneWidget);
    expect(isHighlighted(t, 120), isTrue);
    expect(find.text(lineText(0)), findsNothing);

    await env.dispose(t);
  });

  testWidgets('long evidence lists collapse behind +N; unknown ids vanish', (
    t,
  ) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final id = await env.run(t, () => seed(env));
    await pumpPage(
      t,
      env,
      id,
      const [1, 2, 3, 4, 5, 6, 999],
      location: EvidenceAudioLocation.notKept,
      players: [],
    );
    expect(find.byType(InputChip), findsNWidgets(4));
    expect(find.text('+2'), findsOneWidget);
    await t.tap(find.text('+2'));
    await t.pump();
    expect(find.byType(InputChip), findsNWidgets(6));
    expect(find.text('+2'), findsNothing);
    await env.dispose(t);
  });

  testWidgets('no chips for empty or unresolvable evidence', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final id = await env.run(t, () => seed(env));
    await pumpPage(
      t,
      env,
      id,
      const [999],
      location: EvidenceAudioLocation.notKept,
      players: [],
    );
    expect(find.byType(InputChip), findsNothing);
    expect(find.bySemanticsLabel(ES.evidenceGroupLabel), findsNothing);
    await env.dispose(t);
  });

  testWidgets('long press on a transcript line plays from there', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final id = await env.run(t, () => seed(env));
    final players = <FakeEvidencePlayer>[];
    await pumpPage(
      t,
      env,
      id,
      const [],
      location: const EvidenceAudioLocation(
        EvidenceAudioStatus.available,
        '/r/x.wav',
      ),
      players: players,
    );
    await t.tap(find.text('transcript'));
    await settle(t);
    await t.longPress(find.text(lineText(2)));
    await settle(t);
    expect(players.single.calls, ['open:/r/x.wav', 'seek:7000', 'play']);
    expect(isHighlighted(t, 2), isTrue);
    expect(find.text('${ES.clipTitle(2)} · سارة'), findsOneWidget);
    await env.dispose(t);
  });
}
