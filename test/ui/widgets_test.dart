import 'package:flutter_test/flutter_test.dart';
import 'package:katib/core/models.dart';
import 'package:katib/ui/format.dart';
import 'package:katib/ui/strings_ar.dart';
import 'package:katib/ui/theme.dart';
import 'package:katib/ui/widgets/common.dart';
import 'package:katib/ui/widgets/level_meter.dart';
import 'package:katib/ui/widgets/minutes_view.dart';
import 'package:katib/ui/widgets/speaker_avatar.dart';
import 'package:katib/ui/widgets/transcript_view.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpRtl(WidgetTester t, Widget child, {double width = 420}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: KatibTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

Speaker speaker(String id, String name, {bool named = true}) => Speaker(
  id: id,
  name: name,
  colorValue: 0xFF1E88E5,
  isNamedByUser: named,
  createdAt: DateTime(2026),
);

void main() {
  test('themes use the bundled Arabic font in both brightnesses', () {
    for (final th in [KatibTheme.light(), KatibTheme.dark()]) {
      expect(th.textTheme.bodyLarge?.fontFamily, KatibTheme.arabicFont);
      expect(th.textTheme.bodyLarge?.fontFamilyFallback, contains('NotoSans'));
    }
    expect(KatibTheme.dark().brightness, Brightness.dark);
    expect(onColor(const Color(0xFF000000)), Colors.white);
    expect(onColor(const Color(0xFFFFFFFF)), Colors.black);
  });

  testWidgets('LevelMeter reports its level to accessibility', (t) async {
    final handle = t.ensureSemantics();
    await pumpRtl(t, const LevelMeter(level: 0.5));
    await t.pump(const Duration(milliseconds: 200));
    expect(
      t.getSemantics(find.byType(LevelMeter)),
      matchesSemantics(label: S.micLevel, value: '50٪'),
    );
    await pumpRtl(t, const LevelMeter(level: 0.9, active: false));
    await t.pump(const Duration(milliseconds: 200));
    expect(
      t.getSemantics(find.byType(LevelMeter)),
      matchesSemantics(label: S.micLevel, value: '0٪'),
    );
    handle.dispose();
  });

  testWidgets('StatusChip labels every status', (t) async {
    await pumpRtl(
      t,
      const Column(
        children: [
          StatusChip(status: MeetingStatus.ready),
          StatusChip(status: MeetingStatus.failed, dense: true),
        ],
      ),
    );
    expect(find.text(S.statusReady), findsOneWidget);
    expect(find.text(S.statusFailed), findsOneWidget);
  });

  testWidgets('SpeakerAvatar shows the speaker number or initial', (t) async {
    await pumpRtl(
      t,
      Column(
        children: [
          SpeakerAvatar(speaker: speaker('a', 'متحدث 4', named: false)),
          SpeakerAvatar(speaker: speaker('b', 'سارة')),
          const SpeakerAvatar(speaker: null),
        ],
      ),
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('س'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });

  testWidgets('SpeakerChip is tappable with a semantic button', (t) async {
    var taps = 0;
    await pumpRtl(
      t,
      SpeakerChip(speaker: speaker('b', 'سارة'), onTap: () => taps++),
    );
    await t.tap(find.byType(SpeakerChip));
    expect(taps, 1);
  });

  testWidgets('ErrorBanner offers retry and dismiss', (t) async {
    var retried = 0;
    var dismissed = 0;
    await pumpRtl(
      t,
      ErrorBanner(
        message: 'تعذّر الاتصال',
        onRetry: () => retried++,
        onDismiss: () => dismissed++,
      ),
    );
    await t.tap(find.text(S.retry));
    await t.tap(find.text(S.dismiss));
    expect((retried, dismissed), (1, 1));
  });

  testWidgets('LtrText forces left-to-right digits', (t) async {
    await pumpRtl(t, const LtrText('01:02:03'));
    expect(
      t.widget<Text>(find.text('01:02:03')).textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('TranscriptView groups turns and detects direction', (t) async {
    final segs = [
      const TranscriptSegment(
        id: '1',
        meetingId: 'm',
        index: 0,
        startMs: 0,
        endMs: 2000,
        text: 'صباح الخير',
        speakerId: 'a',
      ),
      const TranscriptSegment(
        id: '2',
        meetingId: 'm',
        index: 1,
        startMs: 2100,
        endMs: 4000,
        text: 'Good morning everyone',
        speakerId: 'a',
        language: 'en',
        speakerLocked: true,
      ),
      const TranscriptSegment(
        id: '3',
        meetingId: 'm',
        index: 2,
        startMs: 4100,
        endMs: 6000,
        text: 'أهلًا',
      ),
    ];
    TranscriptSegment? tapped;
    await pumpRtl(
      t,
      TranscriptView(
        segments: segs,
        speakersById: {'a': speaker('a', 'سارة')},
        onSegmentTap: (s) => tapped = s,
      ),
    );
    expect(find.byType(TranscriptTurnTile), findsNWidgets(2));
    // Names are wrapped in a first-strong bidi isolate.
    expect(find.text(autoIsolate('سارة')), findsOneWidget);
    expect(find.text(autoIsolate(S.unknownSpeaker)), findsOneWidget);
    expect(
      t.widget<Text>(find.text('Good morning everyone')).textDirection,
      TextDirection.ltr,
    );
    expect(find.text('الإنجليزية'), findsOneWidget);
    expect(find.text(S.lockedByUser), findsOneWidget);
    await t.tap(find.text('صباح الخير'));
    expect(tapped?.id, '1');
  });

  testWidgets('action items: table when wide, cards when narrow', (t) async {
    const items = [ActionItem(task: 'إرسال التقرير', owner: 'سارة')];
    await pumpRtl(t, const ActionItemsView(items: items), width: 900);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text(S.notSpecified), findsOneWidget);
    await pumpRtl(t, const ActionItemsView(items: items), width: 400);
    expect(find.byType(Table), findsNothing);
    expect(find.text('${S.due}: ${S.notSpecified}'), findsOneWidget);
  });

  testWidgets('MinutesView marks empty decisions and tasks', (t) async {
    final m = Meeting(
      id: 'm',
      title: 'اجتماع',
      createdAt: DateTime(2026, 11, 19),
      status: MeetingStatus.ready,
    );
    final minutes = Minutes(
      title: '',
      summary: 'ملخص قصير',
      attendees: const [],
      topics: const [],
      decisions: const [],
      actionItems: const [],
      openQuestions: const [],
      languagesDetected: const [],
      generatedAt: DateTime(2026, 11, 19),
      model: 'claude-opus-5-5',
    );
    await pumpRtl(
      t,
      SingleChildScrollView(
        child: MinutesView(meeting: m, minutes: minutes),
      ),
    );
    // Empty minutes title falls back to the meeting title.
    expect(find.text('اجتماع'), findsOneWidget);
    expect(find.text('ملخص قصير'), findsOneWidget);
    expect(find.text(S.noneRecorded), findsNWidgets(2));
  });
}
