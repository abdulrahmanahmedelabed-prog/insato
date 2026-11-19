// Voice enrollment (F1): analysis of a recorded take (VAD → quality checks
// → chunk embeddings → voiceprint) and saving it to the voice library.
//
// The analysis runs on the same engines as meetings — silero VAD and the
// installed speaker-embedding model (`pickInstalledModelId`), the latter in
// a background isolate — so an enrolled voiceprint is directly comparable
// with meeting embeddings. Everything is behind [EnrollmentAnalyzer], so
// tests run without the native library.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/interfaces.dart';
import '../../core/models.dart';
import '../../data/database.dart';
import '../../data/repositories.dart';
import '../../session/meeting_session_controller.dart'
    show pickInstalledModelId;
import '../../session/providers.dart' show modelManagerProvider;
import '../../speech/model_catalog.dart';
import '../../speech/model_manager.dart';
import '../../speech/processing_isolate.dart';
import '../../speech/vad_segmenter.dart';
import 'audio_quality.dart';
import 'strings.dart';
import 'voice_devices.dart';
import 'voiceprint_builder.dart';

/// Thrown when the VAD or speaker model is not installed.
class EnrollmentModelsMissingException extends InsatoException {
  /// Creates the exception with the standard Arabic message.
  const EnrollmentModelsMissingException({super.debugDetails})
    : super(VoiceStrings.speakerModelMissing);
}

/// Speech detection and embedding for enrollment takes.
abstract class EnrollmentAnalyzer {
  /// Context padding (ms, both sides together) the speech detector adds
  /// around each span; subtracted when counting voiced time.
  int get paddingMsPerSpan;

  /// Speech spans of [audio] (mono, [kSampleRate]).
  Future<List<SpeechSpan>> detectSpeech(Float32List audio);

  /// One embedding per chunk (null when a chunk could not be embedded).
  Future<List<Float32List?>> embed(List<Float32List> chunks);

  /// Releases the engines.
  Future<void> dispose();
}

/// Builds an [EnrollmentAnalyzer]; [farField] selects the far-field VAD
/// tuning. Throws [EnrollmentModelsMissingException].
typedef EnrollmentAnalyzerFactory = Future<EnrollmentAnalyzer> Function({
  bool farField,
});

/// Feeds [audio] to a fresh [segmenter] in 100 ms chunks, flushes it and
/// returns the speech spans it emitted. The segmenter is disposed.
Future<List<SpeechSpan>> collectSpeechSpans(
  SpeechSegmenter segmenter,
  Float32List audio,
) async {
  final spans = <SpeechSpan>[];
  final done = Completer<void>();
  Object? error;
  final sub = segmenter.segments.listen(
    (s) {
      final start = millisToSamples(s.startMs);
      spans.add(SpeechSpan(start, start + s.samples.length));
    },
    onError: (Object e) => error ??= e,
    onDone: () {
      if (!done.isCompleted) done.complete();
    },
  );
  try {
    await segmenter.initialize();
    const step = kSampleRate ~/ 10;
    for (var i = 0; i < audio.length; i += step) {
      final end = i + step > audio.length ? audio.length : i + step;
      segmenter.accept(Float32List.sublistView(audio, i, end));
    }
    segmenter.flush();
    // Let the emitted segments reach the listener before closing.
    await Future<void>.delayed(Duration.zero);
  } finally {
    await segmenter.dispose();
    await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    await sub.cancel();
  }
  final e = error;
  if (e != null) {
    throw e is InsatoException
        ? e
        : InsatoException(
            VoiceStrings.analysisFailed,
            debugDetails: '$e',
            cause: e,
          );
  }
  return normalizeSpans(spans, audio.length);
}

/// [EnrollmentAnalyzer] over a segmenter factory and an embedding function.
class SegmenterEmbedderAnalyzer implements EnrollmentAnalyzer {
  /// Creates the analyzer.
  SegmenterEmbedderAnalyzer({
    required this.newSegmenter,
    required this.embedOne,
    this.paddingMsPerSpan = 0,
    this.onDispose,
  });

  /// Creates a fresh (uninitialised) segmenter per take.
  final SpeechSegmenter Function() newSegmenter;

