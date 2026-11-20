// Audio side of merging a meeting package: per-segment SNR, time alignment
// of two recordings made on different devices, and the merged recording.
//
// Alignment (remote time t ↔ main-meeting time t + offset):
//
// 1. The wall clocks give a first offset (remote start − main start). With
//    no network at the remote site the device clock may be off by seconds
//    or minutes, so this is only the centre of the search.
// 2. Coarse: 20 ms log-envelope onsets of a busy ≤ 60 s excerpt of the
//    remote recording are cross-correlated with the main recording over
//    ±[searchMs] around the wall-clock offset (normalised, per lag, over the
//    overlap). A clear peak means both devices heard the same room.
// 3. Fine: 20 s of raw audio at the coarse offset go through the
//    multi-device aligner (`estimateLag`, 1 ms onsets, ±300 ms, parabolic
//    peak) with the same acceptance thresholds as live multi-device
//    meetings (`AlignmentTracker`), giving ~1 ms.
//
// When the audio does not give a confident peak (different rooms, no
// overlap, no recording) the wall-clock offset is used.
//
// Pure Dart + dart:io; runs in a background isolate.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio/pcm.dart' show float32ToPcm16Bytes;
import '../../audio/wav_writer.dart';
import '../../core/models.dart' show kSampleRate;
import '../multi_device/alignment.dart'
    show AlignmentTracker, envelope, estimateLag;

/// Samples per profile bin (20 ms).
const int kProfileHop = kSampleRate ~/ 50;

/// Milliseconds per profile bin.
const int kProfileBinMs = 20;

/// A recording reduced to what alignment and SNR need: the mean |x| per
/// 20 ms and random access to raw windows.
abstract class AlignmentAudio {
  /// Number of samples (16 kHz).
  int get sampleCount;

  /// Mean absolute value per [kProfileHop] samples.
  Float32List get profile;

  /// [count] samples from [start] (zeros outside the recording).
  Future<Float32List> window(int start, int count);

  /// Duration in ms.
  int get durationMs => sampleCount * 1000 ~/ kSampleRate;
}

/// [AlignmentAudio] over samples in memory (tests, short recordings).
class MemoryAlignmentAudio extends AlignmentAudio {
  /// Wraps [samples] (16 kHz mono).
  MemoryAlignmentAudio(this.samples)
    : profile = envelope(samples, hop: kProfileHop);

  /// The samples.
  final Float32List samples;

  @override
  final Float32List profile;

  @override
  int get sampleCount => samples.length;

  @override
  Future<Float32List> window(int start, int count) async =>
      _slice(samples, start, count);
}

Float32List _slice(Float32List x, int start, int count) {
  final out = Float32List(count);
  final a = math.max(0, start);
  final b = math.min(x.length, start + count);
  if (b > a) out.setRange(a - start, b - start, x, a);
  return out;
}

/// [AlignmentAudio] over a WAV file. The profile is computed in one
/// streaming pass; windows of canonical 16 kHz mono PCM16 files are read
/// directly, others by streaming.
class WavFileAlignmentAudio extends AlignmentAudio {
  WavFileAlignmentAudio._(
    this.path,
    this.profile,
    this.sampleCount,
    this._info,
  );

  /// The file.
  final String path;

  @override
  final Float32List profile;

  @override
  final int sampleCount;

  final WavInfo _info;

  /// Reads [path] once to build the profile.
  static Future<WavFileAlignmentAudio> open(String path) async {
    final info = await readWavInfo(path);
    final bins = <double>[];
    var carry = Float32List(0);
    var total = 0;
    await for (final chunk in readWavChunks(path)) {
      total += chunk.length;
      final x = carry.isEmpty
          ? chunk
          : (Float32List(carry.length + chunk.length)
              ..setRange(0, carry.length, carry)
              ..setRange(carry.length, carry.length + chunk.length, chunk));
      final whole = x.length - x.length % kProfileHop;
      bins.addAll(envelope(x, length: whole, hop: kProfileHop));
      carry = Float32List.fromList(Float32List.sublistView(x, whole));
    }
    return WavFileAlignmentAudio._(
      path,
      Float32List.fromList(bins),
      total,
      info,
    );
  }

  bool get _canonical =>
      _info.sampleRate == kSampleRate &&
      _info.channels == 1 &&
      _info.bitsPerSample == 16 &&
      _info.encoding == WavSampleEncoding.pcmInteger;

