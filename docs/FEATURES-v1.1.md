# Insato v1.1 — Feature spec

Features requested by the owner after v1: 1, 2, 3, 5, 8, 9, 12, 13.

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
0. **Cloud — Google Gemini** (DEFAULT, owner decision: free tier, key from
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

## A — Official Arabic minutes (المحضر الرسمي المعتمد)
* Templates (selected per meeting, F3 `template`): مجلس إدارة، جمعية عمومية،
  لجنة، اجتماع حكومي/إداري، اجتماع فريق (مبسّط). Each template defines
  sections, numbering style and wording conventions.
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
