from django.db import migrations


def seed_missing_lectures(apps, schema_editor):
    Subject = apps.get_model("users", "Subject")
    Lecture = apps.get_model("users", "Lecture")

    for subject in Subject.objects.all().iterator():
        existing_numbers = set(
            Lecture.objects.filter(subject_id=subject.pk).values_list(
                "lecture_number", flat=True
            )
        )
        Lecture.objects.bulk_create(
            [
                Lecture(
                    subject_id=subject.pk,
                    title=f"المحاضرة {lecture_number}",
                    lecture_number=lecture_number,
                    order=lecture_number,
                )
                for lecture_number in range(1, 17)
                if lecture_number not in existing_numbers
            ]
        )


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0017_quizattemptanswer_review_count_and_more"),
    ]

    operations = [
        migrations.RunPython(seed_missing_lectures, migrations.RunPython.noop),
    ]
