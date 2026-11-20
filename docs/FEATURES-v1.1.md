# Insato v1.1 — Feature spec

Features requested by the owner after v1: 1, 2, 3, 5, 8, 9, 12, 13.

## Status (integration, 2026-11-19)

| Feature | State | Reachable from |
|---|---|---|
| F1 voice enrollment | Implemented, wired | Voice library «إضافة شخص بصوته», «تحسين البصمة» |
| F2 glossary | Implemented, wired (Deepgram keyterms, minutes prompt) | Settings → «قاموس المصطلحات»; codes tab (promote jargon) |
| F3 meeting context | Implemented, wired | «اجتماع جديد» form; minutes tab card; meeting menu |
| F5 evidence links | Implemented, wired | ▶ chips in minutes, tasks, codes; docked player |
| F8 ask your meetings | Implemented, wired | Destination «اسأل» |
| F9 task tracking | Implemented, wired | Destination «المهام»; meeting tab; recording banner |
| F12 Word export | Implemented, wired | Meeting menu → export sheet |
| F13 Windows system audio | Implemented, wired; native code not yet built with MSVC | Settings and context form (Windows only) |
| F14 engines | Gemini (default), Claude, on-device GGUF, local server; wired | Settings → minutes engine; models screen |
| F15 unknown speakers | Partly: auto labels, saved voiceprints (≥ 3 s of speech), rename everywhere, merge; the «low confidence» flag for brief voices is not set yet | Voice library |
| F16 speaker profiles | Implemented, wired; updated after every minutes | Voice library / meeting speakers menu «ملف المتحدث» |
| F17 codes | Implemented, wired (tab, exports) | Meeting tab «الرموز والشيفرات» |
| F18 external microphones | Implemented, wired (device on the meeting, far-field VAD, relaxed matching across microphones) | Settings «الميكروفون»; context form; recording screen |
| D1 Windows = mobile | Same destinations and widgets; layout by width | — |

Needs real devices: native capture/playback, llama.cpp runtime, WASAPI
loopback (`windows/runner/`), Hugging Face GGUF availability.

## F1 — Voice enrollment (تسجيل بصمة صوتية مسبقاً)
* Screen “إضافة شخص بصوته”: enter a name, read a displayed Arabic/English
  paragraph for ~10–15 s, live level meter + quality checks (enough voiced
  speech ≥ 8 s after VAD, not clipped, not too quiet).
* Embeddings are computed per VAD segment (and on 3 s sliding windows), the
  centroid is stored on a `Speaker` with `isNamedByUser = true`.
* “Improve voice” on an existing speaker appends a new sample
  (weighted centroid update).
* Enrolled speakers are matched from the first segment of every meeting.

## F2 — Custom vocabulary (قاموس المصطلحات)
* `glossary_terms` table: term, optional Arabic spelling/translation, category
  (person / organisation / technical / other), created_at.
* Used in three places:
  1. Deepgram cloud ASR: `keyterm` query params (nova-3).
  2. Minutes prompt: “canonical spellings” list — the model must correct
     recognition errors toward these spellings when context supports it.
  3. Per-meeting context (F3) can add meeting-only terms.
* Speaker names of named speakers are automatically part of the glossary.

## F3 — Pre-meeting context (سياق الاجتماع)
* New meeting fields: `agenda` (ordered list), `expectedAttendees` (list),
  `contextNotes` (free text), `template` (reserved).
* Editable before start (optional sheet on “اجتماع جديد”) and afterwards.
* Minutes prompt: when an agenda exists, `topics` follow agenda order and each
  agenda item is reported (discussed / not discussed).

## F5 — Evidence links to audio (ربط كل بند بلحظته)
* Transcript is rendered with segment ids: `[#42 00:12:31] Name (lang): …`.
* Schema adds `evidence: [segment ids]` (integers) to topics, decisions,
  action items.
