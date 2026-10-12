import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/auth_service.dart';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePass = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _studentIdController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _studentIdController.text.trim(),
      _passController.text,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  auth.errorMessage ?? 'فشل تسجيل الدخول',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Logo ─────────────────────────────────
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Title ────────────────────────────────
                    const Text(
                      'Study Challenge',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'سجّل دخولك للمتابعة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ─── Student ID Field ─────────────────────
                    _buildLabel('رقم الطالب (ID)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _studentIdController,
                      keyboardType: TextInputType.text,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco(
                        hint: 'رقم الطالب (أو البريد للحسابات القديمة)',
                        icon: Icons.badge_outlined,
                      ),
                      validator: (value) {
                        final studentId = value?.trim() ?? '';
                        if (studentId.isEmpty) return 'رقم الطالب مطلوب';
                        final normalizedId = AuthService.normalizeDigits(
                          studentId,
                        );
                        final isStudentId = RegExp(
                          r'^[A-Za-z0-9_-]{4,50}$',
                        ).hasMatch(normalizedId);
                        final isLegacyEmail = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(studentId);
                        if (!isStudentId && !isLegacyEmail) {
                          return 'أدخل رقم طالب صحيحًا';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ─── Password Field ────────────────────────
                    _buildLabel('كلمة المرور'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passController,
                      obscureText: _obscurePass,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco(
                        hint: 'أدخل كلمة المرور',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'كلمة المرور مطلوبة'
                          : null,
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 36),

                    // ─── Login Button ──────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleLogin,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: AppColors.background,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'تسجيل الدخول',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Link to Sign Up ──────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ليس لديك حساب؟',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'إنشاء حساب جديد',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textSubtle,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintTextDirection: TextDirection.rtl,
    prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
    suffixIcon: suffix,
  );
}
