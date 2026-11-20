// Host-side fusion of several microphones into one meeting (v1.2 C).
//
// Timeline: the host's own capture (sample index of the host microphone,
// pauses excluded) is the meeting's timeline. Every guest frame carries the
// guest's capture time; it is mapped to the host clock (network estimate,
// [ClockSyncEstimator]) and then to a host sample index ([CaptureTimestamper]
// of the host capture), plus the audio-measured correction of
// [AlignmentTracker]. Each channel is kept in a ring buffer indexed by host
// sample.
//
// Output to the VAD (and the archive): the host timeline delayed by
// [FusionConfig.latencySamples] (guests' audio needs time to cross the
// network), as an SNR-weighted mix of the channels that cover each 10 ms
// block (gain-normalised to the host's speech level). With no guest the
// output is the host signal, sample for sample.
//
// Per VAD segment ([fuseSegment]): the channel with the best SNR over the
// segment is handed to ASR and embedding, and the SNR of every covering
// channel becomes the segment's [ChannelProfile] (diarization cue).
//
// Guests that drop out simply stop covering blocks; the meeting goes on
// with the remaining channels. Joins, drops and returns are recorded as
// [DeviceTimelineEvent]s in meeting time.
//
// Pure Dart; time is injected (µs of the host's monotonic clock).

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models.dart' show SpeechSegment, kSampleRate;
import '../../diarization/channel_cue.dart';
import 'alignment.dart';
import 'clock_sync.dart';

/// Channel id of the host's own microphone.
const String kHostChannelId = 'host';

/// Tuning of [FusionEngine].
class FusionConfig {
  /// Creates a configuration.
  const FusionConfig({
    this.latencySamples = kSampleRate * 6 ~/ 10,
    this.ringSeconds = 48,
    this.blockSamples = kSampleRate ~/ 100,
    this.elasticToleranceSamples = kSampleRate * 3 ~/ 1000,
    this.refineEverySamples = kSampleRate * 3,
    this.refineWindowSamples = kSampleRate * 4,
    this.maxLagMs = 300,
    this.minSegmentCoverage = 0.9,
  });

  /// Output delay behind the host capture (default 600 ms).
  final int latencySamples;

  /// Ring buffer length per channel, in seconds (longest VAD segment plus
  /// its emission delay must fit).
  final int ringSeconds;

  /// Validity / mixing granularity (10 ms).
  final int blockSamples;

  /// A contiguous guest frame landing within this of where the previous one
  /// ended is written right after it (no click from network jitter).
  final int elasticToleranceSamples;

  /// Cross-correlation refinement period, in samples of guest audio.
  final int refineEverySamples;

  /// Cross-correlation window.
  final int refineWindowSamples;

  /// Largest lag searched by the refinement.
  final int maxLagMs;

  /// Fraction of a segment a channel must cover to compete for it.
  final double minSegmentCoverage;
}

/// One frame of guest audio (decoded).
class GuestAudioFrame {
  /// Creates a frame.
  const GuestAudioFrame({
    required this.seq,
    required this.startIndex,
    required this.captureUs,
    required this.samples,
  });

  /// Per-connection sequence number.
  final int seq;

  /// Guest sample index of the first sample (since the guest's capture
  /// started).
  final int startIndex;

  /// Guest clock time (µs) of the first sample.
  final int captureUs;

  /// 16 kHz mono samples.
  final Float32List samples;
}

/// Ring buffer of one channel on the host timeline.
class ChannelRing {
  /// Creates a ring of [capacity] samples in blocks of [block].
  ChannelRing(int capacity, this.block)
    : capacity = (capacity ~/ block) * block,
      data = Float32List((capacity ~/ block) * block),
      _tags = Int32List(capacity ~/ block)..fillRange(0, capacity ~/ block, -1),
      _counts = Int32List(capacity ~/ block);

  /// Samples held.
  final int capacity;

  /// Block size.
  final int block;

  /// Sample storage (index mod [capacity]).
  final Float32List data;
  final Int32List _tags;
  final Int32List _counts;

  int get _blocks => _tags.length;

