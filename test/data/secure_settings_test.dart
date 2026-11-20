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
      expect(d.claudeModel, 'claude-opus-5-5');
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
        AppSettings.kClaudeModel: '',
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
        claudeModel: 'claude-sonnet-4-6',
      );
      expect(AppSettingsData.fromMap(d.toMap()), d);
      expect(const AppSettingsData().toMap()
          .containsKey(AppSettings.kLanguageHint), isFalse);
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
      await settings.setClaudeModel('claude-x');

      expect(await settings.asrEngine, 'cloud');
      expect(await settings.whisperModelId, 'whisper-medium');
      expect(await settings.languageHint, 'ar');
      expect(await settings.keepAudio, isFalse);
      expect(await settings.matchThreshold, 0.7);
      expect(await settings.consentAcknowledged, isTrue);
      expect(await settings.minutesDetail, 'concise');
      expect(await settings.claudeModel, 'claude-x');

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
      );
      expect(AppSettings.preferenceKeys.toSet(), full.toMap().keys.toSet());
    });

    test('setters validate input', () {
      expect(() => settings.setAsrEngine('x'), throwsArgumentError);
      expect(() => settings.setMinutesDetail('x'), throwsArgumentError);
      expect(() => settings.setMatchThreshold(0), throwsArgumentError);
      expect(() => settings.setMatchThreshold(double.nan), throwsArgumentError);
      expect(() => settings.setWhisperModelId(' '), throwsArgumentError);
      expect(() => settings.setClaudeModel(''), throwsArgumentError);
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
      expect(await s.getAnthropicApiKey(), isNull);
      expect(await s.getDeepgramApiKey(), isNull);

      await s.setAnthropicApiKey('  sk-ant-123 ');
      await s.setDeepgramApiKey('dg-456');
      expect(await s.getAnthropicApiKey(), 'sk-ant-123');
      expect(await s.getDeepgramApiKey(), 'dg-456');

      await s.clearAnthropicApiKey();
      expect(await s.getAnthropicApiKey(), isNull);
      expect(await s.getDeepgramApiKey(), 'dg-456');

      await s.setDeepgramApiKey('   ');
      expect(await s.getDeepgramApiKey(), isNull);
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
      await expectLater(s.getDeepgramApiKey(),
          throwsA(isA<SecureStorageUnavailableException>()));

      storage.fail = false;
      await s.setDeepgramApiKey('dg-1');
      expect(await s.getDeepgramApiKey(), 'dg-1');
      // Device locked mid-meeting: the value read earlier stays available.
      storage.fail = true;
      expect(await s.getDeepgramApiKey(), 'dg-1');
      await expectLater(s.getAnthropicApiKey(),
          throwsA(isA<SecureStorageUnavailableException>()));
    });

    test('migrateAccessibility rewrites stored keys once', () async {
      final storage = _FlakyStorage()
        ..values[SecureSettings.anthropicApiKeyKey] = 'sk-1';
      final s = SecureSettings(storage: storage);
      storage.fail = true;
      await s.migrateAccessibility(); // locked: retried later, never throws
      expect(storage.writes, isEmpty);
      storage.fail = false;
      await s.migrateAccessibility();
      expect(storage.writes, [
        SecureSettings.anthropicApiKeyKey,
        SecureSettings.accessibilityMigratedKey,
      ]);
      expect(storage.values[SecureSettings.anthropicApiKeyKey], 'sk-1');
      await s.migrateAccessibility();
      expect(storage.writes.length, 2);
    });

    group('migrateV1MinutesEngine', () {
      late AppDatabase db;
      late AppSettings settings;
      setUp(() async {
        db = AppDatabase.forExecutor(NativeDatabase.memory());
        settings = AppSettings(db);
        // A v1.0 settings table: some rows, no minutes_engine.
        await settings.setKeepAudio(false);
        await settings.setClaudeModel('claude-sonnet-4-6');
      });
      tearDown(() => db.close());

      Future<String?> row() async => (await (db.select(db.settings)
                ..where((s) => s.key.equals(AppSettings.kMinutesEngine)))
              .getSingleOrNull())
          ?.value;

      test('a v1 user with an Anthropic key stays on Claude', () async {
        final storage = _FlakyStorage()
          ..values[SecureSettings.anthropicApiKeyKey] = 'sk-ant-1';
        await settings.migrateV1MinutesEngine(SecureSettings(storage: storage));
        expect((await settings.load()).minutesEngine, 'claude');
        expect((await settings.load()).keepAudio, isFalse);
      });

      test('no Anthropic key: Gemini, and the row is written', () async {
        await settings.migrateV1MinutesEngine(SecureSettings(storage: _FlakyStorage()));
        expect(await row(), 'gemini');
        expect((await settings.load()).minutesEngine, 'gemini');
      });

      test('an explicit choice is never overridden', () async {
        await settings.setMinutesEngine('gemini');
        final storage = _FlakyStorage()
          ..values[SecureSettings.anthropicApiKeyKey] = 'sk-ant-1';
        await settings.migrateV1MinutesEngine(SecureSettings(storage: storage));
        expect((await settings.load()).minutesEngine, 'gemini');
      });

      test('idempotent: a Claude key added later does not switch', () async {
        final storage = _FlakyStorage();
        final secure = SecureSettings(storage: storage);
        await settings.migrateV1MinutesEngine(secure);
        await secure.setAnthropicApiKey('sk-ant-2');
        await settings.migrateV1MinutesEngine(secure);
        expect((await settings.load()).minutesEngine, 'gemini');
      });

      test('locked keystore: no row written, retried later', () async {
        final storage = _FlakyStorage()
          ..values[SecureSettings.anthropicApiKeyKey] = 'sk-ant-1'
          ..fail = true;
        final secure = SecureSettings(storage: storage);
        await settings.migrateV1MinutesEngine(secure);
        expect(await row(), isNull);
        storage.fail = false;
        await settings.migrateV1MinutesEngine(secure);
        expect(await row(), 'claude');
      });
    });

    test('reads pre-existing values', () async {
      FlutterSecureStorage.setMockInitialValues(
          {SecureSettings.anthropicApiKeyKey: 'abc'});
      expect(await SecureSettings().getAnthropicApiKey(), 'abc');
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
    values.remove(key);
  }
}
