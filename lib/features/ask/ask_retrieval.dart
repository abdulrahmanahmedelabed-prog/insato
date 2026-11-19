// Retrieval and context packing of "Ask your meetings" (F8).
//
// [runAskRetrieval] ranks the corpus with BM25 for the question (and, at a
// lower weight, the previous questions of the conversation, so follow-ups
// such as «ومن المسؤول عنها؟» keep their subject), picks the most relevant
// meetings, and packs within a character budget:
// * a catalogue of meetings (alias, title, date, duration);
// * for each relevant meeting: its agenda, a minutes overview (summary,
//   decisions, action items with their evidence refs) and the matching
//   minutes topics;
// * the best transcript windows, widened by one segment on each side and
//   merged when they touch, rendered as `[M3#42 00:12:31] Speaker: text`.
//
// Meetings are named by short, conversation-stable aliases (`M1`, `M2`, …)
// so that the model can cite `[M3#42]` cheaply; the result maps them back.
//
// Pure Dart: unit-tested and run in an isolate for large corpora.

import 'dart:math' as math;

import '../../core/time_format.dart';
import '../../minutes/minutes_prompt.dart' show formatUnintelligibleMarker;
import 'ask_corpus.dart';
import 'bm25.dart';
import 'search_text.dart';

/// Weight of the previous questions' terms relative to the current one.
const double kAskHistoryQueryWeight = 0.4;

/// Meetings whose score is below this share of the best one are not
/// described in detail.
const double kAskMeetingRelativeThreshold = 0.2;

/// At most this many meetings are described in detail.
const int kAskMaxDetailedMeetings = 6;

/// Share of the budget the meetings catalogue may use.
const double kAskCatalogShare = 0.12;

/// Share of the budget minutes overviews and topics may use.
const double kAskMinutesShare = 0.45;

/// One transcript line is clipped to this many characters.
const int kAskMaxLineChars = 700;

/// Everything [runAskRetrieval] needs (isolate-sendable).
class AskRetrievalJob {
  /// Creates a job.
  const AskRetrievalJob({
    required this.meetings,
    required this.question,
    required this.charBudget,
    this.previousQuestions = const [],
    this.aliases = const {},
    this.windowing = const AskWindowing(),
  });

  /// Every searchable meeting, newest first.
  final List<AskMeetingSource> meetings;

  /// The question.
  final String question;

  /// Earlier questions of the conversation (oldest first).
  final List<String> previousQuestions;

  /// Aliases already used in the conversation (meeting id → number).
  final Map<String, int> aliases;

  /// Maximum characters of the packed context.
  final int charBudget;

  /// Transcript window limits.
  final AskWindowing windowing;

  /// Total transcript characters (to decide whether to use an isolate).
  int get corpusChars {
    var n = 0;
    for (final m in meetings) {
      for (final s in m.segments) {
        n += s.text.length;
      }
    }
    return n;
  }
}

/// What the packed context lets the answer cite in one meeting.
class AskMeetingRef {
  /// Creates a reference.
  const AskMeetingRef({
    required this.meetingId,
    required this.alias,
    required this.title,
    required this.createdAt,
    this.segmentStartMs = const {},
  });

  /// Meeting id.
  final String meetingId;

  /// Alias number (`M<alias>`).
  final int alias;

  /// Title.
  final String title;

  /// Recording date.
  final DateTime createdAt;

  /// Citable segments shown in the context: segment index → start (ms).
  final Map<int, int> segmentStartMs;

  /// Merges the citable segments of [other] (same meeting).
  AskMeetingRef merge(AskMeetingRef other) => AskMeetingRef(
    meetingId: meetingId,
    alias: alias,
    title: other.title,
    createdAt: createdAt,
    segmentStartMs: {...segmentStartMs, ...other.segmentStartMs},
  );
}

/// Result of [runAskRetrieval].
class AskPackedContext {
  /// Creates a result.
  const AskPackedContext({
    required this.text,
    required this.aliases,
    required this.refs,
    required this.hasMatches,
    required this.detailedMeetings,
    required this.excerptLines,
  });

  /// The context block for the prompt.
  final String text;

  /// Every alias assigned so far (previous ones kept), meeting id → number.
  final Map<String, int> aliases;

  /// Citable meetings by alias number.
  final Map<int, AskMeetingRef> refs;

  /// False when no document matched the question (only the most recent
  /// meetings were included as a fallback).
  final bool hasMatches;

  /// Meetings described in detail (ids, in context order).
  final List<String> detailedMeetings;

