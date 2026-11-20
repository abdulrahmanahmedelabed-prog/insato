// Decoding of an imported audio file to the pipeline's format (16 kHz mono
// float samples), in bounded chunks.
//
// * WAV (PCM / float) is read in pure Dart on every platform
//   (`readWavChunks`), no native code involved.
// * Everything else goes through the platform's own decoders behind the
//   MethodChannel `insato/audio_decoder` (Android MediaExtractor +
//   MediaCodec, iOS AVAssetReader, Windows Media Foundation
//   IMFSourceReader; see MainActivity / AudioDecoderChannel.kt,
//   AppDelegate.swift and windows/runner/audio_decoder_channel.cpp). The
//   platform hands over interleaved PCM16 at the file's own rate and channel
//   count, pulled chunk by chunk (natural back-pressure, nothing is decoded
//   ahead of the consumer); the Dart side downmixes and resamples with the
//   same [PcmStreamConverter] the live capture uses. No paid service, no
//   ffmpeg.
//
// Wire protocol of `insato/audio_decoder` (all calls answer on the platform
// thread):
//   isSupported → bool
//   open {path} → {handle: int, sampleRate: int, channels: int,
//                  durationMs: int?, codec: String?, creationDate: String?}
//   read {handle, maxBytes} → {data: Uint8List (PCM16LE interleaved),
//                  sampleRate: int, channels: int} | null (end of stream)
//   close {handle} → null
// Errors: PlatformException codes `unsupported` (no audio track / no
// decoder for the codec), `not_found`, `io`, `decode`.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../audio/pcm.dart';
import '../../audio/wav_writer.dart';
import '../../core/errors.dart';
import '../../core/models.dart' show kSampleRate;
import 'audio_formats.dart';
import 'strings.dart';

// ===========================================================================
// Errors
// ===========================================================================

/// Why an import was refused or failed.
enum ImportFailure {
  /// The file does not exist (any more).
  notFound,

  /// The file cannot be read.
  unreadable,

  /// Zero bytes.
  empty,

  /// Not an audio file.
  notAudio,

  /// Larger than [kMaxImportBytes].
  tooLarge,

  /// Longer than [kMaxImportDuration].
  tooLong,

  /// Shorter than [kMinImportDuration] or silent.
  tooShort,

  /// No decoder for the format on this device.
  unsupported,

  /// The decoder failed (corrupt / truncated file).
  decodeFailed,

  /// Storage full while writing the converted audio.
  noSpace,

  /// Another import or a live recording is running.
  busy,
}

/// An import failure with an Arabic message.
class ImportException extends InsatoException {
  /// Creates the exception.
  const ImportException(
    this.failure,
    super.messageAr, {
    super.debugDetails,
    super.cause,
  });

  /// The kind of failure.
  final ImportFailure failure;
}

// ===========================================================================
// Platform decoder seam
// ===========================================================================

/// Stream properties a platform decoder reports when opening a file.
class NativeAudioInfo {
  /// Creates the info.
  const NativeAudioInfo({
    required this.sampleRate,
    required this.channels,
    this.durationMs,
    this.codec,
    this.creationDate,
  });

  /// Output sample rate (Hz) of the first chunk.
  final int sampleRate;

  /// Output channel count of the first chunk.
  final int channels;

  /// Duration when the container states it.
  final int? durationMs;

  /// Codec / MIME label for display and logs (e.g. `audio/mp4a-latm`).
  final String? codec;

  /// Container creation date as the platform reports it (parsed by
  /// `parseContainerDate`).
  final String? creationDate;
}

/// One chunk of decoded PCM.
class PcmChunk {
  /// Creates a chunk.
  const PcmChunk(this.bytes, {required this.sampleRate, required this.channels});

  /// Interleaved PCM16 little-endian.
  final Uint8List bytes;

  /// Sample rate (Hz).
  final int sampleRate;

  /// Interleaved channels.
  final int channels;
}

/// An open platform decoding session.
abstract interface class NativeDecodeSession {
  /// Properties of the stream.
  NativeAudioInfo get info;

  /// The next chunk, or null at the end of the stream.
  Future<PcmChunk?> read();

  /// Releases the decoder. Idempotent.
  Future<void> close();
}

/// Opens files with the platform's decoders.
abstract interface class NativeAudioDecoder {
  /// Whether this platform has a decoder implementation.
  Future<bool> isSupported();

  /// Opens [path]. Throws [ImportException] (unsupported / not found /
  /// decode).
  Future<NativeDecodeSession> open(String path);
}

