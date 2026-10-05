from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import LectureContent, User


@admin.register(LectureContent)
class LectureContentAdmin(admin.ModelAdmin):
    list_display = ("subject", "lecture_number", "uploaded_at")
    list_filter = ("subject",)
    search_fields = ("subject",)
    readonly_fields = ("uploaded_at",)


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ("-created_at",)
    list_display = (
        "username",
        "full_name",
        "role",
        "academic_year",
        "is_active",
        "is_staff",
    )
    search_fields = ("username", "full_name", "email")
    list_filter = ("role", "academic_year", "is_active", "is_staff")

    fieldsets = (
        (None, {"fields": ("username", "password")}),
        (
            "Personal information",
            {
                "fields": (
                    "full_name",
                    "email",
                    "profile_image",
                    "academic_year",
                    "department",
                )
            },
        ),
        ("Permissions", {"fields": ("role", "is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Dates", {"fields": ("last_login", "created_at", "updated_at")}),
    )

    readonly_fields = ("created_at", "updated_at", "last_login")

    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": (
                    "username",
                    "full_name",
                    "password1",
                    "password2",
                    "role",
                    "is_active",
                    "is_staff",
                    "is_superuser",
                ),
            },
        ),
    )
