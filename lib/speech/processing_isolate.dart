// Long-lived background isolate that runs on-device ASR and speaker
// embedding for speech segments, strictly in submission order.
//
// Protocol (all messages are plain maps / sendable objects):
//
//   main → worker   {'type': 'process', 'id', 'index', 'startMs',
//                    'samples': TransferableTypedData, 'lang'}
//                   {'type': 'dispose', 'drain': bool}
//   worker → main   SendPort (handshake)
//                   {'type': 'ready', 'dimension'}
//                   {'type': 'initError', ...error}
//                   {'type': 'result', 'id', 'text', 'language', 'confidence',
//                    'embedding': TransferableTypedData?, 'embeddingError'}
//                   {'type': 'error', 'id', ...error}
//                   {'type': 'disposed'}

import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import 'model_catalog.dart';
import 'sherpa_asr_engine.dart';
import 'sherpa_speaker_embedder.dart';

/// Output of the processing isolate for one [SpeechSegment].
class ProcessedSegment {
  /// Creates a processed segment.
  const ProcessedSegment({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.asr,
    this.embedding,
    this.embeddingErrorAr,
  });

  /// [SpeechSegment.index] of the source segment.
  final int index;

  /// Start offset (ms) of the source segment.
  final int startMs;

  /// End offset (ms) of the source segment.
  final int endMs;

  /// Transcription; empty text when ASR is disabled (cloud mode) or the
  /// segment contained no speech.
  final AsrResult asr;

  /// L2-normalised voice embedding; null for short segments (< 0.8 s) or
  /// when extraction failed (see [embeddingErrorAr]).
  final Float32List? embedding;

  /// Arabic description of a non-fatal embedding failure, if any.
  final String? embeddingErrorAr;
}

/// Engines owned by the worker isolate.
class WorkerEngines {
  /// Bundles initialised engines. [asr] is null in embedding-only mode.
  const WorkerEngines({required this.asr, required this.embedder});

  /// Speech recogniser (null when ASR runs elsewhere).
  final AsrEngine? asr;

  /// Voice embedder.
  final SpeakerEmbedder embedder;
}

/// Creates and initialises the engines inside the worker isolate. Must be a
/// top-level or static function (it is sent to the isolate).
typedef WorkerEngineFactory = Future<WorkerEngines> Function(
    ProcessingIsolateConfig config);

/// Configuration sent to the worker isolate.
class ProcessingIsolateConfig {
  /// Creates a configuration. When [runAsr] is true the three Whisper paths
  /// are required.
  const ProcessingIsolateConfig({
    required this.whisperEncoder,
    required this.whisperDecoder,
    required this.whisperTokens,
    required this.speakerModel,
    this.languageHint,
    this.runAsr = true,
    this.asrThreads,
    this.embedderThreads,
  });

  /// Whisper encoder ONNX path.
  final String? whisperEncoder;

  /// Whisper decoder ONNX path.
  final String? whisperDecoder;

  /// Whisper tokens path.
  final String? whisperTokens;

  /// Speaker embedding model path.
  final String speakerModel;

  /// Default ISO-639-1 language (null = auto-detect).
  final String? languageHint;

  /// False in cloud-ASR mode: only embeddings are computed.
  final bool runAsr;

  /// Threads for Whisper (default: [recommendedThreadCount]).
  final int? asrThreads;

  /// Threads for the embedder (default: up to 2).
  final int? embedderThreads;
}

/// Default engine factory: sherpa-onnx Whisper + speaker embedder.
Future<WorkerEngines> createSherpaWorkerEngines(
    ProcessingIsolateConfig config) async {
  ensureSherpaBindings();
  AsrEngine? asr;
  if (config.runAsr) {
    asr = SherpaAsrEngine(
      paths: WhisperModelPaths(
        encoder: config.whisperEncoder!,
        decoder: config.whisperDecoder!,
        tokens: config.whisperTokens!,
      ),
      defaultLanguage: config.languageHint,
      numThreads: config.asrThreads,
    );
  }
  final embedder = SherpaSpeakerEmbedder(
    modelPath: config.speakerModel,
    numThreads: config.embedderThreads,
  );
  try {
    await asr?.initialize();
    await embedder.initialize();
  } catch (_) {
    await asr?.dispose();
    await embedder.dispose();
    rethrow;
  }
  return WorkerEngines(asr: asr, embedder: embedder);
}

/// A background isolate owning the on-device [AsrEngine] and
/// [SpeakerEmbedder]. Segments are processed one at a time in the order
/// [process] was called; failures complete the returned future with a
/// [InsatoException].
class ProcessingIsolate {
  ProcessingIsolate._(
      this._port, this._errorPort, this._exitPort, this.config);

