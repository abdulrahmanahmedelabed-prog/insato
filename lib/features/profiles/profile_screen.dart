// The speaker profile screen (F16): the opt-in switch, the guardrail notice,
// then demonstrated knowledge by domain, languages, communication style,
// contributions and the narrative summary. Every claim links to its
// evidence (meeting + timestamp, F5). Rebuild recomputes the profile from
// every meeting; delete removes it with its notes and turns the opt-in off.
//
// The same widgets serve phones and wide windows (D1): the content is kept
// to a readable width.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/navigation.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/speaker_avatar.dart';
import '../evidence/evidence.dart';
import 'profile_evidence.dart';
import 'profile_model.dart';
import 'profile_opt_in.dart';
import 'profile_service.dart';
import 'strings.dart';

/// Items shown per list before «عرض المزيد».
const int kProfileListCollapsed = 5;

/// Percent (0..100) of a 0..1 share.
int profilePercent(double share) => (share * 100).round().clamp(0, 100);

/// Opens the profile of [speakerId] as a page.
Future<void> openSpeakerProfile(BuildContext context, String speakerId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SpeakerProfileScreen(speakerId: speakerId),
      ),
    );

/// The profile of one speaker.
class SpeakerProfileScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SpeakerProfileScreen({super.key, required this.speakerId});

  /// Speaker id.
  final String speakerId;

  @override
  ConsumerState<SpeakerProfileScreen> createState() =>
      _SpeakerProfileScreenState();
}

class _SpeakerProfileScreenState extends ConsumerState<SpeakerProfileScreen> {
  /// Meeting whose evidence player is docked under the profile.
  String? _activeMeeting;

  /// True while an evidence chip is being opened (its fallback is handled
  /// by [_openEvidence], not by the notice listener).
  bool _opening = false;

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final speakers = ref.watch(speakersByIdProvider);
    final speaker = speakers.value?[widget.speakerId];
    final view = ref.watch(speakerProfileViewProvider(widget.speakerId));
    final active = _activeMeeting;
    if (active != null) {
      ref.listen(
        evidenceControllerProvider(active).select((s) => s.noticeSerial),
        (prev, next) {
          if (_opening || prev == null || prev == next) return;
          final notice = ref.read(evidenceControllerProvider(active)).noticeAr;
          if (notice != null) showSnack(context, notice);
        },
      );
    }