  /// Writes [samples] at host index [index] (negative indices are skipped).
  void write(int index, Float32List samples, [int offset = 0, int? length]) {
    final n = length ?? samples.length - offset;
    var i = 0;
    if (index < 0) i = -index;
    while (i < n) {
      final abs = index + i;
      final blockNo = abs ~/ block;
      final slot = blockNo % _blocks;
      if (_tags[slot] != blockNo) {
        _tags[slot] = blockNo;
        _counts[slot] = 0;
        data.fillRange(slot * block, slot * block + block, 0);
      }
      final inBlock = abs - blockNo * block;
      final take = math.min(n - i, block - inBlock);
      final base = slot * block + inBlock;
      for (var k = 0; k < take; k++) {
        data[base + k] = samples[offset + i + k];
      }
      _counts[slot] = math.min(block, _counts[slot] + take);
      i += take;
    }
  }

  /// True when block [blockNo] holds (almost) complete data.
  bool blockValid(int blockNo) {
    if (blockNo < 0) return false;
    final slot = blockNo % _blocks;
    return _tags[slot] == blockNo && _counts[slot] >= block * 9 ~/ 10;
  }

  /// Fraction of the blocks of `[start, start + length)` that are valid.
  double coverage(int start, int length) {
    if (length <= 0) return 0;
    final b0 = start ~/ block;
    final b1 = (start + length - 1) ~/ block;
    var ok = 0;
    for (var b = b0; b <= b1; b++) {
      if (blockValid(b)) ok++;
    }
    return ok / (b1 - b0 + 1);
  }

  /// Sample at host index [abs] (0 when its block is not valid).
  double sampleAt(int abs) {
    final blockNo = abs ~/ block;
    if (!blockValid(blockNo)) return 0;
    return data[abs % capacity];
  }

  /// Copies `[start, start + length)`; invalid blocks are taken from
  /// [fallback] (same range) or zero.
  Float32List read(int start, int length, {Float32List? fallback}) {
    final out = Float32List(length);
    for (var i = 0; i < length; i++) {
      final abs = start + i;
      final blockNo = abs ~/ block;
      if (abs >= 0 && blockValid(blockNo)) {
        out[i] = data[abs % capacity];
      } else if (fallback != null && i < fallback.length) {
        out[i] = fallback[i];
      }
    }
    return out;
  }

  /// Mean energy over the valid blocks of the range (null when none).
  double? meanEnergy(int start, int length) {
    var sum = 0.0;
    var n = 0;
    for (var i = 0; i < length; i++) {
      final abs = start + i;
      if (abs < 0 || !blockValid(abs ~/ block)) continue;
      final v = data[abs % capacity];
      sum += v * v;
      n++;
    }
    return n == 0 ? null : sum / n;
  }
}

/// A join / drop / return / removal of a guest, in meeting time.
class DeviceTimelineEvent {
  /// Creates an event.
  const DeviceTimelineEvent({
    required this.channelId,
    required this.kind,
    required this.atMs,
  });

  /// Guest id.
  final String channelId;

  /// `joined`, `left`, `rejoined` or `removed`.
  final String kind;

  /// Meeting time (ms of the host timeline).
  final int atMs;

  /// JSON form.
  Map<String, Object?> toJson() => {'id': channelId, 'kind': kind, 'at_ms': atMs};

  /// Parses [toJson] output.
  static DeviceTimelineEvent? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], kind = j['kind'], at = j['at_ms'];
    if (id is! String || kind is! String || at is! int) return null;
    return DeviceTimelineEvent(channelId: id, kind: kind, atMs: at);
  }
}

/// Live statistics of one guest channel.
class ChannelStats {
  /// Frames received.
  int framesReceived = 0;

  /// Frames dropped (no clock yet, paused, too old / too far ahead).
  int framesDropped = 0;

  /// Frames that arrived after their audio was already mixed for the VAD
  /// (still used for segment fusion).
  int framesLate = 0;

  /// Sequence gaps (lost frames).
  int framesLost = 0;

  /// Segments for which this channel was chosen for transcription.
  int segmentsChosen = 0;

  /// Last frame's position minus the host capture position, in ms (how far
  /// behind real time the guest's audio arrives).
  double? delayMs;

  /// Guest sample index of the latest placed frame.
  int? lastGuestIndex;

