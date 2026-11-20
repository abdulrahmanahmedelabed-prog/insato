// Merges the per-meeting notes and statistics of one speaker into a
// [SpeakerProfile] (F16), and writes its descriptive narrative summary.
//
// Pure Dart: every input is passed in; see profile_service.dart for the
// database side.

import '../../core/models.dart';
import '../../core/time_format.dart';
import 'profile_guardrails.dart';
import 'profile_model.dart';
import 'strings.dart';

/// Key under which domain names are grouped: normalised text with the
/// Arabic article «ال» removed from each word, so «المالية» and «مالية»
/// merge.
String domainKey(String domain) => normalizeProfileText(domain)
    .split(' ')
    .map((w) => w.length > 3 && w.startsWith('ال') ? w.substring(2) : w)
    .join(' ');

/// How a domain's level evolved across meetings: the deepest level seen in
/// each meeting, oldest first; the later half compared with the earlier
/// half (a difference of half a level or more counts).
DomainTrend computeDomainTrend(List<ProfileKnowledgeItem> items) {
  final perMeeting = <String, ({DateTime at, int rank})>{};
  for (final i in items) {
    final r = levelRank(i.level);
    final prev = perMeeting[i.meetingId];
    if (prev == null || r > prev.rank) {
      perMeeting[i.meetingId] = (at: i.meetingAt, rank: r);
    }
  }
  if (perMeeting.length < 2) return DomainTrend.single;
  final ranks = perMeeting.values.toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  final half = ranks.length ~/ 2;
  double avg(Iterable<({DateTime at, int rank})> xs) =>
      xs.fold<int>(0, (n, x) => n + x.rank) / xs.length;
  final early = avg(ranks.take(half));
  final late = avg(ranks.skip(ranks.length - half));
  final diff = late - early;
  if (diff >= 0.5) return DomainTrend.deepening;
  if (diff <= -0.5) return DomainTrend.lighter;
  return DomainTrend.steady;
}

