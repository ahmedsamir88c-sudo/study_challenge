import hashlib
import math
import os
import re
from dataclasses import dataclass

from django.conf import settings
from django.db import transaction
from pypdf import PdfReader

from ..models import (
    AISummary,
    AcademicYear,
    DocumentChunk,
    Flashcard,
    GeneratedQuizQuestion,
    Lecture,
    LectureContent,
    MaterialDocument,
    Subject,
    User,
)
from .gemini_client import GeminiClient, GeminiServiceError


ACADEMIC_YEAR_SUBJECTS = {
    1: {"Digital Logic Design", "Data Structure and Algorithms"},
    2: {
        "Computer Architecture",
        "Data Structure and Algorithms",
        "Digital Logic Design",
    },
    3: {
        "Computer Networks",
        "Modeling and Simulation",
        "Computer Architecture",
    },
    4: {"Machine Learning", "Computer Networks", "Modeling and Simulation"},
}

NOT_FOUND_MESSAGE = "لم أجد هذه المعلومة في المواد الدراسية المتاحة لهذه المادة."
NO_MATERIAL_MESSAGE = "لا توجد مواد نصية جاهزة للمساعد في هذه المادة حتى الآن."


class AcademicAIScopeError(Exception):
    pass


@dataclass(frozen=True)
class TextChunk:
    text: str
    page_number: int | None


def _extract_lecture_pages(lecture: LectureContent) -> list[tuple[int | None, str]]:
    pages = []
    if (lecture.content or "").strip():
        pages.append((None, lecture.content.strip()))

    if lecture.file:
        if os.path.splitext(lecture.file.name)[1].lower() != ".pdf":
            raise GeminiServiceError("صيغة الملف غير مدعومة للمساعد الدراسي حاليًا.")
        if lecture.file.size > settings.AI_RAG_MAX_PDF_BYTES:
            raise GeminiServiceError(
                "حجم ملف المحاضرة أكبر من الحد المسموح للمعالجة حاليًا."
            )
        try:
            with lecture.file.open("rb") as source_file:
                reader = PdfReader(source_file)
                pages.extend(
                    (page_index + 1, page.extract_text() or "")
                    for page_index, page in enumerate(reader.pages)
                )
        except Exception as error:
            raise GeminiServiceError("تعذر قراءة ملف المحاضرة.") from error

    return [
        (page_number, _clean_text(text))
        for page_number, text in pages
        if _clean_text(text)
    ]