  final ReceivePort _port;
  final ReceivePort _errorPort;
  final ReceivePort _exitPort;

  /// Configuration the worker was started with.
  final ProcessingIsolateConfig config;

  late final SendPort _toWorker;
  final LinkedHashMap<int, _Pending> _pending = LinkedHashMap();
  final Completer<void> _disposedSignal = Completer<void>();
  // Completes when the worker isolate has actually terminated.
  final Completer<void> _exited = Completer<void>();
  Future<void>? _disposeFuture;
  int _nextId = 0;
  int _dimension = 0;
  bool _closing = false;
  bool _dead = false;

  /// Starts the worker and loads the models (may take several seconds for
  /// large Whisper models). Throws [ModelException] when a model cannot be
  /// loaded.
  static Future<ProcessingIsolate> spawn({
    required String? whisperEncoder,
    required String? whisperDecoder,
    required String? whisperTokens,
    required String speakerModel,
    String? languageHint,
    bool runAsr = true,
  }) {
    if (runAsr &&
        (whisperEncoder == null ||
            whisperDecoder == null ||
            whisperTokens == null)) {
      return Future.error(const ModelException(
          'نموذج التفريغ الصوتي غير مُنزَّل. يُرجى تنزيله من صفحة النماذج.'));
    }
    return spawnWithFactory(
      ProcessingIsolateConfig(
        whisperEncoder: whisperEncoder,
        whisperDecoder: whisperDecoder,
        whisperTokens: whisperTokens,
        speakerModel: speakerModel,
        languageHint: languageHint,
        runAsr: runAsr,
      ),
      createSherpaWorkerEngines,
    );
  }

  /// Shutdowns of earlier workers that have not finished yet. A new worker
  /// waits for them so two copies of the (large) native models are never
  /// resident at the same time.
  static final Set<Future<void>> _pendingShutdowns = <Future<void>>{};

  /// Like [spawn] with a custom engine [factory] (a top-level function),
  /// e.g. for tests or alternative engines.
  ///
  /// Waits for any earlier [ProcessingIsolate] whose [dispose] is still in
  /// progress, so its native models are freed before new ones are loaded.
  static Future<ProcessingIsolate> spawnWithFactory(
    ProcessingIsolateConfig config,
    WorkerEngineFactory factory,
  ) async {
    while (_pendingShutdowns.isNotEmpty) {
      await Future.wait(_pendingShutdowns.toList());
    }
    final port = ReceivePort('insato-processing');
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    try {
      await Isolate.spawn<_Bootstrap>(
        _workerMain,
        _Bootstrap(port.sendPort, config, factory),
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
        debugName: 'insato-processing',
      );
    } catch (e) {
      port.close();
      errorPort.close();
      exitPort.close();
      throw ModelException('تعذّر بدء خيط المعالجة في الخلفية.',
          debugDetails: e.toString(), cause: e);
    }
    final pi = ProcessingIsolate._(port, errorPort, exitPort, config);
    await pi._start();
    return pi;
  }

  Future<void> _start() {
    final ready = Completer<void>();
    var gotPort = false;
    _port.listen((msg) {
      if (!gotPort && msg is SendPort) {
        gotPort = true;
        _toWorker = msg;
        return;
      }
      if (msg is! Map) return;
      switch (msg['type']) {
        case 'ready':
          _dimension = (msg['dimension'] as int?) ?? 0;
          if (!ready.isCompleted) ready.complete();
        case 'initError':
          if (!ready.isCompleted) ready.completeError(_decodeError(msg));
          _shutdownPorts();
        case 'result':
          _onResult(msg);
        case 'error':
          final p = _pending.remove(msg['id']);
          p?.completer.completeError(_decodeError(msg));
        case 'disposed':
          if (!_disposedSignal.isCompleted) _disposedSignal.complete();
      }
    });
    _errorPort.listen((msg) {
      final details = msg is List ? msg.join('\n') : '$msg';
      final err = AsrException('حدث خطأ غير متوقع في خيط المعالجة.',
          debugDetails: details);
      // errorsAreFatal (the default): the worker is about to exit. Mark it
      // dead *before* failing pending work, so callers reacting to these
      // failures already see [isClosed] and respawn/retry instead of
      // treating the worker as alive (the exit event arrives later).
      _dead = true;
      if (!ready.isCompleted) ready.completeError(err);
      _failAll(err);
    });
    _exitPort.listen((_) {
      _dead = true;
      if (!_exited.isCompleted) _exited.complete();
      const err = AsrException('توقفت عملية المعالجة في الخلفية.');
      if (!ready.isCompleted) ready.completeError(err);
      _failAll(err);
      if (!_disposedSignal.isCompleted) _disposedSignal.complete();
      _shutdownPorts();
    });
    return ready.future;
  }

