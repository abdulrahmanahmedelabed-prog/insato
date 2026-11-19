// Speech segmentation with sherpa-onnx silero VAD.
//
// The sherpa VAD reports segment start offsets as absolute sample indices of
// the audio fed since the detector was created. This segmenter keeps its own
// history of recent audio so it can add a little context padding around each
// segment (Whisper transcribes word edges better with a few hundred ms of
// context) and hard-split anything longer than Whisper's 30 s window.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import 'sherpa_asr_engine.dart' show ensureSherpaBindings;

/// Tuning of [VadSegmenter]. Defaults are tuned for meetings.
class VadSegmenterConfig {
  /// Creates a configuration.
  const VadSegmenterConfig({
    this.threshold = 0.5,
    this.minSilenceDuration = 0.5,
    this.minSpeechDuration = 0.25,
    this.maxSpeechDuration = 20.0,
    this.windowSize = 512,
    this.bufferSizeInSeconds = 60.0,
    this.prePaddingMs = 100,
    this.postPaddingMs = 200,
    this.maxSegmentSeconds = 29.0,
    this.numThreads = 1,
  });

  /// Speech probability threshold (0..1).
  final double threshold;

  /// Silence (seconds) that ends a segment.
  final double minSilenceDuration;

  /// Shortest speech (seconds) that opens a segment.
  final double minSpeechDuration;

  /// The VAD forces a cut after this many seconds of continuous speech.
  final double maxSpeechDuration;

  /// Silero window in samples (512 at 16 kHz).
  final int windowSize;

  /// Internal VAD ring buffer size in seconds.
  final double bufferSizeInSeconds;

  /// Context added before a segment (never overlapping the previous one).
  final int prePaddingMs;

  /// Context added after a segment (taken from audio already received).
  final int postPaddingMs;

  /// Hard cap for an emitted segment (Whisper's window is 30 s).
  final double maxSegmentSeconds;

  /// Threads for the VAD model.
  final int numThreads;
}

/// [SpeechSegmenter] backed by sherpa-onnx silero VAD.
///
/// Feed audio with [accept] (any chunk size, mono float at [kSampleRate]);
/// segments are emitted on [segments] with absolute [SpeechSegment.startMs]
/// (relative to the first sample ever fed plus [startOffsetMs]) and
/// monotonic indices starting at [firstIndex]. Errors are delivered as
/// [ModelException] events on [segments].
class VadSegmenter implements SpeechSegmenter {
  /// Creates a segmenter for the silero model at [modelPath].
  VadSegmenter({
    required this.modelPath,
    this.config = const VadSegmenterConfig(),
    this.firstIndex = 0,
    this.startOffsetMs = 0,
  })  : _nextIndex = firstIndex,
        _chunker = WindowChunker(config.windowSize),
        _history = AudioHistory(
          ((config.maxSegmentSeconds + config.minSilenceDuration + 8) *
                  kSampleRate)
              .ceil(),
        );

  /// Path of `silero_vad.onnx`.
  final String modelPath;

  /// VAD tuning.
  final VadSegmenterConfig config;

  /// Index of the first emitted segment.
  final int firstIndex;

  /// Added to every segment start (for resumed recordings).
  final int startOffsetMs;

  final StreamController<SpeechSegment> _out =
      StreamController<SpeechSegment>();
  final WindowChunker _chunker;
  final AudioHistory _history;
  sherpa.VoiceActivityDetector? _vad;
  int _nextIndex;
  int _fed = 0; // samples fed to the VAD (real + synthetic)
  int _synthetic = 0; // zero samples injected by flush()
  // (absolute index where synthetic padding ended, total synthetic so far):
  // audio after a flush is shifted back by the padding injected before it.
  final List<(int, int)> _shifts = [];
  int _lastEmittedEnd = 0; // absolute sample index (exclusive)
  bool _disposed = false;

  @override
  Stream<SpeechSegment> get segments => _out.stream;

  /// True while the VAD currently hears speech.
  bool get isSpeechActive {
    final v = _vad;
    if (v == null) return false;
    try {
      return v.isDetected();
    } catch (_) {
      return false;
    }
  }

  /// Total audio fed so far.
  Duration get processedDuration =>
      Duration(
          milliseconds: samplesToMs(_fed - _synthetic + _chunker.pending));

