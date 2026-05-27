import 'package:flutter/material.dart';
import 'colors.dart';

class ParishTheme {
  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      primaryColor: ParishColors.primaryBlue,
      scaffoldBackgroundColor: ParishColors.bgWhite,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: ParishColors.primaryBlue,
        primary: ParishColors.primaryBlue,
        secondary: ParishColors.primaryGold,
        surface: ParishColors.bgWhite,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ParishColors.bgWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: ParishColors.primaryBlue),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        selectedItemColor: ParishColors.primaryBlue,
        unselectedItemColor: ParishColors.textGray600,
        selectedLabelStyle: const TextStyle(fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        elevation: 8,
      ),
    );
  }
}
