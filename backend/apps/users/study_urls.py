from django.urls import path

from .study_views import (
    DailyChallengeView,
    NotificationListView,
    NotificationReadView,
    SmartReviewListView,
    SmartReviewMarkView,
    StudentPreferenceView,
    StudyPlanDetailView,
    StudyPlanListCreateView,
    StudyReportView,
)

urlpatterns = [
    path("daily-challenge/", DailyChallengeView.as_view(), name="daily-challenge"),
    path("review/", SmartReviewListView.as_view(), name="smart-review"),
    path("review/<int:pk>/mark/", SmartReviewMarkView.as_view(), name="smart-review-mark"),
    path("plans/", StudyPlanListCreateView.as_view(), name="study-plans"),
    path("plans/<int:pk>/", StudyPlanDetailView.as_view(), name="study-plan-detail"),
    path("reports/", StudyReportView.as_view(), name="study-reports"),
    path("notifications/", NotificationListView.as_view(), name="notifications"),
    path("notifications/read-all/", NotificationReadView.as_view(), name="notifications-read-all"),
    path("notifications/<int:pk>/read/", NotificationReadView.as_view(), name="notification-read"),
    path("preferences/", StudentPreferenceView.as_view(), name="student-preferences"),
]
