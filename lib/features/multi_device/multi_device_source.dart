// Session audio of a multi-device meeting (v1.2 C): the host's own source
// (microphone / system audio, as configured) plus every guest's stream,
// fused by [FusionEngine].
//
// * frames: the fused stream for the VAD, [FusionConfig.latencySamples]
//   behind the host capture (guest audio needs that long to arrive); the
//   remainder is flushed on stop, so the take keeps its full length.
// * archive: the fused stream (re-processing from audio uses it).
// * [fuseSegment]: the device with the best SNR transcribes each segment.
// * [finishTake]: stores the device log ([MultiDeviceMeetingLog]).
// * pause / resume / stop are forwarded to the guests through the hub.
//
// With no guest the output equals the host source sample for sample.

import 'dart:async';
import 'dart:typed_data';

import '../../audio/audio_capture_service.dart';
import '../../audio/wav_writer.dart';
import '../../core/errors.dart';
import '../../core/models.dart';
import '../../diarization/channel_cue.dart';
import '../../session/meeting_session_controller.dart'
    show SessionAudioSource, SessionInputDeviceReporter, SessionSegmentFuser;
import 'fusion_engine.dart';
import 'host_server.dart';
import 'hub.dart';
import 'meeting_log.dart';
import 'protocol.dart';

/// Opens the archive WAV of a take.
typedef FusedArchiveOpener = Future<WavWriter> Function(String path);

