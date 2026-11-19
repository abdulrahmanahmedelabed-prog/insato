# Katib (كاتب) — Architecture

Katib turns everything the device microphone hears — in any language — into
**Arabic meeting minutes**, identifies speakers by **voice**, labels them
`متحدث 1`, `متحدث 2`, … and lets the user rename them. A rename is remembered
through a persistent *voiceprint*, so the same person is recognised by name in
future meetings.

Targets: **Android, iOS, Windows** from one Flutter codebase.

## Pipeline

```
 mic (16 kHz mono PCM16)                       ┌──────────── worker isolate ────────────┐
   │  record package stream                    │                                        │
   ▼                                           │  SpeechSegment (Float32 samples)       │
 AudioCaptureService ──► WAV archive file      │     │                                  │
   │                                           │     ├─► AsrEngine.transcribe()         │
   ▼                                           │     │     (sherpa-onnx Whisper, or     │
 VadSegmenter (silero VAD, sherpa-onnx)  ────► │     │      cloud engine)               │
   speech segments 0.4 s … 30 s                │     └─► SpeakerEmbedder.embed()        │
                                               │           (sherpa-onnx speaker model)  │
                                               └───────────────┬────────────────────────┘
                                                               ▼
                                   SpeakerTracker (online assignment against
                                   global voiceprints + meeting-local clusters)
                                                               ▼
                                   TranscriptSegment → DB → live UI
                                                               ▼  (stop)
                                   Offline refinement: agglomerative re-clustering
                                   of all segment embeddings → relabel → update voiceprints
                                                               ▼
                                   MinutesGenerator (Claude API, structured JSON,
                                   Arabic) → Minutes → DB → PDF / Markdown / share
```

## Key decisions

| Concern | Decision | Why |
|---|---|---|
| UI | Flutter, Material 3, Arabic-first RTL | One codebase for Android/iOS/Windows |
| State | `flutter_riverpod` | Testable, no codegen required |
| Storage | `drift` (SQLite) | Typed queries, migrations, works on all 3 platforms |
| Secrets | `flutter_secure_storage` | API keys never stored in plain DB |
| Capture | `record` streaming PCM16 16 kHz mono | Supported on Android/iOS/Windows |
| VAD / ASR / speaker embeddings | `sherpa_onnx` (on-device, FFI) | Offline, private; Whisper is multilingual (99 languages, code-switching) |
| Cloud ASR (optional) | Deepgram `nova-3`, `language=multi` | Highest accuracy where privacy policy allows |
| Diarization | VAD segments → embeddings → online cosine assignment + offline agglomerative refinement | Real-time labels during the meeting, corrected labels after |
| Voiceprints | Global `speakers` table; centroid embedding + count, updated on confirmed segments | Renames persist across meetings |
| Minutes | Claude API `claude-opus-5-5`, adaptive thinking, `effort: high`, streaming, `output_config.format` JSON schema, server-side fallback | Faithful, structured Arabic minutes from multilingual transcript |
| Export | PDF (`pdf` + bundled Arabic font), Markdown, plain-text share | Official, printable minutes |

## Module layout (`lib/`)

