// What the phone-call session sources share: per-side levels and live
// counters for the call card, and the call log written at the end of a take.

import '../../diarization/channel_cue.dart';
import 'phone_call_log.dart';
import 'phone_call_models.dart';

/// Live counters of a call take.
class CallLiveStats {
  /// Creates the counters.
  const CallLiveStats({
    this.localSegments = 0,
    this.remoteSegments = 0,
    this.bleedSuppressed = 0,
    this.overlaps = 0,
    this.unattributed = 0,
  });

  /// Segments attributed to the local side.
  final int localSegments;

  /// Segments attributed to the remote side.
  final int remoteSegments;

  /// Microphone segments recognised as the remote voice from the speakers.
  final int bleedSuppressed;

  /// Segments in which both sides spoke.
  final int overlaps;

  /// Segments that could not be attributed.
  final int unattributed;

  /// True when echo of the speakers is frequent enough to recommend
  /// headphones (at least 3 suppressed segments and a quarter of the remote
  /// ones).
  bool get suggestHeadphones =>
      bleedSuppressed >= 3 && bleedSuppressed * 4 >= remoteSegments;
}

/// Optional interface of a session source recording a phone call.
abstract interface class CallSessionAudio {
  /// How the call is captured.
  PhoneCallMode get callMode;

  /// 0..1 level of the local side (microphone).
  Stream<double> get localLevel;

  /// 0..1 level of the remote side (empty for a speakerphone take, where
  /// both sides share the microphone).
  Stream<double> get remoteLevel;

  /// [stats] after each change.
  Stream<CallLiveStats> get liveStats;

  /// Counters of the running (or last) take.
  CallLiveStats get stats;
}

/// The [PhoneCallLog] of a take from the stored segments' profiles.
PhoneCallLog callLogOf(
  PhoneCallMode mode,
  Map<String, ChannelProfile> segmentProfiles,
  CallLiveStats stats,
) => PhoneCallLog(
  mode: mode,
  sides: {
    for (final e in segmentProfiles.entries)
      e.key: ?CallSide.ofPartition(e.value.partition),
  },
  bleedSuppressed: stats.bleedSuppressed,
  overlaps: stats.overlaps,
  unattributed: stats.unattributed,
);
