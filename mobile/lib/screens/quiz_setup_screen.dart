import 'package:flutter/material.dart';

import '../core/app_theme.dart';

import '../core/constants.dart';
import '../services/api_client.dart';
import '../widgets/app_components.dart';
import 'quiz_screen.dart';

class QuizSetupScreen extends StatefulWidget {
  final String? initialSubject;
  final bool isDailyChallenge;
  const QuizSetupScreen({
    super.key,
    this.initialSubject,
    this.isDailyChallenge = false,
  });

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen>
    with SingleTickerProviderStateMixin {
  // ─── Selected State ──────────────────────────────────────────
  String? _selectedSubject;
  int? _selectedLecture;
  int? _selectedCount;
  String? _selectedDifficulty;

  bool _isLoading = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _difficultyOptions = [
    {
      'key': 'easy',
      'label': 'سهل',
      'icon': Icons.sentiment_satisfied_rounded,
      'color': AppColors.success,
      'xp': 1,
      'desc': 'نقطة واحدة لكل سؤال صحيح',
    },
    {
      'key': 'medium',
      'label': 'متوسط',
      'icon': Icons.sentiment_neutral_rounded,
      'color': AppColors.accent,
      'xp': 1,
      'desc': 'نقطة واحدة لكل سؤال صحيح',
    },
    {
      'key': 'hard',
      'label': 'صعب',
      'icon': Icons.sentiment_very_dissatisfied_rounded,
      'color': AppColors.error,
      'xp': 1,
      'desc': 'نقطة واحدة لكل سؤال صحيح',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null &&
        AppConstants.subjects.contains(widget.initialSubject)) {
      _selectedSubject = widget.initialSubject;
    }
    if (widget.isDailyChallenge) {
      _selectedCount = 5;
      _selectedDifficulty = 'medium';
    }
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(covariant QuizSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubject != null &&
        widget.initialSubject != oldWidget.initialSubject) {
      setState(() {
        _selectedSubject = widget.initialSubject;
        _selectedLecture = null;
        _selectedCount = widget.isDailyChallenge ? 5 : null;
        _selectedDifficulty = widget.isDailyChallenge ? 'medium' : null;
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Helper Getters ──────────────────────────────────────────
  int get _maxLectures {
    if (_selectedSubject == null) return 0;
    return AppConstants.subjectLectureCounts[_selectedSubject] ?? 6;
  }

  List<int> get _lectureList {
    return List.generate(_maxLectures, (index) => index + 1);
  }

  int get _calculatedMaxXp {
    if (_selectedCount == null || _selectedDifficulty == null) return 0;
    final diff = _difficultyOptions.firstWhere(
      (d) => d['key'] == _selectedDifficulty,
      orElse: () => _difficultyOptions[1],
    );
    return _selectedCount! * (diff['xp'] as int);
  }

  bool get _isFormComplete =>
      _selectedSubject != null &&
      _selectedLecture != null &&
      _selectedCount != null &&
      _selectedDifficulty != null;

  // ─── Start Quiz Logic ────────────────────────────────────────
  Future<void> _startQuiz() async {
    if (!_isFormComplete) {
      _showError('يرجى إكمال جميع خطوات إعداد الاختبار أولاً');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. تحقق أولاً من توفر محتوى المحاضرة
      final availResponse = await ApiClient.instance.get(
        '${AppConstants.quizAvailabilityUrl}?subject=${Uri.encodeComponent(_selectedSubject!)}&lecture=$_selectedLecture',
      );

      bool isAvailable = false;
      if (availResponse.isSuccess && availResponse.body is Map) {
        isAvailable = availResponse.body['available'] == true;
      }

      if (!isAvailable) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showNoContentDialog();
        }
        return;
      }

      // 2. طلب إعداد وتوليد الأسئلة من الـ Backend
      final setupResponse = await ApiClient.instance.post(
        AppConstants.quizSetupUrl,
        {
          'subject': _selectedSubject!,
          'lecture': _selectedLecture!,
          'count': _selectedCount!,
          'difficulty': _selectedDifficulty!,
          if (widget.isDailyChallenge) 'daily_challenge': true,
        },
        timeout: const Duration(seconds: 75),
      );

      if (!mounted) return;

      if (setupResponse.isSuccess && setupResponse.body is Map) {
        final quizData = Map<String, dynamic>.from(setupResponse.body as Map);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuizScreen(quizData: quizData)),
        );
      } else {
        final errorMsg = setupResponse.errorMessage;
        if (errorMsg.contains('لا توجد أسئلة أو محاضرات متاحة')) {
          _showNoContentDialog();
        } else {
          _showError(errorMsg);
        }
      }
    } catch (_) {
      if (mounted) _showError(AppConstants.connectionErrorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Dialog for Missing Lecture Content ───────────────────────
  void _showNoContentDialog() {
    // إظهار تنبيه في الـ SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                AppConstants.noLectureContentMessage,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // إظهار AlertDialog مانع وواضح
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 40,
          ),
        ),
        title: const Text(
          'تنبيه توفر المحتوى',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          AppConstants.noLectureContentMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSubtle,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'حسناً، فهمت',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
            Icon(Icons.quiz_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text(
              'إعداد الاختبار والتحديات',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header Banner ────────────────────────────
              _buildHeaderBanner(),
              const SizedBox(height: 24),

              // ─── Step 1: Subject Dropdown ─────────────────
              _buildStepCard(
                stepNumber: '1',
                title: 'الخطوة الأولى: اختر اسم المادة',
                isRequired: true,
                child: _buildSubjectDropdown(),
              ),
              const SizedBox(height: 18),

              // ─── Step 2: Lecture Dropdown ─────────────────
              if (_selectedSubject != null) ...[
                AnimatedOpacity(
                  opacity: _selectedSubject != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepCard(
                    stepNumber: '2',
                    title: 'الخطوة الثانية: اختر رقم المحاضرة',
                    subtitle:
                        'المحاضرات المتاحة: (1 إلى $_maxLectures) لمادة $_selectedSubject',
                    isRequired: true,
                    child: _buildLectureDropdown(),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ─── Step 3: Question Count Dropdown ──────────
              if (_selectedLecture != null && !widget.isDailyChallenge) ...[
                AnimatedOpacity(
                  opacity: _selectedLecture != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepCard(
                    stepNumber: '3',
                    title: 'الخطوة الثالثة: اختر عدد الأسئلة',
                    isRequired: true,
                    child: _buildCountDropdown(),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (_selectedLecture != null && widget.isDailyChallenge) ...[
                _buildStepCard(
                  stepNumber: '3',
                  title: 'التحدي اليومي',
                  subtitle: '5 أسئلة • نقطة واحدة لكل إجابة صحيحة',
                  isRequired: true,
                  child: const Text(
                    'تم تثبيت عدد الأسئلة حسب التحدي اليومي.',
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ─── Step 4: Difficulty Dropdown ──────────────
              if (_selectedCount != null) ...[
                AnimatedOpacity(
                  opacity: _selectedCount != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepCard(
                    stepNumber: '4',
                    title: 'الخطوة الرابعة: اختر مستوى الأسئلة',
                    isRequired: true,
                    child: _buildDifficultyDropdown(),
                  ),
                ),
                const SizedBox(height: 22),
              ],

              // ─── Summary Card ─────────────────────────────
              if (_isFormComplete) ...[
                _buildSummaryCard(),
                const SizedBox(height: 20),
              ],

              // ─── Start Button ─────────────────────────────
              _buildStartButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widget Builders ─────────────────────────────────────────

  Widget _buildHeaderBanner() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      color: AppColors.surfaceElevated,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.accent,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'جهّز تحدّيك المخصص!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _calculatedMaxXp > 0
                      ? 'يمكنك كسب حتى $_calculatedMaxXp نقطة في هذا الاختبار'
                      : 'اختر المادة والمحاضرة للبدء في حصد النقاط',
                  style: const TextStyle(color: AppColors.accent, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    String? subtitle,
    required bool isRequired,
    required Widget child,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: AppRadii.control,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isRequired)
                const Text(
                  '*',
                  style: TextStyle(color: AppColors.error, fontSize: 16),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 38),
              child: Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ─── Step 1: Subject Dropdown ─────────────────────────────────
  Widget _buildSubjectDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedSubject != null
              ? AppColors.primary
              : AppColors.border,
          width: _selectedSubject != null ? 1.6 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSubject,
          hint: const Row(
            children: [
              Icon(Icons.school_outlined, size: 18, color: AppColors.textMuted),
              SizedBox(width: 10),
              Text(
                'اختر اسم المادة...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ),
          isExpanded: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: AppConstants.subjects.map((subject) {
            return DropdownMenuItem<String>(
              value: subject,
              child: Row(
                children: [
                  const Icon(
                    Icons.book_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subject,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (_selectedSubject != val) {
              setState(() {
                _selectedSubject = val;
                // إعادة تعيين الخيارات التالية عند تغيير المادة
                _selectedLecture = null;
                _selectedCount = widget.isDailyChallenge ? 5 : null;
                _selectedDifficulty = widget.isDailyChallenge
                    ? 'medium'
                    : null;
              });
            }
          },
        ),
      ),
    );
  }

  // ─── Step 2: Lecture Dropdown ─────────────────────────────────
  Widget _buildLectureDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedLecture != null
              ? AppColors.primary
              : AppColors.border,
          width: _selectedLecture != null ? 1.6 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedLecture,
          hint: const Row(
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 10),
              Text(
                'اختر رقم المحاضرة...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ),
          isExpanded: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: _lectureList.map((lecNum) {
            return DropdownMenuItem<int>(
              value: lecNum,
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'المحاضرة رقم ($lecNum)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (_selectedLecture != val) {
              setState(() {
                _selectedLecture = val;
              });
            }
          },
        ),
      ),
    );
  }

  // ─── Step 3: Question Count Dropdown ──────────────────────────
  Widget _buildCountDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedCount != null ? AppColors.primary : AppColors.border,
          width: _selectedCount != null ? 1.6 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedCount,
          hint: const Row(
            children: [
              Icon(
                Icons.format_list_numbered_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 10),
              Text(
                'اختر عدد الأسئلة...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ),
          isExpanded: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: AppConstants.questionCounts.map((count) {
            return DropdownMenuItem<int>(
              value: count,
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$count سؤال',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedCount = val;
            });
          },
        ),
      ),
    );
  }

  // ─── Step 4: Difficulty Dropdown ──────────────────────────────
  Widget _buildDifficultyDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedDifficulty != null
              ? AppColors.primary
              : AppColors.border,
          width: _selectedDifficulty != null ? 1.6 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDifficulty,
          hint: const Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: AppColors.textMuted),
              SizedBox(width: 10),
              Text(
                'اختر مستوى الصعوبة...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ),
          isExpanded: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: _difficultyOptions.map((diff) {
            final color = diff['color'] as Color;
            return DropdownMenuItem<String>(
              value: diff['key'] as String,
              child: Row(
                children: [
                  Icon(diff['icon'] as IconData, size: 20, color: color),
                  const SizedBox(width: 10),
                  Text(
                    diff['label'] as String,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${diff['desc']})',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedDifficulty = val;
            });
          },
        ),
      ),
    );
  }

  // ─── Summary Card ─────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final diff = _difficultyOptions.firstWhere(
      (d) => d['key'] == _selectedDifficulty,
      orElse: () => _difficultyOptions[1],
    );

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceElevated,
      borderColor: AppColors.success.withValues(alpha: 0.4),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'ملخص الاختبار المحدد',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('المادة الدراسية', _selectedSubject ?? '-'),
          _summaryRow('المحاضرة', 'المحاضرة رقم $_selectedLecture'),
          _summaryRow('عدد الأسئلة', '$_selectedCount سؤال'),
          _summaryRow('مستوى الصعوبة', diff['label'] as String),
          const Divider(color: AppColors.border, height: 16),
          _summaryRow(
            'أقصى نقاط ممكنة',
            '$_calculatedMaxXp نقطة',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.accent : Colors.white,
              fontSize: 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Start Button ─────────────────────────────────────────────
  Widget _buildStartButton() {
    final isReady = _isFormComplete && !_isLoading;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isReady ? _startQuiz : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.background,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.play_arrow_rounded, size: 24),
        label: Text(
          _isLoading
              ? 'جاري التحقق وإعداد الاختبار...'
              : (_isFormComplete
                    ? 'ابدأ الاختبار الآن'
                    : 'أكمل الخطوات أعلاه للبدء'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
