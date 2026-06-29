from __future__ import annotations

import base64
import json
import secrets
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import HTTPException

from config import settings
from db import connect


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def expire_old_subscriptions() -> None:
    current = now_iso()
    with connect() as conn:
        conn.execute(
            """
            UPDATE subscriptions
            SET status = 'expired', updated_at = ?
            WHERE status = 'active' AND end_at <= ?
            """,
            (current, current),
        )
        conn.execute(
            """
            UPDATE users
            SET status = 'expired', updated_at = ?
            WHERE status = 'active'
              AND user_id IN (SELECT user_id FROM subscriptions WHERE status = 'expired')
            """,
            (current,),
        )


def normalize_region(region: str | None) -> str | None:
    if not region:
        return None
    return region.strip().upper().replace("_", "-")


def assign_least_loaded_node(conn: sqlite3.Connection, region_preference: str | None = None) -> sqlite3.Row:
    preferred_region = normalize_region(region_preference)
    params: tuple[Any, ...] = ()
    region_filter = ""
    if preferred_region:
        region_filter = "AND n.region = ?"
        params = (preferred_region,)

    node = conn.execute(
        f"""
        SELECT n.*, COUNT(s.id) AS active_count
        FROM nodes n
        LEFT JOIN subscriptions s ON s.node_id = n.id AND s.status = 'active'
        WHERE n.status = 'active' {region_filter}
        GROUP BY n.id
        HAVING active_count < n.capacity
        ORDER BY active_count ASC, n.load ASC, n.id ASC
        LIMIT 1
        """,
        params,
    ).fetchone()
    if node:
        return node

    node = conn.execute(
        """
        SELECT n.*, COUNT(s.id) AS active_count
        FROM nodes n
        LEFT JOIN subscriptions s ON s.node_id = n.id AND s.status = 'active'
        WHERE n.status = 'active'
        GROUP BY n.id
        HAVING active_count < n.capacity
        ORDER BY active_count ASC, n.load ASC, n.id ASC
        LIMIT 1
        """
    ).fetchone()
    if not node:
        raise HTTPException(status_code=503, detail="no_available_nodes")
    return node


def extract_email(event: dict[str, Any]) -> str | None:
    email = event.get("resource", {}).get("payer", {}).get("email_address")
    return str(email) if email else None


def extract_amount(event: dict[str, Any]) -> tuple[str | None, str | None]:
    amount = event.get("resource", {}).get("amount", {})
    return amount.get("value"), amount.get("currency_code")


def detect_plan(event: dict[str, Any]) -> str:
    amount, _currency = extract_amount(event)
    return "pro" if str(amount) in {"19", "19.00"} else "basic"


def make_config(user_id: str, node_ip: str) -> str:
    return f"vless://{user_id}@{node_ip}:443?encryption=none"


def generate_install_token() -> str:
    return secrets.token_urlsafe(32)


def token_install_url(token: str) -> str:
    return f"{settings.install_base_domain}/i/{token}"


def plan_duration_days(plan: str) -> int:
    return {"basic": 30, "pro": 30, "elite": 90}.get(plan, 30)


