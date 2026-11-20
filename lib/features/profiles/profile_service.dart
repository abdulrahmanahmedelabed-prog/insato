// Database side of speaker profiles (F16): rebuild a profile from every
// meeting, update profiles incrementally after a meeting's minutes are
// saved, enable / disable the opt-in and delete a profile with its notes.
//
// Only speakers with `Speaker.profileEnabled` ever get a profile.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../data/minutes_artifacts.dart'
    show SpeakerNameResolver, speakerNameKey;
import '../../data/repositories.dart'
    show MeetingRepository, SegmentRepository, SpeakerRepository;
import '../../data/secure_settings.dart';
import '../../session/providers.dart';
import 'profile_aggregation.dart';
import 'profile_model.dart';
import 'profile_stats.dart';

/// Decisions of [minutes] whose `proposed_by` resolves to [speakerId].
List<ProfileDecision> decisionsProposedBy(
  Minutes? minutes,
  String speakerId,
  SpeakerNameResolver names,
) => [
  if (minutes != null)
    for (final d in minutes.decisions)
      if (d.text.trim().isNotEmpty && names.id(d.proposedBy) == speakerId)
        ProfileDecision(text: d.text.trim(), evidence: d.evidence),
];

/// Builds, updates and deletes speaker profiles.
class SpeakerProfileService {
  /// Creates the service over the repositories.
  SpeakerProfileService({
    required this._meetings,
    required this._segments,
    required this._speakers,
    required this._tasks,
    required this._profiles,
    required this._notes,
    this._settings,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MeetingRepository _meetings;
  final SegmentRepository _segments;
  final SpeakerRepository _speakers;
  final TaskRepository _tasks;
  final SpeakerProfileRepository _profiles;
  final SpeakerMeetingNotesRepository _notes;
  final AppSettings? _settings;
  final DateTime Function() _clock;

  /// Serialises every write so a rebuild and an incremental update never
  /// interleave.
  Future<void> _queue = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Recomputes the profile of [speakerId] from every meeting and stores
  /// it. Returns null (and stores nothing) when the speaker does not exist
  /// or has not opted in.
  Future<SpeakerProfile?> rebuild(String speakerId) =>
      _serial(() => _rebuild(speakerId));

  Future<SpeakerProfile?> _rebuild(String speakerId) async {
    final speaker = await _speakers.get(speakerId);
    if (speaker == null || !speaker.profileEnabled) return null;
    final meetings = await _meetings.getAll();
    final all = await _speakers.getAllById();
    final perMeeting = <MeetingSpeakerStats>[];
    for (final m in meetings) {
      final segments = await _segments.getForMeeting(m.id);
      // Names resolve among the meeting's own speakers first.
      final names = SpeakerNameResolver.scoped(all, {
        for (final s in segments) ?s.speakerId,
      });
      final stats = computeMeetingSpeakerStats(
        meeting: m,
        segments: segments,
        speakerId: speakerId,
        decisions: decisionsProposedBy(m.minutes, speakerId, names),
      );
      if (stats != null) perMeeting.add(stats);
    }
    return _store(speaker, perMeeting, {for (final m in meetings) m.id: m});
  }

  Future<SpeakerProfile> _store(
    Speaker speaker,
    List<MeetingSpeakerStats> perMeeting,
    Map<String, Meeting> meetingsById,
  ) async {
    final owned = [
      for (final t in await _tasks.getAll())
        if (t.ownerSpeakerId == speaker.id) t,
    ];
    final now = _clock();
    final profile = aggregateSpeakerProfile(
      speakerName: speaker.name,
      perMeeting: perMeeting,
      notes: await _notes.getForSpeaker(speaker.id),
      tasks: owned,
      meetingsById: meetingsById,
      builtAt: now,
    );
    await _profiles.upsert(
      SpeakerProfileRecord(
        speakerId: speaker.id,
        profile: profile.toJson(),
        evidence: profile.evidence,
        updatedAt: now,
      ),
    );
    return profile;
  }

  /// Updates the profiles touched by [meetingId] after its minutes were
  /// saved: every opted-in speaker who speaks in the meeting, has notes for
  /// it, or whose stored profile already covers it. Only that meeting's
  /// statistics are recomputed; a speaker without a stored profile (or with
  /// one of an older shape) is rebuilt from all meetings. Returns the ids of
  /// the speakers whose profile was written.
  Future<List<String>> updateAfterMeeting(String meetingId) =>
      _serial(() => _updateAfterMeeting(meetingId));

  Future<List<String>> _updateAfterMeeting(String meetingId) async {
    final enabled = [
      for (final s in await _speakers.getAll())
        if (s.profileEnabled) s,
    ];
    if (enabled.isEmpty) return const [];
    final meeting = await _meetings.get(meetingId);
    final segments = meeting == null
        ? const <TranscriptSegment>[]
        : await _segments.getForMeeting(meetingId);
    final noted = {
      for (final n in await _notes.getForMeeting(meetingId)) n.speakerId,
    };
    final spoke = {for (final s in segments) ?s.speakerId};
    final names = SpeakerNameResolver.scoped(
      await _speakers.getAllById(),
      spoke,
    );
    Map<String, Meeting>? meetingsById;
    final updated = <String>[];
    for (final speaker in enabled) {
      final record = await _profiles.get(speaker.id);
      final stored = SpeakerProfile.tryParse(record?.profile);
      final covers =
          stored?.perMeeting.any((m) => m.meetingId == meetingId) ?? false;
      if (!spoke.contains(speaker.id) &&
          !noted.contains(speaker.id) &&
          !covers) {
        continue;
      }
      if (stored == null) {
        if (await _rebuild(speaker.id) != null) updated.add(speaker.id);
        continue;
      }
      meetingsById ??= {for (final m in await _meetings.getAll()) m.id: m};
      final fresh = meeting == null
          ? null
          : computeMeetingSpeakerStats(
              meeting: meeting,
              segments: segments,
              speakerId: speaker.id,
              decisions: decisionsProposedBy(
                meeting.minutes,
                speaker.id,
                names,
              ),
            );
      final perMeeting = [
        for (final m in stored.perMeeting)
          if (m.meetingId != meetingId) m,
        ?fresh,
      ];
      await _store(speaker, perMeeting, meetingsById);
      updated.add(speaker.id);
    }
    return updated;
  }

  /// Turns the opt-in of [speakerId] on or off. Turning it on records that
  /// the notice was read and builds the profile from the meetings already
  /// stored; turning it off keeps the data unless [deleteData].
  Future<void> setEnabled(
    String speakerId,
    bool enabled, {
    bool deleteData = false,
  }) => _serial(() async {
    if (enabled) {
      await _settings?.setProfilesFeatureAcknowledged(true);
      await _speakers.setProfileEnabled(speakerId, true);
      await _rebuild(speakerId);
    } else {
      await _speakers.setProfileEnabled(speakerId, false);
      if (deleteData) await _deleteData(speakerId);
    }
  });

  /// Deletes the profile of [speakerId] and every per-meeting note, and
  /// turns the opt-in off so nothing is collected again silently.
  Future<void> deleteProfile(String speakerId) => _serial(() async {
    await _speakers.setProfileEnabled(speakerId, false);
    await _deleteData(speakerId);
  });

  Future<void> _deleteData(String speakerId) async {
    await _profiles.delete(speakerId);
    await _notes.deleteForSpeaker(speakerId);
    await _scrubMinutesNotes(speakerId);
  }

  /// Removes the notes about [speakerId] from the stored minutes of every
  /// meeting (`Minutes.speakerNotes`), so a deleted profile leaves nothing
  /// about the person behind. Names resolve among each meeting's speakers
  /// first; a note under the speaker's name that cannot be attributed to
  /// one person (shared name) is removed too. The meeting status is kept.
  /// Idempotent: a later call finishes an interrupted scrub.
  Future<void> _scrubMinutesNotes(String speakerId) async {
    final all = await _speakers.getAllById();
    final self = all[speakerId];
    final selfKey = self == null ? null : speakerNameKey(self.name);
    for (final m in await _meetings.getAll()) {
      final minutes = m.minutes;
      if (minutes == null || minutes.speakerNotes.isEmpty) continue;
      final names = SpeakerNameResolver.scoped(all, {
        for (final s in await _segments.getForMeeting(m.id)) ?s.speakerId,
      });
      bool aboutSpeaker(MinutesSpeakerNote n) {
        final id = names.id(n.speaker);
        if (id != null) return id == speakerId;
        return selfKey != null &&
            selfKey.isNotEmpty &&
            speakerNameKey(n.speaker) == selfKey;
      }

      final kept = [
        for (final n in minutes.speakerNotes)
          if (!aboutSpeaker(n)) n,
      ];
      if (kept.length == minutes.speakerNotes.length) continue;
      await _meetings.saveMinutes(
        m.id,
        minutes.copyWith(speakerNotes: kept),
        markReady: false,
      );
    }
  }
}

/// The [SpeakerProfileService] of the app database.
final speakerProfileServiceProvider = Provider<SpeakerProfileService>(
  (ref) => SpeakerProfileService(
    meetings: ref.watch(meetingRepositoryProvider),
    segments: ref.watch(segmentRepositoryProvider),
    speakers: ref.watch(speakerRepositoryProvider),
    tasks: ref.watch(taskRepositoryProvider),
    profiles: ref.watch(speakerProfileRepositoryProvider),
    notes: ref.watch(speakerMeetingNotesRepositoryProvider),
    settings: ref.watch(appSettingsProvider),
  ),
);

/// Updates the speaker profiles touched by [meetingId]; call it right after
/// the meeting's minutes (and their artefacts) were saved. Only speakers
/// with `profileEnabled` are affected. Never throws: a failure leaves the
/// previous profile in place (the user can rebuild it). Returns the ids of
/// the updated speakers.
Future<List<String>> updateProfileAfterMeeting(Ref ref, String meetingId) async {
  try {
    return await ref
        .read(speakerProfileServiceProvider)
        .updateAfterMeeting(meetingId);
  } catch (_) {
    return const [];
  }
}

/// The parsed profile of one speaker (null when none is stored, or the
/// stored JSON is of another shape).
final speakerProfileViewProvider = Provider.autoDispose
    .family<AsyncValue<({SpeakerProfile? profile, DateTime? updatedAt})>, String>(
      (ref, speakerId) => ref
          .watch(speakerProfileProvider(speakerId))
          .whenData(
            (r) => (
              profile: SpeakerProfile.tryParse(r?.profile),
              updatedAt: r?.updatedAt,
            ),
          ),
    );
