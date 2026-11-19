// Pure presentation helpers of the UI (no widgets): bidi direction of mixed
// language text, LTR isolation of numbers, transcript turn grouping, talk
// time shares, Arabic-aware search and missing-model detection. Unit-tested
// in test/ui/format_test.dart.

import 'dart:ui' show TextDirection;

import 'package:intl/intl.dart' as intl;

import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/time_format.dart';
import '../data/repositories.dart' show parseAutoSpeakerNumber;
import '../data/secure_settings.dart';
import '../session/meeting_session_controller.dart'
    show SessionEngineRequest, requiredModelIds;
import 'strings_ar.dart';

/// Unicode LEFT-TO-RIGHT ISOLATE.
const String kLri = '\u2066';

/// Unicode FIRST STRONG ISOLATE.
const String kFsi = '\u2068';

/// Unicode POP DIRECTIONAL ISOLATE.
const String kPdi = '\u2069';

/// Wraps [text] in a left-to-right isolate so numbers such as `00:12:34` or
/// Latin fragments keep their order inside Arabic sentences.
String ltrIsolate(String text) => '$kLri$text$kPdi';

/// Wraps [text] in a first-strong isolate (direction from its own content),
/// for user-supplied names embedded in Arabic sentences.
String autoIsolate(String text) => '$kFsi$text$kPdi';

/// Direction a transcript [text] should be laid out in, estimated from its
/// words: mostly-Arabic (or Persian, Urdu, Hebrew) text is RTL, mostly-Latin
/// text is LTR. Neutral text (digits, punctuation, empty) uses [fallback].
TextDirection detectTextDirection(
  String text, {
  TextDirection fallback = TextDirection.rtl,
}) {
  final d = intl.Bidi.estimateDirectionOfText(text);
  if (d == intl.TextDirection.RTL) return TextDirection.rtl;
  if (d == intl.TextDirection.LTR) {
    // Purely numeric / weakly-LTR content (e.g. "2026") stays in the
    // paragraph direction.
    return intl.Bidi.hasAnyLtr(text) ? TextDirection.ltr : fallback;
  }
  return fallback;
}

/// `hh:mm:ss` (or `mm:ss`) of [ms] isolated as LTR.
String ltrDuration(int ms) => ltrIsolate(formatDuration(ms));

/// Arabic label of a meeting [status].
String meetingStatusLabel(MeetingStatus status) => switch (status) {
  MeetingStatus.recording => S.statusRecording,
  MeetingStatus.processing => S.statusProcessing,
  MeetingStatus.ready => S.statusReady,
  MeetingStatus.failed => S.statusFailed,
};

/// Short text for a speaker avatar: the number of automatic names
/// (`متحدث 3` → `3`), otherwise the first letter of the name (two initials
/// for Latin names, e.g. `John Smith` → `JS`).
String speakerInitials(String name) {
  final n = parseAutoSpeakerNumber(name);
  if (n != null) return '$n';
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '؟';
  // Skip common Arabic honorifics so "د. سارة" shows "س".
  const honorifics = {'د.', 'د', 'م.', 'أ.', 'الأستاذ', 'الدكتور', 'المهندس'};
  final meaningful = words.where((w) => !honorifics.contains(w)).toList();
  final list = meaningful.isEmpty ? words : meaningful;
  final first = list.first;
  final firstRune = String.fromCharCode(first.runes.first);
  final isLatin = RegExp('[A-Za-z]').hasMatch(firstRune);
  if (isLatin && list.length > 1) {
    final second = String.fromCharCode(list[1].runes.first);
    return '$firstRune$second'.toUpperCase();
  }
  return isLatin ? firstRune.toUpperCase() : firstRune;
}

/// Consecutive transcript segments of the same speaker, shown as one turn.
class TranscriptTurn {
  /// Creates a turn.
  const TranscriptTurn({required this.speakerId, required this.segments});

  /// Speaker of every segment in the turn (null = unknown).
  final String? speakerId;

  /// Segments in order (never empty).
  final List<TranscriptSegment> segments;

  /// Start of the first segment.
  int get startMs => segments.first.startMs;

  /// End of the last segment.
  int get endMs => segments.last.endMs;
}

