import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/groq/groq_api.dart';
import 'package:insato/features/groq/strings.dart';
import 'package:insato/speech/cloud_asr_engine.dart';

SpeechSegment _seg([int n = 1600]) => SpeechSegment(
    index: 0,
    startMs: 0,
    samples: Float32List.fromList(List.generate(n, (i) => (i % 2) * 0.5)));

/// A Groq / OpenAI `verbose_json` transcription body.
String _vj(String text,
        {String? language = 'arabic',
        double avgLogprob = -0.2,
        double noSpeech = 0.01}) =>
    jsonEncode({
      'task': 'transcribe',
      'language': ?language,
      'duration': 2.0,
      'text': text,
      'segments': [
        {
          'id': 0,
          'start': 0.0,
          'end': 2.0,
          'text': text,
          'avg_logprob': avgLogprob,
          'no_speech_prob': noSpeech,
        }
      ],
      'x_groq': {'id': 'req_1'},
    });

http.Response _ok(String body) => http.Response.bytes(utf8.encode(body), 200,
    headers: const {'content-type': 'application/json'});

http.Response _limit(String message, {String? retryAfter}) => http.Response(
      jsonEncode({
        'error': {
          'message': message,
          'type': 'tokens',
          'code': 'rate_limit_exceeded',
        }
      }),
      429,
      headers: {'retry-after': ?retryAfter},
    );

GroqAsrEngine _engine(MockClient c,
        {String? key = 'secret', GroqRateGate? gate, List<Duration>? waits}) =>
    GroqAsrEngine(
      apiKeyProvider: () => key,
      client: c,
      sleep: (d) async => waits?.add(d),
      gate: gate ?? GroqRateGate(),
      requestsPerMinute: 1000,
    );

/// The multipart fields of a recorded request (name → value; the file
/// part as `file:<filename>:<bytes>`).
Map<String, String> _parts(http.Request r) {
  final type = r.headers['content-type']!;
  final boundary = RegExp('boundary=(.+)').firstMatch(type)!.group(1)!;
  final body = latin1.decode(r.bodyBytes);
  final out = <String, String>{};
  for (final part in body.split('--$boundary')) {
    final m = RegExp(r'name="([^"]+)"(?:; filename="([^"]+)")?').firstMatch(part);
    if (m == null) continue;
    final content = part.substring(part.indexOf('\r\n\r\n') + 4);
    final value = content.endsWith('\r\n')
        ? content.substring(0, content.length - 2)
        : content;
    out[m.group(1)!] = m.group(2) == null
        ? utf8.decode(latin1.encode(value))
        : 'file:${m.group(2)}:${value.length}';
  }
  return out;
}

