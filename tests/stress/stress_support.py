from __future__ import annotations

from dataclasses import dataclass
from types import SimpleNamespace
from typing import Any


@dataclass
class StressNode:
    node_id: int
    host: str
    user: str
    capacity: int
    load: int = 0
    status: str = "ACTIVE"
    region: str = "us-west"


@dataclass
class StressJob:
    job_id: int
    order_id: int
    user_id: int
    subscription_id: int
    plan: str
    status: str = "QUEUED"
    attempts: int = 0
    node_hint: str | None = None
    last_error: str | None = None
    config_text: str | None = None
    last_attempt_time: str | None = None
    locked_at: str | None = None
    worker_id: str | None = None
    published_at: str | None = None
    created_at: str = "2026-06-28T00:00:00Z"
    updated_at: str = "2026-06-28T00:00:00Z"


class StressRepository:
    def __init__(self) -> None:
        self.users: dict[str, SimpleNamespace] = {}
        self.orders: dict[str, SimpleNamespace] = {}
        self.subscriptions: dict[int, SimpleNamespace] = {}
        self.billing_events: list[dict[str, object]] = []
        self.jobs: dict[int, StressJob] = {}
        self.processed_webhooks: set[str] = set()
        self.nodes: dict[int, StressNode] = {
            1: StressNode(1, "node-a.example.com", "root", capacity=1, load=0, region="us-east"),
            2: StressNode(2, "node-b.example.com", "root", capacity=3, load=0, region="us-west"),
        }
        self.next_user_id = 1
        self.next_order_id = 1
        self.next_subscription_id = 1
        self.next_job_id = 1
        self.next_webhook_event = 1

    def _dedupe_key(self, payload: dict[str, object]) -> str:
        resource = payload["resource"]
        if not isinstance(resource, dict):
            raise ValueError("invalid resource")
        resource_id = str(resource.get("id") or payload.get("id") or "")
        if not resource_id:
            raise ValueError("missing dedupe key")
        return resource_id

    def create_payment_capture(self, payload: dict[str, object]):
        resource = payload["resource"]
        if not isinstance(resource, dict):
            raise ValueError("invalid resource")
        subscriber = resource["subscriber"]
        if not isinstance(subscriber, dict):
            raise ValueError("invalid subscriber")

        dedupe_key = self._dedupe_key(payload)
        if dedupe_key in self.processed_webhooks:
            return None
        self.processed_webhooks.add(dedupe_key)

        self.billing_events.append(
            {
                "paypal_event_id": str(payload["id"]),
                "event_type": str(payload["event_type"]),
                "payload": payload,
            }
        )

        identity_key = str(subscriber["payer_id"])
        email = str(subscriber["email_address"])
        plan = str(resource["plan"])
        amount = float(resource["amount"]["value"])  # type: ignore[index]

        user = self.users.get(identity_key)
        if user is None:
            user = SimpleNamespace(
                id=self.next_user_id,
                identity_key=identity_key,
                email=email,
                plan=plan,
                status="ACTIVE",
                last_active="2026-06-28T00:00:00Z",
                created_at="2026-06-28T00:00:00Z",
                updated_at="2026-06-28T00:00:00Z",
            )
            self.users[identity_key] = user
            self.next_user_id += 1

        payment_id = dedupe_key
        order = self.orders.get(payment_id)
        if order is None:
            order = SimpleNamespace(
                id=self.next_order_id,
                user_id=user.id,
                paypal_payment_id=payment_id,
                status="PAID",
                plan=plan,
                amount=amount,
                created_at="2026-06-28T00:00:00Z",
                updated_at="2026-06-28T00:00:00Z",
            )
            self.orders[payment_id] = order
            self.next_order_id += 1

        subscription = self.subscriptions.get(order.id)
        if subscription is None:
            subscription = SimpleNamespace(
                id=self.next_subscription_id,
                user_id=user.id,
                order_id=order.id,
                paypal_subscription_id=str(resource["subscription_id"]),
                status="ACTIVE",
                activated_at="2026-06-28T00:00:00Z",
                expires_at=None,
                config_text=None,
                created_at="2026-06-28T00:00:00Z",
                updated_at="2026-06-28T00:00:00Z",
            )
            self.subscriptions[order.id] = subscription
            self.next_subscription_id += 1

        job = self.jobs.get(order.id)
        if job is None:
            job = StressJob(
                job_id=self.next_job_id,
                order_id=order.id,
                user_id=user.id,
                subscription_id=subscription.id,
                plan=plan,
                node_hint=str(resource.get("node_hint")) if resource.get("node_hint") else None,
            )
            self.jobs[order.id] = job
            self.next_job_id += 1

        return SimpleNamespace(
            paypal_event_id=str(payload["id"]),
            resource_id=dedupe_key,
            dedupe_key=dedupe_key,
            job=job,
        )

    def is_processed_webhook(self, dedupe_key: str) -> bool:
        return dedupe_key in self.processed_webhooks

    def rollback_payment_capture(self, capture: Any) -> None:
        dedupe_key = getattr(capture, "dedupe_key", None)
        if dedupe_key is not None:
            self.processed_webhooks.discard(dedupe_key)
            self.billing_events = [event for event in self.billing_events if event["paypal_event_id"] != getattr(capture, "paypal_event_id", None)]

        job = getattr(capture, "job", None)
        if job is None:
            return

        self.jobs.pop(job.order_id, None)
        self.subscriptions.pop(job.order_id, None)
        for payment_id, order in list(self.orders.items()):
            if order.id == job.order_id:
                self.orders.pop(payment_id, None)
                break

    def get_job(self, job_id: int) -> StressJob:
        for job in self.jobs.values():
            if job.job_id == job_id:
                return job
        raise LookupError(job_id)

    def get_subscription(self, subscription_id: int) -> SimpleNamespace:
        for subscription in self.subscriptions.values():
            if subscription.id == subscription_id:
                return subscription
        raise LookupError(subscription_id)

    def get_dashboard(self) -> dict[str, int]:
        return {
            "active_users": len(self.users),
            "total_payments": len(self.orders),
            "active_subscriptions": len(self.subscriptions),
            "redis_queue_depth": 0,
        }

    def get_node(self, node_id: int) -> StressNode:
        node = self.nodes.get(node_id)
        if node is None:
            raise LookupError(node_id)
        return node

    def get_node_utilization(self) -> list[dict[str, object]]:
        return [
            {
                "node_id": node.node_id,
                "host": node.host,
                "region": node.region,
                "load": node.load,
                "capacity": node.capacity,
                "utilization": round(node.load / max(1, node.capacity), 4),
                "status": node.status,
            }
            for node in self.nodes.values()
        ]

    def get_region_success_rates(self) -> list[dict[str, object]]:
        return [
            {
                "region": node.region,
                "success_rate": 1.0,
                "success_count": 1,
                "total_count": 1,
            }
            for node in self.nodes.values()
        ]

    def select_least_loaded_active_node(self, node_hint: str | None = None) -> StressNode | None:
        candidates = [node for node in self.nodes.values() if node.status == "ACTIVE" and node.load < node.capacity]
        if node_hint:
            hinted = [node for node in candidates if node.region == node_hint or node.host == node_hint]
            if hinted:
                candidates = hinted
        if not candidates:
            return None
        chosen = sorted(candidates, key=lambda node: (node.load, node.node_id))[0]
        chosen.load += 1
        return chosen

    def release_node(self, node_id: int) -> None:
        node = self.nodes[node_id]
        node.load = max(0, node.load - 1)

    def mark_node_failed(self, node_id: int) -> None:
        self.nodes[node_id].status = "FAILED"

    def start_job(self, job_id: int, node_id: int, worker_id: str) -> StressJob | None:
        job = self.get_job(job_id)
        if job.status not in {"QUEUED", "FAILED"} or job.attempts >= 3:
            return None
        job.status = "RUNNING"
        job.attempts += 1
        job.node_id = node_id  # type: ignore[attr-defined]
        job.worker_id = worker_id
        job.last_attempt_time = "2026-06-28T00:00:00Z"
        job.locked_at = "2026-06-28T00:00:00Z"
        return job

    def complete_job(self, job_id: int, config_text: str) -> None:
        job = self.get_job(job_id)
        job.status = "SUCCESS"
        job.config_text = config_text
        job.locked_at = None

    def fail_job(self, job_id: int, error_message: str) -> StressJob:
        job = self.get_job(job_id)
        job.status = "DEAD" if job.attempts >= 3 else "FAILED"
        job.last_error = error_message
        job.locked_at = None
        return job

    def mark_job_published(self, job_id: int) -> bool:
        job = self.get_job(job_id)
        if job.published_at is not None:
            return False
        job.published_at = "2026-06-28T00:00:00Z"
        return True

    def list_unpublished_jobs(self) -> list[StressJob]:
        return [job for job in self.jobs.values() if job.status == "QUEUED" and job.published_at is None]

    def recover_stuck_jobs(self, stale_minutes: int = 10) -> int:
        return 0

    def store_subscription_config(self, subscription_id: int, config_text: str, status: str = "ACTIVE") -> None:
        for subscription in self.subscriptions.values():
            if subscription.id == subscription_id:
                subscription.config_text = config_text
                subscription.status = status
                return
        raise LookupError(subscription_id)