def process_verified_payment(
    *,
    provider: str,
    event_id: str,
    capture_id: str | None,
    email: str | None,
    amount: str | None,
    currency: str | None,
    plan: str,
    region_preference: str | None,
    raw_event: dict[str, Any],
) -> dict[str, Any]:
    plan = plan if plan in {"basic", "pro", "elite"} else "basic"
    with connect() as conn:
        conn.execute("BEGIN IMMEDIATE")
        existing = conn.execute(
            """
            SELECT e.paypal_event_id, t.token
            FROM events e
            LEFT JOIN tokens t ON t.paypal_event_id = e.paypal_event_id
            WHERE e.paypal_event_id = ?
            """,
            (event_id,),
        ).fetchone()
        if existing:
            conn.commit()
            response: dict[str, Any] = {"status": "ok", "idempotent": True}
            if existing["token"]:
                response["install_url"] = token_install_url(existing["token"])
            return response

        node = assign_least_loaded_node(conn, region_preference)
        start_at = datetime.now(timezone.utc)
        end_at = start_at + timedelta(days=plan_duration_days(plan))
        user_id = uuid.uuid4().hex[:12]
        dashboard_token = secrets.token_urlsafe(32)
        install_token = generate_install_token()
        install_token_expires_at = start_at + timedelta(minutes=10)
        config = make_config(user_id, node["ip"])

        conn.execute(
            """
            INSERT INTO users (user_id, email, telegram_id, token, status, node_id, created_at, updated_at)
            VALUES (?, ?, NULL, ?, 'active', ?, ?, ?)
            """,
            (user_id, email, dashboard_token, node["id"], now_iso(), now_iso()),
        )
        conn.execute(
            """
            INSERT INTO subscriptions (
                user_id, node_id, status, plan, start_at, end_at, config, created_at, updated_at
            )
            VALUES (?, ?, 'active', ?, ?, ?, ?, ?, ?)
            """,
            (user_id, node["id"], plan, start_at.isoformat(), end_at.isoformat(), config, now_iso(), now_iso()),
        )
        conn.execute(
            """
            INSERT INTO payments (
                provider, paypal_event_id, event_id, paypal_capture_id, user_id,
                amount, currency, status, raw_event, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 'completed', ?, ?)
            """,
            (
                provider,
                event_id,
                event_id,
                capture_id or "",
                user_id,
                amount,
                currency,
                json.dumps(raw_event, separators=(",", ":")),
                now_iso(),
            ),
        )
        conn.execute(
            """
            INSERT INTO tokens (
                token, user_id, node_id, plan, created_at, expires_at, used, used_at, ip_bound, paypal_event_id
            )
            VALUES (?, ?, ?, ?, ?, ?, 0, NULL, NULL, ?)
            """,
            (
                install_token,
                user_id,
                node["id"],
                plan,
                start_at.isoformat(),
                install_token_expires_at.isoformat(),
                event_id,
            ),
        )
        conn.execute("UPDATE nodes SET load = load + 1 WHERE id = ?", (node["id"],))
        conn.execute(
            """
            INSERT INTO events (paypal_event_id, event_type, status, received_at)
            VALUES (?, ?, 'processed', ?)
            """,
            (event_id, f"{provider}:payment_completed", now_iso()),
        )
        conn.commit()

    return {
        "status": "ok",
        "user_id": user_id,
        "dashboard_url": f"{settings.base_domain.removesuffix('/api')}/dashboard/{user_id}",
        "install_url": token_install_url(install_token),
        "node_ip": node["ip"],
        "plan": plan,
        "expires_at": end_at.isoformat(),
    }


def process_paypal_event(event: dict[str, Any]) -> dict[str, Any]:
    event_id = event["id"]
    event_type = event["event_type"]
    if event_type != "PAYMENT.CAPTURE.COMPLETED":
        with connect() as conn:
            conn.execute("BEGIN IMMEDIATE")
            existing = conn.execute("SELECT paypal_event_id FROM events WHERE paypal_event_id = ?", (event_id,)).fetchone()
            if not existing:
                conn.execute(
                    """
                    INSERT INTO events (paypal_event_id, event_type, status, received_at)
                    VALUES (?, ?, 'ignored', ?)
                    """,
                    (event_id, event_type, now_iso()),
                )
            conn.commit()
        return {"status": "ignored"}

    amount, currency = extract_amount(event)
    resource = event.get("resource", {})
    custom = resource.get("custom_id") or resource.get("invoice_id") or ""
    region_preference = resource.get("region") or None
    plan = resource.get("plan") or detect_plan(event)
    if isinstance(custom, str):
        for item in custom.split("|"):
            if item.startswith("plan="):
                plan = item.split("=", 1)[1]
            if item.startswith("region="):
                region_preference = item.split("=", 1)[1]

    return process_verified_payment(
        provider="paypal",
        event_id=event_id,
        capture_id=str(resource.get("id", "")),
        email=extract_email(event),
        amount=amount,
        currency=currency,
        plan=str(plan),
        region_preference=region_preference,
        raw_event=event,
    )


