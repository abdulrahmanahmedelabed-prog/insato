import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/context/context_logic.dart';
import 'package:insato/features/context/glossary_logic.dart';

Speaker speaker(String name, {bool named = true, bool voice = false}) =>
    Speaker(
      id: name,
      name: name,
      colorValue: 0,
      isNamedByUser: named,
      createdAt: DateTime(2026),
      centroid: voice ? Float32List.fromList([1, 0]) : null,
    );

void main() {
  group('MeetingSetup', () {
    test('empty / trimmedTitle', () {
      expect(MeetingSetup.empty.isEmpty, isTrue);
      expect(const MeetingSetup(title: '   ').isEmpty, isTrue);
      expect(const MeetingSetup(title: ' a  b ').trimmedTitle, 'a b');
      expect(
        const MeetingSetup(meetingTerms: [GlossaryDraft(term: 'x')]).isEmpty,
        isFalse,
      );
    });

    test('normalized trims, dedupes and applies limits', () {
      final s = MeetingSetup(
        title: '  مجلس  ',
        context: MeetingContext(
          agenda: [' أ ', '', for (var i = 0; i < 50; i++) 'بند $i'],
          expectedAttendees: const ['سارة', ' سارة ', '', 'Omar', 'omar'],
          contextNotes: 'n' * (kMaxContextNotesLength + 10),
        ),
        meetingTerms: const [
          GlossaryDraft(term: 'Falcon'),
          GlossaryDraft(term: 'falcon '),
          GlossaryDraft(term: ' '),
        ],
      ).normalized();
      expect(s.title, 'مجلس');
      expect(s.context.agenda, hasLength(kMaxAgendaItems));
      expect(s.context.agenda.first, 'أ');
      expect(s.context.expectedAttendees, ['سارة', 'Omar']);
      expect(s.context.contextNotes!.length, kMaxContextNotesLength);
      expect(s.meetingTerms.map((d) => d.term), ['Falcon']);
    });

    test('sameSetup compares normalised values', () {
      const a = MeetingSetup(
        title: 'x',
        context: MeetingContext(agenda: ['a']),
      );
      const b = MeetingSetup(
        title: ' x ',
        context: MeetingContext(agenda: [' a', ''], contextNotes: '  '),
      );
      expect(sameSetup(a, b), isTrue);
      expect(sameSetup(a, const MeetingSetup(title: 'x')), isFalse);
      expect(
        sameSetup(
          const MeetingSetup(meetingTerms: [GlossaryDraft(term: 'a')]),
          const MeetingSetup(
            meetingTerms: [GlossaryDraft(term: 'a', arSpelling: 'ب')],
          ),
        ),
        isFalse,
      );
    });
  });

  group('list editing', () {
    test('reorderItems uses the onReorderItem convention', () {
      expect(reorderItems(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
      expect(reorderItems(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
      expect(reorderItems(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
      expect(reorderItems(['a', 'b'], 0, 9), ['b', 'a']);
      expect(reorderItems(['a', 'b'], 5, 0), ['a', 'b']);
    });

    test('moveItem moves one step and ignores out-of-range moves', () {
      expect(moveItem(['a', 'b', 'c'], 1, -1), ['b', 'a', 'c']);
      expect(moveItem(['a', 'b', 'c'], 1, 1), ['a', 'c', 'b']);
      expect(moveItem(['a', 'b'], 0, -1), ['a', 'b']);
      expect(moveItem(['a', 'b'], 1, 1), ['a', 'b']);
    });

    test('addUniqueName', () {
      final names = <String>[];
      expect(addUniqueName(names, '  Omar  Ali '), AddNameResult.added);
      expect(addUniqueName(names, 'omar ali'), AddNameResult.duplicate);
      expect(addUniqueName(names, '  '), AddNameResult.invalid);
      expect(
        addUniqueName(names, 'x' * (kMaxAttendeeNameLength + 1)),
        AddNameResult.invalid,
      );
      expect(names, ['Omar Ali']);
      for (var i = names.length; i < kMaxExpectedAttendees; i++) {
        addUniqueName(names, 'n$i');
      }
      expect(addUniqueName(names, 'late'), AddNameResult.full);
    });
  });

  test('attendeeSuggestions: named, not chosen, matching, voice first', () {
    final list = attendeeSuggestions(
      [
        speaker('Zaid', voice: true),
        speaker('أحمد'),
        speaker('Ahmad', voice: true),
        speaker('متحدث 2', named: false),
        speaker('Sara'),
        speaker('sara'),
      ],
      chosen: const ['SARA'],
    );
    expect(list.map((s) => s.name), ['Ahmad', 'Zaid', 'أحمد']);
    expect(
      attendeeSuggestions([speaker('أحمد')], query: 'احمد').single.name,
      'أحمد',
    );
    expect(
      attendeeSuggestions([
        for (var i = 0; i < 20; i++) speaker('p$i'),
      ], limit: 3),
      hasLength(3),
    );
  });
}
