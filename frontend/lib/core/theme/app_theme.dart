import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/finance_provider.dart';

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

  // Mode Semantic Accents (DANA, ShopeePay, Obsidian)
  static const Color danaBlue = Color(0xFF118EEA); // Mode Pribadi: DANA Cyan Blue
  static const Color iosBlue = Color(0xFF118EEA); // Primary personal accent
  static const Color shopeeOrange = Color(0xFFEE4D2D); // Mode Keluarga: ShopeePay Sunset Orange
  static const Color familyPurple = Color(0xFFEE4D2D); // Primary family accent
  static const Color companyObsidian = Color(0xFF1C1C1E); // Mode Perusahaan: Obsidian Titanium Black
  static const Color companyTeal = Color(0xFF0D9488); // Mode Perusahaan accent teal
  static const Color incomeGreen = Color(0xFF34C759);
  static const Color expenseRed = Color(0xFFFF3B30);
  static const Color warningOrange = Color(0xFFFF9500);
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

  static ModeColorScheme getModeScheme(AppViewMode mode) {
    switch (mode) {
      case AppViewMode.personal:
        return ModeColorScheme.dana();
      case AppViewMode.family:
        return ModeColorScheme.shopeePay();
      case AppViewMode.company:
        return ModeColorScheme.obsidian();
    }
  }
}

/// ModeColorScheme - Multi-Mode Palette Engine:
/// - Personal: DANA Cyan Blue (#118EEA)
/// - Family: ShopeePay Sunset Orange (#EE4D2D)
/// - Company: Obsidian Titanium Dark (#1C1C1E)
class ModeColorScheme {
  final Color primary;
  final Color primaryDark;
  final List<Color> gradientColors;
  final Color scaffoldBg;
  final Color appBarBg;
  final Color cardBg;
  final Color cardBorder;
  final Color pillBg;
  final Color pillText;
  final Color buttonBg;
  final Color buttonText;
  final Color navActive;
  final Color heroCardShadow;
  final Color heroTextColor;
  final bool isDarkHero;

  const ModeColorScheme({
    required this.primary,
    required this.primaryDark,
    required this.gradientColors,
    required this.scaffoldBg,
    required this.appBarBg,
    required this.cardBg,
    required this.cardBorder,
    required this.pillBg,
    required this.pillText,
    required this.buttonBg,
    required this.buttonText,
    required this.navActive,
    required this.heroCardShadow,
    required this.heroTextColor,
    this.isDarkHero = true,
  });

  // 1. DANA Style (Personal Mode)
  factory ModeColorScheme.dana() {
    return const ModeColorScheme(
      primary: Color(0xFF118EEA),
      primaryDark: Color(0xFF0075D8),
      gradientColors: [Color(0xFF118EEA), Color(0xFF0075D8)],
      scaffoldBg: Color(0xFFF4F8FD),
      appBarBg: Colors.white,
      cardBg: Colors.white,
      cardBorder: Color(0xFFE1EBF5),
      pillBg: Color(0xFFEBF5FD),
      pillText: Color(0xFF118EEA),
      buttonBg: Color(0xFF118EEA),
      buttonText: Colors.white,
      navActive: Color(0xFF118EEA),
      heroCardShadow: Color(0x3D118EEA),
      heroTextColor: Colors.white,
      isDarkHero: false,
    );
  }

  // 2. ShopeePay Style (Family Mode)
  factory ModeColorScheme.shopeePay() {
    return const ModeColorScheme(
      primary: Color(0xFFEE4D2D),
      primaryDark: Color(0xFFD43819),
      gradientColors: [Color(0xFFEE4D2D), Color(0xFFFF6633)],
      scaffoldBg: Color(0xFFFFF8F5),
      appBarBg: Colors.white,
      cardBg: Colors.white,
      cardBorder: Color(0xFFFCEAE4),
      pillBg: Color(0xFFFFF0EC),
      pillText: Color(0xFFEE4D2D),
      buttonBg: Color(0xFFEE4D2D),
      buttonText: Colors.white,
      navActive: Color(0xFFEE4D2D),
      heroCardShadow: Color(0x3DEE4D2D),
      heroTextColor: Colors.white,
      isDarkHero: false,
    );
  }

  // 3. Obsidian Titanium Executive (Company Mode)
  factory ModeColorScheme.obsidian() {
    return const ModeColorScheme(
      primary: Color(0xFF1C1C1E),
      primaryDark: Color(0xFF121214),
      gradientColors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
      scaffoldBg: Color(0xFFF1F5F9),
      appBarBg: Color(0xFFF1F5F9),
      cardBg: Colors.white,
      cardBorder: Color(0xFFE2E8F0),
      pillBg: Color(0xFFE2E8F0),
      pillText: Color(0xFF1C1C1E),
      buttonBg: Color(0xFF1C1C1E),
      buttonText: Colors.white,
      navActive: Color(0xFF1C1C1E),
      heroCardShadow: Color(0x33000000),
      heroTextColor: Colors.white,
      isDarkHero: true,
    );
  }
}
