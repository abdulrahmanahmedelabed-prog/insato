// Lossless PCM16 compression for multi-device audio frames (v1.2 C).
//
// No maintained Opus encoder covers Android, iOS and Windows from Dart, so
// guests send 16 kHz mono PCM16 with a simple lossless codec: first-order
// prediction (sample − previous sample), zig-zag mapping, then Rice coding
// with a parameter chosen per block of 256 residuals. Speech typically
// shrinks to 55–75 % of raw PCM16; when a frame would not get smaller it is
// sent raw. The decoder reproduces the exact Int16 samples.
//
// Wire format of an encoded frame:
//   byte 0      codec: 0 = raw PCM16 little-endian, 1 = delta + Rice
//   bytes 1..2  sample count (uint16, little-endian)
//   raw:  count × int16 LE
//   rice: int16 LE first sample, then a bit stream (MSB first): per block,
//         4 bits k, then per residual: unary quotient (q ones, a zero) and
//         k remainder bits; q ≥ 24 is an escape followed by 17 raw bits.
//
// Pure Dart.

import 'dart:math' as math;
import 'dart:typed_data';

/// Codec byte of raw PCM16 frames.
const int kPcmCodecRaw = 0;

/// Codec byte of delta + Rice frames.
const int kPcmCodecRice = 1;

/// Largest number of samples in one encoded frame.
const int kMaxCodecSamples = 65535;

const int _block = 256;
const int _escapeQ = 24;

/// Float samples in [-1, 1] → Int16 (clamped, rounded).
Int16List floatToInt16(Float32List samples) {
  final out = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * 32767).round();
    out[i] = v > 32767 ? 32767 : (v < -32768 ? -32768 : v);
  }
  return out;
}

/// Int16 → float samples in [-1, 1).
Float32List int16ToFloat(Int16List samples) {
  final out = Float32List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    out[i] = samples[i] / 32768.0;
  }
  return out;
}

class _BitWriter {
  _BitWriter(int capacity) : _bytes = Uint8List(capacity);
  Uint8List _bytes;
  int _pos = 0; // bytes written
  int _acc = 0;
  int _nbits = 0;

  void _ensure(int extra) {
    if (_pos + extra <= _bytes.length) return;
    final grown = Uint8List(math.max(_bytes.length * 2, _pos + extra + 16));
    grown.setRange(0, _pos, _bytes);
    _bytes = grown;
  }

  void writeBits(int value, int count) {
    // count ≤ 24 per call keeps the accumulator within 32 bits.
    for (var c = count; c > 0;) {
      final take = math.min(c, 16);
      c -= take;
      _acc = (_acc << take) | ((value >> c) & ((1 << take) - 1));
      _nbits += take;
      while (_nbits >= 8) {
        _ensure(1);
        _nbits -= 8;
        _bytes[_pos++] = (_acc >> _nbits) & 0xFF;
      }
      _acc &= (1 << _nbits) - 1;
    }
  }

  void writeUnary(int q) {
    var n = q;
    while (n >= 16) {
      writeBits(0xFFFF, 16);
      n -= 16;
    }
    writeBits(((1 << n) - 1) << 1, n + 1);
  }

  Uint8List finish() {
    if (_nbits > 0) {
      _ensure(1);
      _bytes[_pos++] = (_acc << (8 - _nbits)) & 0xFF;
      _nbits = 0;
      _acc = 0;
    }
    return Uint8List.sublistView(_bytes, 0, _pos);
  }
}

class _BitReader {
  _BitReader(this._bytes, this._pos);
  final Uint8List _bytes;
  int _pos;
  int _acc = 0;
  int _nbits = 0;

  int readBit() {
    if (_nbits == 0) {
      if (_pos >= _bytes.length) {
        throw const FormatException('Truncated audio frame');
      }
      _acc = _bytes[_pos++];
      _nbits = 8;
    }
    _nbits--;
    return (_acc >> _nbits) & 1;
  }

  int readBits(int count) {
    var v = 0;
    for (var i = 0; i < count; i++) {
      v = (v << 1) | readBit();
    }
    return v;
  }

