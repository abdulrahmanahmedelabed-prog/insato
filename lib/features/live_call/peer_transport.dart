// Live Insato call (v1.2): the peer-to-peer link seen by the call logic.
//
// [PeerTransport] is what the call state machine needs from WebRTC: one
// bidirectional audio track (echo cancellation / noise suppression on), one
// ordered reliable data channel, SDP offer / answer, trickle ICE, mute and
// link statistics. Production: [WebRtcPeerTransport]
// (webrtc_peer_transport.dart, package flutter_webrtc); tests: an in-memory
// pair.
//
// Pure Dart.

import 'dart:async';

import 'signaling_protocol.dart' show IceCandidateData;

/// Public STUN server used by default (no account, no cost; it only tells a
/// device its public address and never sees the call).
const String kDefaultStunUrl = 'stun:stun.l.google.com:19302';

/// A STUN / TURN server.
class IceServerConfig {
  /// Creates a server entry.
  const IceServerConfig({
    required this.urls,
    this.username,
    this.credential,
  });

  /// `stun:` / `turn:` / `turns:` URLs.
  final List<String> urls;

  /// TURN user name.
  final String? username;

  /// TURN credential.
  final String? credential;

  /// RTCConfiguration entry.
  Map<String, Object> toMap() => {
    'urls': urls,
    if (username != null && username!.isNotEmpty) 'username': username!,
    if (credential != null && credential!.isNotEmpty)
      'credential': credential!,
  };
}

/// Configuration of a peer connection.
class PeerConfig {
  /// Creates a configuration.
  const PeerConfig({
    this.iceServers = const [IceServerConfig(urls: [kDefaultStunUrl])],
    this.relayOnly = false,
  });

  /// STUN / TURN servers.
  final List<IceServerConfig> iceServers;

  /// Use only TURN relay candidates (hides both IP addresses from each
  /// other; needs a TURN server).
  final bool relayOnly;

  /// True when a TURN server is configured.
  bool get hasTurn => iceServers.any(
    (s) => s.urls.any((u) => u.startsWith('turn:') || u.startsWith('turns:')),
  );

  /// RTCConfiguration map.
  Map<String, Object> toRtcConfiguration() => {
    'iceServers': [for (final s in iceServers) s.toMap()],
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': relayOnly && hasTurn ? 'relay' : 'all',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };
}

/// State of the peer link.
enum PeerLinkState {
  /// ICE / DTLS in progress.
  connecting,

  /// Media and data flow.
  connected,

  /// Temporarily lost (ICE may recover).
  disconnected,

  /// Gave up.
  failed,

  /// Closed locally.
  closed,
}

/// Link statistics (each value null when unknown).
class LinkStats {
  /// Creates statistics.
  const LinkStats({
    this.rttMs,
    this.packetLossPercent,
    this.jitterMs,
    this.relayed,
  });

  /// Round trip of the selected candidate pair.
  final double? rttMs;

  /// Inbound audio packet loss (0–100).
  final double? packetLossPercent;

  /// Inbound audio jitter.
  final double? jitterMs;

  /// True when the media goes through a TURN relay.
  final bool? relayed;
}

/// One end of the peer-to-peer link.
abstract class PeerTransport {
  /// Local ICE candidates to signal.
  Stream<IceCandidateData> get localCandidates;

  /// Link state changes.
  Stream<PeerLinkState> get linkStates;

  /// Text messages received on the data channel.
  Stream<String> get dataMessages;

  /// True when the data channel opened, false when it closed.
  Stream<bool> get dataChannelStates;

  /// Opens the microphone track (echo cancellation, noise suppression,
  /// automatic gain) and creates the connection and the data channel.
  Future<void> open();

  /// Creates and applies the local offer; returns its SDP (caller).
  Future<String> createOffer();

  /// Applies the remote offer, creates and applies the answer; returns its
  /// SDP (callee).
  Future<String> acceptOffer(String sdp);

  /// Applies the remote answer (caller).
  Future<void> acceptAnswer(String sdp);

  /// Adds a remote ICE candidate.
  Future<void> addRemoteCandidate(IceCandidateData candidate);

  /// Sends a text message on the data channel (dropped when not open).
  Future<void> sendData(String text);

  /// Mutes / unmutes the outgoing microphone track.
  Future<void> setMuted(bool muted);

  /// Current statistics (null when unavailable).
  Future<LinkStats?> stats();

  /// Closes everything (microphone track included). Idempotent.
  Future<void> close();
}

/// Builds a transport for a configuration.
typedef PeerTransportFactory = PeerTransport Function(PeerConfig config);
