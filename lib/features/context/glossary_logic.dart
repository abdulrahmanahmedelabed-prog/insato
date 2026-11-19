// Pure logic of the glossary (F2): drafts and validation, search with
// Arabic normalisation, plain-text export / import, the Deepgram keyterm
// list and the meeting-only term synchronisation plan (F3). No Flutter
// imports; unit-tested in test/features/context/.

import '../../core/models.dart';
import '../../data/repositories_v11.dart' show normalizedKey;
import '../../speech/cloud_asr_engine.dart' show kMaxDeepgramKeyterms;

/// Longest accepted glossary term (characters).
const int kMaxGlossaryTermLength = 100;

/// Longest accepted Arabic spelling / translation (characters).
const int kMaxGlossarySpellingLength = 150;

/// Collapses inner whitespace and trims.
String collapseSpaces(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// An edited, not yet stored glossary term. [id] is the stored term being
/// edited (null for a new one).
class GlossaryDraft {
  /// Creates a draft.
  const GlossaryDraft({
    required this.term,
    this.arSpelling,
    this.category = GlossaryCategory.other,
    this.id,
  });

  /// Draft of an existing [t].
  factory GlossaryDraft.of(GlossaryTerm t) => GlossaryDraft(
    id: t.id == 0 ? null : t.id,
    term: t.term,
    arSpelling: t.arSpelling,
    category: t.category,
  );

  /// Stored id, or null for a new term.
  final int? id;

  /// The term (canonical spelling).
  final String term;

  /// Optional Arabic spelling / translation.
  final String? arSpelling;

  /// Category.
  final GlossaryCategory category;

  /// Trimmed copy: whitespace collapsed, blank spelling → null.
  GlossaryDraft normalized() {
    final ar = arSpelling == null ? '' : collapseSpaces(arSpelling!);
    return GlossaryDraft(
      id: id,
      term: collapseSpaces(term),
      arSpelling: ar.isEmpty ? null : ar,
      category: category,
    );
  }

  /// Comparison key of the term.
  String get key => normalizedKey(term);

  @override
  bool operator ==(Object other) =>
      other is GlossaryDraft &&
      other.id == id &&
      other.term == term &&
      other.arSpelling == arSpelling &&
      other.category == category;

  @override
  int get hashCode => Object.hash(id, term, arSpelling, category);

  @override
  String toString() => 'GlossaryDraft($id, $term, $arSpelling, $category)';
}

/// Why a draft cannot be saved.
enum GlossaryDraftError {
  /// The term is blank.
  empty,

  /// The term or its spelling is too long.
  tooLong,

  /// Another term in the same scope has the same key.
  duplicate,
}

/// Validates [draft] against the terms already in its scope ([existing]).
/// A term with the same key is a duplicate unless it is the term being
/// edited (`draft.id`). Returns null when the draft can be saved.
GlossaryDraftError? validateGlossaryDraft(
  GlossaryDraft draft, {
  Iterable<GlossaryDraft> existing = const [],
}) {
  final d = draft.normalized();
  if (d.term.isEmpty) return GlossaryDraftError.empty;
  if (d.term.length > kMaxGlossaryTermLength ||
      (d.arSpelling?.length ?? 0) > kMaxGlossarySpellingLength) {
    return GlossaryDraftError.tooLong;
  }
  final key = d.key;
  for (final e in existing) {
    if (draft.id != null && e.id == draft.id) continue;
    if (identical(e, draft)) continue;
    if (normalizedKey(e.term) == key) return GlossaryDraftError.duplicate;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

final RegExp _arabicMarks = RegExp('[ؐ-ًؚ-ٰٟـ]');

/// Search key: lower-cased, Arabic diacritics and tatweel removed, alef
/// forms unified, alef maqsura → ya, ta marbuta → ha, whitespace collapsed.
String searchKey(String s) => collapseSpaces(
  s
      .toLowerCase()
      .replaceAll(_arabicMarks, '')
      .replaceAll(RegExp('[آأإٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه'),
);

/// True when [query] (normalised) occurs in [text] (normalised). A blank
/// query matches everything.
bool matchesQuery(String text, String query) {
  final q = searchKey(query);
  return q.isEmpty || searchKey(text).contains(q);
}

/// Terms matching [query] (in the term or its Arabic spelling) and, when
/// given, [category]; input order kept.
List<GlossaryTerm> filterGlossary(
  Iterable<GlossaryTerm> terms, {
  String query = '',
  GlossaryCategory? category,
}) => [
  for (final t in terms)
    if ((category == null || t.category == category) &&
        (matchesQuery(t.term, query) ||
            (t.arSpelling != null && matchesQuery(t.arSpelling!, query))))
      t,
];

/// Terms grouped by category in [GlossaryCategory.values] order, each group
/// sorted case-insensitively; empty groups omitted.
Map<GlossaryCategory, List<GlossaryTerm>> groupGlossary(
  Iterable<GlossaryTerm> terms,
) {
  final out = <GlossaryCategory, List<GlossaryTerm>>{};
  for (final c in GlossaryCategory.values) {
    final group = [
      for (final t in terms)
        if (t.category == c) t,
    ]..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
    if (group.isNotEmpty) out[c] = group;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Plain-text export / import
// ---------------------------------------------------------------------------

/// Words accepted for each category in imported text (normalised with
/// [searchKey]); the stored wire value and the Arabic label always work.
const Map<GlossaryCategory, List<String>> _categoryAliases = {
  GlossaryCategory.person: ['person', 'شخص', 'اسم', 'أشخاص'],
  GlossaryCategory.organisation: [
    'organisation',
    'organization',
    'org',
    'جهة',
    'جهات',
    'مؤسسة',
    'شركة',
  ],
  GlossaryCategory.technical: [
    'technical',
    'tech',
    'مصطلح تقني',
    'تقني',
    'تقنية',
    'مصطلح',
  ],
  GlossaryCategory.other: ['other', 'أخرى', 'اخرى', 'غير ذلك'],
};

/// Parses a category word of imported text; null when unknown.
GlossaryCategory? parseCategoryWord(String word) {
  final k = searchKey(word);
  if (k.isEmpty) return null;
  for (final e in _categoryAliases.entries) {
    if (e.value.any((a) => searchKey(a) == k)) return e.key;
  }
  return null;
}

/// Renders [terms] one per line as `term | Arabic spelling | category`
/// (Arabic category label); the inverse of [parseGlossaryText]. Pipes inside
/// fields are replaced by slashes so every line stays parseable.
String glossaryToText(
  Iterable<GlossaryTerm> terms, {
  String Function(GlossaryCategory) label = _defaultLabel,
}) {
  String clean(String s) => collapseSpaces(s.replaceAll('|', '/'));
  return [
    for (final t in terms)
      '${clean(t.term)} | ${clean(t.arSpelling ?? '')} | ${label(t.category)}',
  ].join('\n');
}

String _defaultLabel(GlossaryCategory c) => _categoryAliases[c]![1];

/// Result of [parseGlossaryText].
class GlossaryImport {
  /// Creates a result.
  const GlossaryImport({required this.drafts, required this.invalidLines});

  /// Valid drafts, duplicates (by key) merged — the last line wins.
  final List<GlossaryDraft> drafts;

  /// 1-based numbers of non-blank, non-comment lines that were rejected.
  final List<int> invalidLines;
}

/// Parses pasted text: one term per line, fields separated by `|` or a tab:
/// `term`, optional Arabic spelling, optional category ([parseCategoryWord];
/// unknown → [defaultCategory]). Blank lines and lines starting with `#`
/// are ignored; a blank or too long term rejects the line.
GlossaryImport parseGlossaryText(
  String text, {
  GlossaryCategory defaultCategory = GlossaryCategory.other,
}) {
  final byKey = <String, GlossaryDraft>{};
  final invalid = <int>[];
  final lines = text.split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(RegExp(r'\s*[|\t]\s*'));
    final draft = GlossaryDraft(
      term: parts[0],
      arSpelling: parts.length > 1 ? parts[1] : null,
      category: parts.length > 2
          ? (parseCategoryWord(parts[2]) ?? defaultCategory)
          : defaultCategory,
    ).normalized();
    if (validateGlossaryDraft(draft) != null) {
      invalid.add(i + 1);
      continue;
    }
    byKey.remove(draft.key);
    byKey[draft.key] = draft;
  }
  return GlossaryImport(
    drafts: byKey.values.toList(growable: false),
    invalidLines: invalid,
  );
}

// ---------------------------------------------------------------------------
// Deepgram keyterms (F2 use 1)
// ---------------------------------------------------------------------------

/// The `keyterm` list sent to Deepgram, at most [limit] entries, without
/// duplicates (case- and whitespace-insensitive). Priority, because Deepgram
/// only accepts a limited number: this meeting's terms, its expected
/// attendees, the names of user-named [speakers], global terms; then, while
/// room remains, the Arabic spellings of those terms (helpful when the
/// meeting is in Arabic).
List<String> buildDeepgramKeyterms({
  Iterable<GlossaryTerm> meetingTerms = const [],
  Iterable<String> expectedAttendees = const [],
  Iterable<Speaker> speakers = const [],
  Iterable<GlossaryTerm> globalTerms = const [],
  int limit = kMaxDeepgramKeyterms,
}) {
  final seen = <String>{};
  final out = <String>[];
  void add(String? s) {
    if (s == null || out.length >= limit) return;
    final t = collapseSpaces(s);
    if (t.isEmpty || t.length > kMaxGlossaryTermLength) return;
    if (seen.add(normalizedKey(t))) out.add(t);
  }

  final terms = [...meetingTerms];
  for (final t in terms) {
    add(t.term);
  }
  expectedAttendees.forEach(add);
  for (final s in speakers) {
    if (s.isNamedByUser) add(s.name);
  }
  final global = [...globalTerms];
  for (final t in global) {
    add(t.term);
  }
  for (final t in [...terms, ...global]) {
    add(t.arSpelling);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Meeting-only terms (F3)
// ---------------------------------------------------------------------------

/// A not yet stored [draft] as a [GlossaryTerm] (id 0 unless it has one),
/// e.g. to preview what a meeting's glossary will contain.
GlossaryTerm draftAsTerm(
  GlossaryDraft draft, {
  String? meetingId,
  required DateTime createdAt,
}) {
  final d = draft.normalized();
  return GlossaryTerm(
    id: d.id ?? 0,
    term: d.term,
    arSpelling: d.arSpelling,
    category: d.category,
    meetingId: meetingId,
    createdAt: createdAt,
  );
}

/// Changes that make a meeting's stored terms equal a desired list.
class MeetingTermSyncPlan {
  /// Creates a plan.
  const MeetingTermSyncPlan({
    this.add = const [],
    this.update = const [],
    this.delete = const [],
  });

  /// New terms to insert.
  final List<GlossaryDraft> add;

  /// Stored terms with changed fields (id kept).
  final List<GlossaryTerm> update;

  /// Ids of stored terms to delete.
  final List<int> delete;

  /// True when nothing changes.
  bool get isEmpty => add.isEmpty && update.isEmpty && delete.isEmpty;
}

/// Plans the synchronisation of a meeting's [existing] terms to [desired].
/// A desired draft matches a stored term by id, otherwise by key; blank or
/// invalid drafts are ignored and duplicates (by key) collapse to the last.
MeetingTermSyncPlan planMeetingTermSync(
  List<GlossaryTerm> existing,
  List<GlossaryDraft> desired,
) {
  final wanted = <String, GlossaryDraft>{};
  for (final d in desired) {
    final n = d.normalized();
    if (validateGlossaryDraft(n) != null) continue;
    wanted.remove(n.key);
    wanted[n.key] = n;
  }
  final byId = {for (final e in existing) e.id: e};
  final byKey = {for (final e in existing) normalizedKey(e.term): e};
  final kept = <int>{};
  final add = <GlossaryDraft>[];
  final update = <GlossaryTerm>[];
  for (final d in wanted.values) {
    var match = d.id == null ? null : byId[d.id];
    if (match == null || kept.contains(match.id)) match = byKey[d.key];
    if (match == null || kept.contains(match.id)) {
      add.add(d);
      continue;
    }
    kept.add(match.id);
    if (match.term != d.term ||
        match.arSpelling != d.arSpelling ||
        match.category != d.category) {
      update.add(
        GlossaryTerm(
          id: match.id,
          term: d.term,
          arSpelling: d.arSpelling,
          category: d.category,
          meetingId: match.meetingId,
          createdAt: match.createdAt,
        ),
      );
    }
  }
  return MeetingTermSyncPlan(
    add: add,
    update: update,
    delete: [
      for (final e in existing)
        if (!kept.contains(e.id)) e.id,
    ],
  );
}
