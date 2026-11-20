// Live Insato call (v1.2): the call state machine.
//
//   caller                                         callee
//   start(): keys(code) → relay join               join(): keys(code) → relay join
//   waitingForPeer (code / QR on screen)           connecting (looking for the call)
//            ◄──────── sealed hello / welcome / ready ────────►
//   connecting: open mic + peer, offer ─────────► answer
//            ◄──────────── trickle ICE (sealed) ─────────────►
//            ◄═══════ DTLS-SRTP audio + data channel (P2P / TURN) ═══════►
//   data channel open → auth (fingerprint MACs) both ways → active
//   active: ping/pong clock sync (1 Hz), stats (every 3 s), live lines
//   link lost → reconnecting (ICE may recover) → active | ended
//   hangUp() / bye / failure → ended / failed
//
// The engine never starts by itself: a person starts a call or joins one
// (the UI enforces the consent notice first). It has no knowledge of the
// microphone transcription; the session layer feeds local lines in
// ([localPending], [localFinal], …) and reads remote ones from
// [transcriptEvents].
//
// Pure Dart (WebRTC and the relay are behind [PeerTransport] and
// [RelaySocket]).

import 'dart:async';

import '../multi_device/clock_sync.dart'
    show ClockSample, ClockSyncEstimator, MonotonicClock;
import 'call_code.dart';
import 'data_messages.dart';
import 'peer_transport.dart';
import 'signaling_client.dart';
import 'signaling_protocol.dart';
import 'transcript_merge.dart';

export 'signaling_client.dart' show CallRole;

/// Phase of a call.
enum CallPhase {
  /// Not started.
  idle,

  /// Deriving keys, reaching the relay.
  preparing,

  /// Caller: waiting for someone to join with the code.
  waitingForPeer,

  /// Authenticating and establishing the peer-to-peer link.
  connecting,

  /// Audio and live transcript flow.
  active,

  /// The link dropped; waiting for ICE to recover.
  reconnecting,

  /// Ended normally (one side hung up).
  ended,

  /// Ended by an error.
  failed;

  /// True once the call is over.
  bool get isOver => this == ended || this == failed;

  /// True while microphone audio may be streamed.
  bool get isStreaming => this == active || this == reconnecting;
}

/// Why a call ended.
enum CallEndReason {
  /// We hung up.
  localHangUp,

  /// The other side hung up.
  remoteHangUp,

  /// The link was lost and did not recover.
  networkLost,

  /// No direct (or TURN) path could be established.
  connectFailed,

  /// The other side could not prove the code / certificate.
  securityFailure,

  /// The signaling server is unreachable or not configured.
  relayUnavailable,

  /// Two devices are already in this call.
  callFull,

  /// Nobody answered with this code.
  notFound,

  /// Microphone or WebRTC error on this device.
  deviceError,
}

/// Link quality shown on screen.
enum CallQuality {
  /// Not measured yet.
  unknown,

  /// Round trip < 250 ms and loss < 3 %.
  good,

  /// Round trip < 600 ms and loss < 10 %.
  fair,

  /// Worse.
  poor,
}

/// Quality class of a measurement.
CallQuality qualityOf(LinkStats? s) {
  final rtt = s?.rttMs;
  final loss = s?.packetLossPercent ?? 0;
  if (s == null || rtt == null) return CallQuality.unknown;
  if (rtt < 250 && loss < 3) return CallQuality.good;
  if (rtt < 600 && loss < 10) return CallQuality.fair;
  return CallQuality.poor;
}

/// Timeouts of a call (shortened in tests).
class CallTimeouts {
  /// Creates timeouts.
  const CallTimeouts({
    this.callerWait = const Duration(minutes: 30),
    this.calleeFind = const Duration(seconds: 45),
    this.handshake = const Duration(seconds: 25),
    this.media = const Duration(seconds: 45),
    this.auth = const Duration(seconds: 15),
    this.reconnect = const Duration(seconds: 25),
    this.pingInterval = const Duration(seconds: 1),
    this.statsInterval = const Duration(seconds: 3),
  });

