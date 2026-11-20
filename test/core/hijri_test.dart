import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/hijri.dart';

void main() {
  group('UmmAlQura', () {
    // Anchors checked against the published Umm al-Qura calendar.
    final anchors = <(HijriDate, DateTime)>[
      (const HijriDate(1356, 1, 1), DateTime(1937, 3, 14)),
      (const HijriDate(1445, 1, 1), DateTime(2023, 7, 19)),
      (const HijriDate(1445, 9, 1), DateTime(2024, 3, 11)),
      (const HijriDate(1445, 10, 1), DateTime(2024, 4, 10)),
      (const HijriDate(1446, 1, 1), DateTime(2024, 7, 7)),
      (const HijriDate(1447, 9, 1), DateTime(2026, 2, 18)),
      (const HijriDate(1447, 10, 1), DateTime(2026, 3, 20)),
      (const HijriDate(1448, 1, 1), DateTime(2026, 6, 16)),
    ];

    test('known anchors convert both ways', () {
      for (final (h, g) in anchors) {
        expect(UmmAlQura.fromGregorian(g), h, reason: '$g');
        final back = UmmAlQura.toGregorian(h)!;
        expect((back.year, back.month, back.day), (g.year, g.month, g.day));
      }
    });

    test('the last day of a month is followed by day 1 of the next', () {
      final end = UmmAlQura.toGregorian(const HijriDate(1447, 12, 1))!;
      final len = UmmAlQura.monthLength(1447, 12)!;
      final last = end.add(Duration(days: len - 1));
      expect(UmmAlQura.fromGregorian(last), HijriDate(1447, 12, len));
      expect(
        UmmAlQura.fromGregorian(last.add(const Duration(days: 1))),
        const HijriDate(1448, 1, 1),
      );
    });

    test('every month from 1365 AH is 29 or 30 days; years 353–356 days', () {
      for (var y = 1365; y <= kHijriMaxYear; y++) {
        for (var m = 1; m <= 12; m++) {
          expect(UmmAlQura.monthLength(y, m), anyOf(29, 30), reason: '$y/$m');
        }
        expect(UmmAlQura.yearLength(y), inInclusiveRange(353, 356), reason: '$y');
      }
    });

    test('round trip for every day of the table', () {
      var g = UmmAlQura.toGregorian(const HijriDate(kHijriMinYear, 1, 1))!;
      HijriDate? prev;
      while (true) {
        final h = UmmAlQura.fromGregorian(g);
        if (h == null) break;
        expect(h.isValid, isTrue);
        final back = UmmAlQura.toGregorian(h)!;
        expect(back, g);
        if (prev != null) expect(h.compareTo(prev), 1);
        prev = h;
        g = g.add(const Duration(days: 1));
      }
      expect(prev, HijriDate(1500, 12, UmmAlQura.monthLength(1500, 12)!));
    });

    test('out of range and invalid dates give null', () {
      expect(UmmAlQura.fromGregorian(DateTime(1900)), isNull);
      expect(UmmAlQura.fromGregorian(DateTime(2100)), isNull);
      expect(UmmAlQura.toGregorian(const HijriDate(1447, 13, 1)), isNull);
      expect(UmmAlQura.toGregorian(const HijriDate(1447, 1, 31)), isNull);
      expect(UmmAlQura.toGregorian(const HijriDate(1600, 1, 1)), isNull);
    });

    test('ignores the time of day and the time zone', () {
      expect(
        UmmAlQura.fromGregorian(DateTime(2026, 6, 16, 23, 59)),
        const HijriDate(1448, 1, 1),
      );
      expect(
        UmmAlQura.fromGregorian(DateTime.utc(2026, 6, 16, 0, 1)),
        const HijriDate(1448, 1, 1),
      );
    });

    test('formats in Arabic', () {
      expect(const HijriDate(1448, 1, 1).formatAr(), '1 محرم 1448هـ');
      expect(const HijriDate(1447, 9, 5).formatNumeric(), '1447/09/05هـ');
    });
  });
}
