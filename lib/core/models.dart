// Pure domain models for Insato. No Flutter imports here so the whole file is
// usable from isolates and plain `dart test`.
//
// THIS FILE IS A SHARED CONTRACT. Change it only with care: every module
// depends on it.

import 'dart:typed_data';

import 'models_v11.dart';

export 'models_v11.dart';

/// Audio format used everywhere inside the pipeline.
const int kSampleRate = 16000;

/// A contiguous chunk of speech detected by the VAD.
class SpeechSegment {
  SpeechSegment({
    required this.index,
    required this.startMs,
    required this.samples,
  });

  /// Monotonic index within a meeting (0-based).
  final int index;

  /// Start offset from the beginning of the recording, in milliseconds.
  final int startMs;

  /// Mono float samples in [-1, 1] at [kSampleRate].
  final Float32List samples;

  int get durationMs => (samples.length * 1000) ~/ kSampleRate;
  int get endMs => startMs + durationMs;
}

/// Result of transcribing one [SpeechSegment].
class AsrResult {
  const AsrResult({
    required this.text,
    this.language,
    this.confidence,
    this.rejection,
  });

  final String text;

  /// ISO-639-1 code (e.g. `ar`, `en`, `fr`) when the engine reports it.
  final String? language;

  /// 0..1 when the engine reports it.
  final double? confidence;

  /// Why the engine produced no usable text (v1.1, F17); null when the
  /// result was not rejected or the engine does not report it. See
  /// `classifyAsrOutcome` (speech/asr_outcome.dart) for how the pipeline
  /// turns this into a stored [SegmentKind].
  final AsrRejection? rejection;

  bool get isEmpty => text.trim().isEmpty;
}

/// A speaker known to the app (global voiceprint), shared across meetings.
class Speaker {
  const Speaker({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.isNamedByUser,
    required this.createdAt,
    this.centroid,
    this.embeddingCount = 0,
    this.profileEnabled = false,
    this.voiceDevice,
    this.lowConfidence = false,
  });

  final String id;

  /// Display name. Auto names look like `متحدث 3`.
  final String name;

  /// ARGB color for chips/avatars.
  final int colorValue;

  /// True once the user renamed the speaker (auto names are not "real" names).
  final bool isNamedByUser;

  final DateTime createdAt;

  /// L2-normalised voiceprint centroid. Null if voice was forgotten.
  final Float32List? centroid;

  /// Number of embeddings averaged into [centroid].
  final int embeddingCount;

  /// v1.1 (F16): the user enabled the speaker profile (opt-in, default off).
  /// Only such speakers get per-meeting notes in the minutes.
  final bool profileEnabled;

  /// v1.1 (F18): id / label of the input device the voiceprint was learned
  /// on (null = unknown / default microphone).
  final String? voiceDevice;

  /// v1.1 (F15): the voice was heard only briefly (< 3 s in total); the
  /// voiceprint is kept but not used for matching until more speech
  /// accumulates.
  final bool lowConfidence;

  Speaker copyWith({
    String? name,
    int? colorValue,
    bool? isNamedByUser,
    Float32List? centroid,
    bool clearCentroid = false,
    int? embeddingCount,
    bool? profileEnabled,
    String? voiceDevice,
    bool clearVoiceDevice = false,
    bool? lowConfidence,
  }) {
    return Speaker(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isNamedByUser: isNamedByUser ?? this.isNamedByUser,
      createdAt: createdAt,
      centroid: clearCentroid ? null : (centroid ?? this.centroid),
      embeddingCount: embeddingCount ?? this.embeddingCount,
      profileEnabled: profileEnabled ?? this.profileEnabled,
      voiceDevice: clearVoiceDevice ? null : (voiceDevice ?? this.voiceDevice),
      lowConfidence: lowConfidence ?? this.lowConfidence,
    );
  }
}

/// One transcribed utterance in a meeting.
class TranscriptSegment {
  const TranscriptSegment({
    required this.id,
    required this.meetingId,
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.speakerId,
    this.language,
    this.embedding,
    this.speakerLocked = false,
    this.kind = SegmentKind.speech,
    this.asrConfidence,
    this.speakerConfidence,
  });

