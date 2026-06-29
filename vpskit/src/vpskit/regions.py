"""Multi-region routing and autoscaling primitives for VPSKit v3."""

from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
import hmac
import json
import os
from typing import Any, Mapping


REGION_NAMES = ("us-east", "eu-west", "asia-pacific")
IP_REGION_PREFIXES = {
    "203.0.113.": "us-east",
    "198.51.100.": "eu-west",
    "192.0.2.": "asia-pacific",
}


@dataclass(frozen=True)
class RegionDescriptor:
    name: str
    healthy: bool = True
    latency_ms: int = 0
    queue_depth: int = 0
    cpu_usage: float = 0.0


@dataclass(frozen=True)
class RegionBackendBinding:
    region: str
    database_url: str | None = None
    redis_url: str | None = None


class RegionBackendFactory:
    def build(self, region_name: str, database_url: str | None, redis_url: str | None) -> RegionBackendBinding | None:
        if not database_url and not redis_url:
            return None
        return RegionBackendBinding(region=region_name, database_url=database_url, redis_url=redis_url)


@dataclass
class InMemoryRegionBroker:
    region: str
    published_jobs: list[dict[str, str]] = field(default_factory=list)
    dead_letters: list[dict[str, str]] = field(default_factory=list)

    def publish_job(self, payload: Mapping[str, Any]) -> dict[str, str]:
        normalized = {key: str(value) for key, value in payload.items()}
        self.published_jobs.append(normalized)
        return normalized

    def publish_dead_letter(self, payload: Mapping[str, Any]) -> dict[str, str]:
        normalized = {key: str(value) for key, value in payload.items()}
        self.dead_letters.append(normalized)
        return normalized

    def queue_depth(self) -> int:
        return len(self.published_jobs)


@dataclass
class RegionRuntime:
    descriptor: RegionDescriptor
    broker: InMemoryRegionBroker
    backend: RegionBackendBinding | None = None
    orders: list[dict[str, Any]] = field(default_factory=list)
    users: dict[str, dict[str, Any]] = field(default_factory=dict)
    jobs: list[dict[str, Any]] = field(default_factory=list)

    def record_order(self, order_record: dict[str, Any]) -> None:
        self.orders.append(order_record)

    def upsert_user(self, identity_key: str, email: str | None, plan: str) -> dict[str, Any]:
        record = self.users.get(identity_key)
        if record is None:
            record = {
                "id": len(self.users) + 1,
                "identity_key": identity_key,
                "email": email,
                "plan": plan,
                "status": "ACTIVE",
                "last_active": None,
            }
            self.users[identity_key] = record
        else:
            if email:
                record["email"] = email
            record["plan"] = plan
        return record

    def enqueue_job(self, payload: dict[str, Any]) -> dict[str, str]:
        normalized = self.broker.publish_job(payload)
        self.jobs.append(dict(normalized))
        return normalized

    def get_user(self, user_id: int) -> dict[str, Any]:
        for user in self.users.values():
            if user["id"] == user_id:
                return user
        raise LookupError(f"user {user_id} not found")


