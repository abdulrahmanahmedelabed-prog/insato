// Selection of the minutes engine chosen in Settings (F14): Gemini (default,
// free tier), Groq (free plan), on-device or local-server. Used for minutes,
// "Ask your meetings" (F8) and the consistency checker. Owner decision: the
// cloud engines are free services only.
//
// When the selected free cloud engine has used up its daily quota, the other
// free cloud engine — if the user stored its key and accepted its privacy
// notice — is used automatically (setting `cloudFallbackAuto`) or offered
// ([MinutesQuotaExhaustedException.alternativeEngine]; the minutes tab then
// runs the job once with that engine through [runWithMinutesEngine]).
//
// THIS FILE IS A SHARED CONTRACT (see docs/V11-CONTRACTS.md).

import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../data/secure_settings.dart';
import '../features/groq/groq_api.dart';
import '../features/groq/groq_minutes_backend.dart';
import '../features/groq/strings.dart';
import '../features/local_llm/local_minutes_backends.dart';
import '../minutes/gemini_client.dart';
import '../minutes/minutes_backend.dart';
import 'post_processor.dart'
    show MinutesEngineNotReadyException, MinutesEngineNotReadyReason;

/// Arabic product name of an engine id (`AppSettingsData.minutesEngine`).
String minutesEngineDisplayNameAr(String engine) => switch (engine) {
  AppSettingsData.engineGemini => 'Gemini',
  AppSettingsData.engineGroq => 'Groq',
  AppSettingsData.engineLocal => 'النموذج المحلي على الجهاز',
  AppSettingsData.engineServer => 'الخادم المحلي',
  _ => engine,
};

final Object _engineOverrideKey = Object();

/// Runs [body] with the minutes engine [engine] instead of the one selected
/// in Settings, for every backend created inside it (one job, e.g. "write
/// these minutes with Groq" after Gemini's daily quota ran out). The
/// engine must still be ready (key, accepted notice).
Future<T> runWithMinutesEngine<T>(String engine, Future<T> Function() body) =>
    runZoned(body, zoneValues: {_engineOverrideKey: engine});

/// The engine forced by [runWithMinutesEngine] in the current zone, if any.
String? get currentMinutesEngineOverride {
  final v = Zone.current[_engineOverrideKey];
  return v is String ? v : null;
}

/// The selected free cloud engine used up its daily quota; [alternativeEngine]
/// (set up and acknowledged) can be used instead. Thrown when automatic
/// switching is off.
class MinutesQuotaExhaustedException extends MinutesGenerationException {
  /// Creates the exception.
  const MinutesQuotaExhaustedException(
    super.messageAr, {
    required this.exhaustedEngine,
    required this.alternativeEngine,
    super.debugDetails,
    super.cause,
  });

  /// Engine id whose quota is used up.
  final String exhaustedEngine;

  /// Engine id offered instead.
  final String alternativeEngine;
}

/// True when [e] means the daily free quota of a cloud engine is used up.
bool isDailyQuotaExhausted(Object e) =>
    (e is GeminiQuotaExceededException && e.daily) ||
    (e is GroqQuotaExceededException && e.daily);

