// Text analysis for "Ask your meetings" (F8): normalisation, tokenisation,
// stop-word removal and light stemming for Arabic and English, so that a
// question matches transcripts and minutes despite spelling variants
// (أ/إ/آ/ا, ى/ي, ة/ه, diacritics, tatweel) and common affixes (ال، و، ب…،
// ات، ون، ين…; plural / -ing / -ed in English).
//
// Pure Dart (no Flutter): unit-tested and usable inside an isolate.

/// Arabic diacritics (harakat, tanwin, shadda, sukun, superscript alef),
/// Quranic annotation marks and tatweel.
final RegExp _arabicMarks = RegExp(
  '[ؐ-ًؚ-ٰٟۖ-ۭـ]',
);

/// Bidi controls and zero-width characters that split words invisibly.
final RegExp _invisible = RegExp('[​-‏‪-‮⁦-⁩﻿]');

/// A token: a run of letters / digits (any script).
final RegExp _tokenPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

final RegExp _hasArabic = RegExp('[؀-ۿ]');

/// Normalises [text] for matching: Western digits, lower-case Latin, no
/// diacritics / tatweel / invisible marks, unified alef (أإآٱ → ا), ya
/// (ى، ی → ي), ta marbuta (ة → ه), hamza seats (ؤ → و، ئ → ي) and Persian
/// kaf (ک → ك).
String normalizeSearchText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0);
    } else {
      buffer.writeCharCode(switch (rune) {
        0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627, // أ إ آ ٱ → ا
        0x0649 || 0x06CC || 0x064A => 0x064A, // ى ی → ي
        0x0629 => 0x0647, // ة → ه
        0x0624 => 0x0648, // ؤ → و
        0x0626 => 0x064A, // ئ → ي
        0x06A9 => 0x0643, // ک → ك
        _ => rune,
      });
    }
  }
  return buffer
      .toString()
      .replaceAll(_arabicMarks, '')
      .replaceAll(_invisible, '')
      .toLowerCase();
}

/// Arabic function words and question words (normalised forms) that carry
/// no topical meaning.
const Set<String> _arabicStopWordsRaw = {
  'في', 'من', 'الى', 'إلى', 'على', 'عن', 'مع', 'او', 'أو', 'ثم', 'بل',
  'لا', 'لم', 'لن', 'ما', 'ماذا', 'لماذا', 'متى', 'اين', 'أين', 'كيف', 'هل',
  'كم', 'اي', 'أي', 'اية', 'هذا', 'هذه', 'ذلك', 'تلك', 'هذان', 'هؤلاء',
  'الذي', 'التي', 'الذين', 'اللذين', 'اللتين', 'اللواتي', 'هو', 'هي', 'هم',
  'هن', 'انا', 'أنا', 'نحن', 'انت', 'أنت', 'انتم', 'أنتم', 'كان', 'كانت',
  'كانوا', 'يكون', 'تكون', 'قد', 'لقد', 'ان', 'أن', 'إن', 'انه', 'أنه',
  'انها', 'أنها', 'كل', 'بعض', 'غير', 'عند', 'عندما', 'حتى', 'اذا', 'إذا',
  'لو', 'لكن', 'لكنه', 'ايضا', 'أيضا', 'فقط', 'جدا', 'و', 'ف', 'ب', 'ل',
  'ك', 'به', 'بها', 'له', 'لها', 'لهم', 'فيه', 'فيها', 'منه', 'منها',
  'عليه', 'عليها', 'هناك', 'هنا', 'الان', 'الآن', 'بين', 'حول', 'قبل',
  'بعد', 'خلال', 'دون', 'ذات', 'يا', 'اما', 'أما', 'اذ', 'إذ', 'كما', 'مثل',
  'تم', 'وما', 'وهل', 'فما', 'شيء', 'اللي', 'اللى', 'يعني', 'طيب',
};

/// English stop words.
const Set<String> _englishStopWords = {
  'a', 'an', 'the', 'and', 'or', 'but', 'if', 'then', 'of', 'to', 'in',
  'on', 'at', 'by', 'for', 'with', 'about', 'from', 'into', 'over', 'as',
  'is', 'are', 'was', 'were', 'be', 'been', 'being', 'am', 'do', 'does',
  'did', 'done', 'have', 'has', 'had', 'what', 'which', 'who', 'whom',
  'whose', 'when', 'where', 'why', 'how', 'this', 'that', 'these', 'those',
  'it', 'its', 'i', 'we', 'you', 'he', 'she', 'they', 'me', 'us', 'him',
  'her', 'them', 'my', 'our', 'your', 'their', 'not', 'no', 'so', 'than',
  'too', 'very', 'can', 'could', 'will', 'would', 'should', 'shall', 'may',
  'might', 'must', 'there', 'here', 'any', 'all', 'some', 'just', 'also',
  'again', 'tell', 'please', 'say', 'said',
};

