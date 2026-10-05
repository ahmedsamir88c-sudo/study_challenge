from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.conf import settings
from django.db import models


class LectureContent(models.Model):
    SUBJECT_LECTURE_COUNTS = {
        "Digital Logic Design": 6,
        "Machine Learning": 6,
        "Computer Networks": 9,
        "Modeling and Simulation": 6,
        "Computer Architecture": 6,
        "Data Structure and Algorithms": 4,
    }
    SUBJECT_CHOICES = [(subject, subject) for subject in SUBJECT_LECTURE_COUNTS]

    subject = models.CharField(max_length=100, choices=SUBJECT_CHOICES)
    lecture_number = models.PositiveSmallIntegerField()
    content = models.TextField(blank=True)
    file = models.FileField(upload_to="lectures/", blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("subject", "lecture_number"),
                name="unique_subject_lecture_content",
            ),
        ]

    def __str__(self):
        return f"{self.subject} - Lecture {self.lecture_number}"


class UserManager(BaseUserManager):
    def create_user(self, username, password=None, **extra_fields):
        if not username:
            raise ValueError("Username is required.")

        username = username.strip()
        user = self.model(username=username, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, username, password=None, **extra_fields):
        extra_fields.setdefault("role", User.Role.ADMIN)
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        if extra_fields.get("role") not in {User.Role.ADMIN, User.Role.OWNER}:
            raise ValueError("Superuser must have admin or owner role.")
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self.create_user(username, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        STUDENT = "student", "Student"
        TEACHER = "teacher", "Teacher"
        ADMIN = "admin", "Admin"
        OWNER = "owner", "Owner"

    class AcademicYear(models.IntegerChoices):
        YEAR_1 = 1, "الفرقة الأولى"
        YEAR_2 = 2, "الفرقة الثانية"
        YEAR_3 = 3, "الفرقة الثالثة"
        YEAR_4 = 4, "الفرقة الرابعة"

    username = models.CharField(max_length=50, unique=True, db_index=True)
    university_id = models.CharField(max_length=50, unique=True, null=True, blank=True, db_index=True)
    full_name = models.CharField(max_length=150, blank=True)
    email = models.EmailField(blank=True, null=True, unique=True)

    # صورة البروفايل — URLField للصور المحفوظة على أي خادم خارجي / CDN
    profile_picture = models.URLField(max_length=500, blank=True, null=True)

    # الحقل القديم للتوافق مع الشيفرة الموجودة
    profile_image = models.ImageField(upload_to="profiles/", blank=True, null=True)

    academic_year = models.PositiveSmallIntegerField(
        choices=AcademicYear.choices,
        blank=True,
        null=True,
        db_index=True,
    )
    department = models.CharField(max_length=150, blank=True)

    # نقاط الخبرة — xp_points هو الحقل الرئيسي، xp للتوافق مع الـ views الحالية
    xp_points = models.PositiveIntegerField(default=0, db_index=True)
    xp = models.PositiveIntegerField(default=0, db_index=True)

    streak = models.PositiveIntegerField(default=0)
    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.STUDENT,
        db_index=True,
    )
    class StudentStatus(models.TextChoices):
        PENDING    = "pending",    "Pending"
        APPROVED   = "approved",   "Approved"
        REJECTED   = "rejected",   "Rejected"
        SUSPENDED  = "suspended",  "Suspended"
        ACTIVE     = "active",     "Active"
        INACTIVE   = "inactive",   "Inactive"

    student_status = models.CharField(
        max_length=20,
        choices=StudentStatus.choices,
        default=StudentStatus.PENDING,
        db_index=True,
    )
    last_activity = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "username"
    REQUIRED_FIELDS = ["full_name"]

    class Meta:
        ordering = ["-xp_points", "-created_at"]

    def __str__(self):
        return f"{self.username} ({self.role})"

    def add_xp(self, points: int):
        """إضافة نقاط XP للمستخدم وتحديث الحقلين معاً"""
        self.xp_points = models.F("xp_points") + points
        self.xp = models.F("xp") + points
        self.save(update_fields=["xp_points", "xp", "updated_at"])
        self.refresh_from_db()


