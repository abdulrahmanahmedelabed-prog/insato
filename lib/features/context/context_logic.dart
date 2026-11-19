// Pure logic of the meeting context (F3): the result of the context sheet,
// agenda / attendee list editing and attendee suggestions from the voice
// library. No Flutter imports; unit-tested in test/features/context/.

import '../../core/models.dart';
import '../../data/repositories.dart' show normalizeMeetingContext;
import '../../data/repositories_v11.dart' show normalizedKey;
import 'glossary_logic.dart';

/// Maximum agenda items.
const int kMaxAgendaItems = 40;

/// Longest agenda item (characters).
const int kMaxAgendaItemLength = 300;

/// Maximum expected attendees.
const int kMaxExpectedAttendees = 60;

/// Longest attendee name (characters).
const int kMaxAttendeeNameLength = 80;

/// Longest context notes (characters).
const int kMaxContextNotesLength = 4000;

/// Maximum meeting-only glossary terms.
const int kMaxMeetingTerms = 40;

/// Longest meeting title (characters).
const int kMaxMeetingTitleLength = 120;

/// What the context sheet returns: an optional title, the [context] to store
/// on the meeting and its meeting-only glossary terms.
class MeetingSetup {
  /// Creates a setup.
  const MeetingSetup({
    this.title,
    this.context = MeetingContext.empty,
    this.meetingTerms = const [],
  });

  /// Nothing entered.
  static const MeetingSetup empty = MeetingSetup();

  /// Meeting title (null / blank = default title).
  final String? title;

  /// Agenda, expected attendees, notes.
  final MeetingContext context;

  /// Meeting-only glossary terms (F3 → F2).
  final List<GlossaryDraft> meetingTerms;

  /// Trimmed title or null.
  String? get trimmedTitle {
    final t = title == null ? '' : collapseSpaces(title!);
    return t.isEmpty ? null : t;
  }

  /// True when nothing was entered.
  bool get isEmpty =>
      trimmedTitle == null && context.isEmpty && meetingTerms.isEmpty;

  /// Normalised copy: trimmed fields, blank items dropped, limits applied,
  /// duplicate attendees / terms removed.
  MeetingSetup normalized() {
    final ctx = normalizeMeetingContext(context);
    final agenda = [for (final a in ctx.agenda) collapseSpaces(a)]
        .where((a) => a.isNotEmpty)
        .take(kMaxAgendaItems)
        .toList(growable: false);
    final attendees = <String>[];
    for (final a in ctx.expectedAttendees) {
      addUniqueName(attendees, a);
    }
    final terms = <String, GlossaryDraft>{};
    for (final d in meetingTerms) {
      final n = d.normalized();
      if (validateGlossaryDraft(n) != null) continue;
      terms.putIfAbsent(n.key, () => n);
    }
    final notes = ctx.contextNotes;
    return MeetingSetup(
      title: trimmedTitle,
      context: MeetingContext(
        agenda: agenda,
        expectedAttendees: attendees,
        contextNotes: notes == null || notes.length <= kMaxContextNotesLength
            ? notes
            : notes.substring(0, kMaxContextNotesLength),
        template: ctx.template,
      ),
      meetingTerms: terms.values.take(kMaxMeetingTerms).toList(growable: false),
    );
  }
}

/// Moves the item at [oldIndex] so that it ends up at [newIndex] (the
/// convention of Flutter's `ReorderableListView.onReorderItem`: the index in
/// the resulting list). Returns a new list; an out of range [oldIndex]
/// leaves it unchanged and [newIndex] is clamped.
List<T> reorderItems<T>(List<T> items, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= items.length) return List<T>.of(items);
  final target = newIndex.clamp(0, items.length - 1);
  final out = List<T>.of(items);
  final item = out.removeAt(oldIndex);
  out.insert(target, item);
  return out;
}

/// Moves the item at [index] one place up (-1) or down (+1). Returns a new
/// list; a move past either end leaves it unchanged.
List<T> moveItem<T>(List<T> items, int index, int delta) {
  final to = index + delta;
  if (index < 0 || index >= items.length || to < 0 || to >= items.length) {
    return List<T>.of(items);
  }
  final out = List<T>.of(items);
  final item = out.removeAt(index);
  out.insert(to, item);
  return out;
}

/// Why a name could not be added to the attendees.
enum AddNameResult {
  /// Added.
  added,

  /// Blank or too long.
  invalid,

  /// Already listed (same key).
  duplicate,

  /// [kMaxExpectedAttendees] reached.
  full,
}

/// Adds [name] (trimmed, whitespace collapsed) to [names] in place unless it
/// is blank, too long, already listed or the list is full.
AddNameResult addUniqueName(List<String> names, String name) {
  final n = collapseSpaces(name);
  if (n.isEmpty || n.length > kMaxAttendeeNameLength) {
    return AddNameResult.invalid;
  }
  final key = normalizedKey(n);
  if (names.any((e) => normalizedKey(e) == key)) return AddNameResult.duplicate;
  if (names.length >= kMaxExpectedAttendees) return AddNameResult.full;
  names.add(n);
  return AddNameResult.added;
}

/// Names of user-named [speakers] (voice library) that are not yet in
/// [chosen] and match [query] ([matchesQuery]); speakers with a voiceprint
/// first, then alphabetically. At most [limit].
List<Speaker> attendeeSuggestions(
  Iterable<Speaker> speakers, {
  Iterable<String> chosen = const [],
  String query = '',
  int limit = 8,
}) {
  final taken = {for (final c in chosen) normalizedKey(c)};
  final seen = <String>{};
  final out = <Speaker>[];
  for (final s in speakers) {
    if (!s.isNamedByUser) continue;
    final key = normalizedKey(s.name);
    if (key.isEmpty || taken.contains(key) || !seen.add(key)) continue;
    if (!matchesQuery(s.name, query)) continue;
    out.add(s);
  }
  out.sort((a, b) {
    final va = a.centroid != null, vb = b.centroid != null;
    if (va != vb) return va ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return out.take(limit).toList(growable: false);
}

/// True when [a] and [b] would store the same thing (after normalisation).
bool sameSetup(MeetingSetup a, MeetingSetup b) {
  final x = a.normalized(), y = b.normalized();
  if (x.trimmedTitle != y.trimmedTitle || x.context != y.context) return false;
  if (x.meetingTerms.length != y.meetingTerms.length) return false;
  for (var i = 0; i < x.meetingTerms.length; i++) {
    final p = x.meetingTerms[i], q = y.meetingTerms[i];
    if (p.term != q.term ||
        p.arSpelling != q.arSpelling ||
        p.category != q.category) {
      return false;
    }
  }
  return true;
}