  /// Host index where that frame was placed.
  int? lastHostPos;

  /// Copies the counters.
  Map<String, Object?> toJson() => {
    'received': framesReceived,
    'dropped': framesDropped,
    'late': framesLate,
    'lost': framesLost,
    'chosen': segmentsChosen,
  };
}

class _Channel {
  _Channel(this.id, FusionConfig c)
    : ring = ChannelRing(c.ringSeconds * kSampleRate, c.blockSamples);
  final String id;
  final ChannelRing ring;
  final AlignmentTracker alignment = AlignmentTracker();
  final ChannelStats stats = ChannelStats();
  double? floor; // noise floor energy
  double speechLevel = 0; // EMA of energy on speech blocks
  double weight = 0; // smoothed mixing weight
  int nextPos = -1;
  int nextGuestIndex = -1;
  int lastSeq = -1;
  int sinceRefine = 0;
  int validSince = 0; // host index from which the current correction applies
  bool connected = false;

  double snrDb(double energy) {
    final f = floor ?? energy;
    return 10 * math.log(((energy + 1e-12) / (f + 1e-12))) / math.ln10;
  }

  void updateFloor(double energy) {
    final f = floor;
    if (f == null || energy < f) {
      floor = math.max(energy, 1e-10);
    } else {
      floor = f * 1.002; // ≈ +0.9 dB/s while above
    }
  }
}

/// Result of [FusionEngine.fuseSegment].
class FusedSegment {
  /// Creates a result.
  const FusedSegment({
    required this.segment,
    this.channelId,
    this.profile,
  });

  /// The segment to transcribe (samples of the chosen channel).
  final SpeechSegment segment;

  /// Chosen channel (null: the mix was kept).
  final String? channelId;

  /// SNR per covering channel (null unless ≥ 2 channels covered it).
  final ChannelProfile? profile;
}

/// See the file header.
class FusionEngine {
  /// Creates an engine; [clockOf] returns a guest's clock estimate.
  FusionEngine({
    this.config = const FusionConfig(),
    required this.clockOf,
  }) {
    _host = _Channel(kHostChannelId, config)..connected = true;
    _channels[kHostChannelId] = _host;
  }

  /// Tuning.
  final FusionConfig config;

  /// Clock estimate of a guest (null when unknown).
  final ClockSyncEstimator? Function(String guestId) clockOf;

  late final _Channel _host;
  final Map<String, _Channel> _channels = {};
  final CaptureTimestamper _hostClock = CaptureTimestamper();
  final List<DeviceTimelineEvent> _events = [];
  int _hostCount = 0;
  int _emitted = 0;
  bool _paused = false;
  int? _resumedAtUs;
  bool _flushed = false;

  /// Host samples captured so far.
  int get hostSamples => _hostCount;

  /// Samples emitted to the VAD so far.
  int get emittedSamples => _emitted;

  /// Meeting time of the host capture position, in ms.
  int get nowMs => _hostCount * 1000 ~/ kSampleRate;

  /// Join / drop events in meeting time.
  List<DeviceTimelineEvent> get events => List.unmodifiable(_events);

  /// Guest channel ids seen.
  Iterable<String> get guestIds =>
      _channels.keys.where((k) => k != kHostChannelId);

  /// Statistics of guest [id] (null when never seen).
  ChannelStats? statsOf(String id) => _channels[id]?.stats;

  /// Alignment of guest [id] (null when never seen).
  AlignmentTracker? alignmentOf(String id) => _channels[id]?.alignment;

  /// Records that guest [id] connected (first time: `joined`, later:
  /// `rejoined`).
  void guestConnected(String id) {
    final existing = _channels[id];
    final ch = existing ?? (_channels[id] = _Channel(id, config));
    if (ch.connected) return;
    ch.connected = true;
    ch.nextGuestIndex = -1;
    ch.lastSeq = -1;
    _events.add(
      DeviceTimelineEvent(
        channelId: id,
        kind: existing == null ? 'joined' : 'rejoined',
        atMs: nowMs,
      ),
    );
  }

