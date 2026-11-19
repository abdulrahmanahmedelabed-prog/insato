// Streaming RIFF/WAVE (PCM 16-bit) writer and reader. Pure Dart (dart:io),
// no Flutter dependency.
//
// The writer is designed to survive crashes during multi-hour recordings: a
// valid 44-byte header is written immediately, and the RIFF/data size fields
// are patched (and the file fsync'ed) periodically, so at most the last few
// seconds are missing from the header after a crash. [WavWriter.repair] can
// fix such a file afterwards from its actual length.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/models.dart';
import 'pcm.dart';

/// Size of the canonical PCM WAV header written by [WavWriter].
const int kWavHeaderBytes = 44;

/// Largest value that fits the 32-bit RIFF size fields.
const int _kMaxUint32 = 0xFFFFFFFF;

/// Builds a canonical 44-byte PCM WAV header.
///
/// [dataBytes] is the size of the `data` chunk payload. Values beyond the
/// 32-bit limit are clamped (readers then fall back to the file length).
Uint8List buildWavHeader({
  required int sampleRate,
  required int channels,
  required int dataBytes,
  int bitsPerSample = 16,
}) {
  final blockAlign = channels * (bitsPerSample ~/ 8);
  final header = Uint8List(kWavHeaderBytes);
  final b = ByteData.sublistView(header);
  final data = math.min(dataBytes, _kMaxUint32 - 36);
  // "RIFF"
  header.setRange(0, 4, const [0x52, 0x49, 0x46, 0x46]);
  b.setUint32(4, 36 + data + (data.isOdd ? 1 : 0), Endian.little);
  // "WAVE"
  header.setRange(8, 12, const [0x57, 0x41, 0x56, 0x45]);
  // "fmt "
  header.setRange(12, 16, const [0x66, 0x6d, 0x74, 0x20]);
  b.setUint32(16, 16, Endian.little); // fmt chunk size
  b.setUint16(20, 1, Endian.little); // WAVE_FORMAT_PCM
  b.setUint16(22, channels, Endian.little);
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * blockAlign, Endian.little); // byte rate
  b.setUint16(32, blockAlign, Endian.little);
  b.setUint16(34, bitsPerSample, Endian.little);
  // "data"
  header.setRange(36, 40, const [0x64, 0x61, 0x74, 0x61]);
  b.setUint32(40, data, Endian.little);
  return header;
}

/// Streaming writer for 16-bit PCM WAV files.
///
/// All operations are serialised internally, so callers may fire
/// [appendPcm16] without awaiting each call; awaiting [close] guarantees
/// everything has been written. If a write fails, the error is reported by the
/// failing call (and by every later call), and the writer stops writing.
class WavWriter {
  WavWriter._(
    this.path,
    this._file,
    this.sampleRate,
    this.channels,
    this._patchEveryBytes,
  );

