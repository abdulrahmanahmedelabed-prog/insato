// Exports the minutes as Word (.docx), PDF or Markdown and hands the file to
// the system share sheet with an e-mail subject «محضر اجتماع: …» and a short
// text summary as the body, so mail apps open a ready-to-send message.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../data/repositories.dart';
import '../../minutes/export_service.dart';
import '../../session/providers.dart';
import '../../ui/services/share_gateway.dart' show ShareOutcome;
import '../official/official_document.dart';
import '../official/official_service.dart';
import 'minutes_docx.dart';
import 'strings.dart';

/// File formats offered for the minutes.
enum MinutesExportFormat {
  /// Print-ready PDF (ExportService.toPdf).
  pdf('pdf', 'application/pdf', 'PDF'),

  /// Editable Word document.
  docx(
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'Word',
  ),

  /// Markdown text.
  markdown('md', 'text/markdown', 'Markdown');

  const MinutesExportFormat(this.extension, this.mimeType, this.displayName);

  /// File extension without the dot.
  final String extension;

  /// MIME type of the file.
  final String mimeType;

  /// Name shown to the user.
  final String displayName;
}

/// Everything an export needs, read fresh from the repositories.
class MinutesExportData {
  /// Creates the data.
  const MinutesExportData({
    required this.meeting,
    required this.segments,
    required this.speakersById,
    this.official,
    this.templateBytes,
  });

  /// The meeting (with its minutes, if any).
  final Meeting meeting;

  /// Transcript segments.
  final List<TranscriptSegment> segments;

  /// All speakers by id.
  final Map<String, Speaker> speakersById;

  /// v1.2: the official minutes when the meeting uses an official template.
  final OfficialDocument? official;

  /// v1.2: the uploaded Word template of the meeting, if any.
  final Uint8List? templateBytes;
}

/// Writes exported minutes to the export folder and shares them.
///
/// Files are placed exactly like `DefaultShareGateway` does: on Android / iOS
/// in the short-lived share folder and deleted when the share sheet returns;
/// on desktop in the exports folder, where the copy is kept and its path
/// reported.
class DocxExportService {
  /// Creates the service. [isMobile] defaults to the current platform and
  /// [share] to share_plus; [now] stamps the document properties.
  DocxExportService({
    required this._export,
    required this._exportsDir,
    required this._shareTempDir,
    bool? isMobile,
    Future<void> Function(ShareParams params)? share,
    DateTime Function()? now,
  }) : _isMobile = isMobile ?? (Platform.isAndroid || Platform.isIOS),
       _share = share ?? _sharePlus,
       _now = now ?? DateTime.now;

  final ExportService _export;
  final Future<String> Function() _exportsDir;
  final Future<String> Function() _shareTempDir;
  final bool _isMobile;
  final Future<void> Function(ShareParams params) _share;
  final DateTime Function() _now;

  static Future<void> _sharePlus(ShareParams params) async {
    await SharePlus.instance.share(params);
  }

  /// Longest summary excerpt put into the share body.
  static const int maxSummaryChars = 600;

  /// The .docx bytes of the minutes.
  Uint8List buildDocx(
    Meeting meeting,
    Minutes minutes,
    Map<String, Speaker> speakersById, {
    List<TranscriptSegment> segments = const [],
    bool includeTranscript = false,
    OfficialDocument? official,
    Uint8List? templateBytes,
  }) => official != null
      ? const MinutesDocxComposer().buildOfficial(
          official,
          minutes,
          speakersById,
          segments: segments,
          includeTranscript: includeTranscript,
          created: _now(),
          templateBytes: templateBytes,
        )
      : const MinutesDocxComposer().build(
          meeting,
          minutes,
          speakersById,
          segments: segments,
          includeTranscript: includeTranscript,
          created: _now(),
        );

  /// The bytes of the minutes in [format]. PDF and Markdown come from
  /// [ExportService] unchanged.
  Future<Uint8List> buildBytes(
    MinutesExportFormat format,
    Meeting meeting,
    Minutes minutes,
    Map<String, Speaker> speakersById, {
    List<TranscriptSegment> segments = const [],
    bool includeTranscript = false,
    OfficialDocument? official,
    Uint8List? templateBytes,
  }) async => switch (format) {
    MinutesExportFormat.pdf => await _export.toPdf(
      meeting,
      minutes,
      speakersById,
      segments: segments,
      includeTranscript: includeTranscript,
      official: official,
    ),
    MinutesExportFormat.docx => buildDocx(
      meeting,
      minutes,
      speakersById,
      segments: segments,
      includeTranscript: includeTranscript,
      official: official,
      templateBytes: templateBytes,
    ),
    MinutesExportFormat.markdown => utf8.encode(
      _export.toMarkdown(
        meeting,
        minutes,
        speakersById,
        segments: segments,
        includeTranscript: includeTranscript,
        official: official,
      ),
    ),
  };