  /// Records that guest [id] disconnected ([removed]: by the host).
  void guestDisconnected(String id, {bool removed = false}) {
    final ch = _channels[id];
    if (ch == null || !ch.connected) return;
    ch.connected = false;
    _events.add(
      DeviceTimelineEvent(
        channelId: id,
        kind: removed ? 'removed' : 'left',
        atMs: nowMs,
      ),
    );
  }

  /// Host capture paused: guest audio is ignored until [resume].
  void pause() => _paused = true;

  /// Host capture resumed at host time [nowUs].
  void resume(int nowUs) {
    _paused = false;
    _resumedAtUs = nowUs;
    _hostClock.reset();
    for (final ch in _channels.values) {
      ch.nextGuestIndex = -1;
    }
  }

  /// Adds a host microphone frame that arrived at [arrivalUs]; returns the
  /// fused frames now due for the VAD (zero or one).
  List<Float32List> addHostFrame(Float32List samples, int arrivalUs) {
    if (samples.isEmpty || _flushed) return const [];
    final start = _hostCount;
    _hostClock.stamp(
      endIndex: start + samples.length,
      length: samples.length,
      arrivalUs: arrivalUs,
    );
    _host.ring.write(start, samples);
    _hostCount += samples.length;
    final due = _hostCount - config.latencySamples;
    if (due <= _emitted) return const [];
    return [_mix(_emitted, due - _emitted)];
  }

  /// Emits everything not yet emitted (end of the take).
  List<Float32List> flush() {
    _flushed = true;
    if (_hostCount <= _emitted) return const [];
    return [_mix(_emitted, _hostCount - _emitted)];
  }

  /// Adds a guest frame that arrived at host time [arrivalUs].
  void addGuestFrame(String id, GuestAudioFrame f, int arrivalUs) {
    final ch = _channels[id] ?? (_channels[id] = _Channel(id, config));
    final st = ch.stats;
    st.framesReceived++;
    if (ch.lastSeq >= 0 && f.seq > ch.lastSeq + 1) {
      st.framesLost += f.seq - ch.lastSeq - 1;
    }
    ch.lastSeq = math.max(ch.lastSeq, f.seq);
    final n = f.samples.length;
    final clock = clockOf(id);
    if (_paused || _flushed || n == 0 || clock == null || !clock.isReady ||
        _hostClock.anchorUs == null) {
      st.framesDropped++;
      return;
    }
    final hostUs = clock.guestToHost(f.captureUs);
    final resumed = _resumedAtUs;
    if (resumed != null && hostUs < resumed) {
      st.framesDropped++;
      return;
    }
    var pos = (_hostClock.indexAt(hostUs) + ch.alignment.correctionSamples)
        .round();
    if (ch.nextGuestIndex == f.startIndex &&
        (pos - ch.nextPos).abs() <= config.elasticToleranceSamples) {
      pos = ch.nextPos;
    }
    final capacity = ch.ring.capacity;
    if (pos + n <= _hostCount - capacity + config.latencySamples ||
        pos > _hostCount + capacity ~/ 4) {
      st.framesDropped++;
      ch.nextGuestIndex = -1;
      return;
    }
    if (pos < _emitted) st.framesLate++;
    st.delayMs = (_hostCount - (pos + n)) * 1000 / kSampleRate;
    ch.ring.write(pos, f.samples);
    st.lastGuestIndex = f.startIndex;
    st.lastHostPos = pos;
    ch.nextPos = pos + n;
    ch.nextGuestIndex = f.startIndex + n;
    ch.sinceRefine += n;
    if (ch.sinceRefine >= config.refineEverySamples) {
      ch.sinceRefine = 0;
      _refine(ch);
    }
  }

  /// Runs one cross-correlation refinement of [ch] against the host.
  void _refine(_Channel ch) {
    final w = config.refineWindowSamples;
    final end = math.min(ch.nextPos, _hostCount) - config.blockSamples;
    final start = end - w;
    if (start < ch.validSince || start < 0) return;
    if (ch.ring.coverage(start, w) < 0.95 ||
        _host.ring.coverage(start, w) < 0.95) {
      return;
    }
    final est = estimateLag(
      _host.ring.read(start, w),
      ch.ring.read(start, w),
      maxLagMs: config.maxLagMs,
    );
    final delta = ch.alignment.consider(est);
    if (delta != 0) {
      ch.validSince = ch.nextPos + delta.abs();
      ch.nextGuestIndex = -1; // next frame lands at the corrected place
    }
  }

