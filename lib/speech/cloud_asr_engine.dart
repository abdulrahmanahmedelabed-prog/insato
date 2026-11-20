// Free cloud speech recognition via Groq Whisper (OpenAI-compatible
// `POST /openai/v1/audio/transcriptions`, multipart: the WAV segment,
// `model` = whisper-large-v3 or whisper-large-v3-turbo,
// `response_format=verbose_json`, `temperature=0`, optional `language` and a
// short `prompt` with glossary terms).
//
// Free-plan limits are low (requests per minute, audio seconds per hour and
// per day): requests are queued under a per-minute budget, a 429 is waited
// out when Groq's Retry-After is short, and a long or daily refusal raises
// [CloudAsrQuotaExhaustedException] so the session continues on the device
// for the rest of the meeting (see `IsolateSegmentProcessor`).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import '../features/groq/groq_api.dart';
import '../features/groq/strings.dart';
import '../minutes/http_support.dart' show parseRetryAfter;
import 'sherpa_asr_engine.dart'
    show
        WhisperOutputFilter,
        normalizeLanguageCode,
        normalizeWhisperLanguage,
        prepareForWhisper,
        rmsDbfs;

/// Supplies the API key (e.g. from secure storage); null or empty when not
/// configured.
typedef ApiKeyProvider = FutureOr<String?> Function();

/// The free cloud transcription quota is used up for now (a daily limit,
/// or a wait longer than a meeting can afford). The session switches to
/// on-device transcription for the rest of the meeting when it can.
class CloudAsrQuotaExhaustedException extends AsrException {
  /// Creates the exception.
  const CloudAsrQuotaExhaustedException(
    super.messageAr, {
    this.daily = false,
    this.retryAfter,
    super.debugDetails,
  });

  /// True for a daily limit.
  final bool daily;

  /// Groq's stated wait, when known.
  final Duration? retryAfter;
}

/// Groq transcription endpoint.
const String kGroqTranscriptionsEndpoint = '$kGroqApiBase/audio/transcriptions';

/// Maximum characters of glossary terms sent as Whisper's `prompt` (Groq
/// limits the prompt to 224 tokens; the prompt only biases spelling).
const int kMaxCloudAsrPromptChars = 180;

/// Maximum glossary entries considered for the prompt (F2 priority order).
const int kMaxCloudAsrKeyterms = 50;