  /// E-mail subject: «محضر اجتماع: <title>».
  static String shareSubject(Meeting meeting, Minutes? minutes) =>
      XS.shareSubject(minutesTitle(meeting, minutes));

  /// A short plain-text body: title, date, duration, a summary excerpt, the
  /// number of decisions and tasks, and which file is attached.
  static String shareBody(
    Meeting meeting,
    Minutes minutes, {
    MinutesExportFormat? format,
  }) {
    final b = StringBuffer()
      ..writeln(shareSubject(meeting, minutes))
      ..writeln('${XS.date}: ${formatArabicDateTime(meeting.createdAt)}')
      ..writeln('${XS.duration}: ${meetingDurationText(meeting)}')
      ..writeln();
    final summary = oneLine(minutes.summary);
    if (summary.isNotEmpty) {
      b
        ..writeln(_excerpt(summary, maxSummaryChars))
        ..writeln();
    }
    b.writeln(XS.counts(minutes.decisions.length, minutes.actionItems.length));
    if (format != null) b.writeln(XS.attachedAs(format.displayName));
    b
      ..writeln()
      ..write(XS.sentFrom);
    return b.toString();
  }

  static String _excerpt(String s, int max) {
    final runes = s.runes.toList();
    if (runes.length <= max) return s;
    var cut = String.fromCharCodes(runes.take(max));
    final space = cut.lastIndexOf(' ');
    if (space > max * 0.6) cut = cut.substring(0, space);
    return '${cut.trimRight()}…';
  }

  /// Builds the minutes in [format], writes the file and opens the share
  /// sheet with [shareSubject] and [shareBody].
  Future<ShareOutcome> shareMinutes({
    required MinutesExportFormat format,
    required Meeting meeting,
    required Minutes minutes,
    required Map<String, Speaker> speakersById,
    List<TranscriptSegment> segments = const [],
    bool includeTranscript = false,
    Rect? origin,
    OfficialDocument? official,
    Uint8List? templateBytes,
  }) async {
    final bytes = await buildBytes(
      format,
      meeting,
      minutes,
      speakersById,
      segments: segments,
      includeTranscript: includeTranscript,
      official: official,
      templateBytes: templateBytes,
    );
    return shareFile(
      bytes: bytes,
      fileName: ExportService.suggestedFileName(meeting, format.extension),
      mimeType: format.mimeType,
      subject: shareSubject(meeting, minutes),
      body: shareBody(meeting, minutes, format: format),
      origin: origin,
    );
  }

  /// Writes [bytes] as [fileName] and shares it with [subject] and [body].
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String subject,
    required String body,
    Rect? origin,
  }) async {
    final dir = _isMobile ? await _shareTempDir() : await _exportsDir();
    await Directory(dir).create(recursive: true);
    final path = p.join(dir, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    try {
      await _share(
        ShareParams(
          files: [XFile(path, mimeType: mimeType, name: fileName)],
          subject: subject,
          title: subject,
          text: body,
          sharePositionOrigin: origin,
        ),
      );
      return ShareOutcome(shared: true, savedPath: _isMobile ? null : path);
    } catch (_) {
      // No share target: desktop keeps the saved copy; a hidden app-private
      // path means nothing to a mobile user.
      return ShareOutcome(shared: false, savedPath: _isMobile ? null : path);
    } finally {
      if (_isMobile) {
        try {
          await File(path).delete();
        } catch (_) {
          // Best effort; the share gateway purges the folder later.
        }
      }
    }
  }
}

/// Loads a meeting with its transcript and speakers, or null when the
/// meeting no longer exists.
Future<MinutesExportData?> loadMinutesExportData({
  required MeetingRepository meetings,
  required SegmentRepository segments,
  required SpeakerRepository speakers,
  required String meetingId,
  OfficialMinutesService? official,
}) async {
  final meeting = await meetings.get(meetingId);
  if (meeting == null) return null;
  final doc = await official?.documentForExport(meeting);
  final custom = doc?.customTemplate;
  return MinutesExportData(
    meeting: meeting,
    segments: await segments.getForMeeting(meetingId),
    speakersById: await speakers.getAllById(),
    official: doc,
    templateBytes: custom == null
        ? null
        : await official!.templateBytes(custom),
  );
}

/// The Word export & share service.
final docxExportServiceProvider = Provider<DocxExportService>((ref) {
  final paths = ref.watch(appPathsProvider);
  return DocxExportService(
    export: ref.watch(exportServiceProvider),
    exportsDir: paths.exportsDir,
    shareTempDir: paths.shareTempDir,
  );
});
