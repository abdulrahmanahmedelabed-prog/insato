// Telephone audio profile of phone-call mode.
//
// Cellular speech reaches Insato band-limited: narrowband codecs (AMR-NB,
// Bluetooth HFP CVSD) keep about 300–3400 Hz at 8 kHz sampling, wideband
// ones (AMR-WB / VoLTE "HD voice", HFP mSBC) about 50–7000 Hz, always with
// codec artefacts. The profile adapts the pipeline to that channel:
//
// * VAD: telephone speech upsampled to 16 kHz gets lower silero
//   probabilities than a close microphone, and a phone on speaker is a
//   distant source; thresholds are lowered accordingly ([vadFor]).
// * Embeddings: remote-side segments are band-limited to 300–3400 Hz
//   ([TelephoneBandLimiter]) so every remote voice is embedded through the
//   same channel, whatever the call's codec (optional for local segments).
// * Voiceprints: a voiceprint learned on a wideband microphone scores lower
//   against the same voice on the telephone line; matching across that
//   mismatch is relaxed more than a microphone mismatch
//   ([knownSpeakerThreshold]); remote voiceprints are tagged
//   [kTelephoneVoiceDeviceKey].
// * Language: sherpa-onnx Whisper takes no initial prompt, only a language
//   tag; Whisper's language detection is less reliable on short narrowband
//   segments, so the call setup offers a fixed language
//   ([resolveCallLanguageHint]).
// * Speakerphone (one microphone): a segment whose spectrum is empty above
//   ~4 kHz is narrowband telephone audio, i.e. the remote side
//   ([classifyBandwidth]); HD-voice calls cannot be told apart this way and
//   stay unattributed.
//
// Pure Dart (no Flutter imports).

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models.dart' show Speaker, kSampleRate;
import '../../speech/vad_segmenter.dart' show VadSegmenterConfig;
import '../voice/voice_devices.dart' show knownSpeakerThresholdFor;
import 'phone_call_models.dart';

/// Parameters of the telephone audio profile.
class TelephoneAudioProfile {
  /// Creates a profile (the defaults are the shipped tuning).
  const TelephoneAudioProfile({
    this.phoneLinkVad = const VadSegmenterConfig(
      threshold: 0.4,
      minSpeechDuration: 0.2,
      minSilenceDuration: 0.45,
    ),
    this.speakerphoneVad = const VadSegmenterConfig(
      threshold: 0.32,
      minSpeechDuration: 0.2,
      minSilenceDuration: 0.6,
    ),
    this.bandLowHz = 300,
    this.bandHighHz = 3400,
    this.bandLimitRemote = true,
    this.bandLimitLocal = false,
    this.telephoneRelaxation = 0.1,
    this.relaxedFloor = 0.38,
    this.narrowbandMaxRatioDb = -32,
    this.widebandMinRatioDb = -20,
    this.minBandEnergyDbfs = -55,
  });

  /// VAD for Phone Link (clean digital remote channel + the microphone).
  final VadSegmenterConfig phoneLinkVad;

  /// VAD for a phone on speaker (distant, band-limited loudspeaker).
  final VadSegmenterConfig speakerphoneVad;

  /// Lower edge of the telephone band (Hz).
  final double bandLowHz;

  /// Upper edge of the telephone band (Hz).
  final double bandHighHz;

  /// Band-limit remote-side segments before ASR and embedding.
  final bool bandLimitRemote;

  /// Band-limit local-side segments too (all embeddings through the same
  /// band; costs some local accuracy).
  final bool bandLimitLocal;

  /// Threshold relaxation between a wideband voiceprint and telephone
  /// speech (or the reverse).
  final double telephoneRelaxation;

  /// Lowest threshold a telephone relaxation may reach.
  final double relaxedFloor;

  /// High-band / telephone-band energy ratio (dB) at or below which a
  /// segment is narrowband telephone audio.
  final double narrowbandMaxRatioDb;

