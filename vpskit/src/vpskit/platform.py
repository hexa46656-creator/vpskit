"""Cloud-native Postgres and Redis primitives for VPSKit v2."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import logging
import os
from typing import Any, Mapping

logger = logging.getLogger(__name__)
metrics_logger = logging.getLogger("vpskit.metrics")

try:  # pragma: no cover - exercised in production environments
    import psycopg
    from psycopg.rows import dict_row
except ModuleNotFoundError:  # pragma: no cover - keeps local imports working without deps
    psycopg = None
    dict_row = None

try:  # pragma: no cover - exercised in production environments
    import redis as redis_lib
except ModuleNotFoundError:  # pragma: no cover - keeps local imports working without deps
    redis_lib = None

from vpskit.config import DeploymentSettings

DEFAULT_POSTGRES_DSN = "postgresql://localhost/vpskit"
DEFAULT_REDIS_URL = "redis://localhost:6379/0"
DEFAULT_JOB_STREAM = "vpskit:jobs"
DEFAULT_DEAD_STREAM = "vpskit:dead"
DEFAULT_CONSUMER_GROUP = "vpskit-workers"


@dataclass(frozen=True)
class UserRecord:
    id: int
    identity_key: str
    email: str | None
    plan: str
    status: str
    last_active: str | None
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class OrderRecord:
    id: int
    user_id: int
    paypal_payment_id: str
    status: str
    plan: str
    amount: float
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class SubscriptionRecord:
    id: int
    user_id: int
    order_id: int
    paypal_subscription_id: str
    status: str
    activated_at: str | None
    expires_at: str | None
    config_text: str | None
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class PaymentCaptureRecord:
    paypal_event_id: str | None
    resource_id: str | None
    dedupe_key: str
    job: "ProvisionJobRecord"


@dataclass(frozen=True)
class BillingEventRecord:
    id: int
    paypal_event_id: str
    event_type: str
    payload_json: str
    created_at: str


@dataclass(frozen=True)
class ProvisionJobRecord:
    job_id: int
    user_id: int
    order_id: int
    subscription_id: int
    plan: str
    node_id: int | None
    node_hint: str | None
    status: str
    attempts: int
    last_error: str | None
    last_attempt_time: str | None
    locked_at: str | None
    worker_id: str | None
    provisioned_at: str | None
    published_at: str | None
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class VpsNodeRecord:
    node_id: int
    host: str
    user: str
    capacity: int
    load: int
    status: str
    region: str
    created_at: str
    updated_at: str


class PostgresRepository:
    def __init__(self, dsn: str | None = None) -> None:
        self.dsn = dsn or os.getenv("DATABASE_URL")
        if not self.dsn:
            raise ValueError("DATABASE_URL is required")
        if psycopg is None:
            raise RuntimeError("psycopg is not installed")
        self._ensure_schema()

    @classmethod
    def from_env(cls) -> "PostgresRepository":
        return cls(os.getenv("DATABASE_URL"))

    def _connect(self):
        return psycopg.connect(self.dsn, row_factory=dict_row)

    def _ensure_schema(self) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS users (
                        id BIGSERIAL PRIMARY KEY,
                        identity_key TEXT NOT NULL UNIQUE,
                        email TEXT,
                        plan TEXT NOT NULL DEFAULT 'lite',
                        status TEXT NOT NULL DEFAULT 'ACTIVE',
                        last_active TEXT,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS orders (
                        id BIGSERIAL PRIMARY KEY,
                        user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        paypal_payment_id TEXT NOT NULL UNIQUE,
                        status TEXT NOT NULL,
                        plan TEXT NOT NULL,
                        amount DOUBLE PRECISION NOT NULL,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS subscriptions (
                        id BIGSERIAL PRIMARY KEY,
                        user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
                        paypal_subscription_id TEXT NOT NULL UNIQUE,
                        status TEXT NOT NULL,
                        activated_at TEXT,
                        expires_at TEXT,
                        config_text TEXT,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS billing_events (
                        id BIGSERIAL PRIMARY KEY,
                        paypal_event_id TEXT NOT NULL UNIQUE,
                        event_type TEXT NOT NULL,
                        payload_json TEXT NOT NULL,
                        created_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS processed_webhooks (
                        id BIGSERIAL PRIMARY KEY,
                        paypal_event_id TEXT,
                        resource_id TEXT,
                        dedupe_key TEXT NOT NULL UNIQUE,
                        payload_json TEXT NOT NULL,
                        created_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS vps_nodes (
                        node_id BIGSERIAL PRIMARY KEY,
                        host TEXT NOT NULL UNIQUE,
                        user_name TEXT NOT NULL,
                        capacity INTEGER NOT NULL DEFAULT 1,
                        load INTEGER NOT NULL DEFAULT 0,
                        status TEXT NOT NULL DEFAULT 'ACTIVE',
                        region TEXT NOT NULL DEFAULT 'default',
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL
                    );

                    CREATE TABLE IF NOT EXISTS provision_jobs (
                        job_id BIGSERIAL PRIMARY KEY,
                        user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
                        subscription_id BIGINT NOT NULL UNIQUE REFERENCES subscriptions(id) ON DELETE CASCADE,
                        plan TEXT NOT NULL,
                        node_id BIGINT REFERENCES vps_nodes(node_id) ON DELETE SET NULL,
                        node_hint TEXT,
                        status TEXT NOT NULL,
                        attempts INTEGER NOT NULL DEFAULT 0,
                        last_error TEXT,
                        last_attempt_time TEXT,
                        locked_at TEXT,
                        worker_id TEXT,
                        provisioned_at TEXT,
                        published_at TEXT,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL
                    );
                    """
                )
                cursor.execute("ALTER TABLE provision_jobs ADD COLUMN IF NOT EXISTS published_at TEXT")

    def create_payment_capture(self, payload: Mapping[str, Any]) -> PaymentCaptureRecord | None:
        resource = _mapping(payload.get("resource"))
        subscriber = _mapping(resource.get("subscriber"))
        event_id = _pick_first(payload.get("id"), payload.get("event_id"), resource.get("event_id"))
        payment_id = _pick_first(resource.get("id"), resource.get("capture_id"))
        if not event_id and not payment_id:
            raise ValueError("webhook payload must include an event id or payment id")

        identity_key = _pick_first(subscriber.get("payer_id"), subscriber.get("email_address"), payment_id, event_id)
        if not identity_key:
            raise ValueError("unable to determine user identity")

        email = _pick_first(subscriber.get("email_address"))
        plan = _derive_plan(resource)
        amount = _derive_amount(resource)
        payment_id = payment_id or event_id
        subscription_payment_id = _pick_first(resource.get("subscription_id"), resource.get("billing_agreement_id"))
        if not subscription_payment_id:
            subscription_payment_id = f"sub-{payment_id}"
        node_hint = _pick_first(resource.get("node_hint"), resource.get("region_hint"))

        with self._connect() as connection:
            with connection.cursor() as cursor:
                dedupe_key = payment_id or event_id
                if not self._record_processed_webhook(cursor, event_id, payment_id, payload):
                    return None

                self._upsert_billing_event(cursor, dedupe_key, payload)
                user_id = self._upsert_user(cursor, identity_key, email, plan)
                order_id = self._upsert_order(cursor, user_id, payment_id, plan, amount)
                subscription_id = self._upsert_subscription(
                    cursor,
                    user_id,
                    order_id,
                    subscription_payment_id,
                )
                job = self._upsert_job(
                    cursor,
                    user_id,
                    order_id,
                    subscription_id,
                    plan,
                    node_hint,
                )
                self._touch_user_last_active(cursor, user_id)
                return PaymentCaptureRecord(
                    paypal_event_id=event_id,
                    resource_id=payment_id,
                    dedupe_key=dedupe_key,
                    job=job,
                )

    def register_payment_capture(self, payload: Mapping[str, Any]) -> ProvisionJobRecord | None:
        capture = self.create_payment_capture(payload)
        return capture.job if capture is not None else None

    def rollback_payment_capture(self, capture: PaymentCaptureRecord) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM provision_jobs WHERE order_id = %s", (capture.job.order_id,))
                cursor.execute("DELETE FROM subscriptions WHERE order_id = %s", (capture.job.order_id,))
                cursor.execute("DELETE FROM orders WHERE id = %s", (capture.job.order_id,))
                cursor.execute("DELETE FROM billing_events WHERE paypal_event_id = %s", (capture.dedupe_key,))
                cursor.execute(
                    """
                    DELETE FROM processed_webhooks
                    WHERE dedupe_key = %s OR paypal_event_id = %s OR resource_id = %s
                    """,
                    (capture.dedupe_key, capture.paypal_event_id, capture.resource_id),
                )

    def record_processed_webhook(self, paypal_event_id: str | None, resource_id: str | None, payload: Mapping[str, Any]) -> bool:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                return self._record_processed_webhook(cursor, paypal_event_id, resource_id, payload)

    def is_processed_webhook(self, dedupe_key: str) -> bool:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT 1 FROM processed_webhooks WHERE dedupe_key = %s LIMIT 1",
                    (dedupe_key,),
                )
                return cursor.fetchone() is not None

    def get_user(self, user_id: int) -> UserRecord:
        row = self._fetch_one(
            """
            SELECT id, identity_key, email, plan, status, last_active, created_at, updated_at
            FROM users
            WHERE id = %s
            """,
            (user_id,),
        )
        if row is None:
            raise LookupError(f"user {user_id} not found")
        return _row_to_user(row)

    def get_dashboard(self) -> dict[str, Any]:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                counts = {}
                for label, sql in (
                    ("active_users", "SELECT COUNT(*) FROM users WHERE status = 'ACTIVE'"),
                    ("total_payments", "SELECT COUNT(*) FROM orders WHERE status = 'PAID'"),
                    ("active_subscriptions", "SELECT COUNT(*) FROM subscriptions WHERE status = 'ACTIVE'"),
                    ("queued_jobs", "SELECT COUNT(*) FROM provision_jobs WHERE status = 'QUEUED'"),
                    ("running_jobs", "SELECT COUNT(*) FROM provision_jobs WHERE status = 'RUNNING'"),
                    ("failed_jobs", "SELECT COUNT(*) FROM provision_jobs WHERE status = 'FAILED'"),
                    ("dead_jobs", "SELECT COUNT(*) FROM provision_jobs WHERE status = 'DEAD'"),
                    ("active_nodes", "SELECT COUNT(*) FROM vps_nodes WHERE status = 'ACTIVE'"),
                ):
                    cursor.execute(sql)
                    counts[label] = int(cursor.fetchone()["count"] or 0)

                cursor.execute("SELECT COUNT(*) FROM provision_jobs WHERE status = 'SUCCESS'")
                successful_jobs = int(cursor.fetchone()["count"] or 0)
                total_jobs = successful_jobs + counts["failed_jobs"] + counts["dead_jobs"] + counts["running_jobs"] + counts["queued_jobs"]
                success_rate = successful_jobs / total_jobs if total_jobs else 0.0
                counts["provisioning_success_rate"] = success_rate
                counts["node_utilization"] = self.get_node_utilization()
                return counts

    def get_node_utilization(self) -> list[dict[str, Any]]:
        rows = self._fetch_all(
            """
            SELECT node_id, host, region, load, capacity, status, created_at, updated_at
            FROM vps_nodes
            ORDER BY node_id ASC
            """
        )
        result = []
        for row in rows:
            capacity = max(1, int(row["capacity"]))
            load = int(row["load"])
            result.append(
                {
                    "node_id": int(row["node_id"]),
                    "host": row["host"],
                    "region": row["region"],
                    "load": load,
                    "capacity": capacity,
                    "utilization": round(load / capacity, 4),
                    "status": row["status"],
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
            )
        return result

    def list_vps_nodes(self) -> list[VpsNodeRecord]:
        return [_row_to_node(row) for row in self._fetch_all(
            """
            SELECT node_id, host, user_name, capacity, load, status, region, created_at, updated_at
            FROM vps_nodes
            ORDER BY node_id ASC
            """
        )]

    def add_vps_node(
        self,
        host: str,
        user_name: str,
        capacity: int = 1,
        status: str = "ACTIVE",
        region: str = "default",
    ) -> int:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO vps_nodes (host, user_name, capacity, load, status, region, created_at, updated_at)
                    VALUES (%s, %s, %s, 0, %s, %s, %s, %s)
                    ON CONFLICT (host) DO UPDATE SET
                        user_name = EXCLUDED.user_name,
                        capacity = EXCLUDED.capacity,
                        status = EXCLUDED.status,
                        region = EXCLUDED.region,
                        updated_at = EXCLUDED.updated_at
                    RETURNING node_id
                    """,
                    (host, user_name, capacity, status, region, _now_utc(), _now_utc()),
                )
                return int(cursor.fetchone()["node_id"])

    def select_least_loaded_active_node(self, node_hint: str | None = None) -> VpsNodeRecord | None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                if node_hint:
                    cursor.execute(
                        """
                        SELECT node_id, host, user_name, capacity, load, status, region, created_at, updated_at
                        FROM vps_nodes
                        WHERE status = 'ACTIVE'
                          AND load < capacity
                          AND (region = %s OR host = %s)
                        ORDER BY load ASC, node_id ASC
                        LIMIT 1
                        FOR UPDATE SKIP LOCKED
                        """,
                        (node_hint, node_hint),
                    )
                    row = cursor.fetchone()

                    if row is None:
                        cursor.execute(
                            """
                            SELECT node_id, host, user_name, capacity, load, status, region, created_at, updated_at
                            FROM vps_nodes
                            WHERE status = 'ACTIVE'
                              AND load < capacity
                            ORDER BY load ASC, node_id ASC
                            LIMIT 1
                            FOR UPDATE SKIP LOCKED
                            """
                        )
                        row = cursor.fetchone()
                else:
                    cursor.execute(
                        """
                        SELECT node_id, host, user_name, capacity, load, status, region, created_at, updated_at
                        FROM vps_nodes
                        WHERE status = 'ACTIVE'
                          AND load < capacity
                        ORDER BY load ASC, node_id ASC
                        LIMIT 1
                        FOR UPDATE SKIP LOCKED
                        """
                    )
                    row = cursor.fetchone()

                if row is None:
                    return None

                node = _row_to_node(_row_to_dict(row))
                cursor.execute(
                    """
                    UPDATE vps_nodes
                    SET load = load + 1, updated_at = %s
                    WHERE node_id = %s
                    """,
                    (_now_utc(), node.node_id),
                )
                node.load += 1
                return node

    def reserve_node(self, node_id: int) -> VpsNodeRecord:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE vps_nodes
                    SET load = load + 1, updated_at = %s
                    WHERE node_id = %s
                    RETURNING node_id, host, user_name, capacity, load, status, region, created_at, updated_at
                    """,
                    (_now_utc(), node_id),
                )
                row = cursor.fetchone()
                if row is None:
                    raise LookupError(f"node {node_id} not found")
                return _row_to_node(_row_to_dict(row))

    def get_node(self, node_id: int) -> VpsNodeRecord:
        row = self._fetch_one(
            """
            SELECT node_id, host, user_name, capacity, load, status, region, created_at, updated_at
            FROM vps_nodes
            WHERE node_id = %s
            """,
            (node_id,),
        )
        if row is None:
            raise LookupError(f"node {node_id} not found")
        return _row_to_node(row)

    def reassign_job_node(self, job_id: int, node_id: int) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE provision_jobs
                    SET node_id = %s, updated_at = %s
                    WHERE job_id = %s
                    """,
                    (node_id, _now_utc(), job_id),
                )

    def release_node(self, node_id: int) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE vps_nodes
                    SET load = GREATEST(load - 1, 0), updated_at = %s
                    WHERE node_id = %s
                    """,
                    (_now_utc(), node_id),
                )

    def mark_node_failed(self, node_id: int) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE vps_nodes
                    SET status = 'FAILED', updated_at = %s
                    WHERE node_id = %s
                    """,
                    (_now_utc(), node_id),
                )

    def start_job(self, job_id: int, node_id: int, worker_id: str) -> ProvisionJobRecord | None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE provision_jobs
                    SET status = 'RUNNING',
                        node_id = %s,
                        worker_id = %s,
                        attempts = attempts + 1,
                        locked_at = %s,
                        last_attempt_time = %s,
                        updated_at = %s,
                        last_error = NULL
                    WHERE job_id = %s
                      AND status IN ('QUEUED', 'FAILED')
                      AND attempts < 3
                    RETURNING job_id, user_id, order_id, subscription_id, plan, node_id, node_hint,
                              status, attempts, last_error, last_attempt_time, locked_at, worker_id,
                              provisioned_at, published_at, created_at, updated_at
                    """,
                    (node_id, worker_id, _now_utc(), _now_utc(), _now_utc(), job_id),
                )
                row = cursor.fetchone()
                if row is None:
                    return None
                return _row_to_job(_row_to_dict(row))

    def mark_job_published(self, job_id: int) -> bool:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE provision_jobs
                    SET published_at = %s,
                        updated_at = %s
                    WHERE job_id = %s
                      AND published_at IS NULL
                    RETURNING job_id
                    """,
                    (_now_utc(), _now_utc(), job_id),
                )
                return cursor.fetchone() is not None

    def complete_job(self, job_id: int, config_text: str) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE provision_jobs
                    SET status = 'SUCCESS',
                        config_text = %s,
                        provisioned_at = %s,
                        locked_at = NULL,
                        last_error = NULL,
                        updated_at = %s
                    WHERE job_id = %s
                    """,
                    (config_text, _now_utc(), _now_utc(), job_id),
                )

    def fail_job(self, job_id: int, error_message: str) -> ProvisionJobRecord:
        row = self.get_job(job_id)
        status = "DEAD" if row.attempts >= 3 else "FAILED"
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE provision_jobs
                    SET status = %s,
                        last_error = %s,
                        locked_at = NULL,
                        updated_at = %s
                    WHERE job_id = %s
                    """,
                    (status, error_message[:4000], _now_utc(), job_id),
                )
        return self.get_job(job_id)

    def mark_job_dead(self, job_id: int, error_message: str) -> ProvisionJobRecord:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE provision_jobs
                    SET status = 'DEAD',
                        last_error = %s,
                        locked_at = NULL,
                        updated_at = %s
                    WHERE job_id = %s
                    """,
                    (error_message[:4000], _now_utc(), job_id),
                )
        return self.get_job(job_id)

    def recover_stuck_jobs(self, stale_minutes: int = 10) -> int:
        cutoff = _now_utc(offset_minutes=-stale_minutes)
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE provision_jobs
                    SET status = 'QUEUED', locked_at = NULL, worker_id = NULL, updated_at = %s
                    WHERE status = 'RUNNING'
                      AND locked_at IS NOT NULL
                      AND locked_at < %s
                    RETURNING node_id
                    """,
                    (_now_utc(), cutoff),
                )
                recovered_rows = cursor.fetchall()
                node_ids = {int(row["node_id"]) for row in recovered_rows if row["node_id"] is not None}
                for node_id in node_ids:
                    cursor.execute(
                        """
                        UPDATE vps_nodes
                        SET load = GREATEST(load - 1, 0), updated_at = %s
                        WHERE node_id = %s
                        """,
                        (_now_utc(), node_id),
                    )
                return len(recovered_rows)

    def get_job(self, job_id: int) -> ProvisionJobRecord:
        row = self._fetch_one(
            """
            SELECT job_id, user_id, order_id, subscription_id, plan, node_id, node_hint, status, attempts,
                   last_error, last_attempt_time, locked_at, worker_id, provisioned_at, published_at, created_at, updated_at
            FROM provision_jobs
            WHERE job_id = %s
            """,
            (job_id,),
        )
        if row is None:
            raise LookupError(f"job {job_id} not found")
        return _row_to_job(row)

    def list_jobs(self) -> list[ProvisionJobRecord]:
        return [_row_to_job(row) for row in self._fetch_all(
            """
            SELECT job_id, user_id, order_id, subscription_id, plan, node_id, node_hint, status, attempts,
                   last_error, last_attempt_time, locked_at, worker_id, provisioned_at, published_at, created_at, updated_at
            FROM provision_jobs
            ORDER BY job_id ASC
            """
        )]

    def list_unpublished_jobs(self) -> list[ProvisionJobRecord]:
        return [_row_to_job(row) for row in self._fetch_all(
            """
            SELECT job_id, user_id, order_id, subscription_id, plan, node_id, node_hint, status, attempts,
                   last_error, last_attempt_time, locked_at, worker_id, provisioned_at, published_at, created_at, updated_at
            FROM provision_jobs
            WHERE status = 'QUEUED' AND published_at IS NULL
            ORDER BY job_id ASC
            """
        )]

    def get_subscription(self, subscription_id: int) -> SubscriptionRecord:
        row = self._fetch_one(
            """
            SELECT id, user_id, order_id, paypal_subscription_id, status, activated_at, expires_at, config_text, created_at, updated_at
            FROM subscriptions
            WHERE id = %s
            """,
            (subscription_id,),
        )
        if row is None:
            raise LookupError(f"subscription {subscription_id} not found")
        return _row_to_subscription(row)

    def store_subscription_config(self, subscription_id: int, config_text: str, status: str = "ACTIVE") -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE subscriptions
                    SET config_text = %s,
                        status = %s,
                        activated_at = COALESCE(activated_at, %s),
                        updated_at = %s
                    WHERE id = %s
                    """,
                    (config_text, status, _now_utc(), _now_utc(), subscription_id),
                )

    def get_region_success_rates(self) -> list[dict[str, Any]]:
        rows = self._fetch_all(
            """
            SELECT n.region AS region,
                   COUNT(*) FILTER (WHERE j.status = 'SUCCESS') AS success_count,
                   COUNT(*) FILTER (WHERE j.status IN ('SUCCESS', 'FAILED', 'DEAD')) AS total_count
            FROM vps_nodes AS n
            LEFT JOIN provision_jobs AS j ON j.node_id = n.node_id
            GROUP BY n.region
            ORDER BY n.region ASC
            """
        )
        result = []
        for row in rows:
            total = int(row["total_count"] or 0)
            success = int(row["success_count"] or 0)
            result.append(
                {
                    "region": row["region"],
                    "success_rate": success / total if total else 0.0,
                    "success_count": success,
                    "total_count": total,
                }
            )
        return result

    def _fetch_one(self, sql: str, params: tuple[Any, ...] = ()) -> dict[str, Any] | None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(sql, params)
                row = cursor.fetchone()
                return _row_to_dict(row) if row is not None else None

    def _fetch_all(self, sql: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(sql, params)
                return [_row_to_dict(row) for row in cursor.fetchall()]

    def _record_processed_webhook(
        self,
        cursor,
        paypal_event_id: str | None,
        resource_id: str | None,
        payload: Mapping[str, Any],
    ) -> bool:
        dedupe_key = resource_id or paypal_event_id
        if not dedupe_key:
            raise ValueError("a dedupe key is required")

        cursor.execute(
            """
            INSERT INTO processed_webhooks (paypal_event_id, resource_id, dedupe_key, payload_json, created_at)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (dedupe_key) DO NOTHING
            RETURNING dedupe_key
            """,
            (
                paypal_event_id,
                resource_id,
                dedupe_key,
                json.dumps(payload, sort_keys=True),
                _now_utc(),
            ),
        )
        return cursor.fetchone() is not None

    def _upsert_billing_event(self, cursor, paypal_event_id: str, payload: Mapping[str, Any]) -> int:
        cursor.execute(
            """
            INSERT INTO billing_events (paypal_event_id, event_type, payload_json, created_at)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (paypal_event_id) DO UPDATE SET
                event_type = EXCLUDED.event_type,
                payload_json = EXCLUDED.payload_json
            RETURNING id
            """,
            (
                paypal_event_id,
                str(payload.get("event_type") or payload.get("eventType") or "PAYMENT.CAPTURE.COMPLETED"),
                json.dumps(payload, sort_keys=True),
                _now_utc(),
            ),
        )
        return int(cursor.fetchone()["id"])

    def _upsert_user(self, cursor, identity_key: str, email: str | None, plan: str) -> int:
        timestamp = _now_utc()
        cursor.execute(
            """
            INSERT INTO users (identity_key, email, plan, status, last_active, created_at, updated_at)
            VALUES (%s, %s, %s, 'ACTIVE', %s, %s, %s)
            ON CONFLICT (identity_key) DO UPDATE SET
                email = COALESCE(EXCLUDED.email, users.email),
                plan = EXCLUDED.plan,
                status = EXCLUDED.status,
                last_active = EXCLUDED.last_active,
                updated_at = EXCLUDED.updated_at
            RETURNING id
            """,
            (identity_key, email, plan, timestamp, timestamp, timestamp),
        )
        return int(cursor.fetchone()["id"])

    def _upsert_order(self, cursor, user_id: int, payment_id: str, plan: str, amount: float) -> int:
        timestamp = _now_utc()
        cursor.execute(
            """
            INSERT INTO orders (user_id, paypal_payment_id, status, plan, amount, created_at, updated_at)
            VALUES (%s, %s, 'PAID', %s, %s, %s, %s)
            ON CONFLICT (paypal_payment_id) DO UPDATE SET
                user_id = EXCLUDED.user_id,
                status = EXCLUDED.status,
                plan = EXCLUDED.plan,
                amount = EXCLUDED.amount,
                updated_at = EXCLUDED.updated_at
            RETURNING id
            """,
            (user_id, payment_id, plan, amount, timestamp, timestamp),
        )
        return int(cursor.fetchone()["id"])

    def _upsert_subscription(self, cursor, user_id: int, order_id: int, paypal_subscription_id: str) -> int:
        timestamp = _now_utc()
        cursor.execute(
            """
            INSERT INTO subscriptions (
                user_id, order_id, paypal_subscription_id, status, activated_at, expires_at, config_text, created_at, updated_at
            )
            VALUES (%s, %s, %s, 'ACTIVE', %s, NULL, NULL, %s, %s)
            ON CONFLICT (paypal_subscription_id) DO UPDATE SET
                user_id = EXCLUDED.user_id,
                order_id = EXCLUDED.order_id,
                status = EXCLUDED.status,
                activated_at = COALESCE(subscriptions.activated_at, EXCLUDED.activated_at),
                updated_at = EXCLUDED.updated_at
            RETURNING id
            """,
            (user_id, order_id, paypal_subscription_id, timestamp, timestamp, timestamp),
        )
        return int(cursor.fetchone()["id"])

    def _upsert_job(
        self,
        cursor,
        user_id: int,
        order_id: int,
        subscription_id: int,
        plan: str,
        node_hint: str | None,
    ) -> ProvisionJobRecord:
        timestamp = _now_utc()
        cursor.execute(
            """
            INSERT INTO provision_jobs (
                user_id, order_id, subscription_id, plan, node_hint, status, attempts,
                last_error, last_attempt_time, locked_at, worker_id, provisioned_at, published_at, created_at, updated_at
            )
            VALUES (%s, %s, %s, %s, %s, 'QUEUED', 0, NULL, NULL, NULL, NULL, NULL, NULL, %s, %s)
            ON CONFLICT (order_id) DO UPDATE SET
                subscription_id = EXCLUDED.subscription_id,
                plan = EXCLUDED.plan,
                node_hint = COALESCE(EXCLUDED.node_hint, provision_jobs.node_hint),
                status = CASE
                    WHEN provision_jobs.status = 'SUCCESS' THEN provision_jobs.status
                    ELSE EXCLUDED.status
                END,
                updated_at = EXCLUDED.updated_at
            RETURNING job_id, user_id, order_id, subscription_id, plan, node_id, node_hint, status, attempts,
                      last_error, last_attempt_time, locked_at, worker_id, provisioned_at, published_at, created_at, updated_at
            """,
            (user_id, order_id, subscription_id, plan, node_hint, timestamp, timestamp),
        )
        return _row_to_job(cursor.fetchone())

    def _touch_user_last_active(self, cursor, user_id: int) -> None:
        timestamp = _now_utc()
        cursor.execute(
            "UPDATE users SET last_active = %s, updated_at = %s WHERE id = %s",
            (timestamp, timestamp, user_id),
        )


class RedisStreamBroker:
    def __init__(
        self,
        redis_url: str | None = None,
        stream_name: str | None = None,
        dead_stream_name: str | None = None,
        consumer_group: str | None = None,
    ) -> None:
        self.redis_url = redis_url or os.getenv("REDIS_URL")
        self.stream_name = stream_name or os.getenv("REDIS_STREAM_JOBS", DEFAULT_JOB_STREAM)
        self.dead_stream_name = dead_stream_name or os.getenv("REDIS_STREAM_DEAD", DEFAULT_DEAD_STREAM)
        self.consumer_group = consumer_group or os.getenv("REDIS_CONSUMER_GROUP", DEFAULT_CONSUMER_GROUP)
        if not self.redis_url:
            raise ValueError("REDIS_URL is required")
        if redis_lib is None:
            raise RuntimeError("redis is not installed")
        self._client = redis_lib.Redis.from_url(self.redis_url, decode_responses=True)
        self.ensure_consumer_group()

    @classmethod
    def from_env(cls) -> "RedisStreamBroker":
        return cls(
            redis_url=os.getenv("REDIS_URL"),
            stream_name=os.getenv("REDIS_STREAM_JOBS"),
            dead_stream_name=os.getenv("REDIS_STREAM_DEAD"),
            consumer_group=os.getenv("REDIS_CONSUMER_GROUP"),
        )

    def ensure_consumer_group(self) -> None:
        try:
            self._client.xgroup_create(self.stream_name, self.consumer_group, id="0-0", mkstream=True)
        except Exception as exc:  # pragma: no cover - depends on broker state
            if "BUSYGROUP" not in str(exc):
                raise

    def publish_job(self, job: ProvisionJobRecord | Mapping[str, Any]) -> str:
        payload = _job_payload(job)
        return self._client.xadd(self.stream_name, payload)

    def read_next_job(self, *, consumer: str, block_ms: int = 1000) -> tuple[str, dict[str, str]] | None:
        response = self._client.xreadgroup(
            groupname=self.consumer_group,
            consumername=consumer,
            streams={self.stream_name: ">"},
            count=1,
            block=block_ms,
        )
        if not response:
            return None

        _, entries = response[0]
        message_id, payload = entries[0]
        return message_id, dict(payload)

    def claim_pending_job(self, *, consumer: str, min_idle_ms: int = 30_000) -> tuple[str, dict[str, str]] | None:
        try:
            _, messages, _ = self._client.xautoclaim(
                name=self.stream_name,
                groupname=self.consumer_group,
                consumername=consumer,
                min_idle_time=min_idle_ms,
                start_id="0-0",
                count=1,
            )
        except Exception:  # pragma: no cover - depends on redis version
            return None

        if not messages:
            return None

        message_id, payload = messages[0]
        return message_id, dict(payload)

    def ack(self, message_id: str) -> None:
        self._client.xack(self.stream_name, self.consumer_group, message_id)

    def publish_dead_letter(self, payload: Mapping[str, Any]) -> str:
        return self._client.xadd(self.dead_stream_name, {key: str(value) for key, value in payload.items()})

    def queue_depth(self) -> int:
        return int(self._client.xlen(self.stream_name))


class CloudControlPlane:
    def __init__(self, repository: PostgresRepository, broker: RedisStreamBroker, webhook_secret: str) -> None:
        self.repository = repository
        self.broker = broker
        self.webhook_secret = webhook_secret

    @classmethod
    def from_env(cls) -> "CloudControlPlane":
        settings = DeploymentSettings.from_env()
        if not settings.paypal_webhook_secret:
            raise ValueError("PAYPAL_WEBHOOK_SECRET is required")
        repository = PostgresRepository(settings.database_url)
        broker = RedisStreamBroker(
            redis_url=settings.redis_url,
            stream_name=settings.redis_stream_jobs,
            dead_stream_name=settings.redis_stream_dead,
            consumer_group=settings.redis_consumer_group,
        )
        return cls(repository, broker, settings.paypal_webhook_secret)

    def validate_signature(self, body: bytes, headers: Mapping[str, str]) -> bool:
        provided_signature = headers.get("PayPal-Transmission-Sig") or headers.get("X-PayPal-Signature")
        if not provided_signature:
            return False

        expected = hmac.new(self.webhook_secret.encode(), body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, provided_signature)

    def handle_paypal_webhook(
        self,
        body: bytes,
        headers: Mapping[str, str],
        source_ip: str | None = None,
    ) -> bool:
        if not self.validate_signature(body, headers):
            raise ValueError("invalid signature")

        try:
            payload = json.loads(body.decode() or "{}")
        except json.JSONDecodeError as exc:
            raise ValueError("invalid json") from exc
        if not isinstance(payload, Mapping):
            raise ValueError("invalid json")

        if payload.get("event_type") not in {"PAYMENT.CAPTURE.COMPLETED"}:
            return False

        resource = _mapping(payload.get("resource"))
        paypal_event_id = _pick_first(payload.get("id"), headers.get("PayPal-Event-Id"), headers.get("paypal-event-id"))
        resource_id = _pick_first(resource.get("id"))
        dedupe_key = resource_id or paypal_event_id
        if not dedupe_key:
            raise ValueError("webhook payload missing dedupe key")

        if self.repository.is_processed_webhook(dedupe_key):
            logger.info("Ignoring duplicate PayPal event %s from %s", dedupe_key, source_ip or "unknown")
            return False

        capture = self.repository.create_payment_capture(payload)
        if capture is None:
            logger.info("Ignoring duplicate PayPal event %s from %s", dedupe_key, source_ip or "unknown")
            return False

        try:
            message_id = self.broker.publish_job(capture.job)
        except Exception:
            logger.exception("Failed to publish provisioning job %s for PayPal event %s", capture.job.job_id, dedupe_key)
            self.repository.rollback_payment_capture(capture)
            raise

        if not self.repository.mark_job_published(capture.job.job_id):
            logger.warning("Provisioning job %s was already marked published", capture.job.job_id)

        logger.info("Order created order_id=%s payment_id=%s", capture.job.order_id, dedupe_key)
        logger.info("Job queued job_id=%s order_id=%s message_id=%s", capture.job.job_id, capture.job.order_id, message_id)
        return True

    def get_user(self, user_id: int) -> UserRecord:
        return self.repository.get_user(user_id)

    def get_dashboard(self) -> dict[str, Any]:
        dashboard = self.repository.get_dashboard()
        dashboard["redis_queue_depth"] = self.broker.queue_depth()
        dashboard["success_rate_per_region"] = self.repository.get_region_success_rates()
        return dashboard


def _job_payload(job: ProvisionJobRecord | Mapping[str, Any]) -> dict[str, str]:
    if isinstance(job, Mapping):
        return {key: str(value) for key, value in job.items()}

    return {
        "job_id": str(job.job_id),
        "order_id": str(job.order_id),
        "user_id": str(job.user_id),
        "plan": job.plan,
        "node_hint": job.node_hint or "",
        "created_at": job.created_at,
    }


def _mapping(value: Any) -> Mapping[str, Any]:
    return value if isinstance(value, Mapping) else {}


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


def _pick_first(*values: Any) -> str | None:
    for value in values:
        if value is None:
            continue
        text = str(value).strip()
        if text:
            return text
    return None


def _row_to_dict(row: Any) -> dict[str, Any]:
    if row is None:
        return {}
    if isinstance(row, dict):
        return dict(row)
    if hasattr(row, "keys"):
        return {key: row[key] for key in row.keys()}
    raise TypeError(f"unsupported row type: {type(row)!r}")


def _row_to_user(row: Mapping[str, Any]) -> UserRecord:
    return UserRecord(
        id=int(row["id"]),
        identity_key=str(row["identity_key"]),
        email=row.get("email"),
        plan=str(row["plan"]),
        status=str(row["status"]),
        last_active=row.get("last_active"),
        created_at=str(row["created_at"]),
        updated_at=str(row["updated_at"]),
    )


def _row_to_node(row: Mapping[str, Any]) -> VpsNodeRecord:
    return VpsNodeRecord(
        node_id=int(row["node_id"]),
        host=str(row["host"]),
        user=str(row.get("user_name") or row.get("user") or ""),
        capacity=int(row["capacity"]),
        load=int(row["load"]),
        status=str(row["status"]),
        region=str(row.get("region") or "default"),
        created_at=str(row["created_at"]),
        updated_at=str(row["updated_at"]),
    )


def _row_to_subscription(row: Mapping[str, Any]) -> SubscriptionRecord:
    return SubscriptionRecord(
        id=int(row["id"]),
        user_id=int(row["user_id"]),
        order_id=int(row["order_id"]),
        paypal_subscription_id=str(row["paypal_subscription_id"]),
        status=str(row["status"]),
        activated_at=row.get("activated_at"),
        expires_at=row.get("expires_at"),
        config_text=row.get("config_text"),
        created_at=str(row["created_at"]),
        updated_at=str(row["updated_at"]),
    )


def _row_to_job(row: Mapping[str, Any]) -> ProvisionJobRecord:
    return ProvisionJobRecord(
        job_id=int(row["job_id"]),
        user_id=int(row["user_id"]),
        order_id=int(row["order_id"]),
        subscription_id=int(row["subscription_id"]),
        plan=str(row["plan"]),
        node_id=row.get("node_id"),
        node_hint=row.get("node_hint"),
        status=str(row["status"]),
        attempts=int(row["attempts"]),
        last_error=row.get("last_error"),
        last_attempt_time=row.get("last_attempt_time"),
        locked_at=row.get("locked_at"),
        worker_id=row.get("worker_id"),
        provisioned_at=row.get("provisioned_at"),
        published_at=row.get("published_at"),
        created_at=str(row["created_at"]),
        updated_at=str(row["updated_at"]),
    )


def _now_utc(offset_minutes: int = 0) -> str:
    return (datetime.now(timezone.utc).replace(microsecond=0) + timedelta(minutes=offset_minutes)).isoformat().replace("+00:00", "Z")
