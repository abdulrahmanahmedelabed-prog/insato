// Text normalisation shared by every layer (search, task matching).

import 'time_format.dart';

final RegExp _arabicDiacritics = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

/// Normalises [text] for forgiving Arabic search: removes diacritics and
/// tatweel, unifies alef / ya / ta marbuta / hamza forms, converts
/// Arabic-Indic digits and lower-cases Latin letters.
String normalizeForSearch(String text) {
  var t = toWesternDigits(text).toLowerCase().replaceAll(_arabicDiacritics, '');
  t = t
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}
