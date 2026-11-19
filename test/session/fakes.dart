// Test doubles for the session layer: deterministic "voices", fake engines,
// audio source, platform hooks, engines factory, minutes engine and settings.
//
// Voice encoding: a fake speech segment of speaker k is filled with the
// constant sample value `voiceLevel(k)`. [FakeEmbedder] maps that value back
// to a fixed random unit vector for speaker k plus small deterministic noise,
// so same-speaker cosine ≈ 0.98 and different speakers ≈ 0 ± 0.15.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/interfaces.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/session/meeting_session_controller.dart';

/// Embedding dimension of the fake voices.
const int kFakeDim = 64;

/// Sample value that encodes speaker [k] (k ≥ 0). Value 0 is silence.
double voiceLevel(int k) => 0.01 * (k + 1);

/// Speaker index encoded in [samples] (null for silence / unknown).
int? decodeVoice(Float32List samples) {
  if (samples.isEmpty) return null;
  final v = samples[0];
  if (v <= 0.0) return null;
  return (v / 0.01).round() - 1;
}

Float32List _unit(Float32List v) {
  var s = 0.0;
  for (final x in v) {
    s += x * x;
  }
  final n = math.sqrt(s);
  return Float32List.fromList([for (final x in v) x / n]);
}

/// The base voiceprint of speaker [k].
Float32List voiceOf(int k) {
  final r = math.Random(1000 + k);
  return _unit(
    Float32List.fromList(
      List.generate(kFakeDim, (_) => r.nextDouble() * 2 - 1),
    ),
  );
}

/// A noisy embedding of speaker [k] (deterministic in [seed]).
Float32List embeddingOf(int k, int seed, {double noise = 0.15}) {
  final base = voiceOf(k);
  final r = math.Random(seed * 7919 + k);
  return _unit(
    Float32List.fromList([
      for (var i = 0; i < kFakeDim; i++)
        base[i] + noise * (r.nextDouble() * 2 - 1),
    ]),
  );
}

/// Samples of [durMs] of speaker [k] (or silence when [k] is null).
Float32List voiceSamples(int? k, int durMs) {
  final n = durMs * kSampleRate ~/ 1000;
  return Float32List(n)..fillRange(0, n, k == null ? 0.0 : voiceLevel(k));
}

/// A speech segment of speaker [k].
SpeechSegment speech(int index, int startMs, int durMs, int? k) =>
    SpeechSegment(
      index: index,
      startMs: startMs,
      samples: voiceSamples(k, durMs),
    );

/// ASR fake: `كلام <index>` for speech, empty for silence; throws
/// [AsrException] for indices in [failIndices].
class FakeAsr implements AsrEngine {
  FakeAsr({this.failIndices = const {}});
  final Set<int> failIndices;
  int calls = 0;
  bool disposed = false;

  /// When set, every transcription waits for it (a slow engine).
  Completer<void>? gate;