  /// Opens (creating or truncating) [path] and writes a provisional header.
  ///
  /// [patchInterval] controls how often (in audio time) the header sizes are
  /// patched and the file is flushed to disk.
  static Future<WavWriter> open(
    String path, {
    int sampleRate = kSampleRate,
    int channels = 1,
    Duration patchInterval = const Duration(seconds: 5),
  }) async {
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'must be > 0');
    }
    if (channels < 1) {
      throw ArgumentError.value(channels, 'channels', 'must be >= 1');
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.writeFrom(
        buildWavHeader(sampleRate: sampleRate, channels: channels, dataBytes: 0),
      );
      await raf.flush();
    } catch (_) {
      await raf.close();
      rethrow;
    }
    final bytesPerSecond = sampleRate * channels * 2;
    final patchEvery = math.max(
      2,
      (bytesPerSecond * patchInterval.inMicroseconds) ~/
          Duration.microsecondsPerSecond,
    );
    return WavWriter._(path, raf, sampleRate, channels, patchEvery);
  }

  /// Absolute or relative path of the file being written.
  final String path;

  /// Sample rate written in the header.
  final int sampleRate;

  /// Channel count written in the header.
  final int channels;

  final RandomAccessFile _file;
  final int _patchEveryBytes;
  final Pcm16Decoder _aligner = Pcm16Decoder();

  Future<void> _queue = Future<void>.value();
  // Bytes accepted by appendPcm16 (may not be on disk yet).
  int _dataBytes = 0;
  // Bytes actually written to the file; the header never claims more.
  int _fileDataBytes = 0;
  int _bytesSincePatch = 0;
  bool _closed = false;
  Object? _error;

  /// Number of PCM bytes accepted so far (the `data` chunk size).
  int get dataBytes => _dataBytes;

  /// Duration of the audio accepted so far.
  Duration get duration => Duration(
    microseconds:
        (_dataBytes ~/ (2 * channels)) * Duration.microsecondsPerSecond ~/
            sampleRate,
  );

  /// True once [close] has been called.
  bool get isClosed => _closed;

  /// Appends little-endian PCM16 bytes (interleaved if [channels] > 1).
  ///
  /// An odd trailing byte is held back and joined with the next call, so
  /// arbitrary chunking is safe.
  Future<void> appendPcm16(Uint8List bytes) {
    if (_closed) {
      return Future<void>.error(StateError('WavWriter is closed: $path'));
    }
    final aligned = _aligner.align(bytes);
    if (aligned.isEmpty) return _queue;
    // Copy: the caller may reuse its buffer before the write happens.
    final copy = identical(aligned, bytes) ? Uint8List.fromList(bytes) : aligned;
    _dataBytes += copy.length;
    return _enqueue(() async {
      await _file.writeFrom(copy);
      _fileDataBytes += copy.length;
      _bytesSincePatch += copy.length;
      if (_bytesSincePatch >= _patchEveryBytes) {
        await _patchHeader();
      }
    });
  }

  /// Appends float samples (converted to PCM16 with clipping).
  Future<void> appendFloat32(Float32List samples) =>
      appendPcm16(float32ToPcm16Bytes(samples));

  /// Patches the header sizes and flushes the file to stable storage now.
  Future<void> flush() {
    if (_closed) return _queue;
    return _enqueue(_patchHeader);
  }

  /// Writes the final header sizes and closes the file. Idempotent.
  Future<void> close() {
    if (_closed) return _queue;
    _closed = true;
    final done = _queue.then<void>((_) async {
      if (_error == null) {
        await _patchHeader();
      }
    }).whenComplete(() async {
      try {
        await _file.close();
      } catch (_) {
        // Already closed or the handle is invalid; nothing more to do.
      }
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  Future<void> _enqueue(Future<void> Function() op) {
    final result = _queue.then((_) async {
      final err = _error;
      if (err != null) throw err;
      try {
        await op();
      } catch (e) {
        _error = e;
        rethrow;
      }
    });
    // Keep the chain alive even when an operation fails; the error is
    // surfaced through the returned future.
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _patchHeader() async {
    final written = kWavHeaderBytes + _fileDataBytes;
    final header = buildWavHeader(
      sampleRate: sampleRate,
      channels: channels,
      dataBytes: _fileDataBytes,
    );
    await _file.setPosition(4);
    await _file.writeFrom(header, 4, 8);
    await _file.setPosition(40);
    await _file.writeFrom(header, 40, 44);
    await _file.setPosition(written);
    await _file.flush();
    _bytesSincePatch = 0;
  }

  /// Repairs the header of a WAV file whose sizes were not finalised (for
  /// example after a crash), using the actual file length.
  ///
  /// Only files with a canonical 44-byte PCM header (as produced by
  /// [WavWriter]) are modified. Returns true if the header was changed.
  static Future<bool> repair(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final raf = await file.open(mode: FileMode.append);
    try {
      final length = await raf.length();
      if (length < kWavHeaderBytes) return false;
      await raf.setPosition(0);
      final header = await raf.read(kWavHeaderBytes);
      if (header.length < kWavHeaderBytes || !_isCanonicalHeader(header)) {
        return false;
      }
      final b = ByteData.sublistView(header);
      final channels = b.getUint16(22, Endian.little);
      final blockAlign = math.max(1, channels * 2);
      var dataBytes = length - kWavHeaderBytes;
      dataBytes -= dataBytes % blockAlign;
      final clamped = math.min(dataBytes, _kMaxUint32 - 36);
      final riff = 36 + clamped + (clamped.isOdd ? 1 : 0);
      if (b.getUint32(4, Endian.little) == riff &&
          b.getUint32(40, Endian.little) == clamped) {
        return false;
      }
      final patch = ByteData(4);
      patch.setUint32(0, riff, Endian.little);
      await raf.setPosition(4);
      await raf.writeFrom(patch.buffer.asUint8List());
      patch.setUint32(0, clamped, Endian.little);
      await raf.setPosition(40);
      await raf.writeFrom(patch.buffer.asUint8List());
      await raf.flush();
      return true;
    } finally {
      await raf.close();
    }
  }

  static bool _isCanonicalHeader(Uint8List h) {
    bool tag(int at, String s) {
      for (var i = 0; i < 4; i++) {
        if (h[at + i] != s.codeUnitAt(i)) return false;
      }
      return true;
    }

    final b = ByteData.sublistView(h);
    return tag(0, 'RIFF') &&
        tag(8, 'WAVE') &&
        tag(12, 'fmt ') &&
        b.getUint32(16, Endian.little) == 16 &&
        b.getUint16(20, Endian.little) == 1 &&
        b.getUint16(34, Endian.little) == 16 &&
        tag(36, 'data');
  }
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

/// Sample encoding of a WAV file's `data` chunk.
enum WavSampleEncoding {
  /// Integer PCM (8-bit unsigned, 16/24/32-bit signed little-endian).
  pcmInteger,

  /// IEEE float (32 or 64-bit little-endian).
  ieeeFloat,
}

/// Format and layout of a WAV file, as parsed by [readWavInfo].
class WavInfo {
  /// Creates a description of a WAV file.
  const WavInfo({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.encoding,
    required this.dataOffset,
    required this.dataBytes,
  });

  /// Sample rate in Hz.
  final int sampleRate;

  /// Number of interleaved channels.
  final int channels;

  /// Bits per sample (container size).
  final int bitsPerSample;

  /// Integer PCM or IEEE float.
  final WavSampleEncoding encoding;

  /// Byte offset of the first sample in the file.
  final int dataOffset;

  /// Usable size of the sample data in bytes (whole frames only). When the
  /// header was not finalised (crash), this is derived from the file length.
  final int dataBytes;

  /// Bytes per interleaved frame.
  int get blockAlign => channels * (bitsPerSample ~/ 8);

  /// Number of frames (samples per channel).
  int get frameCount => blockAlign == 0 ? 0 : dataBytes ~/ blockAlign;

  /// Audio duration.
  Duration get duration => Duration(
    microseconds: frameCount * Duration.microsecondsPerSecond ~/ sampleRate,
  );
}

FormatException _invalid(String details) =>
    FormatException('Invalid or unsupported WAV file: $details');

/// Parses the header of the WAV file at [path].
///
/// Supports RIFF/WAVE with `WAVE_FORMAT_PCM` (8/16/24/32-bit),
/// `WAVE_FORMAT_IEEE_FLOAT` (32/64-bit) and `WAVE_FORMAT_EXTENSIBLE` with
/// either sub-format. Unknown chunks (`LIST`, `fact`, …) are skipped. A
/// missing, zero or oversized `data` size (an unfinalised recording) is
/// replaced by what the file actually contains.
///
/// Throws a [FormatException] for malformed or unsupported files and a
/// [FileSystemException] if the file cannot be read.
Future<WavInfo> readWavInfo(String path) async {
  final raf = await File(path).open();
  try {
    return await _parseWavInfo(raf);
  } finally {
    await raf.close();
  }
}

Future<WavInfo> _parseWavInfo(RandomAccessFile raf) async {
  final fileLength = await raf.length();
  await raf.setPosition(0);
  final riff = await raf.read(12);
  if (riff.length < 12 ||
      String.fromCharCodes(riff, 0, 4) != 'RIFF' ||
      String.fromCharCodes(riff, 8, 12) != 'WAVE') {
    throw _invalid('missing RIFF/WAVE signature');
  }

  int? formatTag;
  int? channels;
  int? sampleRate;
  int? bits;
  int? dataOffset;
  int? dataSize;

  var pos = 12;
  while (pos + 8 <= fileLength) {
    await raf.setPosition(pos);
    final head = await raf.read(8);
    if (head.length < 8) break;
    final id = String.fromCharCodes(head, 0, 4);
    final size = ByteData.sublistView(head).getUint32(4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ') {
      if (size < 16) throw _invalid('fmt chunk too small ($size)');
      final fmt = await raf.read(math.min(size, 40));
      if (fmt.length < 16) throw _invalid('truncated fmt chunk');
      final f = ByteData.sublistView(fmt);
      formatTag = f.getUint16(0, Endian.little);
      channels = f.getUint16(2, Endian.little);
      sampleRate = f.getUint32(4, Endian.little);
      bits = f.getUint16(14, Endian.little);
      if (formatTag == 0xFFFE) {
        // WAVE_FORMAT_EXTENSIBLE: the sub-format GUID starts at offset 24
        // and its first two bytes are the actual format tag.
        if (fmt.length < 26) throw _invalid('truncated extensible fmt');
        formatTag = f.getUint16(24, Endian.little);
      }
    } else if (id == 'data') {
      dataOffset = body;
      final available = fileLength - body;
      // 0 / 0xFFFFFFFF / too large => header not finalised (or > 4 GiB).
      dataSize = (size == 0 || size >= available) ? available : size;
      if (formatTag != null) break;
    }
    if (id == 'data' && (size == 0 || size >= fileLength - body)) {
      // The data chunk runs to the end of the file; nothing can follow.
      break;
    }
    pos = body + size + (size & 1);
  }

  if (formatTag == null || channels == null || sampleRate == null) {
    throw _invalid('missing fmt chunk');
  }
  if (dataOffset == null || dataSize == null) {
    throw _invalid('missing data chunk');
  }
  if (channels < 1) throw _invalid('channel count $channels');
  if (sampleRate < 1) throw _invalid('sample rate $sampleRate');

  final WavSampleEncoding encoding;
  if (formatTag == 1 && (bits == 8 || bits == 16 || bits == 24 || bits == 32)) {
    encoding = WavSampleEncoding.pcmInteger;
  } else if (formatTag == 3 && (bits == 32 || bits == 64)) {
    encoding = WavSampleEncoding.ieeeFloat;
  } else {
    throw _invalid('format tag $formatTag with $bits bits per sample');
  }
  final blockAlign = channels * (bits! ~/ 8);
  return WavInfo(
    sampleRate: sampleRate,
    channels: channels,
    bitsPerSample: bits,
    encoding: encoding,
    dataOffset: dataOffset,
    dataBytes: dataSize - dataSize % blockAlign,
  );
}

/// Decodes whole interleaved frames of [bytes] to floats in `[-1, 1]`.
Float32List _decodeSamples(Uint8List bytes, WavInfo info) {
  final bytesPerSample = info.bitsPerSample ~/ 8;
  final n = bytes.length ~/ bytesPerSample;
  final data = ByteData.sublistView(bytes);
  if (info.encoding == WavSampleEncoding.ieeeFloat) {
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      final v = bytesPerSample == 4
          ? data.getFloat32(i * 4, Endian.little)
          : data.getFloat64(i * 8, Endian.little);
      out[i] = v.isFinite ? v : 0;
    }
    return out;
  }
  switch (bytesPerSample) {
    case 1:
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        out[i] = (bytes[i] - 128) / 128.0;
      }
      return out;
    case 2:
      return pcm16LeBytesToFloat32(bytes);
    case 3:
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        final o = i * 3;
        var v = bytes[o] | (bytes[o + 1] << 8) | (bytes[o + 2] << 16);
        if (v >= 0x800000) v -= 0x1000000;
        out[i] = v / 8388608.0;
      }
      return out;
    default:
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        out[i] = data.getInt32(i * 4, Endian.little) / 2147483648.0;
      }
      return out;
  }
}

