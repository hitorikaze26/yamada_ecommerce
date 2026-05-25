import os
from datetime import timedelta


def _normalize_database_url(url: str) -> str:
    """Normalize DATABASE_URL for SQLAlchemy (Supabase/Railway use postgres://)."""
    if url.startswith("postgres://"):
        return url.replace("postgres://", "postgresql+psycopg2://", 1)
    if url.startswith("postgresql://") and "+psycopg2" not in url:
        url = url.replace("postgresql://", "postgresql+psycopg2://", 1)
    if "supabase.co" in url and "sslmode=" not in url:
        sep = "&" if "?" in url else "?"
        url = f"{url}{sep}sslmode=require"
    return url


def _database_url(fallback: str | None = None) -> str | None:
    url = os.environ.get("DATABASE_URL")
    if url:
        return _normalize_database_url(url)
    return fallback


def _engine_options_for_uri(uri: str | None) -> dict:
    """Postgres (Supabase) needs SSL + timeout on every environment."""
    if uri and "postgresql" in uri:
        return {
            "pool_pre_ping": True,
            "connect_args": {
                "connect_timeout": 15,
                "sslmode": "require",
            },
        }
    return {"pool_pre_ping": True}


def _resolve_frontend_url() -> str:
    """Derive canonical frontend URL from env or build from Railway."""
    explicit = os.environ.get("FRONTEND_URL", "").strip()
    if explicit:
        return explicit.rstrip("/")
    vercel = os.environ.get("VERCEL_URL", "").strip()
    if vercel:
        return f"https://{vercel}"
    vercel_branch = os.environ.get("VERCEL_BRANCH_URL", "").strip()
    if vercel_branch:
        return f"https://{vercel_branch}"
    return "http://localhost:3000"


def _resolve_api_base_url() -> str:
    """Derive canonical backend API base URL from env or build from Railway."""
    explicit = os.environ.get("API_BASE_URL", "").strip()
    if explicit:
        return explicit.rstrip("/")
    railway = os.environ.get("RAILWAY_PUBLIC_DOMAIN", "").strip()
    if railway:
        return f"https://{railway}/api"
    return "http://127.0.0.1:5000/api"


def _resolve_cors_origins(frontend_url: str) -> list[str]:
    """Build allowed CORS origins from FRONTEND_URL, CORS_ORIGINS env, and defaults."""
    raw = os.environ.get("CORS_ORIGINS", "").strip()
    origins: list[str] = []
    seen: set[str] = set()

    for part in raw.replace(";", ",").split(","):
        origin = part.strip().strip('"').strip("'")
        if origin and origin not in seen:
            seen.add(origin)
            origins.append(origin)

    if frontend_url and frontend_url not in seen:
        seen.add(frontend_url)
        origins.append(frontend_url)

    railwy_domain = os.environ.get("RAILWAY_PUBLIC_DOMAIN", "").strip()
    if railwy_domain:
        railwy_origin = f"https://{railwy_domain}"
        if railwy_origin not in seen:
            seen.add(railwy_origin)
            origins.append(railwy_origin)

    return origins


