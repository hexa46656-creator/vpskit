from __future__ import annotations

import hashlib
import hmac
import json
import logging
import sys
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Request


CONTROL_PLANE_DIR = Path(__file__).resolve().parent
if str(CONTROL_PLANE_DIR) not in sys.path:
    sys.path.insert(0, str(CONTROL_PLANE_DIR))

from config import load_config  # noqa: E402
from provision import dispatch_payment_received_file, mark_payment_received  # noqa: E402


logger = logging.getLogger(__name__)
app = FastAPI(title="VPSKit Control Plane MVP", version="0.1.0")
config = load_config()


def _signature_header(headers: dict[str, str]) -> str:
    return headers.get("paypal-transmission-sig", "") or headers.get("x-paypal-signature", "")


def _validate_signature(body: bytes, headers: dict[str, str]) -> bool:
    if not config.paypal_webhook_id:
        return False

    signature = _signature_header({key.lower(): value for key, value in headers.items()})
    if not signature:
        return False

    expected = hmac.new(
        config.paypal_webhook_id.encode("utf-8"),
        body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(signature, expected)


@app.post("/webhook/paypal")
async def webhook_paypal(request: Request) -> dict[str, Any]:
    raw_body = await request.body()
    headers = dict(request.headers)

    if not _validate_signature(raw_body, headers):
        raise HTTPException(status_code=403, detail="invalid_signature")

    try:
        payload = json.loads(raw_body.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="invalid_json") from exc

    logger.info("paypal webhook accepted event_type=%s", payload.get("event_type", "unknown"))
    event_path = mark_payment_received(payload)
    result = dispatch_payment_received_file(event_path)

    return {
        "status": "payment_received",
        "event_path": str(event_path),
        "returncode": result.returncode,
    }
