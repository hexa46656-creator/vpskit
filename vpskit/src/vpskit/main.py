"""FastAPI entrypoint for VPSKit."""

from __future__ import annotations

from fastapi import FastAPI

from vpskit.config import AppSettings
from vpskit.runtime.services import RuntimeServiceRegistry


settings = AppSettings.from_env()
service_registry = RuntimeServiceRegistry()
app = FastAPI(title="VPSKit", version="0.7.0-beta")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


@app.get("/runtime/services")
def list_services() -> list[dict[str, str]]:
    return [service.to_dict() for service in service_registry.list_services()]
