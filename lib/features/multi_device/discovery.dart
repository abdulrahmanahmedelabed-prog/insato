// LAN discovery of Insato hosts (v1.2 C) through mDNS / DNS-SD
// (package:bonsoir: Android NSD, Apple Bonjour, Windows DNS-SD), service
// type `_insato._tcp`. Discovery is a convenience only: a guest can always
// scan the QR code or type the address. Failures (multicast blocked by the
// network, permission refused) are swallowed and simply find nothing.

import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'protocol.dart';

/// A host found on the LAN.
class DiscoveredHost {
  /// Creates an entry.
  const DiscoveredHost({
    required this.name,
    required this.addresses,
    required this.port,
    this.sessionId = '',
  });

  /// Advertised name (host device).
  final String name;

  /// Resolved addresses.
  final List<String> addresses;

  /// Port.
  final int port;

  /// Session id from the TXT record.
  final String sessionId;

  /// `ip:port` of the first address.
  String get displayAddress =>
      addresses.isEmpty ? '' : formatHostPort(addresses.first, port);
}

/// Advertising and browsing (overridable in tests).
abstract class MultiDeviceDiscovery {
  /// Advertises [info] until [stopAdvertising].
  Future<void> advertise(JoinInfo info);

  /// Stops advertising.
  Future<void> stopAdvertising();

  /// Hosts currently visible; the stream ends when [stopBrowsing] is
  /// called.
  Stream<List<DiscoveredHost>> browse();

  /// Stops browsing.
  Future<void> stopBrowsing();
}

/// No discovery (tests, unsupported platforms).
class NoDiscovery implements MultiDeviceDiscovery {
  /// Creates the no-op.
  const NoDiscovery();
  @override
  Future<void> advertise(JoinInfo info) async {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  Stream<List<DiscoveredHost>> browse() => Stream.value(const []);
  @override
  Future<void> stopBrowsing() async {}
}

/// Bonsoir-backed discovery.
class BonsoirDiscoveryService implements MultiDeviceDiscovery {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamController<List<DiscoveredHost>>? _hosts;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;

  @override
  Future<void> advertise(JoinInfo info) async {
    await stopAdvertising();
    try {
      final b = BonsoirBroadcast(
        service: BonsoirService(
          name: info.hostName.isEmpty
              ? 'Insato ${info.sessionId}'
              : info.hostName,
          type: kMultiDeviceServiceType,
          port: info.port,
          attributes: {
            'sid': info.sessionId,
            'v': '$kMultiDeviceProtocolVersion',
          },
        ),
      );
      await b.initialize();
      await b.start();
      _broadcast = b;
    } catch (_) {
      // Multicast unavailable: QR / manual entry still work.
    }
  }

  @override
  Future<void> stopAdvertising() async {
    final b = _broadcast;
    _broadcast = null;
    try {
      await b?.stop();
    } catch (_) {
      // Already stopped.
    }
  }

  @override
  Stream<List<DiscoveredHost>> browse() {
    unawaited(stopBrowsing());
    final out = _hosts = StreamController<List<DiscoveredHost>>();
    final found = <String, DiscoveredHost>{};
    () async {
      try {
        final d = BonsoirDiscovery(type: kMultiDeviceServiceType);
        _discovery = d;
        await d.initialize();
        _sub = d.eventStream?.listen((e) {
          switch (e) {
            case BonsoirDiscoveryServiceFoundEvent():
              unawaited(
                e.service.resolve(d.serviceResolver).catchError((Object _) {}),
              );
            case BonsoirDiscoveryServiceResolvedEvent():
            case BonsoirDiscoveryServiceUpdatedEvent():
              final s = e.service!;
              if (s.hostAddresses.isEmpty) return;
              found[s.name] = DiscoveredHost(
                name: s.name,
                addresses: [
                  ...s.hostAddresses.where((a) => !a.contains(':')),
                  ...s.hostAddresses.where((a) => a.contains(':')),
                ],
                port: s.port,
                sessionId: s.attributes['sid'] ?? '',
              );
              if (!out.isClosed) out.add(found.values.toList());
            case BonsoirDiscoveryServiceLostEvent():
              found.remove(e.service.name);
              if (!out.isClosed) out.add(found.values.toList());
            default:
              break;
          }
        });
        await d.start();
      } catch (_) {
        if (!out.isClosed) out.add(const []);
      }
    }();
    return out.stream;
  }

  @override
  Future<void> stopBrowsing() async {
    await _sub?.cancel();
    _sub = null;
    final d = _discovery;
    _discovery = null;
    try {
      await d?.stop();
    } catch (_) {
      // Already stopped.
    }
    final h = _hosts;
    _hosts = null;
    if (h != null && !h.isClosed) unawaited(h.close());
  }
}