  final String id;
  final String meetingId;
  final int index;
  final int startMs;
  final int endMs;
  final String text;

  /// Null until diarization assigns a speaker.
  final String? speakerId;
  final String? language;

  /// L2-normalised speaker embedding of this segment (may be null if the
  /// segment was too short to embed).
  final Float32List? embedding;

  /// True when the user manually assigned the speaker; refinement must not
  /// override it.
  final bool speakerLocked;

  /// v1.1 (F17): recognised speech, or real speech that could not be decoded
  /// (its audio is `startMs..endMs` of the meeting WAV; [text] is empty or
  /// the recogniser's low-confidence guess).
  final SegmentKind kind;

  /// v1.1: recogniser confidence 0..1 when reported.
  final double? asrConfidence;

  /// Heuristic confidence in `[0, 1]` that [speakerId] is right (null when
  /// unknown, e.g. rows stored before this was recorded). User-locked
  /// segments are certain regardless of this value.
  final double? speakerConfidence;

  /// True when the speaker attribution is doubtful: an assigned, unlocked
  /// segment whose [speakerConfidence] is below
  /// [kUncertainSpeakerConfidence].
  bool get isSpeakerUncertain =>
      !speakerLocked &&
      speakerId != null &&
      speakerConfidence != null &&
      speakerConfidence! < kUncertainSpeakerConfidence;

  /// True for [SegmentKind.unintelligible] segments.
  bool get isUnintelligible => kind == SegmentKind.unintelligible;

  /// True when the segment carries content for minutes / transcripts:
  /// recognised text, or an unintelligible segment (which is never dropped).
  bool get hasContent => isUnintelligible || text.trim().isNotEmpty;

  TranscriptSegment copyWith({
    String? text,
    String? speakerId,
    bool? speakerLocked,
    String? language,
    SegmentKind? kind,
    double? asrConfidence,
    double? speakerConfidence,
  }) {
    return TranscriptSegment(
      id: id,
      meetingId: meetingId,
      index: index,
      startMs: startMs,
      endMs: endMs,
      text: text ?? this.text,
      speakerId: speakerId ?? this.speakerId,
      language: language ?? this.language,
      embedding: embedding,
      speakerLocked: speakerLocked ?? this.speakerLocked,
      kind: kind ?? this.kind,
      asrConfidence: asrConfidence ?? this.asrConfidence,
      speakerConfidence: speakerConfidence ?? this.speakerConfidence,
    );
  }
}

/// Speaker attributions with a confidence below this are shown as doubtful
/// (transcript UI) and flagged to the minutes model.
const double kUncertainSpeakerConfidence = 0.5;

enum MeetingStatus {
  recording,
  processing,
  ready,
  failed;

  static MeetingStatus parse(String s) =>
      MeetingStatus.values.firstWhere((e) => e.name == s, orElse: () => failed);
}

