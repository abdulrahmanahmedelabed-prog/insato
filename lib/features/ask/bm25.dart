// Okapi BM25 ranking over pre-analysed documents (F8 retrieval).
//
// Pure Dart: unit-tested and usable inside an isolate.

import 'dart:math' as math;

/// One scored document of a [Bm25Index.search].
class Bm25Hit {
  /// Creates a hit.
  const Bm25Hit(this.doc, this.score);

  /// Index of the document in the list given to [Bm25Index.new].
  final int doc;

  /// BM25 score (> 0).
  final double score;

  @override
  String toString() => 'Bm25Hit($doc, ${score.toStringAsFixed(3)})';
}

/// An inverted index with Okapi BM25 scoring.
///
/// IDF is the non-negative variant `ln(1 + (N − df + 0.5) / (df + 0.5))`, so
/// a term present in every document still scores slightly above zero.
class Bm25Index {
  /// Indexes [documents] (each a list of analysed terms).
  Bm25Index(List<List<String>> documents, {this.k1 = 1.2, this.b = 0.75})
    : documentCount = documents.length,
      _lengths = [for (final d in documents) d.length] {
    var total = 0;
    for (var i = 0; i < documents.length; i++) {
      total += documents[i].length;
      final counts = <String, int>{};
      for (final term in documents[i]) {
        counts[term] = (counts[term] ?? 0) + 1;
      }
      counts.forEach((term, tf) {
        (_postings[term] ??= []).add(_Posting(i, tf));
      });
    }
    averageLength = documents.isEmpty ? 0 : total / documents.length;
  }

  /// Term-frequency saturation.
  final double k1;

  /// Length normalisation.
  final double b;

  /// Number of documents.
  final int documentCount;

  /// Average document length in terms.
  late final double averageLength;

  final List<int> _lengths;
  final Map<String, List<_Posting>> _postings = {};

  /// Number of documents containing [term].
  int documentFrequency(String term) => _postings[term]?.length ?? 0;

  /// Inverse document frequency of [term] (0 when absent).
  double idf(String term) {
    final df = documentFrequency(term);
    if (df == 0) return 0;
    return math.log(1 + (documentCount - df + 0.5) / (df + 0.5));
  }

  /// Scores every document matching at least one term of [query] (term →
  /// weight; repeated question terms can carry a higher weight) and returns
  /// the hits sorted by descending score (ties: lower document index first),
  /// at most [limit] when given.
  List<Bm25Hit> search(Map<String, double> query, {int? limit}) {
    final scores = <int, double>{};
    final avg = averageLength <= 0 ? 1.0 : averageLength;
    query.forEach((term, weight) {
      if (weight <= 0) return;
      final postings = _postings[term];
      if (postings == null) return;
      final termIdf = idf(term);
      for (final p in postings) {
        final norm = k1 * (1 - b + b * _lengths[p.doc] / avg);
        final s = termIdf * (p.tf * (k1 + 1)) / (p.tf + norm);
        scores[p.doc] = (scores[p.doc] ?? 0) + weight * s;
      }
    });
    final hits =
        [
          for (final e in scores.entries)
            if (e.value > 0) Bm25Hit(e.key, e.value),
        ]..sort((a, z) {
          final c = z.score.compareTo(a.score);
          return c != 0 ? c : a.doc.compareTo(z.doc);
        });
    if (limit != null && hits.length > limit) return hits.sublist(0, limit);
    return hits;
  }
}

class _Posting {
  const _Posting(this.doc, this.tf);

  final int doc;
  final int tf;
}

/// Builds a weighted BM25 query from analysed terms: each occurrence adds
/// [weight] (so a term repeated in the question counts more).
Map<String, double> weightedQuery(
  Iterable<String> terms, {
  double weight = 1,
  Map<String, double>? into,
}) {
  final q = into ?? <String, double>{};
  for (final t in terms) {
    q[t] = (q[t] ?? 0) + weight;
  }
  return q;
}
