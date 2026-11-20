import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/context/glossary_logic.dart';
import 'package:insato/features/context/strings.dart';

GlossaryTerm term(
  int id,
  String t, {
  String? ar,
  GlossaryCategory c = GlossaryCategory.other,
  String? meetingId,
}) => GlossaryTerm(
  id: id,
  term: t,
  arSpelling: ar,
  category: c,
  meetingId: meetingId,
  createdAt: DateTime(2026, 11, 19),
);

Speaker speaker(String name, {bool named = true}) => Speaker(
  id: name,
  name: name,
  colorValue: 0,
  isNamedByUser: named,
  createdAt: DateTime(2026),
);

void main() {
  group('GlossaryDraft', () {
    test('normalized collapses whitespace and drops a blank spelling', () {
      final d = const GlossaryDraft(
        term: '  Open   AI ',
        arSpelling: '   ',
      ).normalized();
      expect(d.term, 'Open AI');
      expect(d.arSpelling, isNull);
      expect(d.key, 'open ai');
    });

    test('of() keeps the id except the synthetic speaker id 0', () {
      expect(GlossaryDraft.of(term(5, 'X')).id, 5);
      expect(GlossaryDraft.of(term(0, 'X')).id, isNull);
    });
  });

  group('validateGlossaryDraft', () {
    test('rejects blank and too long terms', () {
      expect(
        validateGlossaryDraft(const GlossaryDraft(term: '  ')),
        GlossaryDraftError.empty,
      );
      expect(
        validateGlossaryDraft(
          GlossaryDraft(term: 'a' * (kMaxGlossaryTermLength + 1)),
        ),
        GlossaryDraftError.tooLong,
      );
      expect(
        validateGlossaryDraft(
          GlossaryDraft(
            term: 'a',
            arSpelling: 'ب' * (kMaxGlossarySpellingLength + 1),
          ),
        ),
        GlossaryDraftError.tooLong,
      );
    });

    test('detects duplicates by key but not the term being edited', () {
      const existing = [
        GlossaryDraft(id: 1, term: 'Kubernetes'),
        GlossaryDraft(id: 2, term: 'Deepgram'),
      ];
      expect(
        validateGlossaryDraft(
          const GlossaryDraft(term: ' kubernetes '),
          existing: existing,
        ),
        GlossaryDraftError.duplicate,
      );
      expect(
        validateGlossaryDraft(
          const GlossaryDraft(id: 1, term: 'KUBERNETES'),
          existing: existing,
        ),
        isNull,
      );
      expect(
        validateGlossaryDraft(
          const GlossaryDraft(term: 'Gemini'),
          existing: existing,
        ),
        isNull,
      );
    });
  });

  group('search', () {
    test('searchKey normalises Arabic letter forms and diacritics', () {
      expect(searchKey('أَحْمَد'), searchKey('احمد'));
      expect(searchKey('مدرسة'), searchKey('مدرسه'));
      expect(searchKey('مصطفى'), searchKey('مصطفي'));
      expect(searchKey('إدارة  الـمشاريع'), 'اداره المشاريع');
      expect(matchesQuery('Kubernetes', 'KUBE'), isTrue);
      expect(matchesQuery('anything', '  '), isTrue);
    });

    test('filterGlossary matches term or Arabic spelling and category', () {
      final terms = [
        term(1, 'Kubernetes', ar: 'كوبرنيتس', c: GlossaryCategory.technical),
        term(2, 'Aramco', ar: 'أرامكو', c: GlossaryCategory.organisation),
        term(3, 'Sara', c: GlossaryCategory.person),
      ];
      expect(filterGlossary(terms, query: 'ارامكو').map((t) => t.id), [2]);
      expect(filterGlossary(terms, query: 'kube').map((t) => t.id), [1]);
      expect(
        filterGlossary(
          terms,
          category: GlossaryCategory.person,
        ).map((t) => t.id),
        [3],
      );
      expect(filterGlossary(terms).length, 3);
    });

    test('groupGlossary orders categories and sorts terms', () {
      final g = groupGlossary([
        term(1, 'zeta', c: GlossaryCategory.technical),
        term(2, 'Alpha', c: GlossaryCategory.technical),
        term(3, 'Sara', c: GlossaryCategory.person),
      ]);
      expect(g.keys, [GlossaryCategory.person, GlossaryCategory.technical]);
      expect(g[GlossaryCategory.technical]!.map((t) => t.term), [
        'Alpha',
        'zeta',
      ]);
    });
  });

  group('text export / import', () {
    test('round-trips through glossaryToText and parseGlossaryText', () {
      final terms = [
        term(1, 'Kubernetes', ar: 'كوبرنيتس', c: GlossaryCategory.technical),
        term(2, 'A|B Corp', c: GlossaryCategory.organisation),
        term(3, 'سارة', c: GlossaryCategory.person),
        term(4, 'misc'),
      ];
      final text = glossaryToText(terms, label: CS.category);
      expect(text.split('\n'), hasLength(4));
      expect(text, contains('A/B Corp'));
      final parsed = parseGlossaryText(text);
      expect(parsed.invalidLines, isEmpty);
      expect(parsed.drafts.map((d) => (d.term, d.arSpelling, d.category)), [
        ('Kubernetes', 'كوبرنيتس', GlossaryCategory.technical),
        ('A/B Corp', null, GlossaryCategory.organisation),
        ('سارة', null, GlossaryCategory.person),
        ('misc', null, GlossaryCategory.other),
      ]);
    });

    test('parse skips comments, reports invalid lines, merges duplicates', () {
      final text = [
        '# my list',
        '',
        'OpenAI',
        'openai | أوبن إيه آي | tech',
        '  | spelling only',
        'Gemini\tجيميناي\tunknown-category',
        'x' * (kMaxGlossaryTermLength + 1),
      ].join('\r\n');
      final r = parseGlossaryText(
        text,
        defaultCategory: GlossaryCategory.technical,
      );
      expect(r.invalidLines, [5, 7]);
      expect(r.drafts, hasLength(2));
      final openai = r.drafts.firstWhere((d) => d.key == 'openai');
      expect(openai.term, 'openai');
      expect(openai.arSpelling, 'أوبن إيه آي');
      expect(openai.category, GlossaryCategory.technical);
      final gemini = r.drafts.firstWhere((d) => d.key == 'gemini');
      expect(gemini.arSpelling, 'جيميناي');
      expect(gemini.category, GlossaryCategory.technical);
    });

    test('parseCategoryWord accepts wire values and Arabic labels', () {
      for (final c in GlossaryCategory.values) {
        expect(parseCategoryWord(c.wire), c);
        expect(parseCategoryWord(CS.category(c)), c);
      }
      expect(parseCategoryWord('مؤسسة'), GlossaryCategory.organisation);
      expect(parseCategoryWord('Organization'), GlossaryCategory.organisation);
      expect(parseCategoryWord('???'), isNull);
      expect(parseCategoryWord(''), isNull);
    });
  });

  group('buildCloudAsrKeyterms', () {
    test('priority: meeting terms, attendees, named speakers, global', () {
      final keys = buildCloudAsrKeyterms(
        meetingTerms: [term(1, 'Project Falcon', ar: 'مشروع الصقر')],
        expectedAttendees: ['Omar', ' sara '],
        speakers: [speaker('Sara'), speaker('متحدث 1', named: false)],
        globalTerms: [
          term(2, 'Kubernetes', ar: 'كوبرنيتس'),
          term(3, 'project   falcon'),
        ],
      );
      expect(keys, [
        'Project Falcon',
        'Omar',
        'sara',
        'Kubernetes',
        'مشروع الصقر',
        'كوبرنيتس',
      ]);
    });

    test('caps at the limit, keeping the highest-priority entries', () {
      final keys = buildCloudAsrKeyterms(
        meetingTerms: [term(1, 'M')],
        globalTerms: [for (var i = 0; i < 80; i++) term(i + 10, 'g$i')],
      );
      expect(keys, hasLength(50));
      expect(keys.first, 'M');
      expect(keys.last, 'g48');
      expect(buildCloudAsrKeyterms(globalTerms: [term(1, 'a')], limit: 0), []);
    });
  });

  group('planMeetingTermSync', () {
    final existing = [
      term(1, 'Falcon', c: GlossaryCategory.technical, meetingId: 'm'),
      term(2, 'Hawk', meetingId: 'm'),
      term(3, 'Eagle', meetingId: 'm'),
    ];

    test('adds, updates and deletes', () {
      final plan = planMeetingTermSync(existing, const [
        GlossaryDraft(
          id: 1,
          term: 'Falcon',
          arSpelling: 'فالكون',
          category: GlossaryCategory.technical,
        ),
        GlossaryDraft(term: 'eagle'),
        GlossaryDraft(term: 'Osprey'),
        GlossaryDraft(term: '   '),
      ]);
      expect(plan.add.map((d) => d.term), ['Osprey']);
      expect(plan.update.map((t) => (t.id, t.term, t.arSpelling)), [
        (1, 'Falcon', 'فالكون'),
        (3, 'eagle', null),
      ]);
      expect(plan.update.first.meetingId, 'm');
      expect(plan.delete, [2]);
      expect(plan.isEmpty, isFalse);
    });

    test('an unchanged list is an empty plan', () {
      final plan = planMeetingTermSync(
        existing,
        existing.map(GlossaryDraft.of).toList(),
      );
      expect(plan.isEmpty, isTrue);
    });

    test('a renamed term keeps its id; duplicates collapse', () {
      final plan = planMeetingTermSync(existing, const [
        GlossaryDraft(id: 2, term: 'Hawkeye'),
        GlossaryDraft(term: 'Hawkeye'),
      ]);
      expect(plan.add, isEmpty);
      expect(plan.update.single.id, 2);
      expect(plan.delete, [1, 3]);
    });

    test('draftAsTerm previews a draft', () {
      final t = draftAsTerm(
        const GlossaryDraft(term: ' a  b ', category: GlossaryCategory.person),
        meetingId: 'm',
        createdAt: DateTime(2026),
      );
      expect(
        (t.id, t.term, t.meetingId, t.category),
        (0, 'a b', 'm', GlossaryCategory.person),
      );
    });
  });
}
