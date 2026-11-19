// Signal-quality analysis for voice enrollment (F1) and the microphone test
// (F18). Pure Dart: no Flutter, no plugins, so every rule is unit-tested.
//
// Two tools:
//
// * [analyzeAudioQuality] — offline report of a finished take, given the
//   speech spans found by the VAD: voiced duration, clipping, speech level,
//   background noise and signal-to-noise ratio, with blocking and advisory
//   findings.
// * [LiveLevelMonitor] — streaming estimate while recording: a running
//   "voiced seconds" figure from a simple adaptive energy detector (the real
//   VAD only runs after the take) and the hint to show right now (too quiet,
//   clipping, good).

import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio/pcm.dart' show kSilenceDbfs, rmsToDbfs;
import '../../core/models.dart' show kSampleRate;

/// |sample| at or above this level counts as clipped (PCM16 full scale is
/// 1.0; converters rarely reach it exactly).
const double kClipSampleLevel = 0.985;

/// Analysis frame: 50 ms at [kSampleRate].
const int kQualityFrameSamples = kSampleRate ~/ 20;

/// Duration of [samples] samples at [kSampleRate], in milliseconds.
int samplesToMillis(int samples) => samples * 1000 ~/ kSampleRate;

/// Number of samples in [ms] milliseconds at [kSampleRate].
int millisToSamples(int ms) => ms * kSampleRate ~/ 1000;

/// A stretch of detected speech inside a take, in samples
/// (`[startSample, endSample)`).
class SpeechSpan {
  /// Creates a span. [endSample] must not be smaller than [startSample].
  const SpeechSpan(this.startSample, this.endSample)
    : assert(endSample >= startSample);

  /// First sample of the span.
  final int startSample;

  /// One past the last sample of the span.
  final int endSample;

  /// Length in samples.
  int get length => endSample - startSample;

  /// Length in milliseconds.
  int get durationMs => samplesToMillis(length);

  @override
  bool operator ==(Object other) =>
      other is SpeechSpan &&
      other.startSample == startSample &&
      other.endSample == endSample;

  @override
  int get hashCode => Object.hash(startSample, endSample);

  @override
  String toString() => 'SpeechSpan($startSample..$endSample)';
}

/// Sorts [spans], clamps them to `[0, totalSamples)` and merges overlapping
/// or touching ones, so no sample is counted twice.
List<SpeechSpan> normalizeSpans(List<SpeechSpan> spans, int totalSamples) {
  final clamped = <SpeechSpan>[
    for (final s in spans)
      if (math.min(s.endSample, totalSamples) > math.max(s.startSample, 0))
        SpeechSpan(
          math.max(s.startSample, 0),
          math.min(s.endSample, totalSamples),
        ),
  ]..sort((a, b) => a.startSample.compareTo(b.startSample));
  final out = <SpeechSpan>[];
  for (final s in clamped) {
    if (out.isNotEmpty && s.startSample <= out.last.endSample) {
      final last = out.removeLast();
      out.add(
        SpeechSpan(last.startSample, math.max(last.endSample, s.endSample)),
      );
    } else {
      out.add(s);
    }
  }
  return out;
}

/// Thresholds of [analyzeAudioQuality]. The defaults suit a 10–15 s voice
/// enrollment read close to the microphone.
class AudioQualityConfig {
  /// Creates a configuration.
  const AudioQualityConfig({
    this.minVoicedMs = 8000,
    this.clipBlockingRatio = 0.002,
    this.clipWarningRatio = 0.0003,
    this.tooQuietDbfs = -42,
    this.quietWarningDbfs = -34,
    this.minSnrDb = 12,
    this.requireVoicedDuration = true,
  });

  /// Least speech (after VAD) a take must contain.
  final int minVoicedMs;

  /// Share of clipped samples that makes the take unusable.
  final double clipBlockingRatio;

  /// Share of clipped samples that earns a warning.
  final double clipWarningRatio;

  /// Speech RMS below this (dBFS) makes the take unusable.
  final double tooQuietDbfs;

