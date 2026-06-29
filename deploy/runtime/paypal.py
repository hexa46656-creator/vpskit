from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import requests
from fastapi import HTTPException, Request

from config import settings


def _parse_paypal_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _require_paypal_config() -> None:
    missing = [
        name
        for name, value in (
            ("PAYPAL_CLIENT_ID", settings.paypal_client_id),
            ("PAYPAL_SECRET", settings.paypal_secret),
            ("PAYPAL_WEBHOOK_ID", settings.paypal_webhook_id),
        )
        if not value
    ]
    if missing:
        raise HTTPException(status_code=503, detail=f"missing_paypal_config:{','.join(missing)}")


def _get_access_token() -> str:
    _require_paypal_config()
    response = requests.post(
        f"{settings.paypal_base_url}/v1/oauth2/token",
        auth=(settings.paypal_client_id, settings.paypal_secret),
        data={"grant_type": "client_credentials"},
        timeout=15,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail="paypal_auth_failed")

    access_token = response.json().get("access_token")
    if not access_token:
        raise HTTPException(status_code=502, detail="paypal_access_token_missing")
    return str(access_token)


def verify_paypal_webhook(request: Request, event_body: dict[str, Any]) -> None:
    headers = request.headers
    required = {
        "transmission_id": headers.get("paypal-transmission-id"),
        "transmission_time": headers.get("paypal-transmission-time"),
        "cert_url": headers.get("paypal-cert-url"),
        "auth_algo": headers.get("paypal-auth-algo"),
        "transmission_sig": headers.get("paypal-transmission-sig"),
    }
    if any(value is None for value in required.values()):
        raise HTTPException(status_code=400, detail="missing_paypal_headers")

    try:
        transmission_time = _parse_paypal_time(required["transmission_time"] or "")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="invalid_transmission_time") from exc

    age_seconds = abs((datetime.now(timezone.utc) - transmission_time).total_seconds())
    if age_seconds > settings.webhook_replay_seconds:
        raise HTTPException(status_code=400, detail="stale_webhook")

    payload = {
        "transmission_id": required["transmission_id"],
        "transmission_time": required["transmission_time"],
        "cert_url": required["cert_url"],
        "auth_algo": required["auth_algo"],
        "transmission_sig": required["transmission_sig"],
        "webhook_id": settings.paypal_webhook_id,
        "webhook_event": event_body,
    }
    response = requests.post(
        f"{settings.paypal_base_url}/v1/notifications/verify-webhook-signature",
        headers={
            "Authorization": f"Bearer {_get_access_token()}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=15,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail="paypal_verification_failed")
    if response.json().get("verification_status") != "SUCCESS":
        raise HTTPException(status_code=403, detail="invalid_paypal_signature")