```
lib/
  main.dart                      bootstrap (bindings, DB, ProviderScope)
  app.dart                       MaterialApp, theme, RTL, routes
  core/
    models.dart                  pure domain models (no Flutter imports)  ← CONTRACT
    interfaces.dart              engine interfaces                         ← CONTRACT
    errors.dart                  KatibException hierarchy
    time_format.dart             mm:ss / hh:mm:ss helpers (Arabic digits optional)
  data/
    database.dart                drift schema + DAO-style methods
    repositories.dart            MeetingRepository, SpeakerRepository (domain ⇄ rows)
    secure_settings.dart         API keys (secure storage) + AppSettings (prefs table)
  audio/
    audio_capture_service.dart   record stream → Float32 frames + level meter + WAV writer
    wav_writer.dart              streaming RIFF/WAV writer (pure Dart)
    pcm.dart                     PCM16 ⇄ Float32, resample helpers (pure Dart)
  speech/
    model_catalog.dart           downloadable model definitions (URLs, sizes, files)
    model_manager.dart           download + verify + extract (.tar.bz2) + status
    vad_segmenter.dart           sherpa-onnx silero VAD wrapper → SpeechSegment
    sherpa_asr_engine.dart       AsrEngine via sherpa-onnx Whisper
    cloud_asr_engine.dart        AsrEngine via Deepgram REST
    sherpa_speaker_embedder.dart SpeakerEmbedder via sherpa-onnx
    processing_isolate.dart      long-lived worker isolate running ASR + embedding
  diarization/
    vector_math.dart             cosine, normalize, mean (pure Dart)
    speaker_tracker.dart         online assignment (pure Dart, unit-tested)
    clustering.dart              agglomerative clustering (pure Dart, unit-tested)
  minutes/
    claude_client.dart           raw-HTTP Messages API client with SSE streaming
    minutes_prompt.dart          system prompt + transcript rendering + JSON schema
    minutes_generator.dart       orchestrates Claude call → Minutes
    export_service.dart          Minutes → Markdown / PDF / share text
  session/
    meeting_session_controller.dart  orchestrates a live recording session
  ui/
    theme.dart, strings_ar.dart
    screens/ home, recording, meeting_detail, speakers, settings, models
    widgets/ level_meter, transcript_view, speaker_chip, minutes_view, …
```

Pure-Dart modules (`core/`, `audio/pcm.dart`, `audio/wav_writer.dart`,
`diarization/`, `minutes/minutes_prompt.dart`, `minutes/claude_client.dart`
parsing) are covered by unit tests in `test/`.

## Speaker identification details

* Embeddings are L2-normalised; similarity = cosine.
* **Online** (`SpeakerTracker`): for each segment ≥ 1.0 s, compare to
  meeting-local clusters first, then to global voiceprints. Accept best match if
  `sim ≥ matchThreshold` (default 0.55). Otherwise open a new local cluster,
  labelled `متحدث N`. Segments < 1.0 s inherit the previous speaker if the gap is
  < 1.5 s, else are assigned by best match without creating clusters.
* **Offline refinement** on stop: average-linkage agglomerative clustering over
  all embeddings (threshold `refineThreshold`, default 0.5); clusters are mapped
  back to global speakers by centroid similarity (≥ `enrollThreshold` 0.6 links
  to an existing voiceprint, else a new speaker record is created).
* Voiceprint update: `centroid = normalize((c·n + Σe) / (n + k))`, capped `n`
  at 200 so voices can drift slowly.
* User actions: rename (updates global speaker → all meetings), merge two
  speakers, reassign a single segment, “not a voiceprint” (forget voice).

## Minutes generation

* Transcript is rendered as lines `[hh:mm:ss] <speaker name> (<lang>): text`.
* System prompt (Arabic + English rules): faithful, no invention, Modern
  Standard Arabic, preserve names/numbers/terms (original in parentheses when
  useful), attribute statements to speakers, mark uncertainty.
* Output is constrained by a JSON schema (see `minutes_prompt.dart`) → `Minutes`.
* Request: `model: claude-opus-5-5`, `max_tokens: 64000`, `stream: true`,
  `thinking: {type: adaptive}`, `output_config: {effort: high, format: …}`,
  `fallbacks: "default"` with `anthropic-beta: server-side-fallback-2026-07-01`,
  `anthropic-version: 2026-10-21`. `stop_reason` is checked (`refusal`,
  `max_tokens`) before parsing.
* The user can regenerate minutes after renaming speakers.

## Privacy

* Audio, transcripts and voiceprints stay on device (SQLite + app documents).
* With on-device ASR only the *text transcript* is sent to Claude to write the
  minutes. With cloud ASR, audio segments go to the ASR provider. Both are
  explained in Settings.
* A recording-consent reminder is shown before the first recording.
