from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path
from typing import Any


CONTROL_PLANE_DIR = Path(__file__).resolve().parent
REPO_ROOT = CONTROL_PLANE_DIR.parent.parent
EVENT_DIR = CONTROL_PLANE_DIR / "runtime" / "events"
INSTALLER_PATH = REPO_ROOT / "vpskit" / "install" / "vpn_stack.sh"


def _event_id() -> str:
    return str(int(time.time() * 1000))


def mark_payment_received(payload: dict[str, Any]) -> Path:
    EVENT_DIR.mkdir(parents=True, exist_ok=True)
    event_path = EVENT_DIR / f"payment_received-{_event_id()}.json"
    event = {
        "status": "payment_received",
        "vpn_stack": str(payload.get("vpn_stack") or os.getenv("VPSKIT_VPN_STACK", "xray")),
        "server_ip": str(payload.get("server_ip") or os.getenv("VPSKIT_SERVER_IP", "")),
        "server_name": str(payload.get("server_name") or os.getenv("VPSKIT_SERVER_NAME", "")),
        "payload": payload,
    }
    event_path.write_text(json.dumps(event, indent=2) + "\n", encoding="utf-8")
    return event_path


def dispatch_payment_received(event: dict[str, Any]) -> subprocess.CompletedProcess[str]:
    if event.get("status") != "payment_received":
        raise ValueError("unsupported event status")

    env = os.environ.copy()
    env["VPSKIT_VPN_STACK"] = str(event.get("vpn_stack") or "")
    env["VPSKIT_SERVER_IP"] = str(event.get("server_ip") or "")
    env["VPSKIT_SERVER_NAME"] = str(event.get("server_name") or "")

    return subprocess.run(
        ["bash", str(INSTALLER_PATH)],
        cwd=REPO_ROOT,
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )


def dispatch_payment_received_file(event_path: str | Path) -> subprocess.CompletedProcess[str]:
    payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
    return dispatch_payment_received(payload)
