import 'package:flutter/material.dart';

/// Colours sampled from the ULS seal and the Health Department emblem.
class ClinicColors {
  const ClinicColors._();

  static const Color navy = Color(0xFF1B3B8F);      // seal ring
  static const Color navyDeep = Color(0xFF0E2350);  // gradients, status bar
  static const Color flame = Color(0xFF1E88E5);     // torch flame
  static const Color leaf = Color(0xFF2E9E3E);      // laurel
  static const Color paper = Color(0xFFF6F8FC);     // app background
  static const Color ink = Color(0xFF1A2233);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ClinicColors.navy,
      primary: ClinicColors.navy,
      onPrimary: Colors.white,
      secondary: ClinicColors.flame,
      tertiary: ClinicColors.leaf,
      surface: ClinicColors.paper,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ClinicColors.paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: ClinicColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        // const RGB instead of withValues() keeps this version-proof
        indicatorColor: Color.fromRGBO(27, 59, 143, 0.14),
        elevation: 3,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}