// Pure logic of the codes tab (F17): grouping stored findings by detector,
// speaker names, unintelligible segments the engine did not cover, and the
// digit check of reference numbers against the transcript. Unit-tested in
// test/features/codes/codes_logic_test.dart.

import '../../core/models.dart';
import 'reversed_speech_logic.dart';

// ---------------------------------------------------------------------------
// Digits
// ---------------------------------------------------------------------------

/// Converts Arabic-Indic (٠–٩) and Eastern Arabic / Persian (۰–۹) digits in
/// [text] to Western digits; everything else is kept.
String normalizeDigits(String text) {
  final b = StringBuffer();
  for (final r in text.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      b.writeCharCode(0x30 + r - 0x06F0);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// Only the digits of [text] (after [normalizeDigits]).
String digitsOf(String text) =>
    normalizeDigits(text).replaceAll(RegExp(r'[^0-9]'), '');

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// Characters that may separate the digit groups of one spoken number
/// (`2024-0042`, `05 / 03`, `1,500.50`, `٢٠٢٤، ٤٢`).
bool _isNumberSeparator(int c) =>
    c == 0x20 || // space
    c == 0x09 ||
    c == 0xA0 || // no-break space
    c == 0x2D || // -
    c == 0x2010 ||
    c == 0x2011 ||
    c == 0x2013 ||
    c == 0x2F || // /
    c == 0x2E || // .
    c == 0x3A || // :
    c == 0x2C || // ,
    c == 0x060C || // Arabic comma
    c == 0x066B || // Arabic decimal separator
    c == 0x066C || // Arabic thousands separator
    c == 0x5F || // _
    c == 0x23 || // #
    c == 0x2B; // +

/// Digit groups of [text], split into "streams": consecutive groups joined
/// only by number separators belong to one stream; any other character
/// (a letter, a word) starts a new stream. `"الفاتورة 2024-0042 بتاريخ 5"`
/// → `[["2024", "0042"], ["5"]]`.
List<List<String>> digitStreams(String text) {
  final s = normalizeDigits(text);
  final streams = <List<String>>[];
  var current = <String>[];
  final group = StringBuffer();
  void endGroup() {
    if (group.isNotEmpty) {
      current.add(group.toString());
      group.clear();
    }
  }

  void endStream() {
    endGroup();
    if (current.isNotEmpty) streams.add(current);
    current = <String>[];
  }

  for (final c in s.codeUnits) {
    if (_isDigit(c)) {
      group.writeCharCode(c);
    } else if (_isNumberSeparator(c)) {
      endGroup();
    } else {
      endStream();
    }
  }
  endStream();
  return streams;
}

/// Outcome of checking a reference number against the transcript.
enum ReferenceCheck {
  /// Its digits appear exactly in the evidence text.
  verified,

  /// They do not (mis-transcribed by the engine, or said in words).
  unverified,

  /// No evidence segment to check against.
  noEvidence,
}

/// Checks that the reference [verbatim] (or, when it has no digits,
/// [normalized]) occurs in [evidenceTexts].
///
/// With digits: the reference's digit string must equal the concatenation
/// of one or more *whole*, consecutive digit groups of one stream of an
/// evidence text (see [digitStreams]) — so `INV-2024/0042` is verified by
/// «الفاتورة 2024 0042» but `42` is not verified by «0042» and `123` is not
/// verified by «12 و3». Without digits (e.g. a product code `ABC-X`), the
/// text itself must occur (case-, space- and dash-insensitive).
ReferenceCheck verifyReferenceText({
  required String verbatim,
  required String normalized,
  required List<String> evidenceTexts,
}) {
  final texts = [
    for (final t in evidenceTexts)
      if (t.trim().isNotEmpty) t,
  ];
  if (texts.isEmpty) return ReferenceCheck.noEvidence;
  var wanted = digitsOf(verbatim);
  if (wanted.isEmpty) wanted = digitsOf(normalized);
  if (wanted.isEmpty) {
    final needle = _looseKey(verbatim.trim().isEmpty ? normalized : verbatim);
    if (needle.isEmpty) return ReferenceCheck.unverified;
    return texts.any((t) => _looseKey(t).contains(needle))
        ? ReferenceCheck.verified
        : ReferenceCheck.unverified;
  }
  for (final t in texts) {
    for (final stream in digitStreams(t)) {
      for (var i = 0; i < stream.length; i++) {
        final b = StringBuffer();
        for (var j = i; j < stream.length; j++) {
          b.write(stream[j]);
          if (b.length > wanted.length) break;
          if (b.length == wanted.length) {
            if (b.toString() == wanted) return ReferenceCheck.verified;
            break;
          }
        }
      }
    }
  }
  return ReferenceCheck.unverified;
}

String _looseKey(String s) =>
    normalizeDigits(s).toLowerCase().replaceAll(RegExp(r'[\s\-‐-―_.]+'), '');

/// [verifyReferenceText] for [item] against the text of its evidence
/// segments in [segments] (matched by `TranscriptSegment.index`).
ReferenceCheck verifyReference(
  ReferenceItem item,
  List<TranscriptSegment> segments,
) {
  final ids = item.evidence.toSet();
  return verifyReferenceText(
    verbatim: item.verbatim,
    normalized: item.normalized,
    evidenceTexts: [
      for (final s in segments)
        if (ids.contains(s.index)) s.text,
    ],
  );
}

// ---------------------------------------------------------------------------
// Findings by detector
// ---------------------------------------------------------------------------

/// A stored finding with its parsed item.
class CodeEntry<T> {
  /// Creates an entry.
  const CodeEntry(this.finding, this.item);

  /// The stored row.
  final CodeFinding finding;

  /// Its payload parsed as the detector's item class.
  final T item;
}

/// The findings of one meeting grouped by detector, in stored order.
class GroupedCodes {
  /// Creates the groups.
  const GroupedCodes({
    this.codedSpeech = const [],
    this.jargon = const [],
    this.spokenCode = const [],
    this.implied = const [],
    this.references = const [],
  });

  /// Detector 1.
  final List<CodeEntry<CodedSpeechItem>> codedSpeech;

  /// Detector 2.
  final List<CodeEntry<JargonItem>> jargon;

  /// Detector 3.
  final List<CodeEntry<SpokenCodeItem>> spokenCode;

  /// Detector 4.
  final List<CodeEntry<ImpliedItem>> implied;

  /// Detector 5.
  final List<CodeEntry<ReferenceItem>> references;

  /// True when there is no finding at all.
  bool get isEmpty =>
      codedSpeech.isEmpty &&
      jargon.isEmpty &&
      spokenCode.isEmpty &&
      implied.isEmpty &&
      references.isEmpty;

  /// The groups as a [MinutesCodes] section (for exports).
  MinutesCodes toMinutesCodes() => MinutesCodes(
    codedSpeech: [for (final e in codedSpeech) e.item],
    jargon: [for (final e in jargon) e.item],
    spokenCode: [for (final e in spokenCode) e.item],
    implied: [for (final e in implied) e.item],
    references: [for (final e in references) e.item],
  );
}

/// Evidence of a finding: the payload's ids, or the row's when the payload
/// has none.
List<int> _evidence(List<int> payload, CodeFinding f) =>
    payload.isNotEmpty ? payload : f.segmentIds;

/// Groups [findings] by detector, parsing each payload. Items whose payload
/// is unusable (no text at all) are skipped.
GroupedCodes groupFindings(List<CodeFinding> findings) {
  final coded = <CodeEntry<CodedSpeechItem>>[];
  final jargon = <CodeEntry<JargonItem>>[];
  final code = <CodeEntry<SpokenCodeItem>>[];
  final implied = <CodeEntry<ImpliedItem>>[];
  final refs = <CodeEntry<ReferenceItem>>[];
  for (final f in findings) {
    final p = f.payload;
    switch (f.kind) {
      case CodeFindingKind.speechCoded:
        final i = CodedSpeechItem.fromJson(p);
        coded.add(
          CodeEntry(
            f,
            CodedSpeechItem(
              speaker: i.speaker,
              character: i.character,
              description: i.description,
              hypotheses: i.hypotheses,
              evidence: _evidence(i.evidence, f),
            ),
          ),
        );
      case CodeFindingKind.jargon:
        final i = JargonItem.fromJson(p);
        if (i.term.isEmpty) continue;
        jargon.add(
          CodeEntry(
            f,
            JargonItem(
              term: i.term,
              inferredMeaning: i.inferredMeaning,
              confidence: i.confidence,
              speakers: i.speakers,
              evidence: _evidence(i.evidence, f),
            ),
          ),
        );
      case CodeFindingKind.spokenCode:
        final i = SpokenCodeItem.fromJson(p);
        if (i.code.trim().isEmpty) continue;
        code.add(
          CodeEntry(
            f,
            SpokenCodeItem(
              language: i.language,
              code: i.code,
              explanation: i.explanation,
              issues: i.issues,
              speaker: i.speaker,
              evidence: _evidence(i.evidence, f),
            ),
          ),
        );
      case CodeFindingKind.implied:
        final i = ImpliedItem.fromJson(p);
        if (i.literal.isEmpty) continue;
        implied.add(
          CodeEntry(
            f,
            ImpliedItem(
              literal: i.literal,
              possibleMeanings: i.possibleMeanings,
              basis: i.basis,
              confidence: i.confidence,
              speaker: i.speaker,
              evidence: _evidence(i.evidence, f),
            ),
          ),
        );
      case CodeFindingKind.reference:
        final i = ReferenceItem.fromJson(p);
        if (i.verbatim.isEmpty && i.normalized.isEmpty) continue;
        refs.add(
          CodeEntry(
            f,
            ReferenceItem(
              kind: i.kind,
              verbatim: i.verbatim,
              normalized: i.normalized,
              context: i.context,
              speaker: i.speaker,
              evidence: _evidence(i.evidence, f),
            ),
          ),
        );
    }
  }
  return GroupedCodes(
    codedSpeech: coded,
    jargon: jargon,
    spokenCode: code,
    implied: implied,
    references: refs,
  );
}

// ---------------------------------------------------------------------------
// Speakers, durations, unintelligible segments
// ---------------------------------------------------------------------------

/// Display name of the speaker of [finding]: the voice-library name of its
/// resolved speaker (follows renames), else [payloadName] as written by the
/// engine, else null.
String? findingSpeakerName(
  CodeFinding finding,
  String payloadName,
  Map<String, Speaker> speakersById,
) {
  final id = finding.speakerId;
  final fromLibrary = id == null ? null : speakersById[id]?.name;
  if (fromLibrary != null && fromLibrary.trim().isNotEmpty) return fromLibrary;
  final n = payloadName.trim();
  return n.isEmpty ? null : n;
}

/// Name of the speaker of [segment], or null.
String? segmentSpeakerName(
  TranscriptSegment segment,
  Map<String, Speaker> speakersById,
) {
  final id = segment.speakerId;
  if (id == null) return null;
  final n = speakersById[id]?.name.trim();
  return n == null || n.isEmpty ? null : n;
}

/// Total duration (ms) of the segments of [segments] cited by [evidence].
int evidenceDurationMs(List<int> evidence, List<TranscriptSegment> segments) {
  final ids = evidence.toSet();
  var total = 0;
  for (final s in segments) {
    if (ids.contains(s.index)) total += (s.endMs - s.startMs).clamp(0, 1 << 40);
  }
  return total;
}

/// Unintelligible segments cited by no coded-speech finding, by time.
List<TranscriptSegment> uncoveredUnintelligible(
  List<TranscriptSegment> segments,
  GroupedCodes codes,
) {
  final covered = <int>{for (final e in codes.codedSpeech) ...e.item.evidence};
  final out = [
    for (final s in segments)
      if (s.isUnintelligible && !covered.contains(s.index)) s,
  ]..sort((a, b) => a.startMs.compareTo(b.startMs));
  return out;
}

/// Low-confidence recogniser guesses of the unintelligible segments cited
/// by [evidence] (shown as guesses, never as the meaning).
List<String> asrGuessesFor(
  List<int> evidence,
  List<TranscriptSegment> segments,
) {
  final ids = evidence.toSet();
  return [
    for (final s in segments)
      if (ids.contains(s.index) &&
          s.isUnintelligible &&
          s.text.trim().isNotEmpty)
        s.text.trim(),
  ];
}

/// Reversed-audio results stored on [entry] (see [readReversedResults]).
List<ReversedSpeechResult> reversedResultsOf(
  CodeEntry<CodedSpeechItem> entry,
) => readReversedResults(entry.finding.payload);

/// True for a coded-speech finding created by the app (not the engine).
bool isAppFinding(CodeFinding f) => f.payload[kFindingOriginKey] == kOriginApp;

// ---------------------------------------------------------------------------
// Spoken code
// ---------------------------------------------------------------------------

const Map<String, String> _languageLabels = {
  'python': 'Python',
  'py': 'Python',
  'sql': 'SQL',
  'bash': 'Bash',
  'sh': 'Shell',
  'shell': 'Shell',
  'zsh': 'Shell',
  'powershell': 'PowerShell',
  'ps1': 'PowerShell',
  'cmd': 'CMD',
  'javascript': 'JavaScript',
  'js': 'JavaScript',
  'typescript': 'TypeScript',
  'ts': 'TypeScript',
  'dart': 'Dart',
  'java': 'Java',
  'kotlin': 'Kotlin',
  'swift': 'Swift',
  'c': 'C',
  'cpp': 'C++',
  'c++': 'C++',
  'csharp': 'C#',
  'c#': 'C#',
  'cs': 'C#',
  'go': 'Go',
  'rust': 'Rust',
  'php': 'PHP',
  'ruby': 'Ruby',
  'html': 'HTML',
  'css': 'CSS',
  'json': 'JSON',
  'yaml': 'YAML',
  'yml': 'YAML',
  'xml': 'XML',
  'regex': 'Regex',
  'url': 'URL',
  'uri': 'URL',
  'text': 'Text',
  'plaintext': 'Text',
};

/// Display label of a spoken-code [language] (`python` → `Python`); an
/// unknown value is shown as given, a blank one as null.
String? codeLanguageLabel(String language) {
  final l = language.trim();
  if (l.isEmpty) return null;
  return _languageLabels[l.toLowerCase()] ?? l;
}

/// Fence tag of a spoken-code [language] for Markdown (`C++` → `cpp`).
String codeFenceTag(String language) {
  final l = language.trim().toLowerCase();
  return switch (l) {
    'c++' => 'cpp',
    'c#' => 'csharp',
    'url' || 'uri' || '' => 'text',
    _ => l.replaceAll(RegExp(r'[^a-z0-9_+-]'), ''),
  };
}
