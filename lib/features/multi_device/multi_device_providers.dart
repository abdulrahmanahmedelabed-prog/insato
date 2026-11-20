// Riverpod wiring of v1.2 C (multi-device recording).
//
// Host: [multiDeviceHostControllerProvider] opens / closes the LAN server
// (the lobby). While it is open, `sessionAudioSourceProvider` wraps the
// normal session source in a [MultiDeviceSessionAudioSource], so the next
// meeting records every guest too. The hub closes itself (guests are told
// the meeting ended) once a meeting that reached recording finishes.
//
// Guest: [guestSessionControllerProvider] joins a host, captures the local
// microphone while the host records and streams it; it reconnects after a
// drop for up to three minutes.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SecretKeyData;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../session/meeting_session_controller.dart';
import '../../session/providers.dart';
import '../voice/device_aware_audio_source.dart'
    show deviceAwareAudioSourceProvider;
import 'battery.dart';
import 'clock_sync.dart';
import 'discovery.dart';
import 'guest_client.dart';
import 'host_server.dart';
import 'hub.dart';
import 'meeting_log.dart';
import 'multi_device_source.dart';
import 'protocol.dart';
import 'secure_channel.dart';
import 'strings.dart';

/// Short platform id sent to the host.
String currentPlatformId() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  return 'linux';
}

/// A readable default name for this device.
String defaultDeviceName() {
  String host = '';
  try {
    host = Platform.localHostname.trim();
  } catch (_) {
    host = '';
  }
  if (host.isNotEmpty && host.toLowerCase() != 'localhost') return host;
  return MS.platform(currentPlatformId());
}

/// True where a camera QR scanner exists (mobile_scanner: Android, iOS).
bool get qrScanSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// LAN discovery (mDNS) where package:bonsoir supports the platform.
final multiDeviceDiscoveryProvider = Provider<MultiDeviceDiscovery>((ref) {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
    return const NoDiscovery();
  }
  final d = BonsoirDiscoveryService();
  ref.onDispose(() {
    unawaited(d.stopAdvertising());
    unawaited(d.stopBrowsing());
  });
  return d;
});

/// Multi-device meeting logs.
final multiDeviceLogStoreProvider = Provider<MultiDeviceLogStore>(
  (ref) => MultiDeviceLogStore(ref.watch(databaseProvider)),
);

/// The multi-device log of a meeting (null for single-device meetings).
final multiDeviceLogProvider = StreamProvider.autoDispose
    .family<MultiDeviceMeetingLog?, String>(
      (ref, id) => ref.watch(multiDeviceLogStoreProvider).watch(id),
    );

/// Starts the host server (overridable in tests).
final multiDeviceHostStarterProvider =
    Provider<Future<MultiDeviceHost> Function()>(
      (ref) =>
          () => MultiDeviceHost.start(hostName: defaultDeviceName()),
    );

/// State of the host lobby.
class HostLobbyState {
  /// Creates a state.
  const HostLobbyState({this.hub, this.opening = false, this.errorAr});

  /// The open hub (null when not hosting).
  final MultiDeviceHub? hub;

  /// True while the server starts.
  final bool opening;

  /// Arabic error of the last attempt.
  final String? errorAr;

  /// True while hosting.
  bool get isOpen => hub != null;
}

/// Opens and closes the host lobby. See the file header.
class MultiDeviceHostController extends Notifier<HostLobbyState> {
  bool _sawRecording = false;
  MultiDeviceDiscovery? _discovery;
  MultiDeviceHub? _hub;

  @override
  HostLobbyState build() {
    ref.listen<SessionState>(meetingSessionControllerProvider, _onSession);
    // `state` cannot be read while disposing: the hub is tracked here.
    ref.onDispose(() {
      final hub = _hub;
      _hub = null;
      if (hub != null) unawaited(_shutdown(hub));
    });
    return const HostLobbyState();
  }

