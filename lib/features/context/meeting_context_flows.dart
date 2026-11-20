// User flows of the meeting context (F3): starting a new meeting through the
// context form, and editing the context of an existing meeting. Like
// lib/ui/actions.dart, every flow reports the outcome in a snack bar and
// never throws.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import '../../ui/navigation.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import '../multi_device/multi_device_providers.dart'
    show guestSessionControllerProvider;
import '../multi_device/strings.dart' show MS;
import '../official/official_service.dart'
    show officialMinutesServiceProvider;
import 'context_logic.dart';
import 'meeting_context_page.dart';
import 'meeting_context_service.dart';
import 'strings.dart';

/// "اجتماع جديد" with the optional context form: while a session is running
/// it just reopens the recording screen; otherwise it shows the consent
/// reminder on first use, then the context form, starts the session with
/// the entered setup and opens the recording screen (which shows the
/// preparation progress and any start error). Closing the form cancels.
Future<void> startNewMeetingWithContext(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref.read(meetingSessionControllerProvider).isActive) {
    await openRecordingScreen(context);
    return;
  }
  // v1.2 C: the microphone is busy streaming to another meeting's host.
  if (ref.read(guestSessionControllerProvider).isActive) {
    showSnack(context, MS.busyGuest, error: true);
    return;
  }
  var consentGiven = false;
  try {
    consentGiven =
        (await ref.read(appSettingsProvider).load()).consentAcknowledged;
  } catch (_) {
    consentGiven = false;
  }
  if (!consentGiven) {
    if (!context.mounted) return;
    consentGiven = await showConsentDialog(context);
    if (!consentGiven) return;
  }
  if (!context.mounted) return;
  final setup = await showMeetingContextPage(context);
  if (setup == null || !context.mounted) return;
  // A session may have been started elsewhere (e.g. a keyboard shortcut)
  // while the form was open.
  if (ref.read(meetingSessionControllerProvider).isActive) {
    await openRecordingScreen(context);
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  // The controller switches to `preparing` synchronously; the recording
  // screen shows its progress and, on failure, the Arabic error.
  unawaited(
    ref.read(meetingContextServiceProvider).startWithSetup(setup).then<void>((
      r,
    ) {
      if (!r.termsSaved && messenger != null) {
        showSnackOn(messenger, scheme, CS.meetingTermsSaveFailed, error: true);
      }
    }, onError: (_) {}),
  );
  await openRecordingScreen(context);
}

/// Lets the user edit [meeting]'s title, agenda, expected attendees, notes
/// and meeting-only terms. Returns true when something was saved.
Future<bool> editMeetingContextFlow(
  BuildContext context,
  WidgetRef ref,
  Meeting meeting,
) async {
  final service = ref.read(meetingContextServiceProvider);
  final MeetingSetup initial;
  try {
    initial = await service.loadSetup(meeting);
  } catch (_) {
    if (context.mounted) {
      showSnack(context, CS.contextSaveFailed, error: true);
    }
    return false;
  }
  if (!context.mounted) return false;
  final setup = await showMeetingContextPage(
    context,
    initial: initial,
    mode: MeetingContextMode.edit,
  );
  if (setup == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  void report(String message, {bool error = false}) {
    if (messenger != null) {
      showSnackOn(messenger, scheme, message, error: error);
    }
  }

  try {
    final current = await ref.read(meetingRepositoryProvider).get(meeting.id);
    if (current == null) {
      report(CS.meetingMissing, error: true);
      return false;
    }
    await service.save(current, setup);
    // v1.2: a different template changes approved official minutes, which
    // then continue as a new draft version.
    try {
      await ref.read(officialMinutesServiceProvider).onMinutesChanged(
        meeting.id,
      );
    } catch (_) {
      // Best effort; the official screen shows a changed hash too.
    }
    report(CS.contextSaved);
    return true;
  } catch (_) {
    report(CS.contextSaveFailed, error: true);
    return false;
  }
}