/// [AsrEngine] that sends each segment as a WAV file to Groq Whisper.
class GroqAsrEngine implements AsrEngine {
  /// Creates the engine. [client] is injectable for tests (an internal
  /// client is created and owned otherwise).
  GroqAsrEngine({
    required this.apiKeyProvider,
    http.Client? client,
    this.model = 'whisper-large-v3',
    this.endpoint = kGroqTranscriptionsEndpoint,
    this.maxAttempts = 4,
    this.maxRateLimitWaits = 6,
    this.retryBaseDelay = const Duration(milliseconds: 800),
    this.requestTimeout = const Duration(seconds: 60),
    this.maxQuotaWait = const Duration(seconds: 60),
    this.requestsPerMinute = 18,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? clock,
    GroqRateGate? gate,
    this.keyterms = const [],
    this.minRmsDbfs = -60,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _sleep = sleep ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now,
       _gate = gate ?? GroqRateGate.shared;

  /// Groq Whisper model (`whisper-large-v3` or `whisper-large-v3-turbo`).
  final String model;

  /// Custom vocabulary (F2: glossary terms and speaker names), in priority
  /// order; the first terms that fit [kMaxCloudAsrPromptChars] are sent as
  /// Whisper's `prompt`.
  final List<String> keyterms;

  /// Segments quieter than this (RMS dBFS) are reported as silence without
  /// a request.
  final double minRmsDbfs;

  /// Transcription endpoint.
  final String endpoint;

  /// Total attempts for network errors and 5xx.
  final int maxAttempts;

  /// Per-minute 429s waited out per segment before giving up on it.
  final int maxRateLimitWaits;

  /// First retry delay (doubles per attempt, capped at 20 s).
  final Duration retryBaseDelay;

  /// Timeout of one HTTP request.
  final Duration requestTimeout;

  /// Longest 429 wait taken; a longer one means the quota is used up for
  /// this meeting.
  final Duration maxQuotaWait;

  /// Requests started per rolling minute (below Groq's free 20 RPM).
  final int requestsPerMinute;

  /// Source of the API key, queried before every request (so a key changed
  /// in the settings applies at once). When it cannot be read (e.g. the
  /// keystore is locked), the key read last is used instead.
  final ApiKeyProvider apiKeyProvider;

  String? _lastKey;
  final http.Client _client;
  final bool _ownsClient;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _clock;
  final GroqRateGate _gate;
  final List<DateTime> _starts = [];
  Future<void> _slot = Future<void>.value();
  bool _disposed = false;

  @override
  String get name => 'groq-$model (cloud)';

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
        GS.asrKeyUnreadable,
        debugDetails: 'api key provider failed: $e',
        cause: e,
      );
    }
    if (k == null || k.isEmpty) {
      _lastKey = null;
      throw const MissingApiKeyException(GS.asrKeyMissing);
    }
    return _lastKey = k;
  }

  @override
  Future<void> initialize() async {
    await _key();
  }

  /// The `prompt` sent with every request: glossary terms joined by «، »
  /// up to [kMaxCloudAsrPromptChars]; null when there are none.
  String? get prompt => buildCloudAsrPrompt(keyterms);

  /// The multipart fields of a request (tests).
  Map<String, String> requestFields({String? language}) {
    final p = prompt;
    final lang = normalizeLanguageCode(language);
    return {
      'model': model,
      'response_format': 'verbose_json',
      'temperature': '0',
      'language': ?lang,
      'prompt': ?p,
    };
  }

  void _checkGate() {
    final b = _gate.blockOf(_lastKey ?? '', scope: 'audio');
    if (b == null) return;
    throw CloudAsrQuotaExhaustedException(
      GS.asrQuotaExhausted,
      daily: b.daily,
      retryAfter: b.remaining,
      debugDetails: 'blocked locally after a 429',
    );
  }

  /// Waits for a free request slot of the per-minute budget (requests are
  /// serialised through [_slot], so concurrent segments queue in order).
  Future<void> _takeSlot() {
    final next = _slot.then((_) async {
      while (true) {
        final now = _clock();
        _starts.removeWhere(
          (t) => now.difference(t) >= const Duration(minutes: 1),
        );
        if (_starts.length < math.max(1, requestsPerMinute)) {
          _starts.add(now);
          return;
        }
        final wait =
            _starts.first.add(const Duration(minutes: 1)).difference(now);
        await _sleep(wait > Duration.zero ? wait : Duration.zero);
        if (_disposed) return;
      }
    });
    _slot = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<AsrResult> transcribe(SpeechSegment segment,
      {String? languageHint}) async {
    if (_disposed) throw const AsrException(GS.asrClosed);
    if (segment.samples.isEmpty || rmsDbfs(segment.samples) < minRmsDbfs) {
      return const AsrResult(text: '', rejection: AsrRejection.silence);
    }
    final key = await _key();
    _checkGate();
    final wav = encodeWav16(prepareForWhisper(segment.samples));
    final hint = normalizeLanguageCode(languageHint);
    try {
      return await _transcribeWith(key, wav, hint);
    } on _UnsupportedLanguage {
      // The hinted language is not accepted: let Whisper detect it rather
      // than losing the segment.
      return _transcribeWith(key, wav, null);
    }
  }

  Future<AsrResult> _transcribeWith(
      String key, Uint8List wav, String? language) async {
    Object? lastError;
    var attempt = 1;
    var rateWaits = 0;
    while (true) {
      if (_disposed) throw const AsrException(GS.asrClosed);
      await _takeSlot();
      Duration? wait;
      try {
        final req = http.MultipartRequest('POST', Uri.parse(endpoint))
          ..headers['Authorization'] = 'Bearer $key'
          ..headers['Accept'] = 'application/json'
          ..fields.addAll(requestFields(language: language))
          ..files.add(
            http.MultipartFile.fromBytes('file', wav, filename: 'segment.wav'),
          );
        final resp = await http.Response.fromStream(
          await _client.send(req).timeout(requestTimeout),
        ).timeout(requestTimeout);
        final code = resp.statusCode;
        final body = utf8.decode(resp.bodyBytes, allowMalformed: true);
        if (code >= 200 && code < 300) {
          return parseGroqTranscription(body, fallbackLanguage: language);
        }
        if (code == 401 || code == 403) {
          throw MissingApiKeyException(
            GS.keyInvalid,
            debugDetails: 'HTTP $code: ${_snippet(body)}',
          );
        }
        if (code == 400 && language != null && _mentionsLanguage(body)) {
          throw const _UnsupportedLanguage();
        }
        if (code == 429) {
          final message = _errorMessage(body);
          final limit = classifyGroqLimit(429, message);
          final stated = parseRetryAfter(resp.headers['retry-after']) ??
              limit.wait;
          final w = stated ?? _backoff(rateWaits + 1);
          if (limit.kind == GroqLimitKind.daily ||
              w > maxQuotaWait ||
              rateWaits >= maxRateLimitWaits) {
            final daily = limit.kind == GroqLimitKind.daily;
            _gate.block(
              key,
              stated ?? (daily ? GroqRateGate.dailyBlock : maxQuotaWait),
              daily: daily,
              scope: 'audio',
            );
            throw CloudAsrQuotaExhaustedException(
              GS.asrQuotaExhausted,
              daily: daily,
              retryAfter: stated,
              debugDetails: 'HTTP 429: ${_snippet(body)}',
            );
          }
          rateWaits++;
          await _sleep(w);
          continue;
        }
        if (code == 408 || code >= 500) {
          lastError = 'HTTP $code: ${_snippet(body)}';
          wait = parseRetryAfter(resp.headers['retry-after']);
        } else {
          throw AsrException(
            GS.asrRejected(code),
            debugDetails: 'HTTP $code: ${_snippet(body)}',
          );
        }
      } on InsatoException {
        rethrow;
      } on _UnsupportedLanguage {
        rethrow;
      } on FormatException catch (e) {
        throw AsrException(GS.asrBadResponse,
            debugDetails: e.toString(), cause: e);
      } catch (e) {
        // Network error / timeout: retryable.
        lastError = e;
      }
      if (attempt >= maxAttempts) break;
      final backoff = _backoff(attempt);
      await _sleep(wait != null && wait > backoff
          ? (wait > const Duration(seconds: 60)
              ? const Duration(seconds: 60)
              : wait)
          : backoff);
      attempt++;
    }
    throw AsrException(
      GS.asrUnreachable,
      debugDetails: '$lastError',
      cause: lastError,
    );
  }

  Duration _backoff(int attempt) => Duration(
      milliseconds:
          math.min(retryBaseDelay.inMilliseconds * (1 << (attempt - 1)), 20000));

  static bool _mentionsLanguage(String body) =>
      (_errorMessage(body) ?? body).toLowerCase().contains('language');

  static String? _errorMessage(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final e = j['error'];
        if (e is Map && e['message'] is String) return e['message'] as String;
        if (e is String) return e;
      }
    } on FormatException {
      // Not JSON.
    }
    return body.isEmpty ? null : body;
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

