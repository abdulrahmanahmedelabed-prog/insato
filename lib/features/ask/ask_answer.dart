// Answers of "Ask your meetings" (F8): parsing the engine's JSON, and
// turning inline references (`[M3#42]`, `[M3#42، #45]`, `[M3]`) into
// numbered, validated citations that open the meeting at that segment.
//
// References are only kept when the context offered them (or an earlier
// answer of the conversation did): an unknown meeting alias is dropped, and
// a segment that was not shown degrades to a citation of the meeting
// itself, so a link never points at an invented moment.
//
// Pure Dart: unit-tested.

import '../../core/time_format.dart';
import '../../minutes/json_repair.dart';
import 'ask_retrieval.dart' show AskMeetingRef;

/// One citation of an answer.
class AskCitation {
  /// Creates a citation.
  const AskCitation({
    required this.number,
    required this.meetingId,
    required this.alias,
    required this.meetingTitle,
    required this.meetingDate,
    this.segmentIndex,
    this.startMs,
  });

  /// 1-based number in the answer's source list.
  final int number;

  /// Meeting id.
  final String meetingId;

  /// Meeting alias number (`M<alias>`).
  final int alias;

  /// Meeting title.
  final String meetingTitle;

  /// Meeting date.
  final DateTime meetingDate;

  /// `TranscriptSegment.index`, or null for the meeting as a whole.
  final int? segmentIndex;

  /// Start of the segment in the recording.
  final int? startMs;

  /// `hh:mm:ss` of the segment, or null.
  String? get timestamp => startMs == null ? null : formatTimestamp(startMs!);

  /// Display label: `title — hh:mm:ss` (or the title alone).
  String get label =>
      timestamp == null ? meetingTitle : '$meetingTitle — $timestamp';

  @override
  bool operator ==(Object other) =>
      other is AskCitation &&
      other.number == number &&
      other.meetingId == meetingId &&
      other.segmentIndex == segmentIndex &&
      other.startMs == startMs;

  @override
  int get hashCode => Object.hash(number, meetingId, segmentIndex, startMs);

  @override
  String toString() => 'AskCitation($number, $meetingId#$segmentIndex)';
}

/// A run of an answer: text or a citation marker.
sealed class AskAnswerPart {
  const AskAnswerPart();
}

/// Plain answer text.
class AskTextPart extends AskAnswerPart {
  /// Creates a text run.
  const AskTextPart(this.text);

  /// The text.
  final String text;

  @override
  bool operator ==(Object other) => other is AskTextPart && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'AskTextPart($text)';
}

/// A citation marker.
class AskCitationPart extends AskAnswerPart {
  /// Creates a marker.
  const AskCitationPart(this.citation);

  /// The citation.
  final AskCitation citation;

  @override
  bool operator ==(Object other) =>
      other is AskCitationPart && other.citation == citation;

  @override
  int get hashCode => citation.hashCode;

  @override
  String toString() => 'AskCitationPart(${citation.number})';
}

/// An answer with linked citations.
class AskLinkedAnswer {
  /// Creates an answer.
  const AskLinkedAnswer({
    required this.parts,
    required this.sources,
    required this.modelText,
  });

  /// Text and markers, in order.
  final List<AskAnswerPart> parts;

  /// Distinct citations in order of first use (numbers 1..n).
  final List<AskCitation> sources;

  /// The answer as written by the model, with only valid references (kept
  /// for the conversation history).
  final String modelText;

  /// The answer text without markers (copying, accessibility).
  String get plainText =>
      parts.whereType<AskTextPart>().map((p) => p.text).join();
}

/// The engine's answer before linking.
class AskRawAnswer {
  /// Creates an answer.
  const AskRawAnswer({required this.answer, required this.found});

  /// Answer text with inline references.
  final String answer;

  /// False when the engine said the meetings do not contain the answer.
  final bool found;
}

/// Parses the engine output (JSON per `askAnswerSchema`, tolerating noise;
/// a plain-text answer from a local model is accepted as is). Returns null
/// when nothing usable came back.
AskRawAnswer? parseAskEngineOutput(String text) {
  final json = decodeJsonObjectTolerant(text);
  if (json != null) {
    final answer = json['answer'];
    if (answer is! String || answer.trim().isEmpty) return null;
    return AskRawAnswer(
      answer: answer.trim(),
      found: json['answer_found'] != false,
    );
  }
  final t = text.trim();
  if (t.isEmpty || t.startsWith('{') || t.startsWith('[')) return null;
  return AskRawAnswer(answer: t, found: true);
}

