// Settings storage.
//
// * [SecureSettings]: API keys, kept only in platform secure storage via
//   flutter_secure_storage (Android Keystore-backed encryption, iOS
//   Keychain, a DPAPI-encrypted file in %APPDATA%\Insato\Insato on
//   Windows). Never written to the SQLite database.
// * [AppSettings]: non-secret preferences in the `settings` table, exposed as
//   an immutable [AppSettingsData] snapshot and a change stream.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/errors.dart';
import 'database.dart';
import 'repositories.dart';

// ---------------------------------------------------------------------------
// Secure settings (API keys)
// ---------------------------------------------------------------------------

/// The platform keystore could not be read (for example the iOS keychain
/// while the device is locked). Distinct from "no key configured": the key
/// may well exist, so callers should retry or postpone rather than ask the
/// user to enter it again.
class SecureStorageUnavailableException extends InsatoException {
  const SecureStorageUnavailableException(super.messageAr,
      {super.debugDetails, super.cause});
}

/// API keys stored in the platform's secure storage.
class SecureSettings {
  /// Creates the store. [storage] can be injected for tests.
  SecureSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? defaultStorage;

  /// The storage used by default.
  ///
  /// On iOS the keychain items use `kSecAttrAccessibleAfterFirstUnlock-
  /// ThisDeviceOnly`: they stay readable while the phone is locked (a
  /// recording continues in the background with the screen off, and cloud
  /// ASR / minutes need the keys then), and they never migrate to another
  /// device (a backup restores them only onto the same device). The plugin
  /// default (`WhenUnlocked`) fails every read while the device is locked and
  /// lets the keys travel to a new device in encrypted backups. Not synchronizable (iCloud Keychain).
  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  final FlutterSecureStorage _storage;

  /// Last value read from or written to the keystore in this process, per
  /// key (null value = known to be absent). Used when a later read fails
  /// transiently (e.g. a locked device), so a running meeting keeps working.
  final Map<String, String?> _lastKnown = {};

  /// Secure-storage key of the Anthropic (Claude) API key.
  static const String anthropicApiKeyKey = 'insato.anthropic_api_key';

  /// Secure-storage key of the Deepgram API key.
  static const String deepgramApiKeyKey = 'insato.deepgram_api_key';

  /// Secure-storage key of the Google Gemini API key (free from Google AI
  /// Studio, aistudio.google.com/apikey).
  static const String geminiApiKeyKey = 'insato.gemini_api_key';

  /// Marker written once [migrateAccessibility] has rewritten the keys.
  static const String accessibilityMigratedKey =
      'insato.keychain_accessibility_v1';

  Future<String?> _read(String key) async {
    try {
      final v = await _storage.read(key: key);
      final t = v?.trim();
      final out = (t == null || t.isEmpty) ? null : t;
      _lastKnown[key] = out;
      return out;
    } on PlatformException catch (e) {
      // A missing item is reported as null, never as an exception: an error
      // means the keystore could not be read (iOS: errSecInteractionNotAllowed
      // while locked). That is not "no key": fall back to the value seen
      // earlier in this process, or report the failure distinctly.
      if (_lastKnown.containsKey(key)) return _lastKnown[key];
      throw SecureStorageUnavailableException(
        'تعذّرت قراءة المفاتيح المحفوظة الآن. افتح قفل الجهاز وحاول مجددًا.',
        debugDetails: 'secure storage read failed: ${e.code} ${e.message}',
        cause: e,
      );
    }
  }

