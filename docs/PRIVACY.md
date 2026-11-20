<div dir="rtl">

# سياسة الخصوصية — إنصاتو

آخر تحديث: نوفمبر 2026

[English version below ↓](#privacy-policy--insato)

إنصاتو تطبيق يسجّل الاجتماعات ويفرّغها ويكتب محاضرها. صُمِّم ليُبقي بياناتك على
جهازك قدر الإمكان، وليُطلعك بوضوح على كل ما يغادر الجهاز ووجهته.

## 1. البيانات التي يعالجها التطبيق

| البيانات | مكان الحفظ | هل تغادر الجهاز؟ |
|---|---|---|
| تسجيلات الصوت (ملفات WAV) | مجلد التطبيق على جهازك | لا، إلا مع التفريغ السحابي (البند 2-ب) |
| نص التفريغ | قاعدة بيانات محلية (SQLite) | نعم، إلى محرك المحضر السحابي الذي تختاره (Google Gemini افتراضياً، أو Anthropic Claude) عند كتابة المحضر؛ لا، مع المحرك المحلي |
| البصمات الصوتية للمتحدثين | قاعدة البيانات المحلية | **لا، أبداً** |
| أسماء المتحدثين التي تدخلها | قاعدة البيانات المحلية | ضمن نص التفريغ المرسَل لكتابة المحضر |
| المحاضر | قاعدة البيانات المحلية | نعم، مقتطفات منها إلى المحرك المختار عند استخدام «اسأل اجتماعاتك» أو كاشف التناقضات، والمهام المفتوحة منها مع طلب المحضر التالي؛ وفيما عدا ذلك لا، إلا إذا شاركتها أو صدّرتها أنت |
| مفاتيح API | المخزن الآمن للنظام | تُرسَل فقط إلى مزوّد الخدمة الخاص بها للمصادقة |
| الإعدادات | قاعدة البيانات المحلية | لا |
| بيانات الجهة وشعارها وقوالب Word المرفوعة (الإصدار 1.2) | قاعدة البيانات المحلية ومجلد التطبيق | لا؛ يُرسَل اسم المجلس/اللجنة وقائمة الحضور المتوقعين ضمن طلب المحضر إلى المحرك المختار، والشعار والقالب يدخلان الملفات التي تصدّرها أنت فقط |
| كشف الحضور ومواقف التصويت ومراجعتها | قاعدة البيانات المحلية | لا، إلا ضمن المحاضر التي تشاركها أو تصدّرها |
| **التواقيع** المرسومة على الجهاز (الإصدار 1.2) | قاعدة البيانات المحلية: خطوط متجهة (إحداثيات وتوقيت) مع اسم الموقِّع وصفته ووقت التوقيع ورمز التحقق للمحتوى المعتمد | **لا تُرسَل إلى أي خدمة**؛ تظهر فقط في ملفات PDF وWord التي تصدّرها أنت (متجهة في PDF، وصورة في Word) |

**التواقيع** تُجمع على الجهاز بعد اعتماد المحضر، وترتبط بإصدار محدد ورمز
تحققه (SHA-256)، وتبقى مع ذلك الإصدار في سجل الإصدارات. لا تُستخدم للتحقق من
الهوية ولا لأي غرض آخر، وتُحذف مع الاجتماع. التوقيع المرسوم على الجهاز ليس
توقيعاً إلكترونياً معتمداً بشهادة رقمية؛ ورمز التحقق يكشف أي تغيير لاحق في
المحتوى المعتمد.

**البصمة الصوتية** متجه رقمي يمثّل خصائص الصوت، يُستخدم فقط لمطابقة المتحدث
مع المتحدثين المحفوظين على جهازك. لا تُرسَل إلى أي جهة، ولا تُستخدم لأي غرض
آخر.

## 2. ما يُرسَل إلى خدمات خارجية

### أ) كتابة المحضر — المحرك الذي تختاره في الإعدادات
عند طلب المحضر يُرسَل **نص التفريغ** (مع أسماء المتحدثين والأوقات وأرقام
المقاطع) وعنوان الاجتماع وسياقه الذي أدخلته (جدول الأعمال، الحضور المتوقعون،
الملاحظات، قاموس المصطلحات، المهام المفتوحة) إلى محرك المحضر عبر اتصال مشفّر
(HTTPS) باستخدام مفتاحك أنت. **لا يُرسَل الصوت أبداً.**

- **Google Gemini (الافتراضي، الفئة المجانية):** يُرسَل النص إلى واجهة Gemini
  البرمجية لدى Google. **تنبيه مهم:** عند استخدام مفتاح مجاني (دون تفعيل
  الفوترة) قد تستخدم Google المحتوى المرسَل والإجابات لتحسين منتجاتها، وقد
  يطّلع عليها مراجعون بشريون بعد فصلها عن حسابك. أما مفتاح مشروع Google Cloud
  مفعّل الفوترة فيُعامَل كخدمة مدفوعة ولا يُستخدم المحتوى في تحسين المنتجات.
  لهذا يعرض إنصاتو هذا التنبيه ويطلب موافقتك قبل أول إرسال، ولا يرسل شيئاً
  دونها. لا تستخدم Gemini المجاني للاجتماعات السرية؛ استخدم لها المحرك المحلي
  على الجهاز. شروط Gemini API: <https://ai.google.dev/gemini-api/terms>،
  وسياسة خصوصية Google: <https://policies.google.com/privacy>.
- **Anthropic Claude (اختياري):** يُرسَل النص إلى واجهة Claude البرمجية لدى
  Anthropic وتخضع معالجته لشروطها وسياسة خصوصيتها:
  <https://www.anthropic.com/legal/privacy>.
- **المحرك على الجهاز / الخادم المحلي:** لا يغادر النص جهازك مع المحرك على الجهاز
  أو خادم على العنوان المحلي (localhost)؛ أما إذا كان عنوان الخادم جهازاً آخر
  فيُرسَل النص إلى ذلك الجهاز، وينبّهك التطبيق إلى ذلك.

ملفات المتحدثين (اختيارية لكل متحدث، معطّلة افتراضياً) تُستخرج من النص نفسه
وتُحفظ على جهازك فقط، ولا تتضمن أي استنتاجات حساسة. وكذلك «الرموز والشيفرات»
تُستخرج مع المحضر وتُحفظ محلياً.

**اسأل اجتماعاتك:** يُرسَل سؤالك مع مقتطفات من نصوص اجتماعاتك ومحاضرها (الأكثر
صلة بالسؤال فقط) إلى المحرك نفسه المختار للمحضر، وبالموافقة نفسها؛ ولا تُحفظ
المحادثة بعد إغلاق التطبيق.

**كاشف التناقضات (الإصدار 1.2):** بعد إنشاء المحضر أو عند طلب الفحص يُرسَل إلى
المحرك نفسه المختار للمحضر، وبالموافقة نفسها: عنوان الاجتماع وتاريخه، وقراراته
ومهامه مع سطرين من التفريغ على الأكثر دليلاً لكل منها، والقرارات والمهام
السابقة المرتبطة بها فقط (نصها، ورقم القرار، وعنوان اجتماعها ورقمه وتاريخه،
والمسؤول والموعد والحالة) — لا تُرسَل التفريغات الكاملة للاجتماعات السابقة.
مع المحرك المحلي لا يغادر شيء الجهاز، وتعمل القواعد المحلية دون أي إرسال.
النتائج والتنويهات («أُلغي رسمياً») تُحفظ محلياً وتُحذف مع الاجتماع.
**الفحص المباشر أثناء التسجيل** معطّل افتراضياً؛ إذا فعّلته يُرسَل كل بضع
دقائق آخر ما قيل (حتى 60 مقطعاً) مع البنود السابقة المرتبطة به، وفقط إلى محرك
سحابي (Gemini أو Claude) سبق أن وافقت عليه؛ ولا تُحفظ نتائجه.

### ب) التفريغ السحابي — Deepgram (اختياري، معطّل افتراضياً)
إذا اخترت محرك التفريغ السحابي، تُرسَل **مقاطع الصوت** إلى Deepgram عبر
HTTPS باستخدام مفتاحك لمعالجتها، ويعود النص فقط. يطلب إنصاتو في كل طلب
الانسحاب من برنامج تحسين النماذج لدى Deepgram (`mip_opt_out=true`)، أي ألّا
تُستخدم هذه المقاطع في تدريب نماذجها. ومع ذلك فإن مدة احتفاظ Deepgram بالصوت
والنص وكيفية تعاملها معهما تحكمهما سياسة بياناتها هي، لا إنصاتو:
<https://deepgram.com/privacy>. مع التفريغ على الجهاز (الافتراضي) لا يُرسَل أي
صوت. ومع التفريغ السحابي تُرسَل أيضاً مصطلحات القاموس وأسماء الحضور المتوقعين
والمتحدثين المسمَّين بوصفها «مصطلحات مفتاحية» (keyterms) لتحسين التعرّف عليها.

**صوت النظام على Windows:** عند اختيار «صوت النظام» أو «الاثنان معاً» يُسجَّل ما
يُشغَّل على الحاسوب (مثل صوت Zoom/Teams) ويُعامَل كتسجيل الميكروفون تماماً: يبقى
على جهازك. أبلِغ المشاركين عن بُعد بأن الاجتماع يُسجَّل.

### ج) تنزيل النماذج
تُنزَّل نماذج الذكاء الاصطناعي مرة واحدة من صفحة إصدارات مشروع sherpa-onnx على
GitHub، ونماذج المحضر على الجهاز (GGUF) من Hugging Face. هذا تنزيل فقط؛ لا
تُرسَل أي بيانات اجتماعات. قد تسجّل GitHub وHugging Face عنوان IP الخاص بالطلب
وفق سياستهما.

### د) الاجتماع متعدد الأجهزة (الإصدار 1.2) — داخل الشبكة المحلية فقط
عند تفعيل «اجتماع متعدد الأجهزة» تعمل هواتف وحواسيب أخرى ميكروفوناتٍ إضافية:
- يُرسل كل جهاز إضافي صوت الميكروفون (16 كيلوهرتز) مباشرةً إلى جهاز المضيف عبر
  شبكة Wi-Fi المحلية، **ولا يمرّ الصوت بأي خادم ولا يخرج إلى الإنترنت**. لا
  حاجة إلى اتصال بالإنترنت أصلاً.
- الاتصال مشفّر وموثَّق (ChaCha20-Poly1305) بمفتاح مشتق من رمز الانضمام الذي
  يظهر على جهاز المضيف (رمز QR أو 12 حرفاً)؛ لا يُرسل الرمز عبر الشبكة، ويُرفض
  أي جهاز لا يعرفه، وتُرفض الرسائل المعادة. حدٌّ أقصى أربعة أجهزة، ويستطيع
  المضيف إزالة أي جهاز.
- الجهاز الإضافي لا يحفظ الصوت ولا النص؛ يُحفظ الاجتماع (التسجيل المدمج
  والنص والمحضر) على جهاز المضيف فقط، ومعه سجل بالأجهزة المشاركة وأوقات
  انقطاعها ونسبة وضوح الصوت لكل جهاز في كل مقطع (للمساعدة على تمييز المتحدثين).
- يُعلن جهاز المضيف عن الاجتماع على الشبكة المحلية (mDNS/Bonjour) باسم
  الجهاز ومعرّف الجلسة فقط، طوال فتح شاشة الاستضافة.
- يرسل الجهاز الإضافي إلى المضيف مستوى البطارية (إن توفر) ومستوى الصوت لعرض
  حالته.

### هـ) ما لا يحدث أبداً
- لا إعلانات، ولا أدوات تتبّع، ولا تحليلات استخدام، ولا تقارير أعطال تلقائية.
- لا خادم خاص بإنصاتو: التطبيق يتصل مباشرة بالخدمات أعلاه بمفاتيحك.
- لا بيع ولا مشاركة للبيانات مع أي طرف آخر.

## 3. الحماية والاحتفاظ والحذف

- تُحفظ مفاتيح API في المخزن الآمن للنظام، لا في قاعدة بيانات التطبيق:
  - Android: تشفير مرتبط بـ Android Keystore.
  - iOS: سلسلة المفاتيح (Keychain) بفئة الوصول «بعد أول فتح للقفل، على هذا
    الجهاز فقط»: تبقى قابلة للقراءة والشاشة مقفلة (ليستمر التفريغ السحابي
    والمحضر أثناء التسجيل في الخلفية) بعد أول فتح لقفل الجهاز منذ تشغيله،
    ولا تُنقل إلى جهاز آخر (لا تُستعاد من نسخة احتياطية إلا على الجهاز نفسه)
    ولا تُزامَن عبر iCloud Keychain.
  - Windows: ملف مشفّر بتقنية DPAPI المرتبطة بحساب المستخدم في
    `%APPDATA%\Insato\Insato`.
- تُستثنى بيانات التطبيق من النسخ الاحتياطي السحابي ومن النقل بين الأجهزة
  على Android، ومن نسخ iCloud والحاسوب على iOS. لذلك **لا تنتقل اجتماعاتك
  تلقائياً إلى جهاز جديد**؛ صدّر ما تحتاجه من محاضر قبل تغيير الجهاز.
- على Windows تُحفظ الاجتماعات (قاعدة البيانات والتسجيلات والملفات المصدَّرة)
  في المجلد المحلي الخاص بالتطبيق `%LOCALAPPDATA%\Insato\Insato`، لا في مجلد
  «المستندات» الذي تشاركه تطبيقات أخرى وكثيراً ما يُزامَن مع OneDrive. تُنقل
  بيانات الإصدارات السابقة من «المستندات» إليه تلقائياً عند أول تشغيل، أما
  الملفات المصدَّرة سابقاً في `Documents\exports` فتبقى في مكانها لأن اسم المجلد
  عام وقد يخص تطبيقات أخرى؛ احذفها يدوياً إن لم تعد تحتاجها. تُحفظ نماذج
  التعرّف على الكلام في `%APPDATA%\Insato\Insato\models`.
- يمكنك اختيار عدم الاحتفاظ بملفات الصوت بعد التفريغ من «الإعدادات».
- يمكنك حذف أي اجتماع أو متحدث أو بصمة صوتية في أي وقت من داخل التطبيق.
  حذف التطبيق على Android وiOS يحذف كل بياناته من الجهاز. على Windows يُوزَّع
  التطبيق مجلداً بلا برنامج إزالة، فاحذف المجلدين المذكورين أعلاه يدوياً لإزالة
  بياناته ومفاتيحه.
- البيانات المرسَلة إلى Google أو Anthropic أو Deepgram يحكمها احتفاظ تلك الجهات
  وفق شروطها؛ لا يملك إنصاتو نسخة منها.

## 4. الموافقة على التسجيل

تسجيل الأشخاص وتحليل أصواتهم قد يتطلب موافقتهم بموجب القانون في بلدك أو
مكان عملك، والبصمة الصوتية تُعد بيانات حيوية حساسة في كثير من الأنظمة.
**يجب إبلاغ جميع الحاضرين بأن الاجتماع يُسجَّل ويُفرَّغ ويُحلَّل، والحصول على
موافقتهم قبل البدء.** يعرض إنصاتو تذكيراً بذلك قبل أول تسجيل، ويظهر إشعار دائم
أثناء التسجيل على Android. المستخدم هو المسؤول عن الالتزام بالأنظمة المعمول
بها، وعن حذف بصمة أي شخص يطلب ذلك.

## 5. الأذونات

| الإذن | السبب |
|---|---|
| الميكروفون | تسجيل الاجتماع — الوظيفة الأساسية |
| الإشعارات (Android 13+) | إظهار إشعار «جارٍ التسجيل» أثناء عمل التسجيل في الخلفية |
| الإنترنت | تنزيل النماذج، وكتابة المحضر، والتفريغ السحابي الاختياري |
| منع السكون / الخدمة المقدّمة / الصوت في الخلفية | استمرار التسجيل مع إطفاء الشاشة |
| الشبكة المحلية (iOS)، حالة الشبكة وWi-Fi والبث المتعدد (Android) | الاجتماع متعدد الأجهزة: الاتصال بين الأجهزة في القاعة واكتشافها على الشبكة المحلية |
| الكاميرا (اختياري) | مسح رمز QR للانضمام إلى اجتماع متعدد الأجهزة فقط؛ لا تُلتقط صور ولا تُحفظ |

لا يطلب إنصاتو الوصول إلى جهات الاتصال أو الموقع أو الصور، ولا يستخدم
الكاميرا إلا لمسح رمز الانضمام عند طلبك.

## 6. الأطفال

التطبيق غير موجّه للأطفال ولا يجمع بيانات عنهم عن قصد.

## 7. التغييرات والتواصل

أي تغيير في هذه السياسة يُنشر في هذا الملف ضمن المستودع مع تاريخ التحديث.
للاستفسارات تواصل مع مالك المستودع عبر صفحة المشروع.

</div>

---

# Privacy policy — Insato

Last updated: November 2026

Insato records meetings, transcribes them and writes minutes. It is designed
to keep your data on your device wherever possible and to tell you exactly
what leaves the device and where it goes.

## 1. Data the app processes

| Data | Where it is stored | Does it leave the device? |
|---|---|---|
| Audio recordings (WAV files) | App folder on your device | No — unless cloud transcription is enabled (2b) |
| Transcript text | Local database (SQLite) | Yes, to the cloud minutes engine you choose (Google Gemini by default, or Anthropic Claude) when minutes are generated; no with the on-device engine |
| Speaker voiceprints | Local database | **Never** |
| Speaker names you enter | Local database | As part of the transcript sent for minutes |
| Minutes | Local database | Yes — relevant excerpts to the chosen engine when you use Ask your meetings or the contradiction checker, and open tasks with later minutes requests; otherwise only if you share/export them |
| API keys | OS secure storage | Only to their own provider, for authentication |
| Settings | Local database | No |
| Entity profile, logo and uploaded Word templates (v1.2) | Local database and app folder | No; the council/committee name and the expected attendees are part of the minutes request to the chosen engine; the logo and template only go into files you export |
| Attendance sheet, vote positions and their review | Local database | No, except inside minutes you share or export |
| **Signatures** drawn on the device (v1.2) | Local database: vector strokes (coordinates and timing) with the signer's name and role, the time and the hash of the approved content | **Never sent to any service**; they appear only in PDF and Word files you export (vectors in PDF, an image in Word) |

**Signatures** are collected on the device after the minutes are approved,
are bound to that version and its SHA-256 hash, and stay with it in the
version history. They are not used for identity verification or anything
else and are deleted with the meeting. A signature drawn on the device is
not a certificate-based qualified electronic signature; the hash reveals any
later change to the approved content.

A **voiceprint** is a numeric vector describing voice characteristics. It is
used only to match speakers against the speakers saved on your device, is
never transmitted and is used for no other purpose.

## 2. What is sent to external services

### a) Minutes — the engine you choose in Settings
When you generate minutes, the **transcript text** (with speaker names,
timestamps and segment numbers), the meeting title and the context you
entered (agenda, expected attendees, notes, glossary, open tasks) are sent
over HTTPS to the minutes engine using your own API key. **Audio is never
sent.**

- **Google Gemini (default, free tier):** the text is sent to Google's Gemini
  API. **Important:** with a free (unbilled) key Google may use the submitted
  content and responses to improve its products, and human reviewers may read
  them after they are disconnected from your account. A key from a Google
  Cloud project with billing enabled is treated as paid and the content is
  not used to improve Google's products. Insato therefore shows this notice
  and asks for your agreement before the first request, and sends nothing
  without it. Do not use the free Gemini tier for confidential meetings — use
  the on-device engine. Gemini API terms:
  <https://ai.google.dev/gemini-api/terms>; Google privacy policy:
  <https://policies.google.com/privacy>.
- **Anthropic Claude (optional):** the text is sent to Anthropic's Claude API,
  governed by Anthropic's API terms and privacy policy:
  <https://www.anthropic.com/legal/privacy>.
- **On-device engine / local server:** with the on-device engine or a server on
  localhost the text never leaves your device; if the server URL points to
  another host, the text is sent to that host (the app warns you when this
  happens).

Speaker profiles (opt-in per speaker, off by default) are derived from the
same text, stored only on your device, and never contain sensitive
inferences. Codes & jargon findings are extracted with the minutes and kept
locally too.

**Ask your meetings:** your question and the excerpts of your transcripts and
minutes most relevant to it are sent to the same engine as the minutes,
under the same consent; the conversation is not kept after the app closes.

**Contradiction checker (v1.2):** after minutes are generated, or when you
run the check, the same engine as the minutes receives, under the same
consent: the meeting's title and date, its decisions and action items with
at most two transcript lines of evidence each, and only the related earlier
resolutions, decisions and tasks (text, resolution number, their meeting's
title, number and date, owner, deadline, status) — never the full
transcripts of earlier meetings. With the on-device engine nothing leaves
the device, and the local rules send nothing. Findings and «أُلغي رسمياً»
annotations are stored locally and deleted with the meeting. **Live checking
while recording** is off by default; when enabled, every few minutes the
latest lines (up to 60 segments) and the related earlier items are sent, and
only to a cloud engine (Gemini or Claude) you already accepted; its results
are not stored.

### b) Cloud transcription — Deepgram (optional, off by default)
If you select the cloud transcription engine, **audio segments** are sent
over HTTPS to Deepgram with your API key for processing, and only text comes
back. Every request opts out of Deepgram's Model Improvement Program
(`mip_opt_out=true`), asking Deepgram not to use the audio to train its
models. How long Deepgram retains the audio and transcript, and how it
handles them, is still governed by Deepgram's own data policy, not by
Insato: <https://deepgram.com/privacy>. With on-device transcription (the
default) no audio is sent anywhere. With cloud transcription, glossary terms
and the names of expected attendees and named speakers are also sent as
keyterms to improve their recognition.

