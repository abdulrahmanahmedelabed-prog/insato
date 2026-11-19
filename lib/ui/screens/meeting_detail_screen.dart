// Meeting details: tabs for the minutes, the full transcript and the
// speakers, plus share / export / print / copy, rename, re-process and
// delete actions and the progress of background jobs.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/models.dart';
import '../../minutes/export_service.dart';
import '../../session/post_processor.dart';
import '../../session/providers.dart';
import '../actions.dart';
import '../navigation.dart';
import '../services/share_gateway.dart';
import '../strings_ar.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'meeting_minutes_tab.dart';
import 'meeting_speakers_tab.dart';
import 'meeting_transcript_tab.dart';

/// Details of one meeting. With [embedded] (wide two-pane layout) the page
/// has no back button.
class MeetingDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    this.embedded = false,
  });

  /// Meeting shown.
  final String meetingId;

  /// True inside the wide layout's detail pane.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(meetingProvider(meetingId));
    return meetingAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: !embedded),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: !embedded),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: S.unexpectedError,
            onRetry: () => ref.invalidate(meetingProvider(meetingId)),
          ),
        ),
      ),
      data: (meeting) {
        if (meeting == null) {
          return Scaffold(
            appBar: AppBar(automaticallyImplyLeading: !embedded),
            body: const EmptyState(
              icon: Icons.event_busy_rounded,
              title: S.meetingNotFound,
            ),
          );
        }
        return _MeetingDetail(meeting: meeting, embedded: embedded);
      },
    );
  }
}

class _MeetingDetail extends ConsumerWidget {
  const _MeetingDetail({required this.meeting, required this.embedded});

