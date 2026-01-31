import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Updated for "Mysterious/Modern"
  static const Color primaryBrand = Color(0xFF00C4B4); // Mint/Teal (Original)
  static const Color secondaryBrand = Color(0xFFFF4081); // Neon Pink
  static const Color darkBackground = Color(0xFF0F111A); // Deep Night Blue (Mysterious)
  static const Color surfaceDark = Color(0xFF1A1F2E); // Slightly Lighter Dark
  
  static const Color accentColor = Color(0xFF00C4B4); // Mint/Teal (Original)

  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Text Theme
  static TextTheme get _textTheme => GoogleFonts.outfitTextTheme();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBrand,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBrand,
        brightness: Brightness.light,
        surface: surfaceLight,
        primary: primaryBrand,
        secondary: secondaryBrand,
        tertiary: const Color(0xFF7C4DFF), // Deep Purple Accent
      ),
      textTheme: _textTheme.apply(
        bodyColor: const Color(0xFF1A1F2E),
        displayColor: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBrand, width: 2)),
        labelStyle: const TextStyle(color: Colors.grey),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryBrand,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBrand,
        brightness: Brightness.dark,
        surface: surfaceDark,
        primary: primaryBrand,
        secondary: secondaryBrand,
        tertiary: const Color(0xFF7C4DFF),
        onSurface: Colors.white,
      ),
      textTheme: _textTheme.apply(
        bodyColor: Colors.white.withOpacity(0.9),
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBrand, width: 2)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIconColor: Colors.white.withOpacity(0.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            backgroundColor: primaryBrand,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        )
      )
    );
  }
}
