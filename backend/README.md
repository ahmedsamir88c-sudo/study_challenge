# Study Challenge Backend

Django + Django REST Framework backend for the Study Challenge platform, with
PostgreSQL as the default database and optional MySQL support.

## 1. Requirements

- Python 3.12+
- Docker Desktop (recommended for PostgreSQL)
- Git

## 2. Start PostgreSQL

```bash
docker compose up -d db
```

## 3. Create Python environment

Windows:

```powershell
py -3.12 -m venv .venv
.venv\Scripts\Activate.ps1
```

Linux/macOS:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
```

## 4. Install dependencies

```bash
pip install -r requirements.txt
```

## 5. Configure environment

Copy `.env.example` to `.env` and change the secret/password values.
When `MYSQL_DB` is set and `DATABASE_ENGINE` is omitted, the backend selects
MySQL automatically. Otherwise, it uses PostgreSQL. Configure the matching
database credentials in `.env`.

MySQL also requires the `PyMySQL` dependency from `requirements.txt`.

Set `GEMINI_API_KEY` in `.env` to enable automatic quiz-question generation.
`GEMINI_QUIZ_MODEL` is optional and defaults to `gemini-2.5-flash`. Each lecture
must have text or a PDF uploaded through Django admin before questions can be
generated. Generated questions are saved and are not reused for the same user.

To create the owner account, set `OWNER_UNIVERSITY_ID` in `.env` and run
`python manage.py create_owner`. The command asks for the owner's name and a
hidden password, hashes the password through Django, and refuses to promote an
existing account automatically. The configured university ID must not already
belong to another account.

## 6. Run migrations

```bash
python manage.py migrate
```

## 7. Create an admin account

```bash
python manage.py createsuperuser
```

## 8. Start API

```bash
python manage.py runserver 0.0.0.0:8000
```

This development server listens on all local interfaces so the Android emulator
can reach it through `10.0.2.2`. The Flutter app already uses that address for
Android. Keep `10.0.2.2` in `DJANGO_ALLOWED_HOSTS` in `.env`.
The Android debug build permits HTTP for local development; production builds
must use an HTTPS API.

API base on the host:

```text
http://127.0.0.1:8000/api/
```

Django admin:

```text
http://127.0.0.1:8000/admin/
```

## Authentication

Register:

```http
POST /api/auth/register/
```

Login:

```http
POST /api/auth/login/
```

Refresh:

```http
POST /api/auth/token/refresh/
```

Current user:

```http
GET /api/auth/me/
Authorization: Bearer <access_token>
```

Admin-only test endpoint:

```http
GET /api/auth/admin-test/
Authorization: Bearer <access_token>
```

The backend uses a custom user model from the first migration. Do not switch to Django's default User model later; extend this model instead.
