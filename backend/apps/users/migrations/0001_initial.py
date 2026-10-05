# Generated manually for the initial custom User model.
from django.db import migrations, models
import django.utils.timezone
import django.db.models.deletion
import apps.users.models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("auth", "0012_alter_user_first_name_max_length"),
    ]

    operations = [
        migrations.CreateModel(
            name="User",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("password", models.CharField(max_length=128, verbose_name="password")),
                ("last_login", models.DateTimeField(blank=True, null=True, verbose_name="last login")),
                ("is_superuser", models.BooleanField(default=False, help_text="Designates that this user has all permissions without explicitly assigning them.", verbose_name="superuser status")),
                ("username", models.CharField(db_index=True, max_length=50, unique=True)),
                ("full_name", models.CharField(max_length=150)),
                ("email", models.EmailField(blank=True, max_length=254, null=True, unique=True)),
                ("profile_image", models.ImageField(blank=True, null=True, upload_to="profiles/")),
                ("academic_year", models.PositiveSmallIntegerField(blank=True, null=True)),
                ("department", models.CharField(blank=True, max_length=150)),
                ("role", models.CharField(choices=[("student", "Student"), ("teacher", "Teacher"), ("admin", "Admin")], db_index=True, default="student", max_length=20)),
                ("is_active", models.BooleanField(default=True)),
                ("is_staff", models.BooleanField(default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("groups", models.ManyToManyField(blank=True, help_text="The groups this user belongs to. A user will get all permissions granted to each of their groups.", related_name="user_set", related_query_name="user", to="auth.group", verbose_name="groups")),
                ("user_permissions", models.ManyToManyField(blank=True, help_text="Specific permissions for this user.", related_name="user_set", related_query_name="user", to="auth.permission", verbose_name="user permissions")),
            ],
            options={"ordering": ["-created_at"]},
            managers=[("objects", apps.users.models.UserManager())],
        ),
    ]
