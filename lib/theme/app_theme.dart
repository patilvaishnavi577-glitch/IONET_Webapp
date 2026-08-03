import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // WhatsApp Web Dark Theme Palette
  static const Color scaffoldBg = Color(0xFF0B141A);
  static const Color cardBg = Color(0xFF111B21);
  static const Color inputBg = Color(0xFF202C33);
  static const Color cardBorder = Color(0xFF222D34);
  static const Color focusedBorder = Color(0xFF00A884); // WhatsApp Green
  static const Color buttonBg = Color(0xFF202C33);
  static const Color primaryColor = Color(0xFF00A884); // WhatsApp Green Accent
  static const Color errorColor = Color(0xFFF15C6D); // WhatsApp Red

  static const Color textPrimary = Color(0xFFE9EDEF);
  static const Color textSecondary = Color(0xFF8696A0);
  static const Color textMuted = Color(0xFF667781);

  // WhatsApp Web Light Theme Palette
  static const Color scaffoldBgLight = Color(0xFFF0F2F5); // WhatsApp Light Grey
  static const Color cardBgLight = Color(0xFFFFFFFF);
  static const Color inputBgLight = Color(0xFFF0F2F5);
  static const Color cardBorderLight = Color(0xFFE9EDEF);
  static const Color focusedBorderLight = Color(0xFF008069); // WhatsApp Light Green
  static const Color buttonBgLight = Color(0xFFF0F2F5);

  static const Color textPrimaryLight = Color(0xFF111B21);
  static const Color textSecondaryLight = Color(0xFF667781);
  static const Color textMutedLight = Color(0xFF8696A0);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        surface: cardBg,
        error: errorColor,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 26,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textPrimary,
          fontSize: 15,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: focusedBorder, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: textPrimary,
          minimumSize: const Size(180, 48),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: cardBorder, width: 1),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: scaffoldBgLight,
      colorScheme: const ColorScheme.light(
        primary: focusedBorderLight,
        surface: cardBgLight,
        error: errorColor,
      ),
      cardTheme: CardThemeData(
        color: cardBgLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorderLight, width: 1),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: textPrimaryLight,
          fontWeight: FontWeight.w500,
          fontSize: 26,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textPrimaryLight,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textPrimaryLight,
          fontSize: 15,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textSecondaryLight,
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBgLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: const TextStyle(color: textMutedLight, fontSize: 15),
        labelStyle: const TextStyle(color: textSecondaryLight, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: textSecondaryLight, fontSize: 13),
        prefixIconColor: textSecondaryLight,
        suffixIconColor: textSecondaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: focusedBorderLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBgLight,
          foregroundColor: textPrimaryLight,
          minimumSize: const Size(180, 48),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: cardBorderLight, width: 1),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
