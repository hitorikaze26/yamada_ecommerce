"""Transactional email helpers."""

from flask import current_app
from flask_mailman import EmailMessage


def _mail_password() -> str:
    """Gmail app passwords are often copied with spaces."""
    raw = current_app.config.get("MAIL_PASSWORD") or ""
    return str(raw).replace(" ", "")


def send_password_reset_email(*, to_email: str, pin: str, expiry_minutes: int) -> None:
    """Send reset PIN email. In DEBUG, logs PIN to console if SMTP fails."""
    msg = EmailMessage(
        subject="Yamada password reset code",
        to=[to_email],
        body=(
            f"Hello,\n\n"
            f"Your Yamada password reset code is: {pin}\n\n"
            f"This code expires in {expiry_minutes} minutes.\n"
            f"If you did not request this, ignore this email.\n"
        ),
    )

    # Ensure spaced app passwords still authenticate.
    original_password = current_app.config.get("MAIL_PASSWORD")
    current_app.config["MAIL_PASSWORD"] = _mail_password()

    try:
        msg.send()
    except Exception as exc:
        if current_app.debug:
            current_app.logger.warning(
                "Password reset email failed (%s). DEV reset PIN for %s: %s",
                exc,
                to_email,
                pin,
            )
            return
        raise
    finally:
        if original_password is not None:
            current_app.config["MAIL_PASSWORD"] = original_password
