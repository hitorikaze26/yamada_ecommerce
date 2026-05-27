"""Transactional email helpers."""

from __future__ import annotations

import logging
from typing import Optional

from flask import current_app, has_app_context
from flask_mailman import EmailMessage

_logger = logging.getLogger(__name__)


def _mail_password() -> str:
    """Gmail app passwords are often copied with spaces."""
    if has_app_context():
        raw = current_app.config.get("MAIL_PASSWORD") or ""
    else:
        raw = ""
    return str(raw).replace(" ", "")


def _mail_backend() -> str:
    if has_app_context():
        return str(current_app.config.get("MAIL_BACKEND", "console")).lower()
    return "console"


def _log_email(*, to: str, subject: str, body: str) -> None:
    banner = "=" * 60
    message = (
        f"\n{banner}\n"
        f"YAMADA EMAIL (console backend)\n"
        f"To: {to}\n"
        f"Subject: {subject}\n"
        f"{banner}\n"
        f"{body}\n"
        f"{banner}\n"
    )
    if has_app_context():
        current_app.logger.info(message)
    else:
        _logger.info(message)


def _send_email(
    *,
    to_email: str,
    subject: str,
    body: str,
    critical: bool = False,
) -> None:
    """Send email via SMTP or log to console when MAIL_BACKEND=console."""
    if not to_email or not to_email.strip():
        return

    to_email = to_email.strip()
    backend = _mail_backend()

    if backend == "console":
        _log_email(to=to_email, subject=subject, body=body)
        return

    msg = EmailMessage(subject=subject, to=[to_email], body=body)

    original_password = None
    if has_app_context():
        original_password = current_app.config.get("MAIL_PASSWORD")
        current_app.config["MAIL_PASSWORD"] = _mail_password()

    try:
        msg.send()
    except Exception as exc:
        if critical and has_app_context() and current_app.debug:
            current_app.logger.warning(
                "Critical email failed (%s). DEV fallback logged for %s",
                exc,
                to_email,
            )
            _log_email(to=to_email, subject=subject, body=body)
            return
        if critical:
            if has_app_context():
                current_app.logger.error(
                    "Critical email failed for %s (%s): %s — check MAIL_BACKEND, "
                    "MAIL_USERNAME, and Gmail App Password on Railway",
                    to_email,
                    subject,
                    exc,
                )
            raise
        if has_app_context():
            current_app.logger.warning(
                "Notification email failed for %s (%s): %s",
                to_email,
                subject,
                exc,
            )
        else:
            _logger.warning(
                "Notification email failed for %s (%s): %s",
                to_email,
                subject,
                exc,
            )
    finally:
        if has_app_context() and original_password is not None:
            current_app.config["MAIL_PASSWORD"] = original_password


def send_notification_email(
    *,
    to_email: str,
    title: str,
    message: str,
    page: Optional[str] = None,
    role: Optional[str] = None,
) -> None:
    """Send a Yamada in-app notification copy to the user's email."""
    lines = [
        "Hello,",
        "",
        message,
        "",
    ]
    if page:
        lines.append(f"Open in Yamada: {page}")
        lines.append("")
    if role:
        lines.append(f"Account: {role}")
        lines.append("")
    lines.extend(
        [
            "— Yamada E-Commerce",
            "You received this because of activity on your account.",
        ]
    )
    subject = f"Yamada: {title}"
    _send_email(
        to_email=to_email,
        subject=subject,
        body="\n".join(lines),
        critical=False,
    )


def send_chat_message_email(
    *,
    to_email: str,
    sender_name: str,
    preview: str,
    conversation_label: str,
) -> None:
    """Notify a user of a new chat message."""
    body = (
        f"Hello,\n\n"
        f"{sender_name} sent you a message in {conversation_label}:\n\n"
        f'"{preview}"\n\n'
        f"Open Yamada to reply.\n\n"
        f"— Yamada E-Commerce"
    )
    _send_email(
        to_email=to_email,
        subject=f"Yamada: New message from {sender_name}",
        body=body,
        critical=False,
    )


def send_password_reset_email(*, to_email: str, pin: str, expiry_minutes: int) -> None:
    """Send reset PIN email. In DEBUG, logs PIN to console if SMTP fails."""
    body = (
        f"Hello,\n\n"
        f"Your Yamada password reset code is: {pin}\n\n"
        f"This code expires in {expiry_minutes} minutes.\n"
        f"If you did not request this, ignore this email.\n"
    )
    _send_email(
        to_email=to_email,
        subject="Yamada password reset code",
        body=body,
        critical=True,
    )


def send_verification_email(*, to_email: str, code: str, expiry_minutes: int) -> None:
    """Send email verification code."""
    body = (
        f"Hello,\n\n"
        f"Your Yamada email verification code is: {code}\n\n"
        f"This code expires in {expiry_minutes} minutes.\n"
        f"If you did not register for Yamada, ignore this email.\n"
    )
    _send_email(
        to_email=to_email,
        subject="Yamada email verification code",
        body=body,
        critical=True,
    )
