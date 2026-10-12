import io
import tempfile
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db.utils import OperationalError
from django.test import TestCase, override_settings
from django.utils import timezone
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from .models import (
    AISummary,
    DailyChallenge,
    DocumentChunk,
    GeneratedQuizQuestion,
    LectureContent,
    Notification,
    QuizAttemptAnswer,
    QuizAttempt,
    QuizQuestionUsage,
    StudyPlan,
    User,
)
from .services.academic_ai import (
    AcademicAIScopeError,
    NOT_FOUND_MESSAGE,
    ask_academic_question,
    summarize_academic_lecture,
)
from .serializers import LoginSerializer
from .views import NO_LECTURE_CONTENT_MESSAGE


class OwnerAccountTests(APITestCase):
    @override_settings(OWNER_UNIVERSITY_ID="42510677")
    @patch(
        "apps.users.management.commands.create_owner.getpass",
        side_effect=["Test-only!Secure-9427", "Test-only!Secure-9427"],
    )
    def test_owner_is_created_securely_and_can_login_by_university_id(
        self,
        getpass_mock,
    ):
        output = io.StringIO()
        call_command("create_owner", full_name="Platform Owner", stdout=output)

        owner = User.objects.get(university_id="42510677")
        self.assertEqual(owner.role, User.Role.OWNER)
        self.assertTrue(owner.is_superuser)
        self.assertTrue(owner.is_staff)
        self.assertTrue(owner.check_password("Test-only!Secure-9427"))
        self.assertNotIn("Test-only!Secure-9427", output.getvalue())
        self.assertEqual(getpass_mock.call_count, 2)

        response = self.client.post(
            "/api/auth/login/",
            {
                "university_id": "42510677",
                "password": "Test-only!Secure-9427",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["user"]["role"], User.Role.OWNER)
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {response.data['access']}"
        )
        self.assertEqual(
            self.client.get("/api/auth/admin-test/").status_code,
            status.HTTP_200_OK,
        )

    @override_settings(OWNER_UNIVERSITY_ID="42510677")
    def test_owner_command_refuses_to_promote_an_existing_account(self):
        existing_user = User.objects.create_user(
            username="existing-student",
            password="Test-only!Secure-9427",
            university_id="42510677",
        )

        with self.assertRaises(CommandError):
            call_command("create_owner", stdout=io.StringIO())

        existing_user.refresh_from_db()
        self.assertEqual(existing_user.role, User.Role.STUDENT)
        self.assertFalse(existing_user.is_superuser)


class LoginErrorHandlingTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="login-student",
            password="Test-only!Secure-9427",
            university_id="32276196",
        )
        self.url = "/api/auth/login/"

    def test_login_accepts_numeric_university_id(self):
        response = self.client.post(
            self.url,
            {"university_id": 32276196, "password": "Test-only!Secure-9427"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertEqual(response.data["user"]["university_id"], "32276196")

    def test_login_rejects_missing_identifier_with_json_validation_error(self):
        response = self.client.post(
            self.url,
            {"password": "Test-only!Secure-9427"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("detail", response.data)

    def test_database_error_during_login_returns_safe_json_503(self):
        with (
            patch.object(LoginSerializer, "validate", side_effect=OperationalError("database unavailable")),
            self.assertLogs("apps.users.views", level="ERROR"),
        ):
            response = self.client.post(
                self.url,
                {"university_id": "32276196", "password": "Test-only!Secure-9427"},
                format="json",
            )

        self.assertEqual(
            response.status_code,
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )
        self.assertEqual(response.data["code"], "database_unavailable")
        self.assertNotIn("database unavailable", response.content.decode().lower())

    def test_unexpected_login_error_returns_safe_json_500(self):
        with (
            patch.object(LoginSerializer, "validate", side_effect=RuntimeError("internal detail")),
            self.assertLogs("apps.users.views", level="ERROR"),
        ):
            response = self.client.post(
                self.url,
                {"university_id": "32276196", "password": "Test-only!Secure-9427"},
                format="json",
            )

        self.assertEqual(
            response.status_code,
            status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
        self.assertEqual(response.data["code"], "login_failed")
        self.assertNotIn("internal detail", response.content.decode())


class OwnerDashboardTests(APITestCase):
    def setUp(self):
        self.url = "/api/auth/owner/dashboard/"
        self.owner = User.objects.create_superuser(
            username="dashboard-owner",
            password="Test-only!Secure-9427",
            role=User.Role.OWNER,
            university_id="42510677",
        )

    def test_owner_receives_database_backed_metrics(self):
        User.objects.create_user(
            username="dashboard-student",
            password="test-password",
            academic_year=2,
        )
        LectureContent.objects.create(
            subject="Computer Architecture",
            lecture_number=2,
            content="Lecture text",
        )
        self.client.force_authenticate(user=self.owner)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["metrics"]["total_students"], 1)
        self.assertEqual(response.data["metrics"]["total_lectures"], 2)
        self.assertEqual(response.data["owner"]["university_id"], "42510677")

    def test_student_cannot_access_owner_dashboard(self):
        student = User.objects.create_user(
            username="dashboard-student",
            password="test-password",
            academic_year=2,
        )
        self.client.force_authenticate(user=student)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class OwnerStudentManagementTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_superuser(
            username="student-management-owner",
            password="test-password",
            role=User.Role.OWNER,
        )
        self.student = User.objects.create_user(
            username="managed-student",
            password="test-password",
            full_name="طالب تجريبي",
            university_id="12345678",
            academic_year=2,
        )
        self.client.force_authenticate(user=self.owner)

    def test_owner_can_search_students_and_change_account_status(self):
        response = self.client.get(
            "/api/auth/owner/students/",
            {"search": "12345678"},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["id"], self.student.id)

        response = self.client.post(
            f"/api/auth/owner/students/{self.student.id}/status/",
            {"is_active": False, "reason": "اختبار الإدارة"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.student.refresh_from_db()
        self.assertFalse(self.student.is_active)
        self.assertEqual(self.student.student_status, User.StudentStatus.SUSPENDED)

    def test_student_cannot_manage_student_accounts(self):
        self.client.force_authenticate(user=self.student)

        response = self.client.get("/api/auth/owner/students/")

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class ProfileImageUploadTests(APITestCase):
    def setUp(self):
        self.media_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.media_directory.cleanup)
        media_settings = override_settings(MEDIA_ROOT=self.media_directory.name)
        media_settings.enable()
        self.addCleanup(media_settings.disable)

        self.user = User.objects.create_user(
            username="photo-student",
            password="test-password",
        )
        self.client.force_authenticate(user=self.user)

    def test_profile_image_can_be_uploaded(self):
        image_bytes = io.BytesIO()
        Image.new("RGB", (1, 1), color="white").save(image_bytes, format="PNG")
        photo = SimpleUploadedFile(
            "profile.png",
            image_bytes.getvalue(),
            content_type="image/png",
        )

        response = self.client.patch(
            "/api/auth/me/",
            {"profile_image": photo},
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("/media/profiles/", response.data["profile_image"])
        self.user.refresh_from_db()
        self.assertTrue(self.user.profile_image.name)


class QuizLectureAvailabilityTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="quiz-student",
            password="test-password",
        )
        self.client.force_authenticate(user=self.user)
        self.url = "/api/auth/quizzes/setup/"
        self.valid_payload = {
            "subject": "Digital Logic Design",
            "lecture": 1,
            "count": 10,
            "difficulty": "medium",
        }

    def test_setup_rejects_lecture_without_uploaded_content(self):
        response = self.client.post(self.url, self.valid_payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(response.data["detail"], NO_LECTURE_CONTENT_MESSAGE)

    def test_availability_endpoint_reports_missing_content(self):
        response = self.client.get(
            "/api/auth/quizzes/availability/",
            {"subject": self.valid_payload["subject"], "lecture": 1},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data["available"])
        self.assertEqual(response.data["message"], NO_LECTURE_CONTENT_MESSAGE)

    @patch("apps.users.views._generate_questions_from_model")
    def test_setup_generates_questions_after_content_is_uploaded(
        self,
        generate_questions,
    ):
        LectureContent.objects.create(
            subject=self.valid_payload["subject"],
            lecture_number=self.valid_payload["lecture"],
            content="Uploaded lecture notes.",
        )
        generate_questions.return_value = [
            {
                "question": f"ما نتيجة الفكرة رقم {index} في المذكرة؟",
                "options": ["الإجابة أ", "الإجابة ب", "الإجابة ج", "الإجابة د"],
                "correct_index": index % 4,
                "explanation": f"شرح السؤال رقم {index}.",
            }
            for index in range(10)
        ]

        response = self.client.post(self.url, self.valid_payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["lecture"], 1)
        self.assertEqual(len(response.data["questions"]), 10)

    def test_setup_rejects_invalid_question_count(self):
        LectureContent.objects.create(
            subject=self.valid_payload["subject"],
            lecture_number=self.valid_payload["lecture"],
            content="Uploaded lecture notes.",
        )
        payload = {**self.valid_payload, "count": 75}

        response = self.client.post(self.url, payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_setup_rejects_non_string_subject_without_server_error(self):
        payload = {**self.valid_payload, "subject": {"invalid": "value"}}

        response = self.client.post(self.url, payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class ComputerArchitectureLectureOneTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="architecture-student",
            password="test-password",
        )
        self.client.force_authenticate(user=self.user)

    def test_first_lecture_is_available(self):
        response = self.client.get(
            "/api/auth/quizzes/availability/",
            {"subject": "Computer Architecture", "lecture": 1},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["available"])

    def test_quiz_uses_first_lecture_questions(self):
        with patch(
            "apps.users.views._generate_questions_from_model",
            return_value=self._generated_questions("فون نيومان", 10),
        ) as generate_questions:
            response = self.client.post(
                "/api/auth/quizzes/setup/",
                {
                    "subject": "Computer Architecture",
                    "lecture": 1,
                    "count": 10,
                    "difficulty": "medium",
                },
                format="json",
            )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["questions"]), 10)
        self.assertTrue(
            any("فون نيومان" in item["question"] for item in response.data["questions"])
        )
        generate_questions.assert_called_once()

    def test_questions_are_not_reused_in_later_quizzes(self):
        with patch(
            "apps.users.views._generate_questions_from_model",
            side_effect=[
                self._generated_questions("الأولى", 10),
                self._generated_questions("الثانية", 10),
            ],
        ):
            first_response = self._request_quiz()
            second_response = self._request_quiz()

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(second_response.status_code, status.HTTP_200_OK)
        first_questions = {
            item["question"] for item in first_response.data["questions"]
        }
        second_questions = {
            item["question"] for item in second_response.data["questions"]
        }
        self.assertTrue(first_questions.isdisjoint(second_questions))
        self.assertEqual(QuizQuestionUsage.objects.filter(user=self.user).count(), 20)

    @patch(
        "apps.users.views._generate_questions_from_model",
        side_effect=lambda lecture, count, difficulty, excluded: (
            ComputerArchitectureLectureOneTests._generated_questions(
                "أسئلة التصحيح", count
            )
        ),
    )
    def test_quiz_is_corrected_server_side_and_cannot_be_submitted_twice(
        self,
        generate_questions,
    ):
        response = self._request_quiz()

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(QuizAttempt.objects.filter(user=self.user).count(), 1)
        questions = response.data["questions"]
        self.assertTrue(
            all("correct_index" not in item and "explanation" not in item for item in questions)
        )
        answers = [
            {
                "question_id": item["id"],
                "selected_index": GeneratedQuizQuestion.objects.get(
                    pk=item["id"]
                ).correct_index,
            }
            for item in questions
        ]

        submitted = self.client.post(
            "/api/auth/quizzes/submit/",
            {
                "quiz_id": response.data["quiz_id"],
                "answers": answers,
                "score": 0,
                "earned_xp": 999999,
            },
            format="json",
        )

        self.assertEqual(submitted.status_code, status.HTTP_200_OK)
        self.assertEqual(submitted.data["score"], 10)
        self.assertEqual(submitted.data["earned_xp"], 10)
        self.user.refresh_from_db()
        self.assertEqual(self.user.xp_points, 10)

        duplicate = self.client.post(
            "/api/auth/quizzes/submit/",
            {"quiz_id": response.data["quiz_id"], "answers": answers},
            format="json",
        )

        self.assertEqual(duplicate.status_code, status.HTTP_409_CONFLICT)
        self.user.refresh_from_db()
        self.assertEqual(self.user.xp_points, 10)
        generate_questions.assert_called_once()

    @patch(
        "apps.users.views._generate_questions_from_model",
        side_effect=lambda lecture, count, difficulty, excluded: (
            ComputerArchitectureLectureOneTests._generated_questions(
                "اختبار الملكية", count
            )
        ),
    )
    def test_quiz_attempt_cannot_be_submitted_by_another_user(self, generate_questions):
        response = self._request_quiz()
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        other_user = User.objects.create_user(
            username="another-quiz-student",
            password="test-password",
        )
        self.client.force_authenticate(user=other_user)
        submitted = self.client.post(
            "/api/auth/quizzes/submit/",
            {"quiz_id": response.data["quiz_id"], "answers": []},
            format="json",
        )

        self.assertEqual(submitted.status_code, status.HTTP_404_NOT_FOUND)
        generate_questions.assert_called_once()

    @patch(
        "apps.users.views._generate_questions_from_model",
        side_effect=lambda lecture, count, difficulty, excluded: (
            ComputerArchitectureLectureOneTests._generated_questions(
                "التحدي اليومي", count
            )
        ),
    )
    def test_daily_challenge_awards_bonus_once_and_notifies_student(
        self,
        generate_questions,
    ):
        setup = self.client.post(
            "/api/auth/quizzes/setup/",
            {
                "subject": "Computer Architecture",
                "lecture": 1,
                "count": 5,
                "difficulty": "medium",
                "daily_challenge": True,
            },
            format="json",
        )
        self.assertEqual(setup.status_code, status.HTTP_200_OK)
        challenge = DailyChallenge.objects.get(user=self.user)
        self.assertEqual(str(challenge.attempt.attempt_id), setup.data["quiz_id"])

        answers = [
            {
                "question_id": item["id"],
                "selected_index": GeneratedQuizQuestion.objects.get(
                    pk=item["id"]
                ).correct_index,
            }
            for item in setup.data["questions"]
        ]
        submitted = self.client.post(
            "/api/auth/quizzes/submit/",
            {"quiz_id": setup.data["quiz_id"], "answers": answers},
            format="json",
        )
        self.assertEqual(submitted.status_code, status.HTTP_200_OK)
        self.assertEqual(submitted.data["bonus_xp"], 0)
        self.assertEqual(submitted.data["earned_xp"], 5)
        self.assertEqual(
            Notification.objects.filter(
                recipient=self.user,
                data__kind="daily_challenge",
            ).count(),
            1,
        )

        challenge_response = self.client.get("/api/study/daily-challenge/")
        self.assertEqual(challenge_response.status_code, status.HTTP_200_OK)
        self.assertTrue(challenge_response.data["completed"])
        self.assertTrue(challenge_response.data["started"])
        self.assertIsNone(challenge_response.data["quiz"])

        duplicate = self.client.post(
            "/api/auth/quizzes/setup/",
            {
                "subject": "Computer Architecture",
                "lecture": 1,
                "count": 5,
                "difficulty": "medium",
                "daily_challenge": True,
            },
            format="json",
        )
        self.assertEqual(duplicate.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(Notification.objects.filter(recipient=self.user).count(), 1)
        generate_questions.assert_called_once()

    def test_duplicate_generated_questions_are_rejected(self):
        first_batch = self._generated_questions("مكرر", 9)
        first_batch.append(first_batch[0])
        with patch(
            "apps.users.views._generate_questions_from_model",
            side_effect=[first_batch, self._generated_questions("إضافي", 1)],
        ):
            response = self._request_quiz()

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        question_texts = [item["question"] for item in response.data["questions"]]
        self.assertEqual(len(question_texts), len(set(question_texts)))

    @patch.dict("os.environ", {"GEMINI_API_KEY": ""})
    def test_generation_reports_missing_ai_configuration(self):
        response = self._request_quiz()

        self.assertEqual(
            response.status_code,
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )
        self.assertIn("غير مفعّل", response.data["detail"])
        self.assertEqual(QuizQuestionUsage.objects.filter(user=self.user).count(), 0)

    def _request_quiz(self):
        return self.client.post(
            "/api/auth/quizzes/setup/",
            {
                "subject": "Computer Architecture",
                "lecture": 1,
                "count": 10,
                "difficulty": "medium",
            },
            format="json",
        )

    @staticmethod
    def _generated_questions(prefix, count):
        return [
            {
                "question": f"{prefix}: حلل الفكرة رقم {index} في بنية الحاسوب؟",
                "options": ["اختيار أ", "اختيار ب", "اختيار ج", "اختيار د"],
                "correct_index": index % 4,
                "explanation": f"تفسير الإجابة الصحيحة للسؤال {index}.",
            }
            for index in range(count)
        ]


class AcademicAIChatAPITests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="ai-student",
            password="test-password",
            academic_year=2,
        )
        self.client.force_authenticate(user=self.user)
        self.url = "/api/auth/ai/chat/"

    def test_chat_requires_a_subject(self):
        response = self.client.post(
            self.url,
            {"message": "اشرح الفكرة"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_student_cannot_ask_about_another_year_subject(self):
        response = self.client.post(
            self.url,
            {"message": "اشرح التعلم الآلي", "subject": "Machine Learning"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @patch("apps.users.views.ask_academic_question")
    def test_chat_returns_answer_and_material_sources(self, ask_question):
        ask_question.return_value = {
            "reply": "تعمل وحدة التحكم على تنسيق التنفيذ. [S1]",
            "sources": [{
                "source_id": "S1",
                "file_name": "lecture.pdf",
                "subject": "Computer Architecture",
                "lecture_number": 1,
                "page_number": 4,
            }],
        }

        response = self.client.post(
            self.url,
            {
                "message": "ما وظيفة وحدة التحكم؟",
                "subject": "Computer Architecture",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["subject"], "Computer Architecture")
        self.assertEqual(response.data["sources"][0]["page_number"], 4)


class AcademicAIRetrievalTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="rag-student",
            password="test-password",
            academic_year=2,
        )
        self.lecture, _ = LectureContent.objects.update_or_create(
            subject="Computer Architecture",
            lecture_number=1,
            defaults={
                "content": "The control unit coordinates instruction execution.",
            },
        )

    @patch("apps.users.services.academic_ai.GeminiClient")
    def test_relevant_answer_is_grounded_and_has_source(self, gemini_class):
        client = gemini_class.return_value
        client.embed_texts.side_effect = [[[1.0, 0.0]], [[1.0, 0.0]]]
        client.generate_grounded_answer.return_value = (
            "The control unit coordinates instruction execution. [S1]"
        )

        result = ask_academic_question(
            user=self.user,
            subject="Computer Architecture",
            question="What does the control unit do?",
        )

        self.assertIn("[S1]", result["reply"])
        self.assertEqual(result["sources"][0]["lecture_number"], 1)
        self.assertEqual(DocumentChunk.objects.filter(academic_year=2).count(), 1)

    @patch("apps.users.services.academic_ai.GeminiClient")
    def test_unrelated_question_is_refused_without_generation(self, gemini_class):
        client = gemini_class.return_value
        client.embed_texts.side_effect = [[[0.0, 1.0]], [[1.0, 0.0]]]

        result = ask_academic_question(
            user=self.user,
            subject="Computer Architecture",
            question="What is today's weather?",
        )

        self.assertEqual(result["reply"], NOT_FOUND_MESSAGE)
        self.assertEqual(result["sources"], [])
        client.generate_grounded_answer.assert_not_called()

    @patch("apps.users.services.academic_ai.GeminiClient")
    def test_subject_scope_is_checked_before_document_retrieval(self, gemini_class):
        with self.assertRaises(AcademicAIScopeError) as raised:
            ask_academic_question(
                user=self.user,
                subject="Machine Learning",
                question="Explain neural networks.",
            )

        self.assertEqual(str(raised.exception), "هذه المادة غير متاحة لفرقتك الدراسية.")
        gemini_class.assert_not_called()


class AISummaryAPITests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="summary-student",
            password="test-password",
            academic_year=2,
        )
        self.client.force_authenticate(user=self.user)
        self.url = "/api/auth/ai/summarize/"
        self.payload = {
            "subject": "Computer Architecture",
            "lecture": 1,
            "summary_type": "quick",
        }

    @patch("apps.users.services.academic_ai.GeminiClient")
    def test_summary_is_saved_with_its_material_source(self, gemini_class):
        client = gemini_class.return_value
        client.embed_texts.side_effect = lambda texts, task_type: [
            [1.0, 0.0] for _ in texts
        ]
        client.generate_grounded_answer.return_value = (
            "تلخص المحاضرة بنية الحاسوب ودورة تنفيذ التعليمات. [S1]"
        )

        response = self.client.post(self.url, self.payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("[S1]", response.data["summary"])
        self.assertEqual(response.data["sources"][0]["subject"], self.payload["subject"])
        self.assertEqual(
            AISummary.objects.filter(user=self.user, academic_year=2).count(),
            1,
        )

    def test_summary_rejects_a_subject_outside_the_student_year(self):
        response = self.client.post(
            self.url,
            {**self.payload, "subject": "Machine Learning"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(AISummary.objects.filter(user=self.user).exists())

    def test_summary_requires_a_lecture_number(self):
        response = self.client.post(
            self.url,
            {"subject": self.payload["subject"], "summary_type": "quick"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_summary_service_reuses_academic_scope_validation(self):
        with self.assertRaises(AcademicAIScopeError):
            summarize_academic_lecture(
                user=self.user,
                subject="Machine Learning",
                lecture_number=1,
                summary_type="quick",
            )


class StudyFeatureAPITests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="study-feature-student",
            password="test-password-123",
            academic_year=4,
        )
        self.client.force_authenticate(user=self.user)

    def test_daily_challenge_has_five_questions_and_is_idempotent(self):
        first = self.client.get("/api/study/daily-challenge/")
        second = self.client.get("/api/study/daily-challenge/")

        self.assertEqual(first.status_code, status.HTTP_200_OK)
        self.assertEqual(first.data["goal_questions"], 5)
        self.assertFalse(first.data["started"])
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(DailyChallenge.objects.filter(user=self.user).count(), 1)

    def test_smart_review_marks_only_owners_answer(self):
        attempt = QuizAttempt.objects.create(
            user=self.user,
            subject="Computer Architecture",
            lecture_number=1,
            difficulty="medium",
            total_questions=1,
            score=0,
            completed_at=timezone.now(),
        )
        question = GeneratedQuizQuestion.objects.create(
            subject=attempt.subject,
            lecture_number=attempt.lecture_number,
            difficulty=attempt.difficulty,
            question="سؤال للمراجعة",
            options=["أ", "ب"],
            correct_index=0,
            explanation="الإجابة الصحيحة هي أ.",
            fingerprint="review-test-question",
        )
        answer = QuizAttemptAnswer.objects.create(
            attempt=attempt,
            question=question,
            selected_index=1,
            is_correct=False,
            answered_at=timezone.now(),
        )

        review = self.client.get("/api/study/review/")
        self.assertEqual(review.status_code, status.HTTP_200_OK)
        self.assertEqual(review.data["count"], 1)
        self.assertEqual(review.data["results"][0]["id"], answer.id)

        marked = self.client.post(
            f"/api/study/review/{answer.id}/mark/",
            {},
            format="json",
        )
        self.assertEqual(marked.status_code, status.HTTP_200_OK)
        self.assertEqual(marked.data["review_count"], 1)
        self.assertEqual(self.client.get("/api/study/review/").data["count"], 0)

        other_user = User.objects.create_user(
            username="other-study-student",
            password="test-password-123",
            academic_year=4,
        )
        self.client.force_authenticate(user=other_user)
        forbidden_answer = self.client.post(
            f"/api/study/review/{answer.id}/mark/",
            {},
            format="json",
        )
        self.assertEqual(forbidden_answer.status_code, status.HTTP_404_NOT_FOUND)

    def test_study_plan_crud_and_ownership(self):
        created = self.client.post(
            "/api/study/plans/",
            {
                "title": "خطة الاستعداد",
                "target_minutes_per_day": 45,
                "sessions_per_week": 4,
                "start_date": timezone.localdate().isoformat(),
                "notes": "مراجعة الوحدات الأولى",
            },
            format="json",
        )
        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        plan_id = created.data["id"]
        self.assertEqual(StudyPlan.objects.filter(user=self.user).count(), 1)

        invalid_plan = self.client.patch(
            f"/api/study/plans/{plan_id}/",
            {"is_active": "yes"},
            format="json",
        )
        self.assertEqual(invalid_plan.status_code, status.HTTP_400_BAD_REQUEST)

        updated = self.client.patch(
            f"/api/study/plans/{plan_id}/",
            {"title": "خطة محدثة", "is_active": False},
            format="json",
        )
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.assertEqual(updated.data["title"], "خطة محدثة")
        self.assertFalse(updated.data["is_active"])

        other_user = User.objects.create_user(
            username="other-plan-student",
            password="test-password-123",
            academic_year=4,
        )
        self.client.force_authenticate(user=other_user)
        self.assertEqual(
            self.client.patch(
                f"/api/study/plans/{plan_id}/",
                {"title": "محاولة تعديل"},
                format="json",
            ).status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_report_aggregates_completed_attempts(self):
        attempt = QuizAttempt.objects.create(
            user=self.user,
            subject="Computer Architecture",
            lecture_number=1,
            difficulty="medium",
            total_questions=4,
            score=3,
            earned_xp=3,
            completed_at=timezone.now(),
        )
        question = GeneratedQuizQuestion.objects.create(
            subject=attempt.subject,
            lecture_number=attempt.lecture_number,
            difficulty=attempt.difficulty,
            question="سؤال عن الذاكرة",
            options=["أ", "ب", "ج", "د"],
            correct_index=0,
            explanation="شرح السؤال",
            fingerprint="report-focus-area-question",
            topic="الذاكرة المخبئية",
        )
        QuizAttemptAnswer.objects.create(
            attempt=attempt,
            question=question,
            selected_index=1,
            is_correct=False,
        )

        response = self.client.get("/api/study/reports/?days=7")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["summary"]["quizzes"], 1)
        self.assertEqual(response.data["summary"]["questions"], 4)
        self.assertEqual(response.data["summary"]["correct"], 3)
        self.assertEqual(response.data["summary"]["xp"], 3)
        self.assertEqual(response.data["summary"]["accuracy_percent"], 75)
        self.assertEqual(
            response.data["focus_areas"][0]["topic"],
            "الذاكرة المخبئية",
        )

    def test_notification_reads_and_preferences_are_user_scoped_and_validated(self):
        own_notification = Notification.objects.create(
            recipient=self.user,
            title="إشعار الطالب",
            body="نص الإشعار",
        )
        other_user = User.objects.create_user(
            username="notification-owner",
            password="test-password-123",
            academic_year=4,
        )
        other_notification = Notification.objects.create(
            recipient=other_user,
            title="إشعار آخر",
            body="يبقى غير مقروء",
        )

        unknown_setting = self.client.patch(
            "/api/study/preferences/",
            {"updated_at": "not-allowed"},
            format="json",
        )
        self.assertEqual(unknown_setting.status_code, status.HTTP_400_BAD_REQUEST)

        updated_preferences = self.client.patch(
            "/api/study/preferences/",
            {
                "notifications_enabled": False,
                "study_goal_minutes": 90,
            },
            format="json",
        )
        self.assertEqual(updated_preferences.status_code, status.HTTP_200_OK)
        self.assertFalse(updated_preferences.data["notifications_enabled"])
        self.assertEqual(updated_preferences.data["study_goal_minutes"], 90)

        read_all = self.client.post(
            "/api/study/notifications/read-all/",
            {},
            format="json",
        )
        self.assertEqual(read_all.status_code, status.HTTP_200_OK)
        own_notification.refresh_from_db()
        other_notification.refresh_from_db()
        self.assertTrue(own_notification.is_read)
        self.assertFalse(other_notification.is_read)