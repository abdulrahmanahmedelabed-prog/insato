// Test doubles of the live call: an in-memory relay speaking the relay
// protocol, and an in-memory WebRTC network linking two [PeerTransport]s.

import 'dart:async';
import 'dart:convert';

import 'package:insato/features/live_call/peer_transport.dart';
import 'package:insato/features/live_call/signaling_client.dart';
import 'package:insato/features/live_call/signaling_protocol.dart';

/// In-memory relay with the reference server's rules (≤ 2 per room).
class MemoryRelay {
  final Map<String, List<_MemorySocket>> _rooms = {};

  /// Every frame clients sent (text), for inspection.
  final List<String> seen = [];

  /// When set, rewrites relayed blobs (a malicious relay).
  RelayData Function(RelayData)? tamper;

  /// Connections opened.
  int connections = 0;

  /// The URLs clients connected to.
  final List<String> urls = [];

  /// Connector for [CallSignaling.connect].
  Future<RelaySocket> connect(String url) async {
    connections++;
    urls.add(url);
    return _MemorySocket(this);
  }

  void _onFrame(_MemorySocket s, String text) {
    seen.add(text);
    final f = RelayFrame.decode(text);
    switch (f) {
      case RelayJoin(:final room):
        final list = _rooms.putIfAbsent(room, () => []);
        if (list.length >= 2) {
          s._deliver(const RelayError('full').encode());
          scheduleMicrotask(() => unawaited(s.close()));
          return;
        }
        s.room = room;
        for (final o in list) {
          o._deliver(const RelayPeerEvent(joined: true).encode());
        }
        s._deliver(RelayJoined(list.length).encode());
        list.add(s);
      case RelayData():
        final out = tamper?.call(f) ?? f;
        for (final o in _rooms[s.room] ?? const <_MemorySocket>[]) {
          if (!identical(o, s)) o._deliver(out.encode());
        }
      case RelayPing():
        s._deliver(const RelayPong().encode());
      default:
        break;
    }
  }

  void _left(_MemorySocket s) {
    final list = _rooms[s.room];
    if (list == null) return;
    list.remove(s);
    if (list.isEmpty) {
      _rooms.remove(s.room);
    } else {
      for (final o in list) {
        o._deliver(const RelayPeerEvent(joined: false).encode());
      }
    }
  }
}

class _MemorySocket implements RelaySocket {
  _MemorySocket(this.relay);
  final MemoryRelay relay;
  final StreamController<String> _in = StreamController<String>();
  String? room;
  bool _closed = false;

  void _deliver(String text) {
    if (_closed) return;
    scheduleMicrotask(() {
      if (!_closed) _in.add(text);
    });
  }

  @override
  Stream<String> get messages => _in.stream;

  @override
  void send(String text) {
    if (_closed) return;
    scheduleMicrotask(() => relay._onFrame(this, text));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    relay._left(this);
    await _in.close();
  }
}

/// SDP of a fake peer with certificate fingerprint [fp].
String fakeSdp(String kind, String fp) =>
    'v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n'
    'a=fingerprint:sha-256 $fp\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
    'a=setup:${kind == 'offer' ? 'actpass' : 'active'}\r\n';

/// Links fake transports pairwise (first two created).
class FakePeerNetwork {
  final List<FakePeerTransport> peers = [];

  /// Rewrites data-channel text between the peers (attack simulation).
  String Function(FakePeerTransport from, String text)? tamperData;

  /// When true, links never connect (strict NAT without TURN).
  bool blocked = false;

  /// Configurations the transports were created with.
  final List<PeerConfig> configs = [];

  /// Factory for the engine.
  PeerTransport create(PeerConfig config) {
    configs.add(config);
    final p = FakePeerTransport._(this, peers.length);
    peers.add(p);
    return p;
  }

  FakePeerTransport? _other(FakePeerTransport p) {
    // Pair by order of creation: (0,1), (2,3), … (a reset peer pairs with
    // the next one created).
    final i = peers.indexOf(p);
    final j = i.isEven ? i + 1 : i - 1;
    return j < peers.length && j >= 0 ? peers[j] : null;
  }

