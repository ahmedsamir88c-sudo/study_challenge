import os
from django.conf import settings
from django.db.models import Count, Q
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .academic_serializers import (
    AcademicYearSerializer,
    AuditLogSerializer,
    FlashcardSerializer,
    LectureSerializer,
    MaterialDocumentSerializer,
    SubjectSerializer,
)
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
from .permissions import IsOwner
from .services.academic_ai import (
    AcademicAIScopeError,
    ask_academic_question,
    generate_academic_flashcards,
    generate_academic_quiz,
    summarize_academic_lecture,
)
from .services.gemini_client import GeminiServiceError
from .services.material_processor import (
    FileValidationError,
    replace_document_file,
    trigger_document_processing,
    validate_file,
)


def get_client_ip(request) -> str:
    x_forwarded_for = request.META.get("HTTP_X_FORWARDED_FOR")
    if x_forwarded_for:
        return x_forwarded_for.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR", "")


# ─────────────────────────────────────────────────────────────
# ACADEMIC YEARS
# ─────────────────────────────────────────────────────────────

class AcademicYearListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [IsOwner()]
        return [permissions.IsAuthenticated()]

    def get(self, request):
        years = AcademicYear.objects.all().order_by("order", "year_number")
        serializer = AcademicYearSerializer(years, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = AcademicYearSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        year = serializer.save()
        AuditLog.objects.create(
            user=request.user,
            action="CREATE_ACADEMIC_YEAR",
            details={"year_id": year.id, "year_number": year.year_number, "name": year.name},
            ip_address=get_client_ip(request),
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class AcademicYearDetailView(APIView):
    permission_classes = [IsOwner]

    def get_object(self, pk):
        return get_object_or_404(AcademicYear, pk=pk)

    def get(self, request, pk):
        year = self.get_object(pk)
        return Response(AcademicYearSerializer(year).data)

    def patch(self, request, pk):
        year = self.get_object(pk)
        serializer = AcademicYearSerializer(year, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        AuditLog.objects.create(
            user=request.user,
            action="UPDATE_ACADEMIC_YEAR",
            details={"year_id": year.id, "updated_fields": list(request.data.keys())},
            ip_address=get_client_ip(request),
        )
        return Response(serializer.data)

    def delete(self, request, pk):
        year = self.get_object(pk)
        year_name = year.name
        year.delete()
        AuditLog.objects.create(
            user=request.user,
            action="DELETE_ACADEMIC_YEAR",
            details={"year_id": pk, "name": year_name},
            ip_address=get_client_ip(request),
        )
        return Response({"message": "تم حذف الفرقة الدراسية بنجاح."}, status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────────────────────
# SUBJECTS
# ─────────────────────────────────────────────────────────────

class SubjectListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [IsOwner()]
        return [permissions.IsAuthenticated()]

    def get(self, request):
        qs = Subject.objects.select_related("academic_year").all()
        year_param = request.query_params.get("year")
        search = request.query_params.get("search", "").strip()

        if year_param:
            try:
                year_num = int(year_param)
                qs = qs.filter(Q(academic_year__year_number=year_num) | Q(academic_year_id=year_num))
            except ValueError:
                pass

        # For student: show their academic year subjects by default if no year filter
        if request.user.role == User.Role.STUDENT and not year_param and request.user.academic_year:
            qs = qs.filter(academic_year__year_number=request.user.academic_year)

        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(code__icontains=search) | Q(description__icontains=search))

        qs = qs.order_by("academic_year__order", "order", "name")
        serializer = SubjectSerializer(qs, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = SubjectSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        subject = serializer.save()
        AuditLog.objects.create(
            user=request.user,
            action="CREATE_SUBJECT",
            details={
                "subject_id": subject.id,
                "name": subject.name,
                "academic_year": subject.academic_year.name,
            },
            ip_address=get_client_ip(request),
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class SubjectDetailView(APIView):
    permission_classes = [IsOwner]

    def get_object(self, pk):
        return get_object_or_404(Subject.objects.select_related("academic_year"), pk=pk)

    def get(self, request, pk):
        return Response(SubjectSerializer(self.get_object(pk)).data)

    def patch(self, request, pk):
        subject = self.get_object(pk)
        serializer = SubjectSerializer(subject, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        AuditLog.objects.create(
            user=request.user,
            action="UPDATE_SUBJECT",
            details={"subject_id": subject.id, "name": subject.name},
            ip_address=get_client_ip(request),
        )
        return Response(serializer.data)

    def delete(self, request, pk):
        subject = self.get_object(pk)
        name = subject.name
        subject.delete()
        AuditLog.objects.create(
            user=request.user,
            action="DELETE_SUBJECT",
            details={"subject_id": pk, "name": name},
            ip_address=get_client_ip(request),
        )
        return Response({"message": "تم حذف المادة بنجاح."}, status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────────────────────
# LECTURES
# ─────────────────────────────────────────────────────────────

class LectureListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [IsOwner()]
        return [permissions.IsAuthenticated()]

    def get(self, request):
        qs = Lecture.objects.select_related("subject", "subject__academic_year").all()
        subject_id = request.query_params.get("subject_id")
        subject_name = request.query_params.get("subject_name")

        if subject_id:
            qs = qs.filter(subject_id=subject_id)
        elif subject_name:
            qs = qs.filter(subject__name=subject_name)

        qs = qs.order_by("order", "lecture_number")
        serializer = LectureSerializer(qs, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = LectureSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        lecture = serializer.save()
        AuditLog.objects.create(
            user=request.user,
            action="CREATE_LECTURE",
            details={
                "lecture_id": lecture.id,
                "title": lecture.title,
                "subject": lecture.subject.name,
                "lecture_number": lecture.lecture_number,
            },
            ip_address=get_client_ip(request),
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class LectureDetailView(APIView):
    permission_classes = [IsOwner]

    def get_object(self, pk):
        return get_object_or_404(Lecture.objects.select_related("subject"), pk=pk)

    def get(self, request, pk):
        return Response(LectureSerializer(self.get_object(pk)).data)

    def patch(self, request, pk):
        lecture = self.get_object(pk)
        serializer = LectureSerializer(lecture, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        AuditLog.objects.create(
            user=request.user,
            action="UPDATE_LECTURE",
            details={"lecture_id": lecture.id, "title": lecture.title},
            ip_address=get_client_ip(request),
        )
        return Response(serializer.data)

    def delete(self, request, pk):
        lecture = self.get_object(pk)
        title = lecture.title
        lecture.delete()
        AuditLog.objects.create(
            user=request.user,
            action="DELETE_LECTURE",
            details={"lecture_id": pk, "title": title},
            ip_address=get_client_ip(request),
        )
        return Response({"message": "تم حذف المحاضرة بنجاح."}, status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────────────────────
# MATERIALS / FILES MANAGEMENT
# ─────────────────────────────────────────────────────────────

class MaterialUploadView(APIView):
    parser_classes = [MultiPartParser, FormParser]
    permission_classes = [IsOwner]

    def post(self, request):
        subject_id = request.data.get("subject_id")
        lecture_id = request.data.get("lecture_id")
        academic_year_id = request.data.get("academic_year_id")
        title = request.data.get("title", "").strip()

        if not subject_id:
            return Response({"detail": "يجب تحديد المادة الدراسية."}, status=status.HTTP_400_BAD_REQUEST)

        subject = get_object_or_404(Subject.objects.select_related("academic_year"), pk=subject_id)
        lecture = get_object_or_404(Lecture, pk=lecture_id) if lecture_id else None
        year = subject.academic_year

        # Support single or multiple files
        files = request.FILES.getlist("files")
        if not files and "file" in request.FILES:
            files = [request.FILES["file"]]

        if not files:
            return Response({"detail": "يرجى اختيار ملف أو أكثر للرفع."}, status=status.HTTP_400_BAD_REQUEST)

        uploaded_docs = []
        errors = []

        for f in files:
            try:
                name, file_type, file_size = validate_file(f)
                doc_title = title if len(files) == 1 and title else os.path.splitext(name)[0]
                mime_type = getattr(f, "content_type", "") or ""

                doc = MaterialDocument.objects.create(
                    academic_year=year,
                    subject=subject,
                    lecture=lecture,
                    title=doc_title,
                    original_filename=name,
                    file=f,
                    file_type=file_type,
                    file_size=file_size,
                    mime_type=mime_type,
                    uploaded_by=request.user,
                    processing_status=MaterialDocument.ProcessingStatus.UPLOADED,
                )

                AuditLog.objects.create(
                    user=request.user,
                    action="UPLOAD_FILE",
                    details={
                        "document_id": doc.id,
                        "title": doc.title,
                        "filename": name,
                        "size": file_size,
                        "subject": subject.name,
                    },
                    ip_address=get_client_ip(request),
                )

                # Trigger background processing
                trigger_document_processing(doc.id, async_process=True)
                uploaded_docs.append(doc)

            except FileValidationError as val_err:
                errors.append(f"الملف {getattr(f, 'name', '')}: {str(val_err)}")
            except Exception as e:
                errors.append(f"الملف {getattr(f, 'name', '')}: تعذر حفظ الملف ({str(e)})")

        serializer = MaterialDocumentSerializer(uploaded_docs, many=True, context={"request": request})
        return Response(
            {
                "uploaded": serializer.data,
                "count": len(uploaded_docs),
                "errors": errors,
            },
            status=status.HTTP_201_CREATED if uploaded_docs else status.HTTP_400_BAD_REQUEST,
        )


class MaterialListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        qs = MaterialDocument.objects.select_related(
            "academic_year", "subject", "lecture", "uploaded_by"
        ).filter(is_active=True)

        # Filters
        year_param = request.query_params.get("academic_year")
        subject_param = request.query_params.get("subject")
        lecture_param = request.query_params.get("lecture")
        status_param = request.query_params.get("status")
        type_param = request.query_params.get("type")
        search = request.query_params.get("search", "").strip()

        # Student scope restrictions
        if request.user.role == User.Role.STUDENT:
            if request.user.academic_year:
                qs = qs.filter(academic_year__year_number=request.user.academic_year)
            # Students only see READY materials
            qs = qs.filter(processing_status=MaterialDocument.ProcessingStatus.READY)

        if year_param:
            qs = qs.filter(Q(academic_year__year_number=year_param) | Q(academic_year_id=year_param))
        if subject_param:
            qs = qs.filter(Q(subject__name=subject_param) | Q(subject_id=subject_param))
        if lecture_param:
            qs = qs.filter(Q(lecture__lecture_number=lecture_param) | Q(lecture_id=lecture_param))
        if status_param and request.user.role == User.Role.OWNER:
            qs = qs.filter(processing_status=status_param.upper())
        if type_param:
            qs = qs.filter(file_type__iexact=type_param.strip())
        if search:
            qs = qs.filter(
                Q(title__icontains=search)
                | Q(original_filename__icontains=search)
                | Q(subject__name__icontains=search)
            )

        qs = qs.order_by("-uploaded_at")
        serializer = MaterialDocumentSerializer(qs, many=True, context={"request": request})
        return Response(serializer.data)


class MaterialDetailView(APIView):
    def get_permissions(self):
        if self.request.method in ("DELETE", "PATCH", "PUT"):
            return [IsOwner()]
        return [permissions.IsAuthenticated()]

    def get_object(self, pk):
        return get_object_or_404(
            MaterialDocument.objects.select_related("academic_year", "subject", "lecture", "uploaded_by"),
            pk=pk,
        )

    def get(self, request, pk):
        doc = self.get_object(pk)
        return Response(MaterialDocumentSerializer(doc, context={"request": request}).data)

    def delete(self, request, pk):
        doc = self.get_object(pk)
        title = doc.title
        # Deactivate associated chunks
        DocumentChunk.objects.filter(document=doc).delete()
        doc.delete()
        AuditLog.objects.create(
            user=request.user,
            action="DELETE_FILE",
            details={"document_id": pk, "title": title},
            ip_address=get_client_ip(request),
        )
        return Response({"message": "تم حذف الملف وإلغاء متجهاته بنجاح."}, status=status.HTTP_204_NO_CONTENT)


class MaterialRetryView(APIView):
    permission_classes = [IsOwner]

    def post(self, request, pk):
        doc = get_object_or_404(MaterialDocument, pk=pk)
        doc.processing_status = MaterialDocument.ProcessingStatus.PROCESSING
        doc.processing_error = ""
        doc.save(update_fields=["processing_status", "processing_error"])

        AuditLog.objects.create(
            user=request.user,
            action="RETRY_PROCESS",
            details={"document_id": doc.id, "title": doc.title},
            ip_address=get_client_ip(request),
        )

        trigger_document_processing(doc.id, async_process=True)
        return Response(
            {"message": "تم بدء إعادة معالجة الملف في الخلفية.", "status": "PROCESSING"},
            status=status.HTTP_200_OK,
        )


class MaterialReplaceView(APIView):
    parser_classes = [MultiPartParser, FormParser]
    permission_classes = [IsOwner]

    def post(self, request, pk):
        doc = get_object_or_404(MaterialDocument, pk=pk)
        new_file = request.FILES.get("file")
        if not new_file:
            return Response({"detail": "يرجى إرفاق الملف البديل."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            updated_doc = replace_document_file(doc, new_file, uploader_user=request.user)
            return Response(
                {
                    "message": "تم استبدال الملف وبدء المعالجة الجديدة بنجاح.",
                    "document": MaterialDocumentSerializer(updated_doc, context={"request": request}).data,
                },
                status=status.HTTP_200_OK,
            )
        except FileValidationError as err:
            return Response({"detail": str(err)}, status=status.HTTP_400_BAD_REQUEST)


class MaterialDownloadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        doc = get_object_or_404(MaterialDocument, pk=pk)
        if request.user.role == User.Role.STUDENT:
            if request.user.academic_year and doc.academic_year.year_number != request.user.academic_year:
                return Response({"detail": "غير مصرح لك بتحميل هذا الملف."}, status=status.HTTP_403_FORBIDDEN)

        if not doc.file or not os.path.exists(doc.file.path):
            raise Http404("الملف غير متوفر على الخادم.")

        response = FileResponse(open(doc.file.path, "rb"), as_attachment=True, filename=doc.original_filename)
        return response


# ─────────────────────────────────────────────────────────────
# OWNER DASHBOARD STATS & AUDIT LOGS
# ─────────────────────────────────────────────────────────────

class OwnerAcademicDashboardView(APIView):
    permission_classes = [IsOwner]

    def get(self, request):
        students = User.objects.filter(role=User.Role.STUDENT)
        materials = MaterialDocument.objects.filter(is_active=True)

        stats = {
            "total_academic_years": AcademicYear.objects.count(),
            "total_subjects": Subject.objects.count(),
            "total_lectures": Lecture.objects.count(),
            "total_materials": materials.count(),
            "ready_materials": materials.filter(processing_status=MaterialDocument.ProcessingStatus.READY).count(),
            "processing_materials": materials.filter(processing_status=MaterialDocument.ProcessingStatus.PROCESSING).count(),
            "failed_materials": materials.filter(processing_status=MaterialDocument.ProcessingStatus.FAILED).count(),
            "uploaded_materials": materials.filter(processing_status=MaterialDocument.ProcessingStatus.UPLOADED).count(),
            "total_students": students.count(),
            "active_students": students.filter(is_active=True).count(),
            "total_questions": GeneratedQuizQuestion.objects.count(),
            "total_flashcards": Flashcard.objects.count(),
        }

        recent_uploads = MaterialDocument.objects.select_related("subject", "academic_year").order_by("-uploaded_at")[:8]
        failed_files = MaterialDocument.objects.filter(
            processing_status=MaterialDocument.ProcessingStatus.FAILED
        ).select_related("subject", "academic_year")[:8]
        processing_queue = MaterialDocument.objects.filter(
            processing_status__in=[MaterialDocument.ProcessingStatus.PROCESSING, MaterialDocument.ProcessingStatus.UPLOADED]
        ).select_related("subject", "academic_year")[:8]

        audit_logs = AuditLog.objects.select_related("user").order_by("-created_at")[:10]

        return Response({
            "metrics": stats,
            "recent_uploads": MaterialDocumentSerializer(recent_uploads, many=True, context={"request": request}).data,
            "failed_files": MaterialDocumentSerializer(failed_files, many=True, context={"request": request}).data,
            "processing_queue": MaterialDocumentSerializer(processing_queue, many=True, context={"request": request}).data,
            "recent_logs": AuditLogSerializer(audit_logs, many=True).data,
        })


class AuditLogListView(APIView):
    permission_classes = [IsOwner]

    def get(self, request):
        logs = AuditLog.objects.select_related("user").order_by("-created_at")[:100]
        return Response(AuditLogSerializer(logs, many=True).data)


# ─────────────────────────────────────────────────────────────
# STUDENT HIERARCHY EXPERIENCE
# ─────────────────────────────────────────────────────────────

class StudentAcademicHierarchyView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        year_num = request.user.academic_year or 1
        year_obj = AcademicYear.objects.filter(year_number=year_num).first()
        if not year_obj:
            return Response({"year": None, "subjects": []})

        subjects = Subject.objects.filter(academic_year=year_obj, is_active=True).prefetch_related(
            "lectures", "lectures__materials"
        ).order_by("order", "name")

        result_subjects = []
        for s in subjects:
            lectures_data = []
            for lec in s.lectures.filter(is_active=True).order_by("order", "lecture_number"):
                ready_materials = lec.materials.filter(
                    is_active=True,
                    processing_status=MaterialDocument.ProcessingStatus.READY,
                )
                lectures_data.append({
                    "id": lec.id,
                    "lecture_number": lec.lecture_number,
                    "title": lec.title,
                    "description": lec.description,
                    "material_count": ready_materials.count(),
                    "materials": [
                        {
                            "id": m.id,
                            "title": m.title,
                            "file_type": m.file_type,
                            "file_size": m.file_size,
                            "page_count": m.page_count,
                            "download_url": f"/api/academic/materials/{m.id}/download/",
                        }
                        for m in ready_materials
                    ],
                })

            result_subjects.append({
                "id": s.id,
                "name": s.name,
                "code": s.code,
                "description": s.description,
                "lectures": lectures_data,
            })

        return Response({
            "academic_year": {
                "id": year_obj.id,
                "year_number": year_obj.year_number,
                "name": year_obj.name,
            },
            "subjects": result_subjects,
        })


# ─────────────────────────────────────────────────────────────
# ACADEMIC AI VIEWS (CHAT, QUIZ, FLASHCARDS)
# ─────────────────────────────────────────────────────────────

class AcademicAIChatEndpoint(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        message = (request.data.get("message") or "").strip()
        subject = (request.data.get("subject") or "").strip()
        lecture = request.data.get("lecture")
        doc_id = request.data.get("document_id")

        if not message:
            return Response({"detail": "الرسالة لا يمكن أن تكون فارغة."}, status=status.HTTP_400_BAD_REQUEST)
        if not subject:
            return Response({"detail": "يرجى تحديد المادة الدراسية."}, status=status.HTTP_400_BAD_REQUEST)

        lecture_num = None
        if lecture not in (None, ""):
            try:
                lecture_num = int(lecture)
            except (ValueError, TypeError):
                pass

        try:
            res = ask_academic_question(
                user=request.user,
                subject=subject,
                question=message,
                lecture_number=lecture_num,
                document_id=doc_id,
            )
            return Response(res, status=status.HTTP_200_OK)
        except AcademicAIScopeError as err:
            return Response({"detail": str(err)}, status=status.HTTP_403_FORBIDDEN)
        except GeminiServiceError as err:
            return Response({"detail": str(err)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Exception as err:
            return Response({"detail": f"حدث خطأ أثناء معالجة السؤال: {str(err)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AcademicAIQuizEndpoint(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        subject = (request.data.get("subject") or "").strip()
        lecture = request.data.get("lecture")
        doc_id = request.data.get("document_id")
        topic = request.data.get("topic", "").strip()
        difficulty = request.data.get("difficulty", "medium")
        question_type = request.data.get("question_type", "mcq")
        count = int(request.data.get("count", 5))

        if not subject:
            return Response({"detail": "يرجى اختيار المادة الدراسية."}, status=status.HTTP_400_BAD_REQUEST)

        lecture_num = None
        if lecture not in (None, ""):
            try:
                lecture_num = int(lecture)
            except (ValueError, TypeError):
                pass

        try:
            res = generate_academic_quiz(
                user=request.user,
                subject=subject,
                lecture_number=lecture_num,
                document_id=doc_id,
                topic=topic,
                difficulty=difficulty,
                question_type=question_type,
                count=count,
            )
            return Response(res, status=status.HTTP_200_OK)
        except AcademicAIScopeError as err:
            return Response({"detail": str(err)}, status=status.HTTP_403_FORBIDDEN)
        except GeminiServiceError as err:
            return Response({"detail": str(err)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Exception as err:
            return Response({"detail": f"تعذر إنشاء الاختبار: {str(err)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AcademicAIFlashcardEndpoint(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        subject = (request.data.get("subject") or "").strip()
        lecture = request.data.get("lecture")
        doc_id = request.data.get("document_id")
        topic = request.data.get("topic", "").strip()
        count = int(request.data.get("count", 5))

        if not subject:
            return Response({"detail": "يرجى اختيار المادة الدراسية."}, status=status.HTTP_400_BAD_REQUEST)

        lecture_num = None
        if lecture not in (None, ""):
            try:
                lecture_num = int(lecture)
            except (ValueError, TypeError):
                pass

        try:
            res = generate_academic_flashcards(
                user=request.user,
                subject=subject,
                lecture_number=lecture_num,
                document_id=doc_id,
                topic=topic,
                count=count,
            )
            return Response(res, status=status.HTTP_200_OK)
        except AcademicAIScopeError as err:
            return Response({"detail": str(err)}, status=status.HTTP_403_FORBIDDEN)
        except GeminiServiceError as err:
            return Response({"detail": str(err)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Exception as err:
            return Response({"detail": f"تعذر إنشاء البطاقات: {str(err)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class FlashcardListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        qs = Flashcard.objects.filter(user=request.user)
        subject_param = request.query_params.get("subject")
        if subject_param:
            qs = qs.filter(subject__name=subject_param)
        qs = qs.order_by("-created_at")
        serializer = FlashcardSerializer(qs, many=True)
        return Response(serializer.data)

