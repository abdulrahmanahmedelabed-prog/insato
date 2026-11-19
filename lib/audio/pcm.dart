// Pure-Dart PCM helpers: PCM16 <-> Float32 conversion, level metering,
// channel downmix and sample-rate conversion to the pipeline rate
// ([kSampleRate], 16 kHz mono).
//
// Everything here is free of Flutter and I/O so it can run in any isolate and
// be unit-tested with plain `flutter test`.

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/models.dart';

/// Scale used to convert between signed 16-bit integers and floats.
///
/// Decoding divides by 32768 so that the full Int16 range maps onto
/// `[-1.0, 1.0)`; encoding multiplies by 32767 (after clamping) so that `1.0`
/// maps onto `32767` without overflow.
const double _kInt16DecodeScale = 1.0 / 32768.0;
const double _kInt16EncodeScale = 32767.0;

/// Lowest dBFS value reported by [rmsToDbfs] (digital silence).
const double kSilenceDbfs = -120.0;

/// Decodes little-endian signed 16-bit PCM bytes to float samples in
/// `[-1, 1]`.
///
/// If [bytes] has an odd length the trailing byte is ignored. When decoding a
/// stream whose chunks may split a sample across chunk boundaries use
/// [Pcm16Decoder] instead, which carries the dangling byte over.
Float32List pcm16LeBytesToFloat32(Uint8List bytes) {
  final sampleCount = bytes.length >> 1;
  final out = Float32List(sampleCount);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < sampleCount; i++) {
    out[i] = data.getInt16(i << 1, Endian.little) * _kInt16DecodeScale;
  }
  return out;
}

/// Encodes float samples (nominally `[-1, 1]`) to little-endian signed 16-bit
/// PCM bytes.
///
/// Values outside `[-1, 1]` are clamped (hard clipping rather than integer
/// wrap-around) and NaN is written as silence. Samples are rounded to the
/// nearest integer.
Uint8List float32ToPcm16Bytes(Float32List samples) {
  final out = Uint8List(samples.length << 1);
  final data = ByteData.sublistView(out);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i << 1, _floatToInt16(samples[i]), Endian.little);
  }
  return out;
}

int _floatToInt16(double v) {
  if (v.isNaN) return 0;
  if (v >= 1.0) return 32767;
  if (v <= -1.0) return -32767;
  return (v * _kInt16EncodeScale).round();
}

/// Stateful PCM16 little-endian decoder for chunked byte streams.
///
/// Platform audio streams do not guarantee that a chunk ends on a sample
/// boundary. This decoder keeps a dangling odd byte and prepends it to the
/// next chunk, so no sample is ever lost or misaligned.
class Pcm16Decoder {
  int? _pendingByte;

  /// True when a single byte is buffered waiting for its partner.
  bool get hasPendingByte => _pendingByte != null;

  /// Decodes [chunk], returning every complete sample it (together with any
  /// byte left from the previous call) contains.
  Float32List convert(Uint8List chunk) {
    final pending = _pendingByte;
    final total = chunk.length + (pending == null ? 0 : 1);
    final sampleCount = total >> 1;
    final out = Float32List(sampleCount);
    if (sampleCount == 0) {
      if (chunk.isNotEmpty) _pendingByte = chunk[0];
      return out;
    }

    var src = 0;
    var dst = 0;
    if (pending != null) {
      out[dst++] = _toFloat(pending, chunk[0]);
      src = 1;
    }
    final data = ByteData.sublistView(chunk);
    while (src + 1 < chunk.length) {
      out[dst++] = data.getInt16(src, Endian.little) * _kInt16DecodeScale;
      src += 2;
    }
    _pendingByte = src < chunk.length ? chunk[src] : null;
    return out;
  }

  /// Like [convert] but returns the raw, sample-aligned PCM16 bytes instead
  /// of floats. Useful when the bytes are archived verbatim.
  Uint8List align(Uint8List chunk) {
    final pending = _pendingByte;
    final total = chunk.length + (pending == null ? 0 : 1);
    final usable = total & ~1;
    if (pending == null && usable == chunk.length) return chunk;
    final out = Uint8List(usable);
    var src = 0;
    var dst = 0;
    if (pending != null && usable > 0) {
      out[dst++] = pending;
    }
    while (dst < usable) {
      out[dst++] = chunk[src++];
    }
    if (usable == 0) {
      _pendingByte = chunk.isNotEmpty ? chunk[0] : pending;
    } else {
      _pendingByte = src < chunk.length ? chunk[src] : null;
    }
    return out;
  }

  /// Drops any buffered byte (call between unrelated streams).
  void reset() => _pendingByte = null;

