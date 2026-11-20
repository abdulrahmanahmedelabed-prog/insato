// Orchestrates the contradiction & consistency checker (v1.2, D): loads
// the institutional memory (earlier meetings' decisions with their official
// records and templates, tracked tasks, superseded resolutions), runs the
// pure-Dart heuristics, asks the selected minutes engine to classify the
// candidate pairs (one structured request, validated), and stores the
// findings. Also the user's actions (dismiss, «تم الإلغاء رسمياً» → an
// annotation of the earlier resolution, undo) and the live check during
// recording.

import '../../core/errors.dart';
import '../../core/models.dart';
import '../../data/consistency_repository.dart';
import '../../data/official_repository.dart';
import '../../data/repositories.dart';
import '../../data/repositories_v11.dart' show TaskRepository;
import '../../minutes/minutes_backend.dart';
import '../ask/ask_prompt.dart' show askPromptCharBudget;
import '../ask/search_text.dart' show analyzeSearchText;
import '../official/official_models.dart';
import '../tasks/task_logic.dart' show taskOwnerLabel;
import 'consistency_logic.dart';
import 'consistency_models.dart';
import 'consistency_prompt.dart';
import 'strings.dart';

/// The outcome of a check.
class ConsistencyRunResult {
  /// Creates a result.
  const ConsistencyRunResult({
    required this.open,
    this.engineUsed = false,
    this.engineNoticeAr,
  });

  /// Open findings after the run.
  final int open;

  /// True when the engine's classification was used.
  final bool engineUsed;

  /// Why the engine was not used (Arabic), when it was wanted.
  final String? engineNoticeAr;
}

/// Everything loaded for one check.
class ConsistencyInputs {
  /// Creates inputs.
  const ConsistencyInputs({
    required this.meeting,
    required this.record,
    required this.items,
    required this.memory,
    required this.candidates,
  });

  /// The checked meeting.
  final Meeting meeting;

  /// Its official record.
  final OfficialRecord? record;

  /// Its decisions and action items.
  final List<NewItem> items;

  /// Earlier items.
  final InstitutionalMemory memory;

  /// Candidates per new item.
  final Map<String, List<MemoryItem>> candidates;
}

