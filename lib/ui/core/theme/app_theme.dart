import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class AppThemeController extends ChangeNotifier {
  AppThemeMode _currentThemeMode = AppThemeMode.system;

  AppThemeMode get currentThemeMode => _currentThemeMode;

  ThemeMode get themeMode {
    switch (_currentThemeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  bool isDark(BuildContext context) {
    switch (_currentThemeMode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.system:
        try {
          return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        } catch (_) {
          return WidgetsBinding
                  .instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
        }
    }
  }

  void setThemeMode(AppThemeMode mode) {
    if (_currentThemeMode != mode) {
      _currentThemeMode = mode;
      notifyListeners();
    }
  }
}

class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final AppThemeController controller;
  static final AppThemeController _defaultController = AppThemeController();

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    return scope?.controller ?? _defaultController;
  }

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      controller != oldWidget.controller;
}

class AppTheme {
  // Core OLED & Obsidian Dark Surfaces
  static const Color obsidianBg = Color(0xFF070B12);
  static const Color obsidianDeep = Color(0xFF0B101B);
  static const Color surfaceCard = Color(0xFF101827);
  static const Color surfaceElevated = Color(0xFF1A2438);
  static const Color surfaceHighlight = Color(0xFF23304A);

  // Clean Light Mode Surfaces
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF8FAFC);
  static const Color lightSurfaceHighlight = Color(0xFFE2E8F0);

  // High-Trust Security Accents
  static const Color emeraldSecure = Color(0xFF10B981);
  static const Color indigoShield = Color(0xFF6366F1);
  static const Color cyberCyan = Color(0xFF38BDF8);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color crimsonAlert = Color(0xFFEF4444);

  // Typography & Border Tokens (Dark)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0x14FFFFFF);
  static const Color borderHighlight = Color(0x29FFFFFF);

  // Typography & Border Tokens (Light)
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightBorderSubtle = Color(0xFFE2E8F0);
  static const Color lightBorderHighlight = Color(0xFFCBD5E1);

  // Theme-Aware Dynamic Getters
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color bgOf(BuildContext context) =>
      isDarkMode(context) ? obsidianBg : lightBg;

  static Color surfaceCardOf(BuildContext context) =>
      isDarkMode(context) ? surfaceCard : lightSurfaceCard;

  static Color surfaceElevatedOf(BuildContext context) =>
      isDarkMode(context) ? surfaceElevated : lightSurfaceElevated;

  static Color surfaceHighlightOf(BuildContext context) =>
      isDarkMode(context) ? surfaceHighlight : lightSurfaceHighlight;

  static Color textPrimaryOf(BuildContext context) =>
      isDarkMode(context) ? textPrimary : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDarkMode(context) ? textSecondary : lightTextSecondary;

  static Color textMutedOf(BuildContext context) =>
      isDarkMode(context) ? textMuted : lightTextMuted;

  static Color borderSubtleOf(BuildContext context) =>
      isDarkMode(context) ? borderSubtle : lightBorderSubtle;

  static Color borderHighlightOf(BuildContext context) =>
      isDarkMode(context) ? borderHighlight : lightBorderHighlight;

  static ThemeData get darkVaultTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidianBg,
      colorScheme: const ColorScheme.dark(
        primary: emeraldSecure,
        secondary: cyberCyan,
        tertiary: indigoShield,
        surface: surfaceCard,
        error: crimsonAlert,
        onPrimary: Color(0xFF04130D),
        onSecondary: Color(0xFF061523),
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: borderHighlight, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13.5),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderHighlight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderHighlight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emeraldSecure, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: crimsonAlert, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emeraldSecure,
          foregroundColor: const Color(0xFF04130D),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderHighlight),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData get lightVaultTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: emeraldSecure,
        secondary: cyberCyan,
        tertiary: indigoShield,
        surface: lightSurfaceCard,
        error: crimsonAlert,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightBorderSubtle, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: lightBorderHighlight, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 13.5),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorderHighlight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorderHighlight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emeraldSecure, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: crimsonAlert, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emeraldSecure,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightBorderHighlight),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

void showThemeSelectionDialog(
  BuildContext context,
  AppThemeController controller,
) {
  final strings = AppLanguageScope.stringsOf(context);
  final isDark = AppTheme.isDarkMode(context);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppTheme.emeraldSecure,
            ),
            const SizedBox(width: 8),
            Text(strings.selectTheme),
          ],
        ),
        content: RadioGroup<AppThemeMode>(
          groupValue: controller.currentThemeMode,
          onChanged: (mode) {
            if (mode != null) controller.setThemeMode(mode);
            Navigator.of(ctx).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<AppThemeMode>(
                value: AppThemeMode.light,
                secondary: const Icon(
                  Icons.wb_sunny_rounded,
                  color: AppTheme.amberWarning,
                ),
                title: Text(strings.lightTheme),
                subtitle: Text(strings.lightThemeDesc),
              ),
              RadioListTile<AppThemeMode>(
                value: AppThemeMode.dark,
                secondary: const Icon(
                  Icons.nightlight_round,
                  color: AppTheme.cyberCyan,
                ),
                title: Text(strings.darkTheme),
                subtitle: Text(strings.darkThemeDesc),
              ),
              RadioListTile<AppThemeMode>(
                value: AppThemeMode.system,
                secondary: const Icon(
                  Icons.brightness_auto_rounded,
                  color: AppTheme.emeraldSecure,
                ),
                title: Text(strings.systemTheme),
                subtitle: Text(strings.systemThemeDesc),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.close),
          ),
        ],
      );
    },
  );
}
