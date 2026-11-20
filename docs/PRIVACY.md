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
| نص التفريغ | قاعدة بيانات محلية (SQLite) | نعم، إلى محرك المحضر السحابي الذي تختاره (Google Gemini افتراضياً، أو Groq؛ وكلاهما مجاني) عند كتابة المحضر؛ لا، مع المحرك المحلي |
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
  يطّلع عليها مراجعون بشريون بعد فصلها عن حسابك. لهذا يعرض إنصاتو هذا التنبيه ويطلب موافقتك قبل أول إرسال، ولا يرسل شيئاً
  دونها. لا تستخدم Gemini المجاني للاجتماعات السرية؛ استخدم لها المحرك المحلي
  على الجهاز. شروط Gemini API: <https://ai.google.dev/gemini-api/terms>،
  وسياسة خصوصية Google: <https://policies.google.com/privacy>.
- **Groq (الخطة المجانية):** يُرسَل النص إلى واجهة Groq البرمجية
  (`api.groq.com`). تقول Groq في سياستها إنها لا تستخدم بيانات واجهتها البرمجية
  لتدريب النماذج، لكنها تعالج النص على خوادمها وقد تحتفظ به مؤقتاً وفق سياستها؛
  وهذا تعهّد من المزوّد وليس ضماناً من إنصاتو. يعرض إنصاتو هذا التنبيه ويطلب
  موافقتك قبل أول إرسال. سياسة خصوصية Groq: <https://groq.com/privacy-policy/>.
- **التبديل بين المحركين المجانيين (اختياري):** إذا نفدت الحصة اليومية للمحرك
  المختار يُعرَض عليك (أو يُستخدم تلقائياً إن فعّلت ذلك) المحرك المجاني الآخر،
  بشرط أن يكون مفتاحه محفوظاً وتنبيه خصوصيته مقبولاً؛ فلا يُرسَل شيء إلى مزوّد
  لم توافق عليه.
- **لا خدمات مدفوعة:** أُزيل محركا Claude (Anthropic) وDeepgram في الإصدار 1.2،
  وحُذفت مفاتيحهما المحفوظة من الجهاز عند الترقية.
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
سحابي (Gemini أو Groq) سبق أن وافقت عليه؛ ولا تُحفظ نتائجه.

### ب) التفريغ السحابي — Groq Whisper (اختياري ومجاني، معطّل افتراضياً)
إذا اخترت التفريغ السحابي ووافقت على تنبيه خصوصيته الخاص، تُرسَل **مقاطع
الصوت** (ملفات WAV قصيرة) إلى Groq عبر HTTPS باستخدام مفتاحك لتحويلها إلى نص،
ويعود النص فقط. تقول Groq في سياستها إنها لا تستخدم بيانات واجهتها البرمجية
لتدريب النماذج، لكن الصوت يُعالَج على خوادمها وفق سياستها، لا وفق إنصاتو:
<https://groq.com/privacy-policy/>. مع التفريغ على الجهاز (الافتراضي) لا يُرسَل
أي صوت؛ وإذا نفدت الحصة المجانية أثناء الاجتماع يكمل إنصاتو على الجهاز فلا
يُرسَل ما تبقى. ومع التفريغ السحابي يُرسَل أيضاً تلميح قصير (حتى 180 حرفاً) من
مصطلحات القاموس وأسماء الحضور المتوقعين والمتحدثين المسمَّين لتحسين التعرّف
عليها.

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

### هـ) حزمة الاجتماع (الإصدار 1.2) — ملف تنقله أنت
- لا يغادر ملف «حزمة الاجتماع» (`.insato`) الجهاز إلا حين تختار مشاركته أو
  حفظه، ويُنقل بالوسيلة التي تختارها (كابل، بلوتوث، المشاركة القريبة، AirDrop،
  بطاقة ذاكرة، بريد). لا يمرّ بأي خادم لإنصاتو.
- **ما يحتويه**: عنوان الاجتماع ووقت بدايته ومدته وسياقه، واسم الجهاز ونوع
  نظامه، والنص الكامل بأوقاته ولغاته، وأسماء المتحدثين كما على الجهاز المصدِّر،
  ونسبة وضوح الصوت لكل مقطع؛ و**اختيارياً** التسجيل الصوتي والمحضر.