  /// Transcript lines included.
  final int excerptLines;
}

const Set<String> _recencyTokens = {
  'اخر',
  'الاخر',
  'الاخير',
  'الاخيره',
  'اخير',
  'اخيره',
  'الماضي',
  'الماضيه',
  'السابق',
  'السابقه',
  'امس',
  'بالامس',
  'البارحه',
  'اليوم',
  'موخرا',
  'last',
  'latest',
  'recent',
  'recently',
  'previous',
  'yesterday',
  'today',
};

/// True when [question] asks about the latest / previous meeting(s).
bool mentionsRecency(String question) => RegExp(r'[\p{L}\p{N}]+', unicode: true)
    .allMatches(normalizeSearchText(question))
    .any((m) => _recencyTokens.contains(m.group(0)));

String _clip(String text, int max) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max).trimRight()}…';
}

/// Assigns aliases to [meetings] not in [previous]: oldest meeting first,
/// numbers continuing after the largest one used.
Map<String, int> assignAskAliases(
  List<AskMeetingSource> meetings,
  Map<String, int> previous,
) {
  final out = Map<String, int>.of(previous);
  var next = out.values.fold<int>(0, math.max) + 1;
  final byAge = [...meetings]
    ..sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  for (final m in byAge) {
    if (!out.containsKey(m.id)) out[m.id] = next++;
  }
  return out;
}