  static double _toFloat(int lo, int hi) {
    var v = (hi << 8) | lo;
    if (v >= 0x8000) v -= 0x10000;
    return v * _kInt16DecodeScale;
  }
}

/// Root-mean-square of `samples[start, end)`.
///
/// Returns 0 for an empty range.
double rms(Float32List samples, [int start = 0, int? end]) {
  final stop = end ?? samples.length;
  RangeError.checkValidRange(start, stop, samples.length);
  final n = stop - start;
  if (n <= 0) return 0;
  var sum = 0.0;
  for (var i = start; i < stop; i++) {
    final s = samples[i];
    sum += s * s;
  }
  return math.sqrt(sum / n);
}

/// Converts a linear RMS amplitude (full scale = 1.0) to dBFS.
///
/// Returns [kSilenceDbfs] for zero / negative / non-finite input.
double rmsToDbfs(double rmsValue) {
  if (!(rmsValue > 0) || !rmsValue.isFinite) return kSilenceDbfs;
  final db = 20 * math.log(rmsValue) / math.ln10;
  return db < kSilenceDbfs ? kSilenceDbfs : db;
}

/// Maps a dBFS value to a 0..1 meter level.
///
/// [floorDb] (default -60 dBFS) maps to 0 and 0 dBFS maps to 1, linearly in
/// dB, which matches how loudness is perceived and keeps quiet distant
/// speakers visible on the meter.
double dbfsToMeterLevel(double dbfs, {double floorDb = -60.0}) {
  assert(floorDb < 0, 'floorDb must be negative');
  if (dbfs.isNaN) return 0;
  final level = (dbfs - floorDb) / -floorDb;
  if (level <= 0) return 0;
  if (level >= 1) return 1;
  return level;
}

/// Convenience: 0..1 meter level of [samples] (RMS → dBFS → [dbfsToMeterLevel]).
double meterLevel(Float32List samples, {double floorDb = -60.0}) =>
    dbfsToMeterLevel(rmsToDbfs(rms(samples)), floorDb: floorDb);

/// Downmixes interleaved multi-channel samples to mono by averaging channels.
///
/// [interleaved] must contain whole frames; a trailing partial frame is
/// ignored. With `channels == 1` the input is returned unchanged.
Float32List downmixToMono(Float32List interleaved, int channels) {
  if (channels < 1) {
    throw ArgumentError.value(channels, 'channels', 'must be >= 1');
  }
  if (channels == 1) return interleaved;
  final frames = interleaved.length ~/ channels;
  final out = Float32List(frames);
  final scale = 1.0 / channels;
  var src = 0;
  for (var f = 0; f < frames; f++) {
    var sum = 0.0;
    for (var c = 0; c < channels; c++) {
      sum += interleaved[src++];
    }
    out[f] = sum * scale;
  }
  return out;
}

/// Stateful mono downmixer for chunked interleaved streams.
///
/// Carries a partial frame over to the next chunk, so chunk boundaries that
/// split a frame between channels are handled correctly.
class InterleavedDownmixer {
  /// Creates a downmixer for [channels] interleaved channels.
  InterleavedDownmixer(this.channels)
    : _carry = Float32List(channels > 0 ? channels : 1) {
    if (channels < 1) {
      throw ArgumentError.value(channels, 'channels', 'must be >= 1');
    }
  }

  /// Number of interleaved input channels.
  final int channels;

  final Float32List _carry;
  int _carryLen = 0;

  /// Mixes [interleaved] (plus any partial frame from the previous call) to
  /// mono.
  Float32List process(Float32List interleaved) {
    if (channels == 1) return interleaved;
    final total = _carryLen + interleaved.length;
    final frames = total ~/ channels;
    final out = Float32List(frames);
    final scale = 1.0 / channels;
    var src = 0;
    for (var f = 0; f < frames; f++) {
      var sum = 0.0;
      for (var c = 0; c < channels; c++) {
        final idx = f * channels + c;
        sum += idx < _carryLen ? _carry[idx] : interleaved[src++];
      }
      out[f] = sum * scale;
    }
    // Every carried sample was consumed if at least one frame was produced;
    // otherwise all input is appended to the carry.
    if (frames == 0) {
      for (var i = 0; i < interleaved.length; i++) {
        _carry[_carryLen++] = interleaved[i];
      }
    } else {
      _carryLen = 0;
      while (src < interleaved.length) {
        _carry[_carryLen++] = interleaved[src++];
      }
    }
    return out;
  }

  /// Discards any buffered partial frame.
  void reset() => _carryLen = 0;
}

int _gcd(int a, int b) {
  while (b != 0) {
    final t = a % b;
    a = b;
    b = t;
  }
  return a;
}