  void _maybeConnect(FakePeerTransport p) {
    final o = _other(p);
    if (blocked || o == null) return;
    if (p._local != null &&
        p._remote != null &&
        o._local != null &&
        o._remote != null &&
        !p._connected &&
        !p._closed &&
        !o._closed) {
      p._connected = o._connected = true;
      for (final x in [p, o]) {
        x._emitState(PeerLinkState.connected);
        x._emitDc(true);
      }
    }
  }

  /// Simulates a network drop (and, with [recover], a recovery).
  Future<void> drop({bool recover = false}) async {
    for (final p in peers) {
      if (p._connected) p._emitState(PeerLinkState.disconnected);
    }
    if (recover) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      for (final p in peers) {
        if (p._connected) p._emitState(PeerLinkState.connected);
      }
    }
  }
}

/// A fake transport.
class FakePeerTransport implements PeerTransport {
  FakePeerTransport._(this.net, this.index)
    : fingerprint = List.generate(
        32,
        (i) => ((index * 37 + i * 11) % 256)
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase(),
      ).join(':');

  final FakePeerNetwork net;
  final int index;
  final String fingerprint;
  final _cand = StreamController<IceCandidateData>.broadcast();
  final _states = StreamController<PeerLinkState>.broadcast();
  final _msgs = StreamController<String>.broadcast();
  final _dc = StreamController<bool>.broadcast();
  String? _local;
  String? _remote;
  bool _connected = false;
  bool _closed = false;
  bool opened = false;
  bool muted = false;
  final List<IceCandidateData> remoteCandidates = [];
  final List<String> sent = [];
  LinkStats nextStats = const LinkStats(
    rttMs: 80,
    packetLossPercent: 0.5,
    relayed: false,
  );

  void _emitState(PeerLinkState s) {
    if (!_states.isClosed) _states.add(s);
  }

  void _emitDc(bool open) {
    if (!_dc.isClosed) _dc.add(open);
  }

  @override
  Stream<IceCandidateData> get localCandidates => _cand.stream;
  @override
  Stream<PeerLinkState> get linkStates => _states.stream;
  @override
  Stream<String> get dataMessages => _msgs.stream;
  @override
  Stream<bool> get dataChannelStates => _dc.stream;

  @override
  Future<void> open() async => opened = true;

  void _candidate() {
    scheduleMicrotask(() {
      if (!_cand.isClosed) {
        _cand.add(
          IceCandidateData(
            candidate:
                'candidate:1 1 udp 2122260223 10.0.0.$index 5000$index typ host',
            sdpMid: '0',
            sdpMLineIndex: 0,
          ),
        );
      }
    });
  }

  @override
  Future<String> createOffer() async {
    _local = fakeSdp('offer', fingerprint);
    _candidate();
    return _local!;
  }

  @override
  Future<String> acceptOffer(String sdp) async {
    _remote = sdp;
    _local = fakeSdp('answer', fingerprint);
    _candidate();
    scheduleMicrotask(() => net._maybeConnect(this));
    return _local!;
  }

  @override
  Future<void> acceptAnswer(String sdp) async {
    _remote = sdp;
    scheduleMicrotask(() => net._maybeConnect(this));
  }

  @override
  Future<void> addRemoteCandidate(IceCandidateData c) async =>
      remoteCandidates.add(c);

  @override
  Future<void> sendData(String text) async {
    if (!_connected || _closed) return;
    sent.add(text);
    final o = net._other(this);
    if (o == null || o._closed) return;
    final t = net.tamperData?.call(this, text) ?? text;
    Timer(Duration.zero, () {
      if (!o._msgs.isClosed) o._msgs.add(t);
    });
  }

  @override
  Future<void> setMuted(bool m) async => muted = m;

  @override
  Future<LinkStats?> stats() async => nextStats;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final o = net._other(this);
    if (o != null && o._connected && !o._closed) {
      Timer(Duration.zero, () => o._emitDc(false));
    }
    await _cand.close();
    await _states.close();
    await _msgs.close();
    await _dc.close();
  }
}

/// JSON of a data message (helper for tampering).
Map<String, Object?> jsonOf(String text) =>
    (jsonDecode(text) as Map).cast<String, Object?>();