* UI: each item shows ▶ chips; tapping plays the archived WAV from the
  segment start (with 1 s pre-roll) and highlights the transcript line.
  Player via `audioplayers` (Android/iOS/Windows support).
* If audio was not kept, the chip jumps to the transcript line instead.

## F8 — Ask your meetings (اسأل اجتماعاتك)
* Chat screen; question in any language, answer in Arabic.
* Retrieval (pure Dart): BM25 over transcript segments + minutes text of all
  meetings with Arabic normalisation (alef/ya/ta-marbuta/diacritics, light
  stemming); top meetings' minutes + top-k transcript windows are packed into
  the prompt (budgeted by characters).
* Claude answers with citations `[meeting title — hh:mm:ss]` mapped to
  clickable links (open meeting at that segment).
* Conversation history kept per session (not persisted by default).

## F9 — Action-item tracking (تتبّع المهام)
* `tasks` table populated from minutes action items: task, owner (speaker id
  or free text), due text, status (open / done / cancelled), source meeting +
  evidence segment, created/updated timestamps.
* Tasks screen: filter by status / owner, mark done, edit.
* Next meeting: open tasks are passed to the minutes prompt; schema adds
  `task_updates: [{task_id, new_status, note, evidence}]` so the minutes
  report progress; updates are applied after user confirmation.
* On recording start: banner listing open tasks of expected attendees.

## F12 — Word export & email (تصدير Word وإرسال)
* Pure-Dart DOCX writer (OOXML via `archive` zip): RTL (`w:bidi`, `w:rtl`),
  Arabic font Noto Naskh Arabic / fallback, headings, bullet lists,
  action-items table, signature block (أسماء الحضور / التوقيع).
* Share sheet with subject “محضر اجتماع: …” and body text summary; attaches
  PDF or DOCX (email apps appear in the share sheet).

## F13 — Windows system-audio capture (تسجيل صوت Zoom/Teams)
* Native Windows plugin (C++, WASAPI shared-mode loopback on the default
  render endpoint) exposed via EventChannel streaming float PCM + format info.
* Dart side resamples to 16 kHz mono and mixes with the microphone
  (sum with soft limiter) — the session can choose: mic only / system only /
  both (default both on Windows).
* Handles device changes (default endpoint switch) and silence (loopback
  delivers no packets when nothing plays — fill with zeros by wall clock).

## F14 — Minutes engine: local or cloud (محرك المحضر: محلي أو سحابي)
Settings → “محرك كتابة المحضر” with these choices (all are a `MinutesBackend`
behind the one `StructuredMinutesEngine`, see docs/V11-CONTRACTS.md):
0. **Cloud — Google Gemini** (DEFAULT, owner decision: free tier, model `gemini-flash-lite-latest`, key from
   Google AI Studio). Settings shows honestly that on the free tier Google may
   use prompts/responses to improve its products and human reviewers may read
   them (a billed Cloud project is treated as paid); the user accepts this
   before the first request. Rate limits are respected (never hammered).
1. **Cloud — Claude** (optional, highest quality): `claude-opus-5-5` as in v1.
2. **On-device** (fully offline, private): GGUF model run in-process via
   `llamadart` (llama.cpp; Android / iOS / Windows). Model catalog entries
   with sizes and RAM requirements, downloaded through `ModelManager`, e.g.
   a ~4B instruct model with strong Arabic (Q4_K_M) as the recommended
   default for phones and a ~8–14B model for Windows PCs with ≥ 16 GB RAM.
   JSON output constrained by grammar/JSON-schema when the runtime supports
   it, otherwise strict prompt + tolerant parser + one repair pass.
   Long transcripts are processed map-reduce (chunk summaries → final
   minutes) to fit the local context window.
3. **Local server** (Windows/LAN power users): Ollama (`/api/chat` with
   `format` = JSON schema) or any LM Studio endpoint, configurable URL + model.