  /// Caller gives up waiting for a joiner.
  final Duration callerWait;

  /// Callee gives up when the caller is not in the room.
  final Duration calleeFind;

  /// Peer present but the handshake does not complete (wrong code).
  final Duration handshake;

  /// Authenticated but no media path.
  final Duration media;

  /// Data channel open but no valid `auth`.
  final Duration auth;

  /// Link lost during the call.
  final Duration reconnect;

  /// Clock-sync ping period.
  final Duration pingInterval;

  /// Statistics period.
  final Duration statsInterval;
}

/// Immutable view of the call for the UI.
class CallSnapshot {
  /// Creates a snapshot.
  const CallSnapshot({
    required this.phase,
    required this.role,
    this.invite,
    this.peerName = '',
    this.peerPlatform = '',
    this.safetyCode,
    this.muted = false,
    this.peerMuted = false,
    this.localSpeaking = false,
    this.remoteSpeaking = false,
    this.remoteLevel = 0,
    this.stats,
    this.quality = CallQuality.unknown,
    this.connectedAt,
    this.endedAt,
    this.endReason,
    this.lines = const [],
    this.clockSynced = false,
  });

  /// Phase.
  final CallPhase phase;

  /// Our role.
  final CallRole role;

  /// The invite (code, relay URL) — shown by the caller.
  final CallInvite? invite;

  /// Authenticated peer name ('' before).
  final String peerName;

  /// Peer platform id.
  final String peerPlatform;

  /// Six-digit safety code (same on both screens).
  final String? safetyCode;

  /// Our microphone is muted.
  final bool muted;

  /// The peer's microphone is muted.
  final bool peerMuted;

  /// Speech detected on our side right now.
  final bool localSpeaking;

  /// Speech detected on the peer's side right now.
  final bool remoteSpeaking;

  /// Peer microphone level 0..1.
  final double remoteLevel;

  /// Latest link statistics.
  final LinkStats? stats;

  /// Quality class.
  final CallQuality quality;

  /// When the call became active.
  final DateTime? connectedAt;

  /// When it ended.
  final DateTime? endedAt;

  /// Why it ended.
  final CallEndReason? endReason;

  /// Combined live transcript, ordered by time on this device.
  final List<LiveLine> lines;

  /// True once the clocks are synchronised.
  final bool clockSynced;

  /// Copy with changes.
  CallSnapshot copyWith({
    CallPhase? phase,
    CallInvite? invite,
    String? peerName,
    String? peerPlatform,
    String? safetyCode,
    bool? muted,
    bool? peerMuted,
    bool? localSpeaking,
    bool? remoteSpeaking,
    double? remoteLevel,
    LinkStats? stats,
    CallQuality? quality,
    DateTime? connectedAt,
    DateTime? endedAt,
    CallEndReason? endReason,
    List<LiveLine>? lines,
    bool? clockSynced,
  }) => CallSnapshot(
    phase: phase ?? this.phase,
    role: role,
    invite: invite ?? this.invite,
    peerName: peerName ?? this.peerName,
    peerPlatform: peerPlatform ?? this.peerPlatform,
    safetyCode: safetyCode ?? this.safetyCode,
    muted: muted ?? this.muted,
    peerMuted: peerMuted ?? this.peerMuted,
    localSpeaking: localSpeaking ?? this.localSpeaking,
    remoteSpeaking: remoteSpeaking ?? this.remoteSpeaking,
    remoteLevel: remoteLevel ?? this.remoteLevel,
    stats: stats ?? this.stats,
    quality: quality ?? this.quality,
    connectedAt: connectedAt ?? this.connectedAt,
    endedAt: endedAt ?? this.endedAt,
    endReason: endReason ?? this.endReason,
    lines: lines ?? this.lines,
    clockSynced: clockSynced ?? this.clockSynced,
  );
}

