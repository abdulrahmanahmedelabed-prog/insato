// Meetings list: search, status chips, speaker avatars, swipe / long-press
// delete with confirmation, models banner and the "new meeting" button.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../features/import_audio/import_audio.dart'
    show
        IS,
        ImportProgressCard,
        ImportRecordingButton,
        ImportedBadge,
        importRecordingFlow,
        isImportedMeeting;
import '../../features/meeting_bot/meeting_bot_screen.dart'
    show MeetingBotButton, openMeetingBotScreen;
import '../../features/meeting_bot/strings.dart' show BotStrings;
import '../../features/multi_device/guest_screens.dart'
    show openGuestJoinScreen;
import '../../features/multi_device/host_lobby_screen.dart'
    show openHostLobbyScreen;
import '../../features/multi_device/strings.dart' show MS;
import '../../features/meeting_package/meeting_package.dart'
    show MeetingPackageImportButton, PS, importMeetingPackageFlow;
import '../../features/multi_device/widgets.dart' show MultiDeviceMenuButton;
import '../../features/phone_call/phone_call_setup_screen.dart'
    show startPhoneCallFlow;
import '../../features/phone_call/phone_call_widgets.dart'
    show PhoneCallMenuButton;
import '../../features/phone_call/strings.dart' show PCS;
import '../../session/providers.dart';
import '../actions.dart';
import '../format.dart';
import '../navigation.dart';
import '../strings_ar.dart';
import '../widgets/common.dart';
import '../widgets/models_banner.dart';
import '../widgets/speaker_avatar.dart';

