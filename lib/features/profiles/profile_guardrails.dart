// F16 guardrails applied on the device, on top of the minutes prompt: a
// speaker profile holds only observable, evidence-backed behaviour. Notes
// that describe emotions, psychological traits, health, religion, politics,
// ethnicity, age or other sensitive attributes of the person, or that read
// as hiring / firing / performance scores, are dropped before they reach the
// profile.
//
// The check is deliberately conservative: it may drop a harmless sentence,
// it must not keep a sensitive one. Descriptions of the *person* (style
// observations, contributions, summaries) are checked against every list;
// knowledge descriptions are checked against the scoring list only, because
// knowing about medicine, law or politics as a subject is an observable
// skill.
//
// Pure Dart.

final RegExp _diacritics = RegExp(
  '[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]',
);

/// Normalises Arabic / Latin text for matching: removes diacritics and
/// tatweel, unifies alef / ya / ta marbuta / hamza forms, lower-cases and
/// collapses whitespace.
String normalizeProfileText(String text) {
  var t = text.toLowerCase().replaceAll(_diacritics, '');
  t = t
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Stems that describe a person's emotions, psychology, health or
/// sensitive attributes. Matched (after [normalizeProfileText]) as
/// substrings of the text padded with one space on each side, so a stem
/// with a leading / trailing space only matches at a word edge.
const List<String> kSensitiveAttributeStems = [
  // Emotions / mood (never inferred from voice or words).
  'غاضب', 'غضب', 'متوتر', 'توتر', 'قلق', 'حزين', 'حزن', 'منزعج', 'انزعاج',
  // «عصبيا» / «عصبي »: not «العصبية» of neural networks.
  'عصبيا', 'عصبي ', 'بعصبيه', 'متعصب', 'انفعل', 'منفعل', 'انفعال', 'مزاج', 'مكتئب', 'اكتئاب',
  'محبط', 'احباط', 'خائف', 'خوف', 'مشاعر', 'عاطف', 'مستاء', 'مرتبك',
  'ارتباك', 'خجول', 'متحمس', 'حماس', 'مرهق', 'ارهاق', 'متضايق', 'ضايق',
  // Positive emotions too. Not the bare names «سعيد» / «فرح» nor the title
  // «سعادة»: the adjective / noun forms only.
  'سعيدا', 'سعيده ب', 'بسعاده', 'فرحا', 'فرحه', 'فرحان', 'مسرور', 'مبتهج',
  // Inferences from the voice itself (tone, pitch), not from what was said.
  'نبره', 'من صوته', 'من صوتها', 'صوته يدل', 'صوتها يدل',
  // Psychology / diagnosis / personality labels.
  'نفسيه', 'نفسيا', 'نفسي ', 'اضطراب', 'تشخيص', 'شخصيته', 'شخصيتها', 'نرجس',
  'انطوائي', 'عدواني', ' غبي', 'كسول', 'متعجرف', 'مغرور', 'ثقته بنفسه',
  'ثقتها بنفسها',
  // Health.
  'مرض', 'مريض', 'تعبان', 'صحته', 'صحتها', 'حالته الصحيه', 'حالتها الصحيه', 'اعاقه',
  // Religion / politics / ethnicity / origin.
  'متدين', 'تدين', ' ديني', 'مذهب', 'طائفي', 'طائفه', 'توجهه السياسي',
  'توجهها السياسي', 'ميوله', 'ميولها', 'انتماؤه', 'انتماوه', 'انتماوها',
  'عرقي', 'قبيله', 'قبلي', 'جنسيته', 'جنسيتها', 'اصوله', 'اصولها',
  'لهجته تدل', 'لهجتها تدل',
  // Age / gender / private life.
  'عمره', 'عمرها', 'كبير السن', 'كبيره السن', 'صغير السن', 'صغيره السن',
  'متزوج', 'مطلق', 'حياته الخاصه', 'حياتها الخاصه',
  // English fallbacks (engines occasionally answer in English).
  'emotion', 'angry', 'anxious', 'nervous', 'depress', ' mood', 'personality',
  'upset', 'happy', 'excited', 'frustrat', 'stress', 'tired', ' sick',
  'psycholog', 'diagnos', ' health', 'religio', ' politic', 'ethnic',
  ' race ', 'nationality', ' age ', ' years old',
];

/// Stems of hiring / firing / performance judgements and scores.
const List<String> kScoringStems = [
  'توظيف', 'تعيينه', 'تعيينها', ' فصله', ' فصلها', 'ترقيته', 'ترقيتها',
  'ترقيه', 'يستحق الترقي', 'تستحق الترقي',
  'تقييم اداء', 'تقييم الاداء', 'درجه من', '/10', 'من عشره', 'لا يصلح',
  'لا تصلح', ' يصلح ل', ' تصلح ل', 'غير كفء', 'كفاءته', 'كفاءتها',
  ' hire', 'hiring', ' fire ', ' score', ' rating', 'performance review',
];

final List<String> _attributeNorm = _normalizeStems(kSensitiveAttributeStems);
final List<String> _scoringNorm = _normalizeStems(kScoringStems);

List<String> _normalizeStems(List<String> stems) => [
  for (final s in stems) _padStem(s),
];

String _padStem(String s) {
  final lead = s.startsWith(' ') ? ' ' : '';
  final trail = s.endsWith(' ') ? ' ' : '';
  return '$lead${normalizeProfileText(s)}$trail';
}

bool _matchesAny(String text, List<String> stems) {
  final t = ' ${normalizeProfileText(text)} ';
  for (final s in stems) {
    if (t.contains(s)) return true;
  }
  return false;
}

/// True when [text], describing a person, contains a sensitive or
/// judgemental inference (emotions, psychology, health, sensitive
/// attributes, hiring scores).
bool violatesProfileGuardrails(String text) =>
    _matchesAny(text, _attributeNorm) || _matchesAny(text, _scoringNorm);

/// True when a knowledge description contains a hiring / firing /
/// performance judgement (subject matter itself is never filtered).
bool violatesKnowledgeGuardrails(String text) =>
    _matchesAny(text, _scoringNorm);
