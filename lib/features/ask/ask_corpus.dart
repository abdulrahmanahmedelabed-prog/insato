// The searchable corpus of "Ask your meetings" (F8): a light, isolate-
// sendable copy of every meeting (title, date, context, minutes, transcript
// with speaker names) and its split into BM25 documents — overlapping
// transcript windows plus the minutes' summary, topics, decisions, action
// items and open questions, and a header (title, date, agenda, attendees).
//
// Pure Dart: unit-tested and usable inside an isolate.

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../minutes/minutes_prompt.dart' show kUnknownSpeakerName;
import 'search_text.dart';

/// One transcript segment as the ask feature needs it.
class AskSegment {
  /// Creates a segment.
  const AskSegment({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.speakerName,
    this.unintelligible = false,
  });

  /// `TranscriptSegment.index` (the id citations use).
  final int index;

  /// Start in the recording.
  final int startMs;

  /// End in the recording.
  final int endMs;

  /// Recognised text (for an unintelligible segment, the recogniser's guess
  /// or empty).
  final String text;

  /// Speaker label.
  final String speakerName;

  /// True for a segment kept as «كلام غير مفهوم».
  final bool unintelligible;
}

/// One meeting as the ask feature needs it.
class AskMeetingSource {
  /// Creates a source.
  const AskMeetingSource({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.durationMs,
    required this.segments,
    this.context = MeetingContext.empty,
    this.minutes,
  });

  /// Copies [meeting] with its [segments] (content only, in index order) and
  /// speaker names from [speakersById].
  factory AskMeetingSource.from(
    Meeting meeting,
    List<TranscriptSegment> segments,
    Map<String, Speaker> speakersById,
  ) {
    final kept = [
      for (final s in segments)
        if (s.hasContent) s,
    ]..sort((a, b) => a.index.compareTo(b.index));
    return AskMeetingSource(
      id: meeting.id,
      title: meeting.title,
      createdAt: meeting.createdAt,
      durationMs: meeting.durationMs,
      context: meeting.context,
      minutes: meeting.minutes,
      segments: [
        for (final s in kept)
          AskSegment(
            index: s.index,
            startMs: s.startMs,
            endMs: s.endMs,
            text: s.text.trim(),
            speakerName: _speakerName(speakersById[s.speakerId]),
            unintelligible: s.isUnintelligible,
          ),
      ],
    );
  }

  /// Meeting id.
  final String id;

  /// Title.
  final String title;

  /// Recording date.
  final DateTime createdAt;

  /// Duration.
  final int durationMs;

  /// Transcript segments with content, in index order.
  final List<AskSegment> segments;

  /// Agenda, expected attendees, notes.
  final MeetingContext context;

  /// Generated minutes, if any.
  final Minutes? minutes;

  /// True when there is anything to search.
  bool get hasContent => segments.isNotEmpty || minutes != null;

  /// Position (in [segments]) of the segment with `index == segmentIndex`,
  /// or -1.
  int positionOf(int segmentIndex) {
    var lo = 0;
    var hi = segments.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final v = segments[mid].index;
      if (v == segmentIndex) return mid;
      if (v < segmentIndex) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -1;
  }
}

String _speakerName(Speaker? s) {
  final name = s?.name.trim() ?? '';
  return name.isEmpty ? kUnknownSpeakerName : name;
}

/// Kinds of searchable documents.
enum AskDocKind {
  /// Title, date, agenda, expected attendees, context notes.
  header,

  /// Minutes title, summary, attendees, notes, next meeting.
  summary,

  /// One minutes topic.
  topic,

  /// All decisions of the minutes.
  decisions,

  /// All action items of the minutes.
  actions,

  /// Open questions and agenda coverage of the minutes.
  openQuestions,

  /// A window of consecutive transcript segments.
  transcript,
}

/// One searchable document.
class AskDocument {
  /// Creates a document.
  const AskDocument({
    required this.meeting,
    required this.kind,
    required this.terms,
    this.first = 0,
    this.last = -1,
    this.topic = -1,
  });

  /// Index of the meeting in the source list.
  final int meeting;