/// The meetings list. [onOpen] opens a meeting (the shell decides between
/// pushing a page and selecting it in the detail pane); [selectedId]
/// highlights the selection in the wide layout.
class MeetingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const MeetingsScreen({super.key, required this.onOpen, this.selectedId});

  /// Opens a meeting.
  final ValueChanged<String> onOpen;

  /// Selected meeting (wide layout).
  final String? selectedId;

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Meeting m) {
    final session = ref.read(meetingSessionControllerProvider);
    if (session.isActive && session.meetingId == m.id) {
      openRecordingScreen(context);
      return;
    }
    widget.onOpen(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final meetings = ref.watch(meetingsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text(S.appName),
          ],
        ),
        actions: const [_MeetingSourcesActions()],
      ),
      floatingActionButton: Tooltip(
        message: S.newMeetingShortcut,
        child: FloatingActionButton.extended(
          heroTag: 'new-meeting',
          onPressed: () => startNewMeeting(context, ref),
          icon: const Icon(Icons.mic_rounded),
          label: const Text(S.newMeeting),
        ),
      ),
      body: Column(
        children: [
          const ModelsMissingBanner(padding: EdgeInsets.fromLTRB(16, 4, 16, 8)),
          ImportProgressCard(
            onOpen: widget.onOpen,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              controller: _search,
              hintText: S.searchMeetings,
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: S.clearSearch,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: meetings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(
                  message: S.unexpectedError,
                  onRetry: () => ref.invalidate(meetingsProvider),
                ),
              ),
              data: (all) {
                if (all.isEmpty) {
                  return EmptyState(
                    icon: Icons.record_voice_over_rounded,
                    title: S.noMeetingsTitle,
                    body: S.noMeetingsBody,
                    action: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => startNewMeeting(context, ref),
                          icon: const Icon(Icons.mic_rounded),
                          label: const Text(S.newMeeting),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => importRecordingFlow(context, ref),
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text(IS.importAction),
                        ),
                      ],
                    ),
                  );
                }
                final list = filterMeetings(all, _query);
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: S.noSearchResults,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = list[i];
                    return MeetingTile(
                      key: ValueKey(m.id),
                      meeting: m,
                      selected: m.id == widget.selectedId,
                      onTap: () => _open(m),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One meeting in the list: swipe (towards the reading start) or long-press
/// to delete or rename.
class MeetingTile extends ConsumerWidget {
  /// Creates the tile.
  const MeetingTile({
    super.key,
    required this.meeting,
    required this.onTap,
    this.selected = false,
  });

  /// The meeting.
  final Meeting meeting;

  /// Open action.
  final VoidCallback onTap;

  /// Highlighted (wide layout selection).
  final bool selected;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text(S.renameMeeting),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text(S.deleteMeeting),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        await renameMeetingFlow(context, ref, meeting);
      case 'delete':
        await deleteMeetingFlow(context, ref, meeting);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final speakers =
        ref.watch(meetingSpeakersProvider(meeting.id)).value ?? const [];
    final summary = meeting.minutes?.summary.trim();
    final card = Card(
      color: selected ? scheme.secondaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _menu(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: meeting.status, dense: true),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isImportedMeeting(meeting)) const ImportedBadge(),
                  _IconText(
                    icon: Icons.calendar_today_rounded,
                    child: Text(
                      formatArabicDateTime(meeting.createdAt.toLocal()),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (meeting.durationMs > 0)
                    _IconText(
                      icon: Icons.timer_outlined,
                      child: LtrText(
                        formatDuration(meeting.durationMs),
                        style: theme.textTheme.bodySmall,
                        semanticsLabel: formatDurationWords(meeting.durationMs),
                      ),
                    ),
                ],
              ),
              if (summary != null && summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (speakers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SpeakerAvatarStack(speakers: speakers),
                    const SizedBox(width: 8),
                    Text(
                      S.speakersCount(speakers.length),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      child: Dismissible(
        key: ValueKey('dismiss-${meeting.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => deleteMeetingFlow(context, ref, meeting),
        background: Container(
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Text(S.delete, style: TextStyle(color: scheme.onErrorContainer)),
            ],
          ),
        ),
        child: card,
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 4),
      Flexible(child: child),
    ],
  );
}

/// One entry of the narrow-screen sources menu.
class _SourceEntry {
  const _SourceEntry(this.id, this.icon, this.label, this.run);

  final String id;
  final IconData icon;
  final String label;
  final void Function(BuildContext context, WidgetRef ref) run;
}

/// The meeting-source actions of the app bar: recording import, meeting
/// package import, meeting bot, phone call and multi-device. Shown as separate icons when there is room; on narrow
/// phones they collapse into one menu so the title never overflows.
class _MeetingSourcesActions extends ConsumerWidget {
  const _MeetingSourcesActions();

  /// Narrower than this, the sources collapse into one menu.
  static const double wideEnough = 520;

  static final List<_SourceEntry> _entries = [
    _SourceEntry(
      'import',
      Icons.upload_file_rounded,
      IS.importTooltip,
      (c, r) => importRecordingFlow(c, r),
    ),
    _SourceEntry(
      'meeting-package',
      Icons.move_to_inbox_rounded,
      PS.importTooltip,
      (c, r) => importMeetingPackageFlow(c, r),
    ),
    _SourceEntry(
      'meeting-bot',
      Icons.smart_toy_outlined,
      BotStrings.entryTooltip,
      (c, _) => openMeetingBotScreen(c),
    ),
    _SourceEntry(
      'phone-call',
      Icons.phone_in_talk_rounded,
      PCS.menuTooltip,
      (c, r) => startPhoneCallFlow(c, r),
    ),
    _SourceEntry(
      'multi-device-host',
      Icons.cast_connected_rounded,
      MS.hostEntry,
      (c, _) => openHostLobbyScreen(c),
    ),
    _SourceEntry(
      'multi-device-guest',
      Icons.mic_external_on_rounded,
      MS.guestEntry,
      (c, _) => openGuestJoinScreen(c),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= wideEnough) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImportRecordingButton(),
          MeetingPackageImportButton(),
          MeetingBotButton(),
          PhoneCallMenuButton(),
          MultiDeviceMenuButton(),
        ],
      );
    }
    return PopupMenuButton<_SourceEntry>(
      key: const ValueKey('meeting-sources-menu'),
      tooltip: S.meetingSourcesMenu,
      icon: const Icon(Icons.add_circle_outline_rounded),
      onSelected: (e) => e.run(context, ref),
      itemBuilder: (_) => [
        for (final e in _entries)
          PopupMenuItem(
            key: ValueKey('source-${e.id}'),
            value: e,
            child: ListTile(
              leading: Icon(e.icon),
              title: Text(e.label),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}
