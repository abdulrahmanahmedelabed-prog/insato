// Audio of the meeting bot.
//
// Preferred: Windows process-loopback capture of the bot browser's process
// tree only (Windows 10 version 2004, build 19041, or later;
// windows/runner/bot_audio_channel.cpp). The native side sends the same
// events as the F13 system-audio channel, so [SystemAudioSource] converts
// them to 16 kHz mono unchanged.
//
// Fallback: the whole system output (F13 WASAPI loopback) with a clear
// warning — everything the computer plays is recorded, including the
// user's own meeting client if it is open.
//
// While a bot records, `sessionAudioSourceProvider` wraps the normal source
// in a system-only [MixedSessionAudioSource] over one of these captures
// ([meetingBotAwareSource]): no microphone is used, silent gaps are kept by
// wall clock and the take is archived like any other.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_capture_service.dart' show CapturePlatform;
import '../../data/secure_settings.dart' show AppSettingsData;
import '../../session/meeting_session_controller.dart' show SessionAudioSource;
import '../system_audio/mixed_session_audio_source.dart'
    show MixedSessionAudioSource, systemAudioPlatformProvider;
import '../system_audio/system_audio_source.dart';

/// How the bot's audio is captured.
enum BotCaptureMode {
  /// Only the bot browser's processes (Windows 10 2004+).
  processLoopback,

  /// Everything the computer plays (fallback).
  systemLoopback,
}

/// Capture mode for the given support, or null when neither works.
BotCaptureMode? chooseBotCaptureMode({
  required bool processSupported,
  required bool systemSupported,
  required bool havePid,
}) {
  if (processSupported && havePid) return BotCaptureMode.processLoopback;
  if (systemSupported) return BotCaptureMode.systemLoopback;
  return null;
}

/// [SystemAudioPlatform] capturing one process tree (the bot browser).
class ProcessLoopbackAudioPlatform implements SystemAudioPlatform {
  /// Creates the client for process [pid]; channels injectable for tests.
  ProcessLoopbackAudioPlatform(
    this.pid, {
    MethodChannel? control,
    EventChannel? events,
  }) : _control = control ?? const MethodChannel(controlChannelName),
       _events = events ?? const EventChannel(eventChannelName);

  /// MethodChannel: isSupported -> bool, start({pid}) -> bool, stop.
  static const String controlChannelName = 'insato/meeting_bot_audio/control';

  /// EventChannel: same events as `insato/system_audio`.
  static const String eventChannelName = 'insato/meeting_bot_audio';

  /// Captured process (its children included).
  final int pid;

  final MethodChannel _control;
  final EventChannel _events;

  /// Whether process-loopback capture exists on this computer.
  static Future<bool> supported({MethodChannel? control}) async {
    final c = control ?? const MethodChannel(controlChannelName);
    try {
      return await c.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<SystemAudioEvent> get events => _events
      .receiveBroadcastStream()
      .map(parseSystemAudioEvent)
      .where((e) => e != null)
      .cast<SystemAudioEvent>();

  @override
  Future<bool> isSupported() => supported(control: _control);

  @override
  Future<bool> start() async {
    try {
      return await _control.invokeMethod<bool>('start', {'pid': pid}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _control.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Nothing to stop.
    } on PlatformException {
      // Cancelling the event stream stops the native side too.
    }
  }
}

/// What the session records while a bot is in a meeting.
class BotCaptureTarget {
  /// Creates a target.
  const BotCaptureTarget({required this.mode, this.pid});

  /// Capture mode.
  final BotCaptureMode mode;

  /// Bot browser process (process loopback).
  final int? pid;
}

/// Holds the bot capture in effect.
class BotCaptureHolder extends Notifier<BotCaptureTarget?> {
  @override
  BotCaptureTarget? build() => null;

  /// Replaces the target.
  void set(BotCaptureTarget? target) => state = target;
}

/// The bot capture in effect (null when no bot records). Kept apart from
/// the bot controller so the session source can depend on it without a
/// dependency cycle.
final botCaptureTargetProvider =
    NotifierProvider<BotCaptureHolder, BotCaptureTarget?>(BotCaptureHolder.new);

/// Sets / clears the bot capture (used by the bot's recorder).
void setBotCaptureTarget(Ref ref, BotCaptureTarget? target) =>
    ref.read(botCaptureTargetProvider.notifier).set(target);

/// Creates the process-loopback platform for a pid (overridable in tests).
final botProcessAudioPlatformFactoryProvider =
    Provider<SystemAudioPlatform Function(int pid)>(
      (ref) => ProcessLoopbackAudioPlatform.new,
    );

/// Whether process-loopback capture is available (overridable in tests).
final botProcessLoopbackSupportedProvider = Provider<Future<bool> Function()>(
  (ref) => ProcessLoopbackAudioPlatform.supported,
);

/// Wraps [base] while a bot records (used by `sessionAudioSourceProvider`):
/// a system-only take over the bot's capture. Otherwise returns [base].
SessionAudioSource meetingBotAwareSource(Ref ref, SessionAudioSource base) {
  final target = ref.watch(botCaptureTargetProvider);
  if (target == null) return base;
  final pid = target.pid;
  final SystemAudioPlatform platform =
      target.mode == BotCaptureMode.processLoopback && pid != null
      ? ref.watch(botProcessAudioPlatformFactoryProvider)(pid)
      : ref.watch(systemAudioPlatformProvider);
  final system = SystemAudioSource(platform: platform);
  final source = MixedSessionAudioSource(
    mic: base,
    system: system,
    loadAudioSource: () async => AppSettingsData.audioSourceSystem,
    platform: CapturePlatform.windows,
  );
  ref.onDispose(() async {
    await source.dispose();
    await system.dispose();
  });
  return source;
}