  int readUnary(int limit) {
    var q = 0;
    while (readBit() == 1) {
      q++;
      if (q > limit) throw const FormatException('Bad Rice code');
    }
    return q;
  }
}

int _zigzag(int v) => v >= 0 ? v << 1 : ((-v) << 1) - 1;
int _unzigzag(int u) => (u & 1) == 0 ? u >> 1 : -((u + 1) >> 1);

int _riceK(Int32List z, int start, int end) {
  var sum = 0;
  for (var i = start; i < end; i++) {
    sum += z[i];
  }
  final n = end - start;
  if (n == 0) return 0;
  final mean = sum / n;
  var k = 0;
  while (k < 15 && (1 << (k + 1)) <= mean + 1) {
    k++;
  }
  return k;
}

/// Encodes [samples] (≤ [kMaxCodecSamples]); never larger than raw + 3.
Uint8List encodePcm16(Int16List samples) {
  final n = samples.length;
  if (n > kMaxCodecSamples) {
    throw ArgumentError.value(n, 'samples.length', 'too many samples');
  }
  final raw = Uint8List(3 + 2 * n);
  raw[0] = kPcmCodecRaw;
  raw[1] = n & 0xFF;
  raw[2] = n >> 8;
  final bd = ByteData.sublistView(raw);
  for (var i = 0; i < n; i++) {
    bd.setInt16(3 + 2 * i, samples[i], Endian.little);
  }
  if (n < 2) return raw;

  final z = Int32List(n - 1);
  for (var i = 1; i < n; i++) {
    z[i - 1] = _zigzag(samples[i] - samples[i - 1]);
  }
  final w = _BitWriter(2 * n);
  for (var b = 0; b < z.length; b += _block) {
    final end = math.min(z.length, b + _block);
    final k = _riceK(z, b, end);
    w.writeBits(k, 4);
    for (var i = b; i < end; i++) {
      final v = z[i];
      final q = v >> k;
      if (q >= _escapeQ) {
        w.writeUnary(_escapeQ);
        w.writeBits(v, 17);
      } else {
        w.writeUnary(q);
        if (k > 0) w.writeBits(v & ((1 << k) - 1), k);
      }
    }
  }
  final body = w.finish();
  if (5 + body.length >= raw.length) return raw;
  final out = Uint8List(5 + body.length);
  out[0] = kPcmCodecRice;
  out[1] = n & 0xFF;
  out[2] = n >> 8;
  ByteData.sublistView(out).setInt16(3, samples[0], Endian.little);
  out.setRange(5, out.length, body);
  return out;
}

/// Decodes [encodePcm16] output; throws a [FormatException] when malformed.
Int16List decodePcm16(Uint8List data) {
  if (data.length < 3) throw const FormatException('Short audio frame');
  final codec = data[0];
  final n = data[1] | (data[2] << 8);
  final out = Int16List(n);
  final bd = ByteData.sublistView(data);
  switch (codec) {
    case kPcmCodecRaw:
      if (data.length != 3 + 2 * n) {
        throw const FormatException('Bad raw frame length');
      }
      for (var i = 0; i < n; i++) {
        out[i] = bd.getInt16(3 + 2 * i, Endian.little);
      }
      return out;
    case kPcmCodecRice:
      if (n < 2 || data.length < 5) {
        throw const FormatException('Bad Rice frame');
      }
      out[0] = bd.getInt16(3, Endian.little);
      final r = _BitReader(data, 5);
      var prev = out[0];
      var i = 1;
      while (i < n) {
        final k = r.readBits(4);
        final end = math.min(n, i + _block);
        for (; i < end; i++) {
          final q = r.readUnary(_escapeQ);
          final int v;
          if (q >= _escapeQ) {
            v = r.readBits(17);
          } else {
            v = (q << k) | (k > 0 ? r.readBits(k) : 0);
          }
          final s = prev + _unzigzag(v);
          if (s < -32768 || s > 32767) {
            throw const FormatException('Sample out of range');
          }
          out[i] = s;
          prev = s;
        }
      }
      return out;
    default:
      throw FormatException('Unknown audio codec $codec');
  }
}
