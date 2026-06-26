"""Application configuration loaded from environment variables."""

from __future__ import annotations

from dataclasses import dataclass
import os


@dataclass(frozen=True)
class AppSettings:
    environment: str = "development"
    host: str = "0.0.0.0"
    port: int = 8080

    @classmethod
    def from_env(cls) -> "AppSettings":
        return cls(
            environment=os.getenv("VPSKIT_ENV", cls.environment),
            host=os.getenv("VPSKIT_HOST", cls.host),
            port=_read_port(os.getenv("VPSKIT_PORT"), cls.port),
        )


def _read_port(raw_value: str | None, default: int) -> int:
    if raw_value is None or raw_value == "":
        return default

    try:
        port = int(raw_value)
    except ValueError as exc:
        raise ValueError("VPSKIT_PORT must be an integer") from exc

    if not 1 <= port <= 65535:
        raise ValueError("VPSKIT_PORT must be between 1 and 65535")

    return port
