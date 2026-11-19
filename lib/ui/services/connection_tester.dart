// "Test connection" of the Settings screen: one tiny structured request to
// the Claude Messages API with the key the user typed, mapped to an Arabic
// verdict.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import '../../minutes/claude_client.dart';

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
