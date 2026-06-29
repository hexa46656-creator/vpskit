from __future__ import annotations

import hashlib
import hmac
import importlib
import json
import os
import sys
import time
from pathlib import Path

from fastapi.testclient import TestClient


RUNTIME_DIR = Path(__file__).resolve().parent


def load_app(tmp_path: Path):
    os.environ["VPSKIT_DB_PATH"] = str(tmp_path / "vpskit.sqlite3")
    os.environ["BASE_DOMAIN"] = "https://alexhexa.com/api"
    os.environ["INSTALL_BASE_DOMAIN"] = "https://alexhexa.com"
    os.environ["PAYPAL_CLIENT_ID"] = "paypal-client"
    os.environ["PAYPAL_SECRET"] = "paypal-secret"
    os.environ["PAYPAL_WEBHOOK_ID"] = "webhook-id"
    os.environ["STRIPE_SECRET_KEY"] = "sk_live_test"
    os.environ["STRIPE_WEBHOOK_SECRET"] = "whsec_test"
    os.environ["STRIPE_SUCCESS_URL"] = "https://alexhexa.com/success.html"
    os.environ["STRIPE_CANCEL_URL"] = "https://alexhexa.com/pricing.html"
    os.environ["STRIPE_PRICE_BASIC"] = "price_basic"
    os.environ["TELEGRAM_BOT_TOKEN"] = "telegram-token"
    os.environ["TELEGRAM_ADMIN_CHAT_ID"] = "123"

    if str(RUNTIME_DIR) not in sys.path:
        sys.path.insert(0, str(RUNTIME_DIR))
    for module_name in (
        "app",
        "config",
        "db",
        "paypal",
        "schemas",
        "services",
        "stripe_payments",
        "telegram_bot",
    ):
        sys.modules.pop(module_name, None)
    return importlib.import_module("app")


def stripe_signature(payload: bytes, secret: str, timestamp: int | None = None) -> str:
    ts = timestamp or int(time.time())
    signed = f"{ts}.{payload.decode()}".encode()
    digest = hmac.new(secret.encode(), signed, hashlib.sha256).hexdigest()
    return f"t={ts},v1={digest}"


def test_stripe_signed_webhook_creates_install_token_and_deduplicates(tmp_path, monkeypatch):
    app_module = load_app(tmp_path)
    sent_messages: list[str] = []
    monkeypatch.setattr(app_module, "send_payment_success_notification", lambda payload: sent_messages.append(payload["install_url"]))

    client = TestClient(app_module.app)
    payload = {
        "id": "evt_stripe_1",
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": "cs_live_1",
                "customer_email": "buyer@example.com",
                "amount_total": 1900,
                "currency": "usd",
                "metadata": {"plan": "pro", "region": "EU"},
            }
        },
    }
    raw = json.dumps(payload, separators=(",", ":")).encode()

    with client:
        first = client.post(
            "/webhook/stripe",
            content=raw,
            headers={
                "content-type": "application/json",
                "stripe-signature": stripe_signature(raw, "whsec_test"),
            },
        )
        second = client.post(
            "/webhook/stripe",
            content=raw,
            headers={
                "content-type": "application/json",
                "stripe-signature": stripe_signature(raw, "whsec_test"),
            },
        )

    assert first.status_code == 200
    assert first.json()["install_url"].startswith("https://alexhexa.com/i/")
    assert second.json() == {"status": "ok", "idempotent": True, "install_url": first.json()["install_url"]}
    assert sent_messages == [first.json()["install_url"]]

    with app_module.connect() as conn:
        users = conn.execute("SELECT email FROM users").fetchall()
        tokens = conn.execute("SELECT token, node_id, ip_bound, used FROM tokens").fetchall()
        node = conn.execute("SELECT region, load FROM nodes WHERE id = ?", (tokens[0]["node_id"],)).fetchone()
    assert users[0]["email"] == "buyer@example.com"
    assert len(tokens) == 1
    assert tokens[0]["used"] == 0
    assert node["region"] == "EU"
    assert node["load"] == 1


def test_stripe_checkout_session_uses_real_api_contract(tmp_path, monkeypatch):
    app_module = load_app(tmp_path)
    stripe_payments = importlib.import_module("stripe_payments")
    captured: dict = {}

    class Response:
        status_code = 200

        def json(self):
            return {"id": "cs_live", "url": "https://checkout.stripe.com/c/pay"}

    def fake_post(url, headers=None, data=None, timeout=None):
        captured.update({"url": url, "headers": headers, "data": data, "timeout": timeout})
        return Response()

    monkeypatch.setattr(stripe_payments.requests, "post", fake_post)
    client = TestClient(app_module.app)
    with client:
        response = client.post("/api/checkout/stripe", json={"plan": "basic", "email": "buyer@example.com"})

    assert response.status_code == 200
    assert response.json()["checkout_url"] == "https://checkout.stripe.com/c/pay"
    assert captured["url"] == "https://api.stripe.com/v1/checkout/sessions"
    assert captured["headers"]["Authorization"] == "Bearer sk_live_test"
    assert captured["data"]["line_items[0][price]"] == "price_basic"
    assert captured["data"]["metadata[plan]"] == "basic"


def test_paypal_checkout_returns_approval_url(tmp_path, monkeypatch):
    app_module = load_app(tmp_path)
    paypal = importlib.import_module("paypal")
    captured: dict = {}

    class Response:
        status_code = 201

        def json(self):
            return {
                "id": "ORDER-123",
                "links": [
                    {"rel": "self", "href": "https://api-m.paypal.com/v2/checkout/orders/ORDER-123"},
                    {"rel": "approve", "href": "https://www.paypal.com/checkoutnow?token=ORDER-123"},
                ],
            }

    def fake_post(url, auth=None, data=None, headers=None, json=None, timeout=None):
        captured.update({"url": url, "auth": auth, "data": data, "headers": headers, "json": json, "timeout": timeout})
        return Response()

    monkeypatch.setattr(paypal.requests, "post", fake_post)
    client = TestClient(app_module.app)
    with client:
        response = client.get("/api/checkout/paypal?plan=basic")

    assert response.status_code == 200
    assert response.json()["checkout_url"] == "https://www.paypal.com/checkoutnow?token=ORDER-123"
    assert captured["url"] == "https://api-m.paypal.com/v2/checkout/orders"
    assert captured["headers"]["Authorization"].startswith("Bearer ")
    assert captured["json"]["purchase_units"][0]["custom_id"] == "plan=basic"


def test_dashboard_and_static_site_files_exist(tmp_path):
    app_module = load_app(tmp_path)
    app_module.init_db()
    result = app_module.process_verified_payment(
        provider="stripe",
        event_id="evt_dash",
        capture_id="cs_dash",
        email="dash@example.com",
        amount="49.00",
        currency="usd",
        plan="elite",
        region_preference="US-EAST",
        raw_event={"id": "evt_dash"},
    )
    client = TestClient(app_module.app)
    with client:
        dashboard = client.get(f"/dashboard/{result['user_id']}")

    assert dashboard.status_code == 200
    assert "Regenerate token" in dashboard.text
    assert "Telegram" in dashboard.text
    assert "curl -sSL https://alexhexa.com/i/" in dashboard.text

    site_root = Path(__file__).resolve().parents[2] / "site"
    for file_name in ("index.html", "pricing.html", "docs.html", "success.html"):
        text = (site_root / file_name).read_text()
        assert "https://alexhexa.com/api/" in text