  final Meeting meeting;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(meetingJobsProvider(meeting.id));
    final session = ref.watch(meetingSessionControllerProvider);
    final isLive = session.isActive && session.meetingId == meeting.id;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !embedded,
          title: Text(meeting.title, overflow: TextOverflow.ellipsis),
          actions: [
            if (!isLive) ...[
              IconButton(
                tooltip: S.shareText,
                icon: const Icon(Icons.share_rounded),
                onPressed: () => _shareText(context, ref),
              ),
              _MoreMenu(meeting: meeting, jobRunning: job.isRunning),
            ],
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  tabs: [
                    Tab(
                      icon: Icon(Icons.description_outlined, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      text: S.tabMinutes,
                    ),
                    Tab(
                      icon: Icon(Icons.notes_rounded, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      text: S.tabTranscript,
                    ),
                    Tab(
                      icon: Icon(Icons.groups_outlined, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      text: S.tabSpeakers,
                    ),
                  ],
                ),
                SizedBox(
                  height: 4,
                  child: job.isRunning
                      ? LinearProgressIndicator(
                          value: job.progress > 0 ? job.progress : null,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            if (isLive)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ErrorBanner(
                  severity: BannerSeverity.info,
                  message: S.meetingStillRecording,
                  retryLabel: S.backToRecording,
                  onRetry: () => openRecordingScreen(context),
                ),
              ),
            if (job.isRunning && job.kind != MeetingJobKind.minutes)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ErrorBanner(
                  severity: BannerSeverity.info,
                  message: job.statusAr ?? S.loading,
                ),
              ),
            if (!job.isRunning &&
                job.kind != MeetingJobKind.minutes &&
                (job.errorAr != null || job.noticeAr != null))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ErrorBanner(
                  severity: job.errorAr != null
                      ? BannerSeverity.error
                      : BannerSeverity.info,
                  message: job.errorAr ?? job.noticeAr!,
                  onDismiss: () => ref
                      .read(meetingJobsProvider(meeting.id).notifier)
                      .clear(),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  MeetingMinutesTab(meeting: meeting),
                  MeetingTranscriptTab(meetingId: meeting.id),
                  MeetingSpeakersTab(meetingId: meeting.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareText(BuildContext context, WidgetRef ref) async {
    final origin = shareOriginOf(context);
    try {
      final data = await _ExportData.load(ref, meeting.id);
      final export = ref.read(exportServiceProvider);
      final m = data.meeting.minutes;
      final text = m != null
          ? export.toPlainText(data.meeting, m, data.speakersById)
          : export.fullTranscriptText(
              data.meeting,
              data.segments,
              data.speakersById,
            );
      final r = await ref
          .read(shareGatewayProvider)
          .shareText(text, subject: data.meeting.title, origin: origin);
      if (!r.shared && context.mounted) showSnack(context, S.copied);
    } catch (e) {
      if (context.mounted) {
        showSnack(
          context,
          e is InsatoException ? e.messageAr : S.exportFailed,
          error: true,
        );
      }
    }
  }
}

/// Everything an export needs, read fresh from the repositories.
class _ExportData {
  _ExportData(this.meeting, this.segments, this.speakersById);

  final Meeting meeting;
  final List<TranscriptSegment> segments;
  final Map<String, Speaker> speakersById;

  static Future<_ExportData> load(WidgetRef ref, String meetingId) async {
    final meeting = await ref.read(meetingRepositoryProvider).get(meetingId);
    if (meeting == null) throw const InsatoException(S.meetingNotFound);
    final segments = await ref
        .read(segmentRepositoryProvider)
        .getForMeeting(meetingId);
    final speakers = await ref.read(speakerRepositoryProvider).getAllById();
    return _ExportData(meeting, segments, speakers);
  }
}

enum _MenuAction {
  export,
  copyMinutes,
  copyTranscript,
  rename,
  refine,
  reprocess,
  delete,
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.meeting, required this.jobRunning});

  final Meeting meeting;
  final bool jobRunning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMinutes = meeting.minutes != null;
    return PopupMenuButton<_MenuAction>(
      tooltip: 'المزيد',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (a) => _run(context, ref, a),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MenuAction.export,
          enabled: hasMinutes,
          child: const ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('${S.exportPdf} / ${S.exportMarkdown}'),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.copyMinutes,
          enabled: hasMinutes,
          child: const ListTile(
            leading: Icon(Icons.copy_rounded),
            title: Text(S.copyMinutes),
          ),
        ),
        const PopupMenuItem(
          value: _MenuAction.copyTranscript,
          child: ListTile(
            leading: Icon(Icons.notes_rounded),
            title: Text(S.copyTranscript),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _MenuAction.rename,
          child: ListTile(
            leading: Icon(Icons.edit_rounded),
            title: Text(S.renameMeeting),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.refine,
          enabled: !jobRunning,
          child: const ListTile(
            leading: Icon(Icons.auto_fix_high_rounded),
            title: Text(S.refineSpeakers),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.reprocess,
          enabled: !jobRunning && meeting.audioPath != null,
          child: const ListTile(
            leading: Icon(Icons.replay_rounded),
            title: Text(S.reprocess),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.delete,
          child: ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text(S.deleteMeeting),
          ),
        ),
      ],
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, _MenuAction a) async {
    switch (a) {
      case _MenuAction.export:
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => ExportSheet(meetingId: meeting.id),
        );
      case _MenuAction.copyMinutes:
      case _MenuAction.copyTranscript:
        try {
          final data = await _ExportData.load(ref, meeting.id);
          final export = ref.read(exportServiceProvider);
          final m = data.meeting.minutes;
          final text = a == _MenuAction.copyMinutes && m != null
              ? export.toPlainText(data.meeting, m, data.speakersById)
              : export.fullTranscriptText(
                  data.meeting,
                  data.segments,
                  data.speakersById,
                );
          await ref.read(shareGatewayProvider).copyText(text);
          if (context.mounted) showSnack(context, S.copied);
        } catch (_) {
          if (context.mounted) showSnack(context, S.exportFailed, error: true);
        }
      case _MenuAction.rename:
        await renameMeetingFlow(context, ref, meeting);
      case _MenuAction.refine:
        unawaited(
          ref.read(meetingJobsProvider(meeting.id).notifier).refineSpeakers(),
        );
      case _MenuAction.reprocess:
        final ok = await showConfirmDialog(
          context,
          title: S.reprocessTitle,
          body: S.reprocessBody,
          confirmLabel: S.reprocessAction,
          icon: Icons.replay_rounded,
        );
        if (ok) {
          unawaited(
            ref
                .read(meetingJobsProvider(meeting.id).notifier)
                .reprocessFromAudio(),
          );
        }
      case _MenuAction.delete:
        if (!context.mounted) return;
        final deleted = await deleteMeetingFlow(context, ref, meeting);
        if (deleted && context.mounted && !isWideLayout(context)) {
          Navigator.of(context).maybePop();
        }
    }
  }
}

/// Bottom sheet exporting the minutes as PDF (share or print) or Markdown,
/// optionally with the full transcript appended.
class ExportSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ExportSheet({super.key, required this.meetingId});

  /// Meeting exported.
  final String meetingId;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  bool _withTranscript = false;
  bool _busy = false;

  Future<void> _do(String kind, Rect? origin) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    String? message;
    var isError = false;
    try {
      final data = await _ExportData.load(ref, widget.meetingId);
      final minutes = data.meeting.minutes;
      if (minutes == null) throw const InsatoException(S.noMinutesToExport);
      final export = ref.read(exportServiceProvider);
      final gateway = ref.read(shareGatewayProvider);
      Future<Uint8List> pdf() => export.toPdf(
        data.meeting,
        minutes,
        data.speakersById,
        segments: data.segments,
        includeTranscript: _withTranscript,
      );
      switch (kind) {
        case 'pdf':
          final r = await gateway.sharePdf(
            bytes: await pdf(),
            fileName: ExportService.suggestedFileName(data.meeting, 'pdf'),
            origin: origin,
          );
          if (r.savedPath != null) message = S.savedTo(r.savedPath!);
        case 'print':
          await gateway.printPdf(build: pdf, name: data.meeting.title);
        case 'md':
          final md = export.toMarkdown(
            data.meeting,
            minutes,
            data.speakersById,
            segments: data.segments,
            includeTranscript: _withTranscript,
          );
          final r = await gateway.shareFile(
            bytes: utf8.encode(md),
            fileName: ExportService.suggestedFileName(data.meeting, 'md'),
            mimeType: 'text/markdown',
            subject: data.meeting.title,
            origin: origin,
          );
          if (r.savedPath != null) message = S.savedTo(r.savedPath!);
      }
    } catch (e) {
      isError = true;
      message = e is InsatoException ? e.messageAr : S.exportFailed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    nav.maybePop();
    if (message != null && messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: isError ? 6 : 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${S.exportPdf} / ${S.exportMarkdown}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            SwitchListTile(
              value: _withTranscript,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _withTranscript = v),
              title: const Text(S.includeTranscript),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: LinearProgressIndicator(),
              ),
            Builder(
              builder: (context) => ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: const Text(S.exportPdf),
                onTap: () => _do('pdf', shareOriginOf(context)),
              ),
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.print_rounded),
              title: const Text(S.printPdf),
              onTap: () => _do('print', null),
            ),
            Builder(
              builder: (context) => ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.code_rounded),
                title: const Text(S.exportMarkdown),
                onTap: () => _do('md', shareOriginOf(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
