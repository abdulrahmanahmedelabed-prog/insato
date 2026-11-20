// Live Insato call (v1.2): near-real-time transcription of this device's
// microphone during a call.
//
// The normal pipeline (VAD → Whisper / cloud ASR + voice embedding in the
// processing isolate → SpeakerTracker → transcript rows) with call settings:
// segments are capped at [kCallMaxSegmentSeconds] (text within a few seconds
// even while someone talks on), every detected segment is announced at once
// as a pending line (partial-result placeholder on both screens), and each
// final line goes through the call engine first, which drops echoes of the
// other side before anything is stored.
//
// Mute feeds silence to the VAD instead of the microphone (the timeline of
// the recording and of the transcript stay aligned; nothing said while muted
// is transcribed or sent).
//
// Pure Dart over the session seams (fake audio source / engines in tests).

import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../diarization/speaker_tracker.dart';
import '../../session/meeting_session_controller.dart';
import 'transcript_merge.dart';

/// Longest segment during a call (seconds).
const double kCallMaxSegmentSeconds = 7.0;

/// Level above which the microphone is considered "speaking now".
const double kSpeakingLevel = 0.18;

/// What the transcriber reports.
abstract class CallTranscriberListener {
  /// Speech detected; text is being computed.
  void onPending(String id, int atUs, int durMs);

  /// A final line; return false to drop it (echo) — it is then not stored.
  bool onFinal(LiveLine line);

  /// A pending line produced no text.
  void onDropped(String id);

  /// Speaking indicator / level.
  void onActivity({required bool speaking, required double level});
}

const Uuid _uuid = Uuid();

class _Pending {
  _Pending(this.id, this.startMs);
  final String id;
  final int startMs;
  bool stored = false;
}

/// Transcribes the local microphone of a call into [meetingId].
class CallTranscriber {
  /// Creates the transcriber. [engines] must have been created with
  /// `maxSegmentSeconds: kCallMaxSegmentSeconds`.
  CallTranscriber({
    required this.meetingId,
    required this.audio,
    required this.engines,
    required SpeakerTracker tracker,
    required SpeakerRepository speakers,
    required SegmentRepository segments,
    required this.listener,
    required this._clockUs,
  }) : _speakers = speakers,
       _segments = segments {
    _pipeline = SessionPipeline(
      meetingId: meetingId,
      processor: engines.processor,
      tracker: tracker,
      speakers: speakers,
      segments: segments,
      sink: _sink,
      onChanged: _onPipelineChanged,
    );
  }

  /// Meeting the local lines are stored in.
  final String meetingId;

  /// Microphone.
  final SessionAudioSource audio;

  /// VAD + ASR + embedder.
  final SessionEngines engines;

  /// Receives the lines.
  final CallTranscriberListener listener;

  final SpeakerRepository _speakers;
  final SegmentRepository _segments;
  final int Function() _clockUs;
  late final SessionPipeline _pipeline;

  final List<_Pending> _pending = [];
  int _resolved = 0;
  int? _startUs;
  int _fedSamples = 0;
  bool _muted = false;
  bool _speaking = false;
  final Set<String> _echoes = {};
  StreamSubscription<Float32List>? _framesSub;
  StreamSubscription<SpeechSegment>? _segSub;
  StreamSubscription<double>? _levelSub;
  final Completer<void> _segmenterDone = Completer<void>();

  /// The pipeline (counters, created speakers).
  SessionPipeline get pipeline => _pipeline;

  /// This clock's time of the first captured sample (null before audio).
  int? get captureStartUs => _startUs;

  /// Ids of lines dropped as echoes before storing.
  Set<String> get droppedEchoes => Set.unmodifiable(_echoes);

  /// Starts capture (archiving to [archivePath] when given).
  Future<void> start({String? archivePath}) async {
    _segSub = engines.segmenter.segments.listen(
      _onSegment,
      onDone: () {
        if (!_segmenterDone.isCompleted) _segmenterDone.complete();
      },
      onError: (Object _) {},
    );
    _framesSub = audio.frames.listen(_onFrame);
    _levelSub = audio.level.listen(_onLevel);
    await audio.start(archivePath: archivePath);
  }