/// Transcript changes the session layer persists.
sealed class CallTranscriptEvent {
  const CallTranscriptEvent();
}

/// A final remote line (store it).
class RemoteLineFinal extends CallTranscriptEvent {
  /// Creates the event.
  const RemoteLineFinal(this.line);

  /// The line (time on this device).
  final LiveLine line;
}

/// The peer retracted one of its lines (delete it).
class RemoteLineDropped extends CallTranscriptEvent {
  /// Creates the event.
  const RemoteLineDropped(this.id);

  /// Remote line id.
  final String id;
}

/// One of our stored lines turned out to be an echo of the peer (delete).
class LocalLineRetracted extends CallTranscriptEvent {
  /// Creates the event.
  const LocalLineRetracted(this.id);

  /// Local line id.
  final String id;
}

/// Remote lines whose provisional time was corrected (update them).
class RemoteLinesRetimed extends CallTranscriptEvent {
  /// Creates the event.
  const RemoteLinesRetimed(this.lines);

  /// Corrected lines.
  final List<LiveLine> lines;
}

/// One live call.
class LiveCallEngine {
  /// Creates the engine of [role] for [code] over the relay at
  /// [signalingUrl].
  LiveCallEngine({
    required this.role,
    required this.code,
    required this.signalingUrl,
    required this.localName,
    required this.localPlatform,
    required this.peerFactory,
    this.peerConfig = const PeerConfig(),
    this.relayConnector,
    this.timeouts = const CallTimeouts(),
    this.kdfIterations,
    int Function()? clockUs,
    DateTime Function()? now,
  }) : _clockUs = clockUs ?? MonotonicClock.instance.nowUs,
       _now = now ?? DateTime.now,
       _snapshot = CallSnapshot(
         phase: CallPhase.idle,
         role: role,
         invite: role == CallRole.caller
             ? CallInvite(
                 code: code,
                 signalingUrl: signalingUrl,
                 callerName: localName,
               )
             : null,
       );

  /// Our role.
  final CallRole role;

  /// Normalised call code.
  final String code;

  /// Relay URL.
  final String signalingUrl;

  /// Our device name.
  final String localName;

  /// Our platform id.
  final String localPlatform;

  /// Builds the WebRTC transport.
  final PeerTransportFactory peerFactory;

  /// STUN / TURN configuration.
  final PeerConfig peerConfig;

  /// Relay socket connector (null: dart:io WebSocket).
  final RelayConnector? relayConnector;

  /// Timeouts.
  final CallTimeouts timeouts;

  /// PBKDF2 iterations override (tests).
  final int? kdfIterations;

  final int Function() _clockUs;
  final DateTime Function() _now;

  final StreamController<CallSnapshot> _snapshots =
      StreamController<CallSnapshot>.broadcast();
  final StreamController<CallTranscriptEvent> _transcript =
      StreamController<CallTranscriptEvent>.broadcast();
  CallSnapshot _snapshot;
  CallKeys? _keys;
  CallSignaling? _signaling;
  PeerTransport? _peer;
  final List<StreamSubscription<Object?>> _subs = [];
  final List<IceCandidateData> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;
  String? _localSdp;
  String? _remoteSdp;
  bool _authSent = false;
  bool _peerAuthed = false;
  AuthMessage? _earlyAuth;
  Timer? _phaseTimer;
  Timer? _pingTimer;
  Timer? _statsTimer;
  Future<void> _queue = Future<void>.value();
  final ClockSyncEstimator _clock = ClockSyncEstimator();
  final LiveTranscriptBook _book = LiveTranscriptBook();
  int _lastActivityUs = -1 << 62;
  bool _lastActivitySpeaking = false;

  /// Current snapshot.
  CallSnapshot get snapshot => _snapshot;

