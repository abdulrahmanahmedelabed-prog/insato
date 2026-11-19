// Material 3 theme of Insato: deep teal / ink seed colour, Noto Naskh Arabic
// with Noto Sans as the Latin fallback, generous tap targets.

import 'package:material_ui/material_ui.dart';

/// Light and dark themes of the app.
abstract final class InsatoTheme {
  /// Seed colour: a deep teal ink.
  static const Color seed = Color(0xFF0E5E6F);

  /// Arabic font family (bundled).
  static const String arabicFont = 'NotoNaskhArabic';

  /// Latin fallback font family (bundled).
  static const List<String> fontFallback = ['NotoSans'];

  /// Width (logical pixels) from which the wide desktop / tablet layout with
  /// a navigation rail and two panes is used.
  static const double wideBreakpoint = 840;

  /// Maximum width of reading content (minutes, settings) on wide screens.
  static const double maxContentWidth = 860;

  /// The light theme.
  static ThemeData light() => _build(Brightness.light);

  /// The dark theme.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: arabicFont,
      fontFamilyFallback: fontFallback,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final text = base.textTheme.apply(
      fontFamily: arabicFont,
      fontFamilyFallback: fontFallback,
    );
    return base.copyWith(
      textTheme: text.copyWith(
        // Naskh glyphs are tall; slightly more line height reads better.
        bodyLarge: text.bodyLarge?.copyWith(height: 1.7),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.65),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 2,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
        contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 16),
      ),
    );
  }
}

/// Text style for clock-like numbers (timers, timestamps): tabular figures
/// so digits do not jitter while counting.
TextStyle tabularFigures(TextStyle? base) => (base ?? const TextStyle())
    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Foreground colour with sufficient contrast on [background] (black or
/// white by relative luminance).
Color onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;
