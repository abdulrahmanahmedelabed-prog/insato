// The minutes backend abstraction (Insato v1.1, F14).
//
// A [MinutesBackend] turns (system prompt, user message, JSON schema) into
// structured JSON text, reporting progress. The minutes engine
// (`StructuredMinutesEngine` in minutes_generator.dart) builds the prompt,
// calls the backend selected in Settings and parses / validates the answer;
// "Ask your meetings" (F8) uses the same backends with its own schema.
//
// Implementations:
// * [GeminiMinutesBackend] (gemini_client.dart) — Google Gemini API, the
//   default engine (free tier);
// * Groq (lib/features/groq) — Groq's free plan, OpenAI-compatible API
//   (shares the local-server client and map-reduce of F14);
// * on-device / local-server backends — lib/features/local_llm (F14).
//
// THIS FILE IS A SHARED CONTRACT (see docs/V11-CONTRACTS.md).

import '../core/models.dart';
import 'minutes_prompt.dart';

/// Coarse phases of a backend request, for the progress UI.
enum MinutesBackendPhase {
  /// Loading a local model into memory (local engines).
  loadingModel,

  /// Sending the request / waiting for the first bytes.
  connecting,

  /// The model is reasoning before writing.
  thinking,

  /// The model is writing the answer ([MinutesBackendProgress.receivedChars]
  /// grows).
  writing,

  /// A transient failure occurred; waiting before the next attempt.
  retrying,

  /// The provider's rate limit was reached; waiting the delay it asked for
  /// ([MinutesBackendProgress.wait]).
  waitingForQuota,

  /// Processing one chunk of a long transcript (local map-reduce;
  /// [MinutesBackendProgress.fraction] is the share done).
  processingChunk,
}

/// One progress report of a backend.
class MinutesBackendProgress {
  /// Creates a report.
  const MinutesBackendProgress(
    this.phase, {
    this.attempt = 1,
    this.receivedChars = 0,
    this.fraction,
    this.wait,
  });

  /// Phase.
  final MinutesBackendPhase phase;

  /// 1-based attempt number.
  final int attempt;

  /// Answer characters received so far (cumulative; resets on a retry).
  final int receivedChars;

  /// 0..1 when the backend knows its overall progress (local engines).
  final double? fraction;

  /// Waiting time announced with [MinutesBackendPhase.retrying] /
  /// [MinutesBackendPhase.waitingForQuota], when known.
  final Duration? wait;
}

/// Receives backend progress.
typedef MinutesBackendProgressCallback = void Function(
  MinutesBackendProgress progress,
);

/// The structured pieces a prompt was built from, for backends that need to
/// re-prompt differently (e.g. map-reduce over transcript chunks on a small
/// local context window). Cloud backends ignore it.
class MinutesPromptContext {
  /// Creates a context.
  const MinutesPromptContext({
    required this.meeting,
    required this.segments,
    required this.speakersById,
    this.inputs = MinutesInputs.none,
    this.detailLevel = MinutesDetailLevel.detailed,
  });

  /// The meeting (title, date, context).
  final Meeting meeting;

  /// Transcript segments with content, in time order.
  final List<TranscriptSegment> segments;

  /// Speakers by id.
  final Map<String, Speaker> speakersById;

  /// Glossary and open tasks.
  final MinutesInputs inputs;

  /// Requested detail.
  final MinutesDetailLevel detailLevel;
}

/// One structured-output request.
class MinutesBackendRequest {
  /// Creates a request.
  const MinutesBackendRequest({
    required this.system,
    required this.user,
    required this.schema,
    this.expectedChars,
    this.context,
  });

  /// System prompt / instruction.
  final String system;

  /// User message.
  final String user;

  /// JSON schema of the answer (strict dialect: every object has
  /// `additionalProperties: false` and all keys `required`; nullable types
  /// as `["string","null"]`; `enum` allowed).
  final Map<String, dynamic> schema;

  /// Rough expected answer size in characters (progress only).
  final int? expectedChars;

  /// Structured source of [user] (minutes requests only).
  final MinutesPromptContext? context;
}

/// The answer of a backend.
class MinutesBackendResult {
  /// Creates a result.
  const MinutesBackendResult({required this.text, required this.model});

  /// The answer: JSON text conforming to the request schema (possibly with
  /// noise around it; callers parse tolerantly).
  final String text;

  /// The model that actually produced it (recorded as `Minutes.model`).
  final String model;
}

/// A minutes / structured-generation engine backend.
abstract class MinutesBackend {
  /// `AppSettingsData.minutesEngine` value of this backend (`gemini`,
  /// `groq`, `local`, `server`).
  String get engineId;

  /// Product name shown in Arabic status lines (e.g. `Gemini`, `Groq`).
  String get displayName;

  /// True when the request leaves the device (cloud provider).
  bool get sendsDataOffDevice;

  /// Generates a structured answer. Throws an `InsatoException`
  /// (`MissingApiKeyException`, `MinutesGenerationException`, …) with an
  /// Arabic message on failure.
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request, {
    MinutesBackendProgressCallback? onProgress,
  });

  /// Releases resources (HTTP client, loaded model). Idempotent.
  void close();
}
