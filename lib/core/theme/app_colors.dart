import 'package:flutter/material.dart';

/// Palet MPorT — dark defaults (back-compat) + light tokens.
class AppColors {
  // ── Dark (legacy static access) ──────────────────────────
  static const Color background = Color(0xFF06080F);
  static const Color surface = Color(0xFF0F1420);
  static const Color card = Color(0xFF151B2B);

  static const Color green = Color(0xFF00E5A0);
  static const Color greenLight = Color(0xFF5CFFC9);
  static const Color greenSoft = Color(0xFF7DFFD4);
  static const Color greenDim = Color(0xFF3DCF9A);

  static const Color textPrimary = Color(0xFF5CFFC9);
  static const Color textSecondary = Color(0xFF3DCF9A);
  static const Color textMuted = Color(0xFF2A9B74);
  static const Color textOnGreen = Color(0xFF061410);

  static const Color white = Colors.white;

  // ── Light tokens ─────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF00A86B);
  static const Color lightPrimarySoft = Color(0xFF00C853);
  static const Color lightTextPrimary = Color(0xFF0D1B2A);
  static const Color lightTextSecondary = Color(0xFF4A5568);
  static const Color lightTextMuted = Color(0xFF718096);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightSheet = Color(0xFFF0F3F7);
}

/// Resolved palette for the current [ThemeData.brightness].
class AppPalette {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color card;
  final Color sheet;
  final Color primary;
  final Color primaryLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnPrimary;
  final Color divider;
  final Color icon;
  final Color gaugeFace;
  final Color gaugeTick;

  const AppPalette._({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.card,
    required this.sheet,
    required this.primary,
    required this.primaryLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnPrimary,
    required this.divider,
    required this.icon,
    required this.gaugeFace,
    required this.gaugeTick,
  });

  static const dark = AppPalette._(
    isDark: true,
    background: AppColors.background,
    surface: AppColors.surface,
    card: AppColors.card,
    sheet: AppColors.surface,
    primary: AppColors.green,
    primaryLight: AppColors.greenLight,
    textPrimary: Color(0xFFE8FFF6),
    textSecondary: AppColors.greenLight,
    textMuted: AppColors.textMuted,
    textOnPrimary: AppColors.textOnGreen,
    divider: Color(0xFF1E2738),
    icon: AppColors.greenLight,
    gaugeFace: Color(0xFF0E1828),
    gaugeTick: AppColors.green,
  );

  static const light = AppPalette._(
    isDark: false,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    card: AppColors.lightCard,
    sheet: AppColors.lightSheet,
    primary: AppColors.lightPrimary,
    primaryLight: AppColors.lightPrimarySoft,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    textOnPrimary: Colors.white,
    divider: AppColors.lightDivider,
    icon: AppColors.lightPrimary,
    gaugeFace: Color(0xFFF7FAFC),
    gaugeTick: AppColors.lightPrimary,
  );

  static AppPalette of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  static AppPalette fromBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;
}
