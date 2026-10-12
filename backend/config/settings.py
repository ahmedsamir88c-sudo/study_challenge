from _frozen_importlib import module_from_spec
from pathlib import Path
from datetime import timedelta
import os
import sys

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "dev-only-secret-change-me")
DEBUG = os.getenv("DJANGO_DEBUG", "False").lower() == "true"

ALLOWED_HOSTS = [
    host.strip()
    for host in os.getenv("DJANGO_ALLOWED_HOSTS", "127.0.0.1,localhost,10.0.2.2,*").split(",")
    if host.strip()
]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "rest_framework_simplejwt",
    "apps.users",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASE_ENGINE = os.getenv("DATABASE_ENGINE", "").strip() or os.getenv(
    "DB_ENGINE",
    "",
).strip()

IS_TESTING = "test" in sys.argv or "pytest" in sys.argv[0]
USE_EXTERNAL_DB_FOR_TESTS = (
    os.getenv("USE_EXTERNAL_DB_FOR_TESTS", "").strip().lower()
    in {"1", "true", "yes"}
)

if IS_TESTING and not USE_EXTERNAL_DB_FOR_TESTS:
    DATABASE_ENGINE = "django.db.backends.sqlite3"
elif not DATABASE_ENGINE:
    DATABASE_ENGINE = "django.db.backends.postgresql"

if DATABASE_ENGINE == "django.db.backends.mysql":
    import pymysql

    pymysql.install_as_MySQLdb()

if DATABASE_ENGINE == "django.db.backends.sqlite3":
    DATABASES = {
        "default": {
            "ENGINE": DATABASE_ENGINE,
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }
else:
    DATABASE_ENV_PREFIX = (
        "MYSQL" if DATABASE_ENGINE == "django.db.backends.mysql" else "POSTGRES"
    )
    DATABASES = {
        "default": {
            "ENGINE": DATABASE_ENGINE,
            "NAME": os.getenv(f"{DATABASE_ENV_PREFIX}_DB", "study_challenge"),
            "USER": os.getenv(
                f"{DATABASE_ENV_PREFIX}_USER",
                "root" if DATABASE_ENV_PREFIX == "MYSQL" else "study_admin",
            ),
            "PASSWORD": os.getenv(f"{DATABASE_ENV_PREFIX}_PASSWORD", ""),
            "HOST": os.getenv(f"{DATABASE_ENV_PREFIX}_HOST", "127.0.0.1"),
            "PORT": os.getenv(
                f"{DATABASE_ENV_PREFIX}_PORT",
                "3306" if DATABASE_ENV_PREFIX == "MYSQL" else "5432",
            ),
        }
    }

AUTH_USER_MODEL = "users.User"
OWNER_UNIVERSITY_ID = os.getenv("OWNER_UNIVERSITY_ID", "42510677").strip()

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "Africa/Cairo"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

CORS_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ALLOWED_ORIGINS",
        "http://localhost:3000,http://127.0.0.1:3000",
    ).split(",")
    if origin.strip()
]

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
    "DEFAULT_RENDERER_CLASSES": (
        "rest_framework.renderers.JSONRenderer",
    ),
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(
        minutes=int(os.getenv("JWT_ACCESS_MINUTES", "30"))
    ),
    "REFRESH_TOKEN_LIFETIME": timedelta(
        days=int(os.getenv("JWT_REFRESH_DAYS", "7"))
    ),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_FAST_MODEL = os.getenv("GEMINI_FAST_MODEL", "gemini-2.5-flash").strip()
GEMINI_ADVANCED_MODEL = os.getenv(
    "GEMINI_ADVANCED_MODEL",
    "gemini-2.5-pro",
).strip()
GEMINI_QUIZ_MODEL = os.getenv("GEMINI_QUIZ_MODEL", GEMINI_FAST_MODEL).strip()
GEMINI_EMBEDDING_MODEL = os.getenv(
    "GEMINI_EMBEDDING_MODEL",
    "gemini-embedding-001",
).strip()
GEMINI_EMBEDDING_DIMENSIONS = int(
    os.getenv("GEMINI_EMBEDDING_DIMENSIONS", "768")
)
AI_RAG_TOP_K = int(os.getenv("AI_RAG_TOP_K", "5"))
AI_RAG_MIN_SIMILARITY = float(os.getenv("AI_RAG_MIN_SIMILARITY", "0.35"))
AI_RAG_MAX_PDF_BYTES = int(os.getenv("AI_RAG_MAX_PDF_BYTES", str(20 * 1024 * 1024)))

SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
SECURE_REFERRER_POLICY = "same-origin"

if not DEBUG:
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_SSL_REDIRECT = True
