
import 'package:flutter/material.dart';
import 'core/services/storage_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/sign_in_screen.dart';
import 'features/onboarding/screens/welcome_screen.dart';
import 'features/navigation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await AuthService().init();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'DailyMinder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: authService.isLoggedIn ? '/home' : '/signin',
      routes: {
        '/signin': (context) => const SignInScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => const MainNavigationScreen(),
      },
    );
  }
}
