from __future__ import annotations

import json
from pathlib import Path

from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, PlainTextResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from db import connect, init_db
from config import settings
from paypal import verify_paypal_webhook
from schemas import CheckoutRequest, LoginRequest, MarkUsedRequest, PayPalWebhookEvent
from services import (
    authenticate_user,
    expire_old_subscriptions,
    get_active_subscription,
    mark_install_token_used,
    process_paypal_event,
    process_verified_payment,
    validate_install_token,
)
from stripe_payments import create_checkout_session, verify_stripe_signature
from telegram_bot import handle_telegram_update, send_payment_success_notification


app = FastAPI(title="VPSKit SaaS", version="1.0.0")
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parent / "templates"))


@app.on_event("startup")
def startup() -> None:
    init_db()
    expire_old_subscriptions()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/")
@app.get("/api/health")
def api_health() -> dict[str, str]:
    return health()


def request_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        return forwarded_for.split(",", 1)[0].strip()
    return request.client.host if request.client else "unknown"


@app.post("/paypal/webhook")
async def paypal_webhook(request: Request) -> dict:
    try:
        raw_event = await request.json()
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="invalid_json") from exc

    event = PayPalWebhookEvent.model_validate(raw_event)
    payload = event.model_dump(mode="json")
    verify_paypal_webhook(request, payload)
    result = process_paypal_event(payload)
    if result.get("install_url") and not result.get("idempotent"):
        send_payment_success_notification(result)
    return result


@app.post("/webhook/paypal")
async def paypal_webhook_v3(request: Request) -> dict:
    return await paypal_webhook(request)


@app.post("/api/webhook/paypal")
async def paypal_webhook_api(request: Request) -> dict:
    return await paypal_webhook(request)


@app.post("/webhook/stripe")
async def stripe_webhook(request: Request) -> dict:
    raw_body = await request.body()
    event = verify_stripe_signature(raw_body, request.headers.get("stripe-signature"))
    event_id = str(event.get("id", ""))
    event_type = str(event.get("type", ""))
    if not event_id:
        raise HTTPException(status_code=400, detail="missing_stripe_event_id")
    if event_type != "checkout.session.completed":
        return {"status": "ignored"}

    session = event.get("data", {}).get("object", {})
    metadata = session.get("metadata") or {}
    amount_total = session.get("amount_total")
    amount = f"{amount_total / 100:.2f}" if isinstance(amount_total, int) else None
    result = process_verified_payment(
        provider="stripe",
        event_id=event_id,
        capture_id=str(session.get("id", "")),
        email=session.get("customer_email"),
        amount=amount,
        currency=session.get("currency"),
        plan=str(metadata.get("plan") or "basic"),
        region_preference=metadata.get("region"),
        raw_event=event,
    )
    if result.get("install_url") and not result.get("idempotent"):
        send_payment_success_notification(result)
    return result


@app.post("/api/webhook/stripe")
async def stripe_webhook_api(request: Request) -> dict:
    return await stripe_webhook(request)


@app.post("/api/checkout/stripe")
def api_checkout_stripe(payload: CheckoutRequest) -> dict[str, str]:
    return create_checkout_session(payload.plan, payload.email, payload.region)


@app.get("/api/checkout/paypal")
def api_checkout_paypal(plan: str = "basic") -> dict[str, str]:
    configured_url = {
        "basic": settings.base_domain.removesuffix("/api") + "/pricing.html#paypal-basic",
        "pro": settings.base_domain.removesuffix("/api") + "/pricing.html#paypal-pro",
        "elite": settings.base_domain.removesuffix("/api") + "/pricing.html#paypal-elite",
    }.get(plan, settings.base_domain.removesuffix("/api") + "/pricing.html")
    return {"checkout_url": configured_url}


@app.post("/paypal-webhook")
async def paypal_webhook_legacy(request: Request) -> dict:
    return await paypal_webhook(request)


@app.get("/sub/{user_id}")
def subscription(user_id: str, format: str | None = None) -> dict:
    return get_active_subscription(user_id, format)


@app.get("/i/{token}", response_class=PlainTextResponse)
def install_entrypoint(token: str) -> str:
    return f"curl -sSL {settings.install_base_domain}/install.sh?token={token} | bash\n"


@app.get("/install.sh", response_class=PlainTextResponse)
def install_script(token: str = "") -> str:
    return f"""#!/usr/bin/env bash
set -euo pipefail

TOKEN="${{1:-{token}}}"
API_BASE="${{VPSKIT_API_BASE:-{settings.install_base_domain}}}"
INSTALLER_URL="${{VPSKIT_INSTALLER_URL:-https://raw.githubusercontent.com/hexa46656-creator/vpskit/main/installer/install.sh}}"

if [ -z "${{TOKEN}}" ]; then
  echo "VPSKit install token is required" >&2
  exit 1
fi

curl -fsS "${{API_BASE}}/api/validate-token?token=${{TOKEN}}" >/dev/null
tmp_installer="$(mktemp)"
cleanup() {{
  rm -f "${{tmp_installer}}"
}}
trap cleanup EXIT
curl -fsSLo "${{tmp_installer}}" "${{INSTALLER_URL}}"
bash "${{tmp_installer}}"
curl -fsS -X POST "${{API_BASE}}/api/mark-used" \\
  -H "Content-Type: application/json" \\
  -d "{{\\"token\\":\\"${{TOKEN}}\\"}}" >/dev/null
echo "VPSKit installation completed"
"""