  /// Speech RMS below this (dBFS) earns a "speak up / come closer" warning.
  final double quietWarningDbfs;

  /// Speech-to-background ratio (dB) below which the room is called noisy.
  final double minSnrDb;

  /// Whether [minVoicedMs] applies (the 5 s microphone test does not need
  /// a minimum amount of speech).
  final bool requireVoicedDuration;

  /// Configuration of the 5 s microphone test: no minimum speech.
  static const AudioQualityConfig micTest = AudioQualityConfig(
    requireVoicedDuration: false,
  );
}

/// What [analyzeAudioQuality] found.
enum AudioQualityIssueKind {
  /// Not enough speech (blocking).
  tooLittleSpeech,

  /// No speech at all was detected (blocking).
  noSpeech,

  /// Heavy clipping: the input is overdriven (blocking).
  clipping,

  /// Some clipping (advisory).
  someClipping,

  /// Speech far too quiet (blocking).
  tooQuiet,

  /// Speech rather quiet (advisory).
  quiet,

  /// Background noise close to the speech level (advisory).
  noisy,
}

/// One finding of a quality report.
class AudioQualityIssue {
  /// Creates a finding.
  const AudioQualityIssue(this.kind, {required this.blocking});

  /// What was found.
  final AudioQualityIssueKind kind;

  /// Whether the take must be recorded again.
  final bool blocking;

  @override
  bool operator ==(Object other) =>
      other is AudioQualityIssue &&
      other.kind == kind &&
      other.blocking == blocking;

  @override
  int get hashCode => Object.hash(kind, blocking);

  @override
  String toString() => 'AudioQualityIssue(${kind.name}, blocking: $blocking)';
}

/// Measurements and findings of one take.
class AudioQualityReport {
  /// Creates a report.
  const AudioQualityReport({
    required this.durationMs,
    required this.voicedMs,
    required this.peak,
    required this.clippedRatio,
    required this.speechDbfs,
    required this.noiseDbfs,
    required this.issues,
  });

  /// Length of the take.
  final int durationMs;

  /// Speech detected in the take.
  final int voicedMs;

  /// Largest |sample| (0..1).
  final double peak;

  /// Share of clipped samples in the whole take (0..1).
  final double clippedRatio;

  /// RMS level of the speech parts in dBFS ([kSilenceDbfs] without speech).
  final double speechDbfs;

  /// Background level (dBFS) estimated from the non-speech parts.
  final double noiseDbfs;

  /// Findings, blocking ones first.
  final List<AudioQualityIssue> issues;

  /// Speech level above the background, in dB (0 without speech).
  double get snrDb =>
      speechDbfs <= kSilenceDbfs ? 0 : math.max(0, speechDbfs - noiseDbfs);

  /// True when nothing blocking was found.
  bool get passed => !issues.any((i) => i.blocking);

  /// Whether [kind] was found.
  bool has(AudioQualityIssueKind kind) => issues.any((i) => i.kind == kind);

  @override
  String toString() =>
      'AudioQualityReport(duration: $durationMs ms, voiced: $voicedMs ms, '
      'peak: ${peak.toStringAsFixed(3)}, clipped: '
      '${(clippedRatio * 100).toStringAsFixed(3)}%, speech: '
      '${speechDbfs.toStringAsFixed(1)} dBFS, noise: '
      '${noiseDbfs.toStringAsFixed(1)} dBFS, issues: $issues)';
}

