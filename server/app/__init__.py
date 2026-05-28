import os

from dotenv import load_dotenv
from flask import Flask, current_app
from flask_cors import CORS
from .models import (
    db,
    Role
)
from .seed_commands import seed_admin_command, seed_report_types_command, seed_categories_command, geofill_stores_command
from .extensions import (
    csrf, 
    jwt,
    bcrypt,
    limiter,
)
from config import config, apply_env_overrides


PLACEHOLDER_SVG = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" '
    'viewBox="0 0 400 400">'
    '<rect width="400" height="400" fill="#f3f4f6"/>'
    '<text x="200" y="200" font-family="sans-serif" font-size="16" '
    'fill="#9ca3af" text-anchor="middle" dominant-baseline="middle">'
    "No Image</text></svg>"
)


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
        apply_env_overrides(app)
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
            if not app.config.get("SUPABASE_ENABLED"):
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
    jwt.init_app(app)
    bcrypt.init_app(app)
    limiter.init_app(app)

    CORS(
        app,
        origins=app.config["CORS_ORIGINS"],
        supports_credentials=True,
        automatic_options=True,
    )

    @app.route("/placeholder.svg")
    def placeholder_svg():
        from flask import Response
        return Response(PLACEHOLDER_SVG, mimetype="image/svg+xml")

    # Catch 404s under /static/ and return placeholder instead
    @app.errorhandler(404)
    def not_found(e):
        from flask import request, Response, jsonify
        if request.path.startswith("/static/"):
            return Response(PLACEHOLDER_SVG, mimetype="image/svg+xml")
        resp = jsonify({"error": "Not found"})
        resp.status_code = 404
        return resp

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
        if current_app.config.get("SUPABASE_ENABLED"):
            from app.utils.supabase_storage import probe_storage_connection

            probe = probe_storage_connection()
            checks["storage"] = "supabase" if probe.get("reachable") else "supabase_misconfigured"
            checks["storage_probe"] = probe
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

    from .security import register_security_hooks

    register_security_hooks(app)

    # Register CLI commands
    app.cli.add_command(seed_admin_command)
    app.cli.add_command(seed_report_types_command)
    app.cli.add_command(seed_categories_command)
    app.cli.add_command(geofill_stores_command)

    return app