// Live Insato call (v1.2): the combined live transcript of both devices and
// the rules that merge it.
//
// Every line carries its start on *this* device's monotonic clock (µs):
// local lines directly, remote lines through the clock-sync estimate (or a
// provisional arrival-based guess until the estimate is ready, corrected
// later). The book keeps lines ordered by that time; pending lines (speech
// detected, text not yet ready) are shown as placeholders and replaced by
// the final text under the same id.
//
// Echo. Without headphones, the remote voice played by the loudspeaker can
// reach the local microphone and be transcribed a second time. A local
// line whose text closely matches a remote line within a few seconds, and
// that starts after it (or at the same time on the callee), is an echo and
// is retracted; each device only ever retracts its own lines, so the two
// devices never both drop the same utterance.
//
// Pure Dart.

import 'dart:math' as math;

import '../../core/models.dart' show SegmentKind;

/// Which device a line comes from.
enum LineOrigin {
  /// This device's microphone.
  local,

  /// The other device.
  remote,
}

/// One line of the live transcript.
class LiveLine {
  /// Creates a line.
  const LiveLine({
    required this.id,
    required this.origin,
    required this.atUs,
    required this.durMs,
    this.peerAtUs,
    this.text = '',
    this.pending = false,
    this.speakerKey = '',
    this.speakerName = '',
    this.language,
    this.kind = SegmentKind.speech,
    this.confidence,
    this.provisionalTime = false,
  });

  /// Line id (unique per origin).
  final String id;

  /// Local or remote.
  final LineOrigin origin;

  /// Start on this device's clock (µs).
  final int atUs;

  /// Duration.
  final int durMs;

  /// Start on the sender's clock (remote lines; for re-mapping).
  final int? peerAtUs;

  /// Text ('' while pending).
  final String text;

  /// True while the text is not ready.
  final bool pending;

  /// Speaker id on the device that transcribed the line.
  final String speakerKey;

  /// Speaker name on that device.
  final String speakerName;

  /// Language.
  final String? language;

  /// Speech or unintelligible.
  final SegmentKind kind;

  /// Recogniser confidence.
  final double? confidence;

  /// True while a remote line's time is only an arrival-based guess.
  final bool provisionalTime;

  /// End on this device's clock (µs).
  int get endUs => atUs + durMs * 1000;

  /// Key in the book.
  String get key => '${origin.name}:$id';

  /// Copy with a new time.
  LiveLine retimed(int atUs, {required bool provisional}) => LiveLine(
    id: id,
    origin: origin,
    atUs: atUs,
    durMs: durMs,
    peerAtUs: peerAtUs,
    text: text,
    pending: pending,
    speakerKey: speakerKey,
    speakerName: speakerName,
    language: language,
    kind: kind,
    confidence: confidence,
    provisionalTime: provisional,
  );
}

/// The live transcript of a call, ordered by time on this device.
class LiveTranscriptBook {
  /// Creates an empty book keeping at most [maxLines] lines in memory (the
  /// whole call is in the database; the screen needs the recent part).
  LiveTranscriptBook({this.maxLines = 2000});

  /// Memory cap.
  final int maxLines;

  final Map<String, LiveLine> _byKey = {};
  List<LiveLine>? _sorted;

  /// All lines ordered by start time (ties: local first, then id).
  List<LiveLine> get lines {
    final cached = _sorted;
    if (cached != null) return cached;
    final out = _byKey.values.toList()
      ..sort((a, b) {
        final c = a.atUs.compareTo(b.atUs);
        if (c != 0) return c;
        final o = a.origin.index.compareTo(b.origin.index);
        return o != 0 ? o : a.id.compareTo(b.id);
      });
    return _sorted = List.unmodifiable(out);
  }

  /// Number of lines.
  int get length => _byKey.length;

  /// The line with [id] of [origin], or null.
  LiveLine? get(LineOrigin origin, String id) => _byKey['${origin.name}:$id'];

  /// Adds or replaces [line] (a final line replaces its pending
  /// placeholder; a late pending never overwrites a final line).
  void upsert(LiveLine line) {
    final old = _byKey[line.key];
    if (old != null && !old.pending && line.pending) return;
    _byKey[line.key] = line;
    _sorted = null;
    if (_byKey.length > maxLines) {
      final oldest = lines.first;
      _byKey.remove(oldest.key);
      _sorted = null;
    }
  }

