// The «الرموز والشيفرات» section of exported minutes (F17), as Markdown or
// plain text. Pure; unit-tested in test/features/codes/codes_export_test.dart.

import '../../core/models.dart';
import '../../core/time_format.dart';
import 'codes_logic.dart';
import 'reversed_speech_logic.dart';
import 'strings.dart';

/// Output format of [renderCodesSection].
enum CodesExportFormat {
  /// Markdown (headings, tables, fenced code).
  markdown,

  /// Plain text (indented, no markup).
  text,
}

/// Renders the codes section of a meeting.
///
/// [codes] is the minutes' section (or [GroupedCodes.toMinutesCodes] of the
/// stored findings). [segments] (the meeting transcript) gives evidence
/// timestamps, the reference-number check and the [uncovered]
/// unintelligible segments' durations; [speakersById] names their speakers.
/// [reversed] are reversed-speech hypotheses keyed by segment index.
/// Returns an empty string when there is nothing to report.
String renderCodesSection({
  required MinutesCodes codes,
  List<TranscriptSegment> segments = const [],
  Map<String, Speaker> speakersById = const {},
  List<TranscriptSegment> uncovered = const [],
  Map<int, List<ReversedSpeechResult>> reversed = const {},
  CodesExportFormat format = CodesExportFormat.markdown,
  int headingLevel = 2,
}) {
  if (codes.isEmpty && uncovered.isEmpty) return '';
  final md = format == CodesExportFormat.markdown;
  final b = StringBuffer();
  final level = headingLevel.clamp(1, 5);

  void heading(String title, int lvl) {
    if (md) {
      b.writeln('${'#' * lvl} $title');
    } else {
      b
        ..writeln(title)
        ..writeln((lvl == level ? '=' : '-') * title.runes.length);
    }
    b.writeln();
  }

  String bullet(String text, [int depth = 0]) =>
      md ? '${'  ' * depth}- $text' : '${'  ' * depth}• $text';

  String evidence(List<int> ids) {
    final byIndex = {for (final s in segments) s.index: s};
    final stamps = [
      for (final id in ids)
        byIndex[id] == null
            ? '#$id'
            : '${formatTimestamp(byIndex[id]!.startMs)} (#$id)',
    ];
    return KS.exportEvidence(stamps);
  }

  void reversedLines(List<int> ids, int depth) {
    for (final id in ids) {
      for (final r in reversed[id] ?? const <ReversedSpeechResult>[]) {
        b.writeln(
          bullet(
            '${KS.reversedResultTitle}: «${r.text}» (#${r.segment})',
            depth,
          ),
        );
      }
    }
  }

  heading(KS.exportTitle, level);
  b
    ..writeln(md ? '_${KS.exportCaveat}_' : KS.exportCaveat)
    ..writeln();

  // 1. Coded / unintelligible speech.
  if (codes.codedSpeech.isNotEmpty || uncovered.isNotEmpty) {
    heading(KS.codedSpeechTitle, level + 1);
    for (final c in codes.codedSpeech) {
      final who = c.speaker.isEmpty ? KS.unknownSpeaker : c.speaker;
      b.writeln(
        bullet(
          '${md ? '**$who**' : who} — ${KS.character(c.character)}'
          '${c.description.isEmpty ? '' : ': ${c.description}'}',
        ),
      );
      if (c.hypotheses.isEmpty) {
        b.writeln(bullet(KS.noHypotheses, 1));
      }
      for (final h in c.hypotheses) {
        b.writeln(
          bullet(
            '${KS.hypothesis} (${KS.confidence(h.confidence)}): ${h.meaning}'
            '${h.basis.isEmpty ? '' : ' — ${KS.basis(h.basis)}'}',
            1,
          ),
        );
      }
      reversedLines(c.evidence, 1);
      if (c.evidence.isNotEmpty) b.writeln(bullet(evidence(c.evidence), 1));
    }
    if (uncovered.isNotEmpty) {
      if (codes.codedSpeech.isNotEmpty) b.writeln();
      b.writeln(
        md ? '**${KS.otherUnintelligibleTitle}**' : KS.otherUnintelligibleTitle,
      );
      for (final s in uncovered) {
        final id = s.speakerId;
        final who =
            (id == null ? null : speakersById[id]?.name) ?? KS.unknownSpeaker;
        b.writeln(
          bullet(
            '$who — ${KS.duration(s.endMs - s.startMs)} — '
            '${formatTimestamp(s.startMs)} (#${s.index})',
          ),
        );
        reversedLines([s.index], 1);
      }
    }
    b.writeln();
  }

  // 2. Jargon.
  if (codes.jargon.isNotEmpty) {
    heading(KS.jargonTitle, level + 1);
    for (final j in codes.jargon) {
      b.writeln(
        bullet(
          '${md ? '**${j.term}**' : j.term}: ${j.inferredMeaning} '
          '(${KS.inferred}، ${KS.confidence(j.confidence)})',
        ),
      );
      final first = jargonFirstUseMs(j, segments);
      if (first != null) {
        b.writeln(bullet(KS.firstUse(formatTimestamp(first)), 1));
      }
      if (j.speakers.isNotEmpty) {
        b.writeln(bullet(KS.speakersLine(j.speakers), 1));
      }
      if (j.evidence.isNotEmpty) b.writeln(bullet(evidence(j.evidence), 1));
    }
    b.writeln();
  }

  // 3. Spoken code.
  if (codes.spokenCode.isNotEmpty) {
    heading(KS.spokenCodeTitle, level + 1);
    for (final c in codes.spokenCode) {
      final lang = codeLanguageLabel(c.language) ?? KS.unknownLanguage;
      final who = c.speaker.isEmpty ? KS.unknownSpeaker : c.speaker;
      b.writeln(
        md
            ? '**$lang** — ${KS.speakerLine(who)}'
            : '$lang — ${KS.speakerLine(who)}',
      );
      if (c.explanation.isNotEmpty) b.writeln(c.explanation);
      b.writeln();
      if (md) {
        final fence = _fenceFor(c.code);
        b
          ..writeln('$fence${codeFenceTag(c.language)}')
          ..writeln(c.code.trimRight())
          ..writeln(fence);
      } else {
        for (final line in c.code.trimRight().split('\n')) {
          b.writeln('    $line');
        }
      }
      b.writeln();
      if (c.issues.isNotEmpty) {
        b.writeln('${KS.potentialIssues}:');
        for (final i in c.issues) {
          b.writeln(bullet(i));
        }
      }
      if (c.evidence.isNotEmpty) b.writeln(bullet(evidence(c.evidence)));
      b.writeln();
    }
  }

  // 4. Implied speech.
  if (codes.implied.isNotEmpty) {
    heading(KS.impliedTitle, level + 1);
    for (final i in codes.implied) {
      final who = i.speaker.isEmpty ? KS.unknownSpeaker : i.speaker;
      b.writeln(bullet('${md ? '**$who**' : who}: ${KS.literal(i.literal)}'));
      for (final m in i.possibleMeanings) {
        b.writeln(
          bullet('${KS.hypothesis} (${KS.confidence(i.confidence)}): $m', 1),
        );
      }
      if (i.basis.isNotEmpty) b.writeln(bullet(KS.basis(i.basis), 1));
      if (i.evidence.isNotEmpty) b.writeln(bullet(evidence(i.evidence), 1));
    }
    b.writeln();
  }

  // 5. References.
  if (codes.references.isNotEmpty) {
    heading(KS.referencesTitle, level + 1);
    String check(ReferenceItem r) => switch (verifyReference(r, segments)) {
      ReferenceCheck.verified => KS.verified,
      ReferenceCheck.unverified => KS.unverified,
      ReferenceCheck.noEvidence => KS.noEvidenceToVerify,
    };
    String value(ReferenceItem r) {
      final n = r.normalized.isEmpty ? r.verbatim : r.normalized;
      return r.verbatim.isEmpty || r.verbatim == n
          ? n
          : '$n (${KS.asSaid(r.verbatim)})';
    }

    String stamps(ReferenceItem r) {
      final byIndex = {for (final s in segments) s.index: s};
      return [
        for (final id in r.evidence)
          byIndex[id] == null ? '#$id' : formatTimestamp(byIndex[id]!.startMs),
      ].join('، ');
    }

    if (md) {
      b
        ..writeln(
          '| ${KS.colKind} | ${KS.colValue} | ${KS.colContext} | '
          '${KS.colSpeaker} | ${KS.colCheck} | ${KS.colEvidence} |',
        )
        ..writeln('|---|---|---|---|---|---|');
      for (final r in codes.references) {
        b.writeln(
          '| ${_cell(KS.referenceKind(r.kind))} | ${_cell(value(r))} | '
          '${_cell(r.context)} | ${_cell(r.speaker)} | ${_cell(check(r))} | '
          '${_cell(stamps(r))} |',
        );
      }
    } else {
      for (final r in codes.references) {
        b.writeln(
          bullet(
            '${KS.referenceKind(r.kind)}: ${value(r)}'
            '${r.context.isEmpty ? '' : ' — ${r.context}'}'
            '${r.speaker.isEmpty ? '' : ' — ${r.speaker}'}'
            ' — ${check(r)}',
          ),
        );
        if (r.evidence.isNotEmpty) b.writeln(bullet(evidence(r.evidence), 1));
      }
    }
    b.writeln();
  }
  return '${b.toString().trimRight()}\n';
}

/// [renderCodesSection] from the stored findings of a meeting (with their
/// reversed-speech enrichments) and its transcript. Speaker names follow the
/// voice library ([resolveSpeakerNames]).
String renderCodesSectionFromFindings({
  required List<CodeFinding> findings,
  required List<TranscriptSegment> segments,
  Map<String, Speaker> speakersById = const {},
  CodesExportFormat format = CodesExportFormat.markdown,
  int headingLevel = 2,
}) {
  final grouped = resolveSpeakerNames(
    groupFindings(findings),
    segments,
    speakersById,
  );
  final reversed = <int, List<ReversedSpeechResult>>{};
  for (final e in grouped.codedSpeech) {
    for (final r in readReversedResults(e.finding.payload)) {
      (reversed[r.segment] ??= []).add(r);
    }
  }
  return renderCodesSection(
    codes: grouped.toMinutesCodes(),
    segments: segments,
    speakersById: speakersById,
    uncovered: uncoveredUnintelligible(segments, grouped),
    reversed: reversed,
    format: format,
    headingLevel: headingLevel,
  );
}

String _cell(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('|', '\\|')
    .replaceAll(RegExp(r'\s*\n\s*'), ' ')
    .trim();

/// A code fence longer than any backtick run inside [code].
String _fenceFor(String code) {
  var longest = 0;
  for (final m in RegExp('`+').allMatches(code)) {
    if (m[0]!.length > longest) longest = m[0]!.length;
  }
  return '`' * (longest < 3 ? 3 : longest + 1);
}
