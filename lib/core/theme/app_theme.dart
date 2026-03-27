import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Comfort-Focused Deep Tech Brand Colors
  static const Color primaryBrand = Color(0xFF009090); // Dimmed Cyan for icons
  static const Color primaryGlow = Color(0xFF00C0C0); // Active Maps Cyan
  static const Color secondaryBrand = Color(0xFF008050); // Dimmed Mint Green
  
  static const Color darkBackground = Color(0xFF050505); // Matte Deep Black
  static const Color pureBlackBackground = Color(0xFF000000); // Pure Black
  
  static const Color surfaceDark = Color(0xFF10141C); // Deep Dark Gray / Steel Blue
  static const Color circuitPattern = Color(0xFF0A0E17); // Almost invisible pattern

  // Legacy Aliases to prevent compilation errors
  static const Color accentColor = primaryGlow; 
  static const Color lightBackground = darkBackground; // Forced to deep black
  static const Color surfaceLight = surfaceDark; // Forced to deep gray

  // Text colors (Legibility First)
  static const Color bodyTextSoft = Color(0xFFF0F0F0); // Off-White / Cool Light Gray
  
  // Text Theme (Geometric)
  static TextTheme get _textTheme => GoogleFonts.montserratTextTheme();

  static ThemeData get lightTheme {
    return _buildComfortTheme();
  }

  static ThemeData get darkTheme {
    return _buildComfortTheme();
  }

  static ThemeData _buildComfortTheme() {
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
        tertiary: primaryGlow,
        onSurface: bodyTextSoft,
      ),
      textTheme: _textTheme.apply(
        bodyColor: bodyTextSoft,          // Matte Off-White body text
        displayColor: const Color(0xFFE0E0E0),  // Cool Light Gray for Titles
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: bodyTextSoft), // Matte white icons in headers
        titleTextStyle: TextStyle(color: bodyTextSoft, fontSize: 20, fontWeight: FontWeight.bold)
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: circuitPattern)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: circuitPattern)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: Color(0xFF00FFFF), width: 1.5) // Crisp border
        ),
        labelStyle: TextStyle(color: bodyTextSoft.withOpacity(0.6), letterSpacing: 0.5),
        prefixIconColor: primaryBrand,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      elevatedButtonTheme: _cyberButtonTheme,
      outlinedButtonTheme: _cyberOutlinedTheme,
    );
  }

  // Comfort-focused Button Theme (Matte borders, no glow)
  static final ElevatedButtonThemeData _cyberButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF151A26), // Deep Dark Background 
        foregroundColor: bodyTextSoft, // Matte Off-White text
        elevation: 0, // No glare
        shadowColor: Colors.transparent, // Remove neon glow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00FFFF), width: 1.5), // Precise Matte Cyan Border
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)
    )
  );
  
  static final OutlinedButtonThemeData _cyberOutlinedTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
        foregroundColor: bodyTextSoft,
        side: const BorderSide(color: Color(0xFF00FFFF), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    )
  );
}
