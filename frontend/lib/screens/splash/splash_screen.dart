import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool isPostLogin;
  const SplashScreen({super.key, this.isPostLogin = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // The animated GIF duration is ~3.0s (30 frames x 100ms)
    // Delay 3.0s so the user sees the complete full-screen animation loop
    Future.delayed(const Duration(milliseconds: 3000), () {
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
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/splash_animation.gif'), context);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(
          child: Image.asset(
            'assets/images/splash_animation.gif',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) {
              return Center(
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
