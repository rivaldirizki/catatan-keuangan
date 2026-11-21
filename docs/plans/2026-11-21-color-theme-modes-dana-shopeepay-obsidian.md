# Multi-Mode Color Theme System (DANA, ShopeePay, Obsidian) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Mengimplementasikan sistem tema warna adaptif multi-mode pada Dompet Linc: Mode Pribadi bernuansa DANA (Vibrant Cyan-Blue), Mode Keluarga bernuansa ShopeePay (Sunset Coral-Orange), dan Mode Perusahaan bernuansa Obsidian Titanium Executive (Carbon Dark & Sleek Slate).

**Architecture:** Membangun `ModeColorScheme` di dalam `AppTheme` yang menyediakan token warna konsisten (primary, gradient, background, card, border, button, badge, bottom nav) sesuai `AppViewMode` (personal, family, company) dari `FinanceProvider`. Mengintegrasikan token ini ke dalam Hero Card, AppBar, Quick Actions, Segmented Mode Switcher, dan Bottom Navigation Bar di `DashboardScreen`.

**Tech Stack:** Flutter 3, Dart, Provider (`FinanceProvider`), Google Fonts (`Inter`), Material 3.

---

## Palet Desain & Spesifikasi Warna

| Elemen UI | Mode Pribadi (DANA Style) | Mode Keluarga (ShopeePay Style) | Mode Perusahaan (Obsidian Style) |
| :--- | :--- | :--- | :--- |
| **Brand Primary** | `#118EEA` (DANA Cyan Blue) | `#EE4D2D` (ShopeePay Sunset Orange) | `#1C1C1E` (Apple Obsidian Black) |
| **Gradient Accent** | `#118EEA` $\rightarrow$ `#0075D8` | `#EE4D2D` $\rightarrow$ `#FF6633` | `#1C1C1E` $\rightarrow$ `#2C2C2E` |
| **Scaffold Background** | `#F4F8FD` (Sky Tinted White) | `#FFF8F5` (Warm Peach Tint) | `#F1F5F9` (Executive Slate Light) |
| **Hero Balance Card** | Gradient DANA Blue + Cyan Glow | Gradient Sunset Orange + Peach Glow | Gradient Carbon Obsidian + Metallic Border |
| **Card Surface** | `#FFFFFF` (Border: `#E1EBF5`) | `#FFFFFF` (Border: `#FCEAE4`) | `#FFFFFF` (Border: `#E2E8F0`) |
| **Primary Button** | `#118EEA` (Teks Putih) | `#EE4D2D` (Teks Putih) | `#1C1C1E` (Teks Putih) |
| **Tag / Pill Background** | `#EBF5FD` (Teks: `#118EEA`) | `#FFF0EC` (Teks: `#EE4D2D`) | `#F1F5F9` (Teks: `#1C1C1E`) |
| **Bottom Nav Active** | `#118EEA` (DANA Blue) | `#EE4D2D` (ShopeePay Orange) | `#1C1C1E` (Obsidian Black) |

---

### Task 1: Mode Theme Architecture & Token Engine (`app_theme.dart`)

**Files:**
- Modify: `frontend/lib/core/theme/app_theme.dart`
- Create: `frontend/test/theme_mode_test.dart`

**Step 1: Write the failing unit test**
Create `frontend/test/theme_mode_test.dart` testing `ModeColorScheme` for personal (DANA), family (ShopeePay), and company (Obsidian):
```dart
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
  });

  test('ModeColorScheme returns ShopeePay sunset-orange palette for family mode', () {
    final scheme = AppTheme.getModeScheme(AppViewMode.family);
    expect(scheme.primary, const Color(0xFFEE4D2D));
    expect(scheme.gradientColors[0], const Color(0xFFEE4D2D));
    expect(scheme.gradientColors[1], const Color(0xFFFF6633));
    expect(scheme.scaffoldBg, const Color(0xFFFFF8F5));
  });

  test('ModeColorScheme returns Obsidian black-carbon palette for company mode', () {
    final scheme = AppTheme.getModeScheme(AppViewMode.company);
    expect(scheme.primary, const Color(0xFF1C1C1E));
    expect(scheme.gradientColors[0], const Color(0xFF1C1C1E));
    expect(scheme.gradientColors[1], const Color(0xFF2C2C2E));
    expect(scheme.scaffoldBg, const Color(0xFFF1F5F9));
  });
}
```

**Step 2: Run test to verify it fails**
Command: `flutter_dart-mcp-server:analyze_files`
Expected: FAIL (`The method 'getModeScheme' isn't defined for the class 'AppTheme'`).

