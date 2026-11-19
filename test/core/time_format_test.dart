import 'package:flutter_test/flutter_test.dart';
import 'package:katib/core/time_format.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(0), '00:00');
    expect(formatDuration(-500), '00:00');
    expect(formatDuration(59999), '00:59');
    expect(formatDuration(61000), '01:01');
    expect(formatDuration(3600000), '01:00:00');
    expect(formatDuration(3723000), '01:02:03');
    expect(formatDuration(36000000 + 5000), '10:00:05');
    expect(formatDuration(65000, alwaysHours: true), '00:01:05');
    expect(formatDuration(65000, arabicDigits: true), '٠١:٠٥');
  });

  test('formatTimestamp always has hours', () {
    expect(formatTimestamp(5000), '00:00:05');
  });

  test('formatClock', () {
    final t = DateTime(2026, 11, 19, 9, 5, 7);
    expect(formatClock(t), '09:05');
    expect(formatClock(t, withSeconds: true), '09:05:07');
    expect(formatClock(t, arabicDigits: true), '٠٩:٠٥');
  });

  test('digit conversion round trip', () {
    expect(toArabicDigits('2026-11-19 x'), '٢٠٢٦-١١-١٩ x');
    expect(toWesternDigits('٢٠٢٦ ۱۲'), '2026 12');
  });

  test('formatDurationWords applies Arabic count agreement', () {
    expect(formatDurationWords(0), 'أقل من ثانية');
    expect(formatDurationWords(1000), 'ثانية');
    expect(formatDurationWords(2000), 'ثانيتان');
    expect(formatDurationWords(5000), '5 ثوانٍ');
    expect(formatDurationWords(45000), '45 ثانية');
    expect(formatDurationWords(3 * 60000 + 2000), '3 دقائق وثانيتان');
    expect(formatDurationWords(3600000 + 12 * 60000 + 30000), 'ساعة و12 دقيقة');
    expect(formatDurationWords(2 * 3600000), 'ساعتان');
  });

  test('Arabic dates', () {
    final d = DateTime(2026, 11, 19, 14, 5);
    final full = formatArabicDate(d);
    expect(full, contains('نوفمبر'));
    expect(full, contains('2026'));
    expect(full, contains('الخميس'));
    expect(formatArabicShortDate(d), contains('19'));
    expect(formatArabicDateTime(d), endsWith('14:05'));
    expect(formatArabicDate(d, arabicDigits: true), contains('٢٠٢٦'));
  });
}
