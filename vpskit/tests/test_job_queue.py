from __future__ import annotations

import hashlib
import hmac
import json
from dataclasses import dataclass, field
from types import SimpleNamespace

import pytest

from vpskit.platform import CloudControlPlane
from vpskit.provisioning import DistributedProvisioningWorker


def _signed_body(payload: dict[str, object], secret: str) -> tuple[dict[str, str], str]:
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True)
    signature = hmac.new(secret.encode(), body.encode(), hashlib.sha256).hexdigest()
    return {"PayPal-Transmission-Sig": signature}, body


@dataclass
class FakeNode:
    node_id: int
    host: str
    user: str
    capacity: int
    load: int = 0
    status: str = "ACTIVE"
    region: str = "us-west"


@dataclass
class FakeJob:
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


class FakeRepository:
    def __init__(self) -> None:
        self.users: dict[str, SimpleNamespace] = {}
        self.orders: dict[str, SimpleNamespace] = {}
        self.subscriptions: dict[int, SimpleNamespace] = {}
        self.billing_events: list[dict[str, object]] = []
        self.jobs: dict[int, FakeJob] = {}
        self.processed_webhooks: set[str] = set()
        self.nodes: dict[int, FakeNode] = {
            1: FakeNode(1, "node-a.example.com", "root", capacity=1, load=1, region="us-east"),
            2: FakeNode(2, "node-b.example.com", "root", capacity=3, load=0, region="us-west"),
        }
        self.next_user_id = 1
        self.next_order_id = 1
        self.next_subscription_id = 1
        self.next_job_id = 1
        self.last_published_job: dict[str, str] | None = None

    def record_billing_event(self, paypal_event_id: str, event_type: str, payload: dict[str, object]) -> int:
        self.billing_events.append(
            {"paypal_event_id": paypal_event_id, "event_type": event_type, "payload": payload}
        )
        return len(self.billing_events)

    def create_payment_capture(self, payload: dict[str, object]):
        resource = payload["resource"]
        assert isinstance(resource, dict)
        subscriber = resource["subscriber"]
        assert isinstance(subscriber, dict)
        paypal_event_id = str(payload["id"])
        paypal_payment_id = str(resource["id"])
        plan = str(resource["plan"])
        email = str(subscriber["email_address"])
        identity_key = str(subscriber["payer_id"])
        amount = float(resource["amount"]["value"])  # type: ignore[index]
        dedupe_key = paypal_payment_id or paypal_event_id
        if dedupe_key in self.processed_webhooks:
            return None
        self.processed_webhooks.add(dedupe_key)
        billing_event_id = self.record_billing_event(paypal_event_id, str(payload["event_type"]), payload)
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

        order = self.orders.get(paypal_payment_id)
        if order is None:
            order = SimpleNamespace(
                id=self.next_order_id,
                user_id=user.id,
                paypal_payment_id=paypal_payment_id,
                status="PAID",
                plan=plan,
                amount=amount,
                created_at="2026-06-28T00:00:00Z",
                updated_at="2026-06-28T00:00:00Z",
            )
            self.orders[paypal_payment_id] = order
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
            job = FakeJob(
                job_id=self.next_job_id,
                order_id=order.id,
                user_id=user.id,
                subscription_id=subscription.id,
                plan=plan,
                node_hint=str(resource.get("node_hint")) if resource.get("node_hint") else None,
            )
            self.jobs[order.id] = job
            self.next_job_id += 1

        job.last_error = None
        return SimpleNamespace(
            paypal_event_id=paypal_event_id,
            resource_id=paypal_payment_id,
            dedupe_key=dedupe_key,
            job=job,
            billing_event_id=billing_event_id,
        )

    def register_payment_capture(self, payload: dict[str, object]):
        capture = self.create_payment_capture(payload)
        return None if capture is None else capture.job

    def mark_processed_webhook(self, dedupe_key: str) -> bool:
        if dedupe_key in self.processed_webhooks:
            return False
        self.processed_webhooks.add(dedupe_key)
        return True

    def record_processed_webhook(
        self,
        paypal_event_id: str | None,
        resource_id: str | None,
        payload: dict[str, object],
    ) -> bool:
        dedupe_key = resource_id or paypal_event_id
        if dedupe_key is None:
            raise ValueError("missing dedupe key")
        if dedupe_key in self.processed_webhooks:
            return False
        self.processed_webhooks.add(dedupe_key)
        return True

    def is_processed_webhook(self, dedupe_key: str) -> bool:
        return dedupe_key in self.processed_webhooks

    def rollback_payment_capture(self, capture) -> None:
        paypal_event_id = getattr(capture, "paypal_event_id", None)
        dedupe_key = getattr(capture, "dedupe_key", None)
        job = getattr(capture, "job", None)
        if dedupe_key is not None:
            self.processed_webhooks.discard(dedupe_key)
            self.billing_events = [
                event
                for event in self.billing_events
                if event.get("paypal_event_id") not in {dedupe_key, paypal_event_id}
            ]
        if job is None:
            return

        self.jobs.pop(job.order_id, None)
        self.subscriptions.pop(job.order_id, None)
        order = None
        for payment_id, stored_order in list(self.orders.items()):
            if stored_order.id == job.order_id:
                order = payment_id
                break
        if order is not None:
            self.orders.pop(order, None)

    def mark_job_published(self, job_id: int) -> bool:
        job = self.get_job(job_id)
        if job.published_at is not None:
            return False
        job.published_at = "2026-06-28T00:00:00Z"
        return True

    def list_unpublished_jobs(self) -> list[FakeJob]:
        return sorted(
            [job for job in self.jobs.values() if job.status == "QUEUED" and job.published_at is None],
            key=lambda job: job.job_id,
        )

    def get_user(self, user_id: int) -> SimpleNamespace:
        for user in self.users.values():
            if user.id == user_id:
                return user
        raise LookupError(user_id)

    def get_dashboard(self) -> dict[str, int]:
        return {
            "active_users": len(self.users),
            "total_payments": len(self.orders),
            "active_subscriptions": len(self.subscriptions),
            "redis_queue_depth": 0,
        }

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

    def get_job(self, job_id: int) -> FakeJob:
        for job in self.jobs.values():
            if job.job_id == job_id:
                return job
        raise LookupError(job_id)

    def select_least_loaded_active_node(self, node_hint: str | None = None) -> FakeNode:
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

    def reserve_node(self, node_id: int) -> FakeNode:
        node = self.nodes[node_id]
        node.load += 1
        return node

    def release_node(self, node_id: int) -> None:
        node = self.nodes[node_id]
        node.load = max(0, node.load - 1)

    def mark_node_failed(self, node_id: int) -> None:
        self.nodes[node_id].status = "FAILED"

    def start_job(self, job_id: int, node_id: int, worker_id: str) -> FakeJob:
        job = self.get_job(job_id)
        job.status = "RUNNING"
        job.attempts += 1
        job.updated_at = "2026-06-28T00:00:00Z"
        job.node_id = node_id  # type: ignore[attr-defined]
        job.worker_id = worker_id  # type: ignore[attr-defined]
        job.last_attempt_time = "2026-06-28T00:00:00Z"
        job.locked_at = "2026-06-28T00:00:00Z"
        return job

    def finish_job(self, job_id: int, config_text: str) -> None:
        job = self.get_job(job_id)
        job.status = "SUCCESS"
        job.config_text = config_text

    def complete_job(self, job_id: int, config_text: str) -> None:
        self.finish_job(job_id, config_text)

    def fail_job(self, job_id: int, error_message: str) -> FakeJob:
        job = self.get_job(job_id)
        job.status = "DEAD" if job.attempts >= 3 else "FAILED"
        job.last_error = error_message
        job.locked_at = None
        return job

    def store_subscription_config(self, subscription_id: int, config_text: str) -> None:
        for subscription in self.subscriptions.values():
            if subscription.id == subscription_id:
                subscription.config_text = config_text
                return
        raise LookupError(subscription_id)

    def get_subscription(self, subscription_id: int) -> SimpleNamespace:
        for subscription in self.subscriptions.values():
            if subscription.id == subscription_id:
                return subscription
        raise LookupError(subscription_id)