class AcademicYear(models.Model):
    year_number = models.PositiveSmallIntegerField(unique=True)
    name = models.CharField(max_length=100)
    order = models.PositiveSmallIntegerField(default=1)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "year_number"]

    def __str__(self):
        return f"{self.name} (Year {self.year_number})"


class Subject(models.Model):
    academic_year = models.ForeignKey(
        AcademicYear,
        on_delete=models.CASCADE,
        related_name="subjects",
    )
    name = models.CharField(max_length=150)
    code = models.CharField(max_length=50, blank=True)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=100, blank=True)
    order = models.PositiveSmallIntegerField(default=1)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "name"]
        constraints = [
            models.UniqueConstraint(
                fields=("academic_year", "name"),
                name="unique_year_subject_name",
            ),
        ]

    def __str__(self):
        return f"{self.name} - {self.academic_year.name}"


class Lecture(models.Model):
    subject = models.ForeignKey(
        Subject,
        on_delete=models.CASCADE,
        related_name="lectures",
    )
    title = models.CharField(max_length=200)
    lecture_number = models.PositiveSmallIntegerField()
    description = models.TextField(blank=True)
    order = models.PositiveSmallIntegerField(default=1)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "lecture_number"]
        constraints = [
            models.UniqueConstraint(
                fields=("subject", "lecture_number"),
                name="unique_subject_lecture_number",
            ),
        ]

    def __str__(self):
        return f"{self.subject.name} - Lecture {self.lecture_number}: {self.title}"


class MaterialDocument(models.Model):
    class ProcessingStatus(models.TextChoices):
        UPLOADED = "UPLOADED", "Uploaded"
        PROCESSING = "PROCESSING", "Processing"
        READY = "READY", "Ready"
        FAILED = "FAILED", "Failed"

    academic_year = models.ForeignKey(
        AcademicYear,
        on_delete=models.CASCADE,
        related_name="materials",
    )
    subject = models.ForeignKey(
        Subject,
        on_delete=models.CASCADE,
        related_name="materials",
    )
    lecture = models.ForeignKey(
        Lecture,
        on_delete=models.CASCADE,
        related_name="materials",
        null=True,
        blank=True,
    )
    title = models.CharField(max_length=255)
    original_filename = models.CharField(max_length=255)
    file = models.FileField(upload_to="academic_materials/%Y/%m/")
    file_type = models.CharField(max_length=20)  # pdf, docx, pptx, txt
    file_size = models.PositiveIntegerField(default=0)
    page_count = models.PositiveIntegerField(default=0)
    mime_type = models.CharField(max_length=100, blank=True)
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="uploaded_materials",
    )
    uploaded_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    processing_status = models.CharField(
        max_length=20,
        choices=ProcessingStatus.choices,
        default=ProcessingStatus.UPLOADED,
        db_index=True,
    )
    processing_error = models.TextField(blank=True)
    processing_started_at = models.DateTimeField(null=True, blank=True)
    processing_completed_at = models.DateTimeField(null=True, blank=True)
    version = models.PositiveIntegerField(default=1)
    is_active = models.BooleanField(default=True, db_index=True)

    class Meta:
        ordering = ["-uploaded_at"]
        indexes = [
            models.Index(fields=("academic_year", "subject", "lecture")),
            models.Index(fields=("processing_status", "is_active")),
        ]

    def __str__(self):
        return f"{self.title} ({self.processing_status})"