void main() {
  group('encodeWav16', () {
    test('writes a canonical 44-byte PCM16 mono header', () {
      final wav = encodeWav16(Float32List.fromList([0, 1, -1, 0.5, 2, double.nan]));
      final b = ByteData.sublistView(wav);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(b.getUint32(4, Endian.little), 36 + 12);
      expect(ascii.decode(wav.sublist(8, 16)), 'WAVEfmt ');
      expect(b.getUint32(16, Endian.little), 16);
      expect(b.getUint16(20, Endian.little), 1);
      expect(b.getUint16(22, Endian.little), 1);
      expect(b.getUint32(24, Endian.little), 16000);
      expect(b.getUint32(28, Endian.little), 32000);
      expect(b.getUint16(32, Endian.little), 2);
      expect(b.getUint16(34, Endian.little), 16);
      expect(ascii.decode(wav.sublist(36, 40)), 'data');
      expect(b.getUint32(40, Endian.little), 12);
      expect(wav.length, 56);
      final pcm = [for (var i = 0; i < 6; i++) b.getInt16(44 + 2 * i, Endian.little)];
      expect(pcm, [0, 32767, -32768, 16384, 32767, 0]);
    });
  });

  group('parseGroqTranscription', () {
    test('reads text, language and confidence', () {
      final r = parseGroqTranscription(_vj(' مرحباً   بكم ', avgLogprob: -0.1));
      expect(r.text, 'مرحباً بكم');
      expect(r.language, 'ar');
      expect(r.confidence, closeTo(0.905, 0.01));
      expect(r.rejection, isNull);
    });

    test('language codes, names and the fallback', () {
      expect(parseGroqTranscription(_vj('hi', language: 'English')).language,
          'en');
      expect(parseGroqTranscription(_vj('hi', language: 'fr')).language, 'fr');
      expect(
          parseGroqTranscription(_vj('hola', language: null),
                  fallbackLanguage: 'es')
              .language,
          'es');
    });

    test('keeps unintelligible speech: empty, no-speech and hallucinations',
        () {
      final empty = parseGroqTranscription(_vj('  '));
      expect(empty.rejection, AsrRejection.noText);
      final noSpeech =
          parseGroqTranscription(_vj('شكرا', avgLogprob: -1.4, noSpeech: 0.9));
      expect(noSpeech.rejection, AsrRejection.noText);
      expect(noSpeech.text, isEmpty);
      final credits = parseGroqTranscription(
          _vj('ترجمة نانسي قنقر', language: 'arabic'));
      expect(credits.rejection, AsrRejection.filtered);
      expect(credits.text, isEmpty);
    });

    test('a low average log-probability lowers the confidence', () {
      final r = parseGroqTranscription(_vj('غير واضح', avgLogprob: -1.6));
      expect(r.text, 'غير واضح');
      expect(r.confidence, lessThan(0.3));
    });

    test('rejects non-objects', () {
      expect(() => parseGroqTranscription('nope'), throwsFormatException);
      expect(() => parseGroqTranscription('[]'), throwsFormatException);
    });
  });

  test('buildCloudAsrPrompt', () {
    expect(buildCloudAsrPrompt(const []), isNull);
    expect(buildCloudAsrPrompt(const ['أرامكو', ' Aramco ', 'aramco']),
        'أرامكو، Aramco');
    final long = buildCloudAsrPrompt([for (var i = 0; i < 60; i++) 'مصطلح$i']);
    expect(long!.length, lessThanOrEqualTo(kMaxCloudAsrPromptChars));
  });

  group('GroqAsrEngine', () {
    test('sends the documented multipart request and parses verbose_json',
        () async {
      late http.Request seen;
      final e = GroqAsrEngine(
        apiKeyProvider: () => 'secret',
        client: MockClient((req) async {
          seen = req;
          return _ok(_vj('We agreed.', language: 'english'));
        }),
        gate: GroqRateGate(),
        keyterms: const ['Insato', 'أرامكو'],
      );
      await e.initialize();
      final r = await e.transcribe(_seg());
      expect(seen.method, 'POST');
      expect(seen.url.toString(),
          'https://api.groq.com/openai/v1/audio/transcriptions');
      expect(seen.headers['Authorization'], 'Bearer secret');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      final parts = _parts(seen);
      expect(parts['model'], 'whisper-large-v3');
      expect(parts['response_format'], 'verbose_json');
      expect(parts['temperature'], '0');
      expect(parts['prompt'], 'Insato، أرامكو');
      expect(parts.containsKey('language'), isFalse);
      // A 0.1 s segment is centred in 1 s of audio (as on the device).
      expect(parts['file'], 'file:segment.wav:${44 + 16000 * 2}');
      expect(r.text, 'We agreed.');
      expect(r.language, 'en');
      expect(e.name, 'groq-whisper-large-v3 (cloud)');
    });

    test('the turbo model and the language hint are sent', () async {
      late http.Request seen;
      final e = GroqAsrEngine(
        apiKeyProvider: () => 'k',
        model: 'whisper-large-v3-turbo',
        client: MockClient((req) async {
          seen = req;
          return _ok(_vj('نعم', language: null));
        }),
        gate: GroqRateGate(),
      );
      final r = await e.transcribe(_seg(), languageHint: 'ar-SA');
      expect(_parts(seen)['model'], 'whisper-large-v3-turbo');
      expect(_parts(seen)['language'], 'ar');
      expect(r.language, 'ar');
    });

    test('a rejected language hint falls back to detection', () async {
      final langs = <String?>[];
      final e = _engine(MockClient((req) async {
        final lang = _parts(req)['language'];
        langs.add(lang);
        if (lang == 'xx') {
          return http.Response(
              '{"error":{"message":"language xx is not supported"}}', 400);
        }
        return _ok(_vj('ok', language: 'english'));
      }));
      final r = await e.transcribe(_seg(), languageHint: 'xx');
      expect(langs, ['xx', null]);
      expect(r.text, 'ok');
    });

    test('missing key throws MissingApiKeyException without a request',
        () async {
      var calls = 0;
      final e = _engine(MockClient((req) async {
        calls++;
        return _ok(_vj('x'));
      }), key: '  ');
      await expectLater(e.initialize(), throwsA(isA<MissingApiKeyException>()));
      await expectLater(
          e.transcribe(_seg()), throwsA(isA<MissingApiKeyException>()));
      expect(calls, 0);
    });

    test('an unreadable key store is transient, not a missing key', () async {
      final keys = <String>[];
      var fail = false;
      final e = GroqAsrEngine(
        apiKeyProvider: () {
          if (fail) throw const InsatoException('المخزن الآمن مقفل');
          return 'secret';
        },
        client: MockClient((req) async {
          keys.add(req.headers['Authorization']!);
          return _ok(_vj('مرحبا'));
        }),
        sleep: (_) async {},
        gate: GroqRateGate(),
      );
      await e.initialize();
      fail = true;
      expect((await e.transcribe(_seg())).text, 'مرحبا');
      expect(keys, ['Bearer secret']);

      final fresh = GroqAsrEngine(
        apiKeyProvider: () => throw const InsatoException('مقفل'),
        client: MockClient((req) async => _ok('{}')),
        sleep: (_) async {},
      );
      final err = await fresh
          .transcribe(_seg())
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(err, isA<AsrException>());
      expect(err, isNot(isA<MissingApiKeyException>()));
    });

    test('401 maps to MissingApiKeyException', () async {
      final e = _engine(MockClient((req) async => http.Response('no', 401)));
      await expectLater(
          e.transcribe(_seg()),
          throwsA(isA<MissingApiKeyException>()
              .having((x) => x.messageAr, 'message', GS.keyInvalid)));
    });

    test('a short 429 is waited out (Retry-After), 5xx and network retried',
        () async {
      var calls = 0;
      final waits = <Duration>[];
      final e = GroqAsrEngine(
        apiKeyProvider: () => 'k',
        client: MockClient((req) async {
          calls++;
          if (calls == 1) {
            return _limit(
                'Rate limit reached for model `whisper-large-v3` on requests '
                'per minute (RPM): Limit 20, Used 20, Requested 1. Please try '
                'again in 3s.',
                retryAfter: '5');
          }
          if (calls == 2) return http.Response('oops', 503);
          if (calls == 3) throw const SocketException('reset');
          return _ok(_vj('done', language: 'english'));
        }),
        sleep: (d) async => waits.add(d),
        retryBaseDelay: const Duration(milliseconds: 100),
        gate: GroqRateGate(),
      );
      final r = await e.transcribe(_seg());
      expect(r.text, 'done');
      expect(calls, 4);
      expect(waits, [
        const Duration(seconds: 5),
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 200),
      ]);
    });

    test('a daily limit is the end of the cloud quota: no more requests',
        () async {
      var calls = 0;
      final gate = GroqRateGate();
      final e = _engine(MockClient((req) async {
        calls++;
        return _limit(
            'Rate limit reached for model `whisper-large-v3` on audio seconds '
            'per day (ASD): Limit 28800, Used 28790, Requested 30. Please try '
            'again in 2h10m.',
            retryAfter: '7800');
      }), gate: gate);
      final err = await e
          .transcribe(_seg())
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(err, isA<CloudAsrQuotaExhaustedException>());
      expect((err! as CloudAsrQuotaExhaustedException).daily, isTrue);
      expect((err as CloudAsrQuotaExhaustedException).messageAr,
          GS.asrQuotaExhausted);
      expect(calls, 1);
      // Blocked locally: the next segment is not even sent.
      await expectLater(e.transcribe(_seg()),
          throwsA(isA<CloudAsrQuotaExhaustedException>()));
      expect(calls, 1);
      expect(gate.blockOf('secret', scope: 'audio')!.daily, isTrue);
      // The chat scope (minutes) is not affected.
      expect(gate.blockOf('secret'), isNull);
    });

    test('a long per-hour wait also ends the cloud quota for the meeting',
        () async {
      final e = _engine(MockClient((req) async => _limit(
          'Rate limit reached on audio seconds per hour (ASH): Limit 7200, '
          'Used 7200, Requested 10.',
          retryAfter: '900')));
      final err = await e
          .transcribe(_seg())
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(err, isA<CloudAsrQuotaExhaustedException>());
      expect((err! as CloudAsrQuotaExhaustedException).daily, isFalse);
      expect((err as CloudAsrQuotaExhaustedException).retryAfter, const Duration(seconds: 900));
    });

    test('requests are queued under the per-minute budget', () async {
      var now = DateTime(2026, 11, 20, 10);
      final waits = <Duration>[];
      final e = GroqAsrEngine(
        apiKeyProvider: () => 'k',
        client: MockClient((req) async => _ok(_vj('x'))),
        sleep: (d) async {
          waits.add(d);
          now = now.add(d);
        },
        clock: () => now,
        requestsPerMinute: 2,
        gate: GroqRateGate(),
      );
      await Future.wait([for (var i = 0; i < 3; i++) e.transcribe(_seg())]);
      expect(waits, [const Duration(minutes: 1)]);
    });

    test('exhausted retries throw AsrException', () async {
      var calls = 0;
      final e = _engine(MockClient((req) async {
        calls++;
        return http.Response('down', 502);
      }));
      await expectLater(e.transcribe(_seg()), throwsA(isA<AsrException>()));
      expect(calls, e.maxAttempts);
    });

    test('other 4xx and bad JSON throw AsrException immediately', () async {
      var calls = 0;
      final e = _engine(MockClient((req) async {
        calls++;
        return http.Response('bad', 413);
      }));
      await expectLater(e.transcribe(_seg()), throwsA(isA<AsrException>()));
      expect(calls, 1);
      final e2 = _engine(MockClient((req) async => http.Response('<html>', 200)));
      await expectLater(e2.transcribe(_seg()), throwsA(isA<AsrException>()));
    });

    test('empty segment returns empty result without a request', () async {
      final e = _engine(MockClient((req) async => fail('no request expected')));
      expect((await e.transcribe(_seg(0))).isEmpty, isTrue);
    });

    test('disposed engine rejects calls', () async {
      final e = _engine(MockClient((req) async => _ok('{}')));
      await e.dispose();
      await expectLater(e.transcribe(_seg()), throwsA(isA<AsrException>()));
    });
  });
}
