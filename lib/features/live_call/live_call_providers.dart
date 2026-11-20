// Live Insato call (v1.2): Riverpod wiring — the call controller that ties
// the call engine (WebRTC + signaling), the local transcription and the
// meeting together.
//
// Lifecycle of one call on either device:
//   start / join (consent notice acknowledged, relay configured, microphone
//   allowed, speech models ready) → engine.start()
//   → active: ongoing notification + wakelock, meeting created
//     («مكالمة مع <peer>»), local capture + transcription, remote lines
//     stored as they arrive, call log «start»
//   → hang-up (either side, the notification button, or a lost link)
//     → capture stopped, remaining speech transcribed, remote times
//       corrected with the final clock estimate, rows ordered by time, call
//       log «stop», speaker refinement, minutes with the selected engine.

import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart' show AudioRecorder, AndroidAudioSource;

import '../../audio/audio_capture_service.dart';
import '../../core/errors.dart';
import '../../core/models.dart';
import '../../data/secure_settings.dart';
import '../../diarization/speaker_tracker.dart';
import '../../diarization/vector_math.dart' show isUsableEmbedding;
import '../../session/meeting_session_controller.dart';
import '../../session/providers.dart';
import '../multi_device/multi_device_providers.dart'
    show currentPlatformId, defaultDeviceName;
import '../voice/voice_devices.dart' show knownSpeakerThresholdFor;
import 'call_code.dart';
import 'call_engine.dart';
import 'call_log.dart';
import 'call_meeting_writer.dart';
import 'call_platform.dart';
import 'call_settings.dart';
import 'call_transcriber.dart';
import 'peer_transport.dart';
import 'signaling_client.dart' show RelayConnector;
import 'strings.dart';
import 'transcript_merge.dart';
import 'webrtc_peer_transport.dart';

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// The live-call consent notice has not been acknowledged yet.
class CallConsentRequiredException extends InsatoException {
  /// Creates the exception.
  const CallConsentRequiredException() : super(LCS.consentRequired);
}

/// No signaling relay is configured.
class CallNotConfiguredException extends InsatoException {
  /// Creates the exception.
  const CallNotConfiguredException() : super(LCS.notConfigured);
}

/// A recording or another call is running.
class CallBusyException extends InsatoException {
  /// Creates the exception.
  const CallBusyException() : super(LCS.busy);
}

// ---------------------------------------------------------------------------
// Seams (overridden in tests)
// ---------------------------------------------------------------------------

/// Capture options during a call: Android's voice-communication source
/// (platform echo cancellation, so the remote voice coming out of the
/// loudspeaker is mostly removed from what we transcribe).
const AudioCaptureOptions kCallCaptureOptions = AudioCaptureOptions(
  androidAudioSource: AndroidAudioSource.voiceCommunication,
);

AudioRecorder _callRecorder() {
  final r = AudioRecorder();
  // iOS: WebRTC owns the audio session (playAndRecord / voiceChat); the
  // recorder must not reconfigure or deactivate it.
  if (!kIsWeb && Platform.isIOS) {
    unawaited(r.ios?.manageAudioSession(false).catchError((Object _) {}));
  }
  return r;
}

/// Microphone of the local transcription during a call.
final liveCallAudioSourceProvider = Provider<SessionAudioSource>((ref) {
  final service = AudioCaptureService(
    options: kCallCaptureOptions,
    recorderFactory: _callRecorder,
  );
  ref.onDispose(service.dispose);
  return AudioCaptureSessionSource(service);
});

/// WebRTC transport factory.
final peerTransportFactoryProvider = Provider<PeerTransportFactory>(
  (ref) => webRtcPeerTransportFactory,
);

/// Relay connector (null: dart:io WebSocket).
final relayConnectorProvider = Provider<RelayConnector?>((ref) => null);

/// PBKDF2 iterations override (tests only; null = production).
final callKdfIterationsProvider = Provider<int?>((ref) => null);

/// Call timeouts.
final callTimeoutsProvider = Provider<CallTimeouts>(
  (ref) => const CallTimeouts(),
);

/// This device's name for calls.
final callDeviceNameProvider = Provider<String Function()>(
  (ref) => defaultDeviceName,
);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// State of the live-call feature.
class LiveCallState {
  /// Creates a state.
  const LiveCallState({
    this.call,
    this.meetingId,
    this.saving = false,
    this.savedMeetingId,
    this.warningAr,
    this.level = 0,
  });

  /// The current (or last) call; null before any.
  final CallSnapshot? call;

  /// Meeting of the call (once streaming started).
  final String? meetingId;

  /// Saving the meeting after the call.
  final bool saving;

  /// Meeting saved after the call ended.
  final String? savedMeetingId;

  /// Warning (background service, transcription unavailable, …).
  final String? warningAr;

