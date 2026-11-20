# Insato v1.1 — Contracts for the feature agents

This file lists the **shared APIs** every v1.1 feature builds on, and **which
directory each feature owns**. Feature agents work only inside their own
directory (and its mirror under `test/features/<name>/`); everything listed
here already exists, is tested, and must not be edited by feature agents. If
a feature needs a shared change, report it to the integrator instead.

Owner decision (F14): **Google Gemini (free tier) is the default minutes
engine**. Owner decision (1.2): **cloud options are free only** — Groq (free
plan) is the second cloud engine and Groq Whisper the cloud transcription;
the paid Claude and Deepgram engines were removed. On-device and
local-server engines plug in through F14. The same engine choice serves
"Ask your meetings" (F8).

Spec: `docs/FEATURES-v1.1.md`. Architecture: `docs/ARCHITECTURE.md`.
Toolchain: Flutter 3.50 / Dart 3.14, Material via
`package:material_ui/material_ui.dart`, Riverpod 3 (no codegen), drift 2.35.

---

## 1. Directory ownership

| Feature | Owns (lib/…) | Tests |
|---|---|---|
| F1 voice enrollment + F18 mic select / test / far field | `lib/features/voice/` | `test/features/voice/` |
| F2 glossary + F3 meeting context (sheet, editing) | `lib/features/context/` | `test/features/context/` |
| F5 audio player + evidence chips | `lib/features/evidence/` | `test/features/evidence/` |
| F8 Ask your meetings (BM25 retrieval, chat) | `lib/features/ask/` | `test/features/ask/` |
| F9 task tracking (screen, banner, confirm updates) | `lib/features/tasks/` | `test/features/tasks/` |
| F12 DOCX writer + share | `lib/features/export_docx/` | `test/features/export_docx/` |
| F13 Windows system audio (Dart side) | `lib/features/system_audio/` + `windows/runner/` or a plugin under `windows/plugins/` | `test/features/system_audio/` |
| F14 on-device / local-server engines, GGUF catalog entries | `lib/features/local_llm/` (already contains `local_minutes_backends.dart`) | `test/features/local_llm/` |
| F16 speaker profiles | `lib/features/profiles/` | `test/features/profiles/` |
| F17 codes UI + post-processing (reversed-audio re-ASR) | `lib/features/codes/` | `test/features/codes/` |

Shared (contracts agent / integrator only): `lib/core/`, `lib/data/`,
`lib/minutes/`, `lib/session/`, `lib/speech/`, `lib/audio/`, `lib/ui/`
(screens, `strings_ar.dart`, theme), `docs/`, `pubspec.yaml`.

Strings: each feature keeps its Arabic (MSA) UI strings in its own
`lib/features/<name>/strings.dart` in the style of `lib/ui/strings_ar.dart`
(an `abstract final class` of `static const String`s with doc comments).
Reuse `S.*` from `lib/ui/strings_ar.dart` for shared words (save, cancel, …).

Wiring into shared screens (navigation entries, meeting-detail tabs, the
"new meeting" sheet, the recording banner, settings tiles) is done by the
**integrator**: each feature exposes self-contained public widgets
(e.g. `TasksScreen`, `EvidenceChips`, `CodesTab`) plus a short note of where
they go.

---

## 2. Dependencies (pubspec.yaml, already added)

| Package | For | Platforms |
|---|---|---|
| `audioplayers: ^6.8.1` | F5 playback (seek to segment start − 1 s), F18 test playback | Android, iOS, Windows |
| `llamadart: ^0.20.1` + `llamadart_llama_cpp_flutter: ^0.20.1` | F14 GGUF via llama.cpp (`LlamaEngine.load`, structured JSON output); only the `llama_cpp` runtime is bundled (`hooks.user_defines`) | Android, iOS (≥ 16.4), Windows |
| `archive` (existing) | F12 DOCX zip | all |
| `http` (existing) | Gemini / Groq / Ollama | all |
| `record` (existing) | F18 `listInputDevices`, device selection | all |

Read package sources in `~/.pub-cache/hosted/pub.dev/` — never guess APIs.
Nothing else was added; signature capture is v1.2.

---

## 3. Domain models (`lib/core/models.dart` + `lib/core/models_v11.dart`)

`models.dart` exports `models_v11.dart`; import `core/models.dart` only.

