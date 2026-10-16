import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color obsidianBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF14171B);
  static const Color surfaceCard = Color(0xFF16191D);
  static const Color cardGrey = Color(0xFF1B1B1B);
  static const Color accentLime = Color(0xFFC6F36B);
  static const Color accentBlue = Color(0xFF6EBEFB);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF8E959E);
  static const Color borderDark = Color(0xFF1E2228);

  static const String fontBricolage = 'Bricolage Grotesque';
  static const String fontInstrument = 'Instrument Sans';

  static TextStyle displayBold({
    double fontSize = 22,
    Color color = textWhite,
    double? letterSpacing = -0.3,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontBricolage,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle displayRegular({
    double fontSize = 22,
    Color color = textWhite,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontBricolage,
      fontWeight: FontWeight.w400,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle uiBold({
    double fontSize = 14,
    Color color = textWhite,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontInstrument,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle uiRegular({
    double fontSize = 14,
    Color color = textGrey,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontInstrument,
      fontWeight: FontWeight.w400,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static ThemeData get trueBlackTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: fontInstrument,
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
          fontSize: 22,
          fontFamily: fontBricolage,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
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
          fontFamily: fontBricolage,
          color: textWhite,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontBricolage,
          color: textWhite,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontFamily: fontBricolage,
          color: textWhite,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontFamily: fontInstrument,
          color: textWhite,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          fontFamily: fontInstrument,
          color: textWhite,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontInstrument,
          color: textWhite,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontInstrument,
          color: textGrey,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          fontFamily: fontInstrument,
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          fontFamily: fontInstrument,
          color: textWhite,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          fontFamily: fontInstrument,
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        labelSmall: TextStyle(
          fontFamily: fontInstrument,
          color: textGrey,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundBlack,
        unselectedItemColor: textGrey,
        selectedItemColor: textWhite,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: fontInstrument,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontInstrument,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF16191D),
        contentTextStyle: const TextStyle(
          color: textWhite,
          fontFamily: fontInstrument,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF262A28), width: 1),
        ),
      ),
    );
  }
}