class Meeting {
  const Meeting({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.status,
    this.durationMs = 0,
    this.audioPath,
    this.minutes,
    this.errorMessage,
    this.context = MeetingContext.empty,
    this.inputDevice,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final MeetingStatus status;
  final int durationMs;

  /// Absolute path of the archived WAV file (if kept).
  final String? audioPath;
  final Minutes? minutes;
  final String? errorMessage;

  /// v1.1 (F3): agenda, expected attendees, notes, template.
  final MeetingContext context;

  /// v1.1 (F18): input device used for the recording (null = default).
  final String? inputDevice;

  Meeting copyWith({
    String? title,
    MeetingStatus? status,
    int? durationMs,
    String? audioPath,
    Minutes? minutes,
    String? errorMessage,
    bool clearError = false,
    MeetingContext? context,
    String? inputDevice,
  }) {
    return Meeting(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      status: status ?? this.status,
      durationMs: durationMs ?? this.durationMs,
      audioPath: audioPath ?? this.audioPath,
      minutes: minutes ?? this.minutes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      context: context ?? this.context,
      inputDevice: inputDevice ?? this.inputDevice,
    );
  }
}

// ---------------------------------------------------------------------------
// Minutes (المحضر). Mirrors the JSON schema in minutes/minutes_prompt.dart.
// All human-readable strings are Arabic.
// ---------------------------------------------------------------------------

class MinutesTopic {
  const MinutesTopic({
    required this.title,
    required this.discussion,
    this.speakerNames = const [],
    this.evidence = const [],
  });

  final String title;
  final String discussion;
  final List<String> speakerNames;

  /// v1.1 (F5): transcript segment indices supporting the topic.
  final List<int> evidence;

  Map<String, dynamic> toJson() => {
        'title': title,
        'discussion': discussion,
        'speakers': speakerNames,
        'evidence': evidence,
      };

  factory MinutesTopic.fromJson(Map<String, dynamic> j) => MinutesTopic(
        title: _str(j['title']),
        discussion: _str(j['discussion']),
        speakerNames: _strList(j['speakers']),
        evidence: parseEvidenceIds(j['evidence']),
      );
}

class MinutesDecision {
  const MinutesDecision({
    required this.text,
    this.proposedBy,
    this.evidence = const [],
  });

  final String text;
  final String? proposedBy;

  /// v1.1 (F5): transcript segment indices supporting the decision.
  final List<int> evidence;

  Map<String, dynamic> toJson() =>
      {'text': text, 'proposed_by': proposedBy, 'evidence': evidence};

  factory MinutesDecision.fromJson(Map<String, dynamic> j) => MinutesDecision(
        text: _str(j['text']),
        proposedBy: _nonEmpty(j['proposed_by']),
        evidence: parseEvidenceIds(j['evidence']),
      );
}

class ActionItem {
  const ActionItem({
    required this.task,
    this.owner,
    this.dueDate,
    this.evidence = const [],
  });

  final String task;
  final String? owner;

  /// Free text as stated in the meeting (e.g. "الخميس القادم").
  final String? dueDate;

  /// v1.1 (F5): transcript segment indices supporting the action item.
  final List<int> evidence;

  Map<String, dynamic> toJson() =>
      {'task': task, 'owner': owner, 'due': dueDate, 'evidence': evidence};

  factory ActionItem.fromJson(Map<String, dynamic> j) => ActionItem(
        task: _str(j['task']),
        owner: _nonEmpty(j['owner']),
        dueDate: _nonEmpty(j['due']),
        evidence: parseEvidenceIds(j['evidence']),
      );
}

class Minutes {
  const Minutes({
    required this.title,
    required this.summary,
    required this.attendees,
    required this.topics,
    required this.decisions,
    required this.actionItems,
    required this.openQuestions,
    required this.languagesDetected,
    required this.generatedAt,
    required this.model,
    this.nextMeeting,
    this.notes,
    this.agendaCoverage = const [],
    this.taskUpdates = const [],
    this.codes = MinutesCodes.empty,
    this.speakerNotes = const [],
  });

  final String title;
  final String summary;
  final List<String> attendees;
  final List<MinutesTopic> topics;
  final List<MinutesDecision> decisions;
  final List<ActionItem> actionItems;
  final List<String> openQuestions;

  /// Languages heard in the meeting, in Arabic (e.g. ["العربية", "الإنجليزية"]).
  final List<String> languagesDetected;
  final String? nextMeeting;
  final String? notes;
  final DateTime generatedAt;

  /// Model that produced the minutes (as reported by the API).
  final String model;

  /// v1.1 (F3): coverage of each agenda item, in agenda order (empty when
  /// the meeting had no agenda).
  final List<MinutesAgendaItem> agendaCoverage;

  /// v1.1 (F9): proposed updates of open tasks (applied after the user
  /// confirms; see `TaskUpdatesPendingRepository`).
  final List<MinutesTaskUpdate> taskUpdates;

  /// v1.1 (F17): codes, jargon, spoken code, implied speech, references.
  final MinutesCodes codes;

  /// v1.1 (F16): notes about speakers who opted in to profiles.
  final List<MinutesSpeakerNote> speakerNotes;

  /// JSON of the content fields only (the shape the minutes engine returns,
  /// see `minutesJsonSchema`).
  Map<String, dynamic> contentJson() => {
        'title': title,
        'summary': summary,
        'attendees': attendees,
        'topics': topics.map((t) => t.toJson()).toList(),
        'decisions': decisions.map((d) => d.toJson()).toList(),
        'action_items': actionItems.map((a) => a.toJson()).toList(),
        'open_questions': openQuestions,
        'languages_detected': languagesDetected,
        'next_meeting': nextMeeting,
        'notes': notes,
        'agenda_coverage': agendaCoverage.map((a) => a.toJson()).toList(),
        'task_updates': taskUpdates.map((u) => u.toJson()).toList(),
        'codes': codes.toJson(),
        'speaker_notes': speakerNotes.map((n) => n.toJson()).toList(),
      };

  /// Copy with replaced fields.
  Minutes copyWith({
    String? title,
    String? summary,
    List<String>? attendees,
    List<MinutesTopic>? topics,
    List<MinutesDecision>? decisions,
    List<ActionItem>? actionItems,
    List<String>? openQuestions,
    List<String>? languagesDetected,
    String? nextMeeting,
    String? notes,
    DateTime? generatedAt,
    String? model,
    List<MinutesAgendaItem>? agendaCoverage,
    List<MinutesTaskUpdate>? taskUpdates,
    MinutesCodes? codes,
    List<MinutesSpeakerNote>? speakerNotes,
  }) {
    return Minutes(
      title: title ?? this.title,
      summary: summary ?? this.summary,
      attendees: attendees ?? this.attendees,
      topics: topics ?? this.topics,
      decisions: decisions ?? this.decisions,
      actionItems: actionItems ?? this.actionItems,
      openQuestions: openQuestions ?? this.openQuestions,
      languagesDetected: languagesDetected ?? this.languagesDetected,
      nextMeeting: nextMeeting ?? this.nextMeeting,
      notes: notes ?? this.notes,
      generatedAt: generatedAt ?? this.generatedAt,
      model: model ?? this.model,
      agendaCoverage: agendaCoverage ?? this.agendaCoverage,
      taskUpdates: taskUpdates ?? this.taskUpdates,
      codes: codes ?? this.codes,
      speakerNotes: speakerNotes ?? this.speakerNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        ...contentJson(),
        'generated_at': generatedAt.toIso8601String(),
        'model': model,
      };

  /// Parses either the stored JSON ([toJson]) or Claude's raw content JSON
  /// (then [generatedAt]/[model] must be supplied).
  factory Minutes.fromJson(
    Map<String, dynamic> j, {
    DateTime? generatedAt,
    String? model,
  }) {
    List<T> objs<T>(Object? v, T Function(Map<String, dynamic>) f) =>
        jsonObjects(v, f);
    return Minutes(
      title: _str(j['title']),
      summary: _str(j['summary']),
      attendees: _strList(j['attendees']),
      topics: objs(j['topics'], MinutesTopic.fromJson),
      decisions: objs(j['decisions'], MinutesDecision.fromJson),
      actionItems: objs(j['action_items'], ActionItem.fromJson),
      openQuestions: _strList(j['open_questions']),
      languagesDetected: _strList(j['languages_detected']),
      nextMeeting: _nonEmpty(j['next_meeting']),
      notes: _nonEmpty(j['notes']),
      generatedAt: generatedAt ??
          DateTime.tryParse(j['generated_at'] is String
              ? j['generated_at'] as String
              : '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      model: model ?? (j['model'] is String ? j['model'] as String : ''),
      agendaCoverage: objs(j['agenda_coverage'], MinutesAgendaItem.fromJson),
      taskUpdates: [
        for (final m in objs(j['task_updates'], MinutesTaskUpdate.tryParse))
          ?m,
      ],
      codes: MinutesCodes.fromJson(j['codes']),
      speakerNotes: objs(j['speaker_notes'], MinutesSpeakerNote.fromJson),
    );
  }
}

List<String> _strList(Object? v) => v is List
    ? v.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
    : const [];

String? _nonEmpty(Object? v) => jsonNonEmpty(v);

/// A string value as-is (v1 behaviour: not trimmed), '' for non-strings.
String _str(Object? v) => v is String ? v : '';
