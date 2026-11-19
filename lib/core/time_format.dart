// Time, duration and date formatting helpers shared by the UI, the transcript
// renderer and the exporters.
//
// Pure Dart (only depends on package:intl), so it is usable from isolates and
// plain unit tests.

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const List<String> _arabicIndicDigits = [
  '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', //
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Replaces the Western digits `0-9` in [input] with Arabic-Indic digits
/// (`٠-٩`). All other characters are left untouched.
String toArabicDigits(String input) {
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buffer.write(_arabicIndicDigits[unit - 0x30]);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// Replaces Arabic-Indic (`٠-٩`) and Eastern Arabic-Indic (`۰-۹`) digits in
/// [input] with Western digits `0-9`.
String toWesternDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Formats a duration given in milliseconds as `mm:ss`, or `h:mm:ss` /
/// `hh:mm:ss` once it reaches one hour.
///
/// * Negative values are treated as zero.
/// * Hours are zero-padded to two digits (`01:02:03`).
/// * [alwaysHours] forces the `hh:mm:ss` form even below one hour.
/// * [arabicDigits] renders the result with Arabic-Indic digits.
String formatDuration(
  int ms, {
  bool alwaysHours = false,
  bool arabicDigits = false,
}) {
  final totalSeconds = (ms < 0 ? 0 : ms) ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final text = (hours > 0 || alwaysHours)
      ? '${_two(hours)}:${_two(minutes)}:${_two(seconds)}'
      : '${_two(minutes)}:${_two(seconds)}';
  return arabicDigits ? toArabicDigits(text) : text;
}

/// Formats an offset from the start of a recording as `hh:mm:ss`, always with
/// hours. This is the timestamp format used in transcripts.
String formatTimestamp(int ms, {bool arabicDigits = false}) =>
    formatDuration(ms, alwaysHours: true, arabicDigits: arabicDigits);

/// Formats the wall-clock time of [time] as 24-hour `HH:mm`
/// (or `HH:mm:ss` when [withSeconds] is true), in local time.
String formatClock(
  DateTime time, {
  bool withSeconds = false,
  bool arabicDigits = false,
}) {
  final t = time.toLocal();
  final text = withSeconds
      ? '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}'
      : '${_two(t.hour)}:${_two(t.minute)}';
  return arabicDigits ? toArabicDigits(text) : text;
}

/// Arabic words for a duration, e.g. `ساعة و12 دقيقة`, `ساعتان و3 دقائق`,
/// `45 ثانية`. Applies the Arabic number–noun agreement rules for 1, 2,
/// 3–10 and 11+. Seconds are only shown when the duration is under one hour.
/// Zero (or negative) yields `أقل من ثانية`.
String formatDurationWords(int ms) {
  final totalSeconds = (ms < 0 ? 0 : ms) ~/ 1000;
  if (totalSeconds == 0) return 'أقل من ثانية';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final parts = <String>[
    if (hours > 0) _countNoun(hours, 'ساعة', 'ساعتان', 'ساعات', 'ساعة'),
    if (minutes > 0)
      _countNoun(minutes, 'دقيقة', 'دقيقتان', 'دقائق', 'دقيقة'),
    if (seconds > 0 && hours == 0)
      _countNoun(seconds, 'ثانية', 'ثانيتان', 'ثوانٍ', 'ثانية'),
  ];
  return parts.join(' و');
}

String _countNoun(
  int n,
  String one,
  String two,
  String fewPlural,
  String manySingular,
) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n >= 3 && n <= 10) return '$n $fewPlural';
  return '$n $manySingular';
}

bool _dateFormattingReady = false;

/// Loads the locale data `package:intl` needs to format dates in Arabic.
///
/// The data ships inside `package:intl` itself, so this completes
/// synchronously; it is safe (and cheap) to call more than once. The date
/// helpers below call it automatically.
void ensureArabicDateFormatting() {
  if (_dateFormattingReady) return;
  // The local-data initializer installs the symbols synchronously and only
  // returns an already-completed future for API compatibility.
  initializeDateFormatting('ar');
  _dateFormattingReady = true;
}

/// Formats [date] as a full Arabic date, e.g. `الخميس، 19 نوفمبر 2026`.
///
/// Digits are Western by default (as in the `ar` locale data); pass
/// [arabicDigits] to use Arabic-Indic digits.
String formatArabicDate(DateTime date, {bool arabicDigits = false}) {
  ensureArabicDateFormatting();
  final text = toWesternDigits(DateFormat.yMMMMEEEEd('ar').format(date.toLocal()));
  return arabicDigits ? toArabicDigits(text) : text;
}

/// Formats [date] as a short Arabic date without the weekday,
/// e.g. `19 نوفمبر 2026`.
String formatArabicShortDate(DateTime date, {bool arabicDigits = false}) {
  ensureArabicDateFormatting();
  final text = toWesternDigits(DateFormat.yMMMMd('ar').format(date.toLocal()));
  return arabicDigits ? toArabicDigits(text) : text;
}

/// Formats [date] as a full Arabic date followed by the 24-hour clock time,
/// e.g. `الخميس، 19 نوفمبر 2026 - 14:05`.
String formatArabicDateTime(DateTime date, {bool arabicDigits = false}) {
  final text = '${formatArabicDate(date)} - ${formatClock(date)}';
  return arabicDigits ? toArabicDigits(text) : text;
}
