// Meeting context form (F3): title, agenda (reorderable by drag or by the
// up / down buttons), expected attendees (from the voice library or typed),
// background notes and meeting-only glossary terms (F2). Shown full screen
// before recording ("اجتماع جديد") and for editing an existing meeting.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import 'context_logic.dart';
import 'glossary_logic.dart';
import 'glossary_term_dialog.dart';
import 'strings.dart';

/// Where the context form is shown.
enum MeetingContextMode {
  /// Before recording: "start" and "start without context" buttons.
  beforeStart,

  /// Editing an existing meeting: a "save" button.
  edit,
}

/// Opens the context form full screen. Returns the normalised setup — for
/// [MeetingContextMode.beforeStart], [MeetingSetup.empty] when the user
/// chose "start without context" — or null when the user closed it.
Future<MeetingSetup?> showMeetingContextPage(
  BuildContext context, {
  MeetingSetup initial = MeetingSetup.empty,
  MeetingContextMode mode = MeetingContextMode.beforeStart,
}) => Navigator.of(context).push<MeetingSetup>(
  MaterialPageRoute<MeetingSetup>(
    fullscreenDialog: true,
    builder: (_) => MeetingContextPage(initial: initial, mode: mode),
  ),
);

/// The context form page.
class MeetingContextPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const MeetingContextPage({
    super.key,
    this.initial = MeetingSetup.empty,
    this.mode = MeetingContextMode.beforeStart,
  });

  /// Values to start from.
  final MeetingSetup initial;

  /// Before start or editing.
  final MeetingContextMode mode;

  @override
  ConsumerState<MeetingContextPage> createState() => _MeetingContextPageState();
}

