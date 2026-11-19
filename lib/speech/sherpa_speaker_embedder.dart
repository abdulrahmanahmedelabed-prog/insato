// Speaker embeddings (voiceprints) with sherpa-onnx.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import 'sherpa_asr_engine.dart' show ensureSherpaBindings, recommendedThreadCount;

/// Segments shorter than this are not embedded.
///
/// Embeddings of sub-second segments are noisy, so they never create or
/// update speakers (see `SpeakerTracker` and the refinement): they are only
/// compared with speakers already heard, which is enough to tell who said a
/// short reply such as «نعم» or «موافق».
const int kMinEmbeddingSamples = kSampleRate ~/ 2; // 0.5 s

/// [SpeakerEmbedder] backed by a sherpa-onnx speaker embedding model
/// (WeSpeaker / 3D-Speaker ONNX). Embeddings are L2-normalised.
///
/// Not thread-safe; use it from one isolate.
class SherpaSpeakerEmbedder implements SpeakerEmbedder {
  /// Creates an embedder for the ONNX model at [modelPath].
  SherpaSpeakerEmbedder({required this.modelPath, int? numThreads})
      : numThreads = numThreads ?? math.min(2, recommendedThreadCount());

  /// Path of the speaker embedding model.
  final String modelPath;

  /// ONNX Runtime threads.
  final int numThreads;

  sherpa.SpeakerEmbeddingExtractor? _extractor;

  /// Embedding size; 0 before [initialize].
  @override
  int get dimension => _extractor?.dim ?? 0;

  @override
  Future<void> initialize() async {
    if (_extractor != null) return;
    try {
      ensureSherpaBindings();
      final ex = sherpa.SpeakerEmbeddingExtractor(
        config: sherpa.SpeakerEmbeddingExtractorConfig(
          model: modelPath,
          numThreads: numThreads,
          debug: false,
          provider: 'cpu',
        ),
      );
      if (ex.dim <= 0) {
        ex.free();
        throw StateError('invalid embedding dimension ${ex.dim}');
      }
      _extractor = ex;
    } catch (e) {
      throw ModelException(
        'تعذّر تحميل نموذج البصمة الصوتية. يُرجى إعادة تنزيله من صفحة النماذج.',
        debugDetails: 'speaker model init ($modelPath): $e',
        cause: e,
      );
    }
  }

  @override
  Future<Float32List?> embed(Float32List samples) async {
    final ex = _extractor;
    if (ex == null) {
      throw const ModelException('نموذج البصمة الصوتية غير مهيّأ.');
    }
    if (samples.length < kMinEmbeddingSamples) return null;
    sherpa.OnlineStream? stream;
    try {
      stream = ex.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: kSampleRate);
      stream.inputFinished();
      if (!ex.isReady(stream)) return null;
      return l2Normalize(ex.compute(stream));
    } catch (e) {
      throw ModelException(
        'تعذّر استخراج البصمة الصوتية لأحد المقاطع.',
        debugDetails: 'embed: $e',
        cause: e,
      );
    } finally {
      stream?.free();
    }
  }

  @override
  Future<void> dispose() async {
    _extractor?.free();
    _extractor = null;
  }
}

/// Returns an L2-normalised copy of [v], or null when [v] is empty, has a
/// zero norm, or contains non-finite values.
Float32List? l2Normalize(Float32List v) {
  if (v.isEmpty) return null;
  var sum = 0.0;
  for (final x in v) {
    if (!x.isFinite) return null;
    sum += x * x;
  }
  final norm = math.sqrt(sum);
  if (!(norm > 1e-12)) return null;
  final out = Float32List(v.length);
  for (var i = 0; i < v.length; i++) {
    out[i] = v[i] / norm;
  }
  return out;
}
