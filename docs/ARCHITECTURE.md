# Insato (إنصاتو) — Architecture

Insato turns everything the device microphone hears — in any language — into
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
                                   StructuredMinutesEngine → MinutesBackend
                                   (Gemini by default / Claude / local, structured
                                   JSON, Arabic) → Minutes (+ tasks, codes, notes)
                                   → DB → PDF / Markdown / share
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
| Minutes | `MinutesBackend` chosen in Settings: **Google Gemini** (default, free tier, `gemini-flash-lite-latest`, `responseJsonSchema` with fallbacks) or Claude API `claude-opus-5-5` (adaptive thinking, structured outputs); on-device / local-server engines plug in (F14) | Free by default; faithful, structured Arabic minutes from multilingual transcript |
| Export | PDF (`pdf` + bundled Arabic font), Word, Markdown, plain-text share; v1.2 official layout and uploaded Word templates | Official, printable minutes |
| Multi-device (v1.2 C) | LAN WebSocket (dart:io) + ChaCha20-Poly1305 (package:cryptography), mDNS (bonsoir), QR (qr / mobile_scanner), pure-Dart clock sync, cross-correlation and fusion | No internet, no server; works on Android, iOS and Windows; fully unit-tested on localhost |
| Live call (v1.2) | flutter_webrtc 1.6 (audio + data channel, DTLS-SRTP, STUN / optional TURN); signaling over a configurable WebSocket relay we do not operate (`tools/signaling_server.dart` or the Cloudflare Worker), sealed with a key from the call code | Internet calls between two devices with no Insato server; the relay can neither read nor impersonate |
| Database | drift schema v6 (v1.2: `official_records`, `minutes_versions`, `minutes_signatures`; v1.2 D: `consistency_findings`, `resolution_annotations`), migrations tested from v1–v5 snapshots (real v5 data upgraded in `test/data/migration_test.dart`) | Upgrades keep all data |

## Module layout (`lib/`)

```
lib/
  main.dart                      bootstrap (bindings, DB, ProviderScope)
  app.dart                       MaterialApp, theme, RTL, routes
  core/
    models.dart                  pure domain models (no Flutter imports)  ← CONTRACT
    hijri.dart                   Umm al-Qura ⇄ Gregorian (v1.2)
    interfaces.dart              engine interfaces                         ← CONTRACT
    errors.dart                  InsatoException hierarchy
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
    export_service.dart          Minutes → Markdown / PDF / share text (official layout when given)
  session/
    meeting_session_controller.dart  orchestrates a live recording session
    minutes_engines.dart         engine selection (Gemini / Claude / local / server)
    post_processor.dart          refinement, voiceprint learning, minutes + artifacts
    providers.dart               Riverpod wiring of the whole app
  features/                      v1.1 / v1.2 features (one folder each, see below; v1.2: official/, consistency/, multi_device/, live_call/)
  ui/
    theme.dart, strings_ar.dart, navigation.dart, actions.dart
    screens/ home, recording, meeting_detail (+ tabs), speakers, settings, models
    widgets/ level_meter, transcript_view, speaker_chip, minutes_view, …
```

## v1.1 features and where they are wired

Each feature lives in `lib/features/<name>/` with its own Arabic strings and
tests (`docs/V11-CONTRACTS.md` lists the shared contracts). The shared
layers wire them in:

