// User flows shared by several screens: starting a meeting (consent first),
// speaker corrections (rename, merge, forget voice, delete) and meeting
// deletion / renaming. Every flow reports success or the Arabic error in a
// snack bar and never throws.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/errors.dart';
import '../core/models.dart';
import '../session/providers.dart';
import 'navigation.dart';
import 'strings_ar.dart';
import 'widgets/common.dart';
import 'widgets/dialogs.dart';

String _messageOf(Object e) =>
    e is KatibException ? e.messageAr : S.unexpectedError;

/// Starts a new meeting: shows the consent reminder on first use (the
/// recording only starts once accepted), starts the session and opens the
/// recording screen, which shows preparation progress and any start error.
/// While a session is already running, just reopens the recording screen.
Future<void> startNewMeeting(BuildContext context, WidgetRef ref) async {
  final session = ref.read(meetingSessionControllerProvider);
  if (session.isActive) {
    await openRecordingScreen(context);
    return;
  }
  var consentGiven = false;
  try {
    final settings = await ref.read(appSettingsProvider).load();
    consentGiven = settings.consentAcknowledged;
  } catch (_) {
    consentGiven = false;
  }
  if (!consentGiven) {
    if (!context.mounted) return;
    consentGiven = await showConsentDialog(context);
    if (!consentGiven) return;
  }
  if (!context.mounted) return;
  final controller = ref.read(meetingSessionControllerProvider.notifier);
  // The controller switches to `preparing` synchronously; the recording
  // screen shows its progress and, on failure, the Arabic error.
  unawaited(
    controller.start(consentGiven: true).then<void>((_) {}, onError: (_) {}),
  );
  await openRecordingScreen(context);
}

/// Renames [speaker] (remembered for future meetings).
Future<void> renameSpeakerFlow(
  BuildContext context,
  WidgetRef ref,
  Speaker speaker,
) async {
  final name = await showTextInputDialog(
    context,
    title: S.renameSpeakerTitle,
    body: S.renameSpeakerBody,
    initialValue: speaker.isNamedByUser ? speaker.name : '',
    label: S.speakerNameLabel,
    hint: S.speakerNameHint,
  );
  if (name == null || name == speaker.name) return;
  try {
    await ref.read(postProcessorProvider).renameSpeaker(speaker.id, name);
    if (context.mounted) showSnack(context, S.speakerRenamed);
  } catch (e) {
    if (context.mounted) showSnack(context, _messageOf(e), error: true);
  }
}

/// Merges [speaker] into another speaker chosen by the user.
Future<void> mergeSpeakerFlow(
  BuildContext context,
  WidgetRef ref,
  Speaker speaker,
) async {
  List<Speaker> candidates;
  try {
    candidates = (await ref.read(speakerRepositoryProvider).getAll())
        .where((s) => s.id != speaker.id)
        .toList();
  } catch (e) {
    if (context.mounted) showSnack(context, _messageOf(e), error: true);
    return;
  }
  if (!context.mounted) return;
  // Named people first: they are the usual merge targets.
  candidates.sort((a, b) {
    if (a.isNamedByUser != b.isNamedByUser) return a.isNamedByUser ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  final target = await showSpeakerPicker(
    context,
    title: S.mergeTitle(speaker.name),
    body: S.mergeBody,
    speakers: candidates,
  );
  if (target == null || !context.mounted) return;
  final ok = await showConfirmDialog(
    context,
    title: S.merge,
    body: S.mergeConfirm(speaker.name, target.name),
    confirmLabel: S.confirm,
    icon: Icons.merge_rounded,
  );
  if (!ok) return;
  try {
    await ref.read(postProcessorProvider).mergeSpeakers(speaker.id, target.id);
    if (context.mounted) showSnack(context, S.speakersMerged);
  } catch (e) {
    if (context.mounted) showSnack(context, _messageOf(e), error: true);
  }
}

/// Forgets [speaker]'s voiceprint ("this is not the same person").
Future<void> forgetVoiceFlow(
  BuildContext context,
  WidgetRef ref,
  Speaker speaker,
) async {
  final ok = await showConfirmDialog(
    context,
    title: S.forgetVoiceTitle,
    body: S.forgetVoiceBody(speaker.name),
    confirmLabel: S.forget,
    icon: Icons.voice_over_off_rounded,
  );
  if (!ok) return;
  try {
    await ref.read(speakerRepositoryProvider).forgetVoice(speaker.id);
    if (context.mounted) showSnack(context, S.voiceForgotten);
  } catch (e) {
    if (context.mounted) showSnack(context, _messageOf(e), error: true);
  }
}

/// Deletes [speaker] and its voiceprint (segments become unassigned).
Future<void> deleteSpeakerFlow(
  BuildContext context,
  WidgetRef ref,
  Speaker speaker,
) async {
  final ok = await showConfirmDialog(
    context,
    title: S.deleteSpeakerTitle,
    body: S.deleteSpeakerBody(speaker.name),
    confirmLabel: S.delete,
    destructive: true,
    icon: Icons.delete_outline_rounded,
  );
  if (!ok) return;
  try {
    await ref.read(speakerRepositoryProvider).delete(speaker.id);
    if (context.mounted) showSnack(context, S.speakerDeleted);
  } catch (e) {
    if (context.mounted) showSnack(context, _messageOf(e), error: true);
  }
}

/// Asks for confirmation and deletes [meeting]. Returns true when deleted.
Future<bool> deleteMeetingFlow(
  BuildContext context,
  WidgetRef ref,
  Meeting meeting,
) async {
  final ok = await showConfirmDialog(
    context,
    title: S.deleteMeetingTitle,
    body: S.deleteMeetingBody(meeting.title),
    confirmLabel: S.delete,
    destructive: true,
    icon: Icons.delete_outline_rounded,
  );
  if (!ok) return false;
  try {
    await ref.read(postProcessorProvider).deleteMeeting(meeting.id);
    if (ref.read(selectedMeetingProvider) == meeting.id) {
      ref.read(selectedMeetingProvider.notifier).select(null);
    }
    if (context.mounted) showSnack(context, S.meetingDeleted);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, _messageOf(e), error: true);
    return false;
  }
}

/// Lets the user edit [meeting]'s title.
Future<void> renameMeetingFlow(
  BuildContext context,
  WidgetRef ref,
  Meeting meeting,
) async {
  final title = await showTextInputDialog(
    context,
    title: S.renameMeeting,
    initialValue: meeting.title,
    label: S.meetingTitleLabel,
  );
  if (title == null || title == meeting.title) return;
  try {
    await ref.read(meetingRepositoryProvider).updateTitle(meeting.id, title);
  } catch (e) {
    if (context.mounted) showSnack(context, _messageOf(e), error: true);
  }
}
