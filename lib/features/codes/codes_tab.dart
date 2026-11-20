// «الرموز والشيفرات» tab of a meeting (F17): the five detectors' findings
// (coded / unintelligible speech, internal jargon, spoken code, implied
// speech, reference numbers), each with its speaker and evidence links.
// Interpretations are labelled as hypotheses with their confidence; nothing
// is presented as a decoded fact.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/format.dart';
import '../../ui/services/share_gateway.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../evidence/evidence.dart';
import 'add_to_glossary_dialog.dart';
import 'codes_export.dart';
import 'codes_logic.dart';
import 'reversed_speech_button.dart';
import 'reversed_speech_logic.dart';
import 'strings.dart';

/// Width from which reference numbers are shown as a data table.
const double kCodesTableBreakpoint = 640;

/// The codes tab of [meetingId]. Scrollable; place it in the meeting
/// screen's `TabBarView` (under an `EvidenceScope` so that evidence chips
/// can fall back to the transcript tab).
class CodesTab extends ConsumerWidget {
  /// Creates the tab.
  const CodesTab({super.key, required this.meetingId});

  /// The meeting.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final findingsAsync = ref.watch(codeFindingsProvider(meetingId));
    final segments =
        ref.watch(segmentsProvider(meetingId)).value ??
        const <TranscriptSegment>[];
    final speakers =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};

    if (findingsAsync.hasError && !findingsAsync.hasValue) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: ErrorBanner(message: KS.loadError),
        ),
      );
    }
    if (!findingsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final grouped = groupFindings(findingsAsync.value!);
    final uncovered = uncoveredUnintelligible(segments, grouped);
    final hasUnintelligible = segments.any((s) => s.isUnintelligible);

    if (grouped.isEmpty && !hasUnintelligible) {
      return const EmptyState(
        icon: Icons.password_rounded,
        title: KS.emptyTitle,
        body: KS.emptyBody,
      );
    }

    final view = _CodesData(
      meetingId: meetingId,
      segments: segments,
      speakers: speakers,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _IntroNote(),
              _ExportBar(
                meetingId: meetingId,
                findings: findingsAsync.value!,
                segments: segments,
                speakers: speakers,
              ),
              // 1. Coded / unintelligible speech.
              SectionHeader(
                KS.codedSpeechTitle,
                icon: Icons.graphic_eq_rounded,
                trailing: _Count(grouped.codedSpeech.length + uncovered.length),
              ),
              if (hasUnintelligible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ReversedSpeechButton(meetingId: meetingId),
                ),
              if (grouped.codedSpeech.isEmpty && uncovered.isEmpty)
                const _Muted(KS.noneInSection),
              for (final e in grouped.codedSpeech)
                _CodedSpeechCard(entry: e, data: view),
              if (uncovered.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SubHeading(KS.otherUnintelligibleTitle),
                const _Muted(KS.otherUnintelligibleNote),
                for (final s in uncovered)
                  _UnintelligibleSegmentCard(segment: s, data: view),
              ],
              // 2. Jargon.
              SectionHeader(
                KS.jargonTitle,
                icon: Icons.translate_rounded,
                trailing: _Count(grouped.jargon.length),
              ),
              if (grouped.jargon.isEmpty) const _Muted(KS.noneInSection),
              for (final e in grouped.jargon) _JargonCard(entry: e, data: view),
              // 3. Spoken code.
              SectionHeader(
                KS.spokenCodeTitle,
                icon: Icons.code_rounded,
                trailing: _Count(grouped.spokenCode.length),
              ),
              if (grouped.spokenCode.isEmpty) const _Muted(KS.noneInSection),
              for (final e in grouped.spokenCode)
                _SpokenCodeCard(entry: e, data: view),
              // 4. Implied speech.
              SectionHeader(
                KS.impliedTitle,
                icon: Icons.psychology_alt_outlined,
                trailing: _Count(grouped.implied.length),
              ),
              if (grouped.implied.isEmpty) const _Muted(KS.noneInSection),
              for (final e in grouped.implied)
                _ImpliedCard(entry: e, data: view),
              // 5. References.
              SectionHeader(
                KS.referencesTitle,
                icon: Icons.tag_rounded,
                trailing: _Count(grouped.references.length),
              ),
              if (grouped.references.isEmpty)
                const _Muted(KS.noneInSection)
              else
                _ReferencesView(entries: grouped.references, data: view),
            ],
          ),
        ),
      ],
    );
  }
}

/// What every card needs.
class _CodesData {
  const _CodesData({
    required this.meetingId,
    required this.segments,
    required this.speakers,
  });

  final String meetingId;
  final List<TranscriptSegment> segments;
  final Map<String, Speaker> speakers;

