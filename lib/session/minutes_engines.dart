// Selection of the minutes engine chosen in Settings (F14): Gemini (default,
// free tier), Claude, on-device or local-server. Used for minutes and for
// "Ask your meetings" (F8).
//
// THIS FILE IS A SHARED CONTRACT (see docs/V11-CONTRACTS.md).

import 'package:http/http.dart' as http;

import '../data/secure_settings.dart';
import '../features/local_llm/local_minutes_backends.dart';
import '../minutes/claude_client.dart';
import '../minutes/gemini_client.dart';
import '../minutes/minutes_backend.dart';
import 'post_processor.dart'
    show MinutesEngineNotReadyException, MinutesEngineNotReadyReason;

/// Arabic product name of an engine id (`AppSettingsData.minutesEngine`).
String minutesEngineDisplayNameAr(String engine) => switch (engine) {
  AppSettingsData.engineGemini => 'Gemini',
  AppSettingsData.engineClaude => 'Claude',
  AppSettingsData.engineLocal => 'النموذج المحلي على الجهاز',
  AppSettingsData.engineServer => 'الخادم المحلي',
  _ => engine,
};

/// Creates the backend of the engine selected in [settings].
///
/// Throws [MinutesEngineNotReadyException] (with an Arabic explanation)
/// when the engine has no API key, its data notice was not accepted (Gemini
/// free tier — nothing is sent before), or it is not available; and
/// `SecureStorageUnavailableException` when the keystore is locked.
///
/// [httpClient] is injected into cloud clients (tests); [geminiGate] too.
/// [onGeminiModelDiscovered] is called when the configured Gemini model did
/// not exist and another was chosen (persist it in settings).
Future<MinutesBackend> createMinutesBackend({
  required AppSettingsData settings,
  required SecureSettings secure,
  LocalMinutesBackendBuilder? local,
  LocalMinutesBackendBuilder? server,
  http.Client? httpClient,
  GeminiRateGate? geminiGate,
  void Function(String model)? onGeminiModelDiscovered,
}) async {
  switch (settings.minutesEngine) {
    case AppSettingsData.engineClaude:
      final key = await secure.getAnthropicApiKey();
      if (key == null) {
        throw const MinutesEngineNotReadyException(
          'مفتاح Claude API غير مضبوط. أضِفه من الإعدادات، أو اختر محرك '
          'Gemini المجاني.',
          reason: MinutesEngineNotReadyReason.noApiKey,
        );
      }
      return ClaudeMinutesBackend(
        ClaudeClient(
          apiKey: key,
          model: settings.claudeModel,
          client: httpClient,
        ),
      );
    case AppSettingsData.engineLocal:
    case AppSettingsData.engineServer:
      final builder = settings.minutesEngine == AppSettingsData.engineLocal
          ? local
          : server;
      if (builder == null) {
        throw const MinutesEngineNotReadyException(
          'هذا المحرك غير متاح في هذا الإصدار من التطبيق. اختر Gemini أو '
          'Claude من الإعدادات.',
          reason: MinutesEngineNotReadyReason.unavailable,
        );
      }
      final backend = await builder.build(settings);
      if (backend == null) {
        throw MinutesEngineNotReadyException(
          builder.unavailableMessageAr,
          reason: MinutesEngineNotReadyReason.unavailable,
        );
      }
      return backend;
    case AppSettingsData.engineGemini:
    default:
      final key = await secure.getGeminiApiKey();
      if (key == null) {
        throw const MinutesEngineNotReadyException(
          'مفتاح Gemini API غير مضبوط. أنشئ مفتاحاً مجانياً من Google AI '
          'Studio (aistudio.google.com/apikey) وأدخله في الإعدادات.',
          reason: MinutesEngineNotReadyReason.noApiKey,
        );
      }
      if (!settings.geminiPrivacyAcknowledged) {
        throw const MinutesEngineNotReadyException(
          'قبل إرسال نص الاجتماع إلى Gemini، اقرأ تنبيه الخصوصية في '
          'الإعدادات ووافق عليه.',
          reason: MinutesEngineNotReadyReason.privacyNotAcknowledged,
        );
      }
      return GeminiMinutesBackend(
        GeminiClient(
          apiKey: key,
          model: settings.geminiModel,
          client: httpClient,
          gate: geminiGate,
        ),
        onModelDiscovered: onGeminiModelDiscovered,
      );
  }
}