final RegExp _group = RegExp(r'\[([^\[\]\n]{1,160})\]');
final RegExp _ref = RegExp(r'[Mm]\s*(\d+)(?:\s*[#:]\s*(\d+))?|#\s*(\d+)');
final RegExp _separators = RegExp(r'^[\s,،;؛\-–—|و&]*$');
final RegExp _spaceBeforePunct = RegExp(r'[ \t]+([.,،؛:!?؟)])');
final RegExp _multiSpace = RegExp(r'[ \t]{2,}');

/// Links the inline references of [answer] against [refs] (alias → what may
/// be cited). See the file comment.
AskLinkedAnswer linkAskAnswer(String answer, Map<int, AskMeetingRef> refs) {
  final text = answer.replaceAll('**', '').replaceAll('__', '');
  final sources = <AskCitation>[];
  final byKey = <String, AskCitation>{};
  final parts = <AskAnswerPart>[];
  final model = StringBuffer();
  final pending = StringBuffer();

  void flush() {
    if (pending.isEmpty) return;
    parts.add(AskTextPart(pending.toString()));
    pending.clear();
  }

  AskCitation cite(AskMeetingRef ref, int? segment) {
    final start = segment == null ? null : ref.segmentStartMs[segment];
    final seg = start == null ? null : segment;
    final key = '${ref.meetingId}#${seg ?? ''}';
    return byKey.putIfAbsent(key, () {
      final c = AskCitation(
        number: sources.length + 1,
        meetingId: ref.meetingId,
        alias: ref.alias,
        meetingTitle: ref.title,
        meetingDate: ref.createdAt,
        segmentIndex: seg,
        startMs: start,
      );
      sources.add(c);
      return c;
    });
  }

  var last = 0;
  for (final g in _group.allMatches(text)) {
    final inner = toWesternDigits(g.group(1)!);
    final matches = _ref.allMatches(inner).toList();
    final hasMeeting = matches.any((m) => m.group(1) != null);
    if (!hasMeeting || !_separators.hasMatch(inner.replaceAll(_ref, ''))) {
      continue; // Not a reference group: plain text.
    }
    pending.write(text.substring(last, g.start));
    model.write(text.substring(last, g.start));
    last = g.end;
    flush();
    AskMeetingRef? current;
    final seen = <AskCitation>{};
    final kept = <String>[];
    for (final m in matches) {
      int? segment;
      if (m.group(1) != null) {
        current = refs[int.parse(m.group(1)!)];
        segment = m.group(2) == null ? null : int.parse(m.group(2)!);
      } else {
        segment = int.parse(m.group(3)!);
      }
      final ref = current;
      if (ref == null) continue;
      final c = cite(ref, segment);
      if (seen.add(c)) {
        parts.add(AskCitationPart(c));
        kept.add(
          c.segmentIndex == null
              ? '[M${c.alias}]'
              : '[M${c.alias}#${c.segmentIndex}]',
        );
      }
    }
    model.write(kept.join());
  }
  pending.write(text.substring(last));
  model.write(text.substring(last));
  flush();

  // Merge text runs split by dropped references, then tidy the spaces left
  // where references were removed or written after a space.
  final merged = <AskAnswerPart>[];
  for (final p in parts) {
    final prev = merged.isEmpty ? null : merged.last;
    if (p is AskTextPart && prev is AskTextPart) {
      merged[merged.length - 1] = AskTextPart(prev.text + p.text);
    } else {
      merged.add(p);
    }
  }
  parts
    ..clear()
    ..addAll(merged);
  final tidy = <AskAnswerPart>[];
  for (var i = 0; i < parts.length; i++) {
    final p = parts[i];
    if (p is AskTextPart) {
      var t = p.text.replaceAll(_multiSpace, ' ');
      if (i + 1 < parts.length && parts[i + 1] is AskCitationPart) {
        t = t.replaceFirst(RegExp(r'[ \t]+$'), '');
      }
      t = t.replaceAllMapped(_spaceBeforePunct, (m) => m.group(1)!);
      if (i == 0) t = t.trimLeft();
      if (i == parts.length - 1) t = t.trimRight();
      if (t.isNotEmpty) tidy.add(AskTextPart(t));
    } else {
      tidy.add(p);
    }
  }
  return AskLinkedAnswer(
    parts: tidy,
    sources: sources,
    modelText: model
        .toString()
        .replaceAll(_multiSpace, ' ')
        .replaceAllMapped(_spaceBeforePunct, (m) => m.group(1)!)
        .trim(),
  );
}