**Step 3: Implement `ModeColorScheme` in `app_theme.dart`**
Add class `ModeColorScheme` and factory helpers to `frontend/lib/core/theme/app_theme.dart`:
```dart
class ModeColorScheme {
  final Color primary;
  final Color primaryDark;
  final List<Color> gradientColors;
  final Color scaffoldBg;
  final Color cardBg;
  final Color cardBorder;
  final Color pillBg;
  final Color pillText;
  final Color buttonBg;
  final Color buttonText;
  final Color navActive;
  final Color heroCardShadow;
  final bool isDarkHero;

  const ModeColorScheme({
    required this.primary,
    required this.primaryDark,
    required this.gradientColors,
    required this.scaffoldBg,
    required this.cardBg,
    required this.cardBorder,
    required this.pillBg,
    required this.pillText,
    required this.buttonBg,
    required this.buttonText,
    required this.navActive,
    required this.heroCardShadow,
    this.isDarkHero = true,
  });

  // 1. DANA Style (Personal Mode)
  factory ModeColorScheme.dana() {
    return const ModeColorScheme(
      primary: Color(0xFF118EEA),
      primaryDark: Color(0xFF0075D8),
      gradientColors: [Color(0xFF118EEA), Color(0xFF0075D8)],
      scaffoldBg: Color(0xFFF4F8FD),
      cardBg: Colors.white,
      cardBorder: Color(0xFFE1EBF5),
      pillBg: Color(0xFFEBF5FD),
      pillText: Color(0xFF118EEA),
      buttonBg: Color(0xFF118EEA),
      buttonText: Colors.white,
      navActive: Color(0xFF118EEA),
      heroCardShadow: Color(0x3D118EEA),
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
      cardBg: Colors.white,
      cardBorder: Color(0xFFFCEAE4),
      pillBg: Color(0xFFFFF0EC),
      pillText: Color(0xFFEE4D2D),
      buttonBg: Color(0xFFEE4D2D),
      buttonText: Colors.white,
      navActive: Color(0xFFEE4D2D),
      heroCardShadow: Color(0x3DEE4D2D),
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
      cardBg: Colors.white,
      cardBorder: Color(0xFFE2E8F0),
      pillBg: Color(0xFFF1F5F9),
      pillText: Color(0xFF1C1C1E),
      buttonBg: Color(0xFF1C1C1E),
      buttonText: Colors.white,
      navActive: Color(0xFF1C1C1E),
      heroCardShadow: Color(0x33000000),
      isDarkHero: true,
    );
  }
}
```
And add static method:
```dart
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
```

**Step 4: Verify test passes**
Command: `flutter_dart-mcp-server:analyze_files`
Expected: 0 errors.

**Step 5: Commit**
```bash
git add frontend/lib/core/theme/app_theme.dart frontend/test/theme_mode_test.dart
git commit -m "feat(theme): add ModeColorScheme with DANA, ShopeePay, and Obsidian palettes"
```

---

### Task 2: Personal Mode Dashboard (DANA Blue UI Experience)

**Files:**
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart:1850-2050`

**Step 1: Inspect current Personal Hero Card**
Currently in `_buildPersonalDashboardView`:
- Uses hardcoded `colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)]` (black titanium card).

**Step 2: Update Personal Hero Card to DANA Blue Gradient**
Apply `scheme = AppTheme.getModeScheme(AppViewMode.personal)`:
- Hero Card gradient: `LinearGradient(colors: [Color(0xFF118EEA), Color(0xFF0075D8)], begin: Alignment.topLeft, end: Alignment.bottomRight)`
- Card glow / shadow: `BoxShadow(color: Color(0xFF118EEA).withValues(alpha: 0.28), blurRadius: 20, offset: Offset(0, 8))`
- Card content:
  - Header: "Total Saldo Pribadi" (white with 85% opacity), currency IDR in crisp bold white typography.
  - Inflow & Outflow Pill: Inflow (`+Rp...`) with soft green badge, Outflow (`-Rp...`) with soft light-cyan badge.
  - DANA watermark curve or circular subtle ambient ring in the top right corner.

**Step 3: Update Quick Action Buttons in Personal Mode**
- Icon badges: DANA Blue `#118EEA` with soft `#EBF5FD` background.
- Primary Action "Catat Transaksi": `#118EEA` rounded button with white text and clean icon.

**Step 4: Verify analyzer & UI responsiveness**
Command: `flutter_dart-mcp-server:analyze_files`
Expected: 0 errors.

**Step 5: Commit**
```bash
git add frontend/lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(ui): apply DANA cyan-blue theme to personal mode dashboard"
```

---

### Task 3: Family Mode Dashboard (ShopeePay Sunset Orange UI Experience)

**Files:**
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart:2050-2350`

**Step 1: Inspect current Family Hero Card**
Currently uses `familyPurple` (`#5856D6`) and purple tinted cards.

**Step 2: Update Family Hero Card to ShopeePay Sunset Orange Gradient**
Apply `scheme = AppTheme.getModeScheme(AppViewMode.family)`:
- Hero Card gradient: `LinearGradient(colors: [Color(0xFFEE4D2D), Color(0xFFFF6633)], begin: Alignment.topLeft, end: Alignment.bottomRight)`
- Card glow / shadow: `BoxShadow(color: Color(0xFFEE4D2D).withValues(alpha: 0.28), blurRadius: 20, offset: Offset(0, 8))`
- Family Info Header: Warm peach chip with family invite code and member counter.
- Total Shared Balance: Bold white balance with warm sunset highlights.
- Inflow & Outflow Pills: Inflow with warm mint badge, Outflow with deep coral badge.

