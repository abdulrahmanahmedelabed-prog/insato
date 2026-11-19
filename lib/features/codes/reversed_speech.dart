// Reversed-speech post-processing (F17): for every unintelligible segment
// of a meeting whose audio was kept, the segment's audio is sliced from the
// archived WAV, reversed in time and recognised again with the session's
// speech engines (the same `SessionEnginesFactory` seam the recording and
// "re-process from audio" use, so the user's ASR choice and consent apply).
// Text that looks real is stored as an enrichment of the coded-speech
// finding (`CodeFindingRepository.updatePayload`) — a hypothesis shown next
// to the segment; the transcript and the engine's findings are never
// rewritten as fact.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/pcm.dart';
import '../../audio/wav_writer.dart';
import '../../core/errors.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../data/secure_settings.dart';
import '../../session/meeting_session_controller.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import 'reversed_speech_logic.dart';
import 'strings.dart';

// ---------------------------------------------------------------------------
// WAV clips
// ---------------------------------------------------------------------------

/// Reads the mono [kSampleRate] samples of each `(startMs, endMs)` range of
/// the WAV file at [path] (one list per range, in order).
typedef WavClipReader = Future<List<Float32List>> Function(
  String path,
  List<(int, int)> rangesMs,
);

/// Default [WavClipReader].
///
/// 16-bit PCM (what the app records) is read by seeking straight to each
/// range, then down-mixed and resampled to [kSampleRate]; any other format
/// supported by `readWavInfo` is streamed once with `readWavChunks` and the
/// ranges are cut out on the way. Throws [FormatException] /
/// [FileSystemException] like `readWavInfo`.
Future<List<Float32List>> readWavClips(
  String path,
  List<(int, int)> rangesMs,
) async {
  if (rangesMs.isEmpty) return const [];
  final info = await readWavInfo(path);
  if (info.encoding == WavSampleEncoding.pcmInteger &&
      info.bitsPerSample == 16) {
    final raf = await File(path).open();
    try {
      final out = <Float32List>[];
      for (final (startMs, endMs) in rangesMs) {
        final (s, e) = frameRangeForMs(
          startMs: startMs,
          endMs: endMs,
          sampleRate: info.sampleRate,
          totalFrames: info.frameCount,
        );
        if (e <= s) {
          out.add(Float32List(0));
          continue;
        }
        await raf.setPosition(info.dataOffset + s * info.blockAlign);
        final bytes = await raf.read((e - s) * info.blockAlign);
        final whole = bytes.length - bytes.length % info.blockAlign;
        final mono = downmixToMono(
          pcm16LeBytesToFloat32(Uint8List.sublistView(bytes, 0, whole)),
          info.channels,
        );
        out.add(resampleLinear(mono, info.sampleRate));
      }
      return out;
    } finally {
      await raf.close();
    }
  }
  return _streamClips(path, rangesMs);
}

