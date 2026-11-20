// "Test connection" of the Settings screen, mapped to an Arabic verdict.
// Both free cloud engines are checked by listing the key's models, which
// validates the key without using any of the (small) free generation quota:
// * Gemini: `models.list`; checks that the configured model exists
//   (otherwise suggests the newest Flash model);
// * Groq: `GET /openai/v1/models`; reports the model that will be used (the
//   configured one, or the automatic choice).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import '../../features/groq/groq_api.dart';
import '../../features/groq/groq_minutes_backend.dart' show listGroqModels;
import '../../features/groq/strings.dart';
import '../../minutes/gemini_client.dart';

/// Outcome of a connection test.
class ConnectionTestResult {
  /// Creates a result.
  const ConnectionTestResult({
    required this.ok,
    required this.messageAr,
    this.model,
  });

  /// True when the API accepted the key and answered.
  final bool ok;

  /// Arabic message to show.
  final String messageAr;

  /// Model that served the test request (when [ok]).
  final String? model;
}

/// Checks a Gemini API key by listing the models it can use.
class GeminiConnectionTester {
  /// Creates a tester. [client] / [baseUri] are injectable for tests.
  GeminiConnectionTester({this.client, this.baseUri});

  /// HTTP client (tests).
  final http.Client? client;

  /// API base override (tests).
  final Uri? baseUri;

  /// Lists the models of [apiKey] and checks that [model] is one of them.
  ///
  /// Never throws. When [model] is missing but another Flash model is
  /// available, the result is ok and its `model` is that suggestion (the
  /// caller may save it).
  Future<ConnectionTestResult> test(
    String apiKey, {
    String model = kDefaultGeminiModel,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return const ConnectionTestResult(
        ok: false,
        messageAr: 'أدخل مفتاح Gemini API أولًا.',
      );
    }
    final wanted = model.trim().isEmpty ? kDefaultGeminiModel : model.trim();
    final c = GeminiClient(
      apiKey: key,
      client: client,
      model: wanted,
      baseUri: baseUri,
    );
    try {
      final models = await c.listModels();
      if (models.any((m) => m.id == wanted && m.canGenerate)) {
        return ConnectionTestResult(
          ok: true,
          messageAr: 'الاتصال ناجح والمفتاح صالح.',
          model: wanted,
        );
      }
      final pick = pickPreferredGeminiModel(models);
      if (pick == null) {
        return const ConnectionTestResult(
          ok: false,
          messageAr:
              'المفتاح صالح، لكن لا يتوفر له أي نموذج Gemini Flash لكتابة '
              'المحاضر.',
        );
      }
      return ConnectionTestResult(
        ok: true,
        messageAr: 'المفتاح صالح؛ النموذج $wanted غير متاح فسيُستخدم $pick.',
        model: pick,
      );
    } on InsatoException catch (e) {
      return ConnectionTestResult(ok: false, messageAr: e.messageAr);
    } catch (_) {
      return const ConnectionTestResult(
        ok: false,
        messageAr: 'تعذّر الاتصال بخدمة Gemini. تحقّق من اتصالك بالإنترنت.',
      );
    } finally {
      c.close();
    }
  }
}

/// The Gemini connection tester used by the Settings screen.
final geminiConnectionTesterProvider = Provider<GeminiConnectionTester>(
  (ref) => GeminiConnectionTester(),
);

/// Checks a Groq API key by listing the models it can use.
class GroqConnectionTester {
  /// Creates a tester. [client] / [baseUrl] are injectable for tests.
  GroqConnectionTester({this.client, this.baseUrl = kGroqApiBase, this.gate});

  /// HTTP client (tests).
  final http.Client? client;

  /// API base (tests).
  final String baseUrl;

  /// Rate gate (tests).
  final GroqRateGate? gate;

  /// Lists the models of [apiKey]. Never throws. The result's `model` is
  /// the model minutes will use: [model] when the key has it, otherwise the
  /// automatic choice ([pickPreferredGroqModel]).
  Future<ConnectionTestResult> test(String apiKey, {String? model}) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return const ConnectionTestResult(ok: false, messageAr: GS.testNoKey);
    }
    try {
      final models = await listGroqModels(
        apiKey: key,
        httpClient: client,
        baseUrl: baseUrl,
        gate: gate,
      );
      final wanted = model?.trim();
      if (wanted != null &&
          wanted.isNotEmpty &&
          models.any((m) => m.id == wanted && m.active)) {
        return ConnectionTestResult(
          ok: true,
          messageAr: GS.testOk,
          model: wanted,
        );
      }
      final pick = pickPreferredGroqModel(models);
      if (pick == null) {
        return const ConnectionTestResult(ok: false, messageAr: GS.noModel);
      }
      return ConnectionTestResult(ok: true, messageAr: GS.testOk, model: pick);
    } on InsatoException catch (e) {
      return ConnectionTestResult(ok: false, messageAr: e.messageAr);
    } catch (_) {
      return const ConnectionTestResult(
        ok: false,
        messageAr: GS.testUnreachable,
      );
    }
  }
}

/// The Groq connection tester used by the Settings screen.
final groqConnectionTesterProvider = Provider<GroqConnectionTester>(
  (ref) => GroqConnectionTester(),
);
