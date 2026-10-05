import concurrent.futures
import hashlib
import mimetypes
import os
import re
import threading
from datetime import datetime
from pathlib import Path

from django.conf import settings
from django.db import close_old_connections, transaction
from django.utils import timezone
from pypdf import PdfReader

try:
    import docx
except ImportError:
    docx = None

try:
    import pptx
except ImportError:
    pptx = None

from ..models import (
    AuditLog,
    DocumentChunk,
    Lecture,
    LectureContent,
    MaterialDocument,
)
from .gemini_client import GeminiClient, GeminiServiceError

# Allowed academic file extensions and mime types
ALLOWED_EXTENSIONS = {".pdf", ".docx", ".pptx", ".txt"}
ALLOWED_MIME_TYPES = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/vnd.ms-powerpoint",
    "application/zip",  # docx/pptx are zip containers
    "application/x-zip-compressed",
    "text/plain",
    "text/x-python",
}

MAX_FILE_SIZE_BYTES = getattr(
    settings,
    "AI_RAG_MAX_PDF_BYTES",
    30 * 1024 * 1024,
)

# Background executor for document processing
_EXECUTOR = concurrent.futures.ThreadPoolExecutor(max_workers=3)


class FileValidationError(Exception):
    pass


def sanitize_filename(filename: str) -> str:
    """Sanitize the uploaded filename to prevent directory traversal and path injection."""
    clean = os.path.basename(filename)
    clean = re.sub(r"[^\w\.\-\s\(\)]", "_", clean, flags=re.UNICODE)
    clean = re.sub(r"\s+", " ", clean).strip()
    return clean or "document"


def validate_file(uploaded_file) -> tuple[str, str, int]:
    """
    Validate uploaded file: extension, MIME type, size, and magic bytes.
    Returns (cleaned_filename, file_type, file_size).
    """
    name = sanitize_filename(uploaded_file.name)
    ext = os.path.splitext(name)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise FileValidationError(
            f"نوع الملف غير مدعوم ({ext}). الصيغ المسموحة هي: PDF, DOCX, PPTX, TXT."
        )

    file_size = uploaded_file.size
    if file_size <= 0:
        raise FileValidationError("الملف المرفوع فارغ.")
    if file_size > MAX_FILE_SIZE_BYTES:
        mb = MAX_FILE_SIZE_BYTES // (1024 * 1024)
        raise FileValidationError(
            f"حجم الملف يتجاوز الحد الأقصى المسموح به ({mb} ميجابايت)."
        )

    # Validate header magic bytes
    initial_pos = uploaded_file.tell() if hasattr(uploaded_file, "tell") else 0
    header = uploaded_file.read(8)
    if hasattr(uploaded_file, "seek"):
        uploaded_file.seek(initial_pos)

    if ext == ".pdf" and not header.startswith(b"%PDF"):
        raise FileValidationError("ملف PDF غير صالح أو تالف.")
    elif ext in {".docx", ".pptx"} and not header.startswith(b"PK\x03\x04"):
        raise FileValidationError(f"ملف {ext.upper()[1:]} غير صالح أو تالف.")

    file_type = ext.lstrip(".")
    return name, file_type, file_size


