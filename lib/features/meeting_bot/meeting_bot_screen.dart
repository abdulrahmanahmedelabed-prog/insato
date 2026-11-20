// UI of the meeting bot: the screen (link, name, time, consent, live
// status, stop) and its two entries — an app-bar button on the meetings
// list and a tile on the new-meeting form (Windows only). Off Windows the
// screen only explains why the bot is not available there.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';

import '../../audio/audio_capture_service.dart' show CapturePlatform;
import '../../ui/navigation.dart';
import '../../ui/widgets/common.dart';
import '../voice/mic_capture.dart' show capturePlatformProvider;
import 'bot_audio.dart' show BotCaptureMode;
import 'bot_providers.dart';
import 'bot_runner.dart';
import 'bot_scripts.dart' show kBotScriptsVersion;
import 'meeting_link.dart';
import 'strings.dart';

/// Opens the meeting-bot screen.
Future<void> openMeetingBotScreen(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const MeetingBotScreen()));

/// App-bar entry (all platforms; the screen explains the Windows
/// requirement elsewhere).
class MeetingBotButton extends ConsumerWidget {
  /// Creates the button.
  const MeetingBotButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(meetingBotControllerProvider).isBusy;
    final icon = Icon(
      busy ? Icons.smart_toy_rounded : Icons.smart_toy_outlined,
    );
    return IconButton(
      tooltip: BotStrings.entryTooltip,
      icon: busy ? Badge(child: icon) : icon,
      onPressed: () => openMeetingBotScreen(context),
    );
  }
}

/// Entry tile on the new-meeting form; renders nothing off Windows.
class MeetingBotEntryTile extends ConsumerWidget {
  /// Creates the tile.
  const MeetingBotEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(capturePlatformProvider) != CapturePlatform.windows) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: const Icon(Icons.smart_toy_outlined),
        title: const Text(BotStrings.entryTile),
        subtitle: const Text(BotStrings.entryTileSubtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => openMeetingBotScreen(context),
      ),
    );
  }
}

/// The meeting-bot screen.
class MeetingBotScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const MeetingBotScreen({super.key});

  @override
  ConsumerState<MeetingBotScreen> createState() => _MeetingBotScreenState();
}

