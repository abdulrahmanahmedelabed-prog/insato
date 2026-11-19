# Katib v1.1 — Feature spec

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
Settings → “محرك كتابة المحضر” with three choices (all implement `MinutesEngine`):
1. **Cloud — Claude** (default, highest quality): `claude-opus-5-5` as in v1.
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
