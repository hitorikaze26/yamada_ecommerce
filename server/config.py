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


class Config:
    TESTING = False

    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-change-me")
    WTF_CSRF_SECRET_KEY = os.environ.get("WTF_CSRF_SECRET_KEY", "dev-csrf-change-me")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "dev-jwt-change-me")

    WTF_CSRF_CHECK_DEFAULT = False
    WTF_CSRF_TIME_LIMIT = None

    JWT_TOKEN_LOCATION = ["headers", "cookies", "json", "query_string"]
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    JWT_COOKIE_SECURE = False
    JWT_COOKIE_SAMESITE = None
    JWT_COOKIE_CSRF_PROTECT = False
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
    MAIL_BACKEND = os.environ.get("MAIL_BACKEND", "console")

    TWILIO_ACCOUNT_SID = os.environ.get("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN = os.environ.get("TWILIO_AUTH_TOKEN", "")
    TWILIO_FROM_NUMBER = os.environ.get("TWILIO_FROM_NUMBER", "")

    OPENROUTESERVICE_API_KEY = os.environ.get("OPENROUTESERVICE_API_KEY", "")


def _engine_options_for_uri(uri: str | None) -> dict:
    """Postgres (Supabase) needs SSL + timeout on every environment."""
    if uri and "postgresql" in uri:
        return {
            **Config.SQLALCHEMY_ENGINE_OPTIONS,
            "connect_args": {
                "connect_timeout": 15,
                "sslmode": "require",
            },
        }
    return dict(Config.SQLALCHEMY_ENGINE_OPTIONS)


_dev_uri = _database_url(
    os.environ.get(
        "DEV_DATABASE_URL",
        "mysql+pymysql://root:changeme@localhost:3306/yamada_db",
    )
)


class DevelopmentConfig(Config):
    DEBUG = True
    DB_SERVER = os.environ.get("DB_SERVER", "127.0.0.1")
    SQLALCHEMY_DATABASE_URI = _dev_uri
    SQLALCHEMY_ENGINE_OPTIONS = _engine_options_for_uri(_dev_uri)


class ProductionConfig(Config):
    DEBUG = False
    JWT_COOKIE_SECURE = True
    JWT_COOKIE_SAMESITE = "None"
    JWT_COOKIE_CSRF_PROTECT = False
    MAIL_BACKEND = os.environ.get("MAIL_BACKEND", "smtp")
    _prod_uri = _database_url()
    SQLALCHEMY_DATABASE_URI = _prod_uri
    SQLALCHEMY_ENGINE_OPTIONS = _engine_options_for_uri(_prod_uri)


_test_uri = _database_url(
    os.environ.get(
        "TEST_DATABASE_URL",
        "mysql+pymysql://root:changeme@localhost:3306/yamada_db_test",
    )
)


class TestingConfig(Config):
    TESTING = True
    DEBUG = False
    DB_SERVER = "127.0.0.1"
    SQLALCHEMY_DATABASE_URI = _test_uri
    SQLALCHEMY_ENGINE_OPTIONS = _engine_options_for_uri(_test_uri)
    MAIL_SERVER = "sandbox.smtp.mailtrap.io"
    MAIL_PORT = 587
    MAIL_USE_TLS = True
    MAIL_USERNAME = os.environ.get("MAIL_USERNAME", "")
    MAIL_PASSWORD = os.environ.get("MAIL_PASSWORD", "")
    MAIL_DEFAULT_SENDER = "Yamada Test <test@example.com>"


config = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "testing": TestingConfig,
    "default": DevelopmentConfig,
}