* The UI states the quality/speed trade-off honestly; the chosen engine and
  model are recorded on each minutes (`Minutes.model`).
* “Ask your meetings” (F8) uses the same engine choice.

## F15 — Unknown speakers always get a voiceprint (المتحدث غير المعروف)
Recognition is never a precondition:
* Any voice that does not match a known voiceprint immediately gets a
  temporary label (`متحدث N`, N unique across the voice library) and a Speaker
  record **with its voiceprint saved** at the end of the meeting — named or
  not — so the same voice is recognised as the same `متحدث N` next time.
* Renaming at any time (during or after the meeting, from transcript, speaker
  tab or voice library) updates every past meeting and future recognition.
* Voices heard only briefly (< 3 s total speech) are kept as speakers but are
  flagged “low confidence”; their voiceprint is not used for matching until
  more speech accumulates, to avoid false matches.
* Library hygiene: “merge duplicates” suggestions when two unnamed voiceprints
  are very similar; unnamed speakers unseen for N months can be cleaned up
  (manual action only).

## F16 — Speaker profile: communication style & demonstrated skills (ملف المتحدث)
For each speaker, a profile aggregated across **all** meetings, whatever the
language(s) spoken and the domains discussed (translation-invariant: the
analysis runs on meaning, output in Arabic).

Contents (every claim carries evidence links — meeting + timestamp, F5):
* **Demonstrated knowledge & skills** by domain (e.g. مالية، هندسة برمجيات،
  قانون، تسويق) with level indicators *as evidenced in speech* (mentions,
  explanations given, questions answered, decisions led) and trend over time.
* **Languages used** and share of speech per language; code-switching habits.
* **Communication style**: talk-time share, turn length, questions asked vs.
  statements, interruptions given/received, clarity, how often they propose
  vs. decide vs. take tasks, follow-through on tasks (F9).
* **Contributions**: decisions proposed, action items owned / completed.
* **Narrative summary** (strengths observed, typical role in meetings).

Guardrails (built in, not optional):
* Opt-in per speaker (“تفعيل ملف المتحدث”), off by default; a notice that the
  person should be informed. Profiles stay on device; deletable at any time.
* Only *observable, evidence-backed* behaviour from what was said. No
  clinical/psychological diagnosis, no inferences about emotions from voice,
  health, religion, politics, ethnicity, age, or other sensitive attributes,
  and no hiring/firing “scores”. Low-evidence items are marked as such or
  omitted. Wording is descriptive, never judgemental.
* Built incrementally: per-meeting speaker notes are extracted together with
  the minutes (same engine: Claude / on-device / local server), then merged
  into the profile; “rebuild profile” recomputes from all meetings.

## F17 — Codes, jargon, hidden meanings & references (الشيفرات والرموز)
A dedicated tab “الرموز والشيفرات” in each meeting, and a section in the
minutes. Every item shows **who said it** (speaker) and **when** (evidence
link, F5). Five detectors:

1. **Coded / obfuscated speech (كلام مرمّز أو غير مفهوم):** speech the VAD
   detected but that does not decode as a known language — invented or
   “secret” languages, reversed or letter-shuffled words, spelled-out letter
   or number sequences, heavy whispering.
   * Pipeline change (important): such segments are **never silently
     dropped**. When ASR returns empty / low-confidence / hallucination-filtered
     output for real speech, the segment is stored with
     `kind = unintelligible` and its audio kept, instead of being discarded.
   * Characterisation: duration, speaker, whether it looks like a real but
     unsupported language, a known transformation (e.g. reversed speech —
     the app can re-run ASR on time-reversed audio), letters/numbers, or
     unknown.
   * Interpretation only as clearly labelled *hypotheses* with confidence and
     evidence; the app never claims to have “broken” a code.
2. **Internal codes & jargon (رموز ومصطلحات داخلية):** project codenames,
   abbreviations, team slang — detected, meaning inferred from context
   (labelled “مستنتج”), first use, who uses them most; can be promoted to the
   glossary (F2) with a confirmed meaning.
