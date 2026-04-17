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

  static ThemeData get lightTheme => _buildComfortTheme(Brightness.light);
  static ThemeData get darkTheme => _buildComfortTheme(Brightness.dark);

  static ThemeData _buildComfortTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Light Mode Palette
    const Color lightBg = Color(0xFFF5F5F7);
    const Color lightSurface = Colors.white;
    const Color lightText = Color(0xFF1D1D1F);
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryBrand,
      scaffoldBackgroundColor: isDark ? darkBackground : lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBrand,
        brightness: brightness,
        surface: isDark ? surfaceDark : lightSurface,
        primary: primaryBrand,
        secondary: secondaryBrand,
        tertiary: primaryGlow,
        onSurface: isDark ? bodyTextSoft : lightText,
      ),
      textTheme: _textTheme.apply(
        bodyColor: isDark ? bodyTextSoft : lightText,
        displayColor: isDark ? const Color(0xFFE0E0E0) : lightText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? bodyTextSoft : lightText),
        titleTextStyle: TextStyle(color: isDark ? bodyTextSoft : lightText, fontSize: 20, fontWeight: FontWeight.bold)
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: isDark ? circuitPattern : Colors.grey.shade300)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: isDark ? circuitPattern : Colors.grey.shade300)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: primaryBrand, width: 1.5)
        ),
        labelStyle: TextStyle(color: (isDark ? bodyTextSoft : lightText).withOpacity(0.6), letterSpacing: 0.5),
        prefixIconColor: primaryBrand,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surfaceDark : lightSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      elevatedButtonTheme: _cyberButtonTheme(isDark),
      outlinedButtonTheme: _cyberOutlinedTheme(isDark),
    );
  }

  static ElevatedButtonThemeData _cyberButtonTheme(bool isDark) => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF151A26) : primaryBrand,
        foregroundColor: isDark ? bodyTextSoft : Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDark ? const BorderSide(color: primaryGlow, width: 1.5) : BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)
    )
  );
  
  static OutlinedButtonThemeData _cyberOutlinedTheme(bool isDark) => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? bodyTextSoft : primaryBrand,
        side: BorderSide(color: isDark ? primaryGlow : primaryBrand, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    )
  );
}
