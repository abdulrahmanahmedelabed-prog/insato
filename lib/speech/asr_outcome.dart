// What the pipeline stores for a VAD speech segment once ASR ran (F17).
//
// Real speech is never silently dropped: when the recogniser returns no
// text, its output was removed by the hallucination filter, or its
// confidence is low, the segment is stored as
// `SegmentKind.unintelligible` (audio = its start..end range of the meeting
// WAV; text = the low-confidence guess or empty). Only audio the engine
// reports as (near) silence is dropped.
//
// Pure Dart, unit-tested.

import '../core/models.dart';

/// Confidence below which recognised text is treated as unintelligible.
const double kLowAsrConfidence = 0.3;

/// What to store for one segment.
class AsrOutcome {
  /// Creates an outcome; [kind] null means "drop".
  const AsrOutcome({required this.kind, this.text = '', this.confidence});

  /// Nothing to store (silence).
  static const AsrOutcome drop = AsrOutcome(kind: null);

  /// Stored kind, or null to drop the segment.
  final SegmentKind? kind;

  /// Text to store (trimmed; possibly empty for unintelligible speech).
  final String text;

  /// Recogniser confidence, when reported.
  final double? confidence;

  /// True when nothing is stored.
  bool get isDropped => kind == null;
}

/// Classifies the ASR result [r] of a VAD speech segment (see the file
/// comment). [lowConfidence] is the confidence threshold.
AsrOutcome classifyAsrOutcome(
  AsrResult r, {
  double lowConfidence = kLowAsrConfidence,
}) {
  if (r.rejection == AsrRejection.silence) return AsrOutcome.drop;
  final text = r.text.trim();
  final conf = r.confidence;
  if (text.isEmpty ||
      r.rejection == AsrRejection.noText ||
      r.rejection == AsrRejection.filtered) {
    return AsrOutcome(
      kind: SegmentKind.unintelligible,
      // A filtered output is a hallucination, never a useful guess.
      text: r.rejection == AsrRejection.filtered ? '' : text,
      confidence: conf,
    );
  }
  if (r.rejection == AsrRejection.lowConfidence ||
      (conf != null && conf < lowConfidence)) {
    return AsrOutcome(
      kind: SegmentKind.unintelligible,
      text: text,
      confidence: conf,
    );
  }
  return AsrOutcome(kind: SegmentKind.speech, text: text, confidence: conf);
}
