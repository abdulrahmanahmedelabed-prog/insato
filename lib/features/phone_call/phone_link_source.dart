// Session audio of a Phone Link call (Windows): the microphone (local side)
// and system audio (WASAPI loopback: the telephone line played by Phone
// Link, i.e. the remote side) as two separate, time-aligned channels.
//
// * The microphone is the clock: every microphone frame takes the same
//   number of loopback samples (jitter pre-roll 80 ms, latency bound 200 ms,
//   as in the F13 mixer). Both runs are appended to per-channel rings on one
//   timeline (sample index = samples handed to the session).
// * The session's VAD runs on the soft-limited sum of both channels (one
//   segmenter finds every turn of either side); the WAV archive holds the
//   same sum, so playback and evidence work as usual.
// * For every VAD segment, [fuseSegment] takes the segment's span from both
//   rings, attributes it with [attributeCallSegment] (bleed of the PC
//   speakers into the microphone suppressed) and returns the samples of
//   that side's channel only (remote: band-limited by the telephone
//   profile) with a [ChannelProfile] whose partition keeps remote and local
//   voices apart in diarization.
// * Per-channel levels drive the call card and the pre-call check.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio/audio_capture_service.dart';
import '../../audio/wav_writer.dart';
import '../../core/errors.dart';
import '../../core/models.dart' show SpeechSegment, kSampleRate;
import '../../data/secure_settings.dart' show AppSettingsData;
import '../../diarization/channel_cue.dart';
import '../../session/meeting_session_controller.dart'
    show SessionAudioSource, SessionInputDeviceReporter, SessionSegmentFuser;
import '../system_audio/system_audio_dsp.dart' show LevelMeter, mixSoftLimited;
import '../system_audio/system_audio_source.dart';
import 'call_session_audio.dart';
import 'channel_attribution.dart';
import 'phone_call_log.dart';
import 'phone_call_models.dart';
import 'strings.dart';
import 'telephone_profile.dart';

/// Fixed-capacity ring of samples addressed by absolute sample index.
class SampleRing {
  /// Creates a ring holding the last [capacity] samples.
  SampleRing(this.capacity) : _data = Float32List(capacity);

  /// Samples kept.
  final int capacity;
  final Float32List _data;
  int _end = 0;

  /// Absolute index one past the newest sample.
  int get end => _end;

  /// Absolute index of the oldest sample still held.
  int get start => math.max(0, _end - capacity);

  /// Appends [samples].
  void append(Float32List samples) {
    var from = 0;
    if (samples.length > capacity) from = samples.length - capacity;
    for (var i = from; i < samples.length; i++) {
      _data[(_end + i) % capacity] = samples[i];
    }
    _end += samples.length;
  }

  /// Samples [from] … [from] + [length] (zero-padded past [end]), or null
  /// when the start was already overwritten.
  Float32List? slice(int from, int length) {
    if (from < start || length < 0) return null;
    final out = Float32List(length);
    final avail = math.max(0, math.min(length, _end - from));
    for (var i = 0; i < avail; i++) {
      out[i] = _data[(from + i) % capacity];
    }
    return out;
  }

  /// Forgets everything.
  void clear() => _end = 0;
}

/// Opens the archive WAV of a call take.
typedef CallArchiveOpener = Future<WavWriter> Function(String path);

