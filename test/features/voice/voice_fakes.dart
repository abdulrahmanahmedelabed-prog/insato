// Test doubles and synthetic audio for the voice-feature tests.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/voice/audio_quality.dart';
import 'package:insato/features/voice/enrollment_engine.dart';
import 'package:insato/features/voice/mic_capture.dart';
import 'package:insato/features/voice/mic_test_controller.dart';

import '../../session/fakes.dart' show embeddingOf;

/// [n] ms of a 220 Hz tone at [amplitude] (speech stand-in).
Float32List tone(int ms, {double amplitude = 0.2, double hz = 220}) {
  final n = ms * kSampleRate ~/ 1000;
  return Float32List.fromList([
    for (var i = 0; i < n; i++)
      amplitude * math.sin(2 * math.pi * hz * i / kSampleRate),
  ]);
}

/// [n] ms of low noise at [amplitude] (deterministic).
Float32List noise(int ms, {double amplitude = 0.001, int seed = 1}) {
  final r = math.Random(seed);
  final n = ms * kSampleRate ~/ 1000;
  return Float32List.fromList([
    for (var i = 0; i < n; i++) amplitude * (r.nextDouble() * 2 - 1),
  ]);
}

/// Concatenates [parts].
Float32List join(List<Float32List> parts) {
  final total = parts.fold<int>(0, (a, p) => a + p.length);
  final out = Float32List(total);
  var at = 0;
  for (final p in parts) {
    out.setAll(at, p);
    at += p.length;
  }
  return out;
}

/// A reading take: [segments] × (speech [speechMs] + pause [pauseMs]),
/// starting with a pause.
Float32List readingTake({
  int segments = 5,
  int speechMs = 2200,
  int pauseMs = 400,
  double amplitude = 0.2,
}) => join([
  noise(pauseMs),
  for (var i = 0; i < segments; i++) ...[
    tone(speechMs, amplitude: amplitude),
    noise(pauseMs, seed: i + 2),
  ],
]);

/// Microphone fake: tests push frames with [emit].
class FakeMic implements MicCapture {
  FakeMic({this.devices = const [], this.permission = true});

  List<InputDevice> devices;
  bool permission;
  Object? listError;
  Object? startError;
  InputDevice? _selected;
  InputDevice? startedWith;
  String? archivePath;
  bool started = false;
  bool disposed = false;
  int listCalls = 0;
  int _samples = 0;
  final List<Float32List> _emitted = [];

  final _frames = StreamController<Float32List>.broadcast();
  final _level = StreamController<double>.broadcast();
  final _states = StreamController<AudioCaptureState>.broadcast();
  final _errors = StreamController<AudioCaptureException>.broadcast();

  /// Delivers [samples] as captured audio.
  void emit(Float32List samples) {
    _samples += samples.length;
    _emitted.add(samples);
    _frames.add(samples);
    _level.add(0.5);
  }

  /// Sends a capture warning.
  void warn(String message) => _errors.add(AudioCaptureException(message));

  /// Reports a capture state change made by the platform.
  void pushState(AudioCaptureState s) => _states.add(s);

  /// Holds [hasPermission] until completed (null = answer at once).
  Future<void>? permissionGate;

  @override
  Stream<Float32List> get frames => _frames.stream;
  @override
  Stream<double> get level => _level.stream;
  @override
  Stream<AudioCaptureState> get states => _states.stream;
  @override
  Stream<AudioCaptureException> get errors => _errors.stream;
  @override
  Duration get elapsed =>
      Duration(milliseconds: _samples * 1000 ~/ kSampleRate);
  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (permissionGate != null) await permissionGate;
    return permission;
  }
  @override
  Future<List<InputDevice>> listInputDevices() async {
    listCalls++;
    final e = listError;
    if (e != null) throw e;
    return devices;
  }

  @override
  void selectDevice(InputDevice? device) => _selected = device;
  @override
  InputDevice? get selectedDevice => _selected;
  @override
  Future<void> start({String? archivePath}) async {
    final e = startError;
    if (e != null) throw e;
    this.archivePath = archivePath;
    startedWith = _selected;
    started = true;
    _states.add(AudioCaptureState.recording);
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<Duration> stop() async {
    final path = archivePath;
    if (started && path != null) {
      final w = await WavWriter.open(path);
      for (final f in _emitted) {
        await w.appendFloat32(f);
      }
      await w.close();
    }
    started = false;
    _states.add(AudioCaptureState.idle);
    return elapsed;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _frames.close();
    await _level.close();
    await _states.close();
    await _errors.close();
  }
}

/// Records every [FakeMic] made and the options it was made with.
class FakeMicFactory {
  FakeMicFactory({this.devices = const []});

  List<InputDevice> devices;
  bool permission = true;

  /// Gate given to every new mic's [FakeMic.permissionGate].
  Future<void>? permissionGate;
  final List<FakeMic> made = [];
  final List<AudioCaptureOptions> options = [];

  /// The most recent microphone that was started.
  FakeMic? get recording {
    for (final m in made.reversed) {
      if (m.started) return m;
    }
    return null;
  }

  MicCapture call(AudioCaptureOptions o) {
    options.add(o);
    final m = FakeMic(devices: devices, permission: permission)
      ..permissionGate = permissionGate;
    made.add(m);
    return m;
  }
}

/// Analyzer fake: energy-based speech spans; every chunk embeds as a noisy
/// version of speaker [speaker] (or, with [mixed], alternately two voices).
class FakeEnrollmentAnalyzer implements EnrollmentAnalyzer {
  FakeEnrollmentAnalyzer({this.speaker = 3, this.mixed = false});

  final int speaker;
  final bool mixed;
  int embedCalls = 0;
  bool disposed = false;

  @override
  int get paddingMsPerSpan => 0;

  @override
  Future<List<SpeechSpan>> detectSpeech(Float32List audio) async =>
      energySpeechSpans(audio);

  @override
  Future<List<Float32List?>> embed(List<Float32List> chunks) async => [
    for (var i = 0; i < chunks.length; i++)
      chunks[i].length < kSampleRate * 8 ~/ 10
          ? null
          : embeddingOf(
              mixed && i.isOdd ? speaker + 1 : speaker,
              ++embedCalls,
              noise: 0.1,
            ),
  ];

  @override
  Future<void> dispose() async => disposed = true;
}

/// Playback fake.
class FakePlayback implements TestPlayback {
  final List<String> played = [];
  int stops = 0;
  bool disposed = false;
  Object? playError;
  final _done = StreamController<void>.broadcast();

  void complete() => _done.add(null);

  @override
  Future<void> play(String path) async {
    final e = playError;
    if (e != null) throw e;
    if (!File(path).existsSync()) throw StateError('missing $path');
    played.add(path);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Stream<void> get onComplete => _done.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _done.close();
  }
}

/// A generic Insato error for fakes.
const InsatoException fakeFailure = InsatoException('خطأ تجريبي');