  /// Snapshot changes (broadcast).
  Stream<CallSnapshot> get snapshots => _snapshots.stream;

  /// Transcript changes to persist (broadcast).
  Stream<CallTranscriptEvent> get transcriptEvents => _transcript.stream;

  /// Clock-sync estimate (peer − this clock).
  ClockSyncEstimator get clockSync => _clock;

  /// This device's monotonic clock (µs).
  int nowUs() => _clockUs();

  void _set(CallSnapshot s) {
    _snapshot = s;
    if (!_snapshots.isClosed) _snapshots.add(s);
  }

  void _setLines() => _set(_snapshot.copyWith(lines: _book.lines));

  /// Runs [f] after every earlier queued step (events are handled one at a
  /// time, in order, even when a step awaits WebRTC).
  void _enqueue(Future<void> Function() f) {
    _queue = _queue.then((_) async {
      if (_snapshot.phase.isOver) return;
      try {
        await f();
      } catch (_) {
        if (!_snapshot.phase.isOver) {
          await _finish(
            _snapshot.phase.isStreaming
                ? CallEndReason.networkLost
                : CallEndReason.deviceError,
          );
        }
      }
    });
  }

  // -------------------------------------------------------------------------
  // Start / stop
  // -------------------------------------------------------------------------

  /// Starts (caller) or joins (callee) the call. Completes once the relay
  /// is joined; afterwards follow [snapshots]. Never throws: failures end
  /// the call with a reason.
  Future<void> start() async {
    if (_snapshot.phase != CallPhase.idle) return;
    _set(_snapshot.copyWith(phase: CallPhase.preparing));
    try {
      final iterations = kdfIterations;
      _keys = iterations == null
          ? await deriveCallKeys(code)
          : await deriveCallKeys(code, iterations: iterations);
      final sig = _signaling = CallSignaling(
        role: role,
        keys: _keys!,
        localName: localName,
        localPlatform: localPlatform,
      );
      _subs.add(sig.events.listen((e) => _enqueue(() => _onSignaling(e))));
      await sig.connect(signalingUrl, connector: relayConnector);
    } catch (_) {
      await _finish(CallEndReason.relayUnavailable);
      return;
    }
    if (_snapshot.phase.isOver) return;
    if (role == CallRole.caller) {
      _set(_snapshot.copyWith(phase: CallPhase.waitingForPeer));
      _arm(timeouts.callerWait, CallEndReason.notFound);
    } else {
      _set(_snapshot.copyWith(phase: CallPhase.connecting));
      _arm(timeouts.calleeFind, CallEndReason.notFound);
    }
  }

  /// Hangs up (one tap, any phase). Idempotent.
  Future<void> hangUp() async {
    if (_snapshot.phase.isOver) return;
    try {
      await _peer?.sendData(const ByeMessage('hangup').encode());
    } catch (_) {}
    _signaling?.sendBye();
    await _finish(CallEndReason.localHangUp);
  }

  /// Mutes / unmutes our outgoing audio.
  Future<void> setMuted(bool muted) async {
    if (_snapshot.phase.isOver) return;
    _set(_snapshot.copyWith(muted: muted));
    try {
      await _peer?.setMuted(muted);
    } catch (_) {}
    await _send(MuteMessage(muted));
  }

  void _arm(Duration d, CallEndReason reason) {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(d, () => _enqueue(() => _finish(reason)));
  }

  Future<void> _finish(CallEndReason reason) async {
    if (_snapshot.phase.isOver) return;
    _phaseTimer?.cancel();
    _pingTimer?.cancel();
    _statsTimer?.cancel();
    final failure = switch (reason) {
      CallEndReason.localHangUp || CallEndReason.remoteHangUp => false,
      // A link lost after a real conversation is a normal end.
      CallEndReason.networkLost => _snapshot.connectedAt == null,
      _ => true,
    };
    _set(
      _snapshot.copyWith(
        phase: failure ? CallPhase.failed : CallPhase.ended,
        endReason: reason,
        endedAt: _now(),
        localSpeaking: false,
        remoteSpeaking: false,
      ),
    );
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final peer = _peer;
    _peer = null;
    final sig = _signaling;
    _signaling = null;
    try {
      await peer?.close();
    } catch (_) {}
    try {
      await sig?.close();
    } catch (_) {}
  }

