// Live call: native configuration and the short-segment VAD profile.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/live_call/call_transcriber.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/speech/vad_segmenter.dart';

void main() {
  test('Android: call foreground service types and permissions', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final p in [
      'FOREGROUND_SERVICE_MICROPHONE',
      'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'RECORD_AUDIO',
      'INTERNET',
      'POST_NOTIFICATIONS',
      'MODIFY_AUDIO_SETTINGS',
      'CHANGE_NETWORK_STATE',
    ]) {
      expect(
        m,
        contains('<uses-permission android:name="android.permission.$p" />'),
        reason: p,
      );
    }
    expect(m, contains('android:foregroundServiceType="microphone|mediaPlayback"'));
    // The call ends with the task: no hidden background streaming.
    expect(m, contains('android:stopWithTask="true"'));
  });

  test('iOS: microphone text mentions the live call; background audio', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('المكالمة الحية'));
    expect(plist, contains('<string>audio</string>'));
    // No VoIP push / CallKit background mode: a call never starts by itself.
    expect(plist, isNot(contains('<string>voip</string>')));
  });

  test('the reference relay and its deploy files ship with the repo', () {
    for (final f in [
      'tools/signaling_server.dart',
      'tools/signaling/worker.js',
      'tools/signaling/wrangler.toml',
      'tools/signaling/Dockerfile',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    // The relay must stay self-contained (deployable without Flutter).
    final src = File('tools/signaling_server.dart').readAsStringSync();
    expect(
      RegExp(r"^import '(?!dart:)", multiLine: true).hasMatch(src),
      isFalse,
    );
  });

  test('call segments are capped for near-real-time text', () {
    const base = VadSegmenterConfig();
    final c = cappedVadConfig(base, kCallMaxSegmentSeconds);
    expect(c.maxSpeechDuration, kCallMaxSegmentSeconds);
    expect(c.maxSegmentSeconds, kCallMaxSegmentSeconds + 1);
    expect(c.threshold, base.threshold);
    expect(c.minSilenceDuration, base.minSilenceDuration);
    expect(identical(cappedVadConfig(base, null), base), isTrue);
    const request = SessionEngineRequest(
      asrEngine: 'local',
      whisperModelId: 'w',
      maxSegmentSeconds: 7,
    );
    expect(request.maxSegmentSeconds, 7);
  });
}
