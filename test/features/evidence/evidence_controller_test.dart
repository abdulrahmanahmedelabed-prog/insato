import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/features/evidence/evidence.dart';

import 'fake_player.dart';

TranscriptSegment seg(int index, int startMs, int endMs) => TranscriptSegment(
  id: 's$index',
  meetingId: 'm',
  index: index,
  startMs: startMs,
  endMs: endMs,
  text: 'line $index',
);

final segments = [
  seg(0, 0, 2000),
  seg(1, 2500, 5000),
  seg(2, 5200, 9000),
  seg(42, 751000, 754000),
];

class Env {
  Env({EvidenceAudioLocation? location, Object? resolverError}) {
    container = ProviderContainer(
      overrides: [
        segmentsProvider.overrideWith((ref, id) => Stream.value(segments)),
        evidenceAudioResolverProvider.overrideWithValue((id) async {
          resolverCalls++;
          if (resolverError != null) throw resolverError;
          return this.location;
        }),
        evidencePlayerFactoryProvider.overrideWithValue(() {
          final p = FakeEvidencePlayer(duration: duration)..failOpen = failOpen;
          players.add(p);
          return p;
        }),
      ],
    );
    this.location =
        location ??
        const EvidenceAudioLocation(EvidenceAudioStatus.available, '/r/m.wav');
    sub = container.listen(evidenceControllerProvider('m'), (_, _) {});
  }

  late final ProviderContainer container;
  late final ProviderSubscription<EvidenceState> sub;
  late EvidenceAudioLocation location;
  int? duration = 3600000;
  bool failOpen = false;
  int resolverCalls = 0;
  final List<FakeEvidencePlayer> players = [];

  EvidenceController get ctrl =>
      container.read(evidenceControllerProvider('m').notifier);
  EvidenceState get state => container.read(evidenceControllerProvider('m'));
  FakeEvidencePlayer get player => players.single;

  Future<void> ready() async {
    await container.read(segmentsProvider('m').future);
    await pumpEventQueue();
  }

  void dispose() => container.dispose();
}

EvidenceTarget target(int index) => resolveEvidence([index], segments).single;

