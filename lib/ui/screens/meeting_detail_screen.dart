// Meeting details: tabs for the minutes (with the meeting context and
// evidence chips), the full transcript (evidence highlight), the speakers,
// the meeting's tasks with pending task updates (F9), the codes (F17) and
// the contradictions found by the consistency checker (v1.2 D),
// all under one evidence scope with a docked audio player (F5); plus share /
// export (PDF, Word, Markdown — F12) / print / copy, edit context, rename,
// re-process and delete actions and the progress of background jobs.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/models.dart';
import '../../features/codes/codes.dart' show CodesTab, KS;
import '../../features/consistency/consistency.dart'
    show ConsistencyTab, ConsistencyTabLabel;
import '../../features/context/meeting_context_flows.dart'
    show editMeetingContextFlow;
import '../../features/context/strings.dart' show CS;
import '../../features/evidence/evidence.dart'
    show EvidenceScope, EvidenceTranscriptTab;
import '../../features/export_docx/export_docx.dart' show showExportShareSheet;
import '../../features/export_docx/strings.dart' show XS;
import '../../features/official/official_document.dart' show OfficialDocument;
import '../../features/official/official_minutes_screen.dart'
    show openOfficialMinutesScreen;
import '../../features/official/official_service.dart'
    show officialMinutesServiceProvider;
import '../../features/official/strings.dart' show OS;
import '../../features/tasks/tasks.dart' show MeetingTasksPanel, TS;
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
      length: 6,
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
                TabBar(
                  // Six tabs do not fit a phone's width.
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.description_outlined, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      text: S.tabMinutes,
                    ),
                    const Tab(
                      icon: Icon(Icons.notes_rounded, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      text: S.tabTranscript,
                    ),
                    const Tab(
                      icon: Icon(Icons.groups_outlined, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      text: S.tabSpeakers,
                    ),
                    const Tab(
                      icon: Icon(Icons.task_alt_rounded, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      text: TS.tasksTitle,
                    ),
                    const Tab(
                      icon: Icon(Icons.password_rounded, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      text: KS.tabTitle,
                    ),
                    Tab(
                      icon: const Icon(Icons.rule_rounded, size: 20),
                      iconMargin: EdgeInsets.zero,
                      height: 48,
                      child: ConsistencyTabLabel(meetingId: meeting.id),
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
              // Evidence chips in every tab play through one controller; the
              // player bar is docked under the tabs and "show in transcript"
              // switches to the transcript tab (index 1).
              child: EvidenceScope(
                meetingId: meeting.id,
                child: TabBarView(
                  children: [
                    MeetingMinutesTab(meeting: meeting),
                    EvidenceTranscriptTab(meetingId: meeting.id),
                    MeetingSpeakersTab(meetingId: meeting.id),
                    MeetingTasksPanel(meetingId: meeting.id),
                    CodesTab(meetingId: meeting.id),
                    ConsistencyTab(meetingId: meeting.id),
                  ],
                ),
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
          ? export.toPlainText(
              data.meeting,
              m,
              data.speakersById,
              segments: data.segments,
              official: data.official,
            )
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
  _ExportData(this.meeting, this.segments, this.speakersById, this.official);

  final Meeting meeting;
  final List<TranscriptSegment> segments;
  final Map<String, Speaker> speakersById;

  /// v1.2: official minutes when the meeting uses an official template.
  final OfficialDocument? official;

  static Future<_ExportData> load(WidgetRef ref, String meetingId) async {
    final meeting = await ref.read(meetingRepositoryProvider).get(meetingId);
    if (meeting == null) throw const InsatoException(S.meetingNotFound);
    final segments = await ref
        .read(segmentRepositoryProvider)
        .getForMeeting(meetingId);
    final speakers = await ref.read(speakerRepositoryProvider).getAllById();
    final official = await ref
        .read(officialMinutesServiceProvider)
        .documentForExport(meeting);
    return _ExportData(meeting, segments, speakers, official);
  }
}

enum _MenuAction {
  official,
  export,
  copyMinutes,
  editContext,
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
          value: _MenuAction.official,
          enabled: hasMinutes,
          child: const ListTile(
            leading: Icon(Icons.gavel_rounded),
            title: Text(OS.screenTitle),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.export,
          enabled: hasMinutes,
          child: const ListTile(
            leading: Icon(Icons.ios_share_rounded),
            title: Text(XS.sheetTitle),
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
          value: _MenuAction.editContext,
          child: ListTile(
            leading: Icon(Icons.event_note_rounded),
            title: Text(CS.editTitle),
          ),
        ),
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
      case _MenuAction.official:
        await openOfficialMinutesScreen(context, meeting.id);
      case _MenuAction.export:
        await showExportShareSheet(context, meeting.id);
      case _MenuAction.editContext:
        await editMeetingContextFlow(context, ref, meeting);
      case _MenuAction.copyMinutes:
      case _MenuAction.copyTranscript:
        try {
          final data = await _ExportData.load(ref, meeting.id);
          final export = ref.read(exportServiceProvider);
          final m = data.meeting.minutes;
          final text = a == _MenuAction.copyMinutes && m != null
              ? export.toPlainText(
                  data.meeting,
                  m,
                  data.speakersById,
                  segments: data.segments,
                  official: data.official,
                )
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
        // The deletion unmounts this menu (the page switches to "not
        // found"), so capture the navigator and layout first.
        final nav = Navigator.of(context);
        final wide = isWideLayout(context);
        final deleted = await deleteMeetingFlow(context, ref, meeting);
        if (deleted && !wide && nav.mounted) unawaited(nav.maybePop());
    }
  }
}
