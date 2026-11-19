// State and flow of "Ask your meetings" (F8): the in-memory conversation,
// one question at a time (search → engine → linked answer), progress, stop,
// retry and clear.
//
// The engine is the one selected in Settings (`minutesBackendFactoryProvider`
// — Gemini by default, Claude, on-device or local server), so the same
// consent applies: nothing is sent to Gemini before its privacy notice was
// accepted, and nothing leaves the device with a local engine. The
// conversation is kept in memory only (never written to disk).

import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../minutes/gemini_client.dart' show GeminiQuotaExceededException;
import '../../minutes/minutes_backend.dart';
import '../../session/post_processor.dart' show MinutesEngineNotReadyException;
import '../../session/providers.dart' show minutesBackendFactoryProvider;
import 'ask_answer.dart';
import 'ask_corpus.dart';
import 'ask_prompt.dart';
import 'ask_retrieval.dart';
import 'strings.dart';

// ---------------------------------------------------------------------------
// Seams
// ---------------------------------------------------------------------------

/// Loads every searchable meeting (newest first).
abstract interface class AskCorpusLoader {
  /// Loads the corpus.
  Future<List<AskMeetingSource>> load();
}

/// [AskCorpusLoader] over the repositories: every meeting that is not being
/// recorded, with its transcript and minutes.
class RepositoryAskCorpusLoader implements AskCorpusLoader {
  /// Creates a loader.
  const RepositoryAskCorpusLoader({
    required this.meetings,
    required this.segments,
    required this.speakers,
  });

  /// Meetings.
  final MeetingRepository meetings;

  /// Transcript segments.
  final SegmentRepository segments;

  /// Speakers (names).
  final SpeakerRepository speakers;

  @override
  Future<List<AskMeetingSource>> load() async {
    final all = await meetings.getAll();
    final speakersById = await speakers.getAllById();
    final out = <AskMeetingSource>[];
    for (final m in all) {
      if (m.status == MeetingStatus.recording) continue;
      final src = AskMeetingSource.from(
        m,
        await segments.getForMeeting(m.id),
        speakersById,
      );
      if (src.hasContent) out.add(src);
    }
    return out;
  }
}

/// The corpus loader (tests override it).
final askCorpusLoaderProvider = Provider<AskCorpusLoader>(
  (ref) => RepositoryAskCorpusLoader(
    meetings: ref.watch(meetingRepositoryProvider),
    segments: ref.watch(segmentRepositoryProvider),
    speakers: ref.watch(speakerRepositoryProvider),
  ),
);

/// Runs [runAskRetrieval] (tests may run it inline).
typedef AskRetrievalRunner =
    Future<AskPackedContext> Function(AskRetrievalJob job);

/// Corpora above this many transcript characters are searched in a
/// background isolate so the UI stays smooth.
const int kAskIsolateThresholdChars = 150000;

/// Runs [job] inline for small corpora and in a background isolate for
/// large ones.
Future<AskPackedContext> runAskRetrievalInBackground(AskRetrievalJob job) {
  if (job.corpusChars < kAskIsolateThresholdChars) {
    return Future.value(runAskRetrieval(job));
  }
  return Isolate.run(() => runAskRetrieval(job));
}

/// The retrieval runner.
final askRetrievalRunnerProvider = Provider<AskRetrievalRunner>(
  (ref) => runAskRetrievalInBackground,
);

/// Clock (tests override it).
final askClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Who wrote a message.
enum AskRole {
  /// The user's question.
  user,

  /// The assistant's answer or a notice.
  assistant,
}

/// Why a question produced no answer.
enum AskFailure {
  /// The engine is not ready (no key, notice not accepted, unavailable):
  /// offer to open Settings.
  engineNotReady,

  /// The provider's quota is exhausted.
  quota,

  /// No meeting has searchable content.
  noMeetings,

  /// The user stopped the question.
  cancelled,

  /// Any other failure (network, unreadable answer, …).
  error,
}

/// Phases of a running question.
enum AskPhase {
  /// Searching the meetings on the device.
  searching,

  /// Loading a local model.
  loadingModel,

  /// Sending the request.
  connecting,

  /// The model is reasoning.
  thinking,

  /// The model is writing.
  writing,

  /// Retrying after a transient failure.
  retrying,

  /// Waiting for the provider's per-minute limit.
  waitingForQuota,

  /// Processing chunks on the device.
  processingChunk,
}

/// Progress of the running question.
class AskProgress {
  /// Creates a progress report.
  const AskProgress(this.phase, {this.engineName, this.wait, this.fraction});

  /// Phase.
  final AskPhase phase;

  /// Engine name, once known.
  final String? engineName;

  /// Waiting time ([AskPhase.waitingForQuota]).
  final Duration? wait;

