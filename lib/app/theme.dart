import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - Wine Red
  static const Color primary = Color(0xFF8B1A2D);
  static const Color primaryDark = Color(0xFF6B0F1F);
  static const Color primaryLight = Color(0xFFB85C6E);

  // Secondary - Gold
  static const Color gold = Color(0xFFD4AF37);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // Light surfaces
  static const Color surfaceL1 = Color(0xFFFBF9F8);
  static const Color surfaceL2 = Color(0xFFF5F3F2);
  static const Color surfaceL3 = Color(0xFFFFFFFF);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF1A1214);
  static const Color darkSurface = Color(0xFF2D1F23);
}

class AppTheme {
  AppTheme._();

  // ── Cached Themes ────────────────────────────────────────────────────────
  // Pre-computed once; avoids rebuilding ThemeData + ColorScheme on every toggle.

  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.gold,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF5E6B8),
      onSecondaryContainer: const Color(0xFF5C4A00),
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFD1E4FF),
      onTertiaryContainer: const Color(0xFF001D36),
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: AppColors.surfaceL1,
      onSurface: const Color(0xFF1C1B1F),
      onSurfaceVariant: const Color(0xFF49454F),
      outline: const Color(0xFF79747E),
      outlineVariant: const Color(0xFFCAC4D0),
      inverseSurface: const Color(0xFF313033),
      onInverseSurface: const Color(0xFFF4EFF4),
      inversePrimary: AppColors.primaryLight,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceContainerHighest: AppColors.surfaceL3,
      surfaceContainerHigh: AppColors.surfaceL2,
      surfaceContainer: AppColors.surfaceL2,
      surfaceContainerLow: AppColors.surfaceL2,
      surfaceContainerLowest: AppColors.surfaceL3,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.surfaceL1,

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: AppColors.surfaceL1,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: AppColors.primary,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1B1F),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.surfaceL3,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceL2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: AppColors.surfaceL3,
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceL3,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),

      // Divider - intentionally subtle
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 0.5,
        space: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceL2,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),

      // ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF323232),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Dark Theme ───────────────────────────────────────────────────────────

  // Pre-computed colors to avoid repeated withValues() allocations.
  static const Color _darkPrimary = Color(0xFFB85C6E);
  static final _darkAppBarBg = AppColors.darkSurface.withValues(alpha: 0.8);
  static final _darkNavBg = AppColors.darkSurface.withValues(alpha: 0.8);
  static final _darkNavIndicator = _darkPrimary.withValues(alpha: 0.2);
  static final _darkDivider = Colors.white.withValues(alpha: 0.08);
  static final _darkChipSelected = _darkPrimary.withValues(alpha: 0.2);
  static final _darkCardBorder = Colors.white.withValues(alpha: 0.08);

  static ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: const Color(0xFFFFDAD9),
      secondary: AppColors.gold,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF5C4A00),
      onSecondaryContainer: const Color(0xFFF5E6B8),
      tertiary: const Color(0xFF9ECAFF),
      onTertiary: const Color(0xFF003258),
      tertiaryContainer: const Color(0xFF00497D),
      onTertiaryContainer: const Color(0xFFD1E4FF),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: AppColors.darkSurface,
      onSurface: const Color(0xFFE6E1E5),
      onSurfaceVariant: const Color(0xFFCAC4D0),
      outline: const Color(0xFF938F99),
      outlineVariant: const Color(0xFF49454F),
      inverseSurface: const Color(0xFFE6E1E5),
      onInverseSurface: const Color(0xFF313033),
      inversePrimary: AppColors.primary,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceContainerHighest: const Color(0xFF3D2E33),
      surfaceContainerHigh: const Color(0xFF35272C),
      surfaceContainer: const Color(0xFF2D1F23),
      surfaceContainerLow: const Color(0xFF251A1E),
      surfaceContainerLowest: const Color(0xFF1A1214),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.darkBackground,

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _darkAppBarBg,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE6E1E5),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _darkCardBorder, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkPrimary,
          side: const BorderSide(color: _darkPrimary),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF35272C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: AppColors.darkSurface,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkNavBg,
        indicatorColor: _darkNavIndicator,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _darkPrimary,
            );
          }
          return const TextStyle(fontSize: 12, color: Color(0xFFCAC4D0));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _darkPrimary);
          }
          return const IconThemeData(color: Color(0xFF938F99));
        }),
      ),

      dividerTheme: DividerThemeData(
        color: _darkDivider,
        thickness: 0.5,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF35272C),
        selectedColor: _darkChipSelected,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFFE6E1E5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _darkPrimary,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFE6E1E5),
        contentTextStyle: const TextStyle(color: Color(0xFF1C1B1F)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