  /// Embeds one chunk (null when too short / silent).
  final Future<Float32List?> Function(Float32List samples) embedOne;

  @override
  final int paddingMsPerSpan;

  /// Releases the embedding engine.
  final Future<void> Function()? onDispose;

  @override
  Future<List<SpeechSpan>> detectSpeech(Float32List audio) =>
      collectSpeechSpans(newSegmenter(), audio);

  @override
  Future<List<Float32List?>> embed(List<Float32List> chunks) async => [
    for (final c in chunks) await embedOne(c),
  ];

  @override
  Future<void> dispose() async => onDispose?.call();
}

/// Production analyzer: silero VAD (same tuning as meetings) + the installed
/// speaker model in an embedding-only [ProcessingIsolate].
Future<EnrollmentAnalyzer> createSherpaEnrollmentAnalyzer(
  Future<ModelManager> Function() modelManager, {
  bool farField = false,
}) async {
  final mm = await modelManager();
  bool ready(String id) => mm.isReady(id);
  var speakerId = pickInstalledModelId(ModelKind.speaker, ready);
  final vadId = ModelCatalog.sileroVad.id;
  if (!ready(vadId) || !ready(speakerId)) {
    await mm.refresh();
    speakerId = pickInstalledModelId(ModelKind.speaker, ready);
    if (!ready(vadId) || !ready(speakerId)) {
      throw EnrollmentModelsMissingException(
        debugDetails: 'missing: vad=${ready(vadId)} speaker=$speakerId',
      );
    }
  }
  final vadPath = await mm.filePath(vadId);
  final speakerPath = await mm.filePath(speakerId);
  final worker = await ProcessingIsolate.spawn(
    whisperEncoder: null,
    whisperDecoder: null,
    whisperTokens: null,
    speakerModel: speakerPath,
    runAsr: false,
  );
  final config = vadConfigFor(farField: farField);
  var index = 0;
  return SegmenterEmbedderAnalyzer(
    newSegmenter: () => VadSegmenter(modelPath: vadPath, config: config),
    embedOne: (samples) async {
      final r = await worker.process(
        SpeechSegment(index: index++, startMs: 0, samples: samples),
      );
      return r.embedding;
    },
    paddingMsPerSpan: config.prePaddingMs + config.postPaddingMs,
    onDispose: worker.dispose,
  );
}

/// Builds enrollment analyzers. Overridden in tests.
final enrollmentAnalyzerFactoryProvider = Provider<EnrollmentAnalyzerFactory>(
  (ref) =>
      ({bool farField = false}) => createSherpaEnrollmentAnalyzer(
        () => ref.read(modelManagerProvider.future),
        farField: farField,
      ),
);

// ===========================================================================
// Analysis
// ===========================================================================

/// Why a take cannot be saved, beyond the signal checks.
enum EnrollmentVoiceIssue {
  /// No voiceprint could be extracted.
  noVoiceprint,

  /// The chunk embeddings disagree (several voices / bursts of noise).
  inconsistent,
}

/// Result of analysing one enrollment take.
class EnrollmentAnalysis {
  /// Creates the result.
  const EnrollmentAnalysis({
    required this.quality,
    required this.voiceprint,
    required this.voiceIssues,
  });

  /// Signal checks.
  final AudioQualityReport quality;

  /// The voiceprint (null when none could be built).
  final EnrollmentVoiceprint? voiceprint;

  /// Voiceprint problems.
  final List<EnrollmentVoiceIssue> voiceIssues;

  /// Whether the take can be saved.
  bool get canSave =>
      quality.passed && voiceprint != null && voiceIssues.isEmpty;
}