**Windows system audio:** with "system audio" or "both", what plays on the
computer (e.g. Zoom/Teams) is recorded and treated exactly like the
microphone recording: it stays on your device. Tell remote participants that
the meeting is recorded.

### c) Model downloads
AI models are downloaded once from the sherpa-onnx project's GitHub
releases, and the on-device minutes models (GGUF) from Hugging Face. This is
a download only; no meeting data is sent. GitHub and Hugging Face may log the
requesting IP address under their own policies.

### d) Multi-device meetings (version 1.2) — local network only
With "اجتماع متعدد الأجهزة" other phones and computers act as extra
microphones:
- Each extra device sends its microphone audio (16 kHz) directly to the
  host device over the local Wi-Fi network. **Audio never goes through a
  server or out to the internet**; no internet connection is needed at all.
- The link is encrypted and authenticated (ChaCha20-Poly1305) with a key
  derived from the join code shown on the host (QR code or 12 characters).
  The code is never sent over the network; devices that do not know it are
  refused and replayed messages are rejected. At most four devices; the
  host can remove any of them.
- An extra device stores neither audio nor text. The meeting (fused
  recording, transcript, minutes) is stored on the host only, together with
  a log of the participating devices, when they dropped out, and each
  device's signal-to-noise ratio per segment (used to tell speakers apart).