/// Whisper's `prompt` from glossary [terms] (priority order): trimmed,
/// deduplicated (case-insensitive), joined with «، » while the result stays
/// within [maxChars]; null when nothing fits.
String? buildCloudAsrPrompt(
  List<String> terms, {
  int maxChars = kMaxCloudAsrPromptChars,
}) {
  final seen = <String>{};
  final out = StringBuffer();
  for (final raw in terms.take(kMaxCloudAsrKeyterms)) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty || !seen.add(t.toLowerCase())) continue;
    final add = out.isEmpty ? t : '، $t';
    if (out.length + add.length > maxChars) continue;
    out.write(add);
  }
  return out.isEmpty ? null : out.toString();
}

/// Parses a Groq / OpenAI `verbose_json` transcription into an [AsrResult].
///
/// * `text` passes the on-device hallucination filter
///   ([WhisperOutputFilter]); an output removed entirely is
///   [AsrRejection.filtered], an empty one [AsrRejection.noText] — both are
///   kept as unintelligible speech by the pipeline (F17), never dropped.
/// * `language` (a name such as `Arabic`, or a code) → ISO-639-1, else
///   [fallbackLanguage].
/// * confidence = exp(duration-weighted mean `avg_logprob`) of `segments`;
///   audio Whisper itself judges as no speech (`no_speech_prob` > 0.6 with
///   `avg_logprob` < -1) is no-text.
///
/// Throws [FormatException] when the body is not a JSON object.
AsrResult parseGroqTranscription(String body, {String? fallbackLanguage}) {
  final j = jsonDecode(body);
  if (j is! Map) throw const FormatException('Groq: not a JSON object');
  final raw = ((j['text'] as String?) ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final language = normalizeWhisperLanguage(j['language'] as String?) ??
      normalizeLanguageCode(fallbackLanguage);
  double? logprob;
  double? noSpeech;
  final segs = j['segments'];
  if (segs is List && segs.isNotEmpty) {
    var w = 0.0;
    var lp = 0.0;
    var ns = 0.0;
    for (final s in segs) {
      if (s is! Map) continue;
      final start = (s['start'] as num?)?.toDouble() ?? 0;
      final end = (s['end'] as num?)?.toDouble() ?? start;
      final d = math.max(0.1, end - start);
      final a = s['avg_logprob'];
      final n = s['no_speech_prob'];
      if (a is! num) continue;
      w += d;
      lp += a.toDouble() * d;
      ns += (n is num ? n.toDouble() : 0) * d;
    }
    if (w > 0) {
      logprob = lp / w;
      noSpeech = ns / w;
    }
  }
  final confidence =
      logprob == null ? null : math.exp(logprob).clamp(0.0, 1.0).toDouble();
  if (raw.isEmpty ||
      (noSpeech != null && logprob != null && noSpeech > 0.6 && logprob < -1)) {
    return AsrResult(
      text: '',
      language: language,
      confidence: confidence,
      rejection: AsrRejection.noText,
    );
  }
  final text = WhisperOutputFilter.clean(raw);
  if (text.isEmpty) {
    return AsrResult(
      text: '',
      language: language,
      confidence: confidence,
      rejection: AsrRejection.filtered,
    );
  }
  return AsrResult(text: text, language: language, confidence: confidence);
}