class GeneratedQuizQuestion(models.Model):
    subject = models.CharField(max_length=100)
    lecture_number = models.PositiveSmallIntegerField()
    difficulty = models.CharField(max_length=10)
    question = models.TextField()
    options = models.JSONField(default=list)
    correct_index = models.PositiveSmallIntegerField()
    explanation = models.TextField()
    fingerprint = models.CharField(max_length=64, unique=True)
    question_type = models.CharField(
        max_length=20,
        default="mcq",
        choices=[("mcq", "MCQ"), ("essay", "Essay")],
    )
    expected_answer = models.TextField(blank=True)
    grading_criteria = models.TextField(blank=True)
    topic = models.CharField(max_length=200, blank=True)
    source_title = models.CharField(max_length=255, blank=True)
    page_number = models.PositiveSmallIntegerField(null=True, blank=True)
    lecture_fk = models.ForeignKey(
        Lecture,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="questions",
    )
    document = models.ForeignKey(
        MaterialDocument,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="questions",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(
                fields=("subject", "lecture_number", "difficulty"),
                name="quiz_question_topic_idx",
            ),
        ]


class QuizQuestionUsage(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="quiz_question_usages",
    )
    question = models.ForeignKey(
        GeneratedQuizQuestion,
        on_delete=models.CASCADE,
        related_name="usage_records",
    )
    used_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("user", "question"),
                name="unique_user_quiz_question_usage",
            ),
        ]


class DocumentChunk(models.Model):
    document = models.ForeignKey(
        MaterialDocument,
        on_delete=models.CASCADE,
        related_name="chunks",
        null=True,
        blank=True,
    )
    lecture = models.ForeignKey(
        LectureContent,
        on_delete=models.CASCADE,
        related_name="document_chunks",
        null=True,
        blank=True,
    )
    academic_year = models.PositiveSmallIntegerField(
        choices=User.AcademicYear.choices,
        null=True,
        blank=True,
    )
    chunk_index = models.PositiveIntegerField()
    page_number = models.PositiveSmallIntegerField(null=True, blank=True)
    section_title = models.CharField(max_length=255, blank=True)
    token_count = models.PositiveIntegerField(default=0)
    text = models.TextField()
    embedding = models.JSONField(default=list)
    embedding_model = models.CharField(max_length=100, blank=True)
    source_hash = models.CharField(max_length=64, blank=True)
    is_active = models.BooleanField(default=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True)
    indexed_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(
                fields=("academic_year", "lecture"),
                name="doc_chunk_year_lecture_idx",
            ),
            models.Index(
                fields=("document", "is_active"),
                name="doc_chunk_doc_active_idx",
            ),
        ]


class Flashcard(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="flashcards",
    )
    academic_year = models.ForeignKey(
        AcademicYear,
        on_delete=models.CASCADE,
        related_name="flashcards",
        null=True,
        blank=True,
    )
    subject = models.ForeignKey(
        Subject,
        on_delete=models.CASCADE,
        related_name="flashcards",
        null=True,
        blank=True,
    )
    lecture = models.ForeignKey(
        Lecture,
        on_delete=models.CASCADE,
        related_name="flashcards",
        null=True,
        blank=True,
    )
    document = models.ForeignKey(
        MaterialDocument,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="flashcards",
    )
    question = models.TextField()
    answer = models.TextField()
    topic = models.CharField(max_length=200, blank=True)
    source_title = models.CharField(max_length=255, blank=True)
    page_number = models.PositiveSmallIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]


class AISummary(models.Model):
    class SummaryType(models.TextChoices):
        QUICK = "quick", "Quick summary"
        DETAILED = "detailed", "Detailed summary"
        EXAM = "exam", "Exam summary"
        KEY_POINTS = "key_points", "Key points"
        DEFINITIONS = "definitions", "Definitions"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="ai_summaries",
    )
    lecture = models.ForeignKey(
        LectureContent,
        on_delete=models.CASCADE,
        related_name="ai_summaries",
        null=True,
        blank=True,
    )
    material_document = models.ForeignKey(
        MaterialDocument,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ai_summaries",
    )
    academic_year = models.PositiveSmallIntegerField(
        choices=User.AcademicYear.choices,
    )
    summary_type = models.CharField(max_length=16, choices=SummaryType.choices)
    content = models.TextField()
    sources = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(
                fields=("user", "lecture", "created_at"),
                name="ai_summary_user_lecture_idx",
            ),
        ]


