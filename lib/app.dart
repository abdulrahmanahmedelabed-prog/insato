// TEMPORARY placeholder so the app builds before the UI module lands.
// The UI module replaces this file with the real MaterialApp (theme, RTL,
// routes); only the `KatibApp` class name is relied upon by `main.dart`.

import 'package:material_ui/material_ui.dart';

/// Root widget of Katib.
class KatibApp extends StatelessWidget {
  /// Creates the app.
  const KatibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كاتب',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        fontFamily: 'NotoNaskhArabic',
      ),
      home: const Scaffold(body: Center(child: Text('كاتب'))),
    );
  }
}
