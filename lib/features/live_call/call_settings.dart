// Live Insato call (v1.2): settings — signaling relay URL, optional TURN
// server, relay-only mode, device name and the call consent acknowledgement.
//
// Stored as JSON in the settings table (`live_call_settings`); the TURN
// credential is a secret and lives in secure storage only.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/database.dart';
import '../../data/repositories.dart' show databaseProvider;
import '../../data/secure_settings.dart' show SecureSettings;
import 'call_code.dart' show normalizeSignalingUrl;
import 'peer_transport.dart';

/// Settings key.
const String kLiveCallSettingsKey = 'live_call_settings';

/// Relay URL baked into a build (`--dart-define=INSATO_SIGNALING_URL=wss://…`)
/// so a distributor can ship a ready relay; '' when none.
const String kBuiltInSignalingUrl = String.fromEnvironment(
  'INSATO_SIGNALING_URL',
);

/// Live-call settings.
class LiveCallSettings {
  /// Creates settings.
  const LiveCallSettings({
    this.signalingUrl = '',
    this.turnUrl = '',
    this.turnUsername = '',
    this.relayOnly = false,
    this.deviceName = '',
    this.consentAcknowledged = false,
  });

  /// Relay URL typed by the user ('' = the built-in one, if any).
  final String signalingUrl;

  /// TURN URL(s), comma separated (`turn:host:3478`, `turns:host:5349`).
  final String turnUrl;

  /// TURN user name.
  final String turnUsername;

  /// Use only TURN (hides each side's IP address from the other).
  final bool relayOnly;

  /// Name shown to the other side ('' = the device's name).
  final String deviceName;

  /// The live-call consent notice was acknowledged.
  final bool consentAcknowledged;

  /// The relay to use, normalised; null when none is configured.
  String? get effectiveSignalingUrl =>
      normalizeSignalingUrl(signalingUrl) ??
      normalizeSignalingUrl(kBuiltInSignalingUrl);

  /// TURN URLs (valid `turn:` / `turns:` entries only).
  List<String> get turnUrls => [
    for (final u in turnUrl.split(RegExp(r'[,\s]+')))
      if (u.startsWith('turn:') || u.startsWith('turns:')) u,
  ];

  /// Copy with changes.
  LiveCallSettings copyWith({
    String? signalingUrl,
    String? turnUrl,
    String? turnUsername,
    bool? relayOnly,
    String? deviceName,
    bool? consentAcknowledged,
  }) => LiveCallSettings(
    signalingUrl: signalingUrl ?? this.signalingUrl,
    turnUrl: turnUrl ?? this.turnUrl,
    turnUsername: turnUsername ?? this.turnUsername,
    relayOnly: relayOnly ?? this.relayOnly,
    deviceName: deviceName ?? this.deviceName,
    consentAcknowledged: consentAcknowledged ?? this.consentAcknowledged,
  );

  /// JSON form.
  Map<String, Object?> toJson() => {
    'signalingUrl': signalingUrl,
    'turnUrl': turnUrl,
    'turnUsername': turnUsername,
    'relayOnly': relayOnly,
    'deviceName': deviceName,
    'consent': consentAcknowledged,
  };

  /// Parses [toJson] output (defaults for anything missing).
  static LiveCallSettings fromJson(Object? j) {
    if (j is! Map) return const LiveCallSettings();
    String s(String k) => j[k] is String ? j[k] as String : '';
    return LiveCallSettings(
      signalingUrl: s('signalingUrl'),
      turnUrl: s('turnUrl'),
      turnUsername: s('turnUsername'),
      relayOnly: j['relayOnly'] == true,
      deviceName: s('deviceName'),
      consentAcknowledged: j['consent'] == true,
    );
  }
}

/// The WebRTC configuration of [s]: the public STUN server, plus TURN when
/// configured (with [turnCredential]).
PeerConfig peerConfigFor(LiveCallSettings s, {String? turnCredential}) {
  final turn = s.turnUrls;
  return PeerConfig(
    iceServers: [
      const IceServerConfig(urls: [kDefaultStunUrl]),
      if (turn.isNotEmpty)
        IceServerConfig(
          urls: turn,
          username: s.turnUsername.trim(),
          credential: turnCredential,
        ),
    ],
    relayOnly: s.relayOnly && turn.isNotEmpty,
  );
}

/// Secret storage of the TURN credential.
abstract class TurnCredentialStore {
  /// The credential, or null.
  Future<String?> read();

  /// Saves (null / empty: deletes) the credential.
  Future<void> write(String? value);
}

/// [TurnCredentialStore] in the platform keystore.
class SecureTurnCredentialStore implements TurnCredentialStore {
  /// Creates the store.
  const SecureTurnCredentialStore([
    this._storage = SecureSettings.defaultStorage,
  ]);

  final FlutterSecureStorage _storage;

  static const String _key = 'insato.live_call_turn_credential';

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String? value) async {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: v);
    }
  }
}

/// In-memory [TurnCredentialStore] (tests).
class MemoryTurnCredentialStore implements TurnCredentialStore {
  /// The stored value.
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? v) async =>
      value = (v == null || v.trim().isEmpty) ? null : v.trim();
}

/// Settings persistence.
class LiveCallSettingsStore {
  /// Creates the store.
  LiveCallSettingsStore(this._db);

  final AppDatabase _db;

  /// Loads the settings (defaults when absent or unreadable).
  Future<LiveCallSettings> load() async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(kLiveCallSettingsKey))).getSingleOrNull();
    if (row == null) return const LiveCallSettings();
    try {
      return LiveCallSettings.fromJson(jsonDecode(row.value));
    } on FormatException {
      return const LiveCallSettings();
    }
  }

  /// Saves [s].
  Future<void> save(LiveCallSettings s) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion(
          key: const Value(kLiveCallSettingsKey),
          value: Value(jsonEncode(s.toJson())),
        ),
      );

  /// Watches the settings.
  Stream<LiveCallSettings> watch() =>
      (_db.select(_db.settings)
            ..where((t) => t.key.equals(kLiveCallSettingsKey)))
          .watchSingleOrNull()
          .map((r) {
            if (r == null) return const LiveCallSettings();
            try {
              return LiveCallSettings.fromJson(jsonDecode(r.value));
            } on FormatException {
              return const LiveCallSettings();
            }
          });
}

/// The settings store.
final liveCallSettingsStoreProvider = Provider<LiveCallSettingsStore>(
  (ref) => LiveCallSettingsStore(ref.watch(databaseProvider)),
);

/// Live settings.
final liveCallSettingsProvider = StreamProvider<LiveCallSettings>(
  (ref) => ref.watch(liveCallSettingsStoreProvider).watch(),
);

/// TURN credential storage.
final turnCredentialStoreProvider = Provider<TurnCredentialStore>(
  (ref) => const SecureTurnCredentialStore(),
);