  /// Releases the streams (after the call ended).
  Future<void> dispose() async {
    if (!_snapshot.phase.isOver) await hangUp();
    await _snapshots.close();
    await _transcript.close();
  }

  // -------------------------------------------------------------------------
  // Signaling
  // -------------------------------------------------------------------------

  Future<void> _onSignaling(SignalingEvent e) async {
    switch (e) {
      case SignalingJoined():
        break;
      case SignalingAuthenticated(:final peerName, :final peerPlatform):
        _set(
          _snapshot.copyWith(
            phase: CallPhase.connecting,
            peerName: peerName,
            peerPlatform: peerPlatform,
          ),
        );
        _arm(timeouts.media, CallEndReason.connectFailed);
        await _openPeer();
        if (role == CallRole.caller) {
          final offer = await _peer!.createOffer();
          _localSdp = offer;
          _signaling?.sendOffer(offer);
        }
      case SignalingOffer(:final sdp):
        final peer = _peer;
        if (role != CallRole.callee || peer == null || _remoteSdp != null) {
          return;
        }
        _remoteSdp = sdp;
        final answer = await peer.acceptOffer(sdp);
        _localSdp = answer;
        _remoteDescriptionSet = true;
        _signaling?.sendAnswer(answer);
        await _flushCandidates();
      case SignalingAnswer(:final sdp):
        final peer = _peer;
        if (role != CallRole.caller || peer == null || _remoteSdp != null) {
          return;
        }
        _remoteSdp = sdp;
        await peer.acceptAnswer(sdp);
        _remoteDescriptionSet = true;
        await _flushCandidates();
      case SignalingIce(:final candidate):
        if (_remoteDescriptionSet) {
          await _peer?.addRemoteCandidate(candidate);
        } else if (_pendingCandidates.length < 64) {
          _pendingCandidates.add(candidate);
        }
      case SignalingBye():
        await _finish(CallEndReason.remoteHangUp);
      case SignalingPeerLeft():
        if (_snapshot.phase.isStreaming) return; // P2P continues.
        if (_snapshot.phase == CallPhase.connecting && _peer != null) {
          if (role == CallRole.caller) {
            await _resetPeer();
            _set(_snapshot.copyWith(phase: CallPhase.waitingForPeer));
            _arm(timeouts.callerWait, CallEndReason.notFound);
          } else {
            await _finish(CallEndReason.connectFailed);
          }
        }
      case SignalingClosed(:final relayError):
        if (_snapshot.phase.isStreaming) return; // Relay no longer needed.
        await _finish(
          relayError == 'full'
              ? CallEndReason.callFull
              : CallEndReason.relayUnavailable,
        );
      case SignalingPeerPresent():
        // A callee that found the caller but cannot complete the handshake
        // has the wrong code.
        if (role == CallRole.callee && _peer == null) {
          _arm(timeouts.handshake, CallEndReason.securityFailure);
        }
      case SignalingRejectedFrame():
        break;
    }
  }

  Future<void> _flushCandidates() async {
    final list = [..._pendingCandidates];
    _pendingCandidates.clear();
    for (final c in list) {
      await _peer?.addRemoteCandidate(c);
    }
  }

  Future<void> _resetPeer() async {
    final p = _peer;
    _peer = null;
    _localSdp = null;
    _remoteSdp = null;
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();
    _authSent = false;
    _peerAuthed = false;
    _earlyAuth = null;
    try {
      await p?.close();
    } catch (_) {}
  }