/// Analyses [audio] (mono, [kSampleRate]) given the [speech] spans the VAD
/// found in it.
///
/// [paddingMsPerSpan] is subtracted from each span when counting voiced time
/// (the VAD adds context padding around segments, which is not speech).
AudioQualityReport analyzeAudioQuality(
  Float32List audio,
  List<SpeechSpan> speech, {
  AudioQualityConfig config = const AudioQualityConfig(),
  int paddingMsPerSpan = 0,
}) {
  final spans = normalizeSpans(speech, audio.length);
  var peak = 0.0;
  var clipped = 0;
  for (var i = 0; i < audio.length; i++) {
    final a = audio[i].abs();
    if (!a.isFinite) continue;
    if (a > peak) peak = a;
    if (a >= kClipSampleLevel) clipped++;
  }
  final clippedRatio = audio.isEmpty ? 0.0 : clipped / audio.length;

  // Speech level: RMS over every sample inside a span.
  var speechSumSq = 0.0;
  var speechCount = 0;
  var voicedSamples = 0;
  final padding = millisToSamples(math.max(0, paddingMsPerSpan));
  for (final s in spans) {
    for (var i = s.startSample; i < s.endSample; i++) {
      final v = audio[i];
      if (v.isFinite) speechSumSq += v * v;
    }
    speechCount += s.length;
    voicedSamples += math.max(0, s.length - padding);
  }
  final speechDbfs = speechCount == 0
      ? kSilenceDbfs
      : rmsToDbfs(math.sqrt(speechSumSq / speechCount));

  final noiseDbfs = _backgroundDbfs(audio, spans);
  final voicedMs = samplesToMillis(voicedSamples);

  final issues = <AudioQualityIssue>[];
  if (spans.isEmpty || voicedSamples == 0) {
    issues.add(
      const AudioQualityIssue(AudioQualityIssueKind.noSpeech, blocking: true),
    );
  } else if (config.requireVoicedDuration && voicedMs < config.minVoicedMs) {
    issues.add(
      const AudioQualityIssue(
        AudioQualityIssueKind.tooLittleSpeech,
        blocking: true,
      ),
    );
  }
  if (clippedRatio >= config.clipBlockingRatio) {
    issues.add(
      const AudioQualityIssue(AudioQualityIssueKind.clipping, blocking: true),
    );
  } else if (clippedRatio >= config.clipWarningRatio) {
    issues.add(
      const AudioQualityIssue(
        AudioQualityIssueKind.someClipping,
        blocking: false,
      ),
    );
  }
  if (speechCount > 0) {
    if (speechDbfs < config.tooQuietDbfs) {
      issues.add(
        const AudioQualityIssue(AudioQualityIssueKind.tooQuiet, blocking: true),
      );
    } else if (speechDbfs < config.quietWarningDbfs) {
      issues.add(
        const AudioQualityIssue(AudioQualityIssueKind.quiet, blocking: false),
      );
    }
    if (speechDbfs - noiseDbfs < config.minSnrDb &&
        speechDbfs >= config.tooQuietDbfs) {
      issues.add(
        const AudioQualityIssue(AudioQualityIssueKind.noisy, blocking: false),
      );
    }
  }
  issues.sort((a, b) {
    if (a.blocking != b.blocking) return a.blocking ? -1 : 1;
    return a.kind.index.compareTo(b.kind.index);
  });
  return AudioQualityReport(
    durationMs: samplesToMillis(audio.length),
    voicedMs: voicedMs,
    peak: peak,
    clippedRatio: clippedRatio,
    speechDbfs: speechDbfs,
    noiseDbfs: noiseDbfs,
    issues: List.unmodifiable(issues),
  );
}

/// Background level: median RMS of the 50 ms frames that lie entirely
/// outside speech; when there are fewer than 4 such frames, the 10th
/// percentile of all frames (the quietest moments of the take).
double _backgroundDbfs(Float32List audio, List<SpeechSpan> spans) {
  final outside = <double>[];
  final all = <double>[];
  var spanIndex = 0;
  for (
    var start = 0;
    start + kQualityFrameSamples <= audio.length;
    start += kQualityFrameSamples
  ) {
    final end = start + kQualityFrameSamples;
    var sumSq = 0.0;
    for (var i = start; i < end; i++) {
      final v = audio[i];
      if (v.isFinite) sumSq += v * v;
    }
    final db = rmsToDbfs(math.sqrt(sumSq / kQualityFrameSamples));
    all.add(db);
    while (spanIndex < spans.length && spans[spanIndex].endSample <= start) {
      spanIndex++;
    }
    final overlaps =
        spanIndex < spans.length && spans[spanIndex].startSample < end;
    if (!overlaps) outside.add(db);
  }
  if (outside.length >= 4) return _percentile(outside, 0.5);
  if (all.isEmpty) return kSilenceDbfs;
  return _percentile(all, 0.1);
}