- **بصمات الصوت بيانات حيوية (بيومترية)**: لا تُضمَّن في الحزمة إلا إذا فعّلت
  «تضمين بصمات الصوت» في نافذة التصدير نفسها (معطّل افتراضياً ولا يُحفظ هذا
  الاختيار). لا تضمّنها إلا بموافقة المتحدثين ولجهة تثق بها.
- بلا كلمة مرور يستطيع قراءة الملف كل من يحصل عليه. بكلمة مرور تُشفَّر كل
  محتوياته (AES-256-GCM بمفتاح مشتق من كلمة المرور بـ PBKDF2)؛ لا تُحفظ كلمة
  المرور في الملف، فأبلغها للمستلم بطريقة أخرى. وتحمل الحزمة بصمة SHA-256 لكل
  جزء، فيرفض إنصاتو أي ملف تلف أو عُدِّل بعد التصدير.
- عند الدمج تُضاف محتويات الحزمة إلى الاجتماع على الجهاز الرئيسي (ومنها بصمات
  الصوت إن ضُمّنت، فتُضاف إلى مكتبة الأصوات أو تُطابق متحدثاً معروفاً)، وتُحفظ
  نسخة من حال الاجتماع قبل الدمج للتراجع عنه؛ تُحذف هذه النسخة وتسجيلها مع
  حذف الاجتماع. احذف ملف الحزمة من الأجهزة الوسيطة بعد الاستيراد.

### و) المكالمة الحية (الإصدار 1.2) — عبر الإنترنت، بين جهازين فقط
لا تبدأ المكالمة إلا بفعل شخص على كل جهاز: يبدؤها أحدهما فيظهر رمز، وينضم
الآخر بنفسه بكتابة الرمز أو مسحه. لا ردّ تلقائي ولا تشغيل في الخلفية ولا وضع
خفي، ويُعرض إشعار موافقة قبل المكالمة الأولى.
- **الصوت**: يُرسل صوت الميكروفون بتقنية WebRTC مشفّراً (DTLS-SRTP) **مباشرةً
  بين الجهازين**. إن منعت الشبكة الاتصال المباشر وضبطتَ خادم TURN، يمرّ الصوت
  عبره مشفّراً دون أن يستطيع سماعه. يُستخدم خادم STUN عام
  (`stun.l.google.com`) فقط ليعرف كل جهاز عنوانه العام؛ لا يمرّ عبره صوت ولا نص.
- **خادم الإشارة** (تنشره أنت أو جهتك، مجاناً): يمرّر رسائل إعداد الاتصال فقط
  (وصف الجلسة SDP ومرشّحات الشبكة ICE واسم الجهاز ونهاية المكالمة)، وكلها
  **مشفّرة وموثّقة** (ChaCha20-Poly1305) بمفتاح مشتق من رمز المكالمة الذي لا
  يُرسل عبر الشبكة أبداً. يرى الخادم معرّف غرفة (بصمة أحادية الاتجاه للرمز)
  وعناوين IP للجهازين وتوقيت الاتصال وحجم الرسائل، ولا يستطيع قراءتها ولا
  تزويرها ولا انتحال أحد الطرفين: بصمة شهادة كل جهاز موقّعة بمفتاح الرمز
  ويتحقق منها الطرف الآخر، ويُعرض «رمز أمان» يجب أن يتطابق على الشاشتين.
  لا يحفظ الخادم المرجعي شيئاً ولا يسجّل معرّفات الغرف أو العناوين.
- **النص**: يفرّغ كل جهاز ميكروفونه على الجهاز نفسه (أو عبر Groq إن اخترت
  التفريغ السحابي) ويرسل النص وأسماء المتحدثين (كما يعرفها جهازه) إلى الطرف
  الآخر عبر قناة البيانات المشفّرة نفسها. لا تُرسل البصمات الصوتية.
