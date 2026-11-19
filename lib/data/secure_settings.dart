// Settings storage.
//
// * [SecureSettings]: API keys, kept only in the platform keystore/keychain
//   (Android Keystore, iOS Keychain, Windows Credential Manager via
//   flutter_secure_storage). Never written to the SQLite database.
// * [AppSettings]: non-secret preferences in the `settings` table, exposed as
//   an immutable [AppSettingsData] snapshot and a change stream.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database.dart';
import 'repositories.dart';

// ---------------------------------------------------------------------------
// Secure settings (API keys)
// ---------------------------------------------------------------------------

/// API keys stored in the platform's secure storage.
class SecureSettings {
  /// Creates the store. [storage] can be injected for tests.
  SecureSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Secure-storage key of the Anthropic (Claude) API key.
  static const String anthropicApiKeyKey = 'insato.anthropic_api_key';

  /// Secure-storage key of the Deepgram API key.
  static const String deepgramApiKeyKey = 'insato.deepgram_api_key';

  Future<String?> _read(String key) async {
    try {
      final v = await _storage.read(key: key);
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    } on PlatformException {
      // A corrupted or reset keystore entry is equivalent to "no key": the
      // user is asked to enter it again instead of the app failing.
      return null;
    }
  }

  Future<void> _write(String key, String? value) async {
    final t = value?.trim();
    if (t == null || t.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: t);
    }
  }

  /// The Anthropic API key, or null when not configured.
  Future<String?> getAnthropicApiKey() => _read(anthropicApiKeyKey);

  /// Stores the Anthropic API key (trimmed). A blank value clears it.
  Future<void> setAnthropicApiKey(String key) => _write(anthropicApiKeyKey, key);

  /// Removes the Anthropic API key.
  Future<void> clearAnthropicApiKey() => _write(anthropicApiKeyKey, null);

  /// The Deepgram API key, or null when not configured.
  Future<String?> getDeepgramApiKey() => _read(deepgramApiKeyKey);

  /// Stores the Deepgram API key (trimmed). A blank value clears it.
  Future<void> setDeepgramApiKey(String key) => _write(deepgramApiKeyKey, key);

  /// Removes the Deepgram API key.
  Future<void> clearDeepgramApiKey() => _write(deepgramApiKeyKey, null);
}

// ---------------------------------------------------------------------------
// App settings (non-secret preferences)
// ---------------------------------------------------------------------------

/// Immutable snapshot of all app preferences.
class AppSettingsData {
  /// Creates a snapshot; every field defaults to the app default.
  const AppSettingsData({
    this.asrEngine = asrLocal,
    this.whisperModelId = defaultWhisperModelId,
    this.languageHint,
    this.keepAudio = true,
    this.matchThreshold = defaultMatchThreshold,
    this.consentAcknowledged = false,
    this.minutesDetail = detailDetailed,
    this.claudeModel = defaultClaudeModel,
  });

  /// [asrEngine] value for on-device recognition (sherpa-onnx Whisper).
  static const String asrLocal = 'local';

  /// [asrEngine] value for cloud recognition (Deepgram).
  static const String asrCloud = 'cloud';

  /// Allowed [asrEngine] values.
  static const List<String> asrEngines = [asrLocal, asrCloud];

  /// [minutesDetail] value for detailed minutes.
  static const String detailDetailed = 'detailed';

  /// [minutesDetail] value for concise minutes.
  static const String detailConcise = 'concise';

  /// Allowed [minutesDetail] values.
  static const List<String> minutesDetails = [detailDetailed, detailConcise];

  /// Default on-device Whisper model id.
  static const String defaultWhisperModelId = 'whisper-turbo';

  /// Default voice match threshold (cosine similarity).
  static const double defaultMatchThreshold = 0.55;

  /// Default Claude model used for minutes.
  static const String defaultClaudeModel = 'claude-opus-5-5';

  /// All defaults.
  static const AppSettingsData defaults = AppSettingsData();

  /// `'local'` (on-device) or `'cloud'`.
  final String asrEngine;

  /// Id of the on-device Whisper model (see speech/model_catalog.dart).
  final String whisperModelId;

  /// ISO-639-1 language hint for ASR; null means auto-detect.
  final String? languageHint;

  /// Whether to keep the WAV recording after processing.
  final bool keepAudio;

  /// Cosine similarity threshold (0..1) for matching a voice to a speaker.
  final double matchThreshold;

  /// Whether the user acknowledged the recording-consent reminder.
  final bool consentAcknowledged;

  /// `'detailed'` or `'concise'`.
  final String minutesDetail;

  /// Claude model id used to generate minutes.
  final String claudeModel;

  /// True when on-device ASR is selected.
  bool get usesLocalAsr => asrEngine == asrLocal;

  /// True when concise minutes are selected.
  bool get conciseMinutes => minutesDetail == detailConcise;

