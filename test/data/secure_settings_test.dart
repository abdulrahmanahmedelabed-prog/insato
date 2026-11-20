import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/secure_settings.dart';

void main() {
  group('AppSettingsData', () {
    test('defaults', () {
      const d = AppSettingsData.defaults;
      expect(d.asrEngine, 'local');
      expect(d.usesLocalAsr, isTrue);
      expect(d.whisperModelId, 'whisper-turbo');
      expect(d.languageHint, isNull);
      expect(d.keepAudio, isTrue);
      expect(d.matchThreshold, 0.55);
      expect(d.consentAcknowledged, isFalse);
      expect(d.minutesDetail, 'detailed');
      expect(d.conciseMinutes, isFalse);
      expect(d.minutesEngine, 'gemini');
      expect(d.groqModel, isNull);
      expect(d.groqPrivacyAcknowledged, isFalse);
      expect(d.groqAsrModel, 'whisper-large-v3');
      expect(d.groqAsrPrivacyAcknowledged, isFalse);
      expect(d.cloudFallbackAuto, isFalse);
      expect(AppSettingsData.minutesEngines, ['gemini', 'groq', 'local', 'server']);
      expect(AppSettingsData.fromMap(const {}), d);
    });

    test('copyWith and equality', () {
      const d = AppSettingsData();
      final c = d.copyWith(asrEngine: 'cloud', languageHint: 'ar');
      expect(c.asrEngine, 'cloud');
      expect(c.languageHint, 'ar');
      expect(c.whisperModelId, d.whisperModelId);
      expect(c == d, isFalse);
      expect(c.copyWith(clearLanguageHint: true).languageHint, isNull);
      expect(d.copyWith(), d);
      expect(d.copyWith().hashCode, d.hashCode);
    });

    test('fromMap falls back on invalid values', () {
      final d = AppSettingsData.fromMap(const {
        AppSettings.kAsrEngine: 'quantum',
        AppSettings.kWhisperModelId: '  ',
        AppSettings.kLanguageHint: 'AUTO',
        AppSettings.kKeepAudio: 'maybe',
        AppSettings.kMatchThreshold: '1.5',
        AppSettings.kConsentAcknowledged: '1',
        AppSettings.kMinutesDetail: 'verbose',
        AppSettings.kGroqModel: 'bad model id',
        AppSettings.kGroqAsrModel: 'nova-3',
      });
      expect(d, AppSettingsData.defaults.copyWith(consentAcknowledged: true));
    });

    test('toMap/fromMap round trip', () {
      final d = const AppSettingsData().copyWith(
        asrEngine: 'cloud',
        whisperModelId: 'whisper-small',
        languageHint: 'fr',
        keepAudio: false,
        matchThreshold: 0.62,
        consentAcknowledged: true,
        minutesDetail: 'concise',
        minutesEngine: 'groq',
        groqModel: 'openai/gpt-oss-120b',
        groqPrivacyAcknowledged: true,
        groqAsrModel: 'whisper-large-v3-turbo',
        groqAsrPrivacyAcknowledged: true,
        cloudFallbackAuto: true,
      );
      expect(AppSettingsData.fromMap(d.toMap()), d);
      expect(d.copyWith(clearGroqModel: true).groqModel, isNull);
      expect(d.minutesEngineIsCloud, isTrue);
      expect(d.usesCloudAsr, isTrue);
      expect(const AppSettingsData().toMap()
          .containsKey(AppSettings.kLanguageHint), isFalse);
    });

    test('a stored claude engine (removed) falls back to Gemini', () {
      final d = AppSettingsData.fromMap(const {
        AppSettings.kMinutesEngine: 'claude',
      });
      expect(d.minutesEngine, 'gemini');
    });

    test('normalizeGroqModel', () {
      expect(AppSettingsData.normalizeGroqModel(' openai/gpt-oss-120b '),
          'openai/gpt-oss-120b');
      expect(AppSettingsData.normalizeGroqModel('llama-3.3-70b-versatile'),
          'llama-3.3-70b-versatile');
      expect(AppSettingsData.normalizeGroqModel(''), isNull);
      expect(AppSettingsData.normalizeGroqModel('a b'), isNull);
    });

    test('normalizeLanguageHint', () {
      expect(AppSettingsData.normalizeLanguageHint(' EN '), 'en');
      expect(AppSettingsData.normalizeLanguageHint(''), isNull);
      expect(AppSettingsData.normalizeLanguageHint(null), isNull);
      expect(AppSettingsData.normalizeLanguageHint('auto'), isNull);
    });
  });

  group('AppSettings', () {
    late AppDatabase db;
    late AppSettings settings;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
      settings = AppSettings(db);
    });
    tearDown(() => db.close());

    test('typed getters/setters persist', () async {
      expect(await settings.load(), AppSettingsData.defaults);
      await settings.setAsrEngine('cloud');
      await settings.setWhisperModelId(' whisper-medium ');
      await settings.setLanguageHint('AR');
      await settings.setKeepAudio(false);
      await settings.setMatchThreshold(0.7);
      await settings.setConsentAcknowledged(true);
      await settings.setMinutesDetail('concise');
      await settings.setMinutesEngine('groq');
      await settings.setGroqModel(' llama-3.3-70b-versatile ');
      await settings.setGroqPrivacyAcknowledged(true);
      await settings.setGroqAsrModel('whisper-large-v3-turbo');
      await settings.setGroqAsrPrivacyAcknowledged(true);
      await settings.setCloudFallbackAuto(true);

      expect(await settings.asrEngine, 'cloud');
      expect(await settings.whisperModelId, 'whisper-medium');
      expect(await settings.languageHint, 'ar');
      expect(await settings.keepAudio, isFalse);
      expect(await settings.matchThreshold, 0.7);
      expect(await settings.consentAcknowledged, isTrue);
      expect(await settings.minutesDetail, 'concise');
      final loaded = await settings.load();
      expect(loaded.minutesEngine, 'groq');
      expect(loaded.groqModel, 'llama-3.3-70b-versatile');
      expect(loaded.groqPrivacyAcknowledged, isTrue);
      expect(loaded.groqAsrModel, 'whisper-large-v3-turbo');
      expect(loaded.groqAsrPrivacyAcknowledged, isTrue);
      expect(loaded.cloudFallbackAuto, isTrue);
      await settings.setGroqModel(null);
      expect((await settings.load()).groqModel, isNull);

      await settings.setLanguageHint(null);
      expect(await settings.languageHint, isNull);

      await settings.resetToDefaults();
      expect(await settings.load(), AppSettingsData.defaults);
    });

    test('resetToDefaults keeps non-preference rows (voiceprint ledgers)',
        () async {
      await settings.setAsrEngine('cloud');
      await settings.setLanguageHint('fr');
      const ledgerKey = 'voiceprint_ledger:meeting-1';
      await db.into(db.settings).insert(
          SettingsCompanion.insert(key: ledgerKey, value: '{"s1":"sp1"}'));
      await settings.resetToDefaults();
      expect(await settings.load(), AppSettingsData.defaults);
      final rows = await db.select(db.settings).get();
      expect(rows.map((r) => r.key), [ledgerKey]);
      expect(rows.single.value, '{"s1":"sp1"}');
    });

    test('preferenceKeys covers every key written by save', () {
      final full = AppSettingsData.defaults.copyWith(
        languageHint: 'ar',
        localLlmModelId: 'qwen',
        serverModel: 'llama',
        inputDeviceId: 'usb-mic',
        groqModel: 'openai/gpt-oss-120b',
      );
      expect(AppSettings.preferenceKeys.toSet(), full.toMap().keys.toSet());
    });

    test('setters validate input', () {
      expect(() => settings.setAsrEngine('x'), throwsArgumentError);
      expect(() => settings.setMinutesDetail('x'), throwsArgumentError);
      expect(() => settings.setMatchThreshold(0), throwsArgumentError);
      expect(() => settings.setMatchThreshold(double.nan), throwsArgumentError);
      expect(() => settings.setWhisperModelId(' '), throwsArgumentError);
      expect(() => settings.setMinutesEngine('claude'), throwsArgumentError);
      expect(() => settings.setGroqModel('a b'), throwsArgumentError);
      expect(() => settings.setGroqAsrModel('nova-3'), throwsArgumentError);
    });

    test('save writes a full snapshot', () async {
      final d = AppSettingsData.defaults
          .copyWith(languageHint: 'de', keepAudio: false);
      await settings.save(d);
      expect(await settings.load(), d);
      await settings.save(d.copyWith(clearLanguageHint: true));
      expect(await settings.languageHint, isNull);
    });

    test('watch emits distinct snapshots', () async {
      final stream = settings.watch();
      expect(await stream.first, AppSettingsData.defaults);
      final later = expectLater(
        stream.map((d) => d.asrEngine),
        emitsInOrder(['local', 'cloud']),
      );
      await Future<void>.delayed(Duration.zero);
      await settings.setAsrEngine('cloud');
      await later;
    });
  });

  group('SecureSettings', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('get/set/clear API keys', () async {
      final s = SecureSettings();
      expect(await s.getGeminiApiKey(), isNull);
      expect(await s.getGroqApiKey(), isNull);

      await s.setGeminiApiKey('  AIza-123 ');
      await s.setGroqApiKey('gsk_456');
      expect(await s.getGeminiApiKey(), 'AIza-123');
      expect(await s.getGroqApiKey(), 'gsk_456');

      await s.clearGeminiApiKey();
      expect(await s.getGeminiApiKey(), isNull);
      expect(await s.getGroqApiKey(), 'gsk_456');

      await s.setGroqApiKey('   ');
      expect(await s.getGroqApiKey(), isNull);
    });

    test('default storage: readable after first unlock, never backed up',
        () {
      final o = SecureSettings.defaultStorage.iOptions;
      expect(o.accessibility, KeychainAccessibility.first_unlock_this_device);
      final m = o.toMap();
      expect(m['accessibility'], 'first_unlock_this_device');
      expect(m['synchronizable'], 'false');
    });

    test('a keystore read failure is not reported as "no key"', () async {
      final storage = _FlakyStorage();
      final s = SecureSettings(storage: storage);
      storage.fail = true;
      await expectLater(s.getGroqApiKey(),
          throwsA(isA<SecureStorageUnavailableException>()));

      storage.fail = false;
      await s.setGroqApiKey('gsk-1');
      expect(await s.getGroqApiKey(), 'gsk-1');
      // Device locked mid-meeting: the value read earlier stays available.
      storage.fail = true;
      expect(await s.getGroqApiKey(), 'gsk-1');
      await expectLater(s.getGeminiApiKey(),
          throwsA(isA<SecureStorageUnavailableException>()));
    });

    test('migrateAccessibility rewrites stored keys once', () async {
      final storage = _FlakyStorage()
        ..values[SecureSettings.groqApiKeyKey] = 'gsk-1';
      final s = SecureSettings(storage: storage);
      storage.fail = true;
      await s.migrateAccessibility(); // locked: retried later, never throws
      expect(storage.writes, isEmpty);
      storage.fail = false;
      await s.migrateAccessibility();
      expect(storage.writes, [
        SecureSettings.groqApiKeyKey,
        SecureSettings.accessibilityMigratedKey,
      ]);
      expect(storage.values[SecureSettings.groqApiKeyKey], 'gsk-1');
      await s.migrateAccessibility();
      expect(storage.writes.length, 2);
    });

    group('migrateToFreeEngines', () {
      late AppDatabase db;
      late AppSettings settings;
      setUp(() async {
        db = AppDatabase.forExecutor(NativeDatabase.memory());
        settings = AppSettings(db);
        await settings.setKeepAudio(false);
      });
      tearDown(() => db.close());

      Future<Map<String, String>> rows() async => {
            for (final r in await db.select(db.settings).get()) r.key: r.value,
          };

      Future<void> putRaw(String key, String value) => db
          .into(db.settings)
          .insertOnConflictUpdate(
              SettingsCompanion.insert(key: key, value: value));

      _FlakyStorage paidKeys() => _FlakyStorage()
        ..values[SecureSettings.legacyAnthropicApiKeyKey] = 'sk-ant-1'
        ..values[SecureSettings.legacyDeepgramApiKeyKey] = 'dg-1'
        ..values[SecureSettings.geminiApiKeyKey] = 'AIza-1';

      test('Claude → Gemini (notice still required), keys deleted', () async {
        await putRaw(AppSettings.kMinutesEngine, 'claude');
        await putRaw(AppSettings.kLegacyClaudeModel, 'claude-opus-5-5');
        final storage = paidKeys();
        await settings.migrateToFreeEngines(SecureSettings(storage: storage));
        final s = await settings.load();
        expect(s.minutesEngine, 'gemini');
        expect(s.geminiPrivacyAcknowledged, isFalse);
        expect(s.keepAudio, isFalse);
        final r = await rows();
        expect(r[AppSettings.kMinutesEngine], 'gemini');
        expect(r.containsKey(AppSettings.kLegacyClaudeModel), isFalse);
        expect(r[AppSettings.kFreeEnginesMigrated], '1');
        expect(storage.values.keys, [SecureSettings.geminiApiKeyKey]);
      });

      test('an accepted Gemini notice is kept', () async {
        await putRaw(AppSettings.kMinutesEngine, 'claude');
        await settings.setGeminiPrivacyAcknowledged(true);
        await settings.migrateToFreeEngines(
            SecureSettings(storage: _FlakyStorage()));
        final s = await settings.load();
        expect(s.minutesEngine, 'gemini');
        expect(s.geminiPrivacyAcknowledged, isTrue);
      });

      test('Deepgram cloud ASR → on-device without the Groq notice', () async {
        await settings.setAsrEngine('cloud');
        await settings.migrateToFreeEngines(SecureSettings(storage: paidKeys()));
        expect((await settings.load()).asrEngine, 'local');
      });

      test('Deepgram cloud ASR → Groq Whisper with the notice accepted',
          () async {
        await settings.setAsrEngine('cloud');
        await settings.setGroqAsrPrivacyAcknowledged(true);
        await settings.migrateToFreeEngines(SecureSettings(storage: paidKeys()));
        final s = await settings.load();
        expect(s.asrEngine, 'cloud');
        expect(s.usesCloudAsr, isTrue);
      });

      test('free choices are untouched; runs once', () async {
        await settings.setMinutesEngine('server');
        final storage = _FlakyStorage();
        final secure = SecureSettings(storage: storage);
        await settings.migrateToFreeEngines(secure);
        expect((await settings.load()).minutesEngine, 'server');
        // A later run is a no-op (marker), even for a changed choice.
        await settings.setAsrEngine('cloud');
        await settings.migrateToFreeEngines(secure);
        expect((await settings.load()).asrEngine, 'cloud');
      });

      test('locked keystore: settings migrated, retried until keys deleted',
          () async {
        await putRaw(AppSettings.kMinutesEngine, 'claude');
        final storage = paidKeys()..fail = true;
        final secure = SecureSettings(storage: storage);
        await settings.migrateToFreeEngines(secure); // never throws
        expect((await settings.load()).minutesEngine, 'gemini');
        expect((await rows()).containsKey(AppSettings.kFreeEnginesMigrated),
            isFalse);
        expect(
            storage.values.containsKey(SecureSettings.legacyAnthropicApiKeyKey),
            isTrue);
        storage.fail = false;
        await settings.migrateToFreeEngines(secure);
        expect(
            storage.values.containsKey(SecureSettings.legacyAnthropicApiKeyKey),
            isFalse);
        expect(
            storage.values.containsKey(SecureSettings.legacyDeepgramApiKeyKey),
            isFalse);
        expect((await rows())[AppSettings.kFreeEnginesMigrated], '1');
      });

      test('reset keeps the migration marker', () async {
        await settings.migrateToFreeEngines(
            SecureSettings(storage: _FlakyStorage()));
        await settings.resetToDefaults();
        expect((await rows())[AppSettings.kFreeEnginesMigrated], '1');
      });
    });

    test('reads pre-existing values', () async {
      FlutterSecureStorage.setMockInitialValues(
          {SecureSettings.groqApiKeyKey: 'abc'});
      expect(await SecureSettings().getGroqApiKey(), 'abc');
    });
  });
}

/// In-memory storage whose reads can fail like a locked iOS keychain.
class _FlakyStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};
  final List<String> writes = [];
  bool fail = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail) {
      throw PlatformException(code: '-25308', message: 'interaction not allowed');
    }
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail) throw PlatformException(code: '-25308');
    writes.add(key);
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail) throw PlatformException(code: '-25308');
    values.remove(key);
  }
}