**Step 3: Update Family Quick Actions & Member Badges**
- Action buttons: ShopeePay Sunset Orange `#EE4D2D` with peach `#FFF0EC` container.
- Member avatars: Warm orange rings and orange role badges ("Admin Keluarga", "Anggota").
- Family Wallet and Spending breakdown cards: Warm cream border `#FCEAE4` with orange percentage progress bars.

**Step 4: Verify analyzer**
Command: `flutter_dart-mcp-server:analyze_files`
Expected: 0 errors.

**Step 5: Commit**
```bash
git add frontend/lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(ui): apply ShopeePay sunset-orange theme to family mode dashboard"
```

---

### Task 4: Company Mode Dashboard (Obsidian Titanium Executive Dark Experience)

**Files:**
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart:2350-2800`

**Step 1: Inspect current Company Dashboard**
Currently uses corporate blue `#1E3A8A`.

**Step 2: Update Company Mode to Obsidian Titanium Black (ada hitam-hitamnya)**
Apply `scheme = AppTheme.getModeScheme(AppViewMode.company)`:
- Hero Card: `LinearGradient(colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)], begin: Alignment.topLeft, end: Alignment.bottomRight)`
- Subtle Metallic Border: `Border.all(color: Color(0xFF38383A), width: 1.0)`
- Total Company Cashflow & Project Budget: Executive white lettering with bold platinum metrics.
- Badges: Jet black badge `#1C1C1E` with emerald status dot for active projects.

**Step 3: Update Company Project Cards & Action Buttons**
- Action Buttons ("Tambah Kas Proyek", "Buat Proyek"): Apple Obsidian `#1C1C1E` with white icon and text.
- Project Budget Progress Bar: Slate track with emerald progress fill.
- Member list & Company ID badge: Executive obsidian styling with silver borders.

**Step 4: Verify analyzer**
Command: `flutter_dart-mcp-server:analyze_files`
Expected: 0 errors.

**Step 5: Commit**
```bash
git add frontend/lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(ui): apply Obsidian executive dark theme to company mode dashboard"
```

---

### Task 5: Dynamic Mode Switcher, AppBar & Bottom Navigation Bar

**Files:**
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart:1480-1620, 3450-3550`

**Step 1: Dynamic Top AppBar**
Update `appBar` background, avatar, and title styling to react to `themeScheme`:
- Pribadi: White appbar with subtle sky tint, `#118EEA` avatar circle, and DANA blue status badge.
- Keluarga: White appbar with warm peach tint, `#EE4D2D` avatar circle, and ShopeePay orange status badge.
- Perusahaan: Slate light appbar `#F1F5F9`, `#1C1C1E` avatar circle with executive dark badge.

**Step 2: Segmented Mode Switcher (Pribadi / Keluarga / Perusahaan)**
Update the 3-tab segmented controller:
- When "Pribadi" active: Pill glows DANA Blue (`#118EEA`) with white text.
- When "Keluarga" active: Pill glows ShopeePay Orange (`#EE4D2D`) with white text.
- When "Perusahaan" active: Pill glows Obsidian Black (`#1C1C1E`) with white text.
- Inactive pills: Clean neutral slate gray (`#8E8E93`) with smooth animated switch.

**Step 3: Dynamic Bottom Navigation Bar**
Update bottom navigation bar items (Home, Dompet, Hutang, Tabungan, Proyek):
- Active icon and label tint dynamically matches `themeScheme.navActive`:
  - DANA Blue (`#118EEA`) in Personal mode.
  - ShopeePay Orange (`#EE4D2D`) in Family mode.
  - Obsidian Black (`#1C1C1E`) in Company mode.
- Active pill indicator above or behind the active icon.

**Step 4: Verify analyzer & all views**
Command: `flutter_dart-mcp-server:analyze_files`
Expected: 0 errors.

**Step 5: Commit**
```bash
git add frontend/lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(ui): dynamically link AppBar, Mode Switcher, and BottomNav to active mode theme"
```

---

### Task 6: Visual Verification & Test Suite Execution

**Files:**
- Test: `frontend/test/theme_mode_test.dart`
- Test: `backend/tests/*.test.js`

**Step 1: Run Dart analyzer**
Command: `flutter_dart-mcp-server:analyze_files`
Expected: 0 errors, 0 warnings.

**Step 2: Run backend tests to verify non-breakage**
Command: `npm --prefix backend test`
Expected: 40 passing tests.

**Step 3: Push commit to remote**
Command: `git push origin master; git checkout main; git merge master; git push origin main; git checkout master`
Expected: Remote master and main updated.

---

## Ringkasan Perubahan Visual

```
Mode Pribadi:      [DANA Cyan Blue]       #118EEA  |  Kartu Gradien Biru DANA
Mode Keluarga:     [ShopeePay Orange]     #EE4D2D  |  Kartu Gradien Sunset Coral
Mode Perusahaan:   [Obsidian Dark Slate]  #1C1C1E  |  Kartu Hitam Titanium Karbon
```