/// Creates the backend of the engine selected in [settings] (or forced by
/// [runWithMinutesEngine]).
///
/// Throws [MinutesEngineNotReadyException] (with an Arabic explanation)
/// when the engine has no API key, its data notice was not accepted (Gemini
/// and Groq — nothing is sent before), or it is not available; and
/// `SecureStorageUnavailableException` when the keystore is locked.
///
/// For a free cloud engine, the result falls back on a daily-quota refusal
/// to the other free cloud engine when that one is ready (automatically
/// with `cloudFallbackAuto`, otherwise by throwing
/// [MinutesQuotaExhaustedException]).
///
/// [httpClient] is injected into cloud clients (tests); [geminiGate] /
/// [groqGate] too. [onGeminiModelDiscovered] / [onGroqModelDiscovered] are
/// called when the configured model did not exist and another was chosen
/// (persist it in settings).
Future<MinutesBackend> createMinutesBackend({
  required AppSettingsData settings,
  required SecureSettings secure,
  LocalMinutesBackendBuilder? local,
  LocalMinutesBackendBuilder? server,
  http.Client? httpClient,
  GeminiRateGate? geminiGate,
  GroqRateGate? groqGate,
  void Function(String model)? onGeminiModelDiscovered,
  void Function(String model)? onGroqModelDiscovered,
}) async {
  final engine = currentMinutesEngineOverride ?? settings.minutesEngine;
  Future<MinutesBackend> cloud(String id) => _createCloudBackend(
    id,
    settings: settings,
    secure: secure,
    httpClient: httpClient,
    geminiGate: geminiGate,
    groqGate: groqGate,
    onGeminiModelDiscovered: onGeminiModelDiscovered,
    onGroqModelDiscovered: onGroqModelDiscovered,
  );

  switch (engine) {
    case AppSettingsData.engineLocal:
    case AppSettingsData.engineServer:
      final builder = engine == AppSettingsData.engineLocal ? local : server;
      if (builder == null) {
        throw const MinutesEngineNotReadyException(
          'هذا المحرك غير متاح في هذا الإصدار من التطبيق. اختر Gemini أو '
          'Groq من الإعدادات.',
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
    default:
      final primaryId = engine == AppSettingsData.engineGroq
          ? AppSettingsData.engineGroq
          : AppSettingsData.engineGemini;
      final primary = await cloud(primaryId);
      final alternativeId = primaryId == AppSettingsData.engineGemini
          ? AppSettingsData.engineGroq
          : AppSettingsData.engineGemini;
      // Forced engines (an accepted offer) do not chain further.
      if (currentMinutesEngineOverride != null) return primary;
      return QuotaFallbackMinutesBackend(
        primary: primary,
        alternativeEngine: alternativeId,
        automatic: settings.cloudFallbackAuto,
        isAlternativeReady: () =>
            cloudEngineIsReady(alternativeId, settings: settings, secure: secure),
        createAlternative: () => cloud(alternativeId),
      );
  }
}

/// Whether the free cloud engine [engine] has a stored key and an accepted
/// privacy notice. Never throws (a locked keystore counts as not ready).
Future<bool> cloudEngineIsReady(
  String engine, {
  required AppSettingsData settings,
  required SecureSettings secure,
}) async {
  try {
    switch (engine) {
      case AppSettingsData.engineGemini:
        return settings.geminiPrivacyAcknowledged &&
            await secure.getGeminiApiKey() != null;
      case AppSettingsData.engineGroq:
        return settings.groqPrivacyAcknowledged &&
            await secure.getGroqApiKey() != null;
    }
  } catch (_) {
    // Locked keystore.
  }
  return false;
}

Future<MinutesBackend> _createCloudBackend(
  String engine, {
  required AppSettingsData settings,
  required SecureSettings secure,
  http.Client? httpClient,
  GeminiRateGate? geminiGate,
  GroqRateGate? groqGate,
  void Function(String model)? onGeminiModelDiscovered,
  void Function(String model)? onGroqModelDiscovered,
}) async {
  if (engine == AppSettingsData.engineGroq) {
    final key = await secure.getGroqApiKey();
    if (key == null) {
      throw const MinutesEngineNotReadyException(
        GS.keyMissing,
        reason: MinutesEngineNotReadyReason.noApiKey,
      );
    }
    if (!settings.groqPrivacyAcknowledged) {
      throw const MinutesEngineNotReadyException(
        GS.privacyPending,
        reason: MinutesEngineNotReadyReason.privacyNotAcknowledged,
      );
    }
    return GroqMinutesBackend(
      apiKey: key,
      model: settings.groqModel,
      httpClient: httpClient,
      gate: groqGate,
      onModelDiscovered: onGroqModelDiscovered,
    );
  }
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

/// A free cloud backend that, when its daily quota is used up, switches to
/// the other free cloud engine ([automatic]) or offers it by throwing
/// [MinutesQuotaExhaustedException] — only when that engine is ready (key
/// stored, privacy notice accepted). Otherwise the refusal propagates.
class QuotaFallbackMinutesBackend implements MinutesBackend {
  /// Wraps [primary].
  QuotaFallbackMinutesBackend({
    required this.primary,
    required this.alternativeEngine,
    required this.automatic,
    required this._isAlternativeReady,
    required this._createAlternative,
  });

  /// The selected engine.
  final MinutesBackend primary;

  /// Engine id of the other free cloud engine.
  final String alternativeEngine;

  /// Switch without asking (`cloudFallbackAuto`).
  final bool automatic;

  final Future<bool> Function() _isAlternativeReady;
  final Future<MinutesBackend> Function() _createAlternative;
  MinutesBackend? _alternative;

  @override
  String get engineId => primary.engineId;

  @override
  String get displayName => primary.displayName;

  @override
  bool get sendsDataOffDevice => true;

  @override
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  }) async {
    final alt = _alternative;
    if (alt != null) {
      return alt.generateStructured(request, onProgress: onProgress);
    }
    try {
      return await primary.generateStructured(request, onProgress: onProgress);
    } on MinutesGenerationException catch (e) {
      if (!isDailyQuotaExhausted(e) || !await _isAlternativeReady()) rethrow;
      final exhausted = minutesEngineDisplayNameAr(primary.engineId);
      final other = minutesEngineDisplayNameAr(alternativeEngine);
      if (!automatic) {
        throw MinutesQuotaExhaustedException(
          GS.quotaOffer(exhausted, other),
          exhaustedEngine: primary.engineId,
          alternativeEngine: alternativeEngine,
          debugDetails: e.debugDetails,
          cause: e,
        );
      }
      onProgress?.call(
        const MinutesBackendProgress(MinutesBackendPhase.connecting),
      );
      final next = _alternative = await _createAlternative();
      return next.generateStructured(request, onProgress: onProgress);
    }
  }

  @override
  void close() {
    primary.close();
    _alternative?.close();
  }
}