  @override
  Future<Float32List> window(int start, int count) async {
    final out = Float32List(count);
    final a = math.max(0, start);
    final b = math.min(sampleCount, start + count);
    if (b <= a) return out;
    if (_canonical) {
      final raf = await File(path).open();
      try {
        await raf.setPosition(_info.dataOffset + a * 2);
        final bytes = await raf.read((b - a) * 2);
        final data = ByteData.sublistView(bytes);
        for (var i = 0; i < bytes.length ~/ 2; i++) {
          out[a - start + i] = data.getInt16(i * 2, Endian.little) / 32768.0;
        }
      } finally {
        await raf.close();
      }
      return out;
    }
    var pos = 0;
    await for (final chunk in readWavChunks(path)) {
      final cEnd = pos + chunk.length;
      final s = math.max(a, pos);
      final e = math.min(b, cEnd);
      if (e > s) out.setRange(s - start, e - start, chunk, s - pos);
      pos = cEnd;
      if (pos >= b) break;
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// SNR
// ---------------------------------------------------------------------------

/// Noise floor of a profile: the 10th percentile of its non-zero bins
/// (digital silence from padding or pauses is ignored).
double noiseFloorOf(Float32List profile) {
  final v = [
    for (final x in profile)
      if (x > 1e-6) x,
  ]..sort();
  if (v.isEmpty) return 1e-6;
  return math.max(1e-6, v[(v.length * 0.1).floor()]);
}

/// Speech-to-noise ratio (dB) of `[startMs, endMs)`: the 90th percentile of
/// the segment's 20 ms levels over [noiseFloor]. Null when the segment is
/// outside the recording.
double? segmentSnrDb(
  Float32List profile,
  double noiseFloor,
  int startMs,
  int endMs,
) {
  final a = math.max(0, startMs ~/ kProfileBinMs);
  final b = math.min(
    profile.length,
    (endMs + kProfileBinMs - 1) ~/ kProfileBinMs,
  );
  if (b <= a) return null;
  final v = Float32List.sublistView(profile, a, b).toList()..sort();
  final level = v[math.min(v.length - 1, (v.length * 0.9).floor())];
  if (level <= 0) return null;
  final db = 20 * math.log(level / noiseFloor) / math.ln10;
  return db.clamp(-20.0, 90.0).toDouble();
}

// ---------------------------------------------------------------------------
// Alignment
// ---------------------------------------------------------------------------

/// How the offset of an imported recording was found.
enum AlignmentMethod {
  /// From the two devices' wall clocks only.
  wallClock,

  /// Refined by cross-correlating the two recordings.
  audio,
}

/// Where an imported recording sits on the main meeting's timeline.
class RecordingAlignment {
  /// Creates an alignment.
  const RecordingAlignment({
    required this.offsetMs,
    required this.wallClockOffsetMs,
    required this.method,
    this.peak,
    this.ratio,
  });

  /// Remote time t is main-meeting time t + [offsetMs].
  final int offsetMs;

  /// The wall-clock estimate.
  final int wallClockOffsetMs;

  /// How [offsetMs] was found.
  final AlignmentMethod method;

  /// Correlation peak of the audio match.
  final double? peak;

  /// Peak / runner-up ratio of the audio match.
  final double? ratio;

  /// True when the audio showed both devices heard the same sounds.
  bool get sameRoom => method == AlignmentMethod.audio;

  /// How far the audio moved the wall-clock estimate.
  int get clockErrorMs => offsetMs - wallClockOffsetMs;
}

/// Length of the overlap (ms) of a main recording of [mainMs] and a remote
/// one of [remoteMs] placed at [offsetMs].
int overlapMs(int mainMs, int remoteMs, int offsetMs) =>
    math.max(0, math.min(mainMs, offsetMs + remoteMs) - math.max(0, offsetMs));

/// Log-envelope onsets: log level minus its moving average over [window]
/// bins (levels do not matter, changes do).
Float32List onsetCurve(Float32List env, {int window = 25}) {
  final n = env.length;
  final logEnv = Float64List(n);
  for (var i = 0; i < n; i++) {
    logEnv[i] = math.log(1e-4 + env[i]);
  }
  final prefix = Float64List(n + 1);
  for (var i = 0; i < n; i++) {
    prefix[i + 1] = prefix[i] + logEnv[i];
  }
  final out = Float32List(n);
  final half = window ~/ 2;
  for (var i = 0; i < n; i++) {
    final a = math.max(0, i - half);
    final b = math.min(n, i + half + 1);
    out[i] = logEnv[i] - (prefix[b] - prefix[a]) / (b - a);
  }
  return out;
}

double _variance(Float32List x, int a, int b) {
  if (b <= a) return 0;
  var m = 0.0;
  for (var i = a; i < b; i++) {
    m += x[i];
  }
  m /= b - a;
  var s = 0.0;
  for (var i = a; i < b; i++) {
    s += (x[i] - m) * (x[i] - m);
  }
  return s / (b - a);
}

/// Result of [coarseLag].
typedef CoarseLag = ({double lagBins, double peak, double ratio});

/// Finds the lag L (bins) maximising the normalised correlation of
/// `remote[e0, e1)` with `main[i + L]`, for L in [lo, hi]. A lag counts only
/// when at least half of the excerpt overlaps [main]. Null when nothing
/// overlaps.
CoarseLag? coarseLag(
  Float32List main,
  Float32List remote,
  int e0,
  int e1,
  int lo,
  int hi,
) {
  final len = e1 - e0;
  if (len <= 0 || hi < lo) return null;
  final corr = Float64List(hi - lo + 1)..fillRange(0, hi - lo + 1, -2);
  for (var l = lo; l <= hi; l++) {
    final i0 = math.max(e0, -l);
    final i1 = math.min(e1, main.length - l);
    if (i1 - i0 < len ~/ 2) continue;
    var dot = 0.0, ea = 0.0, eb = 0.0;
    for (var i = i0; i < i1; i++) {
      final x = remote[i], y = main[i + l];
      dot += x * y;
      ea += x * x;
      eb += y * y;
    }
    corr[l - lo] = (ea <= 0 || eb <= 0) ? 0 : dot / math.sqrt(ea * eb);
  }
  var bi = -1;
  for (var i = 0; i < corr.length; i++) {
    if (corr[i] > -2 && (bi < 0 || corr[i] > corr[bi])) bi = i;
  }
  if (bi < 0) return null;
  final peak = corr[bi];
  var other = 1e-9;
  for (var i = 0; i < corr.length; i++) {
    // ±100 ms around the peak belongs to it.
    if ((i - bi).abs() > 5 && corr[i] > other) other = corr[i];
  }
  var frac = 0.0;
  if (bi > 0 &&
      bi < corr.length - 1 &&
      corr[bi - 1] > -2 &&
      corr[bi + 1] > -2) {
    final y0 = corr[bi - 1], y1 = corr[bi], y2 = corr[bi + 1];
    final den = y0 - 2 * y1 + y2;
    if (den.abs() > 1e-12) frac = (0.5 * (y0 - y2) / den).clamp(-0.5, 0.5);
  }
  return (lagBins: lo + bi + frac, peak: peak, ratio: peak / other);
}

/// Aligns [remote] on [main] (see the file comment). [wallClockOffsetMs]:
/// remote start − main start by the devices' clocks; [searchMs]: how far
/// the clocks may be wrong.
Future<RecordingAlignment> alignRecordings({
  required AlignmentAudio main,
  required AlignmentAudio remote,
  required int wallClockOffsetMs,
  int searchMs = 5 * 60 * 1000,
  int excerptMs = 60 * 1000,
}) async {
  final fallback = RecordingAlignment(
    offsetMs: wallClockOffsetMs,
    wallClockOffsetMs: wallClockOffsetMs,
    method: AlignmentMethod.wallClock,
  );
  final m = onsetCurve(main.profile);
  final r = onsetCurve(remote.profile);
  if (m.length < 100 || r.length < 100) return fallback;

  // The busiest remote excerpt (most onset variance), preferring the part
  // the wall clocks say overlaps the main recording.
  final exBins = math.min(r.length, excerptMs ~/ kProfileBinMs);
  final predicted = (wallClockOffsetMs / kProfileBinMs).round();
  final searchBins = searchMs ~/ kProfileBinMs;
  var bestStart = -1;
  var bestVar = 0.0;
  var bestInside = false;
  final step = math.max(1, exBins ~/ 4);
  for (var s = 0; s + exBins <= r.length; s += step) {
    final inside = s + predicted >= 0 && s + exBins + predicted <= m.length;
    final v = _variance(r, s, s + exBins);
    if (bestStart < 0 ||
        (inside && !bestInside) ||
        (inside == bestInside && v > bestVar)) {
      bestStart = s;
      bestVar = v;
      bestInside = inside;
    }
  }
  if (bestStart < 0 || bestVar < 1e-3) return fallback;
  final coarse = coarseLag(
    m,
    r,
    bestStart,
    bestStart + exBins,
    predicted - searchBins,
    predicted + searchBins,
  );
  final tracker = AlignmentTracker();
  if (coarse == null ||
      coarse.peak < tracker.minPeak ||
      coarse.ratio < tracker.minRatio) {
    return fallback;
  }
  final coarseSamples = (coarse.lagBins * kProfileHop).round();

  // Fine: 20 s of raw audio around the excerpt's centre.
  const fineSamples = 20 * kSampleRate;
  final center = (bestStart + exBins ~/ 2) * kProfileHop;
  final rs = math.max(
    0,
    math.min(remote.sampleCount - fineSamples, center - fineSamples ~/ 2),
  );
  final rw = await remote.window(rs, fineSamples);
  final mw = await main.window(rs + coarseSamples, fineSamples);
  final fine = estimateLag(mw, rw);
  var offsetSamples = coarseSamples;
  double peak = coarse.peak, ratio = coarse.ratio;
  if (fine != null &&
      fine.peak >= tracker.minPeak &&
      fine.ratio >= tracker.minRatio) {
    // The remote window lags the main window by `fine.lagSamples`: remote
    // sample i matches main sample i − lag, i.e. the offset shrinks.
    offsetSamples = coarseSamples - fine.lagSamples.round();
    peak = fine.peak;
    ratio = fine.ratio;
  }
  return RecordingAlignment(
    offsetMs: (offsetSamples * 1000 / kSampleRate).round(),
    wallClockOffsetMs: wallClockOffsetMs,
    method: AlignmentMethod.audio,
    peak: peak,
    ratio: ratio,
  );
}

// ---------------------------------------------------------------------------
// Merged recording
// ---------------------------------------------------------------------------

/// How the merged recording combines the two devices where both recorded.
enum AudioMergeMode {
  /// Same room: the main device's audio, the remote only where the main
  /// device did not record (no comb filtering from two microphones).
  preferMain,

  /// Different rooms: both are mixed.
  mix,
}

/// Writes a 16 kHz mono PCM16 WAV of the merged timeline to [outPath]:
/// [main] starts at [mainStartSample], [remote] at [remoteStartSample]
/// (either may be null). Returns the number of samples written.
Future<int> writeMergedWav({
  required String outPath,
  AlignmentAudio? main,
  int mainStartSample = 0,
  AlignmentAudio? remote,
  int remoteStartSample = 0,
  AudioMergeMode mode = AudioMergeMode.preferMain,
  int blockSamples = 10 * kSampleRate,
}) async {
  final mainEnd = main == null ? 0 : mainStartSample + main.sampleCount;
  final remoteEnd = remote == null ? 0 : remoteStartSample + remote.sampleCount;
  final total = math.max(mainEnd, remoteEnd);
  final sink = File(outPath).openWrite();
  try {
    sink.add(
      buildWavHeader(
        sampleRate: kSampleRate,
        channels: 1,
        dataBytes: total * 2,
      ),
    );
    for (var b = 0; b < total; b += blockSamples) {
      final n = math.min(blockSamples, total - b);
      final out = Float32List(n);
      final hasMain = main != null && b < mainEnd && b + n > mainStartSample;
      final hasRemote =
          remote != null && b < remoteEnd && b + n > remoteStartSample;
      final mw = hasMain ? await main.window(b - mainStartSample, n) : null;
      final rw = hasRemote
          ? await remote.window(b - remoteStartSample, n)
          : null;
      for (var i = 0; i < n; i++) {
        final t = b + i;
        final inMain = mw != null && t >= mainStartSample && t < mainEnd;
        final inRemote = rw != null && t >= remoteStartSample && t < remoteEnd;
        if (mode == AudioMergeMode.preferMain) {
          out[i] = inMain ? mw[i] : (inRemote ? rw[i] : 0);
        } else {
          out[i] = (inMain ? mw[i] : 0) + (inRemote ? rw[i] : 0);
        }
      }
      sink.add(float32ToPcm16Bytes(out));
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
  return total;
}