- **الحفظ**: يحفظ كل جهاز الاجتماع لديه: تسجيل ميكروفونه هو (لا يُسجَّل صوت
  الطرف الآخر كملف)، والنص المدمج للطرفين، وسجل المكالمة (اسما الجهازين،
  ووقتا بدء البث وإيقافه ومن أوقفه، والكتم وانقطاعات الاتصال، ورمز الأمان).
  يُحذف السجل مع الاجتماع. يُرسل النص إلى محرك المحضر الذي اخترته كأي اجتماع.
- **أثناء البث**: مؤشر «يتم البث والتفريغ» ظاهر على الشاشتين مع زر إيقاف
  بلمسة واحدة، وإشعار دائم على Android بزر «إيقاف البث». الكتم يوقف إرسال
  الصوت وتفريغه معاً. إغلاق التطبيق ينهي المكالمة.

### ز) ما لا يحدث أبداً
- لا إعلانات، ولا أدوات تتبّع، ولا تحليلات استخدام، ولا تقارير أعطال تلقائية.
- لا خادم خاص بإنصاتو: التطبيق يتصل مباشرة بالخدمات أعلاه بمفاتيحك (وخادم
  إشارة المكالمة الحية تنشره أنت ولا يرى إلا رسائل مشفّرة).
- لا بيع ولا مشاركة للبيانات مع أي طرف آخر.

### ح) استيراد تسجيل (مكالمة أو مذكرة صوتية)
- الملف الذي تختاره أو تشاركه إلى إنصاتو يُقرأ على جهازك فقط، ويُفكّ ترميزه
  بمفكّكات نظام التشغيل نفسه (لا خدمة خارجية ولا خدمة مدفوعة). تُحذف النسخة
  المؤقتة التي يصنعها النظام عند المشاركة بعد الاستيراد، ويبقى ملفك الأصلي
  كما هو.
- يُعامل الاجتماع المستورد كأي اجتماع مسجّل: يُحفظ الصوت المحوَّل في مجلد
  التسجيلات الخاص بالتطبيق فقط إذا كان «الاحتفاظ بالتسجيل الصوتي» مفعّلاً،
  ويُرسَل إلى الخدمات الخارجية ما يُرسَل في الاجتماع المسجّل نفسه (مقاطع الصوت
  إلى Deepgram إن اخترت التفريغ السحابي، والنص إلى محرك المحضر).
- يُحفظ مع الاجتماع اسم الملف الأصلي وصيغته فقط، ويُحذفان بحذفه.
- **تسجيل المكالمات تحكمه قوانين تختلف من بلد إلى آخر؛** يذكّرك إنصاتو بذلك
  قبل كل استيراد، وعليك التأكد من أن التسجيل مسموح به وأن المشاركين علموا به.
### ط) روبوت الاجتماع (ويندوز)

عند إرسال روبوت إنصاتو إلى اجتماع Google Meet أو Microsoft Teams أو Zoom أو
Webex يفتح التطبيق متصفح Microsoft Edge (أو Chrome) مستقلاً بملف تعريف مؤقت
يُحذف بعد الاجتماع، ويدخل بصفته ضيفاً باسم ظاهر لكل المشاركين (افتراضياً
«إنصاتو — كاتب المحضر»)، ولا يدخل إلا إذا سمح له المنظّم. ميكروفون الروبوت
ملف صامت دائماً والكاميرا مرفوضة، فلا يُرسل أي صوت أو صورة من جهازك. يُسجَّل
صوت متصفح الروبوت وحده (ويندوز 10 الإصدار 2004 أو أحدث)، وإلا فكل ما يصدر من
السماعات مع تنبيه واضح. يتصل المتصفح بخدمة الاجتماع مباشرة كما لو انضممت
بنفسك، وتنطبق سياسة خصوصية تلك الخدمة على ذلك؛ لا يمرّ شيء بخوادم إنصاتو. لا
يتجاوز الروبوت أي إعداد أمان (غرفة الانتظار، التحقق البشري، اشتراط الحساب).
عليك إبلاغ المشاركين بالتسجيل والحصول على موافقتهم وفق الأنظمة المعمول بها.

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
- البيانات المرسَلة إلى Google أو Groq يحكمها احتفاظ تلك الجهات
  وفق شروطها؛ لا يملك إنصاتو نسخة منها.