double _percentile(List<double> values, double q) {
  final sorted = [...values]..sort();
  final idx = ((sorted.length - 1) * q).round().clamp(0, sorted.length - 1);
  return sorted[idx];
}

// ===========================================================================
// Live monitoring
// ===========================================================================

/// What the live meter should tell the user right now.
enum LiveSignalHint {
  /// Not enough audio yet to judge.
  waiting,

  /// Level looks fine.
  good,

  /// Speech is too quiet: speak up or move closer.
  tooQuiet,

  /// The input clips: move away or lower the input gain.
  clipping,
}

/// Streaming signal monitor for the recording screens.
///
/// Feed every captured frame to [add]. The voiced-time estimate uses an
/// adaptive energy detector (frames 9 dB above the tracked noise floor and
/// above −55 dBFS); it only drives the on-screen progress — the saved
/// quality verdict comes from the real VAD.
class LiveLevelMonitor {
  /// Creates a monitor.
  LiveLevelMonitor({
    this.hintWindowMs = 2000,
    this.quietWindowMs = 3000,
    this.quietDbfs = -42,
    this.clipRatio = 0.001,
    this.voicedMarginDb = 9,
    this.voicedFloorDbfs = -55,
  }) : _recentClipped = List<int>.filled(math.max(1, hintWindowMs ~/ 50), 0),
       _recentDb = List<double>.filled(
         math.max(1, quietWindowMs ~/ 50),
         kSilenceDbfs,
       );

  /// Window for the clipping hint.
  final int hintWindowMs;

  /// Window for the "too quiet" hint.
  final int quietWindowMs;

  /// If the loudest 50 ms frame of the quiet window stays below this, the
  /// speech is called too quiet.
  final double quietDbfs;

  /// Share of clipped samples within the hint window that triggers the
  /// clipping hint.
  final double clipRatio;

  /// Margin above the noise floor for a frame to count as voiced.
  final double voicedMarginDb;

  /// Absolute minimum level of a voiced frame.
  final double voicedFloorDbfs;

  final List<int> _recentClipped;
  final List<double> _recentDb;
  int _frames = 0;
  final Float32List _pending = Float32List(kQualityFrameSamples);
  int _pendingLen = 0;
  int _pendingClipped = 0;
  double _pendingSumSq = 0;
  double? _floorDb;
  int _voicedFrames = 0;
  int _totalSamples = 0;
  double _lastDb = kSilenceDbfs;
  bool _clippedEver = false;

  /// Audio fed so far, in ms.
  int get elapsedMs => samplesToMillis(_totalSamples);

  /// Estimated voiced time so far, in ms.
  int get voicedMs => _voicedFrames * 50;

  /// Level of the most recent complete frame, dBFS.
  double get lastFrameDbfs => _lastDb;

  /// Tracked background level, dBFS (null before the first frame).
  double? get noiseFloorDbfs => _floorDb;

  /// Whether any clipping was seen since the start.
  bool get clippedEver => _clippedEver;

  /// The hint for the current moment.
  LiveSignalHint get hint {
    if (_frames == 0) return LiveSignalHint.waiting;
    final clipWindow = math.min(_frames, _recentClipped.length);
    var clipped = 0;
    for (var i = 0; i < clipWindow; i++) {
      clipped += _recentClipped[i];
    }
    if (clipped / (clipWindow * kQualityFrameSamples) >= clipRatio) {
      return LiveSignalHint.clipping;
    }
    if (_frames < _recentDb.length) return LiveSignalHint.waiting;
    var loudest = kSilenceDbfs;
    for (final db in _recentDb) {
      if (db > loudest) loudest = db;
    }
    if (loudest < quietDbfs) return LiveSignalHint.tooQuiet;
    return LiveSignalHint.good;
  }

