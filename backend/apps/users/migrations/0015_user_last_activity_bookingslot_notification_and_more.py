import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0014_user_student_status"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="last_activity",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.CreateModel(
            name="BookingSlot",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=200)),
                ("description", models.TextField(blank=True)),
                ("booking_type", models.CharField(choices=[("academic_consultation", "استشارة أكاديمية"), ("student_meeting", "اجتماع طلابي"), ("exam_assessment", "امتحان / تقييم"), ("course_session", "جلسة دراسية"), ("revision_session", "مراجعة"), ("support_session", "جلسة دعم"), ("other", "أخرى")], db_index=True, default="other", max_length=30)),
                ("date", models.DateField(db_index=True)),
                ("start_time", models.TimeField()),
                ("end_time", models.TimeField()),
                ("max_capacity", models.PositiveSmallIntegerField(default=1)),
                ("location", models.CharField(blank=True, max_length=300)),
                ("meeting_link", models.URLField(blank=True, max_length=500)),
                ("notes", models.TextField(blank=True)),
                ("status", models.CharField(choices=[("available", "متاح"), ("pending", "قيد الانتظار"), ("confirmed", "مؤكد"), ("full", "مكتمل"), ("cancelled", "ملغي"), ("completed", "منتهي")], db_index=True, default="available", max_length=20)),
                ("allow_waitlist", models.BooleanField(default=False)),
                ("is_active", models.BooleanField(db_index=True, default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("created_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="created_slots", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["date", "start_time"],
                "indexes": [
                    models.Index(fields=["date", "status"], name="users_booki_date_6bdc00_idx"),
                    models.Index(fields=["booking_type", "status"], name="users_booki_booking_003e3a_idx"),
                ],
            },
        ),
        migrations.CreateModel(
            name="Notification",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("notification_type", models.CharField(choices=[("booking_created", "حجز جديد"), ("booking_confirmed", "تأكيد الحجز"), ("booking_rejected", "رفض الحجز"), ("booking_cancelled", "إلغاء الحجز"), ("booking_rescheduled", "تغيير موعد الحجز"), ("booking_reminder", "تذكير بالحجز"), ("booking_completed", "انتهاء الحجز"), ("seat_available", "مقعد متاح"), ("student_approved", "قبول الطالب"), ("student_rejected", "رفض الطالب"), ("material_ready", "مادة جاهزة"), ("general", "عام")], db_index=True, default="general", max_length=30)),
                ("title", models.CharField(max_length=200)),
                ("body", models.TextField()),
                ("data", models.JSONField(default=dict)),
                ("is_read", models.BooleanField(db_index=True, default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("read_at", models.DateTimeField(blank=True, null=True)),
                ("recipient", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="notifications", to=settings.AUTH_USER_MODEL)),
                ("sender", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="sent_notifications", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-created_at"],
                "indexes": [
                    models.Index(fields=["recipient", "is_read"], name="users_notif_recipie_2469dd_idx"),
                ],
            },
        ),
        migrations.CreateModel(
            name="StudentBooking",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("booking_ref", models.CharField(db_index=True, max_length=20, unique=True)),
                ("status", models.CharField(choices=[("pending", "قيد الانتظار"), ("confirmed", "مؤكد"), ("cancelled", "ملغي"), ("completed", "منتهي"), ("rejected", "مرفوض")], db_index=True, default="pending", max_length=20)),
                ("notes", models.TextField(blank=True)),
                ("owner_notes", models.TextField(blank=True)),
                ("booked_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("cancelled_at", models.DateTimeField(blank=True, null=True)),
                ("confirmed_at", models.DateTimeField(blank=True, null=True)),
                ("slot", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="bookings", to="users.bookingslot")),
                ("student", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="student_bookings", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-booked_at"],
                "indexes": [
                    models.Index(fields=["student", "status"], name="users_stude_student_110958_idx"),
                    models.Index(fields=["slot", "status"], name="users_stude_slot_id_5f58f2_idx"),
                ],
                "constraints": [
                    models.UniqueConstraint(fields=("slot", "student"), name="unique_slot_student_booking"),
                ],
            },
        ),
        migrations.CreateModel(
            name="WaitlistEntry",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("position", models.PositiveSmallIntegerField(default=1)),
                ("notified", models.BooleanField(default=False)),
                ("joined_at", models.DateTimeField(auto_now_add=True)),
                ("slot", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="waitlist", to="users.bookingslot")),
                ("student", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="waitlist_entries", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["position", "joined_at"],
                "constraints": [
                    models.UniqueConstraint(fields=("slot", "student"), name="unique_slot_student_waitlist"),
                ],
            },
        ),
    ]
