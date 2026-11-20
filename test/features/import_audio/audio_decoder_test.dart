import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/features/import_audio/audio_decoder.dart';
import 'package:insato/features/import_audio/audio_formats.dart';

import 'import_fakes.dart';

Float32List _sine(int rate, int ms, {double hz = 440, double amp = 0.5}) {
  final n = rate * ms ~/ 1000;
  return Float32List.fromList([
    for (var i = 0; i < n; i++) amp * math.sin(2 * math.pi * hz * i / rate),
  ]);
}

Future<Float32List> _collect(Stream<Float32List> s) async {
  final parts = <Float32List>[];
  await for (final c in s) {
    parts.add(c);
  }
  final out = Float32List(parts.fold(0, (a, c) => a + c.length));
  var o = 0;
  for (final c in parts) {
    out.setRange(o, o + c.length, c);
    o += c.length;
  }
  return out;
}

double _rms(Float32List x, [int from = 0, int? to]) {
  final end = to ?? x.length;
  var s = 0.0;
  for (var i = from; i < end; i++) {
    s += x[i] * x[i];
  }
  return math.sqrt(s / math.max(1, end - from));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pcmChunksToMono', () {
    test('8 kHz phone audio is resampled to 16 kHz', () async {
      final tone = _sine(8000, 2000, hz: 300);
      final chunks = [
        for (var i = 0; i < tone.length; i += 1000)
          PcmChunk(
            pcm16(Float32List.sublistView(tone, i, math.min(i + 1000, tone.length))),
            sampleRate: 8000,
            channels: 1,
          ),
      ];
      final out = await _collect(pcmChunksToMono(Stream.fromIterable(chunks)));
      expect(out.length, closeTo(32000, 2));
      // Energy is preserved (300 Hz is well inside the band).
      expect(_rms(out, 1000, 31000), closeTo(_rms(tone), 0.02));
    });

    test('stereo 48 kHz is downmixed and resampled', () async {
      final left = _sine(48000, 1000, hz: 500);
      final right = Float32List(left.length); // silent channel
      final out = await _collect(
        pcmChunksToMono(
          Stream.value(
            PcmChunk(stereoPcm16(left, right), sampleRate: 48000, channels: 2),
          ),
        ),
      );
      expect(out.length, closeTo(16000, 2));
      // Average of the channels: half the amplitude.
      expect(_rms(out, 500, 15500), closeTo(_rms(left) / 2, 0.02));
    });

    test('a mid-stream format change (HE-AAC) keeps the timeline', () async {
      final a = _sine(22050, 500);
      final b = _sine(44100, 500);
      final out = await _collect(
        pcmChunksToMono(
          Stream.fromIterable([
            PcmChunk(pcm16(a), sampleRate: 22050, channels: 1),
            PcmChunk(Uint8List(0), sampleRate: 44100, channels: 1),
            PcmChunk(pcm16(b), sampleRate: 44100, channels: 1),
          ]),
        ),
      );
      expect(out.length, closeTo(16000, 4));
    });

    test('an invalid format is a decode failure', () async {
      expect(
        _collect(
          pcmChunksToMono(
            Stream.value(PcmChunk(Uint8List(4), sampleRate: 0, channels: 1)),
          ),
        ),
        throwsA(
          isA<ImportException>().having(
            (e) => e.failure,
            'failure',
            ImportFailure.decodeFailed,
          ),
        ),
      );
    });
  });

  group('ImportAudioDecoder', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('insato_dec_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('WAV is decoded in pure Dart without a platform decoder', () async {
      final path = '${tmp.path}/a.wav';
      final w = await WavWriter.open(path, sampleRate: 44100, channels: 2);
      final tone = _sine(44100, 1500);
      await w.appendPcm16(stereoPcm16(tone, tone));
      await w.close();

      final audio = await const ImportAudioDecoder().open(
        path,
        AudioContainer.wav,
      );
      expect(audio.nativeDecoder, isFalse);
      expect(audio.durationMs, 1500);
      expect(audio.sourceSampleRate, 44100);
      expect(audio.sourceChannels, 2);
      expect(audio.codec, 'pcm_s16');
      final out = await _collect(audio.samples());
      expect(out.length, closeTo(24000, 2));
      expect(() => audio.samples(), throwsStateError);
    });

    test('compressed formats go to the platform decoder', () async {
      final tone = _sine(16000, 1000);
      final native = FakeNativeDecoder(
        chunks: [PcmChunk(pcm16(tone), sampleRate: 16000, channels: 1)],
        info: const NativeAudioInfo(
          sampleRate: 16000,
          channels: 1,
          durationMs: 1000,
          codec: 'audio/mp4a-latm',
          creationDate: '2024-11-15T10:30:00Z',
        ),
      );
      final audio = await ImportAudioDecoder(
        native: native,
      ).open('/x/call.m4a', AudioContainer.mp4);
      expect(audio.nativeDecoder, isTrue);
      expect(audio.codec, 'audio/mp4a-latm');
      expect(audio.creationDate, '2024-11-15T10:30:00Z');
      final out = await _collect(audio.samples());
      expect(out.length, 16000);
      expect(native.closed, 1, reason: 'released at the end of the stream');
    });

    test('cancelling the stream releases the platform decoder', () async {
      final native = FakeNativeDecoder(
        chunks: [
          for (var i = 0; i < 10; i++)
            PcmChunk(pcm16(_sine(16000, 100)), sampleRate: 16000, channels: 1),
        ],
      );
      final audio = await ImportAudioDecoder(
        native: native,
      ).open('/x/a.mp3', AudioContainer.mp3);
      await for (final _ in audio.samples()) {
        break;
      }
      expect(native.closed, 1);
    });

    test('without a platform decoder compressed files are unsupported', () {
      expect(
        const ImportAudioDecoder().open('/x/a.ogg', AudioContainer.ogg),
        throwsA(
          isA<ImportException>()
              .having((e) => e.failure, 'failure', ImportFailure.unsupported)
              .having((e) => e.messageAr, 'messageAr', contains('OGG')),
        ),
      );
    });

    test('an unsupported codec names the format in Arabic', () {
      final native = FakeNativeDecoder(
        openError: const ImportException(ImportFailure.unsupported, 'x'),
      );
      expect(
        ImportAudioDecoder(native: native).open('/x/a.amr', AudioContainer.amrNb),
        throwsA(
          isA<ImportException>().having(
            (e) => e.messageAr,
            'messageAr',
            allOf(contains('AMR'), contains('لا يدعم')),
          ),
        ),
      );
    });

    test('a compressed WAV falls back to the platform decoder', () async {
      // WAVE_FORMAT_MULAW (7): not decoded in Dart.
      final path = '${tmp.path}/ulaw.wav';
      final header = buildWavHeader(sampleRate: 8000, channels: 1, dataBytes: 8);
      ByteData.sublistView(header).setUint16(20, 7, Endian.little);
      ByteData.sublistView(header).setUint16(34, 8, Endian.little);
      File(path).writeAsBytesSync([...header, ...List.filled(8, 0xFF)]);
      final native = FakeNativeDecoder(
        chunks: [PcmChunk(pcm16(Float32List(8000)), sampleRate: 8000, channels: 1)],
        info: const NativeAudioInfo(sampleRate: 8000, channels: 1),
      );
      final audio = await ImportAudioDecoder(
        native: native,
      ).open(path, AudioContainer.wav);
      expect(audio.nativeDecoder, isTrue);
      expect(native.opened, [path]);
    });
  });

  group('MethodChannelAudioDecoder', () {
    const channel = MethodChannel('insato/audio_decoder');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('open / read / close protocol', () async {
      final calls = <MethodCall>[];
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'open':
            return {
              'handle': 7,
              'sampleRate': 44100,
              'channels': 2,
              'durationMs': 61000,
              'codec': 'audio/mpeg',
              'creationDate': '20241115T103012.000Z',
            };
          case 'read':
            reads++;
            if (reads > 1) return null;
            return {
              'data': Uint8List(8),
              'sampleRate': 44100,
              'channels': 2,
            };
          default:
            return null;
        }
      });
      const decoder = MethodChannelAudioDecoder(maxChunkBytes: 1234);
      final session = await decoder.open('/x/a.mp3');
      expect(session.info.sampleRate, 44100);
      expect(session.info.channels, 2);
      expect(session.info.durationMs, 61000);
      expect(session.info.codec, 'audio/mpeg');
      expect(session.info.creationDate, '20241115T103012.000Z');
      final c = await session.read();
      expect(c!.bytes, hasLength(8));
      expect(await session.read(), isNull);
      await session.close();
      await session.close();
      expect(calls.map((c) => c.method), ['open', 'read', 'read', 'close']);
      expect(calls[0].arguments, {'path': '/x/a.mp3'});
      expect(calls[1].arguments, {'handle': 7, 'maxBytes': 1234});
      expect(calls.last.arguments, {'handle': 7});
    });

    test('platform errors map to Arabic import failures', () async {
      for (final (code, failure) in const [
        ('unsupported', ImportFailure.unsupported),
        ('not_found', ImportFailure.notFound),
        ('io', ImportFailure.unreadable),
        ('decode', ImportFailure.decodeFailed),
      ]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: code, message: 'details');
        });
        await expectLater(
          const MethodChannelAudioDecoder().open('/x'),
          throwsA(
            isA<ImportException>()
                .having((e) => e.failure, 'failure', failure)
                .having((e) => e.messageAr, 'messageAr', isNotEmpty),
          ),
        );
      }
    });

    test('a missing platform implementation is "unsupported"', () async {
      expect(await const MethodChannelAudioDecoder().isSupported(), isFalse);
      await expectLater(
        const MethodChannelAudioDecoder().open('/x'),
        throwsA(
          isA<ImportException>().having(
            (e) => e.failure,
            'failure',
            ImportFailure.unsupported,
          ),
        ),
      );
    });
  });
}
