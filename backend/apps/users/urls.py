from django.urls import path

from .views import (
    AdminTestView,
    AIChatView,
    AISummaryView,
    LeaderboardView,
    LoginView,
    MeView,
    OwnerDashboardView,
    OwnerStudentListView,
    OwnerStudentStatusView,
    QuizAvailabilityView,
    QuizListView,
    QuizSetupView,
    QuizSubmitView,
    RegisterView,
)

urlpatterns = [
    path("register/",             RegisterView.as_view(),   name="register"),
    path("login/",                LoginView.as_view(),      name="login"),
    path("me/",                   MeView.as_view(),         name="me"),
    path("owner/dashboard/",      OwnerDashboardView.as_view(), name="owner-dashboard"),
    path("owner/students/",       OwnerStudentListView.as_view(), name="owner-students"),
    path("owner/students/<int:pk>/status/", OwnerStudentStatusView.as_view(), name="owner-student-status"),
    path("leaderboard/",          LeaderboardView.as_view(),name="leaderboard"),
    path("quizzes/",              QuizListView.as_view(),   name="quiz-list"),
    path("quizzes/availability/", QuizAvailabilityView.as_view(), name="quiz-availability"),
    path("quizzes/setup/",        QuizSetupView.as_view(),  name="quiz-setup"),
    path("quizzes/submit/",       QuizSubmitView.as_view(), name="quiz-submit"),
    path("ai/chat/",              AIChatView.as_view(),     name="ai-chat"),
    path("ai/summarize/",         AISummaryView.as_view(),  name="ai-summarize"),
    path("admin-test/",           AdminTestView.as_view(),  name="admin-test"),
]
