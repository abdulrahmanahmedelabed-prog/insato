// Test doubles for the F13 tests.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/system_audio/system_audio.dart';
import 'package:insato/session/meeting_session_controller.dart';

/// [ms] of a sine at [hz] / [rate] with [amplitude], mono.
Float32List sine(
  int ms, {
  int rate = kSampleRate,
  double hz = 440,
  double amplitude = 0.5,
}) {
  final n = ms * rate ~/ 1000;
  return Float32List.fromList([
    for (var i = 0; i < n; i++) amplitude * math.sin(2 * math.pi * hz * i / rate),
  ]);
}

/// Interleaves [mono] into [channels] identical channels.
Float32List interleave(Float32List mono, int channels) {
  final out = Float32List(mono.length * channels);
  for (var i = 0; i < mono.length; i++) {
    for (var c = 0; c < channels; c++) {
      out[i * channels + c] = mono[i];
    }
  }
  return out;
}

/// Native capture fake: tests push events with [emit].
class FakeSystemAudioPlatform implements SystemAudioPlatform {
  FakeSystemAudioPlatform({this.supported = true, this.startResult = true});

  bool supported;
  bool startResult;
  Object? startError;
  int starts = 0;
  int stops = 0;
  bool running = false;
  final _events = StreamController<SystemAudioEvent>.broadcast();

  /// True while somebody listens to [events].
  bool get hasListener => _events.hasListener;

  void emit(SystemAudioEvent e) => _events.add(e);

  /// Sends [mono] at [rate] as stereo packets.
  void emitAudio(Float32List mono, {int rate = 48000, int channels = 2}) =>
      emit(
        SystemAudioPacket(
          sampleRate: rate,
          channels: channels,
          samples: interleave(mono, channels),
        ),
      );

  @override
  Stream<SystemAudioEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> start() async {
    starts++;
    final e = startError;
    if (e != null) throw e;
    running = startResult;
    return startResult;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }
}

/// Microphone fake implementing the session seam.
class FakeSessionMic implements SessionAudioSource {
  bool permission = true;
  String? archivePath;
  bool started = false;
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  int _samples = 0;
  Object? startError;

  final _frames = StreamController<Float32List>.broadcast();
  final _level = StreamController<double>.broadcast();
  final _states = StreamController<AudioCaptureState>.broadcast();
  final _errors = StreamController<AudioCaptureException>.broadcast();

  void emit(Float32List samples) {
    _samples += samples.length;
    _frames.add(samples);
    _level.add(0.25);
  }

  void warn(String m) => _errors.add(AudioCaptureException(m));

  @override
  Stream<Float32List> get frames => _frames.stream;
  @override
  Stream<double> get level => _level.stream;
  @override
  Stream<AudioCaptureState> get states => _states.stream;
  @override
  Stream<AudioCaptureException> get errors => _errors.stream;
  @override
  Duration get elapsed => Duration(milliseconds: _samples * 1000 ~/ kSampleRate);
  @override
  Future<bool> hasPermission({bool request = true}) async => permission;

  @override
  Future<void> start({String? archivePath}) async {
    final e = startError;
    if (e != null) throw e;
    starts++;
    started = true;
    this.archivePath = archivePath;
    _states.add(AudioCaptureState.recording);
  }

  @override
  Future<void> pause() async {
    pauses++;
    _states.add(AudioCaptureState.paused);
  }

  @override
  Future<void> resume() async {
    resumes++;
    _states.add(AudioCaptureState.recording);
  }

  @override
  Future<Duration> stop() async {
    stops++;
    started = false;
    _states.add(AudioCaptureState.idle);
    return elapsed;
  }
}

/// Manually advanced monotonic clock.
class FakeClock {
  Duration now = Duration.zero;

  Duration call() => now;

  void advance(Duration d) => now += d;
}

/// Lets broadcast-stream deliveries run.
Future<void> flushEvents() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
