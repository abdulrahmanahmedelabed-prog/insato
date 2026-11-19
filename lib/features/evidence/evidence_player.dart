// Audio playback of the archived meeting WAV for evidence clips (F5), behind
// a small interface so the controller is testable without the native
// `audioplayers` plugin.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays one local audio file with seeking, pause and speed control.
abstract class EvidenceAudioPlayer {
  /// Opens the WAV file at [path] (paused at 0). Throws when the file
  /// cannot be opened.
  Future<void> open(String path);

  /// Moves to [positionMs].
  Future<void> seek(int positionMs);

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Sets the playback rate (call after [play]; 1.0 = normal).
  Future<void> setRate(double rate);

  /// Duration of the open file, when known.
  Future<int?> durationMs();

  /// Playback position updates (milliseconds).
  Stream<int> get positionMs;

  /// Duration updates (milliseconds) once the file is prepared.
  Stream<int> get durationChanges;

  /// Fires when playback reaches the end of the file.
  Stream<void> get completed;

  /// Releases the player; it must not be used afterwards.
  Future<void> dispose();
}

/// [EvidenceAudioPlayer] backed by `audioplayers` (Android, iOS, Windows).
class AudioplayersEvidencePlayer implements EvidenceAudioPlayer {
  /// Creates the player.
  AudioplayersEvidencePlayer() : _player = AudioPlayer();

  final AudioPlayer _player;
  bool _configured = false;

  @override
  Future<void> open(String path) async {
    if (!_configured) {
      // Keep the source after completion so chips can replay without
      // re-opening the file.
      await _player.setReleaseMode(ReleaseMode.stop);
      _configured = true;
    }
    await _player.setSource(DeviceFileSource(path, mimeType: 'audio/wav'));
  }

  @override
  Future<void> seek(int positionMs) =>
      _player.seek(Duration(milliseconds: positionMs < 0 ? 0 : positionMs));

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> setRate(double rate) => _player.setPlaybackRate(rate);

  @override
  Future<int?> durationMs() async =>
      (await _player.getDuration())?.inMilliseconds;

  @override
  Stream<int> get positionMs =>
      _player.onPositionChanged.map((d) => d.inMilliseconds);

  @override
  Stream<int> get durationChanges =>
      _player.onDurationChanged.map((d) => d.inMilliseconds);

  @override
  Stream<void> get completed => _player.onPlayerComplete;

  @override
  Future<void> dispose() => _player.dispose();
}

/// Creates the evidence player. Overridden in tests.
final evidencePlayerFactoryProvider = Provider<EvidenceAudioPlayer Function()>(
  (ref) => AudioplayersEvidencePlayer.new,
);