  void _onResult(Map msg) {
    final p = _pending.remove(msg['id']);
    if (p == null) return;
    final emb = msg['embedding'];
    p.completer.complete(ProcessedSegment(
      index: p.index,
      startMs: p.startMs,
      endMs: p.endMs,
      asr: AsrResult(
        text: (msg['text'] as String?) ?? '',
        language: msg['language'] as String?,
        confidence: (msg['confidence'] as num?)?.toDouble(),
      ),
      embedding: emb is TransferableTypedData
          ? emb.materialize().asFloat32List()
          : null,
      embeddingErrorAr: msg['embeddingError'] as String?,
    ));
  }

  /// Embedding dimension reported by the worker's speaker model.
  int get embeddingDimension => _dimension;

  /// Segments submitted but not yet completed.
  int get pendingCount => _pending.length;

  /// True after [dispose] or when the worker died.
  bool get isClosed => _closing || _dead;

  /// Queues [segment]; completes with its [ProcessedSegment] once all
  /// earlier segments are done. [languageHint] overrides the configured hint
  /// for this segment. Throws [AsrException] / [ModelException] on failure.
  Future<ProcessedSegment> process(SpeechSegment segment,
      {String? languageHint}) {
    if (isClosed) {
      return Future.error(
          const AsrException('تم إيقاف المعالجة؛ لا يمكن إضافة مقاطع جديدة.'));
    }
    final id = _nextId++;
    final pending = _Pending(segment.index, segment.startMs, segment.endMs);
    _pending[id] = pending;
    final s = segment.samples;
    _toWorker.send({
      'type': 'process',
      'id': id,
      'index': segment.index,
      'startMs': segment.startMs,
      'samples': TransferableTypedData.fromList(
          [s.buffer.asUint8List(s.offsetInBytes, s.lengthInBytes)]),
      'lang': languageHint,
    });
    return pending.completer.future;
  }

  /// Stops the worker and frees the native models.
  ///
  /// With [waitForPending] every queued segment is processed first;
  /// otherwise queued segments fail with [AsrException] and only the
  /// segment currently being decoded is finished.
  ///
  /// The worker is never killed: a decode in progress is a single blocking
  /// FFI call that `Isolate.kill` cannot interrupt anyway, and killing would
  /// skip freeing the native models (sherpa-onnx has no finalizers), leaking
  /// them until the app restarts. The returned future completes only after
  /// the worker has released its models and exited, so a caller can safely
  /// spawn a new worker afterwards ([spawnWithFactory] also waits for it).
  Future<void> dispose({bool waitForPending = false}) {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    _closing = true;
    final f = _shutdown(waitForPending);
    _disposeFuture = f;
    _pendingShutdowns.add(f);
    f.whenComplete(() => _pendingShutdowns.remove(f)).ignore();
    return f;
  }

  Future<void> _shutdown(bool drain) async {
    if (!_dead) {
      _toWorker.send({'type': 'dispose', 'drain': drain});
      // No timeout: the worker reaches shutdown() as soon as the segment it
      // is decoding returns. 'disposed' arrives after the native free()s.
      await Future.any([_disposedSignal.future, _exited.future]);
    }
    // After 'disposed' the worker closes its last port and terminates
    // promptly; wait for that so the isolate is really gone. The cap only
    // guards against a lost exit notification (models are already freed).
    await _exited.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    _failAll(const AsrException('تم إيقاف المعالجة.'));
    _shutdownPorts();
    if (!_disposedSignal.isCompleted) _disposedSignal.complete();
  }

  void _failAll(InsatoException e) {
    final all = _pending.values.toList();
    _pending.clear();
    for (final p in all) {
      if (!p.completer.isCompleted) p.completer.completeError(e);
    }
  }

  void _shutdownPorts() {
    _port.close();
    _errorPort.close();
    _exitPort.close();
  }
}

class _Pending {
  _Pending(this.index, this.startMs, this.endMs);
  final int index;
  final int startMs;
  final int endMs;
  final Completer<ProcessedSegment> completer = Completer<ProcessedSegment>();
}

class _Bootstrap {
  const _Bootstrap(this.mainPort, this.config, this.factory);
  final SendPort mainPort;
  final ProcessingIsolateConfig config;
  final WorkerEngineFactory factory;
}

// ---------------------------------------------------------------------------
// Error (de)serialisation (pure; unit-tested).
// ---------------------------------------------------------------------------

