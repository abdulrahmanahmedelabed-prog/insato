// Test doubles of the recording import: a platform decoder that hands over
// prepared PCM chunks (optionally gated, to cancel mid-way).

import 'dart:async';
import 'dart:typed_data';

import 'package:insato/audio/pcm.dart';
import 'package:insato/features/import_audio/audio_decoder.dart';

/// PCM16 bytes of mono float [samples].
Uint8List pcm16(Float32List samples) => float32ToPcm16Bytes(samples);

/// Interleaves [left] / [right] into stereo PCM16.
Uint8List stereoPcm16(Float32List left, Float32List right) {
  final inter = Float32List(left.length * 2);
  for (var i = 0; i < left.length; i++) {
    inter[2 * i] = left[i];
    inter[2 * i + 1] = right[i];
  }
  return float32ToPcm16Bytes(inter);
}

/// A [NativeAudioDecoder] that serves [chunks].
class FakeNativeDecoder implements NativeAudioDecoder {
  FakeNativeDecoder({
    this.chunks = const [],
    this.info = const NativeAudioInfo(sampleRate: 16000, channels: 1),
    this.openError,
    this.readError,
    this.readErrorAfter,
  });

  /// Served in order by [NativeDecodeSession.read].
  List<PcmChunk> chunks;

  /// What [open] reports.
  NativeAudioInfo info;

  /// Thrown by [open].
  ImportException? openError;

  /// Thrown by read number [readErrorAfter] (0-based).
  ImportException? readError;

  /// See [readError].
  int? readErrorAfter;

  /// Before each read (e.g. to cancel at a given point).
  void Function(int readIndex)? onRead;

  /// Paths opened.
  final List<String> opened = [];

  /// Sessions closed.
  int closed = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<NativeDecodeSession> open(String path) async {
    opened.add(path);
    final e = openError;
    if (e != null) throw e;
    return _FakeSession(this);
  }
}

class _FakeSession implements NativeDecodeSession {
  _FakeSession(this._owner);

  final FakeNativeDecoder _owner;
  int _next = 0;
  bool _closed = false;

  @override
  NativeAudioInfo get info => _owner.info;

  @override
  Future<PcmChunk?> read() async {
    await Future<void>.delayed(Duration.zero);
    _owner.onRead?.call(_next);
    if (_owner.readErrorAfter == _next && _owner.readError != null) {
      throw _owner.readError!;
    }
    if (_next >= _owner.chunks.length) return null;
    return _owner.chunks[_next++];
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _owner.closed++;
  }
}
