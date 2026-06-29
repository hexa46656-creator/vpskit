from pathlib import Path
import sys


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from vpskit.config import AppSettings
from vpskit.config import DeploymentSettings


def test_settings_read_environment(monkeypatch):
    monkeypatch.setenv("VPSKIT_ENV", "production")
    monkeypatch.setenv("VPSKIT_HOST", "127.0.0.1")
    monkeypatch.setenv("VPSKIT_PORT", "9000")

    settings = AppSettings.from_env()

    assert settings.environment == "production"
    assert settings.host == "127.0.0.1"
    assert settings.port == 9000


def test_deployment_settings_read_environment(monkeypatch):
    monkeypatch.setenv("VPSKIT_REGION", "eu-west")
    monkeypatch.setenv("DATABASE_URL", "postgresql://postgres:postgres@localhost/vpskit")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    monkeypatch.setenv("PAYPAL_CLIENT_ID", "client")
    monkeypatch.setenv("PAYPAL_CLIENT_SECRET", "secret")
    monkeypatch.setenv("PAYPAL_WEBHOOK_ID", "webhook")
    monkeypatch.setenv("PAYPAL_WEBHOOK_SECRET", "webhook-secret")
    monkeypatch.setenv("PAYPAL_ENV", "sandbox")
    monkeypatch.setenv("VPS_HOST", "203.0.113.10")
    monkeypatch.setenv("VPS_USER", "deploy")
    monkeypatch.setenv("VPS_SSH_PRIVATE_KEY", "/root/.ssh/id_ed25519")
    monkeypatch.setenv("VPSKIT_API_TOKEN", "token")

    settings = DeploymentSettings.from_env()

    assert settings.paypal_client_id == "client"
    assert settings.paypal_client_secret == "secret"
    assert settings.paypal_webhook_id == "webhook"
    assert settings.paypal_webhook_secret == "webhook-secret"
    assert settings.paypal_env == "sandbox"
    assert settings.region_name == "eu-west"
    assert settings.database_url == "postgresql://postgres:postgres@localhost/vpskit"
    assert settings.redis_url == "redis://localhost:6379/0"
    assert settings.vps_host == "203.0.113.10"
    assert settings.vps_user == "deploy"
    assert settings.vps_ssh_private_key == "/root/.ssh/id_ed25519"
    assert settings.vpskit_api_token == "token"
    assert settings.missing_required_values() == []


def test_deployment_settings_reports_missing_values(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.delenv("REDIS_URL", raising=False)
    monkeypatch.delenv("PAYPAL_CLIENT_ID", raising=False)
    monkeypatch.delenv("PAYPAL_CLIENT_SECRET", raising=False)
    monkeypatch.delenv("PAYPAL_WEBHOOK_ID", raising=False)
    monkeypatch.delenv("PAYPAL_WEBHOOK_SECRET", raising=False)
    monkeypatch.delenv("VPS_HOST", raising=False)
    monkeypatch.delenv("VPS_USER", raising=False)
    monkeypatch.delenv("VPS_SSH_PRIVATE_KEY", raising=False)
    monkeypatch.delenv("VPSKIT_API_TOKEN", raising=False)

    settings = DeploymentSettings.from_env()

    assert settings.paypal_env == "sandbox"
    assert settings.missing_required_values() == [
        "DATABASE_URL",
        "REDIS_URL",
        "PAYPAL_CLIENT_ID",
        "PAYPAL_CLIENT_SECRET",
        "PAYPAL_WEBHOOK_ID",
        "PAYPAL_WEBHOOK_SECRET",
        "VPS_HOST",
        "VPS_USER",
        "VPS_SSH_PRIVATE_KEY",
        "VPSKIT_API_TOKEN",
    ]