class _MeetingContextPageState extends ConsumerState<MeetingContextPage> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial.context.contextNotes ?? '',
  );
  final TextEditingController _agendaInput = TextEditingController();
  final TextEditingController _attendeeInput = TextEditingController();
  final FocusNode _agendaFocus = FocusNode();
  final FocusNode _attendeeFocus = FocusNode();
  int _nextAgendaId = 0;
  late List<_AgendaEntry> _agenda = [
    for (final a in widget.initial.context.agenda)
      _AgendaEntry(_nextAgendaId++, a),
  ];
  late final List<String> _attendees = List.of(
    widget.initial.context.expectedAttendees,
  );
  late List<GlossaryDraft> _terms = List.of(widget.initial.meetingTerms);
  String? _agendaError;
  String? _attendeeError;
  bool _closing = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _agendaInput.dispose();
    _attendeeInput.dispose();
    _agendaFocus.dispose();
    _attendeeFocus.dispose();
    super.dispose();
  }

  MeetingSetup get _current => MeetingSetup(
    title: _title.text,
    context: widget.initial.context.copyWith(
      agenda: [for (final a in _agenda) a.text],
      expectedAttendees: _attendees,
      contextNotes: _notes.text,
      clearContextNotes: _notes.text.trim().isEmpty,
    ),
    meetingTerms: _terms,
  );

  bool get _dirty => !sameSetup(_current, widget.initial);

  void _finish(MeetingSetup? result) {
    _closing = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _maybeClose() async {
    if (!_dirty) {
      _finish(null);
      return;
    }
    final discard = await showConfirmDialog(
      context,
      title: CS.discardTitle,
      body: CS.discardBody,
      confirmLabel: CS.discard,
      destructive: true,
    );
    if (discard && mounted) _finish(null);
  }

  // --- Agenda -----------------------------------------------------------------

  void _addAgendaItem() {
    final text = collapseSpaces(_agendaInput.text);
    if (text.isEmpty) {
      setState(() => _agendaError = CS.agendaItemEmpty);
      return;
    }
    if (_agenda.length >= kMaxAgendaItems) {
      setState(() => _agendaError = CS.agendaFull(kMaxAgendaItems));
      return;
    }
    setState(() {
      _agenda = [..._agenda, _AgendaEntry(_nextAgendaId++, text)];
      _agendaError = null;
      _agendaInput.clear();
    });
    _agendaFocus.requestFocus();
  }

  Future<void> _editAgendaItem(int i) async {
    final text = await showTextInputDialog(
      context,
      title: CS.editAgendaItem,
      initialValue: _agenda[i].text,
      label: CS.agendaHeader,
      emptyError: CS.agendaItemEmpty,
      maxLines: 3,
    );
    if (text == null || !mounted) return;
    final t = collapseSpaces(text);
    if (t.isEmpty) return;
    setState(
      () => _agenda = [..._agenda]..[i] = _AgendaEntry(_agenda[i].id, t),
    );
  }

  // --- Attendees --------------------------------------------------------------

  void _addAttendee(String name) {
    final result = addUniqueName(_attendees, name);
    setState(() {
      _attendeeError = switch (result) {
        AddNameResult.added => null,
        AddNameResult.invalid => S.nameEmpty,
        AddNameResult.duplicate => CS.attendeeDuplicate,
        AddNameResult.full => CS.attendeesFull(kMaxExpectedAttendees),
      };
      if (result == AddNameResult.added) _attendeeInput.clear();
    });
  }

  // --- Meeting terms ----------------------------------------------------------

  Future<void> _editTerm([int? index]) async {
    if (index == null && _terms.length >= kMaxMeetingTerms) return;
    final draft = await showGlossaryTermDialog(
      context,
      initial: index == null ? null : _terms[index],
      existing: _terms,
    );
    if (draft == null || !mounted) return;
    setState(() {
      _terms = index == null
          ? [..._terms, draft]
          : ([..._terms]..[index] = draft);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final before = widget.mode == MeetingContextMode.beforeStart;
    final speakers = ref.watch(speakersProvider).value ?? const <Speaker>[];
    return PopScope<MeetingSetup>(
      canPop: _closing || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: S.close,
            icon: const Icon(Icons.close_rounded),
            onPressed: _maybeClose,
          ),
          title: Text(before ? CS.setupTitle : CS.editTitle),
          actions: [
            if (!before)
              TextButton(
                onPressed: () => _finish(_current.normalized()),
                child: const Text(S.save),
              ),
          ],
        ),
        bottomNavigationBar: before
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _finish(MeetingSetup.empty),
                        child: const Text(CS.skipAndStart),
                      ),
                      FilledButton.icon(
                        onPressed: () => _finish(_current.normalized()),
                        icon: const Icon(Icons.mic_rounded),
                        label: const Text(CS.startRecording),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ReadableWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    before ? CS.setupIntro : CS.editIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _title,
                    maxLength: kMaxMeetingTitleLength,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: before ? CS.titleLabel : S.meetingTitleLabel,
                      hintText: CS.titleHint,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  ..._agendaSection(theme),
                  ..._attendeesSection(theme, speakers),
                  const SectionHeader(
                    CS.notesHeader,
                    icon: Icons.sticky_note_2_outlined,
                  ),
                  TextField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: kMaxContextNotesLength,
                    decoration: const InputDecoration(
                      labelText: CS.notesLabel,
                      hintText: CS.notesHint,
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  ..._termsSection(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _agendaSection(ThemeData theme) => [
    SectionHeader(
      CS.agendaHeader,
      icon: Icons.format_list_numbered_rounded,
      trailing: Text(
        '${_agenda.length}/$kMaxAgendaItems',
        style: theme.textTheme.labelMedium,
      ),
    ),
    if (_agenda.isEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(CS.agendaEmpty, style: theme.textTheme.bodyMedium),
      )
    else
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorderItem: (o, n) =>
            setState(() => _agenda = reorderItems(_agenda, o, n)),
        children: [
          for (var i = 0; i < _agenda.length; i++)
            AgendaItemTile(
              key: ValueKey(_agenda[i].id),
              index: i,
              total: _agenda.length,
              text: _agenda[i].text,
              onMove: (d) => setState(() => _agenda = moveItem(_agenda, i, d)),
              onEdit: () => _editAgendaItem(i),
              onRemove: () =>
                  setState(() => _agenda = [..._agenda]..removeAt(i)),
            ),
        ],
      ),
    const SizedBox(height: 8),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _agendaInput,
            focusNode: _agendaFocus,
            maxLength: kMaxAgendaItemLength,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: CS.agendaItemLabel,
              hintText: CS.agendaItemHint,
              errorText: _agendaError,
            ),
            onSubmitted: (_) => _addAgendaItem(),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.filledTonal(
            tooltip: CS.addAgendaItem,
            icon: const Icon(Icons.add_rounded),
            onPressed: _addAgendaItem,
          ),
        ),
      ],
    ),
  ];

  List<Widget> _attendeesSection(ThemeData theme, List<Speaker> speakers) {
    final suggestions = attendeeSuggestions(
      speakers,
      chosen: _attendees,
      query: _attendeeInput.text,
    );
    return [
      SectionHeader(
        CS.attendeesHeader,
        icon: Icons.groups_rounded,
        trailing: Text(
          '${_attendees.length}',
          style: theme.textTheme.labelMedium,
        ),
      ),
      if (_attendees.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(CS.attendeesEmpty, style: theme.textTheme.bodyMedium),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in _attendees)
              InputChip(
                avatar: const Icon(Icons.person_rounded, size: 18),
                label: Text(a),
                deleteButtonTooltipMessage: CS.removeAttendee(a),
                onDeleted: () => setState(() => _attendees.remove(a)),
              ),
          ],
        ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _attendeeInput,
              focusNode: _attendeeFocus,
              maxLength: kMaxAttendeeNameLength,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: CS.attendeeLabel,
                hintText: CS.attendeeHint,
                errorText: _attendeeError,
              ),
              onChanged: (_) => setState(() => _attendeeError = null),
              onSubmitted: (v) {
                _addAttendee(v);
                _attendeeFocus.requestFocus();
              },
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton.filledTonal(
              tooltip: CS.addAttendee,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => _addAttendee(_attendeeInput.text),
            ),
          ),
        ],
      ),
      if (suggestions.isNotEmpty) ...[
        Text(CS.fromVoiceLibrary, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggestions)
              ActionChip(
                avatar: Icon(
                  s.centroid != null
                      ? Icons.fingerprint_rounded
                      : Icons.person_outline_rounded,
                  size: 18,
                ),
                label: Text(s.name),
                onPressed: () => _addAttendee(s.name),
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _termsSection(ThemeData theme) => [
    SectionHeader(
      CS.meetingTermsHeader,
      icon: Icons.spellcheck_rounded,
      trailing: Text(
        '${_terms.length}/$kMaxMeetingTerms',
        style: theme.textTheme.labelMedium,
      ),
    ),
    Text(
      CS.meetingTermsBody,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 8),
    if (_terms.isEmpty)
      Text(CS.meetingTermsEmpty, style: theme.textTheme.bodyMedium)
    else
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _terms.length; i++)
            InputChip(
              avatar: Icon(glossaryCategoryIcon(_terms[i].category), size: 18),
              label: Text(
                _terms[i].arSpelling == null
                    ? _terms[i].term
                    : '${_terms[i].term} — ${_terms[i].arSpelling}',
              ),
              tooltip: CS.editTerm,
              onPressed: () => _editTerm(i),
              deleteButtonTooltipMessage: CS.removeTerm(_terms[i].term),
              onDeleted: () =>
                  setState(() => _terms = [..._terms]..removeAt(i)),
            ),
        ],
      ),
    const SizedBox(height: 8),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        onPressed: _terms.length >= kMaxMeetingTerms ? null : _editTerm,
        icon: const Icon(Icons.add_rounded),
        label: const Text(CS.addMeetingTerm),
      ),
    ),
  ];
}

