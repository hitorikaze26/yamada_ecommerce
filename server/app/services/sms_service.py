"""Optional SMS delivery via Twilio (env-gated)."""

import os
import re

from flask import current_app


def to_e164(phone: str, default_country_code: str = "63") -> str:
    """Normalize a phone number to E.164 for Twilio (e.g. 0960… -> +63960…)."""
    raw = (phone or "").strip()
    if not raw:
        return raw

    if raw.startswith("+"):
        digits = re.sub(r"\D", "", raw)
        return f"+{digits}" if digits else raw

    digits = re.sub(r"\D", "", raw)
    cc = re.sub(r"\D", "", default_country_code or "63") or "63"

    if digits.startswith("0") and len(digits) >= 10:
        return f"+{cc}{digits[1:]}"
    if digits.startswith(cc):
        return f"+{digits}"
    if len(digits) == 10 and digits[0] == "9":
        return f"+{cc}{digits}"

    return f"+{digits}" if digits else raw


def sms_configured() -> bool:
    return bool(
        os.environ.get("TWILIO_ACCOUNT_SID")
        or current_app.config.get("TWILIO_ACCOUNT_SID")
    ) and bool(
        os.environ.get("TWILIO_AUTH_TOKEN")
        or current_app.config.get("TWILIO_AUTH_TOKEN")
    ) and bool(
        os.environ.get("TWILIO_FROM_NUMBER")
        or current_app.config.get("TWILIO_FROM_NUMBER")
    )


def send_sms(to_number: str, body: str) -> None:
    """Send SMS using Twilio. Raises RuntimeError if not configured or send fails."""
    if not sms_configured():
        raise RuntimeError("SMS is not configured on the server")

    account_sid = os.environ.get("TWILIO_ACCOUNT_SID") or current_app.config.get(
        "TWILIO_ACCOUNT_SID"
    )
    auth_token = os.environ.get("TWILIO_AUTH_TOKEN") or current_app.config.get(
        "TWILIO_AUTH_TOKEN"
    )
    from_number = os.environ.get("TWILIO_FROM_NUMBER") or current_app.config.get(
        "TWILIO_FROM_NUMBER"
    )

    try:
        from twilio.rest import Client
    except ImportError as exc:
        raise RuntimeError(
            "Twilio package not installed. Add twilio to server requirements."
        ) from exc

    country = (
        os.environ.get("DEFAULT_PHONE_COUNTRY_CODE")
        or current_app.config.get("DEFAULT_PHONE_COUNTRY_CODE")
        or "63"
    )
    to_e164_number = to_e164(to_number, default_country_code=country)

    client = Client(account_sid, auth_token)
    client.messages.create(body=body, from_=from_number, to=to_e164_number)
