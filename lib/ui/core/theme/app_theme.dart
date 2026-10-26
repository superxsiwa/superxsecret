import 'package:flutter/material.dart';

class AppTheme {
  static const Color obsidianBg = Color(0xFF070B12);
  static const Color surfaceCard = Color(0xFF101827);
  static const Color surfaceElevated = Color(0xFF1A2438);
  static const Color emeraldSecure = Color(0xFF10B981);
  static const Color cyberCyan = Color(0xFF38BDF8);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color crimsonAlert = Color(0xFFEF4444);

  static ThemeData get darkVaultTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidianBg,
      colorScheme: const ColorScheme.dark(
        primary: emeraldSecure,
        secondary: cyberCyan,
        surface: surfaceCard,
        error: crimsonAlert,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianBg,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: emeraldSecure, width: 1.5),
        ),
      ),
    );
  }
}

