"""Distributed provisioning worker for VPSKit v2."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
import logging
import os
import shlex
import socket
import subprocess
import time

from vpskit.config import DeploymentSettings
from vpskit.platform import PostgresRepository, RedisStreamBroker, ProvisionJobRecord, VpsNodeRecord
from vpskit.subscription.models import SubscriptionNode, SubscriptionProfile
from vpskit.subscription.renderer import render_subscription


logger = logging.getLogger(__name__)
metrics_logger = logging.getLogger("vpskit.metrics")
POLL_INTERVAL_SECONDS = 3


@dataclass(frozen=True)
class ProvisioningResult:
    config_text: str


class ProvisioningExecutor:
    def __init__(self, settings: DeploymentSettings, repository: PostgresRepository) -> None:
        self.settings = settings
        self.repository = repository

    def execute(self, job: ProvisionJobRecord, node: VpsNodeRecord) -> ProvisioningResult:
        subscription = self.repository.get_subscription(job.subscription_id)
        self._run_install_script(node)
        self._verify_remote_state(node)
        config_text = self._generate_subscription_config(subscription.paypal_subscription_id, node)
        self.repository.store_subscription_config(subscription.id, config_text, status="ACTIVE")
        return ProvisioningResult(config_text=config_text)

    def _run_install_script(self, node: VpsNodeRecord) -> None:
        remote_command = os.getenv("VPSKIT_REMOTE_INSTALL_COMMAND", "bash install.sh")
        self._run_ssh_command(node, remote_command)

    def _verify_remote_state(self, node: VpsNodeRecord) -> None:
        checks = [
            "systemctl is-active --quiet xray",
            "systemctl is-active --quiet hysteria2",
            "ss -ltn | grep -q ':443 '",
        ]
        for command in checks:
            self._run_ssh_command(node, command)

    def _generate_subscription_config(self, subscription_name: str, node: VpsNodeRecord) -> str:
        profile = SubscriptionProfile(
            name=subscription_name,
            nodes=[
                SubscriptionNode(
                    name="primary",
                    host=node.host,
                    port=443,
                    protocol="vless",
                )
            ],
        )
        return render_subscription(profile)

    def _run_ssh_command(self, node: VpsNodeRecord, remote_command: str) -> None:
        ssh_key = self.settings.vps_ssh_private_key
        if not ssh_key:
            raise RuntimeError("VPS_SSH_PRIVATE_KEY is required")

        command = [
            "ssh",
            "-i",
            ssh_key,
            "-o",
            "BatchMode=yes",
            "-o",
            "StrictHostKeyChecking=accept-new",
            f"{node.user}@{node.host}",
            remote_command,
        ]
        self._run_command(command)

    def _run_command(self, command: list[str]) -> None:
        logger.info("Running command: %s", shlex.join(command))
        completed = subprocess.run(command, check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise RuntimeError(
                f"command failed with exit code {completed.returncode}: "
                f"{completed.stderr.strip() or completed.stdout.strip()}"
            )


class DistributedProvisioningWorker:
    def __init__(
        self,
        repository: PostgresRepository | None = None,
        broker: RedisStreamBroker | None = None,
        executor: ProvisioningExecutor | None = None,
        settings: DeploymentSettings | None = None,
        worker_id: str | None = None,
    ) -> None:
        self.settings = settings or DeploymentSettings.from_env()
        self.region_name = self.settings.region_name or os.getenv("VPSKIT_REGION") or "us-east"
        self.repository = repository or PostgresRepository.from_env()
        self.broker = broker or RedisStreamBroker.from_env()
        self.worker_id = worker_id or self.settings.worker_id or socket.gethostname()
        self.executor = executor or ProvisioningExecutor(self.settings, self.repository)
        self.processed_jobs = 0
        self.successful_jobs = 0
        self._region_stats: dict[str, dict[str, int]] = defaultdict(lambda: {"success": 0, "total": 0})

    def recover_stuck_jobs(self) -> int:
        recovered = self.repository.recover_stuck_jobs()
        if recovered:
            logger.warning("Recovered %s stuck provisioning jobs", recovered)
        return recovered

    def recover_unpublished_jobs(self) -> int:
        recovered = 0
        for job in self.repository.list_unpublished_jobs():
            try:
                message_id = self.broker.publish_job(job)
            except Exception:  # noqa: BLE001
                logger.exception("Failed to republish queued job %s", job.job_id)
                continue

            if self.repository.mark_job_published(job.job_id):
                recovered += 1
                logger.info("Republished queued job %s as %s", job.job_id, message_id)
            else:
                logger.warning("Queued job %s was already marked published", job.job_id)

        return recovered

    def process_next_message(self) -> bool:
        message = self.broker.claim_pending_job(consumer=self.worker_id)
        if message is None:
            message = self.broker.read_next_job(consumer=self.worker_id, block_ms=1000)
        if message is None:
            return False

        message_id, payload = message
        job_id = int(payload["job_id"])
        try:
            job = self.repository.get_job(job_id)
        except LookupError:
            self.broker.ack(message_id)
            return True

        if job.status in {"SUCCESS", "DEAD"}:
            self.broker.ack(message_id)
            return True

        node_hint = job.node_hint or payload.get("node_hint") or None
        selected_node = self.repository.select_least_loaded_active_node(node_hint=node_hint)
        if selected_node is None:
            logger.warning("No active VPS node available for job %s", job.job_id)
            return False

        started_at = _parse_utc_timestamp(job.last_attempt_time) or _parse_utc_timestamp(job.created_at)
        started_job = self.repository.start_job(job.job_id, selected_node.node_id, self.worker_id)
        if started_job is None:
            self.repository.release_node(selected_node.node_id)
            self.broker.ack(message_id)
            return True

        succeeded = False
        error_message = ""
        try:
            logger.info("Processing provisioning job %s on node %s", job.job_id, selected_node.node_id)
            result = self.executor.execute(started_job, selected_node)
            self.repository.complete_job(job.job_id, result.config_text)
            self.repository.release_node(selected_node.node_id)
            self.broker.ack(message_id)
            self.successful_jobs += 1
            succeeded = True
            logger.info("Provisioning job %s completed", job.job_id)
        except Exception as exc:  # noqa: BLE001
            error_message = str(exc)
            logger.exception("Provisioning job %s failed on node %s", job.job_id, selected_node.node_id)
            self.repository.mark_node_failed(selected_node.node_id)
            self.repository.release_node(selected_node.node_id)
            job_state = self.repository.fail_job(job.job_id, error_message)
            if job_state.status == "DEAD":
                self.broker.publish_dead_letter(
                    {
                        "job_id": str(job.job_id),
                        "order_id": str(job.order_id),
                        "user_id": str(job.user_id),
                        "error": error_message,
                        "attempts": str(job_state.attempts),
                    }
                )
                self.broker.ack(message_id)

        self.processed_jobs += 1
        self._record_metrics(job, started_at, succeeded)
        return True

    def _record_metrics(self, job: ProvisionJobRecord, started_at: datetime | None, succeeded: bool) -> None:
        finished_at = datetime.now(timezone.utc)
        latency_seconds = max(0.0, (finished_at - started_at).total_seconds()) if started_at else 0.0
        success_rate = self.successful_jobs / self.processed_jobs if self.processed_jobs else 0.0
        region = self._job_region(job)
        region_stats = self._region_stats[region]
        region_stats["total"] += 1
        if succeeded:
            region_stats["success"] += 1

        metrics_logger.info("metric name=redis_queue_depth value=%s", self.broker.queue_depth())
        metrics_logger.info("metric name=worker_throughput value=%s worker_id=%s", self.processed_jobs, self.worker_id)
        metrics_logger.info("metric name=provisioning_latency_seconds value=%.3f job_id=%s", latency_seconds, job.job_id)
        metrics_logger.info("metric name=success_rate value=%.3f job_id=%s", success_rate, job.job_id)
        metrics_logger.info(
            "metric name=success_rate_per_region region=%s value=%.3f",
            region,
            region_stats["success"] / region_stats["total"] if region_stats["total"] else 0.0,
        )
        metrics_logger.info("metric name=node_utilization value=%s", self._node_utilization_summary())

    def _job_region(self, job: ProvisionJobRecord) -> str:
        if job.node_id is None:
            return "unknown"

        try:
            node = self.repository.get_node(job.node_id)
        except Exception:  # noqa: BLE001 - best effort metrics lookup
            return "unknown"
        return node.region

    def _emit_heartbeat(self) -> None:
        metrics_logger.info("metric name=worker_heartbeat region=%s worker_id=%s", self.region_name, self.worker_id)

    def _node_utilization_summary(self) -> list[dict[str, object]]:
        return self.repository.get_node_utilization()

    def run_forever(self) -> None:
        self.recover_unpublished_jobs()
        self.recover_stuck_jobs()
        logger.info("Provisioning worker started as %s in region %s", self.worker_id, self.region_name)
        while True:
            self._emit_heartbeat()
            processed = self.process_next_message()
            if not processed:
                time.sleep(POLL_INTERVAL_SECONDS)


def configure_logging() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


def main() -> None:
    configure_logging()
    worker = DistributedProvisioningWorker()
    try:
        worker.run_forever()
    except KeyboardInterrupt:
        logger.info("Provisioning worker stopped")


if __name__ == "__main__":
    main()


def _parse_utc_timestamp(raw_value: str | None) -> datetime | None:
    if raw_value in {None, ""}:
        return None

    return datetime.fromisoformat(raw_value.replace("Z", "+00:00"))
