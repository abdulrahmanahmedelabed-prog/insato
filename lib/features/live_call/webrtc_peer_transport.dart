// Live Insato call (v1.2): [PeerTransport] over package:flutter_webrtc
// (verified against flutter_webrtc 1.6.3 / webrtc_interface 1.5.1 sources).
//
// * Audio: `getUserMedia({'audio': {echoCancellation, noiseSuppression,
//   autoGainControl}})` — WebRTC's audio processing (Android also uses the
//   platform AEC/NS by default, `androidUseHardwareAudioProcessing`). The
//   remote track is played by the native audio device module; nothing to
//   render.
// * Data: one negotiated channel (`negotiated: true, id: 0`) created on both
//   sides before the offer, so no `onDataChannel` race; ordered, reliable.
// * Encryption: DTLS-SRTP (`DtlsSrtpKeyAgreement`), always on in WebRTC.
// * Raw remote PCM is NOT available from Dart on any platform in this
//   package (the only sink is `MediaRecorder`, which writes AAC files on
//   Android and needs a video track on iOS); see docs/ARCHITECTURE.md.
//
// Not unit-testable (native plugin); the call logic is tested through the
// [PeerTransport] interface with an in-memory fake.

import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'peer_transport.dart';
import 'signaling_protocol.dart' show IceCandidateData;

/// Production [PeerTransport].
class WebRtcPeerTransport implements PeerTransport {
  /// Creates a transport for [config].
  WebRtcPeerTransport(this.config);

  /// Peer connection configuration.
  final PeerConfig config;

  RTCPeerConnection? _pc;
  RTCDataChannel? _dc;
  MediaStream? _local;
  bool _closed = false;
  final _candidates = StreamController<IceCandidateData>.broadcast();
  final _states = StreamController<PeerLinkState>.broadcast();
  final _messages = StreamController<String>.broadcast();
  final _dcStates = StreamController<bool>.broadcast();

  @override
  Stream<IceCandidateData> get localCandidates => _candidates.stream;
  @override
  Stream<PeerLinkState> get linkStates => _states.stream;
  @override
  Stream<String> get dataMessages => _messages.stream;
  @override
  Stream<bool> get dataChannelStates => _dcStates.stream;

  void _add<T>(StreamController<T> c, T v) {
    if (!c.isClosed) c.add(v);
  }

  @override
  Future<void> open() async {
    final local = _local = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    final pc = _pc = await createPeerConnection(config.toRtcConfiguration());
    pc.onIceCandidate = (c) {
      final line = c.candidate;
      if (line == null || line.isEmpty) return;
      _add(
        _candidates,
        IceCandidateData(
          candidate: line,
          sdpMid: c.sdpMid,
          sdpMLineIndex: c.sdpMLineIndex,
        ),
      );
    };
    pc.onConnectionState = (s) => _add(_states, _map(s));
    for (final track in local.getAudioTracks()) {
      await pc.addTrack(track, local);
    }
    final dc = _dc = await pc.createDataChannel(
      'insato-call',
      RTCDataChannelInit()
        ..negotiated = true
        ..id = 0
        ..ordered = true,
    );
    dc.onDataChannelState = (s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) _add(_dcStates, true);
      if (s == RTCDataChannelState.RTCDataChannelClosed) {
        _add(_dcStates, false);
      }
    };
    dc.onMessage = (m) {
      if (!m.isBinary) _add(_messages, m.text);
    };
    if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
      _add(_dcStates, true);
    }
  }

  static PeerLinkState _map(RTCPeerConnectionState s) => switch (s) {
    RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
      PeerLinkState.connected,
    RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
      PeerLinkState.disconnected,
    RTCPeerConnectionState.RTCPeerConnectionStateFailed => PeerLinkState.failed,
    RTCPeerConnectionState.RTCPeerConnectionStateClosed => PeerLinkState.closed,
    _ => PeerLinkState.connecting,
  };

  RTCPeerConnection get _peer {
    final pc = _pc;
    if (pc == null) throw StateError('open() first');
    return pc;
  }

  @override
  Future<String> createOffer() async {
    final offer = await _peer.createOffer({'offerToReceiveAudio': true});
    await _peer.setLocalDescription(offer);
    return offer.sdp ?? '';
  }

  @override
  Future<String> acceptOffer(String sdp) async {
    await _peer.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await _peer.createAnswer({'offerToReceiveAudio': true});
    await _peer.setLocalDescription(answer);
    return answer.sdp ?? '';
  }

  @override
  Future<void> acceptAnswer(String sdp) =>
      _peer.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));

  @override
  Future<void> addRemoteCandidate(IceCandidateData c) => _peer.addCandidate(
    RTCIceCandidate(c.candidate, c.sdpMid, c.sdpMLineIndex),
  );

  @override
  Future<void> sendData(String text) async {
    final dc = _dc;
    if (dc == null || dc.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }
    try {
      await dc.send(RTCDataChannelMessage(text));
    } catch (_) {
      // Closed meanwhile.
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
  }

  @override
  Future<LinkStats?> stats() async {
    final pc = _pc;
    if (pc == null) return null;
    try {
      return parseWebRtcStats([
        for (final r in await pc.getStats())
          (r.type, Map<String, Object?>.from(r.values)),
      ]);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _dc?.close();
    } catch (_) {}
    for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await _local?.dispose();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    _add(_states, PeerLinkState.closed);
    await _candidates.close();
    await _states.close();
    await _messages.close();
    await _dcStates.close();
  }
}

/// Extracts [LinkStats] from W3C stats reports `(type, values)`: the
/// selected / nominated `candidate-pair` (round trip, local candidate type)
/// and the audio `inbound-rtp` (loss, jitter). Values in seconds are turned
/// into milliseconds.
LinkStats parseWebRtcStats(List<(String, Map<String, Object?>)> reports) {
  double? num0(Object? v) => v is num
      ? v.toDouble()
      : (v is String ? double.tryParse(v) : null);
  Map<String, Object?>? pair;
  final byId = <String, Map<String, Object?>>{};
  for (final (type, values) in reports) {
    final id = values['id'];
    if (id is String) byId[id] = values;
    if (type == 'candidate-pair') {
      final ok = values['state'] == 'succeeded' &&
          (values['nominated'] == true || values['selected'] == true);
      if (ok || pair == null) pair = values;
    }
  }
  double? rtt;
  bool? relayed;
  if (pair != null) {
    final r = num0(pair['currentRoundTripTime']);
    if (r != null) rtt = r * 1000;
    final local = byId[pair['localCandidateId']];
    final remote = byId[pair['remoteCandidateId']];
    if (local != null || remote != null) {
      relayed = local?['candidateType'] == 'relay' ||
          remote?['candidateType'] == 'relay';
    }
  }
  double? loss;
  double? jitter;
  for (final (type, values) in reports) {
    if (type != 'inbound-rtp') continue;
    if (values['kind'] != 'audio' && values['mediaType'] != 'audio') continue;
    final lost = num0(values['packetsLost']);
    final got = num0(values['packetsReceived']);
    if (lost != null && got != null && lost + got > 0) {
      loss = 100 * lost / (lost + got);
    }
    final j = num0(values['jitter']);
    if (j != null) jitter = j * 1000;
  }
  return LinkStats(
    rttMs: rtt,
    packetLossPercent: loss,
    jitterMs: jitter,
    relayed: relayed,
  );
}

/// Production factory.
PeerTransport webRtcPeerTransportFactory(PeerConfig config) =>
    WebRtcPeerTransport(config);