  /// Kind.
  final AskDocKind kind;

  /// Analysed terms.
  final List<String> terms;

  /// First / last position in the meeting's segments ([AskDocKind.transcript]).
  final int first;

  /// See [first].
  final int last;

  /// Topic index ([AskDocKind.topic]).
  final int topic;
}

/// Window size limits of transcript documents.
class AskWindowing {
  /// Creates limits.
  const AskWindowing({this.maxSegments = 6, this.maxChars = 600});

  /// Maximum segments per window.
  final int maxSegments;

  /// A window stops growing once its text reaches this many characters.
  final int maxChars;
}

/// Splits [segments] into overlapping windows (inclusive position ranges):
/// each window grows until [AskWindowing.maxSegments] segments or
/// [AskWindowing.maxChars] characters, and the next one starts half-way
/// through it, so every passage appears whole in at least one window.
List<(int, int)> transcriptWindows(
  List<AskSegment> segments, {
  AskWindowing windowing = const AskWindowing(),
}) {
  final out = <(int, int)>[];
  var start = 0;
  while (start < segments.length) {
    var end = start;
    var chars = segments[start].text.length;
    while (end + 1 < segments.length &&
        end - start + 1 < windowing.maxSegments &&
        chars < windowing.maxChars) {
      end++;
      chars += segments[end].text.length;
    }
    out.add((start, end));
    if (end == segments.length - 1) break;
    final span = end - start + 1;
    start += span <= 1 ? 1 : span ~/ 2;
  }
  return out;
}

/// Builds the BM25 documents of [meetings].
List<AskDocument> buildAskDocuments(
  List<AskMeetingSource> meetings, {
  AskWindowing windowing = const AskWindowing(),
}) {
  final docs = <AskDocument>[];
  void add(int m, AskDocKind kind, String text, {int topic = -1}) {
    final terms = analyzeSearchText(text);
    if (terms.isEmpty) return;
    docs.add(AskDocument(meeting: m, kind: kind, terms: terms, topic: topic));
  }

  for (var m = 0; m < meetings.length; m++) {
    final src = meetings[m];
    final ctx = src.context;
    add(
      m,
      AskDocKind.header,
      [
        src.title,
        formatArabicDate(src.createdAt),
        ...ctx.agenda,
        ...ctx.expectedAttendees,
        ctx.contextNotes ?? '',
      ].join('\n'),
    );
    final minutes = src.minutes;
    if (minutes != null) {
      add(
        m,
        AskDocKind.summary,
        [
          minutes.title,
          minutes.summary,
          ...minutes.attendees,
          minutes.notes ?? '',
          minutes.nextMeeting ?? '',
        ].join('\n'),
      );
      for (var i = 0; i < minutes.topics.length; i++) {
        final t = minutes.topics[i];
        add(
          m,
          AskDocKind.topic,
          [t.title, t.discussion, ...t.speakerNames].join('\n'),
          topic: i,
        );
      }
      add(m, AskDocKind.decisions, [
        for (final d in minutes.decisions) '${d.text} ${d.proposedBy ?? ''}',
      ].join('\n'));
      add(m, AskDocKind.actions, [
        for (final a in minutes.actionItems)
          '${a.task} ${a.owner ?? ''} ${a.dueDate ?? ''}',
      ].join('\n'));
      add(m, AskDocKind.openQuestions, [
        ...minutes.openQuestions,
        for (final a in minutes.agendaCoverage) '${a.item} ${a.note ?? ''}',
      ].join('\n'));
    }
    for (final (first, last) in transcriptWindows(
      src.segments,
      windowing: windowing,
    )) {
      final buffer = StringBuffer();
      for (var i = first; i <= last; i++) {
        final s = src.segments[i];
        buffer
          ..write(s.speakerName)
          ..write(' ')
          ..writeln(s.text);
      }
      final terms = analyzeSearchText(buffer.toString());
      if (terms.isEmpty) continue;
      docs.add(
        AskDocument(
          meeting: m,
          kind: AskDocKind.transcript,
          terms: terms,
          first: first,
          last: last,
        ),
      );
    }
  }
  return docs;
}