* `TranscriptSegment`: new `kind` (`SegmentKind.speech | unintelligible`),
  `asrConfidence`, getters `isUnintelligible`, `hasContent`. The audio of an
  unintelligible segment is `startMs..endMs` of the meeting WAV
  (`Meeting.audioPath`, resolve with `AppPaths.resolveRecording`; absent when
  "keep audio" is off).
* `Speaker`: `profileEnabled` (F16 opt-in, default false), `voiceDevice`
  (F18), `lowConfidence` (F15).
* `Meeting`: `context` (`MeetingContext{agenda, expectedAttendees,
  contextNotes, template}`), `inputDevice`.
* `AsrResult.rejection` (`AsrRejection.silence | noText | filtered |
  lowConfidence`).
* `Minutes` (all new fields optional with defaults; v1 JSON still parses):
  `topics[].evidence`, `decisions[].evidence`, `actionItems[].evidence`
  (List<int> = `TranscriptSegment.index`), `agendaCoverage`
  (`MinutesAgendaItem`), `taskUpdates` (`MinutesTaskUpdate`), `codes`
  (`MinutesCodes{codedSpeech, jargon, spokenCode, implied, references}`),
  `speakerNotes` (`MinutesSpeakerNote{speaker, knowledge, contributions,
  style, summary, lowEvidence}`), `copyWith`.
* Table models: `GlossaryTerm`, `GlossaryCategory`, `TrackedTask`,
  `TaskStatus`, `PendingTaskUpdate`, `SpeakerProfileRecord` (profile JSON
  shape owned by F16), `SpeakerMeetingNotesRecord`, `CodeFinding`,
  `CodeFindingKind`, `EvidenceRef{meetingId, segmentIndex}`.
* `MinutesInputs{glossary, openTasks, taskSourceTitles}`.
* JSON helpers: `parseEvidenceIds`, `jsonStringList`, `jsonNonEmpty`,
  `jsonObjects`.

**Evidence ids are `TranscriptSegment.index` values of the meeting** (not
row ids). Map an id to a segment with
`segments.firstWhere((s) => s.index == id)`.

---

## 4. Database (schema v2) and repositories

(v1.2: the schema is now v5 — v3 speaker confidence, v4 task dismissals, v5
official minutes; see docs/ARCHITECTURE.md.)

`AppDatabase.currentSchemaVersion == 2` at v1.1; `onUpgrade` 1 → 2 is tested against
the drift snapshots in `drift_schemas/` (`test/data/migration_test.dart`).
After any future schema change: bump the version, add a migration step,
`dart run drift_dev schema dump lib/data/database.dart drift_schemas/drift_schema_vN.json`
and `dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/`.

Existing repositories (`lib/data/repositories.dart`), new methods:

* `MeetingRepository.create(..., context:, inputDevice:)`,
  `updateContext(id, MeetingContext)`, `setInputDevice(id, device)`.
* `SegmentRepository.getUnintelligible(meetingId)`,
  `setKind(segmentId, SegmentKind)`, `updateText(segmentId, text)`.
* `SpeakerRepository.create(..., voiceDevice:, lowConfidence:)`,
  `setProfileEnabled`, `setVoiceDevice`, `setLowConfidence`; `merge` moves
  tasks / notes / profiles / findings to the survivor.

New repositories (`lib/data/repositories_v11.dart`, all re-exported by
`lib/session/providers.dart`):

| Class | Provider | Key methods | Stream providers |
|---|---|---|---|
| `GlossaryRepository` | `glossaryRepositoryProvider` | `add(term:, arSpelling:, category:, meetingId:)` (dedupes per scope), `update`, `delete`, `getGlobal`, `getForMeeting`, `getEffective(meetingId, speakers:)` (global + meeting + named speakers) | `globalGlossaryProvider`, `meetingGlossaryProvider(meetingId)` |
| `TaskRepository` | `taskRepositoryProvider` | `create`, `get`, `getAll(status:, sourceMeetingId:)`, `getOpen`, `update(task)` (stamps `updatedAt`), `setStatus`, `delete` | `tasksProvider`, `openTasksProvider`, `meetingTasksProvider(meetingId)` |
| `PendingTaskUpdateRepository` | `pendingTaskUpdateRepositoryProvider` | `replaceForMeeting`, `getAll(meetingId:)`, `confirm(id)` (applies status, returns task), `dismiss(id)` | `pendingTaskUpdatesProvider`, `meetingPendingTaskUpdatesProvider(meetingId)` |
| `SpeakerProfileRepository` | `speakerProfileRepositoryProvider` | `get`, `getAll`, `upsert(SpeakerProfileRecord)`, `delete` | `speakerProfileProvider(speakerId)` |
| `SpeakerMeetingNotesRepository` | `speakerMeetingNotesRepositoryProvider` | `replaceForMeeting`, `getForSpeaker`, `getForMeeting`, `deleteForSpeaker` | `speakerMeetingNotesProvider(speakerId)` |
| `CodeFindingRepository` | `codeFindingRepositoryProvider` | `replaceForMeeting`, `getForMeeting`, `getByKind`, `updatePayload(id, payload)`, `delete` | `codeFindingsProvider(meetingId)` |