3. **Spoken source code (كود برمجي يُقال شفهياً):** dictated code, commands,
   function/variable names, SQL, URLs — reconstructed into properly
   formatted code blocks with language detection, a short explanation and
   potential issues, attributed to the speaker; exportable.
4. **Indirect / implied speech (كلام مُلمَّح):** hints, euphemisms, implied
   requests or objections — flagged cautiously with the literal text, the
   possible meanings and why; never presented as fact.
5. **Reference numbers & identifiers (أرقام ورموز مرجعية):** contract,
   invoice, ticket, legal-article, product and account numbers, amounts,
   dates — extracted exactly (digits verified against the transcript),
   normalised, attributed, and listed in a table.

Engine: extracted together with the minutes (same engine choice F14) via
an extra `codes` section of the JSON schema; detector 1 also uses audio-level
signals from the ASR stage. Same transparency rules as F16: findings are
descriptive and evidence-backed; participants should be informed that
meetings are recorded and analysed.

## D1 — Windows = mobile (تطابق كامل بين ويندوز والجوال)
Owner requirement (clarified): the Windows app is the same app as the phone
app — same features, settings, theme, colours, fonts, icons, strings,
components and visual identity — while the **layout adapts to the screen
width** so it uses a large Windows window well.
* Responsive layout: phone width → bottom NavigationBar, single column;
  wide window (≥ 840 px) → NavigationRail + master/detail panes; the window
  opens maximised-friendly (default ≈ 1280 × 800, min 400 × 640).
* No desktop-only or mobile-only features or screens; the same widgets render
  on both, only arranged differently by width.
* Only extra on Windows: the audio-source selector (mic / system audio /
  both, F13), because phones cannot capture other apps' audio. Keyboard
  shortcuts are invisible conveniences.
* Golden tests render key screens at phone and desktop widths.

## F18 — External microphones (المايكات الخارجية)
* Input-device selector on all platforms (Settings + recording screen), using
  `record`'s `listInputDevices`; remembers the last device; falls back to the
  default device if it disappears mid-meeting (without stopping recording).
* “اختبار المايك” screen: live level, clipping/too-quiet warnings, a 5 s test
  recording with playback, and a distance tip.
* Far-field profile toggle (“اجتماع في قاعة”): enables automatic gain and
  noise suppression where the platform supports them; VAD threshold tuned for
  quieter distant speech.
* Bluetooth headsets are flagged as lower quality (narrow-band call profile).
* Voiceprints remember the device they were learned on; when a meeting uses a
  different mic, matching thresholds are relaxed slightly and voiceprints are
  updated from confirmed segments so they adapt to the new mic.

---
# v1.2 — Differentiators (approved: A, B, C, D)
Goal: Insato becomes *the* app for official Arabic minutes. Scheduled after
v1.1 is verified on real devices.

## Status (v1.2 A + B + C + D, 2026-11-20)