/// Retrieves and packs the context of [job.question]. See the file comment.
AskPackedContext runAskRetrieval(AskRetrievalJob job) {
  final meetings = job.meetings;
  final aliases = assignAskAliases(meetings, job.aliases);
  final budget = math.max(job.charBudget, 1000);
  final refs = <int, AskMeetingRef>{};
  final segStarts = <int, Map<int, int>>{}; // meeting position → citable

  String tag(int m) => 'M${aliases[meetings[m].id]}';

  // ---- Ranking -------------------------------------------------------------
  final docs = buildAskDocuments(meetings, windowing: job.windowing);
  final index = Bm25Index([for (final d in docs) d.terms]);
  final query = weightedQuery(analyzeSearchText(job.question));
  for (final q in job.previousQuestions.reversed.take(2)) {
    weightedQuery(
      analyzeSearchText(q),
      weight: kAskHistoryQueryWeight,
      into: query,
    );
  }
  final hits = index.search(query);
  final perMeeting = <int, List<double>>{};
  for (final h in hits) {
    (perMeeting[docs[h.doc].meeting] ??= []).add(h.score);
  }
  final meetingScore = <int, double>{
    for (final e in perMeeting.entries)
      e.key: e.value.take(3).fold<double>(0, (a, b) => a + b),
  };
  final ranked = meetingScore.keys.toList()
    ..sort((a, b) {
      final c = meetingScore[b]!.compareTo(meetingScore[a]!);
      // Ties: newer meeting first (the list is newest first).
      return c != 0 ? c : a.compareTo(b);
    });
  final best = ranked.isEmpty ? 0.0 : meetingScore[ranked.first]!;
  final detailed = <int>[
    for (final m in ranked)
      if (meetingScore[m]! >= best * kAskMeetingRelativeThreshold) m,
  ].take(kAskMaxDetailedMeetings).toList();
  final hasMatches = hits.isNotEmpty;
  final recent = [
    for (var m = 0; m < meetings.length; m++)
      if (meetings[m].hasContent) m,
  ];
  if (!hasMatches) {
    detailed.addAll(recent.take(3));
  } else if (mentionsRecency(job.question) && recent.isNotEmpty) {
    detailed
      ..remove(recent.first)
      ..insert(0, recent.first);
    if (detailed.length > kAskMaxDetailedMeetings) detailed.removeLast();
  }

  // ---- Catalogue -----------------------------------------------------------
  var used = 0;
  final catalog = StringBuffer();
  final catalogBudget = (budget * kAskCatalogShare).floor();
  var listed = 0;
  for (var m = 0; m < meetings.length; m++) {
    final src = meetings[m];
    final line =
        '${tag(m)} | ${_clip(src.title, 80)} | '
        '${formatArabicShortDate(src.createdAt)} ${formatClock(src.createdAt)}'
        ' | ${formatDuration(src.durationMs)}'
        ' | ${src.minutes != null ? 'له محضر' : 'بلا محضر'}\n';
    if (catalog.length + line.length > catalogBudget) break;
    catalog.write(line);
    listed++;
    refs[aliases[src.id]!] = AskMeetingRef(
      meetingId: src.id,
      alias: aliases[src.id]!,
      title: src.title,
      createdAt: src.createdAt,
    );
  }
  final omitted = meetings.length - listed;
  if (omitted > 0) catalog.writeln('… و$omitted اجتماعات أقدم غير مدرجة.');
  used += catalog.length + 64;

  // ---- Minutes overviews ---------------------------------------------------
  final minutesBlocks = <int, StringBuffer>{};
  final minutesBudget = (budget * kAskMinutesShare).floor();
  var minutesUsed = 0;

  final pendingStarts = <int, Map<int, int>>{};

  String evidence(int m, List<int> ids) {
    final src = meetings[m];
    final shown = <String>[];
    for (final id in ids) {
      final pos = src.positionOf(id);
      if (pos < 0) continue;
      (pendingStarts[m] ??= {})[id] = src.segments[pos].startMs;
      shown.add('[${tag(m)}#$id]');
      if (shown.length == 4) break;
    }
    return shown.isEmpty ? '' : ' ${shown.join('')}';
  }

  bool addMinutes(int m, String text) {
    final starts = pendingStarts.remove(m);
    if (text.isEmpty) return true;
    if (minutesUsed + text.length > minutesBudget ||
        used + text.length > budget) {
      return false;
    }
    if (starts != null) (segStarts[m] ??= {}).addAll(starts);
    (minutesBlocks[m] ??= StringBuffer()).write(text);
    minutesUsed += text.length;
    used += text.length;
    return true;
  }

  // Header (title, agenda) of every detailed meeting, then minutes overviews
  // in relevance order, then matched topics.
  final headers = <int, String>{};
  for (final m in detailed) {
    final src = meetings[m];
    final b = StringBuffer()
      ..write('<meeting id="${tag(m)}" title="${_clip(src.title, 80)}" ')
      ..write('date="${formatArabicShortDate(src.createdAt)}">\n');
    if (src.context.agenda.isNotEmpty) {
      b.writeln('جدول الأعمال: ${_clip(src.context.agenda.join('؛ '), 400)}');
    }
    final notes = src.context.contextNotes?.trim() ?? '';
    if (notes.isNotEmpty) b.writeln('ملاحظات سياقية: ${_clip(notes, 300)}');
    headers[m] = b.toString();
    used += headers[m]!.length + 12; // + closing tag
  }
  for (final m in detailed) {
    final minutes = meetings[m].minutes;
    if (minutes == null) continue;
    final b = StringBuffer()..writeln('<minutes>');
    b.writeln('الملخص: ${_clip(minutes.summary, 900)}');
    if (minutes.attendees.isNotEmpty) {
      b.writeln('الحضور: ${_clip(minutes.attendees.join('، '), 200)}');
    }
    if (minutes.decisions.isNotEmpty) {
      b.writeln('القرارات:');
      for (final d in minutes.decisions.take(10)) {
        final by = d.proposedBy == null ? '' : ' (اقترحه: ${d.proposedBy})';
        b.writeln('- ${_clip(d.text, 300)}$by${evidence(m, d.evidence)}');
      }
    }
    if (minutes.actionItems.isNotEmpty) {
      b.writeln('المهام:');
      for (final a in minutes.actionItems.take(10)) {
        final owner = a.owner == null ? '' : ' — المسؤول: ${a.owner}';
        final due = a.dueDate == null ? '' : ' — الموعد: ${a.dueDate}';
        b.writeln(
          '- ${_clip(a.task, 250)}$owner$due${evidence(m, a.evidence)}',
        );
      }
    }
    if (minutes.openQuestions.isNotEmpty) {
      b.writeln(
        'أسئلة مفتوحة: ${_clip(minutes.openQuestions.join('؛ '), 300)}',
      );
    }
    b.writeln('</minutes>');
    if (!addMinutes(m, b.toString())) {
      // Keep at least the summary when the full overview does not fit.
      addMinutes(
        m,
        '<minutes>\nالملخص: ${_clip(minutes.summary, 400)}\n</minutes>\n',
      );
    }
  }
  final topicHits = [
    for (final h in hits)
      if (docs[h.doc].kind == AskDocKind.topic &&
          detailed.contains(docs[h.doc].meeting))
        docs[h.doc],
  ];
  final topicsPerMeeting = <int, int>{};
  for (final d in topicHits) {
    final count = topicsPerMeeting[d.meeting] ?? 0;
    if (count >= 3) continue;
    final t = meetings[d.meeting].minutes!.topics[d.topic];
    final text =
        'موضوع: ${_clip(t.title, 150)}\n${_clip(t.discussion, 1200)}'
        '${evidence(d.meeting, t.evidence)}\n';
    if (addMinutes(d.meeting, text)) topicsPerMeeting[d.meeting] = count + 1;
  }

  // ---- Transcript windows --------------------------------------------------
  final ranges = <int, List<(int, int)>>{};
  final lineCache = <int, Map<int, String>>{};

  String line(int m, int pos) => (lineCache[m] ??= {}).putIfAbsent(pos, () {
    final s = meetings[m].segments[pos];
    final text = s.unintelligible
        ? (s.text.isEmpty
              ? formatUnintelligibleMarker(s.index, s.endMs - s.startMs)
              : '${formatUnintelligibleMarker(s.index, s.endMs - s.startMs)}'
                    ' «${_clip(s.text, 200)}»')
        : _clip(s.text, kAskMaxLineChars);
    return '[${tag(m)}#${s.index} ${formatTimestamp(s.startMs)}] '
        '${s.speakerName}: $text\n';
  });

  bool covered(int m, int pos) =>
      ranges[m]?.any((r) => pos >= r.$1 && pos <= r.$2) ?? false;

  var lines = 0;
  for (final h in hits) {
    if (budget - used < 200) break;
    final d = docs[h.doc];
    if (d.kind != AskDocKind.transcript) continue;
    final m = d.meeting;
    final src = meetings[m];
    final first = math.max(0, d.first - 1);
    final last = math.min(src.segments.length - 1, d.last + 1);
    var cost = 0;
    var fresh = 0;
    for (var p = first; p <= last; p++) {
      if (!covered(m, p)) {
        cost += line(m, p).length;
        fresh++;
      }
    }
    if (fresh == 0) continue;
    final introducing = !headers.containsKey(m);
    final headerCost = introducing
        ? '<meeting id="${tag(m)}" title="${_clip(src.title, 80)}">\n'.length +
              40
        : 0;
    if (used + cost + headerCost + 8 > budget) continue;
    if (introducing) {
      headers[m] =
          '<meeting id="${tag(m)}" title="${_clip(src.title, 80)}" '
          'date="${formatArabicShortDate(src.createdAt)}">\n';
      detailed.add(m);
    }
    used += cost + headerCost + 8;
    lines += fresh;
    final list = (ranges[m] ??= [])..add((first, last));
    list.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final r in list) {
      if (merged.isNotEmpty && r.$1 <= merged.last.$2 + 1) {
        merged[merged.length - 1] = (
          merged.last.$1,
          math.max(merged.last.$2, r.$2),
        );
      } else {
        merged.add(r);
      }
    }
    ranges[m] = merged;
  }

  // ---- Rendering -----------------------------------------------------------
  final out = StringBuffer()
    ..writeln('<meetings_catalog>')
    ..write(catalog)
    ..writeln('</meetings_catalog>');
  for (final m in detailed) {
    out.write(headers[m]);
    final minutes = minutesBlocks[m];
    if (minutes != null) out.write(minutes);
    final rs = ranges[m];
    if (rs != null && rs.isNotEmpty) {
      out.writeln('<transcript_excerpts>');
      for (var i = 0; i < rs.length; i++) {
        if (i > 0) out.writeln('…');
        for (var p = rs[i].$1; p <= rs[i].$2; p++) {
          out.write(line(m, p));
          final s = meetings[m].segments[p];
          (segStarts[m] ??= {})[s.index] = s.startMs;
        }
      }
      out.writeln('</transcript_excerpts>');
    }
    out.writeln('</meeting>');
  }

  for (final e in segStarts.entries) {
    final src = meetings[e.key];
    final alias = aliases[src.id]!;
    final ref = AskMeetingRef(
      meetingId: src.id,
      alias: alias,
      title: src.title,
      createdAt: src.createdAt,
      segmentStartMs: e.value,
    );
    refs[alias] = refs[alias]?.merge(ref) ?? ref;
  }
  for (final m in detailed) {
    final src = meetings[m];
    final alias = aliases[src.id]!;
    refs[alias] ??= AskMeetingRef(
      meetingId: src.id,
      alias: alias,
      title: src.title,
      createdAt: src.createdAt,
    );
  }

  return AskPackedContext(
    text: out.toString(),
    aliases: aliases,
    refs: refs,
    hasMatches: hasMatches,
    detailedMeetings: [for (final m in detailed) meetings[m].id],
    excerptLines: lines,
  );
}
