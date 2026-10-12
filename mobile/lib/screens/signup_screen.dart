import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/auth_service.dart';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _passController = TextEditingController();
  int? _academicYear;
  bool _obscurePass = true;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _userController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final academicYear = _academicYear;
    if (academicYear == null) return;
    final success = await auth.register(
      username: _userController.text.trim(),
      email: _emailController.text.trim(),
      universityId: _idController.text.trim(),
      password: _passController.text,
      academicYear: academicYear,
    );

    if (!mounted) return;

    if (success) {
      // AuthWrapper will automatically navigate to HomeScreen or pop if pushed
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  auth.errorMessage ?? 'فشل إنشاء الحساب',
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textSubtle,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Header ──────────────────────────────
                    Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'إنشاء حساب جديد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'انضم إلى مجتمع Study Challenge الآن',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Username Field ──────────────────────
                    _buildLabel('اسم المستخدم (Username)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _userController,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco(
                        hint: 'مثال: ahmed_samir',
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'اسم المستخدم مطلوب';
                        }
                        if (v.trim().length < 3) {
                          return 'يجب أن يكون 3 أحرف على الأقل';
                        }
                        if (!RegExp(r'^[A-Za-z0-9_.-]{3,50}$')
                            .hasMatch(v.trim())) {
                          return 'استخدم الحروف الإنجليزية والأرقام و . _ - فقط';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    _buildLabel('البريد الإلكتروني'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco(
                        hint: 'name@example.com',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'البريد الإلكتروني مطلوب';
                        if (!email.contains('@') || !email.contains('.')) {
                          return 'أدخل بريدًا إلكترونيًا صالحًا';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // ─── University ID Field ─────────────────
                    _buildLabel('ID الجامعة (رقم الطالب)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _idController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco(
                        hint: 'مثال: 2024001',
                        icon: Icons.badge_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'ID الجامعة مطلوب';
                        }
                        if (v.trim().length < 4 || v.trim().length > 50) {
                          return 'يجب أن يتكون رقم الطالب من 4 إلى 50 خانة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // ─── Academic Year (الفرقة) ──────────────
                    _buildLabel('السنة الدراسية (الفرقة)'),
                    const SizedBox(height: 8),
                    FormField<int>(
                      validator: (value) =>
                          value == AuthService.requiredAcademicYear
                          ? null
                          : 'اختر الفرقة الثانية فقط',
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: field.value,
                                hint: const Text('اختر الفرقة'),
                                isExpanded: true,
                                dropdownColor: AppColors.surface,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textMuted,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: AuthService.requiredAcademicYear,
                                    child: Text('الفرقة الثانية (2)'),
                                  ),
                                ],
                                onChanged: (value) {
                                  field.didChange(value);
                                  setState(() => _academicYear = value);
                                },
                              ),
                            ),
                          ),
                          if (field.hasError) ...[
                            const SizedBox(height: 6),
                            Text(
                              field.errorText!,
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ─── Password Field ──────────────────────
                    _buildLabel('كلمة المرور (Password)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passController,
                      obscureText: _obscurePass,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco(
                        hint: '8 أحرف على الأقل',
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
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'كلمة المرور مطلوبة';
                        }
                        if (v.length < 6) {
                          return 'يجب ألا تقل عن 6 خانات';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // ─── Sign Up Button ──────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleRegister,
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
                                'إنشاء الحساب',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Link to Login ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'لديك حساب بالفعل؟',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'تسجيل الدخول',
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