/// Streams the WAV file at [path] as mono float chunks at [outputRate]
/// (default 16 kHz), downmixing and resampling as needed.
///
/// Memory use is bounded by [chunkDuration], which makes this suitable for
/// re-processing multi-hour archives. Errors are as for [readWavInfo].
Stream<Float32List> readWavChunks(
  String path, {
  int outputRate = kSampleRate,
  Duration chunkDuration = const Duration(seconds: 10),
}) async* {
  final raf = await File(path).open();
  try {
    final info = await _parseWavInfo(raf);
    final framesPerChunk = math.max(
      1,
      info.sampleRate * chunkDuration.inMilliseconds ~/ 1000,
    );
    final chunkBytes = framesPerChunk * info.blockAlign;
    final downmixer = InterleavedDownmixer(info.channels);
    final resampler = StreamingResampler(
      inputRate: info.sampleRate,
      outputRate: outputRate,
    );
    var remaining = info.dataBytes;
    await raf.setPosition(info.dataOffset);
    while (remaining > 0) {
      final want = math.min(chunkBytes, remaining);
      final bytes = await raf.read(want);
      if (bytes.isEmpty) break;
      remaining -= bytes.length;
      final whole = bytes.length - bytes.length % info.blockAlign;
      if (whole == 0) break;
      final samples = _decodeSamples(
        whole == bytes.length ? bytes : Uint8List.sublistView(bytes, 0, whole),
        info,
      );
      final out = resampler.process(downmixer.process(samples));
      if (out.isNotEmpty) yield out;
      if (whole < bytes.length) break; // Truncated file: stop at last frame.
    }
    final tail = resampler.flush();
    if (tail.isNotEmpty) yield tail;
  } finally {
    await raf.close();
  }
}

/// Reads the whole WAV file at [path] as mono float samples at [outputRate]
/// (default 16 kHz).
///
/// Accepts 16-bit PCM mono/stereo at any sample rate (plus the other formats
/// listed in [readWavInfo]). For very long files prefer [readWavChunks].
Future<Float32List> readWavAsFloat32(
  String path, {
  int outputRate = kSampleRate,
}) async {
  final chunks = <Float32List>[];
  var total = 0;
  await for (final chunk in readWavChunks(path, outputRate: outputRate)) {
    chunks.add(chunk);
    total += chunk.length;
  }
  if (chunks.length == 1) return chunks.first;
  final out = Float32List(total);
  var offset = 0;
  for (final c in chunks) {
    out.setRange(offset, offset + c.length, c);
    offset += c.length;
  }
  return out;
}