final Set<String> _arabicStopWords = {
  for (final w in _arabicStopWordsRaw) normalizeSearchText(w),
};

/// Prefixes removed by [stemArabic] (normalised forms, longest first), after
/// an optional leading conjunction و.
const List<String> _arabicArticlePrefixes = [
  'وال', 'بال', 'كال', 'فال', 'لل', 'ال', //
];

/// Suffixes removed by [stemArabic] (normalised forms, in order: Larkey's
/// "light10" list with ة → ه and ى → ي).
const List<String> _arabicSuffixes = [
  'ها', 'ان', 'ات', 'ون', 'ين', 'يه', 'ه', 'ي', //
];

/// Light Arabic stemmer (after Larkey et al., "light10") for a normalised
/// word: strips a leading و (word longer than 3 letters), one definite
/// article form (وال، بال، كال، فال، لل، ال) when at least 2 letters remain,
/// then each suffix of ها، ان، ات، ون، ين، يه، ه، ي in turn while at least 2
/// letters remain.
String stemArabic(String word) {
  var w = word;
  if (w.length > 3 && w.startsWith('و')) w = w.substring(1);
  for (final p in _arabicArticlePrefixes) {
    if (w.startsWith(p) && w.length - p.length >= 2) {
      w = w.substring(p.length);
      break;
    }
  }
  for (final s in _arabicSuffixes) {
    if (w.length > s.length + 1 && w.endsWith(s)) {
      w = w.substring(0, w.length - s.length);
    }
  }
  return w;
}

bool _isVowel(int c) => 'aeiou'.codeUnits.contains(c);

/// Light English stemmer for a lower-case word: plural endings (-ies → y,
/// -sses → ss, -s), then -ing / -ed (undoubling a final doubled consonant:
/// planned → plan) and a final silent -e (decide / decided → decid). Words
/// of 3 letters or fewer are left alone.
String stemEnglish(String word) {
  var w = word;
  if (w.length <= 3) return w;
  if (w.endsWith('ies') && w.length > 4) {
    w = '${w.substring(0, w.length - 3)}y';
  } else if (w.endsWith('sses')) {
    w = w.substring(0, w.length - 2);
  } else if (w.endsWith('s') &&
      !w.endsWith('ss') &&
      !w.endsWith('us') &&
      !w.endsWith('is')) {
    w = w.substring(0, w.length - 1);
  }
  var stripped = false;
  if (w.endsWith('ing') && w.length > 5) {
    w = w.substring(0, w.length - 3);
    stripped = true;
  } else if (w.endsWith('ed') && w.length > 4) {
    w = w.substring(0, w.length - 2);
    stripped = true;
  }
  if (stripped && w.length > 3) {
    final last = w.codeUnitAt(w.length - 1);
    final prev = w.codeUnitAt(w.length - 2);
    if (last == prev && !_isVowel(last) && !'lsz'.codeUnits.contains(last)) {
      w = w.substring(0, w.length - 1);
    }
  }
  if (w.length > 4 && w.endsWith('e')) w = w.substring(0, w.length - 1);
  return w;
}

/// Splits normalised text into raw tokens (no stop-word removal).
Iterable<String> _rawTokens(String normalized) =>
    _tokenPattern.allMatches(normalized).map((m) => m.group(0)!);

/// Analyses [text] into index terms: normalised, tokenised, stop words
/// removed, stemmed (Arabic or English by script). Single Latin letters are
/// dropped; numbers are kept.
List<String> analyzeSearchText(String text) {
  final out = <String>[];
  for (final token in _rawTokens(normalizeSearchText(text))) {
    if (_hasArabic.hasMatch(token)) {
      if (_arabicStopWords.contains(token)) continue;
      final stem = stemArabic(token);
      if (stem.isEmpty || _arabicStopWords.contains(stem)) continue;
      out.add(stem);
    } else {
      if (_englishStopWords.contains(token)) continue;
      if (token.length == 1 && !_isDigit(token.codeUnitAt(0))) continue;
      out.add(stemEnglish(token));
    }
  }
  return out;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
