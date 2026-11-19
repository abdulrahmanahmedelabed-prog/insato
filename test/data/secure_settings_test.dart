import 'package:drift/native.dart';
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

    test('reads pre-existing values', () async {
      FlutterSecureStorage.setMockInitialValues(
          {SecureSettings.anthropicApiKeyKey: 'abc'});
      expect(await SecureSettings().getAnthropicApiKey(), 'abc');
    });
  });
}
