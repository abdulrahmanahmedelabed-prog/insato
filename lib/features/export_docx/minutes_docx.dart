// Meeting minutes as a right-to-left Word document (.docx), with the same
// sections and wording as the PDF / Markdown exports of ExportService plus
// the agenda coverage and a signature block.

import 'dart:typed_data';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../minutes/export_service.dart';
import '../../minutes/minutes_prompt.dart';
import 'docx_writer.dart';
import 'strings.dart';

/// Collapses line breaks into single spaces.
String oneLine(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

/// Paragraphs of [text] split at blank lines.
List<String> paragraphsOf(String text) => text
    .trim()
    .split(RegExp(r'\n\s*\n'))
    .map((p) => p.trim())
    .where((p) => p.isNotEmpty)
    .toList();

/// Title of the exported minutes: the minutes' own title, else the meeting's.
String minutesTitle(Meeting meeting, Minutes? minutes) {
  final t = minutes?.title.trim() ?? '';
  return oneLine(t.isEmpty ? meeting.title : t);
}

/// Attendees as in the other exports: the minutes' list, else the named
/// speakers heard in [segments].
List<String> minutesAttendees(
  Minutes minutes,
  Map<String, Speaker> speakersById,
  List<TranscriptSegment> segments,
) {
  if (minutes.attendees.isNotEmpty) {
    return [
      for (final a in minutes.attendees)
        if (oneLine(a).isNotEmpty) oneLine(a),
    ];
  }
  return speakerStats(
    segments,
    speakersById,
  ).where((s) => s.name != kUnknownSpeakerName).map((s) => s.name).toList();
}

/// Duration text, e.g. `01:02:03 (ساعة ودقيقتان)`.
String meetingDurationText(Meeting meeting) => meeting.durationMs > 0
    ? '${formatDuration(meeting.durationMs, alwaysHours: true)} '
          '(${formatDurationWords(meeting.durationMs)})'
    : XS.unknownDuration;

/// Composes the minutes document.
class MinutesDocxComposer {
  /// Creates the composer.
  const MinutesDocxComposer();

  /// Body rows of the action-items table (`#`, task, owner, due).
  static List<List<String>> actionRows(List<ActionItem> items) => [
    for (var i = 0; i < items.length; i++)
      [
        '${i + 1}',
        oneLine(items[i].task),
        _cell(items[i].owner),
        _cell(items[i].dueDate),
      ],
  ];

  static String _cell(String? s) =>
      s == null || s.trim().isEmpty ? XS.emptyCell : oneLine(s);

  /// Fills a [DocxBuilder] with the minutes.
  DocxBuilder compose(
    Meeting meeting,
    Minutes minutes,
    Map<String, Speaker> speakersById, {
    List<TranscriptSegment> segments = const [],
    bool includeTranscript = false,
  }) {
    final d = DocxBuilder(
      footerText: '${XS.docKicker}: ${minutesTitle(meeting, minutes)}',
      pageLabel: XS.page,
      ofLabel: XS.of,
    );
    const w = DocxBuilder.textWidth;

    // Title and metadata.
    d
      ..subtitle(XS.docKicker)
      ..title(minutesTitle(meeting, minutes))
      ..labelValue(XS.date, formatArabicDateTime(meeting.createdAt))
      ..labelValue(XS.duration, meetingDurationText(meeting));
    if (minutes.languagesDetected.isNotEmpty) {
      d.labelValue(XS.languages, minutes.languagesDetected.join('، '));
    }

    // Summary.
    d.heading(XS.summary);
    final summary = paragraphsOf(minutes.summary);
    if (summary.isEmpty) {
      d.note(XS.noSummary);
    } else {
      summary.forEach(d.paragraph);
    }

    // Attendees.
    final attendees = minutesAttendees(minutes, speakersById, segments);
    d.heading(XS.attendees);
    if (attendees.isEmpty) {
      d.note(XS.noAttendees);
    } else {
      d.bullets(attendees);
    }

    // Agenda coverage.
    if (minutes.agendaCoverage.isNotEmpty) {
      d
        ..heading(XS.agenda)
        ..table(
          DocxTable(
            header: const [XS.agendaItem, XS.agendaStatus, XS.agendaNote],
            rows: [
              for (final a in minutes.agendaCoverage)
                [
                  oneLine(a.item),
                  XS.agendaStatusLabel(a.status),
                  _cell(a.note),
                ],
            ],
            columnWidths: const [w * 4 ~/ 10, w * 2 ~/ 10, w * 4 ~/ 10],
          ),
        );
    }

    // Topics.
    if (minutes.topics.isNotEmpty) {
      d.heading(XS.topics);
      for (var i = 0; i < minutes.topics.length; i++) {
        final t = minutes.topics[i];
        d.heading('${i + 1}. ${oneLine(t.title)}', level: 2);
        paragraphsOf(t.discussion).forEach(d.paragraph);
        if (t.speakerNames.isNotEmpty) {
          d.note(XS.topicSpeakers(t.speakerNames.join('، ')));
        }
      }
    }

    // Decisions.
    d.heading(XS.decisions);
    if (minutes.decisions.isEmpty) {
      d.note(XS.noDecisions);
    } else {
      d.numberedRuns([
        for (final dec in minutes.decisions)
          [
            DocxRun(oneLine(dec.text)),
            if (dec.proposedBy != null && dec.proposedBy!.trim().isNotEmpty)
              DocxRun(XS.proposedBy(oneLine(dec.proposedBy!)), color: '5F6B7A'),
          ],
      ]);
    }

    // Action items.
    d.heading(XS.actionItems);
    if (minutes.actionItems.isEmpty) {
      d.note(XS.noActionItems);
    } else {
      d.table(
        DocxTable(
          header: const [XS.colNumber, XS.colTask, XS.colOwner, XS.colDue],
          rows: actionRows(minutes.actionItems),
          columnWidths: const [
            500,
            (w - 500) * 5 ~/ 9,
            (w - 500) * 2 ~/ 9,
            (w - 500) * 2 ~/ 9,
          ],
        ),
      );
    }

    // Open questions, next meeting, notes.
    if (minutes.openQuestions.isNotEmpty) {
      d
        ..heading(XS.openQuestions)
        ..bullets([for (final q in minutes.openQuestions) oneLine(q)]);
    }
    final next = minutes.nextMeeting?.trim() ?? '';
    if (next.isNotEmpty) {
      d
        ..heading(XS.nextMeeting)
        ..paragraph(next);
    }
    final notes = paragraphsOf(minutes.notes ?? '');
    if (notes.isNotEmpty) {
      d.heading(XS.notes);
      notes.forEach(d.paragraph);
    }

    // Signature block.
    final signers = attendees.isEmpty ? const ['', '', ''] : attendees;
    d
      ..heading(XS.signatures)
      ..table(
        DocxTable(
          header: const [XS.sigName, XS.sigSignature, XS.sigDate],
          rows: [
            for (final s in signers) [s, '', ''],
          ],
          columnWidths: const [w * 4 ~/ 10, w * 4 ~/ 10, w * 2 ~/ 10],
          minRowHeight: 680,
        ),
      )
      ..note(
        XS.generatedBy(
          ExportService.appName,
          minutes.model,
          formatArabicDateTime(minutes.generatedAt),
        ),
      );

    // Transcript appendix.
    if (includeTranscript && segments.isNotEmpty) {
      d
        ..pageBreak()
        ..heading(XS.transcriptAppendix);
      for (final block in buildTranscriptBlocks(segments, speakersById)) {
        d.runs([
          DocxRun(
            '[${formatTimestamp(block.startMs)}] ',
            color: '5F6B7A',
            sizeHalfPoints: 18,
          ),
          DocxRun('${block.speakerName}: ', bold: true, sizeHalfPoints: 20),
          DocxRun(block.text, sizeHalfPoints: 20),
        ], align: DocxAlign.justify);
      }
    }
    return d;
  }

  /// The .docx bytes of the minutes.
  Uint8List build(
    Meeting meeting,
    Minutes minutes,
    Map<String, Speaker> speakersById, {
    List<TranscriptSegment> segments = const [],
    bool includeTranscript = false,
    DateTime? created,
  }) {
    final builder = compose(
      meeting,
      minutes,
      speakersById,
      segments: segments,
      includeTranscript: includeTranscript,
    );
    return builder.build(
      DocxMetadata(
        title: XS.shareSubject(minutesTitle(meeting, minutes)),
        subject: formatArabicDateTime(meeting.createdAt),
        creator: ExportService.appName,
        application: ExportService.appName,
        created: created ?? minutes.generatedAt,
      ),
    );
  }
}
