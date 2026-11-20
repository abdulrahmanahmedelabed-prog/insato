<div dir="rtl">

# إنصاتو — محاضر الاجتماعات بالذكاء الاصطناعي

**إنصاتو** تطبيق Flutter يعمل على **Android وiOS وWindows**. يسجّل كل ما يسمعه
ميكروفون الجهاز **بأي لغة**، ويفرّغه نصياً، ويميّز المتحدثين **بأصواتهم**،
ثم يكتب **محضر اجتماع احترافياً باللغة العربية الفصحى** باستخدام Google Gemini (مجاناً، افتراضياً) أو Claude.

[English below ↓](#insato--ai-meeting-minutes)

## ماذا يفعل إنصاتو؟

1. تضغط «اجتماع جديد» ويبدأ التسجيل؛ يستمر حتى مع إطفاء الشاشة.
2. يكتشف إنصاتو مقاطع الكلام ويتجاهل الصمت، ثم يفرّغ كل مقطع بلغته الأصلية
   (العربية واللهجات والإنجليزية والفرنسية وغيرها، بما في ذلك الخلط بين اللغات
   في الجملة الواحدة).
3. يستخرج **بصمة صوتية** لكل مقطع، ويسمّي المتحدثين تلقائياً «متحدث 1»،
   «متحدث 2»… أثناء الاجتماع.
4. يمكنك إعادة تسمية أي متحدث (مثلاً «متحدث 2» ← «أ. سارة»)؛ يتذكّر إنصاتو
   الصوت ويتعرّف على صاحبه باسمه في الاجتماعات القادمة.
5. عند الانتهاء يُحسِّن إنصاتو توزيع المتحدثين على كامل التسجيل، ثم يكتب المحضر
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

### الجديد في الإصدار 1.1

- **محرك المحضر حسب اختيارك**: Google Gemini (الافتراضي، الفئة المجانية،
  نموذج `gemini-flash-lite-latest`، مع تنبيه خصوصية يُقبل قبل أول إرسال)، أو
  Claude (اختياري)، أو **على الجهاز بالكامل** بنموذج GGUF عبر llama.cpp دون
  إنترنت، أو **خادم محلي** (Ollama / LM Studio). المحرك نفسه يخدم «اسأل
  اجتماعاتك».
- **سياق الاجتماع**: جدول أعمال وحضور متوقعون وملاحظات ومصطلحات خاصة بالاجتماع
  قبل البدء (أو «تخطٍّ وابدأ»)، ويُبلَّغ في المحضر بما نوقش من جدول الأعمال.
- **قاموس المصطلحات**: تهجئات معتمدة للأسماء والجهات والمصطلحات تُرسَل إلى
  Deepgram وإلى محرك المحضر.
- **ربط كل بند بلحظته**: أزرار ▶ تحت المحاور والقرارات والمهام تشغّل التسجيل من
  لحظة القول وتبرز السطر في النص الكامل.
- **تتبّع المهام**: شاشة للمهام مع التصفية والتعديل، وتحديثات حالة مقترحة من
  الاجتماع التالي تُطبَّق بعد تأكيدك، وتنبيه بالمهام المفتوحة للحضور عند بدء
  التسجيل.
- **اسأل اجتماعاتك**: محادثة تجيب بالعربية مع استشهادات تفتح اللحظة المذكورة.
- **تصدير Word** (DOCX عربي من اليمين إلى اليسار مع جدول المهام وكتلة التوقيع)
  إلى جانب PDF وMarkdown، عبر نافذة المشاركة (والبريد).
- **بصمة صوتية مسبقة** («إضافة شخص بصوته») و«تحسين البصمة».
- **المايكات الخارجية**: اختيار جهاز الإدخال، و«اختبار المايك»، ووضع «اجتماع في
  قاعة»، والتنبيه إلى سماعات البلوتوث.
- **صوت النظام على Windows**: تسجيل صوت Zoom/Teams وحده أو مع الميكروفون.
- **ملف المتحدث** (اختياري لكل متحدث، معطّل افتراضياً): المعارف والمهارات
  الظاهرة في الكلام، واللغات، وأسلوب التواصل، والإسهامات، مع دليل لكل ادعاء
  وضوابط تمنع أي استنتاج حساس.
- **الرموز والشيفرات**: كلام مرمّز أو غير مفهوم (لا يُحذف أبداً)، ومصطلحات
  داخلية، وكود برمجي يُقال شفهياً، وكلام مُلمَّح، وأرقام مرجعية — كلها فرضيات
  موسومة بقائلها ولحظتها.

### الجديد في الإصدار 1.2

- **المحضر الرسمي المعتمد**: قوالب عامة لأي جهة (مجلس إدارة، جمعية عمومية،
  لجنة، اجتماع إداري/حكومي، اجتماع فريق مبسّط) بصياغة رسمية للقرارات
  («قرر المجلس…»، «أوصت اللجنة…») وترقيم وقواعد نصاب وتصويت وتواقيع.
- **قالب Word خاص بجهتك**: ارفع قالبك بصيغة .docx مع حقول مثل
  `{{meeting_number}}` و`{{resolutions}}` و`{{signatures}}`، مع قالب نموذجي
  للتنزيل؛ ويُحتفظ بتنسيق قالبك وخطوطه واتجاهه.
- **بيانات الجهة**: الاسم والشعار والمجالس واللجان، وترقيم تلقائي للاجتماعات
  (مثل 12/1448هـ).
- **التاريخ الهجري (أم القرى) والميلادي** في الترويسة وكل الصادرات.
- **كشف الحضور والنصاب**: حاضر / غائب بعذر / غائب دون عذر / مدعو، مع عبارة
  «اكتمل النصاب / لم يكتمل».
- **رصد التصويت**: موقف كل متحدث من كل قرار (موافق، معترض، ممتنع، لم يصوّت،
  غير واضح) مع الدليل، و«توافق دون تصويت رسمي»، وحساب النتيجة وفق قاعدة
  الأغلبية، وشاشة مراجعة لأمين السر.
- **الاعتماد والتواقيع**: مسودة ← مراجعة ← اعتماد يقفل المحتوى ويطبع رمز
  التحقق SHA-256، وتواقيع بالإصبع أو القلم على الجهاز، وسجل للإصدارات.
- **كاشف التناقضات**: بعد إنشاء المحضر (وعند الطلب من تبويب «التناقضات»)
  تُقارَن قرارات الاجتماع ومهامه بالقرارات المعتمدة والمهام السابقة وببعضها:
  تعارض مع قرار سابق، تكرار مهمة قائمة، تغيير المسؤول أو الموعد، إعادة فتح
  موضوع محسوم، تعارض داخل الاجتماع — مع ذكر الطرفين (الاجتماع ورقمه وتاريخه
  الهجري والميلادي ورقم القرار والدليل) ودرجة الخطورة. تعمل القواعد المحلية
  دون اتصال، ويتحقق محرك المحضر من الحالات الأدق دون أن يُسمح له باختلاق
  مراجع. «تم الإلغاء رسمياً» يضيف تنويهاً إلى القرار السابق في اجتماعه دون
  تعديل محضره المعتمد. وفحص مباشر أثناء التسجيل اختياري (معطّل افتراضياً).
- **اجتماع متعدد الأجهزة**: حتى أربعة هواتف أو حواسيب في القاعة تعمل
  ميكروفوناً واحداً. يعرض جهاز المضيف رمز QR ورمزاً من 12 حرفاً، فينضم الآخرون
  بمسح الرمز (Android وiOS) أو كتابته (ويندوز)، أو باختيار الاجتماع من قائمة
  الاجتماعات القريبة. يُرسل الصوت مشفّراً عبر شبكة Wi-Fi المحلية مباشرةً دون
  إنترنت، وتُزامَن ساعات الأجهزة ثم تُضبط بمقارنة الصوت نفسه إلى أقل من 20
  مللي ثانية، ويُفرَّغ كل مقطع من الجهاز الأقرب إلى المتحدث (أعلى وضوحاً)،
  ويساعد «أقرب جهاز» على تمييز المتحدثين. إن انقطع جهاز يستمر الاجتماع
  ويُسجَّل الانقطاع، ويرى المضيف حالة كل جهاز (الاتصال، البطارية، جودة الشبكة،
  مستوى الصوت) ويستطيع إزالته. من القائمة أعلى قائمة الاجتماعات: «اجتماع متعدد
  الأجهزة» و«الانضمام كجهاز إضافي».
- **استيراد تسجيل**: حوّل تسجيلاً موجوداً — مكالمة هاتفية (تسجيل مكالمات
  iPhone منذ iOS 18.1، أو مسجّل المكالمات في Samsung وXiaomi وPixel)، أو مذكرة
  صوتية، أو تسجيلاً منزّلاً من Zoom — إلى اجتماع يُعالَج تماماً كالاجتماع
  المسجّل: تفريغ بمحرك التفريغ الذي اخترته، وتمييز المتحدثين ببصماتهم، والمحضر
  وكل مزايا 1.1 و1.2. من زر «استيراد تسجيل» أعلى قائمة الاجتماعات (كل
  الأنظمة)، أو بمشاركة الملف إلى إنصاتو من تطبيق آخر (Android: «مشاركة» /
  «فتح باستخدام»؛ iOS: «فتح في إنصاتو» من ورقة المشاركة أو تطبيق الملفات).
  الصيغ: M4A/AAC وMP3 وWAV وAMR وOGG/Opus وFLAC و3GP/MP4 وCAF (بحسب ما يدعمه
  الجهاز). يُفكّ الترميز على الجهاز بمفكّكات النظام نفسه دون أي خدمة مدفوعة،
  وتعمل المعالجة في الخلفية مع شريط تقدّم وزر إلغاء، ويحمل الاجتماع شارة
  «مستورد». تذكير: تختلف قوانين تسجيل المكالمات من بلد إلى آخر، فأبلغ
  المشاركين بالتسجيل.

## البنية باختصار

```
الميكروفون (PCM16، ‏16 kHz، أحادي)
  → كاشف الكلام Silero VAD
  → خيط معالجة منفصل (Isolate): التفريغ (Whisper أو Deepgram) + البصمة الصوتية
  → متتبّع المتحدثين (مطابقة فورية مع البصمات المحفوظة)
  → قاعدة البيانات (SQLite عبر drift) والواجهة الحية
  → عند الإيقاف: تحسين التجميع ← محرك المحضر (Gemini / Claude) ← المحضر ← PDF / Markdown / مشاركة
```

في الاجتماع متعدد الأجهزة يُدمج صوت الأجهزة الإضافية (WebSocket مشفّر على
الشبكة المحلية) مع ميكروفون المضيف قبل كاشف الكلام، ويُفرَّغ كل مقطع من الجهاز
الأوضح صوتاً.

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
| iOS | ‏macOS مع Xcode حديث؛ أدنى إصدار iOS 16.4 (حدّ llama.cpp للمحرك على الجهاز) | `flutter build ios --release` |
| Windows | ‏Visual Studio 2022 مع «Desktop development with C++»؛ ‏Windows 10 (1903) أو أحدث | `flutter build windows --release` |

نسخ الإصدار الجاهزة تُبنى تلقائياً عبر GitHub Actions عند دفع وسم `vX.Y.Z`
(انظر قسم «الإصدار» في docs/SETUP.md).

## التشغيل الأول: تنزيل النماذج

لا تُضمَّن نماذج الذكاء الاصطناعي داخل التطبيق للحفاظ على صغر حجمه؛ يُنزّلها
إنصاتو مرة واحدة من صفحة إصدارات sherpa-onnx الرسمية على GitHub عند التشغيل
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

- **Google Gemini (المحرك الافتراضي للمحضر، مجاني)**: أنشئ مفتاحاً من
  <https://aistudio.google.com/apikey> ووافق على تنبيه الخصوصية في الإعدادات
  (في الفئة المجانية قد تستخدم Google النصوص لتحسين منتجاتها).
- **Anthropic (اختياري، محرك Claude)**: من <https://console.anthropic.com>.
  التسجيل والتفريغ يعملان دون أي مفتاح، لكن المحضر يحتاج مفتاح المحرك المختار.
- **Deepgram (اختياري)**: فقط إن اخترت التفريغ السحابي، من
  <https://console.deepgram.com>.

## الخصوصية باختصار

- التسجيلات والتفريغ والبصمات الصوتية تبقى **على جهازك** (قاعدة بيانات محلية
  ومجلد التطبيق)، ومستثناة من النسخ الاحتياطي السحابي.
- مع التفريغ على الجهاز، لا يُرسَل إلى الإنترنت إلا **نص التفريغ** عند كتابة
  المحضر (إلى Google Gemini أو Anthropic حسب المحرك المختار).
- مع التفريغ السحابي تُرسَل **مقاطع الصوت** إلى Deepgram.
- مع محرك «على الجهاز» أو خادم على الجهاز نفسه لا يغادر الجهازَ شيء؛ ملفات
  المتحدثين اختيارية ومحلية وقابلة للحذف.
- في الاجتماع متعدد الأجهزة لا يغادر صوت الأجهزة الإضافية **الشبكة المحلية**:
  يصل مشفّراً إلى جهاز المضيف مباشرةً، ولا يُحفظ على الأجهزة الإضافية.
- لا إعلانات ولا تتبّع ولا تحليلات استخدام.

التفاصيل في [docs/PRIVACY.md](docs/PRIVACY.md).

## تنبيه الموافقة على التسجيل

تسجيل الأشخاص دون علمهم قد يكون مخالفاً للقانون في بلدك أو مكان عملك، والبصمة
الصوتية بيانات حيوية حساسة. **أبلِغ جميع الحاضرين بأن الاجتماع يُسجَّل ويُفرَّغ
ويُحلَّل، واحصل على موافقتهم قبل البدء.** يعرض إنصاتو تذكيراً بذلك قبل أول
تسجيل. أنت المسؤول عن الالتزام بالأنظمة المعمول بها.

## التقنيات المستخدمة

Flutter وDart ·‏ `flutter_riverpod` لإدارة الحالة ·‏ `drift` (SQLite) للتخزين ·‏
`sherpa_onnx` ‏(Silero VAD وWhisper ونماذج البصمة الصوتية، على الجهاز) ·‏ `record`
لالتقاط الصوت ·‏ Gemini API ‏(`gemini-flash-lite-latest`، افتراضي) أو Claude API ‏(`claude-opus-5-5`) لكتابة المحضر ·‏ Deepgram
(اختياري) ·‏ `pdf` و`printing` و`share_plus` للتصدير ·‏
`flutter_secure_storage` للمفاتيح ·‏ `flutter_foreground_task` و`wakelock_plus`
للتسجيل الطويل ·‏ خطوط Noto Naskh Arabic وNoto Sans (رخصة SIL OFL 1.1، انظر
[assets/fonts/OFL.txt](assets/fonts/OFL.txt)).

## الترخيص

الترخيص: يحدده مالك المستودع.

</div>

---

# Insato — AI meeting minutes

**Insato** (Arabic: إنصاتو, from إنصات "attentive listening") is a Flutter app for **Android, iOS and
Windows**. It records everything the device microphone hears, **in any
language**, transcribes it, identifies speakers **by voice**, and writes
**professional meeting minutes in Modern Standard Arabic** using Google Gemini (free, default) or Claude.

## What it does

1. Tap "New meeting" and recording starts; it keeps going with the screen off.
2. Speech segments are detected (silence is skipped) and each one is
   transcribed in its original language — Arabic and its dialects, English,
   French and ~99 others, including code-switching within a sentence.
3. A **voiceprint** is extracted per segment and speakers are labelled
   automatically "متحدث 1", "متحدث 2", … (Speaker 1, Speaker 2) live.
4. Rename any speaker; Insato remembers the voice and recognises that person
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

### New in 1.1

- **Choose the minutes engine**: Google Gemini (default, free tier,
  `gemini-flash-lite-latest`, with a privacy notice accepted before the first
  request), Claude (optional), **fully on-device** with a GGUF model through
  llama.cpp (offline), or a **local server** (Ollama / LM Studio). The same
  engine answers "Ask your meetings".
- **Meeting context**: agenda, expected attendees, notes and meeting-only
  terms before recording (or "skip and start"); the minutes report agenda
  coverage.
- **Custom vocabulary**: canonical spellings sent to Deepgram and to the
  minutes engine.
- **Evidence links**: ▶ chips under topics, decisions and action items play
  the recording from that moment and highlight the transcript line.
- **Task tracking**: a tasks screen with filters and editing, status updates
  proposed by the next meeting and applied after your confirmation, and a
  banner of attendees' open tasks when recording starts.
- **Ask your meetings**: chat answered in Arabic with citations that open the
  cited moment.
- **Word export** (RTL Arabic DOCX with the action-items table and a
  signature block) next to PDF and Markdown, through the share sheet (mail).
- **Voice enrollment** ("add a person by voice") and "improve voice".
- **External microphones**: input-device choice, microphone test, the
  "meeting room" far-field profile, Bluetooth warning.
- **Windows system audio**: record Zoom/Teams audio alone or mixed with the
  microphone.
- **Speaker profiles** (opt-in per speaker, off by default): demonstrated
  knowledge, languages, communication style and contributions, every claim
  with evidence and guardrails against sensitive inferences.
- **Codes & jargon**: coded or unintelligible speech (never dropped),
  internal jargon, spoken source code, implied speech and reference numbers,
  as labelled hypotheses with speaker and timestamp.

### New in 1.2

- **Official approved minutes**: generic templates for any institution
  (board, general assembly, committee, administrative/government, simplified
  team meeting) with formal resolution wording, numbering, quorum, majority
  and signature rules.
- **Your own Word template**: upload a .docx with placeholders such as
  `{{meeting_number}}`, `{{resolutions}}`, `{{signatures}}` (a sample
  template is downloadable); its styles, fonts and direction are kept.
- **Entity profile**: name, logo, councils/committees, automatic meeting
  numbers (e.g. 12/1448هـ).
- **Hijri (Umm al-Qura) and Gregorian dates** in the header and all exports.
- **Attendance and quorum**: present / excused / absent / guest, with the
  quorum statement.
- **Vote detection**: each speaker's position per resolution with evidence,
  "consensus without a formal vote", results under the majority rule, and a
  secretary review screen.
- **Approval and signatures**: draft → reviewed → approved locks the
  content and prints its SHA-256; finger/pen signatures on the device;
  version history.
- **Contradiction & consistency checker**: after the minutes are generated
  (and on demand from the «التناقضات» tab) the meeting's decisions and
  action items are compared with approved resolutions, earlier decisions and
  tasks, and with each other: contradicts a resolution, duplicates a task,
  changes an owner or deadline, revisits a closed topic, conflicts within
  the meeting — citing both sides (meeting, number, Hijri and Gregorian
  date, resolution number, evidence) with a severity. Local rules work
  offline; the minutes engine classifies the subtler cases and cannot invent
  references. «تم الإلغاء رسمياً» annotates the earlier resolution on its
  meeting without editing approved minutes. Optional live check while
  recording (off by default).
- **Multi-device recording**: up to four phones or PCs in the room act as
  one microphone. The host shows a QR code and a 12-character code; others
  join by scanning it (Android, iOS), typing it (Windows) or picking the
  meeting from the list of nearby meetings (mDNS). Audio travels encrypted
  over the local Wi-Fi only, no internet needed; clocks are synchronised by
  NTP-style pings and refined by cross-correlating the audio itself to
  under 20 ms; each segment is transcribed from the device nearest the
  talker (best SNR) and "nearest device" helps tell speakers apart. A device
  dropping out does not stop the meeting (the gap is logged); the host sees
  each device's link, battery, network quality and level and can remove it.
  Entries: the devices menu above the meetings list.
- **Import a recording**: turn an existing recording — a phone call (iPhone
  call recording since iOS 18.1, or the Samsung / Xiaomi / Pixel call
  recorder), a voice memo, a Zoom download — into a meeting processed
  exactly like a recorded one: transcription with your chosen ASR engine,
  speaker identification with voiceprints, minutes and every 1.1 / 1.2
  feature. Use «استيراد تسجيل» above the meetings list (all platforms), or
  share the file to Insato from another app (Android "Share" / "Open with";
  iOS "Open in Insato" from the share sheet or Files). Formats: M4A/AAC,
  MP3, WAV, AMR, OGG/Opus, FLAC, 3GP/MP4, CAF (as supported by the device).
  Decoding happens on the device with the OS's own decoders — no paid
  service, no ffmpeg; processing runs in the background with progress and
  cancel, and the meeting carries an «مستورد» badge. Reminder: call
  recording laws vary — inform the participants.

## Architecture summary

```
microphone (PCM16, 16 kHz, mono)
  → Silero VAD speech segmenter
  → worker isolate: ASR (Whisper or Deepgram) + speaker embedding
  → speaker tracker (online matching against stored voiceprints)
  → database (SQLite via drift) + live UI
  → on stop: re-clustering → minutes engine (Gemini / Claude) → minutes → PDF / Markdown / share
```

In a multi-device meeting the guests' audio (encrypted WebSocket on the LAN)
is aligned and fused with the host microphone before the VAD, and each
segment is transcribed from the clearest device.

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
| iOS | macOS with a recent Xcode; runs on iOS 16.4+ (llama.cpp floor for the on-device engine) | `flutter build ios --release` |
| Windows | Visual Studio 2022 with "Desktop development with C++"; Windows 10 1903+ | `flutter build windows --release` |

Release artifacts are built by GitHub Actions when a `vX.Y.Z` tag is pushed
(see "Releasing" in docs/SETUP.md).

## First run: model download

AI models are not bundled, to keep the app small. On first run Insato
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

- **Google Gemini (default minutes engine, free)**: create a key at
  <https://aistudio.google.com/apikey> and accept the privacy notice in
  Settings (on the free tier Google may use the text to improve its products).
- **Anthropic (optional, Claude engine)**: <https://console.anthropic.com>.
  Recording and transcription work without any key; minutes need the key of
  the selected engine.
- **Deepgram (optional)**: only for cloud transcription,
  <https://console.deepgram.com>.

## Privacy summary

- Recordings, transcripts and voiceprints stay **on your device** (local
  database and app folder) and are excluded from cloud backups.
- With on-device transcription, only the **transcript text** leaves the
  device, sent to Google Gemini or Anthropic (the selected engine) when
  minutes are generated.
- With cloud transcription, **audio segments** are sent to Deepgram.
- With the on-device engine (or a server on the same machine) nothing leaves
  the device; speaker profiles are opt-in, local and deletable.
- In a multi-device meeting the extra devices' audio never leaves the
  **local network**: it goes encrypted straight to the host and is not
  stored on the extra devices.
- No ads, no tracking, no usage analytics.

Details: [docs/PRIVACY.md](docs/PRIVACY.md).

## Recording consent

Recording people without their knowledge may be illegal where you live or
work, and voiceprints are sensitive biometric data. **Tell everyone present
that the meeting is being recorded, transcribed and analysed, and obtain
their consent before you start.** Insato shows a reminder before the first
recording. You are responsible for complying with applicable law.

## Tech stack

Flutter / Dart · `flutter_riverpod` (state) · `drift` (SQLite) ·
`sherpa_onnx` (Silero VAD, Whisper, speaker-embedding models, on device) ·
`record` (audio capture) · Gemini API (`gemini-flash-lite-latest`, default) or Claude API (`claude-opus-5-5`) for minutes ·
Deepgram (optional) · `pdf`, `printing`, `share_plus` (export) ·
`flutter_secure_storage` (API keys) · `flutter_foreground_task`,
`wakelock_plus` (long recordings) · Noto Naskh Arabic and Noto Sans fonts
(SIL OFL 1.1, see [assets/fonts/OFL.txt](assets/fonts/OFL.txt)).

## License

License: to be decided by the repository owner (الترخيص: يحدده مالك المستودع).
