import 'package:flutter/material.dart';

class AppColors {
  // Primary palette - Deep Ocean
  static const Color primary = Color(0xFF1A1B2E);
  static const Color primaryLight = Color(0xFF2D2F4E);
  static const Color primaryDark = Color(0xFF0F1021);

  // Accent - Electric Coral
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF8E8E);
  static const Color accentSoft = Color(0x20FF6B6B);

  // Secondary - Golden Hour
  static const Color secondary = Color(0xFFFFB347);
  static const Color secondaryLight = Color(0xFFFFCC80);

  // Status colors
  static const Color success = Color(0xFF4ECB71);
  static const Color successSoft = Color(0x204ECB71);
  static const Color warning = Color(0xFFFFB347);
  static const Color warningSoft = Color(0x20FFB347);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color dangerSoft = Color(0x20FF6B6B);
  static const Color info = Color(0xFF6C9EFF);
  static const Color infoSoft = Color(0x206C9EFF);

  // Neutrals
  static const Color surface = Color(0xFF1E1F36);
  static const Color surfaceLight = Color(0xFF262842);
  static const Color surfaceElevated = Color(0xFF2E3050);
  static const Color cardBg = Color(0xFF242645);
  static const Color divider = Color(0xFF3A3C5A);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9496B0);
  static const Color textMuted = Color(0xFF6B6D88);

  // Category colors
  static const List<Color> categoryColors = [
    Color(0xFF6C9EFF), // Azul
    Color(0xFFFF6B6B), // Vermelho
    Color(0xFF4ECB71), // Verde
    Color(0xFFFFB347), // Laranja
    Color(0xFFBB86FC), // Roxo
    Color(0xFF4DD0E1), // Ciano
    Color(0xFFFF80AB), // Rosa
    Color(0xFFFFD54F), // Amarelo
  ];

  // Priority colors
  static const Color priorityLow = Color(0xFF4ECB71);
  static const Color priorityMedium = Color(0xFFFFB347);
  static const Color priorityHigh = Color(0xFFFF6B6B);

  static Color getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return priorityLow;
      case 2:
        return priorityMedium;
      case 3:
        return priorityHigh;
      default:
        return priorityMedium;
    }
  }

  static Color getCategoryColor(int index) {
    return categoryColors[index % categoryColors.length];
  }
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.primary,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      fontFamily: 'Outfit',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentSoft;
          }
          return AppColors.surfaceLight;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.accentSoft,
        labelStyle: const TextStyle(
          fontFamily: 'Outfit',
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(
          fontFamily: 'Outfit',
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        hourMinuteColor: AppColors.surfaceLight,
        hourMinuteTextColor: AppColors.textPrimary,
        dayPeriodColor: AppColors.surfaceLight,
        dayPeriodTextColor: AppColors.textPrimary,
        dialHandColor: AppColors.accent,
        dialBackgroundColor: AppColors.surfaceLight,
        dialTextColor: AppColors.textPrimary,
        entryModeIconColor: AppColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