  /// Opens the lobby (no-op when open; refused while this device is a guest
  /// of another meeting).
  Future<void> open() async {
    if (state.isOpen || state.opening) return;
    if (ref.read(guestSessionControllerProvider).isActive) {
      state = const HostLobbyState(errorAr: MS.busyGuest);
      return;
    }
    state = const HostLobbyState(opening: true);
    try {
      final host = await ref.read(multiDeviceHostStarterProvider)();
      if (!ref.mounted) {
        await host.close();
        return;
      }
      final hub = MultiDeviceHub(host);
      _sawRecording = false;
      _hub = hub;
      state = HostLobbyState(hub: hub);
      ref.read(_hubHolderProvider.notifier).set(hub);
      final discovery = ref.read(multiDeviceDiscoveryProvider);
      _discovery = discovery;
      unawaited(discovery.advertise(host.joinInfo).catchError((Object _) {}));
    } catch (_) {
      if (ref.mounted) {
        state = const HostLobbyState(errorAr: MS.hostStartFailed);
      }
    }
  }

  /// Closes the lobby; false while a meeting records (it must end first).
  Future<bool> close() async {
    final hub = state.hub;
    if (hub == null) return true;
    if (ref.read(meetingSessionControllerProvider).isActive) return false;
    _hub = null;
    state = const HostLobbyState();
    ref.read(_hubHolderProvider.notifier).set(null);
    await _shutdown(hub);
    return true;
  }

  /// Removes guest [id] for the rest of the meeting.
  Future<void> remove(String id) async => state.hub?.remove(id);

  Future<void> _shutdown(MultiDeviceHub hub) async {
    try {
      await _discovery?.stopAdvertising();
    } catch (_) {
      // Best effort.
    }
    await hub.close();
  }

  void _onSession(SessionState? prev, SessionState next) {
    final hub = state.hub;
    if (hub == null) return;
    if (next.isCapturing) {
      _sawRecording = true;
      if (next.title != null && next.title != prev?.title) {
        hub.setRecordingState(hub.recordingState, title: next.title);
      }
    }
    if (_sawRecording && prev != null && prev.isActive && !next.isActive) {
      // The meeting is over (saved or discarded): guests are released.
      _sawRecording = false;
      _hub = null;
      state = const HostLobbyState();
      ref.read(_hubHolderProvider.notifier).set(null);
      unawaited(_shutdown(hub));
    }
  }
}

/// The host lobby.
final multiDeviceHostControllerProvider =
    NotifierProvider<MultiDeviceHostController, HostLobbyState>(
      MultiDeviceHostController.new,
    );

/// Holds the open hub. Separate from [multiDeviceHostControllerProvider]
/// (which listens to the session) so that the session's audio source can
/// depend on it without a dependency cycle.
class _HubHolder extends Notifier<MultiDeviceHub?> {
  @override
  MultiDeviceHub? build() => null;

  void set(MultiDeviceHub? hub) => state = hub;
}

final _hubHolderProvider = NotifierProvider<_HubHolder, MultiDeviceHub?>(
  _HubHolder.new,
);

/// The open hub, if any.
final multiDeviceHubProvider = Provider<MultiDeviceHub?>(
  (ref) => ref.watch(_hubHolderProvider),
);

/// Live guest views of the open hub.
final guestViewsProvider = StreamProvider.autoDispose<List<GuestView>>((ref) {
  final hub = ref.watch(multiDeviceHubProvider);
  if (hub == null) return Stream.value(const []);
  return () async* {
    yield hub.current;
    yield* hub.views;
  }();
});

/// Wraps [base] when a hub is open (used by `sessionAudioSourceProvider`).
SessionAudioSource multiDeviceAwareSource(Ref ref, SessionAudioSource base) {
  final hub = ref.watch(multiDeviceHubProvider);
  if (hub == null) return base;
  final source = MultiDeviceSessionAudioSource(
    local: base,
    hub: hub,
    logStore: ref.watch(multiDeviceLogStoreProvider),
  );
  ref.onDispose(source.dispose);
  return source;
}

// ===========================================================================
// Guest
// ===========================================================================

