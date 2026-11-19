// Cloud speech recognition via Deepgram's pre-recorded REST API (nova-3).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import 'sherpa_asr_engine.dart' show normalizeLanguageCode, rmsDbfs;

/// Supplies the Deepgram API key (e.g. from secure storage); null or empty
/// when not configured.
typedef ApiKeyProvider = FutureOr<String?> Function();

/// [AsrEngine] that sends each segment as a WAV file to Deepgram.
///
/// Uses `model=nova-3` with `language=multi` (multilingual code-switching)
/// unless a language hint is given. Retries 408/429/5xx and network errors
/// with exponential backoff (honouring `Retry-After`). Every request opts
/// out of Deepgram's Model Improvement Program (`mip_opt_out=true`).
class CloudAsrEngine implements AsrEngine {
  /// Creates the engine. [client] is injectable for tests (an internal
  /// client is created and owned otherwise).
  CloudAsrEngine({
    required this.apiKeyProvider,
    http.Client? client,
    this.model = 'nova-3',
    this.endpoint = 'https://api.deepgram.com/v1/listen',
    this.maxAttempts = 4,
    this.retryBaseDelay = const Duration(milliseconds: 800),
    this.requestTimeout = const Duration(seconds: 60),
    Future<void> Function(Duration)? sleep,
    this.keyterms = const [],
    this.minRmsDbfs = -60,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _sleep = sleep ?? Future<void>.delayed;

  /// Convenience constructor with a fixed [apiKey].
  factory CloudAsrEngine.withKey(String? apiKey, {http.Client? client}) =>
      CloudAsrEngine(apiKeyProvider: () => apiKey, client: client);

  /// Deepgram model name.
  final String model;

  /// Custom vocabulary (F2, glossary terms and speaker names) sent as
  /// repeated `keyterm` parameters (nova-3 keyterm prompting). At most
  /// [kMaxDeepgramKeyterms] non-blank terms are used.
  final List<String> keyterms;

  /// Segments quieter than this (RMS dBFS) are reported as silence without
  /// a request.
  final double minRmsDbfs;

  /// Pre-recorded transcription endpoint.
  final String endpoint;

  /// Total attempts for retryable failures.
  final int maxAttempts;

  /// First retry delay (doubles per attempt, capped at 20 s).
  final Duration retryBaseDelay;

  /// Timeout of one HTTP request.
  final Duration requestTimeout;

  /// Source of the API key, queried before every request (so a key changed
  /// in the settings applies at once). When it cannot be read (e.g. the
  /// keystore is locked), the key read last is used instead.
  final ApiKeyProvider apiKeyProvider;

  /// Key returned by the last successful [apiKeyProvider] call.
  String? _lastKey;

  final http.Client _client;
  final bool _ownsClient;
  final Future<void> Function(Duration) _sleep;
  bool _disposed = false;

  @override
  String get name => 'deepgram-$model (cloud)';

  Future<String> _key() async {
    String? k;
    try {
      k = (await apiKeyProvider())?.trim();
    } catch (e) {
      // The key store failed (not "no key"): keep using the key read earlier
      // in this session, or fail this segment as a transient error so it is
      // not reported as a missing key.
      final last = _lastKey;
      if (last != null) return last;
      throw AsrException(
        'تعذّرت قراءة مفتاح Deepgram المحفوظ الآن. افتح قفل الجهاز وحاول '
        'مجددًا.',
        debugDetails: 'api key provider failed: $e',
        cause: e,
      );
    }
    if (k == null || k.isEmpty) {
      _lastKey = null;
      throw const MissingApiKeyException(
          'لم يتم إدخال مفتاح Deepgram. أضفه من الإعدادات لاستخدام التفريغ السحابي.');
    }
    return _lastKey = k;
  }

  @override
  Future<void> initialize() async {
    await _key();
  }

  /// Builds the request URI for an optional ISO-639-1 [language].
  Uri buildUri({String? language}) {
    final lang = normalizeLanguageCode(language);
    final terms = <String>{
      for (final t in keyterms)
        if (t.trim().isNotEmpty) t.trim().replaceAll(RegExp(r'\s+'), ' '),
    }.take(kMaxDeepgramKeyterms).toList();
    return Uri.parse(endpoint).replace(queryParameters: {
      if (terms.isNotEmpty) 'keyterm': terms,
      'model': model,
      'language': lang ?? 'multi',
      'smart_format': 'true',
      'punctuate': 'true',
      // Private meeting audio: opt out of Deepgram's Model Improvement
      // Program so requests are not retained for training. Every request
      // (retries and the multilingual fallback included) is built here.
      'mip_opt_out': 'true',
    });
  }

  @override
  Future<AsrResult> transcribe(SpeechSegment segment,
      {String? languageHint}) async {
    if (_disposed) {
      throw const AsrException('محرك التفريغ السحابي مُغلق.');
    }
    if (segment.samples.isEmpty || rmsDbfs(segment.samples) < minRmsDbfs) {
      return const AsrResult(text: '', rejection: AsrRejection.silence);
    }
    final key = await _key();
    final body = encodeWav16(segment.samples);
    final hint = normalizeLanguageCode(languageHint);
    try {
      return await _transcribeWith(key, body, hint);
    } on _UnsupportedLanguage {
      // The hinted language is not available for this model: fall back to
      // multilingual detection rather than losing the segment.
      return _transcribeWith(key, body, null);
    }
  }

  Future<AsrResult> _transcribeWith(
      String key, Uint8List wav, String? language) async {
    final uri = buildUri(language: language);
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      Duration? retryAfter;
      try {
        final resp = await _client
            .post(uri,
                headers: {
                  'Authorization': 'Token $key',
                  'Content-Type': 'audio/wav',
                  'Accept': 'application/json',
                },
                body: wav)
            .timeout(requestTimeout);
        final code = resp.statusCode;
        if (code >= 200 && code < 300) {
          return parseDeepgramResponse(utf8.decode(resp.bodyBytes),
              fallbackLanguage: language);
        }
        if (code == 401 || code == 403) {
          throw MissingApiKeyException(
            'مفتاح Deepgram غير صالح أو لا يملك صلاحية. تحقّق منه في الإعدادات.',
            debugDetails: 'HTTP $code: ${_snippet(resp.body)}',
          );
        }
        if (code == 402) {
          throw AsrException(
            'رصيد حساب Deepgram غير كافٍ لإتمام التفريغ.',
            debugDetails: 'HTTP 402: ${_snippet(resp.body)}',
          );
        }
        if (code == 400 && language != null) {
          throw const _UnsupportedLanguage();
        }
        if (code == 408 || code == 429 || code >= 500) {
          lastError = 'HTTP $code: ${_snippet(resp.body)}';
          retryAfter = parseRetryAfter(resp.headers['retry-after']);
        } else {
          throw AsrException(
            'رفض خادم Deepgram طلب التفريغ (رمز $code).',
            debugDetails: 'HTTP $code: ${_snippet(resp.body)}',
          );
        }
      } on InsatoException {
        rethrow;
      } on _UnsupportedLanguage {
        rethrow;
      } on FormatException catch (e) {
        throw AsrException('استجابة غير مفهومة من خادم Deepgram.',
            debugDetails: e.toString(), cause: e);
      } catch (e) {
        // Network error / timeout: retryable.
        lastError = e;
      }
      if (attempt < maxAttempts) {
        final backoff = Duration(
            milliseconds: math.min(
                retryBaseDelay.inMilliseconds * (1 << (attempt - 1)), 20000));
        final wait = retryAfter != null && retryAfter > backoff
            ? (retryAfter > const Duration(seconds: 60)
                ? const Duration(seconds: 60)
                : retryAfter)
            : backoff;
        await _sleep(wait);
      }
    }
    throw AsrException(
      'تعذّر الاتصال بخدمة التفريغ السحابي. تحقق من الاتصال بالإنترنت.',
      debugDetails: '$lastError',
      cause: lastError,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_ownsClient) _client.close();
  }

  static String _snippet(String s) =>
      s.length <= 300 ? s : '${s.substring(0, 300)}…';
}

class _UnsupportedLanguage implements Exception {
  const _UnsupportedLanguage();
}

// ---------------------------------------------------------------------------
// Pure helpers (unit-tested).
// ---------------------------------------------------------------------------

/// Encodes mono float [samples] as a 16-bit PCM RIFF/WAV file at
/// [sampleRate] (44-byte canonical header, little-endian).
Uint8List encodeWav16(Float32List samples, {int sampleRate = kSampleRate}) {
  const channels = 1;
  const bitsPerSample = 16;
  final dataLen = samples.length * 2;
  final out = Uint8List(44 + dataLen);
  final b = ByteData.sublistView(out);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out[offset + i] = s.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, channels, Endian.little);
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(
      28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little); // bytes/s
  b.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little); // align
  b.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = samples[i];
    final int s;
    if (v.isNaN) {
      s = 0;
    } else if (v >= 1.0) {
      s = 32767;
    } else if (v <= -1.0) {
      s = -32768;
    } else {
      s = (v * 32767.0).round();
    }
    b.setInt16(44 + i * 2, s, Endian.little);
  }
  return out;
}

