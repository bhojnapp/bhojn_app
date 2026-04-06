import 'package:flutter/material.dart';

class BhojnTheme {
  static const Color primaryOrange = Color(0xFFFF9800);
  static const Color darkBg = Color(0xFF121212); // ✅ FIX: 0密121212 ko 0xFF121212 kiya
  static const Color surfaceCard = Color(0xFF1E1E1E);
  static const Color accentRed = Color(0xFFE53935);

  static ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: darkBg,
    primaryColor: primaryOrange,
    colorScheme: const ColorScheme.dark(
      primary: primaryOrange,
      secondary: primaryOrange,
      surface: surfaceCard,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: primaryOrange, width: 1.5),
      ),
    ),
  );
}