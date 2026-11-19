// Per-meeting evidence controller (F5): opening an evidence chip plays the
// archived WAV from the segment start minus a 1 s pre-roll and highlights
// the transcript line; without the audio (not kept, still recording, file
// missing or unplayable) it jumps to the transcript line instead. While
// playing, the highlight follows the line being heard.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import 'evidence_logic.dart';
import 'evidence_player.dart';
import 'strings.dart';

/// Whether a meeting's recording can be played.
enum EvidenceAudioStatus {
  /// The WAV exists at [EvidenceAudioLocation.path].
  available,

  /// The recording was not kept (setting off) or the file is gone.
  notKept,

  /// The meeting is still being recorded (the WAV is not final).
  recording,
}

/// Result of resolving a meeting's recording.
class EvidenceAudioLocation {
  /// Creates a location.
  const EvidenceAudioLocation(this.status, [this.path]);

  /// Not kept.
  static const EvidenceAudioLocation notKept = EvidenceAudioLocation(
    EvidenceAudioStatus.notKept,
  );

  /// Status.
  final EvidenceAudioStatus status;

  /// Absolute file path when [status] is available.
  final String? path;
}

/// Resolves the playable recording of a meeting. Overridden in tests.
final evidenceAudioResolverProvider =
    Provider<Future<EvidenceAudioLocation> Function(String meetingId)>((ref) {
      return (meetingId) async {
        final session = ref.read(meetingSessionControllerProvider);
        if (session.isActive && session.meetingId == meetingId) {
          return const EvidenceAudioLocation(EvidenceAudioStatus.recording);
        }
        final meeting = await ref
            .read(meetingRepositoryProvider)
            .get(meetingId);
        final stored = meeting?.audioPath;
        if (stored == null || stored.isEmpty) {
          return EvidenceAudioLocation.notKept;
        }
        final path = await ref.read(appPathsProvider).resolveRecording(stored);
        if (!await File(path).exists()) return EvidenceAudioLocation.notKept;
        return EvidenceAudioLocation(EvidenceAudioStatus.available, path);
      };
    });

/// What the evidence UI of one meeting shows.
class EvidenceState {
  /// Creates a state.
  const EvidenceState({
    this.target,
    this.playerVisible = false,
    this.loading = false,
    this.playing = false,
    this.positionMs = 0,
    this.durationMs,
    this.speed = 1.0,
    this.highlightedSegmentId,
    this.highlightedSegmentIndex,
    this.focusSerial = 0,
    this.transcriptJumpSerial = 0,
    this.noticeAr,
    this.noticeSerial = 0,
  });

  /// The evidence clip last opened.
  final EvidenceTarget? target;

  /// Whether the player bar is shown.
  final bool playerVisible;

  /// Opening the recording.
  final bool loading;

  /// Audio is playing.
  final bool playing;

  /// Playback position.
  final int positionMs;

  /// Recording duration, when known.
  final int? durationMs;

  /// Playback speed (one of [kEvidenceSpeeds]).
  final double speed;

  /// Row id of the highlighted transcript line.
  final String? highlightedSegmentId;

  /// `TranscriptSegment.index` of the highlighted line.
  final int? highlightedSegmentIndex;

  /// Increments when the transcript should scroll to the highlighted line.
  final int focusSerial;

  /// Increments when the meeting screen should switch to the transcript.
  final int transcriptJumpSerial;

  /// Last one-shot notice (fallback reason or error).
  final String? noticeAr;

  /// Increments with each new [noticeAr].
  final int noticeSerial;

  /// Returns a copy with the given fields replaced.
  EvidenceState copyWith({
    EvidenceTarget? target,
    bool? playerVisible,
    bool? loading,
    bool? playing,
    int? positionMs,
    int? durationMs,
    double? speed,
    String? highlightedSegmentId,
    int? highlightedSegmentIndex,
    int? focusSerial,
    int? transcriptJumpSerial,
    String? noticeAr,
    int? noticeSerial,
  }) => EvidenceState(
    target: target ?? this.target,
    playerVisible: playerVisible ?? this.playerVisible,
    loading: loading ?? this.loading,
    playing: playing ?? this.playing,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    speed: speed ?? this.speed,
    highlightedSegmentId: highlightedSegmentId ?? this.highlightedSegmentId,
    highlightedSegmentIndex:
        highlightedSegmentIndex ?? this.highlightedSegmentIndex,
    focusSerial: focusSerial ?? this.focusSerial,
    transcriptJumpSerial: transcriptJumpSerial ?? this.transcriptJumpSerial,
    noticeAr: noticeAr ?? this.noticeAr,
    noticeSerial: noticeSerial ?? this.noticeSerial,
  );
}