Foreign keys: meeting deletion cascades glossary (meeting terms), pending
updates, notes, findings; tasks keep their row with `sourceMeetingId = null`.
Speaker deletion cascades profile and notes; tasks / findings get
`speakerId = null`.

`lib/data/minutes_artifacts.dart` — `MinutesArtifactsWriter.persist(...)`
runs automatically right after minutes are saved (same transaction), so
features only **read** these tables:

* action items → `tasks` (re-generation matches reworded items to existing
  tasks — Arabic-normalised text or shared evidence —, keeps tasks the user
  touched, adds new ones, deletes untouched stale ones, and never re-creates
  items the user deleted (`task_dismissals`, schema v4) — `planTaskSync`);
* `taskUpdates` → `task_updates_pending` (only ids of open tasks of *earlier*
  meetings that were given to the engine; updates the user already
  confirmed or dismissed are not proposed again);
* `speakerNotes` → `speaker_meeting_notes` (only speakers with
  `profileEnabled`; others are never stored);
* `codes` → `code_findings` (payload = the item's `toJson()`, speaker
  resolved by name — among the meeting's own speakers first; reversed-speech
  results and app findings of an earlier run are carried over).

---

## 5. Settings (`lib/data/secure_settings.dart`)

`AppSettingsData` fields (keys in `AppSettings.k*`, setters on
`AppSettings`, snapshot via `appSettingsDataProvider` /
`settingsSnapshotProvider`):

| Field | Key | Default | Setter |
|---|---|---|---|
| `minutesEngine` (`engineGemini` \| `engineGroq` \| `engineLocal` \| `engineServer`) | `minutes_engine` | `'gemini'` | `setMinutesEngine` |
| `geminiModel` | `gemini_model` | `'gemini-flash-lite-latest'` | `setGeminiModel` (strips `models/`) |
| `geminiPrivacyAcknowledged` | `gemini_privacy_acknowledged` | `false` | `setGeminiPrivacyAcknowledged` |
| `groqModel` (null = automatic) | `groq_model` | `null` | `setGroqModel` |
| `groqPrivacyAcknowledged` | `groq_privacy_acknowledged` | `false` | `setGroqPrivacyAcknowledged` |
| `groqAsrModel` (`whisper-large-v3` \| `whisper-large-v3-turbo`) | `groq_asr_model` | `'whisper-large-v3'` | `setGroqAsrModel` |
| `groqAsrPrivacyAcknowledged` | `groq_asr_privacy_acknowledged` | `false` | `setGroqAsrPrivacyAcknowledged` |
| `cloudFallbackAuto` | `cloud_fallback_auto` | `false` | `setCloudFallbackAuto` |
| `localLlmModelId` (null = recommended) | `local_llm_model_id` | `null` | `setLocalLlmModelId` |
| `serverUrl` | `server_url` | `'http://127.0.0.1:11434'` | `setServerUrl` (http/https only) |
| `serverModel` | `server_model` | `null` | `setServerModel` |
| `audioSource` (`mic` \| `system` \| `both`; Windows only) | `audio_source` | `'both'` | `setAudioSource` |
| `inputDeviceId` (null = default) | `input_device_id` | `null` | `setInputDeviceId` |
| `farFieldMode` | `far_field_mode` | `false` | `setFarFieldMode` |
| `profilesFeatureAcknowledged` | `profiles_feature_acknowledged` | `false` | `setProfilesFeatureAcknowledged` |

Helpers: `minutesEngineIsCloud`, `usesCloudAsr`, `normalizeGeminiModel`,
`normalizeGroqModel`, `normalizeServerUrl`. One-time upgrade:
`AppSettings.migrateToFreeEngines(secure)` (marker `free_engines_migrated_v1`).