- While the hosting screen is open the host announces the meeting on the
  local network (mDNS/Bonjour) with the device name and session id only.
- Extra devices report their battery level (when available) and input level
  to the host for its status display.

### e) What never happens
- No ads, trackers, usage analytics or automatic crash reporting.
- No Insato server: the app talks directly to the services above with your keys.
- No selling or sharing of data with anyone else.

## 3. Security, retention and deletion

- API keys are kept in OS secure storage, never in the app database:
  - Android: encryption backed by the Android Keystore.
  - iOS: the Keychain with the "after first unlock, this device only"
    accessibility class: readable while the screen is locked once the device
    has been unlocked after boot (so cloud transcription and minutes keep
    working during background recording), never moved to another device (a
    backup restores them only onto the same device) and not synced through
    iCloud Keychain.
  - Windows: a file encrypted with DPAPI, bound to your Windows user
    account, in `%APPDATA%\Insato\Insato`.
- App data is excluded from cloud backup and device-to-device transfer on
  Android, and from iCloud/computer backups on iOS. Consequently **meetings do
  not move to a new device automatically**; export the minutes you need first.
- On Windows, meetings (database, recordings, exported files) are stored in
  the app's private local folder `%LOCALAPPDATA%\Insato\Insato`, not in
  Documents, which other apps share and which is often synced to OneDrive.
  Data from earlier versions is moved there from Documents on first launch.
  Files exported earlier to `Documents\exports` are left in place, because
  that folder name is generic and may belong to other apps; delete them by
  hand if you no longer need them. Speech models are stored in
  `%APPDATA%\Insato\Insato\models`.