/// Groups [segments] (any order) into speaker turns: consecutive segments of
/// the same speaker separated by at most [maxGapMs] form one turn.
List<TranscriptTurn> groupTurns(
  List<TranscriptSegment> segments, {
  int maxGapMs = 4000,
}) {
  final sorted = [...segments]
    ..sort((a, b) {
      final c = a.startMs.compareTo(b.startMs);
      return c != 0 ? c : a.index.compareTo(b.index);
    });
  final turns = <TranscriptTurn>[];
  var current = <TranscriptSegment>[];
  for (final s in sorted) {
    if (current.isNotEmpty &&
        (current.last.speakerId != s.speakerId ||
            s.startMs - current.last.endMs > maxGapMs)) {
      turns.add(
        TranscriptTurn(speakerId: current.first.speakerId, segments: current),
      );
      current = <TranscriptSegment>[];
    }
    current.add(s);
  }
  if (current.isNotEmpty) {
    turns.add(
      TranscriptTurn(speakerId: current.first.speakerId, segments: current),
    );
  }
  return turns;
}

/// Speaking time of one speaker within a meeting.
class SpeakerTalkTime {
  /// Creates a record.
  const SpeakerTalkTime({
    required this.speakerId,
    required this.speakingMs,
    required this.segmentCount,
    required this.share,
  });

  /// Speaker (null = unassigned speech).
  final String? speakerId;

  /// Total duration of the speaker's segments.
  final int speakingMs;

  /// Number of segments.
  final int segmentCount;

  /// Share of all speech, 0..1.
  final double share;

  /// [share] as a whole percentage.
  int get percent => (share * 100).round();
}

/// Talk time per speaker over [segments], most talkative first.
List<SpeakerTalkTime> computeTalkTimes(List<TranscriptSegment> segments) {
  final ms = <String?, int>{};
  final counts = <String?, int>{};
  var total = 0;
  for (final s in segments) {
    final d = (s.endMs - s.startMs).clamp(0, 1 << 31);
    ms[s.speakerId] = (ms[s.speakerId] ?? 0) + d;
    counts[s.speakerId] = (counts[s.speakerId] ?? 0) + 1;
    total += d;
  }
  final list = [
    for (final e in ms.entries)
      SpeakerTalkTime(
        speakerId: e.key,
        speakingMs: e.value,
        segmentCount: counts[e.key] ?? 0,
        share: total == 0 ? 0 : e.value / total,
      ),
  ];
  list.sort((a, b) => b.speakingMs.compareTo(a.speakingMs));
  return list;
}

final RegExp _arabicDiacritics = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

/// Normalises [text] for forgiving Arabic search: removes diacritics and
/// tatweel, unifies alef / ya / ta marbuta / hamza forms, converts
/// Arabic-Indic digits and lower-cases Latin letters.
String normalizeForSearch(String text) {
  var t = toWesternDigits(text).toLowerCase().replaceAll(_arabicDiacritics, '');
  t = t
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// True when every word of [query] occurs in [meeting]'s title, minutes
/// (summary, attendees, topics, decisions, tasks) or Arabic date.
bool meetingMatchesQuery(Meeting meeting, String query) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;
  final m = meeting.minutes;
  final haystack = normalizeForSearch(
    [
      meeting.title,
      formatArabicDate(meeting.createdAt),
      if (m != null) ...[
        m.title,
        m.summary,
        ...m.attendees,
        for (final t in m.topics) t.title,
        for (final d in m.decisions) d.text,
        for (final a in m.actionItems) '${a.task} ${a.owner ?? ''}',
      ],
    ].join(' '),
  );
  return q.split(' ').every(haystack.contains);
}

/// Meetings of [meetings] matching [query] (order kept).
List<Meeting> filterMeetings(List<Meeting> meetings, String query) =>
    meetings.where((m) => meetingMatchesQuery(m, query)).toList();

/// Ids of the models the current [settings] need that are not installed
/// according to [states] (VAD, speaker model and — for on-device ASR — the
/// chosen Whisper model).
List<String> missingModelIds(
  AppSettingsData settings,
  Map<String, ModelState> states,
) {
  bool ready(String id) => states[id]?.status == ModelStatus.ready;
  return requiredModelIds(
    SessionEngineRequest.fromSettings(settings),
    ready,
  ).where((id) => !ready(id)).toList();
}

/// Model ids the current [settings] need (installed or not).
List<String> neededModelIds(
  AppSettingsData settings,
  Map<String, ModelState> states,
) => requiredModelIds(
  SessionEngineRequest.fromSettings(settings),
  (id) => states[id]?.status == ModelStatus.ready,
);
