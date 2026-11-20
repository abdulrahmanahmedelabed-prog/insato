// Meeting bot (Windows): joins a Google Meet, Microsoft Teams, Zoom or Webex
// meeting as a clearly named guest, waits to be admitted, records its audio
// through the normal Insato pipeline and leaves when the meeting ends.
//
// Wiring (minimal, outside this folder):
// * lib/session/providers.dart: `sessionAudioSourceProvider` wraps its
//   source with [meetingBotAwareSource] (system-only take over the bot
//   capture while a bot records).
// * lib/ui/screens/meetings_screen.dart: [MeetingBotButton] in the app bar.
// * lib/features/context/meeting_context_page.dart: [MeetingBotEntryTile]
//   in the audio section of the new-meeting form (Windows only).
// * windows/runner/bot_audio_*: process-loopback capture
//   (`insato/meeting_bot_audio`), registered by FlutterWindow::OnCreate.
//
// Join flows (selectors, texts) live in bot_scripts.dart, versioned.

export 'bot_audio.dart';
export 'bot_providers.dart';
export 'bot_runner.dart';
export 'bot_scripts.dart';
export 'browser_driver.dart';
export 'cdp.dart';
export 'meeting_bot_screen.dart';
export 'meeting_link.dart';
export 'strings.dart';