- You can choose not to keep audio files after transcription (Settings).
- Any meeting, speaker or voiceprint can be deleted at any time in the app.
  Uninstalling the app on Android and iOS deletes all of its data from the
  device. On Windows the app is distributed as a folder without an
  uninstaller: delete the two folders named above to remove its data and
  keys.
- Data sent to Google, Anthropic or Deepgram is retained under those providers'
  terms; Insato keeps no copy of it anywhere else.

## 4. Recording consent

Recording people and analysing their voices may require their consent under
the law where you live or work, and voiceprints are sensitive biometric data
in many jurisdictions. **Inform everyone present that the meeting is being
recorded, transcribed and analysed, and obtain their consent before
starting.** Insato shows a reminder before the first recording and a
persistent notification while recording on Android. The user is responsible
for complying with applicable law and for deleting anyone's voiceprint on
request.

## 5. Permissions

| Permission | Why |
|---|---|
| Microphone | Recording the meeting — the core function |
| Notifications (Android 13+) | The "recording in progress" notification during background recording |
| Internet | Model downloads, minutes generation, optional cloud transcription |
| Wake lock / foreground service / background audio | Keep recording with the screen off |
| Local network (iOS); network state, Wi-Fi state, multicast (Android) | Multi-device meetings: connecting and discovering the devices in the room on the local network |
| Camera (optional) | Only to scan the QR code that joins a multi-device meeting; no photos are taken or stored |

Insato does not request access to contacts, location or photos, and uses
the camera only to scan a join code when you ask it to.

## 6. Children

The app is not directed at children and does not knowingly collect data
about them.

## 7. Changes and contact

Changes to this policy are published in this file in the repository, with
the update date. For questions, contact the repository owner via the
project page.
