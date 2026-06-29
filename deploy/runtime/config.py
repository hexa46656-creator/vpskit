from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    db_path: str
    base_domain: str
    install_base_domain: str
    paypal_client_id: str
    paypal_secret: str
    paypal_webhook_id: str
    paypal_base_url: str
    webhook_replay_seconds: int
    stripe_secret_key: str
    stripe_webhook_secret: str
    stripe_success_url: str
    stripe_cancel_url: str
    stripe_price_basic: str
    stripe_price_pro: str
    stripe_price_elite: str
    telegram_bot_token: str
    telegram_admin_chat_id: str
    telegram_support_url: str


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


settings = Settings(
    db_path=_env("VPSKIT_DB_PATH", "/opt/vpskit/vpskit.sqlite3"),
    base_domain=_env("BASE_DOMAIN", "https://vpskit.alexhexa.com").rstrip("/"),
    install_base_domain=_env("INSTALL_BASE_DOMAIN", "https://alexhexa.com").rstrip("/"),
    paypal_client_id=_env("PAYPAL_CLIENT_ID"),
    paypal_secret=_env("PAYPAL_SECRET"),
    paypal_webhook_id=_env("PAYPAL_WEBHOOK_ID"),
    paypal_base_url=_env("PAYPAL_BASE_URL", "https://api-m.paypal.com").rstrip("/"),
    webhook_replay_seconds=int(_env("PAYPAL_REPLAY_WINDOW_SECONDS", "600")),
    stripe_secret_key=_env("STRIPE_SECRET_KEY"),
    stripe_webhook_secret=_env("STRIPE_WEBHOOK_SECRET"),
    stripe_success_url=_env("STRIPE_SUCCESS_URL", "https://alexhexa.com/success.html"),
    stripe_cancel_url=_env("STRIPE_CANCEL_URL", "https://alexhexa.com/pricing.html"),
    stripe_price_basic=_env("STRIPE_PRICE_BASIC"),
    stripe_price_pro=_env("STRIPE_PRICE_PRO"),
    stripe_price_elite=_env("STRIPE_PRICE_ELITE"),
    telegram_bot_token=_env("TELEGRAM_BOT_TOKEN"),
    telegram_admin_chat_id=_env("TELEGRAM_ADMIN_CHAT_ID"),
    telegram_support_url=_env("TELEGRAM_SUPPORT_URL", "https://alexhexa.com/docs.html#support"),
)