  @override
  Future<void> initialize() async {
    if (_vad != null) return;
    if (_disposed) throw StateError('VadSegmenter disposed');
    try {
      ensureSherpaBindings();
      final vadConfig = sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: modelPath,
          threshold: config.threshold,
          minSilenceDuration: config.minSilenceDuration,
          minSpeechDuration: config.minSpeechDuration,
          windowSize: config.windowSize,
          maxSpeechDuration: config.maxSpeechDuration,
        ),
        sampleRate: kSampleRate,
        numThreads: config.numThreads,
        provider: 'cpu',
        debug: false,
      );
      _vad = sherpa.VoiceActivityDetector(
        config: vadConfig,
        bufferSizeInSeconds: config.bufferSizeInSeconds,
      );
    } catch (e) {
      throw ModelException(
        'تعذّر تحميل نموذج كشف الكلام. يُرجى إعادة تنزيله من صفحة النماذج.',
        debugDetails: 'VAD init ($modelPath): $e',
        cause: e,
      );
    }
  }

  @override
  void accept(Float32List samples) {
    final vad = _vad;
    if (vad == null || _disposed || samples.isEmpty) return;
    try {
      for (final window in _chunker.add(samples)) {
        _feed(vad, window);
      }
    } catch (e) {
      _emitError(e);
    }
  }

  void _feed(sherpa.VoiceActivityDetector vad, Float32List window) {
    _history.append(window);
    vad.acceptWaveform(window);
    _fed += window.length;
    _drain(vad);
  }

  @override
  void flush() {
    final vad = _vad;
    if (vad == null || _disposed) return;
    try {
      final remainder = _chunker.takeRemainder();
      final realEnd = _fed + remainder.length;
      if (remainder.isNotEmpty) {
        final padded = Float32List(config.windowSize)..setAll(0, remainder);
        _feed(vad, padded);
      }
      // Trailing silence lets the VAD close an open segment at its real end
      // (sherpa's own flush() would cut the last minSilenceDuration).
      final silenceWindows =
          ((config.minSilenceDuration * kSampleRate) / config.windowSize)
                  .ceil() +
              2;
      final zeros = Float32List(config.windowSize);
      for (var i = 0; i < silenceWindows; i++) {
        _feed(vad, zeros);
      }
      vad.flush();
      _drain(vad);
      _synthetic += _fed - realEnd;
      _shifts.add((_fed, _synthetic));
    } catch (e) {
      _emitError(e);
    }
  }

  void _drain(sherpa.VoiceActivityDetector vad) {
    while (!vad.isEmpty()) {
      final seg = vad.front();
      vad.pop();
      _emitVadSegment(seg.start, seg.samples);
    }
  }

  void _emitVadSegment(int vadStart, Float32List vadSamples) {
    if (vadSamples.isEmpty) return;
    final absStart = math.max(0, vadStart);
    final absEnd = math.min(absStart + vadSamples.length, _fed);
    final pre = msToSamples(config.prePaddingMs);
    final post = msToSamples(config.postPaddingMs);
    // Pre-padding never reaches back into the previous segment, but the
    // VAD's own start is always kept.
    final from = math.max(
        math.max(absStart - pre, math.min(_lastEmittedEnd, absStart)),
        _history.startIndex);
    final to = math.min(absEnd + post, _history.endIndex);
    final Float32List audio;
    final int audioStart;
    if (from <= absStart && to >= absEnd && to > from) {
      audio = _history.slice(from, to);
      audioStart = from;
    } else {
      audio = vadSamples;
      audioStart = absStart;
    }
    _lastEmittedEnd = math.max(_lastEmittedEnd, audioStart + audio.length);

    final maxSamples = (config.maxSegmentSeconds * kSampleRate).floor();
    for (final piece in splitLongSegment(audio, maxSamples)) {
      if (_out.isClosed) return;
      _out.add(SpeechSegment(
        index: _nextIndex++,
        startMs: startOffsetMs +
            samplesToMs(_toRealIndex(audioStart + piece.offset)),
        samples: piece.samples,
      ));
    }
  }

  /// Maps an absolute VAD sample index to real recording time by removing
  /// the silence injected by earlier [flush] calls.
  int _toRealIndex(int index) {
    var shift = 0;
    for (final (boundary, total) in _shifts) {
      if (index >= boundary) shift = total;
    }
    return math.max(0, index - shift);
  }

  void _emitError(Object e) {
    if (_out.isClosed) return;
    _out.addError(ModelException(
      'حدث خطأ أثناء تحليل الصوت لاكتشاف الكلام.',
      debugDetails: 'VAD: $e',
      cause: e,
    ));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      _vad?.free();
    } catch (_) {
      // Already released.
    }
    _vad = null;
    // `_out` is single-subscription: its close() future completes only once
    // the done event reaches a listener. With nobody listening (e.g. engine
    // set-up failed before the pipeline subscribed) awaiting it would hang
    // forever and swallow the original error.
    if (_out.hasListener && !_out.isPaused) {
      await _out.close();
    } else {
      unawaited(_out.close());
    }
  }
}

// ---------------------------------------------------------------------------
// Pure helpers (unit-tested).
// ---------------------------------------------------------------------------