/// Evidence playback and transcript focus of one meeting.
class EvidenceController extends Notifier<EvidenceState> {
  /// Creates the controller of [meetingId].
  EvidenceController(this.meetingId);

  /// The meeting.
  final String meetingId;

  EvidenceAudioPlayer? _player;
  String? _openPath;
  final List<StreamSubscription<Object?>> _subs = [];
  List<TranscriptSegment> _sorted = const [];
  bool _completed = false;
  int _request = 0;

  /// Start of the clip being played from its pre-roll: the highlight stays
  /// on the evidence line until playback reaches it (null = follow freely).
  int? _clipStartMs;

  @override
  EvidenceState build() {
    ref.listen<AsyncValue<List<TranscriptSegment>>>(
      segmentsProvider(meetingId),
      (_, next) {
        final list = next.value;
        if (list != null) _sorted = sortSegmentsByTime(list);
      },
      fireImmediately: true,
    );
    ref.onDispose(_release);
    return const EvidenceState();
  }

  /// Opens [target]: plays the recording from its pre-roll and highlights
  /// the line, or jumps to the line when the audio cannot be played.
  Future<void> open(EvidenceTarget target) async {
    final request = ++_request;
    state = state.copyWith(
      target: target,
      highlightedSegmentId: target.segmentId,
      highlightedSegmentIndex: target.segmentIndex,
      focusSerial: state.focusSerial + 1,
    );
    EvidenceAudioLocation location;
    try {
      location = await ref.read(evidenceAudioResolverProvider)(meetingId);
    } catch (_) {
      location = EvidenceAudioLocation.notKept;
    }
    if (!_current(request)) return;
    if (location.status != EvidenceAudioStatus.available ||
        location.path == null) {
      await _pausePlayer();
      if (!_current(request)) return;
      _jumpToTranscript(
        location.status == EvidenceAudioStatus.recording
            ? ES.audioStillRecording
            : ES.audioNotKept,
      );
      return;
    }
    state = state.copyWith(playerVisible: true, loading: true);
    try {
      final player = _ensurePlayer();
      if (_openPath != location.path) {
        _openPath = null;
        await player.open(location.path!);
        if (!_current(request)) return;
        _openPath = location.path;
      }
      final duration = await player.durationMs() ?? state.durationMs;
      if (!_current(request)) return;
      final start = evidencePlaybackStartMs(
        target.startMs,
        durationMs: duration,
      );
      await player.seek(start);
      if (!_current(request)) return;
      await player.play();
      if (state.speed != 1.0) await player.setRate(state.speed);
      if (!_current(request)) return;
      _completed = false;
      _clipStartMs = target.startMs;
      state = state.copyWith(
        loading: false,
        playing: true,
        positionMs: start,
        durationMs: duration != null && duration > 0 ? duration : null,
      );
    } catch (_) {
      if (!_current(request)) return;
      await _release();
      state = EvidenceState(
        target: target,
        speed: state.speed,
        highlightedSegmentId: target.segmentId,
        highlightedSegmentIndex: target.segmentIndex,
        focusSerial: state.focusSerial,
        transcriptJumpSerial: state.transcriptJumpSerial,
        noticeAr: state.noticeAr,
        noticeSerial: state.noticeSerial,
      );
      _jumpToTranscript(ES.playbackFailed);
    }
  }

  /// Opens the evidence segment with index [segmentIndex] of this meeting.
  /// Shows a notice when the segment no longer exists.
  Future<void> openIndex(int segmentIndex) async {
    final matches = resolveEvidence([segmentIndex], _sorted);
    if (matches.isEmpty) {
      _notice(ES.segmentMissing);
      return;
    }
    await open(matches.first);
  }

  /// Plays or pauses. After the end of the file, replays the clip.
  Future<void> togglePlay() async {
    final player = _player;
    if (player == null || state.loading) return;
    try {
      if (state.playing) {
        await player.pause();
        state = state.copyWith(playing: false);
        return;
      }
      if (_completed) {
        await replayClip();
        return;
      }
      await player.play();
      if (state.speed != 1.0) await player.setRate(state.speed);
      state = state.copyWith(playing: true);
    } catch (_) {
      await _fail();
    }
  }

  /// Seeks back to the opened clip's pre-roll and plays.
  Future<void> replayClip() async {
    final player = _player;
    final target = state.target;
    if (player == null || target == null) return;
    try {
      final start = evidencePlaybackStartMs(
        target.startMs,
        durationMs: state.durationMs,
      );
      await player.seek(start);
      await player.play();
      if (state.speed != 1.0) await player.setRate(state.speed);
      _completed = false;
      _clipStartMs = target.startMs;
      state = state.copyWith(
        playing: true,
        positionMs: start,
        highlightedSegmentId: target.segmentId,
        highlightedSegmentIndex: target.segmentIndex,
      );
    } catch (_) {
      await _fail();
    }
  }

