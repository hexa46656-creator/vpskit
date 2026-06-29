from fastapi.testclient import TestClient

from vpskit.main import app


client = TestClient(app)


def test_health_returns_ok_status_and_environment():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "environment": "development"}


def test_runtime_services_returns_configured_api_service():
    response = client.get("/runtime/services")

    assert response.status_code == 200
    assert response.json() == [
        {
            "name": "api",
            "state": "configured",
            "detail": "FastAPI production control plane is importable",
        }
    ]
