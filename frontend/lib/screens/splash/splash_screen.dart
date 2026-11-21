import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool isPostLogin;
  const SplashScreen({super.key, this.isPostLogin = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();

    // The animated GIF duration is 3.0s (30 frames x 100ms)
    // Delay 3.2s so the user sees the complete smooth loop
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final nextScreen = (widget.isPostLogin || auth.isAuthenticated)
          ? const DashboardScreen()
          : const LoginScreen();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Ambient soft gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFCFCFD),
                    Color(0xFFF3F5F9),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Main Center Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated GIF Frame
                      Container(
                        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/splash_animation.gif',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return Image.asset(
                                'assets/images/app_icon.png',
                                width: 140,
                                height: 140,
                                fit: BoxFit.contain,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // System Name: Dompet Linc
                      const Text(
                        'Dompet Linc',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isPostLogin
                            ? 'Masuk Berhasil • Menyiapkan Dompet Anda...'
                            : 'Sistem Finansial Pribadi, Keluarga & Bisnis',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Subtle iOS Loading Indicator
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0038FF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Small Text: Sistem by Linc 2026
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Text(
                  'Sistem by Linc 2026',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: AppTheme.textSecondary.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
