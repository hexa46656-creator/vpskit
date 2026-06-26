"""Runtime service status primitives."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ServiceStatus:
    name: str
    state: str
    detail: str

    def to_dict(self) -> dict[str, str]:
        return {"name": self.name, "state": self.state, "detail": self.detail}


class RuntimeServiceRegistry:
    """Small in-memory registry until systemd or Docker adapters are added."""

    def __init__(self) -> None:
        self._services = [
            ServiceStatus("api", "configured", "FastAPI application is importable"),
        ]

    def list_services(self) -> list[ServiceStatus]:
        return list(self._services)