class AuditLog(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_logs",
    )
    action = models.CharField(max_length=100, db_index=True)
    details = models.JSONField(default=dict)
    ip_address = models.CharField(max_length=45, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        user_str = self.user.username if self.user else "Anonymous"
        return f"[{self.created_at}] {user_str} - {self.action}"


# ─────────────────────────────────────────────────────────────
# BOOKING SYSTEM
# ─────────────────────────────────────────────────────────────

class BookingSlot(models.Model):
    class BookingType(models.TextChoices):
        ACADEMIC_CONSULTATION = "academic_consultation", "استشارة أكاديمية"
        STUDENT_MEETING       = "student_meeting",       "اجتماع طلابي"
        EXAM_ASSESSMENT       = "exam_assessment",       "امتحان / تقييم"
        COURSE_SESSION        = "course_session",        "جلسة دراسية"
        REVISION_SESSION      = "revision_session",      "مراجعة"
        SUPPORT_SESSION       = "support_session",       "جلسة دعم"
        OTHER                 = "other",                 "أخرى"

    class SlotStatus(models.TextChoices):
        AVAILABLE  = "available",  "متاح"
        PENDING    = "pending",    "قيد الانتظار"
        CONFIRMED  = "confirmed",  "مؤكد"
        FULL       = "full",       "مكتمل"
        CANCELLED  = "cancelled",  "ملغي"
        COMPLETED  = "completed",  "منتهي"

    created_by      = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_slots",
    )
    title           = models.CharField(max_length=200)
    description     = models.TextField(blank=True)
    booking_type    = models.CharField(
        max_length=30,
        choices=BookingType.choices,
        default=BookingType.OTHER,
        db_index=True,
    )
    date            = models.DateField(db_index=True)
    start_time      = models.TimeField()
    end_time        = models.TimeField()
    max_capacity    = models.PositiveSmallIntegerField(default=1)
    location        = models.CharField(max_length=300, blank=True)
    meeting_link    = models.URLField(max_length=500, blank=True)
    notes           = models.TextField(blank=True)
    status          = models.CharField(
        max_length=20,
        choices=SlotStatus.choices,
        default=SlotStatus.AVAILABLE,
        db_index=True,
    )
    allow_waitlist  = models.BooleanField(default=False)
    is_active       = models.BooleanField(default=True, db_index=True)
    created_at      = models.DateTimeField(auto_now_add=True)
    updated_at      = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["date", "start_time"]
        indexes = [
            models.Index(fields=["date", "status"]),
            models.Index(fields=["booking_type", "status"]),
        ]

    def __str__(self):
        return f"{self.title} — {self.date} {self.start_time}"

    @property
    def confirmed_count(self):
        return self.bookings.filter(
            status__in=[StudentBooking.BookingStatus.CONFIRMED, StudentBooking.BookingStatus.PENDING]
        ).count()

    @property
    def available_seats(self):
        return max(0, self.max_capacity - self.confirmed_count)

    @property
    def is_full(self):
        return self.confirmed_count >= self.max_capacity


