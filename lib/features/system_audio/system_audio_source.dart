// Dart client of the Windows system-audio capture (F13).
//
// The native side (windows/runner/system_audio_channel.cpp) captures the
// default render endpoint with WASAPI loopback and sends interleaved float32
// packets with their format over the EventChannel `insato/system_audio`;
// `insato/system_audio/control` starts / stops it. [SystemAudioSource]
// converts the packets to 16 kHz mono into a [SystemAudioBuffer] and turns
// native status events into Arabic warnings.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../core/errors.dart';
import 'strings.dart';
import 'system_audio_dsp.dart';

// ===========================================================================
// Events
// ===========================================================================

/// An event of the native capture.
sealed class SystemAudioEvent {
  const SystemAudioEvent();
}

/// Captured audio: interleaved float32 at [sampleRate] × [channels].
final class SystemAudioPacket extends SystemAudioEvent {
  /// Creates the packet.
  const SystemAudioPacket({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  /// Sample rate of the render endpoint's mix format.
  final int sampleRate;

  /// Channel count of the mix format.
  final int channels;

  /// Interleaved samples.
  final Float32List samples;
}

/// Kind of a [SystemAudioStatus].
enum SystemAudioStatusKind {
  /// Capture opened the default output device.
  started,

  /// The default output device changed; capture moved to the new one.
  restarted,

  /// A capture problem; the native side retries by itself.
  error,
}

/// A status change of the native capture.
final class SystemAudioStatus extends SystemAudioEvent {
  /// Creates the status.
  const SystemAudioStatus(this.kind, {this.code});

  /// What happened.
  final SystemAudioStatusKind kind;

  /// Error code for [SystemAudioStatusKind.error]: `no_device`, `init`,
  /// `format`, `capture`, `com`.
  final String? code;
}

/// Parses one EventChannel message; null when it is not understood.
SystemAudioEvent? parseSystemAudioEvent(Object? raw) {
  if (raw is! Map) return null;
  switch (raw['type']) {
    case 'audio':
      final rate = raw['rate'];
      final channels = raw['channels'];
      final samples = raw['samples'];
      if (rate is! int || channels is! int || rate <= 0 || channels <= 0) {
        return null;
      }
      final Float32List data;
      if (samples is Float32List) {
        data = samples;
      } else if (samples is List) {
        data = Float32List.fromList([
          for (final s in samples)
            if (s is num) s.toDouble() else 0.0,
        ]);
      } else {
        return null;
      }
      return SystemAudioPacket(
        sampleRate: rate,
        channels: channels,
        samples: data,
      );
    case 'started':
      return const SystemAudioStatus(SystemAudioStatusKind.started);
    case 'restarted':
      return const SystemAudioStatus(SystemAudioStatusKind.restarted);
    case 'error':
      final code = raw['code'];
      return SystemAudioStatus(
        SystemAudioStatusKind.error,
        code: code is String ? code : null,
      );
  }
  return null;
}

/// Arabic warning for a native error [code].
String systemAudioErrorMessage(String? code) => switch (code) {
  'no_device' => SystemAudioStrings.noDevice,
  'format' => SystemAudioStrings.unsupportedFormat,
  _ => SystemAudioStrings.captureProblem,
};

// ===========================================================================
// Platform seam
// ===========================================================================

/// The native capture surface (replaced by a fake in tests).
abstract class SystemAudioPlatform {
  /// Native events. Listen before [start]; cancelling stops the capture.
  Stream<SystemAudioEvent> get events;

  /// Whether system audio can be captured here.
  Future<bool> isSupported();

  /// Starts capture; false when it could not be started.
  Future<bool> start();

  /// Stops capture.
  Future<void> stop();
}

/// [SystemAudioPlatform] over the runner's platform channels.
class MethodChannelSystemAudioPlatform implements SystemAudioPlatform {
  /// Creates the client; channels are injectable for tests.
  MethodChannelSystemAudioPlatform({
    MethodChannel? control,
    EventChannel? events,
  }) : _control = control ?? const MethodChannel(controlChannelName),
       _events = events ?? const EventChannel(eventChannelName);

  /// Name of the MethodChannel (start / stop / isSupported).
  static const String controlChannelName = 'insato/system_audio/control';

  /// Name of the EventChannel (packets and status).
  static const String eventChannelName = 'insato/system_audio';

  final MethodChannel _control;
  final EventChannel _events;

  @override
  Stream<SystemAudioEvent> get events => _events
      .receiveBroadcastStream()
      .map(parseSystemAudioEvent)
      .where((e) => e != null)
      .cast<SystemAudioEvent>();

  @override
  Future<bool> isSupported() async {
    try {
      return await _control.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> start() async {
    try {
      return await _control.invokeMethod<bool>('start') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _control.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Nothing to stop.
    } on PlatformException {
      // The native side stops when the event stream is cancelled anyway.
    }
  }
}

// ===========================================================================
// Source
// ===========================================================================

/// System audio as 16 kHz mono samples in [buffer], plus Arabic warnings.
class SystemAudioSource {
  /// Creates the source over [platform].
  SystemAudioSource({
    required this._platform,
    SystemAudioBuffer? buffer,
    SystemAudioConverter? converter,
  }) : buffer = buffer ?? SystemAudioBuffer(),
       _converter = converter ?? SystemAudioConverter();

  final SystemAudioPlatform _platform;
  final SystemAudioConverter _converter;

  /// Converted samples waiting to be consumed.
  final SystemAudioBuffer buffer;

  final _warnings = StreamController<AudioCaptureException>.broadcast();
  StreamSubscription<SystemAudioEvent>? _sub;
  final Set<String> _reported = {};
  bool _capturing = false;
  bool _disposed = false;
  int _packets = 0;

  /// Non-fatal problems and device changes (Arabic).
  Stream<AudioCaptureException> get warnings => _warnings.stream;

  /// True between a successful [start] and [stop].
  bool get isCapturing => _capturing;

  /// Audio packets received since [start].
  int get packets => _packets;

  /// Whether system audio can be captured here.
  Future<bool> isSupported() async {
    try {
      return await _platform.isSupported();
    } catch (_) {
      return false;
    }
  }

  /// Starts capture with an empty buffer. Throws [AudioCaptureException]
  /// when the native capture cannot start.
  Future<void> start() async {
    if (_disposed) throw StateError('SystemAudioSource disposed');
    if (_capturing) return;
    buffer.clear();
    _converter.reset();
    _reported.clear();
    _packets = 0;
    await _sub?.cancel();
    _sub = _platform.events.listen(
      _onEvent,
      onError: (Object e) =>
          _warnOnce('stream', SystemAudioStrings.captureProblem, e),
    );
    bool ok;
    Object? failure;
    try {
      ok = await _platform.start();
    } catch (e) {
      ok = false;
      failure = e;
    }
    if (!ok) {
      final sub = _sub;
      _sub = null;
      await sub?.cancel();
      throw AudioCaptureException(
        SystemAudioStrings.startFailed,
        debugDetails: 'system audio start failed: ${failure ?? 'false'}',
        cause: failure,
      );
    }
    _capturing = true;
  }

  /// Stops capture; samples still held by the resampler go to [buffer].
  Future<void> stop() async {
    final sub = _sub;
    _sub = null;
    final was = _capturing;
    _capturing = false;
    if (was) {
      try {
        await _platform.stop();
      } catch (_) {
        // Cancelling the event stream below stops the native side too.
      }
    }
    await sub?.cancel();
    final tail = _converter.flush();
    if (tail.isNotEmpty) buffer.add(tail);
  }

  /// Stops capture and closes [warnings].
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _warnings.close();
  }

  void _onEvent(SystemAudioEvent event) {
    switch (event) {
      case SystemAudioPacket():
        _packets++;
        final mono = _converter.convert(
          event.samples,
          sampleRate: event.sampleRate,
          channels: event.channels,
        );
        if (mono.isNotEmpty) buffer.add(mono);
      case SystemAudioStatus(kind: SystemAudioStatusKind.started):
        _reported.clear();
      case SystemAudioStatus(kind: SystemAudioStatusKind.restarted):
        final tail = _converter.flush();
        if (tail.isNotEmpty) buffer.add(tail);
        _reported.clear();
        _warn(SystemAudioStrings.deviceChanged, 'restarted');
      case SystemAudioStatus(kind: SystemAudioStatusKind.error):
        final code = event.code ?? 'unknown';
        _warnOnce(code, systemAudioErrorMessage(code), code);
    }
  }

  // The native side retries failed devices every few seconds; each problem
  // is reported once until capture works again.
  void _warnOnce(String key, String message, Object details) {
    if (!_reported.add(key)) return;
    _warn(message, details);
  }

  void _warn(String message, Object details) {
    if (_warnings.isClosed) return;
    _warnings.add(
      AudioCaptureException(message, debugDetails: 'system audio: $details'),
    );
  }
}
