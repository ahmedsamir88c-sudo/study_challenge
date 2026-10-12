from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0013_seed_academic_structure"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="student_status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("approved", "Approved"),
                    ("rejected", "Rejected"),
                    ("suspended", "Suspended"),
                    ("active", "Active"),
                    ("inactive", "Inactive"),
                ],
                db_index=True,
                default="pending",
                max_length=20,
            ),
        ),
    ]
