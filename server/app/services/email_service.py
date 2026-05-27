"""Transactional email helpers."""

from __future__ import annotations

import logging
import os
from typing import Optional

import resend
from flask import has_app_context, current_app

_logger = logging.getLogger(__name__)

resend.api_key = os.environ.get("RESEND_API_KEY", "")

RESEND_FROM = os.environ.get("RESEND_FROM", "YamadaShop <onboarding@resend.dev>")

YAMADA_MAIL_CONSOLE = os.environ.get("YAMADA_MAIL_CONSOLE", "false").lower() in ("1", "true", "yes")


def _is_console_mode() -> bool:
    return YAMADA_MAIL_CONSOLE


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


def _text_to_html(text: str) -> str:
    """Convert plain text to a minimal HTML email body."""
    paragraphs = [f"<p>{line}</p>" for line in text.strip().split("\n\n") if line.strip()]
    return f"<!DOCTYPE html><html><body style=\"font-family: sans-serif; line-height: 1.6;\">{''.join(paragraphs)}</body></html>"


def _send_email(
    *,
    to_email: str,
    subject: str,
    body: str,
    critical: bool = False,
) -> None:
    """Send email via Resend or log to console when YAMADA_MAIL_CONSOLE is true."""
    if not to_email or not to_email.strip():
        return

    to_email = to_email.strip()

    if _is_console_mode():
        _log_email(to=to_email, subject=subject, body=body)
        return

    try:
        resend.Emails.send({
            "from": RESEND_FROM,
            "to": to_email,
            "subject": subject,
            "html": _text_to_html(body),
        })
    except Exception as exc:
        if critical:
            if has_app_context():
                current_app.logger.error(
                    "Critical email failed for %s (%s): %s — check RESEND_API_KEY",
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
