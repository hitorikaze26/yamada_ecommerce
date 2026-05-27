from flask_wtf.csrf import CSRFProtect
from flask_mailman import Mail
from flask_jwt_extended import JWTManager
from flask_bcrypt import Bcrypt
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

# Note: Migrate (flask_migrate) is intentionally not imported here to avoid
# importing alembic/mako at module import time. Initialize Migrate inside
# `create_app` where the app and db are available.
mail = Mail()
csrf = CSRFProtect()
jwt = JWTManager()
bcrypt = Bcrypt()
limiter = Limiter(key_func=get_remote_address, default_limits=["1000 per day", "200 per hour"])