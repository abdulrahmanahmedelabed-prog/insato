import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/interfaces.dart';
import 'package:insato/core/models.dart';
import 'package:insato/speech/processing_isolate.dart';

class _FakeAsr implements AsrEngine {
  @override
  String get name => 'fake';
  @override
  Future<void> initialize() async {}
  @override
  Future<AsrResult> transcribe(SpeechSegment segment,
      {String? languageHint}) async {
    if (segment.samples.isNotEmpty && segment.samples[0] < 0) {
      throw const AsrException('فشل', debugDetails: 'negative');
    }
    // Simulate work so ordering bugs would show.
    final sw = Stopwatch()..start();
    while (sw.elapsedMicroseconds < 2000) {}
    return AsrResult(
        text: 'seg ${segment.index} n=${segment.samples.length}',
        language: languageHint ?? 'xx',
        confidence: 0.5);
  }

  @override
  Future<void> dispose() async {}
}

class _FakeEmbedder implements SpeakerEmbedder {
  @override
  int get dimension => 3;
  @override
  Future<void> initialize() async {}
  @override
  Future<Float32List?> embed(Float32List samples) async {
    if (samples.length < 10) return null;
    if (samples.length == 11) throw const ModelException('embed failed');
    return Float32List.fromList([samples.length.toDouble(), 0, 1]);
  }

  @override
  Future<void> dispose() async {}
}

Future<WorkerEngines> fakeFactory(ProcessingIsolateConfig c) async =>
    WorkerEngines(asr: c.runAsr ? _FakeAsr() : null, embedder: _FakeEmbedder());

Future<WorkerEngines> failingFactory(ProcessingIsolateConfig c) async =>
    throw const ModelException('النموذج تالف', debugDetails: 'boom');

/// ASR whose decode blocks synchronously (like a sherpa FFI call) and
/// whose engines record, in the directory passed as `speakerModel`, that
/// their native resources were released.
class _SlowAsr implements AsrEngine {
  _SlowAsr(this.dir);
  final String dir;
  @override
  String get name => 'slow';
  @override
  Future<void> initialize() async {}
  @override
  Future<AsrResult> transcribe(
    SpeechSegment segment, {
    String? languageHint,
  }) async {
    final sw = Stopwatch()..start();
    while (sw.elapsedMilliseconds < 1500) {}
    return const AsrResult(text: 'slow');
  }

  @override
  Future<void> dispose() async => File('$dir/asr_freed').writeAsStringSync('1');
}

class _RecordingEmbedder extends _FakeEmbedder {
  _RecordingEmbedder(this.dir);
  final String dir;
  @override
  Future<void> dispose() async =>
      File('$dir/embedder_freed').writeAsStringSync('1');
}

Future<WorkerEngines> slowFactory(ProcessingIsolateConfig c) async =>
    WorkerEngines(
      asr: _SlowAsr(c.speakerModel),
      embedder: _RecordingEmbedder(c.speakerModel),
    );

/// ASR that crashes the worker with an uncaught async error.
class _CrashingAsr extends _FakeAsr {
  @override
  Future<AsrResult> transcribe(SpeechSegment segment, {String? languageHint}) {
    Timer.run(() => throw StateError('uncaught in worker'));
    return Completer<AsrResult>().future; // never completes
  }
}

Future<WorkerEngines> crashingFactory(ProcessingIsolateConfig c) async =>
    WorkerEngines(asr: _CrashingAsr(), embedder: _FakeEmbedder());

const _config = ProcessingIsolateConfig(
  whisperEncoder: 'e',
  whisperDecoder: 'd',
  whisperTokens: 't',
  speakerModel: 's',
  languageHint: 'ar',
);

SpeechSegment _seg(int index, int n, {double v = 0.1}) => SpeechSegment(
    index: index,
    startMs: index * 1000,
    samples: Float32List.fromList(List.filled(n, v)));

