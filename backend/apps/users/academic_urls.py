from django.urls import path

from .academic_views import (
    AcademicAIChatEndpoint,
    AcademicAIFlashcardEndpoint,
    AcademicAIQuizEndpoint,
    AcademicYearDetailView,
    AcademicYearListCreateView,
    AuditLogListView,
    FlashcardListView,
    LectureDetailView,
    LectureListCreateView,
    MaterialDetailView,
    MaterialDownloadView,
    MaterialListView,
    MaterialReplaceView,
    MaterialRetryView,
    MaterialUploadView,
    OwnerAcademicDashboardView,
    StudentAcademicHierarchyView,
    SubjectDetailView,
    SubjectListCreateView,
)

urlpatterns = [
    # Academic Years
    path("years/", AcademicYearListCreateView.as_view(), name="academic-years-list"),
    path("years/<int:pk>/", AcademicYearDetailView.as_view(), name="academic-year-detail"),

    # Subjects
    path("subjects/", SubjectListCreateView.as_view(), name="subjects-list"),
    path("subjects/<int:pk>/", SubjectDetailView.as_view(), name="subject-detail"),

    # Lectures
    path("lectures/", LectureListCreateView.as_view(), name="lectures-list"),
    path("lectures/<int:pk>/", LectureDetailView.as_view(), name="lecture-detail"),

    # Materials / Files
    path("materials/", MaterialListView.as_view(), name="materials-list"),
    path("materials/upload/", MaterialUploadView.as_view(), name="material-upload"),
    path("materials/<int:pk>/", MaterialDetailView.as_view(), name="material-detail"),
    path("materials/<int:pk>/retry/", MaterialRetryView.as_view(), name="material-retry"),
    path("materials/<int:pk>/replace/", MaterialReplaceView.as_view(), name="material-replace"),
    path("materials/<int:pk>/download/", MaterialDownloadView.as_view(), name="material-download"),

    # Dashboard & Audit
    path("dashboard/", OwnerAcademicDashboardView.as_view(), name="owner-academic-dashboard"),
    path("audit-logs/", AuditLogListView.as_view(), name="audit-logs-list"),

    # Student Experience View
    path("student/hierarchy/", StudentAcademicHierarchyView.as_view(), name="student-academic-hierarchy"),

    # AI Endpoints
    path("ai/chat/", AcademicAIChatEndpoint.as_view(), name="academic-ai-chat"),
    path("ai/generate-quiz/", AcademicAIQuizEndpoint.as_view(), name="academic-ai-generate-quiz"),
    path("ai/generate-flashcards/", AcademicAIFlashcardEndpoint.as_view(), name="academic-ai-generate-flashcards"),
    path("flashcards/", FlashcardListView.as_view(), name="flashcards-list"),
]