  /// Moves playback to [positionMs] (scrubbing).
  Future<void> seekTo(int positionMs) async {
    final player = _player;
    if (player == null) return;
    final p = clampSeekMs(positionMs, state.durationMs);
    state = state.copyWith(positionMs: p);
    _completed = false;
    _clipStartMs = null;
    _follow(p, force: true);
    try {
      await player.seek(p);
    } catch (_) {
      await _fail();
    }
  }

  /// Switches to the next playback speed.
  Future<void> cycleSpeed() async {
    final next = nextEvidenceSpeed(state.speed);
    state = state.copyWith(speed: next);
    final player = _player;
    if (player == null || !state.playing) return;
    try {
      await player.setRate(next);
    } catch (_) {
      // Rate changes are best effort (e.g. old Android); playback goes on.
    }
  }

  /// Asks the meeting screen to show the highlighted line in the transcript.
  void showInTranscript() {
    state = state.copyWith(
      transcriptJumpSerial: state.transcriptJumpSerial + 1,
      focusSerial: state.focusSerial + 1,
    );
  }

  /// Pauses and hides the player bar (the highlight stays).
  Future<void> closePlayer() async {
    _request++;
    await _pausePlayer();
    state = state.copyWith(playerVisible: false, loading: false);
  }

  // ---------------------------------------------------------------------------

  bool _current(int request) => ref.mounted && request == _request;

  EvidenceAudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = ref.read(evidencePlayerFactoryProvider)();
    _player = player;
    _subs
      ..add(player.positionMs.listen(_onPosition, onError: (Object _) {}))
      ..add(
        player.durationChanges.listen((d) {
          if (ref.mounted && d > 0 && d != state.durationMs) {
            state = state.copyWith(durationMs: d);
          }
        }, onError: (Object _) {}),
      )
      ..add(
        player.completed.listen((_) {
          if (!ref.mounted) return;
          _completed = true;
          state = state.copyWith(
            playing: false,
            positionMs: state.durationMs ?? state.positionMs,
          );
        }, onError: (Object _) {}),
      );
    return player;
  }

  void _onPosition(int ms) {
    if (!ref.mounted || state.loading || !state.playerVisible) return;
    state = state.copyWith(positionMs: clampSeekMs(ms, state.durationMs));
    if (state.playing) _follow(ms);
  }

  /// Moves the highlight to the line heard at [positionMs]. Silences keep
  /// the previous highlight unless [force] (scrubbing) and a line is found.
  void _follow(int positionMs, {bool force = false}) {
    if (!force) {
      if (holdsEvidenceHighlight(positionMs, _clipStartMs)) return;
      _clipStartMs = null;
    }
    final seg = segmentAtPosition(_sorted, positionMs);
    if (seg == null || seg.id == state.highlightedSegmentId) return;
    state = state.copyWith(
      highlightedSegmentId: seg.id,
      highlightedSegmentIndex: seg.index,
      focusSerial: force ? state.focusSerial + 1 : null,
    );
  }

  void _jumpToTranscript(String noticeAr) {
    state = state.copyWith(
      playerVisible: false,
      loading: false,
      playing: false,
      transcriptJumpSerial: state.transcriptJumpSerial + 1,
      focusSerial: state.focusSerial + 1,
      noticeAr: noticeAr,
      noticeSerial: state.noticeSerial + 1,
    );
  }

  void _notice(String noticeAr) {
    state = state.copyWith(
      noticeAr: noticeAr,
      noticeSerial: state.noticeSerial + 1,
    );
  }

  Future<void> _fail() async {
    _request++;
    await _release();
    if (!ref.mounted) return;
    state = state.copyWith(
      playerVisible: false,
      loading: false,
      playing: false,
    );
    _jumpToTranscript(ES.playbackFailed);
  }

  Future<void> _pausePlayer() async {
    final player = _player;
    if (player == null || !state.playing) return;
    try {
      await player.pause();
    } catch (_) {
      // The player is released below on the next failure.
    }
    if (ref.mounted) state = state.copyWith(playing: false);
  }

  Future<void> _release() async {
    final subs = [..._subs];
    _subs.clear();
    final player = _player;
    _player = null;
    _openPath = null;
    _completed = false;
    _clipStartMs = null;
    for (final s in subs) {
      await s.cancel();
    }
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {
        // Already released by the platform.
      }
    }
  }
}

/// Evidence playback and transcript focus, per meeting. Disposed (audio
/// stopped) when no widget of the meeting watches it any more.
final evidenceControllerProvider = NotifierProvider.autoDispose
    .family<EvidenceController, EvidenceState, String>(EvidenceController.new);