  /// 0..1 when known.
  final double? fraction;

  /// Arabic status line.
  String get labelAr {
    final engine = engineName ?? '';
    return switch (phase) {
      AskPhase.searching => AS.searching,
      AskPhase.loadingModel => AS.loadingModel,
      AskPhase.connecting => AS.connecting(engine),
      AskPhase.thinking => AS.thinking(engine),
      AskPhase.writing => AS.writing(engine),
      AskPhase.retrying => AS.retrying,
      AskPhase.waitingForQuota => AS.waitingForQuota(wait),
      AskPhase.processingChunk => AS.processingChunk,
    };
  }
}

/// Maps a backend phase to an [AskPhase].
AskPhase askPhaseOf(MinutesBackendPhase phase) => switch (phase) {
  MinutesBackendPhase.loadingModel => AskPhase.loadingModel,
  MinutesBackendPhase.connecting => AskPhase.connecting,
  MinutesBackendPhase.thinking => AskPhase.thinking,
  MinutesBackendPhase.writing => AskPhase.writing,
  MinutesBackendPhase.retrying => AskPhase.retrying,
  MinutesBackendPhase.waitingForQuota => AskPhase.waitingForQuota,
  MinutesBackendPhase.processingChunk => AskPhase.processingChunk,
};

/// One message of the conversation.
class AskMessage {
  /// Creates a message.
  const AskMessage({
    required this.id,
    required this.role,
    required this.text,
    this.answer,
    this.found = true,
    this.engineName,
    this.sentOffDevice = false,
    this.failure,
    this.question,
  });

  /// Unique id within the conversation.
  final int id;

  /// Author.
  final AskRole role;

  /// The question (user), the answer's plain text, or the failure message.
  final String text;

  /// The linked answer (successful assistant messages).
  final AskLinkedAnswer? answer;

  /// False when the engine said the meetings do not contain the answer.
  final bool found;

  /// Engine that answered.
  final String? engineName;

  /// True when the question and excerpts were sent to a cloud engine.
  final bool sentOffDevice;

  /// Why there is no answer (assistant failure messages).
  final AskFailure? failure;

  /// The question a failure message belongs to (for retry).
  final String? question;

  /// True for a failure that can be retried.
  bool get retryable =>
      failure != null && failure != AskFailure.noMeetings && question != null;
}

/// The conversation.
class AskState {
  /// Creates a state.
  const AskState({this.messages = const [], this.progress});

  /// Messages, oldest first.
  final List<AskMessage> messages;

  /// Progress of the running question (null when idle).
  final AskProgress? progress;

  /// True while a question runs.
  bool get busy => progress != null;

  AskState _copy({List<AskMessage>? messages, AskProgress? progress}) =>
      AskState(messages: messages ?? this.messages, progress: progress);
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Drives the conversation. Kept for the app's lifetime (in memory only).
class AskController extends Notifier<AskState> {
  int _generation = 0;
  int _nextId = 1;
  MinutesBackend? _backend;
  Map<String, int> _aliases = const {};
  final Map<int, AskMeetingRef> _refs = {};

  @override
  AskState build() {
    ref.onDispose(() {
      _generation++;
      _backend?.close();
      _backend = null;
    });
    return const AskState();
  }

  void _set(AskState s) {
    if (ref.mounted) state = s;
  }

  void _progress(AskProgress p) => _set(state._copy(progress: p));

  void _append(AskMessage m, {bool idle = false}) => _set(
    state._copy(
      messages: [...state.messages, m],
      progress: idle ? null : state.progress,
    ),
  );

  List<AskHistoryTurn> _history() {
    final turns = <AskHistoryTurn>[];
    final msgs = state.messages;
    for (var i = 0; i + 1 < msgs.length; i++) {
      final q = msgs[i];
      final a = msgs[i + 1];
      if (q.role == AskRole.user &&
          a.role == AskRole.assistant &&
          a.answer != null) {
        turns.add(AskHistoryTurn(question: q.text, answer: a.answer!.modelText));
      }
    }
    return turns;
  }

  /// Asks [question]. Returns false (and does nothing) when it is empty or
  /// another question is running.
  Future<bool> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || state.busy) return false;
    final text = q.length > kAskMaxQuestionChars
        ? q.substring(0, kAskMaxQuestionChars)
        : q;
    final history = _history();
    final generation = ++_generation;
    _set(
      state._copy(
        messages: [
          ...state.messages,
          AskMessage(id: _nextId++, role: AskRole.user, text: text),
        ],
        progress: const AskProgress(AskPhase.searching),
      ),
    );
    bool current() => generation == _generation && ref.mounted;
    void fail(AskFailure failure, String messageAr) {
      if (!current()) return;
      _append(
        AskMessage(
          id: _nextId++,
          role: AskRole.assistant,
          text: messageAr,
          failure: failure,
          question: text,
        ),
        idle: true,
      );
    }

