// Live Insato call (v1.2): platform integration while streaming.
//
// * Android: a foreground service (types microphone + mediaPlayback) with
//   the ongoing notification «يتم البث والتفريغ» and a «إيقاف البث» button
//   that ends the call in one tap (the button press reaches the UI isolate
//   through flutter_foreground_task's communication port). The service
//   stops with the task: swiping the app away ends the call.
// * iOS: no CallKit; the in-app call screen and its indicator are the UI.
//   Background audio (UIBackgroundModes audio) keeps the call running with
//   the screen locked; when the app is killed the process — and with it
//   the microphone, WebRTC and the call — ends.
// * All platforms: wakelock while streaming.

import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart' as fft;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../audio/audio_capture_service.dart' show CapturePlatform;
import '../../session/meeting_session_controller.dart'
    show DefaultSessionPlatformHooks, SessionAudioSource;
import 'strings.dart';

/// Data the notification button sends to the UI isolate.
const String kStopCallCommand = 'insato.stop_call';

/// Entry point of the foreground task (Android).
@pragma('vm:entry-point')
void insatoLiveCallTaskCallback() {
  fft.FlutterForegroundTask.setTaskHandler(_LiveCallTaskHandler());
}

class _LiveCallTaskHandler extends fft.TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, fft.TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') fft.FlutterForegroundTask.sendDataToMain(kStopCallCommand);
  }

  @override
  void onNotificationPressed() => fft.FlutterForegroundTask.launchApp();
}

/// What the call needs from the platform.
abstract class CallPlatformHooks {
  /// Throws an [AudioCaptureException]-style InsatoException when the
  /// microphone is not allowed.
  Future<void> ensureMicrophonePermission(SessionAudioSource audio);

  /// Streaming started: show the ongoing notification; [onStopRequested]
  /// runs when its stop button is pressed. Returns a warning, or null.
  Future<String?> onStreamingStarted({
    required String peerName,
    required void Function() onStopRequested,
  });

  /// Streaming stopped: remove the notification, release the wakelock.
  Future<void> onStreamingStopped();
}

/// Production hooks.
class DefaultCallPlatformHooks implements CallPlatformHooks {
  /// Creates the hooks.
  DefaultCallPlatformHooks({CapturePlatform? platform})
    : platform = platform ?? CapturePlatform.current;

  /// Target platform.
  final CapturePlatform platform;

  bool _service = false;
  void Function(Object)? _callback;

  @override
  Future<void> ensureMicrophonePermission(SessionAudioSource audio) =>
      DefaultSessionPlatformHooks(
        platform: platform,
      ).ensureMicrophonePermission(audio);

  @override
  Future<String?> onStreamingStarted({
    required String peerName,
    required void Function() onStopRequested,
  }) async {
    String? warning;
    if (platform == CapturePlatform.android) {
      warning = await _startService(peerName, onStopRequested);
    }
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    return warning;
  }

  Future<String?> _startService(
    String peerName,
    void Function() onStopRequested,
  ) async {
    try {
      if (await fft.FlutterForegroundTask.checkNotificationPermission() !=
          fft.NotificationPermission.granted) {
        await fft.FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {}
    fft.FlutterForegroundTask.initCommunicationPort();
    final cb = _callback = (Object data) {
      if (data == kStopCallCommand) onStopRequested();
    };
    fft.FlutterForegroundTask.addTaskDataCallback(cb);
    fft.FlutterForegroundTask.init(
      androidNotificationOptions: fft.AndroidNotificationOptions(
        channelId: 'insato_live_call',
        channelName: LCS.notificationChannel,
        channelDescription: LCS.notificationChannelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const fft.IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: fft.ForegroundTaskOptions(
        eventAction: fft.ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowAutoRestart: false,
        stopWithTask: true,
      ),
    );
    final result = await fft.FlutterForegroundTask.startService(
      serviceId: 4712,
      serviceTypes: const [
        fft.ForegroundServiceTypes.microphone,
        fft.ForegroundServiceTypes.mediaPlayback,
      ],
      notificationTitle: LCS.notificationTitle,
      notificationText: LCS.notificationText(peerName),
      notificationButtons: const [
        fft.NotificationButton(id: 'stop', text: LCS.notificationStop),
      ],
      callback: insatoLiveCallTaskCallback,
    );
    switch (result) {
      case fft.ServiceRequestSuccess():
        _service = true;
        return null;
      case fft.ServiceRequestFailure():
        return LCS.backgroundWarning;
    }
  }

  @override
  Future<void> onStreamingStopped() async {
    final cb = _callback;
    _callback = null;
    if (cb != null) fft.FlutterForegroundTask.removeTaskDataCallback(cb);
    if (_service) {
      _service = false;
      try {
        await fft.FlutterForegroundTask.stopService();
      } catch (_) {}
    }
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}

/// Platform hooks of calls.
final callPlatformHooksProvider = Provider<CallPlatformHooks>(
  (ref) => DefaultCallPlatformHooks(),
);