  /// Rewrites stored keys once so that items created with an older keychain
  /// accessibility class (the plugin default `WhenUnlocked`) get the class of
  /// [defaultStorage]. Changing the option does not touch existing items;
  /// the plugin's write deletes the old item and re-adds it with the new
  /// class. Call at app start while in the foreground (device unlocked).
  /// Never throws: on failure it is retried at the next launch.
  Future<void> migrateAccessibility() async {
    try {
      if (await _storage.read(key: accessibilityMigratedKey) != null) return;
      for (final k in [anthropicApiKeyKey, deepgramApiKeyKey, geminiApiKeyKey]) {
        final v = await _storage.read(key: k);
        if (v != null && v.trim().isNotEmpty) {
          await _storage.write(key: k, value: v);
        }
      }
      await _storage.write(key: accessibilityMigratedKey, value: '1');
    } on PlatformException {
      // Locked or unavailable keystore: try again next launch.
    }
  }

  Future<void> _write(String key, String? value) async {
    final t = value?.trim();
    if (t == null || t.isEmpty) {
      await _storage.delete(key: key);
      _lastKnown[key] = null;
    } else {
      await _storage.write(key: key, value: t);
      _lastKnown[key] = t;
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

  /// The Google Gemini API key, or null when not configured.
  Future<String?> getGeminiApiKey() => _read(geminiApiKeyKey);

  /// Stores the Gemini API key (trimmed). A blank value clears it.
  Future<void> setGeminiApiKey(String key) => _write(geminiApiKeyKey, key);

  /// Removes the Gemini API key.
  Future<void> clearGeminiApiKey() => _write(geminiApiKeyKey, null);
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
    this.minutesEngine = engineGemini,
    this.geminiModel = defaultGeminiModel,
    this.geminiPrivacyAcknowledged = false,
    this.localLlmModelId,
    this.serverUrl = defaultServerUrl,
    this.serverModel,
    this.audioSource = audioSourceBoth,
    this.inputDeviceId,
    this.farFieldMode = false,
    this.profilesFeatureAcknowledged = false,
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

  /// [minutesEngine] value: Google Gemini API (free tier by default).
  static const String engineGemini = 'gemini';

  /// [minutesEngine] value: Anthropic Claude API.
  static const String engineClaude = 'claude';

  /// [minutesEngine] value: on-device GGUF model (F14).
  static const String engineLocal = 'local';

  /// [minutesEngine] value: local network server, Ollama / LM Studio (F14).
  static const String engineServer = 'server';

  /// Allowed [minutesEngine] values.
  static const List<String> minutesEngines = [
    engineGemini,
    engineClaude,
    engineLocal,
    engineServer,
  ];

  /// [audioSource] value: microphone only.
  static const String audioSourceMic = 'mic';

  /// [audioSource] value: system audio (WASAPI loopback) only.
  static const String audioSourceSystem = 'system';

  /// [audioSource] value: microphone mixed with system audio.
  static const String audioSourceBoth = 'both';

  /// Allowed [audioSource] values.
  static const List<String> audioSources = [
    audioSourceMic,
    audioSourceSystem,
    audioSourceBoth,
  ];

  /// Default on-device Whisper model id.
  static const String defaultWhisperModelId = 'whisper-turbo';

  /// Default voice match threshold (cosine similarity).
  static const double defaultMatchThreshold = 0.55;

  /// Default Claude model used for minutes.
  static const String defaultClaudeModel = 'claude-opus-5-5';

  /// Default Gemini model: Google's alias of the newest stable Flash-Lite model
  /// (available on the free tier). When an account lacks it, the engine
  /// discovers a Flash model through `models.list` (see `gemini_client.dart`).
  static const String defaultGeminiModel = 'gemini-flash-lite-latest';

  /// Default local-server endpoint (Ollama's default port on this machine).
  static const String defaultServerUrl = 'http://127.0.0.1:11434';

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

  /// Claude model id used to generate minutes (engine `claude`).
  final String claudeModel;

  /// Minutes engine (F14): [engineGemini] (default), [engineClaude],
  /// [engineLocal] or [engineServer]. Also used by "Ask your meetings" (F8).
  final String minutesEngine;

  /// Gemini model id (engine `gemini`), e.g. `gemini-flash-lite-latest`.
  final String geminiModel;

  /// The user read and accepted the Gemini free-tier data notice (Google
  /// may use free-tier prompts and responses to improve its products, and
  /// human reviewers may read them). Nothing is sent to Gemini before this.
  final bool geminiPrivacyAcknowledged;

  /// Catalog id of the on-device GGUF model (engine `local`); null = the
  /// catalog's recommended model.
  final String? localLlmModelId;

  /// Base URL of the local-network server (engine `server`).
  final String serverUrl;

  /// Model name on the local server (engine `server`); null = not chosen.
  final String? serverModel;

  /// Windows only (F13): what to record — [audioSourceMic],
  /// [audioSourceSystem] or [audioSourceBoth] (default). Ignored on
  /// Android / iOS, which always record the microphone.
  final String audioSource;

  /// Input device id chosen by the user (F18); null = system default.
  final String? inputDeviceId;

  /// Far-field "meeting room" profile (F18): automatic gain and noise
  /// suppression where supported, VAD tuned for distant speech.
  final bool farFieldMode;

  /// The user read the speaker-profiles notice (F16; profiles are still
  /// opt-in per speaker).
  final bool profilesFeatureAcknowledged;

  /// True when on-device ASR is selected.
  bool get usesLocalAsr => asrEngine == asrLocal;

  /// True when concise minutes are selected.
  bool get conciseMinutes => minutesDetail == detailConcise;

  /// True when the selected minutes engine sends the transcript off the
  /// device to a cloud provider (Gemini or Claude).
  bool get minutesEngineIsCloud =>
      minutesEngine == engineGemini || minutesEngine == engineClaude;

  /// Returns a copy with the given fields replaced. The `clear*` flags
  /// reset nullable fields to null ([clearLanguageHint] = auto-detect).
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
    String? minutesEngine,
    String? geminiModel,
    bool? geminiPrivacyAcknowledged,
    String? localLlmModelId,
    bool clearLocalLlmModelId = false,
    String? serverUrl,
    String? serverModel,
    bool clearServerModel = false,
    String? audioSource,
    String? inputDeviceId,
    bool clearInputDeviceId = false,
    bool? farFieldMode,
    bool? profilesFeatureAcknowledged,
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
      minutesEngine: minutesEngine ?? this.minutesEngine,
      geminiModel: geminiModel ?? this.geminiModel,
      geminiPrivacyAcknowledged:
          geminiPrivacyAcknowledged ?? this.geminiPrivacyAcknowledged,
      localLlmModelId: clearLocalLlmModelId
          ? null
          : (localLlmModelId ?? this.localLlmModelId),
      serverUrl: serverUrl ?? this.serverUrl,
      serverModel: clearServerModel ? null : (serverModel ?? this.serverModel),
      audioSource: audioSource ?? this.audioSource,
      inputDeviceId:
          clearInputDeviceId ? null : (inputDeviceId ?? this.inputDeviceId),
      farFieldMode: farFieldMode ?? this.farFieldMode,
      profilesFeatureAcknowledged:
          profilesFeatureAcknowledged ?? this.profilesFeatureAcknowledged,
    );
  }

