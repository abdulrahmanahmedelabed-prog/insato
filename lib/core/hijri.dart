// Umm al-Qura (أم القرى) Hijri calendar ⇄ Gregorian, pure Dart.
//
// Table-based: the official Umm al-Qura calendar is defined by the
// month-start dates published by the Saudi authorities, not by a formula.
// [_kMonthLengths] lists the length of every month from 1 Muharram 1356 AH
// (14 March 1937) to the end of Dhu al-Hijjah 1500 AH (16 November 2077),
// derived from R. H. van Gent's published Umm al-Qura month-start table
// (the data set used by most Umm al-Qura implementations). Each year is a
// string of 12 digits, one per month: the month length minus 28 (so `1` =
// 29 days, `2` = 30 days). The historic data reproduce one 28-day month
// (Sha'ban 1364 AH, `0`) exactly as published; every month from 1365 AH on
// is 29 or 30 days.
//
// Dates outside the supported range convert to null; callers then show the
// Gregorian date only.

/// Arabic names of the Hijri months (index 0 = Muharram).
const List<String> kHijriMonthNamesAr = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

/// First Hijri year covered by the table.
const int kHijriMinYear = 1356;

/// Last Hijri year covered by the table.
const int kHijriMaxYear = 1500;

/// Days since 1970-01-01 (UTC) of 1 Muharram [kHijriMinYear].
const int _kFirstDay = -11981;

const List<String> _kMonthLengths = [
  '112121221121', // 1356
  '212121212122', // 1357
  '221211211221', // 1358
  '222121121121', // 1359
  '212121212122', // 1360
  '212121212121', // 1361
  '212121212121', // 1362
  '212121212122', // 1363
  '212121202221', // 1364
  '212121212122', // 1365
  '212121212121', // 1366
  '212121212121', // 1367
  '212121212122', // 1368
  '212121221221', // 1369
  '212121212121', // 1370
  '212112121222', // 1371
  '121212112122', // 1372
  '121212121212', // 1373
  '212121221122', // 1374
  '212121211221', // 1375
  '121122212121', // 1376
  '211212122122', // 1377
  '212121212121', // 1378
  '121212121212', // 1379
  '212121212121', // 1380
  '212212112121', // 1381
  '212212211212', // 1382
  '121221212121', // 1383
  '212121212121', // 1384
  '212211212221', // 1385
  '221121212122', // 1386
  '112121212122', // 1387
  '122121212121', // 1388
  '212121212122', // 1389
  '212121221211', // 1390
  '212121212122', // 1391
  '112121212122', // 1392
  '212111212122', // 1393
  '212121211221', // 1394
  '212212112121', // 1395
  '212221211212', // 1396
  '121221212121', // 1397
  '212121221212', // 1398
  '121212121221', // 1399
  '221211212122', // 1400
  '121212112121', // 1401
  '222121211212', // 1402
  '122212121121', // 1403
  '122122212112', // 1404
  '112212212121', // 1405
  '212121212212', // 1406
  '121212121212', // 1407
  '212121211212', // 1408
  '212212121121', // 1409
  '212221212112', // 1410
  '121221221211', // 1411
  '211221222121', // 1412
  '121122122122', // 1413
  '112112122212', // 1414
  '121211212212', // 1415
  '212121211212', // 1416
  '212122121211', // 1417
  '212122212121', // 1418
  '121212212212', // 1419
  '121121222212', // 1420
  '112111222212', // 1421
  '211211122212', // 1422
  '212121121212', // 1423
  '212212112121', // 1424
  '212212122121', // 1425
  '121212212212', // 1426
  '112112221221', // 1427
  '211211222122', // 1428
  '121121122122', // 1429
  '122112121212', // 1430
  '122121212112', // 1431
  '122212121211', // 1432
  '212212212121', // 1433
  '121212212211', // 1434
  '212121212212', // 1435
  '121212121212', // 1436
  '212211212112', // 1437
  '212221121121', // 1438
  '212221212112', // 1439
  '121222121211', // 1440
  '212122122121', // 1441
  '121212122121', // 1442
  '212121212122', // 1443
  '121221121212', // 1444
  '122212112112', // 1445
  '122221211211', // 1446
  '212221212121', // 1447
  '121221221212', // 1448
  '112121221221', // 1449
  '212112121221', // 1450
  '221211212121', // 1451
  '222121121212', // 1452
  '122211212121', // 1453
  '122212121212', // 1454
  '112212122121', // 1455
  '211212122212', // 1456
  '121121122122', // 1457
  '212112112212', // 1458
  '221211211221', // 1459
  '221212121122', // 1460
  '121221212121', // 1461
  '212121212212', // 1462
  '121121221221', // 1463
  '212112121222', // 1464
  '121211211222', // 1465
  '212121121212', // 1466
  '212212112121', // 1467
  '212212121212', // 1468
  '112212212211', // 1469
  '211221212221', // 1470
  '121121221221', // 1471
  '212121121221', // 1472
  '212212112121', // 1473
  '221221211212', // 1474
  '121222121121', // 1475
  '121222122112', // 1476
  '112122122211', // 1477
  '211212212212', // 1478
  '121121212212', // 1479
  '122112121212', // 1480
  '122122121121', // 1481
  '212212212112', // 1482
  '112212221211', // 1483
  '211221221221', // 1484
  '121122122122', // 1485
  '112121212122', // 1486
  '121212112122', // 1487
  '122121211212', // 1488
  '122212121121', // 1489
  '212212212112', // 1490
  '121212212122', // 1491
  '112121212212', // 1492
  '211212112212', // 1493
  '221121121212', // 1494
  '221212112121', // 1495
  '222121211212', // 1496
  '122122112121', // 1497
  '212122121212', // 1498
  '121212121221', // 1499
  '221121121222', // 1500
];