  void _onFrame(Float32List frame) {
    _startUs ??= _clockUs() - frame.length * 1000000 ~/ kSampleRate;
    _fedSamples += frame.length;
    engines.segmenter.accept(_muted ? Float32List(frame.length) : frame);
  }

  void _onLevel(double level) {
    final l = _muted ? 0.0 : level;
    // Hysteresis: on above the threshold, off clearly below it.
    final speaking = _speaking
        ? l > kSpeakingLevel * 0.6
        : l > kSpeakingLevel;
    _speaking = speaking;
    listener.onActivity(speaking: speaking, level: l);
  }

  /// This clock's time of meeting time [ms].
  int usAt(int ms) => (_startUs ?? _clockUs()) + ms * 1000;

  void _onSegment(SpeechSegment s) {
    final id = _uuid.v4();
    _pending.add(_Pending(id, s.startMs));
    listener.onPending(id, usAt(s.startMs), s.durationMs);
    _pipeline.submit(s);
  }

  Future<TranscriptSegment> _sink(TranscriptSegment seg) async {
    // Results are applied in submission order: the first unresolved pending
    // entry is this segment's.
    final idx = _resolved < _pending.length ? _resolved : -1;
    final p = idx >= 0 ? _pending[idx] : null;
    final id = p?.id ?? _uuid.v4();
    p?.stored = true;
    final sid = seg.speakerId;
    var name = '';
    if (sid != null) {
      try {
        name = (await _speakers.get(sid))?.name ?? '';
      } catch (_) {}
    }
    final withId = TranscriptSegment(
      id: id,
      meetingId: seg.meetingId,
      index: seg.index,
      startMs: seg.startMs,
      endMs: seg.endMs,
      text: seg.text,
      speakerId: seg.speakerId,
      language: seg.language,
      embedding: seg.embedding,
      speakerLocked: seg.speakerLocked,
      kind: seg.kind,
      asrConfidence: seg.asrConfidence,
      speakerConfidence: seg.speakerConfidence,
    );
    final keep = listener.onFinal(
      LiveLine(
        id: id,
        origin: LineOrigin.local,
        atUs: usAt(seg.startMs),
        durMs: seg.endMs - seg.startMs,
        text: seg.text,
        speakerKey: sid ?? '',
        speakerName: name,
        language: seg.language,
        kind: seg.kind,
        confidence: seg.asrConfidence,
      ),
    );
    if (!keep) {
      _echoes.add(id);
      return withId; // Not stored: an echo of the other side.
    }
    return _segments.insert(withId);
  }

  void _onPipelineChanged() {
    final done = _pipeline.completedCount;
    while (_resolved < done && _resolved < _pending.length) {
      final p = _pending[_resolved++];
      if (!p.stored) listener.onDropped(p.id);
    }
    // Keep the list short: resolved entries are no longer needed.
    if (_resolved > 64) {
      _pending.removeRange(0, _resolved);
      _resolved = 0;
    }
  }

  /// Mutes: silence goes to the VAD instead of the microphone.
  void setMuted(bool muted) {
    _muted = muted;
    if (muted) _onLevel(0);
  }

  /// Audio fed so far.
  Duration get fed =>
      Duration(microseconds: _fedSamples * 1000000 ~/ kSampleRate);

  /// Stops capture, transcribes what is left and releases the engines.
  /// Returns the recorded duration.
  Future<Duration> stop() async {
    Duration duration;
    try {
      duration = await audio.stop();
    } catch (_) {
      duration = fed;
    }
    await Future<void>.delayed(Duration.zero);
    await _framesSub?.cancel();
    await _levelSub?.cancel();
    engines.segmenter.flush();
    await disposeSegmenterSafely(engines.segmenter);
    await _segmenterDone.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    await _segSub?.cancel();
    await _pipeline.drain();
    await engines.dispose();
    return duration;
  }

  /// Stops without waiting for the remaining transcription.
  Future<void> abort() async {
    _pipeline.abort();
    try {
      await audio.stop();
    } catch (_) {}
    await _framesSub?.cancel();
    await _levelSub?.cancel();
    await _segSub?.cancel();
    await engines.dispose();
  }
}
