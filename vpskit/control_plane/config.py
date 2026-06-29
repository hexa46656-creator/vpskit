from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


SECRET_PATHS = (
    Path("/run/secrets"),
    Path("/etc/vpskit/secrets"),
)


def _read_secret(name: str) -> str | None:
    for root in SECRET_PATHS:
        path = root / name
        if path.is_file():
            return path.read_text(encoding="utf-8").strip()
    return None


@dataclass(frozen=True)
class ControlPlaneConfig:
    paypal_webhook_id: str


def load_config() -> ControlPlaneConfig:
    paypal_webhook_id = _read_secret("PAYPAL_WEBHOOK_ID") or os.getenv("PAYPAL_WEBHOOK_ID", "")
    return ControlPlaneConfig(paypal_webhook_id=paypal_webhook_id)