  @override
  String get name => 'fake-asr';
  @override
  Future<void> initialize() async {}
  @override
  Future<AsrResult> transcribe(
    SpeechSegment segment, {
    String? languageHint,
  }) async {
    calls++;
    final g = gate;
    if (g != null) await g.future;
    if (failIndices.contains(segment.index)) {
      throw const AsrException('فشل التفريغ', debugDetails: 'fake failure');
    }
    final k = decodeVoice(segment.samples);
    if (k == null) return const AsrResult(text: '  ');
    return AsrResult(text: 'كلام ${segment.index}', language: 'ar');
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// Embedder fake: voice of the encoded speaker, null under 0.8 s.
class FakeEmbedder implements SpeakerEmbedder {
  int calls = 0;
  bool disposed = false;

  @override
  int get dimension => kFakeDim;
  @override
  Future<void> initialize() async {}
  @override
  Future<Float32List?> embed(Float32List samples) async {
    calls++;
    if (samples.length < 12800) return null;
    final k = decodeVoice(samples);
    if (k == null) return null;
    return embeddingOf(k, samples.length);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// Processor whose results complete in an arbitrary (reverse-ish) order, to
/// prove the pipeline applies them in submission order.
class ShuffledProcessor implements SegmentProcessor {
  ShuffledProcessor(this.inner);
  final SegmentProcessor inner;
  final List<(SpeechSegment, Completer<ProcessedSegment>)> _held = [];
  int _pending = 0;

  @override
  int get pendingCount => _pending;

  @override
  Future<ProcessedSegment> process(SpeechSegment segment) {
    _pending++;
    final c = Completer<ProcessedSegment>();
    _held.add((segment, c));
    return c.future.whenComplete(() => _pending--);
  }

  /// Completes all held segments, last submitted first.
  Future<void> releaseReversed() async {
    final held = List.of(_held);
    _held.clear();
    final results = <ProcessedSegment>[];
    for (final (seg, _) in held) {
      results.add(await inner.process(seg));
    }
    for (var i = held.length - 1; i >= 0; i--) {
      held[i].$2.complete(results[i]);
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> dispose({bool waitForPending = false}) =>
      inner.dispose(waitForPending: waitForPending);
}

/// Segmenter fake: every accepted chunk is one speech segment.
class FakeSegmenter implements SpeechSegmenter {
  final StreamController<SpeechSegment> _out = StreamController();
  int _index = 0;
  int _samples = 0;
  bool flushed = false;
  bool disposed = false;

  @override
  Future<void> initialize() async {}
  @override
  void accept(Float32List samples) {
    if (disposed) return;
    final start = _samples * 1000 ~/ kSampleRate;
    _samples += samples.length;
    _out.add(SpeechSegment(index: _index++, startMs: start, samples: samples));
  }

  @override
  void flush() => flushed = true;
  @override
  Stream<SpeechSegment> get segments => _out.stream;
  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await _out.close();
  }
}

/// Audio source fake: tests push frames with [emit].
class FakeAudioSource implements SessionAudioSource {
  final _frames = StreamController<Float32List>.broadcast();
  final _level = StreamController<double>.broadcast();
  final _states = StreamController<AudioCaptureState>.broadcast();
  final _errors = StreamController<AudioCaptureException>.broadcast();
  bool permission = true;
  bool started = false;
  bool paused = false;
  String? archivePath;
  int _samples = 0;
  Object? startError;

  /// When true, [stop] writes every emitted frame to the archive as a WAV
  /// file (like the real capture service), so it can be re-processed.
  bool writeWavOnStop = false;
  final List<Float32List> _emitted = [];

  void emit(Float32List samples) {
    _samples += samples.length;
    if (writeWavOnStop) _emitted.add(samples);
    _frames.add(samples);
    _level.add(0.5);
  }

  /// Simulates the platform ending the take.
  void endBySystem() {
    started = false;
    _states.add(AudioCaptureState.idle);
  }

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
  Future<bool> hasPermission({bool request = true}) async => permission;
  @override
  Future<void> start({String? archivePath}) async {
    final e = startError;
    if (e != null) throw e;
    this.archivePath = archivePath;
    if (archivePath != null) File(archivePath).writeAsBytesSync(const []);
    started = true;
    _states.add(AudioCaptureState.recording);
  }

  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async => paused = false;
  @override
  Future<Duration> stop() async {
    final path = archivePath;
    if (writeWavOnStop && path != null) {
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
}

/// Platform hooks fake.
class FakeHooks implements SessionPlatformHooks {
  bool deny = false;
  int started = 0;
  int stopped = 0;

  @override
  Future<void> ensureMicrophonePermission(SessionAudioSource audio) async {
    if (deny) {
      throw const AudioCaptureException('يحتاج إنصاتو إلى إذن الميكروفون.');
    }
  }

  @override
  Future<String?> onRecordingStarted({required String meetingTitle}) async {
    started++;
    return null;
  }

  @override
  Future<void> onRecordingStopped() async => stopped++;

  /// Titles passed to [onTitleChanged], in order.
  final List<String> titles = [];

  @override
  Future<void> onTitleChanged(String title) async => titles.add(title);
}

/// Engines factory fake building [FakeSegmenter] + [InlineSegmentProcessor].
class FakeEnginesFactory implements SessionEnginesFactory {
  InsatoException? notReady;
  FakeSegmenter? lastSegmenter;
  FakeAsr asr = FakeAsr();
  int created = 0;

  /// Optional custom segmenter builder (e.g. a re-blocking segmenter).
  SpeechSegmenter Function()? segmenterBuilder;

  @override
  Future<void> ensureReady(SessionEngineRequest request) async {
    final e = notReady;
    if (e != null) throw e;
  }

  @override
  Future<SessionEngines> create(SessionEngineRequest request) async {
    await ensureReady(request);
    created++;
    final SpeechSegmenter seg;
    final b = segmenterBuilder;
    if (b != null) {
      seg = b();
    } else {
      seg = lastSegmenter = FakeSegmenter();
    }
    return SessionEngines(
      segmenter: seg,
      processor: InlineSegmentProcessor(asr: asr, embedder: FakeEmbedder()),
      description: 'fake',
    );
  }
}

/// Segmenter fake for file re-processing: splits the incoming audio into
/// segments at value changes (each run of the same value = one segment).
class RunSegmenter implements SpeechSegmenter {
  /// Creates the segmenter; with [errorAfterSegments] the stream reports a
  /// VAD error after that many segments (and keeps going).
  RunSegmenter({this.errorAfterSegments});

  /// See the constructor.
  final int? errorAfterSegments;

  final StreamController<SpeechSegment> _out = StreamController();
  final List<double> _run = [];
  int _runStart = 0;
  int _pos = 0;
  int _index = 0;

  @override
  Future<void> initialize() async {}

  @override
  void accept(Float32List samples) {
    for (final v in samples) {
      if (_run.isNotEmpty && (v - _run.first).abs() > 1e-4) _emit();
      if (_run.isEmpty) _runStart = _pos;
      _run.add(v);
      _pos++;
    }
  }

  void _emit() {
    if (_run.isEmpty) return;
    final first = _run.first;
    if (first.abs() > 1e-4) {
      _out.add(
        SpeechSegment(
          index: _index++,
          startMs: _runStart * 1000 ~/ kSampleRate,
          samples: Float32List.fromList(_run),
        ),
      );
      if (_index == errorAfterSegments) {
        _out.addError(const ModelException('خطأ في اكتشاف الكلام'));
      }
    }
    _run.clear();
  }

  @override
  void flush() => _emit();
  @override
  Stream<SpeechSegment> get segments => _out.stream;
  @override
  Future<void> dispose() => _out.close();
}

/// Minutes engine fake.
class FakeMinutesEngine implements MinutesEngine {
  FakeMinutesEngine({this.fail});
  final InsatoException? fail;
  int calls = 0;
  List<String> lastSpeakerNames = const [];

  @override
  Future<Minutes> generate({
    required Meeting meeting,
    required List<TranscriptSegment> segments,
    required Map<String, Speaker> speakersById,
    void Function(double progress, String status)? onProgress,
  }) async {
    calls++;
    onProgress?.call(0.5, 'جارٍ الكتابة…');
    final f = fail;
    if (f != null) throw f;
    lastSpeakerNames = [
      for (final s in segments)
        if (s.speakerId != null) speakersById[s.speakerId]!.name,
    ];
    return Minutes(
      title: meeting.title,
      summary: 'ملخص ${segments.length} مقاطع',
      attendees: lastSpeakerNames.toSet().toList(),
      topics: const [],
      decisions: const [],
      actionItems: const [],
      openQuestions: const [],
      languagesDetected: const ['العربية'],
      generatedAt: DateTime.utc(2026, 11, 19),
      model: 'fake-model',
    );
  }
}

/// Secure settings fake (in memory).
class FakeSecureSettings extends SecureSettings {
  String? anthropic;
  String? deepgram;

  @override
  Future<String?> getAnthropicApiKey() async => anthropic;
  @override
  Future<void> setAnthropicApiKey(String key) async =>
      anthropic = key.trim().isEmpty ? null : key.trim();
  @override
  Future<void> clearAnthropicApiKey() async => anthropic = null;
  @override
  Future<String?> getDeepgramApiKey() async => deepgram;
  @override
  Future<void> setDeepgramApiKey(String key) async =>
      deepgram = key.trim().isEmpty ? null : key.trim();
  @override
  Future<void> clearDeepgramApiKey() async => deepgram = null;
}

/// A fresh in-memory database.
AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase.forExecutor(NativeDatabase.memory());
}

/// Waits until [condition] holds (or fails after [timeout]).
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final sw = Stopwatch()..start();
  while (!condition()) {
    if (sw.elapsed > timeout) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}