/// Analyses an enrollment take with [analyzer] (not disposed here).
Future<EnrollmentAnalysis> analyzeEnrollmentTake(
  Float32List audio,
  EnrollmentAnalyzer analyzer, {
  AudioQualityConfig config = const AudioQualityConfig(),
}) async {
  final spans = await analyzer.detectSpeech(audio);
  final quality = analyzeAudioQuality(
    audio,
    spans,
    config: config,
    paddingMsPerSpan: analyzer.paddingMsPerSpan,
  );
  if (quality.has(AudioQualityIssueKind.noSpeech)) {
    return EnrollmentAnalysis(
      quality: quality,
      voiceprint: null,
      voiceIssues: const [EnrollmentVoiceIssue.noVoiceprint],
    );
  }
  final chunks = planEnrollmentChunks(audio, spans);
  final embeddings = chunks.isEmpty
      ? const <Float32List?>[]
      : await analyzer.embed([for (final c in chunks) c.samples]);
  final weighted = <WeightedEmbedding>[
    for (var i = 0; i < chunks.length && i < embeddings.length; i++)
      if (embeddings[i] != null)
        WeightedEmbedding(embeddings[i]!, chunkWeight(chunks[i].durationMs)),
  ];
  final voiceprint = buildEnrollmentVoiceprint(weighted);
  final issues = <EnrollmentVoiceIssue>[
    if (voiceprint == null) EnrollmentVoiceIssue.noVoiceprint,
    if (voiceprint != null && voiceprint.used >= 3 && !voiceprint.isConsistent)
      EnrollmentVoiceIssue.inconsistent,
  ];
  return EnrollmentAnalysis(
    quality: quality,
    voiceprint: voiceprint,
    voiceIssues: issues,
  );
}

// ===========================================================================
// Saving
// ===========================================================================

/// Writes enrolled voiceprints to the voice library.
class VoiceEnrollmentWriter {
  /// Creates the writer.
  VoiceEnrollmentWriter({required this.db, required this.speakers});

  /// The database (for one transaction per save).
  final AppDatabase db;

  /// The voice library.
  final SpeakerRepository speakers;

  /// Creates a person named [name] with the [sample] voiceprint, recorded on
  /// [deviceKey] (null = default microphone). Throws [ArgumentError] for a
  /// blank name.
  Future<Speaker> createSpeaker({
    required String name,
    required EnrollmentVoiceprint sample,
    String? deviceKey,
  }) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError.value(name, 'name', 'blank');
    return speakers.create(
      name: n,
      isNamedByUser: true,
      centroid: sample.centroid,
      embeddingCount: sample.embeddingCount,
      voiceDevice: deviceKey,
    );
  }

  /// Adds [sample] to the voiceprint of [speakerId] (weighted by evidence
  /// counts), clears its low-confidence flag, updates its device tag and,
  /// when [newName] is given, names it. Throws [InsatoException] when the
  /// speaker no longer exists.
  Future<Speaker> improveSpeaker({
    required String speakerId,
    required EnrollmentVoiceprint sample,
    String? deviceKey,
    String? newName,
  }) {
    return db.transaction(() async {
      final speaker = await speakers.get(speakerId);
      if (speaker == null) {
        throw const InsatoException(VoiceStrings.speakerGone);
      }
      final hadUsable =
          speaker.centroid != null &&
          speaker.embeddingCount > 0 &&
          speaker.centroid!.length == sample.centroid.length;
      final next = improvedVoiceprint(speaker, sample);
      await speakers.updateVoiceprint(speakerId, next.centroid, next.count);
      if (speaker.lowConfidence) {
        await speakers.setLowConfidence(speakerId, false);
      }
      final device = voiceDeviceAfterLearning(
        currentDevice: hadUsable ? speaker.voiceDevice : null,
        sessionDeviceKey: deviceKey,
        previousCount: hadUsable ? speaker.embeddingCount : 0,
        learnedCount: sample.embeddingCount,
      );
      if (device != speaker.voiceDevice) {
        await speakers.setVoiceDevice(speakerId, device);
      }
      final n = newName?.trim();
      if (n != null &&
          n.isNotEmpty &&
          (n != speaker.name || !speaker.isNamedByUser)) {
        await speakers.rename(speakerId, n);
      }
      return (await speakers.get(speakerId))!;
    });
  }
}

/// The enrollment writer.
final voiceEnrollmentWriterProvider = Provider<VoiceEnrollmentWriter>(
  (ref) => VoiceEnrollmentWriter(
    db: ref.watch(databaseProvider),
    speakers: ref.watch(speakerRepositoryProvider),
  ),
);
