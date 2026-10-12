import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

import '../core/constants.dart';
import '../services/api_client.dart';
import '../widgets/app_components.dart';

class QuizScreen extends StatefulWidget {
  final Map<String, dynamic>? quizData;

  const QuizScreen({super.key, this.quizData});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;
  int _earnedXp = 0;
  bool _isQuizCompleted = false;
  bool _isSubmitting = false;
  String? _loadError;
  String? _submissionError;
  List<Map<String, dynamic>> _attemptResults = [];
  final Map<String, int?> _answers = {};

  // Timer
  Timer? _timer;
  int _timeLeft = 30;
  final int _questionDuration = 30;

  @override
  void initState() {
    super.initState();
    _initQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initQuiz() async {
    if (widget.quizData != null && widget.quizData!['questions'] != null) {
      _loadFromData(widget.quizData!);
      return;
    }

    setState(() {
      _isLoading = false;
      _loadError = 'ابدأ الاختبار من شاشة إعداد الاختبار.';
    });
  }

  void _loadFromData(Map<String, dynamic> data) {
    final rawQ = data['questions'];
    if (data['quiz_id'] is! String ||
        rawQ is! List ||
        rawQ.isEmpty ||
        rawQ.any(
          (item) =>
              item is! Map ||
              (item['id'] is! int &&
                  (item['id'] is! String || (item['id'] as String).isEmpty)) ||
              item['question'] is! String ||
              item['options'] is! List ||
              (item['options'] as List).isEmpty,
        )) {
      setState(() {
        _isLoading = false;
        _loadError = 'استجابة الاختبار غير صالحة. ارجع وأعد المحاولة.';
      });
      return;
    }

    setState(() {
      _questions = (rawQ)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _isLoading = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _questionDuration;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    if (!_answered) {
      _selectOption(-1); // No answer
    }
  }

  void _selectOption(int index) {
    if (_answered || _isSubmitting) return;
    _timer?.cancel();

    final currentQ = _questions[_currentIndex];

    setState(() {
      _selectedOption = index;
      _answered = true;
      _answers[currentQ['id'].toString()] = index >= 0 ? index : null;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    if (_isSubmitting || _isQuizCompleted) return;
    _timer?.cancel();
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final response = await ApiClient.instance.post(AppConstants.quizSubmitUrl, {
      'quiz_id': widget.quizData!['quiz_id'],
      'answers': _questions
          .map(
            (question) => {
              'question_id': question['id'].toString(),
              'selected_index': _answers[question['id'].toString()],
            },
          )
          .toList(),
    });
    if (!mounted) return;
    final body = response.body;
    if (!response.isSuccess || body is! Map) {
      setState(() {
        _isSubmitting = false;
        _submissionError = response.errorMessage;
      });
      return;
    }

    final rawResults = body['answers'];
    setState(() {
      _score = body['score'] is int ? body['score'] as int : 0;
      _earnedXp = body['earned_xp'] is int ? body['earned_xp'] as int : 0;
      _attemptResults = rawResults is List
          ? rawResults
                .whereType<Map>()
                .map((result) => Map<String, dynamic>.from(result))
                .toList()
          : [];
      _isSubmitting = false;
      _isQuizCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_loadError != null || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('الاختبار')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError ?? 'لا توجد أسئلة متاحة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('العودة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isQuizCompleted) {
      return _buildResultScreen();
    }

    final currentQ = _questions[_currentIndex];
    final options = (currentQ['options'] as List)
        .map((e) => e.toString())
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'السؤال ${_currentIndex + 1} من ${_questions.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '+$_earnedXp نقطة',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Progress Bar & Timer ────────────────────────
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _questions.length,
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _timeLeft <= 10
                          ? AppColors.error.withValues(alpha: 0.2)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _timeLeft <= 10
                            ? AppColors.error
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: _timeLeft <= 10
                              ? AppColors.error
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_timeLeft}s',
                          style: TextStyle(
                            color: _timeLeft <= 10
                                ? AppColors.error
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Question Card ───────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(22),
                borderRadius: AppRadii.panel,
                boxShadow: AppShadows.card,
                child: Text(
                  currentQ['question'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(height: 24),

              // ─── Options List ────────────────────────────────
              ...List.generate(options.length, (i) {
                return _buildOptionTile(
                  index: i,
                  text: options[i],
                  isSelected: _selectedOption == i,
                );
              }),

              if (_submissionError != null) ...[
                const SizedBox(height: 16),
                Text(
                  'تعذر حفظ النتيجة: $_submissionError',
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // ─── Next Button ─────────────────────────────────
              if (_answered || _submissionError != null)
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : _submissionError != null
                      ? _finishQuiz
                      : _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _submissionError != null
                              ? 'إعادة إرسال النتيجة'
                              : _currentIndex < _questions.length - 1
                              ? 'السؤال التالي'
                              : 'عرض النتيجة النهائية',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required int index,
    required String text,
    required bool isSelected,
  }) {
    final borderColor = isSelected ? AppColors.primary : AppColors.border;
    final bgColor = isSelected ? AppColors.surfaceElevated : AppColors.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _answered || _isSubmitting ? null : () => _selectOption(index),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.background,
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final percent = ((_score / _questions.length) * 100).toInt();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── Badge Trophy ──────────────────────────────
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.accent,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'أحسنت! اكتمل الاختبار',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  percent >= 70
                      ? 'أداء رائع ومتميز في التحدي.'
                      : 'أداء جيد، واصل المذاكرة والتدريب.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Score & points cards ─────────────────────
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(18),
                        borderRadius: AppRadii.control,
                        child: Column(
                          children: [
                            const Text(
                              'الدرجة',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$_score / ${_questions.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(18),
                        borderRadius: AppRadii.control,
                        child: Column(
                          children: [
                            const Text(
                              'النقاط',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '+$_earnedXp نقطة',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                ..._attemptResults.map((result) {
                  final options = result['options'] is List
                      ? (result['options'] as List)
                            .map((option) => option.toString())
                            .toList()
                      : const <String>[];
                  final selectedIndex = result['selected_index'] as int?;
                  final correctIndex = result['correct_index'] as int?;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result['question']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedIndex != null &&
                                  selectedIndex >= 0 &&
                                  selectedIndex < options.length
                              ? 'إجابتك: ${options[selectedIndex]}'
                              : 'لم تتم الإجابة.',
                          style: TextStyle(
                            color: result['is_correct'] == true
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        if (correctIndex != null &&
                            correctIndex >= 0 &&
                            correctIndex < options.length)
                          Text(
                            'الإجابة الصحيحة: ${options[correctIndex]}',
                            style: const TextStyle(color: AppColors.success),
                          ),
                        if (result['explanation'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              result['explanation'].toString(),
                              style: const TextStyle(
                                color: AppColors.textSubtle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // ─── Action Buttons ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'العودة للرئيسية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: const Text(
                    'اختبار جديد',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