/// [SessionAudioSource] of [PhoneCallMode.phoneLink].
class PhoneLinkSessionAudioSource
    implements
        SessionAudioSource,
        SessionInputDeviceReporter,
        SessionSegmentFuser,
        CallSessionAudio {
  /// Creates the source over the microphone [_mic] and the loopback
  /// [_system]. [logStore] receives the call log at the end of a take.
  PhoneLinkSessionAudioSource({
    required this._mic,
    required this._system,
    this.profile = TelephoneAudioProfile.standard,
    this.attribution = const CallAttributionConfig(),
    this._logStore,
    CallArchiveOpener? openArchive,
    this.ringSeconds = 90,
    this.onTakeEnded,
  }) : _openArchive = openArchive ?? _defaultOpenArchive,
       _localRing = SampleRing(ringSeconds * kSampleRate),
       _remoteRing = SampleRing(ringSeconds * kSampleRate);

  static Future<WavWriter> _defaultOpenArchive(String path) =>
      WavWriter.open(path, sampleRate: kSampleRate, channels: 1);

  final SessionAudioSource _mic;
  final SystemAudioSource _system;
  final PhoneCallLogStore? _logStore;
  final CallArchiveOpener _openArchive;

  /// Telephone audio profile.
  final TelephoneAudioProfile profile;

  /// Attribution tuning.
  final CallAttributionConfig attribution;

  /// Seconds of both channels kept for [fuseSegment].
  final int ringSeconds;

  /// Called once a started take has stopped (the armed call is used up).
  final void Function()? onTakeEnded;

  final SampleRing _localRing;
  final SampleRing _remoteRing;
  final NoiseFloorTracker _localFloor = NoiseFloorTracker();
  final NoiseFloorTracker _remoteFloor = NoiseFloorTracker(initialDbfs: -90);

  final _frames = StreamController<Float32List>.broadcast();
  final _level = StreamController<double>.broadcast();
  final _localLevel = StreamController<double>.broadcast();
  final _remoteLevel = StreamController<double>.broadcast();
  final _states = StreamController<AudioCaptureState>.broadcast();
  final _errors = StreamController<AudioCaptureException>.broadcast();
  final _deviceKeys = StreamController<String?>.broadcast();
  final _stats = StreamController<CallLiveStats>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  final LevelMeter _meter = LevelMeter();
  final LevelMeter _localMeter = LevelMeter();
  final LevelMeter _remoteMeter = LevelMeter();

  static const int _sysTarget = kSampleRate * 80 ~/ 1000;
  static const int _sysMax = kSampleRate * 200 ~/ 1000;

  bool _sysPrimed = false;
  WavWriter? _wav;
  bool _wavFailed = false;
  bool _systemActive = false;
  bool _active = false;
  bool _disposed = false;
  int _samples = 0;
  CallLiveStats _live = const CallLiveStats();

  @override
  PhoneCallMode get callMode => PhoneCallMode.phoneLink;

  @override
  Stream<double> get localLevel => _localLevel.stream;

  @override
  Stream<double> get remoteLevel => _remoteLevel.stream;

  @override
  Stream<CallLiveStats> get liveStats => _stats.stream;

  @override
  CallLiveStats get stats => _live;

  @override
  Stream<Float32List> get frames => _frames.stream;
  @override
  Stream<double> get level => _level.stream;
  @override
  Stream<AudioCaptureState> get states => _states.stream;
  @override
  Stream<AudioCaptureException> get errors => _errors.stream;

  @override
  Duration get elapsed => Duration(
    microseconds: _samples * Duration.microsecondsPerSecond ~/ kSampleRate,
  );

  SessionInputDeviceReporter? get _micReporter =>
      _mic is SessionInputDeviceReporter
      ? _mic as SessionInputDeviceReporter
      : null;

  @override
  String? get activeDeviceKey => _micReporter?.activeDeviceKey;

  @override
  Stream<String?> get activeDeviceChanges => _deviceKeys.stream;

  @override
  String get activeAudioSource => AppSettingsData.audioSourceBoth;

  void _listen() {
    if (_subs.isNotEmpty) return;
    _subs
      ..add(_mic.frames.listen(_onMicFrames))
      ..add(_mic.states.listen(_onMicState))
      ..add(_mic.errors.listen(_addError))
      ..add(
        _system.warnings.listen((e) {
          if (_active) _addError(e);
        }),
      );
    final reporter = _micReporter;
    if (reporter != null) {
      _subs.add(
        reporter.activeDeviceChanges.listen((k) {
          if (!_deviceKeys.isClosed) _deviceKeys.add(k);
        }),
      );
    }
  }

  @override
  Future<bool> hasPermission({bool request = true}) =>
      _mic.hasPermission(request: request);

  @override
  Future<void> start({String? archivePath}) async {
    if (_disposed) throw StateError('PhoneLinkSessionAudioSource disposed');
    _listen();
    if (!await _system.isSupported()) {
      throw const AudioCaptureException(
        PCS.loopbackUnavailable,
        debugDetails: 'phone link: system audio unsupported',
      );
    }
    _samples = 0;
    _sysPrimed = false;
    _wavFailed = false;
    _localRing.clear();
    _remoteRing.clear();
    _localFloor.reset();
    _remoteFloor.reset();
    for (final m in [_meter, _localMeter, _remoteMeter]) {
      m.reset();
    }
    _live = const CallLiveStats();
    await _openWav(archivePath);
    _active = true;
    try {
      await _mic.start();
    } catch (_) {
      _active = false;
      await _closeWav();
      rethrow;
    }
    try {
      await _system.start();
      _systemActive = true;
    } on AudioCaptureException catch (e) {
      _active = false;
      try {
        await _mic.stop();
      } catch (_) {
        // Best effort.
      }
      await _closeWav();
      throw AudioCaptureException(
        PCS.loopbackStartFailed,
        debugDetails: e.debugDetails,
        cause: e,
      );
    }
  }

  @override
  Future<void> pause() async {
    await _mic.pause();
    if (_systemActive) {
      await _system.stop();
      _system.buffer.clear();
      _sysPrimed = false;
    }
  }

  @override
  Future<void> resume() async {
    if (_systemActive) {
      try {
        await _system.start();
      } on AudioCaptureException catch (e) {
        _addError(
          AudioCaptureException(
            PCS.loopbackLost,
            debugDetails: e.debugDetails,
            cause: e,
          ),
        );
      }
    }
    await _mic.resume();
  }

  @override
  Future<Duration> stop() async {
    if (!_active) return elapsed;
    try {
      await _mic.stop();
      await Future<void>.delayed(Duration.zero);
    } finally {
      _active = false;
      if (_systemActive) {
        _systemActive = false;
        await _system.stop();
      }
      await _closeWav();
      _emitLevels(0, 0, 0);
      onTakeEnded?.call();
    }
    return elapsed;
  }

  /// Stops any take and closes the streams (the microphone and loopback
  /// sources belong to their own providers).
  Future<void> dispose() async {
    if (_disposed) return;
    if (_active) {
      try {
        await stop();
      } catch (_) {
        // Best effort.
      }
    }
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final c in [
      _frames,
      _level,
      _localLevel,
      _remoteLevel,
      _states,
      _errors,
      _deviceKeys,
      _stats,
    ]) {
      await c.close();
    }
  }

  // -------------------------------------------------------------------------
  // Segments
  // -------------------------------------------------------------------------

  @override
  ({SpeechSegment segment, ChannelProfile? channels}) fuseSegment(
    SpeechSegment segment,
  ) {
    final from = segment.startMs * kSampleRate ~/ 1000;
    final n = segment.samples.length;
    final local = _localRing.slice(from, n);
    final remote = _remoteRing.slice(from, n);
    if (local == null || remote == null) {
      // Too old for the rings (a long backlog): keep the mix, no partition.
      _bump(unattributed: 1);
      return (segment: segment, channels: null);
    }
    final a = attributeCallSegment(
      local,
      remote,
      localFloorDbfs: _localFloor.floorDbfs,
      remoteFloorDbfs: _remoteFloor.floorDbfs,
      config: attribution,
    );
    final chosen = a.side == CallSide.remote ? remote : local;
    final samples = profile.bandLimits(a.side)
        ? profile.bandLimit(chosen)
        : chosen;
    _bump(
      local: a.side == CallSide.local ? 1 : 0,
      remote: a.side == CallSide.remote ? 1 : 0,
      bleed: a.bleedSuppressed ? 1 : 0,
      overlaps: a.overlap ? 1 : 0,
    );
    return (
      segment: SpeechSegment(
        index: segment.index,
        startMs: segment.startMs,
        samples: samples,
      ),
      channels: ChannelProfile({
        kCallChannelLocal: a.localSnrDb,
        kCallChannelRemote: a.remoteSnrDb,
      }, partition: a.side.partition),
    );
  }

  @override
  Future<void> finishTake({
    required String meetingId,
    required Map<String, ChannelProfile> segmentProfiles,
  }) async {
    await _logStore?.save(
      meetingId,
      callLogOf(PhoneCallMode.phoneLink, segmentProfiles, _live),
    );
  }

  void _bump({
    int local = 0,
    int remote = 0,
    int bleed = 0,
    int overlaps = 0,
    int unattributed = 0,
  }) {
    _live = CallLiveStats(
      localSegments: _live.localSegments + local,
      remoteSegments: _live.remoteSegments + remote,
      bleedSuppressed: _live.bleedSuppressed + bleed,
      overlaps: _live.overlaps + overlaps,
      unattributed: _live.unattributed + unattributed,
    );
    if (!_stats.isClosed) _stats.add(_live);
  }

  // -------------------------------------------------------------------------
  // Audio
  // -------------------------------------------------------------------------

  void _onMicFrames(Float32List frame) {
    if (!_active) return;
    final sys = _takeSystemFor(frame.length);
    final remote = sys.isEmpty ? Float32List(frame.length) : sys;
    _localRing.append(frame);
    _remoteRing.append(remote);
    _localFloor.add(frame);
    _remoteFloor.add(remote);
    final mixed = mixSoftLimited(frame, remote);
    _samples += mixed.length;
    final wav = _wav;
    if (wav != null && !_wavFailed) {
      wav.appendFloat32(mixed).catchError((Object e) {
        if (_wavFailed) return;
        _wavFailed = true;
        _addError(
          AudioCaptureException(
            PCS.archiveWriteFailed,
            debugDetails: '$e',
            cause: e,
          ),
        );
      });
    }
    if (!_frames.isClosed) _frames.add(mixed);
    final l = _localMeter.add(frame);
    final r = _remoteMeter.add(remote);
    final m = _meter.add(mixed);
    for (var i = 0; i < m.length; i++) {
      _emitLevels(m[i], i < l.length ? l[i] : null, i < r.length ? r[i] : null);
    }
  }

  Float32List _takeSystemFor(int n) {
    if (!_systemActive) return Float32List(0);
    final buf = _system.buffer;
    if (!_sysPrimed && buf.length >= _sysTarget + n) _sysPrimed = true;
    if (!_sysPrimed) return Float32List(0);
    if (buf.length < n) {
      _sysPrimed = false;
      return Float32List(0);
    }
    if (buf.length > _sysMax + n) buf.take(buf.length - _sysTarget - n);
    return buf.take(n);
  }

  void _onMicState(AudioCaptureState s) {
    if (!_states.isClosed) _states.add(s);
    if (s != AudioCaptureState.recording) {
      for (final m in [_meter, _localMeter, _remoteMeter]) {
        m.reset();
      }
      _emitLevels(0, 0, 0);
    }
  }

  void _emitLevels(double mixed, double? local, double? remote) {
    if (!_level.isClosed) _level.add(mixed);
    if (local != null && !_localLevel.isClosed) _localLevel.add(local);
    if (remote != null && !_remoteLevel.isClosed) _remoteLevel.add(remote);
  }

  Future<void> _openWav(String? path) async {
    _wav = null;
    if (path == null) return;
    try {
      _wav = await _openArchive(path);
    } catch (e) {
      throw AudioCaptureException(
        PCS.archiveFailed,
        debugDetails: '$e',
        cause: e,
      );
    }
  }

  Future<void> _closeWav() async {
    final wav = _wav;
    _wav = null;
    if (wav == null) return;
    try {
      await wav.close();
    } catch (e) {
      if (!_wavFailed) {
        _wavFailed = true;
        _addError(
          AudioCaptureException(
            PCS.archiveWriteFailed,
            debugDetails: '$e',
            cause: e,
          ),
        );
      }
    }
  }

  void _addError(AudioCaptureException e) {
    if (!_errors.isClosed) _errors.add(e);
  }
}
