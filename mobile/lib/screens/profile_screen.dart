import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_components.dart';
import 'quiz_screen.dart';

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
  Map<String, dynamic> _dailyChallenge = {};
  Map<String, dynamic> _studyReport = {};
  int _reportDays = 30;
  bool _isLoading = true;
  bool _isChallengeLoading = true;
  bool _isReportLoading = true;
  String? _challengeError;
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
    unawaited(_reloadDailyChallenge());
    unawaited(_reloadStudyReport());
    final response = await ApiClient.instance.get(AppConstants.meUrl);
    if (!mounted) return;

    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
      return;
    }
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

  Future<void> _reloadDailyChallenge() async {
    setState(() {
      _isChallengeLoading = true;
      _challengeError = null;
    });
    final response = await ApiClient.instance.get(
      AppConstants.dailyChallengeUrl,
      timeout: const Duration(seconds: 120),
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
      return;
    }
    setState(() {
      _dailyChallenge = response.isSuccess && response.body is Map
          ? Map<String, dynamic>.from(response.body as Map)
          : {};
      _challengeError = response.isSuccess ? null : response.errorMessage;
      _isChallengeLoading = false;
    });
  }

  Future<void> _reloadStudyReport() async {
    setState(() => _isReportLoading = true);
    final response = await ApiClient.instance.get(
      '${AppConstants.studyReportsUrl}?days=$_reportDays',
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
      return;
    }
    setState(() {
      _studyReport = response.isSuccess && response.body is Map
          ? Map<String, dynamic>.from(response.body as Map)
          : {};
      _isReportLoading = false;
    });
    if (!response.isSuccess) _showProfileMessage(response.errorMessage);
  }

  Future<void> _startDailyChallenge() async {
    final rawQuiz = _dailyChallenge['quiz'];
    if (rawQuiz is! Map) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          quizData: Map<String, dynamic>.from(rawQuiz),
        ),
      ),
    );
    if (mounted) {
      await Future.wait([_reloadDailyChallenge(), _reloadStudyReport()]);
    }
  }

  void _showProfileMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
                      _buildDailyChallengeCard(),
                      const SizedBox(height: 24),
                      _buildStudyReport(),
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
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        borderRadius: AppRadii.panel,
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
                    border: Border.all(color: AppColors.border, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3322C8A3),
                        blurRadius: 28,
                        offset: Offset(0, 8),
                      ),
                    ],
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
      ),
    );
  }

  Widget _buildStatsRow() {
    final xp = _profileData?['xp_points'] ?? _profileData?['xp'] ?? 0;
    final streak = _profileData?['streak'] ?? 0;
    final year = _profileData?['academic_year'] ?? '-';

    return Row(
      children: [
        _statCard('النقاط', '$xp', Icons.bolt_rounded, AppColors.accent),
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

  Widget _buildDailyChallengeCard() {
    final quiz = _dailyChallenge['quiz'];
    final available = _dailyChallenge['available'] == true;
    final completed = _dailyChallenge['completed'] == true;
    final challengeReady = quiz is Map;
    final summary = completed
        ? 'أنهيت تحدي اليوم بنتيجة '
              '${_dailyChallenge['score'] ?? 0}/${_dailyChallenge['total_questions'] ?? 5}.'
        : challengeReady
        ? 'خمسة أسئلة جديدة من '
              '${_dailyChallenge['subject'] ?? 'موادك الدراسية'}، '
              'المحاضرة ${_dailyChallenge['lecture'] ?? '—'}'
              '${(_dailyChallenge['section_title']?.toString().isNotEmpty ?? false) ? ' • ${_dailyChallenge['section_title']}' : ''}.'
        : _dailyChallenge['message']?.toString().isNotEmpty == true
        ? _dailyChallenge['message'].toString()
        : _challengeError ?? 'يجري تجهيز أسئلة اليوم من محتوى المواد المتاح.';

    return AppCard(
      padding: const EdgeInsets.all(18),
      borderRadius: AppRadii.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded, color: AppColors.primary),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'التحدي اليومي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isChallengeLoading ? null : _reloadDailyChallenge,
                tooltip: 'تحديث التحدي',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: const TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 14),
          if (_isChallengeLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (!completed && challengeReady)
            FilledButton.icon(
              onPressed: _startDailyChallenge,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ابدأ التحدي — 5 أسئلة'),
            )
          else if (!completed && available)
            OutlinedButton.icon(
              onPressed: _reloadDailyChallenge,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تعذر تحميل الأسئلة — حاول التحديث'),
            )
          else if (!completed &&
              _dailyChallenge['generation_state'] == 'generating')
            OutlinedButton.icon(
              onPressed: _reloadDailyChallenge,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('جاري التجهيز — تحديث الحالة'),
            )
          else if (!completed && _challengeError != null)
            OutlinedButton.icon(
              onPressed: _reloadDailyChallenge,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            )
          else if (completed)
            const Text(
              'التحدي اختياري؛ ستجد تحديًا جديدًا غدًا.',
              style: TextStyle(color: AppColors.success),
            )
          else
            const Text(
              'سيظهر التحدي عند رفع محتوى دراسي قابل للمعالجة.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          if (!completed && challengeReady)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'التحدي اختياري • كل إجابة صحيحة = نقطة واحدة',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudyReport() {
    final summary = _studyReport['summary'] is Map
        ? Map<String, dynamic>.from(_studyReport['summary'] as Map)
        : <String, dynamic>{};
    final subjects = _reportMaps(_studyReport['subjects']);
    final lectures = _reportMaps(_studyReport['lectures']);
    final focusAreas = _reportMaps(_studyReport['focus_areas']);
    final bestLectures = [...lectures]
      ..sort(
        (left, right) => (right['accuracy'] as int? ?? 0).compareTo(
          left['accuracy'] as int? ?? 0,
        ),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'تقارير التقدم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DropdownButton<int>(
              value: _reportDays,
              dropdownColor: AppColors.surface,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 أيام')),
                DropdownMenuItem(value: 30, child: Text('30 يومًا')),
                DropdownMenuItem(value: 90, child: Text('90 يومًا')),
              ],
              onChanged: (days) {
                if (days == null) return;
                setState(() => _reportDays = days);
                _reloadStudyReport();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isReportLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else ...[
          AppCard(
            padding: const EdgeInsets.all(14),
            borderRadius: AppRadii.panel,
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              runSpacing: 16,
              children: [
                _reportMetric('الأسئلة المحلولة', summary['questions'] ?? 0),
                _reportMetric('الإجابات الصحيحة', summary['correct'] ?? 0),
                _reportMetric('الدقة', '${summary['accuracy_percent'] ?? 0}%'),
                _reportMetric('الاختبارات', summary['quizzes'] ?? 0),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _reportSection(
            title: 'المواد التي تتميز فيها',
            icon: Icons.emoji_events_outlined,
            rows: subjects.take(5).toList(),
            emptyText: 'حل بعض الأسئلة ليظهر تقييم المواد.',
            label: (row) => row['subject']?.toString() ?? 'مادة',
          ),
          const SizedBox(height: 10),
          _reportSection(
            title: 'محاضرات أداؤك فيها أفضل',
            icon: Icons.workspace_premium_outlined,
            rows: bestLectures.take(3).toList(),
            emptyText: 'حل بعض الأسئلة ليظهر تقييم المحاضرات.',
            label: (row) =>
                '${row['subject'] ?? 'مادة'} • المحاضرة ${row['lecture'] ?? '—'}',
          ),
          const SizedBox(height: 10),
          _reportSection(
            title: 'مواد ومحاضرات تحتاج تحسينًا',
            icon: Icons.trending_up_rounded,
            rows: lectures.take(5).toList(),
            emptyText: 'لا توجد محاضرات مسجلة في هذه الفترة.',
            label: (row) =>
                '${row['subject'] ?? 'مادة'} • المحاضرة ${row['lecture'] ?? '—'}',
          ),
          const SizedBox(height: 10),
          _reportSection(
            title: 'أجزاء ركّز عليها',
            icon: Icons.center_focus_strong_rounded,
            rows: focusAreas.take(5).toList(),
            emptyText: 'ستظهر الأجزاء المقترحة بعد حل الأسئلة.',
            label: (row) =>
                '${row['topic'] ?? 'موضوع'} • ${row['subject'] ?? 'مادة'} '
                '• محاضرة ${row['lecture'] ?? '—'}',
            trailing: (row) => '${row['incorrect'] ?? 0} خطأ',
          ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _reportMaps(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : [];

  Widget _reportMetric(String title, Object value) => SizedBox(
    width: 130,
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _reportSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> rows,
    required String emptyText,
    required String Function(Map<String, dynamic>) label,
    String Function(Map<String, dynamic>)? trailing,
  }) => AppCard(
    padding: const EdgeInsets.all(14),
    borderRadius: AppRadii.panel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(emptyText, style: const TextStyle(color: AppColors.textMuted))
        else
          ...rows.map(
            (row) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                label(row),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              trailing: Text(
                trailing?.call(row) ??
                    '${row['accuracy'] ?? 0}% • ${row['correct'] ?? 0}/${row['questions'] ?? 0}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        borderRadius: AppRadii.control,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.compact),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
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
