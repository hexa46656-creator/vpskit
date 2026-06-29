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


@dataclass(frozen=True)
class DeploymentSettings:
    region_name: str | None = None
    database_url: str | None = None
    redis_url: str | None = None
    redis_stream_jobs: str = "vpskit:jobs"
    redis_stream_dead: str = "vpskit:dead"
    redis_consumer_group: str = "vpskit-workers"
    worker_id: str | None = None
    paypal_client_id: str | None = None
    paypal_client_secret: str | None = None
    paypal_webhook_id: str | None = None
    paypal_webhook_secret: str | None = None
    paypal_env: str = "sandbox"
    vps_host: str | None = None
    vps_user: str | None = None
    vps_ssh_private_key: str | None = None
    vpskit_api_token: str | None = None

    @classmethod
    def from_env(cls) -> "DeploymentSettings":
        return cls(
            region_name=_read_optional_env("VPSKIT_REGION"),
            database_url=_read_optional_env("DATABASE_URL"),
            redis_url=_read_optional_env("REDIS_URL"),
            redis_stream_jobs=os.getenv("REDIS_STREAM_JOBS", cls.redis_stream_jobs),
            redis_stream_dead=os.getenv("REDIS_STREAM_DEAD", cls.redis_stream_dead),
            redis_consumer_group=os.getenv("REDIS_CONSUMER_GROUP", cls.redis_consumer_group),
            worker_id=_read_optional_env("WORKER_ID"),
            paypal_client_id=_read_optional_env("PAYPAL_CLIENT_ID"),
            paypal_client_secret=_read_optional_env("PAYPAL_CLIENT_SECRET"),
            paypal_webhook_id=_read_optional_env("PAYPAL_WEBHOOK_ID"),
            paypal_webhook_secret=_read_optional_env("PAYPAL_WEBHOOK_SECRET"),
            paypal_env=os.getenv("PAYPAL_ENV", cls.paypal_env),
            vps_host=_read_optional_env("VPS_HOST"),
            vps_user=_read_optional_env("VPS_USER"),
            vps_ssh_private_key=_read_optional_env("VPS_SSH_PRIVATE_KEY"),
            vpskit_api_token=_read_optional_env("VPSKIT_API_TOKEN"),
        )

    def missing_required_values(self) -> list[str]:
        missing = []
        for field_name, value in (
            ("DATABASE_URL", self.database_url),
            ("REDIS_URL", self.redis_url),
            ("PAYPAL_CLIENT_ID", self.paypal_client_id),
            ("PAYPAL_CLIENT_SECRET", self.paypal_client_secret),
            ("PAYPAL_WEBHOOK_ID", self.paypal_webhook_id),
            ("PAYPAL_WEBHOOK_SECRET", self.paypal_webhook_secret),
            ("VPS_HOST", self.vps_host),
            ("VPS_USER", self.vps_user),
            ("VPS_SSH_PRIVATE_KEY", self.vps_ssh_private_key),
            ("VPSKIT_API_TOKEN", self.vpskit_api_token),
        ):
            if value in {None, ""}:
                missing.append(field_name)

        return missing


def _read_optional_env(name: str) -> str | None:
    raw_value = os.getenv(name)
    if raw_value is None or raw_value == "":
        return None

    return raw_value