/// Where and how to join.
class JoinTarget {
  /// Creates a target.
  const JoinTarget({
    required this.hosts,
    required this.port,
    required this.code,
  });

  /// From a scanned QR code.
  factory JoinTarget.fromInfo(JoinInfo info) =>
      JoinTarget(hosts: info.addresses, port: info.port, code: info.code);

  /// Host addresses to try in order.
  final List<String> hosts;

  /// Port.
  final int port;

  /// Normalised pairing code.
  final String code;
}

/// Connects to a host (overridable in tests).
typedef GuestConnector = Future<MultiDeviceGuest> Function({
  required JoinTarget target,
  required SecretKeyData key,
  required String guestId,
  required String name,
});

/// Derives the pairing key (overridable in tests).
final pairingKeyDeriverProvider =
    Provider<Future<SecretKeyData> Function(String code)>(
      (ref) =>
          (code) => derivePairingKey(code),
    );

/// Default connector.
final guestConnectorProvider = Provider<GuestConnector>(
  (ref) =>
      ({
        required JoinTarget target,
        required SecretKeyData key,
        required String guestId,
        required String name,
      }) => MultiDeviceGuest.connect(
        hosts: target.hosts,
        port: target.port,
        pairingKey: key,
        guestId: guestId,
        name: name,
        platform: currentPlatformId(),
      ),
);

/// Microphone of a guest device (not the system-audio mix).
final guestAudioSourceProvider = Provider<SessionAudioSource>(
  (ref) => ref.watch(deviceAwareAudioSourceProvider),
);

/// Battery of this device.
final batteryReaderProvider = Provider<BatteryReader>(
  (ref) => const BatteryReader(),
);

/// Guest lifecycle.
enum GuestPhase {
  /// Not joined.
  idle,

  /// Connecting.
  connecting,

  /// Joined; the host has not started recording.
  waiting,

  /// Recording and streaming.
  recording,

  /// The host paused.
  paused,

  /// The link dropped; retrying.
  reconnecting,

  /// The meeting ended.
  ended,

  /// The host removed this device.
  removed,

  /// Joining or reconnecting failed.
  failed,
}

/// Guest state.
class GuestSessionState {
  /// Creates a state.
  const GuestSessionState({
    this.phase = GuestPhase.idle,
    this.hostName = '',
    this.title = '',
    this.level = 0,
    this.messageAr,
  });

  /// Phase.
  final GuestPhase phase;

  /// Host device name.
  final String hostName;

  /// Meeting title.
  final String title;

  /// Input level 0..1.
  final double level;

  /// Arabic message (failure / warning).
  final String? messageAr;

  /// True while joined or trying to be.
  bool get isActive => switch (phase) {
    GuestPhase.connecting ||
    GuestPhase.waiting ||
    GuestPhase.recording ||
    GuestPhase.paused ||
    GuestPhase.reconnecting => true,
    _ => false,
  };

  /// Copy with changes.
  GuestSessionState copyWith({
    GuestPhase? phase,
    String? hostName,
    String? title,
    double? level,
    String? messageAr,
    bool clearMessage = false,
  }) => GuestSessionState(
    phase: phase ?? this.phase,
    hostName: hostName ?? this.hostName,
    title: title ?? this.title,
    level: level ?? this.level,
    messageAr: clearMessage ? null : (messageAr ?? this.messageAr),
  );
}

/// Guest controller. See the file header.
class GuestSessionController extends Notifier<GuestSessionState> {
  /// Stable id of this device for the app run (a returning guest keeps its
  /// channel on the host).
  static final String guestId = randomBase32(10);

  /// Reconnection attempts (every 2 s ≈ 3 minutes).
  static const int maxRetries = 90;