class StudentBooking(models.Model):
    class BookingStatus(models.TextChoices):
        PENDING    = "pending",    "قيد الانتظار"
        CONFIRMED  = "confirmed",  "مؤكد"
        CANCELLED  = "cancelled",  "ملغي"
        COMPLETED  = "completed",  "منتهي"
        REJECTED   = "rejected",   "مرفوض"

    booking_ref     = models.CharField(max_length=20, unique=True, db_index=True)
    slot            = models.ForeignKey(
        BookingSlot,
        on_delete=models.CASCADE,
        related_name="bookings",
    )
    student         = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="student_bookings",
    )
    status          = models.CharField(
        max_length=20,
        choices=BookingStatus.choices,
        default=BookingStatus.PENDING,
        db_index=True,
    )
    notes           = models.TextField(blank=True)
    owner_notes     = models.TextField(blank=True)
    booked_at       = models.DateTimeField(auto_now_add=True)
    updated_at      = models.DateTimeField(auto_now=True)
    cancelled_at    = models.DateTimeField(null=True, blank=True)
    confirmed_at    = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-booked_at"]
        constraints = [
            models.UniqueConstraint(
                fields=("slot", "student"),
                name="unique_slot_student_booking",
            ),
        ]
        indexes = [
            models.Index(fields=["student", "status"]),
            models.Index(fields=["slot", "status"]),
        ]

    def __str__(self):
        return f"{self.booking_ref} — {self.student.username} @ {self.slot.title}"

    def save(self, *args, **kwargs):
        if not self.booking_ref:
            import datetime as dt
            year = dt.date.today().year
            last = StudentBooking.objects.filter(
                booking_ref__startswith=f"BK-{year}-"
            ).order_by("-id").first()
            if last:
                try:
                    seq = int(last.booking_ref.split("-")[-1]) + 1
                except (ValueError, IndexError):
                    seq = 1
            else:
                seq = 1
            self.booking_ref = f"BK-{year}-{seq:06d}"
        super().save(*args, **kwargs)


class WaitlistEntry(models.Model):
    slot        = models.ForeignKey(
        BookingSlot,
        on_delete=models.CASCADE,
        related_name="waitlist",
    )
    student     = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="waitlist_entries",
    )
    position    = models.PositiveSmallIntegerField(default=1)
    notified    = models.BooleanField(default=False)
    joined_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["position", "joined_at"]
        constraints = [
            models.UniqueConstraint(
                fields=("slot", "student"),
                name="unique_slot_student_waitlist",
            ),
        ]

    def __str__(self):
        return f"Waitlist #{self.position} — {self.student.username} @ {self.slot.title}"


# ─────────────────────────────────────────────────────────────
# NOTIFICATION SYSTEM
# ─────────────────────────────────────────────────────────────

class Notification(models.Model):
    class NotificationType(models.TextChoices):
        BOOKING_CREATED     = "booking_created",     "حجز جديد"
        BOOKING_CONFIRMED   = "booking_confirmed",   "تأكيد الحجز"
        BOOKING_REJECTED    = "booking_rejected",    "رفض الحجز"
        BOOKING_CANCELLED   = "booking_cancelled",   "إلغاء الحجز"
        BOOKING_RESCHEDULED = "booking_rescheduled", "تغيير موعد الحجز"
        BOOKING_REMINDER    = "booking_reminder",    "تذكير بالحجز"
        BOOKING_COMPLETED   = "booking_completed",   "انتهاء الحجز"
        SEAT_AVAILABLE      = "seat_available",      "مقعد متاح"
        STUDENT_APPROVED    = "student_approved",    "قبول الطالب"
        STUDENT_REJECTED    = "student_rejected",    "رفض الطالب"
        MATERIAL_READY      = "material_ready",      "مادة جاهزة"
        GENERAL             = "general",             "عام"

    recipient           = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    sender              = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="sent_notifications",
    )
    notification_type   = models.CharField(
        max_length=30,
        choices=NotificationType.choices,
        default=NotificationType.GENERAL,
        db_index=True,
    )
    title       = models.CharField(max_length=200)
    body        = models.TextField()
    data        = models.JSONField(default=dict)
    is_read     = models.BooleanField(default=False, db_index=True)
    created_at  = models.DateTimeField(auto_now_add=True, db_index=True)
    read_at     = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["recipient", "is_read"]),
        ]

    def __str__(self):
        return f"[{self.notification_type}] → {self.recipient.username}: {self.title}"