/// See the file header.
class MultiDeviceSessionAudioSource
    implements
        SessionAudioSource,
        SessionInputDeviceReporter,
        SessionSegmentFuser {
  /// Creates the source over [local] (the host's normal source) and [hub].
  MultiDeviceSessionAudioSource({
    required this.local,
    required this.hub,
    required this.logStore,
    this.config = const FusionConfig(),
    FusedArchiveOpener? openArchive,
  }) : _openArchive = openArchive ?? _defaultOpenArchive;

  static Future<WavWriter> _defaultOpenArchive(String path) =>
      WavWriter.open(path, sampleRate: kSampleRate, channels: 1);

  /// The host's own audio source.
  final SessionAudioSource local;

  /// Guests.
  final MultiDeviceHub hub;

  /// Where [finishTake] stores the device log.
  final MultiDeviceLogStore logStore;

  /// Fusion tuning.
  final FusionConfig config;

  final FusedArchiveOpener _openArchive;
  final _frames = StreamController<Float32List>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  FusionEngine? _engine;
  WavWriter? _wav;
  bool _wavFailed = false;
  bool _running = false;
  bool _disposed = false;

  /// Engine of the running (or last) take.
  FusionEngine? get engine => _engine;

  SessionInputDeviceReporter? get _reporter =>
      local is SessionInputDeviceReporter
      ? local as SessionInputDeviceReporter
      : null;

  @override
  Stream<Float32List> get frames => _frames.stream;
  @override
  Stream<double> get level => local.level;
  @override
  Stream<AudioCaptureState> get states => local.states;
  @override
  Stream<AudioCaptureException> get errors => local.errors;
  @override
  Duration get elapsed => local.elapsed;

  @override
  String? get activeDeviceKey => _reporter?.activeDeviceKey;
  @override
  Stream<String?> get activeDeviceChanges =>
      _reporter?.activeDeviceChanges ?? const Stream<String?>.empty();
  @override
  String get activeAudioSource => _reporter?.activeAudioSource ?? 'mic';

  @override
  Future<bool> hasPermission({bool request = true}) =>
      local.hasPermission(request: request);

  @override
  Future<void> start({String? archivePath}) async {
    if (_disposed) throw StateError('MultiDeviceSessionAudioSource disposed');
    final engine = _engine = FusionEngine(config: config, clockOf: hub.clockOf);
    for (final id in hub.connectedIds) {
      engine.guestConnected(id);
    }
    _wavFailed = false;
    if (archivePath != null) _wav = await _openArchive(archivePath);
    _subs
      ..add(local.frames.listen(_onHostFrame))
      ..add(hub.events.listen(_onGuestEvent));
    _running = true;
    try {
      await local.start();
    } catch (_) {
      _running = false;
      await _cancelSubs();
      await _closeWav();
      rethrow;
    }
    hub.setRecordingState(HostState.recording);
  }

  @override
  Future<void> pause() async {
    await local.pause();
    _engine?.pause();
    hub.setRecordingState(HostState.paused);
  }

  @override
  Future<void> resume() async {
    hub.setRecordingState(HostState.recording);
    _engine?.resume(hub.nowUs());
    await local.resume();
  }

  @override
  Future<Duration> stop() async {
    if (!_running) return local.elapsed;
    Duration d;
    try {
      d = await local.stop();
      // Let the host's last frames reach the engine.
      await Future<void>.delayed(Duration.zero);
    } finally {
      _running = false;
      final engine = _engine;
      if (engine != null) {
        for (final f in engine.flush()) {
          _emit(f);
        }
      }
      await _cancelSubs();
      await _closeWav();
      hub.setRecordingState(HostState.ended);
    }
    return d;
  }

  @override
  ({SpeechSegment segment, ChannelProfile? channels}) fuseSegment(
    SpeechSegment segment,
  ) {
    final engine = _engine;
    if (engine == null) return (segment: segment, channels: null);
    final f = engine.fuseSegment(segment);
    _reportFusion();
    return (segment: f.segment, channels: f.profile);
  }

  @override
  Future<void> finishTake({
    required String meetingId,
    required Map<String, ChannelProfile> segmentProfiles,
  }) async {
    final engine = _engine;
    if (engine == null) return;
    final known = hub.knownGuests;
    final ids = {...engine.guestIds, ...known.keys};
    if (ids.isEmpty && segmentProfiles.isEmpty) return;
    final log = MultiDeviceMeetingLog(
      devices: [
        for (final id in ids)
          LoggedDevice(
            id: id,
            name: known[id]?.name ?? '',
            platform: known[id]?.platform ?? '',
            segmentsChosen: engine.statsOf(id)?.segmentsChosen ?? 0,
            framesLost: engine.statsOf(id)?.framesLost ?? 0,
            framesLate: engine.statsOf(id)?.framesLate ?? 0,
          ),
      ],
      events: engine.events,
      segmentProfiles: segmentProfiles,
    );
    await logStore.save(meetingId, log);
  }

  /// Stops any take and releases the stream (the local source and the hub
  /// are owned elsewhere).
  Future<void> dispose() async {
    if (_disposed) return;
    if (_running) {
      try {
        await stop();
      } catch (_) {
        // Best effort on teardown.
      }
    }
    _disposed = true;
    await _cancelSubs();
    await _frames.close();
  }

  // -------------------------------------------------------------------------

  void _onHostFrame(Float32List f) {
    final engine = _engine;
    if (!_running || engine == null) return;
    for (final out in engine.addHostFrame(f, hub.nowUs())) {
      _emit(out);
    }
  }

  void _onGuestEvent(HostEvent e) {
    final engine = _engine;
    if (engine == null) return;
    switch (e) {
      case GuestAudio(:final guestId, :final frame, :final arrivalUs):
        if (_running) engine.addGuestFrame(guestId, frame, arrivalUs);
      case GuestConnected(:final guestId):
        // The server tells a guest that joins (or returns) mid-meeting the
        // current state, so it starts streaming right away.
        engine.guestConnected(guestId);
      case GuestDisconnected(:final guestId, :final removed):
        engine.guestDisconnected(guestId, removed: removed);
      case GuestClock() || GuestStatusReport():
        break;
    }
  }

  void _reportFusion() {
    final engine = _engine;
    if (engine == null) return;
    for (final id in engine.guestIds) {
      final st = engine.statsOf(id)!;
      final a = engine.alignmentOf(id)!;
      hub.reportFusion(
        id,
        alignment: a.state,
        residualMs: a.lastResidualMs,
        lateRate: st.framesReceived == 0
            ? 0
            : st.framesLate / st.framesReceived,
      );
    }
  }

  void _emit(Float32List f) {
    if (_frames.isClosed) return;
    _frames.add(f);
    final wav = _wav;
    if (wav != null && !_wavFailed) {
      unawaited(
        wav.appendFloat32(f).catchError((Object _) {
          _wavFailed = true;
        }),
      );
    }
  }

  Future<void> _closeWav() async {
    final wav = _wav;
    _wav = null;
    if (wav == null) return;
    try {
      await wav.close();
    } catch (_) {
      // The archive keeps what was written.
    }
  }

  Future<void> _cancelSubs() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}