class FakeRedisStream:
    def __init__(self, messages: list[tuple[str, dict[str, str]]] | None = None) -> None:
        self.messages = messages or []
        self.published: list[tuple[str, dict[str, str]]] = []
        self.acked: list[tuple[str, str]] = []
        self.dead_letters: list[dict[str, str]] = []

    def publish_job(self, payload: dict[str, str]) -> str:
        if isinstance(payload, FakeJob):
            payload = {
                "job_id": str(payload.job_id),
                "order_id": str(payload.order_id),
                "user_id": str(payload.user_id),
                "plan": payload.plan,
                "node_hint": payload.node_hint or "",
                "created_at": payload.created_at,
            }
        self.published.append(("vpskit:jobs", payload))
        self.messages.append((f"{len(self.messages) + 1}-0", payload))
        return self.messages[-1][0]

    def read_next_job(self, *, consumer: str, block_ms: int = 1000, group: str | None = None):
        if not self.messages:
            return None
        return self.messages.pop(0)

    def claim_pending_job(self, *, consumer: str, min_idle_ms: int = 30_000):
        return None

    def ack(self, message_id: str, stream_name: str = "vpskit:jobs") -> None:
        self.acked.append((stream_name, message_id))

    def publish_dead_letter(self, payload: dict[str, str]) -> str:
        self.dead_letters.append(payload)
        return f"dead-{len(self.dead_letters)}"

    def queue_depth(self) -> int:
        return len(self.messages)


