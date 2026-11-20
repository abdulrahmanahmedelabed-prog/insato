// Glossary screen (F2): global custom vocabulary — search, category
// filters, add / edit / delete, plain-text import and export — plus the
// names of user-named speakers (included automatically) and where the
// glossary is used (Deepgram keyterms, minutes prompt).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../data/secure_settings.dart';
import '../../session/providers.dart';
import '../../speech/cloud_asr_engine.dart' show kMaxDeepgramKeyterms;
import '../../ui/services/share_gateway.dart';
import '../../ui/strings_ar.dart';
import '../../ui/ui_providers.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import 'glossary_logic.dart';
import 'glossary_term_dialog.dart';
import 'strings.dart';

enum _MenuAction { export, import }

/// The glossary screen.
class GlossaryScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GlossaryScreen({super.key});

  @override
  ConsumerState<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends ConsumerState<GlossaryScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  GlossaryCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<GlossaryTerm> get _terms =>
      ref.read(globalGlossaryProvider).value ?? const [];

  Future<void> _add() async {
    final draft = await showGlossaryTermDialog(
      context,
      existing: _terms.map(GlossaryDraft.of),
      defaultCategory: _category ?? GlossaryCategory.other,
    );
    if (draft == null) return;
    try {
      await ref
          .read(glossaryRepositoryProvider)
          .add(
            term: draft.term,
            arSpelling: draft.arSpelling,
            category: draft.category,
          );
      if (mounted) showSnack(context, CS.termAdded);
    } catch (_) {
      if (mounted) showSnack(context, CS.saveFailed, error: true);
    }
  }

  Future<void> _edit(GlossaryTerm term) async {
    final draft = await showGlossaryTermDialog(
      context,
      initial: GlossaryDraft.of(term),
      existing: _terms.map(GlossaryDraft.of),
    );
    if (draft == null) return;
    try {
      await ref
          .read(glossaryRepositoryProvider)
          .update(draftAsTerm(draft, createdAt: term.createdAt));
      if (mounted) showSnack(context, CS.termSaved);
    } catch (_) {
      if (mounted) showSnack(context, CS.saveFailed, error: true);
    }
  }

  Future<void> _delete(GlossaryTerm term) async {
    final ok = await showConfirmDialog(
      context,
      title: CS.deleteTermTitle,
      body: CS.deleteTermBody(term.term),
      confirmLabel: S.delete,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    try {
      await ref.read(glossaryRepositoryProvider).delete(term.id);
      if (mounted) showSnack(context, CS.termDeleted);
    } catch (_) {
      if (mounted) showSnack(context, CS.saveFailed, error: true);
    }
  }

  Future<void> _export() async {
    final terms = _terms;
    if (terms.isEmpty) {
      showSnack(context, CS.nothingToExport);
      return;
    }
    try {
      await ref
          .read(shareGatewayProvider)
          .copyText(glossaryToText(terms, label: CS.category));
      if (mounted) showSnack(context, CS.exported(terms.length));
    } catch (_) {
      if (mounted) showSnack(context, S.unexpectedError, error: true);
    }
  }

  Future<void> _import() async {
    final text = await showTextInputDialog(
      context,
      title: CS.importTitle,
      body: CS.importBody,
      label: CS.importFieldLabel,
      confirmLabel: CS.importAction,
      emptyError: CS.importNothing,
      maxLines: 8,
    );
    if (text == null) return;
    final parsed = parseGlossaryText(text);
    if (parsed.drafts.isEmpty) {
      if (mounted) showSnack(context, CS.importNothing, error: true);
      return;
    }
    final repo = ref.read(glossaryRepositoryProvider);
    try {
      for (final d in parsed.drafts) {
        await repo.add(
          term: d.term,
          arSpelling: d.arSpelling,
          category: d.category,
        );
      }
      if (mounted) {
        showSnack(
          context,
          CS.imported(parsed.drafts.length, parsed.invalidLines.length),
        );
      }
    } catch (_) {
      if (mounted) showSnack(context, CS.saveFailed, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glossary = ref.watch(globalGlossaryProvider);
    final speakers = ref.watch(speakersProvider).value ?? const <Speaker>[];
    final settings = ref.watch(settingsSnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(CS.glossaryTitle),
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: CS.glossaryMenu,
            onSelected: (a) => switch (a) {
              _MenuAction.export => _export(),
              _MenuAction.import => _import(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _MenuAction.export,
                child: ListTile(
                  leading: Icon(Icons.copy_all_rounded),
                  title: Text(CS.exportList),
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.import,
                child: ListTile(
                  leading: Icon(Icons.playlist_add_rounded),
                  title: Text(CS.importList),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'glossary-add',
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text(CS.addTerm),
      ),
      body: glossary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: S.unexpectedError,
            onRetry: () => ref.invalidate(globalGlossaryProvider),
          ),
        ),
        data: (terms) => _body(context, terms, speakers, settings),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<GlossaryTerm> terms,
    List<Speaker> speakers,
    AppSettingsData settings,
  ) {
    final theme = Theme.of(context);
    final named = [
      for (final s in speakers)
        if (s.isNamedByUser && s.name.trim().isNotEmpty) s,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final filtered = filterGlossary(terms, query: _query, category: _category);
    final groups = groupGlossary(filtered);
    final children = <Widget>[
      Text(
        CS.glossaryIntro,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      GlossaryUsageCard(
        terms: terms,
        speakers: speakers,
        cloudAsr: !settings.usesLocalAsr,
      ),
      const SizedBox(height: 12),
    ];
    if (terms.isEmpty) {
      children.add(
        const EmptyState(
          icon: Icons.spellcheck_rounded,
          title: CS.emptyTitle,
          body: CS.emptyBody,
        ),
      );
    } else {
      children
        ..add(
          SearchBar(
            controller: _search,
            hintText: CS.searchHint,
            leading: const Icon(Icons.search_rounded),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: CS.clearSearch,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
          ),
        )
        ..add(const SizedBox(height: 8))
        ..add(
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text(CS.allCategories),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              for (final c in GlossaryCategory.values)
                FilterChip(
                  avatar: Icon(glossaryCategoryIcon(c), size: 18),
                  label: Text(CS.category(c)),
                  selected: _category == c,
                  onSelected: (sel) =>
                      setState(() => _category = sel ? c : null),
                ),
            ],
          ),
        );
      if (groups.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              CS.noResults,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        );
      }
      for (final e in groups.entries) {
        children.add(
          SectionHeader(
            CS.categoryCount(CS.category(e.key), e.value.length),
            icon: glossaryCategoryIcon(e.key),
          ),
        );
        for (final t in e.value) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GlossaryTermTile(
                term: t,
                onEdit: () => _edit(t),
                onDelete: () => _delete(t),
              ),
            ),
          );
        }
      }
    }
    if (named.isNotEmpty) {
      children
        ..add(
          const SectionHeader(
            CS.speakerNamesHeader,
            icon: Icons.record_voice_over_rounded,
          ),
        )
        ..add(
          Text(
            CS.speakerNamesBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        )
        ..add(const SizedBox(height: 8))
        ..add(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in named)
                Chip(
                  avatar: const Icon(Icons.person_rounded, size: 18),
                  label: Text(s.name),
                ),
            ],
          ),
        );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
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
}

