<div dir="rtl">

# سياسة الخصوصية — كاتب

آخر تحديث: نوفمبر 2026

[English version below ↓](#privacy-policy--katib)

كاتب تطبيق يسجّل الاجتماعات ويفرّغها ويكتب محاضرها. صُمِّم ليُبقي بياناتك على
جهازك قدر الإمكان، وليُطلعك بوضوح على كل ما يغادر الجهاز ووجهته.

## 1. البيانات التي يعالجها التطبيق

| البيانات | مكان الحفظ | هل تغادر الجهاز؟ |
|---|---|---|
| تسجيلات الصوت (ملفات WAV) | مجلد التطبيق على جهازك | لا، إلا مع التفريغ السحابي (البند 2-ب) |
| نص التفريغ | قاعدة بيانات محلية (SQLite) | نعم، إلى Anthropic عند كتابة المحضر |
| البصمات الصوتية للمتحدثين | قاعدة البيانات المحلية | **لا، أبداً** |
| أسماء المتحدثين التي تدخلها | قاعدة البيانات المحلية | ضمن نص التفريغ المرسَل لكتابة المحضر |
| المحاضر | قاعدة البيانات المحلية | لا، إلا إذا شاركتها أنت |
| مفاتيح API | المخزن الآمن للنظام | تُرسَل فقط إلى مزوّد الخدمة الخاص بها للمصادقة |
| الإعدادات | قاعدة البيانات المحلية | لا |

**البصمة الصوتية** متجه رقمي يمثّل خصائص الصوت، يُستخدم فقط لمطابقة المتحدث
مع المتحدثين المحفوظين على جهازك. لا تُرسَل إلى أي جهة، ولا تُستخدم لأي غرض
آخر.

## 2. ما يُرسَل إلى خدمات خارجية

### أ) كتابة المحضر — Anthropic (Claude)
عند طلب المحضر يُرسَل **نص التفريغ** (مع أسماء المتحدثين والأوقات) وعنوان
الاجتماع إلى واجهة Claude البرمجية لدى Anthropic عبر اتصال مشفّر (HTTPS)
باستخدام مفتاحك أنت. **لا يُرسَل الصوت.** تخضع معالجة هذه البيانات لشروط
Anthropic وسياسة خصوصيتها الخاصة بالواجهة البرمجية:
<https://www.anthropic.com/legal/privacy>.

### ب) التفريغ السحابي — Deepgram (اختياري، معطّل افتراضياً)
إذا اخترت محرك التفريغ السحابي، تُرسَل **مقاطع الصوت** إلى Deepgram عبر
HTTPS باستخدام مفتاحك، ويعود النص فقط. تخضع لسياسة Deepgram:
<https://deepgram.com/privacy>. مع التفريغ على الجهاز (الافتراضي) لا يُرسَل أي
صوت.

### ج) تنزيل النماذج
تُنزَّل نماذج الذكاء الاصطناعي مرة واحدة من صفحة إصدارات مشروع sherpa-onnx على
GitHub. هذا تنزيل فقط؛ لا تُرسَل أي بيانات اجتماعات. قد تسجّل GitHub عنوان IP
الخاص بالطلب وفق سياستها.

### د) ما لا يحدث أبداً
- لا إعلانات، ولا أدوات تتبّع، ولا تحليلات استخدام، ولا تقارير أعطال تلقائية.
- لا خادم خاص بكاتب: التطبيق يتصل مباشرة بالخدمات أعلاه بمفاتيحك.
- لا بيع ولا مشاركة للبيانات مع أي طرف آخر.

## 3. الحماية والاحتفاظ والحذف

- تُحفظ مفاتيح API في المخزن الآمن للنظام: Android Keystore، و‏iOS Keychain،
  وتشفير DPAPI المرتبط بحساب المستخدم على Windows.
- تُستثنى بيانات التطبيق من النسخ الاحتياطي السحابي ومن النقل بين الأجهزة
  على Android، ومن نسخ iCloud والحاسوب على iOS. لذلك **لا تنتقل اجتماعاتك
  تلقائياً إلى جهاز جديد**؛ صدّر ما تحتاجه من محاضر قبل تغيير الجهاز.
- يمكنك اختيار عدم الاحتفاظ بملفات الصوت بعد التفريغ من «الإعدادات».
- يمكنك حذف أي اجتماع أو متحدث أو بصمة صوتية في أي وقت من داخل التطبيق.
  حذف التطبيق يحذف كل بياناته من الجهاز.
- البيانات المرسَلة إلى Anthropic أو Deepgram يحكمها احتفاظ تلك الجهات
  وفق شروطها؛ لا يملك كاتب نسخة منها.

## 4. الموافقة على التسجيل

تسجيل الأشخاص وتحليل أصواتهم قد يتطلب موافقتهم بموجب القانون في بلدك أو
مكان عملك، والبصمة الصوتية تُعد بيانات حيوية حساسة في كثير من الأنظمة.
**يجب إبلاغ جميع الحاضرين بأن الاجتماع يُسجَّل ويُفرَّغ ويُحلَّل، والحصول على
موافقتهم قبل البدء.** يعرض كاتب تذكيراً بذلك قبل أول تسجيل، ويظهر إشعار دائم
أثناء التسجيل على Android. المستخدم هو المسؤول عن الالتزام بالأنظمة المعمول
بها، وعن حذف بصمة أي شخص يطلب ذلك.

## 5. الأذونات

| الإذن | السبب |
|---|---|
| الميكروفون | تسجيل الاجتماع — الوظيفة الأساسية |
| الإشعارات (Android 13+) | إظهار إشعار «جارٍ التسجيل» أثناء عمل التسجيل في الخلفية |
| الإنترنت | تنزيل النماذج، وكتابة المحضر، والتفريغ السحابي الاختياري |
| منع السكون / الخدمة المقدّمة / الصوت في الخلفية | استمرار التسجيل مع إطفاء الشاشة |

لا يطلب كاتب الوصول إلى جهات الاتصال أو الموقع أو الصور أو الكاميرا.

## 6. الأطفال

التطبيق غير موجّه للأطفال ولا يجمع بيانات عنهم عن قصد.

## 7. التغييرات والتواصل

أي تغيير في هذه السياسة يُنشر في هذا الملف ضمن المستودع مع تاريخ التحديث.
للاستفسارات تواصل مع مالك المستودع عبر صفحة المشروع.

</div>

---

# Privacy policy — Katib

Last updated: November 2026

Katib records meetings, transcribes them and writes minutes. It is designed
to keep your data on your device wherever possible and to tell you exactly
what leaves the device and where it goes.

## 1. Data the app processes

| Data | Where it is stored | Does it leave the device? |
|---|---|---|
| Audio recordings (WAV files) | App folder on your device | No — unless cloud transcription is enabled (2b) |
| Transcript text | Local database (SQLite) | Yes, to Anthropic when minutes are generated |
| Speaker voiceprints | Local database | **Never** |
| Speaker names you enter | Local database | As part of the transcript sent for minutes |
| Minutes | Local database | Only if you share/export them |
| API keys | OS secure storage | Only to their own provider, for authentication |
| Settings | Local database | No |

A **voiceprint** is a numeric vector describing voice characteristics. It is
used only to match speakers against the speakers saved on your device, is
never transmitted and is used for no other purpose.

## 2. What is sent to external services

### a) Minutes — Anthropic (Claude)
When you generate minutes, the **transcript text** (with speaker names and
timestamps) and the meeting title are sent over HTTPS to Anthropic's Claude
API using your own API key. **Audio is not sent.** Processing is governed by
Anthropic's API terms and privacy policy: <https://www.anthropic.com/legal/privacy>.

### b) Cloud transcription — Deepgram (optional, off by default)
If you select the cloud transcription engine, **audio segments** are sent
over HTTPS to Deepgram with your API key and only text comes back. Governed
by Deepgram's policy: <https://deepgram.com/privacy>. With on-device
transcription (the default) no audio is sent anywhere.

### c) Model downloads
AI models are downloaded once from the sherpa-onnx project's GitHub
releases. This is a download only; no meeting data is sent. GitHub may log
the requesting IP address under its own policy.

### d) What never happens
- No ads, trackers, usage analytics or automatic crash reporting.
- No Katib server: the app talks directly to the services above with your keys.
- No selling or sharing of data with anyone else.

## 3. Security, retention and deletion

- API keys are kept in the OS secure store: Android Keystore, iOS Keychain,
  and DPAPI encryption bound to your Windows user account.
- App data is excluded from cloud backup and device-to-device transfer on
  Android, and from iCloud/computer backups on iOS. Consequently **meetings do
  not move to a new device automatically**; export the minutes you need first.
- You can choose not to keep audio files after transcription (Settings).
- Any meeting, speaker or voiceprint can be deleted at any time in the app.
  Uninstalling the app deletes all of its data from the device.
- Data sent to Anthropic or Deepgram is retained under those providers'
  terms; Katib keeps no copy of it anywhere else.

## 4. Recording consent

Recording people and analysing their voices may require their consent under
the law where you live or work, and voiceprints are sensitive biometric data
in many jurisdictions. **Inform everyone present that the meeting is being
recorded, transcribed and analysed, and obtain their consent before
starting.** Katib shows a reminder before the first recording and a
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

Katib does not request access to contacts, location, photos or the camera.

## 6. Children

The app is not directed at children and does not knowingly collect data
about them.

## 7. Changes and contact

Changes to this policy are published in this file in the repository, with
the update date. For questions, contact the repository owner via the
project page.