class StressBroker:
    def __init__(self) -> None:
        self.messages: list[tuple[str, dict[str, str]]] = []
        self.published: list[dict[str, str]] = []
        self.acked: list[tuple[str, str]] = []
        self.dead_letters: list[dict[str, str]] = []
        self._next_message_id = 1

    def publish_job(self, payload: Any) -> str:
        if hasattr(payload, "job_id"):
            payload = {
                "job_id": str(payload.job_id),
                "order_id": str(payload.order_id),
                "user_id": str(payload.user_id),
                "plan": payload.plan,
                "node_hint": payload.node_hint or "",
                "created_at": payload.created_at,
            }
        normalized = {key: str(value) for key, value in payload.items()}
        self.published.append(normalized)
        message_id = f"{self._next_message_id}-0"
        self._next_message_id += 1
        self.messages.append((message_id, normalized))
        return message_id

    def read_next_job(self, *, consumer: str, block_ms: int = 1000):
        if not self.messages:
            return None
        return self.messages[0]

    def claim_pending_job(self, *, consumer: str, min_idle_ms: int = 30_000):
        return None

    def ack(self, message_id: str, stream_name: str = "vpskit:jobs") -> None:
        self.acked.append((stream_name, message_id))
        self.messages = [message for message in self.messages if message[0] != message_id]

    def publish_dead_letter(self, payload: dict[str, str]) -> str:
        self.dead_letters.append(payload)
        return f"dead-{len(self.dead_letters)}"

    def queue_depth(self) -> int:
        return len(self.messages)


class RecordingExecutor:
    def __init__(self, repository: StressRepository, fail_on_call: bool = False, crash_on_call: bool = False) -> None:
        self.repository = repository
        self.fail_on_call = fail_on_call
        self.crash_on_call = crash_on_call
        self.calls: list[tuple[int, int]] = []

    def execute(self, job: StressJob, node: StressNode) -> SimpleNamespace:
        self.calls.append((job.job_id, node.node_id))
        if self.crash_on_call:
            raise RuntimeError("simulated crash")
        if self.fail_on_call:
            raise RuntimeError("simulated provisioning failure")
        config_text = f"config-for-{job.job_id}-on-{node.host}"
        self.repository.store_subscription_config(job.subscription_id, config_text)
        return SimpleNamespace(config_text=config_text)
