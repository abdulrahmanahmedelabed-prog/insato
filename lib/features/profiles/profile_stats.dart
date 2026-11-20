// Deterministic per-meeting statistics of one speaker (F16), computed from
// the transcript only: talk time and share, turns, questions, languages and
// code switching, overlaps (interruptions).
//
// Pure Dart.

import '../../core/models.dart';
import 'profile_model.dart';

/// Minimum overlap for a segment start to count as an interruption: the
/// speaker starts at least this long before the previous speaker's segment
/// ends.
const int kInterruptionOverlapMs = 500;

final RegExp _questionMarks = RegExp('[?؟]+');

/// Number of questions in [text]: runs of `?` / `؟` (Arabic and Latin), so
/// «لماذا؟؟» counts once.
int countQuestions(String text) => _questionMarks.allMatches(text).length;

/// Primary language subtag of [code] (`en-US` → `en`), or null when blank.
String? normalizeLanguageCode(String? code) {
  if (code == null) return null;
  final c = code.trim().toLowerCase().split(RegExp('[-_]')).first;
  return c.isEmpty ? null : c;
}

int _duration(TranscriptSegment s) {
  final d = s.endMs - s.startMs;
  return d < 0 ? 0 : d;
}

/// Statistics of [speakerId] in [meeting] from its [segments] (any order),
/// with [decisions] the meeting's minutes attribute to the speaker. Null
/// when the speaker has no content segment in the meeting.
MeetingSpeakerStats? computeMeetingSpeakerStats({
  required Meeting meeting,
  required List<TranscriptSegment> segments,
  required String speakerId,
  List<ProfileDecision> decisions = const [],
}) {
  final sorted = segments.where((s) => s.hasContent).toList()
    ..sort((a, b) {
      final c = a.startMs.compareTo(b.startMs);
      return c != 0 ? c : a.index.compareTo(b.index);
    });
  if (!sorted.any((s) => s.speakerId == speakerId)) return null;

  var meetingSpeech = 0;
  var speaking = 0, count = 0, speech = 0, turns = 0;
  var questions = 0, questionSegments = 0;
  var transitions = 0, switches = 0, mixedTurns = 0;
  var given = 0, received = 0;
  final langMs = <String, int>{};

  String? lastLang; // last known language of the speaker in this meeting
  Set<String> turnLangs = {};
  var inTurn = false;
  TranscriptSegment? prev;

  void closeTurn() {
    if (inTurn && turnLangs.length >= 2) mixedTurns++;
    inTurn = false;
    turnLangs = {};
  }

  for (final s in sorted) {
    final d = _duration(s);
    meetingSpeech += d;
    final mine = s.speakerId == speakerId;
    if (prev != null &&
        prev.speakerId != s.speakerId &&
        prev.endMs - s.startMs >= kInterruptionOverlapMs) {
      if (mine) given++;
      if (prev.speakerId == speakerId) received++;
    }
    if (!mine) {
      closeTurn();
      prev = s;
      continue;
    }
    if (!inTurn) {
      inTurn = true;
      turns++;
    }
    count++;
    speaking += d;
    if (!s.isUnintelligible && s.text.trim().isNotEmpty) {
      speech++;
      final q = countQuestions(s.text);
      questions += q;
      if (q > 0) questionSegments++;
      final lang = normalizeLanguageCode(s.language);
      if (lang != null) {
        langMs[lang] = (langMs[lang] ?? 0) + d;
        turnLangs.add(lang);
        if (lastLang != null) {
          transitions++;
          if (lastLang != lang) switches++;
        }
        lastLang = lang;
      }
    }
    prev = s;
  }
  closeTurn();

  return MeetingSpeakerStats(
    meetingId: meeting.id,
    meetingTitle: meeting.title,
    meetingAt: meeting.createdAt,
    speakingMs: speaking,
    meetingSpeechMs: meetingSpeech,
    segments: count,
    speechSegments: speech,
    turns: turns,
    questions: questions,
    questionSegments: questionSegments,
    languageMs: langMs,
    languageTransitions: transitions,
    languageSwitches: switches,
    mixedTurns: mixedTurns,
    interruptionsGiven: given,
    interruptionsReceived: received,
    decisions: decisions,
  );
}