## 4. الموافقة على التسجيل

تسجيل الأشخاص وتحليل أصواتهم قد يتطلب موافقتهم بموجب القانون في بلدك أو
مكان عملك، والبصمة الصوتية تُعد بيانات حيوية حساسة في كثير من الأنظمة.
**يجب إبلاغ جميع الحاضرين بأن الاجتماع يُسجَّل ويُفرَّغ ويُحلَّل، والحصول على
موافقتهم قبل البدء.** يعرض إنصاتو تذكيراً بذلك قبل أول تسجيل، ويظهر إشعار دائم
أثناء التسجيل على Android. المستخدم هو المسؤول عن الالتزام بالأنظمة المعمول
بها، وعن حذف بصمة أي شخص يطلب ذلك.

**المكالمات الهاتفية (وضع المكالمة):** تسجيل المكالمات تنظّمه قوانين خاصة
تختلف من بلد إلى آخر؛ كثير منها يشترط علم جميع أطراف المكالمة أو موافقتهم،
وقد يُعدّ تسجيل مكالمة دون إذن مخالفة أو جريمة. أبلِغ الطرف البعيد في بداية
المكالمة بأنها تُسجَّل وتُفرَّغ لإعداد محضر، واحصل على موافقة الحاضرين في
الطرفين. يعرض إنصاتو هذا التنبيه في شاشة إعداد المكالمة ولا يبدأ قبل تأكيده.
لا يتصل إنصاتو بشبكة الهاتف ولا بتطبيق Phone Link: يسجّل فقط ما يصدر من سمّاعات
الحاسوب وما يلتقطه الميكروفون، ويُعالَج كل ذلك على الجهاز كأي اجتماع (ويُرسل
النص وحده إلى محرك المحضر المختار). تُحفظ مع الاجتماع طريقة الالتقاط ونسبة كل
مقطع إلى الطرف المحلي أو البعيد، وتُحذف بحذفه. البصمات المتعلَّمة من صوت
الطرف البعيد تُوسَم بأنها من خط الهاتف.

## 5. الأذونات

| الإذن | السبب |
|---|---|
| الميكروفون | تسجيل الاجتماع — الوظيفة الأساسية |
| الإشعارات (Android 13+) | إظهار إشعار «جارٍ التسجيل» أثناء عمل التسجيل في الخلفية |
| الإنترنت | تنزيل النماذج، وكتابة المحضر، والتفريغ السحابي الاختياري |
| منع السكون / الخدمة المقدّمة / الصوت في الخلفية | استمرار التسجيل مع إطفاء الشاشة |
| الشبكة المحلية (iOS)، حالة الشبكة وWi-Fi والبث المتعدد (Android) | الاجتماع متعدد الأجهزة: الاتصال بين الأجهزة في القاعة واكتشافها على الشبكة المحلية |
| الكاميرا (اختياري) | مسح رمز QR للانضمام إلى اجتماع متعدد الأجهزة أو مكالمة حية فقط؛ لا تُلتقط صور ولا تُحفظ |
| الخدمة المقدّمة لتشغيل الوسائط وتغيير حالة الشبكة (Android) | المكالمة الحية: تشغيل صوت الطرف الآخر مع إشعار «يتم البث والتفريغ» واستمرار الاتصال عند تغيّر الشبكة |

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
| Transcript text | Local database (SQLite) | Yes, to the cloud minutes engine you choose (Google Gemini by default, or Groq — both free) when minutes are generated; no with the on-device engine |
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
  them after they are disconnected from your account. Insato therefore shows this notice
  and asks for your agreement before the first request, and sends nothing
  without it. Do not use the free Gemini tier for confidential meetings — use
  the on-device engine. Gemini API terms:
  <https://ai.google.dev/gemini-api/terms>; Google privacy policy:
  <https://policies.google.com/privacy>.