/// The checker.
class ConsistencyService {
  /// Creates the service.
  ConsistencyService({
    required this.repository,
    required this._meetings,
    required this._segments,
    required this._speakers,
    required this._official,
    required this._officialSettings,
    required this._tasks,
    this._backendFactory,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Findings storage.
  final ConsistencyRepository repository;
  final MeetingRepository _meetings;
  final SegmentRepository _segments;
  final SpeakerRepository _speakers;
  final OfficialMinutesRepository _official;
  final OfficialSettingsStore _officialSettings;
  final TaskRepository _tasks;
  final Future<MinutesBackend> Function()? _backendFactory;

  final DateTime Function() _clock;

  /// Loads the memory of everything before [meeting] (excluded: the
  /// meeting itself, later meetings, superseded resolutions).
  Future<InstitutionalMemory> loadMemory(
    Meeting meeting, {
    Map<String, Speaker>? speakersById,
  }) async {
    final customs = await _officialSettings.templates();
    final superseded = await repository.supersededKeys();
    final speakers = speakersById ?? await _speakers.getAllById();
    final memoryMeetings = <MemoryMeeting>[];
    for (final m in await _meetings.getAll()) {
      if (m.id == meeting.id) continue;
      final record = await _official.get(m.id);
      memoryMeetings.add(
        MemoryMeeting(
          meeting: m,
          record: record,
          template: resolveTemplate(m.context.template, customs).template,
          supersededKeys: superseded[m.id] ?? const {},
        ),
      );
    }
    return buildInstitutionalMemory(
      current: meeting,
      meetings: memoryMeetings,
      tasks: await _tasks.getAll(),
      taskOwner: (t) => taskOwnerLabel(t, speakers),
    );
  }

  /// Loads the inputs of a check of [meetingId], or null without minutes.
  Future<ConsistencyInputs?> load(String meetingId) async {
    final meeting = await _meetings.get(meetingId);
    if (meeting == null || meeting.minutes == null) return null;
    final record = await _official.get(meetingId);
    final customs = await _officialSettings.templates();
    final template = resolveTemplate(meeting.context.template, customs);
    final items = newItemsOf(
      meeting,
      record: record,
      template: template.template,
    );
    final memory = await loadMemory(meeting);
    return ConsistencyInputs(
      meeting: meeting,
      record: record,
      items: items,
      memory: memory,
      candidates: retrieveCandidates(memory, items),
    );
  }

  /// Checks [meetingId]: heuristics, then (with [useEngine]) the selected
  /// engine when there is something to classify. The engine failing never
  /// fails the check: the heuristic findings are kept and the reason is
  /// returned. [onStatus] reports progress (Arabic).
  Future<ConsistencyRunResult> check(
    String meetingId, {
    bool useEngine = true,
    void Function(String statusAr)? onStatus,
  }) async {
    onStatus?.call(DS.checkingLocal);
    final inputs = await load(meetingId);
    if (inputs == null) {
      throw const InsatoException(DS.noMinutes);
    }
    final heuristic = heuristicFindings(
      meetingId: meetingId,
      items: inputs.items,
      candidates: inputs.candidates,
    );
    var findings = heuristic;
    var engineUsed = false;
    String? notice;
    final worthAsking =
        inputs.candidates.isNotEmpty || inputs.items.length >= 2;
    if (useEngine && worthAsking && _backendFactory != null) {
      MinutesBackend? backend;
      try {
        backend = await _backendFactory();
        onStatus?.call(DS.checkingEngine(backend.displayName));
        final segments = await _segments.getForMeeting(meetingId);
        final plan = buildConsistencyPlan(
          meeting: inputs.meeting,
          items: inputs.items,
          candidates: inputs.candidates,
          segments: segments,
          speakersById: await _speakers.getAllById(),
          charBudget:
              askPromptCharBudget(backend.engineId) -
              kConsistencySystemPrompt.length,
        );
        final result = await backend.generateStructured(
          MinutesBackendRequest(
            system: kConsistencySystemPrompt,
            user: plan.user,
            schema: consistencyAnswerSchema(),
            expectedChars: kConsistencyExpectedChars,
          ),
        );
        findings = mergeFindings(
          heuristic,
          parseConsistencyAnswer(result.text, plan),
        );
        engineUsed = true;
      } on InsatoException catch (e) {
        notice = DS.localOnly(e.messageAr);
      } catch (_) {
        notice = DS.localOnly(DS.engineFailed);
      } finally {
        backend?.close();
      }
    }
    final stored = await repository.replaceOpen(meetingId, findings);
    return ConsistencyRunResult(
      open: stored.length,
      engineUsed: engineUsed,
      engineNoticeAr: notice,
    );
  }

  /// Dismisses finding [id].
  Future<void> dismiss(int id) =>
      repository.setStatus(id, FindingStatus.dismissed);

  /// Confirms finding [id]. For a finding about an earlier decision /
  /// resolution («تم الإلغاء رسمياً») the earlier resolution is annotated
  /// as superseded by this meeting's decision — an annotation, never an
  /// edit, so approved minutes stay locked with their hash (official
  /// lifecycle). Other findings are only marked confirmed.
  Future<void> confirm(int id) async {
    final f = await repository.get(id);
    if (f == null) throw const InsatoException(DS.actionFailed);
    final prior = f.priorSide;
    final priorMeeting = prior.meetingId;
    ResolutionAnnotation? annotation;
    if (f.kind.aboutDecisions &&
        prior.kind.isDecision &&
        priorMeeting != null &&
        prior.itemIndex != null &&
        priorMeeting != f.meetingId &&
        await _meetings.get(priorMeeting) != null) {
      annotation = ResolutionAnnotation(
        meetingId: priorMeeting,
        decisionIndex: prior.itemIndex!,
        decisionKey: prior.itemKey,
        byMeetingId: f.meetingId,
        findingId: id,
        bySide: f.newSide,
        createdAt: _clock(),
      );
    }
    await repository.confirm(f, annotate: annotation);
  }

  /// Re-opens finding [id] (removes its annotation).
  Future<void> reopen(int id) => repository.reopen(id);

  /// Live check during recording: the [recent] transcript lines of
  /// [meetingId] against the earlier items they recall. Only with a cloud
  /// engine (the user accepted its data notice; [MinutesBackend.
  /// sendsDataOffDevice]); returns no findings otherwise. Nothing is
  /// stored.
  Future<List<ConsistencyFinding>> liveCheck({
    required String meetingId,
    required String title,
    required DateTime createdAt,
    required List<TranscriptSegment> recent,
  }) async {
    final lines = [
      for (final s in recent)
        if (s.hasContent && !s.isUnintelligible) s,
    ];
    if (lines.isEmpty || _backendFactory == null) return const [];
    final placeholder = Meeting(
      id: meetingId,
      title: title,
      createdAt: createdAt,
      status: MeetingStatus.recording,
    );
    final speakers = await _speakers.getAllById();
    final memory = await loadMemory(placeholder, speakersById: speakers);
    if (memory.isEmpty) return const [];
    final terms = analyzeSearchText(lines.map((s) => s.text).join(' '));
    final candidates = memory.search(terms, limit: 8);
    if (candidates.isEmpty) return const [];
    final backend = await _backendFactory();
    try {
      if (!backend.sendsDataOffDevice) return const [];
      final plan = buildLivePlan(
        meetingId: meetingId,
        title: title,
        date: createdAt,
        recent: lines,
        candidates: candidates,
        speakersById: speakers,
        charBudget:
            (askPromptCharBudget(backend.engineId) ~/ 2) -
            kConsistencySystemPrompt.length,
      );
      final result = await backend.generateStructured(
        MinutesBackendRequest(
          system: kConsistencySystemPrompt,
          user: plan.user,
          schema: consistencyAnswerSchema(),
          expectedChars: kConsistencyExpectedChars,
        ),
      );
      final byIndex = {for (final s in lines) s.index: s.text.trim()};
      return parseConsistencyAnswer(
        result.text,
        plan,
        segmentText: (i) => byIndex[i] ?? '',
      );
    } finally {
      backend.close();
    }
  }
}
