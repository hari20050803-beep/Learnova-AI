import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Controls the theme (light / dark) of the WHOLE app.
/// When this value changes, MaterialApp rebuilds with the new theme.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// ---------------------------------------------------------------------------
/// LIGHT AND DARK THEMES
/// ---------------------------------------------------------------------------
InputDecorationTheme _inputTheme(Color fill, Color hint) {
  return InputDecorationTheme(
    filled: true,
    fillColor: fill,
    hintStyle: TextStyle(color: hint),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.indigo, width: 1.5),
    ),
    prefixIconColor: AppColors.indigo,
  );
}

/// Rounded, floating snackbars used across the whole app.
const SnackBarThemeData _snackBarTheme = SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  ),
);

/// Rounded dialogs (matches the app's 20–24dp card corners).
const DialogThemeData _dialogTheme = DialogThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  ),
);

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.indigo),
    scaffoldBackgroundColor: AppColors.lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.indigo,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: _inputTheme(
      const Color(0xFFF3F4F8),
      AppColors.lightSubText,
    ),
    snackBarTheme: _snackBarTheme,
    dialogTheme: _dialogTheme,
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkCard,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: _inputTheme(
      const Color(0xFF222A4D),
      AppColors.darkSubText,
    ),
    snackBarTheme: _snackBarTheme,
    dialogTheme: _dialogTheme,
  );
}