  /// Feeds captured samples (mono, [kSampleRate]).
  void add(Float32List samples) {
    for (var i = 0; i < samples.length; i++) {
      var v = samples[i];
      if (!v.isFinite) v = 0;
      _pending[_pendingLen++] = v;
      _pendingSumSq += v * v;
      if (v.abs() >= kClipSampleLevel) _pendingClipped++;
      if (_pendingLen == kQualityFrameSamples) _closeFrame();
    }
    _totalSamples += samples.length;
  }

  /// Forgets everything (new take).
  void reset() {
    _frames = 0;
    _pendingLen = 0;
    _pendingClipped = 0;
    _pendingSumSq = 0;
    _floorDb = null;
    _voicedFrames = 0;
    _totalSamples = 0;
    _lastDb = kSilenceDbfs;
    _clippedEver = false;
    _recentClipped.fillRange(0, _recentClipped.length, 0);
    _recentDb.fillRange(0, _recentDb.length, kSilenceDbfs);
  }

  void _closeFrame() {
    final db = rmsToDbfs(math.sqrt(_pendingSumSq / kQualityFrameSamples));
    _lastDb = db;
    _recentClipped[_frames % _recentClipped.length] = _pendingClipped;
    _recentDb[_frames % _recentDb.length] = db;
    if (_pendingClipped > 0) _clippedEver = true;
    _frames++;
    // Noise floor: follows quieter frames at once, rises slowly (0.1 dB per
    // frame = 2 dB/s) so continuous speech does not become "background".
    final floor = _floorDb;
    _floorDb = floor == null || db < floor ? db : floor + 0.1;
    if (db >= voicedFloorDbfs && db >= _floorDb! + voicedMarginDb) {
      _voicedFrames++;
    }
    _pendingLen = 0;
    _pendingClipped = 0;
    _pendingSumSq = 0;
  }
}

/// Speech spans found by energy alone (no model needed): 50 ms frames at
/// least [marginDb] above the background (10th percentile of all frames)
/// and above [floorDbfs], closed after [hangoverMs] of quiet and merged
/// across shorter gaps. Spans shorter than [minSpanMs] are dropped. Used by
/// the microphone test, which must work before any model is downloaded.
List<SpeechSpan> energySpeechSpans(
  Float32List audio, {
  double marginDb = 9,
  double floorDbfs = -55,
  int hangoverMs = 300,
  int minSpanMs = 200,
}) {
  final frameDb = <double>[];
  for (
    var start = 0;
    start + kQualityFrameSamples <= audio.length;
    start += kQualityFrameSamples
  ) {
    var sumSq = 0.0;
    for (var i = start; i < start + kQualityFrameSamples; i++) {
      final v = audio[i];
      if (v.isFinite) sumSq += v * v;
    }
    frameDb.add(rmsToDbfs(math.sqrt(sumSq / kQualityFrameSamples)));
  }
  if (frameDb.isEmpty) return const [];
  final background = _percentile(frameDb, 0.1);
  final threshold = math.max(floorDbfs, background + marginDb);
  final hangFrames = math.max(0, hangoverMs ~/ 50);
  final spans = <SpeechSpan>[];
  int? openStart;
  var lastVoiced = -1;
  for (var f = 0; f < frameDb.length; f++) {
    if (frameDb[f] >= threshold) {
      openStart ??= f;
      lastVoiced = f;
    } else if (openStart != null && f - lastVoiced > hangFrames) {
      spans.add(
        SpeechSpan(
          openStart * kQualityFrameSamples,
          (lastVoiced + 1) * kQualityFrameSamples,
        ),
      );
      openStart = null;
    }
  }
  if (openStart != null) {
    spans.add(
      SpeechSpan(
        openStart * kQualityFrameSamples,
        (lastVoiced + 1) * kQualityFrameSamples,
      ),
    );
  }
  final minSamples = millisToSamples(minSpanMs);
  return [
    for (final s in spans)
      if (s.length >= minSamples) s,
  ];
}