| Feature | Folder | Wired in |
|---|---|---|
| F1 voice enrollment, F18 microphones | `voice/` | Voice library FAB «إضافة شخص بصوته» and «تحسين البصمة» menus (library, meeting speakers tab); Settings «الميكروفون» (device, far field, mic test); microphone chip on the context form and recording screen; `sessionAudioSourceProvider` → device-aware source; far field → `SessionEngineRequest.farField` → `vadConfigFor`; `Meeting.inputDevice` from `sessionInputDeviceProvider`; voiceprints learned on another microphone match with `knownSpeakerThresholdFor` (`SpeakerTracker.knownSpeakerThresholdOf`) and are re-tagged with `voiceDeviceAfterLearning` after learning |
| F2 glossary, F3 context | `context/` | «اجتماع جديد» (`startNewMeeting` → `startNewMeetingWithContext`: consent, context form with «تخطٍّ وابدأ»); context card + edit on the minutes tab and in the meeting menu; Settings → «قاموس المصطلحات»; Deepgram keyterms via `resolveSessionKeyterms` (includes the upcoming meeting's terms and attendees) |
| F5 evidence | `evidence/` | `EvidenceScope` around the meeting tabs (docked player); `EvidenceChips` under agenda items, topics, decisions and action items (`MinutesView.evidenceBuilder`), tasks and pending updates; `EvidenceTranscriptTab` as the transcript tab |
| F8 ask | `ask/` | Shell destination «اسأل» (`AskMeetingsScreen(embedded: true)`) |
| F9 tasks | `tasks/` | Shell destination «المهام»; meeting tab «المهام» (`MeetingTasksPanel` with pending updates to confirm); `OpenTasksBanner` on the recording screen |
| F12 Word | `export_docx/` | Meeting menu «تصدير المحضر ومشاركته» → `ExportShareSheet` (Word / PDF / Markdown / print) |
| F13 system audio | `system_audio/` + `windows/runner/` | `sessionAudioSourceProvider` → `mixedSessionAudioSourceProvider` (Windows: mic / system / both; elsewhere the microphone); `AudioSourceSelector` in Settings and on the context form (renders nothing off Windows) |
| F14 local engines | `local_llm/` | Settings engine selector (builders from `local_minutes_backends.dart`); GGUF downloads in Settings and on the models screen |
| F16 profiles | `profiles/` | «ملف المتحدث» from the voice library and the meeting speakers tab; `PostProcessor.onMinutesSaved` → `SpeakerProfileService.updateAfterMeeting` after every saved minutes |
| F17 codes | `codes/` | Meeting tab «الرموز والشيفرات»; codes section in Markdown / text exports (`renderCodesSection`) |

## v1.2 official minutes (A) and vote detection (B)

`lib/features/official/` (strings `OS`), wired by the integrator:

| Piece | File | Notes |
|---|---|---|
| Umm al-Qura calendar | `lib/core/hijri.dart` | Table of month lengths 1356–1500 AH (van Gent data set), `UmmAlQura.fromGregorian / toGregorian`, unit-tested against published anchors |
| Vote models | `lib/core/models_v12.dart` | `MinutesDecision.formalText`, `MinutesDecision.vote` (`MinutesVote{mode, positions, announcedResult, evidence}`), `MinutesStyleHint` (`MinutesInputs.style`) |
| Built-in templates | `official_templates.dart` | Generic: team (default), board, general assembly, committee, administrative; sections, numbering, wording, `QuorumRule`, `MajorityRule`, signatories |
| Records & profile | `official_models.dart`, `lib/data/official_repository.dart` | `OfficialRecord` (number, header, attendance, rule overrides, vote reviews, lifecycle) in `official_records`; approved snapshots in `minutes_versions`; vector signatures in `minutes_signatures` (schema v5); `EntityProfile` and uploaded `CustomTemplate`s as JSON settings |
| Pure logic | `official_logic.dart` | Attendance pre-fill, quorum, `tallyVote` / `decideVote`, meeting numbers, canonical content + SHA-256 |
| Render model | `official_document.dart`, `official_outline.dart` | One `OfficialDocument` (+ format-neutral outline following the template's sections) rendered by PDF, Word, Markdown and share text |
| Word templates | `docx_template.dart`, `template_placeholders.dart` | OOXML filling with package:archive + package:xml (split runs, blocks, repeated rows, images), placeholder catalogue, sample template |
| Service | `official_service.dart` | `ensureRecord`, review gate, `approve`, `startNewVersion`, `onMinutesChanged`, `sign`, logo / template files (`AppPaths.brandingDir / templatesDir`) |
| Screens | `official_minutes_screen.dart`, `attendance_screen.dart`, `vote_review_screen.dart`, `signature_pad.dart`, `versions_screen.dart`, `entity_settings_screen.dart`, `template_picker.dart`, `official_summary_card.dart` | Meeting menu «المحضر الرسمي»; card on the minutes tab; template on the context page; Settings «الجهة والقوالب» |

Flow: the template id lives in `MeetingContext.template` (`board`, …, or
`custom:<id>`). `PostProcessor.minutesInputsFor` adds the template's
`MinutesStyleHint` (body, «قرر المجلس …») to the prompt's
`<minutes_template>` block; the schema asks every engine for `formal_text`
and `vote` per decision; `sanitizeVote` drops positions of speakers not in
the transcript, unknown segment ids, downgrades unsupported positions to
«غير واضح», and turns an unsupported voting moment into "none". The app,
never the engine, computes the result under the majority rule. Approval
hashes the canonical content (sorted-key JSON of the minutes without
speaker notes / codes, header, attendance, rules and reviews); regenerating
minutes, changing the template or editing after approval starts a new draft
version (`onMinutesSaved` / context flow). Exports take an optional
`OfficialDocument`; Word uses the meeting's uploaded template when there is
one (PDF keeps the built-in official layout with that template's rules).

## v1.2 contradiction & consistency checker (D)

`lib/features/consistency/` (strings `DS`), storage in
`lib/data/consistency_repository.dart` (schema v6):

| Piece | File | Notes |
|---|---|---|
| Models | `consistency_models.dart` | `FindingKind` (contradicts_resolution, duplicates_task, changes_owner, changes_deadline, revisits_closed_topic, internal_conflict), `FindingSeverity`, `FindingStatus`, `FindingSide` (snapshot of one side: meeting id / title / date / number, item index + key, resolution label, text, owner, due, task id / status, evidence), `ConsistencyFinding`, `ResolutionAnnotation` |
| Memory & heuristics | `consistency_logic.dart` | `buildInstitutionalMemory` (earlier meetings only: approved resolutions ×1.0, other decisions ×0.6, tasks ×0.8 / ×0.5 when closed; superseded resolutions skipped), `newItemsOf` (`D1…`, `A1…`), `retrieveCandidates` (F8 `Bm25Index` + `analyzeSearchText`, ≥ 2 shared terms, top 4), `heuristicFindings` (negation / cancellation words, changed numbers, `similarTaskText` + `personNamesMatch`), `mergeFindings` (a pair found by a rule keeps the rule's finding) |
| Engine request | `consistency_prompt.dart` | `kConsistencySystemPrompt`, strict `consistencyAnswerSchema` (every object closed, all keys required, `prior_ref` nullable, `no_issue` allowed), `buildConsistencyPlan` (budget = `askPromptCharBudget(engine)`; items with candidates first; ≤ 2 evidence lines per item), `parseConsistencyAnswer` (keeps only candidate pairs given in the request, kinds that fit the sides, existing segments; drops findings whose explanation cites unknown `[R7]`, `#44` or resolution numbers; replaces refs by labels), `buildLivePlan` |
| Service | `consistency_service.dart` | `check` (heuristics → engine when there are candidates or ≥ 2 items; engine errors keep the heuristic findings with a notice), `confirm` (decision findings: annotation of the earlier resolution in the same transaction), `dismiss`, `reopen`, `liveCheck` (cloud engines only, nothing stored) |
| Wiring | `consistency_providers.dart` | `consistencyServiceProvider` (engine = `minutesBackendFactoryProvider`), `consistencyCheckProvider(meetingId)` (one run at a time, not auto-disposed), `startAutomaticConsistencyCheck` (called by `MeetingJobsController.generateMinutes` after minutes were saved), `liveConsistencyProvider` |
| UI | `consistency_widgets.dart` | `ConsistencyTab` (6th meeting tab, `ConsistencyTabLabel` badge), `FindingCard` / `FindingSideView` (this meeting: `EvidenceChips`; earlier meeting: `openAskCitation` → source sheet → open meeting), `SupersededResolutionsCard` (earlier meeting's minutes tab and official screen), `LiveConsistencyBanner` (recording screen), `ConsistencyLiveSettingTile` (Settings) |

Approval locks: confirming «تم الإلغاء رسمياً» never edits minutes; it adds
a `resolution_annotations` row keyed by the decision index and
`decisionKeyOf` (shown only while the decision still exists). Approved
minutes therefore keep their content, version and SHA-256; the annotation
is displayed next to them. Re-checks replace only *open* findings; the
`finding_key` (kind + both sides) keeps dismissed / confirmed decisions.
Deleting the checked meeting deletes its findings and annotations; deleting
the earlier meeting nulls `prior_meeting_id` (the snapshot stays readable).

## v1.2 multi-device recording (C)

`lib/features/multi_device/` (strings `MS`). Several phones / PCs in the room
act as one microphone array; everything stays on the LAN.

```
 guest device                                   host device
 mic → GuestAudioFramer (sample index →         MultiDeviceHost (HttpServer + WebSocket)
       CPU time, sliding minimum)                 │ ping/pong every 1 s ──► ClockSyncEstimator (per guest, in MultiDeviceHub)
     → PCM16 + delta/Rice → ChaCha20-Poly1305 ──► │ audio frames (seq, start index, capture µs)
                                                  ▼
 host mic / system audio (mixed source) ─────► FusionEngine
                                                  • guest frame → host clock (NTP offset + drift)
                                                    → host sample index (host CaptureTimestamper)
                                                    + AlignmentTracker correction (envelope xcorr)
                                                  • one ring buffer per device on the host timeline
                                                  • VAD stream = SNR-weighted, gain-matched mix,
                                                    600 ms behind the host capture (archived)
                                                  ▼
                                   VadSegmenter → MeetingSessionController._onSegment
                                                  → SessionSegmentFuser.fuseSegment: best-SNR device's
                                                    samples + ChannelProfile (SNR per device)
                                                  → SessionPipeline.submit(channels:) → SpeakerTracker
                                   stop → finishTake (MultiDeviceMeetingLog) → PostProcessor.refine
                                          (channelProfilesOf → refineSpeakers(channelProfiles))
```

| Piece | File | Notes |
|---|---|---|
| Wire protocol | `protocol.dart` | QR payload `insato://join?v=1&s=&a=&p=&k=&n=`, 12-char Crockford pairing code, message types (hello / welcome / reject / ready / audio / control JSON), `runInSocketZone` (late dart:io socket errors) |
| Security | `secure_channel.dart` | K = PBKDF2-HMAC-SHA256(code, 60 000 it., background isolate); per connection HKDF(K, cn‖sn) → c2s / s2c keys; ChaCha20-Poly1305 frames `[phase][nonce][ct+tag]`; handshake AAD names the direction; session nonces are strictly increasing counters |
| Host server | `host_server.dart` | Admission: authenticated hello (else closed silently), fresh client nonce, version, not removed, ≤ 4 guests; `ready` proves the connection key; a returning guest replaces its old link; idle timeout 6 s; `setState` (lobby / recording / paused / ended), `remove` |
| Guest client | `guest_client.dart` | Tries every host address, answers pings (t2 at arrival, t3 at send), streams `sendAudio`, reports `GuestStatus`; `JoinFailure` → Arabic messages |
| Clocks | `clock_sync.dart` | `MonotonicClock`, `CaptureTimestamper`, `ClockSyncEstimator` (min-RTT filter, least-squares drift over 2 min, ±500 ppm cap) |
| Alignment | `alignment.dart` | Log-envelope onsets at 1 ms, normalised xcorr ±300 ms with parabolic peak; accept peak ≥ 0.35 and ratio ≥ 1.15; apply when two estimates agree within 3 ms |
| Fusion | `fusion_engine.dart` | `ChannelRing` (48 s per device, 10 ms validity blocks), elastic placement (contiguous frames within 3 ms stay contiguous), min-statistics noise floors, mix weights ∝ SNR power (50 ms smoothing), `fuseSegment`, `DeviceTimelineEvent`s |
| Session source | `multi_device_source.dart` | Wraps the normal session source when a hub is open (`sessionAudioSourceProvider` → `multiDeviceAwareSource`); implements `SessionSegmentFuser`; forwards pause / resume / stop to guests |
| Hub & views | `hub.dart` | Per-guest clock, battery, level, loss, `networkQualityOf`, alignment feedback; views throttled to 4 Hz |
| Log | `meeting_log.dart` | `multi_device_log:<meeting id>` in the settings table (devices, events, per-segment profiles); deleted with the meeting (`MeetingRepository.delete`) |
| Providers | `multi_device_providers.dart` | `MultiDeviceHostController` (lobby; closes itself after a meeting that reached recording ends), hub holder (no dependency cycle with the session), `GuestSessionController` (capture via `guestAudioSourceProvider` + `SessionPlatformHooks`, reconnects every 2 s for 3 min) |
| Discovery / battery | `discovery.dart`, `battery.dart` | bonsoir `_insato._tcp`; MethodChannel `insato/battery` (MainActivity.kt, AppDelegate.swift, windows/runner/battery_channel.cpp) |
| UI | `host_lobby_screen.dart`, `guest_screens.dart`, `widgets.dart` | Lobby, join (QR / nearby / manual), guest screen, `GuestTile`, `MultiDeviceRecordingCard` (recording screen), `MultiDeviceLogCard` (minutes tab), `MultiDeviceMenuButton` (meetings app bar) |

Single-device meetings are untouched: without an open hub the session source
is the usual one; a segment without a `ChannelProfile` leaves the tracker
and the refinement exactly as before.

Navigation (D1): the same five destinations on every platform — meetings,
tasks, ask, voice library, settings (`ShellTab`) — in a bottom
`NavigationBar` on phones and a `NavigationRail` with list / detail panes
from 840 px.

## v1.2 live call («مكالمة إنصاتو الحية»)

`lib/features/live_call/` (strings `LCS`). Two devices on the internet:
a WebRTC voice call, each device transcribing its own microphone, the text
exchanged live, one merged meeting saved on each device.

```
 device A (caller)                 relay (wss, free; we run nothing)          device B (callee)
 «بدء مكالمة» → code + QR                                                     «الانضمام» → code / QR
 K = PBKDF2(code); K_call, room = HKDF(K)   ← same on both sides, code never sent →
 join(room) ───────────────────────► pairs ≤ 2 sockets ◄─────────────────── join(room)
      ◄──── sealed hello / welcome / ready (ChaCha20-Poly1305, K_call, then per-connection keys) ────►
      ──── sealed offer (SDP + DTLS fingerprint) ────►   ◄──── sealed answer ────   ⇄ sealed ICE
 ═══════════════════ WebRTC: audio (AEC/NS/AGC) + data channel, DTLS-SRTP, P2P or TURN ═══════════════════
 data channel: auth = MAC(K_call, role ‖ own fp ‖ peer fp) both ways → active; safety code on both screens
 mic → CallTranscriber (VAD ≤ 7 s → Whisper / cloud ASR + embedding → SpeakerTracker)
        → pend / seg / drop ─────────────────── data channel ───────────────────► remote lines
 ping / pong (1 Hz) → ClockSyncEstimator (multi_device) → remote times on the local timeline
 LiveTranscriptBook (both screens) · echo retraction · CallMeetingWriter (rows live, ordered at the end)
 stop → drain → retime → reorder by time → call log → refine → minutes (selected engine)
```

| Piece | File | Notes |
|---|---|---|
| Code, invite, keys | `call_code.dart` | 12-char Crockford code (multi_device helpers), QR `insato://call?v=1&k=&u=&n=`, K_call / room id by HKDF over the multi_device PBKDF2 key (domain-separated), signaling URL normalisation |
| Signaling protocol | `signaling_protocol.dart` | Relay frames (join / joined / peer / relay / ping / error), sealed call messages, SDP fingerprint parsing, fingerprint MACs, six-digit safety code |
| Signaling client | `signaling_client.dart` | `RelaySocket` (dart:io WebSocket; `?room=` added for sharded relays), `CallSignaling`: callee hello → caller welcome → callee ready (reuses multi_device `SecureChannel`: handshake under K_call, per-connection keys, strict counters), refuses a second hello while a callee is connected, frames processed strictly in order |
| Reference relay | `tools/signaling_server.dart`, `tools/signaling/{worker.js,wrangler.toml,Dockerfile}` | Self-contained dart:io relay (≤ 2 per room, size / rate / join / idle limits, logs counts only); Cloudflare Worker + Durable Object per room with the same protocol; Docker image for free container hosts |
| Peer link | `peer_transport.dart`, `webrtc_peer_transport.dart` | `PeerTransport` seam (fake in tests); flutter_webrtc: `getUserMedia` with echoCancellation / noiseSuppression / autoGainControl, negotiated data channel id 0, unified plan, max-bundle, STUN `stun.l.google.com:19302` + optional TURN / relay-only, W3C stats → RTT, loss, jitter, relayed |
| Data channel | `data_messages.dart` | auth, ping / pong, pend, seg (text, language, kind, confidence, speaker id + name), drop, act (speaking / level), mute, bye |
| State machine | `call_engine.dart` | `LiveCallEngine`: idle → preparing → waitingForPeer / connecting → active ⇄ reconnecting → ended / failed; timeouts (caller wait, callee find, handshake, media, auth, reconnect); end reasons; events serialised; clock sync; echo rules; `CallSnapshot` for the UI |
| Merge | `transcript_merge.dart` | `LiveTranscriptBook` ordered by local time, pending → final, provisional remote times fixed once the clock estimate is ready, echo = similar text (≥ 3 words, bigram Dice ≥ 0.75) within 4 s and not earlier (ties: the callee's line) |
| Local transcription | `call_transcriber.dart` | Normal engines with `SessionEngineRequest.maxSegmentSeconds = 7` (`cappedVadConfig`), `SessionPipeline` with a sink that asks the engine first (echo → not stored), pending ids reused as row ids, mute = silence to the VAD |
| Meeting | `call_meeting_writer.dart` | Remote rows `speakerLocked` (no embedding, refinement never moves them), remote speakers by name or «متحدث N (<device>)», deletions for retractions, final renumbering by start time |
| Log, settings, platform | `call_log.dart`, `call_settings.dart`, `call_platform.dart` | `live_call_log:<meeting id>` (deleted with the meeting); `live_call_settings` (relay URL, TURN URL / user, relay-only, device name, consent) + TURN credential in secure storage, `--dart-define=INSATO_SIGNALING_URL` default; Android FGS microphone + mediaPlayback with a «إيقاف البث» button (communication port), wakelock |
| UI | `live_call_screens.dart`, `live_call_settings_screen.dart`, `widgets.dart` | Entry button on the meetings app bar, start / join (QR scan on Android / iOS), consent notice, call screen (code + QR, indicator with one-tap stop, quality, safety code, live transcript, mute, stop; cannot be left while streaming), outcome + open meeting, settings tile, `LiveCallLogCard` on the minutes tab |

Why this signaling. Requirement: free, no server operated by us, no manual
offer/answer copying. Options checked: manual / QR SDP exchange (rejected
for usability: two large blobs each way, and trickle ICE impossible);
public third-party brokers (PeerJS cloud, public MQTT, ntfy) — free but
outside our control, with message-size and rate limits that SDPs hit, and
their availability is not ours to promise; Firebase-style services need an
account and an SDK per platform. Chosen: a configurable WebSocket URL with
a ~250-line reference relay in the repo that anyone deploys once for free
(Cloudflare Workers free plan, or the Docker image on a free container
host), and that is *untrusted by design*: it relays sealed blobs between
the two sockets of a room id, so a malicious or compromised relay can only
deny service. A distributor can bake the URL in with `--dart-define`.

Raw remote audio. flutter_webrtc exposes no remote PCM to Dart on any
platform (audio is rendered natively; `MediaRecorder` writes an AAC file of
the playout on Android and needs a video track on iOS; nothing on Windows).
So each device archives only its own microphone; the other side's speech is
in the meeting as the transcript that device produced (its microphone is
archived there). With speakers instead of headphones the remote voice is
also faintly present in the local recording.

Microphone sharing. WebRTC and the transcription each open the microphone:
Android uses the `voiceCommunication` source for the transcription capture
(platform AEC), iOS gives the audio session to WebRTC
(`AudioRecorder.ios.manageAudioSession(false)`), Windows allows shared
capture. To verify on devices (see the report).

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
  speakers, reassign a single segment, “not a voiceprint” (forget voice),
  delete a speaker.
* Learning from corrections is idempotent through a per-meeting ledger
  (`segment id → speaker id` in the `settings` table, prefix
  `voiceprint_ledger:`). Forgetting a voice, or a merge that drops one side's
  centroid, turns entries into tombstones (`!<speaker id>`): such a segment
  is never learned again while it stays with that speaker, and moving it away
  unlearns nothing. `SpeakerRepository.merge`, `forgetVoice` and `delete`
  rewrite the ledgers of all meetings in their own transaction, so merges
  must go through `PostProcessor.mergeSpeakers` / the repository, never raw
  SQL.
* Live session: renaming the meeting being recorded goes through
  `MeetingSessionController.renameMeeting`, which also updates the session
  title and the Android recording notification
  (`SessionPlatformHooks.onTitleChanged`). While stopping, the user can
  choose “finish later” (`finishLater()`): the remaining queue is dropped and
  the meeting is marked for re-processing from the archived audio.

## Minutes generation

* Transcript is rendered one line per segment with its id,
  `[#42 hh:mm:ss] <speaker name> (<lang>): text`; unintelligible segments
  (F17) appear as `[غير مفهوم — مقطع #n، m ث]`. Evidence arrays in the answer
  cite these ids (see docs/V11-CONTRACTS.md).
* System prompt (Arabic + English rules): faithful, no invention, Modern
  Standard Arabic, preserve names/numbers/terms (original in parentheses when
  useful), attribute statements to speakers, mark uncertainty.
* Output is constrained by a JSON schema (see `minutes_prompt.dart`) → `Minutes`.
* Gemini (default): `POST …/v1beta/models/{model}:streamGenerateContent?alt=sse`
  with `x-goog-api-key`, `systemInstruction`, `generationConfig.responseMimeType
  = application/json` and `responseJsonSchema` (fallback `responseSchema`, then
  plain JSON mode + tolerant repair). `finishReason` / `promptFeedback` are
  checked; 429s are waited out once when short and never hammered
  (`GeminiRateGate`). A missing model triggers `models.list` discovery.
* Claude (optional): `model: claude-opus-5-5`, `max_tokens: 64000`,
  `stream: true`, `thinking: {type: adaptive}`, `output_config: {effort: high,
  format: …}`, `fallbacks: "default"` with `anthropic-beta:
  server-side-fallback-2026-07-01`, `anthropic-version: 2026-10-21`.
  `stop_reason` is checked (`refusal`, `max_tokens`) before parsing.
* The answer is validated (`sanitizeMinutes`: evidence ids, agenda order,
  known task ids, opted-in speakers only) and its tasks / pending task
  updates / speaker notes / code findings are stored with the minutes
  (`MinutesArtifactsWriter`).
* The user can regenerate minutes after renaming speakers.

## Privacy

* Recordings, transcripts and voiceprints are stored only on device (cloud
  ASR sends audio segments to Deepgram, see below). Data root
  (`AppPaths`): the app documents directory on Android/iOS (excluded from
  backups); `%LOCALAPPDATA%\Insato\Insato` on Windows (never Documents, which
  is shared and often OneDrive-synced; v1 data is migrated from there at
  start-up, before the database opens). `Meeting.audioPath` stores only the
  file name; readers resolve it with `AppPaths.resolveRecording`, and
  `MeetingRepository.delete` removes the file from the current recordings
  directory (`recordingsDirProvider`) as well as a legacy absolute path.
* With on-device ASR only the *text transcript* is sent to the selected
  minutes engine (Google Gemini by default — on its free tier Google may use
  the content to improve its products, which Settings states and the user
  accepts before the first request — or Anthropic Claude; nothing with a local
  engine). With cloud ASR, audio segments go to Deepgram; every request sets
  `mip_opt_out=true` (no use for model training), but retention is governed
  by Deepgram's data policy. Both are explained in Settings and in the
  consent reminder.
* API keys live only in flutter_secure_storage. On iOS the keychain items
  use `AfterFirstUnlockThisDeviceOnly` (readable while locked during a
  background recording; never migrated to another device); `main()` calls
  `SecureSettings.migrateAccessibility()` once in the foreground to rewrite
  keys stored with the old class. A keystore read failure raises
  `SecureStorageUnavailableException`, which is never treated as "no key":
  cloud ASR keeps the key read earlier in the session (or fails the segment
  as transient), automatic minutes are postponed
  (`MinutesOutcome.postponedKeyUnavailable`), and Settings shows the key
  state as unknown.
* A recording-consent reminder is shown before the first recording.
* Multi-device meetings (v1.2 C): guest audio goes only to the host over the
  LAN, encrypted and authenticated with a key derived from the join code
  (never transmitted); guests store nothing; the host advertises only its
  device name and session id over mDNS while the lobby is open.
* Live call (v1.2): started by a person on each device (consent notice
  before the first call); audio DTLS-SRTP peer-to-peer or via the user's
  TURN; the signaling relay only sees a room id, IP addresses and sealed,
  authenticated setup messages; text and speaker names cross the encrypted
  data channel, voiceprints never; each device stores its own microphone,
  the merged transcript and the call log; persistent indicator + one-tap
  stop, Android ongoing notification; the call ends with the app.
