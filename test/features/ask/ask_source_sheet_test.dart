import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/ask/ask.dart';
import 'package:insato/features/ask/ask_source_sheet.dart';
import 'package:insato/features/evidence/evidence.dart';
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/harness.dart';
import '../evidence/fake_player.dart';

TranscriptSegment seg(int index, String text, {SegmentKind? kind}) =>
    TranscriptSegment(
      id: 's$index',
      meetingId: 'm',
      index: index,
      startMs: index * 1000,
      endMs: index * 1000 + 900,
      text: text,
      speakerId: null,
      kind: kind ?? SegmentKind.speech,
    );

void main() {
  group('askExcerptAround', () {
    final segments = [
      for (var i = 9; i >= 0; i--) seg(i, 'نص $i'),
    ]; // reverse order on purpose

    test('cited line with two lines on each side, in order', () {
      final e = askExcerptAround(segments, 5);
      expect([for (final s in e.lines) s.index], [3, 4, 5, 6, 7]);
      expect(e.cited, 2);
      expect(e.found, isTrue);
    });

    test('clamped at the start and end of the transcript', () {
      final first = askExcerptAround(segments, 0);
      expect([for (final s in first.lines) s.index], [0, 1, 2]);
      expect(first.cited, 0);
      final last = askExcerptAround(segments, 9, radius: 1);
      expect([for (final s in last.lines) s.index], [8, 9]);
      expect(last.cited, 1);
    });

    test('empty lines are skipped, the cited one is kept', () {
      final e = askExcerptAround(
        [
          seg(0, 'أ'),
          seg(1, '  '),
          seg(2, 'ب'),
          seg(3, '', kind: SegmentKind.unintelligible),
          seg(4, 'ج'),
        ],
        2,
        radius: 1,
      );
      expect([for (final s in e.lines) s.index], [0, 2, 3]);
      expect(e.cited, 1);
    });

    test('missing segment', () {
      final e = askExcerptAround(segments, 42);
      expect(e.found, isFalse);
      expect(e.lines, isEmpty);
    });
  });

  test('evidence notices are reworded for the sheet', () {
    expect(askSourceNotice(ES.audioNotKept), AS.sourceNoAudio);
    expect(askSourceNotice(ES.audioStillRecording), AS.sourceStillRecording);
    expect(askSourceNotice(ES.playbackFailed), AS.sourcePlaybackFailed);
    expect(askSourceNotice(ES.segmentMissing), AS.sourceSegmentMissing);
    expect(askSourceNotice('أخرى'), 'أخرى');
  });

  group('sheet', () {
    late UiTestEnv env;
    late List<FakeEvidencePlayer> players;
    late List<bool> results;
    late bool failOpen;

    setUp(() {
      env = UiTestEnv();
      players = [];
      results = [];
      failOpen = false;
    });

    Future<Meeting> pump(
      WidgetTester t, {
      EvidenceAudioLocation location = EvidenceAudioLocation.notKept,
      int segmentIndex = 1,
    }) async {
      setScreenSize(t, kPhone);
      final seeded = await env.run(t, () => seedMeeting(env));
      final m = seeded.meeting;
      final citation = AskCitation(
        number: 1,
        meetingId: m.id,
        alias: 1,
        meetingTitle: m.title,
        meetingDate: m.createdAt,
        segmentIndex: segmentIndex,
        startMs: 5000,
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            ...env.overrides,
            evidenceAudioResolverProvider.overrideWithValue(
              (_) async => location,
            ),
            evidencePlayerFactoryProvider.overrideWithValue(() {
              final p = FakeEvidencePlayer()..failOpen = failOpen;
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
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      results.add(await showAskSourceSheet(context, citation)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(t);
      await t.tap(find.text('open'));
      await settle(t);
      return m;
    }

    testWidgets('shows the excerpt; without audio there is no play button', (
      t,
    ) async {
      await pump(t);
      expect(find.text('اجتماع الميزانية'), findsOneWidget);
      expect(find.text(AS.excerptLabel), findsOneWidget);
      expect(
        find.text('We should finalize the marketing budget this week'),
        findsOneWidget,
      );
      expect(find.text('مرحبًا بكم في اجتماع الميزانية'), findsOneWidget);
      expect(find.text(AS.playFromHere), findsNothing);
      expect(find.bySemanticsLabel(RegExp(AS.citedLine)), findsOneWidget);
      await t.tap(find.text(AS.openMeeting));
      await settle(t);
      expect(results, [true]);
      await env.dispose(t);
    });

    testWidgets('plays the recording from the cited line, then pauses', (
      t,
    ) async {
      await pump(
        t,
        location: const EvidenceAudioLocation(
          EvidenceAudioStatus.available,
          '/rec.wav',
        ),
      );
      expect(find.text(AS.playFromHere), findsOneWidget);
      await t.tap(find.text(AS.playFromHere));
      await settle(t);
      expect(players, hasLength(1));
      expect(players.single.calls, contains('open:/rec.wav'));
      expect(players.single.calls, contains('play'));
      // Pre-roll: 1 s before the segment start (5 s).
      expect(players.single.lastSeek, 4000);
      expect(find.text(AS.pauseSource(4000)), findsOneWidget);

      await t.tap(find.text(AS.pauseSource(4000)));
      await settle(t);
      expect(players.single.calls.last, 'pause');
      expect(find.text(AS.playFromHere), findsOneWidget);

      // Dismissing the sheet does not open the meeting and stops the audio.
      await t.tapAt(const Offset(10, 10));
      await settle(t);
      expect(results, [false]);
      await settle(t);
      expect(players.single.disposed, isTrue);
      await env.dispose(t);
    });

    testWidgets('a deleted segment is reported', (t) async {
      await pump(t, segmentIndex: 99);
      expect(find.text(AS.sourceSegmentMissing), findsOneWidget);
      expect(find.text(AS.openMeeting), findsOneWidget);
      await env.dispose(t);
    });

    testWidgets('a failed playback shows the reason', (t) async {
      failOpen = true;
      await pump(
        t,
        location: const EvidenceAudioLocation(
          EvidenceAudioStatus.available,
          '/rec.wav',
        ),
      );
      await t.tap(find.text(AS.playFromHere));
      await settle(t);
      expect(find.text(AS.sourcePlaybackFailed), findsOneWidget);
      expect(find.text(AS.playFromHere), findsOneWidget);
      await env.dispose(t);
    });
  });
}