class _MeetingBotScreenState extends ConsumerState<MeetingBotScreen> {
  final TextEditingController _link = TextEditingController();
  final TextEditingController _name = TextEditingController(
    text: BotStrings.defaultBotName,
  );
  final TextEditingController _passcode = TextEditingController();
  bool _later = false;
  DateTime? _at;
  bool _showWindow = false;
  bool _consent = false;

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    _passcode.dispose();
    super.dispose();
  }

  MeetingLinkResult get _parsed => parseMeetingLink(_link.text);

  String? get _timeError {
    if (!_later) return null;
    final at = _at;
    if (at == null || !at.isAfter(DateTime.now())) return BotStrings.timeInPast;
    return null;
  }

  bool get _canStart =>
      _parsed.isValid &&
      _name.text.trim().isNotEmpty &&
      _consent &&
      _timeError == null;

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _at ?? now.add(const Duration(minutes: 10));
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    // A time already past today means tomorrow.
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    setState(() {
      _at = at;
      _later = true;
    });
  }

  Future<void> _start() async {
    var link = _parsed.link;
    if (link == null || !_canStart) return;
    if (link.platform == MeetingPlatform.zoom &&
        _passcode.text.trim().isNotEmpty) {
      link = link.withPasscode(_passcode.text);
    }
    await ref
        .read(meetingBotControllerProvider.notifier)
        .start(
          BotRequest(
            link: link,
            botName: _name.text.trim(),
            scheduledAt: _later ? _at : null,
            showWindow: _showWindow,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final windows =
        ref.watch(capturePlatformProvider) == CapturePlatform.windows;
    final status = ref.watch(meetingBotControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(BotStrings.title)),
      body: !windows
          ? const EmptyState(
              icon: Icons.desktop_windows_outlined,
              title: BotStrings.windowsOnlyTitle,
              body: BotStrings.windowsOnlyBody,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                ReadableWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        BotStrings.intro,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (status.phase != BotPhase.idle) ...[
                        const SectionHeader(
                          BotStrings.statusHeader,
                          icon: Icons.smart_toy_outlined,
                        ),
                        BotStatusCard(status: status),
                      ],
                      if (!status.isBusy) ..._form(context),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _form(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsed;
    final linkText = _link.text.trim();
    final link = parsed.link;
    final timeError = _timeError;
    return [
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('bot-link'),
        controller: _link,
        textDirection: TextDirection.ltr,
        keyboardType: TextInputType.url,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: BotStrings.linkLabel,
          hintText: BotStrings.linkHint,
          prefixIcon: const Icon(Icons.link_rounded),
          errorText: linkText.isEmpty || parsed.isValid
              ? null
              : BotStrings.linkError(parsed.error!),
          helperText: link == null
              ? null
              : BotStrings.detected(link.platform, link.meetingId),
        ),
        onChanged: (_) {
          final p = parseMeetingLink(_link.text).link?.passcode;
          if (p != null && _passcode.text.isEmpty) _passcode.text = p;
          setState(() {});
        },
      ),
      if (link?.platform == MeetingPlatform.zoom) ...[
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('bot-passcode'),
          controller: _passcode,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: BotStrings.passcodeLabel,
            helperText: BotStrings.passcodeHelper,
            prefixIcon: Icon(Icons.password_rounded),
          ),
        ),
      ],
      if (link?.platform == MeetingPlatform.webex) ...[
        const SizedBox(height: 8),
        Text(
          BotStrings.webexExperimental,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('bot-name'),
        controller: _name,
        maxLength: 60,
        decoration: InputDecoration(
          labelText: BotStrings.nameLabel,
          helperText: BotStrings.nameHelper,
          prefixIcon: const Icon(Icons.badge_outlined),
          errorText: _name.text.trim().isEmpty ? BotStrings.nameEmpty : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SectionHeader(BotStrings.whenHeader, icon: Icons.schedule_rounded),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            label: const Text(BotStrings.joinNow),
            selected: !_later,
            onSelected: (_) => setState(() => _later = false),
          ),
          ChoiceChip(
            label: const Text(BotStrings.joinLater),
            selected: _later,
            onSelected: (_) {
              if (_at == null) {
                unawaited(_pickTime());
              } else {
                setState(() => _later = true);
              }
            },
          ),
          if (_later)
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time_rounded),
              label: Text(
                _at == null
                    ? BotStrings.pickTime
                    : BotStrings.joinAt(_formatTime(context, _at!)),
              ),
            ),
        ],
      ),
      if (_later) ...[
        const SizedBox(height: 8),
        Text(
          timeError ?? BotStrings.scheduleNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: timeError == null
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.error,
          ),
        ),
      ],
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _showWindow,
        onChanged: (v) => setState(() => _showWindow = v),
        title: const Text(BotStrings.showWindow),
        subtitle: const Text(BotStrings.showWindowHint),
      ),
      const SectionHeader(
        BotStrings.privacyHeader,
        icon: Icons.privacy_tip_outlined,
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            BotStrings.privacyNotice,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
      CheckboxListTile(
        key: const ValueKey('bot-consent'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _consent,
        onChanged: (v) => setState(() => _consent = v ?? false),
        title: const Text(BotStrings.consentCheck),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        key: const ValueKey('bot-start'),
        onPressed: _canStart ? _start : null,
        icon: Icon(_later ? Icons.schedule_send_rounded : Icons.send_rounded),
        label: Text(_later ? BotStrings.schedule : BotStrings.start),
      ),
      const SizedBox(height: 12),
      Text(
        BotStrings.requirement,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        BotStrings.scriptsVersion(kBotScriptsVersion),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}

String _formatTime(BuildContext context, DateTime t) {
  final now = DateTime.now();
  final sameDay =
      t.year == now.year && t.month == now.month && t.day == now.day;
  final time = intl.DateFormat.Hm().format(t);
  return sameDay ? time : '${intl.DateFormat('d/M').format(t)} $time';
}

/// Live status of the bot with its actions.
class BotStatusCard extends ConsumerWidget {
  /// Creates the card.
  const BotStatusCard({super.key, required this.status});

  /// The status shown.
  final BotStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(meetingBotControllerProvider.notifier);
    final request = status.request;
    final failed = status.phase == BotPhase.failed;
    final scheduledAt = request?.scheduledAt;
    final reason = status.reason;
    final meetingId = status.meetingId;
    final since = status.recordingSince;
    final mode = status.captureMode;
    final working = switch (status.phase) {
      BotPhase.launching ||
      BotPhase.joining ||
      BotPhase.waitingAdmission ||
      BotPhase.leaving => true,
      _ => false,
    };
    return Card(
      color: failed ? scheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (working)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(_iconOf(status.phase), color: _colorOf(status, scheme)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    BotStrings.phase(
                      status.phase,
                      botName: request?.botName,
                      time: scheduledAt == null
                          ? null
                          : _formatTime(context, scheduledAt),
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (request != null) ...[
              const SizedBox(height: 8),
              Text(
                BotStrings.detected(
                  request.link.platform,
                  request.link.meetingId,
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (status.isActive &&
                BotStrings.pageDetail(status.pageState) != null) ...[
              const SizedBox(height: 8),
              Text(BotStrings.pageDetail(status.pageState)!),
            ],
            if (since != null && status.phase == BotPhase.recording) ...[
              const SizedBox(height: 4),
              Text(
                BotStrings.recordingSince(intl.DateFormat.Hm().format(since)),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (reason != null &&
                (status.phase == BotPhase.ended || failed)) ...[
              const SizedBox(height: 8),
              Text(BotStrings.reason(reason)),
              if (status.errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(status.errorMessage!),
              ],
              if (meetingId != null) ...[
                const SizedBox(height: 4),
                const Text(BotStrings.recordingSaved),
              ],
            ],
            if (mode != null && status.phase == BotPhase.recording) ...[
              const SizedBox(height: 8),
              Text(
                BotStrings.capture(mode),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: mode == BotCaptureMode.processLoopback
                      ? null
                      : scheme.error,
                ),
              ),
              const SizedBox(height: 4),
              Text(BotStrings.speakersNote, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (status.phase == BotPhase.recording)
                  OutlinedButton.icon(
                    onPressed: () => openRecordingScreen(context),
                    icon: const Icon(Icons.graphic_eq_rounded),
                    label: const Text(BotStrings.openRecording),
                  ),
                if (status.isBusy && status.phase != BotPhase.leaving)
                  FilledButton.icon(
                    key: const ValueKey('bot-stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: controller.stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(
                      status.phase == BotPhase.recording
                          ? BotStrings.stop
                          : BotStrings.cancel,
                    ),
                  ),
                if (meetingId != null && !status.isBusy)
                  FilledButton.tonalIcon(
                    onPressed: () => openMeeting(context, ref, meetingId),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text(BotStrings.openMeeting),
                  ),
                if (!status.isBusy)
                  TextButton(
                    onPressed: controller.reset,
                    child: const Text(BotStrings.again),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(BotPhase phase) => switch (phase) {
    BotPhase.scheduled => Icons.schedule_rounded,
    BotPhase.recording => Icons.fiber_manual_record_rounded,
    BotPhase.ended => Icons.check_circle_outline_rounded,
    BotPhase.failed => Icons.error_outline_rounded,
    _ => Icons.smart_toy_outlined,
  };

  static Color? _colorOf(BotStatus s, ColorScheme scheme) => switch (s.phase) {
    BotPhase.recording || BotPhase.failed => scheme.error,
    BotPhase.ended => scheme.primary,
    _ => null,
  };
}