def _clean_text(text: str) -> str:
    text = text.replace("\x00", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _split_pages(pages: list[tuple[int | None, str]]) -> list[TextChunk]:
    chunks = []
    chunk_size = 1800
    overlap = 220

    for page_number, text in pages:
        start = 0
        while start < len(text):
            end = min(start + chunk_size, len(text))
            if end < len(text):
                boundary = max(
                    text.rfind("\n", start + chunk_size // 2, end),
                    text.rfind(". ", start + chunk_size // 2, end),
                )
                if boundary > start:
                    end = boundary + 1
            chunk_text = text[start:end].strip()
            if chunk_text:
                chunks.append(TextChunk(chunk_text, page_number))
            if end >= len(text):
                break
            start = max(end - overlap, start + 1)
    return chunks


def _source_hash(pages: list[tuple[int | None, str]]) -> str:
    serialized = "\n".join(f"{page}:{text}" for page, text in pages)
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()


def _index_lecture(
    client: GeminiClient,
    lecture: LectureContent,
    academic_year: int,
) -> list[DocumentChunk]:
    pages = _extract_lecture_pages(lecture)
    chunks = _split_pages(pages)
    source_hash = _source_hash(pages)
    existing = list(
        DocumentChunk.objects.filter(
            lecture=lecture,
            academic_year=academic_year,
            is_active=True,
        ).order_by("chunk_index")
    )
    if (
        len(existing) == len(chunks)
        and existing
        and all(chunk.source_hash == source_hash for chunk in existing)
    ):
        return existing

    if not chunks:
        DocumentChunk.objects.filter(
            lecture=lecture,
            academic_year=academic_year,
        ).delete()
        return []

    embeddings = client.embed_texts(
        [chunk.text for chunk in chunks],
        task_type="RETRIEVAL_DOCUMENT",
    )
    if len(embeddings) != len(chunks):
        raise GeminiServiceError("تعذر تجهيز محتوى المحاضرة للبحث.")

    indexed_chunks = [
        DocumentChunk(
            lecture=lecture,
            academic_year=academic_year,
            chunk_index=index,
            page_number=chunk.page_number,
            text=chunk.text,
            embedding=embedding,
            embedding_model=settings.GEMINI_EMBEDDING_MODEL,
            source_hash=source_hash,
            is_active=True,
        )
        for index, (chunk, embedding) in enumerate(zip(chunks, embeddings))
    ]
    with transaction.atomic():
        DocumentChunk.objects.filter(
            lecture=lecture,
            academic_year=academic_year,
        ).delete()
        DocumentChunk.objects.bulk_create(indexed_chunks)
    return indexed_chunks


def _cosine_similarity(first: list[float], second: list[float]) -> float:
    if len(first) != len(second) or not first:
        return -1.0
    dot = sum(left * right for left, right in zip(first, second))
    first_norm = math.sqrt(sum(value * value for value in first))
    second_norm = math.sqrt(sum(value * value for value in second))
    if not first_norm or not second_norm:
        return -1.0
    return dot / (first_norm * second_norm)


def _source_label(chunk: DocumentChunk, source_id: str) -> dict:
    file_name = "محتوى المحاضرة"
    subject = ""
    lecture_number = None
    doc_id = None

    if chunk.document:
        doc_id = chunk.document.id
        file_name = chunk.document.original_filename or chunk.document.title
        subject = chunk.document.subject.name
        if chunk.document.lecture:
            lecture_number = chunk.document.lecture.lecture_number
    elif chunk.lecture:
        if chunk.lecture.file:
            file_name = os.path.basename(chunk.lecture.file.name)
        subject = chunk.lecture.subject
        lecture_number = chunk.lecture.lecture_number

    return {
        "source_id": source_id,
        "file_name": file_name,
        "subject": subject,
        "lecture_number": lecture_number,
        "page_number": chunk.page_number,
        "section_title": chunk.section_title or "",
        "document_id": doc_id,
    }


def _validate_student_subject(user: User, subject: str) -> int:
    if getattr(user, "role", None) in {User.Role.OWNER, User.Role.ADMIN}:
        if user.academic_year:
            return user.academic_year
        sub_obj = Subject.objects.filter(name=subject, is_active=True).first()
        if sub_obj:
            return sub_obj.academic_year.year_number
        return 1

    academic_year = user.academic_year
    if (
        academic_year not in ACADEMIC_YEAR_SUBJECTS
        and not AcademicYear.objects.filter(year_number=academic_year).exists()
    ):
        raise AcademicAIScopeError("يجب تحديد الفرقة الدراسية أولًا.")

    is_valid_dynamic = Subject.objects.filter(
        name=subject,
        academic_year__year_number=academic_year,
        is_active=True,
    ).exists()
    is_valid_legacy = subject in ACADEMIC_YEAR_SUBJECTS.get(academic_year, set())

    if not (is_valid_dynamic or is_valid_legacy):
        raise AcademicAIScopeError("هذه المادة غير متاحة لفرقتك الدراسية.")
    return academic_year


def _fetch_active_chunks_for_subject(
    subject: str,
    academic_year: int,
    lecture_number: int | None = None,
    document_id: int | None = None,
) -> list[DocumentChunk]:
    """Retrieve all active indexed chunks for the given subject and year."""
    chunks_qs = DocumentChunk.objects.filter(
        is_active=True,
        document__subject__name=subject,
        document__academic_year__year_number=academic_year,
        document__is_active=True,
    )
    if lecture_number is not None:
        chunks_qs = chunks_qs.filter(document__lecture__lecture_number=lecture_number)
    if document_id is not None:
        chunks_qs = chunks_qs.filter(document_id=document_id)

    chunks = list(chunks_qs.select_related("document", "document__subject", "document__lecture"))

    # Also include legacy LectureContent chunks if needed
    lectures = LectureContent.objects.filter(subject=subject).order_by("lecture_number")
    if lecture_number is not None:
        lectures = lectures.filter(lecture_number=lecture_number)
    lectures = list(lectures)

    client = GeminiClient()
    for lec in lectures:
        legacy_chunks = _index_lecture(client, lec, academic_year)
        chunks.extend(legacy_chunks)

    return chunks



def summarize_academic_lecture(
    *,
    user: User,
    subject: str,
    lecture_number: int,
    summary_type: str,
) -> dict:
    summary_instructions = {
        AISummary.SummaryType.QUICK: (
            "اكتب ملخصًا سريعًا من 4 إلى 6 نقاط قصيرة يلتقط الأفكار الأساسية."
        ),
        AISummary.SummaryType.DETAILED: (
            "اكتب ملخصًا تفصيليًا منظمًا بعناوين فرعية، واشرح العلاقات بين المفاهيم."
        ),
        AISummary.SummaryType.EXAM: (
            "اكتب مراجعة امتحانية تتضمن التعريفات والمفاهيم والمقارنات والقواعد "
            "المهمة الواردة في المصادر فقط، دون توقع أسئلة غير مدعومة."
        ),
        AISummary.SummaryType.KEY_POINTS: (
            "استخرج أهم النقاط فقط في قائمة موجزة، دون إضافة شرح من خارج المصادر."
        ),
        AISummary.SummaryType.DEFINITIONS: (
            "استخرج المصطلحات والتعريفات الموجودة صراحةً في المصادر. إذا لم يوجد "
            "تعريف واضح، لا تخترع تعريفًا."
        ),
    }
    if summary_type not in summary_instructions:
        raise ValueError("نوع الملخص غير صالح.")

    academic_year = _validate_student_subject(user, subject)
    chunks = _fetch_active_chunks_for_subject(
        subject=subject,
        academic_year=academic_year,
        lecture_number=lecture_number,
    )
    if not chunks:
        return {"summary": NO_MATERIAL_MESSAGE, "sources": []}

    client = GeminiClient()
    source_entries = [
        _source_label(chunk, f"S{index}")
        for index, chunk in enumerate(chunks, 1)
    ]
    source_blocks = [
        f"[{source['source_id']}] الصفحة: "
        f"{source['page_number'] or 'غير محددة'}\n{chunk.text}"
        for source, chunk in zip(source_entries, chunks)
    ]
    groups = [source_blocks[index:index + 5] for index in range(0, len(source_blocks), 5)]
    instruction = summary_instructions[summary_type]
    partial_summaries = [
        client.generate_grounded_answer(
            f"{instruction} حافظ على معرّفات المصادر بين الأقواس المربعة.",
            "\n\n".join(group),
        )
        for group in groups
    ]
    if len(partial_summaries) == 1:
        summary_text = partial_summaries[0]
    else:
        summary_context = "\n\n".join(
            f"ملخص الجزء {index}:\n{text}"
            for index, text in enumerate(partial_summaries, 1)
        )
        summary_text = client.generate_grounded_answer(
            f"ادمج ملخصات أجزاء المحاضرة في ملخص واحد. {instruction} "
            "احتفظ بمعرّفات المصادر كما هي، ولا تضف أي معلومة جديدة.",
            summary_context,
        )

    legacy_lecture = LectureContent.objects.filter(
        subject=subject,
        lecture_number=lecture_number,
    ).first()

    summary = AISummary.objects.create(
        user=user,
        lecture=legacy_lecture,
        academic_year=academic_year,
        summary_type=summary_type,
        content=summary_text,
        sources=source_entries,
    )
    return {
        "id": summary.pk,
        "subject": subject,
        "lecture_number": lecture_number,
        "academic_year": academic_year,
        "summary_type": summary_type,
        "summary": summary_text,
        "sources": source_entries,
        "created_at": summary.created_at.isoformat(),
    }


def ask_academic_question(
    *,
    user: User,
    subject: str,
    question: str,
    lecture_number: int | None = None,
    document_id: int | None = None,
) -> dict:
    academic_year = _validate_student_subject(user, subject)
    if lecture_number is not None and (
        subject in LectureContent.SUBJECT_LECTURE_COUNTS
        and not 1 <= lecture_number <= LectureContent.SUBJECT_LECTURE_COUNTS[subject]
    ):
        raise ValueError("Invalid lecture number for the selected subject.")

    indexed_chunks = _fetch_active_chunks_for_subject(
        subject=subject,
        academic_year=academic_year,
        lecture_number=lecture_number,
        document_id=document_id,
    )
    if not indexed_chunks:
        return {"reply": NO_MATERIAL_MESSAGE, "sources": []}

    client = GeminiClient()
    query_embedding = client.embed_texts(
        [question],
        task_type="RETRIEVAL_QUERY",
    )[0]
    ranked_chunks = sorted(
        (
            (_cosine_similarity(query_embedding, chunk.embedding), chunk)
            for chunk in indexed_chunks
        ),
        key=lambda result: result[0],
        reverse=True,
    )
    relevant_chunks = [
        chunk
        for similarity, chunk in ranked_chunks[:settings.AI_RAG_TOP_K]
        if similarity >= settings.AI_RAG_MIN_SIMILARITY
    ]
    if not relevant_chunks:
        return {"reply": NOT_FOUND_MESSAGE, "sources": []}

    sources = [
        _source_label(chunk, f"S{index}")
        for index, chunk in enumerate(relevant_chunks, 1)
    ]
    source_text = "\n\n".join(
        f"[{source['source_id']}] المادة: {source['subject']}، "
        f"المحاضرة: {source['lecture_number'] or 'عامة'}، الصفحة: "
        f"{source['page_number'] or 'غير محددة'}\n{chunk.text}"
        for source, chunk in zip(sources, relevant_chunks)
    )
    answer = client.generate_grounded_answer(question, source_text)
    return {"reply": answer, "sources": sources}


def generate_academic_quiz(
    *,
    user: User,
    subject: str,
    academic_year: int | None = None,
    lecture_number: int | None = None,
    document_id: int | None = None,
    topic: str = "",
    difficulty: str = "medium",
    question_type: str = "mcq",
    count: int = 5,
) -> dict:
    year = academic_year or _validate_student_subject(user, subject)
    chunks = _fetch_active_chunks_for_subject(
        subject=subject,
        academic_year=year,
        lecture_number=lecture_number,
        document_id=document_id,
    )
    if not chunks:
        return {"questions": [], "message": NO_MATERIAL_MESSAGE}

    client = GeminiClient()
    selected_chunks = chunks
    if topic.strip():
        try:
            topic_emb = client.embed_texts([topic], task_type="RETRIEVAL_QUERY")[0]
            ranked = sorted(
                ((_cosine_similarity(topic_emb, c.embedding), c) for c in chunks),
                key=lambda x: x[0],
                reverse=True,
            )
            selected_chunks = [c for s, c in ranked if s >= 0.25][:8] or chunks[:8]
        except Exception:
            selected_chunks = chunks[:8]
    else:
        selected_chunks = chunks[:8]

    context_text = "\n\n".join(
        f"[صفحة {c.page_number or 1}] {c.text}"
        for c in selected_chunks
    )

    if question_type == "essay":
        sys_prompt = (
            "أنت أستاذ جامعي خبير في إعداد الأسئلة المقالية. "
            "قم بتوليد أسئلة مقالية دقيقة استناداً حصراً وبدقة إلى المحتوى المرفق. "
            "لكل سؤال اذكر: نص السؤال، الإجابة النموذجية الكاملة، ومعايير تقييم الإجابة، ورقم الصفحة إن وجد. "
            "لا تخترع أي معلومات من خارج النص. "
            "أرجع مصفوفة JSON تحتوي كائنات بالحقول التالية فقط: "
            "question, expected_answer, grading_criteria, topic, page_number"
        )
    else:
        sys_prompt = (
            "أنت أستاذ جامعي خبير في إعداد اختبارات الاختيار من متعدد (MCQ). "
            "قم بتوليد أسئلة اختيار من متعدد مبنية حصراً على المحتوى المرفق. "
            "لكل سؤال: 4 خيارات (options) خيار واحد صحيح وثلاثة مشتتات دقيقة من سياق المادة، "
            "ومؤشر الخيار الصحيح correct_index (0 إلى 3)، وتفسير مفصل، والموضوع، ورقم الصفحة إن وجد. "
            "لا تخترع أي معلومات من خارج النص. "
            "أرجع مصفوفة JSON تحتوي كائنات بالحقول التالية فقط: "
            "question, options, correct_index, explanation, topic, page_number"
        )

    user_prompt = (
        f"المادة: {subject}\n"
        f"المستوى: {difficulty}\n"
        f"الموضوع المطلوب: {topic or 'عام'}\n"
        f"عدد الأسئلة: {count}\n\n"
        f"المحتوى المصدري (بيانات فقط):\n{context_text}"
    )

    raw_result = client.generate_structured_json(sys_prompt, user_prompt)
    if isinstance(raw_result, dict):
        raw_questions = raw_result.get("questions", [])
    elif isinstance(raw_result, list):
        raw_questions = raw_result
    else:
        raw_questions = []

    lec_obj = None
    if lecture_number is not None:
        lec_obj = Lecture.objects.filter(
            subject__name=subject,
            lecture_number=lecture_number,
        ).first()

    doc_obj = None
    if document_id is not None:
        doc_obj = MaterialDocument.objects.filter(id=document_id).first()

    created_questions = []
    for item in raw_questions:
        q_text = (item.get("question") or "").strip()
        if not q_text:
            continue

        fingerprint = hashlib.sha256(f"{subject}:{q_text}".encode("utf-8")).hexdigest()
        existing_q = GeneratedQuizQuestion.objects.filter(fingerprint=fingerprint).first()
        if existing_q:
            created_questions.append(existing_q)
            continue

        if question_type == "essay":
            exp_ans = item.get("expected_answer", "")
            crit = item.get("grading_criteria", "")
            new_q = GeneratedQuizQuestion.objects.create(
                subject=subject,
                lecture_number=lecture_number or 1,
                difficulty=difficulty,
                question=q_text,
                question_type="essay",
                expected_answer=exp_ans,
                grading_criteria=crit,
                topic=item.get("topic", topic),
                source_title=doc_obj.title if doc_obj else subject,
                page_number=item.get("page_number"),
                lecture_fk=lec_obj,
                document=doc_obj,
                fingerprint=fingerprint,
                options=[],
                correct_index=0,
                explanation=exp_ans,
            )
            created_questions.append(new_q)
        else:
            opts = item.get("options")
            corr_idx = item.get("correct_index", 0)
            if not isinstance(opts, list) or len(opts) < 2:
                continue
            if not isinstance(corr_idx, int) or not (0 <= corr_idx < len(opts)):
                corr_idx = 0
            new_q = GeneratedQuizQuestion.objects.create(
                subject=subject,
                lecture_number=lecture_number or 1,
                difficulty=difficulty,
                question=q_text,
                options=opts,
                correct_index=corr_idx,
                explanation=item.get("explanation", ""),
                question_type="mcq",
                topic=item.get("topic", topic),
                source_title=doc_obj.title if doc_obj else subject,
                page_number=item.get("page_number"),
                lecture_fk=lec_obj,
                document=doc_obj,
                fingerprint=fingerprint,
            )
            created_questions.append(new_q)

    return {
        "subject": subject,
        "lecture_number": lecture_number,
        "count": len(created_questions),
        "questions": [
            {
                "id": q.id,
                "question": q.question,
                "question_type": q.question_type,
                "options": q.options,
                "correct_index": q.correct_index,
                "explanation": q.explanation,
                "expected_answer": q.expected_answer,
                "grading_criteria": q.grading_criteria,
                "topic": q.topic,
                "page_number": q.page_number,
                "source_title": q.source_title,
            }
            for q in created_questions
        ],
    }


def generate_academic_flashcards(
    *,
    user: User,
    subject: str,
    academic_year: int | None = None,
    lecture_number: int | None = None,
    document_id: int | None = None,
    topic: str = "",
    count: int = 5,
) -> dict:
    year = academic_year or _validate_student_subject(user, subject)
    chunks = _fetch_active_chunks_for_subject(
        subject=subject,
        academic_year=year,
        lecture_number=lecture_number,
        document_id=document_id,
    )
    if not chunks:
        return {"flashcards": [], "message": NO_MATERIAL_MESSAGE}

    client = GeminiClient()
    selected_chunks = chunks[:8]
    context_text = "\n\n".join(
        f"[صفحة {c.page_number or 1}] {c.text}"
        for c in selected_chunks
    )

    sys_prompt = (
        "أنت مساعد دراسي أكاديمي متخصص في إعداد بطاقات الاستذكار (Flashcards). "
        "استخرج بطاقات دراسية مركزة وفعالة (سؤال وجواب) استناداً حصراً وبدقة إلى المحتوى الأكاديمي المرفق. "
        "أرجع مصفوفة JSON تحتوي على كائنات بالحقول التالية فقط: "
        "question, answer, topic, page_number"
    )
    user_prompt = (
        f"المادة: {subject}\n"
        f"الموضوع: {topic or 'عام'}\n"
        f"العدد المطلوب: {count}\n\n"
        f"المحتوى المصدري:\n{context_text}"
    )

    raw_result = client.generate_structured_json(sys_prompt, user_prompt)
    if isinstance(raw_result, dict):
        raw_cards = raw_result.get("flashcards", [])
    elif isinstance(raw_result, list):
        raw_cards = raw_result
    else:
        raw_cards = []

    year_obj = AcademicYear.objects.filter(year_number=year).first()
    sub_obj = Subject.objects.filter(name=subject).first()
    lec_obj = Lecture.objects.filter(subject=sub_obj, lecture_number=lecture_number).first() if lecture_number else None
    doc_obj = MaterialDocument.objects.filter(id=document_id).first() if document_id else None

    created_cards = []
    for item in raw_cards:
        q_text = (item.get("question") or "").strip()
        ans_text = (item.get("answer") or "").strip()
        if not q_text or not ans_text:
            continue

        card = Flashcard.objects.create(
            user=user,
            academic_year=year_obj,
            subject=sub_obj,
            lecture=lec_obj,
            document=doc_obj,
            question=q_text,
            answer=ans_text,
            topic=item.get("topic", topic),
            source_title=doc_obj.title if doc_obj else subject,
            page_number=item.get("page_number"),
        )
        created_cards.append(card)

    return {
        "subject": subject,
        "lecture_number": lecture_number,
        "count": len(created_cards),
        "flashcards": [
            {
                "id": c.id,
                "question": c.question,
                "answer": c.answer,
                "topic": c.topic,
                "source_title": c.source_title,
                "page_number": c.page_number,
                "created_at": c.created_at.isoformat(),
            }
            for c in created_cards
        ],
    }