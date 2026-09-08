import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// APP COLORS (matching the Learnova AI logo: blue -> indigo -> purple)
/// ---------------------------------------------------------------------------
class AppColors {
  // Brand colors
  static const Color blue = Color(0xFF3D5AF1);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color purple = Color(0xFF7C3AED);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF8F9FE);
  static const Color lightCard = Colors.white;
  static const Color lightText = Color(0xFF1E1B4B);
  static const Color lightSubText = Color(0xFF6B7280);

  // Dark theme colors (dark navy, not pure black)
  static const Color darkBackground = Color(0xFF0B1023);
  static const Color darkCard = Color(0xFF161C36);
  static const Color darkText = Color(0xFFEDEDFB);
  static const Color darkSubText = Color(0xFF9CA3C0);

  static const LinearGradient mainGradient = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ----- Helpers that pick the right color for the current theme -----
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;

  static Color text(BuildContext context) =>
      isDark(context) ? darkText : lightText;

  static Color subText(BuildContext context) =>
      isDark(context) ? darkSubText : lightSubText;

  // ----- Elevation -----
  // Three tiers so a stat tile and a hero card do not carry the same weight.
  // Dark mode leans on black (colour is invisible against navy); light mode
  // tints the shadow indigo so it reads as brand depth rather than grey.

  /// Tier 1 — small chips, tiles and list rows.
  static List<BoxShadow> shadowSm(BuildContext context) => [
    BoxShadow(
      color: isDark(context)
          ? Colors.black.withValues(alpha: 0.30)
          : indigo.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  /// Tier 2 — the standard card. This is what [cardShadow] resolves to.
  static List<BoxShadow> shadowMd(BuildContext context) => [
    BoxShadow(
      color: isDark(context)
          ? Colors.black.withValues(alpha: 0.45)
          : indigo.withValues(alpha: 0.10),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// Tier 3 — hero surfaces that should float above everything else.
  static List<BoxShadow> shadowLg(BuildContext context) => [
    BoxShadow(
      color: isDark(context)
          ? Colors.black.withValues(alpha: 0.55)
          : indigo.withValues(alpha: 0.16),
      blurRadius: 30,
      offset: const Offset(0, 14),
    ),
  ];

  /// Soft shadow used by cards in both themes.
  ///
  /// Kept as the tier-2 alias so every existing call site is unchanged.
  static List<BoxShadow> cardShadow(BuildContext context) => shadowMd(context);

  /// A coloured glow in [color], for surfaces that should feel lit — hero
  /// gradients, primary buttons, accent tiles.
  static List<BoxShadow> glow(
    BuildContext context,
    Color color, {
    double strength = 1.0,
  }) => [
    BoxShadow(
      color: color.withValues(
        alpha: (isDark(context) ? 0.42 : 0.28) * strength,
      ),
      blurRadius: 20 * strength,
      offset: Offset(0, 8 * strength),
    ),
  ];

  /// A very subtle border so cards stay visible in dark mode.
  static Border? cardBorder(BuildContext context) => isDark(context)
      ? Border.all(color: Colors.white.withValues(alpha: 0.06))
      : null;

  /// An accent colour that stays legible as TEXT in both themes.
  ///
  /// The brand colours are deep enough that indigo or purple on the dark navy
  /// background reads as almost black, so on dark they are mixed towards
  /// white. Light mode is left exactly as designed.
  static Color readable(BuildContext context, Color color) =>
      isDark(context) ? Color.lerp(color, Colors.white, 0.45)! : color;
}
