import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyChallengeApp());
}

class StudyChallengeApp extends StatelessWidget {
  const StudyChallengeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Study Challenge',
        supportedLocales: const [Locale('ar'), Locale('en')],
        theme: AppTheme.dark,
        // ─── Root: AuthWrapper يتحكم في التوجيه ─────────
        home: const AuthWrapper(),
      ),
    );
  }
}