/// A date of the Umm al-Qura calendar.
class HijriDate implements Comparable<HijriDate> {
  /// Creates a date (not validated; see [isValid]).
  const HijriDate(this.year, this.month, this.day);

  /// Hijri year (AH).
  final int year;

  /// Month 1..12.
  final int month;

  /// Day 1..30.
  final int day;

  /// True when the date exists in the supported table.
  bool get isValid {
    final len = UmmAlQura.monthLength(year, month);
    return len != null && day >= 1 && day <= len;
  }

  /// Arabic month name.
  String get monthNameAr => kHijriMonthNamesAr[(month - 1).clamp(0, 11)];

  /// `16 ذو الحجة 1447هـ`.
  String formatAr() => '$day $monthNameAr $yearهـ';

  /// Numeric `1447/12/16هـ`.
  String formatNumeric() =>
      '$year/${month.toString().padLeft(2, '0')}/'
      '${day.toString().padLeft(2, '0')}هـ';

  @override
  int compareTo(HijriDate o) => year != o.year
      ? year.compareTo(o.year)
      : month != o.month
      ? month.compareTo(o.month)
      : day.compareTo(o.day);

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day AH';
}

/// Umm al-Qura conversions.
abstract final class UmmAlQura {
  static List<int>? _starts;

  /// Day number (days since 1970-01-01) of the first day of every month in
  /// the table, plus one sentinel after the last month.
  static List<int> get _monthStarts {
    final cached = _starts;
    if (cached != null) return cached;
    final out = <int>[_kFirstDay];
    var day = _kFirstDay;
    for (final year in _kMonthLengths) {
      for (final c in year.codeUnits) {
        day += 28 + (c - 0x30);
        out.add(day);
      }
    }
    return _starts = out;
  }

  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// Length (29 or 30) of [month] of [year], or null outside the table.
  static int? monthLength(int year, int month) {
    if (year < kHijriMinYear || year > kHijriMaxYear) return null;
    if (month < 1 || month > 12) return null;
    final c = _kMonthLengths[year - kHijriMinYear].codeUnitAt(month - 1);
    return 28 + (c - 0x30);
  }

  /// Number of days in Hijri [year], or null outside the table.
  static int? yearLength(int year) {
    if (year < kHijriMinYear || year > kHijriMaxYear) return null;
    var n = 0;
    for (var m = 1; m <= 12; m++) {
      n += monthLength(year, m)!;
    }
    return n;
  }

  /// The Umm al-Qura date of the calendar day of [date] (its own
  /// year/month/day fields, whatever its time zone), or null outside
  /// 1356–1500 AH.
  static HijriDate? fromGregorian(DateTime date) {
    final day = _epochDay(date);
    final starts = _monthStarts;
    if (day < starts.first || day >= starts.last) return null;
    // Binary search for the last month start <= day.
    var lo = 0, hi = starts.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= day) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return HijriDate(
      kHijriMinYear + lo ~/ 12,
      lo % 12 + 1,
      day - starts[lo] + 1,
    );
  }

  /// The Gregorian date (UTC midnight) of [h], or null when [h] is not a
  /// valid date of the table.
  static DateTime? toGregorian(HijriDate h) {
    if (!h.isValid) return null;
    final index = (h.year - kHijriMinYear) * 12 + h.month - 1;
    final day = _monthStarts[index] + h.day - 1;
    return DateTime.fromMillisecondsSinceEpoch(
      day * Duration.millisecondsPerDay,
      isUtc: true,
    );
  }
}
