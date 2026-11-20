// Live recording session: microphone → VAD → (ASR + voice embedding) →
// speaker tracking → transcript rows in the database.
//
// Layers (each one replaceable in tests, none of them needs a microphone or
// the sherpa-onnx native library when faked):
//
// * [SessionAudioSource]   – audio capture (production: [AudioCaptureService]).
// * [SessionEnginesFactory]– builds the [SpeechSegmenter] + [SegmentProcessor]
//                            for a session (production: sherpa VAD on the main
//                            isolate, Whisper + speaker embedder in a
//                            [ProcessingIsolate], optional Groq Whisper).
// * [SessionPipeline]      – pure orchestration core: strictly ordered
//                            processing results → [SpeakerTracker] → speaker
//                            records → [TranscriptSegment] rows.
// * [SessionPlatformHooks] – microphone permission, Android foreground
//                            service, wakelock.
// * [MeetingSessionController] – the Riverpod notifier the UI talks to.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_foreground_task/flutter_foreground_task.dart' as fft;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio/audio_capture_service.dart';
import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/time_format.dart';
import '../data/repositories.dart';
import '../data/secure_settings.dart';
import '../diarization/channel_cue.dart';
import '../diarization/speaker_tracker.dart';
import '../diarization/vector_math.dart';
import '../features/phone_call/phone_call_providers.dart'
    show phoneCallSessionPlanProvider;
import '../features/voice/voice_devices.dart'
    show knownSpeakerThresholdFor, vadConfigFor;
import '../speech/asr_outcome.dart';
import '../features/groq/strings.dart' show GS;
import '../speech/cloud_asr_engine.dart';
import '../speech/model_catalog.dart';
import '../speech/model_manager.dart';
import '../speech/processing_isolate.dart';
import '../speech/vad_segmenter.dart';
import 'post_processor.dart';
import 'providers.dart';

export '../speech/processing_isolate.dart' show ProcessedSegment;

const Uuid _uuid = Uuid();

// ===========================================================================
// Errors
// ===========================================================================

/// Thrown by [MeetingSessionController.start] when the user has not yet
/// acknowledged the recording-consent reminder. Show the reminder, then call
/// `start(consentGiven: true)`.
class ConsentRequiredException extends InsatoException {
  /// Creates the exception with the standard Arabic message.
  const ConsentRequiredException()
    : super(
        'قبل التسجيل الأول: يجب إبلاغ جميع الحاضرين بأن الاجتماع '
        'سيُسجَّل وأخذ موافقتهم. يُرجى تأكيد ذلك للمتابعة.',
      );
}

/// Meeting error shown when a transcript was saved incomplete (the user
/// skipped the remaining transcription, or re-processing after a live
/// backlog overflow failed).
const String kIncompleteTranscriptAr =
    'لم يكتمل التفريغ؛ أعد المعالجة من التسجيل الصوتي.';

InsatoException _asInsato(Object e, String fallbackAr) {
  if (e is InsatoException) return e;
  return InsatoException(fallbackAr, debugDetails: '$e', cause: e);
}

// ===========================================================================
// Segment processing seam
// ===========================================================================

/// Turns a [SpeechSegment] into a [ProcessedSegment] (transcript + voice
/// embedding). Implementations may work concurrently but must accept calls in
/// chronological order; [SessionPipeline] re-orders nothing itself and
/// applies results strictly in submission order.
abstract class SegmentProcessor {
  /// Transcribes and embeds [segment]. Throws a [InsatoException] on failure.
  Future<ProcessedSegment> process(SpeechSegment segment);

  /// Segments submitted to [process] that have not completed yet.
  int get pendingCount;

  /// Releases engines. With [waitForPending] queued work is finished first.
  Future<void> dispose({bool waitForPending = false});
}

/// [SegmentProcessor] that runs an [AsrEngine] (optional) and a
/// [SpeakerEmbedder] sequentially on the current isolate.
///
/// Used by tests and for engines that are cheap or remote; production
/// on-device inference uses [IsolateSegmentProcessor] so the UI never janks.
class InlineSegmentProcessor implements SegmentProcessor {
  /// Creates a processor. [asr] may be null (embedding only); then every
  /// transcript is empty. [languageHint] is passed to the ASR engine.
  InlineSegmentProcessor({
    required this._asr,
    required this._embedder,
    this.languageHint,
  });

  final AsrEngine? _asr;
  final SpeakerEmbedder _embedder;

  /// ISO-639-1 hint for the ASR engine (null = auto-detect).
  final String? languageHint;

  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  bool _disposed = false;

  @override
  int get pendingCount => _pending;

  @override
  Future<ProcessedSegment> process(SpeechSegment segment) {
    if (_disposed) {
      return Future.error(
        const AsrException('تم إيقاف المعالجة؛ لا يمكن إضافة مقاطع جديدة.'),
      );
    }
    _pending++;
    final result = _tail.then((_) => _run(segment));
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result.whenComplete(() => _pending--);
  }

  Future<ProcessedSegment> _run(SpeechSegment segment) async {
    var asr = const AsrResult(text: '');
    final engine = _asr;
    if (engine != null) {
      asr = await engine.transcribe(segment, languageHint: languageHint);
    }
    Float32List? embedding;
    String? embeddingError;
    try {
      embedding = await _embedder.embed(segment.samples);
    } on InsatoException catch (e) {
      embeddingError = e.messageAr;
    } catch (_) {
      embeddingError = 'تعذّر استخراج البصمة الصوتية لهذا المقطع.';
    }
    return ProcessedSegment(
      index: segment.index,
      startMs: segment.startMs,
      endMs: segment.endMs,
      asr: asr,
      embedding: embedding,
      embeddingErrorAr: embeddingError,
    );
  }

  @override
  Future<void> dispose({bool waitForPending = false}) async {
    if (_disposed) return;
    _disposed = true;
    if (waitForPending) await _tail;
    await _asr?.dispose();
    await _embedder.dispose();
  }
}

/// Small async semaphore bounding concurrent operations.
class _Pool {
  _Pool(this.size);
  final int size;
  int _active = 0;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_active >= size) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    _active++;
    try {
      return await task();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
    }
  }
}

/// Production [SegmentProcessor]: on-device ASR + embeddings in a
/// [ProcessingIsolate], or (cloud mode) embeddings in the isolate and ASR via
/// a remote [AsrEngine] on the main isolate with bounded concurrency.
///
/// If the worker isolate dies (e.g. a native crash), it is respawned (at most
/// [maxRespawns] times per session) and the affected segments are retried
/// once, so a single crash does not lose the rest of the meeting.
class IsolateSegmentProcessor implements SegmentProcessor {
  IsolateSegmentProcessor._(
    this._spawn,
    this._isolate, {
    AsrEngine? cloudAsr,
    this.languageHint,
    int maxConcurrentCloudRequests = 3,
    this.maxRespawns = 3,
    this._onDeviceFallback,
    this._onNotice,
  }) : _cloud = cloudAsr,
       _pool = _Pool(math.max(1, maxConcurrentCloudRequests));

  /// Spawns the first worker with [spawn] (also used for respawns).
  ///
  /// With [cloudAsr] the worker must have been configured with
  /// `runAsr: false`; transcripts then come from [cloudAsr].
  ///
  /// [onDeviceFallback] spawns a worker that also runs on-device ASR: when
  /// the cloud engine reports that its free quota is used up
  /// ([CloudAsrQuotaExhaustedException]), the processor switches to it for
  /// the rest of the session and reports [GS.asrFellBackToDevice] through
  /// [onNotice] (or [GS.asrNoDeviceFallback] without a fallback).
  static Future<IsolateSegmentProcessor> start({
    required Future<ProcessingIsolate> Function() spawn,
    AsrEngine? cloudAsr,
    String? languageHint,
    int maxConcurrentCloudRequests = 3,
    int maxRespawns = 3,
    Future<ProcessingIsolate> Function()? onDeviceFallback,
    void Function(String noticeAr)? onNotice,
  }) async {
    final iso = await spawn();
    return IsolateSegmentProcessor._(
      spawn,
      iso,
      cloudAsr: cloudAsr,
      languageHint: languageHint,
      maxConcurrentCloudRequests: maxConcurrentCloudRequests,
      maxRespawns: maxRespawns,
      onDeviceFallback: onDeviceFallback,
      onNotice: onNotice,
    );
  }

  Future<ProcessingIsolate> Function() _spawn;
  ProcessingIsolate _isolate;
  final AsrEngine? _cloud;
  final _Pool _pool;
  final Future<ProcessingIsolate> Function()? _onDeviceFallback;
  final void Function(String noticeAr)? _onNotice;

  /// True once cloud transcription was abandoned for this session (quota
  /// used up) and the on-device worker took over.
  bool get usesDeviceFallback => _onDevice;
  bool _onDevice = false;
  bool _quotaNoticeSent = false;
  Future<void>? _switching;

  /// Language hint for the cloud engine (the worker has its own copy).
  final String? languageHint;

  /// Maximum number of worker restarts after crashes.
  final int maxRespawns;

  Future<ProcessingIsolate>? _respawning;
  int _respawns = 0;
  int _inFlight = 0;
  bool _disposed = false;

  /// Embedding dimension reported by the current worker.
  int get embeddingDimension => _isolate.embeddingDimension;

  @override
  int get pendingCount => _inFlight;

