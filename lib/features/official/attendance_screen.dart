// Attendance sheet editor (v1.2): present / absent with or without excuse /
// invited guests, pre-filled from the expected attendees and recognised
// voices, with the quorum stated live.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import 'official_logic.dart';
import 'official_models.dart';
import 'official_providers.dart';
import 'official_service.dart';
import 'strings.dart';

/// Opens the attendance editor of [meetingId].
Future<void> openAttendanceScreen(BuildContext context, String meetingId) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceScreen(meetingId: meetingId),
      ),
    );

/// The attendance editor.
class AttendanceScreen extends ConsumerWidget {
  /// Creates the screen.
  const AttendanceScreen({super.key, required this.meetingId});

  /// Meeting edited.
  final String meetingId;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    OfficialRecord record,
    List<AttendanceEntry> attendance,
  ) async {
    try {
      await ref
          .read(officialMinutesServiceProvider)
          .save(record.copyWith(attendance: attendance));
    } on OfficialActionException catch (e) {
      if (context.mounted) showSnack(context, e.messageAr, error: true);
    } catch (_) {
      if (context.mounted) showSnack(context, S.unexpectedError, error: true);
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    OfficialRecord record, [
    int? index,
  ]) async {
    final speakers = await ref
        .read(officialMinutesServiceProvider)
        .spokenNames(meetingId);
    if (!context.mounted) return;
    final current = index == null ? null : record.attendance[index];
    final result = await showDialog<AttendanceEntry>(
      context: context,
      builder: (_) => _PersonDialog(initial: current, speakers: speakers),
    );
    if (result == null || !context.mounted) return;
    final key = nameKey(result.name);
    final clash = record.attendance.indexWhere((a) => nameKey(a.name) == key);
    if (clash >= 0 && clash != index) {
      showSnack(context, OS.duplicatePerson, error: true);
      return;
    }
    final list = [...record.attendance];
    if (index == null) {
      list.add(result);
    } else {
      list[index] = result;
    }
    await _save(context, ref, record, list);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officialBundleProvider(meetingId));
    return Scaffold(
      appBar: AppBar(title: const Text(OS.attendance)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(S.unexpectedError)),
        data: (b) {
          if (b == null) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: OS.noMinutes,
            );
          }
          final record = b.record;
          final locked = record.isLocked;
          final quorum = b.document.quorum;
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (locked)
                      const ErrorBanner(
                        severity: BannerSeverity.info,
                        message: OS.lockedHint,
                      ),
                    Text(OS.attendanceIntro, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Card(
                      color: quorum.met
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.errorContainer,
                      child: ListTile(
                        leading: Icon(
                          quorum.met
                              ? Icons.verified_rounded
                              : Icons.report_gmailerrorred_rounded,
                        ),
                        title: const Text(OS.quorum),
                        subtitle: Text(quorum.statementAr),
                      ),
                    ),
                    if (!locked)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () async {
                            final meeting = await ref
                                .read(meetingRepositoryProvider)
                                .get(meetingId);
                            if (meeting == null) return;
                            try {
                              await ref
                                  .read(officialMinutesServiceProvider)
                                  .refreshAttendance(meeting, record);
                            } on OfficialActionException catch (e) {
                              if (context.mounted) {
                                showSnack(context, e.messageAr, error: true);
                              }
                            }
                          },
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text(OS.refreshAttendance),
                        ),
                      ),
                    if (record.attendance.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(OS.attendanceEmpty),
                      ),
                    for (var i = 0; i < record.attendance.length; i++)
                      _AttendanceTile(
                        key: ValueKey('att-${record.attendance[i].name}'),
                        entry: record.attendance[i],
                        enabled: !locked,
                        onStatus: (s) => _save(context, ref, record, [
                          for (var j = 0; j < record.attendance.length; j++)
                            j == i
                                ? record.attendance[j].copyWith(
                                    status: s,
                                    needsConfirmation: false,
                                  )
                                : record.attendance[j],
                        ]),
                        onEdit: () => _edit(context, ref, record, i),
                        onRemove: () => _save(
                          context,
                          ref,
                          record,
                          [...record.attendance]..removeAt(i),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final b = ref.watch(officialBundleProvider(meetingId)).value;
          if (b == null || b.record.isLocked) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _edit(context, ref, b.record),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text(OS.addPerson),
          );
        },
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({
    super.key,
    required this.entry,
    required this.enabled,
    required this.onStatus,
    required this.onEdit,
    required this.onRemove,
  });

  final AttendanceEntry entry;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onStatus;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (entry.title.trim().isNotEmpty) entry.title.trim(),
      if (entry.speakerName != null && entry.speakerName != entry.name)
        '${OS.spokeAs}: ${entry.speakerName}',
    ].join(' — ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: theme.textTheme.titleSmall),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  if (entry.needsConfirmation)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        OS.needsConfirmation,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            DropdownButton<AttendanceStatus>(
              value: entry.status,
              onChanged: enabled ? (s) => s == null ? null : onStatus(s) : null,
              items: [
                for (final s in AttendanceStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.labelAr)),
              ],
            ),
            PopupMenuButton<int>(
              enabled: enabled,
              tooltip: 'المزيد',
              onSelected: (v) => v == 0 ? onEdit() : onRemove(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text(OS.edit)),
                PopupMenuItem(value: 1, child: Text(OS.removePerson)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({required this.initial, required this.speakers});

  final AttendanceEntry? initial;
  final List<String> speakers;

  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late AttendanceStatus _status =
      widget.initial?.status ?? AttendanceStatus.present;
  late String? _speaker = widget.initial?.speakerName;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speakers = {...widget.speakers, ?_speaker}.toList();
    return AlertDialog(
      title: Text(widget.initial == null ? OS.addPerson : OS.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.initial == null,
              decoration: InputDecoration(
                labelText: OS.personName,
                errorText: _error,
              ),
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: OS.personTitle),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AttendanceStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: OS.attendance),
              items: [
                for (final s in AttendanceStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.labelAr)),
              ],
              onChanged: (s) => setState(() => _status = s ?? _status),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _speaker,
              isExpanded: true,
              decoration: const InputDecoration(labelText: OS.spokeAs),
              items: [
                const DropdownMenuItem<String?>(child: Text(OS.notLinked)),
                for (final s in speakers)
                  DropdownMenuItem<String?>(value: s, child: Text(s)),
              ],
              onChanged: (s) => setState(() => _speaker = s),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
            if (name.isEmpty) {
              setState(() => _error = S.nameEmpty);
              return;
            }
            Navigator.of(context).pop(
              AttendanceEntry(
                name: name,
                title: _title.text.trim(),
                status: _status,
                speakerName: _speaker,
              ),
            );
          },
          child: const Text(S.save),
        ),
      ],
    );
  }
}
