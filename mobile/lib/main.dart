import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/app_theme.dart';
import 'core/firebase_options.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final useNativeAndroidOptions =
      defaultTargetPlatform == TargetPlatform.android;
  if (!useNativeAndroidOptions && !DefaultFirebaseOptions.isConfigured) {
    runApp(const StudyChallengeApp());
    return;
  }
  try {
    if (useNativeAndroidOptions) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    runApp(const StudyChallengeApp(firebaseInitialized: true));
  } on FirebaseException catch (error) {
    runApp(
      const StudyChallengeApp(
        firebaseError:
            'تعذر تهيئة Firebase. راجع إعدادات Firebase وبيانات التطبيق.',
      ),
    );
    debugPrint(
      'Firebase initialization failed: ${error.code}: ${error.message}',
    );
  } catch (error) {
    runApp(
      const StudyChallengeApp(
        firebaseError: 'تعذر تهيئة Firebase. راجع إعدادات التطبيق وحاول مجددًا.',
      ),
    );
    debugPrint('Unexpected Firebase initialization error: $error');
  }
}

class StudyChallengeApp extends StatelessWidget {
  const StudyChallengeApp({
    super.key,
    this.firebaseInitialized = false,
    this.firebaseError,
  });

  final bool firebaseInitialized;
  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    if (!firebaseInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Study Challenge',
        theme: AppTheme.dark,
        home: _FirebaseSetupScreen(error: firebaseError),
      );
    }
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

class _FirebaseSetupScreen extends StatelessWidget {
  const _FirebaseSetupScreen({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'يلزم إعداد مشروع Firebase قبل استخدام التطبيق.',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    ),
  );
}