  @override
  Future<ProcessedSegment> process(SpeechSegment segment) async {
    if (_disposed) {
      throw const AsrException('تم إيقاف المعالجة؛ لا يمكن إضافة مقاطع جديدة.');
    }
    _inFlight++;
    try {
      final cloud = _cloud;
      if (_switching != null) await _switching;
      if (cloud == null || _onDevice) return await _runIsolate(segment);
      // Embedding failures are not fatal in cloud mode: the transcript is
      // what matters, the speaker then falls back to continuity rules.
      final embedding = _runIsolate(segment)
          .then<ProcessedSegment?>((r) => r, onError: (Object _) => null);
      final AsrResult asr;
      try {
        asr = await _pool.run(
          () => cloud.transcribe(segment, languageHint: languageHint),
        );
      } on CloudAsrQuotaExhaustedException {
        await embedding;
        if (_onDeviceFallback == null) {
          _notifyOnce(GS.asrNoDeviceFallback);
          rethrow;
        }
        await (_switching ??= _switchToDevice());
        return await _runIsolate(segment);
      }
      final emb = await embedding;
      return ProcessedSegment(
        index: segment.index,
        startMs: segment.startMs,
        endMs: segment.endMs,
        asr: asr,
        embedding: emb?.embedding,
        embeddingErrorAr: emb == null
            ? 'تعذّر استخراج البصمة الصوتية لهذا المقطع.'
            : emb.embeddingErrorAr,
      );
    } finally {
      _inFlight--;
    }
  }

  void _notifyOnce(String message) {
    if (_quotaNoticeSent) return;
    _quotaNoticeSent = true;
    _onNotice?.call(message);
  }

  /// Replaces the embedding-only worker by one that also transcribes, for
  /// the rest of the session.
  Future<void> _switchToDevice() async {
    final spawnDevice = _onDeviceFallback!;
    final old = _isolate;
    // Free the old worker first: a new one waits for earlier shutdowns so
    // two copies of the native models are never resident.
    try {
      await old.dispose(waitForPending: true);
    } catch (_) {
      // Best effort.
    }
    _isolate = await spawnDevice();
    _spawn = spawnDevice;
    _onDevice = true;
    _notifyOnce(GS.asrFellBackToDevice);
  }

  Future<ProcessedSegment> _runIsolate(SpeechSegment segment) async {
    final iso = _isolate;
    try {
      return await iso.process(segment);
    } catch (_) {
      if (_disposed || !iso.isClosed) rethrow;
      final fresh = await _respawn(iso);
      return fresh.process(segment);
    }
  }

  Future<ProcessingIsolate> _respawn(ProcessingIsolate dead) {
    if (!identical(_isolate, dead)) return Future.value(_isolate);
    final running = _respawning;
    if (running != null) return running;
    if (_respawns >= maxRespawns) {
      return Future.error(
        const AsrException(
          'توقفت المعالجة في الخلفية بشكل متكرر. يُرجى إعادة تشغيل التطبيق.',
        ),
      );
    }
    _respawns++;
    final f = _spawn().then((fresh) {
      _isolate = fresh;
      return fresh;
    });
    _respawning = f;
    return f.whenComplete(() => _respawning = null);
  }

  @override
  Future<void> dispose({bool waitForPending = false}) async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _isolate.dispose(waitForPending: waitForPending);
    } finally {
      await _cloud?.dispose();
    }
  }
}

// ===========================================================================
// Engines factory seam
// ===========================================================================

/// What a session needs from the speech engines, derived from settings.
class SessionEngineRequest {
  /// Creates a request.
  const SessionEngineRequest({
    required this.asrEngine,
    required this.whisperModelId,
    this.languageHint,
    this.firstIndex = 0,
    this.farField = false,
    this.cloudAsrModel = AppSettingsData.defaultGroqAsrModel,
    this.cloudAsrAcknowledged = false,
    this.vadConfig,
  });

  /// Builds a request from the user's settings.
  factory SessionEngineRequest.fromSettings(
    AppSettingsData s, {
    int firstIndex = 0,
  }) => SessionEngineRequest(
    asrEngine: s.asrEngine,
    whisperModelId: s.whisperModelId,
    languageHint: s.languageHint,
    firstIndex: firstIndex,
    farField: s.farFieldMode,
    cloudAsrModel: s.groqAsrModel,
    cloudAsrAcknowledged: s.groqAsrPrivacyAcknowledged,
  );

  /// [AppSettingsData.asrLocal] or [AppSettingsData.asrCloud].
  final String asrEngine;

  /// Catalog id of the Whisper model (on-device mode).
  final String whisperModelId;

  /// ISO-639-1 hint, null = auto-detect (recommended for mixed meetings).
  final String? languageHint;

  /// Index of the first segment produced by the segmenter.
  final int firstIndex;

  /// F18 far-field profile ("اجتماع في قاعة"): the VAD is tuned for quieter,
  /// distant speech ([vadConfigFor]).
  final bool farField;

  /// Groq Whisper model of cloud transcription.
  final String cloudAsrModel;

  /// The user accepted the cloud-transcription notice (audio to Groq);
  /// cloud transcription never starts without it.
  final bool cloudAsrAcknowledged;

  /// VAD tuning that replaces the far-field / default one (phone-call
  /// mode: the telephone audio profile); null = [vadConfigFor].
  final VadSegmenterConfig? vadConfig;

  /// True when transcription goes to the cloud engine.
  bool get usesCloudAsr => asrEngine == AppSettingsData.asrCloud;

  /// A copy with [languageHint] / [vadConfig] replaced (phone-call mode).
  SessionEngineRequest withOverrides({
    String? languageHint,
    bool clearLanguageHint = false,
    VadSegmenterConfig? vadConfig,
  }) => SessionEngineRequest(
    asrEngine: asrEngine,
    whisperModelId: whisperModelId,
    languageHint: clearLanguageHint
        ? null
        : (languageHint ?? this.languageHint),
    firstIndex: firstIndex,
    farField: farField,
    cloudAsrModel: cloudAsrModel,
    cloudAsrAcknowledged: cloudAsrAcknowledged,
    vadConfig: vadConfig ?? this.vadConfig,
  );
}

/// How long [disposeSegmenterSafely] waits for a segmenter to finish closing.
const Duration kSegmenterDisposeTimeout = Duration(seconds: 2);

/// Disposes [segmenter] without ever hanging or throwing.
///
/// A segmenter's [SpeechSegmenter.segments] is typically a single-subscription
/// stream: if nobody ever listened to it (engine creation or session start
/// failed before the session subscribed), closing it never completes. The
/// native resources are released synchronously before that point, so giving
/// up on the close after [timeout] loses nothing.
Future<void> disposeSegmenterSafely(
  SpeechSegmenter segmenter, {
  Duration timeout = kSegmenterDisposeTimeout,
}) async {
  try {
    await segmenter.dispose().timeout(timeout, onTimeout: () {});
  } catch (_) {
    // Best effort.
  }
}

/// Engines of one session (or one re-processing run).
class SessionEngines {
  /// Bundles a segmenter and a processor. [onDispose] releases anything else
  /// the factory created.
  SessionEngines({
    required this.segmenter,
    required this.processor,
    required this.description,
    this.notices = const Stream<String>.empty(),
    this._onDispose,
  });

  /// Arabic notices raised while the engines run (e.g. cloud transcription
  /// switched to the device after its free quota ran out); shown as the
  /// session warning.
  final Stream<String> notices;

  /// Splits the audio stream into speech segments.
  final SpeechSegmenter segmenter;

  /// Transcribes and embeds segments.
  final SegmentProcessor processor;

  /// Human-readable engine description (e.g. `whisper-turbo (on-device)`).
  final String description;

  final Future<void> Function()? _onDispose;
  bool _disposed = false;

  /// Disposes the segmenter, the processor (optionally finishing queued
  /// work) and any extra resources. Idempotent; never throws.
  Future<void> dispose({bool waitForPending = false}) async {
    if (_disposed) return;
    _disposed = true;
    await disposeSegmenterSafely(segmenter);
    try {
      await processor.dispose(waitForPending: waitForPending);
    } catch (_) {
      // Best effort.
    }
    try {
      await _onDispose?.call();
    } catch (_) {
      // Best effort.
    }
  }
}

/// Creates the speech engines for a session.
abstract class SessionEnginesFactory {
  /// Verifies that everything [request] needs is available (models
  /// downloaded, API key present) without loading anything heavy.
  ///
  /// Throws [ModelException] (models missing — the message tells the user to
  /// download them from the models screen) or [MissingApiKeyException].
  Future<void> ensureReady(SessionEngineRequest request);

  /// Loads the engines. Throws [ModelException] / [MissingApiKeyException].
  Future<SessionEngines> create(SessionEngineRequest request);
}

/// Picks the installed model of [kind]: the catalog's recommended one when
/// ready, else the first ready one, else the recommended id (reported as
/// missing by the caller).
String pickInstalledModelId(
  ModelKind kind,
  bool Function(String modelId) isReady,
) {
  final recommended = ModelCatalog.recommendedFor(kind).id;
  if (isReady(recommended)) return recommended;
  for (final spec in ModelCatalog.ofKind(kind)) {
    if (isReady(spec.id)) return spec.id;
  }
  return recommended;
}

/// Model ids a session needs: VAD, speaker model and (on-device ASR) the
/// Whisper model. An unknown Whisper id falls back to the recommended one.
List<String> requiredModelIds(
  SessionEngineRequest request,
  bool Function(String modelId) isReady,
) {
  final ids = <String>[
    ModelCatalog.sileroVad.id,
    pickInstalledModelId(ModelKind.speaker, isReady),
  ];
  if (!request.usesCloudAsr) {
    final spec = ModelCatalog.tryById(request.whisperModelId);
    ids.add(
      spec != null && spec.kind == ModelKind.asr
          ? spec.id
          : ModelCatalog.recommendedFor(ModelKind.asr).id,
    );
  }
  return ids;
}

/// Production [SessionEnginesFactory] backed by sherpa-onnx and (optionally)
/// Groq Whisper (free cloud transcription, with on-device fallback when its
/// quota runs out and the Whisper model is installed).
class SherpaSessionEnginesFactory implements SessionEnginesFactory {
  /// Creates the factory. [modelManager] resolves the app's [ModelManager]
  /// (it is created asynchronously).
  ///
  /// `keyterms` (F2) yields the custom vocabulary sent to cloud ASR
  /// (Groq Whisper `prompt`); a failure there never prevents recording.
  SherpaSessionEnginesFactory({
    required this._modelManager,
    required SecureSettings secureSettings,
    this._keyterms,
  }) : _secure = secureSettings;

