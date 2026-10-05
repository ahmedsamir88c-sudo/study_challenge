import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// ثوابت المشروع المركزية — تدعم محاكي الأندرويد وسطح المكتب (Windows) تلقائياً
class AppConstants {
  AppConstants._();

  // ─── Base URL ──────────────────────────────────────────
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  // ─── Auth & App Endpoints ────────────────────────────────
  static String get loginUrl => '$baseUrl/api/auth/login/';
  static String get refreshUrl => '$baseUrl/api/auth/token/refresh/';
  static String get meUrl => '$baseUrl/api/auth/me/';
  static String get registerUrl => '$baseUrl/api/auth/register/';
  static String get leaderboardUrl => '$baseUrl/api/auth/leaderboard/';
  static String get quizzesUrl => '$baseUrl/api/auth/quizzes/';
  static String get quizAvailabilityUrl =>
      '$baseUrl/api/auth/quizzes/availability/';
  static String get quizSetupUrl => '$baseUrl/api/auth/quizzes/setup/';
  static String get quizSubmitUrl => '$baseUrl/api/auth/quizzes/submit/';
  static String get aiChatUrl => '$baseUrl/api/auth/ai/chat/';
  static String get aiSummaryUrl => '$baseUrl/api/auth/ai/summarize/';
  static String get ownerDashboardUrl => '$baseUrl/api/auth/owner/dashboard/';

  // ─── Secure Storage Keys ────────────────────────────────
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUsername = 'username';
  static const String keyRole = 'role';
  static const String keyUniversityId = 'university_id';
  static const String keyAcademicYear = 'academic_year';
  static const String keyFullName = 'full_name';

  // ─── Token Settings ──────────────────────────────────────
  static const int accessTokenLifetimeMinutes = 30;

  // ─── Academic Subjects ──────────────────────────────────
  static const List<String> subjects = [
    'Digital Logic Design',
    'Machine Learning',
    'Computer Networks',
    'Modeling and Simulation',
    'Computer Architecture',
    'Data Structure and Algorithms',
  ];

  static const Map<String, String> subjectLabels = {
    'Digital Logic Design': 'Digital Logic Design (المنطق الرقمي)',
    'Machine Learning': 'Machine Learning (التعلم الآلي)',
    'Computer Networks': 'Computer Networks (شبكات الحاسوب)',
    'Modeling and Simulation': 'Modeling and Simulation (النمذجة والمحاكاة)',
    'Computer Architecture': 'Computer Architecture (معمارية الحاسوب)',
    'Data Structure and Algorithms':
        'Data Structure and Algorithms (هياكل البيانات)',
  };

  // ─── Subject Lecture Counts ──────────────────────────────
  static const Map<String, int> subjectLectureCounts = {
    'Digital Logic Design': 6,
    'Machine Learning': 6,
    'Computer Networks': 9,
    'Modeling and Simulation': 6,
    'Computer Architecture': 6,
    'Data Structure and Algorithms': 4,
  };

  // ─── Academic Years & Subjects ──────────────────────────
  static const Map<int, String> academicYearLabels = {
    1: 'الفرقة الأولى',
    2: 'الفرقة الثانية',
    3: 'الفرقة الثالثة',
    4: 'الفرقة الرابعة',
  };

  static const Map<int, List<String>> academicYearSubjects = {
    1: ['Digital Logic Design', 'Data Structure and Algorithms'],
    2: [
      'Computer Architecture',
      'Data Structure and Algorithms',
      'Digital Logic Design',
    ],
    3: [
      'Computer Networks',
      'Modeling and Simulation',
      'Computer Architecture',
    ],
    4: ['Machine Learning', 'Computer Networks', 'Modeling and Simulation'],
  };

  // ─── Question Counts Options ─────────────────────────────
  static const List<int> questionCounts = [10, 20, 25, 30, 35, 40, 50, 100];

  // ─── Error / Warning Messages ────────────────────────────
  static const String connectionErrorMessage =
      'تعذر الاتصال بالخادم. تحقق من اتصال الإنترنت وحاول مرة أخرى.';
  static const String unexpectedErrorMessage =
      'حدث خطأ غير متوقع. حاول مرة أخرى.';
  static const String noLectureContentMessage =
      'عذراً، لا توجد أسئلة أو محاضرات متاحة لهذه المحاضرة حتى الآن، يجيب الانتظار لحين رفع المحتوى';
}
