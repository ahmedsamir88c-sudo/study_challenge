import base64
import hashlib
import json
import os
import random
import re
import unicodedata
import urllib.request
import urllib.error

from django.contrib.auth import authenticate
from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models import F
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView

from .models import (
    AISummary,
    GeneratedQuizQuestion,
    LectureContent,
    QuizQuestionUsage,
    User,
)
from .permissions import IsAdmin, IsOwner
from .serializers import LoginSerializer, RegisterSerializer, UpdateProfileSerializer, UserSerializer
from .services.academic_ai import (
    AcademicAIScopeError,
    ask_academic_question,
    summarize_academic_lecture,
)
from .services.gemini_client import GeminiServiceError


# ─────────────────────────────────────────────────────────────
# AUTH VIEWS
# ─────────────────────────────────────────────────────────────

class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = LoginSerializer.get_token(user)
        return Response(
            {
                "message": "تم إنشاء الحساب بنجاح.",
                "user": UserSerializer(user).data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(TokenObtainPairView):
    serializer_class = LoginSerializer
    permission_classes = [AllowAny]


# ─────────────────────────────────────────────────────────────
# PROFILE VIEWS
# ─────────────────────────────────────────────────────────────

class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user

    def update(self, request, *args, **kwargs):
        # لا نسمح بتغيير الـ role أو الـ xp عبر هذا الـ endpoint
        data = request.data.copy()
        data.pop("role", None)
        data.pop("xp", None)
        data.pop("xp_points", None)

        serializer = UpdateProfileSerializer(
            self.get_object(),
            data=data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        # إرجاع البيانات الكاملة بعد التحديث
        return Response(
            UserSerializer(
                self.get_object(),
                context=self.get_serializer_context(),
            ).data,
            status=status.HTTP_200_OK,
        )


class OwnerDashboardView(APIView):
    permission_classes = [IsOwner]

    def get(self, request):
        student_users = User.objects.filter(role=User.Role.STUDENT)
        return Response({
            "owner": {
                "username": request.user.username,
                "university_id": request.user.university_id,
            },
            "metrics": {
                "total_students": student_users.count(),
                "active_students": student_users.filter(is_active=True).count(),
                "total_subjects": LectureContent.objects.values("subject")
                .distinct()
                .count(),
                "total_lectures": LectureContent.objects.count(),
                "total_files": LectureContent.objects.exclude(file="").count(),
                "total_questions": GeneratedQuizQuestion.objects.count(),
                "total_summaries": AISummary.objects.count(),
            },
        })


# ─────────────────────────────────────────────────────────────
# LEADERBOARD
# ─────────────────────────────────────────────────────────────

class LeaderboardView(APIView):
    """
    إرجاع أعلى 10 مراتب حسب نقاط الـ XP مع فلترة بالفرقة الدراسية
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        year_param = request.query_params.get("year", "all")
        # استبعاد المستخدمين الفيك أو الذين ليس لديهم نقاط خبرة فعلية
        qs = User.objects.filter(is_active=True, role=User.Role.STUDENT, xp_points__gt=0)

        if year_param and year_param != "all":
            try:
                year_num = int(year_param)
                if year_num in [1, 2, 3, 4]:
                    qs = qs.filter(academic_year=year_num)
            except ValueError:
                pass

        # أعلى 10 طلاب مرتبين تنازلياً بالـ xp_points
        top_users = qs.order_by("-xp_points", "-xp")[:10]
        total = qs.count()

        leaderboard = []
        for rank, u in enumerate(top_users, start=1):
            leaderboard.append({
                "rank": rank,
                "id": u.id,
                "username": u.username,
                "full_name": u.full_name or u.username,
                "university_id": u.university_id or "",
                "academic_year": u.academic_year or 1,
                "xp_points": u.xp_points,
                "xp": u.xp_points,  # توافق مع Flutter القديم
                "streak": u.streak,
                "profile_picture": u.profile_picture or "",
                "is_current_user": (u.id == request.user.id),
            })

        return Response({
            "filter_year": year_param,
            "total_students": total,
            "leaderboard": leaderboard,
        })


# ─────────────────────────────────────────────────────────────
# QUIZ — الأسئلة الديناميكية حسب المادة والمستوى والعدد
# ─────────────────────────────────────────────────────────────

NO_LECTURE_CONTENT_MESSAGE = (
    "عذراً، لا توجد أسئلة أو محاضرات متاحة لهذه المحاضرة حتى الآن، "
    "يجيب الانتظار لحين رفع المحتوى"
)
QUESTION_COUNTS = [10, 20, 25, 30, 35, 40, 50, 100]

COMPUTER_ARCHITECTURE_LECTURE_QUESTIONS = [
    {
        "question": "ما الذي تصفه معمارية الحاسوب أساساً؟",
        "options": [
            "التفاصيل الفيزيائية لكل دائرة",
            "الخصائص التي يراها المبرمج مثل التعليمات وأنواع البيانات",
            "طريقة تصنيع المعالج فقط",
            "سرعة اتصال الإنترنت",
        ],
        "correct_index": 1,
        "explanation": "المعمارية تحدد الواجهة والخصائص الظاهرة للمبرمج، مثل مجموعة التعليمات وأنواع البيانات.",
    },
    {
        "question": "أي مثال يعبّر عن تنظيم الحاسوب لا معمارية الحاسوب؟",
        "options": [
            "مجموعة التعليمات التي ينفذها المعالج",
            "أنماط عنونة الذاكرة",
            "طريقة تنفيذ وحدة الضرب داخل المعالج",
            "أنواع البيانات التي تدعمها التعليمات",
        ],
        "correct_index": 2,
        "explanation": "اختيار الدوائر أو الوحدات التي تنفذ العملية من تفاصيل التنظيم الداخلي.",
    },
    {
        "question": "ما الوظائف الأساسية الأربع للحاسوب؟",
        "options": [
            "الإدخال، الطباعة، التشفير، الاتصال",
            "معالجة البيانات، تخزينها، نقلها، والتحكم",
            "النسخ، الحذف، البحث، والفرز",
            "التحميل، التثبيت، التشغيل، والإغلاق",
        ],
        "correct_index": 1,
        "explanation": "تُجمع وظائف الحاسوب الأساسية في معالجة البيانات وتخزينها ونقلها والتحكم.",
    },
    {
        "question": "ما المكونات الهيكلية الرئيسية للحاسوب؟",
        "options": [
            "المعالج والذاكرة الرئيسية وأجهزة الإدخال والإخراج والربط بينها",
            "الشاشة ولوحة المفاتيح والفأرة فقط",
            "نظام التشغيل والبرامج وقواعد البيانات فقط",
            "وحدة الحساب والقرص الصلب فقط",
        ],
        "correct_index": 0,
        "explanation": "تتكون الصورة الهيكلية العامة من CPU والذاكرة وI/O وآلية الربط بينها.",
    },
    {
        "question": "ما الدور الأساسي لوحدة التحكم داخل المعالج؟",
        "options": [
            "تخزين الملفات بعد إيقاف التشغيل",
            "تنسيق تنفيذ التعليمات وحركة البيانات داخل النظام",
            "عرض الصور على الشاشة",
            "تنفيذ العمليات الحسابية وحدها",
        ],
        "correct_index": 1,
        "explanation": "وحدة التحكم تنسق خطوات التنفيذ وتوجّه حركة البيانات والإشارات.",
    },
    {
        "question": "ما الفكرة المحورية في نموذج فون نيومان؟",
        "options": [
            "تخزين التعليمات والبيانات في الذاكرة ليعالجها البرنامج",
            "استخدام معالج منفصل لكل تعليمة",
            "تنفيذ البرامج بتوصيل الأسلاك يدوياً لكل مسألة",
            "الاستغناء عن الذاكرة الرئيسية",
        ],
        "correct_index": 0,
        "explanation": "يعتمد نموذج البرنامج المخزن على وجود التعليمات والبيانات في الذاكرة.",
    },
    {
        "question": "ما المقصود باختناق فون نيومان؟",
        "options": [
            "بطء وحدة الحساب مقارنة بوحدة التحكم دائماً",
            "محدودية نقل التعليمات والبيانات عبر مسار مشترك بين المعالج والذاكرة",
            "عدم قدرة الحاسوب على تخزين البرامج",
            "زيادة عدد وحدات الإدخال والإخراج",
        ],
        "correct_index": 1,
        "explanation": "المسار المشترك بين CPU والذاكرة قد يحد من معدل نقل التعليمات والبيانات.",
    },
    {
        "question": "ما الترتيب المعتاد لدورة تنفيذ التعليمة؟",
        "options": [
            "تنفيذ، جلب، تخزين، فك ترميز",
            "جلب التعليمة، فك ترميزها، ثم تنفيذها",
            "فك الترميز، إيقاف المعالج، ثم الجلب",
            "تخزين النتيجة، ثم اختيار البرنامج",
        ],
        "correct_index": 1,
        "explanation": "تجلب وحدة التحكم التعليمة، وتفك ترميزها، ثم تُنفذ العملية المطلوبة.",
    },
    {
        "question": "لماذا تُستخدم المستويات الهرمية في وصف الحاسوب؟",
        "options": [
            "لإلغاء الحاجة إلى العتاد",
            "لتقسيم النظام إلى طبقات تجريد يمكن فهم كل منها على حدة",
            "لجعل كل البرامج تعمل بلغة الآلة مباشرة",
            "لمنع المستويات العليا من استخدام المستويات الأدنى",
        ],
        "correct_index": 1,
        "explanation": "كل مستوى يخفي تفاصيل المستوى الأدنى ويقدم واجهة أبسط للمستوى الأعلى.",
    },
    {
        "question": "ما الذي تصفه ملاحظة مور تاريخياً؟",
        "options": [
            "زيادة كثافة الترانزستورات على الشرائح مع مرور الزمن",
            "ثبات سرعة المعالجات إلى الأبد",
            "انخفاض عدد مكونات كل حاسوب سنوياً",
            "زيادة سعة القرص الصلب فقط",
        ],
        "correct_index": 0,
        "explanation": "تصف ملاحظة مور اتجاهاً تاريخياً في نمو كثافة الترانزستورات، وليس قانوناً مضموناً بلا نهاية.",
    },
]

QUESTION_BANK = {
    "Digital Logic Design": [
        {"question": "ما هو ناتج البوابة المنطقية AND للمدخلات A=1 و B=0؟", "options": ["0", "1", "غير محدد", "2"], "correct_index": 0, "explanation": "AND تُعيد 1 فقط إذا كانت جميع المدخلات 1."},
        {"question": "أي من هذه البوابات يُعيد 1 فقط إذا كانت جميع المدخلات 0؟", "options": ["AND", "OR", "NOR", "NAND"], "correct_index": 2, "explanation": "NOR تُعيد 1 فقط عندما تكون جميع المدخلات 0."},
        {"question": "ما هو العدد الثنائي للعدد العشري 10؟", "options": ["1010", "1100", "1001", "0110"], "correct_index": 0, "explanation": "10 = 8+2 = 1010 في النظام الثنائي."},
        {"question": "ما هو ناتج XOR للمدخلين A=1, B=1؟", "options": ["0", "1", "X", "غير محدد"], "correct_index": 0, "explanation": "XOR تُعيد 0 عندما تكون المدخلات متساوية."},
        {"question": "كم خلية تحتاج خريطة كارنوه (K-Map) لـ 3 متغيرات؟", "options": ["4", "6", "8", "16"], "correct_index": 2, "explanation": "لـ n متغيرات تحتاج 2^n خلية، لذا 2^3 = 8."},
        {"question": "ما هو النظام الست عشري للعدد الثنائي 1111؟", "options": ["E", "F", "D", "C"], "correct_index": 1, "explanation": "1111 ثنائي = 15 عشري = F سادس عشري."},
        {"question": "ما هي وظيفة دائرة Multiplexer (MUX)؟", "options": ["تقسيم البيانات", "اختيار مدخل واحد من عدة مدخلات", "تضخيم الإشارة", "تخزين البيانات"], "correct_index": 1, "explanation": "MUX يختار مدخلاً واحداً من عدة مدخلات بناءً على إشارات التحكم."},
        {"question": "ما هو الفرق بين D Flip-Flop و SR Flip-Flop؟", "options": ["D أبسط ولا يملك حالة محظورة", "SR أسرع", "لا فرق بينهما", "D يخزن بيتين"], "correct_index": 0, "explanation": "D Flip-Flop يحل مشكلة الحالة المحظورة (S=R=1) الموجودة في SR."},
        {"question": "ما هي نظرية De Morgan الأولى؟", "options": ["(A.B)' = A' + B'", "(A+B)' = A'.B'", "(A+B)' = A'+B'", "A.B = B.A"], "correct_index": 0, "explanation": "نظرية De Morgan الأولى: NOT(A AND B) = NOT_A OR NOT_B."},
        {"question": "ما هو عدد مراحل العداد Mod-8 Counter؟", "options": ["4", "6", "8", "16"], "correct_index": 2, "explanation": "Mod-8 Counter يعد من 0 إلى 7، أي 8 حالات."},
    ],
    "Machine Learning": [
        {"question": "ما هي خوارزمية التعلم الآلي التي تُستخدم للتصنيف والانحدار معاً؟", "options": ["K-Means", "Decision Tree", "PCA", "DBSCAN"], "correct_index": 1, "explanation": "Decision Tree يمكن استخدامه للتصنيف والانحدار على حد سواء."},
        {"question": "ما هو الهدف من خوارزمية K-Means؟", "options": ["التصنيف المُشرف", "التجميع غير المُشرف", "الانحدار الخطي", "تقليل الأبعاد"], "correct_index": 1, "explanation": "K-Means هي خوارزمية تجميع (Clustering) غير مُشرفة."},
        {"question": "ما الفرق بين Overfitting و Underfitting؟", "options": ["لا فرق", "Overfitting يحفظ بيانات التدريب لكن لا يُعمم، Underfitting لا يتعلم بشكل كافٍ", "Underfitting أسوأ دائماً", "Overfitting أفضل دائماً"], "correct_index": 1, "explanation": "Overfitting يؤدي أداءً جيداً على بيانات التدريب لكن ضعيفاً على بيانات الاختبار."},
        {"question": "ما هي وظيفة دالة Sigmoid في الشبكات العصبية؟", "options": ["حساب الخسارة", "ضغط الناتج بين 0 و1", "حساب الانحدار", "تهيئة الأوزان"], "correct_index": 1, "explanation": "Sigmoid تحوّل أي قيمة إلى نطاق [0,1]، مناسبة للتصنيف الثنائي."},
        {"question": "ما هو Cross-Entropy Loss؟", "options": ["قياس المسافة بين نقطتين", "دالة خسارة للتصنيف تقيس الفارق بين التوزيعات", "خوارزمية تحسين", "مقياس دقة"], "correct_index": 1, "explanation": "Cross-Entropy Loss تُستخدم في مسائل التصنيف لقياس الفارق بين التوزيعين الحقيقي والمتوقع."},
        {"question": "ما هي Gradient Descent؟", "options": ["طريقة لتحميل البيانات", "خوارزمية تحسين تُقلل دالة الخسارة تدريجياً", "نوع من أنواع الشبكات العصبية", "أسلوب تقييم"], "correct_index": 1, "explanation": "Gradient Descent تُقلل دالة الخسارة عبر تحديث الأوزان في اتجاه التدرج السالب."},
        {"question": "ما هو Random Forest؟", "options": ["شجرة قرار واحدة", "مجموعة أشجار قرار تعمل معاً (Ensemble)", "خوارزمية تجميع", "شبكة عصبية"], "correct_index": 1, "explanation": "Random Forest تجمع عدة أشجار قرار وتُصوّت على النتيجة النهائية."},
        {"question": "ما هو Learning Rate في التعلم الآلي؟", "options": ["عدد الطبقات", "حجم الخطوة في تحديث الأوزان", "عدد العينات", "دقة النموذج"], "correct_index": 1, "explanation": "Learning Rate يُحدد مقدار تحديث الأوزان في كل خطوة من Gradient Descent."},
    ],
    "Computer Networks": [
        {"question": "ما هو بروتوكول HTTP؟", "options": ["بروتوكول نقل الملفات", "بروتوكول نقل النصوص الفائقة للويب", "بروتوكول البريد الإلكتروني", "بروتوكول توجيه الشبكة"], "correct_index": 1, "explanation": "HTTP (HyperText Transfer Protocol) هو البروتوكول الأساسي لنقل صفحات الويب."},
        {"question": "كم طبقة يحتوي نموذج OSI؟", "options": ["4", "5", "7", "9"], "correct_index": 2, "explanation": "نموذج OSI يتكون من 7 طبقات: Physical, Data Link, Network, Transport, Session, Presentation, Application."},
        {"question": "ما وظيفة بروتوكول TCP؟", "options": ["توجيه الحزم", "نقل موثوق ومرتب للبيانات", "تشفير الاتصال", "ترجمة الأسماء إلى IP"], "correct_index": 1, "explanation": "TCP يوفر نقلاً موثوقاً ومرتباً للبيانات مع التحقق من الاستلام."},
        {"question": "ما الفرق بين TCP و UDP؟", "options": ["UDP أسرع وغير موثوق، TCP أبطأ وموثوق", "لا فرق", "TCP أسرع", "UDP يُستخدم للويب فقط"], "correct_index": 0, "explanation": "UDP أسرع لأنه لا يضمن الاستلام، مناسب للبث المباشر. TCP يضمن الوصول."},
        {"question": "ما هو رقم المنفذ (Port) لبروتوكول HTTPS؟", "options": ["80", "21", "443", "22"], "correct_index": 2, "explanation": "HTTPS يعمل على المنفذ 443 افتراضياً، بينما HTTP يعمل على 80."},
        {"question": "ما وظيفة بروتوكول DNS؟", "options": ["تشفير البيانات", "ترجمة أسماء النطاقات إلى عناوين IP", "نقل الملفات", "إدارة البريد الإلكتروني"], "correct_index": 1, "explanation": "DNS يترجم أسماء النطاقات (مثل google.com) إلى عناوين IP رقمية."},
        {"question": "ما هي الطبقة المسؤولة عن التوجيه (Routing) في نموذج OSI؟", "options": ["طبقة النقل", "طبقة الشبكة", "طبقة البيانات", "طبقة التطبيق"], "correct_index": 1, "explanation": "طبقة الشبكة (Network Layer) مسؤولة عن التوجيه وعنونة IP."},
        {"question": "ما هو بروتوكول DHCP؟", "options": ["بروتوكول نقل الملفات", "بروتوكول تعيين عناوين IP تلقائياً", "بروتوكول البريد", "بروتوكول التشفير"], "correct_index": 1, "explanation": "DHCP يُعيّن عناوين IP تلقائياً للأجهزة المتصلة بالشبكة."},
    ],
    "Modeling and Simulation": [
        {"question": "ما هو الفرق بين النموذج (Model) والمحاكاة (Simulation)؟", "options": ["لا فرق", "النموذج تمثيل مُبسط، المحاكاة تشغيل النموذج عبر الزمن", "المحاكاة أبسط", "النموذج أدق دائماً"], "correct_index": 1, "explanation": "النموذج هو تمثيل مُبسط للواقع، والمحاكاة هي تشغيل هذا النموذج لمراقبة سلوكه."},
        {"question": "ما هي المحاكاة العشوائية (Stochastic Simulation)؟", "options": ["محاكاة حتمية بنتائج ثابتة", "محاكاة تستخدم أرقاماً عشوائية لمحاكاة العمليات الاحتمالية", "محاكاة للطقس فقط", "محاكاة رياضية بحتة"], "correct_index": 1, "explanation": "المحاكاة العشوائية تستخدم أرقاماً عشوائية لتمثيل العمليات غير الحتمية."},
        {"question": "ما هي طريقة Monte Carlo؟", "options": ["خوارزمية ترتيب", "طريقة محاكاة تستخدم أخذ عينات عشوائية لحل مسائل رياضية", "أسلوب رياضيات بحتة", "بروتوكول شبكة"], "correct_index": 1, "explanation": "Monte Carlo تحل مسائل رياضية معقدة عبر أخذ عينات عشوائية كثيرة وتحليل النتائج."},
        {"question": "ما هو نموذج الصف (Queue Model) في نظرية الانتظار؟", "options": ["نموذج لحركة المرور فقط", "نموذج رياضي يصف أنظمة الانتظار وتقديم الخدمة", "خوارزمية تحسين", "نموذج شبكي"], "correct_index": 1, "explanation": "نظرية الانتظار (Queuing Theory) تُحلل أنظمة الخدمة ووقت الانتظار."},
        {"question": "ما هو وقت الحرارة (Warm-up Period) في المحاكاة؟", "options": ["وقت تسخين الحاسوب", "الفترة الأولية قبل استقرار النظام التي يجب تجاهلها في تحليل البيانات", "مدة المحاكاة الكاملة", "وقت الاستراحة"], "correct_index": 1, "explanation": "Warm-up Period هي الفترة الأولية غير المستقرة في المحاكاة التي تُستبعد من تحليل البيانات."},
        {"question": "ما هو الفرق بين المحاكاة المستمرة والمتقطعة؟", "options": ["لا فرق عملي", "المستمرة تُغيّر الحالة بشكل مستمر، المتقطعة تُغيّرها عند أحداث محددة", "المتقطعة أدق دائماً", "المستمرة للأنظمة الرقمية فقط"], "correct_index": 1, "explanation": "DES تُغيّر الحالة عند أحداث محددة، بينما Continuous Simulation تُغيّر بشكل مستمر."},
    ],
    "Computer Architecture": [
        {"question": "ما هو الفرق بين معالج RISC و CISC؟", "options": ["RISC أبطأ دائماً", "RISC تعليمات بسيطة وسريعة، CISC تعليمات معقدة وقليلة الكود", "CISC أسرع دائماً", "لا فرق عملي"], "correct_index": 1, "explanation": "RISC (Reduced Instruction Set) تُبسط التعليمات لتسريع التنفيذ، CISC تُقلل عدد تعليمات الكود."},
        {"question": "ما هو Cache Memory؟", "options": ["ذاكرة بطيئة رخيصة", "ذاكرة سريعة صغيرة قريبة من المعالج لتسريع الوصول للبيانات", "الذاكرة الرئيسية RAM", "وحدة تخزين دائم"], "correct_index": 1, "explanation": "Cache Memory تخزن البيانات الأكثر استخداماً قرب المعالج لتقليل وقت الوصول."},
        {"question": "ما هو Pipeline في المعالج؟", "options": ["نوع من الذاكرة", "تقنية تُشغّل مراحل متعددة للتعليمات بشكل متوازٍ لزيادة الأداء", "بروتوكول الشبكة", "وحدة المنطق"], "correct_index": 1, "explanation": "Pipeline تُقسم تنفيذ التعليمة لمراحل تعمل بشكل متداخل لزيادة معدل التنفيذ."},
        {"question": "ما هو مبدأ موقع (Locality of Reference)؟", "options": ["الملفات تُخزن محلياً", "البرامج تميل للوصول لنفس البيانات أو بيانات قريبة منها في فترات قصيرة", "مبدأ الشبكات المحلية", "نوع من الخوارزميات"], "correct_index": 1, "explanation": "Locality of Reference هو المبدأ الذي يُبرر فاعلية الـ Cache Memory."},
        {"question": "ما هو Virtual Memory؟", "options": ["ذاكرة وهمية غير موجودة", "تقنية تُمكّن البرامج من استخدام ذاكرة أكبر من الـ RAM الفعلية عبر القرص", "ذاكرة سريعة", "نوع من الـ Cache"], "correct_index": 1, "explanation": "Virtual Memory تستخدم القرص الصلب كامتداد للـ RAM عند نفادها."},
        {"question": "ما هي وحدة ALU في المعالج؟", "options": ["وحدة التحكم", "وحدة المنطق والحساب المسؤولة عن العمليات الرياضية والمنطقية", "وحدة الذاكرة", "وحدة الإدخال"], "correct_index": 1, "explanation": "ALU (Arithmetic Logic Unit) تُنفذ العمليات الحسابية والمنطقية في المعالج."},
        {"question": "ما هو Instruction Set Architecture (ISA)؟", "options": ["معمارية الذاكرة", "مجموعة التعليمات التي يفهمها المعالج وواجهة البرمجة والمعدات", "نوع من الـ Cache", "بروتوكول الشبكة"], "correct_index": 1, "explanation": "ISA هي الواجهة بين البرمجيات والمعدات، تُحدد التعليمات التي يتعرف عليها المعالج."},
    ],
    "Data Structure and Algorithms": [
        {"question": "ما هو تعقيد الوقت لعملية البحث في Hash Table في أفضل الحالات؟", "options": ["O(n)", "O(log n)", "O(1)", "O(n^2)"], "correct_index": 2, "explanation": "Hash Table يوفر وصولاً مباشراً O(1) في غياب التصادمات (Collisions)."},
        {"question": "ما هي خوارزمية Merge Sort وما تعقيدها الزمني؟", "options": ["خوارزمية تبادل، O(n^2)", "خوارزمية تقسيم وتغلب، O(n log n)", "خوارزمية جشعة، O(n)", "خوارزمية ديناميكية، O(n^2)"], "correct_index": 1, "explanation": "Merge Sort تقسم المصفوفة للنصف تكرارياً ثم تدمجها، تعقيدها O(n log n) في جميع الحالات."},
        {"question": "ما الفرق بين Stack و Queue؟", "options": ["لا فرق", "Stack: LIFO (آخر داخل أول خارج)، Queue: FIFO (أول داخل أول خارج)", "Queue: LIFO، Stack: FIFO", "كلاهما FIFO"], "correct_index": 1, "explanation": "Stack يعمل كـ LIFO (المكدس)، Queue يعمل كـ FIFO (الطابور)."},
        {"question": "ما هو Binary Search Tree (BST)؟", "options": ["شجرة عشوائية", "شجرة ثنائية يكون فيها كل ابن أيسر أصغر من الأب وكل ابن أيمن أكبر", "شجرة متوازنة دائماً", "شجرة البحث الخطي"], "correct_index": 1, "explanation": "BST: العقد اليسرى أصغر من الجذر، واليمنى أكبر، مما يُسرّع عمليات البحث."},
        {"question": "ما هو تعقيد خوارزمية Bubble Sort في أسوأ الحالات؟", "options": ["O(n)", "O(n log n)", "O(n^2)", "O(log n)"], "correct_index": 2, "explanation": "Bubble Sort في أسوأ الحالات (مصفوفة مرتبة عكسياً) تحتاج n*(n-1)/2 مقارنة = O(n^2)."},
        {"question": "ما هو Dijkstra's Algorithm؟", "options": ["خوارزمية ترتيب", "خوارزمية إيجاد أقصر مسار في الرسم البياني (Graph)", "خوارزمية تجميع", "خوارزمية بحث ثنائي"], "correct_index": 1, "explanation": "Dijkstra يجد أقصر مسار من عقدة مصدر إلى جميع العقد الأخرى في الرسم البياني الموزون."},
        {"question": "ما هو مفهوم Dynamic Programming؟", "options": ["برمجة ديناميكية بلغات مختلفة", "أسلوب حل يُقسم المشكلة لمسائل فرعية ويُخزن نتائجها لتجنب إعادة الحساب", "نوع من أنواع الـ Sorting", "خوارزمية بحث"], "correct_index": 1, "explanation": "DP تحل مسائل ذات مسائل فرعية متكررة (Overlapping Subproblems) بتخزين النتائج (Memoization)."},
        {"question": "ما هو تعقيد عمليات إدراج وحذف في Linked List؟", "options": ["O(n) للإدراج في الأول، O(1) للحذف", "O(1) للإدراج في الأول، O(1) للحذف من الأول", "O(n^2) دائماً", "O(log n)"], "correct_index": 1, "explanation": "Linked List: الإدراج والحذف من البداية O(1)، أما من الوسط أو النهاية فيحتاج O(n) للوصول أولاً."},
    ],
}


class QuizQuestionGenerationError(Exception):
    pass


def _normalize_question(question: str) -> str:
    normalized = unicodedata.normalize("NFKC", question).casefold()
    normalized = re.sub(r"[\u064b-\u065f\u0670\u0640]", "", normalized)
    return " ".join(re.sub(r"[^\w]+", " ", normalized).split())


def _question_fingerprint(question: str) -> str:
    normalized = _normalize_question(question)
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def _lecture_source_parts(lecture: LectureContent) -> list[dict]:
    parts = []
    if (lecture.content or "").strip():
        parts.append({"text": f"محتوى المحاضرة:\n{lecture.content.strip()}"})

    if lecture.file:
        extension = os.path.splitext(lecture.file.name)[1].lower()
        if extension != ".pdf":
            raise QuizQuestionGenerationError(
                "صيغة ملف المحاضرة غير مدعومة. ارفع ملف PDF أو نص المحاضرة."
            )
        try:
            lecture.file.open("rb")
            file_bytes = lecture.file.read()
        except OSError as error:
            raise QuizQuestionGenerationError(
                "تعذر قراءة ملف المحاضرة. يرجى رفعه مرة أخرى."
            ) from error
        finally:
            lecture.file.close()

        if len(file_bytes) > 20 * 1024 * 1024:
            raise QuizQuestionGenerationError(
                "حجم ملف المحاضرة أكبر من الحد المسموح لتوليد الأسئلة."
            )
        parts.append({
            "inline_data": {
                "mime_type": "application/pdf",
                "data": base64.b64encode(file_bytes).decode("ascii"),
            }
        })

    if not parts:
        raise QuizQuestionGenerationError(
            "لا يوجد محتوى نصي أو ملف PDF لهذه المحاضرة."
        )
    return parts


def _generate_questions_from_model(
    lecture: LectureContent,
    count: int,
    difficulty: str,
    excluded_questions: list[str],
) -> list[dict]:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        raise QuizQuestionGenerationError(
            "التوليد التلقائي للأسئلة غير مفعّل حاليًا. يرجى التواصل مع الإدارة."
        )

    difficulty_labels = {
        "easy": "سهل: فهم المصطلحات والمفاهيم الأساسية",
        "medium": "متوسط: تطبيق المفاهيم والتمييز بين الحالات",
        "hard": "صعب: تحليل سيناريوهات وربط عدة أفكار من المحاضرة",
    }
    excluded_text = "\n".join(f"- {question}" for question in excluded_questions)
    prompt = (
        "أنشئ أسئلة اختبار جامعية أصلية اعتمادًا حصريًا على محتوى المحاضرة المرفق. "
        "اكتب الأسئلة والاختيارات والشرح باللغة العربية مع إبقاء المصطلحات التقنية "
        "الإنجليزية عند الحاجة. اجعل الأسئلة متنوعة وتقيس الفهم والتطبيق والتحليل، "
        "ولا تسأل عن معلومة غير موجودة في المحاضرة. لكل سؤال أربعة اختيارات مختلفة، "
        "إجابة صحيحة واحدة، وشرح موجز يوضح سبب صحتها. "
        f"المادة: {lecture.subject}. رقم المحاضرة: {lecture.lecture_number}. "
        f"مستوى الصعوبة المطلوب: {difficulty_labels[difficulty]}. "
        f"أنشئ {count} سؤالًا بالضبط. لا تكرر أي سؤال من هذه الأسئلة السابقة "
        "ولا تعِد صياغتها فقط:\n"
        f"{excluded_text}\n"
        'أعد JSON فقط بالشكل: {"questions":[{"question":"...",'
        '"options":["...","...","...","..."],"correct_index":0,'
        '"explanation":"..."}]}'
    )
    content_parts = [{"text": prompt}, *_lecture_source_parts(lecture)]
    model = settings.GEMINI_QUIZ_MODEL
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={api_key}"
    )
    payload = json.dumps({
        "contents": [{"parts": content_parts}],
        "generationConfig": {
            "maxOutputTokens": 16384,
            "temperature": 0.8,
            "responseMimeType": "application/json",
        },
    }).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            response_data = json.loads(response.read().decode("utf-8"))
        response_text = "".join(
            part.get("text", "")
            for part in response_data["candidates"][0]["content"]["parts"]
        )
        parsed = json.loads(response_text)
    except (
        urllib.error.URLError,
        TimeoutError,
        KeyError,
        IndexError,
        TypeError,
        ValueError,
    ) as error:
        raise QuizQuestionGenerationError(
            "تعذر إنشاء الأسئلة الآن. حاول مرة أخرى بعد قليل."
        ) from error

    questions = parsed.get("questions") if isinstance(parsed, dict) else None
    if not isinstance(questions, list):
        raise QuizQuestionGenerationError(
            "تعذر قراءة الأسئلة التي تم إنشاؤها. حاول مرة أخرى."
        )
    return questions


def _get_questions_for_quiz(
    subject: str,
    count: int,
    difficulty: str,
    lecture_number: int,
    user: User,
) -> list[dict]:
    lecture = LectureContent.objects.get(
        subject=subject,
        lecture_number=lecture_number,
    )

    for _ in range(4):
        with transaction.atomic():
            User.objects.select_for_update().get(pk=user.pk)
            available = list(
                GeneratedQuizQuestion.objects.filter(
                    subject=subject,
                    lecture_number=lecture_number,
                    difficulty=difficulty,
                )
                .exclude(usage_records__user=user)
                .order_by("id")[:count]
            )
            if len(available) >= count:
                random.shuffle(available)
                selected = available[:count]
                QuizQuestionUsage.objects.bulk_create([
                    QuizQuestionUsage(user=user, question=question)
                    for question in selected
                ])
                return [
                    {
                        "id": index,
                        "question": question.question,
                        "options": question.options,
                        "correct_index": question.correct_index,
                        "explanation": question.explanation,
                    }
                    for index, question in enumerate(selected, 1)
                ]

        used_questions = list(
            QuizQuestionUsage.objects.filter(user=user)
            .select_related("question")
            .order_by("-used_at")
            .values_list("question__question", flat=True)[:100]
        )
        previous_for_lecture = list(
            GeneratedQuizQuestion.objects.filter(
                subject=subject,
                lecture_number=lecture_number,
            ).values_list("question", flat=True)
        )
        excluded_questions = list(dict.fromkeys([
            *used_questions,
            *previous_for_lecture,
        ]))
        generated = _generate_questions_from_model(
            lecture,
            count - len(available),
            difficulty,
            excluded_questions,
        )

        seen_in_batch = set()
        for item in generated:
            if not isinstance(item, dict):
                continue
            question = item.get("question")
            options = item.get("options")
            correct_index = item.get("correct_index")
            explanation = item.get("explanation")
            if (
                not isinstance(question, str)
                or not question.strip()
                or not isinstance(options, list)
                or len(options) != 4
                or any(not isinstance(option, str) or not option.strip() for option in options)
                or len({_normalize_question(option) for option in options}) != 4
                or isinstance(correct_index, bool)
                or not isinstance(correct_index, int)
                or not 0 <= correct_index < 4
                or not isinstance(explanation, str)
                or not explanation.strip()
            ):
                continue

            fingerprint = _question_fingerprint(question)
            if not _normalize_question(question) or fingerprint in seen_in_batch:
                continue
            seen_in_batch.add(fingerprint)
            try:
                GeneratedQuizQuestion.objects.get_or_create(
                    fingerprint=fingerprint,
                    defaults={
                        "subject": subject,
                        "lecture_number": lecture_number,
                        "difficulty": difficulty,
                        "question": question.strip(),
                        "options": options,
                        "correct_index": correct_index,
                        "explanation": explanation.strip(),
                    },
                )
            except IntegrityError:
                continue

    raise QuizQuestionGenerationError(
        "لم نتمكن من إنشاء عدد كافٍ من الأسئلة الجديدة دون تكرار. حاول مرة أخرى."
    )


def _parse_integer(value):
    if isinstance(value, bool):
        return None
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return None
    if str(parsed) != str(value).strip():
        return None
    return parsed


def _lecture_has_content(subject: str, lecture_number: int) -> bool:
    lecture = LectureContent.objects.filter(
        subject=subject,
        lecture_number=lecture_number,
    ).first()
    return bool(lecture and ((lecture.content or "").strip() or lecture.file))


class QuizAvailabilityView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        subject = request.query_params.get("subject")
        lecture_number = _parse_integer(request.query_params.get("lecture"))
        if (
            not isinstance(subject, str)
            or subject not in LectureContent.SUBJECT_LECTURE_COUNTS
        ):
            return Response(
                {"detail": "المادة المختارة غير صالحة."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if (
            lecture_number is None
            or not 1 <= lecture_number <= LectureContent.SUBJECT_LECTURE_COUNTS[subject]
        ):
            return Response(
                {"detail": "رقم المحاضرة غير صالح للمادة المختارة."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        available = _lecture_has_content(subject, lecture_number)
        return Response({
            "available": available,
            "message": "" if available else NO_LECTURE_CONTENT_MESSAGE,
        })


class QuizSetupView(APIView):
    """
    إعداد الاختبار: توليد أسئلة ديناميكية بناءً على المادة والعدد والمستوى
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        subject = request.data.get("subject")
        lecture_number = _parse_integer(request.data.get("lecture"))
        count = _parse_integer(request.data.get("count"))
        difficulty = request.data.get("difficulty")

        if not isinstance(subject, str) or subject not in QUESTION_BANK:
            return Response(
                {"detail": "يرجى اختيار مادة صالحة."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if (
            lecture_number is None
            or not 1 <= lecture_number <= LectureContent.SUBJECT_LECTURE_COUNTS[subject]
        ):
            return Response(
                {"detail": "يرجى اختيار رقم محاضرة صالح."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if count not in QUESTION_COUNTS:
            return Response(
                {"detail": "عدد الأسئلة المختار غير صالح."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(difficulty, str) or difficulty not in (
            "easy",
            "medium",
            "hard",
        ):
            return Response(
                {"detail": "يرجى اختيار مستوى صعوبة صالح."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not _lecture_has_content(subject, lecture_number):
            return Response(
                {"detail": NO_LECTURE_CONTENT_MESSAGE},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            questions = _get_questions_for_quiz(
                subject,
                count,
                difficulty,
                lecture_number,
                request.user,
            )
        except QuizQuestionGenerationError as error:
            return Response(
                {"detail": str(error)},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        xp_per_correct = 1
        max_xp = count * xp_per_correct

        return Response({
            "quiz_id": f"custom_{subject[:10].replace(' ', '_')}_l{lecture_number}_{count}_{difficulty}",
            "subject": subject,
            "lecture": lecture_number,
            "difficulty": difficulty,
            "count": count,
            "xp_per_correct": xp_per_correct,
            "max_xp": max_xp,
            "questions": questions,
        })


class QuizListView(APIView):
    """
    قائمة المواد المتاحة والاختبارات الجاهزة
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        subjects = list(QUESTION_BANK.keys())
        difficulties = [
            {"key": "easy", "label": "سهل", "xp_per_correct": 10},
            {"key": "medium", "label": "متوسط", "xp_per_correct": 25},
            {"key": "hard", "label": "صعب", "xp_per_correct": 50},
        ]
        return Response({
            "subjects": subjects,
            "lecture_counts": LectureContent.SUBJECT_LECTURE_COUNTS,
            "difficulties": difficulties,
            "question_counts": QUESTION_COUNTS,
        })


# ─────────────────────────────────────────────────────────────
# QUIZ SUBMIT
# ─────────────────────────────────────────────────────────────

class QuizSubmitView(APIView):
    """
    تسليم نتيجة الاختبار وحساب وإضافة نقاط الـ XP للطالب
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        quiz_id = request.data.get("quiz_id", "unknown")
        score = int(request.data.get("score", 0))
        total_questions = max(int(request.data.get("total_questions", 1)), 1)
        earned_xp = int(request.data.get("earned_xp", 0))

        # تحديث XP و Streak
        user = request.user
        is_perfect = score == total_questions

        user.xp_points = F("xp_points") + earned_xp
        user.xp = F("xp") + earned_xp
        if is_perfect:
            user.streak = F("streak") + 1
        user.save(update_fields=["xp_points", "xp", "streak", "updated_at"])
        user.refresh_from_db()

        return Response({
            "message": f"أحسنت! حصلت على +{earned_xp} XP بنجاح.",
            "earned_xp": earned_xp,
            "new_xp": user.xp_points,
            "new_streak": user.streak,
            "is_perfect": is_perfect,
            "user": UserSerializer(user).data,
        })


class AIChatView(APIView):
    """Answer questions using only the selected subject's indexed materials."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        message = (request.data.get("message") or "").strip()
        if not message:
            return Response(
                {"error": "الرسالة لا يمكن أن تكون فارغة"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(message) > 4000:
            return Response(
                {"detail": "السؤال أطول من الحد المسموح."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        subject = request.data.get("subject")
        if not isinstance(subject, str) or not subject.strip():
            return Response(
                {"detail": "اختر المادة قبل إرسال السؤال."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        raw_lecture_number = request.data.get("lecture")
        lecture_number = None
        if raw_lecture_number not in (None, ""):
            lecture_number = _parse_integer(raw_lecture_number)
            if (
                lecture_number is None
                or subject not in LectureContent.SUBJECT_LECTURE_COUNTS
                or not 1 <= lecture_number
                <= LectureContent.SUBJECT_LECTURE_COUNTS[subject]
            ):
                return Response(
                    {"detail": "رقم المحاضرة غير صالح للمادة المختارة."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        try:
            result = ask_academic_question(
                user=request.user,
                subject=subject.strip(),
                question=message,
                lecture_number=lecture_number,
            )
        except AcademicAIScopeError as error:
            return Response(
                {"detail": str(error)},
                status=status.HTTP_403_FORBIDDEN,
            )
        except GeminiServiceError as error:
            return Response(
                {"detail": str(error)},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response({
            **result,
            "subject": subject,
        })


class AISummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        subject = request.data.get("subject")
        lecture_number = _parse_integer(request.data.get("lecture"))
        summary_type = request.data.get("summary_type", AISummary.SummaryType.QUICK)

        if not isinstance(subject, str) or not subject.strip():
            return Response(
                {"detail": "اختر المادة قبل إنشاء الملخص."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if lecture_number is None:
            return Response(
                {"detail": "اختر رقم المحاضرة لإنشاء الملخص."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if summary_type not in AISummary.SummaryType.values:
            return Response(
                {"detail": "نوع الملخص غير صالح."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            summary = summarize_academic_lecture(
                user=request.user,
                subject=subject.strip(),
                lecture_number=lecture_number,
                summary_type=summary_type,
            )
        except AcademicAIScopeError as error:
            return Response(
                {"detail": str(error)},
                status=status.HTTP_403_FORBIDDEN,
            )
        except ValueError as error:
            return Response(
                {"detail": str(error)},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except GeminiServiceError as error:
            return Response(
                {"detail": str(error)},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response(summary, status=status.HTTP_200_OK)


# ─────────────────────────────────────────────────────────────
# ADMIN TEST
# ─────────────────────────────────────────────────────────────

class AdminTestView(generics.GenericAPIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        return Response({
            "message": "Admin access granted.",
            "username": request.user.username,
            "role": request.user.role,
        })


# ─────────────────────────────────────────────────────────────
# LEGACY LOGIN (للتوافق مع الشيفرة القديمة)
# ─────────────────────────────────────────────────────────────

@csrf_exempt
def api_login(request):
    if request.method != "POST":
        return JsonResponse({"status": "error", "message": "Only POST method allowed"}, status=405)
    try:
        data = json.loads(request.body)
    except (json.JSONDecodeError, Exception):
        data = {}
    username = data.get("username")
    password = data.get("password")
    user = authenticate(username=username, password=password)
    if user is not None:
        return JsonResponse(
            {"status": "success", "message": "Logged in successfully", "username": user.username},
            status=200,
        )
    return JsonResponse({"status": "error", "message": "Invalid credentials"}, status=400)