  final Future<ModelManager> Function() _modelManager;
  final SecureSettings _secure;
  final Future<List<String>> Function()? _keyterms;

  Future<List<String>> _safeKeyterms() async {
    final f = _keyterms;
    if (f == null) return const [];
    try {
      return await f();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> ensureReady(SessionEngineRequest request) async {
    final mm = await _modelManager();
    var ids = requiredModelIds(request, mm.isReady);
    var missing = ids.where((id) => !mm.isReady(id)).toList();
    if (missing.isNotEmpty) {
      // States may be stale (e.g. files restored); re-scan once.
      await mm.refresh();
      ids = requiredModelIds(request, mm.isReady);
      missing = ids.where((id) => !mm.isReady(id)).toList();
    }
    if (missing.isNotEmpty) {
      final names = missing
          .map((id) => '«${ModelCatalog.tryById(id)?.displayNameAr ?? id}»')
          .join('، ');
      throw ModelException(
        'لا يمكن بدء التسجيل قبل تنزيل النماذج التالية: $names. '
        'يُرجى تنزيلها من صفحة «النماذج».',
        debugDetails: 'missing models: ${missing.join(', ')}',
      );
    }
    if (request.usesCloudAsr) {
      if (await _secure.getGroqApiKey() == null) {
        throw const MissingApiKeyException(GS.asrKeyMissing);
      }
      if (!request.cloudAsrAcknowledged) {
        throw const MissingApiKeyException(GS.asrPrivacyPending);
      }
    }
  }

  @override
  Future<SessionEngines> create(SessionEngineRequest request) async {
    await ensureReady(request);
    final mm = await _modelManager();
    final ids = requiredModelIds(request, mm.isReady);
    final vadPath = await mm.filePath(ids[0]);
    final speakerPath = await mm.filePath(ids[1]);
    final whisper = request.usesCloudAsr ? null : await mm.whisperPaths(ids[2]);
    // Cloud mode: the on-device Whisper model, when installed, takes over if
    // the free cloud quota runs out during the meeting.
    final fallbackSpec = ModelCatalog.tryById(request.whisperModelId);
    final fallbackId = request.usesCloudAsr
        ? (fallbackSpec != null &&
                  fallbackSpec.kind == ModelKind.asr &&
                  mm.isReady(fallbackSpec.id)
              ? fallbackSpec.id
              : (() {
                  final id = pickInstalledModelId(ModelKind.asr, mm.isReady);
                  return mm.isReady(id) ? id : null;
                })())
        : null;
    final fallbackWhisper = fallbackId == null
        ? null
        : await mm.whisperPaths(fallbackId);

    final segmenter = VadSegmenter(
      modelPath: vadPath,
      firstIndex: request.firstIndex,
      config: request.vadConfig ?? vadConfigFor(farField: request.farField),
    );
    GroqAsrEngine? cloud;
    final notices = StreamController<String>.broadcast();
    try {
      await segmenter.initialize();
      if (request.usesCloudAsr) {
        cloud = GroqAsrEngine(
          apiKeyProvider: _secure.getGroqApiKey,
          model: request.cloudAsrModel,
          keyterms: await _safeKeyterms(),
        );
        await cloud.initialize();
      }
      final processor = await IsolateSegmentProcessor.start(
        spawn: () => ProcessingIsolate.spawn(
          whisperEncoder: whisper?.encoder,
          whisperDecoder: whisper?.decoder,
          whisperTokens: whisper?.tokens,
          speakerModel: speakerPath,
          languageHint: request.languageHint,
          runAsr: whisper != null,
        ),
        cloudAsr: cloud,
        languageHint: request.languageHint,
        onDeviceFallback: fallbackWhisper == null
            ? null
            : () => ProcessingIsolate.spawn(
                whisperEncoder: fallbackWhisper.encoder,
                whisperDecoder: fallbackWhisper.decoder,
                whisperTokens: fallbackWhisper.tokens,
                speakerModel: speakerPath,
                languageHint: request.languageHint,
              ),
        onNotice: notices.add,
      );
      final asrName =
          cloud?.name ??
          '${ModelCatalog.tryById(ids[2])?.displayNameAr ?? ids[2]} (على الجهاز)';
      return SessionEngines(
        segmenter: segmenter,
        processor: processor,
        description: asrName,
        notices: notices.stream,
        onDispose: notices.close,
      );
    } catch (e) {
      // Nobody listens to the segmenter yet: never await its close blindly,
      // and release the cloud engine even if the segmenter misbehaves.
      await disposeSegmenterSafely(segmenter);
      try {
        await cloud?.dispose();
      } catch (_) {
        // Best effort.
      }
      await notices.close();
      rethrow;
    }
  }
}

// ===========================================================================
// Pipeline core (pure orchestration; unit-tested with fakes)
// ===========================================================================

/// Persists a finished transcript segment and returns the stored version.
typedef SegmentSink = Future<TranscriptSegment> Function(
  TranscriptSegment segment,
);

class _Outcome {
  const _Outcome.ok(ProcessedSegment this.result) : error = null;
  const _Outcome.failed(InsatoException this.error) : result = null;
  final ProcessedSegment? result;
  final InsatoException? error;
}

/// Orchestrates one meeting's segments: every submitted [SpeechSegment] is
/// processed (concurrently, by the [SegmentProcessor]) but its result is
/// applied strictly in submission order:
///
/// 1. empty transcripts are skipped (silence, music, filtered
///    hallucinations) and never create speakers;
/// 2. [SpeakerTracker.assign] picks the speaker from the voice embedding;
/// 3. a new meeting-local cluster gets a new [Speaker] record (`متحدث N`,
///    N unique across the voice library) and is linked to it; a cluster
///    matching a saved voiceprint reuses that speaker (and its name);
/// 4. the [TranscriptSegment] is stored through the [SegmentSink].
///
/// Nothing is ever dropped silently: failures are counted in [failedCount]
/// and the latest is kept in [lastError]. Speakers that disappear mid-meeting
/// (merged or deleted by the user) are followed: the cluster is relinked to
/// the merge target, or to a fresh speaker after a delete.
class SessionPipeline {
  /// Creates a pipeline for [meetingId].
  ///
  /// [sink] defaults to inserting into [segments]. [onChanged] is called
  /// after every submission and every applied result.
  SessionPipeline({
    required this.meetingId,
    required this._processor,
    required this._tracker,
    required this._speakers,
    required SegmentRepository segments,
    int firstIndex = 0,
    SegmentSink? sink,
    this.onChanged,
  }) : _segments = segments,
       _nextIndex = firstIndex,
       _sink = sink ?? segments.insert;

  /// Meeting the segments belong to.
  final String meetingId;

  /// Change listener (UI refresh).
  final void Function()? onChanged;

  final SegmentProcessor _processor;
  final SpeakerTracker _tracker;
  final SpeakerRepository _speakers;
  final SegmentRepository _segments;
  final SegmentSink _sink;

  int _nextIndex;
  int _submitted = 0;
  int _completed = 0;
  int _stored = 0;
  int _skipped = 0;
  int _failed = 0;
  int _pendingAudioMs = 0;
  Future<void> _tail = Future<void>.value();
  bool _aborted = false;
  final Completer<_Outcome?> _abortSignal = Completer<_Outcome?>();
  Speaker? _current;
  InsatoException? _lastError;
  final Set<String> _created = {};
  final Set<String> _recognized = {};
  final Map<String, String> _lastSegmentBySpeaker = {};
  final Map<String, ChannelProfile> _channelProfiles = {};
  final List<(int, Completer<void>)> _capacityWaiters = [];
  void Function(int done, int total)? _drainProgress;

  /// Segments handed to [submit].
  int get submittedCount => _submitted;

  /// Segments whose result has been applied (stored, skipped or failed).
  int get completedCount => _completed;

  /// Segments stored as transcript rows.
  int get storedCount => _stored;

  /// Segments without speech (empty transcript).
  int get skippedCount => _skipped;

  /// Segments that could not be transcribed or stored.
  int get failedCount => _failed;

  /// Segments waiting for processing (backpressure indicator).
  int get pendingCount => _submitted - _completed;

  /// Audio duration (ms) waiting for processing.
  int get pendingAudioMs => _pendingAudioMs;

  /// Speaker of the most recent stored segment (null = unknown).
  Speaker? get currentSpeaker => _current;

  /// Most recent processing/storage failure.
  InsatoException? get lastError => _lastError;

  /// Speaker records created by this pipeline.
  Set<String> get createdSpeakerIds => Set.unmodifiable(_created);

  /// Existing speakers (from earlier meetings) recognised by voice.
  Set<String> get recognizedSpeakerIds => Set.unmodifiable(_recognized);

  /// Queues [segment]. Processing starts immediately; the result is applied
  /// after every earlier segment's result.
  ///
  /// Only the segment's duration is retained here: the samples are owned by
  /// the processor from now on (the isolate processor copies them right
  /// away), so a backlog does not keep every segment's audio twice.
  ///
  /// [channels] (v1.2 C, multi-device meetings): SNR per device of this
  /// segment, used as a speaker cue and kept per stored segment
  /// ([channelProfiles]).
  void submit(SpeechSegment segment, {ChannelProfile? channels}) {
    if (_aborted) return;
    _submitted++;
    final durationMs = segment.durationMs;
    _pendingAudioMs += durationMs;
    final outcome = _processor
        .process(segment)
        .then<_Outcome>(
          _Outcome.ok,
          onError: (Object e) =>
              _Outcome.failed(_asInsato(e, 'تعذّر تفريغ أحد مقاطع الكلام.')),
        );
    _tail = _tail.then((_) => _apply(durationMs, outcome, channels));
    onChanged?.call();
  }

  /// Stored segment id → SNR per device (multi-device meetings only).
  Map<String, ChannelProfile> get channelProfiles =>
      Map.unmodifiable(_channelProfiles);

  /// Completes when at most [maxPending] segments are waiting (used to
  /// throttle fast producers such as re-processing a file).
  Future<void> waitForCapacity(int maxPending) {
    if (pendingCount <= maxPending) return Future<void>.value();
    final c = Completer<void>();
    _capacityWaiters.add((maxPending, c));
    return c.future;
  }

  /// Completes once every submitted segment has been applied, including
  /// segments submitted while draining. [onProgress] receives
  /// `(completed, submitted)` after each applied segment.
  Future<void> drain({void Function(int done, int total)? onProgress}) async {
    _drainProgress = onProgress;
    onProgress?.call(_completed, _submitted);
    try {
      while (true) {
        final t = _tail;
        await t;
        if (identical(t, _tail)) break;
      }
    } finally {
      _drainProgress = null;
    }
  }

  /// Stops applying results: pending segments are discarded without waiting
  /// for their processing to finish, so [drain] completes promptly (used when
  /// the user cancels a recording or skips the remaining transcription).
  /// Already stored rows are not touched.
  void abort() {
    if (_aborted) return;
    _aborted = true;
    _abortSignal.complete(null);
  }

  /// True once [abort] was called.
  bool get isAborted => _aborted;

  Future<void> _apply(
    int durationMs,
    Future<_Outcome> outcome, [
    ChannelProfile? channels,
  ]) async {
    try {
      final o = _aborted
          ? null
          : await Future.any<_Outcome?>([outcome, _abortSignal.future]);
      if (o == null || _aborted) return;
      final error = o.error;
      if (error != null) {
        _failed++;
        _lastError = error;
        return;
      }
      final r = o.result!;
      // F17: real speech without usable text is stored as unintelligible
      // (never dropped); only silence is skipped.
      final asrOutcome = classifyAsrOutcome(r.asr);
      final kind = asrOutcome.kind;
      if (kind == null) {
        _skipped++;
        return;
      }
      final assignment = _tracker.assign(
        segmentIndex: r.index,
        startMs: r.startMs,
        endMs: r.endMs,
        embedding: r.embedding,
        channels: channels,
      );
      var speaker = await _resolveSpeaker(assignment);
      if (_aborted) return;
      final seg = TranscriptSegment(
        id: _uuid.v4(),
        meetingId: meetingId,
        index: _nextIndex,
        startMs: r.startMs,
        endMs: math.max(r.startMs, r.endMs),
        text: asrOutcome.text,
        speakerId: speaker?.id,
        language: r.asr.language,
        embedding: r.embedding,
        kind: kind,
        asrConfidence: asrOutcome.confidence,
        speakerConfidence: speaker == null ? null : assignment.confidence,
      );
      TranscriptSegment stored;
      try {
        stored = await _sink(seg);
      } catch (e) {
        // The speaker may have been deleted between resolving and storing:
        // keep the words, drop the label.
        if (seg.speakerId == null) rethrow;
        speaker = null;
        stored = await _sink(_withoutSpeaker(seg));
      }
      _nextIndex++;
      _stored++;
      if (channels != null) _channelProfiles[stored.id] = channels;
      _current = speaker;
      final sid = stored.speakerId;
      if (sid != null) _lastSegmentBySpeaker[sid] = stored.id;
    } catch (e) {
      _failed++;
      _lastError = _asInsato(e, 'تعذّر حفظ أحد مقاطع النص.');
    } finally {
      _completed++;
      _pendingAudioMs = math.max(0, _pendingAudioMs - durationMs);
      _drainProgress?.call(_completed, _submitted);
      _wakeCapacityWaiters();
      onChanged?.call();
    }
  }

  void _wakeCapacityWaiters() {
    _capacityWaiters.removeWhere((w) {
      if (pendingCount <= w.$1) {
        w.$2.complete();
        return true;
      }
      return false;
    });
  }

  static TranscriptSegment _withoutSpeaker(TranscriptSegment s) =>
      TranscriptSegment(
        id: s.id,
        meetingId: s.meetingId,
        index: s.index,
        startMs: s.startMs,
        endMs: s.endMs,
        text: s.text,
        language: s.language,
        embedding: s.embedding,
        kind: s.kind,
        asrConfidence: s.asrConfidence,
      );

  Future<Speaker?> _resolveSpeaker(SpeakerAssignment a) async {
    final key = a.clusterKey;
    if (key == null) return null;
    final linked = a.linkedSpeakerId;
    if (linked != null) {
      final sp = await _speakers.get(linked);
      if (sp != null) {
        if (!_created.contains(sp.id)) _recognized.add(sp.id);
        return sp;
      }
      final replacement = await _followMissing(linked);
      if (replacement != null) {
        _tracker.linkCluster(
          key,
          replacement.id,
          voiceprint: replacement.centroid,
        );
        return replacement;
      }
    }
    final created = await _speakers.create();
    _created.add(created.id);
    _tracker.linkCluster(key, created.id);
    return created;
  }

  /// A speaker linked to a live cluster no longer exists. If the user merged
  /// it, the segments we stored for it now carry the merge target.
  Future<Speaker?> _followMissing(String speakerId) async {
    final segId = _lastSegmentBySpeaker.remove(speakerId);
    if (segId == null) return null;
    final seg = await _segments.get(segId);
    final target = seg?.speakerId;
    if (target == null || target == speakerId) return null;
    return _speakers.get(target);
  }
}

// ===========================================================================
// Audio source seam
// ===========================================================================

/// The audio capture surface the session needs.
abstract class SessionAudioSource {
  /// 16 kHz mono float frames.
  Stream<Float32List> get frames;

  /// 0..1 input level.
  Stream<double> get level;

  /// Capture state changes.
  Stream<AudioCaptureState> get states;

  /// Non-fatal capture problems (Arabic messages).
  Stream<AudioCaptureException> get errors;

  /// Captured audio time (excludes pauses).
  Duration get elapsed;

  /// Checks (and optionally requests) microphone permission.
  Future<bool> hasPermission({bool request = true});

  /// Starts capturing; archives to [archivePath] when given.
  Future<void> start({String? archivePath});

  /// Pauses capture.
  Future<void> pause();

  /// Resumes capture.
  Future<void> resume();

  /// Stops capture, flushes frames, returns the captured duration.
  Future<Duration> stop();
}

/// Optional interface of a [SessionAudioSource] that knows which input
/// device the running take actually captures from (F18): the remembered
/// microphone may be missing at start, lost mid-meeting, or not used at all
/// (system-audio takes). The session tags the meeting with this key rather
/// than the remembered one.
abstract interface class SessionInputDeviceReporter {
  /// Key of the device capturing now (`voiceDeviceKey`; null = the system
  /// default microphone).
  String? get activeDeviceKey;

  /// [activeDeviceKey] after each change during a take.
  Stream<String?> get activeDeviceChanges;

  /// Audio source of the running take: `mic`, `system` or `both`
  /// (`AppSettingsData.audioSource*`).
  String get activeAudioSource;
}

/// Optional interface of a [SessionAudioSource] that records several devices
/// at once (v1.2 C multi-device meetings).
abstract interface class SessionSegmentFuser {
  /// The audio to transcribe for the VAD [segment] (the device that heard it
  /// best) and the segment's SNR per device (null unless ≥ 2 devices
  /// covered it).
  ({SpeechSegment segment, ChannelProfile? channels}) fuseSegment(
    SpeechSegment segment,
  );

  /// Called once the take is drained, before speaker refinement: stores the
  /// take's device log and [segmentProfiles] (stored segment id → SNRs).
  Future<void> finishTake({
    required String meetingId,
    required Map<String, ChannelProfile> segmentProfiles,
  });
}

/// [SessionAudioSource] over the app's [AudioCaptureService].
class AudioCaptureSessionSource implements SessionAudioSource {
  /// Wraps [service].
  AudioCaptureSessionSource(this.service);

  /// The wrapped capture service.
  final AudioCaptureService service;

  @override
  Stream<Float32List> get frames => service.frames;
  @override
  Stream<double> get level => service.level;
  @override
  Stream<AudioCaptureState> get states => service.states;
  @override
  Stream<AudioCaptureException> get errors => service.errors;
  @override
  Duration get elapsed => service.elapsed;
  @override
  Future<bool> hasPermission({bool request = true}) =>
      service.hasPermission(request: request);
  @override
  Future<void> start({String? archivePath}) =>
      service.start(archivePath: archivePath);
  @override
  Future<void> pause() => service.pause();
  @override
  Future<void> resume() => service.resume();
  @override
  Future<Duration> stop() => service.stop();
}

// ===========================================================================
// Platform hooks seam
// ===========================================================================

/// Platform integration around a recording.
abstract class SessionPlatformHooks {
  /// Ensures microphone permission; throws [AudioCaptureException] with an
  /// Arabic explanation when denied.
  Future<void> ensureMicrophonePermission(SessionAudioSource audio);

  /// Called right before capture starts. Returns an Arabic warning when
  /// background protection could not be enabled (recording still works while
  /// the app stays open), else null.
  Future<String?> onRecordingStarted({required String meetingTitle});

  /// Called after capture stopped (or the session was cancelled).
  Future<void> onRecordingStopped();

  /// Called when the meeting being recorded is renamed, so platform UI that
  /// shows the title (the Android foreground notification) follows it.
  /// Must not throw.
  Future<void> onTitleChanged(String title);
}

/// Entry point of the Android foreground-service task. It does no work: the
/// service only keeps the process (and microphone access) alive while
/// recording in the background.
@pragma('vm:entry-point')
void insatoForegroundTaskCallback() {
  fft.FlutterForegroundTask.setTaskHandler(_RecordingTaskHandler());
}

class _RecordingTaskHandler extends fft.TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, fft.TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Production hooks: permission_handler on Android/iOS (record's own check on
/// Windows), a microphone-type foreground service with an Arabic notification
/// on Android, and a screen wakelock on every platform.
class DefaultSessionPlatformHooks implements SessionPlatformHooks {
  /// Creates the hooks for [platform] (default: the current one).
  DefaultSessionPlatformHooks({CapturePlatform? platform})
    : platform = platform ?? CapturePlatform.current;

  /// Target platform.
  final CapturePlatform platform;

  static const int _serviceId = 4711;
  bool _serviceStarted = false;

  bool get _isMobile =>
      platform == CapturePlatform.android || platform == CapturePlatform.ios;

  @override
  Future<void> ensureMicrophonePermission(SessionAudioSource audio) async {
    if (_isMobile) {
      ph.PermissionStatus? status;
      try {
        status = await ph.Permission.microphone.request();
      } catch (_) {
        status = null; // Plugin unavailable: fall back to record's check.
      }
      if (status != null) {
        if (status.isGranted || status.isLimited) return;
        // Cross-check with the recorder's own permission API: a misconfigured
        // permission_handler build (e.g. a missing iOS permission macro)
        // reports "denied" although recording is allowed.
        if (await _recorderAllows(audio)) return;
        if (status.isPermanentlyDenied || status.isRestricted) {
          throw const AudioCaptureException(
            'إذن الميكروفون مرفوض. يُرجى تفعيله من إعدادات الجهاز '
            '(التطبيقات ← إنصاتو ← الأذونات ← الميكروفون) ثم المحاولة مجددًا.',
          );
        }
        throw const AudioCaptureException(
          'يحتاج إنصاتو إلى إذن الميكروفون لتسجيل الاجتماع.',
        );
      }
    }
    if (!await audio.hasPermission()) {
      throw const AudioCaptureException(
        'لا يمكن الوصول إلى الميكروفون. تحقّق من إعدادات الخصوصية في النظام '
        'واسمح لتطبيق إنصاتو باستخدام الميكروفون.',
      );
    }
  }

  static Future<bool> _recorderAllows(SessionAudioSource audio) async {
    try {
      return await audio.hasPermission(request: false);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> onRecordingStarted({required String meetingTitle}) async {
    String? warning;
    if (platform == CapturePlatform.android) {
      warning = await _startForegroundService(meetingTitle);
    }
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Not critical: the foreground service / audio session keep recording.
    }
    return warning;
  }

  Future<String?> _startForegroundService(String meetingTitle) async {
    try {
      final perm =
          await fft.FlutterForegroundTask.checkNotificationPermission();
      if (perm != fft.NotificationPermission.granted) {
        await fft.FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {
      // The notification is still shown on most devices; continue.
    }
    fft.FlutterForegroundTask.init(
      androidNotificationOptions: fft.AndroidNotificationOptions(
        channelId: 'insato_recording',
        channelName: 'تسجيل الاجتماعات',
        channelDescription: 'يظهر هذا الإشعار طوال مدة تسجيل الاجتماع.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const fft.IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: fft.ForegroundTaskOptions(
        eventAction: fft.ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowAutoRestart: false,
        stopWithTask: true,
      ),
    );
    final result = await fft.FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [fft.ForegroundServiceTypes.microphone],
      notificationTitle: 'إنصاتو يسجّل الاجتماع',
      notificationText: meetingTitle,
      callback: insatoForegroundTaskCallback,
    );
    switch (result) {
      case fft.ServiceRequestSuccess():
        _serviceStarted = true;
        return null;
      case fft.ServiceRequestFailure(:final error):
        if (error is fft.ServiceAlreadyStartedException) {
          _serviceStarted = true;
          await fft.FlutterForegroundTask.updateService(
            notificationTitle: 'إنصاتو يسجّل الاجتماع',
            notificationText: meetingTitle,
          );
          return null;
        }
        return 'تعذّر تشغيل التسجيل في الخلفية؛ أبقِ التطبيق مفتوحًا أثناء '
            'الاجتماع.';
    }
  }

  @override
  Future<void> onTitleChanged(String title) async {
    if (platform != CapturePlatform.android || !_serviceStarted) return;
    try {
      await fft.FlutterForegroundTask.updateService(
        notificationTitle: 'إنصاتو يسجّل الاجتماع',
        notificationText: title,
      );
    } catch (_) {
      // Cosmetic only: the recording continues with the old text.
    }
  }

  @override
  Future<void> onRecordingStopped() async {
    if (platform == CapturePlatform.android && _serviceStarted) {
      _serviceStarted = false;
      await fft.FlutterForegroundTask.stopService();
    }
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Ignore.
    }
  }
}

// ===========================================================================
// Session state
// ===========================================================================

/// Lifecycle phase of [MeetingSessionController].
enum SessionPhase {
  /// No recording.
  idle,

  /// Checking permission/models and loading engines.
  preparing,

  /// Capturing audio.
  recording,

  /// Capture paused.
  paused,

  /// Stopping: draining the processing queue, refining speakers.
  finishing,

  /// The last operation failed; see [SessionState.error].
  error,
}

/// Immutable snapshot of the live session for the UI.
class SessionState {
  /// Creates a state.
  const SessionState({
    this.phase = SessionPhase.idle,
    this.meetingId,
    this.title,
    this.elapsed = Duration.zero,
    this.level = 0,
    this.liveSegments = 0,
    this.pendingProcessing = 0,
    this.pendingAudioMs = 0,
    this.failedSegments = 0,
    this.liveTranscriptionPaused = false,
    this.currentSpeakerId,
    this.currentSpeakerLabel,
    this.engineDescription,
    this.statusAr,
    this.progress,
    this.warningAr,
    this.error,
    this.lastMeetingId,
    this.inputDeviceKey,
    this.farField,
    this.audioSourceInUse,
  });

  /// Current phase.
  final SessionPhase phase;

  /// Meeting being recorded (null when idle).
  final String? meetingId;

  /// Title of the meeting being recorded.
  final String? title;

  /// Recorded audio time (pauses excluded).
  final Duration elapsed;

  /// 0..1 microphone level.
  final double level;

  /// Transcript segments stored so far.
  final int liveSegments;

  /// Segments waiting for transcription (backpressure).
  final int pendingProcessing;

  /// Audio (ms) waiting for transcription.
  final int pendingAudioMs;

  /// Segments that could not be transcribed.
  final int failedSegments;

  /// True while live transcription is suspended because it fell too far
  /// behind the speech (see [MeetingSessionController.start]); the meeting is
  /// then transcribed again from the audio archive after stopping.
  final bool liveTranscriptionPaused;

  /// Speaker of the latest segment.
  final String? currentSpeakerId;

  /// Display name of the latest segment's speaker.
  final String? currentSpeakerLabel;

  /// Description of the ASR engine in use.
  final String? engineDescription;

  /// Arabic status line while preparing / finishing.
  final String? statusAr;

  /// 0..1 progress while finishing (null = indeterminate).
  final double? progress;

  /// Non-fatal Arabic warning (e.g. background recording unavailable).
  final String? warningAr;

  /// Error of the last failed operation ([SessionPhase.error]).
  final InsatoException? error;

  /// Meeting finished most recently (to navigate to its details).
  final String? lastMeetingId;

  /// Input device of the running take (`voiceDeviceKey`; null = the default
  /// microphone, or not known before the take starts). Updated when the
  /// source falls back to the default microphone.
  final String? inputDeviceKey;

  /// Whether the running take uses the far-field profile; null before a take
  /// starts. Settings changed during a take apply to the next one only.
  final bool? farField;

  /// Audio source of the running take (`AppSettingsData.audioSource*`
  /// value); null when not known (the settings then apply).
  final String? audioSourceInUse;

  /// Arabic message of [error].
  String? get errorAr => error?.messageAr;

  /// True while a session occupies the microphone or is finishing.
  bool get isActive =>
      phase == SessionPhase.preparing ||
      phase == SessionPhase.recording ||
      phase == SessionPhase.paused ||
      phase == SessionPhase.finishing;

  /// True while recording or paused.
  bool get isCapturing =>
      phase == SessionPhase.recording || phase == SessionPhase.paused;

  /// True when a new recording may start.
  bool get canStart => !isActive;

  /// True when transcription lags more than a minute behind the speech.
  bool get isProcessingBehind => pendingAudioMs > 60000;

  /// Returns a copy with the given fields replaced (`clear*` set to null).
  SessionState copyWith({
    SessionPhase? phase,
    String? meetingId,
    String? title,
    Duration? elapsed,
    double? level,
    int? liveSegments,
    int? pendingProcessing,
    int? pendingAudioMs,
    int? failedSegments,
    bool? liveTranscriptionPaused,
    String? currentSpeakerId,
    String? currentSpeakerLabel,
    bool clearCurrentSpeaker = false,
    String? engineDescription,
    String? statusAr,
    bool clearStatus = false,
    double? progress,
    bool clearProgress = false,
    String? warningAr,
    bool clearWarning = false,
    InsatoException? error,
    bool clearError = false,
    String? lastMeetingId,
    String? inputDeviceKey,
    bool clearInputDevice = false,
    bool? farField,
    String? audioSourceInUse,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      meetingId: meetingId ?? this.meetingId,
      title: title ?? this.title,
      elapsed: elapsed ?? this.elapsed,
      level: level ?? this.level,
      liveSegments: liveSegments ?? this.liveSegments,
      pendingProcessing: pendingProcessing ?? this.pendingProcessing,
      pendingAudioMs: pendingAudioMs ?? this.pendingAudioMs,
      failedSegments: failedSegments ?? this.failedSegments,
      liveTranscriptionPaused:
          liveTranscriptionPaused ?? this.liveTranscriptionPaused,
      currentSpeakerId: clearCurrentSpeaker
          ? null
          : (currentSpeakerId ?? this.currentSpeakerId),
      currentSpeakerLabel: clearCurrentSpeaker
          ? null
          : (currentSpeakerLabel ?? this.currentSpeakerLabel),
      engineDescription: engineDescription ?? this.engineDescription,
      statusAr: clearStatus ? null : (statusAr ?? this.statusAr),
      progress: clearProgress ? null : (progress ?? this.progress),
      warningAr: clearWarning ? null : (warningAr ?? this.warningAr),
      error: clearError ? null : (error ?? this.error),
      lastMeetingId: lastMeetingId ?? this.lastMeetingId,
      inputDeviceKey: clearInputDevice
          ? null
          : (inputDeviceKey ?? this.inputDeviceKey),
      farField: farField ?? this.farField,
      audioSourceInUse: audioSourceInUse ?? this.audioSourceInUse,
    );
  }

  @override
  String toString() =>
      'SessionState(${phase.name}, meeting: $meetingId, '
      'elapsed: $elapsed, segments: $liveSegments, '
      'pending: $pendingProcessing, error: ${error?.messageAr})';
}

/// Default title of a meeting started at [time]:
/// `اجتماع الخميس، 19 نوفمبر 2026 - 14:05`.
String defaultSessionTitle(DateTime time) =>
    'اجتماع ${formatArabicDateTime(time)}';

// ===========================================================================
// Controller
// ===========================================================================

class _ActiveSession {
  _ActiveSession({
    required this.meeting,
    required this.engines,
    required this.pipeline,
    required this.audio,
    required this.hooks,
    required this.archivePath,
    required this.backlogLimitMs,
  });

  final Meeting meeting;
  final SessionEngines engines;
  final SessionPipeline pipeline;
  final SessionAudioSource audio;
  final SessionPlatformHooks hooks;
  final String? archivePath;
  final Completer<void> segmenterDone = Completer<void>();
  StreamSubscription<SpeechSegment>? segmentsSub;
  StreamSubscription<Float32List>? framesSub;
  StreamSubscription<double>? levelSub;
  StreamSubscription<AudioCaptureException>? errorsSub;
  StreamSubscription<AudioCaptureState>? statesSub;
  StreamSubscription<String?>? deviceSub;
  StreamSubscription<String>? noticesSub;
  Timer? ticker;
  bool stopping = false;

  /// Live-backlog cap (ms of audio waiting for transcription); 0 = none.
  final int backlogLimitMs;

  /// Live submission is suspended (backlog over [backlogLimitMs]).
  bool liveSuspended = false;

  /// Some speech was not transcribed live (backlog overflow): the meeting
  /// must be re-processed from the archive to be complete.
  bool overflowed = false;

  /// Speech segments not submitted because of the backlog cap.
  int droppedSegments = 0;

  /// The pipeline finished draining during stop.
  bool drained = false;

  /// The user chose to skip the remaining transcription while stopping.
  bool finishLater = false;

  Future<void> cancelAudioListeners() async {
    ticker?.cancel();
    ticker = null;
    await framesSub?.cancel();
    await levelSub?.cancel();
    await errorsSub?.cancel();
    await statesSub?.cancel();
    await deviceSub?.cancel();
    deviceSub = null;
    await noticesSub?.cancel();
    noticesSub = null;
    framesSub = null;
    levelSub = null;
    errorsSub = null;
    statesSub = null;
  }

  Future<void> cancelAll() async {
    await cancelAudioListeners();
    await segmentsSub?.cancel();
    segmentsSub = null;
    if (!segmenterDone.isCompleted) segmenterDone.complete();
  }
}

/// Drives a live recording session. One session at a time.
///
/// Typical use from the UI:
///
/// ```dart
/// final c = ref.read(meetingSessionControllerProvider.notifier);
/// try {
///   await c.start(title: 'اجتماع الفريق');
/// } on ConsentRequiredException {
///   // show the consent reminder, then: await c.start(consentGiven: true);
/// } on ModelException catch (e) {
///   // e.messageAr → offer to open the models screen
/// }
/// ...
/// final meetingId = await c.stop(); // minutes are generated in background
/// ```
///
/// Live transcript and speakers are read from the database streams
/// (`segmentsProvider(meetingId)`, `meetingSpeakersProvider(meetingId)`);
/// [SessionState] carries timing, level, backlog and status.
class MeetingSessionController extends Notifier<SessionState> {
  _ActiveSession? _active;
  Future<String?>? _stopping;

  @override
  SessionState build() {
    ref.onDispose(_teardown);
    return const SessionState();
  }

  void _set(SessionState s) {
    if (ref.mounted) state = s;
  }

  /// Starts recording a new meeting and returns its id.
  ///
  /// Checks, in order: recording consent ([ConsentRequiredException]; pass
  /// [consentGiven] after showing the reminder to record the
  /// acknowledgement), microphone permission ([AudioCaptureException]),
  /// required models / API keys ([ModelException],
  /// [MissingApiKeyException]). Then loads the engines, creates the meeting
  /// (title defaults to [defaultSessionTitle]), starts the Android
  /// foreground service and wakelock, and starts capture (archiving to
  /// `recordings/<meetingId>.wav` when "keep audio" is on).
  ///
  /// On failure nothing is left behind, the state becomes
  /// [SessionPhase.error] and the [InsatoException] is rethrown.
  ///
  /// v1.1: [context] (F3: agenda, expected attendees, notes) is stored with
  /// the meeting; [inputDevice] (F18) records the microphone used (the
  /// capture itself is configured by the audio source).
  Future<String> start({
    String? title,
    bool consentGiven = false,
    MeetingContext context = MeetingContext.empty,
    String? inputDevice,
  }) async {
    if (state.isActive) {
      throw const InsatoException('يوجد تسجيل قيد التشغيل بالفعل.');
    }
    final lastMeeting = state.lastMeetingId;
    _set(
      SessionState(
        phase: SessionPhase.preparing,
        statusAr: 'جارٍ التحضير للتسجيل…',
        lastMeetingId: lastMeeting,
      ),
    );

    final settingsStore = ref.read(appSettingsProvider);
    final hooks = ref.read(sessionPlatformHooksProvider);
    final audio = ref.read(sessionAudioSourceProvider);
    final factory = ref.read(sessionEnginesFactoryProvider);
    final meetings = ref.read(meetingRepositoryProvider);
    final speakers = ref.read(speakerRepositoryProvider);
    final segments = ref.read(segmentRepositoryProvider);
    final paths = ref.read(appPathsProvider);
    final post = ref.read(postProcessorProvider);
    final backlogLimitMs = ref.read(liveBacklogLimitMsProvider);

    SessionEngines? engines;
    Meeting? meeting;
    _ActiveSession? session;
    var hooksStarted = false;
    try {
      final settings = await settingsStore.load();
      if (!settings.consentAcknowledged) {
        if (!consentGiven) throw const ConsentRequiredException();
        await settingsStore.setConsentAcknowledged(true);
      }
      await hooks.ensureMicrophonePermission(audio);

      // Phone-call mode: telephone audio profile (VAD, language hint,
      // voiceprint thresholds per call side); null otherwise.
      final call = ref.read(phoneCallSessionPlanProvider);
      final request =
          call?.adjustRequest(SessionEngineRequest.fromSettings(settings)) ??
          SessionEngineRequest.fromSettings(settings);
      _set(state.copyWith(statusAr: 'جارٍ التحقق من النماذج…'));
      await factory.ensureReady(request);
      _set(state.copyWith(statusAr: 'جارٍ تحميل نماذج التعرّف على الكلام…'));
      engines = await factory.create(request);

      final known = (await speakers.getAll())
          .where((s) => isUsableEmbedding(s.centroid))
          .toList();
      // F18: the microphone of this meeting (the remembered input device
      // unless the caller names one); voiceprints learned on another
      // microphone are matched with a slightly relaxed threshold.
      // Provisional: replaced below by the device the source actually
      // opened, when it can tell (see [SessionInputDeviceReporter]).
      var deviceKey =
          inputDevice ?? await ref.read(sessionInputDeviceProvider)();
      final now = DateTime.now();
      final t = title?.trim();
      meeting = await meetings.create(
        title: (t == null || t.isEmpty) ? defaultSessionTitle(now) : t,
        createdAt: now,
        context: context,
        inputDevice: deviceKey,
      );
      String? archivePath;
      if (settings.keepAudio) {
        final dir = await paths.recordingsDir();
        final fileName = recordingFileName(meeting.id);
        archivePath = p.join(dir, fileName);
        // Only the file name is stored: absolute sandbox paths change on iOS
        // app updates. Readers resolve it with [AppPaths.resolveRecording].
        await meetings.setAudioPath(meeting.id, fileName);
      }

      final tracker = SpeakerTracker(
        knownSpeakers: known,
        matchThreshold: settings.matchThreshold,
        knownSpeakerThresholdOf: (sp) => knownSpeakerThresholdFor(
          sp,
          sessionDeviceKey: deviceKey,
          base: settings.matchThreshold,
        ),
        knownSpeakerThresholdIn: call == null
            ? null
            : (sp, partition) => call.knownSpeakerThreshold(
                sp,
                partition: partition,
                sessionDeviceKey: deviceKey,
                base: settings.matchThreshold,
              ),
      );
      final pipeline = SessionPipeline(
        meetingId: meeting.id,
        processor: engines.processor,
        tracker: tracker,
        speakers: speakers,
        segments: segments,
        onChanged: _onPipelineChanged,
      );
      final s = session = _ActiveSession(
        meeting: meeting,
        engines: engines,
        pipeline: pipeline,
        audio: audio,
        hooks: hooks,
        archivePath: archivePath,
        backlogLimitMs: backlogLimitMs,
      );
      _active = s;
      _listen(s);

      hooksStarted = true;
      final warning = await hooks.onRecordingStarted(
        meetingTitle: meeting.title,
      );
      await audio.start(archivePath: archivePath);
      // An explicit [inputDevice] from the caller is kept as given.
      if (audio is SessionInputDeviceReporter && inputDevice == null) {
        final reporter = audio as SessionInputDeviceReporter;
        final actual = reporter.activeDeviceKey;
        if (actual != deviceKey) {
          deviceKey = actual; // Read by the tracker's threshold closure.
          await meetings.setInputDevice(meeting.id, actual);
        }
        final id = meeting.id;
        s.deviceSub = reporter.activeDeviceChanges.listen((key) {
          // A fallback mid-meeting: the take mixes two microphones; it is
          // tagged with the device now in use (null = default) rather than
          // credited to the lost one.
          if (key == deviceKey) return;
          deviceKey = key;
          if (identical(_active, s)) {
            _set(
              state.copyWith(inputDeviceKey: key, clearInputDevice: key == null),
            );
          }
          unawaited(
            meetings.setInputDevice(id, key).then((_) {}, onError: (Object _) {}),
          );
        });
      }
      s.ticker = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _onTick(s),
      );
      _set(
        SessionState(
          phase: SessionPhase.recording,
          meetingId: meeting.id,
          title: meeting.title,
          engineDescription: engines.description,
          warningAr: warning,
          lastMeetingId: lastMeeting,
          inputDeviceKey: deviceKey,
          farField: request.farField,
          audioSourceInUse: audio is SessionInputDeviceReporter
              ? (audio as SessionInputDeviceReporter).activeAudioSource
              : null,
        ),
      );
      return meeting.id;
    } catch (e) {
      final error = _asInsato(e, 'تعذّر بدء التسجيل.');
      _active = null;
      if (session != null) {
        final active = session;
        active.pipeline.abort();
        await _safe(active.cancelAll);
      }
      if (engines != null) await _safe(engines.dispose);
      if (hooksStarted) await _safe(hooks.onRecordingStopped);
      if (meeting != null) {
        await _safe(() => meetings.delete(meeting!.id));
        await _deleteArchive(session?.archivePath);
        if (session != null) {
          await _safe(
            () =>
                post.deleteOrphanSpeakers(session!.pipeline.createdSpeakerIds),
          );
        }
      }
      _set(
        SessionState(
          phase: SessionPhase.error,
          error: error,
          lastMeetingId: lastMeeting,
        ),
      );
      throw error;
    }
  }

  void _listen(_ActiveSession s) {
    s.noticesSub = s.engines.notices.listen((message) {
      if (identical(_active, s)) _set(state.copyWith(warningAr: message));
    });
    s.segmentsSub = s.engines.segmenter.segments.listen(
      (segment) => _onSegment(s, segment),
      onError: (Object e) {
        _set(
          state.copyWith(
            warningAr: _asInsato(e, 'حدث خطأ أثناء اكتشاف الكلام.').messageAr,
          ),
        );
      },
      onDone: () {
        if (!s.segmenterDone.isCompleted) s.segmenterDone.complete();
      },
    );
    s.framesSub = s.audio.frames.listen(s.engines.segmenter.accept);
    s.levelSub = s.audio.level.listen((level) {
      if (identical(_active, s)) _set(state.copyWith(level: level));
    });
    s.errorsSub = s.audio.errors.listen((e) {
      if (identical(_active, s)) _set(state.copyWith(warningAr: e.messageAr));
    });
    s.statesSub = s.audio.states.listen((st) {
      // The platform ended the take (e.g. device lost, system stop): save
      // everything recorded so far as a normal meeting.
      if (st == AudioCaptureState.idle &&
          identical(_active, s) &&
          !s.stopping &&
          state.isCapturing) {
        _set(
          state.copyWith(
            warningAr: 'توقف التسجيل بشكل غير متوقع، وجارٍ حفظ ما سُجّل.',
          ),
        );
        unawaited(stop());
      }
    });
  }

  /// Submits a live segment, unless transcription is too far behind.
  ///
  /// Every queued segment holds its audio in memory until it is processed.
  /// When the queue exceeds [_ActiveSession.backlogLimitMs] of audio (a slow
  /// model on a slow device over a long meeting), live submission pauses
  /// until the backlog halves (an idle queue always takes the next segment,
  /// however long); the speech is still in the WAV archive, and
  /// the meeting is re-processed from it after stopping. Without an archive
  /// nothing could recover the speech, so every segment is queued.
  void _onSegment(_ActiveSession s, SpeechSegment segment) {
    final limit = s.backlogLimitMs;
    if (limit > 0 && s.archivePath != null && !s.pipeline.isAborted) {
      final pending = s.pipeline.pendingAudioMs;
      if (s.liveSuspended && pending > limit ~/ 2) {
        s.droppedSegments++;
        return;
      }
      if (s.liveSuspended) {
        s.liveSuspended = false;
        if (identical(_active, s)) {
          _set(state.copyWith(liveTranscriptionPaused: false));
        }
      } else if (pending > 0 && pending + segment.durationMs > limit) {
        s.liveSuspended = true;
        s.overflowed = true;
        s.droppedSegments++;
        if (identical(_active, s)) {
          _set(
            state.copyWith(
              liveTranscriptionPaused: true,
              warningAr:
                  'تأخّر التفريغ كثيرًا عن الكلام، فأُوقف التفريغ المباشر '
                  'مؤقتًا لحماية ذاكرة الجهاز. التسجيل مستمر، وسيُعاد تفريغ '
                  'الاجتماع كاملًا من التسجيل الصوتي بعد الإيقاف.',
            ),
          );
        }
        return;
      }
    }
    final audio = s.audio;
    if (audio is SessionSegmentFuser) {
      try {
        final fused = (audio as SessionSegmentFuser).fuseSegment(segment);
        s.pipeline.submit(fused.segment, channels: fused.channels);
        return;
      } catch (_) {
        // Fusion is an improvement only: transcribe the mix.
      }
    }
    s.pipeline.submit(segment);
  }

  void _onTick(_ActiveSession s) {
    if (!identical(_active, s) || s.stopping) return;
    _set(state.copyWith(elapsed: s.audio.elapsed));
  }

  void _onPipelineChanged() {
    final s = _active;
    if (s == null) return;
    final pl = s.pipeline;
    final sp = pl.currentSpeaker;
    _set(
      state.copyWith(
        liveSegments: pl.storedCount,
        pendingProcessing: pl.pendingCount,
        pendingAudioMs: pl.pendingAudioMs,
        failedSegments: pl.failedCount,
        currentSpeakerId: sp?.id,
        currentSpeakerLabel: sp?.name,
        clearCurrentSpeaker: sp == null && pl.storedCount > 0,
      ),
    );
  }

  /// Pauses capture (no audio is recorded until [resume]).
  Future<void> pause() async {
    final s = _active;
    if (s == null || state.phase != SessionPhase.recording) return;
    try {
      await s.audio.pause();
      _set(state.copyWith(phase: SessionPhase.paused, level: 0));
    } catch (e) {
      final err = _asInsato(e, 'تعذّر إيقاف التسجيل مؤقتًا.');
      _set(state.copyWith(warningAr: err.messageAr));
      throw err;
    }
  }

  /// Resumes a paused capture.
  Future<void> resume() async {
    final s = _active;
    if (s == null || state.phase != SessionPhase.paused) return;
    try {
      await s.audio.resume();
      _set(state.copyWith(phase: SessionPhase.recording, clearWarning: true));
    } catch (e) {
      final err = _asInsato(e, 'تعذّر استئناف التسجيل.');
      _set(state.copyWith(warningAr: err.messageAr));
      throw err;
    }
  }

  /// Stops recording and finishes the meeting:
  ///
  /// 1. stops capture (remaining frames are flushed into the VAD and the WAV
  ///    archive is finalised), flushes the VAD;
  /// 2. waits until every queued segment is transcribed and stored
  ///    ([SessionState.progress] reports the drain);
  /// 3. releases the engines, foreground service and wakelock;
  /// 4. stores the duration, sets the status to `processing` and runs speaker
  ///    refinement ([PostProcessor.refine]; a failure there keeps the live
  ///    labels, and voiceprints are still learned from them);
  /// 5. starts minutes generation in the background
  ///    ([MeetingJobsController.generateMinutes] with `automatic: true`):
  ///    with no minutes-engine key the meeting becomes `ready` with a hint. When
  ///    live transcription had to pause (backlog cap), the meeting is first
  ///    re-processed from the audio archive, then the minutes are written.
  ///
  /// While step 2 runs, [finishLater] skips the remaining transcription.
  ///
  /// Returns the meeting id (null when no session was running). On failure
  /// the meeting is marked `failed` with an Arabic error; its transcript is
  /// kept.
  Future<String?> stop() {
    final s = _active;
    if (s == null) return Future.value(null);
    return _stopping ??= _stop(s).whenComplete(() => _stopping = null);
  }

  Future<String?> _stop(_ActiveSession s) async {
    s.stopping = true;
    final id = s.meeting.id;
    final meetings = ref.read(meetingRepositoryProvider);
    final post = ref.read(postProcessorProvider);
    _set(
      state.copyWith(
        phase: SessionPhase.finishing,
        statusAr: 'جارٍ إيقاف التسجيل…',
        level: 0,
        clearProgress: true,
      ),
    );
    var warning = state.warningAr;
    try {
      Duration duration;
      try {
        duration = await s.audio.stop();
      } catch (e) {
        warning = _asInsato(e, 'حدث خطأ أثناء إيقاف التسجيل.').messageAr;
        duration = s.audio.elapsed;
      }
      // Let already-queued frame events reach the segmenter.
      await Future<void>.delayed(Duration.zero);
      await s.cancelAudioListeners();
      s.engines.segmenter.flush();
      await disposeSegmenterSafely(s.engines.segmenter);
      await s.segmenterDone.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );

      _set(
        state.copyWith(
          elapsed: duration,
          statusAr: 'جارٍ تفريغ ما تبقّى من الكلام…',
        ),
      );
      await s.pipeline.drain(
        onProgress: (done, total) {
          if (s.finishLater) return;
          _set(
            state.copyWith(
              progress: total == 0 ? 1.0 : done / total,
              statusAr: total - done > 0
                  ? 'جارٍ تفريغ ما تبقّى من الكلام (${total - done} مقطع)…'
                  : 'اكتمل التفريغ.',
            ),
          );
        },
      );
      s.drained = true;
      // Everything is drained (or skipped); a hung worker is killed after a
      // timeout.
      await s.engines.dispose();
      await _safe(s.hooks.onRecordingStopped);
      await s.segmentsSub?.cancel();
      s.segmentsSub = null;

      await meetings.setDuration(id, duration.inMilliseconds);
      final audio = s.audio;
      if (audio is SessionSegmentFuser) {
        // v1.2 C: device log + per-segment SNRs, read by the refinement.
        await _safe(
          () => (audio as SessionSegmentFuser)
              .finishTake(
                meetingId: id,
                segmentProfiles: s.pipeline.channelProfiles,
              )
              .timeout(const Duration(seconds: 10)),
        );
      }
      final archive = s.archivePath;
      final hasArchive = archive != null && await File(archive).exists();
      if (archive != null && !hasArchive) {
        await meetings.setAudioPath(id, null);
      }

      if (s.finishLater) return await _finishedLater(s, hasArchive: hasArchive);

      await meetings.updateStatus(id, MeetingStatus.processing);

      _set(
        state.copyWith(
          statusAr: 'جارٍ تحسين تمييز المتحدثين…',
          clearProgress: true,
        ),
      );
      try {
        await post.refine(
          id,
          sessionCreatedSpeakerIds: s.pipeline.createdSpeakerIds,
        );
      } catch (_) {
        // Refinement is an improvement only; the live labels stay valid.
        warning ??= 'تعذّر تحسين تمييز المتحدثين؛ أُبقيت التسميات الأولية.';
        try {
          // F15: every voice heard live must still get its voiceprint.
          // refine() already tried this; learning is idempotent, so this
          // only tells whether the voiceprints are safe.
          await post.learnFromCorrections(id);
        } catch (_) {
          warning =
              'تعذّر تحسين تمييز المتحدثين وحفظ البصمات الصوتية؛ يمكنك '
              'إعادة تمييز المتحدثين من صفحة الاجتماع.';
        }
      }
      final failed = s.pipeline.failedCount;
      if (failed > 0) {
        warning =
            'تعذّر تفريغ $failed من مقاطع الكلام'
            '${s.pipeline.lastError == null ? '' : ' (${s.pipeline.lastError!.messageAr})'}'
            '${hasArchive ? '. يمكنك إعادة المعالجة من التسجيل الصوتي.' : '.'}';
      }
      final completeFromArchive = s.overflowed && hasArchive;
      if (s.overflowed) {
        warning = completeFromArchive
            ? 'تأخّر التفريغ المباشر عن الكلام، لذا يُعاد الآن تفريغ الاجتماع '
                  'كاملًا من التسجيل الصوتي، ثم يُكتب المحضر.'
            : 'تأخّر التفريغ المباشر عن الكلام ولم يُفرَّغ جزء من الاجتماع.';
      }
      _active = null;
      _set(
        SessionState(
          phase: SessionPhase.idle,
          lastMeetingId: id,
          warningAr: warning,
        ),
      );
      final jobs = ref.read(meetingJobsProvider(id).notifier);
      unawaited(
        completeFromArchive
            ? _completeFromArchive(jobs, meetings, id)
            : jobs.generateMinutes(automatic: true),
      );
      return id;
    } catch (e) {
      final error = _asInsato(e, 'تعذّر إنهاء الاجتماع.');
      _active = null;
      s.pipeline.abort();
      await s.cancelAll();
      await s.engines.dispose();
      await _safe(s.hooks.onRecordingStopped);
      await _safe(
        () => meetings.setError(
          id,
          'تعذّر إكمال معالجة الاجتماع: ${error.messageAr}',
        ),
      );
      _set(
        SessionState(
          phase: SessionPhase.error,
          error: error,
          lastMeetingId: id,
        ),
      );
      return id;
    }
  }

  /// End of [_stop] after [finishLater]: the transcript stored so far is
  /// kept, refinement and automatic minutes are skipped, and the meeting is
  /// marked so the user re-processes it from the recording.
  Future<String> _finishedLater(
    _ActiveSession s, {
    required bool hasArchive,
  }) async {
    final id = s.meeting.id;
    await ref
        .read(meetingRepositoryProvider)
        .setError(
          id,
          hasArchive
              ? kIncompleteTranscriptAr
              : 'لم يكتمل التفريغ، ولا يوجد تسجيل صوتي لإكماله.',
        );
    _active = null;
    _set(
      SessionState(
        phase: SessionPhase.idle,
        lastMeetingId: id,
        warningAr: hasArchive
            ? 'حُفظ الاجتماع دون إكمال التفريغ. أعد المعالجة من التسجيل '
                  'الصوتي في صفحة الاجتماع لإكماله.'
            : 'حُفظ الاجتماع دون إكمال التفريغ.',
      ),
    );
    return id;
  }

  /// Re-transcribes a meeting whose live transcription overflowed, then
  /// writes its minutes. On failure the meeting keeps its partial transcript
  /// and says how to complete it.
  static Future<void> _completeFromArchive(
    MeetingJobsController jobs,
    MeetingRepository meetings,
    String id,
  ) async {
    try {
      if (await jobs.reprocessFromAudio()) {
        await jobs.generateMinutes(automatic: true);
        return;
      }
    } catch (_) {
      // Fall through: mark the meeting.
    }
    await _safe(() => meetings.setError(id, kIncompleteTranscriptAr));
  }

  /// True while [stop] is waiting for the remaining transcription and the
  /// recording is archived, so [finishLater] can skip the wait.
  bool get canFinishLater {
    final s = _active;
    return s != null &&
        s.stopping &&
        !s.drained &&
        !s.finishLater &&
        s.archivePath != null &&
        state.phase == SessionPhase.finishing;
  }

  /// Skips the remaining transcription of a meeting being stopped (see
  /// [canFinishLater]): queued segments are dropped, the transcript stored
  /// so far is kept, refinement and automatic minutes are skipped, and the
  /// meeting is marked "transcription incomplete" so the user can run
  /// "re-process from audio" later. The pending [stop] completes with the
  /// meeting id. Returns false when not possible.
  bool finishLater() {
    if (!canFinishLater) return false;
    final s = _active!;
    s.finishLater = true;
    s.pipeline.abort();
    _set(
      state.copyWith(
        statusAr: 'جارٍ حفظ الاجتماع دون إكمال التفريغ…',
        clearProgress: true,
      ),
    );
    return true;
  }

  /// True when [cancel] would discard the recording: a session runs and no
  /// stop (by the user or by the platform ending the take) has begun.
  bool get canDiscard {
    final s = _active;
    return s != null && !s.stopping && _stopping == null;
  }

  /// Discards the running recording: capture stops, queued work is dropped,
  /// and the meeting (transcript, audio file) plus the speakers it created
  /// (unless used elsewhere) are deleted. Returns true when discarded.
  ///
  /// Once a stop has begun (e.g. the platform ended the take while a discard
  /// confirmation was open) the meeting is being saved: nothing is deleted,
  /// this waits for the save and returns false.
  Future<bool> cancel() async {
    final s = _active;
    if (s == null) return false;
    if (s.stopping || _stopping != null) {
      try {
        await _stopping;
      } catch (_) {
        // _stop reports its own errors through the state.
      }
      return false;
    }
    s.stopping = true;
    _active = null;
    _set(
      state.copyWith(
        phase: SessionPhase.finishing,
        statusAr: 'جارٍ إلغاء التسجيل…',
      ),
    );
    s.pipeline.abort();
    try {
      await s.audio.stop();
    } catch (_) {
      // Discarding anyway.
    }
    await s.cancelAll();
    await s.engines.dispose();
    await s.pipeline.drain();
    await _safe(s.hooks.onRecordingStopped);
    await _safe(() => ref.read(meetingRepositoryProvider).delete(s.meeting.id));
    await _deleteArchive(s.archivePath);
    await _safe(
      () => ref
          .read(postProcessorProvider)
          .deleteOrphanSpeakers(s.pipeline.createdSpeakerIds),
    );
    _set(SessionState(lastMeetingId: state.lastMeetingId));
    return true;
  }

  /// Renames meeting [meetingId] (blank titles are ignored). When it is the
  /// meeting being recorded, the session title and the platform UI (the
  /// Android recording notification) follow. Returns true when renamed.
  Future<bool> renameMeeting(String meetingId, String title) async {
    final t = title.trim();
    if (t.isEmpty) return false;
    final ok = await ref
        .read(meetingRepositoryProvider)
        .updateTitle(meetingId, t);
    if (!ok) return false;
    final s = _active;
    if (s != null && s.meeting.id == meetingId) {
      if (state.meetingId == meetingId) _set(state.copyWith(title: t));
      await _safe(() => s.hooks.onTitleChanged(t));
    }
    return true;
  }

  /// Clears an error or warning shown by the UI.
  void dismissMessage() {
    if (state.phase == SessionPhase.error) {
      _set(SessionState(lastMeetingId: state.lastMeetingId));
    } else {
      _set(state.copyWith(clearWarning: true));
    }
  }

  static Future<void> _deleteArchive(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort.
    }
  }

  static Future<void> _safe(FutureOr<Object?> Function() f) async {
    try {
      await f();
    } catch (_) {
      // Best effort cleanup.
    }
  }

  void _teardown() {
    final s = _active;
    _active = null;
    if (s == null) return;
    s.pipeline.abort();
    unawaited(() async {
      try {
        await s.audio.stop();
      } catch (_) {
        // Shutting down.
      }
      await s.cancelAll();
      await s.engines.dispose();
      await _safe(s.hooks.onRecordingStopped);
    }());
  }
}