def clean_text(text: str) -> str:
    text = text.replace("\x00", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_pages(file_path: str, file_type: str) -> list[dict]:
    """
    Extract text and metadata from PDF, DOCX, PPTX, or TXT file.
    Returns list of dicts: [{'page_number': int, 'text': str, 'section_title': str}]
    """
    pages = []
    file_type = file_type.lower()

    if file_type == "pdf":
        with open(file_path, "rb") as f:
            reader = PdfReader(f)
            for idx, page in enumerate(reader.pages):
                extracted = page.extract_text() or ""
                cleaned = clean_text(extracted)
                if cleaned:
                    pages.append({
                        "page_number": idx + 1,
                        "text": cleaned,
                        "section_title": f"صفحة {idx + 1}",
                    })

    elif file_type == "docx":
        if docx is None:
            raise FileValidationError("مكتبة قراءة ملفات Word غير متوفرة.")
        doc = docx.Document(file_path)
        current_page = 1
        current_section = "مقدمة"
        page_paras = []
        word_count = 0

        for para in doc.paragraphs:
            p_text = clean_text(para.text)
            if not p_text:
                continue
            if para.style and para.style.name and "Heading" in para.style.name:
                current_section = p_text

            page_paras.append(p_text)
            word_count += len(p_text.split())
            if word_count >= 350:
                pages.append({
                    "page_number": current_page,
                    "text": "\n".join(page_paras),
                    "section_title": current_section,
                })
                current_page += 1
                page_paras = []
                word_count = 0

        if page_paras:
            pages.append({
                "page_number": current_page,
                "text": "\n".join(page_paras),
                "section_title": current_section,
            })

    elif file_type == "pptx":
        if pptx is None:
            raise FileValidationError("مكتبة قراءة ملفات PowerPoint غير متوفرة.")
        prs = pptx.Presentation(file_path)
        for idx, slide in enumerate(prs.slides):
            slide_texts = []
            title = f"شريحة {idx + 1}"
            for shape in slide.shapes:
                if hasattr(shape, "text") and shape.text:
                    stext = clean_text(shape.text)
                    if stext:
                        if shape == slide.shapes[0] and len(stext) < 100:
                            title = stext
                        slide_texts.append(stext)
            full_slide_text = "\n".join(slide_texts)
            if full_slide_text:
                pages.append({
                    "page_number": idx + 1,
                    "text": full_slide_text,
                    "section_title": title,
                })

    elif file_type == "txt":
        raw_bytes = Path(file_path).read_bytes()
        decoded_text = None
        for encoding in ("utf-8", "utf-8-sig", "cp1256", "iso-8859-6", "latin1"):
            try:
                decoded_text = raw_bytes.decode(encoding)
                break
            except UnicodeDecodeError:
                continue
        if decoded_text is None:
            decoded_text = raw_bytes.decode("utf-8", errors="ignore")

        # Split into simulated pages by paragraphs / double newlines
        paragraphs = [clean_text(p) for p in decoded_text.split("\n\n") if clean_text(p)]
        current_page = 1
        current_paras = []
        word_count = 0
        for p in paragraphs:
            current_paras.append(p)
            word_count += len(p.split())
            if word_count >= 300:
                pages.append({
                    "page_number": current_page,
                    "text": "\n\n".join(current_paras),
                    "section_title": f"جزء {current_page}",
                })
                current_page += 1
                current_paras = []
                word_count = 0
        if current_paras:
            pages.append({
                "page_number": current_page,
                "text": "\n\n".join(current_paras),
                "section_title": f"جزء {current_page}",
            })

    return pages


def chunk_pages(pages: list[dict], chunk_size: int = 1500, overlap: int = 200) -> list[dict]:
    """
    Split extracted pages into contextual chunks respecting sentence/paragraph boundaries.
    """
    chunks = []
    chunk_index = 0

    for page in pages:
        text = page["text"]
        page_num = page["page_number"]
        section = page.get("section_title", "")
        start = 0

        while start < len(text):
            end = min(start + chunk_size, len(text))
            if end < len(text):
                boundary = max(
                    text.rfind("\n", start + chunk_size // 2, end),
                    text.rfind(". ", start + chunk_size // 2, end),
                    text.rfind("، ", start + chunk_size // 2, end),
                )
                if boundary > start:
                    end = boundary + 1

            chunk_text = text[start:end].strip()
            if chunk_text:
                approx_tokens = len(chunk_text.split())
                chunks.append({
                    "chunk_index": chunk_index,
                    "page_number": page_num,
                    "section_title": section,
                    "text": chunk_text,
                    "token_count": approx_tokens,
                })
                chunk_index += 1

            if end >= len(text):
                break
            start = max(end - overlap, start + 1)

    return chunks


def compute_hash(chunks: list[dict]) -> str:
    content = "\n".join(f"{c['page_number']}:{c['text']}" for c in chunks)
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def process_material_sync(document_id: int) -> bool:
    """
    Synchronous processing function for a MaterialDocument:
    1. Reads file from storage
    2. Extracts text & page numbers
    3. Chunks text
    4. Calls Gemini embedding model
    5. Saves DocumentChunks
    6. Updates status to READY (or FAILED on error)
    """
    is_main_thread = threading.current_thread() is threading.main_thread()
    if not is_main_thread:
        close_old_connections()
    try:
        doc = MaterialDocument.objects.select_related("subject", "academic_year", "lecture").get(id=document_id)
    except MaterialDocument.DoesNotExist:
        return False

    doc.processing_status = MaterialDocument.ProcessingStatus.PROCESSING
    doc.processing_started_at = timezone.now()
    doc.processing_error = ""
    doc.save(update_fields=["processing_status", "processing_started_at", "processing_error"])

    try:
        file_path = doc.file.path
        if not os.path.exists(file_path):
            raise FileValidationError("ملف المادة غير موجود على مسار التخزين.")

        pages = extract_pages(file_path, doc.file_type)
        if not pages:
            raise FileValidationError("لم يتم العثور على أي نصوص قابلة للاستخراج داخل هذا الملف.")

        doc.page_count = len(pages)
        chunks = chunk_pages(pages)
        if not chunks:
            raise FileValidationError("تعذر تقسيم الملف إلى مقتطفات نصية.")

        source_hash = compute_hash(chunks)

        # Generate embeddings via Gemini client
        client = GeminiClient()
        texts_to_embed = [c["text"] for c in chunks]

        try:
            embeddings = client.embed_texts(texts_to_embed, task_type="RETRIEVAL_DOCUMENT")
        except Exception as embed_err:
            raise GeminiServiceError(f"خطأ أثناء إنشاء المتجهات الذكية: {str(embed_err)}")

        if len(embeddings) != len(chunks):
            raise GeminiServiceError("عدد المتجهات الناتجة لا يطابق عدد المقتطفات.")

        with transaction.atomic():
            # Deactivate previous active chunks for this document
            DocumentChunk.objects.filter(document=doc).delete()

            new_chunks = [
                DocumentChunk(
                    document=doc,
                    academic_year=doc.academic_year.year_number,
                    chunk_index=c["chunk_index"],
                    page_number=c["page_number"],
                    section_title=c["section_title"],
                    token_count=c["token_count"],
                    text=c["text"],
                    embedding=emb,
                    embedding_model=settings.GEMINI_EMBEDDING_MODEL,
                    source_hash=source_hash,
                    is_active=True,
                )
                for c, emb in zip(chunks, embeddings)
            ]
            DocumentChunk.objects.bulk_create(new_chunks)

            # Sync with legacy LectureContent if applicable for existing compatibility
            if doc.lecture and doc.subject:
                lec_num = doc.lecture.lecture_number
                sub_name = doc.subject.name
                legacy_lecture, _ = LectureContent.objects.get_or_create(
                    subject=sub_name,
                    lecture_number=lec_num,
                )
                # Link newly created chunks to legacy lecture as well
                DocumentChunk.objects.filter(document=doc).update(lecture=legacy_lecture)

            doc.processing_status = MaterialDocument.ProcessingStatus.READY
            doc.processing_completed_at = timezone.now()
            doc.processing_error = ""
            doc.save(
                update_fields=[
                    "page_count",
                    "processing_status",
                    "processing_completed_at",
                    "processing_error",
                ]
            )

        return True

    except Exception as err:
        doc.processing_status = MaterialDocument.ProcessingStatus.FAILED
        doc.processing_error = str(err)
        doc.processing_completed_at = timezone.now()
        doc.save(
            update_fields=[
                "processing_status",
                "processing_error",
                "processing_completed_at",
            ]
        )
        return False
    finally:
        close_old_connections()


def trigger_document_processing(document_id: int, async_process: bool = True):
    """
    Launch document processing asynchronously or synchronously (e.g. for testing).
    """
    if async_process:
        _EXECUTOR.submit(process_material_sync, document_id)
    else:
        process_material_sync(document_id)


def replace_document_file(doc: MaterialDocument, new_file, uploader_user=None) -> MaterialDocument:
    """
    Replaces an existing document with a new file:
    1. Archives/deactivates old chunks
    2. Increments version
    3. Replaces file
    4. Triggers re-processing
    """
    name, file_type, file_size = validate_file(new_file)

    with transaction.atomic():
        # Deactivate old chunks
        DocumentChunk.objects.filter(document=doc).update(is_active=False)

        doc.file = new_file
        doc.original_filename = name
        doc.file_type = file_type
        doc.file_size = file_size
        doc.version += 1
        doc.processing_status = MaterialDocument.ProcessingStatus.UPLOADED
        doc.processing_error = ""
        doc.processing_started_at = None
        doc.processing_completed_at = None
        doc.save()

        if uploader_user:
            AuditLog.objects.create(
                user=uploader_user,
                action="REPLACE_FILE",
                details={
                    "document_id": doc.id,
                    "title": doc.title,
                    "new_version": doc.version,
                    "filename": name,
                },
            )

    trigger_document_processing(doc.id, async_process=True)
    return doc