/// One term: tap to edit, delete button.
class GlossaryTermTile extends StatelessWidget {
  /// Creates the tile.
  const GlossaryTermTile({
    super.key,
    required this.term,
    required this.onEdit,
    required this.onDelete,
  });

  /// The term.
  final GlossaryTerm term;

  /// Edit callback.
  final VoidCallback onEdit;

  /// Delete callback.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
        leading: Icon(
          glossaryCategoryIcon(term.category),
          color: theme.colorScheme.primary,
        ),
        title: Text(term.term, style: theme.textTheme.titleMedium),
        subtitle: term.arSpelling == null ? null : Text(term.arSpelling!),
        onTap: onEdit,
        trailing: IconButton(
          tooltip: S.delete,
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

/// Explains where the glossary goes: the Deepgram keyterm list (with its
/// limit) and the minutes prompt.
class GlossaryUsageCard extends StatelessWidget {
  /// Creates the card.
  const GlossaryUsageCard({
    super.key,
    required this.terms,
    required this.speakers,
    required this.cloudAsr,
  });

  /// Global terms.
  final List<GlossaryTerm> terms;

  /// All speakers (named ones are part of the glossary).
  final List<Speaker> speakers;

  /// True when cloud ASR (Deepgram) is the selected recogniser.
  final bool cloudAsr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = buildDeepgramKeyterms(
      speakers: speakers,
      globalTerms: terms,
      limit: 1 << 30,
    );
    final sent = all.length < kMaxDeepgramKeyterms
        ? all.length
        : kMaxDeepgramKeyterms;
    final effective = mergeGlossary(terms, const [], speakers: speakers);
    final lines = [
      cloudAsr
          ? CS.deepgramUsage(sent, all.length, kMaxDeepgramKeyterms)
          : CS.deepgramOff,
      CS.minutesUsage(effective.length),
    ];
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      CS.usageHeader,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l, style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