class Config:
    TESTING = False

    SECRET_KEY = os.environ.get("SECRET_KEY")
    WTF_CSRF_SECRET_KEY = os.environ.get("WTF_CSRF_SECRET_KEY")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY")

    WTF_CSRF_CHECK_DEFAULT = False
    WTF_CSRF_TIME_LIMIT = None

    JWT_TOKEN_LOCATION = ["headers", "cookies"]
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    JWT_COOKIE_CSRF_PROTECT = True
    JWT_ACCESS_CSRF_COOKIE_NAME = "csrf_access_token"
    JWT_ACCESS_CSRF_HEADER_NAME = "X-CSRF-TOKEN"
    JWT_ACCESS_COOKIE_PATH = "/"
    JWT_ACCESS_COOKIE_NAME = "access_token_cookie"

    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True}

    MAIL_SERVER = os.environ.get("MAIL_SERVER", "smtp.gmail.com")
    MAIL_PORT = int(os.environ.get("MAIL_PORT", "587"))
    MAIL_USE_TLS = os.environ.get("MAIL_USE_TLS", "true").lower() in (
        "1",
        "true",
        "yes",
    )
    MAIL_USERNAME = os.environ.get("MAIL_USERNAME", "")
    MAIL_PASSWORD = os.environ.get("MAIL_PASSWORD", "")
    MAIL_DEFAULT_SENDER = os.environ.get(
        "MAIL_DEFAULT_SENDER",
        "Yamada Support <noreply@example.com>",
    )
    MAIL_BACKEND = os.environ.get("MAIL_BACKEND", "smtp")

    TWILIO_ACCOUNT_SID = os.environ.get("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN = os.environ.get("TWILIO_AUTH_TOKEN", "")
    TWILIO_FROM_NUMBER = os.environ.get("TWILIO_FROM_NUMBER", "")

    OPENROUTESERVICE_API_KEY = os.environ.get("OPENROUTESERVICE_API_KEY", "")

    FRONTEND_URL = _resolve_frontend_url()
    API_BASE_URL = _resolve_api_base_url()

    SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
    SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
    SUPABASE_ENABLED = bool(SUPABASE_URL and SUPABASE_SERVICE_KEY)

    FORCE_SUPABASE_UPLOADS = os.environ.get("FORCE_SUPABASE_UPLOADS", "").lower() in (
        "1",
        "true",
        "yes",
    )

    CORS_ORIGINS = _resolve_cors_origins(FRONTEND_URL)

    DISABLE_STRICT_SLASHES = True


class DevelopmentConfig(Config):
    DEBUG = True

    DB_SERVER = os.environ.get("DB_SERVER", "127.0.0.1")

    JWT_COOKIE_SECURE = False
    JWT_COOKIE_SAMESITE = "Lax"

    _dev_uri = _database_url(
        os.environ.get(
            "DEV_DATABASE_URL",
            "mysql+pymysql://root:changeme@localhost:3306/yamada_db",
        )
    )
    SQLALCHEMY_DATABASE_URI = _dev_uri
    SQLALCHEMY_ENGINE_OPTIONS = _engine_options_for_uri(_dev_uri)

    SUPPORTS_LOCAL_STORAGE = True


class ProductionConfig(Config):
    DEBUG = False

    JWT_COOKIE_SECURE = True
    JWT_COOKIE_SAMESITE = "None"

    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=2)

    MAIL_BACKEND = os.environ.get("MAIL_BACKEND", "smtp")

    _prod_uri = _database_url()
    SQLALCHEMY_DATABASE_URI = _prod_uri
    SQLALCHEMY_ENGINE_OPTIONS = _engine_options_for_uri(_prod_uri)

    SUPPORTS_LOCAL_STORAGE = False


class TestingConfig(Config):
    TESTING = True
    DEBUG = False

    DB_SERVER = "127.0.0.1"

    JWT_COOKIE_SECURE = False
    JWT_COOKIE_SAMESITE = "Lax"

    _test_uri = _database_url(
        os.environ.get(
            "TEST_DATABASE_URL",
            "mysql+pymysql://root:changeme@localhost:3306/yamada_db_test",
        )
    )
    SQLALCHEMY_DATABASE_URI = _test_uri
    SQLALCHEMY_ENGINE_OPTIONS = _engine_options_for_uri(_test_uri)

    MAIL_SERVER = "sandbox.smtp.mailtrap.io"
    MAIL_PORT = 587
    MAIL_USE_TLS = True
    MAIL_USERNAME = os.environ.get("MAIL_USERNAME", "")
    MAIL_PASSWORD = os.environ.get("MAIL_PASSWORD", "")
    MAIL_DEFAULT_SENDER = "Yamada Test <test@example.com>"

    SUPPORTS_LOCAL_STORAGE = True


config = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "testing": TestingConfig,
    "default": DevelopmentConfig,
}
