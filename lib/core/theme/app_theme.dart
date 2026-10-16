import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static const red = Color(0xFFC62828);
  static const orange = Color(0xFFF57C00);
  static const amber = Color(0xFFFFC107);
  static const cream = Color(0xFFFFF8E8);
  static const brown = Color(0xFF3E2723);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: red,
      primary: red,
      secondary: orange,
      surface: cream,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFFFBF4),
      textTheme: GoogleFonts.nunitoTextTheme().apply(bodyColor: brown),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111113),
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8DDCE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8DDCE)),
        ),
      ),
    );
  }
}
