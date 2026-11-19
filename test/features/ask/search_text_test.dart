import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/ask/search_text.dart';

void main() {
  group('normalizeSearchText', () {
    test('unifies alef, ya, ta marbuta and hamza seats', () {
      expect(normalizeSearchText('أإآٱا'), 'ااااا');
      expect(normalizeSearchText('مستشفى'), 'مستشفي');
      expect(normalizeSearchText('ميزانية'), 'ميزانيه');
      expect(normalizeSearchText('مسؤول'), 'مسءول');
      expect(normalizeSearchText('مسئول'), 'مسءول');
      expect(normalizeSearchText('رئيس'), 'رءيس');
      expect(normalizeSearchText('کتاب ی'), 'كتاب ي');
    });

    test('removes diacritics, tatweel and invisible marks', () {
      expect(normalizeSearchText('مُحَمَّدٌ'), 'محمد');
      expect(normalizeSearchText('اجتمـــاع'), 'اجتماع');
      expect(normalizeSearchText('قرا\u200Fر\u2067ات\u2069'), 'قرارات');
    });

    test('converts digits and lower-cases Latin', () {
      expect(normalizeSearchText('٢٠٢٦ و۳ Budget'), '2026 و3 budget');
    });
  });

  group('stemArabic', () {
    test('strips conjunction and article prefixes', () {
      expect(stemArabic('والمشروع'), 'مشروع');
      expect(stemArabic('بالميزانيه'), 'ميزان');
      expect(stemArabic('للموظفين'), 'موظف');
      expect(stemArabic('المهندسين'), 'مهندس');
    });

    test('strips common suffixes', () {
      expect(stemArabic('قرارات'), 'قرار');
      expect(stemArabic('مهندسون'), 'مهندس');
      expect(stemArabic('ميزانيه'), 'ميزان');
      expect(stemArabic('مشروعها'), 'مشروع');
    });

    test('keeps short words', () {
      expect(stemArabic('وقت'), 'وقت');
      expect(stemArabic('ال'), 'ال');
      expect(stemArabic('يد'), 'يد');
    });
  });

  group('stemEnglish', () {
    test('plurals', () {
      expect(stemEnglish('budgets'), 'budget');
      expect(stemEnglish('companies'), 'company');
      expect(stemEnglish('classes'), 'class');
      expect(stemEnglish('status'), 'status');
      expect(stemEnglish('analysis'), 'analysis');
    });

    test('verb endings converge', () {
      expect(stemEnglish('planned'), stemEnglish('planning'));
      expect(stemEnglish('planned'), 'plan');
      expect(stemEnglish('decided'), stemEnglish('decide'));
      expect(stemEnglish('deciding'), stemEnglish('decide'));
      expect(stemEnglish('released'), stemEnglish('release'));
      expect(stemEnglish('called'), 'call');
    });

    test('short words untouched', () {
      expect(stemEnglish('bus'), 'bus');
      expect(stemEnglish('is'), 'is');
    });
  });

  group('analyzeSearchText', () {
    test('drops stop words and stems', () {
      expect(
        analyzeSearchText('ما هي القرارات التي اتُّخذت بشأن الميزانية؟'),
        ['قرار', 'اتخذت', 'ميزان'],
      );
      expect(
        analyzeSearchText('What was decided about the budgets?'),
        ['decid', 'budget'],
      );
    });

    test('spelling variants produce the same terms', () {
      expect(
        analyzeSearchText('الإدارة المالية'),
        analyzeSearchText('الادارة الماليه'),
      );
      expect(analyzeSearchText('مسؤولية'), analyzeSearchText('مسئولية'));
    });

    test('keeps numbers, drops single Latin letters', () {
      expect(analyzeSearchText('Q 4 2026 a'), ['4', '2026']);
    });

    test('mixed scripts', () {
      expect(analyzeSearchText('نشر Kubernetes غداً'), ['نشر', 'kubernet', 'غدا']);
    });
  });
}
