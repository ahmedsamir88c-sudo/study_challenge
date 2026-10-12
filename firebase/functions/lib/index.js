"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.academicAssistant = exports.getLeaderboard = exports.submitQuiz = exports.startQuiz = exports.getDailyChallenge = exports.firebaseApi = exports.processAcademicMaterial = void 0;
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const storage_1 = require("firebase-admin/storage");
const firestore_2 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const officeparser_1 = require("officeparser");
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
const storage = (0, storage_1.getStorage)();
const geminiApiKey = (0, params_1.defineSecret)("GEMINI_API_KEY");
const validUsername = /^[a-zA-Z0-9_.-]{3,50}$/;
const validYears = new Set([1, 2, 3, 4]);
const maxMaterialBytes = 30 * 1024 * 1024;
const maxExtractedCharacters = 500_000;
function splitMaterialText(text) {
    const chunks = [];
    const chunkSize = 1800;
    const overlap = 220;
    let start = 0;
    while (start < text.length) {
        let end = Math.min(start + chunkSize, text.length);
        if (end < text.length) {
            const boundary = Math.max(text.lastIndexOf("\n", end), text.lastIndexOf(". ", end));
            if (boundary > start + chunkSize * 0.75)
                end = boundary + 1;
        }
        const chunk = text.slice(start, end).trim();
        if (chunk)
            chunks.push(chunk);
        if (end >= text.length)
            break;
        start = Math.max(end - overlap, start + 1);
    }
    return chunks;
}
async function deleteMaterialChunks(materialId) {
    while (true) {
        const chunks = await db.collection("lectureChunks")
            .where("materialId", "==", materialId)
            .limit(450)
            .get();
        if (chunks.empty)
            return;
        const batch = db.batch();
        for (const chunk of chunks.docs)
            batch.delete(chunk.ref);
        await batch.commit();
        if (chunks.size < 450)
            return;
    }
}
async function updateLectureContentFlag(lectureId) {
    if (typeof lectureId !== "string" || !lectureId)
        return;
    const [lecture, chunk] = await Promise.all([
        db.doc(`lectures/${lectureId}`).get(),
        db.collection("lectureChunks")
            .where("lectureId", "==", lectureId)
            .limit(1)
            .get(),
    ]);
    if (lecture.exists) {
        await lecture.ref.update({ hasContent: !chunk.empty });
    }
}
async function processMaterial(materialId, material) {
    const ref = db.doc(`materials/${materialId}`);
    const storagePath = material.storagePath;
    if (typeof storagePath !== "string" ||
        typeof material.uploadedBy !== "string" ||
        !storagePath.startsWith(`studyMaterials/${material.uploadedBy}/`)) {
        throw new Error("مسار الملف الدراسي غير صالح.");
    }
    const file = storage.bucket().file(storagePath);
    const [metadata] = await file.getMetadata();
    if (Number(metadata.size ?? 0) > maxMaterialBytes) {
        throw new Error("حجم الملف يتجاوز الحد المسموح به (30 ميجابايت).");
    }
    const [buffer] = await file.download();
    const filename = String(material.originalFilename ?? "");
    const extension = filename.split(".").pop()?.toLowerCase();
    const supportedExtensions = new Set(["pdf", "docx", "pptx", "txt"]);
    if (!extension || !supportedExtensions.has(extension)) {
        throw new Error("صيغة الملف غير مدعومة. استخدم PDF أو DOCX أو PPTX أو TXT.");
    }
    const rawText = extension === "txt" ?
        new TextDecoder("utf-8").decode(buffer) :
        (await (await officeparser_1.OfficeParser.parseOffice(buffer)).to("text")).value;
    const text = rawText.replace(/\u0000/g, " ").replace(/[ \t]+/g, " ").trim();
    if (!text)
        throw new Error("لم يتم العثور على نص قابل للاستخراج في الملف.");
    if (text.length > maxExtractedCharacters) {
        throw new Error("محتوى الملف أكبر من الحد المسموح للمعالجة.");
    }
    const current = await ref.get();
    if (!current.exists || current.get("storagePath") !== storagePath)
        return;
    const chunks = splitMaterialText(text);
    if (chunks.length === 0) {
        throw new Error("تعذر تقسيم محتوى الملف إلى أجزاء قابلة للبحث.");
    }
    const chunkRefs = chunks.map(() => db.collection("lectureChunks").doc());
    const lectureRef = typeof material.lectureId === "string" ?
        db.doc(`lectures/${material.lectureId}`) : null;
    await db.runTransaction(async (transaction) => {
        const [latest, lecture] = await Promise.all([
            transaction.get(ref),
            lectureRef ? transaction.get(lectureRef) : Promise.resolve(null),
        ]);
        if (!latest.exists ||
            latest.get("storagePath") !== storagePath ||
            latest.get("processingStatus") !== "PROCESSING") {
            return;
        }
        chunks.forEach((chunk, index) => {
            transaction.create(chunkRefs[index], {
                materialId,
                subjectId: material.subjectId,
                yearNumber: material.yearNumber,
                lectureId: material.lectureId,
                lectureNumber: material.lectureNumber ?? null,
                materialType: material.materialType ?? "lecture",
                sectionTitle: material.sectionTitle ?? "",
                sourceTitle: material.originalFilename || material.title,
                chunkIndex: index,
                text: chunk,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            });
        });
        transaction.update(ref, {
            processingStatus: "READY",
            processingError: "",
            processingCompletedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        if (lectureRef && lecture?.exists) {
            transaction.update(lectureRef, { hasContent: true });
        }
    });
}
exports.processAcademicMaterial = (0, firestore_2.onDocumentWritten)({ document: "materials/{materialId}", timeoutSeconds: 540, memory: "1GiB" }, async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    const materialId = event.params.materialId;
    if (!after?.exists) {
        await deleteMaterialChunks(materialId);
        await updateLectureContentFlag(before?.get("lectureId"));
        return;
    }
    const material = after.data();
    if (material?.processingStatus !== "UPLOADED")
        return;
    if (before?.exists &&
        before.get("processingStatus") === "UPLOADED" &&
        before.get("storagePath") === material.storagePath) {
        return;
    }
    const ref = db.doc(`materials/${materialId}`);
    const claimed = await db.runTransaction(async (transaction) => {
        const latest = await transaction.get(ref);
        if (!latest.exists || latest.get("processingStatus") !== "UPLOADED") {
            return false;
        }
        transaction.update(ref, {
            processingStatus: "PROCESSING",
            processingError: "",
            processingStartedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        return true;
    });
    if (!claimed)
        return;
    try {
        await deleteMaterialChunks(materialId);
        await updateLectureContentFlag(material.lectureId);
        await processMaterial(materialId, material);
    }
    catch (error) {
        console.error("Academic material processing failed.", {
            materialId,
            error,
        });
        const latest = await ref.get();
        if (!latest.exists ||
            latest.get("storagePath") !== material.storagePath ||
            latest.get("processingStatus") !== "PROCESSING") {
            return;
        }
        await deleteMaterialChunks(materialId);
        await updateLectureContentFlag(material.lectureId);
        const current = await ref.get();
        if (current.exists &&
            current.get("storagePath") === material.storagePath &&
            current.get("processingStatus") === "PROCESSING") {
            await ref.update({
                processingStatus: "FAILED",
                processingError: error instanceof Error ?
                    error.message.slice(0, 1000) : "تعذرت معالجة الملف.",
                processingCompletedAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
    }
});
async function ensureSubjectLectures(subjectId) {
    const sequenceRef = db.doc("_sequences/lectures");
    const initialSequence = await sequenceRef.get();
    let initialMax = Number(initialSequence.get("value") ?? 0);
    if (!initialSequence.exists) {
        const existing = await db.collection("lectures").get();
        for (const lecture of existing.docs) {
            const id = Number(lecture.id);
            if (Number.isSafeInteger(id))
                initialMax = Math.max(initialMax, id);
        }
    }
    await db.runTransaction(async (transaction) => {
        const lectureQuery = db.collection("lectures")
            .where("subjectId", "==", subjectId);
        const [lectures, sequence] = await Promise.all([
            transaction.get(lectureQuery),
            transaction.get(sequenceRef),
        ]);
        const existingNumbers = new Set(lectures.docs.map((lecture) => Number(lecture.get("lectureNumber"))));
        const missing = Array.from({ length: 16 }, (_, index) => index + 1)
            .filter((number) => !existingNumbers.has(number));
        if (missing.length === 0)
            return;
        let nextId = Math.max(initialMax, Number(sequence.get("value") ?? 0));
        for (const lectureNumber of missing) {
            nextId += 1;
            transaction.create(db.doc(`lectures/${nextId}`), {
                subjectId,
                title: `المحاضرة ${lectureNumber}`,
                lectureNumber,
                description: "",
                order: lectureNumber,
                hasContent: false,
                isActive: true,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        transaction.set(sequenceRef, { value: nextId }, { merge: true });
    });
}
async function createDailyChallenge(uid, profile) {
    const dateId = challengeDateId();
    const challengeRef = db.doc(`users/${uid}/dailyChallenges/${dateId}`);
    const generationToken = db.collection("_dailyChallengeTokens").doc().id;
    const claimed = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(challengeRef);
        const challenge = snapshot.data();
        if (challenge?.attemptId)
            return false;
        if (challenge?.generationState === "generating") {
            const updatedAt = challenge.updatedAt?.toDate?.();
            if (updatedAt && Date.now() - updatedAt.getTime() < 5 * 60 * 1000) {
                return false;
            }
        }
        transaction.set(challengeRef, {
            generationState: "generating",
            generationToken,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return true;
    });
    if (!claimed)
        return;
    try {
        let chunkQuery = db.collection("lectureChunks")
            .where("yearNumber", "==", profile.academicYear)
            .select("materialId", "subjectId", "lectureId", "sectionTitle", "sourceTitle")
            .limit(500);
        const candidates = new Map();
        while (true) {
            const page = await chunkQuery.get();
            for (const chunk of page.docs) {
                const data = chunk.data();
                if (typeof data.subjectId !== "string" ||
                    typeof data.lectureId !== "string")
                    continue;
                const sectionTitle = String(data.sectionTitle ?? "");
                const sourceTitle = String(data.sourceTitle ?? "");
                const materialId = typeof data.materialId === "string" ?
                    data.materialId : undefined;
                const groupId = materialId ??
                    `${data.lectureId}:${sectionTitle}:${sourceTitle}`;
                if (!candidates.has(groupId)) {
                    candidates.set(groupId, {
                        ...(materialId ? { materialId } : {}),
                        subjectId: data.subjectId,
                        lectureId: data.lectureId,
                        sectionTitle,
                        sourceTitle,
                    });
                }
            }
            if (page.size < 500)
                break;
            chunkQuery = db.collection("lectureChunks")
                .where("yearNumber", "==", profile.academicYear)
                .select("materialId", "subjectId", "lectureId", "sectionTitle", "sourceTitle")
                .startAfter(page.docs[page.docs.length - 1])
                .limit(500);
        }
        const sourceOptions = [...candidates.values()];
        if (sourceOptions.length === 0) {
            await db.runTransaction(async (transaction) => {
                const latest = await transaction.get(challengeRef);
                if (latest.get("generationToken") === generationToken) {
                    transaction.set(challengeRef, {
                        generationState: "unavailable",
                        message: "لا توجد ملفات دراسية جاهزة لهذه الفرقة حتى الآن.",
                        updatedAt: firestore_1.FieldValue.serverTimestamp(),
                    }, { merge: true });
                }
            });
            return;
        }
        const source = sourceOptions[Math.floor(Math.random() * sourceOptions.length)];
        const sourceChunkQuery = source.materialId ?
            db.collection("lectureChunks")
                .where("materialId", "==", source.materialId) :
            db.collection("lectureChunks")
                .where("yearNumber", "==", profile.academicYear)
                .where("lectureId", "==", source.lectureId)
                .where("sectionTitle", "==", source.sectionTitle)
                .where("sourceTitle", "==", source.sourceTitle);
        const sourceChunks = await sourceChunkQuery.limit(500).get();
        const selectedChunks = sourceChunks.docs
            .filter((chunk) => chunk.get("yearNumber") === profile.academicYear &&
            chunk.get("subjectId") === source.subjectId &&
            chunk.get("sectionTitle") === source.sectionTitle &&
            chunk.get("sourceTitle") === source.sourceTitle)
            .sort((left, right) => Number(left.get("chunkIndex") ?? 0) -
            Number(right.get("chunkIndex") ?? 0));
        if (selectedChunks.length === 0) {
            throw new Error("تعذر تحميل محتوى المصدر المختار للتحدي.");
        }
        const subjectSnapshot = await db.doc(`subjects/${source.subjectId}`).get();
        const lectureSnapshot = await db.doc(`lectures/${source.lectureId}`).get();
        if (!subjectSnapshot.exists || !lectureSnapshot.exists ||
            subjectSnapshot.get("yearNumber") !== profile.academicYear ||
            lectureSnapshot.get("subjectId") !== source.subjectId) {
            throw new Error("المادة أو المحاضرة المرتبطة بالمحتوى غير موجودة.");
        }
        const sectionTitle = source.sectionTitle;
        const sourceText = selectedChunks.map((chunk) => chunk.get("text"))
            .filter((text) => typeof text === "string")
            .join("\n")
            .slice(0, 24000);
        const questions = await generateQuestions(sourceText, String(subjectSnapshot.get("name") ?? "مادة"), String(lectureSnapshot.get("title") ?? "محاضرة"), 5, "medium", sectionTitle);
        if (questions.length !== 5) {
            throw new Error("لم يتمكن الذكاء الاصطناعي من إنشاء خمسة أسئلة صالحة.");
        }
        const questionRefs = questions.map(() => db.collection("questionBank").doc());
        const attemptRef = db.collection("quizAttempts").doc();
        await db.runTransaction(async (transaction) => {
            const latestChallenge = await transaction.get(challengeRef);
            if (latestChallenge.get("generationToken") !== generationToken ||
                latestChallenge.get("generationState") !== "generating") {
                return;
            }
            questions.forEach((question, index) => {
                transaction.create(questionRefs[index], {
                    ...question,
                    subjectId: source.subjectId,
                    lectureId: source.lectureId,
                    difficulty: "medium",
                    sourceTitle: source.sourceTitle,
                    sectionTitle,
                    createdAt: firestore_1.FieldValue.serverTimestamp(),
                });
            });
            transaction.create(attemptRef, {
                uid,
                subjectId: source.subjectId,
                subjectName: subjectSnapshot.get("name"),
                lectureId: source.lectureId,
                lectureNumber: lectureSnapshot.get("lectureNumber"),
                sectionTitle,
                difficulty: "medium",
                totalQuestions: questions.length,
                questionIds: questionRefs.map((ref) => ref.id),
                dailyChallenge: true,
                dailyChallengeDate: dateId,
                score: 0,
                earnedXp: 0,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
                completedAt: null,
            });
            transaction.set(challengeRef, {
                attemptId: attemptRef.id,
                subjectId: source.subjectId,
                subjectName: subjectSnapshot.get("name"),
                lectureId: source.lectureId,
                lectureNumber: lectureSnapshot.get("lectureNumber"),
                sectionTitle,
                sourceTitle: source.sourceTitle,
                generationState: "ready",
                startedAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        });
    }
    catch (error) {
        console.error("Daily challenge generation failed.", { uid, dateId, error });
        await db.runTransaction(async (transaction) => {
            const latest = await transaction.get(challengeRef);
            if (latest.get("generationToken") === generationToken &&
                !latest.get("attemptId")) {
                transaction.set(challengeRef, {
                    generationState: "failed",
                    message: error instanceof Error ?
                        error.message.slice(0, 300) : "تعذر إعداد التحدي اليومي.",
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        });
        throw new https_1.HttpsError("failed-precondition", error instanceof Error ? error.message : "تعذر إعداد التحدي اليومي.");
    }
}
exports.firebaseApi = (0, https_1.onCall)({ timeoutSeconds: 540, memory: "1GiB" }, async (request) => {
    const uid = requireUid(request.auth?.uid);
    const method = String(request.data.method ?? "").toUpperCase();
    const path = String(request.data.path ?? "");
    const query = (request.data.query ?? {});
    const body = (request.data.body ?? {});
    const profileRef = db.doc(`users/${uid}`);
    const profileSnapshot = await profileRef.get();
    const profile = profileSnapshot.data();
    if (!profile)
        throw new https_1.HttpsError("failed-precondition", "ملف الحساب غير موجود.");
    const isOwner = request.auth?.token.owner === true;
    const respond = (bodyValue, statusCode = 200) => ({ body: bodyValue, status_code: statusCode });
    const requireOwner = () => {
        if (!isOwner)
            throw new https_1.HttpsError("permission-denied", "هذه العملية للمالك فقط.");
    };
    const mapDocs = (snapshot) => snapshot.docs.map((doc) => ({
        id: /^\d+$/.test(doc.id) ? Number(doc.id) : doc.id,
        ...toClientData(doc.data()),
    }));
    const nextNumericId = async (key) => {
        const ref = db.doc(`_sequences/${key}`);
        let next = 0;
        await db.runTransaction(async (transaction) => {
            const snapshot = await transaction.get(ref);
            next = (snapshot.get("value") ?? 0) + 1;
            transaction.set(ref, { value: next });
        });
        return next;
    };
    if (method === "GET" && path === "/api/auth/me/") {
        return respond(toClientData(profile));
    }
    if (method === "PATCH" && path === "/api/auth/me/") {
        const username = body.username;
        const fullName = body.full_name;
        const profilePicture = body.profile_picture;
        if (username !== undefined &&
            (typeof username !== "string" || !validUsername.test(username.trim()))) {
            throw new https_1.HttpsError("invalid-argument", "اسم المستخدم غير صالح.");
        }
        if (fullName !== undefined && typeof fullName !== "string") {
            throw new https_1.HttpsError("invalid-argument", "الاسم الكامل غير صالح.");
        }
        if (profilePicture !== undefined && typeof profilePicture !== "string") {
            throw new https_1.HttpsError("invalid-argument", "الصورة الشخصية غير صالحة.");
        }
        const update = {
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        };
        if (fullName !== undefined)
            update.fullName = fullName.trim().slice(0, 150);
        if (profilePicture !== undefined)
            update.profilePicture = profilePicture;
        if (typeof username === "string" && username.trim() !== profile.username) {
            const normalized = username.trim();
            const nextUsernameRef = db.doc(`usernames/${normalized.toLowerCase()}`);
            const previousUsernameRef = db.doc(`usernames/${String(profile.username).toLowerCase()}`);
            await db.runTransaction(async (transaction) => {
                const taken = await transaction.get(nextUsernameRef);
                if (taken.exists && taken.get("uid") !== uid) {
                    throw new https_1.HttpsError("already-exists", "اسم المستخدم مستخدم بالفعل.");
                }
                transaction.set(nextUsernameRef, { uid });
                transaction.delete(previousUsernameRef);
                transaction.update(profileRef, { ...update, username: normalized });
            });
        }
        else {
            await profileRef.update(update);
        }
        return respond(toClientData((await profileRef.get()).data() ?? {}));
    }
    if (method === "GET" && path === "/api/academic/years/") {
        const years = await db.collection("academicYears").orderBy("order").get();
        return respond(mapDocs(years));
    }
    if (method === "GET" && path === "/api/academic/subjects/") {
        let subjects = db.collection("subjects").orderBy("order");
        if (query.year) {
            const year = Number(query.year);
            subjects = subjects.where("yearNumber", "==", year);
        }
        else if (!isOwner) {
            subjects = subjects.where("yearNumber", "==", profile.academicYear);
        }
        const snapshot = await subjects.get();
        await Promise.all(snapshot.docs.map((doc) => ensureSubjectLectures(doc.id)));
        return respond(snapshot.docs.map((doc) => ({
            id: /^\d+$/.test(doc.id) ? Number(doc.id) : doc.id,
            ...toClientData(doc.data()),
            lecture_count: 16,
        })));
    }
    if (method === "GET" && path === "/api/academic/lectures/") {
        if (query.subject_id) {
            const subject = await db.doc(`subjects/${query.subject_id}`).get();
            if (subject.exists) {
                await ensureSubjectLectures(subject.id);
            }
        }
        let lectures = db.collection("lectures").orderBy("order");
        if (query.subject_id)
            lectures = lectures.where("subjectId", "==", query.subject_id);
        return respond(mapDocs(await lectures.get()));
    }
    if (method === "GET" && path === "/api/academic/student/hierarchy/") {
        const subjectSnapshot = await db.collection("subjects")
            .where("yearNumber", "==", profile.academicYear)
            .get();
        const subjects = await Promise.all(subjectSnapshot.docs.map(async (doc) => {
            await ensureSubjectLectures(doc.id);
            const lectures = await db.collection("lectures")
                .where("subjectId", "==", doc.id)
                .orderBy("order")
                .get();
            return {
                id: /^\d+$/.test(doc.id) ? Number(doc.id) : doc.id,
                name: doc.get("name"),
                lecture_count: lectures.size,
                lectures: lectures.docs.map((lecture) => ({
                    id: /^\d+$/.test(lecture.id) ? Number(lecture.id) : lecture.id,
                    title: lecture.get("title"),
                    lecture_number: lecture.get("lectureNumber"),
                    has_content: lecture.get("hasContent") === true,
                })),
            };
        }));
        return respond({ subjects });
    }
    if (method === "GET" && path === "/api/academic/materials/") {
        let materials = db.collection("materials").orderBy("uploadedAt", "desc");
        if (query.subject_id) {
            materials = materials.where("subjectId", "==", query.subject_id);
        }
        return respond(mapDocs(await materials.get()));
    }
    if (method === "POST" && path === "/api/academic/materials/upload/") {
        requireOwner();
        const subjectId = String(body.subject_id ?? "");
        const yearNumber = Number(body.academic_year_id);
        const lectureId = body.lecture_id == null ? null : String(body.lecture_id);
        const materialType = body.material_type ?? "lecture";
        if (materialType !== "lecture" && materialType !== "section") {
            throw new https_1.HttpsError("invalid-argument", "نوع المحتوى المرفوع غير صالح.");
        }
        const sectionTitle = typeof body.section_title === "string" ?
            body.section_title.trim().slice(0, 200) : "";
        const files = body.files;
        if (!Array.isArray(files) || files.length === 0 || files.length > 20) {
            throw new https_1.HttpsError("invalid-argument", "اختر ملفًا واحدًا على الأقل.");
        }
        const subject = await db.doc(`subjects/${subjectId}`).get();
        if (!subject.exists || subject.get("yearNumber") !== yearNumber) {
            throw new https_1.HttpsError("invalid-argument", "المادة أو الفرقة غير صالحة.");
        }
        if (materialType === "section" && (!lectureId || !sectionTitle)) {
            throw new https_1.HttpsError("invalid-argument", "اختر محاضرة واكتب اسم السكشن قبل رفعه.");
        }
        if (!lectureId) {
            throw new https_1.HttpsError("invalid-argument", "اختر المحاضرة المرتبطة بالملف.");
        }
        const lecture = await db.doc(`lectures/${lectureId}`).get();
        if (!lecture.exists || lecture.get("subjectId") !== subjectId) {
            throw new https_1.HttpsError("invalid-argument", "المحاضرة لا تتبع المادة المحددة.");
        }
        const lectureNumber = Number(lecture.get("lectureNumber"));
        const created = [];
        for (const file of files) {
            if (!file || typeof file.path !== "string" ||
                !file.path.startsWith(`studyMaterials/${uid}/`) ||
                typeof file.filename !== "string" ||
                !Number.isInteger(file.size) || file.size < 1 ||
                file.size > maxMaterialBytes ||
                !["pdf", "docx", "pptx", "txt"].includes(file.filename.split(".").pop()?.toLowerCase() ?? "")) {
                throw new https_1.HttpsError("invalid-argument", "بيانات الملف المرفوع غير صالحة.");
            }
            const materialId = String(await nextNumericId("materials"));
            const ref = db.doc(`materials/${materialId}`);
            const title = files.length === 1 &&
                typeof body.title === "string" && body.title.trim() ?
                body.title.trim().slice(0, 150) : file.filename;
            await ref.create({
                title,
                originalFilename: file.filename.slice(0, 255),
                subjectId,
                yearNumber,
                lectureId,
                lectureNumber,
                materialType,
                sectionTitle,
                storagePath: file.path,
                size: file.size,
                contentType: String(file.contentType ?? "application/octet-stream"),
                processingStatus: "UPLOADED",
                processingError: "",
                uploadedBy: uid,
                uploadedAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
            created.push({ id: Number(materialId), title });
        }
        return respond({ results: created }, 201);
    }
    const materialDownload = path.match(/^\/api\/academic\/materials\/([^/]+)\/download\/$/);
    if (method === "GET" && materialDownload) {
        const material = await db.doc(`materials/${materialDownload[1]}`).get();
        if (!material.exists)
            throw new https_1.HttpsError("not-found", "الملف غير موجود.");
        return respond({ storage_path: material.get("storagePath") });
    }
    const materialAction = path.match(/^\/api\/academic\/materials\/([^/]+)\/(retry|replace)?\/?$/);
    if (materialAction && method === "POST" && materialAction[2] === "retry") {
        requireOwner();
        const ref = db.doc(`materials/${materialAction[1]}`);
        const material = await ref.get();
        if (!material.exists)
            throw new https_1.HttpsError("not-found", "الملف غير موجود.");
        if (material.get("processingStatus") !== "FAILED") {
            throw new https_1.HttpsError("failed-precondition", "يمكن إعادة معالجة الملفات التي فشلت فقط.");
        }
        await ref.update({
            processingStatus: "UPLOADED",
            processingError: "",
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        return respond({ id: materialAction[1], processing_status: "UPLOADED" });
    }
    if (materialAction && method === "POST" && materialAction[2] === "replace") {
        requireOwner();
        const file = Array.isArray(body.files) ? body.files[0] : null;
        if (!file || typeof file.path !== "string" ||
            !file.path.startsWith(`studyMaterials/${uid}/`) ||
            typeof file.filename !== "string" ||
            !Number.isInteger(file.size) || file.size < 1 ||
            file.size > maxMaterialBytes ||
            !["pdf", "docx", "pptx", "txt"].includes(file.filename.split(".").pop()?.toLowerCase() ?? "")) {
            throw new https_1.HttpsError("invalid-argument", "بيانات الملف البديل غير صالحة.");
        }
        const ref = db.doc(`materials/${materialAction[1]}`);
        const material = await ref.get();
        if (!material.exists)
            throw new https_1.HttpsError("not-found", "الملف غير موجود.");
        const oldPath = material.get("storagePath");
        await ref.update({
            originalFilename: file.filename.slice(0, 255),
            storagePath: file.path,
            size: file.size,
            contentType: String(file.contentType ?? "application/octet-stream"),
            processingStatus: "UPLOADED",
            processingError: "",
            processingStartedAt: null,
            processingCompletedAt: null,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        if (typeof oldPath === "string")
            await storage.bucket().file(oldPath).delete();
        return respond({ id: materialAction[1], processing_status: "awaiting_processing" });
    }
    if (materialAction && method === "DELETE") {
        requireOwner();
        const ref = db.doc(`materials/${materialAction[1]}`);
        const material = await ref.get();
        if (!material.exists)
            throw new https_1.HttpsError("not-found", "الملف غير موجود.");
        const storagePath = material.get("storagePath");
        if (typeof storagePath === "string") {
            await storage.bucket().file(storagePath).delete();
        }
        await ref.delete();
        return respond({}, 204);
    }
    if (method === "GET" && path === "/api/auth/quizzes/availability/") {
        const subjectName = query.subject ?? "";
        const lectureNumber = Number(query.lecture);
        const subject = await db.collection("subjects")
            .where("yearNumber", "==", profile.academicYear)
            .where("name", "==", subjectName)
            .limit(1)
            .get();
        if (subject.empty || !Number.isInteger(lectureNumber)) {
            return respond({ available: false });
        }
        const lecture = await db.collection("lectures")
            .where("subjectId", "==", subject.docs[0].id)
            .where("lectureNumber", "==", lectureNumber)
            .limit(1)
            .get();
        if (lecture.empty)
            return respond({ available: false });
        const [questions, chunks] = await Promise.all([
            db.collection("questionBank")
                .where("subjectId", "==", subject.docs[0].id)
                .where("lectureId", "==", lecture.docs[0].id)
                .limit(1)
                .get(),
            db.collection("lectureChunks")
                .where("subjectId", "==", subject.docs[0].id)
                .where("lectureId", "==", lecture.docs[0].id)
                .limit(1)
                .get(),
        ]);
        return respond({ available: !questions.empty || !chunks.empty });
    }
    if (method === "GET" && path === "/api/auth/owner/dashboard/") {
        requireOwner();
        const [students, activeStudents, subjects, lectures, materials, questions] = await Promise.all([
            db.collection("users").where("role", "==", "student").count().get(),
            db.collection("users").where("role", "==", "student")
                .where("studentStatus", "==", "active").count().get(),
            db.collection("subjects").count().get(),
            db.collection("lectures").count().get(),
            db.collection("materials").count().get(),
            db.collection("questionBank").count().get(),
        ]);
        return respond({
            owner: { username: profile.username },
            metrics: {
                total_students: students.data().count,
                active_students: activeStudents.data().count,
                total_subjects: subjects.data().count,
                total_lectures: lectures.data().count,
                total_files: materials.data().count,
                total_questions: questions.data().count,
                total_summaries: 0,
            },
        });
    }
    if (method === "GET" && path === "/api/auth/owner/students/") {
        requireOwner();
        const search = (query.search ?? "").trim().toLowerCase();
        const status = query.status ?? "";
        const page = Math.max(1, Number(query.page) || 1);
        const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 25));
        const snapshot = await db.collection("users")
            .where("role", "==", "student")
            .get();
        const filtered = snapshot.docs.filter((doc) => {
            const data = doc.data();
            const matchesStatus = !status ||
                (status === "active" ? data.studentStatus === "active" :
                    data.studentStatus !== "active");
            const searchable = [
                data.username,
                data.fullName,
                data.universityId,
            ].join(" ").toLowerCase();
            return matchesStatus && (!search || searchable.includes(search));
        });
        const offset = (page - 1) * pageSize;
        return respond({
            count: filtered.length,
            results: filtered.slice(offset, offset + pageSize).map((doc) => ({
                id: doc.id,
                uid: doc.id,
                username: doc.get("username"),
                full_name: doc.get("fullName") ?? "",
                university_id: doc.get("universityId") ?? "",
                is_active: doc.get("studentStatus") === "active",
                student_status: doc.get("studentStatus"),
            })),
        });
    }
    const studentStatusMatch = path.match(/^\/api\/auth\/owner\/students\/([^/]+)\/status\/$/);
    if (method === "POST" && studentStatusMatch) {
        requireOwner();
        if (typeof body.is_active !== "boolean") {
            throw new https_1.HttpsError("invalid-argument", "حالة الطالب غير صالحة.");
        }
        const studentRef = db.doc(`users/${studentStatusMatch[1]}`);
        const student = await studentRef.get();
        if (!student.exists || student.get("role") !== "student") {
            throw new https_1.HttpsError("not-found", "الطالب غير موجود.");
        }
        const studentStatus = body.is_active ? "active" : "suspended";
        await studentRef.update({
            studentStatus,
            statusReason: String(body.reason ?? "").slice(0, 300),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        return respond({
            id: student.id,
            is_active: body.is_active,
            student_status: studentStatus,
        });
    }
    if (method === "GET" && path === "/api/study/reports/") {
        const days = Math.min(90, Math.max(1, Number(query.days) || 7));
        const since = new Date();
        since.setUTCDate(since.getUTCDate() - days);
        const attempts = await db.collection("quizAttempts")
            .where("uid", "==", uid)
            .where("completedAt", ">=", since)
            .orderBy("completedAt", "desc")
            .limit(200)
            .get();
        const results = attempts.docs.map((doc) => doc.data());
        const correctAnswers = results.reduce((total, attempt) => total + Number(attempt.score ?? 0), 0);
        const totalQuestions = results.reduce((total, attempt) => total + Number(attempt.totalQuestions ?? 0), 0);
        const subjectStats = new Map();
        const lectureStats = new Map();
        const focusStats = new Map();
        const answerSnapshots = await Promise.all(attempts.docs.map((attempt) => attempt.ref.collection("answers").get()));
        attempts.docs.forEach((attemptDoc, index) => {
            const attempt = attemptDoc.data();
            const subject = String(attempt.subjectName ?? "مادة غير معروفة");
            const lecture = Number(attempt.lectureNumber ?? 0);
            const subjectId = String(attempt.subjectId ?? subject);
            const lectureId = String(attempt.lectureId ?? lecture);
            const subjectRow = subjectStats.get(subjectId) ?? {
                subject,
                quizzes: 0,
                questions: 0,
                correct: 0,
            };
            subjectRow.quizzes += 1;
            subjectRow.questions += Number(attempt.totalQuestions ?? 0);
            subjectRow.correct += Number(attempt.score ?? 0);
            subjectStats.set(subjectId, subjectRow);
            const lectureKey = `${subjectId}:${lectureId}`;
            const lectureRow = lectureStats.get(lectureKey) ?? {
                subject,
                lecture,
                quizzes: 0,
                questions: 0,
                correct: 0,
            };
            lectureRow.quizzes += 1;
            lectureRow.questions += Number(attempt.totalQuestions ?? 0);
            lectureRow.correct += Number(attempt.score ?? 0);
            lectureStats.set(lectureKey, lectureRow);
            for (const answerDoc of answerSnapshots[index].docs) {
                const answer = answerDoc.data();
                if (answer.isCorrect === true)
                    continue;
                const topic = String(answer.topic || answer.sectionTitle || answer.sourceTitle ||
                    "موضوع يحتاج مراجعة");
                const focusKey = `${lectureKey}:${topic}`;
                const focusRow = focusStats.get(focusKey) ?? {
                    subject,
                    lecture,
                    topic,
                    incorrect: 0,
                };
                focusRow.incorrect += 1;
                focusStats.set(focusKey, focusRow);
            }
        });
        const accuracy = (row) => row.questions ? Math.round(row.correct / row.questions * 100) : 0;
        const subjects = [...subjectStats.values()]
            .map((row) => ({ ...row, accuracy: accuracy(row) }))
            .sort((left, right) => right.accuracy - left.accuracy);
        const lectures = [...lectureStats.values()]
            .map((row) => ({ ...row, accuracy: accuracy(row) }))
            .sort((left, right) => left.accuracy - right.accuracy);
        return respond({
            days,
            summary: {
                quizzes: results.length,
                questions: totalQuestions,
                correct: correctAnswers,
                xp: results.reduce((total, attempt) => total + Number(attempt.earnedXp ?? 0), 0),
                accuracy_percent: totalQuestions ?
                    Math.round(correctAnswers / totalQuestions * 100) : 0,
                active_days: new Set(results.map((attempt) => attempt.completedAt
                    ?.toDate?.().toISOString().slice(0, 10) ?? "")).size,
            },
            subjects,
            lectures,
            focus_areas: [...focusStats.values()]
                .sort((left, right) => right.incorrect - left.incorrect)
                .slice(0, 10),
        });
    }
    if (method === "GET" && path === "/api/study/daily-challenge/") {
        const dateId = challengeDateId();
        const snapshot = await db.doc(`users/${uid}/dailyChallenges/${dateId}`).get();
        const challenge = snapshot.data();
        if (!challenge) {
            return respond({
                date: dateId,
                goal_questions: 5,
                bonus_xp: 0,
                started: false,
                completed: false,
                quiz: null,
            });
        }
        return respond({
            date: dateId,
            goal_questions: 5,
            bonus_xp: 0,
            started: Boolean(challenge.attemptId),
            completed: Boolean(challenge.completedAt),
            quiz: null,
        });
    }
    if (method === "GET" && path === "/api/study/review/") {
        const items = await db.collection(`users/${uid}/reviewItems`)
            .orderBy("attemptedAt", "desc")
            .limit(100)
            .get();
        const results = mapDocs(items);
        return respond({
            count: results.filter((item) => !item.reviewedAt).length,
            results,
        });
    }
    if (method === "POST" && path.match(/^\/api\/study\/review\/[^/]+\/mark\/$/)) {
        const itemId = path.split("/")[4];
        const ref = db.doc(`users/${uid}/reviewItems/${itemId}`);
        const item = await ref.get();
        if (!item.exists)
            throw new https_1.HttpsError("not-found", "عنصر المراجعة غير موجود.");
        await ref.update({
            reviewedAt: firestore_1.FieldValue.serverTimestamp(),
            reviewCount: firestore_1.FieldValue.increment(1),
        });
        const updated = (await ref.get()).data() ?? {};
        return respond({
            id: itemId,
            reviewed: true,
            review_count: updated.reviewCount,
        });
    }
    if (path === "/api/study/plans/" && method === "GET") {
        const plans = await db.collection(`users/${uid}/studyPlans`)
            .orderBy("createdAt", "desc")
            .get();
        return respond(mapDocs(plans));
    }
    if (path === "/api/study/plans/" && method === "POST") {
        const title = typeof body.title === "string" ? body.title.trim() : "";
        const target = Number(body.target_minutes_per_day ?? 30);
        const sessions = Number(body.sessions_per_week ?? 5);
        const startDate = String(body.start_date ?? "");
        if (!title || title.length > 120 || !Number.isInteger(target) ||
            target < 5 || target > 600 || !Number.isInteger(sessions) ||
            sessions < 1 || sessions > 7 || !/^\d{4}-\d{2}-\d{2}$/.test(startDate)) {
            throw new https_1.HttpsError("invalid-argument", "بيانات خطة المذاكرة غير صالحة.");
        }
        const ref = db.collection(`users/${uid}/studyPlans`).doc();
        await ref.create({
            title,
            subjectId: body.subject ?? null,
            targetMinutesPerDay: target,
            sessionsPerWeek: sessions,
            startDate,
            endDate: body.end_date ?? null,
            notes: String(body.notes ?? "").slice(0, 500),
            isActive: true,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        return respond({ id: ref.id, ...toClientData((await ref.get()).data() ?? {}) }, 201);
    }
    const planMatch = path.match(/^\/api\/study\/plans\/([^/]+)\/$/);
    if (planMatch && method === "PATCH") {
        const ref = db.doc(`users/${uid}/studyPlans/${planMatch[1]}`);
        const existing = await ref.get();
        if (!existing.exists)
            throw new https_1.HttpsError("not-found", "الخطة غير موجودة.");
        const mapping = {
            title: "title",
            subject: "subjectId",
            target_minutes_per_day: "targetMinutesPerDay",
            sessions_per_week: "sessionsPerWeek",
            start_date: "startDate",
            end_date: "endDate",
            notes: "notes",
            is_active: "isActive",
        };
        const update = {};
        for (const [key, value] of Object.entries(body)) {
            if (!mapping[key])
                throw new https_1.HttpsError("invalid-argument", "حقل خطة غير معروف.");
            update[mapping[key]] = value;
        }
        update.updatedAt = firestore_1.FieldValue.serverTimestamp();
        await ref.update(update);
        return respond({ id: ref.id, ...toClientData((await ref.get()).data() ?? {}) });
    }
    if (planMatch && method === "DELETE") {
        await db.doc(`users/${uid}/studyPlans/${planMatch[1]}`).delete();
        return respond({}, 204);
    }
    if (method === "GET" && path === "/api/study/preferences/") {
        const snapshot = await db.doc(`users/${uid}/preferences/settings`).get();
        const settings = snapshot.data() ?? {};
        return respond({
            notifications_enabled: settings.notificationsEnabled ?? true,
            daily_challenge_reminders: settings.dailyChallengeReminders ?? true,
            weekly_progress_reports: settings.weeklyProgressReports ?? true,
            study_goal_minutes: settings.studyGoalMinutes ?? 60,
            updated_at: toClientData(settings).updatedAt ?? null,
        });
    }
    if (method === "PATCH" && path === "/api/study/preferences/") {
        const mapping = {
            notifications_enabled: "notificationsEnabled",
            daily_challenge_reminders: "dailyChallengeReminders",
            weekly_progress_reports: "weeklyProgressReports",
            study_goal_minutes: "studyGoalMinutes",
        };
        const update = {};
        for (const [key, value] of Object.entries(body)) {
            if (!mapping[key])
                throw new https_1.HttpsError("invalid-argument", "إعداد غير معروف.");
            update[mapping[key]] = value;
        }
        update.updatedAt = firestore_1.FieldValue.serverTimestamp();
        const ref = db.doc(`users/${uid}/preferences/settings`);
        await ref.set(update, { merge: true });
        const settings = (await ref.get()).data() ?? {};
        return respond({
            notifications_enabled: settings.notificationsEnabled ?? true,
            daily_challenge_reminders: settings.dailyChallengeReminders ?? true,
            weekly_progress_reports: settings.weeklyProgressReports ?? true,
            study_goal_minutes: settings.studyGoalMinutes ?? 60,
            updated_at: toClientData(settings).updatedAt ?? null,
        });
    }
    if (method === "GET" && path === "/api/study/notifications/") {
        const notifications = await db.collection(`users/${uid}/notifications`)
            .orderBy("createdAt", "desc")
            .limit(100)
            .get();
        const results = mapDocs(notifications).map((item) => ({
            ...item,
            type: item.type ?? "general",
            is_read: item.is_read ?? false,
        }));
        return respond({
            unread_count: results.filter((item) => !item.is_read).length,
            results,
        });
    }
    if (method === "POST" && path === "/api/study/notifications/read-all/") {
        const unread = await db.collection(`users/${uid}/notifications`)
            .where("isRead", "==", false)
            .get();
        const batch = db.batch();
        for (const doc of unread.docs) {
            batch.update(doc.ref, { isRead: true, readAt: firestore_1.FieldValue.serverTimestamp() });
        }
        await batch.commit();
        return respond({ updated: unread.size });
    }
    const readNotification = path.match(/^\/api\/study\/notifications\/([^/]+)\/read\/$/);
    if (method === "POST" && readNotification) {
        const ref = db.doc(`users/${uid}/notifications/${readNotification[1]}`);
        await ref.update({ isRead: true, readAt: firestore_1.FieldValue.serverTimestamp() });
        return respond({ id: readNotification[1], is_read: true });
    }
    if (method === "GET" && path === "/api/auth/leaderboard/") {
        const year = Number(query.year ?? profile.academicYear);
        const leaders = await db.collection("users")
            .where("role", "==", "student")
            .where("academicYear", "==", year)
            .where("studentStatus", "==", "active")
            .orderBy("xpPoints", "desc")
            .limit(10)
            .get();
        return respond({
            leaderboard: leaders.docs.map((doc, index) => ({
                id: doc.id,
                rank: index + 1,
                username: doc.get("username"),
                full_name: doc.get("fullName") ?? "",
                university_id: doc.get("universityId") ?? "",
                xp_points: doc.get("xpPoints") ?? 0,
                xp: doc.get("xpPoints") ?? 0,
            })),
        });
    }
    const academicCollections = {
        "/api/academic/years/": "academicYears",
        "/api/academic/subjects/": "subjects",
        "/api/academic/lectures/": "lectures",
    };
    const academicItem = path.match(/^\/api\/academic\/(years|subjects|lectures)\/([^/]+)\/$/);
    if (method === "POST" && academicCollections[path]) {
        requireOwner();
        const collection = academicCollections[path];
        const data = academicDocument(collection, body);
        const documentId = collection === "academicYears" ?
            String(data.yearNumber) : String(await nextNumericId(collection));
        const ref = db.collection(collection).doc(documentId);
        await ref.create({ ...data, createdAt: firestore_1.FieldValue.serverTimestamp() });
        return respond({
            id: Number.isSafeInteger(Number(ref.id)) ? Number(ref.id) : ref.id,
            ...toClientData((await ref.get()).data() ?? {}),
        }, 201);
    }
    if (academicItem) {
        requireOwner();
        const collection = academicCollections[`/api/academic/${academicItem[1]}/`];
        const ref = db.doc(`${collection}/${academicItem[2]}`);
        if (method === "PATCH") {
            await ref.update({
                ...academicDocument(collection, body, true),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
            return respond({
                id: /^\d+$/.test(ref.id) ? Number(ref.id) : ref.id,
                ...toClientData((await ref.get()).data() ?? {}),
            });
        }
        if (method === "DELETE") {
            await ref.delete();
            return respond({}, 204);
        }
    }
    throw new https_1.HttpsError("unimplemented", `Firebase migration for ${method} ${path} is not configured yet.`);
});
exports.getDailyChallenge = (0, https_1.onCall)({
    secrets: [geminiApiKey],
    timeoutSeconds: 120,
}, async (request) => {
    const uid = requireUid(request.auth?.uid);
    const profile = (await db.doc(`users/${uid}`).get()).data();
    if (!profile || profile.role !== "student" ||
        profile.studentStatus === "suspended") {
        throw new https_1.HttpsError("permission-denied", "الحساب غير متاح للتحدي اليومي.");
    }
    const dateId = challengeDateId();
    const challengeRef = db.doc(`users/${uid}/dailyChallenges/${dateId}`);
    await createDailyChallenge(uid, profile);
    const snapshot = await challengeRef.get();
    const challenge = snapshot.data() ?? {};
    const attemptId = challenge.attemptId;
    const attemptSnapshot = attemptId ?
        await db.doc(`quizAttempts/${attemptId}`).get() : null;
    const attempt = attemptSnapshot?.data();
    let quiz = null;
    if (attempt && !challenge.completedAt) {
        const questions = await Promise.all(attempt.questionIds.map(async (id) => {
            const question = (await db.doc(`questionBank/${id}`).get()).data();
            if (!question)
                return null;
            return {
                id,
                question: question.question,
                options: question.options,
            };
        }));
        if (questions.some((question) => question === null)) {
            throw new https_1.HttpsError("failed-precondition", "تعذر تحميل جميع أسئلة التحدي اليومي.");
        }
        quiz = {
            quiz_id: attemptId,
            subject: attempt.subjectName,
            lecture: attempt.lectureNumber,
            difficulty: attempt.difficulty,
            count: attempt.questionIds.length,
            questions,
        };
    }
    return {
        date: dateId,
        goal_questions: 5,
        bonus_xp: 0,
        available: challenge.generationState === "ready",
        generation_state: challenge.generationState ?? "generating",
        message: challenge.message ?? "",
        started: challenge.participationStarted === true,
        completed: Boolean(challenge.completedAt),
        completed_at: challenge.completedAt?.toDate().toISOString() ?? null,
        score: attempt?.score ?? 0,
        total_questions: attempt?.totalQuestions ?? 0,
        subject: attempt?.subjectName ?? challenge.subjectName ?? null,
        lecture: attempt?.lectureNumber ?? challenge.lectureNumber ?? null,
        section_title: challenge.sectionTitle ?? "",
        source_title: challenge.sourceTitle ?? "",
        quiz,
    };
});
exports.startQuiz = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    const uid = requireUid(request.auth?.uid);
    const { subjectId, lectureId, count, difficulty, dailyChallenge = false } = request.data;
    if (typeof subjectId !== "string" || typeof lectureId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "المادة أو المحاضرة غير صالحة.");
    }
    if (!Number.isInteger(count) || ![5, 10, 20, 25, 30, 35, 40, 50, 100].includes(count)) {
        throw new https_1.HttpsError("invalid-argument", "عدد الأسئلة المختار غير صالح.");
    }
    if (!["easy", "medium", "hard"].includes(String(difficulty))) {
        throw new https_1.HttpsError("invalid-argument", "مستوى الصعوبة غير صالح.");
    }
    if (typeof dailyChallenge !== "boolean" || (dailyChallenge && count !== 5)) {
        throw new https_1.HttpsError("invalid-argument", "التحدي اليومي يتكون من 5 أسئلة.");
    }
    const [profileSnapshot, subjectSnapshot, lectureSnapshot] = await Promise.all([
        db.doc(`users/${uid}`).get(),
        db.doc(`subjects/${subjectId}`).get(),
        db.doc(`lectures/${lectureId}`).get(),
    ]);
    const profile = profileSnapshot.data();
    const subject = subjectSnapshot.data();
    const lecture = lectureSnapshot.data();
    if (!profile || profile.studentStatus === "suspended") {
        throw new https_1.HttpsError("permission-denied", "الحساب غير متاح.");
    }
    if (!subject || !lecture || lecture.subjectId !== subjectId) {
        throw new https_1.HttpsError("not-found", "المادة أو المحاضرة غير موجودة.");
    }
    if (profile.role === "student" && profile.academicYear !== subject.yearNumber) {
        throw new https_1.HttpsError("permission-denied", "المادة لا تتبع فرقتك الدراسية.");
    }
    let questionSnapshot = await db.collection("questionBank")
        .where("subjectId", "==", subjectId)
        .where("lectureId", "==", lectureId)
        .where("difficulty", "==", difficulty)
        .limit(count)
        .get();
    if (questionSnapshot.size < count) {
        const chunks = await db.collection("lectureChunks")
            .where("subjectId", "==", subjectId)
            .where("lectureId", "==", lectureId)
            .limit(30)
            .get();
        if (chunks.empty || !geminiApiKey.value()) {
            throw new https_1.HttpsError("failed-precondition", "لا تتوفر أسئلة كافية أو محتوى لهذه المحاضرة.");
        }
        const sourceText = chunks.docs.map((doc) => doc.get("text"))
            .filter((text) => typeof text === "string")
            .join("\n")
            .slice(0, 24000);
        const generated = await generateQuestions(sourceText, subject.name, lecture.title, count, String(difficulty));
        const batch = db.batch();
        for (const item of generated) {
            batch.create(db.collection("questionBank").doc(), {
                ...item,
                subjectId,
                lectureId,
                difficulty,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        await batch.commit();
        questionSnapshot = await db.collection("questionBank")
            .where("subjectId", "==", subjectId)
            .where("lectureId", "==", lectureId)
            .where("difficulty", "==", difficulty)
            .limit(count)
            .get();
    }
    if (questionSnapshot.size < count) {
        throw new https_1.HttpsError("failed-precondition", "تعذر إنشاء العدد المطلوب من الأسئلة.");
    }
    const selected = questionSnapshot.docs
        .sort(() => Math.random() - 0.5)
        .slice(0, count);
    const attemptRef = db.collection("quizAttempts").doc();
    const dateId = challengeDateId();
    const challengeRef = db.doc(`users/${uid}/dailyChallenges/${dateId}`);
    await db.runTransaction(async (transaction) => {
        if (dailyChallenge) {
            const challenge = (await transaction.get(challengeRef)).data();
            if (challenge?.completedAt) {
                throw new https_1.HttpsError("already-exists", "أكملت تحدي اليوم بالفعل.");
            }
            if (challenge?.attemptId) {
                throw new https_1.HttpsError("already-exists", "لديك تحدٍ بدأته بالفعل.");
            }
        }
        transaction.create(attemptRef, {
            uid,
            subjectId,
            subjectName: subject.name,
            lectureId,
            lectureNumber: lecture.lectureNumber,
            difficulty,
            totalQuestions: selected.length,
            questionIds: selected.map((doc) => doc.id),
            dailyChallenge,
            dailyChallengeDate: dailyChallenge ? dateId : null,
            score: 0,
            earnedXp: 0,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            completedAt: null,
        });
        if (dailyChallenge) {
            transaction.set(challengeRef, {
                attemptId: attemptRef.id,
                startedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
    });
    return {
        quiz_id: attemptRef.id,
        subject: subject.name,
        lecture: lecture.lectureNumber,
        difficulty,
        count: selected.length,
        xp_per_correct: xpForDifficulty(String(difficulty)),
        max_xp: selected.length * xpForDifficulty(String(difficulty)),
        questions: selected.map((doc) => ({
            id: doc.id,
            question: doc.get("question"),
            options: doc.get("options"),
        })),
    };
});
exports.submitQuiz = (0, https_1.onCall)(async (request) => {
    const uid = requireUid(request.auth?.uid);
    const quizId = request.data.quiz_id;
    const submittedAnswers = request.data.answers;
    if (typeof quizId !== "string" || !Array.isArray(submittedAnswers)) {
        throw new https_1.HttpsError("invalid-argument", "بيانات الاختبار غير صالحة.");
    }
    const attemptRef = db.doc(`quizAttempts/${quizId}`);
    const initialAttempt = await attemptRef.get();
    const initialData = initialAttempt.data();
    if (!initialData || initialData.uid !== uid) {
        throw new https_1.HttpsError("not-found", "محاولة الاختبار غير موجودة.");
    }
    const questionIds = initialData.questionIds;
    const parsed = new Map();
    for (const answer of submittedAnswers) {
        if (!answer || typeof answer.question_id !== "string" ||
            !questionIds.includes(answer.question_id) || parsed.has(answer.question_id)) {
            throw new https_1.HttpsError("invalid-argument", "تتضمن الإجابات سؤالًا غير صالح.");
        }
        const selectedIndex = answer.selected_index;
        if (selectedIndex !== null &&
            (!Number.isInteger(selectedIndex) || selectedIndex < 0 || selectedIndex > 3)) {
            throw new https_1.HttpsError("invalid-argument", "رقم الاختيار غير صالح.");
        }
        parsed.set(answer.question_id, selectedIndex);
    }
    if (parsed.size !== questionIds.length) {
        throw new https_1.HttpsError("invalid-argument", "أرسل إجابة لكل سؤال.");
    }
    const userRef = db.doc(`users/${uid}`);
    const dateId = typeof initialData.dailyChallengeDate === "string" ?
        initialData.dailyChallengeDate : challengeDateId();
    const challengeRef = db.doc(`users/${uid}/dailyChallenges/${dateId}`);
    const questionRefs = questionIds.map((id) => db.doc(`questionBank/${id}`));
    let result = {};
    await db.runTransaction(async (transaction) => {
        const [attemptSnapshot, userSnapshot, challengeSnapshot, ...questionSnapshots] = await transaction.getAll(attemptRef, userRef, challengeRef, ...questionRefs);
        const attempt = attemptSnapshot.data();
        const user = userSnapshot.data();
        if (!attempt || attempt.uid !== uid) {
            throw new https_1.HttpsError("not-found", "محاولة الاختبار غير موجودة.");
        }
        if (attempt.completedAt) {
            throw new https_1.HttpsError("already-exists", "تم تسليم هذا الاختبار بالفعل.");
        }
        if (!user)
            throw new https_1.HttpsError("not-found", "ملف المستخدم غير موجود.");
        let score = 0;
        const answerResults = questionIds.map((id, index) => {
            const question = questionSnapshots[index].data();
            const selectedIndex = parsed.get(id) ?? null;
            if (!question) {
                throw new https_1.HttpsError("failed-precondition", "تعذر تحميل سؤال من الاختبار.");
            }
            const isCorrect = selectedIndex === question.correctIndex;
            if (isCorrect)
                score++;
            return {
                id,
                question,
                selectedIndex,
                isCorrect,
            };
        });
        const daily = attempt.dailyChallenge === true &&
            challengeSnapshot.get("attemptId") === quizId &&
            challengeSnapshot.get("completedAt") == null;
        const xpPerCorrect = xpForDifficulty(String(attempt.difficulty));
        const bonusXp = 0;
        const earnedXp = score * xpPerCorrect + bonusXp;
        const completedAt = firestore_1.FieldValue.serverTimestamp();
        transaction.update(attemptRef, {
            score,
            earnedXp,
            completedAt,
        });
        transaction.update(userRef, {
            xpPoints: firestore_1.FieldValue.increment(earnedXp),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        if (daily) {
            transaction.update(challengeRef, {
                completedAt,
                bonusAwarded: false,
                score,
            });
            const notificationRef = db.collection(`users/${uid}/notifications`).doc();
            transaction.create(notificationRef, {
                type: "general",
                title: "اكتمل التحدي اليومي",
                body: `أجبت إجابة صحيحة عن ${score} من أصل ${questionIds.length} أسئلة.`,
                isRead: false,
                createdAt: completedAt,
                data: { kind: "daily_challenge", date: dateId, score },
            });
        }
        for (const answer of answerResults) {
            const answerRef = attemptRef.collection("answers").doc(answer.id);
            transaction.create(answerRef, {
                questionId: answer.id,
                selectedIndex: answer.selectedIndex,
                isCorrect: answer.isCorrect,
                topic: answer.question.topic ?? "",
                sectionTitle: answer.question.sectionTitle ?? "",
                sourceTitle: answer.question.sourceTitle ?? "",
                answeredAt: completedAt,
            });
            if (!answer.isCorrect) {
                const reviewRef = db.collection(`users/${uid}/reviewItems`).doc(`${quizId}_${answer.id}`);
                transaction.set(reviewRef, {
                    questionId: answer.id,
                    attemptId: quizId,
                    subjectId: attempt.subjectId,
                    subject: attempt.subjectName,
                    lecture: attempt.lectureNumber,
                    question: answer.question.question,
                    options: answer.question.options,
                    correctIndex: answer.question.correctIndex,
                    explanation: answer.question.explanation,
                    selectedIndex: answer.selectedIndex,
                    attemptedAt: completedAt,
                    reviewedAt: null,
                    reviewCount: 0,
                });
            }
        }
        result = {
            score,
            total_questions: attempt.totalQuestions,
            earned_xp: earnedXp,
            bonus_xp: bonusXp,
            new_xp: (user.xpPoints ?? 0) + earnedXp,
            answers: answerResults.map((answer) => ({
                question_id: answer.id,
                question: answer.question.question,
                options: answer.question.options,
                selected_index: answer.selectedIndex,
                correct_index: answer.question.correctIndex,
                is_correct: answer.isCorrect,
                explanation: answer.question.explanation,
            })),
        };
    });
    return result;
});
exports.getLeaderboard = (0, https_1.onCall)(async (request) => {
    requireUid(request.auth?.uid);
    const year = Number(request.data.year);
    if (!Number.isInteger(year) || !validYears.has(year)) {
        throw new https_1.HttpsError("invalid-argument", "السنة الدراسية غير صالحة.");
    }
    const result = await db.collection("users")
        .where("role", "==", "student")
        .where("academicYear", "==", year)
        .where("studentStatus", "==", "active")
        .orderBy("xpPoints", "desc")
        .limit(10)
        .get();
    return {
        leaderboard: result.docs.map((doc, index) => ({
            id: doc.id,
            rank: index + 1,
            username: doc.get("username"),
            full_name: doc.get("fullName"),
            university_id: doc.get("universityId"),
            xp_points: doc.get("xpPoints") ?? 0,
            xp: doc.get("xpPoints") ?? 0,
            academic_year: doc.get("academicYear"),
        })),
    };
});
exports.academicAssistant = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    const uid = requireUid(request.auth?.uid);
    const { subjectId, lectureId, message, summaryType } = request.data;
    if (typeof subjectId !== "string" || typeof lectureId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "المادة أو المحاضرة غير صالحة.");
    }
    const profile = (await db.doc(`users/${uid}`).get()).data();
    const subject = (await db.doc(`subjects/${subjectId}`).get()).data();
    if (!profile || !subject || profile.academicYear !== subject.yearNumber) {
        throw new https_1.HttpsError("permission-denied", "المادة غير متاحة لفرقتك.");
    }
    const chunks = await db.collection("lectureChunks")
        .where("subjectId", "==", subjectId)
        .where("lectureId", "==", lectureId)
        .limit(30)
        .get();
    if (chunks.empty) {
        throw new https_1.HttpsError("not-found", "لا يوجد محتوى لهذه المحاضرة.");
    }
    const sources = chunks.docs.map((doc) => ({
        source_id: doc.id,
        file_name: doc.get("sourceTitle") ?? "مادة دراسية",
        subject: subject.name,
        lecture_number: doc.get("lectureNumber"),
        page_number: doc.get("pageNumber") ?? null,
        section_title: doc.get("sectionTitle") ?? "",
    }));
    const context = chunks.docs.map((doc) => doc.get("text"))
        .filter((text) => typeof text === "string")
        .join("\n")
        .slice(0, 24000);
    const prompt = typeof summaryType === "string" ?
        `لخص المحتوى بالعربية بنمط ${summaryType}. اذكر فقط المعلومات في المصادر.` :
        `أجب بالعربية عن السؤال اعتمادًا على المصادر فقط: ${String(message ?? "").slice(0, 2000)}`;
    const reply = await generateGroundedText(context, prompt);
    return summaryType ?
        { summary: reply, sources } :
        { reply, sources };
});
function requireUid(uid) {
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "سجّل الدخول أولًا.");
    return uid;
}
function xpForDifficulty(_difficulty) {
    return 1;
}
function challengeDateId(date = new Date()) {
    const parts = new Intl.DateTimeFormat("en-CA", {
        timeZone: "Africa/Cairo",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    }).formatToParts(date);
    const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return `${values.year}-${values.month}-${values.day}`;
}
function toClientData(value) {
    const result = {};
    for (const [key, item] of Object.entries(value)) {
        const clientKey = key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
        if (item && typeof item === "object" &&
            "toDate" in item && typeof item.toDate === "function") {
            result[clientKey] = item.toDate().toISOString();
        }
        else {
            result[clientKey] = item;
        }
    }
    return result;
}
function academicDocument(collection, data, partial = false) {
    const result = {};
    const setString = (field, value, required = false) => {
        if (typeof value === "string") {
            result[field] = value.trim();
        }
        else if (required && !partial) {
            throw new https_1.HttpsError("invalid-argument", `الحقل ${field} مطلوب.`);
        }
    };
    const setNumber = (field, value, fallback, required = false) => {
        if (value === undefined && partial)
            return;
        const parsed = Number(value ?? fallback);
        if (!Number.isSafeInteger(parsed) || parsed < 1) {
            if (required || value !== undefined) {
                throw new https_1.HttpsError("invalid-argument", `الحقل ${field} غير صالح.`);
            }
            return;
        }
        result[field] = parsed;
    };
    setString("name", data.name, true);
    if (data.is_active !== undefined) {
        result.isActive = Boolean(data.is_active);
    }
    else if (!partial) {
        result.isActive = true;
    }
    if (collection === "academicYears") {
        setNumber("yearNumber", data.year_number, undefined, true);
        setNumber("order", data.order, 1);
        return result;
    }
    if (collection === "subjects") {
        setNumber("yearNumber", data.academic_year, undefined, true);
        setString("code", data.code);
        setString("description", data.description);
        setNumber("order", data.order, 1);
        return result;
    }
    setString("title", data.title, true);
    setString("subjectId", data.subject);
    setNumber("lectureNumber", data.lecture_number, undefined, true);
    setString("description", data.description);
    setNumber("order", data.order ?? data.lecture_number, 1);
    if (!partial)
        result.hasContent = false;
    return result;
}
async function generateQuestions(sourceText, subject, lecture, count, difficulty, sectionTitle = "") {
    const prompt = [
        "أنشئ أسئلة اختيار من متعدد باللغة العربية من النص الموثوق فقط.",
        `المادة: ${subject}، المحاضرة: ${lecture}، السكشن: ${sectionTitle || "غير محدد"}، المستوى: ${difficulty}، العدد: ${count}.`,
        "أعد JSON فقط بالشكل {\"questions\":[{\"question\":\"...\",\"options\":[\"...\",\"...\",\"...\",\"...\"],\"correctIndex\":0,\"explanation\":\"...\",\"topic\":\"اسم الجزء أو الفكرة\"}]}",
        "لا تكرر الأسئلة ولا تخترع معلومات غير واردة في النص.",
        `النص:\n${sourceText}`,
    ].join("\n");
    const text = await generateGroundedText(sourceText, prompt, true);
    let parsed;
    try {
        parsed = JSON.parse(text);
    }
    catch {
        throw new https_1.HttpsError("internal", "تعذر تحليل الأسئلة المولدة.");
    }
    if (!parsed || typeof parsed !== "object" ||
        !Array.isArray(parsed.questions)) {
        throw new https_1.HttpsError("internal", "استجابة توليد الأسئلة غير صالحة.");
    }
    const questions = parsed.questions
        .filter((item) => Boolean(item) && typeof item === "object")
        .filter((item) => typeof item.question === "string" &&
        Array.isArray(item.options) &&
        item.options.length === 4 &&
        item.options.every((option) => typeof option === "string") &&
        Number.isInteger(item.correctIndex) &&
        item.correctIndex >= 0 &&
        item.correctIndex < 4 &&
        typeof item.explanation === "string")
        .map((item) => ({
        question: String(item.question).slice(0, 1000),
        options: item.options.map((option) => option.slice(0, 500)),
        correctIndex: item.correctIndex,
        explanation: String(item.explanation).slice(0, 2000),
        topic: typeof item.topic === "string" ?
            item.topic.slice(0, 200) : "",
    }));
    return questions.slice(0, count);
}
async function generateGroundedText(context, instruction, jsonOnly = false) {
    const response = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": geminiApiKey.value(),
        },
        body: JSON.stringify({
            contents: [{
                    role: "user",
                    parts: [{ text: `${instruction}\n\nالمصادر:\n${context}` }],
                }],
            generationConfig: {
                temperature: 0.2,
                ...(jsonOnly ? { responseMimeType: "application/json" } : {}),
            },
        }),
    });
    if (!response.ok) {
        throw new https_1.HttpsError("unavailable", "تعذر الاتصال بخدمة الذكاء الاصطناعي.");
    }
    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts
        ?.map((part) => part.text ?? "")
        .join("")
        .trim();
    if (!text)
        throw new https_1.HttpsError("unavailable", "لم تنتج الخدمة إجابة.");
    return text;
}
