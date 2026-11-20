// Export & share sheet for the minutes (F12): PDF / Word / Markdown, each
// handed to the system share sheet with the e-mail subject
// «محضر اجتماع: …» and a short summary body, plus printing the PDF.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../session/providers.dart';
import '../../ui/services/share_gateway.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../official/official_service.dart'
    show officialMinutesServiceProvider;
import 'docx_export_service.dart';
import 'strings.dart';

/// Opens [ExportShareSheet] for [meetingId] as a modal bottom sheet.
Future<void> showExportShareSheet(BuildContext context, String meetingId) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ExportShareSheet(meetingId: meetingId),
    );

/// Icon button that opens [ExportShareSheet] (for an app bar or the minutes
/// tab header). Disabled while [enabled] is false (no minutes yet).
class ExportShareButton extends StatelessWidget {
  /// Creates the button.
  const ExportShareButton({
    super.key,
    required this.meetingId,
    this.enabled = true,
  });

  /// Meeting exported.
  final String meetingId;

  /// False disables the button.
  final bool enabled;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: XS.openSheet,
    icon: const Icon(Icons.ios_share_rounded),
    onPressed: enabled ? () => showExportShareSheet(context, meetingId) : null,
  );
}

enum _Action { pdf, docx, markdown, print }

/// Sheet offering the minutes of [meetingId] as PDF, Word or Markdown via
/// the share sheet (mail apps included), optionally with the transcript.
class ExportShareSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ExportShareSheet({super.key, required this.meetingId});

  /// Meeting exported.
  final String meetingId;

  @override
  ConsumerState<ExportShareSheet> createState() => _ExportShareSheetState();
}

class _ExportShareSheetState extends ConsumerState<ExportShareSheet> {
  bool _withTranscript = false;
  _Action? _busy;

  Future<void> _run(_Action action, Rect? origin) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    String? message;
    var isError = false;
    try {
      final data = await loadMinutesExportData(
        meetings: ref.read(meetingRepositoryProvider),
        segments: ref.read(segmentRepositoryProvider),
        speakers: ref.read(speakerRepositoryProvider),
        meetingId: widget.meetingId,
        official: ref.read(officialMinutesServiceProvider),
      );
      if (data == null) throw const InsatoException(S.meetingNotFound);
      final minutes = data.meeting.minutes;
      if (minutes == null) throw const InsatoException(S.noMinutesToExport);
      final service = ref.read(docxExportServiceProvider);
      if (action == _Action.print) {
        final export = ref.read(exportServiceProvider);
        await ref
            .read(shareGatewayProvider)
            .printPdf(
              build: () => export.toPdf(
                data.meeting,
                minutes,
                data.speakersById,
                segments: data.segments,
                includeTranscript: _withTranscript,
                official: data.official,
              ),
              name: DocxExportService.shareSubject(data.meeting, minutes),
            );
      } else {
        final format = switch (action) {
          _Action.pdf => MinutesExportFormat.pdf,
          _Action.docx => MinutesExportFormat.docx,
          _ => MinutesExportFormat.markdown,
        };
        final r = await service.shareMinutes(
          format: format,
          meeting: data.meeting,
          minutes: minutes,
          speakersById: data.speakersById,
          segments: data.segments,
          includeTranscript: _withTranscript,
          origin: origin,
          official: data.official,
          templateBytes: data.templateBytes,
        );
        if (r.savedPath != null) {
          message = S.savedTo(r.savedPath!);
        } else if (!r.shared) {
          isError = true;
          message = S.exportFailed;
        }
      }
    } catch (e) {
      isError = true;
      message = e is InsatoException ? e.messageAr : S.exportFailed;
    }
    if (!mounted) return;
    setState(() => _busy = null);
    await nav.maybePop();
    if (message != null && messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: isError ? 6 : 4),
        ),
      );
    }
  }

  Widget _tile({
    required _Action action,
    required IconData icon,
    required String title,
    String? subtitle,
  }) => Builder(
    builder: (context) => ListTile(
      enabled: _busy == null,
      minTileHeight: 56,
      leading: _busy == action
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () => _run(action, shareOriginOf(context)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    header: true,
                    child: Text(
                      XS.sheetTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    XS.sheetHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _withTranscript,
                  onChanged: _busy != null
                      ? null
                      : (v) => setState(() => _withTranscript = v),
                  title: const Text(S.includeTranscript),
                ),
                if (_busy != null)
                  Semantics(
                    liveRegion: true,
                    label: XS.preparing,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: LinearProgressIndicator(),
                    ),
                  ),
                _tile(
                  action: _Action.docx,
                  icon: Icons.description_rounded,
                  title: XS.shareDocx,
                  subtitle: XS.shareDocxHint,
                ),
                _tile(
                  action: _Action.pdf,
                  icon: Icons.picture_as_pdf_rounded,
                  title: XS.sharePdf,
                  subtitle: XS.sharePdfHint,
                ),
                _tile(
                  action: _Action.markdown,
                  icon: Icons.text_snippet_rounded,
                  title: XS.shareMarkdown,
                  subtitle: XS.shareMarkdownHint,
                ),
                _tile(
                  action: _Action.print,
                  icon: Icons.print_rounded,
                  title: XS.printPdf,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