/// Builds the profile of a speaker called [speakerName].
///
/// * [perMeeting]: deterministic statistics per meeting (entries of
///   meetings missing from [meetingsById] are dropped as deleted).
/// * [notes]: the speaker's per-meeting notes (extracted with the minutes).
/// * [tasks]: tasks owned by the speaker.
/// * [meetingsById]: existing meetings (titles and dates).
SpeakerProfile aggregateSpeakerProfile({
  required String speakerName,
  required List<MeetingSpeakerStats> perMeeting,
  required List<SpeakerMeetingNotesRecord> notes,
  required List<TrackedTask> tasks,
  required Map<String, Meeting> meetingsById,
  required DateTime builtAt,
}) {
  // Statistics: existing meetings only, refreshed titles / dates.
  final stats =
      [
        for (final m in perMeeting)
          if (meetingsById[m.meetingId] case final meeting?)
            MeetingSpeakerStats(
              meetingId: m.meetingId,
              meetingTitle: meeting.title,
              meetingAt: meeting.createdAt,
              speakingMs: m.speakingMs,
              meetingSpeechMs: m.meetingSpeechMs,
              segments: m.segments,
              speechSegments: m.speechSegments,
              turns: m.turns,
              questions: m.questions,
              questionSegments: m.questionSegments,
              languageMs: m.languageMs,
              languageTransitions: m.languageTransitions,
              languageSwitches: m.languageSwitches,
              mixedTurns: m.mixedTurns,
              interruptionsGiven: m.interruptionsGiven,
              interruptionsReceived: m.interruptionsReceived,
              decisions: m.decisions,
            ),
      ]..sort((a, b) {
        final c = a.meetingAt.compareTo(b.meetingAt);
        return c != 0 ? c : a.meetingId.compareTo(b.meetingId);
      });

  final usable =
      [
        for (final n in notes)
          if (meetingsById.containsKey(n.meetingId)) n,
      ]..sort((a, b) {
        final c = meetingsById[a.meetingId]!.createdAt.compareTo(
          meetingsById[b.meetingId]!.createdAt,
        );
        return c != 0 ? c : a.meetingId.compareTo(b.meetingId);
      });

  var omitted = 0;
  var lowEvidenceMeetings = 0;
  final domainItems = <String, List<ProfileKnowledgeItem>>{};
  final domainSpellings = <String, Map<String, int>>{};
  final domainLastSpelling = <String, String>{};
  final contributions = <ProfileContribution>[];
  final style = <ProfileStyleItem>[];
  final summaries = <ProfileSummaryItem>[];

  for (final record in usable) {
    final at = meetingsById[record.meetingId]!.createdAt;
    final n = record.notes;
    final low = n.lowEvidence;
    if (low) lowEvidenceMeetings++;
    for (final k in n.knowledge) {
      final domain = k.domain.trim();
      final key = domainKey(domain);
      if (key.isEmpty || k.demonstrated.trim().isEmpty) continue;
      if (violatesKnowledgeGuardrails(k.demonstrated) ||
          violatesKnowledgeGuardrails(domain)) {
        omitted++;
        continue;
      }
      (domainItems[key] ??= []).add(
        ProfileKnowledgeItem(
          meetingId: record.meetingId,
          meetingAt: at,
          demonstrated: k.demonstrated.trim(),
          level: k.level,
          evidence: k.evidence,
          lowEvidence: low || k.evidence.isEmpty,
        ),
      );
      final spellings = domainSpellings[key] ??= {};
      spellings[domain] = (spellings[domain] ?? 0) + 1;
      domainLastSpelling[key] = domain;
    }
    for (final c in n.contributions) {
      if (c.text.trim().isEmpty) continue;
      if (violatesProfileGuardrails(c.text)) {
        omitted++;
        continue;
      }
      contributions.add(
        ProfileContribution(
          meetingId: record.meetingId,
          meetingAt: at,
          kind: c.kind,
          text: c.text.trim(),
          evidence: c.evidence,
          lowEvidence: low || c.evidence.isEmpty,
        ),
      );
    }
    for (final s in n.style) {
      if (s.observation.trim().isEmpty) continue;
      if (violatesProfileGuardrails(s.observation)) {
        omitted++;
        continue;
      }
      style.add(
        ProfileStyleItem(
          meetingId: record.meetingId,
          meetingAt: at,
          observation: s.observation.trim(),
          evidence: s.evidence,
          lowEvidence: low || s.evidence.isEmpty,
        ),
      );
    }
    final summary = n.summary?.trim();
    if (summary != null && summary.isNotEmpty) {
      if (violatesProfileGuardrails(summary)) {
        omitted++;
      } else {
        summaries.add(
          ProfileSummaryItem(
            meetingId: record.meetingId,
            meetingAt: at,
            summary: summary,
            lowEvidence: low,
          ),
        );
      }
    }
  }

  final domains = <ProfileDomain>[
    for (final e in domainItems.entries)
      () {
        final items = e.value;
        final spellings = domainSpellings[e.key]!;
        final best = spellings.values.reduce((a, b) => a > b ? a : b);
        final last = domainLastSpelling[e.key]!;
        final name = spellings[last] == best
            ? last
            : spellings.entries.firstWhere((s) => s.value == best).key;
        final meetings = items.map((i) => i.meetingId).toSet().length;
        final evidenceCount = items.fold<int>(
          0,
          (n, i) => n + i.evidence.length,
        );
        return ProfileDomain(
          domain: name,
          items: items,
          trend: computeDomainTrend(items),
          lowEvidence:
              items.every((i) => i.lowEvidence) ||
              (meetings == 1 && evidenceCount < 2),
        );
      }(),
  ]..sort(_compareDomains);

  int newestFirst(DateTime a, DateTime b) => b.compareTo(a);
  _stableSort(contributions, (a, b) => newestFirst(a.meetingAt, b.meetingAt));
  _stableSort(style, (a, b) => newestFirst(a.meetingAt, b.meetingAt));
  _stableSort(summaries, (a, b) => newestFirst(a.meetingAt, b.meetingAt));

  final ownedTasks =
      [
        for (final t in tasks)
          ProfileTask(
            taskId: t.id,
            task: t.task,
            status: t.status,
            meetingId:
                t.sourceMeetingId != null &&
                    meetingsById.containsKey(t.sourceMeetingId)
                ? t.sourceMeetingId
                : null,
            evidence:
                t.sourceMeetingId != null &&
                    meetingsById.containsKey(t.sourceMeetingId)
                ? t.evidenceSegmentIds
                : const [],
          ),
      ]..sort((a, b) => b.taskId.compareTo(a.taskId));

  final base = SpeakerProfile(
    speakerName: speakerName,
    builtAt: builtAt,
    perMeeting: stats,
    knowledge: domains,
    contributions: contributions,
    style: style,
    summaries: summaries,
    tasks: ProfileTasks(items: ownedTasks),
    notesMeetings: usable.length,
    lowEvidenceMeetings: lowEvidenceMeetings,
    omittedByGuardrails: omitted,
  );
  return SpeakerProfile(
    speakerName: speakerName,
    builtAt: builtAt,
    perMeeting: stats,
    knowledge: domains,
    contributions: contributions,
    style: style,
    summaries: summaries,
    tasks: base.tasks,
    notesMeetings: base.notesMeetings,
    lowEvidenceMeetings: lowEvidenceMeetings,
    omittedByGuardrails: omitted,
    narrative: buildProfileNarrative(base),
  );
}

