import 'package:flutter/material.dart';

class AppTheme {
  // True Black color palette based on requirements
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color cardGrey = Color(0xFF1B1B1B);
  static const Color accentBlue = Color(0xFF3F75FF); // From the cleaner button
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFAAAAAA);

  static ThemeData get trueBlackTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundBlack,
      primaryColor: backgroundBlack,
      colorScheme: const ColorScheme.dark(
        primary: backgroundBlack,
        secondary: accentBlue,
        surface: cardGrey,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundBlack,
        elevation: 0,
        iconTheme: IconThemeData(color: textWhite),
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardGrey,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      iconTheme: const IconThemeData(color: textWhite),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textWhite,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textWhite,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: textWhite,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: textWhite, fontSize: 16),
        bodyMedium: TextStyle(color: textGrey, fontSize: 14),
        labelSmall: TextStyle(color: textGrey, fontSize: 12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundBlack,
        unselectedItemColor: textGrey,
        selectedItemColor: textWhite,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