class RegionRegistry:
    def __init__(
        self,
        regions: list[RegionDescriptor] | None = None,
        runtimes: dict[str, RegionRuntime] | None = None,
    ) -> None:
        if runtimes is not None:
            self._regions = runtimes
        else:
            descriptors = regions or [
                RegionDescriptor(name=name, healthy=True, latency_ms=index * 50)
                for index, name in enumerate(REGION_NAMES)
            ]
            self._regions = {
                descriptor.name: RegionRuntime(
                    descriptor=descriptor,
                    broker=InMemoryRegionBroker(region=descriptor.name),
                )
                for descriptor in descriptors
            }
        self.global_orders: list[dict[str, Any]] = []

    @classmethod
    def from_env(cls, backend_factory: RegionBackendFactory | None = None) -> "RegionRegistry":
        backend_factory = backend_factory or RegionBackendFactory()
        runtimes: dict[str, RegionRuntime] = {}
        for index, region_name in enumerate(REGION_NAMES):
            env_prefix = region_name.upper().replace("-", "_")
            database_url = os.getenv(f"{env_prefix}_DATABASE_URL")
            redis_url = os.getenv(f"{env_prefix}_REDIS_URL")
            latency_raw = os.getenv(f"{env_prefix}_LATENCY_MS")
            healthy_raw = os.getenv(f"{env_prefix}_HEALTHY")
            descriptor = RegionDescriptor(
                name=region_name,
                healthy=_parse_bool(healthy_raw, default=True) if healthy_raw is not None else True,
                latency_ms=_parse_int(latency_raw, default=index * 50),
            )
            runtimes[region_name] = RegionRuntime(
                descriptor=descriptor,
                broker=InMemoryRegionBroker(region=region_name),
                backend=backend_factory.build(region_name, database_url, redis_url),
            )
        return cls(runtimes=runtimes)

    def region(self, name: str) -> RegionRuntime:
        try:
            return self._regions[name]
        except KeyError as exc:
            raise LookupError(f"region {name} not found") from exc

    def healthy_regions(self) -> list[RegionRuntime]:
        return [runtime for runtime in self._regions.values() if runtime.descriptor.healthy]

    def all_regions(self) -> list[RegionRuntime]:
        return list(self._regions.values())


class AutoScalingPolicy:
    def __init__(self, queue_threshold: int = 10, idle_threshold: int = 2, cpu_threshold: float = 0.75) -> None:
        self.queue_threshold = queue_threshold
        self.idle_threshold = idle_threshold
        self.cpu_threshold = cpu_threshold

    def decide(
        self,
        *,
        queue_depth: int,
        job_latency_seconds: float,
        cpu_usage: float,
        idle_workers: int,
    ) -> str:
        if queue_depth > self.queue_threshold or job_latency_seconds > 1.5 or cpu_usage >= self.cpu_threshold:
            return "scale_up"

        if queue_depth == 0 and idle_workers > self.idle_threshold:
            return "scale_down"

        return "hold"


