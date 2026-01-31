import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - "Planmapp Signature" (Extracted from Logo)
  static const Color primaryBrand = Color(0xFF00C4B4); // Turquoise/Teal
  static const Color secondaryBrand = Color(0xFFFF9E45); // Orange/Coral from the smile/arrow
  static const Color darkSurface = Color(0xFF1E272E); // Dark Blue/Grey from dark mode bg

  static const Color accentColor = Color(0xFF00C4B4); // Primary is also accent for now
  
  static const Color darkBackground = Color(0xFF151B22); // Deep dark
  static const Color lightBackground = Color(0xFFF0F4F8); // Soft grey-blue
  
  static const Color surfaceDark = Color(0xFF242C36);
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
        primary: primaryBrand,
        secondary: secondaryBrand,
        tertiary: accentColor,
      ),
      textTheme: _textTheme.apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
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
        tertiary: accentColor,
      ),
      textTheme: _textTheme.apply(
        bodyColor: Colors.white70,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }
}
