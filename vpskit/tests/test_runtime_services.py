from vpskit.runtime.services import ServiceStatus


def test_service_status_serializes_to_plain_dict():
    service = ServiceStatus(
        name="api",
        state="configured",
        detail="FastAPI application is importable",
    )

    assert service.to_dict() == {
        "name": "api",
        "state": "configured",
        "detail": "FastAPI application is importable",
    }
