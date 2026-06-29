"""FastAPI entrypoint for the cloud-native VPSKit control plane."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, HTTPException, Request, Response

from vpskit.config import AppSettings
from vpskit.platform import CloudControlPlane


settings = AppSettings.from_env()
app = FastAPI(title="VPSKit", version="3.0.0")
logger = logging.getLogger(__name__)
_control_plane: CloudControlPlane | None = None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


@app.get("/runtime/services")
def list_services() -> list[dict[str, str]]:
    return [
        {
            "name": "api",
            "state": "configured",
            "detail": "FastAPI production control plane is importable",
        }
    ]


@app.get("/user/{user_id}")
def get_user(user_id: int) -> dict[str, Any]:
    control_plane = _get_control_plane()
    try:
        user = control_plane.get_user(user_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail="user_not_found") from exc
    return _user_to_dict(user)


@app.get("/user/{user_id}/status")
def get_user_status(user_id: int) -> dict[str, str]:
    control_plane = _get_control_plane()
    try:
        user = control_plane.get_user(user_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail="user_not_found") from exc
    return {"id": str(user.id), "status": user.status, "plan": user.plan}


@app.get("/dashboard")
def dashboard() -> dict[str, Any]:
    control_plane = _get_control_plane()
    return control_plane.get_dashboard()


@app.post("/webhook/paypal")
async def webhook_paypal(request: Request, response: Response) -> dict[str, str]:
    body = await request.body()
    headers = dict(request.headers)
    source_ip = _request_ip(request)
    logger.info("PayPal webhook received from ip=%s", source_ip)

    control_plane = _get_control_plane()
    try:
        accepted = control_plane.handle_paypal_webhook(body, headers, source_ip=source_ip)
    except ValueError as exc:
        message = str(exc).lower()
        if "signature" in message:
            raise HTTPException(status_code=403, detail="invalid_signature") from exc
        raise HTTPException(status_code=400, detail="invalid_json") from exc
    except Exception as exc:  # noqa: BLE001
        logger.exception("PayPal webhook processing failed")
        raise HTTPException(status_code=503, detail="temporary_unavailable") from exc

    if not accepted:
        response.status_code = 200
        return {"status": "ignored"}

    response.status_code = 202
    return {"status": "queued"}


def _get_control_plane() -> CloudControlPlane:
    global _control_plane
    if _control_plane is None:
        _control_plane = CloudControlPlane.from_env()
    return _control_plane


def _request_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()

    client = request.client
    return client.host if client else "unknown"


def _user_to_dict(user: Any) -> dict[str, Any]:
    return {
        "id": user.id,
        "identity_key": user.identity_key,
        "email": user.email,
        "plan": user.plan,
        "status": user.status,
        "last_active": user.last_active,
        "created_at": user.created_at,
        "updated_at": user.updated_at,
    }