  List<Object?> get _fields => [
        asrEngine,
        whisperModelId,
        languageHint,
        keepAudio,
        matchThreshold,
        consentAcknowledged,
        minutesDetail,
        claudeModel,
        minutesEngine,
        geminiModel,
        geminiPrivacyAcknowledged,
        localLlmModelId,
        serverUrl,
        serverModel,
        audioSource,
        inputDeviceId,
        farFieldMode,
        profilesFeatureAcknowledged,
      ];

  @override
  bool operator ==(Object other) {
    if (other is! AppSettingsData) return false;
    final a = _fields;
    final b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);

  @override
  String toString() => 'AppSettingsData(asrEngine: $asrEngine, '
      'whisperModelId: $whisperModelId, languageHint: $languageHint, '
      'keepAudio: $keepAudio, matchThreshold: $matchThreshold, '
      'consentAcknowledged: $consentAcknowledged, '
      'minutesDetail: $minutesDetail, claudeModel: $claudeModel, '
      'minutesEngine: $minutesEngine, geminiModel: $geminiModel, '
      'geminiPrivacyAcknowledged: $geminiPrivacyAcknowledged, '
      'localLlmModelId: $localLlmModelId, serverUrl: $serverUrl, '
      'serverModel: $serverModel, audioSource: $audioSource, '
      'inputDeviceId: $inputDeviceId, farFieldMode: $farFieldMode, '
      'profilesFeatureAcknowledged: $profilesFeatureAcknowledged)';

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