void main() {
  test('plays from the segment start minus 1 s and highlights it', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.open(target(42));
    expect(env.player.calls, ['open:/r/m.wav', 'seek:750000', 'play']);
    final s = env.state;
    expect(s.playerVisible, isTrue);
    expect(s.playing, isTrue);
    expect(s.loading, isFalse);
    expect(s.positionMs, 750000);
    expect(s.durationMs, 3600000);
    expect(s.highlightedSegmentId, 's42');
    expect(s.highlightedSegmentIndex, 42);
    expect(s.focusSerial, 1);
    expect(s.transcriptJumpSerial, 0);
    expect(s.target?.segmentIndex, 42);
    env.dispose();
    await pumpEventQueue();
    expect(env.player.disposed, isTrue);
  });

  test('pre-roll is clamped at the start of the recording', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.open(target(0));
    expect(env.player.lastSeek, 0);
    env.dispose();
  });

  test('re-opening reuses the loaded file', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.open(target(42));
    await env.ctrl.open(target(1));
    expect(env.player.calls.where((c) => c.startsWith('open')), hasLength(1));
    expect(env.player.lastSeek, 1500);
    expect(env.state.highlightedSegmentIndex, 1);
    expect(env.state.focusSerial, 2);
    env.dispose();
  });

  test('without kept audio it jumps to the transcript line', () async {
    final env = Env(location: EvidenceAudioLocation.notKept);
    await env.ready();
    await env.ctrl.open(target(2));
    expect(env.players, isEmpty);
    final s = env.state;
    expect(s.playerVisible, isFalse);
    expect(s.highlightedSegmentId, 's2');
    expect(s.transcriptJumpSerial, 1);
    expect(s.focusSerial, greaterThanOrEqualTo(1));
    expect(s.noticeAr, ES.audioNotKept);
    expect(s.noticeSerial, 1);
    env.dispose();
  });

  test('while still recording it jumps with its own notice', () async {
    final env = Env(
      location: const EvidenceAudioLocation(EvidenceAudioStatus.recording),
    );
    await env.ready();
    await env.ctrl.open(target(2));
    expect(env.state.noticeAr, ES.audioStillRecording);
    expect(env.state.transcriptJumpSerial, 1);
    env.dispose();
  });

  test('resolver failure falls back to the transcript', () async {
    final env = Env(resolverError: Exception('db'));
    await env.ready();
    await env.ctrl.open(target(2));
    expect(env.state.transcriptJumpSerial, 1);
    expect(env.state.noticeAr, ES.audioNotKept);
    env.dispose();
  });

  test('unplayable file falls back to the transcript and releases', () async {
    final env = Env()..failOpen = true;
    await env.ready();
    final container = env.container;
    final ctrl = env.ctrl;
    await ctrl.open(target(42));
    expect(env.players.single.disposed, isTrue);
    final s = container.read(evidenceControllerProvider('m'));
    expect(s.playerVisible, isFalse);
    expect(s.highlightedSegmentId, 's42');
    expect(s.transcriptJumpSerial, 1);
    expect(s.noticeAr, ES.playbackFailed);
    // A later tap creates a fresh player.
    env.failOpen = false;
    await ctrl.open(target(1));
    expect(env.players, hasLength(2));
    expect(env.state.playing, isTrue);
    env.dispose();
  });

  test('pause, resume, speed toggle (applied after play)', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.open(target(1));
    await env.ctrl.togglePlay();
    expect(env.state.playing, isFalse);
    expect(env.player.calls.last, 'pause');
    await env.ctrl.cycleSpeed();
    expect(env.state.speed, 1.5);
    // Paused: the rate is applied on the next play.
    expect(env.player.calls.last, 'pause');
    await env.ctrl.togglePlay();
    expect(env.state.playing, isTrue);
    expect(env.player.calls.sublist(env.player.calls.length - 2), [
      'play',
      'rate:1.5',
    ]);
    await env.ctrl.cycleSpeed();
    expect(env.state.speed, 1.0);
    expect(env.player.calls.last, 'rate:1.0');
    env.dispose();
  });

  test('speed is kept for the next clip', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.cycleSpeed();
    await env.ctrl.open(target(42));
    expect(env.player.calls, [
      'open:/r/m.wav',
      'seek:750000',
      'play',
      'rate:1.5',
    ]);
    env.dispose();
  });

  test('scrub seeks (clamped) and moves the highlight', () async {
    final env = Env();
    env.duration = 10000;
    await env.ready();
    await env.ctrl.open(target(0));
    final focus = env.state.focusSerial;
    await env.ctrl.seekTo(6000);
    expect(env.player.lastSeek, 6000);
    expect(env.state.positionMs, 6000);
    expect(env.state.highlightedSegmentIndex, 2);
    expect(env.state.focusSerial, focus + 1);
    await env.ctrl.seekTo(99999);
    expect(env.player.lastSeek, 10000);
    await env.ctrl.seekTo(-5);
    expect(env.player.lastSeek, 0);
    env.dispose();
  });

  test('highlight follows playback position', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.open(target(2));
    expect(env.player.lastSeek, 4200);
    final focus = env.state.focusSerial;
    // Pre-roll (inside line 1): the evidence line stays highlighted.
    env.player.position.add(4300);
    await pumpEventQueue();
    expect(env.state.positionMs, 4300);
    expect(env.state.highlightedSegmentIndex, 2);
    env.player.position.add(6000);
    await pumpEventQueue();
    expect(env.state.highlightedSegmentIndex, 2);
    // Scrub back to line 1, then playback follows.
    await env.ctrl.seekTo(1000);
    expect(env.state.highlightedSegmentIndex, 0);
    final afterScrub = env.state.focusSerial;
    expect(afterScrub, focus + 1);
    env.player.position.add(3000);
    await pumpEventQueue();
    expect(env.state.positionMs, 3000);
    expect(env.state.highlightedSegmentIndex, 1);
    // Following does not force a precise re-scroll.
    expect(env.state.focusSerial, afterScrub);
    env.player.position.add(5500);
    await pumpEventQueue();
    expect(env.state.highlightedSegmentIndex, 2);
    // Long silence keeps the last line.
    env.player.position.add(15000);
    await pumpEventQueue();
    expect(env.state.highlightedSegmentIndex, 2);
    env.dispose();
  });

  test('completion stops; play again replays the clip', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.open(target(42));
    env.player.done.add(null);
    await pumpEventQueue();
    expect(env.state.playing, isFalse);
    expect(env.state.positionMs, 3600000);
    await env.ctrl.togglePlay();
    expect(env.player.lastSeek, 750000);
    expect(env.state.playing, isTrue);
    env.dispose();
  });

  test('duration updates and replayClip', () async {
    final env = Env();
    env.duration = null;
    await env.ready();
    await env.ctrl.open(target(2));
    expect(env.state.durationMs, isNull);
    env.player.durations.add(20000);
    await pumpEventQueue();
    expect(env.state.durationMs, 20000);
    await env.ctrl.seekTo(15000);
    await env.ctrl.replayClip();
    expect(env.player.lastSeek, 4200);
    expect(env.state.highlightedSegmentIndex, 2);
    env.dispose();
  });

  test('close pauses and hides; showInTranscript asks for a jump', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.open(target(1));
    await env.ctrl.closePlayer();
    expect(env.state.playerVisible, isFalse);
    expect(env.state.playing, isFalse);
    expect(env.player.calls.last, 'pause');
    expect(env.state.highlightedSegmentId, 's1');
    final jumps = env.state.transcriptJumpSerial;
    env.ctrl.showInTranscript();
    expect(env.state.transcriptJumpSerial, jumps + 1);
    env.dispose();
  });

  test('play failure falls back to the transcript', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.open(target(1));
    await env.ctrl.togglePlay(); // pause
    env.player.failPlay = true;
    await env.ctrl.togglePlay();
    expect(env.players.single.disposed, isTrue);
    expect(env.state.playerVisible, isFalse);
    expect(env.state.noticeAr, ES.playbackFailed);
    env.dispose();
  });

  test('openIndex resolves ids and reports missing segments', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.openIndex(77);
    expect(env.state.noticeAr, ES.segmentMissing);
    expect(env.players, isEmpty);
    await env.ctrl.openIndex(42);
    expect(env.state.highlightedSegmentIndex, 42);
    expect(env.state.playing, isTrue);
    env.dispose();
  });

  test('a newer tap supersedes one still opening', () async {
    final env = Env();
    await env.ready();
    final first = env.ctrl.open(target(42));
    final second = env.ctrl.open(target(1));
    await Future.wait([first, second]);
    expect(env.state.target?.segmentIndex, 1);
    expect(env.state.highlightedSegmentIndex, 1);
    expect(env.player.lastSeek, 1500);
    env.dispose();
  });

  test('controls without a player are no-ops', () async {
    final env = Env();
    await env.ready();
    await env.ctrl.togglePlay();
    await env.ctrl.replayClip();
    await env.ctrl.seekTo(100);
    await env.ctrl.cycleSpeed();
    expect(env.players, isEmpty);
    expect(env.state.speed, 1.5);
    env.dispose();
  });
}
