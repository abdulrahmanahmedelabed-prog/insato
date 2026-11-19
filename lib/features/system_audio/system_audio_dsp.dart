// Pure audio logic of F13: converting loopback packets to 16 kHz mono,
// buffering them, filling silence by wall clock and mixing with the
// microphone through a soft limiter. No plugins; fully unit-tested.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio/pcm.dart';
import '../../core/models.dart' show kSampleRate;

// ===========================================================================
// Format conversion
// ===========================================================================

/// Converts interleaved float32 blocks of any rate / channel count (the
/// render endpoint's mix format, typically 48 kHz stereo) to [outputRate]
/// mono. A format change (e.g. the user switched the default output device)
/// flushes the previous converter and starts a new one.
class SystemAudioConverter {
  /// Creates the converter.
  SystemAudioConverter({this.outputRate = kSampleRate});

  /// Output rate (mono).
  final int outputRate;

  int? _rate;
  int? _channels;
  InterleavedDownmixer? _downmixer;
  StreamingResampler? _resampler;

  /// Input sample rate of the current format (null before the first block).
  int? get inputRate => _rate;

  /// Input channel count of the current format.
  int? get inputChannels => _channels;

  /// Converts one block. Returns the mono samples now available (possibly
  /// including the tail of the previous format).
  Float32List convert(
    Float32List interleaved, {
    required int sampleRate,
    required int channels,
  }) {
    if (sampleRate <= 0 || channels <= 0) {
      throw ArgumentError('invalid format $sampleRate Hz × $channels');
    }
    Float32List tail = Float32List(0);
    if (sampleRate != _rate || channels != _channels) {
      tail = flush();
      _rate = sampleRate;
      _channels = channels;
      _downmixer = InterleavedDownmixer(channels);
      _resampler = StreamingResampler(
        inputRate: sampleRate,
        outputRate: outputRate,
      );
    }
    final mono = _downmixer!.process(interleaved);
    final out = _resampler!.process(mono);
    return tail.isEmpty ? out : concatSamples([tail, out]);
  }

  /// Releases what the current converter still holds and forgets the
  /// format (the next block starts fresh).
  Float32List flush() {
    final r = _resampler;
    _resampler = null;
    _downmixer = null;
    _rate = null;
    _channels = null;
    return r == null ? Float32List(0) : r.flush();
  }

  /// Forgets the format and any buffered samples.
  void reset() {
    _resampler = null;
    _downmixer = null;
    _rate = null;
    _channels = null;
  }
}

/// Concatenates [parts] into one list.
Float32List concatSamples(List<Float32List> parts) {
  final total = parts.fold<int>(0, (a, p) => a + p.length);
  final out = Float32List(total);
  var at = 0;
  for (final p in parts) {
    out.setAll(at, p);
    at += p.length;
  }
  return out;
}

// ===========================================================================
// Buffer
// ===========================================================================

/// FIFO of 16 kHz mono system-audio samples between the loopback packets
/// and whoever consumes them (the microphone clock or the wall clock).
///
/// [take] always returns exactly the requested count: buffered samples
/// first, zeros for the rest (loopback delivers nothing while nothing plays).
/// The buffer never holds more than [maxSamples]; older samples are dropped,
/// which bounds the latency between system audio and microphone and
/// absorbs clock drift between the two devices.
class SystemAudioBuffer {
  /// Creates the buffer.
  SystemAudioBuffer({this.maxSamples = kSampleRate ~/ 2})
    : assert(maxSamples > 0, 'maxSamples must be > 0');

  /// Upper bound of buffered samples (default 0.5 s at 16 kHz).
  final int maxSamples;

  final ListQueue<Float32List> _chunks = ListQueue<Float32List>();
  int _headOffset = 0;
  int _length = 0;
  int _dropped = 0;
  int _zeroFilled = 0;

  /// Buffered sample count.
  int get length => _length;

  /// Samples dropped because the buffer was full.
  int get dropped => _dropped;

