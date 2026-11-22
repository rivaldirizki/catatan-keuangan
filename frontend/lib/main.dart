import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  final ApiClient? apiClient;
  const FinanceApp({super.key, this.apiClient});

  @override
  Widget build(BuildContext context) {
    final client = apiClient ?? ApiClient();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient: client)),
        ChangeNotifierProvider(create: (_) => FinanceProvider(apiClient: client)),
        ChangeNotifierProvider(create: (_) => ChatProvider(apiClient: client)),
      ],
      child: MaterialApp(
        title: 'Dompet Linc',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
      ),
    );
  }
}