/// An agenda item with a stable id (list key across reorders).
class _AgendaEntry {
  const _AgendaEntry(this.id, this.text);

  final int id;
  final String text;
}

/// One agenda item: number, text, drag handle and accessible move / edit /
/// remove buttons.
class AgendaItemTile extends StatelessWidget {
  /// Creates the tile.
  const AgendaItemTile({
    super.key,
    required this.index,
    required this.total,
    required this.text,
    required this.onMove,
    required this.onEdit,
    required this.onRemove,
  });

  /// Position (0-based).
  final int index;

  /// Number of items.
  final int total;

  /// Item text.
  final String text;

  /// Moves the item by -1 / +1.
  final ValueChanged<int> onMove;

  /// Edits the text.
  final VoidCallback onEdit;

  /// Removes the item.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 4),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Tooltip(
                message: CS.dragToReorder,
                child: SizedBox(
                  width: 40,
                  height: 48,
                  child: Icon(Icons.drag_indicator_rounded),
                ),
              ),
            ),
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                label: CS.agendaItemSemantics(index + 1, total, text),
                hint: CS.editAgendaItem,
                button: true,
                excludeSemantics: true,
                onTap: onEdit,
                child: InkWell(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(text, style: theme.textTheme.bodyLarge),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: CS.moveUp,
              icon: const Icon(Icons.arrow_upward_rounded),
              onPressed: index == 0 ? null : () => onMove(-1),
            ),
            IconButton(
              tooltip: CS.moveDown,
              icon: const Icon(Icons.arrow_downward_rounded),
              onPressed: index == total - 1 ? null : () => onMove(1),
            ),
            IconButton(
              tooltip: CS.removeAgendaItem,
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