/// Streaming sample-rate converter (mono).
///
/// Uses linear interpolation between input samples. When downsampling, the
/// input first passes through a windowed-sinc (Blackman) low-pass FIR filter
/// at ~90 % of the output Nyquist frequency so that energy above 8 kHz (for a
/// 16 kHz target) does not alias into the speech band — this matters for ASR
/// accuracy when a device captures at 44.1/48 kHz. The filter's group delay
/// is compensated, so output sample `k` corresponds to input time
/// `k / outputRate` exactly.
///
/// Positions are tracked with exact integer arithmetic, so there is no drift
/// even over many hours of audio. Call [flush] at the end of the stream to
/// obtain the trailing samples.
class StreamingResampler {
  /// Creates a resampler converting from [inputRate] to [outputRate] Hz.
  StreamingResampler({required this.inputRate, this.outputRate = kSampleRate})
    : _in = inputRate ~/ _gcd(inputRate, outputRate),
      _out = outputRate ~/ _gcd(inputRate, outputRate) {
    if (inputRate <= 0) {
      throw ArgumentError.value(inputRate, 'inputRate', 'must be > 0');
    }
    if (outputRate <= 0) {
      throw ArgumentError.value(outputRate, 'outputRate', 'must be > 0');
    }
    if (inputRate > outputRate) {
      _kernel = _designLowPass(inputRate, outputRate);
      _history = Float32List(_kernel!.length - 1);
      _delayToSkip = (_kernel!.length - 1) ~/ 2;
    }
  }

  /// Input sample rate in Hz.
  final int inputRate;

  /// Output sample rate in Hz.
  final int outputRate;

  // Reduced ratio: each output advances the read position by _in/_out input
  // samples. Positions are expressed in units of 1/_out input samples.
  final int _in;
  final int _out;

  Float32List? _kernel;
  Float32List? _history;
  int _delayToSkip = 0;

  // Filtered input samples not yet fully consumed.
  Float32List _buf = Float32List(0);
  // Read position into _buf, in units of 1/_out samples.
  int _pos = 0;
  bool _flushed = false;

  /// True when input and output rates are equal (samples pass through).
  bool get isPassthrough => inputRate == outputRate;

  /// Converts the next chunk of input samples.
  Float32List process(Float32List input) {
    if (_flushed) {
      throw StateError('StreamingResampler.process() called after flush()');
    }
    if (isPassthrough) return input;
    if (input.isEmpty) return Float32List(0);
    var filtered = _kernel == null ? input : _filter(input);
    if (_delayToSkip > 0) {
      final skip = math.min(_delayToSkip, filtered.length);
      _delayToSkip -= skip;
      filtered = Float32List.sublistView(filtered, skip);
    }
    return _interpolate(filtered, isFinal: false);
  }

  /// Emits the remaining samples at the end of the stream. The resampler
  /// cannot be used afterwards.
  Float32List flush() {
    if (_flushed) return Float32List(0);
    _flushed = true;
    if (isPassthrough) return Float32List(0);
    var tail = Float32List(0);
    if (_kernel != null) {
      // Push zeros through the filter to release its group delay.
      final delay = (_kernel!.length - 1) ~/ 2;
      tail = _filter(Float32List(delay));
      if (_delayToSkip > 0) {
        final skip = math.min(_delayToSkip, tail.length);
        _delayToSkip -= skip;
        tail = Float32List.sublistView(tail, skip);
      }
    }
    return _interpolate(tail, isFinal: true);
  }

  Float32List _filter(Float32List input) {
    final kernel = _kernel!;
    final history = _history!;
    final taps = kernel.length;
    final hLen = history.length;
    // Contiguous working signal: history ++ input.
    final work = Float32List(hLen + input.length)
      ..setRange(0, hLen, history)
      ..setRange(hLen, hLen + input.length, input);
    final out = Float32List(input.length);
    for (var n = 0; n < input.length; n++) {
      // The kernel is symmetric, so correlation equals convolution.
      var acc = 0.0;
      for (var k = 0; k < taps; k++) {
        acc += kernel[k] * work[n + k];
      }
      out[n] = acc;
    }
    // Keep the last hLen samples of the working signal as history.
    history.setRange(0, hLen, work, work.length - hLen);
    return out;
  }

