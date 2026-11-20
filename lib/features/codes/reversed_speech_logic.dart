// Pure logic of the reversed-speech post-processing (F17): sample ranges
// and time reversal of a segment's audio, the decision whether a re-ASR of
// reversed audio produced real text, and how results enrich the stored
// coded-speech findings (never replacing the original transcript).
// Unit-tested in test/features/codes/reversed_speech_logic_test.dart.

import 'dart:typed_data';

import '../../core/models.dart';
import '../../speech/asr_outcome.dart';

// ---------------------------------------------------------------------------
// Audio
// ---------------------------------------------------------------------------

/// Half-open frame range `[start, end)` of `startMs..endMs` in a signal of
/// [totalFrames] frames at [sampleRate], clamped to the signal. Empty
/// (start == end) when the range lies outside it or is inverted.
(int start, int end) frameRangeForMs({
  required int startMs,
  required int endMs,
  required int sampleRate,
  required int totalFrames,
}) {
  int toFrame(int ms) =>
      (ms.clamp(0, 1 << 40) * sampleRate ~/ 1000).clamp(0, totalFrames);
  final s = toFrame(startMs);
  final e = toFrame(endMs);
  return e <= s ? (s, s) : (s, e);
}

/// Samples of `startMs..endMs` of the mono [signal] at [sampleRate] (a
/// copy; empty when the range is outside the signal).
Float32List sliceMs(
  Float32List signal,
  int startMs,
  int endMs, {
  int sampleRate = kSampleRate,
}) {
  final (s, e) = frameRangeForMs(
    startMs: startMs,
    endMs: endMs,
    sampleRate: sampleRate,
    totalFrames: signal.length,
  );
  return Float32List.fromList(Float32List.sublistView(signal, s, e));
}

/// [samples] in reverse time order (a new list).
Float32List reverseSamples(Float32List samples) {
  final n = samples.length;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = samples[n - 1 - i];
  }
  return out;
}

// ---------------------------------------------------------------------------
// Decision
// ---------------------------------------------------------------------------

/// Shortest clip worth re-recognising (ms).
const int kMinReversibleMs = 400;

/// Most letters per second of plausible speech; more means the recogniser
/// hallucinated text for the clip.
const double kMaxLettersPerSecond = 25;

/// Why a reversed-audio recognition was not accepted.
enum ReversedRejection {
  /// The clip is too short to re-recognise.
  tooShort,

  /// The engine reported silence / no text / filtered output.
  noText,

  /// The engine's confidence was low.
  lowConfidence,

  /// Fewer than two distinct letters (noise, a single repeated sound).
  tooFewLetters,

  /// Far more text than the clip could hold.
  implausibleLength,

  /// Same text as the forward recognition (not a reversal effect).
  sameAsForward,
}

/// Outcome of [assessReversedAsr].
class ReversedVerdict {
  /// Accepted text.
  const ReversedVerdict.accepted(String this.text, {this.confidence})
    : rejection = null;

  /// Rejected.
  const ReversedVerdict.rejected(ReversedRejection this.rejection)
    : text = null,
      confidence = null;

  /// Text when accepted.
  final String? text;

  /// Engine confidence when reported.
  final double? confidence;

  /// Reason when rejected.
  final ReversedRejection? rejection;

  /// True when the reversed audio decoded to real text.
  bool get isAccepted => text != null;
}

final RegExp _letter = RegExp(r'\p{L}', unicode: true);