  /// Ratio at or above which a segment is clearly wideband (a live voice).
  final double widebandMinRatioDb;

  /// Telephone-band level (dBFS) below which a segment is not classified.
  final double minBandEnergyDbfs;

  /// The shipped profile.
  static const TelephoneAudioProfile standard = TelephoneAudioProfile();

  /// VAD tuning of [mode].
  VadSegmenterConfig vadFor(PhoneCallMode mode) => switch (mode) {
    PhoneCallMode.phoneLink => phoneLinkVad,
    PhoneCallMode.speakerphone => speakerphoneVad,
  };

  /// Whether segments of [side] are band-limited.
  bool bandLimits(CallSide side) =>
      side == CallSide.remote ? bandLimitRemote : bandLimitLocal;

  /// Similarity a segment of [partition] needs to match [speaker]'s
  /// voiceprint. The channel of a remote segment is the telephone line
  /// ([kTelephoneVoiceDeviceKey]); a local segment's is [sessionDeviceKey].
  /// Same channel → [base]; telephone ↔ microphone → relaxed by
  /// [telephoneRelaxation] (not below [relaxedFloor]); two different
  /// microphones → the F18 rule ([knownSpeakerThresholdFor]).
  double knownSpeakerThreshold(
    Speaker speaker, {
    required String? partition,
    required String? sessionDeviceKey,
    required double base,
  }) {
    final channel = CallSide.ofPartition(partition) == CallSide.remote
        ? kTelephoneVoiceDeviceKey
        : sessionDeviceKey;
    final learned = speaker.voiceDevice;
    final phoneHere = isTelephoneVoiceDevice(channel);
    final phoneThere = isTelephoneVoiceDevice(learned);
    if (phoneHere && phoneThere) return base;
    if (phoneHere || phoneThere) {
      return math.max(math.min(relaxedFloor, base), base - telephoneRelaxation);
    }
    return knownSpeakerThresholdFor(
      speaker,
      sessionDeviceKey: channel,
      base: base,
    );
  }

  /// Band-limits [samples] to the telephone band (new list).
  Float32List bandLimit(Float32List samples) => TelephoneBandLimiter(
    lowHz: bandLowHz,
    highHz: bandHighHz,
  ).process(samples);

  /// Bandwidth class of [samples] (speakerphone attribution): narrowband →
  /// [CallSide.remote], clearly wideband → [CallSide.local], else null.
  CallSide? classifyBandwidth(Float32List samples) {
    final m = measureBandwidth(samples);
    if (m.bandDbfs < minBandEnergyDbfs) return null;
    if (m.highToBandDb <= narrowbandMaxRatioDb) return CallSide.remote;
    if (m.highToBandDb >= widebandMinRatioDb) return CallSide.local;
    return null;
  }
}

/// Language hint of a call: [choice] is the call setup's choice (null: as
/// in Settings, [kCallLanguageAuto]: auto-detect, else an ISO-639-1 code);
/// [settingsHint] is the Settings value (null = auto-detect).
String? resolveCallLanguageHint(String? choice, String? settingsHint) {
  final c = choice?.trim();
  if (c == null || c.isEmpty) return settingsHint;
  if (c == kCallLanguageAuto) return null;
  return c;
}

/// Call-setup language choice meaning "auto-detect".
const String kCallLanguageAuto = 'auto';

// ===========================================================================
// Filters
// ===========================================================================

/// One biquad section (RBJ cookbook), transposed direct form II.
class Biquad {
  /// Low-pass at [hz] with quality [q] for [sampleRate].
  factory Biquad.lowPass(double hz, double q, {int sampleRate = kSampleRate}) {
    final w = 2 * math.pi * hz / sampleRate;
    final c = math.cos(w);
    final alpha = math.sin(w) / (2 * q);
    return Biquad._norm(
      (1 - c) / 2,
      1 - c,
      (1 - c) / 2,
      1 + alpha,
      -2 * c,
      1 - alpha,
    );
  }