| Item | State | Reachable from |
|---|---|---|
| A templates | Built-in, generic: مجلس إدارة، جمعية عمومية، لجنة، اجتماع إداري/حكومي، اجتماع فريق (مبسّط، الافتراضي). Each defines sections, numbering (أولاً… / 1. / قرار رقم n/meeting/year), wording (`resolutionLead`), quorum rule, majority rule (+ chair casting vote), signatories | Context page «نوع المحضر»; official screen |
| A uploaded Word templates | `.docx` with `{{placeholders}}` (full list in Settings and in `template_placeholders.dart`), validated on upload (real .docx, ≤ 10 MB, ≥ 1 known placeholder), linked to a built-in template's rules, chosen per meeting; sample template download | Settings → «الجهة والقوالب» |
| A «learn the structure from a sample» | **Not done** (optional item; placeholder path prioritised) | — |
| A entity profile | Name, logo (PNG/JPG, app data), councils/committees, default chair/secretary/place, numbering year (Hijri/Gregorian) | Settings → «الجهة والقوالب» |
| A meeting number | Auto sequence per entity + committee + year (`12/1448هـ`, `12/2026`), editable | Official screen → «بيانات المحضر» |
| A dates | Umm al-Qura converter (`lib/core/hijri.dart`, table 1356–1500 AH) + Gregorian in header and every export | Official screen, exports |
| A attendance & quorum | Present / absent with / without excuse / guests, pre-filled from expected attendees + voices, editable; quorum stated | Official screen → «كشف الحضور» |
| A resolutions | `formal_text` per decision (template wording), numbered, with evidence and vote result | Official screen; exports |
| A lifecycle | draft → reviewed (blocked while unclear votes matter) → approved (locked, SHA-256 of canonical content); edits / regeneration / template change after approval → new draft version; history kept | Official screen; «سجل الإصدارات» |
| A signatures | Finger / pen strokes stored as vector JSON with signer, role, time and hash; drawn as vectors in PDF, as PNG in Word | Official screen → «توقيع» |
| B vote detection | Schema `decisions[].vote {mode, announced_result, positions[{speaker, position, evidence}], evidence}`; consensus = «توافق دون تصويت رسمي»; validation drops unknown speakers / segments and downgrades unsupported positions to «غير واضح» | Engine (all backends) |
| B tally | Simple / absolute / two-thirds / unanimity, chair casting vote, unclear positions → «بحاجة إلى تأكيد» only when they could change the outcome | Pure Dart (`official_logic.dart`) |
| B secretary review | Confirm / correct positions and mode per resolution | Official screen → «مراجعة التصويت» |
| PDF for uploaded templates | PDF uses the built-in official layout with the linked template's rules (a .docx cannot be rendered to PDF on device); Word uses the uploaded file | Export sheet |
| D institutional memory | Approved resolutions (weight 1.0), decisions of non-approved minutes (0.6), open (0.8) and closed (0.5) tasks of meetings *before* the checked one, indexed with the F8 BM25 + Arabic analysis; resolutions marked «أُلغي رسمياً» are left out | `consistency_logic.dart` |
| D checker | After every minutes generation (background) and on demand: pure-Dart heuristics first (same decision again, negation / cancellation, changed numbers, duplicated task, other owner / deadline, closed task re-assigned, conflicts inside the meeting), then one structured request to the selected engine (strict schema) classifying the candidate pairs; references, numbers and segments the engine cites are validated, the rest dropped; engine failure keeps the heuristic findings with a notice | Meeting tab «التناقضات» (badge = open findings) |
| D findings | Stored per meeting (schema v6 `consistency_findings`), both sides as snapshots (meeting title / number / Hijri + Gregorian date, resolution label, text, owner / deadline, evidence) with severity and origin; re-checks keep dismissed / confirmed ones | Tab «التناقضات» |
| D actions | Dismiss; «تم الإلغاء رسمياً» → annotation of the earlier resolution (`resolution_annotations`) shown on its meeting (minutes tab and official screen) — never an edit, so approved minutes keep their content, version and hash; task findings «تأكيد»; undo | Tab «التناقضات»; earlier meeting's minutes tab / «المحضر الرسمي» |
| D live mode | Off by default (Settings → «فحص التناقضات أثناء التسجيل»); every 4 minutes while the recording screen is open, the latest lines + related earlier items go to the selected engine **only if it is a cloud engine already accepted**; subtle banner + details sheet; nothing stored | Recording screen |
| D not done | Annotations are not printed in exports (PDF / Word) yet; live checks pause while the recording screen is not shown | — |
| C entry points | Host: devices menu above the meetings list → «اجتماع متعدد الأجهزة» (lobby: QR + 12-character code + LAN address, joined devices, «بدء الاجتماع» runs the normal new-meeting flow). Guest: same menu → «الانضمام كجهاز إضافي» (QR scan on Android / iOS via mobile_scanner; Windows: code + address typed; nearby hosts via mDNS) → minimal guest screen (status, level, leave) | Meetings screen app bar |
| C transport & security | WebSocket (dart:io) on the LAN, no internet; ChaCha20-Poly1305 with keys from PBKDF2(code) + HKDF(per-connection nonces); per-direction message counters (replay / reorder rejected); unauthenticated peers closed without an answer; replayed hello refused; max 4 guests; removed devices refused for the meeting | `secure_channel.dart`, `host_server.dart`, `guest_client.dart` |
| C discovery | mDNS / DNS-SD `_insato._tcp` via package:bonsoir (Android NSD, Apple Bonjour, Windows DNS-SD); QR / manual address always work | `discovery.dart` |
| C audio | 16 kHz mono PCM16 frames (≤ 100 ms) with capture timestamps, lossless delta + Rice compression (no maintained cross-platform Opus encoder for Dart) | `pcm_codec.dart` |
| C clock alignment | NTP-style ping / pong every second (min-RTT filtering, offset + drift regression), capture timestamps by sliding minimum, refined by envelope cross-correlation of overlapping audio (accepted only when strong and unambiguous, applied when two estimates agree); simulated skewed clocks (5.3 s offset, 80 ppm drift, 110 ms unknown input latency, network jitter) align to < 3 ms (target < 20 ms) | `clock_sync.dart`, `alignment.dart`, `fusion_engine_test.dart` |
| C fusion | VAD runs on an SNR-weighted, gain-matched mix delayed 600 ms (one device: the host signal unchanged); per VAD segment the best-SNR device's audio goes to ASR and embedding; SNR per device is the segment's `ChannelProfile` | `fusion_engine.dart`, `multi_device_source.dart` |
| C diarization cue | "Nearest device" proximity: `SpeakerTracker` shifts close calls between local clusters by ≤ 0.05 (never the thresholds); offline refinement clusters voice + proximity (`augmentWithChannelCue`, β² = 0.08) with voice-only centroids; no profile → unchanged behaviour | `channel_cue.dart`, tracker, clustering |
| C robustness | A guest dropping out leaves the meeting running; the guest retries for 3 minutes and returns to its channel; joins / drops / returns / removals and per-device counters are stored with the meeting (`multi_device_log:<id>`) and shown on its minutes tab | `meeting_log.dart`, `MultiDeviceLogCard` |
| C status UI | Per guest: connected, battery (own MethodChannel: Android BatteryManager, iOS UIDevice, Windows GetSystemPowerStatus — battery_plus conflicts with wakelock_plus), network quality (RTT, loss, late frames), level meter, alignment, remove | Lobby + recording screen card |
| C not done | Opus (no maintained encoder); guests do not buffer audio while disconnected (the gap is logged instead); the archive WAV is the live mix (re-processing from audio uses it, not per-device audio); a guest records only its microphone (not Windows system audio); real-device verification pending (see report) | — |


