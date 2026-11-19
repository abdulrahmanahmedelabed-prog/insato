import 'dart:ui' show TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:katib/core/interfaces.dart';
import 'package:katib/core/models.dart';
import 'package:katib/data/secure_settings.dart';
import 'package:katib/ui/format.dart';
import 'package:katib/ui/strings_ar.dart';

TranscriptSegment seg(
  int i,
  int start,
  int end,
  String? speaker, {
  String text = 'نص',
}) => TranscriptSegment(
  id: 's$i',
  meetingId: 'm',
  index: i,
  startMs: start,
  endMs: end,
  text: text,
  speakerId: speaker,
);

Meeting meeting(String title, {Minutes? minutes}) => Meeting(
  id: title,
  title: title,
  createdAt: DateTime(2026, 11, 19, 10),
  status: MeetingStatus.ready,
  minutes: minutes,
);

void main() {
  group('detectTextDirection', () {
    test('Arabic text is RTL', () {
      expect(detectTextDirection('مرحبًا بكم في الاجتماع'), TextDirection.rtl);
    });

    test('English text is LTR', () {
      expect(
        detectTextDirection('Let us review the quarterly budget'),
        TextDirection.ltr,
      );
    });

    test('mostly English with an Arabic word stays LTR', () {
      expect(
        detectTextDirection('We should ask أحمد about the API rollout today'),
        TextDirection.ltr,
      );
    });

    test('mostly Arabic with an English term stays RTL', () {
      expect(
        detectTextDirection('سنراجع الـ budget في الاجتماع القادم إن شاء الله'),
        TextDirection.rtl,
      );
    });

    test('neutral text uses the fallback', () {
      expect(detectTextDirection('12:30 - 2026'), TextDirection.rtl);
      expect(
        detectTextDirection('', fallback: TextDirection.ltr),
        TextDirection.ltr,
      );
    });
  });

  test('ltrIsolate wraps text in LRI … PDI', () {
    final s = ltrIsolate('00:12:34');
    expect(s.codeUnitAt(0), 0x2066);
    expect(s.codeUnitAt(s.length - 1), 0x2069);
    expect(s.substring(1, s.length - 1), '00:12:34');
    expect(autoIsolate('Sara').codeUnitAt(0), 0x2068);
    expect(ltrDuration(754000), ltrIsolate('12:34'));
  });

  test('meetingStatusLabel covers every status', () {
    expect(meetingStatusLabel(MeetingStatus.ready), S.statusReady);
    expect(meetingStatusLabel(MeetingStatus.failed), S.statusFailed);
    expect(meetingStatusLabel(MeetingStatus.recording), S.statusRecording);
    expect(meetingStatusLabel(MeetingStatus.processing), S.statusProcessing);
  });

  group('speakerInitials', () {
    test('automatic names show their number', () {
      expect(speakerInitials('متحدث 3'), '3');
      expect(speakerInitials('متحدث ١٢'), '12');
    });

    test('Arabic names show the first letter, skipping honorifics', () {
      expect(speakerInitials('سارة أحمد'), 'س');
      expect(speakerInitials('د. سارة'), 'س');
    });

    test('Latin names show two initials', () {
      expect(speakerInitials('john smith'), 'JS');
      expect(speakerInitials('Alice'), 'A');
    });

    test('blank names show a question mark', () {
      expect(speakerInitials('   '), '؟');
    });
  });

  group('groupTurns', () {
    test('merges consecutive segments of the same speaker', () {
      final turns = groupTurns([
        seg(0, 0, 1000, 'a'),
        seg(1, 1200, 2000, 'a'),
        seg(2, 2100, 3000, 'b'),
        seg(3, 3100, 4000, 'a'),
      ]);
      expect(turns.map((t) => t.speakerId), ['a', 'b', 'a']);
      expect(turns.first.segments.map((s) => s.id), ['s0', 's1']);
      expect(turns.first.startMs, 0);
      expect(turns.first.endMs, 2000);
    });

    test('splits a turn on a long pause and sorts by time', () {
      final turns = groupTurns([
        seg(1, 20000, 21000, 'a'),
        seg(0, 0, 1000, 'a'),
      ], maxGapMs: 4000);
      expect(turns, hasLength(2));
      expect(turns.first.segments.single.id, 's0');
    });

    test('unknown speakers form their own turns', () {
      final turns = groupTurns([
        seg(0, 0, 1000, null),
        seg(1, 1100, 2000, null),
        seg(2, 2100, 3000, 'a'),
      ]);
      expect(turns.map((t) => t.speakerId), [null, 'a']);
    });

    test('empty input gives no turns', () {
      expect(groupTurns(const []), isEmpty);
    });
  });

  test('computeTalkTimes gives shares sorted by speaking time', () {
    final t = computeTalkTimes([
      seg(0, 0, 3000, 'a'),
      seg(1, 3000, 4000, 'b'),
      seg(2, 4000, 7000, 'a'),
      seg(3, 7000, 9000, null),
    ]);
    expect(t.map((x) => x.speakerId), ['a', null, 'b']);
    expect(t.first.speakingMs, 6000);
    expect(t.first.segmentCount, 2);
    expect(t.first.share, closeTo(6 / 9, 1e-9));
    expect(t.first.percent, 67);
    expect(computeTalkTimes(const []), isEmpty);
  });

  group('search', () {
    test('normalizeForSearch unifies Arabic letter forms and digits', () {
      expect(
        normalizeForSearch('إجتماعُ  الميزانيّة ٢٠٢٦'),
        'اجتماع الميزانيه 2026',
      );
      expect(normalizeForSearch('مستشفى'), 'مستشفي');
      expect(normalizeForSearch('Budget'), 'budget');
    });

    test('matches title, minutes and ignores diacritics', () {
      final minutes = Minutes(
        title: 'محضر',
        summary: 'ناقش الفريق خطة التسويق',
        attendees: const ['سارة'],
        topics: const [],
        decisions: const [],
        actionItems: const [ActionItem(task: 'إعداد العرض', owner: 'Omar')],
        openQuestions: const [],
        languagesDetected: const [],
        generatedAt: DateTime(2026),
        model: 'x',
      );
      final list = [
        meeting('اجتماع الميزانية'),
        meeting('مراجعة', minutes: minutes),
      ];
      expect(filterMeetings(list, '').length, 2);
      expect(
        filterMeetings(list, 'الميزانيه').single.title,
        'اجتماع الميزانية',
      );
      expect(filterMeetings(list, 'التسويق').single.title, 'مراجعة');
      expect(filterMeetings(list, 'omar العرض').single.title, 'مراجعة');
      expect(filterMeetings(list, 'غير موجود'), isEmpty);
    });
  });

  group('models', () {
    const ready = ModelState(ModelStatus.ready);

    test('on-device ASR needs VAD, speaker and the chosen Whisper', () {
      const s = AppSettingsData(whisperModelId: 'whisper-small');
      expect(missingModelIds(s, const {}), [
        'silero-vad',
        'wespeaker-resnet34',
        'whisper-small',
      ]);
      expect(
        missingModelIds(s, const {
          'silero-vad': ready,
          'wespeaker-resnet34': ready,
          'whisper-small': ready,
        }),
        isEmpty,
      );
    });

    test('cloud ASR does not need Whisper', () {
      const s = AppSettingsData(asrEngine: AppSettingsData.asrCloud);
      expect(missingModelIds(s, const {'silero-vad': ready}), [
        'wespeaker-resnet34',
      ]);
      expect(neededModelIds(s, const {}), ['silero-vad', 'wespeaker-resnet34']);
    });

    test('an installed alternative speaker model satisfies the need', () {
      const s = AppSettingsData(asrEngine: AppSettingsData.asrCloud);
      expect(
        missingModelIds(s, const {
          'silero-vad': ready,
          '3dspeaker-eres2net-base': ready,
        }),
        isEmpty,
      );
    });

    test('downloading models still count as missing', () {
      const s = AppSettingsData(asrEngine: AppSettingsData.asrCloud);
      expect(
        missingModelIds(s, const {
          'silero-vad': ModelState(ModelStatus.downloading, progress: 0.5),
          'wespeaker-resnet34': ready,
        }),
        ['silero-vad'],
      );
    });
  });

  group('strings', () {
    test('Arabic counting forms', () {
      expect(S.speakersCount(1), 'متحدث واحد');
      expect(S.speakersCount(2), 'متحدثان');
      expect(S.speakersCount(5), '5 متحدثين');
      expect(S.speakersCount(11), '11 متحدثًا');
      expect(S.meetingsCount(0), 'لم يظهر في أي اجتماع');
      expect(S.segmentsCount(3), '3 مقاطع');
    });

    test('language names accept region tags', () {
      expect(S.languageName('en-US'), 'الإنجليزية');
      expect(S.languageName('AR'), 'العربية');
      expect(S.languageName('xx'), isNull);
      expect(S.languageName(null), isNull);
      for (final c in S.commonLanguageCodes) {
        expect(S.languageName(c), isNotNull, reason: c);
      }
    });

    test('approximate sizes', () {
      expect(S.approxSize(27), 'نحو 27 ميغابايت');
      expect(S.approxSize(1800), 'نحو 1.8 غيغابايت');
    });
  });
}
