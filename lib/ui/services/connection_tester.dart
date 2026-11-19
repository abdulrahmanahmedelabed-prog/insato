// "Test connection" of the Settings screen, mapped to an Arabic verdict:
// * Claude: one tiny structured request to the Messages API;
// * Gemini: `models.list` with the key — it validates the key without using
//   any of the (very small) free generation quota, and checks that the
//   configured model exists (otherwise suggests the newest Flash model).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import '../../minutes/claude_client.dart';
import '../../minutes/gemini_client.dart';

/// Outcome of [ClaudeConnectionTester.test].
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

/// Checks an Anthropic API key with a minimal request.
class ClaudeConnectionTester {
  /// Creates a tester. [client] is injectable for tests; when omitted each
  /// test uses (and closes) its own HTTP client.
  ClaudeConnectionTester({this.client, this.endpoint});

  /// HTTP client (tests).
  final http.Client? client;

  /// Endpoint override (tests).
  final Uri? endpoint;

  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'properties': {
      'ok': {'type': 'boolean'},
    },
    'required': ['ok'],
    'additionalProperties': false,
  };

  /// Sends one tiny request with [apiKey] to [model].
  ///
  /// Never throws: failures become a result with `ok == false` and an Arabic
  /// explanation (invalid key, unavailable model, network…).
  Future<ConnectionTestResult> test(
    String apiKey, {
    String model = kDefaultClaudeModel,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return const ConnectionTestResult(
        ok: false,
        messageAr: 'أدخل مفتاح Anthropic API أولًا.',
      );
    }
    final m = model.trim().isEmpty ? kDefaultClaudeModel : model.trim();
    final c = ClaudeClient(
      apiKey: key,
      client: client,
      model: m,
      endpoint: endpoint,
      maxAttempts: 2,
      baseRetryDelay: const Duration(milliseconds: 500),
      maxRetryDelay: const Duration(seconds: 5),
      idleTimeout: const Duration(seconds: 45),
    );
    try {
      final r = await c.createStructured(
        system: 'Connectivity check. Answer with {"ok": true}.',
        user: 'ping',
        schema: _schema,
        effort: 'low',
        maxTokens: 1024,
      );
      return ConnectionTestResult(
        ok: true,
        messageAr: 'الاتصال ناجح والمفتاح صالح.',
        model: r.model,
      );
    } on MissingApiKeyException catch (e) {
      return ConnectionTestResult(ok: false, messageAr: e.messageAr);
    } on MinutesGenerationException catch (e) {
      // The key was accepted and the model answered; the tiny token budget
      // simply ran out (or the model declined the ping). Both prove the key
      // and model work.
      final d = e.debugDetails ?? '';
      if (d.contains('stop_reason=max_tokens') ||
          d.contains('stop_reason=refusal')) {
        return ConnectionTestResult(
          ok: true,
          messageAr: 'الاتصال ناجح والمفتاح صالح.',
          model: m,
        );
      }
      return ConnectionTestResult(ok: false, messageAr: e.messageAr);
    } on InsatoException catch (e) {
      return ConnectionTestResult(ok: false, messageAr: e.messageAr);
    } catch (_) {
      return const ConnectionTestResult(
        ok: false,
        messageAr: 'تعذّر الاتصال بخدمة Claude. تحقّق من اتصالك بالإنترنت.',
      );
    } finally {
      c.close();
    }
  }
}

/// The connection tester used by the Settings screen.
final claudeConnectionTesterProvider = Provider<ClaudeConnectionTester>(
  (ref) => ClaudeConnectionTester(),
);

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