## A — Official Arabic minutes (المحضر الرسمي المعتمد)
* Templates (selected per meeting, F3 `template`): مجلس إدارة، جمعية عمومية،
  لجنة، اجتماع حكومي/إداري، اجتماع فريق (مبسّط). Each template defines
  sections, numbering style and wording conventions. Owner decision
  (2026-11-20): templates stay generic (any institution); an institution's
  own layout is uploaded as a Word template with placeholders.
* Official header: entity name/logo (settings), meeting number (auto
  sequence per entity/committee), place, Hijri **and** Gregorian date
  (Umm al-Qura via `intl`/custom converter, unit-tested), start/end time,
  chair (رئيس الاجتماع) and secretary (أمين السر).
* Attendance: present / absent (with/without excuse) / invited guests,
  matched against expected attendees (F3) and voiceprints; **quorum** rule per
  template (e.g. ≥ half + 1, configurable) → “اكتمل النصاب / لم يكتمل”.
* Numbered resolutions (قرار رقم 1/2026/…) with formal phrasing
  (“قرر المجلس …”), linked to votes (B) and evidence (F5).
* Approval & signatures: minutes lifecycle draft → reviewed → approved;
  each attendee signs on device (finger/pen signature captured as vector,
  stored with timestamp); signature block rendered in PDF/DOCX; a SHA-256 hash
  of the approved content is printed in the footer, any later edit creates a
  new version (version history kept).

