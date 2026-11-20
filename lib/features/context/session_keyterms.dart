// The custom vocabulary of a recording session (F2 → cloud-ASR vocabulary),
// including the context entered for the meeting about to start (F3), whose
// id does not exist yet when the speech engines are created.
//
// Depends only on the data layer, so lib/session/providers.dart can import
// it without a cycle.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../data/repositories_v11.dart';
import 'context_logic.dart';
import 'glossary_logic.dart';

/// Holds the [MeetingSetup] of the meeting being started, between the
/// context sheet and the creation of its speech engines (null otherwise).
class UpcomingMeetingSetupNotifier extends Notifier<MeetingSetup?> {
  @override
  MeetingSetup? build() => null;

  /// Sets (or with null clears) the upcoming meeting's setup.
  void set(MeetingSetup? setup) => state = setup;
}

/// The setup of the meeting being started; read by the session's keyterm
/// resolver.
final upcomingMeetingSetupProvider =
    NotifierProvider<UpcomingMeetingSetupNotifier, MeetingSetup?>(
      UpcomingMeetingSetupNotifier.new,
    );

/// Resolves the cloud-ASR vocabulary of a session: the [upcoming] meeting's
/// terms and expected attendees, the names of user-named speakers and the
/// global glossary ([buildCloudAsrKeyterms] priority and limit).
Future<List<String>> resolveSessionKeyterms({
  required GlossaryRepository glossary,
  required SpeakerRepository speakers,
  MeetingSetup? upcoming,
}) async {
  final setup = upcoming?.normalized();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  return buildCloudAsrKeyterms(
    meetingTerms: [
      for (final d in setup?.meetingTerms ?? const <GlossaryDraft>[])
        draftAsTerm(d, createdAt: epoch),
    ],
    expectedAttendees: setup?.context.expectedAttendees ?? const [],
    speakers: await speakers.getAll(),
    globalTerms: await glossary.getGlobal(),
  );
}