/// Converts a sample count at [kSampleRate] to whole milliseconds.
int samplesToMs(int samples) => (samples * 1000) ~/ kSampleRate;

/// Converts milliseconds to a sample count at [kSampleRate].
int msToSamples(int ms) => (ms * kSampleRate) ~/ 1000;

/// Re-blocks an arbitrary stream of sample chunks into fixed windows.
class WindowChunker {
  /// Creates a chunker producing windows of [windowSize] samples.
  WindowChunker(this.windowSize)
      : assert(windowSize > 0),
        _buf = Float32List(windowSize);

  /// Window length in samples.
  final int windowSize;
  final Float32List _buf;
  int _len = 0;

  /// Samples buffered, waiting for a full window.
  int get pending => _len;

  /// Adds [samples] and returns every completed window (fresh lists).
  List<Float32List> add(Float32List samples) {
    final out = <Float32List>[];
    var i = 0;
    while (i < samples.length) {
      final take = math.min(windowSize - _len, samples.length - i);
      _buf.setRange(_len, _len + take, samples, i);
      _len += take;
      i += take;
      if (_len == windowSize) {
        out.add(Float32List.fromList(_buf));
        _len = 0;
      }
    }
    return out;
  }

  /// Returns and clears the partial window.
  Float32List takeRemainder() {
    final r = Float32List.fromList(Float32List.sublistView(_buf, 0, _len));
    _len = 0;
    return r;
  }
}

/// Ring buffer of the most recent audio, addressed by absolute sample index.
class AudioHistory {
  /// Creates a history holding up to [capacity] samples.
  AudioHistory(this.capacity)
      : assert(capacity > 0),
        _data = Float32List(capacity);

  /// Maximum number of retained samples.
  final int capacity;
  final Float32List _data;
  int _end = 0; // absolute index one past the newest sample

  /// Absolute index of the oldest retained sample.
  int get startIndex => math.max(0, _end - capacity);

  /// Absolute index one past the newest sample.
  int get endIndex => _end;

  /// Appends [samples].
  void append(Float32List samples) {
    var src = samples;
    if (src.length > capacity) {
      _end += src.length - capacity;
      src = Float32List.sublistView(src, src.length - capacity);
    }
    var pos = _end % capacity;
    var i = 0;
    while (i < src.length) {
      final n = math.min(capacity - pos, src.length - i);
      _data.setRange(pos, pos + n, src, i);
      i += n;
      pos = (pos + n) % capacity;
    }
    _end += src.length;
  }

  /// Copy of absolute range [from, to). Throws [RangeError] when the range
  /// is not (fully) retained.
  Float32List slice(int from, int to) {
    if (from < startIndex || to > _end || from > to) {
      throw RangeError('[$from, $to) not in [$startIndex, $_end)');
    }
    final out = Float32List(to - from);
    var pos = from % capacity;
    var i = 0;
    while (i < out.length) {
      final n = math.min(capacity - pos, out.length - i);
      out.setRange(i, i + n, _data, pos);
      i += n;
      pos = (pos + n) % capacity;
    }
    return out;
  }
}

/// A piece of a split segment: [offset] samples from the original start.
class SegmentPiece {
  /// Creates a piece.
  const SegmentPiece(this.offset, this.samples);

  /// Offset in samples from the start of the original segment.
  final int offset;

  /// Audio of this piece.
  final Float32List samples;
}

/// Splits [samples] into pieces of at most [maxSamples], cutting at the
/// quietest 20 ms frame within the last third of each allowed span (so words
/// are rarely cut). Returns a single piece when no split is needed.
List<SegmentPiece> splitLongSegment(Float32List samples, int maxSamples) {
  if (maxSamples <= 0 || samples.length <= maxSamples) {
    return [SegmentPiece(0, samples)];
  }
  const frame = kSampleRate ~/ 50; // 20 ms
  final pieces = <SegmentPiece>[];
  var start = 0;
  while (samples.length - start > maxSamples) {
    final searchFrom = start + (maxSamples * 2) ~/ 3;
    final searchTo = start + maxSamples - frame;
    var bestCut = start + maxSamples;
    var bestEnergy = double.infinity;
    for (var f = searchFrom; f <= searchTo; f += frame) {
      var e = 0.0;
      for (var k = f; k < f + frame; k++) {
        final v = samples[k];
        e += v * v;
      }
      if (e < bestEnergy) {
        bestEnergy = e;
        bestCut = f + frame ~/ 2;
      }
    }
    pieces.add(SegmentPiece(
        start, Float32List.fromList(samples.sublist(start, bestCut))));
    start = bestCut;
  }
  pieces.add(SegmentPiece(start, Float32List.fromList(samples.sublist(start))));
  return pieces;
}
