import 'package:flutter/material.dart';

import '../core/app_theme.dart';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/owner_dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';

/// Route Guard — يراقب حالة المصادقة ويعرض الشاشة المناسبة تلقائياً
/// - checking      → شاشة تحميل
/// - authenticated → HomeScreen
/// - unauthenticated → LoginScreen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: switch (auth.status) {
        AuthStatus.checking => const _SplashScreen(),
        AuthStatus.authenticated =>
          auth.user?.role == 'owner'
              ? const OwnerDashboardScreen()
              : const HomeScreen(),
        AuthStatus.unauthenticated => const LoginScreen(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            SizedBox(height: 24),
            Text(
              'Study Challenge',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