- **Groq (free plan):** the text is sent to Groq's API (`api.groq.com`).
  Groq's stated policy is that it does not use API data to train models, but
  it processes the text on its servers and may retain it temporarily under
  its policy — this is the provider's statement, not a guarantee by Insato.
  Insato shows this notice and asks for your agreement before the first
  request. Groq privacy policy: <https://groq.com/privacy-policy/>.
- **Switching between the free engines (optional):** when the selected
  engine's daily quota is used up, the other free cloud engine is offered (or
  used automatically if you enabled that) — only if its key is stored and its
  notice accepted, so nothing goes to a provider you did not accept.
- **No paid services:** the Claude (Anthropic) and Deepgram engines were
  removed in 1.2, and their stored keys are deleted from the device on
  upgrade.
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
only to a cloud engine (Gemini or Groq) you already accepted; its results
are not stored.

### b) Cloud transcription — Groq Whisper (optional, free, off by default)
If you select cloud transcription and accept its own privacy notice, **audio
segments** (short WAV files) are sent over HTTPS to Groq with your API key,
and only text comes back. Groq's stated policy is not to use API data for
training, but the audio is processed on its servers under Groq's policy, not
Insato's: <https://groq.com/privacy-policy/>. With on-device transcription
(the default) no audio is sent anywhere; if the free quota runs out during a
meeting, Insato finishes on the device and sends nothing more. With cloud
transcription a short hint (up to 180 characters) of glossary terms and the
names of expected attendees and named speakers is also sent to improve their
recognition.

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

### e) Meeting packages (version 1.2) — a file you move yourself
- A meeting package (`.insato`) leaves the device only when you share or
  save it, and travels by the means you choose (cable, Bluetooth, Nearby
  Share, AirDrop, SD card, e-mail). It never goes through an Insato server.
- **What it contains**: the meeting title, start time, duration and context,
  the device name and platform, the full transcript with timestamps and
  languages, the speaker names as on the exporting device and a per-segment
  signal-to-noise ratio; **optionally** the recording and the minutes.
- **Voiceprints are biometric data**: they are included only when you turn
  on "تضمين بصمات الصوت" in that export dialog (off by default, never
  remembered). Include them only with the speakers' consent and for a
  recipient you trust.
- Without a password anyone holding the file can read it. With a password
  every entry is encrypted (AES-256-GCM, key derived with PBKDF2); the
  password is not stored in the file, so tell it to the recipient another
  way. Every entry is listed with its SHA-256, so Insato refuses a file that
  was damaged or modified after export.
- Merging adds the package's content to the meeting on the main device
  (including voiceprints when present, which join the voice library or match
  a known speaker) and keeps a snapshot of the meeting as it was, for undo;
  the snapshot and its recording are deleted with the meeting. Delete the
  package file from intermediate devices after importing it.

### f) Live call (version 1.2) — over the internet, two devices only
A call only starts by a person's action on each device: one starts it and
gets a code, the other joins by typing or scanning it. No auto-answer, no
background start, no hidden mode; a consent notice is shown before the
first call.
- **Audio**: the microphone audio is sent with WebRTC, encrypted
  (DTLS-SRTP), **directly between the two devices**. If the network blocks
  direct connections and you configured a TURN server, audio passes through
  it, still encrypted and unreadable to it. A public STUN server
  (`stun.l.google.com`) only tells each device its public address; no audio
  or text goes through it.
- **Signaling relay** (deployed by you or your organisation, free): it only
  forwards call-setup messages (SDP session description, ICE network
  candidates, device name, hang-up), all **sealed and authenticated**
  (ChaCha20-Poly1305) with a key derived from the call code, which is never
  sent over the network. The relay sees a room id (a one-way hash of the
  code), both devices' IP addresses, timing and message sizes; it can
  neither read nor forge the messages nor impersonate a side: each device's
  certificate fingerprint is authenticated with the code key and verified
  by the other, and a safety code that must match is shown on both
  screens. The reference relay stores nothing and logs no room ids or
  addresses.
- **Text**: each device transcribes its own microphone on the device (or
  with Groq if you chose cloud transcription) and sends the text and
  speaker names (as that device knows them) to the other side over the same
  encrypted data channel. Voiceprints are never sent.
