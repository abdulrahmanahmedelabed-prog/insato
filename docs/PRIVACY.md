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
HTTPS باستخدام مفتاحك لمعالجتها، ويعود النص فقط. يطلب إنصاتو في كل طلب
الانسحاب من برنامج تحسين النماذج لدى Deepgram (`mip_opt_out=true`)، أي ألّا
تُستخدم هذه المقاطع في تدريب نماذجها. ومع ذلك فإن مدة احتفاظ Deepgram بالصوت
والنص وكيفية تعاملها معهما تحكمهما سياسة بياناتها هي، لا إنصاتو:
<https://deepgram.com/privacy>. مع التفريغ على الجهاز (الافتراضي) لا يُرسَل أي
صوت.

### ج) تنزيل النماذج
تُنزَّل نماذج الذكاء الاصطناعي مرة واحدة من صفحة إصدارات مشروع sherpa-onnx على
GitHub. هذا تنزيل فقط؛ لا تُرسَل أي بيانات اجتماعات. قد تسجّل GitHub عنوان IP
الخاص بالطلب وفق سياستها.

### د) ما لا يحدث أبداً
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
- البيانات المرسَلة إلى Anthropic أو Deepgram يحكمها احتفاظ تلك الجهات
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

لا يطلب إنصاتو الوصول إلى جهات الاتصال أو الموقع أو الصور أو الكاميرا.

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
over HTTPS to Deepgram with your API key for processing, and only text comes
back. Every request opts out of Deepgram's Model Improvement Program
(`mip_opt_out=true`), asking Deepgram not to use the audio to train its
models. How long Deepgram retains the audio and transcript, and how it
handles them, is still governed by Deepgram's own data policy, not by
Insato: <https://deepgram.com/privacy>. With on-device transcription (the
default) no audio is sent anywhere.

### c) Model downloads
AI models are downloaded once from the sherpa-onnx project's GitHub
releases. This is a download only; no meeting data is sent. GitHub may log
the requesting IP address under its own policy.

### d) What never happens
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
- Data sent to Anthropic or Deepgram is retained under those providers'
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

Insato does not request access to contacts, location, photos or the camera.

## 6. Children

The app is not directed at children and does not knowingly collect data
about them.

## 7. Changes and contact

Changes to this policy are published in this file in the repository, with
the update date. For questions, contact the repository owner via the
project page.
