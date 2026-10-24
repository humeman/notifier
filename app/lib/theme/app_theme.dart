import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// The bundled monospaced family. Declared in pubspec.yaml under `fonts:`.
const kMonoFamily = 'JetBrainsMono';

/// Single source of truth for the app's look. Every screen inherits from here;
/// avoid hardcoding colors or text styles in widgets.
abstract final class AppTheme {
  static ThemeData build() {
    const colorScheme = ColorScheme.dark(
      surface: Palette.background,
      primary: Palette.accent,
      onPrimary: Palette.background,
      secondary: Palette.accent,
      onSurface: Palette.text,
      error: Palette.error,
      outline: Palette.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Palette.background,
      fontFamily: kMonoFamily,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      dividerTheme: const DividerThemeData(
        color: Palette.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kMonoFamily,
          color: Palette.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Palette.accent,
        linearTrackColor: Palette.surfaceHigh,
        strokeWidth: 2,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Palette.surfaceHigh,
        contentTextStyle: TextStyle(
          fontFamily: kMonoFamily,
          color: Palette.text,
          fontSize: 12,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) => base
      .apply(
        fontFamily: kMonoFamily,
        bodyColor: Palette.text,
        displayColor: Palette.text,
      )
      .copyWith(
        // The alert title at the top of the detail page.
        headlineSmall: const TextStyle(
          fontFamily: kMonoFamily,
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          color: Palette.text,
        ),
        titleMedium: const TextStyle(
          fontFamily: kMonoFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: Palette.text,
        ),
        // Section headers: uppercased, tracked out.
        labelLarge: const TextStyle(
          fontFamily: kMonoFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: Palette.textMuted,
        ),
        labelMedium: const TextStyle(
          fontFamily: kMonoFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: Palette.textMuted,
        ),
        bodyMedium: const TextStyle(
          fontFamily: kMonoFamily,
          fontSize: 13,
          height: 1.35,
          color: Palette.text,
        ),
        bodySmall: const TextStyle(
          fontFamily: kMonoFamily,
          fontSize: 11,
          height: 1.3,
          color: Palette.textMuted,
        ),
      );
}
