from __future__ import annotations

from typing import Any

import requests

from config import settings
from db import connect


def send_telegram_message(chat_id: str, text: str) -> None:
    if not settings.telegram_bot_token or not chat_id:
        return
    requests.post(
        f"https://api.telegram.org/bot{settings.telegram_bot_token}/sendMessage",
        json={"chat_id": chat_id, "text": text, "disable_web_page_preview": True},
        timeout=10,
    )


def send_payment_success_notification(payload: dict[str, Any]) -> None:
    lines = [
        "VPSKit payment success",
        f"Plan: {payload.get('plan', 'unknown')}",
        f"Node: {payload.get('node_ip', 'pending')}",
        f"Expires: {payload.get('expires_at', 'unknown')}",
        f"Install: {payload.get('install_url', '')}",
    ]
    message = "\n".join(lines)
    if settings.telegram_admin_chat_id:
        send_telegram_message(settings.telegram_admin_chat_id, message)

    user_id = payload.get("user_id")
    if user_id:
        with connect() as conn:
            user = conn.execute("SELECT telegram_id FROM users WHERE user_id = ?", (user_id,)).fetchone()
        if user and user["telegram_id"]:
            send_telegram_message(user["telegram_id"], message)


def handle_telegram_update(update: dict[str, Any]) -> dict[str, str]:
    message = update.get("message") or {}
    chat = message.get("chat") or {}
    chat_id = str(chat.get("id", ""))
    text = str(message.get("text", "")).strip()
    if not chat_id:
        return {"status": "ignored"}

    if text.startswith("/start"):
        send_telegram_message(chat_id, "Welcome to VPSKit. Use /buy to choose a plan or /support for help.")
    elif text.startswith("/buy"):
        send_telegram_message(chat_id, "Buy VPSKit at https://alexhexa.com/pricing.html")
    elif text.startswith("/support"):
        send_telegram_message(chat_id, f"Support: {settings.telegram_support_url}")
    elif text.startswith("/status") or text.startswith("/myvpn"):
        with connect() as conn:
            row = conn.execute(
                """
                SELECT u.user_id, s.status, s.end_at, s.config, n.ip
                FROM users u
                JOIN subscriptions s ON s.user_id = u.user_id
                JOIN nodes n ON n.id = s.node_id
                WHERE u.telegram_id = ?
                ORDER BY s.id DESC
                LIMIT 1
                """,
                (chat_id,),
            ).fetchone()
        if row:
            send_telegram_message(
                chat_id,
                f"Status: {row['status']}\nNode: {row['ip']}\nExpires: {row['end_at']}\nConfig: {row['config']}",
            )
        else:
            send_telegram_message(chat_id, "No active VPSKit subscription is linked to this Telegram account.")
    elif text.startswith("/admin_users") and chat_id == settings.telegram_admin_chat_id:
        with connect() as conn:
            count = conn.execute("SELECT COUNT(*) AS count FROM users").fetchone()["count"]
        send_telegram_message(chat_id, f"Users: {count}")
    elif text.startswith("/admin_revenue") and chat_id == settings.telegram_admin_chat_id:
        with connect() as conn:
            rows = conn.execute(
                "SELECT currency, SUM(CAST(amount AS REAL)) AS total FROM payments WHERE status='completed' GROUP BY currency"
            ).fetchall()
        summary = "\n".join(f"{row['currency'] or 'unknown'} {row['total'] or 0:.2f}" for row in rows) or "No revenue yet."
        send_telegram_message(chat_id, summary)
    elif text.startswith("/broadcast ") and chat_id == settings.telegram_admin_chat_id:
        body = text.removeprefix("/broadcast ").strip()
        with connect() as conn:
            users = conn.execute("SELECT telegram_id FROM users WHERE telegram_id IS NOT NULL").fetchall()
        for user in users:
            send_telegram_message(user["telegram_id"], body)
    else:
        send_telegram_message(chat_id, "Unknown command. Use /buy, /status, /myvpn, or /support.")

    return {"status": "ok"}
