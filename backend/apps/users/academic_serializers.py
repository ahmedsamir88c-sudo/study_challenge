from rest_framework import serializers

from .models import (
    AcademicYear,
    AuditLog,
    DocumentChunk,
    Flashcard,
    GeneratedQuizQuestion,
    Lecture,
    MaterialDocument,
    Subject,
)


class AcademicYearSerializer(serializers.ModelSerializer):
    subject_count = serializers.SerializerMethodField()
    document_count = serializers.SerializerMethodField()

    class Meta:
        model = AcademicYear
        fields = [
            "id",
            "year_number",
            "name",
            "order",
            "is_active",
            "subject_count",
            "document_count",
            "created_at",
            "updated_at",
        ]

    def get_subject_count(self, obj):
        return obj.subjects.count()

    def get_document_count(self, obj):
        return obj.materials.filter(is_active=True).count()


class SubjectSerializer(serializers.ModelSerializer):
    academic_year_name = serializers.CharField(source="academic_year.name", read_only=True)
    academic_year_number = serializers.IntegerField(source="academic_year.year_number", read_only=True)
    lecture_count = serializers.SerializerMethodField()
    document_count = serializers.SerializerMethodField()
    question_count = serializers.SerializerMethodField()

    class Meta:
        model = Subject
        fields = [
            "id",
            "academic_year",
            "academic_year_name",
            "academic_year_number",
            "name",
            "code",
            "description",
            "icon",
            "order",
            "is_active",
            "lecture_count",
            "document_count",
            "question_count",
            "created_at",
            "updated_at",
        ]

    def get_lecture_count(self, obj):
        return obj.lectures.count()

    def get_document_count(self, obj):
        return obj.materials.filter(is_active=True).count()

    def get_question_count(self, obj):
        return GeneratedQuizQuestion.objects.filter(subject=obj.name).count()


class LectureSerializer(serializers.ModelSerializer):
    subject_name = serializers.CharField(source="subject.name", read_only=True)
    material_count = serializers.SerializerMethodField()

    class Meta:
        model = Lecture
        fields = [
            "id",
            "subject",
            "subject_name",
            "title",
            "lecture_number",
            "description",
            "order",
            "is_active",
            "material_count",
            "created_at",
            "updated_at",
        ]

    def get_material_count(self, obj):
        return obj.materials.filter(is_active=True).count()


class MaterialDocumentSerializer(serializers.ModelSerializer):
    academic_year_name = serializers.CharField(source="academic_year.name", read_only=True)
    academic_year_number = serializers.IntegerField(source="academic_year.year_number", read_only=True)
    subject_name = serializers.CharField(source="subject.name", read_only=True)
    lecture_title = serializers.CharField(source="lecture.title", read_only=True)
    lecture_number = serializers.IntegerField(source="lecture.lecture_number", read_only=True)
    uploader_name = serializers.CharField(source="uploaded_by.username", read_only=True)
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = MaterialDocument
        fields = [
            "id",
            "academic_year",
            "academic_year_name",
            "academic_year_number",
            "subject",
            "subject_name",
            "lecture",
            "lecture_title",
            "lecture_number",
            "title",
            "original_filename",
            "file",
            "file_url",
            "file_type",
            "file_size",
            "page_count",
            "mime_type",
            "uploaded_by",
            "uploader_name",
            "uploaded_at",
            "updated_at",
            "processing_status",
            "processing_error",
            "processing_started_at",
            "processing_completed_at",
            "version",
            "is_active",
        ]
        read_only_fields = [
            "id",
            "original_filename",
            "file_type",
            "file_size",
            "page_count",
            "mime_type",
            "uploaded_by",
            "uploaded_at",
            "updated_at",
            "processing_status",
            "processing_error",
            "processing_started_at",
            "processing_completed_at",
            "version",
        ]

    def get_file_url(self, obj):
        if not obj.file:
            return ""
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.file.url)
        return obj.file.url


class AuditLogSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)
    university_id = serializers.CharField(source="user.university_id", read_only=True)

    class Meta:
        model = AuditLog
        fields = [
            "id",
            "user",
            "username",
            "university_id",
            "action",
            "details",
            "ip_address",
            "created_at",
        ]


class FlashcardSerializer(serializers.ModelSerializer):
    subject_name = serializers.CharField(source="subject.name", read_only=True)
    lecture_number = serializers.IntegerField(source="lecture.lecture_number", read_only=True)

    class Meta:
        model = Flashcard
        fields = [
            "id",
            "academic_year",
            "subject",
            "subject_name",
            "lecture",
            "lecture_number",
            "document",
            "question",
            "answer",
            "topic",
            "source_title",
            "page_number",
            "created_at",
        ]