  Future<void> _openPeer() async {
    await _resetPeer();
    final peer = _peer = peerFactory(peerConfig);
    _subs.add(
      peer.localCandidates.listen((c) => _signaling?.sendIce(c)),
    );
    _subs.add(
      peer.linkStates.listen((s) => _enqueue(() => _onLink(peer, s))),
    );
    _subs.add(
      peer.dataChannelStates.listen(
        (open) => _enqueue(() => _onDataChannel(peer, open)),
      ),
    );
    _subs.add(
      peer.dataMessages.listen((t) {
        final arrival = _clockUs();
        _enqueue(() => _onData(peer, t, arrival));
      }),
    );
    try {
      await peer.open();
      if (_snapshot.muted) await peer.setMuted(true);
    } catch (_) {
      await _finish(CallEndReason.deviceError);
    }
  }

  // -------------------------------------------------------------------------
  // Peer link
  // -------------------------------------------------------------------------

  Future<void> _onLink(PeerTransport peer, PeerLinkState s) async {
    if (!identical(peer, _peer)) return;
    switch (s) {
      case PeerLinkState.connected:
        if (_snapshot.phase == CallPhase.reconnecting) {
          _phaseTimer?.cancel();
          _set(_snapshot.copyWith(phase: CallPhase.active));
        }
      case PeerLinkState.disconnected:
        if (_snapshot.phase == CallPhase.active) {
          _set(_snapshot.copyWith(phase: CallPhase.reconnecting));
          _arm(timeouts.reconnect, CallEndReason.networkLost);
        }
      case PeerLinkState.failed:
        await _finish(
          _snapshot.phase.isStreaming
              ? CallEndReason.networkLost
              : CallEndReason.connectFailed,
        );
      case PeerLinkState.connecting || PeerLinkState.closed:
        break;
    }
  }

  Future<void> _onDataChannel(PeerTransport peer, bool open) async {
    if (!identical(peer, _peer)) return;
    if (!open) {
      if (_snapshot.phase.isStreaming) {
        await _finish(CallEndReason.networkLost);
      }
      return;
    }
    if (_authSent) return;
    final keys = _keys;
    final own = _localSdp == null ? null : sdpFingerprint(_localSdp!);
    final theirs = _remoteSdp == null ? null : sdpFingerprint(_remoteSdp!);
    if (keys == null || own == null || theirs == null) {
      await _finish(CallEndReason.securityFailure);
      return;
    }
    _authSent = true;
    final mac = await fingerprintMac(
      callKey: keys.callKey,
      role: role.wire,
      own: own,
      peer: theirs,
    );
    await peer.sendData(AuthMessage(fingerprint: own, mac: mac).encode());
    _arm(timeouts.auth, CallEndReason.securityFailure);
    final early = _earlyAuth;
    _earlyAuth = null;
    if (early != null) await _onAuth(early);
    if (_peerAuthed) await _becomeActive();
  }

  Future<void> _onAuth(AuthMessage m) async {
    if (_peerAuthed) return;
    if (!_authSent) {
      _earlyAuth = m;
      return;
    }
    final keys = _keys!;
    final own = sdpFingerprint(_localSdp!)!;
    final theirs = sdpFingerprint(_remoteSdp!)!;
    final peerRole = role == CallRole.caller ? CallRole.callee : CallRole.caller;
    final expected = await fingerprintMac(
      callKey: keys.callKey,
      role: peerRole.wire,
      own: theirs,
      peer: own,
    );
    final claimed = sdpFingerprints('a=fingerprint:${m.fingerprint}');
    if (claimed.length != 1 ||
        claimed.single != theirs ||
        !bytesEqual(expected, m.mac)) {
      await _finish(CallEndReason.securityFailure);
      return;
    }
    _peerAuthed = true;
    await _becomeActive();
  }