    final hasProfile = view.value?.profile != null;
    final enabled = speaker?.profileEnabled ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          speaker == null ? PS.screenTitle : PS.screenTitleFor(speaker.name),
        ),
        actions: [
          if (speaker != null && enabled)
            IconButton(
              tooltip: PS.rebuildTooltip,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _busy ? null : _rebuild,
            ),
          if (speaker != null && (enabled || hasProfile))
            IconButton(
              tooltip: PS.deleteProfile,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _busy ? null : _delete,
            ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(semanticsLabel: PS.rebuilding),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(child: _body(context, speakers, speaker, view)),
          if (active != null) EvidencePlayerBar(meetingId: active),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AsyncValue<Map<String, Speaker>> speakers,
    Speaker? speaker,
    AsyncValue<({SpeakerProfile? profile, DateTime? updatedAt})> view,
  ) {
    if (speakers.hasError || view.hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(
          message: PS.loadFailed,
          onRetry: () {
            ref.invalidate(speakersByIdProvider);
            ref.invalidate(speakerProfileProvider(widget.speakerId));
          },
        ),
      );
    }
    if (!speakers.hasValue || !view.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (speaker == null) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: PS.speakerMissing,
      );
    }
    final profile = view.value!.profile;
    final updatedAt = view.value!.updatedAt ?? profile?.builtAt;
    final children = <Widget>[
      _SpeakerHeader(speaker: speaker),
      const SizedBox(height: 8),
      Card(child: ProfileOptInTile(speakerId: speaker.id)),
      const SizedBox(height: 12),
    ];
    if (profile == null) {
      children.add(
        speaker.profileEnabled
            ? const _Placeholder(
                icon: Icons.hourglass_empty_rounded,
                title: PS.emptyTitle,
                body: PS.emptyBody,
              )
            : const _Placeholder(
                icon: Icons.badge_outlined,
                title: PS.notEnabledTitle,
                body: PS.notEnabledBody,
              ),
      );
    } else {
      children.addAll(
        _profileSections(context, profile, updatedAt ?? profile.builtAt),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  List<Widget> _profileSections(
    BuildContext context,
    SpeakerProfile p,
    DateTime updatedAt,
  ) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return [
      const ErrorBanner(severity: BannerSeverity.info, message: PS.disclaimer),
      const SizedBox(height: 8),
      Text(PS.headerLine(p.meetingIds.length, updatedAt), style: muted),
      if (p.omittedByGuardrails > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(PS.omittedNote(p.omittedByGuardrails), style: muted),
        ),
      if (p.isEmpty) ...[
        const SizedBox(height: 12),
        const _Placeholder(
          icon: Icons.hourglass_empty_rounded,
          title: PS.emptyTitle,
          body: PS.emptyBody,
        ),
      ] else ...[
        if (p.notesMeetings == 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(PS.noNotesHint, style: muted),
          ),
        const SectionHeader(PS.sectionKnowledge, icon: Icons.school_outlined),
        _KnowledgeSection(domains: p.knowledge, onOpen: _openEvidence),
        const SectionHeader(PS.sectionLanguages, icon: Icons.translate_rounded),
        _LanguagesSection(totals: p.totals),
        const SectionHeader(PS.sectionStyle, icon: Icons.forum_outlined),
        _StyleSection(profile: p, onOpen: _openEvidence),
        const SectionHeader(
          PS.sectionContributions,
          icon: Icons.emoji_objects_outlined,
        ),
        _ContributionsSection(profile: p, onOpen: _openEvidence),
        const SectionHeader(PS.sectionSummary, icon: Icons.notes_rounded),
        _SummarySection(profile: p),
      ],
    ];
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _openEvidence(String meetingId, EvidenceTarget target) async {
    final previous = _activeMeeting;
    if (previous != null && previous != meetingId) {
      // One clip at a time across meetings.
      try {
        await ref
            .read(evidenceControllerProvider(previous).notifier)
            .closePlayer();
      } catch (_) {
        // Already released.
      }
      if (!mounted) return;
    }
    setState(() => _activeMeeting = meetingId);
    final provider = evidenceControllerProvider(meetingId);
    final controller = ref.read(provider.notifier);
    final before = ref.read(provider).transcriptJumpSerial;
    _opening = true;
    try {
      await controller.open(target);
    } finally {
      _opening = false;
    }
    if (!mounted) return;
    final after = ref.read(provider);
    if (after.transcriptJumpSerial == before) return;
    // No playable recording: show the cited line instead.
    final openIt = await showProfileEvidenceLineSheet(
      context,
      meetingId: meetingId,
      target: target,
      reason: profileLineSheetReason(after.noticeAr),
    );
    if (openIt && mounted) await openMeeting(context, ref, meetingId);
  }

  Future<void> _rebuild() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    setState(() => _busy = true);
    try {
      await ref.read(speakerProfileServiceProvider).rebuild(widget.speakerId);
      if (messenger != null) showSnackOn(messenger, scheme, PS.rebuilt);
    } catch (_) {
      if (messenger != null) {
        showSnackOn(messenger, scheme, PS.actionFailed, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text(PS.deleteTitle),
        content: const SingleChildScrollView(child: Text(PS.deleteBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final active = _activeMeeting;
    setState(() {
      _busy = true;
      _activeMeeting = null;
    });
    if (active != null) {
      try {
        await ref
            .read(evidenceControllerProvider(active).notifier)
            .closePlayer();
      } catch (_) {
        // Already released.
      }
    }
    try {
      await ref
          .read(speakerProfileServiceProvider)
          .deleteProfile(widget.speakerId);
      if (messenger != null) showSnackOn(messenger, scheme, PS.deletedSnack);
    } catch (_) {
      if (messenger != null) {
        showSnackOn(messenger, scheme, PS.actionFailed, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

class _SpeakerHeader extends StatelessWidget {
  const _SpeakerHeader({required this.speaker});

  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SpeakerAvatar(speaker: speaker, radius: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(speaker.name, style: theme.textTheme.headlineSmall),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// «أدلة محدودة» badge.
class _LowEvidenceBadge extends StatelessWidget {
  const _LowEvidenceBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: PS.lowEvidenceHint,
      child: Semantics(
        label: '${PS.lowEvidence}. ${PS.lowEvidenceHint}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                PS.lowEvidence,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list that shows [kProfileListCollapsed] items, then «عرض المزيد».
class _CollapsibleList extends StatefulWidget {
  const _CollapsibleList({required this.children});

  final List<Widget> children;

  @override
  State<_CollapsibleList> createState() => _CollapsibleListState();
}

class _CollapsibleListState extends State<_CollapsibleList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.children;
    final collapse = all.length > kProfileListCollapsed + 1;
    final shown = !collapse || _expanded
        ? all
        : all.take(kProfileListCollapsed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...shown,
        if (collapse)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _expanded
                    ? PS.showLess
                    : PS.showMore(all.length - kProfileListCollapsed),
              ),
            ),
          ),
      ],
    );
  }
}

/// One evidence-backed claim: text, optional leading label, low-evidence
/// badge, then the meeting and its evidence chips.
class _ClaimTile extends StatelessWidget {
  const _ClaimTile({
    required this.text,
    required this.meetingId,
    required this.meetingAt,
    required this.evidence,
    required this.onOpen,
    this.label,
    this.lowEvidence = false,
  });

  final String text;
  final String? label;
  final String? meetingId;
  final DateTime? meetingAt;
  final List<int> evidence;
  final bool lowEvidence;
  final ProfileEvidenceOpener onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final id = meetingId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null || lowEvidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (lowEvidence) const _LowEvidenceBadge(),
                ],
              ),
            ),
          Text(text, style: theme.textTheme.bodyMedium),
          if (id != null && id.isNotEmpty)
            ProfileEvidenceLinks(
              meetingId: id,
              evidence: evidence,
              meetingAt: meetingAt,
              onOpen: onOpen,
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _SubHeader extends StatelessWidget {
  const _SubHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

class _KnowledgeSection extends StatelessWidget {
  const _KnowledgeSection({required this.domains, required this.onOpen});

  final List<ProfileDomain> domains;
  final ProfileEvidenceOpener onOpen;

  @override
  Widget build(BuildContext context) {
    if (domains.isEmpty) {
      return const _SectionCard(children: [_EmptyLine(PS.knowledgeEmpty)]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in domains) _DomainCard(domain: d, onOpen: onOpen),
      ],
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain, required this.onOpen});

  final ProfileDomain domain;
  final ProfileEvidenceOpener onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Newest demonstrations first inside the card.
    final items = domain.items.reversed.toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(switch (domain.highestLevel) {
          DemonstrationLevel.led => Icons.workspace_premium_outlined,
          DemonstrationLevel.explained => Icons.record_voice_over_outlined,
          DemonstrationLevel.mentioned => Icons.chat_bubble_outline_rounded,
        }, color: scheme.primary),
        title: Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(domain.domain, style: theme.textTheme.titleMedium),
            if (domain.lowEvidence) const _LowEvidenceBadge(),
          ],
        ),
        subtitle: Text(
          '${PS.domainSubtitle(domain.meetings, domain.highestLevel)}\n'
          '${PS.trendLabel(domain.trend)}',
        ),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CollapsibleList(
            children: [
              for (final i in items)
                _ClaimTile(
                  label: PS.levelLabel(i.level),
                  text: i.demonstrated,
                  meetingId: i.meetingId,
                  meetingAt: i.meetingAt,
                  evidence: i.evidence,
                  lowEvidence: i.lowEvidence,
                  onOpen: onOpen,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguagesSection extends StatelessWidget {
  const _LanguagesSection({required this.totals});

  final ProfileTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langs = totals.languages;
    if (langs.isEmpty) {
      return const _SectionCard(children: [_EmptyLine(PS.languagesEmpty)]);
    }
    return _SectionCard(
      children: [
        for (final l in langs)
          _ShareRow(
            label: S.languageName(l.code) ?? l.code,
            value: PS.languageShare(profilePercent(l.share), l.ms),
            share: l.share,
          ),
        const SizedBox(height: 4),
        Text(
          langs.length < 2 || totals.languageSwitches == 0
              ? PS.singleLanguage
              : PS.codeSwitching(
                  profilePercent(totals.codeSwitchRate),
                  totals.mixedTurns,
                ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// A label, a value and a share bar.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.value,
    required this.share,
    this.semanticsLabel,
  });

  final String label;
  final String value;
  final double share;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel ?? '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(value, style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.clamp(0, 1).toDouble(),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(value, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleSection extends StatelessWidget {
  const _StyleSection({required this.profile, required this.onOpen});

  final SpeakerProfile profile;
  final ProfileEvidenceOpener onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = profile.totals;
    final tasks = profile.tasks;
    final perMeeting = [
      for (final m in profile.perMeeting.reversed)
        if (m.segments > 0) m,
    ];
    return _SectionCard(
      children: [
        if (t.segments > 0) ...[
          if (t.lowEvidence)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const _LowEvidenceBadge(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      PS.statsLowEvidence,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          _StatRow(
            PS.statTalkShare,
            PS.talkShareValue(profilePercent(t.talkShare), t.speakingMs),
          ),
          _StatRow(PS.statTurns, '${t.turns}'),
          _StatRow(PS.statMeanTurn, formatDurationWords(t.meanTurnMs)),
          _StatRow(
            PS.statQuestions,
            PS.questionsValue(t.questions, t.statementSegments),
          ),
          _StatRow(
            PS.statInterruptions,
            PS.interruptionsValue(
              t.interruptionsGiven,
              t.interruptionsReceived,
            ),
          ),
          _StatRow(PS.statDecisions, '${t.decisionsProposed}'),
        ],
        if (tasks.owned > 0)
          _StatRow(
            PS.statTasks,
            PS.tasksValue(tasks.completed, tasks.owned, tasks.open),
          ),
        if (perMeeting.length > 1) ...[
          const _SubHeader(PS.perMeetingTitle),
          _CollapsibleList(
            children: [
              for (final m in perMeeting)
                _ShareRow(
                  label: PS.evidenceMeeting(m.meetingTitle, m.meetingAt),
                  value: '${profilePercent(m.talkShare)}٪',
                  share: m.talkShare,
                  semanticsLabel: PS.perMeetingSemantics(
                    m.meetingTitle,
                    profilePercent(m.talkShare),
                  ),
                ),
            ],
          ),
        ],
        if (profile.style.isNotEmpty) ...[
          const _SubHeader(PS.styleObservations),
          _CollapsibleList(
            children: [
              for (final s in profile.style)
                _ClaimTile(
                  text: s.observation,
                  meetingId: s.meetingId,
                  meetingAt: s.meetingAt,
                  evidence: s.evidence,
                  lowEvidence: s.lowEvidence,
                  onOpen: onOpen,
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ContributionsSection extends StatelessWidget {
  const _ContributionsSection({required this.profile, required this.onOpen});

  final SpeakerProfile profile;
  final ProfileEvidenceOpener onOpen;

  @override
  Widget build(BuildContext context) {
    final decisions = [
      for (final m in profile.perMeeting.reversed)
        for (final d in m.decisions) (meeting: m, decision: d),
    ];
    final tasks = profile.tasks.items;
    final counts = profile.contributionCounts;
    if (profile.contributions.isEmpty && decisions.isEmpty && tasks.isEmpty) {
      return const _SectionCard(children: [_EmptyLine(PS.contributionsEmpty)]);
    }
    return _SectionCard(
      children: [
        if (counts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final k in ContributionKind.values)
                  if ((counts[k] ?? 0) > 0)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${PS.contributionKind(k)} · ${counts[k]}'),
                    ),
              ],
            ),
          ),
        if (profile.contributions.isNotEmpty)
          _CollapsibleList(
            children: [
              for (final c in profile.contributions)
                _ClaimTile(
                  label: PS.contributionKind(c.kind),
                  text: c.text,
                  meetingId: c.meetingId,
                  meetingAt: c.meetingAt,
                  evidence: c.evidence,
                  lowEvidence: c.lowEvidence,
                  onOpen: onOpen,
                ),
            ],
          ),
        if (decisions.isNotEmpty) ...[
          const _SubHeader(PS.decisionsTitle),
          _CollapsibleList(
            children: [
              for (final d in decisions)
                _ClaimTile(
                  text: d.decision.text,
                  meetingId: d.meeting.meetingId,
                  meetingAt: d.meeting.meetingAt,
                  evidence: d.decision.evidence,
                  onOpen: onOpen,
                ),
            ],
          ),
        ],
        if (tasks.isNotEmpty) ...[
          const _SubHeader(PS.tasksTitle),
          _CollapsibleList(
            children: [
              for (final task in tasks)
                _ClaimTile(
                  label: PS.taskStatus(task.status),
                  text: task.task,
                  meetingId: task.meetingId,
                  meetingAt: null,
                  evidence: task.evidence,
                  onOpen: onOpen,
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.profile});

  final SpeakerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final narrative = profile.narrative.where((s) => s.trim().isNotEmpty);
    return _SectionCard(
      children: [
        if (narrative.isEmpty)
          const _EmptyLine(PS.summaryEmpty)
        else
          for (final paragraph in narrative)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(paragraph, style: theme.textTheme.bodyMedium),
            ),
        if (profile.summaries.isNotEmpty) ...[
          const _SubHeader(PS.meetingSummaries),
          _CollapsibleList(
            children: [
              for (final s in profile.summaries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatArabicShortDate(s.meetingAt),
                            style: muted,
                          ),
                          if (s.lowEvidence) const _LowEvidenceBadge(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(s.summary, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}