int _compareDomains(ProfileDomain a, ProfileDomain b) {
  if (a.lowEvidence != b.lowEvidence) return a.lowEvidence ? 1 : -1;
  var c = b.meetings.compareTo(a.meetings);
  if (c != 0) return c;
  c = levelRank(b.highestLevel).compareTo(levelRank(a.highestLevel));
  if (c != 0) return c;
  c = b.evidenceCount.compareTo(a.evidenceCount);
  if (c != 0) return c;
  return a.domain.compareTo(b.domain);
}

void _stableSort<T>(List<T> list, int Function(T, T) compare) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  list
    ..clear()
    ..addAll(indexed.map((e) => e.$2));
}

/// The descriptive narrative summary of [p]: participation, typical role
/// (from the observed contributions), most evidenced domains, observed
/// strengths, then the most recent per-meeting summaries. Nominal,
/// gender-neutral Arabic; no judgement, no score.
List<String> buildProfileNarrative(SpeakerProfile p, {int recentSummaries = 2}) {
  final out = <String>[];
  final t = p.totals;
  if (t.meetings > 0) {
    final dated = p.perMeeting.where((m) => m.segments > 0).toList();
    out.add(
      PS.narrativeParticipation(
        meetings: t.meetings,
        first: formatArabicShortDate(dated.first.meetingAt),
        last: formatArabicShortDate(dated.last.meetingAt),
        sharePercent: (t.talkShare * 100).round(),
        speakingMs: t.speakingMs,
      ),
    );
  }

  final counts = p.contributionCounts.entries
      .where((e) => e.key != ContributionKind.other)
      .toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.index.compareTo(b.key.index);
    });
  if (counts.isNotEmpty) {
    out.add(
      PS.narrativeRole([
        for (final e in counts.take(2)) PS.contributionRole(e.key),
      ]),
    );
  }

  final strong = p.knowledge.where((d) => !d.lowEvidence).take(3).toList();
  if (strong.isNotEmpty) {
    out.add(
      PS.narrativeDomains([
        for (final d in strong) PS.domainWithMeetings(d.domain, d.meetings),
      ]),
    );
  }

  final strengths = <String>[
    for (final d in p.knowledge.where((d) => !d.lowEvidence))
      if (d.highestLevel != DemonstrationLevel.mentioned)
        PS.strengthInDomain(d.highestLevel, d.domain),
  ].take(3).toList();
  if (p.tasks.owned > 0 && p.tasks.completed > 0) {
    strengths.add(PS.strengthTasks(p.tasks.completed, p.tasks.owned));
  }
  if (strengths.isNotEmpty) out.add(PS.narrativeStrengths(strengths));

  final recent = p.summaries
      .where((s) => !s.lowEvidence)
      .take(recentSummaries)
      .toList();
  for (final s in recent) {
    out.add(PS.narrativeMeetingSummary(formatArabicShortDate(s.meetingAt), s.summary));
  }

  if (p.notesMeetings == 0) {
    out.add(PS.narrativeNoNotes);
  } else if (t.lowEvidence || p.lowEvidenceMeetings == p.notesMeetings) {
    out.add(PS.narrativeLowEvidence);
  }
  return out;
}