- **Storage**: each device saves the meeting: its own microphone recording
  (the other side's audio is not saved as a file), the merged transcript of
  both sides, and the call log (both device names, when streaming started
  and stopped and who stopped it, mutes and reconnections, the safety code).
  The log is deleted with the meeting. The text goes to your minutes engine
  like any meeting.
- **While streaming**: a «يتم البث والتفريغ» indicator is on both screens
  with a one-tap stop, plus an ongoing Android notification with a stop
  button. Mute stops both sending and transcribing your audio. Closing the
  app ends the call.

### g) What never happens
- No ads, trackers, usage analytics or automatic crash reporting.
- No Insato server: the app talks directly to the services above with your keys
  (the live-call signaling relay is deployed by you and only sees sealed
  messages).
- No selling or sharing of data with anyone else.

### h) Importing a recording (phone call, voice memo)
- The file you choose or share to Insato is read on your device only and
  decoded with the operating system's own decoders (no external or paid
  service). The temporary copy the OS makes when sharing is deleted after the
  import; your original file is left untouched.
- An imported meeting is treated like a recorded one: the converted audio is
  kept in the app's private recordings folder only when "keep audio" is on,
  and the same data leaves the device as for a recorded meeting (audio
  segments to Deepgram if you chose cloud transcription, the transcript to
  the minutes engine).
- Only the original file name and format are stored with the meeting, and
  they are deleted with it.
- **Call-recording laws differ between countries;** Insato reminds you
  before every import — make sure the recording is lawful and that the
  participants were informed.
### i) Meeting bot (Windows)

When you send Insato's bot to a Google Meet, Microsoft Teams, Zoom or Webex
meeting, the app starts a separate Microsoft Edge (or Chrome) with a
temporary profile that is deleted afterwards. The bot joins as a guest
under a name every participant sees (default «إنصاتو — كاتب المحضر») and
only when the organiser admits it. Its microphone is a silent file and the
camera permission is denied, so nothing from your devices is sent. Only the
bot browser's audio is recorded (Windows 10 version 2004 or later),
otherwise the whole system output with a clear warning. The browser talks
to the meeting service directly, as if you had joined yourself, under that
service's privacy policy; nothing goes through Insato servers. The bot
never bypasses meeting security (waiting rooms, human checks, sign-in
requirements). You are responsible for informing participants and
obtaining their consent as required by applicable law.

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
- Data sent to Google or Groq is retained under those providers'
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

**Phone calls (phone-call mode):** call recording is governed by specific
laws that differ between countries; many require every party to the call to
be informed or to consent, and recording a call without permission may be an
offence. Tell the remote side at the start of the call that it is being
recorded and transcribed for minutes, and obtain the consent of everyone on
both sides. Insato shows this notice on the call setup screen and does not
start before it is confirmed. Insato does not connect to the phone network
or to Phone Link: it only records what the PC speakers play and what the
microphone hears, processed on the device like any meeting (only the text
goes to the chosen minutes engine). The capture mode and the side (local /
remote) of each segment are stored with the meeting and deleted with it.
Voiceprints learned from remote speech are tagged as telephone-line
voiceprints.

## 5. Permissions

| Permission | Why |
|---|---|
| Microphone | Recording the meeting — the core function |
| Notifications (Android 13+) | The "recording in progress" notification during background recording |
| Internet | Model downloads, minutes generation, optional cloud transcription |
| Wake lock / foreground service / background audio | Keep recording with the screen off |
| Local network (iOS); network state, Wi-Fi state, multicast (Android) | Multi-device meetings: connecting and discovering the devices in the room on the local network |
| Camera (optional) | Only to scan the QR code that joins a multi-device meeting or a live call; no photos are taken or stored |
| Media-playback foreground service, change network state (Android) | Live call: playing the other side's voice with the «يتم البث والتفريغ» notification, and keeping the call across network changes |

Insato does not request access to contacts, location or photos, and uses
the camera only to scan a join code when you ask it to.

## 6. Children

The app is not directed at children and does not knowingly collect data
about them.

## 7. Changes and contact

Changes to this policy are published in this file in the repository, with
the update date. For questions, contact the repository owner via the
project page.
