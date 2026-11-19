// Root widget of Insato (إنصاتو): Material 3 app, Arabic locale with RTL
// layout, light / dark themes following the system, and the home shell.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'ui/screens/home_shell.dart';
import 'ui/strings_ar.dart';
import 'ui/theme.dart';

/// Root widget of Insato. Must be placed under a Riverpod `ProviderScope`
/// (main.dart uses an `UncontrolledProviderScope` with the app database).
class InsatoApp extends ConsumerWidget {
  /// Creates the app.
  const InsatoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: S.appName,
      onGenerateTitle: (_) => S.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: InsatoTheme.light(),
      darkTheme: InsatoTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