/// Encodes [e] into a sendable map (`kind`, `messageAr`, `debug`).
Map<String, Object?> encodeWorkerError(Object e, [StackTrace? st]) {
  if (e is InsatoException) {
    final kind = switch (e) {
      ModelException() => 'model',
      MissingApiKeyException() => 'apiKey',
      AsrException() => 'asr',
      _ => 'insato',
    };
    return {'kind': kind, 'messageAr': e.messageAr, 'debug': e.debugDetails};
  }
  return {
    'kind': 'other',
    'messageAr': 'حدث خطأ غير متوقع أثناء معالجة الصوت.',
    'debug': st == null ? '$e' : '$e\n$st',
  };
}

/// Rebuilds the [InsatoException] encoded by [encodeWorkerError].
InsatoException decodeWorkerError(Map msg) {
  final m = (msg['messageAr'] as String?) ??
      'حدث خطأ غير متوقع أثناء معالجة الصوت.';
  final d = msg['debug'] as String?;
  return switch (msg['kind']) {
    'model' => ModelException(m, debugDetails: d),
    'apiKey' => MissingApiKeyException(m, debugDetails: d),
    'insato' => InsatoException(m, debugDetails: d),
    _ => AsrException(m, debugDetails: d),
  };
}

InsatoException _decodeError(Map msg) => decodeWorkerError(msg);

// ---------------------------------------------------------------------------
// Worker side.
// ---------------------------------------------------------------------------

Future<void> _workerMain(_Bootstrap boot) async {
  final out = boot.mainPort;
  final inbox = ReceivePort();
  out.send(inbox.sendPort);

  final WorkerEngines engines;
  try {
    engines = await boot.factory(boot.config);
  } catch (e, st) {
    out.send({'type': 'initError', ...encodeWorkerError(e, st)});
    inbox.close();
    return;
  }
  out.send({'type': 'ready', 'dimension': engines.embedder.dimension});

  final queue = Queue<Map>();
  var busy = false;
  Map? disposeRequest;

  Future<void> shutdown() async {
    try {
      await engines.asr?.dispose();
    } catch (_) {
      // Best effort.
    }
    try {
      await engines.embedder.dispose();
    } catch (_) {
      // Best effort.
    }
    out.send({'type': 'disposed'});
    inbox.close();
  }

  Future<void> pump() async {
    busy = true;
    while (true) {
      final dr = disposeRequest;
      if (dr != null && (queue.isEmpty || dr['drain'] != true)) {
        for (final m in queue) {
          out.send({
            'type': 'error',
            'id': m['id'],
            ...encodeWorkerError(const AsrException('تم إيقاف المعالجة.')),
          });
        }
        queue.clear();
        await shutdown();
        return;
      }
      if (queue.isEmpty) break;
      final msg = queue.removeFirst();
      out.send(await _processOne(engines, boot.config, msg));
      // Yield to the event loop so a pending 'dispose' can be received.
      await Future<void>.delayed(Duration.zero);
    }
    busy = false;
  }

  inbox.listen((msg) {
    if (msg is! Map) return;
    switch (msg['type']) {
      case 'process':
        queue.add(msg);
      case 'dispose':
        disposeRequest = msg;
    }
    if (!busy) unawaited(pump());
  });
}

Future<Map<String, Object?>> _processOne(
    WorkerEngines engines, ProcessingIsolateConfig config, Map msg) async {
  final id = msg['id'];
  try {
    final samples =
        (msg['samples'] as TransferableTypedData).materialize().asFloat32List();
    final segment = SpeechSegment(
      index: msg['index'] as int,
      startMs: msg['startMs'] as int,
      samples: samples,
    );
    var asr = const AsrResult(text: '');
    final engine = engines.asr;
    if (engine != null) {
      asr = await engine.transcribe(segment,
          languageHint: (msg['lang'] as String?) ?? config.languageHint);
    }
    Float32List? embedding;
    String? embeddingError;
    try {
      embedding = await engines.embedder.embed(samples);
    } on InsatoException catch (e) {
      embeddingError = e.messageAr;
    } catch (_) {
      embeddingError = 'تعذّر استخراج البصمة الصوتية لهذا المقطع.';
    }
    return {
      'type': 'result',
      'id': id,
      'text': asr.text,
      'language': asr.language,
      'confidence': asr.confidence,
      'embedding': embedding == null
          ? null
          : TransferableTypedData.fromList([
              embedding.buffer
                  .asUint8List(embedding.offsetInBytes, embedding.lengthInBytes)
            ]),
      'embeddingError': embeddingError,
    };
  } catch (e, st) {
    return {'type': 'error', 'id': id, ...encodeWorkerError(e, st)};
  }
}