  /// Returns a copy with the given fields replaced. Pass
  /// [clearLanguageHint] to switch back to auto-detect.
  AppSettingsData copyWith({
    String? asrEngine,
    String? whisperModelId,
    String? languageHint,
    bool clearLanguageHint = false,
    bool? keepAudio,
    double? matchThreshold,
    bool? consentAcknowledged,
    String? minutesDetail,
    String? claudeModel,
  }) {
    return AppSettingsData(
      asrEngine: asrEngine ?? this.asrEngine,
      whisperModelId: whisperModelId ?? this.whisperModelId,
      languageHint:
          clearLanguageHint ? null : (languageHint ?? this.languageHint),
      keepAudio: keepAudio ?? this.keepAudio,
      matchThreshold: matchThreshold ?? this.matchThreshold,
      consentAcknowledged: consentAcknowledged ?? this.consentAcknowledged,
      minutesDetail: minutesDetail ?? this.minutesDetail,
      claudeModel: claudeModel ?? this.claudeModel,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettingsData &&
      other.asrEngine == asrEngine &&
      other.whisperModelId == whisperModelId &&
      other.languageHint == languageHint &&
      other.keepAudio == keepAudio &&
      other.matchThreshold == matchThreshold &&
      other.consentAcknowledged == consentAcknowledged &&
      other.minutesDetail == minutesDetail &&
      other.claudeModel == claudeModel;

  @override
  int get hashCode => Object.hash(
        asrEngine,
        whisperModelId,
        languageHint,
        keepAudio,
        matchThreshold,
        consentAcknowledged,
        minutesDetail,
        claudeModel,
      );

  @override
  String toString() => 'AppSettingsData(asrEngine: $asrEngine, '
      'whisperModelId: $whisperModelId, languageHint: $languageHint, '
      'keepAudio: $keepAudio, matchThreshold: $matchThreshold, '
      'consentAcknowledged: $consentAcknowledged, '
      'minutesDetail: $minutesDetail, claudeModel: $claudeModel)';

  /// Builds a snapshot from raw `settings` table values, falling back to the
  /// default for any missing or invalid entry.
  factory AppSettingsData.fromMap(Map<String, String> m) {
    String choice(String key, List<String> allowed, String def) {
      final v = m[key]?.trim();
      return (v != null && allowed.contains(v)) ? v : def;
    }

    String nonEmpty(String key, String def) {
      final v = m[key]?.trim();
      return (v == null || v.isEmpty) ? def : v;
    }

    bool flag(String key, bool def) => switch (m[key]?.trim()) {
          'true' || '1' => true,
          'false' || '0' => false,
          _ => def,
        };

    final threshold = double.tryParse(m[AppSettings.kMatchThreshold] ?? '');
    return AppSettingsData(
      asrEngine: choice(AppSettings.kAsrEngine, asrEngines, asrLocal),
      whisperModelId:
          nonEmpty(AppSettings.kWhisperModelId, defaultWhisperModelId),
      languageHint: normalizeLanguageHint(m[AppSettings.kLanguageHint]),
      keepAudio: flag(AppSettings.kKeepAudio, true),
      matchThreshold: (threshold != null && isValidThreshold(threshold))
          ? threshold
          : defaultMatchThreshold,
      consentAcknowledged: flag(AppSettings.kConsentAcknowledged, false),
      minutesDetail:
          choice(AppSettings.kMinutesDetail, minutesDetails, detailDetailed),
      claudeModel: nonEmpty(AppSettings.kClaudeModel, defaultClaudeModel),
    );
  }

  /// Raw `settings` table values for this snapshot. A null [languageHint] is
  /// omitted (absent row = auto-detect).
  Map<String, String> toMap() => {
        AppSettings.kAsrEngine: asrEngine,
        AppSettings.kWhisperModelId: whisperModelId,
        AppSettings.kLanguageHint: ?languageHint,
        AppSettings.kKeepAudio: keepAudio.toString(),
        AppSettings.kMatchThreshold: matchThreshold.toString(),
        AppSettings.kConsentAcknowledged: consentAcknowledged.toString(),
        AppSettings.kMinutesDetail: minutesDetail,
        AppSettings.kClaudeModel: claudeModel,
      };

  /// Normalises a language hint: trimmed lowercase ISO-639 code, or null for
  /// blank / `auto`.
  static String? normalizeLanguageHint(String? hint) {
    final t = hint?.trim().toLowerCase();
    if (t == null || t.isEmpty || t == 'auto') return null;
    return t;
  }

  /// True for a finite threshold in the open interval (0, 1).
  static bool isValidThreshold(double v) => v.isFinite && v > 0 && v < 1;
}

/// Non-secret preferences persisted in the `settings` table.
class AppSettings {
  /// Creates the store over [db].
  AppSettings(this._db);

  final AppDatabase _db;

  /// Settings-table key for [AppSettingsData.asrEngine].
  static const String kAsrEngine = 'asr_engine';

  /// Settings-table key for [AppSettingsData.whisperModelId].
  static const String kWhisperModelId = 'whisper_model_id';

  /// Settings-table key for [AppSettingsData.languageHint].
  static const String kLanguageHint = 'language_hint';

  /// Settings-table key for [AppSettingsData.keepAudio].
  static const String kKeepAudio = 'keep_audio';

  /// Settings-table key for [AppSettingsData.matchThreshold].
  static const String kMatchThreshold = 'match_threshold';

  /// Settings-table key for [AppSettingsData.consentAcknowledged].
  static const String kConsentAcknowledged = 'consent_acknowledged';

  /// Settings-table key for [AppSettingsData.minutesDetail].
  static const String kMinutesDetail = 'minutes_detail';

  /// Settings-table key for [AppSettingsData.claudeModel].
  static const String kClaudeModel = 'claude_model';

  static AppSettingsData _fromRows(List<SettingRow> rows) =>
      AppSettingsData.fromMap({for (final r in rows) r.key: r.value});

  /// Current settings snapshot.
  Future<AppSettingsData> load() async =>
      _fromRows(await _db.select(_db.settings).get());

  /// Settings snapshots, emitted now and after every distinct change.
  Stream<AppSettingsData> watch() =>
      _db.select(_db.settings).watch().map(_fromRows).distinct();

  /// Persists every field of [data] in one transaction.
  Future<void> save(AppSettingsData data) => _db.transaction(() async {
        final map = data.toMap();
        for (final e in map.entries) {
          await _put(e.key, e.value);
        }
        if (!map.containsKey(kLanguageHint)) await _remove(kLanguageHint);
      });

  Future<void> _put(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> _remove(String key) =>
      (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();

  /// Selected ASR engine (`'local'` or `'cloud'`).
  Future<String> get asrEngine async => (await load()).asrEngine;

  /// Selects the ASR engine. Throws [ArgumentError] for unknown values.
  Future<void> setAsrEngine(String engine) {
    if (!AppSettingsData.asrEngines.contains(engine)) {
      throw ArgumentError.value(engine, 'engine', 'must be local or cloud');
    }
    return _put(kAsrEngine, engine);
  }

  /// Selected on-device Whisper model id.
  Future<String> get whisperModelId async => (await load()).whisperModelId;

  /// Selects the on-device Whisper model. Throws [ArgumentError] when blank.
  Future<void> setWhisperModelId(String id) {
    final t = id.trim();
    if (t.isEmpty) throw ArgumentError.value(id, 'id', 'must not be blank');
    return _put(kWhisperModelId, t);
  }

  /// ASR language hint (null = auto-detect).
  Future<String?> get languageHint async => (await load()).languageHint;

  /// Sets the ASR language hint; null, blank or `auto` means auto-detect.
  Future<void> setLanguageHint(String? hint) {
    final n = AppSettingsData.normalizeLanguageHint(hint);
    return n == null ? _remove(kLanguageHint) : _put(kLanguageHint, n);
  }

  /// Whether recordings are kept after processing.
  Future<bool> get keepAudio async => (await load()).keepAudio;

  /// Sets whether recordings are kept after processing.
  Future<void> setKeepAudio(bool keep) => _put(kKeepAudio, keep.toString());

  /// Voice match threshold (cosine similarity).
  Future<double> get matchThreshold async => (await load()).matchThreshold;

  /// Sets the voice match threshold. Throws [ArgumentError] outside (0, 1).
  Future<void> setMatchThreshold(double v) {
    if (!AppSettingsData.isValidThreshold(v)) {
      throw ArgumentError.value(v, 'v', 'must be in (0, 1)');
    }
    return _put(kMatchThreshold, v.toString());
  }

  /// Whether the recording-consent reminder was acknowledged.
  Future<bool> get consentAcknowledged async =>
      (await load()).consentAcknowledged;

  /// Records whether the recording-consent reminder was acknowledged.
  Future<void> setConsentAcknowledged(bool v) =>
      _put(kConsentAcknowledged, v.toString());

  /// Minutes detail level (`'detailed'` or `'concise'`).
  Future<String> get minutesDetail async => (await load()).minutesDetail;

  /// Sets the minutes detail level. Throws [ArgumentError] for unknown values.
  Future<void> setMinutesDetail(String detail) {
    if (!AppSettingsData.minutesDetails.contains(detail)) {
      throw ArgumentError.value(
          detail, 'detail', 'must be detailed or concise');
    }
    return _put(kMinutesDetail, detail);
  }

  /// Claude model id used for minutes.
  Future<String> get claudeModel async => (await load()).claudeModel;

  /// Sets the Claude model id. Throws [ArgumentError] when blank.
  Future<void> setClaudeModel(String model) {
    final t = model.trim();
    if (t.isEmpty) {
      throw ArgumentError.value(model, 'model', 'must not be blank');
    }
    return _put(kClaudeModel, t);
  }

  /// Removes all stored preferences (back to defaults).
  Future<void> resetToDefaults() => _db.delete(_db.settings).go();
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Secure API-key storage.
final secureSettingsProvider =
    Provider<SecureSettings>((ref) => SecureSettings());

/// Preference store over [databaseProvider].
final appSettingsProvider =
    Provider<AppSettings>((ref) => AppSettings(ref.watch(databaseProvider)));

/// Live [AppSettingsData] snapshot.
final appSettingsDataProvider = StreamProvider<AppSettingsData>(
    (ref) => ref.watch(appSettingsProvider).watch());
