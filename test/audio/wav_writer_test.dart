import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:katib/audio/pcm.dart';
import 'package:katib/audio/wav_writer.dart';

Float32List sine(double freq, int rate, int n, {double amp = 0.5}) {
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = amp * math.sin(2 * math.pi * freq * i / rate);
  }
  return out;
}

String tag(Uint8List b, int at) => String.fromCharCodes(b, at, at + 4);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('katib_wav_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  String p(String name) => '${dir.path}/$name';

  group('buildWavHeader', () {
    test('canonical PCM16 mono 16 kHz header', () {
      final h = buildWavHeader(sampleRate: 16000, channels: 1, dataBytes: 3200);
      final d = ByteData.sublistView(h);
      expect(h, hasLength(kWavHeaderBytes));
      expect(tag(h, 0), 'RIFF');
      expect(d.getUint32(4, Endian.little), 36 + 3200);
      expect(tag(h, 8), 'WAVE');
      expect(tag(h, 12), 'fmt ');
      expect(d.getUint32(16, Endian.little), 16);
      expect(d.getUint16(20, Endian.little), 1);
      expect(d.getUint16(22, Endian.little), 1);
      expect(d.getUint32(24, Endian.little), 16000);
      expect(d.getUint32(28, Endian.little), 32000);
      expect(d.getUint16(32, Endian.little), 2);
      expect(d.getUint16(34, Endian.little), 16);
      expect(tag(h, 36), 'data');
      expect(d.getUint32(40, Endian.little), 3200);
    });

    test('stereo byte rate and block align', () {
      final d = ByteData.sublistView(
        buildWavHeader(sampleRate: 44100, channels: 2, dataBytes: 0),
      );
      expect(d.getUint32(28, Endian.little), 44100 * 4);
      expect(d.getUint16(32, Endian.little), 4);
    });
  });

  group('WavWriter', () {
    test('writes a valid file and round trips samples', () async {
      final path = p('a/b/rec.wav'); // parent dirs are created
      final w = await WavWriter.open(path);
      final s = sine(440, 16000, 16000);
      final bytes = float32ToPcm16Bytes(s);
      // Feed in odd-sized chunks without awaiting each one.
      final futures = <Future<void>>[];
      var i = 0;
      var size = 1;
      while (i < bytes.length) {
        final n = math.min(size, bytes.length - i);
        futures.add(w.appendPcm16(Uint8List.sublistView(bytes, i, i + n)));
        i += n;
        size = size * 3 % 1001 + 1;
      }
      await Future.wait(futures);
      expect(w.dataBytes, bytes.length);
      expect(w.duration, const Duration(seconds: 1));
      await w.close();
      expect(w.isClosed, isTrue);

      final raw = await File(path).readAsBytes();
      expect(raw.length, kWavHeaderBytes + bytes.length);
      final d = ByteData.sublistView(raw);
      expect(d.getUint32(4, Endian.little), 36 + bytes.length);
      expect(d.getUint32(40, Endian.little), bytes.length);
      expect(Uint8List.sublistView(raw, kWavHeaderBytes), orderedEquals(bytes));

      final info = await readWavInfo(path);
      expect(info.sampleRate, 16000);
      expect(info.channels, 1);
      expect(info.bitsPerSample, 16);
      expect(info.frameCount, 16000);
      expect(info.duration, const Duration(seconds: 1));

      final back = await readWavAsFloat32(path);
      expect(back, hasLength(16000));
      for (var k = 0; k < back.length; k++) {
        expect(back[k], closeTo(s[k], 1.5 / 32768));
      }
    });

    test('appendFloat32 and empty file', () async {
      final path = p('f.wav');
      final w = await WavWriter.open(path);
      await w.close();
      expect(await readWavAsFloat32(path), isEmpty);

      final w2 = await WavWriter.open(path);
      await w2.appendFloat32(Float32List.fromList([0.5, -0.5]));
      await w2.close();
      expect(await readWavAsFloat32(path), [
        closeTo(0.5, 1e-4),
        closeTo(-0.5, 1e-4),
      ]);
    });

    test('patches header sizes periodically before close', () async {
      final path = p('crash.wav');
      final w = await WavWriter.open(
        path,
        patchInterval: const Duration(milliseconds: 100),
      );
      // 0.25 s of audio: crosses the 100 ms patch threshold twice.
      await w.appendFloat32(sine(200, 16000, 1600));
      await w.appendFloat32(sine(200, 16000, 1600));
      await w.appendFloat32(sine(200, 16000, 800));
      final raw = await File(path).readAsBytes();
      final d = ByteData.sublistView(raw);
      // Header reflects at least the first 200 ms without close().
      expect(d.getUint32(40, Endian.little), greaterThanOrEqualTo(6400));
      expect(
        d.getUint32(4, Endian.little),
        36 + d.getUint32(40, Endian.little),
      );
      await w.flush();
      final d2 = ByteData.sublistView(await File(path).readAsBytes());
      expect(d2.getUint32(40, Endian.little), 8000);
      await w.close();
    });

    test('rejects use after close and close is idempotent', () async {
      final w = await WavWriter.open(p('c.wav'));
      await w.close();
      await w.close();
      expect(w.appendPcm16(Uint8List(2)), throwsStateError);
    });

    test('rejects invalid formats', () async {
      expect(WavWriter.open(p('x.wav'), sampleRate: 0), throwsArgumentError);
      expect(WavWriter.open(p('x.wav'), channels: 0), throwsArgumentError);
    });

    test('repair() fixes an unfinalised header from the file length', () async {
      final path = p('r.wav');
      final pcm = float32ToPcm16Bytes(sine(300, 16000, 4000));
      final f = File(path);
      await f.writeAsBytes([
        ...buildWavHeader(sampleRate: 16000, channels: 1, dataBytes: 0),
        ...pcm,
        7, // torn half-sample at the end
      ]);
      expect(await WavWriter.repair(path), isTrue);
      final raw = await f.readAsBytes();
      expect(raw.length, kWavHeaderBytes + pcm.length + 1);
      final d = ByteData.sublistView(raw);
      expect(d.getUint32(40, Endian.little), pcm.length);
      expect(d.getUint32(4, Endian.little), 36 + pcm.length);
      expect(await WavWriter.repair(path), isFalse); // already consistent
      expect(await WavWriter.repair(p('missing.wav')), isFalse);
      await File(p('junk.wav')).writeAsBytes(List.filled(100, 1));
      expect(await WavWriter.repair(p('junk.wav')), isFalse);
    });
  });

  group('readWav', () {
    Future<String> writeRaw(String name, List<int> bytes) async {
      final path = p(name);
      await File(path).writeAsBytes(bytes);
      return path;
    }

    test('stereo 44.1 kHz PCM16 -> 16 kHz mono', () async {
      const rate = 44100;
      final mono = sine(500, rate, rate);
      final stereo = Float32List(rate * 2);
      for (var i = 0; i < rate; i++) {
        stereo[2 * i] = mono[i];
        stereo[2 * i + 1] = mono[i];
      }
      final data = float32ToPcm16Bytes(stereo);
      final path = await writeRaw('st.wav', [
        ...buildWavHeader(
          sampleRate: rate,
          channels: 2,
          dataBytes: data.length,
        ),
        ...data,
      ]);
      final out = await readWavAsFloat32(path);
      expect(out.length, closeTo(16000, 1));
      final ideal = sine(500, 16000, out.length);
      for (var k = 400; k < out.length - 400; k++) {
        expect(out[k], closeTo(ideal[k], 0.01));
      }
      final chunks = await readWavChunks(
        path,
        chunkDuration: const Duration(milliseconds: 100),
      ).toList();
      expect(chunks.length, greaterThan(5));
      expect(chunks.fold<int>(0, (a, c) => a + c.length), out.length);
    });

    test('unfinalised data size reads to end of file', () async {
      final data = float32ToPcm16Bytes(sine(100, 16000, 1000));
      final path = await writeRaw('u.wav', [
        ...buildWavHeader(sampleRate: 16000, channels: 1, dataBytes: 0),
        ...data,
      ]);
      expect(await readWavAsFloat32(path), hasLength(1000));
      final info = await readWavInfo(path);
      expect(info.dataBytes, data.length);
    });

    test('skips extra chunks and parses extensible / float / 24-bit', () async {
      // WAVE_FORMAT_EXTENSIBLE, 24-bit, mono, 16 kHz, with a LIST chunk.
      final fmt = ByteData(40)
        ..setUint16(0, 0xFFFE, Endian.little)
        ..setUint16(2, 1, Endian.little)
        ..setUint32(4, 16000, Endian.little)
        ..setUint32(8, 16000 * 3, Endian.little)
        ..setUint16(12, 3, Endian.little)
        ..setUint16(14, 24, Endian.little)
        ..setUint16(16, 22, Endian.little)
        ..setUint16(18, 24, Endian.little)
        ..setUint32(20, 4, Endian.little)
        ..setUint16(24, 1, Endian.little); // sub-format PCM
      final samples = [0x400000, -0x400000, 0];
      final data = BytesBuilder();
      for (final s in samples) {
        final v = s & 0xFFFFFF;
        data.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff]);
      }
      final dataBytes = data.takeBytes();
      final list = [...'LIST'.codeUnits, 3, 0, 0, 0, 1, 2, 3, 0]; // odd + pad
      final body = <int>[
        ...'WAVE'.codeUnits,
        ...'fmt '.codeUnits,
        40,
        0,
        0,
        0,
        ...fmt.buffer.asUint8List(),
        ...list,
        ...'data'.codeUnits,
        dataBytes.length,
        0,
        0,
        0,
        ...dataBytes,
      ];
      final riff = [...'RIFF'.codeUnits, ..._u32(body.length), ...body];
      final path = await writeRaw('ext.wav', riff);
      final info = await readWavInfo(path);
      expect(info.bitsPerSample, 24);
      expect(info.encoding, WavSampleEncoding.pcmInteger);
      expect(await readWavAsFloat32(path), [0.5, -0.5, 0.0]);

      // IEEE float 32-bit.
      final fdata = ByteData(8)
        ..setFloat32(0, 0.25, Endian.little)
        ..setFloat32(4, -0.75, Endian.little);
      final ffmt = ByteData(16)
        ..setUint16(0, 3, Endian.little)
        ..setUint16(2, 1, Endian.little)
        ..setUint32(4, 16000, Endian.little)
        ..setUint32(8, 64000, Endian.little)
        ..setUint16(12, 4, Endian.little)
        ..setUint16(14, 32, Endian.little);
      final fbody = <int>[
        ...'WAVE'.codeUnits,
        ...'fmt '.codeUnits,
        16,
        0,
        0,
        0,
        ...ffmt.buffer.asUint8List(),
        ...'data'.codeUnits,
        8,
        0,
        0,
        0,
        ...fdata.buffer.asUint8List(),
      ];
      final fpath = await writeRaw('float.wav', [
        ...'RIFF'.codeUnits,
        ..._u32(fbody.length),
        ...fbody,
      ]);
      expect(await readWavAsFloat32(fpath), [0.25, -0.75]);
    });

    test('rejects malformed files', () async {
      final notWav = await writeRaw('bad.wav', List.filled(64, 0));
      expect(readWavInfo(notWav), throwsFormatException);
      final noData = await writeRaw('nodata.wav', [
        ...buildWavHeader(
          sampleRate: 16000,
          channels: 1,
          dataBytes: 0,
        ).sublist(0, 36),
      ]);
      expect(readWavAsFloat32(noData), throwsFormatException);
      final mulaw = buildWavHeader(sampleRate: 8000, channels: 1, dataBytes: 2);
      ByteData.sublistView(mulaw).setUint16(20, 7, Endian.little);
      final ulaw = await writeRaw('ulaw.wav', [...mulaw, 0, 0]);
      expect(readWavInfo(ulaw), throwsFormatException);
      expect(readWavInfo(p('nope.wav')), throwsA(isA<FileSystemException>()));
    });
  });
}

List<int> _u32(int v) => [
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
];