  Float32List _interpolate(Float32List input, {required bool isFinal}) {
    // Concatenate carry + input.
    final Float32List buf;
    if (_buf.isEmpty) {
      buf = input;
    } else if (input.isEmpty) {
      buf = _buf;
    } else {
      buf = Float32List(_buf.length + input.length)
        ..setRange(0, _buf.length, _buf)
        ..setRange(_buf.length, _buf.length + input.length, input);
    }
    final len = buf.length;
    // Interior outputs need both neighbours (index i + 1 < len), i.e.
    // _pos < (len - 1) * _out. On the final flush, outputs whose time lies
    // in the last sample interval hold the last sample (_pos < len * _out).
    final limit = (isFinal ? len : len - 1) * _out;
    final count = _pos < limit ? (limit - _pos + _in - 1) ~/ _in : 0;
    final out = Float32List(count);
    for (var k = 0; k < count; k++) {
      final i = _pos ~/ _out;
      final frac = _pos - i * _out;
      final a = buf[i];
      if (frac == 0 || i + 1 >= len) {
        out[k] = a;
      } else {
        out[k] = a + (buf[i + 1] - a) * (frac / _out);
      }
      _pos += _in;
    }
    // Drop fully consumed samples, keep the rest for the next call.
    final consumed = math.min(_pos ~/ _out, len);
    _pos -= consumed * _out;
    _buf = consumed >= len
        ? Float32List(0)
        : Float32List.fromList(Float32List.sublistView(buf, consumed));
    return out;
  }

  static Float32List _designLowPass(int inputRate, int outputRate) {
    final ratio = inputRate / outputRate;
    // Cut-off at 90 % of the output Nyquist, as a fraction of input rate.
    final fc = 0.45 / ratio;
    // Enough taps for a reasonably sharp transition band; odd for symmetry.
    var taps = (ratio * 32).ceil();
    if (taps < 31) taps = 31;
    if (taps > 511) taps = 511;
    if (taps.isEven) taps++;
    final m = taps - 1;
    final kernel = Float32List(taps);
    var sum = 0.0;
    for (var n = 0; n < taps; n++) {
      final x = n - m / 2;
      final sinc = x == 0
          ? 2 * fc
          : math.sin(2 * math.pi * fc * x) / (math.pi * x);
      final window =
          0.42 -
          0.5 * math.cos(2 * math.pi * n / m) +
          0.08 * math.cos(4 * math.pi * n / m);
      final v = sinc * window;
      kernel[n] = v;
      sum += v;
    }
    for (var n = 0; n < taps; n++) {
      kernel[n] = kernel[n] / sum;
    }
    return kernel;
  }
}

/// One-shot resampling of a complete mono signal from [fromRate] to
/// [toRate] (default [kSampleRate]).
///
/// Linear interpolation with an anti-aliasing low-pass when downsampling (see
/// [StreamingResampler]). The output has `round(input.length * toRate /
/// fromRate)` samples (±1).
Float32List resampleLinear(
  Float32List input,
  int fromRate, [
  int toRate = kSampleRate,
]) {
  if (fromRate == toRate) return input;
  final r = StreamingResampler(inputRate: fromRate, outputRate: toRate);
  final a = r.process(input);
  final b = r.flush();
  if (b.isEmpty) return a;
  return Float32List(a.length + b.length)
    ..setRange(0, a.length, a)
    ..setRange(a.length, a.length + b.length, b);
}

/// Converts a chunked PCM16 little-endian stream of any sample rate and
/// channel count into 16 kHz (or [outputRate]) mono float samples.
///
/// Chains [Pcm16Decoder] → [InterleavedDownmixer] → [StreamingResampler], all
/// of which carry state across chunk boundaries.
class PcmStreamConverter {
  /// Creates a converter for the given input format.
  PcmStreamConverter({
    required this.inputSampleRate,
    required this.inputChannels,
    this.outputRate = kSampleRate,
  }) : _downmixer = InterleavedDownmixer(inputChannels),
       _resampler = StreamingResampler(
         inputRate: inputSampleRate,
         outputRate: outputRate,
       );

  /// Input sample rate in Hz.
  final int inputSampleRate;

  /// Number of interleaved input channels.
  final int inputChannels;

  /// Output sample rate in Hz (mono).
  final int outputRate;

  final Pcm16Decoder _decoder = Pcm16Decoder();
  final InterleavedDownmixer _downmixer;
  final StreamingResampler _resampler;

  /// True when the input already is mono at [outputRate], i.e. the bytes can
  /// be archived verbatim.
  bool get isIdentity => inputChannels == 1 && inputSampleRate == outputRate;

  /// Converts the next chunk of PCM16 bytes.
  Float32List convert(Uint8List bytes) =>
      _resampler.process(_downmixer.process(_decoder.convert(bytes)));

  /// Returns the trailing samples held by the resampler. The converter cannot
  /// be used afterwards.
  Float32List flush() => _resampler.flush();
}