  /// Local microphone level 0..1.
  final double level;

  /// True while a call is being set up or running.
  bool get isBusy => call != null && !call!.phase.isOver;

  /// Copy with changes.
  LiveCallState copyWith({
    CallSnapshot? call,
    String? meetingId,
    bool? saving,
    String? savedMeetingId,
    String? warningAr,
    double? level,
  }) => LiveCallState(
    call: call ?? this.call,
    meetingId: meetingId ?? this.meetingId,
    saving: saving ?? this.saving,
    savedMeetingId: savedMeetingId ?? this.savedMeetingId,
    warningAr: warningAr ?? this.warningAr,
    level: level ?? this.level,
  );
}

class _Streaming implements CallTranscriberListener {
  _Streaming(this.engine);
  final LiveCallEngine engine;
  CallTranscriber? transcriber;
  CallMeetingWriter? writer;
  String? meetingId;
  String? archivePath;
  int baseUs = 0;
  LiveCallLog? log;
  StreamSubscription<CallTranscriptEvent>? transcriptSub;

  /// Our lines found to be echoes (deleted again after the transcription
  /// drained, in case a row was still being written when retracted).
  final Set<String> retracted = {};
  void Function(double level)? onLevel;

  int get captureStartUs => transcriber?.captureStartUs ?? baseUs;

  Future<void> cancelTranscript() async {
    await transcriptSub?.cancel();
    transcriptSub = null;
  }

  @override
  void onPending(String id, int atUs, int durMs) =>
      engine.localPending(id, atUs, durMs);

  @override
  bool onFinal(LiveLine line) => engine.localFinal(line);

  @override
  void onDropped(String id) => engine.localDropped(id);

  @override
  void onActivity({required bool speaking, required double level}) {
    engine.localActivity(speaking: speaking, level: level);
    onLevel?.call(level);
  }
}

/// The live-call controller.
class LiveCallController extends Notifier<LiveCallState> {
  LiveCallEngine? _engine;
  StreamSubscription<CallSnapshot>? _sub;
  _Streaming? _streaming;
  Future<void>? _starting;
  Future<void>? _finishing;
  CallPhase? _lastPhase;