    String? optional(String key) {
      final v = m[key]?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    bool flag(String key, bool def) => switch (m[key]?.trim()) {
          'true' || '1' => true,
          'false' || '0' => false,
          _ => def,
        };

    final threshold = double.tryParse(m[AppSettings.kMatchThreshold] ?? '');
    final server = normalizeServerUrl(m[AppSettings.kServerUrl]);
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
      minutesEngine:
          choice(AppSettings.kMinutesEngine, minutesEngines, engineGemini),
      geminiModel: normalizeGeminiModel(m[AppSettings.kGeminiModel]) ??
          defaultGeminiModel,
      geminiPrivacyAcknowledged:
          flag(AppSettings.kGeminiPrivacyAcknowledged, false),
      localLlmModelId: optional(AppSettings.kLocalLlmModelId),
      serverUrl: server ?? defaultServerUrl,
      serverModel: optional(AppSettings.kServerModel),
      audioSource:
          choice(AppSettings.kAudioSource, audioSources, audioSourceBoth),
      inputDeviceId: optional(AppSettings.kInputDeviceId),
      farFieldMode: flag(AppSettings.kFarFieldMode, false),
      profilesFeatureAcknowledged:
          flag(AppSettings.kProfilesFeatureAcknowledged, false),
    );
  }

  /// Raw `settings` table values for this snapshot. Null optional fields
  /// are omitted (absent row = default).
  Map<String, String> toMap() => {
        AppSettings.kAsrEngine: asrEngine,
        AppSettings.kWhisperModelId: whisperModelId,
        AppSettings.kLanguageHint: ?languageHint,
        AppSettings.kKeepAudio: keepAudio.toString(),
        AppSettings.kMatchThreshold: matchThreshold.toString(),
        AppSettings.kConsentAcknowledged: consentAcknowledged.toString(),
        AppSettings.kMinutesDetail: minutesDetail,
        AppSettings.kClaudeModel: claudeModel,
        AppSettings.kMinutesEngine: minutesEngine,
        AppSettings.kGeminiModel: geminiModel,
        AppSettings.kGeminiPrivacyAcknowledged:
            geminiPrivacyAcknowledged.toString(),
        AppSettings.kLocalLlmModelId: ?localLlmModelId,
        AppSettings.kServerUrl: serverUrl,
        AppSettings.kServerModel: ?serverModel,
        AppSettings.kAudioSource: audioSource,
        AppSettings.kInputDeviceId: ?inputDeviceId,
        AppSettings.kFarFieldMode: farFieldMode.toString(),
        AppSettings.kProfilesFeatureAcknowledged:
            profilesFeatureAcknowledged.toString(),
      };

  /// Normalises a language hint: trimmed lowercase ISO-639 code, or null for
  /// blank / `auto`.
  static String? normalizeLanguageHint(String? hint) {
    final t = hint?.trim().toLowerCase();
    if (t == null || t.isEmpty || t == 'auto') return null;
    return t;
  }

  /// Normalises a Gemini model id: trimmed, a leading `models/` removed;
  /// null when blank or not a plausible id (letters, digits, `.`, `-`,
  /// `_`).
  static String? normalizeGeminiModel(String? model) {
    var t = model?.trim() ?? '';
    if (t.startsWith('models/')) t = t.substring('models/'.length);
    if (t.isEmpty || !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(t)) return null;
    return t;
  }

  /// Normalises a local-server URL: trimmed, trailing slashes removed;
  /// null unless it is an absolute `http`/`https` URL with a host.
  static String? normalizeServerUrl(String? url) {
    var t = url?.trim() ?? '';
    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    final u = Uri.tryParse(t);
    if (u == null ||
        !(u.scheme == 'http' || u.scheme == 'https') ||
        u.host.isEmpty) {
      return null;
    }
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

  /// Settings-table key for [AppSettingsData.minutesEngine].
  static const String kMinutesEngine = 'minutes_engine';

  /// Settings-table key for [AppSettingsData.geminiModel].
  static const String kGeminiModel = 'gemini_model';

  /// Settings-table key for [AppSettingsData.geminiPrivacyAcknowledged].
  static const String kGeminiPrivacyAcknowledged =
      'gemini_privacy_acknowledged';

  /// Settings-table key for [AppSettingsData.localLlmModelId].
  static const String kLocalLlmModelId = 'local_llm_model_id';

  /// Settings-table key for [AppSettingsData.serverUrl].
  static const String kServerUrl = 'server_url';

  /// Settings-table key for [AppSettingsData.serverModel].
  static const String kServerModel = 'server_model';

  /// Settings-table key for [AppSettingsData.audioSource].
  static const String kAudioSource = 'audio_source';

  /// Settings-table key for [AppSettingsData.inputDeviceId].
  static const String kInputDeviceId = 'input_device_id';

  /// Settings-table key for [AppSettingsData.farFieldMode].
  static const String kFarFieldMode = 'far_field_mode';

  /// Settings-table key for [AppSettingsData.profilesFeatureAcknowledged].
  static const String kProfilesFeatureAcknowledged =
      'profiles_feature_acknowledged';

  /// Keys whose absence means null (removed by [save] when null).
  static const List<String> _optionalKeys = [
    kLanguageHint,
    kLocalLlmModelId,
    kServerModel,
    kInputDeviceId,
  ];

  static AppSettingsData _fromRows(List<SettingRow> rows) =>
      AppSettingsData.fromMap({for (final r in rows) r.key: r.value});

  /// Current settings snapshot.
  Future<AppSettingsData> load() async =>
      _fromRows(await _db.select(_db.settings).get());

  /// Settings snapshots, emitted now and after every distinct change.
  Stream<AppSettingsData> watch() =>
      _db.select(_db.settings).watch().map(_fromRows).distinct();

  /// One-time upgrade step for v1.0 users: v1.0 had only the Claude engine
  /// and never wrote [kMinutesEngine], so its absence would otherwise fall
  /// back to Gemini and stop automatic minutes for a user whose working
  /// Claude key is still stored. When the row is absent, writes `claude` if
  /// an Anthropic key exists, else `gemini` (the default). Writing the row in
  /// both cases makes this run once only, and an explicit choice is never
  /// overridden. Never throws: a keystore that cannot be read now (locked
  /// device) leaves the row absent so the step is retried at next launch.
  Future<void> migrateV1MinutesEngine(SecureSettings secure) async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(kMinutesEngine)))
          .getSingleOrNull();
      if (row != null) return;
      final key = await secure.getAnthropicApiKey();
      await _put(
        kMinutesEngine,
        key != null
            ? AppSettingsData.engineClaude
            : AppSettingsData.engineGemini,
      );
    } catch (e) {
      debugPrint('migrateV1MinutesEngine failed: $e');
    }
  }

  /// Persists every field of [data] in one transaction.
  Future<void> save(AppSettingsData data) => _db.transaction(() async {
        final map = data.toMap();
        for (final e in map.entries) {
          await _put(e.key, e.value);
        }
        for (final k in _optionalKeys) {
          if (!map.containsKey(k)) await _remove(k);
        }
      });

  Future<void> _put(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> _remove(String key) =>
      (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();

  Future<void> _putOptional(String key, String? value) {
    final t = value?.trim();
    return (t == null || t.isEmpty) ? _remove(key) : _put(key, t);
  }

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

  /// Selected minutes engine (see [AppSettingsData.minutesEngines]).
  Future<String> get minutesEngine async => (await load()).minutesEngine;

  /// Selects the minutes engine. Throws [ArgumentError] for unknown values.
  Future<void> setMinutesEngine(String engine) {
    if (!AppSettingsData.minutesEngines.contains(engine)) {
      throw ArgumentError.value(
          engine, 'engine', 'must be gemini, claude, local or server');
    }
    return _put(kMinutesEngine, engine);
  }

  /// Gemini model id.
  Future<String> get geminiModel async => (await load()).geminiModel;

  /// Sets the Gemini model id (a leading `models/` is removed). Throws
  /// [ArgumentError] when blank or malformed.
  Future<void> setGeminiModel(String model) {
    final n = AppSettingsData.normalizeGeminiModel(model);
    if (n == null) {
      throw ArgumentError.value(model, 'model', 'not a Gemini model id');
    }
    return _put(kGeminiModel, n);
  }

  /// Whether the Gemini free-tier data notice was accepted.
  Future<bool> get geminiPrivacyAcknowledged async =>
      (await load()).geminiPrivacyAcknowledged;

  /// Records whether the Gemini free-tier data notice was accepted.
  Future<void> setGeminiPrivacyAcknowledged(bool v) =>
      _put(kGeminiPrivacyAcknowledged, v.toString());

  /// Sets the on-device GGUF model id (null / blank = recommended model).
  Future<void> setLocalLlmModelId(String? id) =>
      _putOptional(kLocalLlmModelId, id);

  /// Sets the local-server URL. Throws [ArgumentError] unless it is an
  /// absolute http(s) URL.
  Future<void> setServerUrl(String url) {
    final n = AppSettingsData.normalizeServerUrl(url);
    if (n == null) {
      throw ArgumentError.value(url, 'url', 'must be an http(s) URL');
    }
    return _put(kServerUrl, n);
  }

  /// Sets the local-server model (null / blank = not chosen).
  Future<void> setServerModel(String? model) =>
      _putOptional(kServerModel, model);

  /// Sets the Windows audio source. Throws [ArgumentError] for unknown
  /// values.
  Future<void> setAudioSource(String source) {
    if (!AppSettingsData.audioSources.contains(source)) {
      throw ArgumentError.value(
          source, 'source', 'must be mic, system or both');
    }
    return _put(kAudioSource, source);
  }

  /// Sets the input device (null / blank = system default).
  Future<void> setInputDeviceId(String? id) => _putOptional(kInputDeviceId, id);

  /// Enables or disables the far-field profile.
  Future<void> setFarFieldMode(bool v) => _put(kFarFieldMode, v.toString());

  /// Records whether the speaker-profiles notice was read.
  Future<void> setProfilesFeatureAcknowledged(bool v) =>
      _put(kProfilesFeatureAcknowledged, v.toString());

  /// Preference keys owned by this store. Other modules keep their own rows
  /// in the same table (e.g. the per-meeting voiceprint ledgers), which a
  /// reset must not touch.
  static const List<String> preferenceKeys = [
    kAsrEngine,
    kWhisperModelId,
    kLanguageHint,
    kKeepAudio,
    kMatchThreshold,
    kConsentAcknowledged,
    kMinutesDetail,
    kClaudeModel,
    kMinutesEngine,
    kGeminiModel,
    kGeminiPrivacyAcknowledged,
    kLocalLlmModelId,
    kServerUrl,
    kServerModel,
    kAudioSource,
    kInputDeviceId,
    kFarFieldMode,
    kProfilesFeatureAcknowledged,
  ];

  /// Removes all stored preferences (back to defaults). Other data kept in
  /// the settings table, such as the voiceprint ledgers, is left alone.
  Future<void> resetToDefaults() =>
      (_db.delete(_db.settings)..where((s) => s.key.isIn(preferenceKeys))).go();
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