  Future<void> _becomeActive() async {
    if (!_authSent || !_peerAuthed || _snapshot.phase.isStreaming) return;
    _phaseTimer?.cancel();
    final keys = _keys!;
    final sas = await safetyCode(
      callKey: keys.callKey,
      fingerprintA: sdpFingerprint(_localSdp!)!,
      fingerprintB: sdpFingerprint(_remoteSdp!)!,
    );
    _set(
      _snapshot.copyWith(
        phase: CallPhase.active,
        connectedAt: _now(),
        safetyCode: sas,
      ),
    );
    _ping();
    _pingTimer = Timer.periodic(timeouts.pingInterval, (_) => _ping());
    _statsTimer = Timer.periodic(
      timeouts.statsInterval,
      (_) => _enqueue(_pollStats),
    );
    if (_snapshot.muted) await _send(const MuteMessage(true));
  }

  void _ping() {
    if (!_snapshot.phase.isStreaming) return;
    unawaited(_send(PingMessage(_clockUs())));
  }

  Future<void> _pollStats() async {
    final s = await _peer?.stats();
    if (s == null) return;
    _set(_snapshot.copyWith(stats: s, quality: qualityOf(s)));
  }

  Future<void> _send(CallDataMessage m) async {
    final peer = _peer;
    if (peer == null || !_snapshot.phase.isStreaming) return;
    try {
      await peer.sendData(m.encode());
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Data channel
  // -------------------------------------------------------------------------

  Future<void> _onData(PeerTransport peer, String text, int arrivalUs) async {
    if (!identical(peer, _peer)) return;
    final m = CallDataMessage.decode(text);
    if (m == null) return;
    if (m is AuthMessage) {
      await _onAuth(m);
      return;
    }
    if (!_snapshot.phase.isStreaming) return;
    switch (m) {
      case PingMessage(:final t1):
        final t3 = _clockUs();
        await _send(PongMessage(t1: t1, t2: arrivalUs, t3: t3));
      case PongMessage(:final t1, :final t2, :final t3):
        _clock.add(ClockSample(t1, t2, t3, arrivalUs));
        if (_clock.isReady && !_snapshot.clockSynced) {
          final fixed = _book.fixProvisional(_clock.guestToHost);
          _set(_snapshot.copyWith(clockSynced: true, lines: _book.lines));
          if (fixed.isNotEmpty && !_transcript.isClosed) {
            _transcript.add(RemoteLinesRetimed(fixed));
          }
        }
      case PendingLineMessage(:final id, :final atUs, :final durMs):
        final (local, provisional) = _toLocal(atUs, m.sentUs, arrivalUs);
        _book.upsert(
          LiveLine(
            id: id,
            origin: LineOrigin.remote,
            atUs: local,
            peerAtUs: atUs,
            durMs: durMs,
            pending: true,
            provisionalTime: provisional,
          ),
        );
        _setLines();
      case LineMessage():
        _onRemoteLine(m, arrivalUs);
      case DropLineMessage(:final id):
        if (_book.remove(LineOrigin.remote, id)) _setLines();
        if (!_transcript.isClosed) _transcript.add(RemoteLineDropped(id));
      case ActivityMessage(:final speaking, :final level):
        _set(_snapshot.copyWith(remoteSpeaking: speaking, remoteLevel: level));
      case MuteMessage(:final muted):
        _set(_snapshot.copyWith(peerMuted: muted));
      case ByeMessage():
        await _finish(CallEndReason.remoteHangUp);
      case AuthMessage():
        break;
    }
  }

  (int, bool) _toLocal(int peerAtUs, int sentUs, int arrivalUs) {
    if (_clock.sampleCount > 0) {
      return (_clock.guestToHost(peerAtUs), !_clock.isReady);
    }
    // No exchange yet: assume an instant delivery.
    return (arrivalUs - (sentUs - peerAtUs), true);
  }

  void _onRemoteLine(LineMessage m, int arrivalUs) {
    final (local, provisional) = _toLocal(m.atUs, m.sentUs, arrivalUs);
    final line = LiveLine(
      id: m.id,
      origin: LineOrigin.remote,
      atUs: local,
      peerAtUs: m.atUs,
      durMs: m.durMs,
      text: m.text,
      speakerKey: m.speakerKey,
      speakerName: m.speakerName,
      language: m.language,
      kind: m.kind,
      confidence: m.confidence,
      provisionalTime: provisional,
    );
    _book.upsert(line);
    if (!_transcript.isClosed) _transcript.add(RemoteLineFinal(line));
    // Our own lines that merely repeat this one through the loudspeaker.
    for (final mine in _book.finalsNear(LineOrigin.local, local).toList()) {
      if (isEchoOf(mine, line, localIsCallee: role == CallRole.callee)) {
        _book.remove(LineOrigin.local, mine.id);
        unawaited(_send(DropLineMessage(mine.id)));
        if (!_transcript.isClosed) {
          _transcript.add(LocalLineRetracted(mine.id));
        }
      }
    }
    _setLines();
  }

  // -------------------------------------------------------------------------
  // Local transcription (fed by the session layer)
  // -------------------------------------------------------------------------

  /// Speech detected on our microphone at [atUs] (this clock) for [durMs];
  /// its text is being computed.
  void localPending(String id, int atUs, int durMs) {
    if (!_snapshot.phase.isStreaming) return;
    _book.upsert(
      LiveLine(
        id: id,
        origin: LineOrigin.local,
        atUs: atUs,
        durMs: durMs,
        pending: true,
      ),
    );
    _setLines();
    unawaited(
      _send(
        PendingLineMessage(
          id: id,
          atUs: atUs,
          durMs: durMs,
          sentUs: _clockUs(),
        ),
      ),
    );
  }

  /// A final local line. Returns false when it is an echo of the peer's
  /// speech (then it is not shown or sent, and must not be stored).
  bool localFinal(LiveLine line) {
    if (_snapshot.phase.isOver) return true;
    for (final theirs in _book.finalsNear(LineOrigin.remote, line.atUs)) {
      if (isEchoOf(line, theirs, localIsCallee: role == CallRole.callee)) {
        localDropped(line.id);
        return false;
      }
    }
    _book.upsert(line);
    _setLines();
    unawaited(
      _send(
        LineMessage(
          id: line.id,
          atUs: line.atUs,
          durMs: line.durMs,
          sentUs: _clockUs(),
          text: line.text,
          speakerKey: line.speakerKey,
          speakerName: line.speakerName,
          language: line.language,
          kind: line.kind,
          confidence: line.confidence,
        ),
      ),
    );
    return true;
  }

  /// A pending local line produced no text (silence / failure).
  void localDropped(String id) {
    if (_book.remove(LineOrigin.local, id)) _setLines();
    unawaited(_send(DropLineMessage(id)));
  }

  /// Our speaking state / level (sent at most every 250 ms, and on every
  /// change of the speaking state).
  void localActivity({required bool speaking, required double level}) {
    if (!_snapshot.phase.isStreaming) return;
    final now = _clockUs();
    if (speaking != _snapshot.localSpeaking) {
      _set(_snapshot.copyWith(localSpeaking: speaking));
    }
    if (speaking == _lastActivitySpeaking &&
        now - _lastActivityUs < 250 * 1000) {
      return;
    }
    _lastActivityUs = now;
    _lastActivitySpeaking = speaking;
    unawaited(_send(ActivityMessage(speaking: speaking, level: level)));
  }

  /// Remote lines whose time is still provisional, re-mapped with the
  /// current estimate (call at the end, before persisting).
  List<LiveLine> fixProvisionalNow() => _clock.sampleCount == 0
      ? const []
      : _book.fixProvisional(_clock.guestToHost);
}
