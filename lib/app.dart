// Root widget of Katib (كاتب): Material 3 app, Arabic locale with RTL
// layout, light / dark themes following the system, and the home shell.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'ui/screens/home_shell.dart';
import 'ui/strings_ar.dart';
import 'ui/theme.dart';

/// Root widget of Katib. Must be placed under a Riverpod `ProviderScope`
/// (main.dart uses an `UncontrolledProviderScope` with the app database).
class KatibApp extends ConsumerWidget {
  /// Creates the app.
  const KatibApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: S.appName,
      onGenerateTitle: (_) => S.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: KatibTheme.light(),
      darkTheme: KatibTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
