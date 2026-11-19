// Pure domain models for Insato. No Flutter imports here so the whole file is
// usable from isolates and plain `dart test`.
//
// THIS FILE IS A SHARED CONTRACT. Change it only with care: every module
// depends on it.

import 'dart:typed_data';

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
  });

  final String text;

  /// ISO-639-1 code (e.g. `ar`, `en`, `fr`) when the engine reports it.
  final String? language;

  /// 0..1 when the engine reports it.
  final double? confidence;

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

  Speaker copyWith({
    String? name,
    int? colorValue,
    bool? isNamedByUser,
    Float32List? centroid,
    bool clearCentroid = false,
    int? embeddingCount,
  }) {
    return Speaker(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isNamedByUser: isNamedByUser ?? this.isNamedByUser,
      createdAt: createdAt,
      centroid: clearCentroid ? null : (centroid ?? this.centroid),
      embeddingCount: embeddingCount ?? this.embeddingCount,
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

  TranscriptSegment copyWith({
    String? text,
    String? speakerId,
    bool? speakerLocked,
    String? language,
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
    );
  }
}

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

  Meeting copyWith({
    String? title,
    MeetingStatus? status,
    int? durationMs,
    String? audioPath,
    Minutes? minutes,
    String? errorMessage,
    bool clearError = false,
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
  });

  final String title;
  final String discussion;
  final List<String> speakerNames;

  Map<String, dynamic> toJson() => {
        'title': title,
        'discussion': discussion,
        'speakers': speakerNames,
      };

  factory MinutesTopic.fromJson(Map<String, dynamic> j) => MinutesTopic(
        title: (j['title'] ?? '') as String,
        discussion: (j['discussion'] ?? '') as String,
        speakerNames: _strList(j['speakers']),
      );
}

class MinutesDecision {
  const MinutesDecision({required this.text, this.proposedBy});

  final String text;
  final String? proposedBy;

  Map<String, dynamic> toJson() => {'text': text, 'proposed_by': proposedBy};

  factory MinutesDecision.fromJson(Map<String, dynamic> j) => MinutesDecision(
        text: (j['text'] ?? '') as String,
        proposedBy: _nonEmpty(j['proposed_by']),
      );
}

class ActionItem {
  const ActionItem({required this.task, this.owner, this.dueDate});

  final String task;
  final String? owner;

  /// Free text as stated in the meeting (e.g. "الخميس القادم").
  final String? dueDate;

  Map<String, dynamic> toJson() =>
      {'task': task, 'owner': owner, 'due': dueDate};

  factory ActionItem.fromJson(Map<String, dynamic> j) => ActionItem(
        task: (j['task'] ?? '') as String,
        owner: _nonEmpty(j['owner']),
        dueDate: _nonEmpty(j['due']),
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

  /// JSON of the content fields only (the shape Claude returns).
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
      };

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
        (v is List)
            ? v.whereType<Map>().map((m) => f(m.cast<String, dynamic>())).toList()
            : <T>[];
    return Minutes(
      title: (j['title'] ?? '') as String,
      summary: (j['summary'] ?? '') as String,
      attendees: _strList(j['attendees']),
      topics: objs(j['topics'], MinutesTopic.fromJson),
      decisions: objs(j['decisions'], MinutesDecision.fromJson),
      actionItems: objs(j['action_items'], ActionItem.fromJson),
      openQuestions: _strList(j['open_questions']),
      languagesDetected: _strList(j['languages_detected']),
      nextMeeting: _nonEmpty(j['next_meeting']),
      notes: _nonEmpty(j['notes']),
      generatedAt: generatedAt ??
          DateTime.tryParse((j['generated_at'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      model: model ?? (j['model'] as String?) ?? '',
    );
  }
}

List<String> _strList(Object? v) =>
    v is List ? v.whereType<String>().where((s) => s.trim().isNotEmpty).toList() : const [];

String? _nonEmpty(Object? v) =>
    (v is String && v.trim().isNotEmpty) ? v.trim() : null;