String _key(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

/// Decides whether the recognition [r] of a time-reversed clip of
/// [durationMs] is real text: the engine must classify it as speech (see
/// `classifyAsrOutcome`), with at least two distinct letters, at a
/// plausible rate ([kMaxLettersPerSecond]) and different from the
/// segment's forward guess [forwardText].
ReversedVerdict assessReversedAsr(
  AsrResult r, {
  required int durationMs,
  String forwardText = '',
}) {
  if (durationMs < kMinReversibleMs) {
    return const ReversedVerdict.rejected(ReversedRejection.tooShort);
  }
  final outcome = classifyAsrOutcome(r);
  if (outcome.kind == null || outcome.text.isEmpty) {
    return const ReversedVerdict.rejected(ReversedRejection.noText);
  }
  if (outcome.kind == SegmentKind.unintelligible) {
    return const ReversedVerdict.rejected(ReversedRejection.lowConfidence);
  }
  final text = outcome.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final letters = _letter.allMatches(text).map((m) => m[0]!.toLowerCase());
  if (letters.toSet().length < 2) {
    return const ReversedVerdict.rejected(ReversedRejection.tooFewLetters);
  }
  if (letters.length > kMaxLettersPerSecond * durationMs / 1000) {
    return const ReversedVerdict.rejected(ReversedRejection.implausibleLength);
  }
  final fwd = _key(forwardText);
  if (fwd.isNotEmpty && fwd == _key(text)) {
    return const ReversedVerdict.rejected(ReversedRejection.sameAsForward);
  }
  return ReversedVerdict.accepted(text, confidence: outcome.confidence);
}

// ---------------------------------------------------------------------------
// Finding enrichment
// ---------------------------------------------------------------------------

/// Payload key: list of [ReversedSpeechResult] JSON objects.
const String kReversedResultsKey = 'reversed_speech';

/// Payload key: segment indices already re-recognised in reverse.
const String kReversedCheckedKey = 'reversed_speech_checked';

/// Payload key of the finding's origin.
const String kFindingOriginKey = 'origin';

/// [kFindingOriginKey] value of findings created by the app (an
/// unintelligible segment the minutes engine did not mention).
const String kOriginApp = 'app';

/// Text recognised in one time-reversed unintelligible segment — a
/// hypothesis shown next to the segment, never the segment's text.
class ReversedSpeechResult {
  /// Creates a result.
  const ReversedSpeechResult({
    required this.segment,
    required this.text,
    this.language,
    this.confidence,
    this.at,
  });

  /// `TranscriptSegment.index`.
  final int segment;

  /// Recognised text.
  final String text;

  /// Language reported by the engine.
  final String? language;

  /// Confidence reported by the engine (0..1).
  final double? confidence;

  /// When it was recognised.
  final DateTime? at;

  /// Stored JSON.
  Map<String, dynamic> toJson() => {
    'segment': segment,
    'text': text,
    'language': ?language,
    'confidence': ?confidence,
    'at': ?at?.toUtc().toIso8601String(),
  };

  /// Parses [toJson] output; null when malformed.
  static ReversedSpeechResult? tryParse(Object? j) {
    if (j is! Map) return null;
    final s = j['segment'];
    final t = j['text'];
    if (s is! int || s < 0 || t is! String || t.trim().isEmpty) return null;
    final l = j['language'];
    final c = j['confidence'];
    final a = j['at'];
    return ReversedSpeechResult(
      segment: s,
      text: t.trim(),
      language: l is String && l.isNotEmpty ? l : null,
      confidence: c is num ? c.toDouble().clamp(0.0, 1.0) : null,
      at: a is String ? DateTime.tryParse(a) : null,
    );
  }
}

/// Reversed-audio results stored in a finding [payload].
List<ReversedSpeechResult> readReversedResults(Map<String, dynamic> payload) {
  final raw = payload[kReversedResultsKey];
  if (raw is! List) return const [];
  return [for (final r in raw) ?ReversedSpeechResult.tryParse(r)];
}

/// Segment indices of [payload] already re-recognised in reverse.
Set<int> readReversedChecked(Map<String, dynamic> payload) {
  final raw = payload[kReversedCheckedKey];
  if (raw is! List) return const {};
  return {
    for (final v in raw)
      if (v is int && v >= 0) v,
  };
}

/// Copy of [payload] with the results of a reversed re-recognition of
/// [checked] segments: earlier results for those segments are replaced by
/// [results] (only results of [checked] segments are kept); everything else
/// in the payload, including the engine's own item, is left untouched.
Map<String, dynamic> enrichPayload(
  Map<String, dynamic> payload, {
  required Set<int> checked,
  required List<ReversedSpeechResult> results,
}) {
  final kept = [
    for (final r in readReversedResults(payload))
      if (!checked.contains(r.segment)) r,
    for (final r in results)
      if (checked.contains(r.segment)) r,
  ]..sort((a, b) => a.segment.compareTo(b.segment));
  final allChecked = {...readReversedChecked(payload), ...checked}.toList()
    ..sort();
  return {
    ...payload,
    kReversedResultsKey: [for (final r in kept) r.toJson()],
    kReversedCheckedKey: allChecked,
  };
}

/// One analysed segment of a run.
class ReversedAttempt {
  /// Creates an attempt.
  const ReversedAttempt({required this.segment, this.result});

  /// The unintelligible segment.
  final TranscriptSegment segment;

  /// Accepted result, or null when nothing real was recognised.
  final ReversedSpeechResult? result;
}

/// How a run changes the stored findings.
class ReversedFindingsPlan {
  /// Creates a plan.
  const ReversedFindingsPlan({required this.updates, required this.created});

  /// Finding id → new payload of existing findings.
  final Map<int, Map<String, dynamic>> updates;

  /// New app findings (for accepted results in segments no coded-speech
  /// finding cites).
  final List<CodeFinding> created;

  /// True when nothing changes.
  bool get isEmpty => updates.isEmpty && created.isEmpty;
}

/// Plans the storage of [attempts] over the meeting's [findings]:
///
/// * every coded-speech finding citing an attempted segment gets its
///   payload enriched ([enrichPayload]) with the results for its segments;
/// * an accepted result in a segment no coded-speech finding cites becomes
///   a new app finding (`origin: app`, character unknown, description from
///   [describe]) carrying the result — the engine's findings and the
///   transcript are never rewritten as fact.
ReversedFindingsPlan planReversedFindings({
  required String meetingId,
  required List<CodeFinding> findings,
  required List<ReversedAttempt> attempts,
  required String Function(TranscriptSegment segment) speakerName,
  required String Function(int durationMs) describe,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final bySegment = {for (final a in attempts) a.segment.index: a};
  final covered = <int>{};
  final updates = <int, Map<String, dynamic>>{};
  for (final f in findings) {
    if (f.kind != CodeFindingKind.speechCoded) continue;
    final item = CodedSpeechItem.fromJson(f.payload);
    final ids = {...item.evidence, ...f.segmentIds};
    final mine = ids.where(bySegment.containsKey).toSet();
    if (mine.isEmpty) continue;
    covered.addAll(mine);
    updates[f.id] = enrichPayload(
      f.payload,
      checked: mine,
      results: [for (final i in mine) ?bySegment[i]!.result],
    );
  }
  final created = <CodeFinding>[];
  for (final a in attempts) {
    final r = a.result;
    if (r == null || covered.contains(a.segment.index)) continue;
    final s = a.segment;
    final duration = (s.endMs - s.startMs).clamp(0, 1 << 40);
    final item = CodedSpeechItem(
      speaker: speakerName(s),
      character: CodedSpeechCharacter.unknown,
      description: describe(duration),
      evidence: [s.index],
    );
    created.add(
      CodeFinding(
        id: 0,
        meetingId: meetingId,
        kind: CodeFindingKind.speechCoded,
        speakerId: s.speakerId,
        segmentIds: [s.index],
        payload: enrichPayload(
          {...item.toJson(), kFindingOriginKey: kOriginApp},
          checked: {s.index},
          results: [r],
        ),
        createdAt: at,
      ),
    );
  }
  return ReversedFindingsPlan(updates: updates, created: created);
}

/// Carries the stored reversed-speech state of a meeting over a
/// regeneration of its minutes, which replaces every code finding:
///
/// * every new coded-speech finding of [engine] that cites a segment
///   already re-recognised in reverse (in any [previous] finding) gets
///   that segment's results and checked mark ([enrichPayload]);
/// * app findings (`origin: app`) of [previous] are kept unless every one
///   of their segments is now cited by a new coded-speech finding (which
///   then carries their results, so nothing is duplicated).
///
/// Returns the engine findings followed by the kept app findings.
List<CodeFinding> carryOverReversedFindings({
  required List<CodeFinding> previous,
  required List<CodeFinding> engine,
}) {
  final resultsBySeg = <int, List<ReversedSpeechResult>>{};
  final checkedSegs = <int>{};
  for (final f in previous) {
    if (f.kind != CodeFindingKind.speechCoded) continue;
    checkedSegs.addAll(readReversedChecked(f.payload));
    for (final r in readReversedResults(f.payload)) {
      final list = resultsBySeg.putIfAbsent(r.segment, () => []);
      if (!list.any((x) => x.text == r.text)) list.add(r);
    }
  }
  final keptApp = [
    for (final f in previous)
      if (f.kind == CodeFindingKind.speechCoded &&
          f.payload[kFindingOriginKey] == kOriginApp)
        f,
  ];
  if (checkedSegs.isEmpty && resultsBySeg.isEmpty && keptApp.isEmpty) {
    return engine;
  }
  final covered = <int>{};
  final out = <CodeFinding>[];
  for (final f in engine) {
    if (f.kind != CodeFindingKind.speechCoded) {
      out.add(f);
      continue;
    }
    final item = CodedSpeechItem.fromJson(f.payload);
    final ids = {...item.evidence, ...f.segmentIds};
    final mine = ids
        .where((i) => checkedSegs.contains(i) || resultsBySeg.containsKey(i))
        .toSet();
    if (mine.isEmpty) {
      out.add(f);
      continue;
    }
    covered.addAll(mine);
    out.add(
      CodeFinding(
        id: f.id,
        meetingId: f.meetingId,
        kind: f.kind,
        speakerId: f.speakerId,
        segmentIds: f.segmentIds,
        payload: enrichPayload(
          f.payload,
          checked: mine,
          results: [
            for (final i in mine) ...?resultsBySeg[i],
          ],
        ),
        createdAt: f.createdAt,
      ),
    );
  }
  for (final f in keptApp) {
    if (f.segmentIds.isNotEmpty && f.segmentIds.every(covered.contains)) {
      continue;
    }
    out.add(f);
  }
  return out;
}