  MultiDeviceGuest? _guest;
  StreamSubscription<GuestClientEvent>? _eventsSub;
  final List<StreamSubscription<Object?>> _audioSubs = [];
  JoinTarget? _target;
  SecretKeyData? _key;
  String _name = '';
  SessionAudioSource? _audio;
  GuestAudioFramer _framer = GuestAudioFramer();
  bool _capturing = false;
  bool _hooksStarted = false;
  Timer? _statusTimer;
  Timer? _retryTimer;
  int _retries = 0;
  double _peakLevel = 0;
  SessionPlatformHooks? _hooks;

  @override
  GuestSessionState build() {
    ref.onDispose(() => unawaited(_teardown()));
    return const GuestSessionState();
  }

  void _set(GuestSessionState s) {
    if (ref.mounted) state = s;
  }

  /// Joins [target] as [name]. Returns false (with [GuestSessionState.messageAr])
  /// on failure.
  Future<bool> join(JoinTarget target, {String? name}) async {
    if (state.isActive) return false;
    if (ref.read(meetingSessionControllerProvider).isActive) {
      _set(
        const GuestSessionState(
          phase: GuestPhase.failed,
          messageAr: MS.busyRecording,
        ),
      );
      return false;
    }
    _set(const GuestSessionState(phase: GuestPhase.connecting));
    final audio = ref.read(guestAudioSourceProvider);
    final hooks = ref.read(sessionPlatformHooksProvider);
    _audio = audio;
    _hooks = hooks;
    try {
      await hooks.ensureMicrophonePermission(audio);
    } on InsatoException catch (e) {
      _set(GuestSessionState(phase: GuestPhase.failed, messageAr: e.messageAr));
      return false;
    }
    _target = target;
    _name = (name == null || name.trim().isEmpty)
        ? defaultDeviceName()
        : name.trim();
    _framer = GuestAudioFramer();
    _retries = 0;
    try {
      _key = await ref.read(pairingKeyDeriverProvider)(target.code);
      await _connect();
    } on JoinException catch (e) {
      await _teardown();
      _set(
        GuestSessionState(
          phase: GuestPhase.failed,
          messageAr: MS.joinFailure(e.failure),
        ),
      );
      return false;
    } catch (_) {
      await _teardown();
      _set(
        GuestSessionState(
          phase: GuestPhase.failed,
          messageAr: MS.joinFailure(JoinFailure.unreachable),
        ),
      );
      return false;
    }
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _sendStatus(),
    );
    return true;
  }

  Future<void> _connect() async {
    final g = await ref.read(guestConnectorProvider)(
      target: _target!,
      key: _key!,
      guestId: guestId,
      name: _name,
    );
    _guest = g;
    _set(state.copyWith(hostName: g.welcome.hostName, clearMessage: true));
    _eventsSub = g.events.listen(_onEvent);
    await _applyHostState(g.welcome.state, g.welcome.title);
    _sendStatus();
  }

  /// Leaves the meeting.
  Future<void> leave() async {
    await _teardown();
    _set(const GuestSessionState());
  }

  /// Clears a finished state (back to idle).
  void reset() {
    if (!state.isActive) _set(const GuestSessionState());
  }

  Future<void> _onEvent(GuestClientEvent e) async {
    switch (e) {
      case HostStateChanged(:final state, :final title):
        await _applyHostState(state, title);
      case GuestKicked():
        await _finish(GuestPhase.removed, MS.removed);
      case GuestConnectionLost(:final failure):
        _guest = null;
        await _eventsSub?.cancel();
        _eventsSub = null;
        if (failure != null) {
          await _finish(GuestPhase.failed, MS.joinFailure(failure));
        } else if (state.phase != GuestPhase.ended &&
            state.phase != GuestPhase.removed) {
          _startReconnecting();
        }
    }
  }

  Future<void> _applyHostState(String hostState, String title) async {
    if (title.isNotEmpty) _set(state.copyWith(title: title));
    switch (hostState) {
      case HostState.recording:
        await _startCapture();
        _set(state.copyWith(phase: GuestPhase.recording));
      case HostState.paused:
        if (_capturing) {
          try {
            await _audio?.pause();
          } catch (_) {
            // Keep going; the host ignores audio while paused.
          }
        }
        _set(state.copyWith(phase: GuestPhase.paused));
      case HostState.ended:
        await _finish(GuestPhase.ended, null);
      default:
        _set(state.copyWith(phase: GuestPhase.waiting));
    }
  }

  Future<void> _startCapture() async {
    final audio = _audio;
    if (audio == null) return;
    if (_capturing) {
      if (state.phase == GuestPhase.paused) {
        _framer.discontinuity();
        try {
          await audio.resume();
        } catch (_) {
          // Reported through the level staying at zero.
        }
      }
      return;
    }
    _audioSubs
      ..add(audio.frames.listen(_onFrame))
      ..add(
        audio.level.listen((l) {
          _peakLevel = l > _peakLevel ? l : _peakLevel;
          if (ref.mounted && state.isActive) _set(state.copyWith(level: l));
        }),
      );
    _hooksStarted = true;
    await _hooks?.onRecordingStarted(
      meetingTitle: state.title.isEmpty ? MS.guestNotification : state.title,
    );
    try {
      await audio.start();
      _capturing = true;
    } catch (e) {
      final msg = e is InsatoException
          ? e.messageAr
          : MS.joinFailure(JoinFailure.unreachable);
      await _finish(GuestPhase.failed, msg);
    }
  }

  void _onFrame(Float32List f) {
    final frames = _framer.add(f, MonotonicClock.instance.nowUs());
    final g = _guest;
    if (g == null || state.phase != GuestPhase.recording) return;
    for (final (start, us, samples) in frames) {
      g.sendAudio(startIndex: start, captureUs: us, samples: samples);
    }
  }

  void _sendStatus() {
    final g = _guest;
    if (g == null) return;
    final level = _peakLevel;
    _peakLevel = 0;
    unawaited(
      ref.read(batteryReaderProvider).read().then((b) {
        if (!identical(_guest, g)) return;
        g.sendStatus(
          GuestStatus(battery: b.level, charging: b.charging, level: level),
        );
      }),
    );
  }

  void _startReconnecting() {
    _set(state.copyWith(phase: GuestPhase.reconnecting));
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), _retry);
  }

  Future<void> _retry() async {
    if (state.phase != GuestPhase.reconnecting) return;
    if (++_retries > maxRetries) {
      await _finish(GuestPhase.failed, MS.gaveUp);
      return;
    }
    try {
      await _connect();
      _retries = 0;
    } on JoinException catch (e) {
      if (e.failure == JoinFailure.unreachable ||
          e.failure == JoinFailure.rejectedOrWrongCode) {
        _retryTimer = Timer(const Duration(seconds: 2), _retry);
      } else {
        await _finish(GuestPhase.failed, MS.joinFailure(e.failure));
      }
    } catch (_) {
      _retryTimer = Timer(const Duration(seconds: 2), _retry);
    }
  }

  Future<void> _finish(GuestPhase phase, String? messageAr) async {
    await _teardown();
    _set(
      GuestSessionState(
        phase: phase,
        hostName: state.hostName,
        title: state.title,
        messageAr: messageAr,
      ),
    );
  }

  Future<void> _teardown() async {
    _statusTimer?.cancel();
    _statusTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _eventsSub?.cancel();
    _eventsSub = null;
    final g = _guest;
    _guest = null;
    if (g != null) {
      try {
        await g.close();
      } catch (_) {
        // Already gone.
      }
    }
    if (_capturing) {
      _capturing = false;
      try {
        await _audio?.stop();
      } catch (_) {
        // Best effort.
      }
    }
    for (final s in _audioSubs) {
      await s.cancel();
    }
    _audioSubs.clear();
    if (_hooksStarted) {
      _hooksStarted = false;
      try {
        await _hooks?.onRecordingStopped();
      } catch (_) {
        // Best effort.
      }
    }
  }
}

/// The guest session.
final guestSessionControllerProvider =
    NotifierProvider<GuestSessionController, GuestSessionState>(
      GuestSessionController.new,
    );
