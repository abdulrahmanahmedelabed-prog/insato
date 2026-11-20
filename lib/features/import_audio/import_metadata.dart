// Meeting metadata of an imported recording: the recording time (container
// metadata, then a date in the file name, then the file's modification
// time) and a title made from the file name. Pure Dart.

import '../../core/time_format.dart';
import 'strings.dart';

/// Earliest plausible recording time; container dates before it (1904 /
/// 1970 epochs of unset fields) are ignored.
final DateTime _kEarliest = DateTime.utc(2000);

bool _plausible(DateTime d, DateTime now) =>
    !d.isBefore(_kEarliest) && !d.isAfter(now.add(const Duration(days: 1)));

DateTime? _build(int y, int mo, int d, [int h = 0, int mi = 0, int s = 0]) {
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  if (h > 23 || mi > 59 || s > 59) return null;
  final dt = DateTime(y, mo, d, h, mi, s);
  // Rejects 31 February and similar (DateTime would roll over).
  if (dt.month != mo || dt.day != d) return null;
  return dt;
}

/// Parses the creation date a platform decoder reports for a container
/// (ISO 8601 from iOS, `yyyyMMdd'T'HHmmss.SSS'Z'` from Android's
/// `MediaMetadataRetriever`, or `yyyy-MM-dd HH:mm:ss`). Returns null for
/// missing, malformed or implausible dates (before 2000 or in the future;
/// [now] defaults to the current time).
DateTime? parseContainerDate(String? raw, {DateTime? now}) {
  final s = raw?.trim();
  if (s == null || s.isEmpty) return null;
  final ref = now ?? DateTime.now();
  // DateTime.tryParse rolls impossible dates over (month 13 → next year).
  final ymd = RegExp(r'^(\d{4})-?(\d{2})-?(\d{2})').firstMatch(s);
  if (ymd != null &&
      _build(
            int.parse(ymd.group(1)!),
            int.parse(ymd.group(2)!),
            int.parse(ymd.group(3)!),
          ) ==
          null) {
    return null;
  }
  DateTime? d = DateTime.tryParse(s);
  if (d == null) {
    final m = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(?:\.\d+)?(Z)?$',
    ).firstMatch(s);
    if (m != null) {
      final parts = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
      final local = _build(
        parts[0],
        parts[1],
        parts[2],
        parts[3],
        parts[4],
        parts[5],
      );
      if (local != null) {
        d = m.group(7) == 'Z'
            ? DateTime.utc(
                parts[0],
                parts[1],
                parts[2],
                parts[3],
                parts[4],
                parts[5],
              )
            : local;
      }
    }
  }
  if (d == null) return null;
  return _plausible(d, ref) ? d : null;
}

final List<RegExp> _fileDatePatterns = [
  // 2024-11-15 10.30.12, 20241115_103012, 2024_11_15-10-30, 20241115103012
  RegExp(
    r'(?<!\d)(20\d{2})[-_.]?(\d{2})[-_.]?(\d{2})(?:[ _T-]*(\d{2})[-_.:h]?(\d{2})(?:[-_.:m]?(\d{2}))?)?(?!\d)',
  ),
  // Samsung: Call recording Name_241115_103012 (yyMMdd_HHmmss)
  RegExp(r'(?<!\d)(\d{2})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})(?!\d)'),
];

/// The recording time encoded in a file name ([fileName] with or without
/// its extension), e.g. `Call recording Ahmad_241115_103012.m4a` or
/// `Recording 2024-11-15 10.30.12.mp3`; null when none is found or it is
/// implausible.
DateTime? dateFromFileName(String fileName, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  for (var i = 0; i < _fileDatePatterns.length; i++) {
    for (final m in _fileDatePatterns[i].allMatches(fileName)) {
      int g(int n) => int.tryParse(m.group(n) ?? '') ?? 0;
      final year = i == 0 ? g(1) : 2000 + g(1);
      final d = _build(year, g(2), g(3), g(4), g(5), g(6));
      if (d != null && _plausible(d, ref)) return d;
    }
  }
  return null;
}

/// When the recording was made: the container date, else the date in the
/// file name, else the file's [modified] time, else [now].
DateTime resolveRecordingTime({
  String? containerDate,
  required String fileName,
  DateTime? modified,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final fromContainer = parseContainerDate(containerDate, now: ref);
  if (fromContainer != null) return fromContainer.toLocal();
  final fromName = dateFromFileName(fileName, now: ref);
  if (fromName != null) return fromName;
  if (modified != null && _plausible(modified, ref)) return modified;
  return ref;
}

final RegExp _callWords = RegExp(
  r'(call[ _-]?recording|callrecord(?:ing)?|call[ _-]?rec|recorded[ _-]?call|'
  r'call[ _-]?(?:from|with|to)|phone[ _-]?call|\bcall\b|تسجيل[ _]?المكالمة|'
  r'تسجيل[ _]?مكالمة|مكالمة)',
  caseSensitive: false,
);

/// The file name without extension (when it is a known audio one).
String _stem(String fileName) {
  final base = fileName.split(RegExp(r'[\\/]')).last;
  final dot = base.lastIndexOf('.');
  if (dot > 0 && base.length - dot <= 6) return base.substring(0, dot);
  return base;
}

/// Whether [fileName] looks like a phone-call recording (Samsung, Xiaomi,
/// Pixel, iOS 18 call recordings, or an Arabic name containing «مكالمة»).
bool looksLikeCallRecording(String fileName) =>
    _callWords.hasMatch(_stem(fileName));

/// A meeting title for an imported file: the file name without extension,
/// dates / times and separators; `مكالمة: <name>` for call recordings; and
/// `تسجيل مستورد <date>` (or `مكالمة <date>`) when nothing meaningful is
/// left. [recordedAt] is the recording time ([resolveRecordingTime]).
String suggestImportTitle(String fileName, DateTime recordedAt) {
  var stem = _stem(fileName);
  final call = looksLikeCallRecording(stem);
  if (call) stem = stem.replaceAll(_callWords, ' ');
  for (final p in _fileDatePatterns) {
    stem = stem.replaceAll(p, ' ');
  }
  stem = stem
      // Bare clock times left over (10.30, 10-30-12).
      .replaceAll(RegExp(r'(?<!\d)\d{1,2}[.:h-]\d{2}(?:[.:m-]\d{2})?(?!\d)'), ' ')
      .replaceAll(RegExp(r'[_+]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^[\s\-–—.,:;()\[\]]+|[\s\-–—.,:;(\[]+$'), '')
      .trim();
  final date = formatArabicDateTime(recordedAt);
  final meaningful = RegExp(r'[\p{L}]', unicode: true).hasMatch(stem);
  if (call) {
    return meaningful ? IS.callTitle(stem) : IS.callTitleAt(date);
  }
  return meaningful ? stem : IS.importedTitleAt(date);
}
