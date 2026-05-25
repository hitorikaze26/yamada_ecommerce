"""Production security helpers: headers and sanitized errors."""

import os

from flask import jsonify, request


def register_security_hooks(app) -> None:
    @app.after_request
    def set_security_headers(response):
        if os.environ.get("FLASK_ENV", "development") == "production":
            response.headers.setdefault("X-Content-Type-Options", "nosniff")
            response.headers.setdefault("X-Frame-Options", "DENY")
            response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
            response.headers.setdefault(
                "Permissions-Policy",
                "camera=(), microphone=(), geolocation=()",
            )
        return response

    @app.errorhandler(500)
    def internal_error(_error):
        if os.environ.get("FLASK_ENV", "development") == "production":
            app.logger.exception("Unhandled error on %s %s", request.method, request.path)
            return jsonify(msg="An internal error occurred"), 500
        return jsonify(msg="Internal server error"), 500

    @app.errorhandler(413)
    def request_too_large(_error):
        return jsonify(msg="Uploaded file is too large"), 413
