// F13 — Windows system-audio capture (تسجيل صوت Zoom/Teams).
//
// Wiring (integrator):
// * Session capture: point `sessionAudioSourceProvider`
//   (lib/session/providers.dart) at [mixedSessionAudioSourceProvider], e.g.
//   `sessionAudioSourceProvider.overrideWith(
//      (ref) => ref.watch(mixedSessionAudioSourceProvider))` in the root
//   ProviderScope, or make the provider body return it. Off Windows it is
//   the F18 device-aware microphone source itself.
// * Settings → audio section: `AudioSourceSelector()`; recording screen
//   (before a take): `AudioSourceSelector(compact: true)`. Both render
//   nothing outside Windows.
// * Native side: windows/runner/system_audio_channel.cpp, registered by
//   FlutterWindow::OnCreate.

export 'audio_source_selector.dart';
export 'mixed_session_audio_source.dart';
export 'strings.dart';
export 'system_audio_dsp.dart';
export 'system_audio_source.dart';
