from django.db import models
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import User


class UserSerializer(serializers.ModelSerializer):
    """سيريالايزر عرض بيانات المستخدم الكاملة"""
    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "university_id",
            "full_name",
            "email",
            "profile_picture",
            "profile_image",
            "academic_year",
            "department",
            "xp_points",
            "xp",
            "streak",
            "role",
            "created_at",
        ]
        read_only_fields = ["id", "role", "created_at"]


def normalize_arabic_digits(text: str) -> str:
    """تحويل الأرقام العربية والفارسية إلى أرقام إنجليزية قياسية"""
    if not text:
        return ""
    mapping = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
    return str(text).translate(mapping).strip()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    password_confirm = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = User
        fields = [
            "username",
            "university_id",
            "password",
            "password_confirm",
            "academic_year",
            "full_name",
            "email",
            "department",
        ]

    def validate_username(self, value):
        value = str(value).strip()
        if not value:
            raise serializers.ValidationError("اسم المستخدم مطلوب.")
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("اسم المستخدم هذا مستخدم بالفعل.")
        return value

    def validate_university_id(self, value):
        if value:
            value = normalize_arabic_digits(value)
            if User.objects.filter(university_id__iexact=value).exists():
                raise serializers.ValidationError("ID الجامعة هذا مسجل بالفعل.")
        return value

    def validate_academic_year(self, value):
        if value is not None and value not in [1, 2, 3, 4]:
            raise serializers.ValidationError("الفرقة الدراسية يجب أن تكون بين 1 و 4.")
        return value

    def validate(self, attrs):
        if "password_confirm" in attrs and attrs.get("password_confirm"):
            if attrs["password"] != attrs["password_confirm"]:
                raise serializers.ValidationError(
                    {"password_confirm": "كلمتا المرور غير متطابقتين."}
                )
        attrs.pop("password_confirm", None)
        return attrs

    def create(self, validated_data):
        if "university_id" in validated_data and validated_data["university_id"]:
            validated_data["university_id"] = normalize_arabic_digits(validated_data["university_id"])
        return User.objects.create_user(**validated_data)


class LoginSerializer(TokenObtainPairSerializer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["university_id"] = serializers.CharField(required=False, write_only=True)
        self.fields["username"].required = False

    def validate(self, attrs):
        raw_id = (attrs.get("university_id") or attrs.get("username") or "").strip()
        password = attrs.get("password", "")

        if not raw_id:
            raise serializers.ValidationError({"detail": "يرجى إدخال ID الجامعة أو اسم المستخدم."})
        if not password:
            raise serializers.ValidationError({"detail": "يرجى إدخال كلمة المرور."})

        norm_id = normalize_arabic_digits(raw_id)

        # البحث بجميع الاحتمالات: university_id أو username أو email (بالأرقام القياسية والعربية)
        user = User.objects.filter(
            models.Q(university_id__iexact=raw_id)
            | models.Q(university_id__iexact=norm_id)
            | models.Q(username__iexact=raw_id)
            | models.Q(username__iexact=norm_id)
            | models.Q(email__iexact=raw_id)
            | models.Q(email__iexact=norm_id)
        ).first()

        if user is None or not user.check_password(password):
            raise serializers.ValidationError(
                {"detail": "بيانات الدخول غير صحيحة. يرجى التأكد من الـ ID أو اسم المستخدم وكلمة المرور."}
            )

        if not user.is_active:
            raise serializers.ValidationError(
                {"detail": "هذا الحساب معطل. يرجى التواصل مع الإدارة."}
            )

        refresh = self.get_token(user)
        data = {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": UserSerializer(user).data,
        }
        return data

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["role"] = user.role
        token["username"] = user.username
        token["university_id"] = user.university_id or ""
        token["academic_year"] = user.academic_year or 1
        token["xp_points"] = user.xp_points
        return token


class UpdateProfileSerializer(serializers.ModelSerializer):
    """سيريالايزر تحديث الملف الشخصي"""
    class Meta:
        model = User
        fields = [
            "username",
            "full_name",
            "email",
            "profile_picture",
            "profile_image",
            "academic_year",
            "department",
        ]

    def validate_username(self, value):
        value = value.strip()
        user = self.instance
        if User.objects.filter(username__iexact=value).exclude(pk=user.pk).exists():
            raise serializers.ValidationError("اسم المستخدم هذا مستخدم بالفعل.")
        return value

    def validate_academic_year(self, value):
        if value is not None and value not in [1, 2, 3, 4]:
            raise serializers.ValidationError("الفرقة الدراسية يجب أن تكون بين 1 و 4.")
        return value