/// Maps a platform error code to an [ImportException].
ImportException importExceptionForPlatformCode(
  String code, {
  String? formatLabel,
  String? details,
}) {
  return switch (code) {
    'unsupported' => ImportException(
      ImportFailure.unsupported,
      formatLabel == null
          ? IS.unsupportedUnknown
          : IS.unsupported(formatLabel),
      debugDetails: details,
    ),
    'not_found' => ImportException(
      ImportFailure.notFound,
      IS.notFound,
      debugDetails: details,
    ),
    'io' => ImportException(
      ImportFailure.unreadable,
      IS.unreadable,
      debugDetails: details,
    ),
    _ => ImportException(
      ImportFailure.decodeFailed,
      IS.decodeFailed,
      debugDetails: '$code: $details',
    ),
  };
}

/// [NativeAudioDecoder] over the MethodChannel `insato/audio_decoder`.
class MethodChannelAudioDecoder implements NativeAudioDecoder {
  /// Creates the decoder.
  const MethodChannelAudioDecoder({
    this.channel = const MethodChannel('insato/audio_decoder'),
    this.maxChunkBytes = 256 * 1024,
  });

  /// The channel.
  final MethodChannel channel;

  /// Upper bound of PCM bytes per [NativeDecodeSession.read].
  final int maxChunkBytes;

  @override
  Future<bool> isSupported() async {
    try {
      return await channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<NativeDecodeSession> open(String path) async {
    final Map<String, Object?>? r;
    try {
      r = await channel.invokeMapMethod<String, Object?>('open', {
        'path': path,
      });
    } on MissingPluginException catch (e) {
      throw ImportException(
        ImportFailure.unsupported,
        IS.unsupportedUnknown,
        debugDetails: 'no platform decoder: $e',
      );
    } on PlatformException catch (e) {
      throw importExceptionForPlatformCode(e.code, details: e.message);
    }
    final handle = r?['handle'];
    final rate = r?['sampleRate'];
    final channels = r?['channels'];
    if (handle is! int || rate is! int || channels is! int) {
      throw const ImportException(
        ImportFailure.decodeFailed,
        IS.decodeFailed,
        debugDetails: 'malformed open reply',
      );
    }
    final duration = r?['durationMs'];
    return _ChannelSession(
      this,
      handle,
      NativeAudioInfo(
        sampleRate: rate,
        channels: channels,
        durationMs: duration is int && duration > 0 ? duration : null,
        codec: r?['codec'] as String?,
        creationDate: r?['creationDate'] as String?,
      ),
    );
  }
}

class _ChannelSession implements NativeDecodeSession {
  _ChannelSession(this._owner, this._handle, this.info);

  final MethodChannelAudioDecoder _owner;
  final int _handle;
  bool _closed = false;

  @override
  final NativeAudioInfo info;

  @override
  Future<PcmChunk?> read() async {
    if (_closed) return null;
    final Map<String, Object?>? r;
    try {
      r = await _owner.channel.invokeMapMethod<String, Object?>('read', {
        'handle': _handle,
        'maxBytes': _owner.maxChunkBytes,
      });
    } on PlatformException catch (e) {
      throw importExceptionForPlatformCode(e.code, details: e.message);
    }
    if (r == null) return null;
    final data = r['data'];
    final rate = r['sampleRate'];
    final channels = r['channels'];
    if (data is! Uint8List || rate is! int || channels is! int) {
      throw const ImportException(
        ImportFailure.decodeFailed,
        IS.decodeFailed,
        debugDetails: 'malformed read reply',
      );
    }
    return PcmChunk(data, sampleRate: rate, channels: channels);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _owner.channel.invokeMethod<void>('close', {'handle': _handle});
    } on PlatformException {
      // Already released.
    } on MissingPluginException {
      // Nothing to release.
    }
  }
}

// ===========================================================================
// Conversion to 16 kHz mono
// ===========================================================================

/// Converts a stream of [PcmChunk]s (whose format may change mid-stream,
/// e.g. HE-AAC reporting its doubled SBR rate after the first frames) into
/// mono float samples at [outputRate].
Stream<Float32List> pcmChunksToMono(
  Stream<PcmChunk> chunks, {
  int outputRate = kSampleRate,
}) async* {
  PcmStreamConverter? converter;
  await for (final c in chunks) {
    if (c.sampleRate <= 0 || c.channels <= 0) {
      throw ImportException(
        ImportFailure.decodeFailed,
        IS.decodeFailed,
        debugDetails: 'invalid format ${c.sampleRate} Hz × ${c.channels}',
      );
    }
    final current = converter;
    if (current == null ||
        current.inputSampleRate != c.sampleRate ||
        current.inputChannels != c.channels) {
      if (current != null) {
        final tail = current.flush();
        if (tail.isNotEmpty) yield tail;
      }
      converter = PcmStreamConverter(
        inputSampleRate: c.sampleRate,
        inputChannels: c.channels,
        outputRate: outputRate,
      );
    }
    if (c.bytes.isEmpty) continue;
    final out = converter!.convert(c.bytes);
    if (out.isNotEmpty) yield out;
  }
  final tail = converter?.flush();
  if (tail != null && tail.isNotEmpty) yield tail;
}

/// An audio file opened for import.
class DecodedAudio {
  /// Creates the description.
  DecodedAudio({
    required this.container,
    required this.sourceSampleRate,
    required this.sourceChannels,
    required this._samples,
    required this._close,
    this.durationMs,
    this.codec,
    this.creationDate,
    this.nativeDecoder = false,
  });