  /// Picks the transcription channel of [s] (see the file header).
  FusedSegment fuseSegment(SpeechSegment s) {
    if (_channels.length < 2) return FusedSegment(segment: s);
    final start = s.startMs * kSampleRate ~/ 1000;
    final len = s.samples.length;
    final snr = <String, double>{};
    for (final ch in _channels.values) {
      if (ch.ring.coverage(start, len) < config.minSegmentCoverage) continue;
      final e = ch.ring.meanEnergy(start, len);
      if (e == null || ch.floor == null) continue;
      snr[ch.id] = ch.snrDb(e);
    }
    if (snr.isEmpty) return FusedSegment(segment: s);
    final profile = ChannelProfile(snr);
    final best = profile.nearest!;
    final ch = _channels[best]!;
    ch.stats.segmentsChosen++;
    return FusedSegment(
      segment: SpeechSegment(
        index: s.index,
        startMs: s.startMs,
        samples: ch.ring.read(start, len, fallback: s.samples),
      ),
      channelId: best,
      profile: profile.isInformative ? profile : null,
    );
  }

  /// Mixes `[start, start + length)` for the VAD.
  Float32List _mix(int start, int length) {
    final out = Float32List(length);
    final block = config.blockSamples;
    var i = 0;
    final channels = _channels.values.toList(growable: false);
    final energies = List<double?>.filled(channels.length, null);
    final raw = List<double>.filled(channels.length, 0);
    while (i < length) {
      final abs = start + i;
      final blockNo = abs ~/ block;
      final end = math.min(length, (blockNo + 1) * block - start);
      final n = end - i;
      // Energy / SNR per covering channel.
      var hostSpeech = _host.speechLevel;
      var total = 0.0;
      for (var c = 0; c < channels.length; c++) {
        final ch = channels[c];
        energies[c] = null;
        raw[c] = 0;
        if (!ch.ring.blockValid(blockNo)) continue;
        var e = 0.0;
        for (var k = 0; k < n; k++) {
          final v = ch.ring.data[(abs + k) % ch.ring.capacity];
          e += v * v;
        }
        e /= n;
        energies[c] = e;
        ch.updateFloor(e);
        final snr = ch.snrDb(e);
        if (snr > 10) {
          ch.speechLevel = ch.speechLevel == 0
              ? e
              : ch.speechLevel * 0.995 + e * 0.005;
        }
        raw[c] = math.pow(10, snr.clamp(-20.0, 60.0) / 10).toDouble();
        total += raw[c];
      }
      hostSpeech = _host.speechLevel;
      // Smooth the weights (≈ 50 ms), normalise, gain-match to the host.
      var wsum = 0.0;
      for (var c = 0; c < channels.length; c++) {
        final ch = channels[c];
        final target = energies[c] == null || total <= 0 ? 0.0 : raw[c] / total;
        ch.weight = energies[c] == null ? 0 : ch.weight * 0.8 + target * 0.2;
        wsum += ch.weight;
      }
      if (wsum <= 0 || channels.length == 1) {
        // Host only (or nothing yet): pass the host through unchanged.
        for (var k = i; k < end; k++) {
          out[k] = _host.ring.sampleAt(start + k);
        }
      } else {
        for (var c = 0; c < channels.length; c++) {
          final ch = channels[c];
          if (energies[c] == null || ch.weight <= 0) continue;
          var gain = 1.0;
          if (!identical(ch, _host) && hostSpeech > 0 && ch.speechLevel > 0) {
            gain = math.sqrt(hostSpeech / ch.speechLevel).clamp(0.25, 4.0);
          }
          final w = ch.weight / wsum * gain;
          for (var k = i; k < end; k++) {
            out[k] += ch.ring.data[(start + k) % ch.ring.capacity] * w;
          }
        }
        for (var k = i; k < end; k++) {
          out[k] = out[k].clamp(-1.0, 1.0);
        }
      }
      i = end;
    }
    _emitted = start + length;
    return out;
  }
}