## B — Vote detection (رصد التصويت)
* The minutes engine identifies voting moments (explicit “نصوّت / من
  الموافق”, rounds of agreement, objections, abstentions) and each speaker's
  position: موافق / معترض / ممتنع / لم يصوّت, with evidence links.
* Result per resolution: counts, names per position, pass/fail per the
  template's majority rule (simple / two-thirds / unanimity); chair's casting
  vote rule optional.
* Never invents votes: implicit consensus is reported as “توافق دون تصويت
  رسمي”; ambiguous positions are listed as “غير واضح” for the secretary to
  confirm in a review screen before approval.

## C — Multi-device recording (عدة أجهزة كمايك واحد)
* One device hosts the meeting; 1–4 other phones/PCs join over the local
  network (QR code with session id + key; discovery via mDNS where allowed,
  manual IP fallback). No internet required.
* Each node streams 16 kHz PCM (or Opus) + timestamps to the host over an
  encrypted WebSocket (key from the QR). Clock alignment: NTP-style ping
  exchange + cross-correlation of overlapping audio to refine offsets to
  < 20 ms; drift tracked continuously.
* Host fuses channels: per VAD segment choose the channel with the best SNR
  for ASR (or weighted mix); channel energy differences are an extra
  diarization cue (which device is nearest a speaker) combined with voice
  embeddings.
* Robust to a node dropping out (meeting continues; gap noted); battery and
  network-quality indicators per node.

## E — Offline meeting packages (حزمة الاجتماع)

Status: implemented (`lib/features/meeting_package/`, tests in
`test/features/meeting_package/`).

* Export from any meeting: one `.insato` file (ZIP) with a manifest (app /
  schema / format version, device name, start wall clock + monotonic clock
  at export, meeting id, title), the transcript with timestamps, the local
  speakers, optionally the WAV recording (remembered per settings) and the
  minutes; voiceprints only on explicit opt-in (default off). SHA-256 per
  entry in the manifest; optional password (AES-256-GCM, PBKDF2).
* Transfer by any means: USB, Bluetooth / Nearby Share / AirDrop, SD card,
  e-mail. Android "open with" / share and iOS "Open in" deliver the file to
  the import flow; the file picker works on every platform.
* Import as a new meeting, or merge into an existing one: offset from the
  wall clocks refined by audio cross-correlation (multi-device aligner) when
  the recordings overlap; segments ordered by aligned time with the source
  device in new speaker names (`متحدث N (جهاز: …)`); duplicates heard by
  both devices keep the better-SNR text; remote speakers mapped to the voice
  library by voiceprint (if included) or by user-given name; speaker
  refinement re-run; offer to regenerate minutes.
* Merge preview (device, duration, overlap, offset, duplicates, speakers),
  progress, undo of the last merges (snapshot).

## D — Contradiction & consistency checker (كاشف التناقضات)
* Institutional memory: all approved resolutions and tasks (F9) are indexed
  (F8 retrieval).
* After minutes generation (and optionally live every few minutes), the
  engine checks new statements/decisions against prior ones and reports:
  contradicts a previous resolution, duplicates an existing task, changes an
  owner/deadline, revisits a closed topic, or conflicts within the same
  meeting.
* Each finding cites both sides (meeting, resolution number, timestamp) and a
  severity; the user can dismiss or confirm (“تم الإلغاء رسمياً”) which
  updates the earlier resolution's status.
