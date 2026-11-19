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
