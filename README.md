<div dir="rtl">

# كاتب — محاضر الاجتماعات بالذكاء الاصطناعي

**كاتب** تطبيق Flutter يعمل على **Android وiOS وWindows**. يسجّل كل ما يسمعه
ميكروفون الجهاز **بأي لغة**، ويفرّغه نصياً، ويميّز المتحدثين **بأصواتهم**،
ثم يكتب **محضر اجتماع احترافياً باللغة العربية الفصحى** باستخدام Claude.

[English below ↓](#katib--ai-meeting-minutes)

## ماذا يفعل كاتب؟

1. تضغط «اجتماع جديد» ويبدأ التسجيل؛ يستمر حتى مع إطفاء الشاشة.
2. يكتشف كاتب مقاطع الكلام ويتجاهل الصمت، ثم يفرّغ كل مقطع بلغته الأصلية
   (العربية واللهجات والإنجليزية والفرنسية وغيرها، بما في ذلك الخلط بين اللغات
   في الجملة الواحدة).
3. يستخرج **بصمة صوتية** لكل مقطع، ويسمّي المتحدثين تلقائياً «متحدث 1»،
   «متحدث 2»… أثناء الاجتماع.
4. يمكنك إعادة تسمية أي متحدث (مثلاً «متحدث 2» ← «أ. سارة»)؛ يتذكّر كاتب
   الصوت ويتعرّف على صاحبه باسمه في الاجتماعات القادمة.
5. عند الانتهاء يُحسِّن كاتب توزيع المتحدثين على كامل التسجيل، ثم يكتب المحضر
   بالعربية: الملخص، والحضور، والمحاور، والقرارات، والمهام مع المسؤولين
   والمواعيد، والنقاط المعلّقة.
6. تصدير المحضر PDF (بخط عربي مضمَّن) أو Markdown، ومشاركته مباشرة.

## المزايا

- **تفريغ على الجهاز** دون إنترنت باستخدام Whisper (عبر sherpa-onnx)، يدعم
  نحو 99 لغة.
- **تفريغ سحابي اختياري** عبر Deepgram (`nova-3`، متعدد اللغات) لمن يريد أعلى
  دقة ويقبل إرسال الصوت إلى مزوّد الخدمة.
- **تمييز المتحدثين بالصوت**: تعيين فوري أثناء التسجيل، ثم تحسين نهائي بعد
  الإيقاف (تجميع هرمي للبصمات).
- **مكتبة أصوات دائمة**: إعادة التسمية والدمج وتصحيح مقطع واحد ونسيان بصمة.
- **محاضر عربية رسمية** بأمانة تامة للنص: لا اختلاق، مع الحفاظ على الأسماء
  والأرقام والمصطلحات، ونسبة كل قول إلى قائله، والإشارة إلى مواضع الشك.
- **إعادة توليد المحضر** بعد تصحيح أسماء المتحدثين.
- **واجهة عربية أولاً** (من اليمين إلى اليسار) بتصميم Material 3، وتخطيط يتكيّف
  مع عرض الشاشة (الهاتف ونافذة Windows الكبيرة).
- **تسجيل طويل موثوق**: خدمة مقدّمة (Foreground Service) على Android، ووضع
  الصوت في الخلفية على iOS، ومنع السكون أثناء التسجيل.

## البنية باختصار

```
الميكروفون (PCM16، ‏16 kHz، أحادي)
  → كاشف الكلام Silero VAD
  → خيط معالجة منفصل (Isolate): التفريغ (Whisper أو Deepgram) + البصمة الصوتية
  → متتبّع المتحدثين (مطابقة فورية مع البصمات المحفوظة)
  → قاعدة البيانات (SQLite عبر drift) والواجهة الحية
  → عند الإيقاف: تحسين التجميع ← Claude ← المحضر ← PDF / Markdown / مشاركة
```

التفاصيل الكاملة في [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## البناء والتشغيل

المتطلبات العامة: Flutter ‏3.50.0 (القناة المستقرة). دليل المطوّر الكامل في
[docs/SETUP.md](docs/SETUP.md).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # توليد كود drift
flutter test
```

| المنصة | المتطلبات | أمر البناء |
|---|---|---|
| Android | ‏JDK 17، ‏Android SDK 36؛ أدنى إصدار Android 7.0 (API 24) | `flutter build apk --release --split-per-abi` |
| iOS | ‏macOS مع Xcode حديث؛ أدنى إصدار iOS 15 | `flutter build ios --release` |
| Windows | ‏Visual Studio 2022 مع «Desktop development with C++»؛ ‏Windows 10 (1903) أو أحدث | `flutter build windows --release` |

نسخ الإصدار الجاهزة تُبنى تلقائياً عبر GitHub Actions عند دفع وسم `vX.Y.Z`
(انظر قسم «الإصدار» في docs/SETUP.md).

## التشغيل الأول: تنزيل النماذج

لا تُضمَّن نماذج الذكاء الاصطناعي داخل التطبيق للحفاظ على صغر حجمه؛ يُنزّلها
كاتب مرة واحدة من صفحة إصدارات sherpa-onnx الرسمية على GitHub عند التشغيل
الأول (يمكن اختيار النموذج من شاشة «النماذج»):

| النموذج | الغرض | حجم التنزيل التقريبي |
|---|---|---|
| ‏Silero VAD | اكتشاف الكلام (مطلوب دائماً) | ‏2 ميغابايت |
| ‏WeSpeaker ResNet34 | البصمة الصوتية (موصى به) | ‏27 ميغابايت |
| ‏3D-Speaker ERes2Net | بصمة صوتية (بديل) | ‏38 ميغابايت |
| ‏Whisper Turbo | التفريغ — الأعلى دقة (موصى به) | ‏1000 ميغابايت |
| ‏Whisper Medium | التفريغ — متوازن | ‏1800 ميغابايت |
| ‏Whisper Small | التفريغ — الأسرع، للأجهزة الأقدم | ‏610 ميغابايت |

- يُستخرج من أرشيفات Whisper ملفات الأوزان المضغوطة (int8) فقط، لذا تشغل
  مساحة أقل من حجم التنزيل.
- يُفضَّل التنزيل عبر Wi-Fi. يكفي نموذج تفريغ واحد ونموذج بصمة واحد.
- عند اختيار التفريغ السحابي (Deepgram) لا حاجة إلى نموذج Whisper.

## مفاتيح API

تُدخَل المفاتيح من شاشة «الإعدادات» وتُحفظ في المخزن الآمن للنظام
(Android Keystore، ‏iOS Keychain، وتشفير DPAPI لحساب المستخدم على Windows)، ولا تُحفظ في قاعدة
البيانات ولا في الكود.

- **Anthropic (مطلوب لكتابة المحضر)**: من <https://console.anthropic.com>.
  التسجيل والتفريغ يعملان دونه، لكن المحضر يحتاجه.
- **Deepgram (اختياري)**: فقط إن اخترت التفريغ السحابي، من
  <https://console.deepgram.com>.

## الخصوصية باختصار

- التسجيلات والتفريغ والبصمات الصوتية تبقى **على جهازك** (قاعدة بيانات محلية
  ومجلد التطبيق)، ومستثناة من النسخ الاحتياطي السحابي.
- مع التفريغ على الجهاز، لا يُرسَل إلى الإنترنت إلا **نص التفريغ** عند كتابة
  المحضر (إلى Anthropic).
- مع التفريغ السحابي تُرسَل **مقاطع الصوت** إلى Deepgram.
- لا إعلانات ولا تتبّع ولا تحليلات استخدام.

التفاصيل في [docs/PRIVACY.md](docs/PRIVACY.md).

## تنبيه الموافقة على التسجيل

تسجيل الأشخاص دون علمهم قد يكون مخالفاً للقانون في بلدك أو مكان عملك، والبصمة
الصوتية بيانات حيوية حساسة. **أبلِغ جميع الحاضرين بأن الاجتماع يُسجَّل ويُفرَّغ
ويُحلَّل، واحصل على موافقتهم قبل البدء.** يعرض كاتب تذكيراً بذلك قبل أول
تسجيل. أنت المسؤول عن الالتزام بالأنظمة المعمول بها.

## التقنيات المستخدمة

Flutter وDart ·‏ `flutter_riverpod` لإدارة الحالة ·‏ `drift` (SQLite) للتخزين ·‏
`sherpa_onnx` ‏(Silero VAD وWhisper ونماذج البصمة الصوتية، على الجهاز) ·‏ `record`
لالتقاط الصوت ·‏ Claude API ‏(`claude-opus-5-5`) لكتابة المحضر ·‏ Deepgram
(اختياري) ·‏ `pdf` و`printing` و`share_plus` للتصدير ·‏
`flutter_secure_storage` للمفاتيح ·‏ `flutter_foreground_task` و`wakelock_plus`
للتسجيل الطويل ·‏ خطوط Noto Naskh Arabic وNoto Sans (رخصة SIL OFL 1.1، انظر
[assets/fonts/OFL.txt](assets/fonts/OFL.txt)).

## الترخيص

الترخيص: يحدده مالك المستودع.

</div>

---

# Katib — AI meeting minutes

**Katib** (Arabic: كاتب, "scribe") is a Flutter app for **Android, iOS and
Windows**. It records everything the device microphone hears, **in any
language**, transcribes it, identifies speakers **by voice**, and writes
**professional meeting minutes in Modern Standard Arabic** using Claude.

## What it does

1. Tap "New meeting" and recording starts; it keeps going with the screen off.
2. Speech segments are detected (silence is skipped) and each one is
   transcribed in its original language — Arabic and its dialects, English,
   French and ~99 others, including code-switching within a sentence.
3. A **voiceprint** is extracted per segment and speakers are labelled
   automatically "متحدث 1", "متحدث 2", … (Speaker 1, Speaker 2) live.
4. Rename any speaker; Katib remembers the voice and recognises that person
   by name in future meetings.
5. On stop, speaker assignment is refined over the whole recording and the
   Arabic minutes are generated: summary, attendees, topics, decisions,
   action items with owners and due dates, open questions.
6. Export the minutes as PDF (embedded Arabic font) or Markdown, or share them.

## Features

- **On-device transcription** (offline) with Whisper via sherpa-onnx.
- **Optional cloud transcription** with Deepgram `nova-3` (multilingual) for
  maximum accuracy, when sending audio to a provider is acceptable.
- **Voice-based diarization**: online assignment while recording, offline
  agglomerative refinement after stopping.
- **Persistent voice library**: rename, merge, reassign a segment, forget a
  voiceprint.
- **Faithful, official Arabic minutes**: nothing invented; names, numbers and
  terms preserved; every statement attributed; uncertainty marked.
- **Regenerate minutes** after correcting speaker names.
- **Arabic-first RTL UI** (Material 3) with a layout that adapts from phone to
  a large Windows window.
- **Reliable long recordings**: Android foreground service, iOS background
  audio mode, wake lock while recording.

## Architecture summary

```
microphone (PCM16, 16 kHz, mono)
  → Silero VAD speech segmenter
  → worker isolate: ASR (Whisper or Deepgram) + speaker embedding
  → speaker tracker (online matching against stored voiceprints)
  → database (SQLite via drift) + live UI
  → on stop: re-clustering → Claude → minutes → PDF / Markdown / share
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design.

## Building

Requires Flutter 3.50.0 (stable). Full developer guide:
[docs/SETUP.md](docs/SETUP.md).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift codegen
flutter test
```

| Platform | Requirements | Build command |
|---|---|---|
| Android | JDK 17, Android SDK 36; runs on Android 7.0+ (API 24) | `flutter build apk --release --split-per-abi` |
| iOS | macOS with a recent Xcode; runs on iOS 15+ | `flutter build ios --release` |
| Windows | Visual Studio 2022 with "Desktop development with C++"; Windows 10 1903+ | `flutter build windows --release` |

Release artifacts are built by GitHub Actions when a `vX.Y.Z` tag is pushed
(see "Releasing" in docs/SETUP.md).

## First run: model download

AI models are not bundled, to keep the app small. On first run Katib
downloads them once from the official sherpa-onnx GitHub releases (choose
models on the "Models" screen):

| Model | Purpose | Approx. download |
|---|---|---|
| Silero VAD | Speech detection (always required) | 2 MB |
| WeSpeaker ResNet34 | Voiceprints (recommended) | 27 MB |
| 3D-Speaker ERes2Net | Voiceprints (alternative) | 38 MB |
| Whisper Turbo | Transcription — most accurate (recommended) | 1000 MB |
| Whisper Medium | Transcription — balanced | 1800 MB |
| Whisper Small | Transcription — fastest, older devices | 610 MB |

- Only the int8 weights are extracted from the Whisper archives, so the
  on-disk size is smaller than the download.
- Wi-Fi is recommended. One transcription model and one voiceprint model are
  enough.
- With cloud transcription (Deepgram) no Whisper model is needed.

## API keys

Keys are entered in Settings and stored in the OS secure store (Android
Keystore, iOS Keychain, Windows DPAPI encryption bound to your Windows
user account) — never in the database
or in source code.

- **Anthropic (required for minutes)**: <https://console.anthropic.com>.
  Recording and transcription work without it; minutes need it.
- **Deepgram (optional)**: only for cloud transcription,
  <https://console.deepgram.com>.

## Privacy summary

- Recordings, transcripts and voiceprints stay **on your device** (local
  database and app folder) and are excluded from cloud backups.
- With on-device transcription, only the **transcript text** leaves the
  device, sent to Anthropic when minutes are generated.
- With cloud transcription, **audio segments** are sent to Deepgram.
- No ads, no tracking, no usage analytics.

Details: [docs/PRIVACY.md](docs/PRIVACY.md).

## Recording consent

Recording people without their knowledge may be illegal where you live or
work, and voiceprints are sensitive biometric data. **Tell everyone present
that the meeting is being recorded, transcribed and analysed, and obtain
their consent before you start.** Katib shows a reminder before the first
recording. You are responsible for complying with applicable law.

## Tech stack

Flutter / Dart · `flutter_riverpod` (state) · `drift` (SQLite) ·
`sherpa_onnx` (Silero VAD, Whisper, speaker-embedding models, on device) ·
`record` (audio capture) · Claude API (`claude-opus-5-5`) for minutes ·
Deepgram (optional) · `pdf`, `printing`, `share_plus` (export) ·
`flutter_secure_storage` (API keys) · `flutter_foreground_task`,
`wakelock_plus` (long recordings) · Noto Naskh Arabic and Noto Sans fonts
(SIL OFL 1.1, see [assets/fonts/OFL.txt](assets/fonts/OFL.txt)).

## License

License: to be decided by the repository owner (الترخيص: يحدده مالك المستودع).
