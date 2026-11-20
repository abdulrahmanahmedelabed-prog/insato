// Phone-call mode (وضع المكالمة الهاتفية): transcribe a regular cellular
// call live, with a remote group gathered around one phone on speaker.
//
// Wiring (see docs/ARCHITECTURE.md, "Phone-call mode"):
// * `sessionAudioSourceProvider` → [phoneCallAwareSource] (Phone Link /
//   speakerphone source while a call is armed).
// * `MeetingSessionController.start` → [phoneCallSessionPlanProvider]
//   (telephone VAD, language hint, voiceprint thresholds per call side).
// * `postProcessorProvider` → [PhoneCallLogStore] (partitions, telephone
//   voiceprint tags, minutes hint).
// * UI: [PhoneCallMenuButton] (meetings app bar), [PhoneCallRecordingCard]
//   (recording screen), [PhoneCallMeetingCard] (minutes tab).

export 'call_session_audio.dart';
export 'channel_attribution.dart';
export 'phone_call_check.dart';
export 'phone_call_guide.dart';
export 'phone_call_log.dart';
export 'phone_call_models.dart';
export 'phone_call_providers.dart';
export 'phone_call_setup_screen.dart';
export 'phone_call_widgets.dart';
export 'phone_link_source.dart';
export 'speakerphone_source.dart';
export 'strings.dart';
export 'telephone_profile.dart';