    MinutesBackend? backend;
    try {
      final sources = await ref.read(askCorpusLoaderProvider).load();
      if (!current()) return true;
      if (sources.isEmpty) {
        fail(AskFailure.noMeetings, AS.noMeetings);
        return true;
      }
      backend = await ref.read(minutesBackendFactoryProvider)();
      if (!current()) {
        backend.close();
        return true;
      }
      _backend = backend;
      final engine = backend.displayName;
      _progress(AskProgress(AskPhase.searching, engineName: engine));

      final budget =
          askPromptCharBudget(backend.engineId) -
          kAskSystemPrompt.length -
          askMessageOverhead(text, history);
      final packed = await ref.read(askRetrievalRunnerProvider)(
        AskRetrievalJob(
          meetings: sources,
          question: text,
          previousQuestions: [for (final h in history) h.question],
          aliases: _aliases,
          charBudget: budget,
        ),
      );
      if (!current()) return true;
      _aliases = packed.aliases;
      packed.refs.forEach((alias, r) {
        final old = _refs[alias];
        _refs[alias] = old == null || old.meetingId != r.meetingId
            ? r
            : old.merge(r);
      });

      _progress(AskProgress(AskPhase.connecting, engineName: engine));
      final result = await backend.generateStructured(
        MinutesBackendRequest(
          system: kAskSystemPrompt,
          user: buildAskUserMessage(
            question: text,
            context: packed.text,
            history: history,
            now: ref.read(askClockProvider)(),
            noMatches: !packed.hasMatches,
          ),
          schema: askAnswerSchema(),
          expectedChars: kAskExpectedAnswerChars,
        ),
        onProgress: (p) {
          if (!current()) return;
          _progress(
            AskProgress(
              askPhaseOf(p.phase),
              engineName: engine,
              wait: p.wait,
              fraction: p.fraction,
            ),
          );
        },
      );
      if (!current()) return true;
      final raw = parseAskEngineOutput(result.text);
      if (raw == null) {
        fail(AskFailure.error, AS.unreadable);
        return true;
      }
      final linked = linkAskAnswer(raw.answer, _refs);
      _append(
        AskMessage(
          id: _nextId++,
          role: AskRole.assistant,
          text: linked.plainText,
          answer: linked,
          found: raw.found,
          engineName: engine,
          sentOffDevice: backend.sendsDataOffDevice,
          question: text,
        ),
        idle: true,
      );
    } on MinutesEngineNotReadyException catch (e) {
      fail(AskFailure.engineNotReady, e.messageAr);
    } on GeminiQuotaExceededException catch (e) {
      fail(AskFailure.quota, e.messageAr);
    } on InsatoException catch (e) {
      fail(AskFailure.error, e.messageAr);
    } catch (_) {
      fail(AskFailure.error, AS.unexpected);
    } finally {
      backend?.close();
      if (identical(_backend, backend)) _backend = null;
      if (current() && state.busy) _set(state._copy());
    }
    return true;
  }

  /// Stops the running question (its answer, if any, is discarded).
  void cancel() {
    if (!state.busy) return;
    _generation++;
    _backend?.close();
    _backend = null;
    final lastQuestion = state.messages.lastWhere(
      (m) => m.role == AskRole.user,
    );
    _append(
      AskMessage(
        id: _nextId++,
        role: AskRole.assistant,
        text: AS.cancelled,
        failure: AskFailure.cancelled,
        question: lastQuestion.text,
      ),
      idle: true,
    );
  }

  /// Asks again the question of the failure message [messageId] (the failed
  /// exchange is removed first).
  Future<bool> retry(int messageId) async {
    if (state.busy) return false;
    final i = state.messages.indexWhere((m) => m.id == messageId);
    if (i < 0) return false;
    final failed = state.messages[i];
    final question = failed.question;
    if (!failed.retryable || question == null) return false;
    final messages = [...state.messages]..removeAt(i);
    if (i > 0 &&
        messages[i - 1].role == AskRole.user &&
        messages[i - 1].text == question) {
      messages.removeAt(i - 1);
    }
    _set(state._copy(messages: messages));
    return ask(question);
  }

  /// Clears the conversation (stopping a running question).
  void clear() {
    _generation++;
    _backend?.close();
    _backend = null;
    _aliases = const {};
    _refs.clear();
    _set(const AskState());
  }
}

/// The conversation of "Ask your meetings" (kept until the app closes).
final askControllerProvider = NotifierProvider<AskController, AskState>(
  AskController.new,
);
