// Insato v1.1 settings: minutes engine (Gemini by default), Gemini model and
// privacy notice, local engines, audio source / input device / far field,
// profiles notice, and the Gemini API key in secure storage.

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/secure_settings.dart';

void main() {
  group('AppSettingsData v1.1', () {
    test('defaults: Gemini engine, nothing acknowledged', () {
      const d = AppSettingsData.defaults;
      expect(d.minutesEngine, 'gemini');
      expect(d.minutesEngineIsCloud, isTrue);
      expect(d.geminiModel, 'gemini-flash-lite-latest');
      expect(d.geminiPrivacyAcknowledged, isFalse);
      expect(d.localLlmModelId, isNull);
      expect(d.serverUrl, 'http://127.0.0.1:11434');
      expect(d.serverModel, isNull);
      expect(d.audioSource, 'both');
      expect(d.inputDeviceId, isNull);
      expect(d.farFieldMode, isFalse);
      expect(d.profilesFeatureAcknowledged, isFalse);
      expect(AppSettingsData.fromMap(const {}), d);
    });

    test('round trip of every field', () {
      final d = AppSettingsData.defaults.copyWith(
        minutesEngine: 'server',
        geminiModel: 'gemini-3-flash',
        geminiPrivacyAcknowledged: true,
        localLlmModelId: 'qwen3-4b',
        serverUrl: 'http://192.168.1.5:1234',
        serverModel: 'qwen3:8b',
        audioSource: 'system',
        inputDeviceId: 'usb-1',
        farFieldMode: true,
        profilesFeatureAcknowledged: true,
      );
      expect(d.minutesEngineIsCloud, isFalse);
      expect(AppSettingsData.fromMap(d.toMap()), d);
      expect(d.copyWith(), d);
      expect(d.copyWith().hashCode, d.hashCode);
      final cleared = d.copyWith(
        clearLocalLlmModelId: true,
        clearServerModel: true,
        clearInputDeviceId: true,
      );
      expect(cleared.localLlmModelId, isNull);
      expect(cleared.serverModel, isNull);
      expect(cleared.inputDeviceId, isNull);
      expect(cleared.toMap().containsKey(AppSettings.kInputDeviceId), isFalse);
    });

    test('invalid stored values fall back to defaults', () {
      final d = AppSettingsData.fromMap(const {
        AppSettings.kMinutesEngine: 'openai',
        AppSettings.kGeminiModel: 'bad model!',
        AppSettings.kGeminiPrivacyAcknowledged: 'yes',
        AppSettings.kServerUrl: 'ftp://x',
        AppSettings.kAudioSource: 'loud',
        AppSettings.kInputDeviceId: '  ',
        AppSettings.kFarFieldMode: '1',
      });
      expect(d, AppSettingsData.defaults.copyWith(farFieldMode: true));
    });

    test('normalisers', () {
      expect(
        AppSettingsData.normalizeGeminiModel(' models/gemini-2.5-flash '),
        'gemini-2.5-flash',
      );
      expect(AppSettingsData.normalizeGeminiModel(''), isNull);
      expect(AppSettingsData.normalizeGeminiModel('a b'), isNull);
      expect(
        AppSettingsData.normalizeServerUrl('http://localhost:11434//'),
        'http://localhost:11434',
      );
      expect(AppSettingsData.normalizeServerUrl('localhost:11434'), isNull);
      expect(AppSettingsData.normalizeServerUrl('https://'), isNull);
    });
  });

  group('AppSettings v1.1 setters', () {
    late AppDatabase db;
    late AppSettings settings;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
      settings = AppSettings(db);
    });
    tearDown(() => db.close());

    test('persist and validate', () async {
      await settings.setMinutesEngine('claude');
      await settings.setGeminiModel('models/gemini-2.5-flash');
      await settings.setGeminiPrivacyAcknowledged(true);
      await settings.setLocalLlmModelId(' qwen ');
      await settings.setServerUrl('http://10.0.0.2:11434/');
      await settings.setServerModel('llama3');
      await settings.setAudioSource('mic');
      await settings.setInputDeviceId('dev-7');
      await settings.setFarFieldMode(true);
      await settings.setProfilesFeatureAcknowledged(true);
      final d = await settings.load();
      expect(d.minutesEngine, 'claude');
      expect(await settings.minutesEngine, 'claude');
      expect(await settings.geminiModel, 'gemini-2.5-flash');
      expect(await settings.geminiPrivacyAcknowledged, isTrue);
      expect(d.localLlmModelId, 'qwen');
      expect(d.serverUrl, 'http://10.0.0.2:11434');
      expect(d.serverModel, 'llama3');
      expect(d.audioSource, 'mic');
      expect(d.inputDeviceId, 'dev-7');
      expect(d.farFieldMode, isTrue);
      expect(d.profilesFeatureAcknowledged, isTrue);

      await settings.setInputDeviceId(null);
      await settings.setServerModel(' ');
      await settings.setLocalLlmModelId(null);
      final e = await settings.load();
      expect(e.inputDeviceId, isNull);
      expect(e.serverModel, isNull);
      expect(e.localLlmModelId, isNull);

      expect(() => settings.setMinutesEngine('gpt'), throwsArgumentError);
      expect(() => settings.setGeminiModel(' '), throwsArgumentError);
      expect(() => settings.setServerUrl('nope'), throwsArgumentError);
      expect(() => settings.setAudioSource('x'), throwsArgumentError);

      await settings.save(e.copyWith(serverModel: 'm', inputDeviceId: 'd'));
      await settings.save(
        (await settings.load()).copyWith(clearServerModel: true),
      );
      expect((await settings.load()).serverModel, isNull);
      expect((await settings.load()).inputDeviceId, 'd');

      await settings.resetToDefaults();
      expect(await settings.load(), AppSettingsData.defaults);
    });
  });

  group('SecureSettings Gemini key', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('get/set/clear', () async {
      final s = SecureSettings();
      expect(await s.getGeminiApiKey(), isNull);
      await s.setGeminiApiKey('  AIzaSy-test ');
      expect(await s.getGeminiApiKey(), 'AIzaSy-test');
      await s.setAnthropicApiKey('sk-ant');
      await s.clearGeminiApiKey();
      expect(await s.getGeminiApiKey(), isNull);
      expect(await s.getAnthropicApiKey(), 'sk-ant');
      await s.setGeminiApiKey('x');
      await s.setGeminiApiKey(' ');
      expect(await s.getGeminiApiKey(), isNull);
    });
  });
}
