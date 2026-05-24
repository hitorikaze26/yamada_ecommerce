from flask_wtf.csrf import CSRFProtect
from flask_mailman import Mail
from flask_jwt_extended import JWTManager
from flask_bcrypt import Bcrypt

# Note: Migrate (flask_migrate) is intentionally not imported here to avoid
# importing alembic/mako at module import time. Initialize Migrate inside
# `create_app` where the app and db are available.
mail = Mail()
csrf = CSRFProtect()
jwt = JWTManager()
bcrypt = Bcrypt()