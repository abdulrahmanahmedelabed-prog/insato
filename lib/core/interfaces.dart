// Engine interfaces. THIS FILE IS A SHARED CONTRACT.
//
// Implementations live in speech/, diarization/, minutes/. The session
// controller and tests depend only on these abstractions so that engines can be
// swapped (on-device vs. cloud) and faked in tests.

import 'dart:async';
import 'dart:typed_data';

import 'models.dart';

/// Converts speech audio to text. Implementations must be safe to call
/// sequentially from a single isolate; they need not be re-entrant.
abstract class AsrEngine {
  /// Human-readable identifier, e.g. `whisper-turbo (on-device)`.
  String get name;

  /// Loads models / validates credentials. Idempotent.
  Future<void> initialize();

  /// Transcribes one segment.
  ///
  /// [languageHint] is an ISO-639-1 code or null for auto-detect (default:
  /// auto-detect, because meetings may mix languages).
  Future<AsrResult> transcribe(SpeechSegment segment, {String? languageHint});

  Future<void> dispose();
}

/// Produces a fixed-size L2-normalised voice embedding for a segment.
abstract class SpeakerEmbedder {
  int get dimension;

  Future<void> initialize();

  /// Returns null if the segment is too short / silent to embed reliably.
  Future<Float32List?> embed(Float32List samples);

  Future<void> dispose();
}

/// Splits a continuous audio stream into [SpeechSegment]s.
abstract class SpeechSegmenter {
  Future<void> initialize();

  /// Feed mono float samples at [kSampleRate]. Completed segments are emitted
  /// on [segments].
  void accept(Float32List samples);

  /// Flush any trailing speech as a final segment.
  void flush();

  Stream<SpeechSegment> get segments;

  Future<void> dispose();
}

/// Generates Arabic minutes from a transcript.
abstract class MinutesEngine {
  /// [onProgress] receives a rough 0..1 progress and an Arabic status line.
  Future<Minutes> generate({
    required Meeting meeting,
    required List<TranscriptSegment> segments,
    required Map<String, Speaker> speakersById,
    void Function(double progress, String status)? onProgress,
  });
}

/// Status of a downloadable on-device model.
enum ModelStatus { notDownloaded, downloading, ready, failed }

class ModelState {
  const ModelState(this.status, {this.progress = 0, this.error});
  final ModelStatus status;

  /// 0..1 while downloading.
  final double progress;
  final String? error;
}