Secure storage (`SecureSettings`, `secureSettingsProvider`):
`getGeminiApiKey / setGeminiApiKey / clearGeminiApiKey` (key
`insato.gemini_api_key`) and `getGroqApiKey / setGroqApiKey /
clearGroqApiKey` (`insato.groq_api_key`, minutes and transcription);
`deleteLegacyPaidKeys` removes the old Anthropic / Deepgram keys. A
locked keystore throws `SecureStorageUnavailableException` (never "no key").

UI readiness (`lib/ui/ui_providers.dart`): `geminiKeyConfiguredProvider`,
`groqKeyConfiguredProvider`, `minutesEngineReadyProvider` (bool?).

---

## 6. Minutes contract (`lib/minutes/`)

* `minutes_prompt.dart`
  * `minutesJsonSchema()` — strict schema mirroring `Minutes.contentJson()`
    (every object `additionalProperties: false`, all keys required, enums).
  * `kMinutesSystemPrompt` — one constant prompt for every engine (evidence,
    agenda, glossary, open tasks, opt-in speaker notes with the F16
    guardrails, F17 codes as hypotheses, unintelligible markers).
  * `renderEvidenceTranscript(segments, speakersById)` — one line per
    segment: `[#42 00:12:31] Name (lang): text`; unintelligible:
    `[#7 00:01:02] Name: [غير مفهوم — مقطع #7، 2.4 ث] «guess»`.
  * `buildMinutesUserMessage(meeting:, segments:, speakersById:,
    detailLevel:, inputs:)` — metadata, `<meeting_context>`, `<glossary>`,
    `<open_tasks>`, `<speaker_notes_opt_in>`, `<transcript>`,
    `<instructions>`.
  * `buildTranscriptBlocks` (exports; blocks carry `segmentIndices`),
    `renderTranscript`, `segmentTranscriptText`,
    `formatUnintelligibleMarker`, `optedInSpeakerNames`, `speakerStats`.
* `minutes_validation.dart` — `sanitizeMinutes(minutes, MinutesConstraints)`,
  `alignAgendaCoverage`.
* `json_repair.dart` — `decodeJsonObjectTolerant`, `repairJson` (fences,
  prose, trailing commas, comments, truncation). `parseMinutesJson` uses it.
* `minutes_backend.dart` — **the engine plug-in interface**:

```dart
abstract class MinutesBackend {
  String get engineId;          // 'gemini' | 'groq' | 'local' | 'server'
  String get displayName;       // shown in Arabic status lines
  bool get sendsDataOffDevice;
  Future<MinutesBackendResult> generateStructured(
    MinutesBackendRequest request,           // system, user, schema,
    {MinutesBackendProgressCallback? onProgress}); // expectedChars, context
  void close();
}
// MinutesBackendResult{text, model}; MinutesBackendProgress{phase, attempt,
// receivedChars, fraction, wait}; phases: loadingModel, connecting,
// thinking, writing, retrying, waitingForQuota, processingChunk.
// MinutesBackendRequest.context (MinutesPromptContext: meeting, segments,
// speakersById, inputs, detailLevel) lets local engines re-prompt in chunks
// (map-reduce) with the helpers above.
```

* `lib/features/groq/` — `GroqMinutesBackend` (a `LocalLlmMinutesBackend`
  over `GroqTextGenerator` / `LlmServerClient` with an API key: json_schema
  or json_object, map-reduce, quota waits, model chain), `groq_api.dart`
  (`pickPreferredGroqModel`, `rankGroqModels`, `classifyGroqLimit`,
  `GroqRateGate`, `GroqQuotaExceededException`).
* `gemini_client.dart` — `GeminiClient` (streaming SSE,
  `responseJsonSchema` → `responseSchema` → JSON-prompt fallback, finish
  reasons, 429 handling with `GeminiRateGate`, `listModels`,
  `withModel`), `GeminiMinutesBackend` (404 → `models.list` →
  `pickPreferredGeminiModel`), `toGeminiOpenApiSchema`,
  `GeminiQuotaExceededException`, `GeminiModelNotFoundException`,
  `kDefaultGeminiModel`, `kGeminiApiKeyUrl`.
* `minutes_generator.dart` — `StructuredMinutesEngine(backend:,
  detailLevel:)` implements `MinutesEngine` (builds the prompt, calls the
  backend, parses tolerantly, sanitizes).
