import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/core/theme/app_theme.dart';
import 'package:finance_app/providers/finance_provider.dart';

void main() {
  test('ModeColorScheme returns DANA cyan-blue palette for personal mode', () {
    final scheme = AppTheme.getModeScheme(AppViewMode.personal);
    expect(scheme.primary, const Color(0xFF118EEA));
    expect(scheme.gradientColors[0], const Color(0xFF118EEA));
    expect(scheme.gradientColors[1], const Color(0xFF0075D8));
    expect(scheme.scaffoldBg, const Color(0xFFF4F8FD));
    expect(scheme.isDarkHero, false);
  });

  test('ModeColorScheme returns ShopeePay sunset-orange palette for family mode', () {
    final scheme = AppTheme.getModeScheme(AppViewMode.family);
    expect(scheme.primary, const Color(0xFFEE4D2D));
    expect(scheme.gradientColors[0], const Color(0xFFEE4D2D));
    expect(scheme.gradientColors[1], const Color(0xFFFF6633));
    expect(scheme.scaffoldBg, const Color(0xFFFFF8F5));
    expect(scheme.isDarkHero, false);
  });

  test('ModeColorScheme returns Obsidian black-carbon palette for company mode', () {
    final scheme = AppTheme.getModeScheme(AppViewMode.company);
    expect(scheme.primary, const Color(0xFF1C1C1E));
    expect(scheme.gradientColors[0], const Color(0xFF1C1C1E));
    expect(scheme.gradientColors[1], const Color(0xFF2C2C2E));
    expect(scheme.scaffoldBg, const Color(0xFFF1F5F9));
    expect(scheme.isDarkHero, true);
  });
}