void main() {
  test('processes segments in order and returns ASR + embeddings', () async {
    final pi = await ProcessingIsolate.spawnWithFactory(_config, fakeFactory);
    expect(pi.embeddingDimension, 3);
    final futures = [
      for (var i = 0; i < 20; i++) pi.process(_seg(i, 16000 + i)),
    ];
    expect(pi.pendingCount, 20);
    final order = <int>[];
    for (final f in futures) {
      unawaited(f.then((r) => order.add(r.index)));
    }
    final results = await Future.wait(futures);
    expect(order, List.generate(20, (i) => i));
    for (var i = 0; i < 20; i++) {
      final r = results[i];
      expect(r.index, i);
      expect(r.startMs, i * 1000);
      expect(r.endMs, i * 1000 + ((16000 + i) * 1000) ~/ kSampleRate);
      expect(r.asr.text, 'seg $i n=${16000 + i}');
      expect(r.asr.language, 'ar');
      expect(r.asr.confidence, 0.5);
      expect(r.embedding, [16000.0 + i, 0, 1]);
    }
    expect(pi.pendingCount, 0);
    await pi.dispose();
    expect(pi.isClosed, isTrue);
    await expectLater(pi.process(_seg(0, 100)), throwsA(isA<AsrException>()));
  });

  test('per-segment language hint overrides the default', () async {
    final pi = await ProcessingIsolate.spawnWithFactory(_config, fakeFactory);
    final r = await pi.process(_seg(0, 100), languageHint: 'en');
    expect(r.asr.language, 'en');
    await pi.dispose();
  });

  test('ASR errors propagate as typed exceptions; later segments continue',
      () async {
    final pi = await ProcessingIsolate.spawnWithFactory(_config, fakeFactory);
    final bad = pi.process(_seg(0, 100, v: -1));
    final good = pi.process(_seg(1, 100));
    await expectLater(
        bad,
        throwsA(isA<AsrException>()
            .having((e) => e.messageAr, 'messageAr', 'فشل')
            .having((e) => e.debugDetails, 'debug', 'negative')));
    expect((await good).asr.text, startsWith('seg 1'));
    await pi.dispose();
  });

  test('embedding failure is non-fatal; short segments have no embedding',
      () async {
    final pi = await ProcessingIsolate.spawnWithFactory(_config, fakeFactory);
    final r1 = await pi.process(_seg(0, 11));
    expect(r1.embedding, isNull);
    expect(r1.embeddingErrorAr, 'embed failed');
    expect(r1.asr.text, isNotEmpty);
    final r2 = await pi.process(_seg(1, 5));
    expect(r2.embedding, isNull);
    expect(r2.embeddingErrorAr, isNull);
    await pi.dispose();
  });

  test('embedding-only mode (cloud ASR) returns empty text', () async {
    const cfg = ProcessingIsolateConfig(
      whisperEncoder: null,
      whisperDecoder: null,
      whisperTokens: null,
      speakerModel: 's',
      runAsr: false,
    );
    final pi = await ProcessingIsolate.spawnWithFactory(cfg, fakeFactory);
    final r = await pi.process(_seg(0, 50));
    expect(r.asr.isEmpty, isTrue);
    expect(r.embedding, [50.0, 0, 1]);
    await pi.dispose();
  });

  test('initialisation failure surfaces as ModelException', () async {
    await expectLater(
        ProcessingIsolate.spawnWithFactory(_config, failingFactory),
        throwsA(isA<ModelException>()
            .having((e) => e.messageAr, 'messageAr', 'النموذج تالف')));
  });

  test('spawn without Whisper paths in ASR mode fails fast', () async {
    await expectLater(
        ProcessingIsolate.spawn(
            whisperEncoder: null,
            whisperDecoder: null,
            whisperTokens: null,
            speakerModel: 's'),
        throwsA(isA<ModelException>()));
  });

  test('dispose without waiting cancels queued segments', () async {
    final pi = await ProcessingIsolate.spawnWithFactory(_config, fakeFactory);
    final futures = [
      for (var i = 0; i < 50; i++) pi.process(_seg(i, 16000)),
    ];
    final outcomes = Future.wait(futures.map((f) =>
        f.then<Object>((r) => r, onError: (Object e) => e)));
    await pi.dispose();
    final all = await outcomes;
    expect(all.whereType<ProcessedSegment>().length +
        all.whereType<AsrException>().length, 50);
    expect(pi.pendingCount, 0);
  });

  test('dispose(waitForPending) finishes every queued segment', () async {
    final pi = await ProcessingIsolate.spawnWithFactory(_config, fakeFactory);
    final futures = [
      for (var i = 0; i < 10; i++) pi.process(_seg(i, 1000)),
    ];
    await pi.dispose(waitForPending: true);
    final results = await Future.wait(futures);
    expect(results.map((r) => r.index), List.generate(10, (i) => i));
  });

  test('error encoding round-trips the exception type', () {
    for (final e in <InsatoException>[
      const ModelException('m', debugDetails: 'd'),
      const AsrException('a'),
      const MissingApiKeyException('k'),
      const InsatoException('x'),
    ]) {
      final back = decodeWorkerError(encodeWorkerError(e));
      expect(back.runtimeType, e.runtimeType);
      expect(back.messageAr, e.messageAr);
      expect(back.debugDetails, e.debugDetails);
    }
    final other = decodeWorkerError(encodeWorkerError(StateError('x')));
    expect(other, isA<AsrException>());
    expect(other.messageAr, isNotEmpty);
  });

  group('shutdown', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('insato_pi_'));
    tearDown(() => dir.deleteSync(recursive: true));

    ProcessingIsolateConfig cfg() => ProcessingIsolateConfig(
      whisperEncoder: 'e',
      whisperDecoder: 'd',
      whisperTokens: 't',
      speakerModel: dir.path,
    );

    bool freed() =>
        File('${dir.path}/asr_freed').existsSync() &&
        File('${dir.path}/embedder_freed').existsSync();

    test(
      'dispose waits for an in-flight decode and frees the engines',
      () async {
        final pi = await ProcessingIsolate.spawnWithFactory(cfg(), slowFactory);
        final inFlight = pi.process(_seg(0, 16000));
        final queued = pi
            .process(_seg(1, 16000))
            .then<Object>((r) => r, onError: (Object e) => e);
        // Let the worker pick up the first segment.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await pi.dispose();
        // Native free() ran: the worker was shut down, not killed.
        expect(freed(), isTrue);
        expect((await inFlight).asr.text, 'slow');
        expect(await queued, isA<AsrException>());
        expect(pi.isClosed, isTrue);
      },
    );

    test('spawn waits for a previous worker to free its models', () async {
      final first = await ProcessingIsolate.spawnWithFactory(
        cfg(),
        slowFactory,
      );
      unawaited(first.process(_seg(0, 16000)).then((_) {}, onError: (_) {}));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // Caller does not await dispose before spawning the next worker.
      unawaited(first.dispose());
      final second = await ProcessingIsolate.spawnWithFactory(
        _config,
        fakeFactory,
      );
      expect(
        freed(),
        isTrue,
        reason: 'old models must be freed before new ones load',
      );
      await second.dispose();
    });

    test('an uncaught worker error marks the isolate closed before failing '
        'pending segments', () async {
      final pi = await ProcessingIsolate.spawnWithFactory(
        _config,
        crashingFactory,
      );
      bool? closedWhenFailed;
      Object? error;
      try {
        await pi.process(_seg(0, 16000));
      } catch (e) {
        // Same check IsolateSegmentProcessor uses to decide on a respawn.
        closedWhenFailed = pi.isClosed;
        error = e;
      }
      expect(error, isA<AsrException>());
      expect(closedWhenFailed, isTrue);
      await expectLater(
        pi.process(_seg(1, 16000)),
        throwsA(isA<AsrException>()),
      );
      await pi.dispose().timeout(const Duration(seconds: 10));
    });
  });
}
