from __future__ import annotations

import importlib
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi.testclient import TestClient


RUNTIME_DIR = Path(__file__).resolve().parent


def load_app(tmp_path: Path):
    os.environ["VPSKIT_DB_PATH"] = str(tmp_path / "vpskit.sqlite3")
    os.environ["BASE_DOMAIN"] = "https://get.vpskit.com"
    os.environ["INSTALL_BASE_DOMAIN"] = "https://get.alexhexa.com"
    os.environ["PAYPAL_CLIENT_ID"] = "client"
    os.environ["PAYPAL_SECRET"] = "secret"
    os.environ["PAYPAL_WEBHOOK_ID"] = "webhook"

    if str(RUNTIME_DIR) not in sys.path:
        sys.path.insert(0, str(RUNTIME_DIR))

    for module_name in ("app", "services", "db", "config", "paypal", "schemas"):
        sys.modules.pop(module_name, None)

    app_module = importlib.import_module("app")
    return app_module


def completed_payment(event_id: str = "WH-1") -> dict:
    return {
        "id": event_id,
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "resource": {
            "id": "CAPTURE-1",
            "amount": {"value": "19.00", "currency_code": "USD"},
            "payer": {"email_address": "buyer@example.com"},
        },
    }


def test_payment_creates_one_time_install_token_and_deduplicates(tmp_path):
    app_module = load_app(tmp_path)
    app_module.init_db()

    first = app_module.process_paypal_event(completed_payment("WH-1"))
    second = app_module.process_paypal_event(completed_payment("WH-1"))

    assert first["status"] == "ok"
    assert first["install_url"].startswith("https://get.alexhexa.com/i/")
    token = first["install_url"].rsplit("/", 1)[1]
    assert len(token) >= 32
    assert second == {"status": "ok", "idempotent": True, "install_url": first["install_url"]}

    with app_module.connect() as conn:
        rows = conn.execute("SELECT token, user_id, plan, used, paypal_event_id FROM tokens").fetchall()
    assert len(rows) == 1
    assert rows[0]["token"] == token
    assert rows[0]["plan"] == "pro"
    assert rows[0]["used"] == 0
    assert rows[0]["paypal_event_id"] == "WH-1"


def test_install_entrypoint_and_token_ip_binding_lifecycle(tmp_path):
    app_module = load_app(tmp_path)
    client = TestClient(app_module.app)

    with client:
        created = app_module.process_paypal_event(completed_payment("WH-2"))
        token = created["install_url"].rsplit("/", 1)[1]

        install = client.get(f"/i/{token}")
        assert install.status_code == 200
        assert f"curl -sSL https://get.alexhexa.com/install.sh?token={token} | bash" in install.text

        first = client.get(
            "/api/validate-token",
            params={"token": token},
            headers={"x-forwarded-for": "203.0.113.10"},
        )
        assert first.status_code == 200
        assert first.json() == {"status": "ok"}

        same_ip = client.get(
            "/api/validate-token",
            params={"token": token},
            headers={"x-forwarded-for": "203.0.113.10"},
        )
        assert same_ip.status_code == 200

        different_ip = client.get(
            "/api/validate-token",
            params={"token": token},
            headers={"x-forwarded-for": "203.0.113.11"},
        )
        assert different_ip.status_code == 403

        marked = client.post(
            "/api/mark-used",
            json={"token": token},
            headers={"x-forwarded-for": "203.0.113.10"},
        )
        assert marked.status_code == 200
        assert marked.json() == {"status": "ok"}

        reused = client.get(
            "/api/validate-token",
            params={"token": token},
            headers={"x-forwarded-for": "203.0.113.10"},
        )
        assert reused.status_code == 403


def test_expired_token_is_rejected(tmp_path):
    app_module = load_app(tmp_path)
    client = TestClient(app_module.app)

    with client:
        created = app_module.process_paypal_event(completed_payment("WH-3"))
        token = created["install_url"].rsplit("/", 1)[1]
        expired_at = (datetime.now(timezone.utc) - timedelta(seconds=1)).isoformat()

        with app_module.connect() as conn:
            conn.execute("UPDATE tokens SET expires_at = ? WHERE token = ?", (expired_at, token))

        response = client.get(
            "/api/validate-token",
            params={"token": token},
            headers={"x-forwarded-for": "203.0.113.10"},
        )
        assert response.status_code == 403
        assert response.json()["detail"] == "token_expired"