  String speakerOf(CodeFinding f, String payloadName) =>
      findingSpeakerName(f, payloadName, speakers) ?? KS.unknownSpeaker;
}

// ---------------------------------------------------------------------------
// Small parts
// ---------------------------------------------------------------------------

class _IntroNote extends StatelessWidget {
  const _IntroNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                KS.intro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «نسخ القسم» / «مشاركة القسم»: the whole section (code blocks included)
/// as Markdown, as in exported minutes.
class _ExportBar extends ConsumerWidget {
  const _ExportBar({
    required this.meetingId,
    required this.findings,
    required this.segments,
    required this.speakers,
  });

  final String meetingId;
  final List<CodeFinding> findings;
  final List<TranscriptSegment> segments;
  final Map<String, Speaker> speakers;

  String _render() => renderCodesSectionFromFindings(
    findings: findings,
    segments: segments,
    speakersById: speakers,
  );

  Future<void> _run(
    BuildContext context,
    Future<void> Function(String text) action, {
    String? done,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    try {
      await action(_render());
      if (done != null && messenger != null) {
        showSnackOn(messenger, scheme, done);
      }
    } catch (_) {
      if (messenger != null) {
        showSnackOn(messenger, scheme, KS.exportFailed, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(meetingProvider(meetingId)).value?.title ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Tooltip(
        message: KS.exportHint,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: () => _run(
                context,
                (t) => ref.read(shareGatewayProvider).copyText(t),
                done: S.copied,
              ),
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text(KS.exportCopy),
            ),
            Builder(
              builder: (button) => TextButton.icon(
                onPressed: () => _run(context, (t) async {
                  final box = button.findRenderObject() as RenderBox?;
                  final origin = box == null || !box.hasSize
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size;
                  await ref
                      .read(shareGatewayProvider)
                      .shareText(
                        t,
                        subject: KS.exportSubject(title),
                        origin: origin,
                      );
                }),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text(KS.exportShare),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Badge(
      label: Text('$count'),
      backgroundColor: theme.colorScheme.primaryContainer,
      textColor: theme.colorScheme.onPrimaryContainer,
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

/// «مستنتج» / «فرضية» badge with an optional confidence.
class _HypothesisBadge extends StatelessWidget {
  const _HypothesisBadge({required this.label, this.confidence});

  final String label;
  final HypothesisConfidence? confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = confidence;
    final text = c == null ? label : '$label · ${KS.confidence(c)}';
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 14,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeakerLine extends StatelessWidget {
  const _SpeakerLine(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.person_outline_rounded,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            KS.speakerLine(name),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.meetingId, required this.evidence});

  final String meetingId;
  final List<int> evidence;

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          KS.noEvidence,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return EvidenceChips(meetingId: meetingId, evidence: evidence);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 1. Coded / unintelligible speech
// ---------------------------------------------------------------------------

class _CodedSpeechCard extends StatelessWidget {
  const _CodedSpeechCard({required this.entry, required this.data});

  final CodeEntry<CodedSpeechItem> entry;
  final _CodesData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = entry.item;
    final duration = evidenceDurationMs(item.evidence, data.segments);
    final guesses = asrGuessesFor(item.evidence, data.segments);
    final reversed = reversedResultsOf(entry);
    final app = isAppFinding(entry.finding);
    return _ItemCard(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SpeakerLine(data.speakerOf(entry.finding, item.speaker)),
            _HypothesisBadge(label: KS.character(item.character)),
          ],
        ),
        if (app) ...[
          const SizedBox(height: 6),
          Text(
            KS.fromTranscript,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (item.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(item.description, style: theme.textTheme.bodyMedium),
        ],
        if (duration > 0) ...[
          const SizedBox(height: 4),
          Text(KS.totalDuration(duration), style: theme.textTheme.bodySmall),
        ],
        for (final g in guesses) ...[
          const SizedBox(height: 4),
          Text(KS.asrGuess(g), style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        if (item.hypotheses.isEmpty)
          Text(
            KS.noHypotheses,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          Text(KS.possibleMeanings, style: theme.textTheme.titleSmall),
          for (final h in item.hypotheses)
            _HypothesisTile(
              meaning: h.meaning,
              confidence: h.confidence,
              basis: h.basis,
            ),
        ],
        for (final r in reversed) _ReversedResultBox(result: r),
        _Evidence(meetingId: data.meetingId, evidence: item.evidence),
      ],
    );
  }
}

class _HypothesisTile extends StatelessWidget {
  const _HypothesisTile({
    required this.meaning,
    required this.confidence,
    this.basis = '',
  });

  final String meaning;
  final HypothesisConfidence confidence;
  final String basis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HypothesisBadge(label: KS.hypothesis, confidence: confidence),
          const SizedBox(height: 4),
          Text(meaning, style: theme.textTheme.bodyMedium),
          if (basis.isNotEmpty)
            Text(
              KS.basis(basis),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReversedResultBox extends StatelessWidget {
  const _ReversedResultBox({required this.result});

  final ReversedSpeechResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 18, color: scheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  KS.reversedResultTitle,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '«${result.text}»',
            textDirection: detectTextDirection(result.text),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${KS.segmentNumber(result.segment)} — ${KS.reversedResultCaveat}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnintelligibleSegmentCard extends StatelessWidget {
  const _UnintelligibleSegmentCard({required this.segment, required this.data});

  final TranscriptSegment segment;
  final _CodesData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = segment;
    final guess = s.text.trim();
    return _ItemCard(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SpeakerLine(
              segmentSpeakerName(s, data.speakers) ?? KS.unknownSpeaker,
            ),
            Text(
              KS.duration(s.endMs - s.startMs),
              style: theme.textTheme.bodySmall,
            ),
            LtrText(
              formatTimestamp(s.startMs),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        if (guess.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(KS.asrGuess(guess), style: theme.textTheme.bodySmall),
        ],
        _Evidence(meetingId: data.meetingId, evidence: [s.index]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Jargon
// ---------------------------------------------------------------------------

class _JargonCard extends ConsumerWidget {
  const _JargonCard({required this.entry, required this.data});

  final CodeEntry<JargonItem> entry;
  final _CodesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = entry.item;
    final global =
        ref.watch(globalGlossaryProvider).value ?? const <GlossaryTerm>[];
    final local =
        ref.watch(meetingGlossaryProvider(data.meetingId)).value ??
        const <GlossaryTerm>[];
    final key = normalizedKey(item.term);
    final inGlossary = [
      ...global,
      ...local,
    ].any((t) => normalizedKey(t.term) == key);
    final used = jargonSpeakers(item, data.segments, data.speakers);
    final speakers = used.isNotEmpty
        ? used
        : [data.speakerOf(entry.finding, '')];
    final firstUse = jargonFirstUseMs(item, data.segments);
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return _ItemCard(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.term,
              textDirection: detectTextDirection(item.term),
              style: theme.textTheme.titleMedium,
            ),
            _HypothesisBadge(label: KS.inferred, confidence: item.confidence),
          ],
        ),
        if (item.inferredMeaning.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            KS.inferredMeaning(item.inferredMeaning),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 6),
        Text(KS.speakersLine(speakers), style: muted),
        if (speakers.length > 1)
          Text(KS.mostUsedBy(speakers.first), style: muted),
        if (firstUse != null)
          Text(KS.firstUse(formatTimestamp(firstUse)), style: muted),
        _Evidence(meetingId: data.meetingId, evidence: item.evidence),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: inGlossary
              ? OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(KS.inGlossary),
                )
              : OutlinedButton.icon(
                  onPressed: () => showAddJargonToGlossaryDialog(
                    context,
                    meetingId: data.meetingId,
                    item: item,
                  ),
                  icon: const Icon(Icons.library_add_outlined),
                  label: const Text(KS.addToGlossary),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Spoken code
// ---------------------------------------------------------------------------

class _SpokenCodeCard extends ConsumerWidget {
  const _SpokenCodeCard({required this.entry, required this.data});

  final CodeEntry<SpokenCodeItem> entry;
  final _CodesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = entry.item;
    return _ItemCard(
      children: [
        _SpeakerLine(data.speakerOf(entry.finding, item.speaker)),
        const SizedBox(height: 8),
        CodeBlock(
          code: item.code,
          language: codeLanguageLabel(item.language) ?? KS.unknownLanguage,
          onCopy: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final scheme = theme.colorScheme;
            await ref.read(shareGatewayProvider).copyText(item.code);
            if (messenger != null) showSnackOn(messenger, scheme, S.copied);
          },
        ),
        if (item.explanation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(item.explanation, style: theme.textTheme.bodyMedium),
        ],
        if (item.issues.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(KS.potentialIssues, style: theme.textTheme.titleSmall),
          for (final i in item.issues)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 2),
              child: Text('• $i', style: theme.textTheme.bodySmall),
            ),
        ],
        const SizedBox(height: 6),
        Text(
          KS.reconstructedNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        _Evidence(meetingId: data.meetingId, evidence: item.evidence),
      ],
    );
  }
}

/// A left-to-right monospace code block with a language label and a copy
/// button.
class CodeBlock extends StatelessWidget {
  /// Creates the block.
  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    required this.onCopy,
  });

  /// The code (whitespace kept).
  final String code;

  /// Language label shown above the code.
  final String language;

  /// Copies [code].
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const [
        'Cascadia Mono',
        'Consolas',
        'Menlo',
        'Roboto Mono',
        'Courier New',
        'monospace',
      ],
      height: 1.4,
    );
    return Semantics(
      container: true,
      label: KS.codeBlockLabel(language),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        language,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: KS.copyCode,
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  code.trimRight(),
                  style: mono,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Implied speech
// ---------------------------------------------------------------------------

class _ImpliedCard extends StatelessWidget {
  const _ImpliedCard({required this.entry, required this.data});

  final CodeEntry<ImpliedItem> entry;
  final _CodesData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = entry.item;
    return _ItemCard(
      children: [
        _SpeakerLine(data.speakerOf(entry.finding, item.speaker)),
        const SizedBox(height: 6),
        Text(KS.literal(item.literal), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(KS.impliedMeanings, style: theme.textTheme.titleSmall),
            _HypothesisBadge(label: KS.hypothesis, confidence: item.confidence),
          ],
        ),
        for (final m in item.possibleMeanings)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
            child: Text('• $m', style: theme.textTheme.bodyMedium),
          ),
        if (item.basis.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            KS.basis(item.basis),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        _Evidence(meetingId: data.meetingId, evidence: item.evidence),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. References
// ---------------------------------------------------------------------------

class _CheckBadge extends StatelessWidget {
  const _CheckBadge(this.check);

  final ReferenceCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (label, hint, icon, color) = switch (check) {
      ReferenceCheck.verified => (
        KS.verified,
        KS.verifiedHint,
        Icons.verified_outlined,
        scheme.primary,
      ),
      ReferenceCheck.unverified => (
        KS.unverified,
        KS.unverifiedHint,
        Icons.warning_amber_rounded,
        scheme.error,
      ),
      ReferenceCheck.noEvidence => (
        KS.noEvidenceToVerify,
        KS.noEvidenceToVerifyHint,
        Icons.help_outline_rounded,
        scheme.onSurfaceVariant,
      ),
    };
    return Tooltip(
      message: hint,
      child: Semantics(
        label: '$label. $hint',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferencesView extends StatelessWidget {
  const _ReferencesView({required this.entries, required this.data});

  final List<CodeEntry<ReferenceItem>> entries;
  final _CodesData data;

  String _value(ReferenceItem r) =>
      r.normalized.isEmpty ? r.verbatim : r.normalized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checks = [
      for (final e in entries) verifyReference(e.item, data.segments),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCodesTableBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < entries.length; i++)
                _ItemCard(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            KS.referenceKind(entries[i].item.kind),
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        _CheckBadge(checks[i]),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ReferenceValue(item: entries[i].item, value: _value),
                    if (entries[i].item.context.isNotEmpty)
                      Text(
                        entries[i].item.context,
                        style: theme.textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 4),
                    _SpeakerLine(
                      data.speakerOf(
                        entries[i].finding,
                        entries[i].item.speaker,
                      ),
                    ),
                    _Evidence(
                      meetingId: data.meetingId,
                      evidence: entries[i].item.evidence,
                    ),
                  ],
                ),
            ],
          );
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                dataRowMinHeight: 56,
                dataRowMaxHeight: double.infinity,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text(KS.colKind)),
                  DataColumn(label: Text(KS.colValue)),
                  DataColumn(label: Text(KS.colContext)),
                  DataColumn(label: Text(KS.colSpeaker)),
                  DataColumn(label: Text(KS.colCheck)),
                  DataColumn(label: Text(KS.colEvidence)),
                ],
                rows: [
                  for (var i = 0; i < entries.length; i++)
                    DataRow(
                      cells: [
                        DataCell(Text(KS.referenceKind(entries[i].item.kind))),
                        DataCell(
                          _ReferenceValue(item: entries[i].item, value: _value),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(entries[i].item.context),
                          ),
                        ),
                        DataCell(
                          Text(
                            data.speakerOf(
                              entries[i].finding,
                              entries[i].item.speaker,
                            ),
                          ),
                        ),
                        DataCell(_CheckBadge(checks[i])),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: _Evidence(
                              meetingId: data.meetingId,
                              evidence: entries[i].item.evidence,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReferenceValue extends StatelessWidget {
  const _ReferenceValue({required this.item, required this.value});

  final ReferenceItem item;
  final String Function(ReferenceItem) value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value(item);
    final asSaid = item.verbatim.isNotEmpty && item.verbatim != v;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          v,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (asSaid)
          Text(
            KS.asSaid(autoIsolate(item.verbatim)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
