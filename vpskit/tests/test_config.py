from pathlib import Path
import sys


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from vpskit.config import AppSettings


def test_settings_read_environment(monkeypatch):
    monkeypatch.setenv("VPSKIT_ENV", "production")
    monkeypatch.setenv("VPSKIT_HOST", "127.0.0.1")
    monkeypatch.setenv("VPSKIT_PORT", "9000")

    settings = AppSettings.from_env()

    assert settings.environment == "production"
    assert settings.host == "127.0.0.1"
    assert settings.port == 9000