class SuccessfulExecutor:
    def __init__(self, repository: FakeRepository) -> None:
        self.repository = repository

    def execute(self, job: FakeJob, node: FakeNode) -> SimpleNamespace:
        config_text = f"config-for-{job.job_id}-on-{node.host}"
        self.repository.store_subscription_config(job.subscription_id, config_text)
        return SimpleNamespace(config_text=config_text)


class FailingExecutor:
    def execute(self, job: FakeJob, node: FakeNode) -> str:
        raise RuntimeError("ssh failed")


class FailingPublishRedisStream(FakeRedisStream):
    def publish_job(self, payload: dict[str, str]) -> str:
        raise RuntimeError("redis unavailable")


def test_webhook_creates_order_subscription_job_and_stream_message() -> None:
    repository = FakeRepository()
    broker = FakeRedisStream()
    control_plane = CloudControlPlane(repository, broker, webhook_secret="secret")

    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-123",
        "resource": {
            "id": "PAY-123",
            "subscription_id": "SUB-456",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "node_hint": "us-west",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-1",
            },
        },
    }

    headers, body = _signed_body(payload, "secret")
    accepted = control_plane.handle_paypal_webhook(body.encode(), headers, source_ip="203.0.113.10")
    duplicate = control_plane.handle_paypal_webhook(body.encode(), headers, source_ip="203.0.113.10")

    assert accepted is True
    assert duplicate is False
    assert len(repository.billing_events) == 1
    assert len(repository.orders) == 1
    assert len(repository.subscriptions) == 1
    assert len(repository.jobs) == 1
    assert len(broker.published) == 1
    assert broker.published[0][1]["job_id"] == str(next(iter(repository.jobs.values())).job_id)
    assert repository.get_dashboard()["total_payments"] == 1


def test_webhook_rolls_back_when_queue_publish_fails() -> None:
    repository = FakeRepository()
    broker = FailingPublishRedisStream()
    control_plane = CloudControlPlane(repository, broker, webhook_secret="secret")

    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-123",
        "resource": {
            "id": "PAY-123",
            "subscription_id": "SUB-456",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "node_hint": "us-west",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-1",
            },
        },
    }

    headers, body = _signed_body(payload, "secret")

    with pytest.raises(RuntimeError):
        control_plane.handle_paypal_webhook(body.encode(), headers, source_ip="203.0.113.10")

    assert repository.billing_events == []
    assert repository.orders == {}
    assert repository.subscriptions == {}
    assert repository.jobs == {}
    assert repository.processed_webhooks == set()


