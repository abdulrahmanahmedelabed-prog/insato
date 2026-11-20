// Session audio of a speakerphone call (any platform): the call runs on
// speaker on one phone and this device's microphone hears both the people
// in the room and the phone's loudspeaker.
//
// Capture, archive and levels are the microphone source's own. For every
// VAD segment, [fuseSegment] measures the bandwidth: a narrowband segment
// (nothing above ~4 kHz) is the telephone line, i.e. the remote side; a
// clearly wideband one is a live voice in the room; anything else stays
// unattributed (no partition: the voices alone decide, as in an ordinary
// meeting). HD-voice calls (wideband codecs) therefore mostly stay
// unattributed. Remote segments are band-limited by the telephone profile.

import 'dart:async';
import 'dart:typed_data';

import '../../audio/audio_capture_service.dart';
import '../../core/errors.dart';
import '../../core/models.dart' show SpeechSegment;
import '../../data/secure_settings.dart' show AppSettingsData;
import '../../diarization/channel_cue.dart';
import '../../session/meeting_session_controller.dart'
    show SessionAudioSource, SessionInputDeviceReporter, SessionSegmentFuser;
import 'call_session_audio.dart';
import 'phone_call_log.dart';
import 'phone_call_models.dart';
import 'telephone_profile.dart';

/// [SessionAudioSource] of [PhoneCallMode.speakerphone].
class SpeakerphoneSessionAudioSource
    implements
        SessionAudioSource,
        SessionInputDeviceReporter,
        SessionSegmentFuser,
        CallSessionAudio {
  /// Wraps the microphone source [_mic].
  SpeakerphoneSessionAudioSource({
    required this._mic,
    this.profile = TelephoneAudioProfile.standard,
    this._logStore,
    this.onTakeEnded,
  });

  final SessionAudioSource _mic;
  final PhoneCallLogStore? _logStore;

  /// Telephone audio profile.
  final TelephoneAudioProfile profile;

  /// Called once a started take has stopped (the armed call is used up).
  final void Function()? onTakeEnded;

  bool _started = false;

  final _stats = StreamController<CallLiveStats>.broadcast();
  CallLiveStats _live = const CallLiveStats();

  SessionInputDeviceReporter? get _micReporter =>
      _mic is SessionInputDeviceReporter
      ? _mic as SessionInputDeviceReporter
      : null;

  @override
  PhoneCallMode get callMode => PhoneCallMode.speakerphone;

  @override
  Stream<double> get localLevel => _mic.level;

  @override
  Stream<double> get remoteLevel => const Stream<double>.empty();

  @override
  Stream<CallLiveStats> get liveStats => _stats.stream;

  @override
  CallLiveStats get stats => _live;

  @override
  Stream<Float32List> get frames => _mic.frames;
  @override
  Stream<double> get level => _mic.level;
  @override
  Stream<AudioCaptureState> get states => _mic.states;
  @override
  Stream<AudioCaptureException> get errors => _mic.errors;
  @override
  Duration get elapsed => _mic.elapsed;

  @override
  String? get activeDeviceKey => _micReporter?.activeDeviceKey;

  @override
  Stream<String?> get activeDeviceChanges =>
      _micReporter?.activeDeviceChanges ?? const Stream<String?>.empty();

  @override
  String get activeAudioSource => AppSettingsData.audioSourceMic;

  @override
  Future<bool> hasPermission({bool request = true}) =>
      _mic.hasPermission(request: request);

  @override
  Future<void> start({String? archivePath}) async {
    _live = const CallLiveStats();
    await _mic.start(archivePath: archivePath);
    _started = true;
  }

  @override
  Future<void> pause() => _mic.pause();

  @override
  Future<void> resume() => _mic.resume();

  @override
  Future<Duration> stop() async {
    try {
      return await _mic.stop();
    } finally {
      if (_started) {
        _started = false;
        onTakeEnded?.call();
      }
    }
  }

  @override
  ({SpeechSegment segment, ChannelProfile? channels}) fuseSegment(
    SpeechSegment segment,
  ) {
    final side = profile.classifyBandwidth(segment.samples);
    _live = CallLiveStats(
      localSegments: _live.localSegments + (side == CallSide.local ? 1 : 0),
      remoteSegments: _live.remoteSegments + (side == CallSide.remote ? 1 : 0),
      unattributed: _live.unattributed + (side == null ? 1 : 0),
    );
    if (!_stats.isClosed) _stats.add(_live);
    final bandLimit = side == null
        ? profile.bandLimitLocal
        : profile.bandLimits(side);
    final samples = bandLimit
        ? profile.bandLimit(segment.samples)
        : segment.samples;
    return (
      segment: identical(samples, segment.samples)
          ? segment
          : SpeechSegment(
              index: segment.index,
              startMs: segment.startMs,
              samples: samples,
            ),
      channels: side == null
          ? null
          : ChannelProfile(const {}, partition: side.partition),
    );
  }

  @override
  Future<void> finishTake({
    required String meetingId,
    required Map<String, ChannelProfile> segmentProfiles,
  }) async {
    await _logStore?.save(
      meetingId,
      callLogOf(PhoneCallMode.speakerphone, segmentProfiles, _live),
    );
  }

  /// Closes the counters stream (the microphone source belongs to its own
  /// provider).
  Future<void> dispose() => _stats.close();
}
