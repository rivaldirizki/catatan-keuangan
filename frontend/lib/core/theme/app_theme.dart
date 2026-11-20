import 'package:flutter/material.dart';

/// AppTheme implements the UI/UX Pro Max Financial Dashboard guidelines:
/// - Primary Dark Slate: #0F172A
/// - Income Green: #10B981
/// - Expense Crimson: #EF4444
/// - Warning Amber (Due Soon): #F59E0B
/// - Saving Accent Blue: #2563EB
/// - High contrast ratio >= 4.5:1 (WCAG AA)
/// - Minimum 44x44px touch targets
class AppTheme {
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateCard = Color(0xFF1E293B);
  static const Color slateLightBg = Color(0xFFF8FAFC);
  static const Color slateBorder = Color(0xFFE2E8F0);

  // Financial indicators
  static const Color incomeGreen = Color(0xFF10B981);
  static const Color expenseRed = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color savingBlue = Color(0xFF2563EB);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: slateDark,
        primary: slateDark,
        secondary: incomeGreen,
        error: expenseRed,
        background: slateLightBg,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: slateLightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: slateDark,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: slateDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48), // >= 44px
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: slateBorder, width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: slateDark,
        brightness: Brightness.dark,
        primary: Colors.white,
        secondary: incomeGreen,
        error: expenseRed,
        background: slateDark,
        surface: slateCard,
      ),
      scaffoldBackgroundColor: slateDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: slateDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: incomeGreen,
          foregroundColor: slateDark,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        color: slateCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
    );
  }
}