  @override
  LiveCallState build() {
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      unawaited(_engine?.dispose());
    });
    return const LiveCallState();
  }

  void _set(LiveCallState s) {
    if (ref.mounted) state = s;
  }

  /// Starts a call (shows the code). Throws [CallConsentRequiredException]
  /// (show the notice, then call again with [consentGiven]),
  /// [CallNotConfiguredException], [CallBusyException] or the microphone /
  /// model errors of a recording.
  Future<void> startCall({bool consentGiven = false}) =>
      _begin(CallRole.caller, newCallCode(), null, consentGiven);

  /// Joins the call of [invite].
  Future<void> joinCall(CallInvite invite, {bool consentGiven = false}) =>
      _begin(CallRole.callee, invite.code, invite.signalingUrl, consentGiven);

  Future<void> _begin(
    CallRole role,
    String code,
    String? inviteUrl,
    bool consentGiven,
  ) async {
    if (state.isBusy || ref.read(meetingSessionControllerProvider).isActive) {
      throw const CallBusyException();
    }
    final store = ref.read(liveCallSettingsStoreProvider);
    var settings = await store.load();
    if (!settings.consentAcknowledged) {
      if (!consentGiven) throw const CallConsentRequiredException();
      settings = settings.copyWith(consentAcknowledged: true);
      await store.save(settings);
    }
    final url = inviteUrl ?? settings.effectiveSignalingUrl;
    if (url == null) throw const CallNotConfiguredException();
    final audio = ref.read(liveCallAudioSourceProvider);
    await ref.read(callPlatformHooksProvider).ensureMicrophonePermission(audio);
    final app = await ref.read(appSettingsProvider).load();
    await ref
        .read(sessionEnginesFactoryProvider)
        .ensureReady(_engineRequest(app));

    final credential = await ref.read(turnCredentialStoreProvider).read();
    final name = settings.deviceName.trim().isNotEmpty
        ? settings.deviceName.trim()
        : ref.read(callDeviceNameProvider)();
    await _finishing;
    _finishing = null;
    await _sub?.cancel();
    await _engine?.dispose();
    _streaming = null;
    _lastPhase = null;
    final engine = _engine = LiveCallEngine(
      role: role,
      code: code,
      signalingUrl: url,
      localName: name,
      localPlatform: currentPlatformId(),
      peerFactory: ref.read(peerTransportFactoryProvider),
      peerConfig: peerConfigFor(settings, turnCredential: credential),
      relayConnector: ref.read(relayConnectorProvider),
      timeouts: ref.read(callTimeoutsProvider),
      kdfIterations: ref.read(callKdfIterationsProvider),
    );
    _set(LiveCallState(call: engine.snapshot));
    _sub = engine.snapshots.listen(_onSnapshot);
    await engine.start();
  }

  // Same engines as a recording (local or cloud ASR with its model and
  // notice), with short segments so text follows the call closely.
  static SessionEngineRequest _engineRequest(AppSettingsData s) =>
      SessionEngineRequest.fromSettings(
        s,
      ).withOverrides(maxSegmentSeconds: kCallMaxSegmentSeconds);

  void _onSnapshot(CallSnapshot snap) {
    final previous = _lastPhase;
    final peerWasMuted = state.call?.peerMuted ?? false;
    _lastPhase = snap.phase;
    _set(state.copyWith(call: snap));
    final st = _streaming;
    if (snap.phase == CallPhase.active && st == null && _starting == null) {
      _starting = _startStreaming().whenComplete(() => _starting = null);
    }
    if (st != null && previous != snap.phase) {
      if (snap.phase == CallPhase.reconnecting) _logEvent('reconnecting');
      if (previous == CallPhase.reconnecting && snap.phase == CallPhase.active) {
        _logEvent('reconnected');
      }
    }
    if (st != null && snap.peerMuted != peerWasMuted && !snap.phase.isOver) {
      _logEvent(snap.peerMuted ? 'mute' : 'unmute', byRemote: true);
    }
    if (snap.phase.isOver && previous != null && !previous.isOver) {
      _finishing ??= _finish(snap);
    }
  }

  Future<void> _startStreaming() async {
    final engine = _engine;
    if (engine == null) return;
    final st = _streaming = _Streaming(engine)..baseUs = engine.nowUs();
    st.onLevel = (l) {
      if ((l - state.level).abs() > 0.02) _set(state.copyWith(level: l));
    };
    final snap = engine.snapshot;
    final hooks = ref.read(callPlatformHooksProvider);
    final warning = await hooks.onStreamingStarted(
      peerName: snap.peerName,
      onStopRequested: () => unawaited(hangUp()),
    );
    if (warning != null) _set(state.copyWith(warningAr: warning));

    final meetings = ref.read(meetingRepositoryProvider);
    final speakers = ref.read(speakerRepositoryProvider);
    final segments = ref.read(segmentRepositoryProvider);
    try {
      final app = await ref.read(appSettingsProvider).load();
      final engines = await ref
          .read(sessionEnginesFactoryProvider)
          .create(_engineRequest(app));
      if (engine.snapshot.phase.isOver) {
        await engines.dispose();
        return;
      }
      final now = DateTime.now();
      final meeting = await meetings.create(
        title: LCS.meetingTitle(snap.peerName, now),
        createdAt: now,
      );
      st.meetingId = meeting.id;
      if (app.keepAudio) {
        final dir = await ref.read(appPathsProvider).recordingsDir();
        final fileName = recordingFileName(meeting.id);
        st.archivePath = p.join(dir, fileName);
        await meetings.setAudioPath(meeting.id, fileName);
      }
      final known = (await speakers.getAll())
          .where((s) => isUsableEmbedding(s.centroid))
          .toList();
      final tracker = SpeakerTracker(
        knownSpeakers: known,
        matchThreshold: app.matchThreshold,
        knownSpeakerThresholdOf: (sp) => knownSpeakerThresholdFor(
          sp,
          sessionDeviceKey: null,
          base: app.matchThreshold,
        ),
      );
      final writer = st.writer = CallMeetingWriter(
        db: ref.read(databaseProvider),
        meetingId: meeting.id,
        remoteDeviceName: snap.peerName,
        segments: segments,
        speakers: speakers,
      );
      st.transcriptSub = engine.transcriptEvents.listen((e) {
        switch (e) {
          case RemoteLineFinal(:final line):
            unawaited(writer.insertRemote(line, st.captureStartUs));
          case RemoteLineDropped(:final id):
            unawaited(writer.delete(id));
          case LocalLineRetracted(:final id):
            st.retracted.add(id);
            unawaited(writer.delete(id));
          case RemoteLinesRetimed(:final lines):
            unawaited(writer.retime(lines, st.captureStartUs));
        }
      });
      final t = st.transcriber = CallTranscriber(
        meetingId: meeting.id,
        audio: ref.read(liveCallAudioSourceProvider),
        engines: engines,
        tracker: tracker,
        speakers: speakers,
        segments: segments,
        listener: st,
        clockUs: engine.nowUs,
      );
      final log = st.log = LiveCallLog(
        role: engine.role.wire,
        localName: engine.localName,
        localPlatform: engine.localPlatform,
        remoteName: snap.peerName,
        remotePlatform: snap.peerPlatform,
        startedAt: snap.connectedAt ?? now,
        relayHost: Uri.tryParse(engine.signalingUrl)?.host ?? '',
        safetyCode: snap.safetyCode,
        events: [CallLogEvent(at: snap.connectedAt ?? now, kind: 'start')],
      );
      await ref.read(liveCallLogStoreProvider).save(meeting.id, log);
      _set(state.copyWith(meetingId: meeting.id));
      await t.start(archivePath: st.archivePath);
      if (engine.snapshot.muted) t.setMuted(true);
    } catch (e) {
      final msg = e is InsatoException ? e.messageAr : '';
      _set(state.copyWith(warningAr: LCS.transcriptionUnavailable(msg)));
    }
  }

  void _logEvent(String kind, {bool byRemote = false}) {
    final st = _streaming;
    final log = st?.log;
    final id = st?.meetingId;
    if (st == null || log == null || id == null) return;
    final next = st.log = log.withEvent(
      CallLogEvent(at: DateTime.now(), kind: kind, byRemote: byRemote),
    );
    unawaited(
      ref
          .read(liveCallLogStoreProvider)
          .save(id, next)
          .catchError((Object _) {}),
    );
  }

  /// Mutes / unmutes this device (audio to the peer and transcription).
  Future<void> setMuted(bool muted) async {
    final engine = _engine;
    if (engine == null || engine.snapshot.phase.isOver) return;
    await engine.setMuted(muted);
    _streaming?.transcriber?.setMuted(muted);
    _logEvent(muted ? 'mute' : 'unmute');
  }

  /// Ends the call (one tap, any phase).
  Future<void> hangUp() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.hangUp();
  }

  Future<void> _finish(CallSnapshot snap) async {
    await _starting;
    final st = _streaming;
    final hooks = ref.read(callPlatformHooksProvider);
    if (st == null) {
      await hooks.onStreamingStopped();
      return;
    }
    await hooks.onStreamingStopped();
    final id = st.meetingId;
    final t = st.transcriber;
    final writer = st.writer;
    if (id == null || t == null || writer == null) return;
    _set(state.copyWith(saving: true, level: 0));
    final meetings = ref.read(meetingRepositoryProvider);
    try {
      final duration = await t.stop();
      await st.cancelTranscript();
      for (final id in st.retracted) {
        await writer.delete(id);
      }
      final fixed = st.engine.fixProvisionalNow();
      if (fixed.isNotEmpty) await writer.retime(fixed, st.captureStartUs);
      await writer.finalizeOrder();
      await meetings.setDuration(id, duration.inMilliseconds);
      final archive = st.archivePath;
      if (archive != null && !await File(archive).exists()) {
        await meetings.setAudioPath(id, null);
      }
      final log = st.log;
      if (log != null) {
        await ref.read(liveCallLogStoreProvider).save(
          id,
          log
              .copyWith(
                endedAt: snap.endedAt ?? DateTime.now(),
                endReason: snap.endReason?.name,
                relayed: snap.stats?.relayed,
                safetyCode: snap.safetyCode,
              )
              .withEvent(
                CallLogEvent(
                  at: snap.endedAt ?? DateTime.now(),
                  kind: 'stop',
                  byRemote: snap.endReason == CallEndReason.remoteHangUp,
                ),
              ),
        );
      }
      await meetings.updateStatus(id, MeetingStatus.processing);
      final post = ref.read(postProcessorProvider);
      try {
        await post.refine(
          id,
          sessionCreatedSpeakerIds: t.pipeline.createdSpeakerIds,
        );
      } catch (_) {
        // The live labels stay valid.
      }
      _set(state.copyWith(saving: false, savedMeetingId: id));
      unawaited(
        ref
            .read(meetingJobsProvider(id).notifier)
            .generateMinutes(automatic: true)
            .then((_) {}, onError: (Object _) {}),
      );
    } catch (e) {
      await meetings
          .setError(id, LCS.saveFailed)
          .then((_) {}, onError: (Object _) {});
      _set(
        state.copyWith(
          saving: false,
          savedMeetingId: id,
          warningAr: LCS.saveFailed,
        ),
      );
    }
  }

  /// Forgets the ended call (back to the start screen).
  Future<void> reset() async {
    if (state.isBusy) return;
    await _finishing;
    _finishing = null;
    await _sub?.cancel();
    _sub = null;
    await _engine?.dispose();
    _engine = null;
    _streaming = null;
    _set(const LiveCallState());
  }

  /// The running engine (tests).
  LiveCallEngine? get engine => _engine;

  /// Completes when the post-call saving is done (tests).
  Future<void> get finished async {
    await _starting;
    await _finishing;
  }
}

/// The live-call controller.
final liveCallControllerProvider =
    NotifierProvider<LiveCallController, LiveCallState>(
      LiveCallController.new,
    );