  /// The detected container.
  final AudioContainer container;

  /// Duration from the header (null when unknown).
  final int? durationMs;

  /// Sample rate of the file.
  final int sourceSampleRate;

  /// Channels of the file.
  final int sourceChannels;

  /// Codec label reported by the decoder.
  final String? codec;

  /// Container creation date (raw, see `parseContainerDate`).
  final String? creationDate;

  /// True when the platform decoder is used.
  final bool nativeDecoder;

  final Stream<Float32List> Function() _samples;
  final Future<void> Function() _close;
  bool _listened = false;

  /// The audio as 16 kHz mono floats (single subscription; may be listened
  /// to once). Cancelling the subscription releases the decoder.
  Stream<Float32List> samples() {
    if (_listened) throw StateError('DecodedAudio.samples() called twice');
    _listened = true;
    return _samples();
  }

  /// Releases the decoder (also done when [samples] ends or is cancelled).
  Future<void> close() => _close();
}

/// Opens audio files for import: pure-Dart WAV, platform decoders for the
/// rest.
class ImportAudioDecoder {
  /// Creates the decoder over [native] (null = no platform decoder, e.g.
  /// in tests: only WAV works).
  const ImportAudioDecoder({this.native});

  /// The platform decoder.
  final NativeAudioDecoder? native;

  /// Opens [path] whose container was detected as [container].
  ///
  /// Throws [ImportException].
  Future<DecodedAudio> open(String path, AudioContainer container) async {
    if (container == AudioContainer.wav) {
      final wav = await _tryWav(path);
      if (wav != null) return wav;
      // Compressed WAV (µ-law, ADPCM, GSM from some call recorders): let
      // the platform try.
    }
    final decoder = native;
    if (decoder == null) {
      throw ImportException(
        ImportFailure.unsupported,
        IS.unsupported(container.label),
        debugDetails: 'no platform decoder for ${container.name}',
      );
    }
    final NativeDecodeSession session;
    try {
      session = await decoder.open(path);
    } on ImportException catch (e) {
      if (e.failure == ImportFailure.unsupported) {
        throw ImportException(
          ImportFailure.unsupported,
          IS.unsupported(container.label),
          debugDetails: e.debugDetails,
          cause: e,
        );
      }
      rethrow;
    }
    final info = session.info;
    Stream<PcmChunk> chunks() async* {
      try {
        while (true) {
          final c = await session.read();
          if (c == null) break;
          yield c;
        }
      } finally {
        await session.close();
      }
    }

    return DecodedAudio(
      container: container,
      durationMs: info.durationMs,
      sourceSampleRate: info.sampleRate,
      sourceChannels: info.channels,
      codec: info.codec,
      creationDate: info.creationDate,
      nativeDecoder: true,
      samples: () => pcmChunksToMono(chunks()),
      close: session.close,
    );
  }

  Future<DecodedAudio?> _tryWav(String path) async {
    final WavInfo info;
    try {
      info = await readWavInfo(path);
    } on FormatException {
      return null;
    } on FileSystemException catch (e) {
      throw ImportException(
        ImportFailure.unreadable,
        IS.unreadable,
        debugDetails: e.message,
        cause: e,
      );
    }
    return DecodedAudio(
      container: AudioContainer.wav,
      durationMs: info.duration.inMilliseconds,
      sourceSampleRate: info.sampleRate,
      sourceChannels: info.channels,
      codec: info.encoding == WavSampleEncoding.ieeeFloat
          ? 'pcm_f${info.bitsPerSample}'
          : 'pcm_s${info.bitsPerSample}',
      samples: () => readWavChunks(path, chunkDuration: const Duration(seconds: 5)),
      close: () async {},
    );
  }
}
