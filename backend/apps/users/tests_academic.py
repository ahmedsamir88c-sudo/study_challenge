import io
import json
import os
import tempfile
from unittest.mock import MagicMock, patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APITestCase

from .models import (
    AcademicYear,
    AuditLog,
    DocumentChunk,
    Flashcard,
    GeneratedQuizQuestion,
    Lecture,
    MaterialDocument,
    Subject,
    User,
)
from .services.academic_ai import (
    NOT_FOUND_MESSAGE,
    ask_academic_question,
    generate_academic_flashcards,
    generate_academic_quiz,
    summarize_academic_lecture,
)
from .services.material_processor import (
    FileValidationError,
    chunk_pages,
    extract_pages,
    process_material_sync,
    replace_document_file,
    validate_file,
)


class AcademicMaterialTests(APITestCase):
    def setUp(self):
        # 1. Owner account
        self.owner = User.objects.create_superuser(
            username="academic-owner",
            password="Test-only!Secure-9427",
            role=User.Role.OWNER,
            university_id="42510677",
        )

        # 2. Student account
        self.student = User.objects.create_user(
            username="academic-student",
            password="Test-only!Secure-9427",
            role=User.Role.STUDENT,
            university_id="11223344",
            academic_year=4,
        )

        # 3. Academic Structure
        self.year4, _ = AcademicYear.objects.get_or_create(
            year_number=4,
            defaults={"name": "الفرقة الرابعة", "order": 4},
        )
        self.year2, _ = AcademicYear.objects.get_or_create(
            year_number=2,
            defaults={"name": "الفرقة الثانية", "order": 2},
        )

        self.subject_ml, _ = Subject.objects.get_or_create(
            academic_year=self.year4,
            name="Machine Learning",
            defaults={"code": "CS401", "description": "تعلم الآلة"},
        )
        self.subject_arch, _ = Subject.objects.get_or_create(
            academic_year=self.year2,
            name="Computer Architecture",
            defaults={"code": "CS201", "description": "معمارية الحاسوب"},
        )

        self.lecture_ml1, _ = Lecture.objects.get_or_create(
            subject=self.subject_ml,
            lecture_number=1,
            defaults={"title": "Introduction to Machine Learning"},
        )
        self.lecture_ml2, _ = Lecture.objects.get_or_create(
            subject=self.subject_ml,
            lecture_number=2,
            defaults={"title": "Supervised Learning"},
        )

    def test_owner_subject_creation_creates_sixteen_lectures(self):
        self.client.force_authenticate(user=self.owner)

        response = self.client.post(
            "/api/academic/subjects/",
            {
                "academic_year": self.year4.id,
                "name": "Sixteen Lecture Test Subject",
                "code": "CS416",
                "description": "Subject used to verify lecture creation.",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        subject = Subject.objects.get(id=response.data["id"])
        self.assertEqual(subject.lectures.count(), 16)
        self.assertEqual(response.data["lecture_count"], 16)

    def test_owner_can_upload_pdf_material(self):
        self.client.force_authenticate(user=self.owner)
        pdf_content = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF"
        uploaded_file = SimpleUploadedFile("ml_lecture1.pdf", pdf_content, content_type="application/pdf")

        response = self.client.post(
            "/api/academic/materials/upload/",
            {
                "subject_id": self.subject_ml.id,
                "lecture_id": self.lecture_ml1.id,
                "title": "Machine Learning Introduction",
                "files": [uploaded_file],
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["count"], 1)
        doc = MaterialDocument.objects.get(id=response.data["uploaded"][0]["id"])
        self.assertEqual(doc.title, "Machine Learning Introduction")
        self.assertEqual(doc.subject, self.subject_ml)
        self.assertEqual(doc.lecture, self.lecture_ml1)
        self.assertEqual(doc.uploaded_by, self.owner)
        self.assertEqual(doc.file_type, "pdf")

        # Verify audit log
        self.assertTrue(
            AuditLog.objects.filter(user=self.owner, action="UPLOAD_FILE").exists()
        )

    def test_student_cannot_upload_material(self):
        self.client.force_authenticate(user=self.student)
        pdf_content = b"%PDF-1.4\ntest"
        uploaded_file = SimpleUploadedFile("student_file.pdf", pdf_content, content_type="application/pdf")

        response = self.client.post(
            "/api/academic/materials/upload/",
            {
                "subject_id": self.subject_ml.id,
                "lecture_id": self.lecture_ml1.id,
                "files": [uploaded_file],
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_upload_rejects_lecture_from_another_subject(self):
        self.client.force_authenticate(user=self.owner)
        other_subject_lecture, _ = Lecture.objects.get_or_create(
            subject=self.subject_arch,
            lecture_number=99,
            defaults={"title": "Architecture lecture"},
        )
        uploaded_file = SimpleUploadedFile(
            "wrong-lecture.txt",
            b"Academic content",
            content_type="text/plain",
        )

        response = self.client.post(
            "/api/academic/materials/upload/",
            {
                "subject_id": self.subject_ml.id,
                "lecture_id": other_subject_lecture.id,
                "files": [uploaded_file],
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(
            MaterialDocument.objects.filter(original_filename="wrong-lecture.txt").exists()
        )

    def test_file_validation_rejects_invalid_type(self):
        invalid_file = SimpleUploadedFile("script.exe", b"MZ\x90\x00executable", content_type="application/octet-stream")
        with self.assertRaises(FileValidationError):
            validate_file(invalid_file)

    def test_file_validation_rejects_corrupted_pdf_header(self):
        corrupt_pdf = SimpleUploadedFile("corrupt.pdf", b"NOT_A_PDF_HEADER", content_type="application/pdf")
        with self.assertRaises(FileValidationError):
            validate_file(corrupt_pdf)

    def test_txt_and_arabic_text_extraction(self):
        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False, mode="w", encoding="utf-8") as f:
            f.write("مقدمة في الذكاء الاصطناعي والتعلم الآلي.\n\nالتعلم الخاضع للإشراف Supervised Learning يعتمد على بيانات معنونة.")
            temp_path = f.name

        try:
            pages = extract_pages(temp_path, "txt")
            self.assertTrue(len(pages) >= 1)
            self.assertIn("الذكاء الاصطناعي", pages[0]["text"])
            self.assertIn("Supervised Learning", pages[0]["text"])

            chunks = chunk_pages(pages, chunk_size=100, overlap=20)
            self.assertTrue(len(chunks) >= 1)
            self.assertEqual(chunks[0]["page_number"], 1)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)


class AcademicMaterialProcessingTests(APITestCase):
    def setUp(self):
        self.student = User.objects.create_user(
            username="academic-ai-input-student",
            password="test-password",
            academic_year=4,
        )
        self.client.force_authenticate(user=self.student)
        self.owner = User.objects.create_superuser(
            username="material-processing-owner",
            password="test-password",
            role=User.Role.OWNER,
            university_id="42510677",
        )
        self.year4, _ = AcademicYear.objects.get_or_create(
            year_number=4,
            defaults={"name": "الفرقة الرابعة", "order": 4},
        )
        self.year2, _ = AcademicYear.objects.get_or_create(
            year_number=2,
            defaults={"name": "الفرقة الثانية", "order": 2},
        )
        self.subject_ml, _ = Subject.objects.get_or_create(
            academic_year=self.year4,
            name="Machine Learning",
            defaults={"code": "CS401", "description": "تعلم الآلة"},
        )
        self.subject_arch, _ = Subject.objects.get_or_create(
            academic_year=self.year2,
            name="Computer Architecture",
            defaults={"code": "CS201", "description": "معمارية الحاسوب"},
        )
        self.lecture_ml1, _ = Lecture.objects.get_or_create(
            subject=self.subject_ml,
            lecture_number=1,
            defaults={"title": "Introduction to Machine Learning"},
        )
        self.lecture_ml2, _ = Lecture.objects.get_or_create(
            subject=self.subject_ml,
            lecture_number=2,
            defaults={"title": "Supervised Learning"},
        )

    def test_quiz_generation_rejects_invalid_count_and_topic_types(self):
        url = "/api/academic/ai/generate-quiz/"
        for payload in (
            {"subject": "Machine Learning", "count": "not-a-number"},
            {"subject": "Machine Learning", "count": 51},
            {"subject": "Machine Learning", "topic": {"invalid": "type"}},
        ):
            with self.subTest(payload=payload):
                response = self.client.post(url, payload, format="json")
                self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_flashcard_generation_rejects_invalid_count(self):
        response = self.client.post(
            "/api/academic/ai/generate-flashcards/",
            {"subject": "Machine Learning", "count": "invalid"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_chat_rejects_invalid_document_id(self):
        response = self.client.post(
            "/api/academic/ai/chat/",
            {
                "message": "اشرح هذا المحتوى",
                "subject": "Machine Learning",
                "document_id": "not-an-id",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch("apps.users.services.material_processor.GeminiClient")
    def test_document_processing_pipeline(self, mock_gemini_cls):
        mock_client = MagicMock()
        mock_gemini_cls.return_value = mock_client
        mock_client.embed_texts.return_value = [[0.1] * 768]

        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False, mode="w", encoding="utf-8") as f:
            f.write("Machine learning is a subset of artificial intelligence.")
            temp_path = f.name

        try:
            with open(temp_path, "rb") as f:
                doc = MaterialDocument.objects.create(
                    academic_year=self.year4,
                    subject=self.subject_ml,
                    lecture=self.lecture_ml1,
                    title="ML Notes",
                    original_filename="ml_notes.txt",
                    file=SimpleUploadedFile("ml_notes.txt", f.read(), content_type="text/plain"),
                    file_type="txt",
                    file_size=100,
                    uploaded_by=self.owner,
                )

            # Process synchronously
            success = process_material_sync(doc.id)
            self.assertTrue(success)

            doc.refresh_from_db()
            self.assertEqual(doc.processing_status, MaterialDocument.ProcessingStatus.READY)
            self.assertEqual(doc.page_count, 1)

            chunks = DocumentChunk.objects.filter(document=doc, is_active=True)
            self.assertEqual(chunks.count(), 1)
            self.assertEqual(chunks.first().page_number, 1)
            self.assertEqual(len(chunks.first().embedding), 768)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_subject_isolation_in_rag_retrieval(self):
        # Create chunk in Machine Learning
        DocumentChunk.objects.create(
            academic_year=4,
            chunk_index=0,
            page_number=1,
            text="Machine learning models learn patterns from training data.",
            embedding=[0.9, 0.1, 0.0],
            source_hash="hash_ml",
            is_active=True,
            document=MaterialDocument.objects.create(
                academic_year=self.year4,
                subject=self.subject_ml,
                lecture=self.lecture_ml1,
                title="ML Lecture",
                original_filename="ml.pdf",
                file_type="pdf",
                uploaded_by=self.owner,
                processing_status=MaterialDocument.ProcessingStatus.READY,
            ),
        )

        # Create chunk in Computer Architecture (Different subject and year!)
        DocumentChunk.objects.create(
            academic_year=2,
            chunk_index=0,
            page_number=1,
            text="The CPU control unit coordinates instruction execution.",
            embedding=[0.9, 0.1, 0.0],
            source_hash="hash_arch",
            is_active=True,
            document=MaterialDocument.objects.create(
                academic_year=self.year2,
                subject=self.subject_arch,
                title="Arch Lecture",
                original_filename="arch.pdf",
                file_type="pdf",
                uploaded_by=self.owner,
                processing_status=MaterialDocument.ProcessingStatus.READY,
            ),
        )

        # When asking about Machine Learning with Gemini mocked
        with patch("apps.users.services.academic_ai.GeminiClient") as mock_gemini_cls:
            mock_client = MagicMock()
            mock_gemini_cls.return_value = mock_client
            mock_client.embed_texts.return_value = [[0.9, 0.1, 0.0]]
            mock_client.generate_grounded_answer.return_value = "نماذج تعلم الآلة تتعلم الأنماط."

            response = ask_academic_question(
                user=self.student,
                subject="Machine Learning",
                question="كيف يتعلم النموذج؟",
            )

            # Check that only Machine Learning sources were retrieved!
            self.assertTrue(len(response["sources"]) >= 1)
            for src in response["sources"]:
                self.assertEqual(src["subject"], "Machine Learning")
                self.assertNotEqual(src["subject"], "Computer Architecture")

    def test_ai_grounding_not_found_message_when_no_match(self):
        with patch("apps.users.services.academic_ai.GeminiClient") as mock_gemini_cls:
            mock_client = MagicMock()
            mock_gemini_cls.return_value = mock_client
            # Unrelated embedding with 0 similarity
            mock_client.embed_texts.return_value = [[-1.0, 0.0, 0.0]]

            DocumentChunk.objects.create(
                academic_year=4,
                chunk_index=0,
                page_number=5,
                text="Supervised learning uses labeled training sets.",
                embedding=[1.0, 0.0, 0.0],
                source_hash="hash1",
                is_active=True,
                document=MaterialDocument.objects.create(
                    academic_year=self.year4,
                    subject=self.subject_ml,
                    lecture=self.lecture_ml1,
                    title="ML Lecture",
                    original_filename="ml.pdf",
                    file_type="pdf",
                    uploaded_by=self.owner,
                    processing_status=MaterialDocument.ProcessingStatus.READY,
                ),
            )

            response = ask_academic_question(
                user=self.student,
                subject="Machine Learning",
                question="ما هو علاج التهاب الحلق؟",  # Unrelated medical query
            )

            self.assertEqual(response["reply"], NOT_FOUND_MESSAGE)
            self.assertEqual(response["sources"], [])

    @patch("apps.users.services.academic_ai.GeminiClient")
    def test_quiz_generation_mcq_and_essay(self, mock_gemini_cls):
        mock_client = MagicMock()
        mock_gemini_cls.return_value = mock_client

        doc = MaterialDocument.objects.create(
            academic_year=self.year4,
            subject=self.subject_ml,
            lecture=self.lecture_ml1,
            title="ML Intro",
            original_filename="ml.pdf",
            file_type="pdf",
            uploaded_by=self.owner,
            processing_status=MaterialDocument.ProcessingStatus.READY,
        )
        DocumentChunk.objects.create(
            document=doc,
            academic_year=4,
            chunk_index=0,
            page_number=3,
            text="Classification is predicting discrete categories.",
            embedding=[0.5] * 768,
            source_hash="h1",
            is_active=True,
        )

        # Mock structured json output for MCQ
        mock_client.generate_structured_json.return_value = [
            {
                "question": "ما هو التصنيف في تعلم الآلة؟",
                "options": ["تنبؤ بفئات منفصلة", "تنبؤ بقيم مستمرة", "تجميع عشوائي", "حذف البيانات"],
                "correct_index": 0,
                "explanation": "التصنيف هو التنبؤ بفئات منفصلة.",
                "topic": "Classification",
                "page_number": 3,
            }
        ]

        quiz_res = generate_academic_quiz(
            user=self.owner,
            subject="Machine Learning",
            lecture_number=1,
            document_id=doc.id,
            question_type="mcq",
            count=1,
        )
        self.assertEqual(quiz_res["count"], 1)
        self.assertEqual(quiz_res["questions"][0]["correct_index"], 0)
        self.assertEqual(quiz_res["questions"][0]["page_number"], 3)

        # Verify in database
        saved_q = GeneratedQuizQuestion.objects.filter(subject="Machine Learning").first()
        self.assertIsNotNone(saved_q)
        self.assertEqual(saved_q.question_type, "mcq")
        self.assertEqual(len(saved_q.options), 4)

    @patch("apps.users.services.academic_ai.GeminiClient")
    def test_flashcards_generation(self, mock_gemini_cls):
        mock_client = MagicMock()
        mock_gemini_cls.return_value = mock_client

        doc = MaterialDocument.objects.create(
            academic_year=self.year4,
            subject=self.subject_ml,
            lecture=self.lecture_ml1,
            title="ML Intro",
            original_filename="ml.pdf",
            file_type="pdf",
            uploaded_by=self.owner,
            processing_status=MaterialDocument.ProcessingStatus.READY,
        )
        DocumentChunk.objects.create(
            document=doc,
            academic_year=4,
            chunk_index=0,
            page_number=7,
            text="Regression is predicting continuous numerical values.",
            embedding=[0.5] * 768,
            source_hash="h2",
            is_active=True,
        )

        mock_client.generate_structured_json.return_value = [
            {
                "question": "ما هو الانحدار Regression؟",
                "answer": "التنبؤ بالقيم العددية المستمرة.",
                "topic": "Regression",
                "page_number": 7,
            }
        ]

        flash_res = generate_academic_flashcards(
            user=self.student,
            subject="Machine Learning",
            lecture_number=1,
            document_id=doc.id,
            count=1,
        )
        self.assertEqual(flash_res["count"], 1)
        self.assertEqual(flash_res["flashcards"][0]["page_number"], 7)
        self.assertTrue(Flashcard.objects.filter(user=self.student, topic="Regression").exists())

    def test_file_replacement_deactivates_old_chunks(self):
        doc = MaterialDocument.objects.create(
            academic_year=self.year4,
            subject=self.subject_ml,
            lecture=self.lecture_ml1,
            title="ML Versioned",
            original_filename="v1.pdf",
            file_type="pdf",
            file_size=500,
            uploaded_by=self.owner,
            version=1,
            processing_status=MaterialDocument.ProcessingStatus.READY,
        )
        chunk_v1 = DocumentChunk.objects.create(
            document=doc,
            academic_year=4,
            chunk_index=0,
            page_number=1,
            text="Old lecture content version 1",
            embedding=[0.1] * 768,
            source_hash="old_hash",
            is_active=True,
        )

        pdf_v2 = SimpleUploadedFile("v2.pdf", b"%PDF-1.4\nNew content v2", content_type="application/pdf")
        with patch("apps.users.services.material_processor.trigger_document_processing"):
            replace_document_file(doc, pdf_v2, uploader_user=self.owner)

        doc.refresh_from_db()
        chunk_v1.refresh_from_db()

        self.assertEqual(doc.version, 2)
        self.assertEqual(doc.original_filename, "v2.pdf")
        self.assertFalse(chunk_v1.is_active)  # Old chunks MUST be deactivated!

    def test_failed_processing_retry_endpoint(self):
        doc = MaterialDocument.objects.create(
            academic_year=self.year4,
            subject=self.subject_ml,
            lecture=self.lecture_ml1,
            title="Failed Doc",
            original_filename="failed.pdf",
            file_type="pdf",
            uploaded_by=self.owner,
            processing_status=MaterialDocument.ProcessingStatus.FAILED,
            processing_error="Corrupt file format error",
        )

        self.client.force_authenticate(user=self.owner)
        with patch("apps.users.academic_views.trigger_document_processing") as mock_trigger:
            response = self.client.post(f"/api/academic/materials/{doc.id}/retry/")
            self.assertEqual(response.status_code, status.HTTP_200_OK)
            mock_trigger.assert_called_once_with(doc.id, async_process=True)

        doc.refresh_from_db()
        self.assertEqual(doc.processing_status, MaterialDocument.ProcessingStatus.PROCESSING)
        self.assertEqual(doc.processing_error, "")

    def test_owner_academic_dashboard_metrics(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get("/api/academic/dashboard/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        metrics = response.data["metrics"]
        self.assertIn("total_academic_years", metrics)
        self.assertIn("total_subjects", metrics)
        self.assertIn("total_materials", metrics)
        self.assertIn("ready_materials", metrics)
        self.assertIn("failed_materials", metrics)
        self.assertIn("recent_uploads", response.data)
        self.assertIn("processing_queue", response.data)
        self.assertIn("failed_files", response.data)
