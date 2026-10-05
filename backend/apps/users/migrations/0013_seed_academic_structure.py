from django.db import migrations


def seed_academic_structure(apps, schema_editor):
    AcademicYear = apps.get_model("users", "AcademicYear")
    Subject = apps.get_model("users", "Subject")
    Lecture = apps.get_model("users", "Lecture")

    years_data = [
        (1, "الفرقة الأولى", 1),
        (2, "الفرقة الثانية", 2),
        (3, "الفرقة الثالثة", 3),
        (4, "الفرقة الرابعة", 4),
    ]
    year_map = {}
    for num, name, order in years_data:
        year, _ = AcademicYear.objects.get_or_create(
            year_number=num,
            defaults={"name": name, "order": order, "is_active": True},
        )
        year_map[num] = year

    academic_year_subjects = {
        1: [
            ("Digital Logic Design", "CS101", "المنطق الرقمي والدوائر المنطقية", 6),
            ("Data Structure and Algorithms", "CS102", "هياكل البيانات والخوارزميات", 4),
        ],
        2: [
            ("Computer Architecture", "CS201", "معمارية الحاسوب وتنظيم المعالجات", 6),
            ("Data Structure and Algorithms", "CS102", "هياكل البيانات والخوارزميات", 4),
            ("Digital Logic Design", "CS101", "المنطق الرقمي والدوائر المنطقية", 6),
        ],
        3: [
            ("Computer Networks", "CS301", "شبكات الحاسوب والبروتوكولات", 9),
            ("Modeling and Simulation", "CS302", "النمذجة والمحاكاة الحاسوبية", 6),
            ("Computer Architecture", "CS201", "معمارية الحاسوب وتنظيم المعالجات", 6),
        ],
        4: [
            ("Machine Learning", "CS401", "تعلم الآلة والنماذج الذكية", 6),
            ("Computer Networks", "CS301", "شبكات الحاسوب والبروتوكولات", 9),
            ("Modeling and Simulation", "CS302", "النمذجة والمحاكاة الحاسوبية", 6),
        ],
    }

    for year_num, subjects_list in academic_year_subjects.items():
        year_obj = year_map[year_num]
        for s_idx, (name, code, desc, lecture_count) in enumerate(subjects_list, 1):
            subject_obj, _ = Subject.objects.get_or_create(
                academic_year=year_obj,
                name=name,
                defaults={
                    "code": code,
                    "description": desc,
                    "order": s_idx,
                    "is_active": True,
                },
            )
            for lec_num in range(1, lecture_count + 1):
                Lecture.objects.get_or_create(
                    subject=subject_obj,
                    lecture_number=lec_num,
                    defaults={
                        "title": f"المحاضرة {lec_num}",
                        "order": lec_num,
                        "is_active": True,
                    },
                )


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0012_academicyear_auditlog_flashcard_lecture_and_more"),
    ]

    operations = [
        migrations.RunPython(seed_academic_structure, migrations.RunPython.noop),
    ]

