from datetime import date, timedelta

from django.db import IntegrityError, transaction
from django.db.models import Count, F, Sum
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    DailyChallenge,
    Notification,
    QuizAttempt,
    QuizAttemptAnswer,
    StudentPreference,
    StudyPlan,
    Subject,
    User,
)


def _plan_data(plan):
    return {
        "id": plan.id,
        "title": plan.title,
        "subject": plan.subject_id,
        "subject_name": plan.subject.name if plan.subject else "",
        "target_minutes_per_day": plan.target_minutes_per_day,
        "sessions_per_week": plan.sessions_per_week,
        "start_date": plan.start_date.isoformat(),
        "end_date": plan.end_date.isoformat() if plan.end_date else None,
        "notes": plan.notes,
        "is_active": plan.is_active,
        "created_at": plan.created_at.isoformat(),
        "updated_at": plan.updated_at.isoformat(),
    }


class DailyChallengeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        today = timezone.localdate()
        try:
            challenge, _ = DailyChallenge.objects.get_or_create(
                user=request.user,
                challenge_date=today,
            )
        except IntegrityError:
            challenge = DailyChallenge.objects.get(
                user=request.user,
                challenge_date=today,
            )
        attempt = challenge.attempt
        payload = {
            "date": today.isoformat(),
            "goal_questions": 5,
            "bonus_xp": 0,
            "started": attempt is not None,
            "completed": challenge.completed_at is not None,
            "completed_at": (
                challenge.completed_at.isoformat()
                if challenge.completed_at
                else None
            ),
            "score": attempt.score if attempt else 0,
            "total_questions": attempt.total_questions if attempt else 0,
            "subject": attempt.subject if attempt else None,
            "lecture": attempt.lecture_number if attempt else None,
            "quiz": None,
        }
        if attempt is not None and challenge.completed_at is None:
            payload["quiz"] = {
                "quiz_id": str(attempt.attempt_id),
                "subject": attempt.subject,
                "lecture": attempt.lecture_number,
                "difficulty": attempt.difficulty,
                "count": attempt.total_questions,
                "questions": [
                    {
                        "id": answer.question_id,
                        "question": answer.question.question,
                        "options": answer.question.options,
                    }
                    for answer in attempt.answers.select_related("question")
                ],
            }
        return Response(payload)


class SmartReviewListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        answers = (
            QuizAttemptAnswer.objects.filter(
                attempt__user=request.user,
                attempt__completed_at__isnull=False,
                is_correct=False,
            )
            .select_related("attempt", "question")
            .order_by("reviewed_at", "-answered_at")[:100]
        )
        return Response(
            {
                "count": sum(answer.reviewed_at is None for answer in answers),
                "results": [
                    {
                        "id": answer.id,
                        "question": answer.question.question,
                        "options": answer.question.options,
                        "correct_index": answer.question.correct_index,
                        "explanation": answer.question.explanation,
                        "subject": answer.attempt.subject,
                        "lecture": answer.attempt.lecture_number,
                        "attempted_at": (
                            answer.answered_at.isoformat()
                            if answer.answered_at
                            else None
                        ),
                        "reviewed_at": (
                            answer.reviewed_at.isoformat()
                            if answer.reviewed_at
                            else None
                        ),
                        "review_count": answer.review_count,
                    }
                    for answer in answers
                ],
            }
        )


class SmartReviewMarkView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        answer = get_object_or_404(
            QuizAttemptAnswer,
            pk=pk,
            attempt__user=request.user,
            attempt__completed_at__isnull=False,
            is_correct=False,
        )
        answer.reviewed_at = timezone.now()
        answer.review_count = F("review_count") + 1
        answer.save(update_fields=["reviewed_at", "review_count"])
        answer.refresh_from_db(fields=["review_count"])
        return Response(
            {"id": answer.id, "reviewed": True, "review_count": answer.review_count}
        )


class StudyPlanListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        plans = StudyPlan.objects.filter(user=request.user).select_related("subject")
        return Response([_plan_data(plan) for plan in plans])

    def post(self, request):
        payload = request.data
        title = payload.get("title")
        notes = payload.get("notes", "")
        if not isinstance(title, str) or not title.strip() or len(title.strip()) > 120:
            return Response(
                {"detail": "عنوان الخطة مطلوب ويجب ألا يتجاوز 120 حرفًا."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(notes, str) or len(notes) > 500:
            return Response(
                {"detail": "ملاحظات الخطة غير صالحة أو طويلة جدًا."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        target_minutes = self._integer(payload.get("target_minutes_per_day", 30))
        sessions = self._integer(payload.get("sessions_per_week", 5))
        if target_minutes is None or not 5 <= target_minutes <= 600:
            return Response(
                {"detail": "هدف الدراسة اليومي يجب أن يكون بين 5 و600 دقيقة."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if sessions is None or not 1 <= sessions <= 7:
            return Response(
                {"detail": "عدد الجلسات الأسبوعية يجب أن يكون بين 1 و7."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            start_date = date.fromisoformat(str(payload.get("start_date")))
            end_date_raw = payload.get("end_date")
            end_date = date.fromisoformat(str(end_date_raw)) if end_date_raw else None
        except (TypeError, ValueError):
            return Response(
                {"detail": "تاريخ بداية الخطة أو نهايتها غير صالح."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if end_date and end_date < start_date:
            return Response(
                {"detail": "تاريخ انتهاء الخطة يجب أن يأتي بعد تاريخ البداية."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        subject = None
        subject_id = payload.get("subject")
        if subject_id not in (None, ""):
            try:
                subject = Subject.objects.get(
                    pk=self._integer(subject_id),
                    is_active=True,
                )
            except (Subject.DoesNotExist, ValueError, TypeError):
                return Response(
                    {"detail": "المادة المختارة غير موجودة أو غير صالحة."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if (
                request.user.role == User.Role.STUDENT
                and request.user.academic_year
                and subject.academic_year.year_number != request.user.academic_year
            ):
                return Response(
                    {"detail": "المادة المختارة لا تتبع فرقتك الدراسية."},
                    status=status.HTTP_403_FORBIDDEN,
                )

        plan = StudyPlan.objects.create(
            user=request.user,
            subject=subject,
            title=title.strip(),
            target_minutes_per_day=target_minutes,
            sessions_per_week=sessions,
            start_date=start_date,
            end_date=end_date,
            notes=notes.strip(),
        )
        return Response(_plan_data(plan), status=status.HTTP_201_CREATED)

    @staticmethod
    def _integer(value):
        if isinstance(value, bool):
            return None
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            return None
        return parsed if str(parsed) == str(value).strip() else None


class StudyPlanDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk):
        plan = get_object_or_404(
            StudyPlan.objects.select_related("subject"),
            pk=pk,
            user=request.user,
        )
        payload = request.data
        for field, minimum, maximum in (
            ("target_minutes_per_day", 5, 600),
            ("sessions_per_week", 1, 7),
        ):
            if field in payload:
                value = StudyPlanListCreateView._integer(payload[field])
                if value is None or not minimum <= value <= maximum:
                    return Response(
                        {"detail": f"قيمة {field} خارج النطاق المسموح."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                setattr(plan, field, value)

        if "title" in payload:
            title = payload["title"]
            if not isinstance(title, str) or not title.strip() or len(title.strip()) > 120:
                return Response(
                    {"detail": "عنوان الخطة غير صالح."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            plan.title = title.strip()
        if "notes" in payload:
            if not isinstance(payload["notes"], str) or len(payload["notes"]) > 500:
                return Response(
                    {"detail": "ملاحظات الخطة غير صالحة."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            plan.notes = payload["notes"].strip()
        for field in ("start_date", "end_date"):
            if field in payload:
                raw_date = payload[field]
                try:
                    parsed_date = date.fromisoformat(str(raw_date)) if raw_date else None
                except ValueError:
                    return Response(
                        {"detail": "تاريخ الخطة غير صالح."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                if field == "start_date":
                    if parsed_date is None:
                        return Response(
                            {"detail": "تاريخ بداية الخطة مطلوب."},
                            status=status.HTTP_400_BAD_REQUEST,
                        )
                    plan.start_date = parsed_date
                else:
                    plan.end_date = parsed_date
        if plan.end_date and plan.end_date < plan.start_date:
            return Response(
                {"detail": "تاريخ انتهاء الخطة يجب أن يأتي بعد تاريخ البداية."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if "subject" in payload:
            subject_id = payload["subject"]
            if subject_id in (None, ""):
                plan.subject = None
            else:
                subject_pk = StudyPlanListCreateView._integer(subject_id)
                subject = Subject.objects.filter(
                    pk=subject_pk,
                    is_active=True,
                ).first()
                if subject is None:
                    return Response(
                        {"detail": "المادة المختارة غير موجودة أو غير صالحة."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                if (
                    request.user.role == User.Role.STUDENT
                    and request.user.academic_year
                    and subject.academic_year.year_number
                    != request.user.academic_year
                ):
                    return Response(
                        {"detail": "المادة المختارة لا تتبع فرقتك الدراسية."},
                        status=status.HTTP_403_FORBIDDEN,
                    )
                plan.subject = subject
        if "is_active" in payload:
            if not isinstance(payload["is_active"], bool):
                return Response(
                    {"detail": "حالة الخطة يجب أن تكون قيمة منطقية."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            plan.is_active = payload["is_active"]
        plan.save()
        return Response(_plan_data(plan))

    def delete(self, request, pk):
        plan = get_object_or_404(StudyPlan, pk=pk, user=request.user)
        plan.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class StudyReportView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        days_raw = request.query_params.get("days", "7")
        days = StudyPlanListCreateView._integer(days_raw)
        if days not in (7, 30, 90):
            return Response(
                {"detail": "اختر نطاقًا زمنيًا قدره 7 أو 30 أو 90 يومًا."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        today = timezone.localdate()
        start_date = today - timedelta(days=days - 1)
        attempts = QuizAttempt.objects.filter(
            user=request.user,
            completed_at__date__gte=start_date,
            completed_at__date__lte=today,
        )
        summary = attempts.aggregate(
            quizzes=Count("id"),
            questions=Sum("total_questions"),
            correct=Sum("score"),
            xp=Sum("earned_xp"),
        )
        daily_rows = (
            attempts.values("completed_at__date")
            .annotate(quizzes=Count("id"), xp=Sum("earned_xp"))
            .order_by("completed_at__date")
        )
        subject_rows = (
            attempts.values("subject")
            .annotate(
                quizzes=Count("id"),
                questions=Sum("total_questions"),
                correct=Sum("score"),
                xp=Sum("earned_xp"),
            )
            .order_by("-quizzes", "subject")
        )
        lecture_rows = (
            attempts.values("subject", "lecture_number")
            .annotate(
                quizzes=Count("id"),
                questions=Sum("total_questions"),
                correct=Sum("score"),
            )
            .order_by("subject", "lecture_number")
        )
        focus_rows = (
            QuizAttemptAnswer.objects.filter(
                attempt__in=attempts,
                is_correct=False,
            )
            .values(
                "attempt__subject",
                "attempt__lecture_number",
                "question__topic",
                "question__source_title",
            )
            .annotate(incorrect=Count("id"))
            .order_by("-incorrect")[:10]
        )
        plans = list(
            StudyPlan.objects.filter(user=request.user, is_active=True)
            .select_related("subject")
        )
        return Response(
            {
                "days": days,
                "start_date": start_date.isoformat(),
                "end_date": today.isoformat(),
                "summary": {
                    "quizzes": summary["quizzes"] or 0,
                    "questions": summary["questions"] or 0,
                    "correct": summary["correct"] or 0,
                    "xp": summary["xp"] or 0,
                    "accuracy_percent": round(
                        100 * (summary["correct"] or 0) / (summary["questions"] or 1)
                    ),
                    "active_days": len(daily_rows),
                },
                "daily": [
                    {
                        "date": row["completed_at__date"].isoformat(),
                        "quizzes": row["quizzes"],
                        "xp": row["xp"] or 0,
                    }
                    for row in daily_rows
                ],
                "subjects": list(subject_rows),
                "lectures": [
                    {
                        **row,
                        "accuracy": round(
                            100 * (row["correct"] or 0) / (row["questions"] or 1)
                        ),
                    }
                    for row in lecture_rows
                ],
                "focus_areas": [
                    {
                        "subject": row["attempt__subject"],
                        "lecture": row["attempt__lecture_number"],
                        "topic": (
                            row["question__topic"]
                            or row["question__source_title"]
                            or "موضوع يحتاج مراجعة"
                        ),
                        "incorrect": row["incorrect"],
                    }
                    for row in focus_rows
                ],
                "active_plans": [_plan_data(plan) for plan in plans],
            }
        )


class NotificationListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        notifications = Notification.objects.filter(recipient=request.user)[:100]
        unread_count = Notification.objects.filter(
            recipient=request.user,
            is_read=False,
        ).count()
        return Response(
            {
                "unread_count": unread_count,
                "results": [
                    {
                        "id": item.id,
                        "type": item.notification_type,
                        "title": item.title,
                        "body": item.body,
                        "data": item.data,
                        "is_read": item.is_read,
                        "created_at": item.created_at.isoformat(),
                    }
                    for item in notifications
                ],
            }
        )


class NotificationReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk=None):
        notifications = Notification.objects.filter(recipient=request.user)
        if pk is None:
            updated = notifications.filter(is_read=False).update(
                is_read=True,
                read_at=timezone.now(),
            )
            return Response({"updated": updated})
        notification = get_object_or_404(notifications, pk=pk)
        if not notification.is_read:
            notification.is_read = True
            notification.read_at = timezone.now()
            notification.save(update_fields=["is_read", "read_at"])
        return Response({"id": notification.id, "is_read": True})


class StudentPreferenceView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    boolean_fields = (
        "notifications_enabled",
        "daily_challenge_reminders",
        "weekly_progress_reports",
    )

    def get(self, request):
        preferences, _ = StudentPreference.objects.get_or_create(user=request.user)
        return Response(self._data(preferences))

    def patch(self, request):
        if not request.data:
            return Response(
                {"detail": "أرسل إعدادًا واحدًا على الأقل للتحديث."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        allowed = set(self.boolean_fields) | {"study_goal_minutes"}
        unknown = set(request.data.keys()) - allowed
        if unknown:
            return Response(
                {"detail": "تتضمن البيانات إعدادات غير معروفة."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        for field in self.boolean_fields:
            if field in request.data and not isinstance(request.data[field], bool):
                return Response(
                    {"detail": f"القيمة {field} يجب أن تكون منطقية."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        goal = None
        if "study_goal_minutes" in request.data:
            goal = StudyPlanListCreateView._integer(request.data["study_goal_minutes"])
            if goal is None or not 5 <= goal <= 600:
                return Response(
                    {"detail": "هدف الدراسة يجب أن يكون بين 5 و600 دقيقة."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        preferences, _ = StudentPreference.objects.get_or_create(user=request.user)
        for field in self.boolean_fields:
            if field in request.data:
                setattr(preferences, field, request.data[field])
        if goal is not None:
            preferences.study_goal_minutes = goal
        preferences.save()
        return Response(self._data(preferences))

    @staticmethod
    def _data(preferences):
        return {
            "notifications_enabled": preferences.notifications_enabled,
            "daily_challenge_reminders": preferences.daily_challenge_reminders,
            "weekly_progress_reports": preferences.weekly_progress_reports,
            "study_goal_minutes": preferences.study_goal_minutes,
            "updated_at": preferences.updated_at.isoformat(),
        }
