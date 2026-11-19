// Smoke test of the app bootstrap helpers in main.dart.
//
// (The Flutter template's counter test was replaced when main.dart became the
// Katib bootstrap; screens are covered by the UI module's own tests.)

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katib/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled Noto font licences are available for the licence page',
    () async {
      final entries = await bundledFontLicenses().toList();
      expect(entries, hasLength(1));
      final LicenseEntry entry = entries.single;
      expect(entry.packages, ['NotoNaskhArabic', 'NotoSans']);
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('SIL OPEN FONT LICENSE'));
    },
  );
}
