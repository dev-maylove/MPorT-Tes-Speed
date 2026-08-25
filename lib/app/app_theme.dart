import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const primary = Color(0xFF00A86B);
    const surface = Color(0xFFF4F7FA);
    const card = Color(0xFFFFFFFF);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: Color(0xFF00C853),
        surface: surface,
        onPrimary: Colors.white,
        onSurface: Color(0xFF0D1B2A),
        onSurfaceVariant: Color(0xFF4A5568),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: Color(0xFF0D1B2A),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF0D1B2A),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardColor: card,
      dividerColor: const Color(0xFFE2E8F0),
      listTileTheme: const ListTileThemeData(
        iconColor: primary,
        textColor: Color(0xFF0D1B2A),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(color: Color(0xFF718096), fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary);
          }
          return const IconThemeData(color: Color(0xFF718096));
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: Color(0xFF0D1B2A)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.green,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.green,
        secondary: AppColors.greenLight,
        surface: AppColors.surface,
        onPrimary: AppColors.textOnGreen,
        onSurface: AppColors.greenLight,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.greenLight),
      ),
      cardColor: AppColors.card,
      dividerColor: AppColors.greenDim.withValues(alpha: 0.3),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.green,
        textColor: AppColors.textPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.green.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.greenLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(color: AppColors.textMuted, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.green);
          }
          return const IconThemeData(color: AppColors.textMuted);
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
