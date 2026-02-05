import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5D4037); // School Wood
  static const Color secondary = Color(0xFF66BB6A); // Chalkboard Green
  static const Color background = Color(0xFFEFEBE9); // Classroom Wall/Paper
  static const Color surface = Color(0xFFFFFFFF); // Clean Page
  static const Color text = Color(0xFF3E2723); // Dark Ink
  static const Color subtle = Color(0xFFA1887F); // Light Wood
  static const Color shadow = Color(0xFF3E2723); // Deep Wood Shadow
  static const Color accent = Color(0xFFFFD54F); // Gold Star
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get pixelTitle => const TextStyle(
        fontFamily: 'Titles',
        fontSize: 42,
        fontWeight: FontWeight.normal,
        color: AppColors.text,
        letterSpacing: 2.0,
      );

  static TextStyle get pixelHeader => const TextStyle(
        fontFamily: 'Alagard',
        fontSize: 24,
        fontWeight: FontWeight.normal,
        color: AppColors.text,
      );

  static TextStyle get pixelBody => const TextStyle(
        fontFamily: 'Alagard',
        fontSize: 16, // Alagard is a bit small, bumping default body
        fontWeight: FontWeight.normal,
        color: AppColors.text,
      );

  static TextStyle get pixelButton => const TextStyle(
        fontFamily: 'Alagard',
        fontSize: 18,
        fontWeight: FontWeight.normal,
        color: AppColors.text,
      );

  static TextStyle get pixelAction => const TextStyle(
        fontFamily: 'Alagard',
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.text,
      );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.text,
        secondary: AppColors.secondary,
        onSecondary: AppColors.text,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: AppColors.background,
        onSurface: AppColors.text,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.pixelTitle,
        titleLarge: AppTextStyles.pixelHeader,
        bodyLarge: AppTextStyles.pixelBody,
        bodyMedium: AppTextStyles.pixelBody.copyWith(fontSize: 12),
        labelLarge: AppTextStyles.pixelButton,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.pixelHeader,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
    );
  }
}
