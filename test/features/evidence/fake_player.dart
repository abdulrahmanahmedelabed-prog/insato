import 'dart:async';

import 'package:insato/features/evidence/evidence_player.dart';

/// Records calls; streams are driven by the test.
class FakeEvidencePlayer implements EvidenceAudioPlayer {
  FakeEvidencePlayer({this.duration = 3600000});

  int? duration;
  bool failOpen = false;
  bool failPlay = false;
  final List<String> calls = [];
  final StreamController<int> position = StreamController<int>.broadcast();
  final StreamController<int> durations = StreamController<int>.broadcast();
  final StreamController<void> done = StreamController<void>.broadcast();
  bool disposed = false;
  double rate = 1.0;
  int lastSeek = -1;

  @override
  Future<void> open(String path) async {
    calls.add('open:$path');
    if (failOpen) throw Exception('cannot open');
  }

  @override
  Future<void> seek(int positionMs) async {
    calls.add('seek:$positionMs');
    lastSeek = positionMs;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    if (failPlay) throw Exception('cannot play');
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> setRate(double rate) async {
    calls.add('rate:$rate');
    this.rate = rate;
  }

  @override
  Future<int?> durationMs() async => duration;

  @override
  Stream<int> get positionMs => position.stream;

  @override
  Stream<int> get durationChanges => durations.stream;

  @override
  Stream<void> get completed => done.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }
}