def validate_install_token(token: str, request_ip: str) -> dict[str, str]:
    current = datetime.now(timezone.utc)
    with connect() as conn:
        conn.execute("BEGIN IMMEDIATE")
        row = conn.execute(
            """
            SELECT token, expires_at, used, ip_bound
            FROM tokens
            WHERE token = ?
            """,
            (token,),
        ).fetchone()
        if not row:
            conn.commit()
            raise HTTPException(status_code=404, detail="token_not_found")
        if row["used"]:
            conn.commit()
            raise HTTPException(status_code=403, detail="token_used")
        if current >= parse_iso(row["expires_at"]):
            conn.commit()
            raise HTTPException(status_code=403, detail="token_expired")
        if row["ip_bound"] and row["ip_bound"] != request_ip:
            conn.commit()
            raise HTTPException(status_code=403, detail="ip_mismatch")
        if not row["ip_bound"]:
            conn.execute("UPDATE tokens SET ip_bound = ? WHERE token = ?", (request_ip, token))
        conn.commit()
    return {"status": "ok"}


def mark_install_token_used(token: str, request_ip: str) -> dict[str, str]:
    current = datetime.now(timezone.utc)
    with connect() as conn:
        conn.execute("BEGIN IMMEDIATE")
        row = conn.execute(
            """
            SELECT token, expires_at, used, ip_bound
            FROM tokens
            WHERE token = ?
            """,
            (token,),
        ).fetchone()
        if not row:
            conn.commit()
            raise HTTPException(status_code=404, detail="token_not_found")
        if row["used"]:
            conn.commit()
            raise HTTPException(status_code=403, detail="token_used")
        if current >= parse_iso(row["expires_at"]):
            conn.commit()
            raise HTTPException(status_code=403, detail="token_expired")
        if row["ip_bound"] and row["ip_bound"] != request_ip:
            conn.commit()
            raise HTTPException(status_code=403, detail="ip_mismatch")
        if not row["ip_bound"]:
            conn.execute("UPDATE tokens SET ip_bound = ? WHERE token = ?", (request_ip, token))
        conn.execute(
            "UPDATE tokens SET used = 1, used_at = ? WHERE token = ?",
            (current.isoformat(), token),
        )
        conn.commit()
    return {"status": "ok"}


def get_active_subscription(user_id: str, output_format: str | None = None) -> dict[str, Any]:
    expire_old_subscriptions()
    with connect() as conn:
        row = conn.execute(
            """
            SELECT s.user_id, s.status, s.end_at, s.config, n.ip AS node_ip
            FROM subscriptions s
            JOIN nodes n ON n.id = s.node_id
            WHERE s.user_id = ?
            ORDER BY s.id DESC
            LIMIT 1
            """,
            (user_id,),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="subscription_not_found")
    if row["status"] != "active":
        raise HTTPException(status_code=403, detail=row["status"])
    if datetime.now(timezone.utc) >= parse_iso(row["end_at"]):
        expire_old_subscriptions()
        raise HTTPException(status_code=403, detail="expired")

    subscription = row["config"]
    if output_format == "base64":
        subscription = base64.b64encode(subscription.encode()).decode()
    return {
        "user_id": row["user_id"],
        "status": row["status"],
        "node_ip": row["node_ip"],
        "expires_at": row["end_at"],
        "subscription": subscription,
    }


def authenticate_user(user_id: str, token: str) -> sqlite3.Row:
    with connect() as conn:
        user = conn.execute(
            "SELECT * FROM users WHERE user_id = ? AND token = ?",
            (user_id, token),
        ).fetchone()
    if not user:
        raise HTTPException(status_code=401, detail="invalid_credentials")
    return user