* `MinutesEngine.generate(..., inputs: MinutesInputs)` — `PostProcessor`
  passes the effective glossary and up to 60 open tasks of earlier meetings
  (source meeting created before this one; manual tasks by their own
  creation time), newest first (`PostProcessor.minutesInputsFor`).

Engine selection (`lib/session/minutes_engines.dart` +
`lib/session/providers.dart`):

* `createMinutesBackend(settings:, secure:, local:, server:, …)` → the
  selected backend, or throws `MinutesEngineNotReadyException(reason:
  noApiKey | privacyNotAcknowledged | unavailable)` with an Arabic message.
  **Nothing is sent to Gemini before `geminiPrivacyAcknowledged`, nor to
  Groq before `groqPrivacyAcknowledged`.** Gemini / Groq come wrapped in
  `QuotaFallbackMinutesBackend` (daily quota → the other free cloud engine,
  automatic with `cloudFallbackAuto` or offered via
  `MinutesQuotaExhaustedException`); `runWithMinutesEngine` forces an engine
  for one job.
* `minutesBackendFactoryProvider` — `Future<MinutesBackend> Function()`;
  **F8 uses this** (caller closes the backend).
* `minutesEngineFactoryProvider` — used by `PostProcessor`.
* `PostProcessor.runMinutesIfPossible` → `MinutesRun{outcome, noticeAr}`.

F14 hook (`lib/features/local_llm/local_minutes_backends.dart`, owned by
F14): `localMinutesBackendBuilderProvider` /
`serverMinutesBackendBuilderProvider` (`LocalMinutesBackendBuilder?{build,
unavailableMessageAr, settings}`). While null, the engine is not offered in
Settings; once F14 returns a builder, Settings shows the choice and renders
`settings(context)` under it. Nothing else needs to change.

---

## 7. Speech pipeline (F17 retention)

* `lib/speech/asr_outcome.dart` — `classifyAsrOutcome(AsrResult)` →
  `AsrOutcome{kind (null = drop), text, confidence}`; `kLowAsrConfidence =
  0.3`. Only `AsrRejection.silence` is dropped; empty / no-text /
  hallucination-filtered output and low-confidence text become
  `SegmentKind.unintelligible` (filtered output is never kept as a guess).
* Sherpa Whisper reports `silence` (RMS < −60 dBFS), `noText`, `filtered`;
  Groq Whisper (`GroqAsrEngine`) reports `silence` (RMS) / `noText` /
  `filtered` (same hallucination filter) and accepts `keyterms` (F2, sent as
  a short `prompt`;
  wired from `GlossaryRepository.getEffective(null, speakers:)` in
  `sessionEnginesFactoryProvider`).
* The isolate protocol carries `rejection`; `SessionPipeline` stores
  unintelligible segments with speaker, embedding and confidence; re-processing
  from audio uses the same path. UI transcript shows
  `S.unintelligibleSegment(durationMs)`; exports use the marker.
* F17 post-processing (reversed-audio re-ASR) reads
  `SegmentRepository.getUnintelligible`, slices the WAV, and on success
  calls `updateText` + `setKind(…, SegmentKind.speech)` or enriches the
  finding with `CodeFindingRepository.updatePayload`.

---

## 8. Session

* `MeetingSessionController.start(title:, consentGiven:, context:,
  inputDevice:)` stores the F3 context and F18 device on the new meeting.
* F13/F18 capture changes go through the `SessionAudioSource` seam
  (`sessionAudioSourceProvider`); the integrator swaps in the feature's
  source.

---

## 9. Privacy rules (all features)

* Opt-in where the spec says: speaker profiles per speaker (default off,
  `profilesFeatureAcknowledged` notice first), Gemini, Groq and Groq Whisper
  notices before first use.
* Nothing leaves the device unless the user chose a cloud engine; F8 uses
  `minutesBackendFactoryProvider` and therefore the same consent.
* Gemini free tier: Google may use prompts and responses to improve its
  products and human reviewers may read them (de-identified). Groq: its
  stated policy is not to train on API data, but data is processed on its
  servers (word it as the provider's policy, not a guarantee). Say so
  wherever data is sent; offer the on-device engine for confidential
  meetings.
* F16 / F17 outputs are descriptive, evidence-backed hypotheses; no
  sensitive inferences.

---

## 10. Quality bar

`flutter analyze` → 0 issues; `flutter test` green; pure logic unit-tested;
Arabic MSA strings; RTL-correct and accessible widgets (Semantics, 48 dp
targets); no stubs / TODOs; never commit.