  /// Zero samples handed out by [take] because the buffer ran short.
  int get zeroFilled => _zeroFilled;

  /// Appends [samples], dropping the oldest ones beyond [maxSamples].
  void add(Float32List samples) {
    if (samples.isEmpty) return;
    var data = samples;
    if (data.length > maxSamples) {
      _dropped += _length + data.length - maxSamples;
      data = Float32List.sublistView(data, data.length - maxSamples);
      clear();
    }
    _chunks.add(Float32List.fromList(data));
    _length += data.length;
    final excess = _length - maxSamples;
    if (excess > 0) {
      _discard(excess);
      _dropped += excess;
    }
  }

  /// Removes and returns exactly [count] samples (zero-filled when short).
  Float32List take(int count) {
    if (count <= 0) return Float32List(0);
    final out = Float32List(count);
    var at = 0;
    while (at < count && _chunks.isNotEmpty) {
      final head = _chunks.first;
      final available = head.length - _headOffset;
      final n = math.min(available, count - at);
      out.setRange(at, at + n, head, _headOffset);
      at += n;
      _headOffset += n;
      _length -= n;
      if (_headOffset >= head.length) {
        _chunks.removeFirst();
        _headOffset = 0;
      }
    }
    _zeroFilled += count - at;
    return out;
  }

  /// Drops everything buffered.
  void clear() {
    _chunks.clear();
    _headOffset = 0;
    _length = 0;
  }

  void _discard(int count) {
    var left = count;
    while (left > 0 && _chunks.isNotEmpty) {
      final head = _chunks.first;
      final available = head.length - _headOffset;
      if (available <= left) {
        _chunks.removeFirst();
        _headOffset = 0;
        left -= available;
      } else {
        _headOffset += left;
        left = 0;
      }
    }
    _length -= count - left;
  }
}

// ===========================================================================
// Silence filler (wall clock)
// ===========================================================================

/// Paces system-only capture by wall clock: WASAPI loopback delivers no
/// packets while nothing plays, so the time line is kept by emitting exactly
/// `elapsed × sampleRate` samples — the buffered audio first, zeros for the
/// silent gaps.
///
/// [lag] gives late packets time to arrive before their slot is emitted
/// (otherwise a delayed packet would be replaced by zeros and then pushed
/// later in time). Paused time is excluded.
class WallClockSilenceFiller {
  /// Creates the filler. [clock] is a monotonic time source (e.g. a
  /// [Stopwatch]'s elapsed time).
  WallClockSilenceFiller({
    required this._clock,
    this.sampleRate = kSampleRate,
    this.lag = const Duration(milliseconds: 150),
  });

  final Duration Function() _clock;

  /// Output rate.
  final int sampleRate;

  /// How far behind the wall clock the output is emitted.
  final Duration lag;

  Duration? _startedAt;
  Duration? _pausedAt;
  Duration _pausedTotal = Duration.zero;
  int _emitted = 0;
  int _silence = 0;

  /// Samples emitted so far.
  int get emitted => _emitted;

  /// Zero samples emitted for silent gaps so far.
  int get silenceSamples => _silence;

  /// True between [start] and [stop].
  bool get isRunning => _startedAt != null;

  /// True while paused.
  bool get isPaused => _pausedAt != null;

  /// Audio time emitted so far.
  Duration get elapsed => Duration(
    microseconds: _emitted * Duration.microsecondsPerSecond ~/ sampleRate,
  );

  /// Starts a take at the current clock time.
  void start() {
    _startedAt = _clock();
    _pausedAt = null;
    _pausedTotal = Duration.zero;
    _emitted = 0;
    _silence = 0;
  }

  /// Pauses the time line (no samples are due while paused).
  void pause() {
    if (_startedAt == null || _pausedAt != null) return;
    _pausedAt = _clock();
  }

  /// Resumes after [pause].
  void resume() {
    final p = _pausedAt;
    if (p == null) return;
    _pausedTotal += _clock() - p;
    _pausedAt = null;
  }

