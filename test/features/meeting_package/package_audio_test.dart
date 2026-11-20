import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/features/meeting_package/package_audio.dart';
import 'package:insato/audio/pcm.dart';

import '../multi_device/sim.dart';

const int _sr = 16000;

/// The remote device recorded the same room, starting [startMs] after the
/// main device, at a different gain and with its own noise.
Float32List _remoteOf(Float32List room, int startMs, int lengthMs) {
  final start = startMs * _sr ~/ 1000;
  final n = lengthMs * _sr ~/ 1000;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final j = start + i;
    out[i] = j >= 0 && j < room.length ? 0.4 * room[j] : 0;
  }
  return mixSignals([(1, out), (1, noise(n, seed: 5, level: 0.004))], n);
}

Future<void> _writeWav(String path, Float32List x) async {
  final bytes = float32ToPcm16Bytes(x);
  await File(path).writeAsBytes([
    ...buildWavHeader(sampleRate: _sr, channels: 1, dataBytes: bytes.length),
    ...bytes,
  ]);
}

void main() {
  final room = mixSignals([
    (1, syntheticSpeech(_sr * 150, seed: 3)),
    (1, noise(_sr * 150, seed: 11)),
  ], _sr * 150);
  final main = MemoryAlignmentAudio(room);

  for (final (trueMs, clockErrorMs) in [
    (30000, 0),
    (42250, 7300),
    (12500, -95000),
    (60000, 140000),
  ]) {
    test(
      'finds a ${trueMs}ms start with a ${clockErrorMs}ms clock error',
      () async {
        final remote = MemoryAlignmentAudio(_remoteOf(room, trueMs, 80000));
        final a = await alignRecordings(
          main: main,
          remote: remote,
          wallClockOffsetMs: trueMs + clockErrorMs,
        );
        expect(a.method, AlignmentMethod.audio);
        expect(a.sameRoom, isTrue);
        expect(a.offsetMs, closeTo(trueMs, 5));
        expect(a.clockErrorMs, closeTo(-clockErrorMs, 5));
      },
    );
  }

  test(
    'a remote recording that started earlier gets a negative offset',
    () async {
      // Remote started 20 s before the main device.
      final earlier = Float32List(_sr * 20 + room.length)
        ..setRange(_sr * 20, _sr * 20 + room.length, room);
      final remote = MemoryAlignmentAudio(
        Float32List.sublistView(earlier, 0, _sr * 90),
      );
      final a = await alignRecordings(
        main: main,
        remote: remote,
        wallClockOffsetMs: -18000,
      );
      expect(a.method, AlignmentMethod.audio);
      expect(a.offsetMs, closeTo(-20000, 5));
    },
  );

  test('another room falls back to the wall clocks', () async {
    final other = MemoryAlignmentAudio(
      mixSignals([
        (1, syntheticSpeech(_sr * 60, seed: 99)),
        (1, noise(_sr * 60, seed: 4)),
      ], _sr * 60),
    );
    final a = await alignRecordings(
      main: main,
      remote: other,
      wallClockOffsetMs: 12345,
    );
    expect(a.method, AlignmentMethod.wallClock);
    expect(a.offsetMs, 12345);
    expect(a.sameRoom, isFalse);
  });

  test('silence falls back to the wall clocks', () async {
    final a = await alignRecordings(
      main: main,
      remote: MemoryAlignmentAudio(Float32List(_sr * 30)),
      wallClockOffsetMs: 500,
    );
    expect(a.method, AlignmentMethod.wallClock);
  });

  test('overlapMs', () {
    expect(overlapMs(60000, 30000, 10000), 30000);
    expect(overlapMs(60000, 30000, 50000), 10000);
    expect(overlapMs(60000, 30000, 70000), 0);
    expect(overlapMs(60000, 30000, -10000), 20000);
  });

  test('segment SNR is higher for a close talker than for a far one', () {
    final quiet = noise(_sr * 10, seed: 2, level: 0.003);
    final near = Float32List.fromList(quiet);
    final far = Float32List.fromList(quiet);
    final speech = syntheticSpeech(_sr * 2, seed: 8);
    for (var i = 0; i < speech.length; i++) {
      near[_sr * 4 + i] += speech[i];
      far[_sr * 4 + i] += 0.05 * speech[i];
    }
    final pn = MemoryAlignmentAudio(near).profile;
    final pf = MemoryAlignmentAudio(far).profile;
    final sn = segmentSnrDb(pn, noiseFloorOf(pn), 4000, 6000)!;
    final sf = segmentSnrDb(pf, noiseFloorOf(pf), 4000, 6000)!;
    expect(sn, greaterThan(sf + 10));
    expect(segmentSnrDb(pn, noiseFloorOf(pn), 20000, 21000), isNull);
  });

  group('WAV files', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('insato_pkg_audio'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('file audio matches memory audio and aligns', () async {
      final mainPath = '${tmp.path}/main.wav';
      final remotePath = '${tmp.path}/remote.wav';
      await _writeWav(mainPath, room);
      await _writeWav(remotePath, _remoteOf(room, 33333, 50000));
      final m = await WavFileAlignmentAudio.open(mainPath);
      final r = await WavFileAlignmentAudio.open(remotePath);
      expect(m.sampleCount, room.length);
      expect(m.profile.length, main.profile.length);
      final w = await m.window(_sr * 10 - 5, 100);
      final mw = await main.window(_sr * 10 - 5, 100);
      for (var i = 0; i < 100; i++) {
        expect(w[i], closeTo(mw[i], 1e-4));
      }
      final before = await m.window(-10, 20);
      expect(before.sublist(0, 10), everyElement(0));
      final a = await alignRecordings(
        main: m,
        remote: r,
        wallClockOffsetMs: 31000,
      );
      expect(a.method, AlignmentMethod.audio);
      expect(a.offsetMs, closeTo(33333, 5));
    });

    test('merged recording places both devices on one timeline', () async {
      final a = Float32List(_sr)..fillRange(0, _sr, 0.25);
      final b = Float32List(_sr)..fillRange(0, _sr, -0.5);
      final out = '${tmp.path}/merged.wav';
      final n = await writeMergedWav(
        outPath: out,
        main: MemoryAlignmentAudio(a),
        mainStartSample: _sr ~/ 2,
        remote: MemoryAlignmentAudio(b),
        remoteStartSample: _sr,
        mode: AudioMergeMode.preferMain,
        blockSamples: 3000,
      );
      expect(n, 2 * _sr);
      final x = await readWavAsFloat32(out);
      expect(x.length, 2 * _sr);
      expect(x[100], 0); // before both
      expect(x[_sr ~/ 2 + 10], closeTo(0.25, 1e-3)); // main only
      expect(x[_sr + 10], closeTo(0.25, 1e-3)); // both: main preferred
      expect(x[_sr * 3 ~/ 2 + 10], closeTo(-0.5, 1e-3)); // remote only

      await writeMergedWav(
        outPath: out,
        main: MemoryAlignmentAudio(a),
        mainStartSample: _sr ~/ 2,
        remote: MemoryAlignmentAudio(b),
        remoteStartSample: _sr,
        mode: AudioMergeMode.mix,
      );
      final y = await readWavAsFloat32(out);
      expect(y[_sr + 10], closeTo(-0.25, 1e-3)); // mixed
    });
  });
}