  /// High-pass at [hz] with quality [q] for [sampleRate].
  factory Biquad.highPass(double hz, double q, {int sampleRate = kSampleRate}) {
    final w = 2 * math.pi * hz / sampleRate;
    final c = math.cos(w);
    final alpha = math.sin(w) / (2 * q);
    return Biquad._norm(
      (1 + c) / 2,
      -(1 + c),
      (1 + c) / 2,
      1 + alpha,
      -2 * c,
      1 - alpha,
    );
  }

  Biquad._norm(double b0, double b1, double b2, double a0, double a1, double a2)
    : _b0 = b0 / a0,
      _b1 = b1 / a0,
      _b2 = b2 / a0,
      _a1 = a1 / a0,
      _a2 = a2 / a0;

  final double _b0, _b1, _b2, _a1, _a2;
  double _z1 = 0, _z2 = 0;

  /// Filters one sample.
  double step(double x) {
    final y = _b0 * x + _z1;
    _z1 = _b1 * x - _a1 * y + _z2;
    _z2 = _b2 * x - _a2 * y;
    return y;
  }

  /// Filters [x] in place.
  void processInPlace(Float32List x) {
    for (var i = 0; i < x.length; i++) {
      x[i] = step(x[i]);
    }
  }
}

/// Q factors of a 4th-order Butterworth as two biquads.
const List<double> _butter4Q = [0.5411961, 1.3065630];

/// 4th-order Butterworth band-pass (high-pass at [lowHz] × low-pass at
/// [highHz]): the telephone band.
class TelephoneBandLimiter {
  /// Creates the filter (fresh state for each [process]).
  const TelephoneBandLimiter({this.lowHz = 300, this.highHz = 3400});

  /// High-pass corner.
  final double lowHz;

  /// Low-pass corner.
  final double highHz;

  /// Filtered copy of [samples].
  Float32List process(Float32List samples) {
    final out = Float32List.fromList(samples);
    for (final q in _butter4Q) {
      Biquad.highPass(lowHz, q).processInPlace(out);
    }
    for (final q in _butter4Q) {
      Biquad.lowPass(highHz, q).processInPlace(out);
    }
    return out;
  }
}

/// Telephone-band level and high-band ratio of a segment.
class BandwidthMeasure {
  /// Creates a measure.
  const BandwidthMeasure({required this.bandDbfs, required this.highToBandDb});

  /// RMS level of the 300–3400 Hz band (dBFS).
  final double bandDbfs;

  /// Energy above ~4 kHz relative to the telephone band (dB).
  final double highToBandDb;
}

/// Measures [samples] (16 kHz mono): telephone band 300–3400 Hz vs the band
/// above 4.2 kHz (8th-order high-pass, so the codec's transition band does
/// not leak in).
BandwidthMeasure measureBandwidth(Float32List samples) {
  if (samples.isEmpty) {
    return const BandwidthMeasure(
      bandDbfs: double.negativeInfinity,
      highToBandDb: 0,
    );
  }
  final band = const TelephoneBandLimiter().process(samples);
  final high = Float32List.fromList(samples);
  for (var k = 0; k < 2; k++) {
    for (final q in _butter4Q) {
      Biquad.highPass(4200, q).processInPlace(high);
    }
  }
  // Skip the filters' start-up transient (20 ms).
  final from = math.min(samples.length - 1, kSampleRate ~/ 50);
  var eb = 0.0, eh = 0.0;
  for (var i = from; i < samples.length; i++) {
    eb += band[i] * band[i];
    eh += high[i] * high[i];
  }
  final n = math.max(1, samples.length - from);
  const tiny = 1e-20;
  return BandwidthMeasure(
    bandDbfs: 10 * math.log(eb / n + tiny) / math.ln10,
    highToBandDb: 10 * math.log((eh + tiny) / (eb + tiny)) / math.ln10,
  );
}