  /// Ends the take.
  void stop() {
    _startedAt = null;
    _pausedAt = null;
  }

  /// Active (unpaused) time since [start].
  Duration get activeTime {
    final s = _startedAt;
    if (s == null) return Duration.zero;
    final now = _pausedAt ?? _clock();
    final t = now - s - _pausedTotal;
    return t.isNegative ? Duration.zero : t;
  }

  /// Number of samples due now (not yet emitted). With [flush] the [lag] is
  /// ignored (end of the take).
  int due({bool flush = false}) {
    if (_startedAt == null) return 0;
    var t = activeTime;
    if (!flush) t -= lag;
    if (t.isNegative) return 0;
    final target =
        t.inMicroseconds * sampleRate ~/ Duration.microsecondsPerSecond;
    return math.max(0, target - _emitted);
  }

  /// Takes the due samples from [buffer]: real audio first, zeros for the
  /// silent rest. Returns an empty list when nothing is due.
  Float32List drain(SystemAudioBuffer buffer, {bool flush = false}) {
    final n = due(flush: flush);
    if (n == 0) return Float32List(0);
    final before = buffer.zeroFilled;
    final out = buffer.take(n);
    _silence += buffer.zeroFilled - before;
    _emitted += n;
    return out;
  }
}

// ===========================================================================
// Mixer
// ===========================================================================

/// Level from which [softLimit] starts compressing.
const double kSoftLimitThreshold = 0.8;

/// Soft limiter: identity below [threshold]; above it, a tanh knee that
/// approaches ±1 smoothly and never exceeds it (continuous, with slope 1 at
/// the knee, so normal speech is untouched and summed peaks do not clip).
double softLimit(double x, {double threshold = kSoftLimitThreshold}) {
  if (x.isNaN) return 0;
  final a = x.abs();
  if (a <= threshold) return x;
  final headroom = 1 - threshold;
  final y = threshold + headroom * _tanh((a - threshold) / headroom);
  return x.isNegative ? -y : y;
}

double _tanh(double v) {
  if (v > 20) return 1;
  final e = math.exp(2 * v);
  return (e - 1) / (e + 1);
}

/// Mixes [mic] and [system] sample by sample (sum with gains) through
/// [softLimit]. The result has the length of the longer input; the shorter
/// one counts as silence where it ends.
Float32List mixSoftLimited(
  Float32List mic,
  Float32List system, {
  double micGain = 1,
  double systemGain = 1,
  double threshold = kSoftLimitThreshold,
}) {
  final n = math.max(mic.length, system.length);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final a = i < mic.length ? mic[i] * micGain : 0.0;
    final b = i < system.length ? system[i] * systemGain : 0.0;
    out[i] = softLimit(a + b, threshold: threshold);
  }
  return out;
}

// ===========================================================================
// Level meter
// ===========================================================================

/// 0..1 level meter over fixed windows, as the microphone service reports
/// it (RMS → dBFS → [dbfsToMeterLevel]).
class LevelMeter {
  /// Creates the meter; [window] samples per reading (default 100 ms).
  LevelMeter({this.window = kSampleRate ~/ 10, this.floorDb = -60});

  /// Samples per reading.
  final int window;

  /// dBFS mapped to 0.
  final double floorDb;

  double _sumSq = 0;
  int _count = 0;

  /// Feeds [samples]; returns the readings completed by them.
  List<double> add(Float32List samples) {
    final readings = <double>[];
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      _sumSq += s * s;
      if (++_count >= window) {
        readings.add(
          dbfsToMeterLevel(
            rmsToDbfs(math.sqrt(_sumSq / _count)),
            floorDb: floorDb,
          ),
        );
        _sumSq = 0;
        _count = 0;
      }
    }
    return readings;
  }

  /// Discards a partial window.
  void reset() {
    _sumSq = 0;
    _count = 0;
  }
}