/// Cuts [rangesMs] out of one pass over the file's 16 kHz mono stream.
Future<List<Float32List>> _streamClips(
  String path,
  List<(int, int)> rangesMs,
) async {
  final ranges = [
    for (final (startMs, endMs) in rangesMs)
      (
        math.max(0, startMs) * kSampleRate ~/ 1000,
        math.max(0, endMs) * kSampleRate ~/ 1000,
      ),
  ];
  final builders = [for (final _ in ranges) BytesBuilder(copy: true)];
  final lastEnd = ranges.fold<int>(0, (m, r) => math.max(m, r.$2));
  var pos = 0;
  await for (final chunk in readWavChunks(path)) {
    final chunkEnd = pos + chunk.length;
    for (var i = 0; i < ranges.length; i++) {
      final (s, e) = ranges[i];
      final from = math.max(s, pos);
      final to = math.min(e, chunkEnd);
      if (to > from) {
        final part = Float32List.fromList(
          Float32List.sublistView(chunk, from - pos, to - pos),
        );
        builders[i].add(part.buffer.asUint8List());
      }
    }
    pos = chunkEnd;
    if (pos >= lastEnd) break;
  }
  return [
    for (final b in builders)
      if (b.takeBytes() case final bytes)
        Float32List.view(bytes.buffer, bytes.offsetInBytes, bytes.length ~/ 4),
  ];
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Progress of a run.
class ReversedSpeechProgress {
  /// Creates a progress value.
  const ReversedSpeechProgress({
    required this.done,
    required this.total,
    required this.statusAr,
  });

  /// Segments analysed.
  final int done;

  /// Segments to analyse.
  final int total;

  /// Arabic status line.
  final String statusAr;

  /// 0..1, or null while the total is unknown (engines loading).
  double? get fraction => total == 0 ? null : (done / total).clamp(0.0, 1.0);
}

/// Summary of a run.
class ReversedSpeechReport {
  /// Creates a report.
  const ReversedSpeechReport({
    required this.analysed,
    required this.found,
    required this.failed,
    this.cancelled = false,
  });

  /// Segments re-recognised.
  final int analysed;

  /// Segments where the reversed audio gave real text.
  final int found;

  /// Segments that could not be processed (engine errors).
  final int failed;

  /// True when the user stopped the run (results so far are saved).
  final bool cancelled;
}

/// Re-recognises unintelligible segments of a meeting in reverse (see the
/// file comment). Every dependency is injectable for tests.
class ReversedSpeechReprocessor {
  /// Creates the service.
  ReversedSpeechReprocessor({
    required this._meetings,
    required this._segments,
    required this._speakers,
    required this._findings,
    required SessionEnginesFactory enginesFactory,
    required this._loadSettings,
    required Future<String> Function(String stored) resolveRecording,
    bool Function(String meetingId)? isMeetingActive,
    WavClipReader? readClips,
    DateTime Function()? clock,
    int batchSize = 8,
  }) : _engines = enginesFactory,
       _resolve = resolveRecording,
       _isActive = isMeetingActive ?? ((_) => false),
       _readClips = readClips ?? readWavClips,
       _clock = clock ?? DateTime.now,
       _batch = math.max(1, batchSize);

  final MeetingRepository _meetings;
  final SegmentRepository _segments;
  final SpeakerRepository _speakers;
  final CodeFindingRepository _findings;
  final SessionEnginesFactory _engines;
  final Future<AppSettingsData> Function() _loadSettings;
  final Future<String> Function(String) _resolve;
  final bool Function(String) _isActive;
  final WavClipReader _readClips;
  final DateTime Function() _clock;
  final int _batch;

  /// The archived WAV of [meetingId], or null when the audio was not kept
  /// (or the file is gone).
  Future<String?> audioFileOf(String meetingId) async {
    final stored = (await _meetings.get(meetingId))?.audioPath;
    if (stored == null || stored.isEmpty) return null;
    final path = await _resolve(stored);
    return await File(path).exists() ? path : null;
  }

  /// Runs the reversed re-recognition of [meetingId]'s unintelligible
  /// segments and stores accepted results (see [planReversedFindings]).
  ///
  /// Throws [InsatoException] (meeting recording / missing, no audio,
  /// unreadable WAV) and the engines factory's [ModelException] /
  /// [MissingApiKeyException]. Engine errors on single segments are counted
  /// in [ReversedSpeechReport.failed]. [isCancelled] is polled between
  /// segments; what was analysed until then is saved.
  Future<ReversedSpeechReport> run(
    String meetingId, {
    void Function(ReversedSpeechProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (_isActive(meetingId)) {
      throw const InsatoException(KS.reverseRecording);
    }
    if (await _meetings.get(meetingId) == null) {
      throw const InsatoException(KS.meetingMissing);
    }
    final path = await audioFileOf(meetingId);
    if (path == null) throw const InsatoException(KS.reverseNoAudio);
    final targets = [
      for (final s in await _segments.getUnintelligible(meetingId))
        if (s.endMs - s.startMs >= kMinReversibleMs) s,
    ]..sort((a, b) => a.startMs.compareTo(b.startMs));
    if (targets.isEmpty) {
      return const ReversedSpeechReport(analysed: 0, found: 0, failed: 0);
    }

    onProgress?.call(
      ReversedSpeechProgress(
        done: 0,
        total: targets.length,
        statusAr: KS.reverseLoading,
      ),
    );
    final request = SessionEngineRequest.fromSettings(await _loadSettings());
    await _engines.ensureReady(request);
    final engines = await _engines.create(request);
    final attempts = <ReversedAttempt>[];
    var failed = 0;
    var cancelled = false;
    try {
      outer:
      for (var b = 0; b < targets.length; b += _batch) {
        final batch = targets.sublist(b, math.min(targets.length, b + _batch));
        final List<Float32List> clips;
        try {
          clips = await _readClips(path, [
            for (final s in batch) (s.startMs, s.endMs),
          ]);
        } on FormatException catch (e) {
          throw InsatoException(
            KS.reverseBadAudio,
            debugDetails: e.message,
            cause: e,
          );
        } on FileSystemException catch (e) {
          throw InsatoException(
            KS.reverseBadAudio,
            debugDetails: e.message,
            cause: e,
          );
        }
        for (var i = 0; i < batch.length; i++) {
          if (isCancelled?.call() ?? false) {
            cancelled = true;
            break outer;
          }
          final seg = batch[i];
          final clip = i < clips.length ? clips[i] : Float32List(0);
          final done = attempts.length + failed;
          onProgress?.call(
            ReversedSpeechProgress(
              done: done,
              total: targets.length,
              statusAr: KS.reverseProgress(done + 1, targets.length),
            ),
          );
          final durationMs = clip.length * 1000 ~/ kSampleRate;
          if (durationMs < kMinReversibleMs) {
            attempts.add(ReversedAttempt(segment: seg));
            continue;
          }
          try {
            final processed = await engines.processor.process(
              SpeechSegment(
                index: seg.index,
                startMs: seg.startMs,
                samples: reverseSamples(clip),
              ),
            );
            final verdict = assessReversedAsr(
              processed.asr,
              durationMs: durationMs,
              forwardText: seg.text,
            );
            attempts.add(
              ReversedAttempt(
                segment: seg,
                result: verdict.isAccepted
                    ? ReversedSpeechResult(
                        segment: seg.index,
                        text: verdict.text!,
                        language: processed.asr.language,
                        confidence: verdict.confidence,
                        at: _clock(),
                      )
                    : null,
              ),
            );
          } on InsatoException {
            failed++;
          }
        }
      }
    } finally {
      await engines.dispose();
    }

    onProgress?.call(
      ReversedSpeechProgress(
        done: targets.length,
        total: targets.length,
        statusAr: KS.reverseSaving,
      ),
    );
    await _store(meetingId, attempts);
    return ReversedSpeechReport(
      analysed: attempts.length,
      found: attempts.where((a) => a.result != null).length,
      failed: failed,
      cancelled: cancelled,
    );
  }

  Future<void> _store(String meetingId, List<ReversedAttempt> attempts) async {
    if (attempts.isEmpty) return;
    final speakers = await _speakers.getAllById();
    final findings = await _findings.getForMeeting(meetingId);
    final plan = planReversedFindings(
      meetingId: meetingId,
      findings: findings,
      attempts: attempts,
      speakerName: (s) =>
          (s.speakerId == null ? null : speakers[s.speakerId]?.name) ?? '',
      describe: KS.appFindingDescription,
      now: _clock(),
    );
    if (plan.isEmpty) return;
    if (plan.created.isEmpty) {
      for (final MapEntry(:key, :value) in plan.updates.entries) {
        await _findings.updatePayload(key, value);
      }
      return;
    }
    // The repository has no single insert: rewrite the meeting's findings
    // with the enriched payloads plus the new app findings, keeping order.
    await _findings.replaceForMeeting(meetingId, [
      for (final f in findings)
        CodeFinding(
          id: f.id,
          meetingId: f.meetingId,
          kind: f.kind,
          speakerId: f.speakerId,
          segmentIds: f.segmentIds,
          payload: plan.updates[f.id] ?? f.payload,
          createdAt: f.createdAt,
        ),
      ...plan.created,
    ]);
  }
}

/// The reversed-speech service wired to the app's repositories, settings
/// and session engines.
final reversedSpeechReprocessorProvider = Provider<ReversedSpeechReprocessor>((
  ref,
) {
  final settings = ref.watch(appSettingsProvider);
  return ReversedSpeechReprocessor(
    meetings: ref.watch(meetingRepositoryProvider),
    segments: ref.watch(segmentRepositoryProvider),
    speakers: ref.watch(speakerRepositoryProvider),
    findings: ref.watch(codeFindingRepositoryProvider),
    enginesFactory: ref.watch(sessionEnginesFactoryProvider),
    loadSettings: settings.load,
    resolveRecording: ref.watch(appPathsProvider).resolveRecording,
    isMeetingActive: (id) {
      final s = ref.read(meetingSessionControllerProvider);
      return s.isActive && s.meetingId == id;
    },
  );
});

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Phase of the reversed-speech run of one meeting.
enum ReversedSpeechPhase {
  /// Not started.
  idle,

  /// Running.
  running,

  /// Finished (see [ReversedSpeechState.report]).
  done,

  /// Failed (see [ReversedSpeechState.errorAr]).
  failed,
}

/// State of the reversed-speech run of one meeting.
class ReversedSpeechState {
  /// Creates a state.
  const ReversedSpeechState({
    this.phase = ReversedSpeechPhase.idle,
    this.progress,
    this.report,
    this.errorAr,
  });

  /// Phase.
  final ReversedSpeechPhase phase;

  /// Latest progress while running.
  final ReversedSpeechProgress? progress;

  /// Result when done.
  final ReversedSpeechReport? report;

  /// Arabic error when failed.
  final String? errorAr;

  /// True while running.
  bool get isRunning => phase == ReversedSpeechPhase.running;
}

/// Runs [ReversedSpeechReprocessor] for one meeting and exposes progress.
class ReversedSpeechController extends Notifier<ReversedSpeechState> {
  /// Creates the controller of [meetingId].
  ReversedSpeechController(this.meetingId);

  /// The meeting.
  final String meetingId;

  bool _cancel = false;

  @override
  ReversedSpeechState build() => const ReversedSpeechState();

  /// Starts a run (no-op while one is running).
  Future<void> start() async {
    if (state.isRunning) return;
    _cancel = false;
    // Keep running (and keep the result) while the tab is not shown.
    final link = ref.keepAlive();
    state = const ReversedSpeechState(phase: ReversedSpeechPhase.running);
    try {
      final report = await ref
          .read(reversedSpeechReprocessorProvider)
          .run(
            meetingId,
            onProgress: (p) {
              if (ref.mounted) {
                state = ReversedSpeechState(
                  phase: ReversedSpeechPhase.running,
                  progress: p,
                );
              }
            },
            isCancelled: () => _cancel,
          );
      if (ref.mounted) {
        state = ReversedSpeechState(
          phase: ReversedSpeechPhase.done,
          report: report,
        );
      }
    } on InsatoException catch (e) {
      if (ref.mounted) {
        state = ReversedSpeechState(
          phase: ReversedSpeechPhase.failed,
          errorAr: e.messageAr,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = const ReversedSpeechState(
          phase: ReversedSpeechPhase.failed,
          errorAr: S.unexpectedError,
        );
      }
    } finally {
      link.close();
    }
  }

  /// Asks the running job to stop after the current segment.
  void cancel() => _cancel = true;

  /// Clears a finished / failed state.
  void clear() {
    if (!state.isRunning) state = const ReversedSpeechState();
  }
}

/// Reversed-speech run of one meeting.
final reversedSpeechControllerProvider = NotifierProvider.autoDispose
    .family<ReversedSpeechController, ReversedSpeechState, String>(
      ReversedSpeechController.new,
    );