/// Maximum `keyterm` parameters sent to Deepgram.
const int kMaxDeepgramKeyterms = 50;

/// Parses a Deepgram pre-recorded response body into an [AsrResult].
///
/// Reads `results.channels[0].alternatives[0].transcript` / `.confidence`
/// and the language from `channels[0].detected_language`, then
/// `alternatives[0].languages[0]`, then [fallbackLanguage]. Throws
/// [FormatException] when the body is not the expected JSON shape.
AsrResult parseDeepgramResponse(String body, {String? fallbackLanguage}) {
  final j = jsonDecode(body);
  if (j is! Map) throw const FormatException('Deepgram: not a JSON object');
  final results = j['results'];
  if (results is! Map) throw const FormatException('Deepgram: no results');
  final channels = results['channels'];
  if (channels is! List || channels.isEmpty) {
    return const AsrResult(text: '', rejection: AsrRejection.noText);
  }
  final ch = channels.first;
  if (ch is! Map) throw const FormatException('Deepgram: bad channel');
  final alts = ch['alternatives'];
  final alt = (alts is List && alts.isNotEmpty && alts.first is Map)
      ? alts.first as Map
      : const {};
  final text = ((alt['transcript'] as String?) ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) {
    return const AsrResult(text: '', rejection: AsrRejection.noText);
  }
  final conf = alt['confidence'];
  String? lang = normalizeLanguageCode(ch['detected_language'] as String?);
  if (lang == null) {
    final langs = alt['languages'];
    if (langs is List && langs.isNotEmpty && langs.first is String) {
      lang = normalizeLanguageCode(langs.first as String);
    }
  }
  lang ??= normalizeLanguageCode(fallbackLanguage);
  return AsrResult(
    text: text,
    language: lang,
    confidence: conf is num ? conf.toDouble().clamp(0.0, 1.0) : null,
  );
}

/// Parses a `Retry-After` header given in seconds; null otherwise.
Duration? parseRetryAfter(String? header) {
  if (header == null) return null;
  final secs = int.tryParse(header.trim());
  if (secs == null || secs < 0) return null;
  return Duration(seconds: secs);
}
