import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  Uint8List? _selectedPhotoBytes;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final response = await ApiClient.instance.get(AppConstants.meUrl);
    if (!mounted) return;

    if (response.isSuccess && response.body is Map) {
      final data = Map<String, dynamic>.from(response.body as Map);
      setState(() {
        _profileData = data;
        _selectedPhotoBytes = null;
        _usernameCtrl.text = data['username'] as String? ?? '';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final body = <String, dynamic>{'username': _usernameCtrl.text.trim()};

    final response = await ApiClient.instance.patch(AppConstants.meUrl, body);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (response.isSuccess) {
      // تحديث الـ profileData المحلية
      if (response.body is Map) {
        setState(() {
          _profileData = Map<String, dynamic>.from(response.body as Map);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success),
              SizedBox(width: 10),
              Text(
                'تم حفظ التغييرات بنجاح',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.errorMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (photo == null || !mounted) return;

      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = true;
        _selectedPhotoBytes = bytes;
      });

      final response = await ApiClient.instance.patchFile(
        AppConstants.meUrl,
        fieldName: 'profile_image',
        bytes: bytes,
        filename: photo.name,
      );

      if (!mounted) return;
      if (response.isSuccess && response.body is Map) {
        setState(() {
          _profileData = Map<String, dynamic>.from(response.body as Map);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث صورة الحساب بنجاح')),
        );
      } else {
        setState(() => _selectedPhotoBytes = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(response.errorMessage)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _selectedPhotoBytes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر اختيار الصورة أو رفعها. حاول مرة أخرى.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text(
              'الملف الشخصي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: _loadProfile,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Avatar Section ───────────────────
                      _buildAvatarSection(),
                      const SizedBox(height: 24),

                      // ─── Stats Row ────────────────────────
                      _buildStatsRow(),
                      const SizedBox(height: 24),

                      // ─── Edit Fields ──────────────────────
                      _buildSectionTitle('تعديل بيانات الحساب'),
                      const SizedBox(height: 14),

                      _buildLabel('اسم المستخدم'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameCtrl,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco(
                          hint: 'اسم المستخدم',
                          icon: Icons.alternate_email_rounded,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'اسم المستخدم مطلوب';
                          }
                          if (v.trim().length < 3) {
                            return 'يجب أن يكون 3 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(height: 28),

                      // ─── Save Button ──────────────────────
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.background,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _isSaving ? 'جاري الحفظ...' : 'حفظ التغييرات',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ─── Logout Button ────────────────────
                      OutlinedButton.icon(
                        onPressed: () => context.read<AuthProvider>().logout(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'تسجيل الخروج',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    final name = _profileData?['username'] as String? ?? 'U';
    final pictureUrl =
        (_profileData?['profile_image'] as String?)?.trim().isNotEmpty == true
        ? (_profileData?['profile_image'] as String).trim()
        : (_profileData?['profile_picture'] as String?)?.trim() ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pictureUrl.isEmpty ? AppColors.primaryContainer : null,
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipOval(
                  child: _selectedPhotoBytes != null
                      ? Image.memory(_selectedPhotoBytes!, fit: BoxFit.cover)
                      : pictureUrl.isNotEmpty
                      ? Image.network(
                          pictureUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isUploadingPhoto ? null : _pickAndUploadProfilePhoto,
            icon: _isUploadingPhoto
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _isUploadingPhoto ? 'جاري رفع الصورة...' : 'إضافة صورة',
            ),
          ),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${_profileData?['username'] ?? ''}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _roleBadge(_profileData?['role'] as String? ?? 'student'),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final xp = _profileData?['xp_points'] ?? _profileData?['xp'] ?? 0;
    final streak = _profileData?['streak'] ?? 0;
    final year = _profileData?['academic_year'] ?? '-';

    return Row(
      children: [
        _statCard('XP', '$xp', Icons.bolt_rounded, AppColors.accent),
        const SizedBox(width: 10),
        _statCard(
          'السلسلة',
          '$streak يوم',
          Icons.local_fire_department_outlined,
          AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _statCard('الفرقة', '$year', Icons.school_outlined, AppColors.primary),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        borderRadius: AppRadii.control,
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSubtle,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      );

  Widget _roleBadge(String role) {
    final map = {
      'owner': (AppColors.primary, 'مالك'),
      'admin': (AppColors.error, 'مسؤول'),
      'student': (AppColors.success, 'طالب'),
    };
    final (color, label) = map[role] ?? (AppColors.textMuted, role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
