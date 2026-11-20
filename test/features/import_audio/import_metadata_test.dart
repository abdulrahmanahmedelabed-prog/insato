import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/time_format.dart';
import 'package:insato/features/import_audio/import_metadata.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final now = DateTime(2026, 11, 20, 12);

  setUpAll(() async {
    await initializeDateFormatting('ar');
    ensureArabicDateFormatting();
  });

  group('parseContainerDate', () {
    test('ISO 8601 (iOS) and Android MediaMetadataRetriever dates', () {
      expect(
        parseContainerDate('2024-11-15T10:30:12Z', now: now),
        DateTime.utc(2024, 11, 15, 10, 30, 12),
      );
      expect(
        parseContainerDate('20241115T103012.000Z', now: now),
        DateTime.utc(2024, 11, 15, 10, 30, 12),
      );
      expect(
        parseContainerDate('20241115T103012', now: now),
        DateTime(2024, 11, 15, 10, 30, 12),
      );
      expect(
        parseContainerDate('2024-11-15 10:30:12', now: now),
        DateTime(2024, 11, 15, 10, 30, 12),
      );
    });

    test('unset epochs, future dates and garbage are ignored', () {
      expect(parseContainerDate('19040101T000000.000Z', now: now), isNull);
      expect(parseContainerDate('1970-01-01T00:00:00Z', now: now), isNull);
      expect(parseContainerDate('2030-01-01T00:00:00Z', now: now), isNull);
      expect(parseContainerDate('20241345T103012', now: now), isNull);
      expect(parseContainerDate('yesterday', now: now), isNull);
      expect(parseContainerDate('', now: now), isNull);
      expect(parseContainerDate(null, now: now), isNull);
    });
  });

  group('dateFromFileName', () {
    test('call recorders and voice recorders', () {
      // Samsung: name_yyMMdd_HHmmss.
      expect(
        dateFromFileName('Call recording Ahmad_241115_103012.m4a', now: now),
        DateTime(2024, 11, 15, 10, 30, 12),
      );
      // Xiaomi: name(number)_yyyyMMddHHmmss.
      expect(
        dateFromFileName('Ahmad(0501234567)_20241115103012.mp3', now: now),
        DateTime(2024, 11, 15, 10, 30, 12),
      );
      // Pixel / generic recorders.
      expect(
        dateFromFileName('Recording_20241115_103012.m4a', now: now),
        DateTime(2024, 11, 15, 10, 30, 12),
      );
      expect(
        dateFromFileName('Meeting 2024-11-15 10.30.mp4', now: now),
        DateTime(2024, 11, 15, 10, 30),
      );
      expect(
        dateFromFileName('zoom_2024-11-15.m4a', now: now),
        DateTime(2024, 11, 15),
      );
    });

    test('no date, impossible or future dates', () {
      expect(dateFromFileName('New Recording 3.m4a', now: now), isNull);
      expect(dateFromFileName('voice_20241399_101010.m4a', now: now), isNull);
      expect(dateFromFileName('call_20991115_101010.m4a', now: now), isNull);
    });
  });

  test('resolveRecordingTime: container, then file name, then mtime', () {
    final mtime = DateTime(2025, 1, 2, 3, 4);
    expect(
      resolveRecordingTime(
        containerDate: '20241115T103012',
        fileName: 'Recording_20230101_000000.m4a',
        modified: mtime,
        now: now,
      ),
      DateTime(2024, 11, 15, 10, 30, 12),
    );
    expect(
      resolveRecordingTime(
        containerDate: '19040101T000000.000Z',
        fileName: 'Recording_20230101_090000.m4a',
        modified: mtime,
        now: now,
      ),
      DateTime(2023, 1, 1, 9),
    );
    expect(
      resolveRecordingTime(fileName: 'memo.m4a', modified: mtime, now: now),
      mtime,
    );
    expect(resolveRecordingTime(fileName: 'memo.m4a', now: now), now);
  });

  group('titles', () {
    final at = DateTime(2024, 11, 15, 10, 30);

    test('call recordings become «مكالمة: name»', () {
      expect(
        suggestImportTitle('Call recording Ahmad_241115_103012.m4a', at),
        'مكالمة: Ahmad',
      );
      expect(
        suggestImportTitle('تسجيل المكالمة سارة 2024-11-15.m4a', at),
        'مكالمة: سارة',
      );
      expect(
        suggestImportTitle('Call recording_241115_103012.m4a', at),
        'مكالمة ${formatArabicDateTime(at)}',
      );
      expect(looksLikeCallRecording('Call from Mona.amr'), isTrue);
      expect(looksLikeCallRecording('Board meeting.m4a'), isFalse);
    });

    test('other files keep their name without dates and separators', () {
      expect(suggestImportTitle('New Recording 3.m4a', at), 'New Recording 3');
      expect(
        suggestImportTitle('board_meeting_2024-11-15 10.30.mp4', at),
        'board meeting',
      );
      expect(
        suggestImportTitle('اجتماع اللجنة.m4a', at),
        'اجتماع اللجنة',
      );
    });

    test('nothing meaningful left → «تسجيل مستورد <date>»', () {
      expect(
        suggestImportTitle('20241115_103012.wav', at),
        'تسجيل مستورد ${formatArabicDateTime(at)}',
      );
      expect(
        suggestImportTitle('___.mp3', at),
        'تسجيل مستورد ${formatArabicDateTime(at)}',
      );
    });
  });
}
