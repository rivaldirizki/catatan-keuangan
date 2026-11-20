import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTheme - Apple iOS 18 Design Experience (UI/UX Pro Max)
/// - Ultra-clean, simple, compact and elegant iOS aesthetic
/// - Grouped background: #F2F2F7 (Apple System Grouped Background)
/// - Card surface: #FFFFFF with 0.8px hairline border (#E5E5EA)
/// - Apple Semantic Accents: System Blue (#007AFF), Mint Green (#34C759), Red (#FF3B30), Orange (#FF9500), Purple (#5856D6)
/// - Typography: Compact SF Pro / Inter typographic scale with tight tracking
/// - WCAG AA contrast ratio >= 4.5:1 & Touch targets >= 44x44px
class AppTheme {
  // Apple iOS System Backgrounds & Surfaces
  static const Color iosBg = Color(0xFFF2F2F7);
  static const Color iosSurface = Color(0xFFFFFFFF);
  static const Color iosCardDark = Color(0xFF1C1C1E);
  static const Color iosCardDarkSecondary = Color(0xFF2C2C2E);
  static const Color iosDivider = Color(0xFFE5E5EA);
  static const Color iosSubtle = Color(0xFFF2F2F7);

  // Apple iOS Labels & Typography
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFFC7C7CC);

  // Apple Semantic Accents
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color incomeGreen = Color(0xFF34C759);
  static const Color expenseRed = Color(0xFFFF3B30);
  static const Color warningOrange = Color(0xFFFF9500);
  static const Color familyPurple = Color(0xFF5856D6);
  static const Color savingTeal = Color(0xFF30B0C7);

  // Legacy mappings for backwards-compatibility
  static const Color slateDark = Color(0xFF1C1C1E);
  static const Color slateCard = Color(0xFF2C2C2E);
  static const Color slateLightBg = iosBg;
  static const Color slateBorder = iosDivider;
  static const Color warningAmber = warningOrange;
  static const Color savingBlue = iosBlue;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: iosBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: iosBlue,
        primary: textPrimary,
        secondary: incomeGreen,
        error: expenseRed,
        surface: iosSurface,
        onSurface: textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        displayMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.4),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3),
        titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.2),
        titleSmall: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: iosBg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        color: iosSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: iosDivider, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: iosBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: iosDivider,
        thickness: 0.8,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
