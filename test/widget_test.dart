// App-level smoke tests: the bundled font licences and the Katib app
// starting in Arabic, right-to-left, over an in-memory database (no native
// plugins). Screen behaviour is covered in test/ui/.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katib/main.dart';
import 'package:katib/ui/screens/home_shell.dart';
import 'package:katib/ui/strings_ar.dart';
import 'package:material_ui/material_ui.dart';

import 'ui/harness.dart';

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

  testWidgets('KatibApp starts in Arabic with an RTL layout', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    await pumpApp(t, env);
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('ar'));
    expect(app.themeMode, ThemeMode.system);
    expect(app.darkTheme, isNotNull);
    expect(
      Directionality.of(t.element(find.byType(HomeShell))),
      TextDirection.rtl,
    );
    expect(find.text(S.appName), findsWidgets);
    expect(find.text(S.newMeeting), findsWidgets);
    await env.dispose(t);
  });
}
