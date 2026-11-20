import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/ask/bm25.dart';

void main() {
  final docs = [
    ['budget', 'review', 'budget'],
    ['hiring', 'plan'],
    ['budget', 'hiring', 'plan', 'office', 'move', 'lunch', 'party'],
    ['lunch'],
  ];

  test('idf is non-negative and higher for rarer terms', () {
    final index = Bm25Index(docs);
    expect(index.documentCount, 4);
    expect(index.documentFrequency('budget'), 2);
    expect(index.idf('budget'), closeTo(math.log(1 + 2.5 / 2.5), 1e-9));
    expect(index.idf('review'), greaterThan(index.idf('budget')));
    expect(index.idf('missing'), 0);
  });

  test('ranks by term frequency and length normalisation', () {
    final hits = Bm25Index(docs).search({'budget': 1});
    expect(hits.map((h) => h.doc), [0, 2]);
    expect(hits.first.score, greaterThan(hits.last.score));
  });

  test('matches the BM25 formula', () {
    final index = Bm25Index(docs);
    final hits = index.search({'lunch': 1});
    final avg = (3 + 2 + 7 + 1) / 4;
    double score(int len) {
      final norm = 1.2 * (1 - 0.75 + 0.75 * len / avg);
      return index.idf('lunch') * (1 * 2.2) / (1 + norm);
    }

    expect(hits.map((h) => h.doc), [3, 2]);
    expect(hits[0].score, closeTo(score(1), 1e-9));
    expect(hits[1].score, closeTo(score(7), 1e-9));
  });

  test('query weights and limit', () {
    final index = Bm25Index(docs);
    final q = weightedQuery(['hiring']);
    weightedQuery(['lunch'], weight: 0.1, into: q);
    final hits = index.search(q, limit: 2);
    expect(hits, hasLength(2));
    expect(hits.first.doc, 1);
    expect(weightedQuery(['a', 'a', 'b']), {'a': 2.0, 'b': 1.0});
  });

  test('empty index and empty query', () {
    expect(Bm25Index(const []).search({'x': 1}), isEmpty);
    expect(Bm25Index(docs).search(const {}), isEmpty);
    expect(Bm25Index(docs).search({'budget': 0}), isEmpty);
  });
}
