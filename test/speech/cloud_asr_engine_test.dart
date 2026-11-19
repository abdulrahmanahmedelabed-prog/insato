import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/speech/cloud_asr_engine.dart';

SpeechSegment _seg([int n = 1600]) => SpeechSegment(
    index: 0,
    startMs: 0,
    samples: Float32List.fromList(List.generate(n, (i) => (i % 2) * 0.5)));

String _dg(String transcript,
        {double confidence = 0.93, String? detected, List<String>? langs}) =>
    jsonEncode({
      'metadata': {'request_id': 'x'},
      'results': {
        'channels': [
          {
            'detected_language': ?detected,
            'alternatives': [
              {
                'transcript': transcript,
                'confidence': confidence,
                'languages': ?langs,
              }
            ]
          }
        ]
      }
    });

CloudAsrEngine _engine(MockClient c, {String? key = 'secret'}) =>
    CloudAsrEngine(
        apiKeyProvider: () => key, client: c, sleep: (_) async {});

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

  group('parseDeepgramResponse', () {
    test('reads transcript, confidence and detected language', () {
      final r = parseDeepgramResponse(_dg(' مرحباً   بكم ', detected: 'ar'));
      expect(r.text, 'مرحباً بكم');
      expect(r.confidence, closeTo(0.93, 1e-9));
      expect(r.language, 'ar');
    });

    test('falls back to alternatives[0].languages then the hint', () {
      expect(parseDeepgramResponse(_dg('hello', langs: ['en-US'])).language,
          'en');
      expect(
          parseDeepgramResponse(_dg('bonjour'), fallbackLanguage: 'fr')
              .language,
          'fr');
      expect(parseDeepgramResponse(_dg('x')).language, isNull);
    });

    test('empty transcript and empty channels give an empty result', () {
      expect(parseDeepgramResponse(_dg('   ')).isEmpty, isTrue);
      expect(
          parseDeepgramResponse(jsonEncode({
            'results': {'channels': []}
          })).isEmpty,
          isTrue);
    });

    test('malformed bodies throw FormatException', () {
      expect(() => parseDeepgramResponse('nope'), throwsFormatException);
      expect(() => parseDeepgramResponse('[]'), throwsFormatException);
      expect(() => parseDeepgramResponse('{}'), throwsFormatException);
    });
  });

  test('parseRetryAfter', () {
    expect(parseRetryAfter('3'), const Duration(seconds: 3));
    expect(parseRetryAfter('Wed, 21 Oct 2015 07:28:00 GMT'), isNull);
    expect(parseRetryAfter(null), isNull);
  });

  group('CloudAsrEngine', () {
    test('sends the documented request and parses the response', () async {
      late http.Request seen;
      final e = _engine(MockClient((req) async {
        seen = req;
        return http.Response.bytes(
            utf8.encode(_dg('We agreed.', detected: 'en')), 200);
      }));
      await e.initialize();
      final r = await e.transcribe(_seg());
      expect(seen.method, 'POST');
      expect(seen.url.host, 'api.deepgram.com');
      expect(seen.url.path, '/v1/listen');
      expect(seen.url.queryParameters, {
        'model': 'nova-3',
        'language': 'multi',
        'smart_format': 'true',
        'punctuate': 'true',
      });
      expect(seen.headers['Authorization'], 'Token secret');
      expect(seen.headers['Content-Type'], 'audio/wav');
      expect(ascii.decode(seen.bodyBytes.sublist(0, 4)), 'RIFF');
      expect(seen.bodyBytes.length, 44 + 1600 * 2);
      expect(r.text, 'We agreed.');
      expect(r.language, 'en');
      expect(e.name, contains('nova-3'));
    });

    test('uses the language hint', () async {
      late Uri uri;
      final e = _engine(MockClient((req) async {
        uri = req.url;
        return http.Response.bytes(utf8.encode(_dg('نعم')), 200);
      }));
      final r = await e.transcribe(_seg(), languageHint: 'ar-SA');
      expect(uri.queryParameters['language'], 'ar');
      expect(r.language, 'ar');
    });

    test('falls back to multi when the hinted language is rejected', () async {
      final langs = <String?>[];
      final e = _engine(MockClient((req) async {
        langs.add(req.url.queryParameters['language']);
        if (req.url.queryParameters['language'] == 'xx') {
          return http.Response('{"err_msg":"unsupported"}', 400);
        }
        return http.Response.bytes(utf8.encode(_dg('ok')), 200);
      }));
      final r = await e.transcribe(_seg(), languageHint: 'xx');
      expect(langs, ['xx', 'multi']);
      expect(r.text, 'ok');
    });

    test('missing key throws MissingApiKeyException without a request',
        () async {
      var calls = 0;
      final e = _engine(MockClient((req) async {
        calls++;
        return http.Response('', 200);
      }), key: '  ');
      await expectLater(
          e.initialize(), throwsA(isA<MissingApiKeyException>()));
      await expectLater(
          e.transcribe(_seg()), throwsA(isA<MissingApiKeyException>()));
      expect(calls, 0);
    });

    test('401 maps to MissingApiKeyException', () async {
      final e = _engine(MockClient((req) async => http.Response('no', 401)));
      await expectLater(
          e.transcribe(_seg()), throwsA(isA<MissingApiKeyException>()));
    });

    test('retries 429/5xx/network errors with backoff then succeeds',
        () async {
      var calls = 0;
      final waits = <Duration>[];
      final e = CloudAsrEngine(
        apiKeyProvider: () => 'k',
        client: MockClient((req) async {
          calls++;
          if (calls == 1) {
            return http.Response('slow down', 429,
                headers: {'retry-after': '5'});
          }
          if (calls == 2) return http.Response('oops', 503);
          if (calls == 3) throw const SocketException('reset');
          return http.Response.bytes(utf8.encode(_dg('done')), 200);
        }),
        sleep: (d) async => waits.add(d),
        retryBaseDelay: const Duration(milliseconds: 100),
      );
      final r = await e.transcribe(_seg());
      expect(r.text, 'done');
      expect(calls, 4);
      expect(waits, [
        const Duration(seconds: 5),
        const Duration(milliseconds: 200),
        const Duration(milliseconds: 400),
      ]);
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
      final e = _engine(MockClient((req) async => http.Response('', 200)));
      await e.dispose();
      await expectLater(e.transcribe(_seg()), throwsA(isA<AsrException>()));
    });
  });
}
