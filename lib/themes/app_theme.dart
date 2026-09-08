import 'package:flutter/material.dart';

/// Shared visual language for El Fatoura.
///
/// The dark palette mirrors the product reference: ink-blue backgrounds,
/// layered navy surfaces and a bright mint accent. Component themes live here
/// so every existing and future screen inherits the same styling.
class AppTheme {
  static const accent = Color(0xFF20D9AE);

  static const lightBg = Color(0xFFF2F6F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF8FBFC);

  static const darkBg = Color(0xFF061421);
  static const darkSurface = Color(0xFF0A1A29);
  static const darkCard = Color(0xFF0D2031);
  static const darkRaised = Color(0xFF11283B);

  static const textDark = Color(0xFF102231);
  static const textMuted = Color(0xFF647989);
  static const textLight = Color(0xFFF4F8FA);
  static const textMutedDark = Color(0xFF91A6B8);

  static const success = Color(0xFF20D9AE);
  static const info = Color(0xFF3C8CFF);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF6269);

  static const ThemeMode defaultThemeMode = ThemeMode.dark;

  static ThemeData defaultTheme({Color primaryColor = accent}) =>
      dark(primaryColor: primaryColor);

  static ThemeData light({Color primaryColor = accent}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      onPrimary: _onColor(primaryColor),
      primaryContainer: const Color(0xFFD8F8EF),
      onPrimaryContainer: const Color(0xFF075C4B),
      secondary: info,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFDCEAFF),
      onSecondaryContainer: const Color(0xFF174F98),
      tertiary: warning,
      onTertiary: const Color(0xFF352300),
      tertiaryContainer: const Color(0xFFFFEBC1),
      onTertiaryContainer: const Color(0xFF684600),
      error: danger,
      onError: Colors.white,
      surface: lightSurface,
      onSurface: textDark,
      onSurfaceVariant: textMuted,
      outline: const Color(0xFFB8C7D0),
      outlineVariant: const Color(0xFFD8E2E7),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF8FBFC),
      surfaceContainer: const Color(0xFFF2F7F8),
      surfaceContainerHigh: const Color(0xFFECF2F4),
      surfaceContainerHighest: const Color(0xFFE5ECEF),
    );

    return _build(
      brightness: Brightness.light,
      scheme: scheme,
      scaffold: lightBg,
      card: lightCard,
      shadow: const Color(0xFF173142),
    );
  }

  static ThemeData dark({Color primaryColor = accent}) {
    final primaryContainer = Color.alphaBlend(
      primaryColor.withValues(alpha: 0.14),
      darkRaised,
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryColor,
      onPrimary: _onColor(primaryColor),
      primaryContainer: primaryContainer,
      onPrimaryContainer: const Color(0xFF7FF6D8),
      secondary: info,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF102B4F),
      onSecondaryContainer: const Color(0xFF9AC2FF),
      tertiary: warning,
      onTertiary: const Color(0xFF2F1F00),
      tertiaryContainer: const Color(0xFF3B2A0D),
      onTertiaryContainer: const Color(0xFFFFD77B),
      error: danger,
      onError: const Color(0xFF350007),
      errorContainer: const Color(0xFF472027),
      onErrorContainer: const Color(0xFFFFB5B9),
      surface: darkSurface,
      onSurface: textLight,
      onSurfaceVariant: textMutedDark,
      outline: const Color(0xFF385064),
      outlineVariant: const Color(0xFF20384B),
      surfaceContainerLowest: const Color(0xFF04101B),
      surfaceContainerLow: const Color(0xFF081725),
      surfaceContainer: darkSurface,
      surfaceContainerHigh: darkCard,
      surfaceContainerHighest: darkRaised,
    );

    return _build(
      brightness: Brightness.dark,
      scheme: scheme,
      scaffold: darkBg,
      card: darkCard,
      shadow: Colors.black,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required Color shadow,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseText = ThemeData(
      brightness: brightness,
      fontFamily: 'Cairo',
    ).textTheme.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    final rounded14 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final rounded18 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Cairo',
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      shadowColor: shadow,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontSize: 28,
          height: 1.18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontSize: 22,
          height: 1.22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.25,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: baseText.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.35,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: baseText.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 68,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 23),
        actionsIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant, size: 23),
        titleTextStyle: baseText.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        shape: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.45 : 0.7),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.all(2),
        color: card,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow.withValues(alpha: isDark ? 0.28 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.62 : 0.8),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 12,
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 16,
        backgroundColor: card,
        modalBackgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.72 : 0.55,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: rounded14,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: rounded14,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: rounded14,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 50),
          elevation: 0,
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          shape: rounded14,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 6,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary.withValues(alpha: 0.13),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: rounded14,
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        pressElevation: 0,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary.withValues(alpha: 0.15),
        disabledColor: scheme.surfaceContainerHigh,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          highlightColor: scheme.primary.withValues(alpha: 0.10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        backgroundColor: isDark ? darkRaised : textDark,
        contentTextStyle: const TextStyle(
          color: textLight,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
        shape: rounded14,
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 10,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: rounded18,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(rounded18),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: danger,
        textColor: Colors.white,
        textStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Color _onColor(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : const Color(0xFF04241C);
}
