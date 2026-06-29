from __future__ import annotations

import hashlib
import hmac
import json

from vpskit.regions import (
    AutoScalingPolicy,
    GlobalRouter,
    RegionBackendFactory,
    RegionDescriptor,
    RegionRegistry,
)


def _signed_payload(payload: dict[str, object], secret: str) -> tuple[dict[str, str], str]:
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True)
    signature = hmac.new(secret.encode(), body.encode(), hashlib.sha256).hexdigest()
    return {"PayPal-Transmission-Sig": signature}, body


def test_global_router_prefers_nearest_healthy_region() -> None:
    registry = RegionRegistry(
        regions=[
            RegionDescriptor(name="us-east", healthy=True, latency_ms=30),
            RegionDescriptor(name="eu-west", healthy=True, latency_ms=90),
            RegionDescriptor(name="asia-pacific", healthy=True, latency_ms=140),
        ]
    )
    router = GlobalRouter(registry)

    assert router.route_request("203.0.113.10") == "us-east"
    assert router.route_request("198.51.100.10") == "eu-west"


def test_global_router_falls_back_to_healthy_region() -> None:
    registry = RegionRegistry(
        regions=[
            RegionDescriptor(name="us-east", healthy=False, latency_ms=30),
            RegionDescriptor(name="eu-west", healthy=True, latency_ms=90),
            RegionDescriptor(name="asia-pacific", healthy=True, latency_ms=140),
        ]
    )
    router = GlobalRouter(registry)

    assert router.route_request("203.0.113.10") == "eu-west"


def test_autoscaling_policy_scales_up_and_down() -> None:
    policy = AutoScalingPolicy(queue_threshold=10, idle_threshold=2)

    assert policy.decide(queue_depth=15, job_latency_seconds=2.5, cpu_usage=0.8, idle_workers=1) == "scale_up"
    assert policy.decide(queue_depth=0, job_latency_seconds=0.2, cpu_usage=0.1, idle_workers=4) == "scale_down"
    assert policy.decide(queue_depth=4, job_latency_seconds=0.5, cpu_usage=0.2, idle_workers=1) == "hold"


def test_webhook_routes_job_to_selected_region_and_records_global_order() -> None:
    registry = RegionRegistry(
        regions=[
            RegionDescriptor(name="us-east", healthy=True, latency_ms=30),
            RegionDescriptor(name="eu-west", healthy=True, latency_ms=90),
            RegionDescriptor(name="asia-pacific", healthy=True, latency_ms=140),
        ]
    )
    router = GlobalRouter(registry)

    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-1",
        "resource": {
            "id": "PAY-1",
            "subscription_id": "SUB-1",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-1",
            },
        },
    }
    headers, body = _signed_payload(payload, "secret")

    result = router.handle_webhook(body.encode(), headers, source_ip="203.0.113.10")

    assert result["region"] == "us-east"
    assert result["order_status"] == "PAID"
    assert registry.region("us-east").broker.published_jobs[0]["order_id"] == "1"
    assert registry.global_orders[0]["region"] == "us-east"


def test_region_registry_builds_from_region_specific_env(monkeypatch) -> None:
    monkeypatch.setenv("US_EAST_DATABASE_URL", "postgresql://east-db/vpskit")
    monkeypatch.setenv("US_EAST_REDIS_URL", "redis://east-redis/0")
    monkeypatch.setenv("EU_WEST_DATABASE_URL", "postgresql://west-db/vpskit")
    monkeypatch.setenv("EU_WEST_REDIS_URL", "redis://west-redis/0")
    monkeypatch.delenv("ASIA_PACIFIC_DATABASE_URL", raising=False)
    monkeypatch.delenv("ASIA_PACIFIC_REDIS_URL", raising=False)

    factory = RegionBackendFactory()
    registry = RegionRegistry.from_env(backend_factory=factory)

    assert registry.region("us-east").backend.database_url == "postgresql://east-db/vpskit"
    assert registry.region("us-east").backend.redis_url == "redis://east-redis/0"
    assert registry.region("eu-west").backend.database_url == "postgresql://west-db/vpskit"
    assert registry.region("eu-west").backend.redis_url == "redis://west-redis/0"
    assert registry.region("asia-pacific").backend is None
