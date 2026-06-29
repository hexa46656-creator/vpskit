from __future__ import annotations

import hashlib
import hmac
import json
import time
from typing import Any

import requests
from fastapi import HTTPException

from config import settings


def _require_stripe_config() -> None:
    missing = [
        name
        for name, value in (
            ("STRIPE_SECRET_KEY", settings.stripe_secret_key),
            ("STRIPE_WEBHOOK_SECRET", settings.stripe_webhook_secret),
        )
        if not value
    ]
    if missing:
        raise HTTPException(status_code=503, detail=f"missing_stripe_config:{','.join(missing)}")


def stripe_price_for_plan(plan: str) -> str:
    prices = {
        "basic": settings.stripe_price_basic,
        "pro": settings.stripe_price_pro,
        "elite": settings.stripe_price_elite,
    }
    price_id = prices.get(plan, "")
    if not price_id:
        raise HTTPException(status_code=503, detail=f"missing_stripe_price:{plan}")
    return price_id


def create_checkout_session(plan: str, email: str | None, region: str | None) -> dict[str, str]:
    if not settings.stripe_secret_key:
        raise HTTPException(status_code=503, detail="missing_stripe_config:STRIPE_SECRET_KEY")

    data = {
        "mode": "payment",
        "success_url": settings.stripe_success_url,
        "cancel_url": settings.stripe_cancel_url,
        "line_items[0][price]": stripe_price_for_plan(plan),
        "line_items[0][quantity]": "1",
        "metadata[plan]": plan,
    }
    if email:
        data["customer_email"] = email
    if region:
        data["metadata[region]"] = region

    response = requests.post(
        "https://api.stripe.com/v1/checkout/sessions",
        headers={"Authorization": f"Bearer {settings.stripe_secret_key}"},
        data=data,
        timeout=15,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail="stripe_checkout_failed")

    payload = response.json()
    checkout_url = payload.get("url")
    if not checkout_url:
        raise HTTPException(status_code=502, detail="stripe_checkout_url_missing")
    return {"checkout_url": str(checkout_url), "session_id": str(payload.get("id", ""))}


def verify_stripe_signature(raw_body: bytes, signature_header: str | None) -> dict[str, Any]:
    _require_stripe_config()
    if not signature_header:
        raise HTTPException(status_code=400, detail="missing_stripe_signature")

    values: dict[str, list[str]] = {}
    for part in signature_header.split(","):
        if "=" in part:
            key, value = part.split("=", 1)
            values.setdefault(key, []).append(value)

    timestamp_values = values.get("t", [])
    signatures = values.get("v1", [])
    if not timestamp_values or not signatures:
        raise HTTPException(status_code=400, detail="invalid_stripe_signature_header")

    timestamp = int(timestamp_values[0])
    if abs(int(time.time()) - timestamp) > settings.webhook_replay_seconds:
        raise HTTPException(status_code=400, detail="stale_webhook")

    signed_payload = f"{timestamp}.{raw_body.decode()}".encode()
    expected = hmac.new(settings.stripe_webhook_secret.encode(), signed_payload, hashlib.sha256).hexdigest()
    if not any(hmac.compare_digest(expected, signature) for signature in signatures):
        raise HTTPException(status_code=403, detail="invalid_stripe_signature")

    return json.loads(raw_body.decode("utf-8"))
