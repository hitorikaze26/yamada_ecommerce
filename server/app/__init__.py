import os

from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS
from .models import (
    db,
    Role
)
from .seed_commands import seed_admin_command, seed_report_types_command
from .extensions import (
    csrf, 
    mail, 
    jwt,
    bcrypt,
    limiter,
)
from config import config

# Match production + preview Vercel deployments + custom domain
_VERCEL_ORIGIN_PATTERN = r"^https://[\w-]+\.vercel\.app$"


def _expand_origins(raw: str) -> list[str]:
    """Split comma/semicolon-separated origins, strip whitespace/quotes."""
    out: list[str] = []
    seen: set[str] = set()
    for part in raw.replace(";", ",").split(","):
        origin = part.strip().strip('"').strip("'")
        if origin and origin not in seen:
            seen.add(origin)
            out.append(origin)
    return out


def _cors_allowed_origins() -> list[str]:
    """Parse CORS_ORIGINS and add safe production defaults."""
    raw = os.environ.get(
        "CORS_ORIGINS",
        "http://127.0.0.1:3000,http://localhost:3000",
    )
    origins = _expand_origins(raw)

    # In production, always allow the Vercel origin wildcard
    if os.environ.get("FLASK_ENV", "development") == "production":
        origins.append(_VERCEL_ORIGIN_PATTERN)

    return origins


def create_app(test_config=None):
    load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
    # Explicitly configure static folder so uploaded documents under app/static
    # are served at /static/...
    app = Flask(
        __name__,
        instance_relative_config=True,
        static_folder="static",
        static_url_path="/static",
    )

    if test_config is None:
        env = os.environ.get("FLASK_ENV", "development")
        config_class = config.get(env, config["development"])
        app.config.from_object(config_class)
        if env == "production":
            missing = []
            if not app.config.get("SQLALCHEMY_DATABASE_URI"):
                missing.append("DATABASE_URL")
            if not app.config.get("SECRET_KEY"):
                missing.append("SECRET_KEY")
            if not app.config.get("JWT_SECRET_KEY"):
                missing.append("JWT_SECRET_KEY")
            if missing:
                raise RuntimeError(
                    f"Missing required env vars in production: {', '.join(missing)}"
                )
            if not os.environ.get("SUPABASE_URL") or not os.environ.get(
                "SUPABASE_SERVICE_KEY"
            ):
                app.logger.warning(
                    "SUPABASE_URL / SUPABASE_SERVICE_KEY not set — uploads use "
                    "ephemeral local disk on Railway."
                )
    else:
        app.config.from_object(config["testing"])

    # Disable strict slashes to prevent 308 redirects that break CORS preflight
    app.url_map.strict_slashes = False

    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass

    db.init_app(app)
    # Initialize flask-migrate here to avoid importing alembic/mako during module import
    from flask_migrate import Migrate
    migrate = Migrate()
    migrate.init_app(app, db)
    csrf.init_app(app)
    mail.init_app(app)
    jwt.init_app(app)
    bcrypt.init_app(app)
    limiter.init_app(app)

    CORS(
        app,
        resources={r"/api/*": {"origins": _cors_allowed_origins()}},
        supports_credentials=True,
    )

    @app.route("/api/health")
    def health_check():
        checks = {"api": "ok", "database": "unknown", "storage": "local"}
        try:
            from sqlalchemy import text

            db.session.execute(text("SELECT 1"))
            checks["database"] = "ok"
        except Exception as exc:
            checks["database"] = "error"
            checks["database_error"] = str(exc)[:200]
        if os.environ.get("SUPABASE_URL") and os.environ.get("SUPABASE_SERVICE_KEY"):
            checks["storage"] = "supabase"
        status_code = 200 if checks["database"] == "ok" else 503
        return {"status": "ok" if status_code == 200 else "degraded", "checks": checks}, status_code

    from .notifications.realtime import init_socketio
    init_socketio(app)

    with app.app_context():
        pass
        # db.create_all()
        # db.session.add(Role(name="seller"))
        # db.session.add(Role(name="buyer"))
        # db.session.add(Role(name="admin"))
        # db.session.commit()

    from .auth import auth as auth_bp
    app.register_blueprint(auth_bp, url_prefix='/api/accounts')
    from .product import products as products_bp
    app.register_blueprint(products_bp, url_prefix='/api/products')
    from .seller import seller as seller_bp
    app.register_blueprint(seller_bp, url_prefix='/api/seller')
    from .store import store as store_bp
    app.register_blueprint(store_bp, url_prefix='/api/store')
    from .stores_public import stores_public as stores_public_bp
    app.register_blueprint(stores_public_bp, url_prefix='/api/stores')
    from .admin import admin as admin_bp
    app.register_blueprint(admin_bp, url_prefix='/api/admin')
    from .admin.commission_routes import commission_bp
    app.register_blueprint(commission_bp, url_prefix='/api/admin/commission')
    from .cart import cart as cart_bp
    app.register_blueprint(cart_bp, url_prefix='/api/cart')
    from .order import orders as orders_bp
    app.register_blueprint(orders_bp, url_prefix='/api')
    from .notifications import notifications as notifications_bp
    app.register_blueprint(notifications_bp, url_prefix='/api')
    from .chat import chat as chat_bp
    app.register_blueprint(chat_bp, url_prefix='/api/chat')
    from .api.philippine_locations import philippine_locations_bp
    app.register_blueprint(philippine_locations_bp)
    from .api.shipping import shipping_bp
    app.register_blueprint(shipping_bp, url_prefix='/api')
    from .api.user_addresses import user_bp
    app.register_blueprint(user_bp, url_prefix='/api')
    from .reports import reports as reports_bp
    app.register_blueprint(reports_bp, url_prefix='/api/reports')

    # Register CLI commands
    app.cli.add_command(seed_admin_command)
    app.cli.add_command(seed_report_types_command)

    return app