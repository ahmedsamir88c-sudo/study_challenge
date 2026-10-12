/// Identifiers passed to Firebase callable functions; these are not HTTP URLs.
class AppConstants {
  AppConstants._();

  static const String baseUrl = 'firebase://study-challenge';

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
  static String get ownerStudentsUrl => '$baseUrl/api/auth/owner/students/';
  static String ownerStudentStatusUrl(Object id) =>
      '$baseUrl/api/auth/owner/students/$id/status/';
  static String get academicYearsUrl => '$baseUrl/api/academic/years/';
  static String academicYearUrl(Object id) =>
      '$baseUrl/api/academic/years/$id/';
  static String get academicSubjectsUrl => '$baseUrl/api/academic/subjects/';
  static String academicSubjectUrl(Object id) =>
      '$baseUrl/api/academic/subjects/$id/';
  static String get academicLecturesUrl => '$baseUrl/api/academic/lectures/';
  static String academicLectureUrl(Object id) =>
      '$baseUrl/api/academic/lectures/$id/';
  static String get academicMaterialsUrl => '$baseUrl/api/academic/materials/';
  static String get academicMaterialUploadUrl =>
      '$baseUrl/api/academic/materials/upload/';
  static String academicMaterialRetryUrl(Object id) =>
      '$baseUrl/api/academic/materials/$id/retry/';
  static String academicMaterialDownloadUrl(Object id) =>
      '$baseUrl/api/academic/materials/$id/download/';
  static String academicMaterialUrl(Object id) =>
      '$baseUrl/api/academic/materials/$id/';
  static String academicMaterialReplaceUrl(Object id) =>
      '$baseUrl/api/academic/materials/$id/replace/';
  static String get studentAcademicHierarchyUrl =>
      '$baseUrl/api/academic/student/hierarchy/';
  static String get dailyChallengeUrl => '$baseUrl/api/study/daily-challenge/';
  static String get smartReviewUrl => '$baseUrl/api/study/review/';
  static String smartReviewMarkUrl(Object id) =>
      '$baseUrl/api/study/review/$id/mark/';
  static String get studyPlansUrl => '$baseUrl/api/study/plans/';
  static String studyPlanUrl(Object id) => '$baseUrl/api/study/plans/$id/';
  static String get studyReportsUrl => '$baseUrl/api/study/reports/';
  static String get notificationsUrl => '$baseUrl/api/study/notifications/';
  static String get notificationsReadAllUrl =>
      '$baseUrl/api/study/notifications/read-all/';
  static String notificationReadUrl(Object id) =>
      '$baseUrl/api/study/notifications/$id/read/';
  static String get studentPreferencesUrl => '$baseUrl/api/study/preferences/';

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
    'Digital Logic Design': 16,
    'Machine Learning': 16,
    'Computer Networks': 16,
    'Modeling and Simulation': 16,
    'Computer Architecture': 16,
    'Data Structure and Algorithms': 16,
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