def test_worker_consumes_stream_message_and_acks_success() -> None:
    repository = FakeRepository()
    broker = FakeRedisStream()
    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-123",
        "resource": {
            "id": "PAY-123",
            "subscription_id": "SUB-456",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-1",
            },
        },
    }
    job = repository.register_payment_capture(payload)
    broker.messages.append(
        (
            "1-0",
            {
                "job_id": str(job.job_id),
                "order_id": str(job.order_id),
                "user_id": str(job.user_id),
                "plan": job.plan,
                "node_hint": "us-west",
                "created_at": job.created_at,
            },
        )
    )

    worker = DistributedProvisioningWorker(
        repository=repository,
        broker=broker,
        executor=SuccessfulExecutor(repository),
        worker_id="worker-1",
    )
    processed = worker.process_next_message()

    assert processed is True
    assert repository.get_job(job.job_id).status == "SUCCESS"
    assert broker.acked == [("vpskit:jobs", "1-0")]
    assert repository.nodes[2].load == 0
    assert repository.get_subscription(job.subscription_id).config_text is not None


def test_worker_releases_reserved_node_when_job_cannot_start() -> None:
    repository = FakeRepository()
    broker = FakeRedisStream()
    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-123",
        "resource": {
            "id": "PAY-123",
            "subscription_id": "SUB-456",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-1",
            },
        },
    }
    job = repository.register_payment_capture(payload)
    assert job is not None
    repository.get_job(job.job_id).status = "SUCCESS"  # type: ignore[misc]
    repository.nodes[2].load = 0
    broker.messages.append(
        (
            "1-0",
            {
                "job_id": str(job.job_id),
                "order_id": str(job.order_id),
                "user_id": str(job.user_id),
                "plan": job.plan,
                "node_hint": "us-west",
                "created_at": job.created_at,
            },
        )
    )

    worker = DistributedProvisioningWorker(
        repository=repository,
        broker=broker,
        executor=SuccessfulExecutor(repository),
        worker_id="worker-1",
    )
    processed = worker.process_next_message()

    assert processed is True
    assert repository.nodes[2].load == 0
    assert broker.acked == [("vpskit:jobs", "1-0")]


def test_worker_repacks_unpublished_jobs_on_startup() -> None:
    repository = FakeRepository()
    broker = FakeRedisStream()
    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-123",
        "resource": {
            "id": "PAY-123",
            "subscription_id": "SUB-456",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-1",
            },
        },
    }
    job = repository.register_payment_capture(payload)
    assert job is not None

    worker = DistributedProvisioningWorker(
        repository=repository,
        broker=broker,
        executor=SuccessfulExecutor(repository),
        worker_id="worker-1",
    )

    recovered = worker.recover_unpublished_jobs()

    assert recovered == 1
    assert len(broker.published) == 1
    assert repository.get_job(job.job_id).published_at is not None


def test_worker_dead_letters_after_third_failure() -> None:
    repository = FakeRepository()
    broker = FakeRedisStream()
    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-123",
        "resource": {
            "id": "PAY-123",
            "subscription_id": "SUB-456",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-1",
            },
        },
    }
    job = repository.register_payment_capture(payload)
    job.attempts = 2
    broker.messages.append(
        (
            "1-0",
            {
                "job_id": str(job.job_id),
                "order_id": str(job.order_id),
                "user_id": str(job.user_id),
                "plan": job.plan,
                "node_hint": "us-west",
                "created_at": job.created_at,
            },
        )
    )

    worker = DistributedProvisioningWorker(
        repository=repository,
        broker=broker,
        executor=FailingExecutor(),
        worker_id="worker-2",
    )
    processed = worker.process_next_message()

    assert processed is True
    assert repository.get_job(job.job_id).status == "DEAD"
    assert broker.dead_letters[0]["job_id"] == str(job.job_id)
    assert broker.acked == [("vpskit:jobs", "1-0")]