class GlobalRouter:
    def __init__(self, registry: RegionRegistry, webhook_secret: str | None = None) -> None:
        self.registry = registry
        self.webhook_secret = webhook_secret or os.getenv("PAYPAL_WEBHOOK_SECRET") or "secret"

    @classmethod
    def from_env(cls) -> "GlobalRouter":
        return cls(RegionRegistry.from_env(), webhook_secret=os.getenv("PAYPAL_WEBHOOK_SECRET"))

    def route_request(self, source_ip: str, preferred_region: str | None = None) -> str:
        candidate = preferred_region or self._region_from_ip(source_ip)
        if candidate and self._is_healthy(candidate):
            return candidate

        healthy_regions = self.registry.healthy_regions()
        if not healthy_regions:
            raise RuntimeError("no healthy regions available")

        return min(healthy_regions, key=lambda runtime: runtime.descriptor.latency_ms).descriptor.name

    def handle_webhook(
        self,
        body: bytes,
        headers: Mapping[str, str],
        source_ip: str | None = None,
    ) -> dict[str, Any]:
        if not self._validate_signature(body, headers):
            raise ValueError("invalid signature")

        try:
            payload = json.loads(body.decode() or "{}")
        except json.JSONDecodeError as exc:
            raise ValueError("invalid json") from exc

        if payload.get("event_type") not in {None, "PAYMENT.CAPTURE.COMPLETED"}:
            return {"status": "ignored"}

        region_name = self.route_request(source_ip or "0.0.0.0")
        runtime = self.registry.region(region_name)

        resource = _mapping(payload.get("resource"))
        subscriber = _mapping(resource.get("subscriber"))
        identity_key = _pick_first(subscriber.get("payer_id"), subscriber.get("email_address"), resource.get("id"), payload.get("id"))
        email = _pick_first(subscriber.get("email_address"))
        plan = _derive_plan(resource)

        user = runtime.upsert_user(identity_key, email, plan)
        order_id = str(len(self.registry.global_orders) + 1)
        order_record = {
            "id": order_id,
            "user_id": str(user["id"]),
            "paypal_payment_id": _pick_first(resource.get("id"), payload.get("id"), f"payment-{order_id}") or f"payment-{order_id}",
            "status": "PAID",
            "plan": plan,
            "region": region_name,
            "created_at": _now_iso(),
        }
        runtime.record_order(order_record)
        self.registry.global_orders.append(order_record)

        job_payload = {
            "job_id": order_id,
            "order_id": order_id,
            "user_id": str(user["id"]),
            "plan": plan,
            "node_hint": region_name,
            "created_at": order_record["created_at"],
        }
        runtime.enqueue_job(job_payload)
        return {
            "region": region_name,
            "order_status": "PAID",
            "order_id": order_id,
            "job_id": order_id,
        }

    def get_user(self, user_id: int) -> dict[str, Any]:
        for runtime in self.registry.all_regions():
            try:
                user = runtime.get_user(user_id)
            except LookupError:
                continue
            return user
        raise LookupError(f"user {user_id} not found")

    def get_dashboard(self) -> dict[str, Any]:
        region_health = {
            runtime.descriptor.name: runtime.descriptor.healthy for runtime in self.registry.all_regions()
        }
        return {
            "active_users": sum(len(runtime.users) for runtime in self.registry.all_regions()),
            "total_payments": len(self.registry.global_orders),
            "active_subscriptions": len(self.registry.global_orders),
            "redis_queue_depth": sum(runtime.broker.queue_depth() for runtime in self.registry.all_regions()),
            "region_health": region_health,
            "cross_region_latency_ms": {
                runtime.descriptor.name: runtime.descriptor.latency_ms for runtime in self.registry.all_regions()
            },
            "job_distribution_map": {
                runtime.descriptor.name: len(runtime.jobs) for runtime in self.registry.all_regions()
            },
            "success_rate_per_region": {
                runtime.descriptor.name: 1.0 if runtime.descriptor.healthy else 0.0
                for runtime in self.registry.all_regions()
            },
            "auto_scaling_events": [],
        }

    def _region_from_ip(self, source_ip: str) -> str | None:
        for prefix, region_name in IP_REGION_PREFIXES.items():
            if source_ip.startswith(prefix):
                return region_name
        return None

    def _is_healthy(self, region_name: str) -> bool:
        try:
            return self.registry.region(region_name).descriptor.healthy
        except LookupError:
            return False

    def _validate_signature(self, body: bytes, headers: Mapping[str, str]) -> bool:
        provided_signature = headers.get("PayPal-Transmission-Sig") or headers.get("X-PayPal-Signature")
        if not provided_signature:
            return False

        expected = hmac.new(self.webhook_secret.encode(), body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, provided_signature)


def _mapping(value: Any) -> Mapping[str, Any]:
    return value if isinstance(value, Mapping) else {}


def _pick_first(*values: Any) -> str | None:
    for value in values:
        if value is None:
            continue
        text = str(value).strip()
        if text:
            return text
    return None


def _derive_plan(resource: Mapping[str, Any]) -> str:
    explicit_plan = _pick_first(resource.get("plan"))
    if explicit_plan in {"lite", "pro", "elite"}:
        return explicit_plan

    amount = _derive_amount(resource)
    if amount >= 99:
        return "elite"
    if amount >= 49:
        return "pro"
    return "lite"


def _derive_amount(resource: Mapping[str, Any]) -> float:
    amount = resource.get("amount")
    if isinstance(amount, Mapping):
        raw_value = _pick_first(amount.get("value"))
        if raw_value is not None:
            try:
                return float(raw_value)
            except ValueError:
                pass
    raw_value = _pick_first(resource.get("amount_value"), resource.get("amount"))
    if raw_value is not None:
        try:
            return float(raw_value)
        except ValueError:
            pass
    return 0.0


def _now_iso() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _parse_int(raw_value: str | None, default: int) -> int:
    if raw_value in {None, ""}:
        return default
    try:
        return int(raw_value)
    except ValueError:
        return default


def _parse_bool(raw_value: str | None, default: bool = True) -> bool:
    if raw_value in {None, ""}:
        return default
    value = raw_value.strip().lower()
    if value in {"1", "true", "yes", "on"}:
        return True
    if value in {"0", "false", "no", "off"}:
        return False
    return default
