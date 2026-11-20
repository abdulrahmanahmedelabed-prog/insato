// Persistence of the meeting context (F3) and meeting-only glossary terms:
// loading a meeting's setup for editing, saving edits, and starting a
// recording with a setup entered on the "new meeting" sheet.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import 'context_logic.dart';
import 'glossary_logic.dart';
import 'session_keyterms.dart';

/// Outcome of [MeetingContextService.startWithSetup].
class StartWithSetupResult {
  /// Creates a result.
  const StartWithSetupResult({
    required this.meetingId,
    required this.termsSaved,
  });

  /// The new meeting.
  final String meetingId;

  /// False when the meeting-only terms could not be stored (the recording
  /// runs regardless).
  final bool termsSaved;
}

/// Applies [plan] to [meetingId]'s terms: deletions first (so a renamed term
/// never collides with one being removed), then updates, then additions.
Future<void> applyMeetingTermSync(
  GlossaryRepository repo,
  String meetingId,
  MeetingTermSyncPlan plan,
) async {
  for (final id in plan.delete) {
    await repo.delete(id);
  }
  for (final t in plan.update) {
    await repo.update(t);
  }
  for (final d in plan.add) {
    await repo.add(
      term: d.term,
      arSpelling: d.arSpelling,
      category: d.category,
      meetingId: meetingId,
    );
  }
}

/// Loads and stores meeting contexts.
class MeetingContextService {
  /// Creates the service.
  MeetingContextService(this._ref);

  final Ref _ref;

  GlossaryRepository get _glossary => _ref.read(glossaryRepositoryProvider);

  /// The current setup of [meeting] (title, context, meeting-only terms).
  Future<MeetingSetup> loadSetup(Meeting meeting) async => MeetingSetup(
    title: meeting.title,
    context: meeting.context,
    meetingTerms: [
      for (final t in await _glossary.getForMeeting(meeting.id))
        GlossaryDraft.of(t),
    ],
  );

  /// Makes [meetingId]'s stored terms equal [desired].
  Future<void> syncMeetingTerms(
    String meetingId,
    List<GlossaryDraft> desired,
  ) async {
    final existing = await _glossary.getForMeeting(meetingId);
    await applyMeetingTermSync(
      _glossary,
      meetingId,
      planMeetingTermSync(existing, desired),
    );
  }

  /// Stores an edited [setup] of [meeting]: context, title (through the
  /// session controller, so a meeting being recorded updates its live title
  /// too) and meeting-only terms. Throws when the meeting no longer exists.
  Future<void> save(Meeting meeting, MeetingSetup setup) async {
    final s = setup.normalized();
    final ok = await _ref
        .read(meetingRepositoryProvider)
        .updateContext(meeting.id, s.context);
    if (!ok) throw StateError('meeting ${meeting.id} not found');
    final title = s.trimmedTitle;
    if (title != null && title != meeting.title) {
      await _ref
          .read(meetingSessionControllerProvider.notifier)
          .renameMeeting(meeting.id, title);
    }
    await syncMeetingTerms(meeting.id, s.meetingTerms);
  }

  /// Starts a recording with [setup] (the caller has obtained the consent
  /// [consentGiven]). While the speech engines are created, the setup is
  /// published in [upcomingMeetingSetupProvider] so its terms and attendees
  /// reach the cloud ASR keyterms. Rethrows the controller's start error.
  Future<StartWithSetupResult> startWithSetup(
    MeetingSetup setup, {
    bool consentGiven = true,
    String? inputDevice,
  }) async {
    final s = setup.normalized();
    final upcoming = _ref.read(upcomingMeetingSetupProvider.notifier);
    upcoming.set(s);
    final String meetingId;
    try {
      meetingId = await _ref
          .read(meetingSessionControllerProvider.notifier)
          .start(
            title: s.trimmedTitle,
            consentGiven: consentGiven,
            context: s.context,
            inputDevice: inputDevice,
          );
    } finally {
      upcoming.set(null);
    }
    if (s.meetingTerms.isEmpty) {
      return StartWithSetupResult(meetingId: meetingId, termsSaved: true);
    }
    try {
      await syncMeetingTerms(meetingId, s.meetingTerms);
      return StartWithSetupResult(meetingId: meetingId, termsSaved: true);
    } catch (_) {
      return StartWithSetupResult(meetingId: meetingId, termsSaved: false);
    }
  }
}

/// The [MeetingContextService].
final meetingContextServiceProvider = Provider<MeetingContextService>(
  MeetingContextService.new,
);
