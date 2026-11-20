// Host-side state of a multi-device meeting (v1.2 C): wraps the server,
// keeps each guest's clock estimate (from the very first ping, so clocks
// are known before the meeting starts) and the live status shown per guest:
// connected, battery, network quality, input level, alignment.
//
// Pure Dart.

import 'dart:async';
import 'dart:math' as math;

import '../../audio/pcm.dart' show meterLevel;
import 'alignment.dart' show AlignmentState;
import 'clock_sync.dart';
import 'host_server.dart';
import 'protocol.dart';

/// Network quality of a guest link.
enum NetworkQuality {
  /// Low latency, nothing lost.
  good,

  /// Usable; some delay or loss.
  fair,

  /// Audio arrives late or gets lost.
  poor,
}

/// Classifies a link from its round trip, lost-frame and late-frame rates.
NetworkQuality networkQualityOf({
  double? rttMs,
  double lossRate = 0,
  double lateRate = 0,
}) {
  final rtt = rttMs ?? 0;
  if (rtt > 250 || lossRate > 0.05 || lateRate > 0.10) {
    return NetworkQuality.poor;
  }
  if (rtt > 60 || lossRate > 0.01 || lateRate > 0.02) {
    return NetworkQuality.fair;
  }
  return NetworkQuality.good;
}

/// What the host shows about one guest.
class GuestView {
  /// Creates a view.
  const GuestView({
    required this.id,
    required this.name,
    required this.platform,
    required this.connected,
    this.battery,
    this.charging,
    this.level = 0,
    this.rttMs,
    this.quality = NetworkQuality.good,
    this.alignment,
    this.alignmentResidualMs,
    this.drops = 0,
  });

  /// Device id.
  final String id;

  /// Display name.
  final String name;

  /// Platform (`android`, `ios`, `windows`, …).
  final String platform;

  /// True while connected.
  final bool connected;

  /// Battery percentage (null = unknown).
  final int? battery;

  /// Charging (null = unknown).
  final bool? charging;

  /// Input level 0..1 (from the received audio).
  final double level;

  /// Median round trip in ms.
  final double? rttMs;

  /// Link quality.
  final NetworkQuality quality;

  /// Audio alignment (null until the meeting starts).
  final AlignmentState? alignment;

  /// Last measured residual in ms.
  final double? alignmentResidualMs;

  /// Number of times the link dropped.
  final int drops;
}

class _Guest {
  _Guest(this.info);
  GuestPeerInfo info;
  bool connected = true;
  GuestStatus status = const GuestStatus();
  double level = 0;
  int frames = 0;
  int lost = 0;
  int lastSeq = -1;
  double lateRate = 0;
  AlignmentState? alignment;
  double? residualMs;
  int drops = 0;
  final ClockSyncEstimator clock = ClockSyncEstimator();
}

/// See the file header.
class MultiDeviceHub {
  /// Wraps [host].
  MultiDeviceHub(
    this.host, {
    Duration viewInterval = const Duration(milliseconds: 250),
  }) {
    _sub = host.events.listen(_onEvent);
    _timer = Timer.periodic(viewInterval, (_) => _flushViews());
  }

  /// The server.
  final MultiDeviceHost host;

  final Map<String, _Guest> _guests = {};
  final _views = StreamController<List<GuestView>>.broadcast();
  StreamSubscription<HostEvent>? _sub;
  Timer? _timer;
  bool _dirty = false;
  bool _closed = false;

  /// What guests need to join.
  JoinInfo get joinInfo => host.joinInfo;

  /// Raw guest events (audio, connections) for the fusion.
  Stream<HostEvent> get events => host.events;

  /// Host clock (µs).
  int nowUs() => host.nowUs();

  /// Guest views, refreshed at most every 250 ms.
  Stream<List<GuestView>> get views => _views.stream;

  /// Current guest views (connected first).
  List<GuestView> get current {
    final list = [for (final g in _guests.values) _view(g)];
    list.sort(
      (a, b) => (a.connected == b.connected) ? 0 : (a.connected ? -1 : 1),
    );
    return list;
  }

  /// Ids of connected guests.
  List<String> get connectedIds => [
    for (final g in _guests.values)
      if (g.connected) g.info.id,
  ];

  /// Name / platform of every guest seen.
  Map<String, GuestPeerInfo> get knownGuests => {
    for (final g in _guests.values) g.info.id: g.info,
  };

  /// True after [close].
  bool get isClosed => _closed;

  /// Clock estimate of guest [id].
  ClockSyncEstimator? clockOf(String id) => _guests[id]?.clock;

  /// Sends the meeting state ([HostState]) to every guest.
  void setRecordingState(String state, {String? title}) =>
      host.setState(state, title: title);

  /// Current meeting state.
  String get recordingState => host.state;

  /// Fusion feedback shown per guest.
  void reportFusion(
    String id, {
    AlignmentState? alignment,
    double? residualMs,
    double? lateRate,
  }) {
    final g = _guests[id];
    if (g == null) return;
    g.alignment = alignment ?? g.alignment;
    g.residualMs = residualMs ?? g.residualMs;
    g.lateRate = lateRate ?? g.lateRate;
    _dirty = true;
  }

  /// Removes guest [id] for the rest of the meeting.
  Future<void> remove(String id) async {
    await host.remove(id);
    _guests.remove(id);
    _dirty = true;
    _flushViews();
  }

  /// Ends the meeting for every guest and stops the server.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    await host.close();
    await _sub?.cancel();
    await _views.close();
  }

  void _onEvent(HostEvent e) {
    switch (e) {
      case GuestConnected(:final info):
        final g = _guests[info.id];
        if (g == null) {
          _guests[info.id] = _Guest(info);
        } else {
          g
            ..info = info
            ..connected = true
            ..lastSeq = -1;
        }
      case GuestDisconnected(:final guestId, :final removed):
        final g = _guests[guestId];
        if (g != null) {
          g.connected = false;
          g.level = 0;
          g.drops++;
          if (removed) _guests.remove(guestId);
        }
      case GuestClock(:final guestId, :final sample):
        _guests[guestId]?.clock.add(sample);
      case GuestStatusReport(:final guestId, :final status):
        _guests[guestId]?.status = status;
      case GuestAudio(:final guestId, :final frame):
        final g = _guests[guestId];
        if (g == null) return;
        g.frames++;
        if (g.lastSeq >= 0 && frame.seq > g.lastSeq + 1) {
          g.lost += frame.seq - g.lastSeq - 1;
        }
        g.lastSeq = math.max(g.lastSeq, frame.seq);
        g.level = math.max(meterLevel(frame.samples), g.level * 0.6);
    }
    _dirty = true;
  }

  GuestView _view(_Guest g) {
    final total = g.frames + g.lost;
    return GuestView(
      id: g.info.id,
      name: g.info.name,
      platform: g.info.platform,
      connected: g.connected,
      battery: g.status.battery,
      charging: g.status.charging,
      level: g.connected ? g.level : 0,
      rttMs: g.clock.rttMs,
      quality: networkQualityOf(
        rttMs: g.clock.rttMs,
        lossRate: total == 0 ? 0 : g.lost / total,
        lateRate: g.lateRate,
      ),
      alignment: g.alignment,
      alignmentResidualMs: g.residualMs,
      drops: g.drops,
    );
  }

  void _flushViews() {
    if (!_dirty || _views.isClosed) return;
    _dirty = false;
    _views.add(current);
  }
}
