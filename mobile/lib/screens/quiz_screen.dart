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

    try {
      final response = await ApiClient.instance.get(AppConstants.quizzesUrl);
      if (response.isSuccess &&
          response.body is Map &&
          response.body['quizzes'] is List) {
        final list = response.body['quizzes'] as List;
        if (list.isNotEmpty) {
          _loadFromData(list.first as Map<String, dynamic>);
          return;
        }
      }
    } catch (_) {}

    // Fallback default sample questions
    _loadFallbackQuestions();
  }

  void _loadFromData(Map<String, dynamic> data) {
    final rawQ = data['questions'] as List;
    setState(() {
      _questions = rawQ
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _isLoading = false;
    });
    _startTimer();
  }

  void _loadFallbackQuestions() {
    setState(() {
      _questions = [
        {
          "id": 1,
          "question": "ما هو تعقيد الوقت (Time Complexity) للبحث الثنائي (Binary Search)؟",
          "options": ["O(n)", "O(log n)", "O(n^2)", "O(1)"],
          "correct_index": 1,
          "explanation": "البحث الثنائي يقسم نطاق البحث إلى النصف في كل خطوة.",
        },
        {
          "id": 2,
          "question": "أي من هياكل البيانات التالية تعتمد على مبدأ LIFO؟",
          "options": ["Queue", "Stack", "Array", "Linked List"],
          "correct_index": 1,
          "explanation": "المكدس (Stack) يعمل بمبدأ Last In First Out.",
        },
        {
          "id": 3,
          "question": "ما هو البروتوكول المستخدم لنقل البيانات المشفرة والآمنة عبر الويب؟",
          "options": ["HTTP", "FTP", "HTTPS", "SMTP"],
          "correct_index": 2,
          "explanation": "HTTPS يستخدم بروتوكول TLS/SSL لتشفير البيانات.",
        },
      ];
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
    if (_answered) return;
    _timer?.cancel();

    final currentQ = _questions[_currentIndex];
    final isCorrect = index == currentQ['correct_index'];

    setState(() {
      _selectedOption = index;
      _answered = true;
      if (isCorrect) {
        _score++;
        final xpPerCorrect = widget.quizData?['xp_per_correct'];
        _earnedXp += xpPerCorrect is int ? xpPerCorrect : 25;
      }
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
    _timer?.cancel();
    setState(() => _isQuizCompleted = true);

    // Submit results to backend to award XP
    try {
      await ApiClient.instance.post(AppConstants.quizSubmitUrl, {
        'quiz_id': widget.quizData?['id'] ?? 'quiz-1',
        'score': _score,
        'total_questions': _questions.length,
        'earned_xp': _earnedXp,
      });
    } catch (_) {}
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

    if (_isQuizCompleted) {
      return _buildResultScreen();
    }

    final currentQ = _questions[_currentIndex];
    final options = (currentQ['options'] as List)
        .map((e) => e.toString())
        .toList();
    final correctIndex = currentQ['correct_index'] as int;

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
                  '+$_earnedXp XP',
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
                  correctIndex: correctIndex,
                );
              }),

              // ─── Explanation Box ─────────────────────────────
              if (_answered && currentQ['explanation'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          currentQ['explanation'].toString(),
                          style: const TextStyle(
                            color: AppColors.textSubtle,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ─── Next Button ─────────────────────────────────
              if (_answered)
                ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _currentIndex < _questions.length - 1
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
    required int correctIndex,
  }) {
    Color borderColor = AppColors.border;
    Color bgColor = AppColors.surface;
    IconData? trailingIcon;
    Color iconColor = Colors.white;

    if (_answered) {
      if (index == correctIndex) {
        borderColor = AppColors.success;
        bgColor = AppColors.surfaceElevated;
        trailingIcon = Icons.check_circle_rounded;
        iconColor = AppColors.success;
      } else if (index == _selectedOption) {
        borderColor = AppColors.error;
        bgColor = AppColors.errorSurface;
        trailingIcon = Icons.cancel_rounded;
        iconColor = AppColors.error;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _answered ? null : () => _selectOption(index),
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
                if (trailingIcon != null)
                  Icon(trailingIcon, color: iconColor, size: 22),
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

                // ─── Score & XP Cards ──────────────────────────
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
                              'نقاط الخبرة',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '+$_earnedXp XP',
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