  /// Removes a line; true when it existed.
  bool remove(LineOrigin origin, String id) {
    final removed = _byKey.remove('${origin.name}:$id') != null;
    if (removed) _sorted = null;
    return removed;
  }

  /// Re-maps the remote lines with a provisional time through [toLocal]
  /// (sender clock → this clock). Returns the re-timed lines.
  List<LiveLine> fixProvisional(int Function(int peerUs) toLocal) {
    final fixed = <LiveLine>[];
    for (final l in _byKey.values.toList()) {
      final p = l.peerAtUs;
      if (!l.provisionalTime || p == null) continue;
      final n = l.retimed(toLocal(p), provisional: false);
      _byKey[n.key] = n;
      fixed.add(n);
    }
    if (fixed.isNotEmpty) _sorted = null;
    return fixed;
  }

  /// Final remote lines starting within [windowUs] of [atUs].
  Iterable<LiveLine> finalsNear(
    LineOrigin origin,
    int atUs, {
    int windowUs = kEchoWindowUs,
  }) => _byKey.values.where(
    (l) =>
        l.origin == origin &&
        !l.pending &&
        l.text.trim().isNotEmpty &&
        (l.atUs - atUs).abs() <= windowUs,
  );
}

// ---------------------------------------------------------------------------
// Echo detection
// ---------------------------------------------------------------------------

/// Lines further apart than this are never echoes of each other.
const int kEchoWindowUs = 4 * 1000 * 1000;

/// Starts closer than this are a tie (decided by role).
const int kEchoTieUs = 150 * 1000;

/// Text similarity from which two overlapping lines are the same speech
/// (conservative: dropping a real line is worse than showing a duplicate).
const double kEchoSimilarity = 0.75;

/// Shorter lines are never treated as echoes («نعم», «شكرًا جزيلًا»).
const int kEchoMinWords = 3;

final RegExp _diacritics = RegExp('[ً-ٰٟـ]');
final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Text normalised for comparison: no Arabic diacritics / tatweel, unified
/// alef / yeh / teh marbuta forms, lower case, punctuation removed, single
/// spaces.
String normalizeForEcho(String text) {
  var s = text.toLowerCase().replaceAll(_diacritics, '');
  s = s
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  return s.replaceAll(_nonWord, ' ').trim();
}

/// Dice coefficient of the character bigrams of the normalised texts
/// (0 = nothing in common, 1 = identical). Robust to the small recognition
/// differences between an utterance and its echo.
double textSimilarity(String a, String b) {
  final x = normalizeForEcho(a).replaceAll(' ', '');
  final y = normalizeForEcho(b).replaceAll(' ', '');
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  if (x.length < 2 || y.length < 2) return 0;
  Map<String, int> grams(String s) {
    final m = <String, int>{};
    for (var i = 0; i < s.length - 1; i++) {
      final g = s.substring(i, i + 2);
      m[g] = (m[g] ?? 0) + 1;
    }
    return m;
  }

  final gx = grams(x), gy = grams(y);
  var common = 0;
  gx.forEach((g, n) => common += math.min(n, gy[g] ?? 0));
  return 2 * common / ((x.length - 1) + (y.length - 1));
}

/// Whether [local] is an echo of [remote]: similar text (at least
/// [kEchoMinWords] words), starting within [kEchoWindowUs], and not before
/// it (a tie within [kEchoTieUs] counts as an echo only when
/// [localIsCallee]).
bool isEchoOf(LiveLine local, LiveLine remote, {required bool localIsCallee}) {
  if (local.pending || remote.pending) return false;
  if ((local.atUs - remote.atUs).abs() > kEchoWindowUs) return false;
  if (normalizeForEcho(local.text).split(' ').length < kEchoMinWords) {
    return false;
  }
  if (textSimilarity(local.text, remote.text) < kEchoSimilarity) return false;
  final d = local.atUs - remote.atUs;
  if (d.abs() <= kEchoTieUs) return localIsCallee;
  return d > 0;
}
