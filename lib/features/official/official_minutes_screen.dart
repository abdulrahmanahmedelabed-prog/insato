// The official minutes of a meeting (v1.2): header data (number, both
// dates, place, chair, secretary, rules), attendance and quorum, numbered
// resolutions with their votes, the draft → reviewed → approved lifecycle
// with the SHA-256 of the approved content, signatures and the version
// history.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import '../consistency/consistency_widgets.dart'
    show SupersededResolutionsCard;
import 'attendance_screen.dart';
import 'official_logic.dart';
import 'official_models.dart';
import 'official_providers.dart';
import 'official_service.dart';
import 'official_templates.dart';
import 'signature_pad.dart';
import 'strings.dart';
import 'template_picker.dart';
import 'versions_screen.dart';
import 'vote_review_screen.dart';

/// Opens the official minutes of [meetingId].
Future<void> openOfficialMinutesScreen(
  BuildContext context,
  String meetingId,
) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => OfficialMinutesScreen(meetingId: meetingId),
  ),
);

/// The official minutes screen.
class OfficialMinutesScreen extends ConsumerWidget {
  /// Creates the screen.
  const OfficialMinutesScreen({super.key, required this.meetingId});

  /// Meeting.
  final String meetingId;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    String? done,
  }) async {
    try {
      await action();
      if (done != null && context.mounted) showSnack(context, done);
    } on OfficialActionException catch (e) {
      if (context.mounted) showSnack(context, e.messageAr, error: true);
    } catch (_) {
      if (context.mounted) showSnack(context, S.unexpectedError, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meeting = ref.watch(meetingProvider(meetingId)).value;
    final async = ref.watch(officialBundleProvider(meetingId));
    return Scaffold(
      appBar: AppBar(
        title: const Text(OS.screenTitle),
        actions: [
          IconButton(
            tooltip: OS.versions,
            icon: const Icon(Icons.history_rounded),
            onPressed: () => openVersionsScreen(context, meetingId),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(S.unexpectedError)),
        data: (b) {
          if (b == null || meeting == null) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: OS.noMinutes,
            );
          }
          final service = ref.read(officialMinutesServiceProvider);
          final doc = b.document;
          final record = b.record;
          final locked = record.isLocked;
          final theme = Theme.of(context);
          final minutes = meeting.minutes!;
          final pending = {
            ...resolutionsNeedingReview(minutes, record),
            for (final r in doc.resolutions)
              if (r.tally.outcome == VoteOutcome.needsReview) r.index,
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // v1.2 D: resolutions superseded by later meetings
                    // (an annotation; the approved content is unchanged).
                    SupersededResolutionsCard(meeting: meeting),
                    // ------------------------------------------- Template
                    const SectionHeader(
                      OS.templateHeader,
                      icon: Icons.gavel_rounded,
                    ),
                    TemplatePickerField(
                      value: meeting.context.template,
                      enabled: !locked,
                      onChanged: (v) => _run(context, () async {
                        await ref
                            .read(meetingRepositoryProvider)
                            .updateContext(
                              meeting.id,
                              meeting.context.copyWith(
                                template: v,
                                clearTemplate: v == null,
                              ),
                            );
                      }),
                    ),
                    if (!b.choice.isOfficial)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: ErrorBanner(
                          severity: BannerSeverity.info,
                          message: OS.notOfficialTemplate,
                        ),
                      ),

                    // ------------------------------------------ Lifecycle
                    const SectionHeader(
                      OS.lifecycle,
                      icon: Icons.verified_outlined,
                    ),
                    _LifecycleCard(
                      record: record,
                      hash: doc.contentHash,
                      hashMatches: doc.hashMatchesApproval,
                      pendingVotes: pending.length,
                      onReview: () =>
                          _run(context, () => service.markReviewed(meetingId)),
                      onApprove: () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: OS.approveTitle,
                          body: OS.approveBody,
                          confirmLabel: OS.approve,
                          icon: Icons.verified_rounded,
                        );
                        if (ok && context.mounted) {
                          await _run(context, () => service.approve(meetingId));
                        }
                      },
                      onNewVersion: () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: OS.newVersionTitle,
                          body: OS.newVersionBody,
                          confirmLabel: OS.newVersion,
                          icon: Icons.edit_note_rounded,
                        );
                        if (ok && context.mounted) {
                          await _run(
                            context,
                            () => service.startNewVersion(meetingId),
                          );
                        }
                      },
                    ),

                    // --------------------------------------------- Header
                    SectionHeader(
                      OS.headerSection,
                      icon: Icons.badge_outlined,
                      trailing: locked
                          ? null
                          : TextButton(
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => _HeaderDialog(
                                  meeting: meeting,
                                  record: record,
                                  committees: b.profile.committees,
                                  template: b.choice.template,
                                ),
                              ),
                              child: const Text(OS.editHeader),
                            ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              doc.documentTitle,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            for (final (label, value) in doc.infoRows)
                              _Row(label, value),
                            _Row(
                              OS.quorumRule,
                              (record.quorumOverride ??
                                      b.choice.template.quorum)
                                  .labelAr,
                            ),
                            _Row(
                              OS.majorityRule,
                              (record.majorityOverride ??
                                      b.choice.template.majority)
                                  .labelAr,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ------------------------------------ Attendance
                    SectionHeader(
                      OS.attendance,
                      icon: Icons.groups_rounded,
                      trailing: TextButton(
                        onPressed: () =>
                            openAttendanceScreen(context, meetingId),
                        child: Text(locked ? OS.attendance : OS.editAttendance),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (label, names) in doc.attendanceGroups)
                              _Row(label, names.join('، ')),
                            if (doc.attendanceGroups.isEmpty)
                              const Text(OS.attendanceEmpty),
                            const Divider(),
                            Row(
                              children: [
                                Icon(
                                  doc.quorum.met
                                      ? Icons.verified_rounded
                                      : Icons.report_gmailerrorred_rounded,
                                  color: doc.quorum.met
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(doc.quorum.statementAr)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ----------------------------------- Resolutions
                    SectionHeader(
                      OS.resolutions,
                      icon: Icons.how_to_vote_rounded,
                      trailing: TextButton(
                        onPressed: () =>
                            openVoteReviewScreen(context, meetingId),
                        child: const Text(OS.voteReview),
                      ),
                    ),
                    if (pending.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ErrorBanner(
                          severity: BannerSeverity.warning,
                          message: OS.pendingVotes(pending.length),
                          retryLabel: OS.voteReview,
                          onRetry: () =>
                              openVoteReviewScreen(context, meetingId),
                        ),
                      ),
                    if (doc.resolutions.isEmpty) const Text(OS.noResolutions),
                    for (final r in doc.resolutions)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(r.label, style: theme.textTheme.titleSmall),
                              Text(r.text),
                              if (r.voteLine != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    r.voteLine!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // ------------------------------------ Signatures
                    if (b.choice.template.signaturesRequired ||
                        b.signatures.isNotEmpty) ...[
                      const SectionHeader(
                        OS.signatures,
                        icon: Icons.draw_rounded,
                      ),
                      if (!doc.isApproved) const Text(OS.signAfterApproval),
                      for (final s in doc.signatories)
                        Card(
                          child: ListTile(
                            title: Text(s.name.isEmpty ? '—' : s.name),
                            subtitle: Text(
                              s.signature == null
                                  ? '${s.role} — ${OS.notSigned}'
                                  : '${s.role} — ${OS.signedAt(formatArabicDateTime(s.signature!.signedAt))}',
                            ),
                            trailing: s.signature != null
                                ? SignaturePreview(signature: s.signature!)
                                : FilledButton.tonal(
                                    onPressed: doc.isApproved
                                        ? () => showSignatureCapture(
                                            context,
                                            meetingId: meetingId,
                                            contentHash: doc.contentHash,
                                            signerName: s.name,
                                            signerRole: s.role,
                                          )
                                        : null,
                                    child: const Text(OS.sign),
                                  ),
                          ),
                        ),
                      if (doc.isApproved)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () => showSignatureCapture(
                              context,
                              meetingId: meetingId,
                              contentHash: doc.contentHash,
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(OS.sign),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

class _LifecycleCard extends StatelessWidget {
  const _LifecycleCard({
    required this.record,
    required this.hash,
    required this.hashMatches,
    required this.pendingVotes,
    required this.onReview,
    required this.onApprove,
    required this.onNewVersion,
  });

  final OfficialRecord record;
  final String hash;
  final bool hashMatches;
  final int pendingVotes;
  final VoidCallback onReview;
  final VoidCallback onApprove;
  final VoidCallback onNewVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = record.status.index;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final s in OfficialStatus.values) ...[
                  Expanded(
                    child: Semantics(
                      selected: s == record.status,
                      child: Column(
                        children: [
                          Icon(
                            s.index <= step
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: s.index <= step
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          Text(
                            s.labelAr,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: s == record.status
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(OS.version(record.version), style: theme.textTheme.bodySmall),
            if (record.isLocked) ...[
              const SizedBox(height: 4),
              Text(
                '${OS.hashLabel}: ${formatHash(record.approvedHash ?? hash)}',
                style: theme.textTheme.labelSmall,
              ),
              if (!hashMatches)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    OS.hashMismatch,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (record.status == OfficialStatus.draft)
                  FilledButton.tonalIcon(
                    onPressed: onReview,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text(OS.markReviewed),
                  ),
                if (record.status == OfficialStatus.reviewed)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text(OS.approve),
                  ),
                if (record.isLocked)
                  OutlinedButton.icon(
                    onPressed: onNewVersion,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text(OS.newVersion),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderDialog extends ConsumerStatefulWidget {
  const _HeaderDialog({
    required this.meeting,
    required this.record,
    required this.committees,
    required this.template,
  });

  final Meeting meeting;
  final OfficialRecord record;
  final List<String> committees;
  final OfficialTemplate template;

  @override
  ConsumerState<_HeaderDialog> createState() => _HeaderDialogState();
}

class _HeaderDialogState extends ConsumerState<_HeaderDialog> {
  late String? _committee = widget.record.committee;
  late final _number = TextEditingController(
    text: widget.record.meetingNumber?.toString() ?? '',
  );
  late final _place = TextEditingController(text: widget.record.place);
  late final _chair = TextEditingController(text: widget.record.chair);
  late final _secretary = TextEditingController(text: widget.record.secretary);
  late DateTime _start = widget.record.startTime ?? widget.meeting.createdAt;
  late DateTime? _end = widget.record.endTime;
  late QuorumKind? _quorum = widget.record.quorumOverride?.kind;
  late MajorityKind? _majority = widget.record.majorityOverride?.kind;
  late bool _casting =
      (widget.record.majorityOverride ?? widget.template.majority)
          .chairCastingVote;
  String? _numberError;

  @override
  void dispose() {
    _number.dispose();
    _place.dispose();
    _chair.dispose();
    _secretary.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickTime(DateTime base) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base.toLocal()),
    );
    if (t == null) return null;
    final d = base.toLocal();
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    final raw = toWesternDigits(_number.text.trim());
    final number = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && (number == null || number <= 0)) {
      setState(() => _numberError = OS.numberInvalid);
      return;
    }
    final service = ref.read(officialMinutesServiceProvider);
    var record = widget.record;
    try {
      if (_committee != record.committee) {
        record = await service.changeCommittee(
          widget.meeting,
          record,
          _committee,
        );
      }
      record = record.copyWith(
        meetingNumber: number,
        clearNumber: number == null,
        numberYear: number == null
            ? null
            : (record.numberYear ??
                  numberYearOf(widget.meeting.createdAt, record.yearStyle)),
        place: _place.text.trim(),
        chair: _chair.text.trim(),
        secretary: _secretary.text.trim(),
        startTime: _start,
        endTime: _end,
        quorumOverride: _quorum == null ? null : QuorumRule(_quorum!),
        clearQuorum: _quorum == null,
        majorityOverride:
            _majority == null &&
                _casting == widget.template.majority.chairCastingVote
            ? null
            : MajorityRule(
                _majority ?? widget.template.majority.kind,
                chairCastingVote: _casting,
              ),
        clearMajority:
            _majority == null &&
            _casting == widget.template.majority.chairCastingVote,
      );
      await service.save(record);
      if (mounted) Navigator.of(context).pop();
    } on OfficialActionException catch (e) {
      if (mounted) showSnack(context, e.messageAr, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final committees = {...widget.committees, ?_committee}.toList();
    return AlertDialog(
      title: const Text(OS.headerSection),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _committee,
              isExpanded: true,
              decoration: const InputDecoration(labelText: OS.committee),
              items: [
                const DropdownMenuItem<String?>(child: Text(OS.noCommittee)),
                for (final c in committees)
                  DropdownMenuItem<String?>(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _committee = v),
            ),
            TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: OS.meetingNumber,
                errorText: _numberError,
              ),
            ),
            TextField(
              controller: _place,
              decoration: const InputDecoration(labelText: OS.place),
            ),
            TextField(
              controller: _chair,
              decoration: const InputDecoration(labelText: OS.chair),
            ),
            TextField(
              controller: _secretary,
              decoration: const InputDecoration(labelText: OS.secretary),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(OS.startTime),
              trailing: Text(formatClock(_start)),
              onTap: () async {
                final t = await _pickTime(_start);
                if (t != null) setState(() => _start = t);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(OS.endTime),
              trailing: Text(_end == null ? '—' : formatClock(_end!)),
              onTap: () async {
                final t = await _pickTime(_end ?? _start);
                if (t != null) setState(() => _end = t);
              },
            ),
            DropdownButtonFormField<QuorumKind?>(
              initialValue: _quorum,
              isExpanded: true,
              decoration: const InputDecoration(labelText: OS.quorumRule),
              items: [
                DropdownMenuItem<QuorumKind?>(
                  child: Text(
                    '${OS.templateDefault} (${widget.template.quorum.labelAr})',
                  ),
                ),
                for (final k in QuorumKind.values)
                  if (k != QuorumKind.percent)
                    DropdownMenuItem<QuorumKind?>(
                      value: k,
                      child: Text(QuorumRule(k).labelAr),
                    ),
              ],
              onChanged: (v) => setState(() => _quorum = v),
            ),
            DropdownButtonFormField<MajorityKind?>(
              initialValue: _majority,
              isExpanded: true,
              decoration: const InputDecoration(labelText: OS.majorityRule),
              items: [
                DropdownMenuItem<MajorityKind?>(
                  child: Text(
                    '${OS.templateDefault} (${widget.template.majority.kind.labelAr})',
                  ),
                ),
                for (final k in MajorityKind.values)
                  DropdownMenuItem<MajorityKind?>(
                    value: k,
                    child: Text(k.labelAr),
                  ),
              ],
              onChanged: (v) => setState(() => _majority = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _casting,
              onChanged: (v) => setState(() => _casting = v),
              title: const Text(OS.castingVote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(onPressed: _save, child: const Text(S.save)),
      ],
    );
  }
}
