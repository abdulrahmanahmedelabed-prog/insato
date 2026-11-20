// Reading passages for voice enrollment (F1).
//
// Each passage takes about 12–18 seconds to read aloud at a natural pace
// and covers a broad range of speech sounds, so the voiceprint does not
// depend on a few vowels. Arabic passages are Modern Standard Arabic and
// mention numbers, names and meeting vocabulary like real meetings do.

/// Language of a reading passage.
enum EnrollmentLanguage {
  /// Arabic (Modern Standard Arabic).
  arabic,

  /// English.
  english;

  /// BCP-47 code (for text direction and screen readers).
  String get code => this == arabic ? 'ar' : 'en';

  /// Whether the passage is right-to-left.
  bool get isRtl => this == arabic;
}

/// Arabic passages.
const List<String> kArabicEnrollmentPassages = [
  ('صباح الخير جميعًا. نبدأ اجتماعنا اليوم بمراجعة ما أنجزناه في الربع الماضي، '
      'ثم نناقش خطة المشروع الجديد وميزانيته التي تبلغ ثلاثمئة وخمسين ألف ريال. '
      'أرجو من كل فريق أن يعرض أهم التحديات بوضوح، وأن يقترح حلولًا عملية '
      'قبل نهاية الأسبوع القادم.'),
  ('شكرًا على هذا العرض المفيد. لديّ ملاحظتان سريعتان: الأولى تتعلق بموعد '
      'التسليم في الخامس عشر من الشهر، والثانية بتوزيع المهام بين الفرق. '
      'أقترح أن نتفق اليوم على المسؤول عن كل بند، وأن نراجع التقدّم في '
      'اجتماعنا القادم صباح يوم الخميس.'),
  ('اسمحوا لي أن أوضّح الصورة بإيجاز. ارتفعت المبيعات بنسبة اثني عشر في '
      'المئة، لكن تكاليف الشحن زادت أيضًا. لذلك نحتاج إلى قرار واضح بشأن '
      'الموردين، وإلى تقرير مفصّل يقدّمه قسم المالية خلال أسبوعين.'),
];

/// English passages.
const List<String> kEnglishEnrollmentPassages = [
  ('Good morning, everyone. Today we will review last quarter, then discuss '
      'the new project plan and its budget of three hundred and fifty '
      'thousand. Please keep each update short, mention the biggest risk you '
      'see, and propose a practical next step before Thursday.'),
  ('Thank you for the clear presentation. I have two quick points. First, '
      'the delivery date on the fifteenth looks tight. Second, we should '
      'agree on who owns each task, and check the progress together at our '
      'next meeting on Monday morning.'),
  ('Let me summarise briefly. Sales grew by twelve percent, but shipping '
      'costs went up as well. So we need a firm decision about our '
      'suppliers, and a detailed report from the finance team within two '
      'weeks.'),
];

/// The passages of [language].
List<String> enrollmentPassages(EnrollmentLanguage language) =>
    language == EnrollmentLanguage.arabic
    ? kArabicEnrollmentPassages
    : kEnglishEnrollmentPassages;

/// Passage number [index] of [language] (wraps around), so each "improve
/// voice" take can use a different text.
String enrollmentPassage(EnrollmentLanguage language, int index) {
  final list = enrollmentPassages(language);
  return list[index.abs() % list.length];
}