@app.get("/api/validate-token")
def api_validate_token(request: Request, token: str) -> dict[str, str]:
    return validate_install_token(token, request_ip(request))


@app.post("/api/mark-used")
def api_mark_used(request: Request, payload: MarkUsedRequest) -> dict[str, str]:
    return mark_install_token_used(payload.token, request_ip(request))


@app.post("/user/login")
def user_login(payload: LoginRequest) -> dict[str, str]:
    authenticate_user(payload.user_id, payload.token)
    return {"status": "ok", "dashboard": f"/dashboard?user_id={payload.user_id}&token={payload.token}"}


@app.get("/user/dashboard")
def user_dashboard(user_id: str, token: str) -> dict:
    authenticate_user(user_id, token)
    return get_active_subscription(user_id)


@app.get("/nodes/list")
def nodes_list() -> dict:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT n.id, n.name, n.ip, n.capacity, n.status, COUNT(s.id) AS active_connections
            FROM nodes n
            LEFT JOIN subscriptions s ON s.node_id = n.id AND s.status = 'active'
            GROUP BY n.id
            ORDER BY n.id ASC
            """
        ).fetchall()
    return {"nodes": [dict(row) for row in rows]}


@app.get("/api/nodes/list")
def api_nodes_list() -> dict:
    return nodes_list()


@app.post("/telegram/webhook")
async def telegram_webhook(request: Request) -> dict[str, str]:
    try:
        update = await request.json()
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="invalid_json") from exc
    return handle_telegram_update(update)


@app.get("/login", response_class=HTMLResponse)
def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})


@app.post("/login")
def login_submit(user_id: str = Form(...), token: str = Form(...)):
    authenticate_user(user_id, token)
    return RedirectResponse(f"/dashboard?user_id={user_id}&token={token}", status_code=303)


@app.get("/dashboard", response_class=HTMLResponse)
def dashboard_page(request: Request, user_id: str, token: str):
    authenticate_user(user_id, token)
    subscription_data = get_active_subscription(user_id)
    return templates.TemplateResponse(
        "dashboard.html",
        {"request": request, "user_id": user_id, "token": token, "subscription": subscription_data},
    )


@app.get("/dashboard/{user_id}", response_class=HTMLResponse)
def dashboard_by_user_id(request: Request, user_id: str):
    subscription_data = get_active_subscription(user_id)
    install_command = f"curl -sSL {settings.install_base_domain}/i/{_latest_install_token(user_id)} | bash"
    return templates.TemplateResponse(
        "dashboard.html",
        {
            "request": request,
            "user_id": user_id,
            "token": "",
            "subscription": subscription_data,
            "install_command": install_command,
            "telegram_url": settings.telegram_support_url,
        },
    )


@app.post("/dashboard/{user_id}/regenerate-token")
def regenerate_token(user_id: str) -> dict[str, str]:
    from services import generate_install_token, now_iso, token_install_url
    from datetime import datetime, timedelta, timezone

    new_token = generate_install_token()
    now = datetime.now(timezone.utc)
    with connect() as conn:
        sub = conn.execute(
            "SELECT node_id, plan FROM subscriptions WHERE user_id=? AND status='active' ORDER BY id DESC LIMIT 1",
            (user_id,),
        ).fetchone()
        if not sub:
            raise HTTPException(status_code=404, detail="active_subscription_not_found")
        conn.execute(
            """
            INSERT INTO tokens (token,user_id,node_id,plan,created_at,expires_at,used,used_at,ip_bound,paypal_event_id)
            VALUES (?,?,?,?,?,?,0,NULL,NULL,?)
            """,
            (
                new_token,
                user_id,
                sub["node_id"],
                sub["plan"],
                now.isoformat(),
                (now + timedelta(minutes=10)).isoformat(),
                f"manual:{user_id}:{now_iso()}",
            ),
        )
    return {"status": "ok", "install_url": token_install_url(new_token)}


def _latest_install_token(user_id: str) -> str:
    with connect() as conn:
        row = conn.execute(
            """
            SELECT token FROM tokens
            WHERE user_id=? AND used=0
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (user_id,),
        ).fetchone()
    return row["token"] if row else ""


@app.get("/billing", response_class=HTMLResponse)
def billing_page(request: Request, user_id: str, token: str):
    authenticate_user(user_id, token)
    return templates.TemplateResponse("billing.html", {"request": request, "user_id": user_id, "token": token})
