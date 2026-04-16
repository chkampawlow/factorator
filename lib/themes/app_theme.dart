import 'package:flutter/material.dart';

class AppTheme {
  /// Subtle, professional accent (used sparingly).
  static const accent = Color(0xFF0F766E); // muted teal

  /// Neutral surfaces
  static const lightBg = Color(0xFFF6F7F9);
  static const lightSurface = Colors.white;

  static const darkBg = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF0F172A);
  static const darkCard = Color(0xFF111827);

  static const textDark = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const textMutedDark = Color(0xFF94A3B8);

  /// Make dark mode the default in your MaterialApp by using:
  /// themeMode: AppTheme.defaultThemeMode,
  static const ThemeMode defaultThemeMode = ThemeMode.dark;

  /// Convenience: use this if you want a single default theme.
  static ThemeData defaultTheme({Color primaryColor = accent}) =>
      dark(primaryColor: primaryColor);

  static ThemeData light({Color primaryColor = accent}) {
    final cs = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs.copyWith(
        primary: primaryColor,
        surface: lightSurface,
        background: lightBg,
        // Keep containers neutral so the UI doesn't look “too colored”.
        primaryContainer: const Color(0xFFE7EEF0),
        secondaryContainer: const Color(0xFFEFF2F6),
        tertiaryContainer: const Color(0xFFEFF2F6),
      ),
      scaffoldBackgroundColor: lightBg,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F2F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
        bodyMedium: TextStyle(fontSize: 14, color: textDark),
        bodySmall: TextStyle(fontSize: 12, color: textMuted),
      ),
    );
  }

  static ThemeData dark({Color primaryColor = accent}) {
    final cs = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs.copyWith(
        primary: primaryColor,
        surface: darkSurface,
        background: darkBg,
        // Keep containers neutral so the UI doesn't look “too colored”.
        primaryContainer: const Color(0xFF15202E),
        secondaryContainer: const Color(0xFF141B25),
        tertiaryContainer: const Color(0xFF141B25),
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F1B2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
        bodySmall: TextStyle(fontSize: 12, color: textMutedDark),
      ),
    );
  }
}